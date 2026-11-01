import Foundation
import Combine

@MainActor
final class NoteManager: ObservableObject {
    @Published private var folderRecords: [Folder] = [] {
        didSet { folders = folderRecords.filter { $0.deletedAt == nil } }
    }
    @Published private var noteRecords: [Note] = [] {
        didSet { notes = noteRecords.filter { $0.deletedAt == nil } }
    }
    @Published private(set) var errorMessage = ""
    @Published private(set) var canEdit = false
    @Published private(set) var selectedNoteID: UUID?

    private var store: (any LibraryPersisting)?

    // Cached because views read these many times per keystroke.
    private(set) var folders: [Folder] = []
    private(set) var notes: [Note] = []
    var deletedFolders: [Folder] {
        folderRecords.filter { $0.deletedAt != nil }.sorted { $0.deletedAt! > $1.deletedAt! }
    }
    var deletedNotes: [Note] {
        let deletedFolderIDs = Set(deletedFolders.map(\.id))
        return noteRecords.filter { $0.deletedAt != nil && !deletedFolderIDs.contains($0.folderID) }
            .sorted { $0.deletedAt! > $1.deletedAt! }
    }
    var deletedNoteCount: Int { noteRecords.filter { $0.deletedAt != nil }.count }
    var hasDeletedItems: Bool { !deletedFolders.isEmpty || !deletedNotes.isEmpty }
    var selectedNote: Note? { notes.first { $0.id == selectedNoteID } }

    init(storageURL: URL? = nil) {
        do {
            try open(LibraryStore(url: storageURL))
        } catch {
            reportOpenError(error)
        }
    }

    init(store: any LibraryPersisting) {
        do {
            try open(store)
        } catch {
            reportOpenError(error)
        }
    }

    private func open(_ store: any LibraryPersisting) throws {
        let library = try store.load()
        self.store = store
        folderRecords = library.folders
        noteRecords = library.notes
        selectedNoteID = library.selectedNoteID
        repairSelection()
        canEdit = true
    }

    private func reportOpenError(_ error: Error) {
        // Never silently replace an unreadable library with an empty database.
        errorMessage = "Couldn't open your notes. Your stored data has not been replaced. \(error.localizedDescription)"
    }

    func selectNote(_ id: UUID?) {
        guard canEdit, id == nil || notes.contains(where: { $0.id == id }),
              selectedNoteID != id else { return }
        selectedNoteID = id
        if !errorMessage.isEmpty { save(); return }
        do {
            try store?.saveSelection(id)
        } catch {
            reportSaveError(error)
        }
    }

    @discardableResult
    func newNote() -> Note? {
        let folder = folders.first { $0.id == selectedNote?.folderID }
            ?? folders.first ?? addFolder(name: "Notes")
        guard let folder else { return nil }
        return addNote(to: folder)
    }

    @discardableResult
    func addFolder(name: String? = nil) -> Folder? {
        guard canEdit else { return nil }
        let title = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = Folder(id: UUID(), name: title.flatMap { $0.isEmpty ? nil : $0 }
            ?? uniqueName("New Folder", among: folders.map(\.name)))
        folderRecords.append(folder)
        save()
        return folder
    }

    func renameFolder(_ folder: Folder, newName: String) {
        let title = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, !title.isEmpty,
              let index = folderRecords.firstIndex(where: { $0.id == folder.id && $0.deletedAt == nil }) else { return }
        folderRecords[index].name = title
        save()
    }

    /// Removing a folder is reversible, including its notes.
    func deleteFolder(_ folder: Folder) {
        guard canEdit, let index = folderRecords.firstIndex(where: { $0.id == folder.id && $0.deletedAt == nil }) else { return }
        let date = Date()
        folderRecords[index].deletedAt = date
        for index in noteRecords.indices where noteRecords[index].folderID == folder.id && noteRecords[index].deletedAt == nil {
            noteRecords[index].deletedAt = date
        }
        repairSelection()
        save()
    }

    @discardableResult
    func addNote(to folder: Folder, name: String? = nil, content: String = "") -> Note? {
        guard canEdit, folders.contains(where: { $0.id == folder.id }) else { return nil }
        let explicitTitle = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let automatic = explicitTitle == nil || explicitTitle!.isEmpty
        let title = automatic ? suggestedTitle(content, excluding: nil) : explicitTitle!
        let note = Note(id: UUID(), name: title, content: content, folderID: folder.id, isTitleAutomatic: automatic)
        noteRecords.append(note)
        selectedNoteID = note.id
        save()
        return note
    }

    func updateNoteContent(_ note: Note, newContent: String) {
        guard canEdit, let index = noteRecords.firstIndex(where: { $0.id == note.id && $0.deletedAt == nil }),
              noteRecords[index].content != newContent else { return }
        noteRecords[index].content = newContent
        if noteRecords[index].isTitleAutomatic {
            noteRecords[index].name = suggestedTitle(newContent, excluding: note.id)
        }
        saveNote(noteRecords[index])
    }

    func renameNote(_ note: Note, newName: String) {
        let title = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, !title.isEmpty,
              let index = noteRecords.firstIndex(where: { $0.id == note.id && $0.deletedAt == nil }) else { return }
        guard noteRecords[index].name != title else { return }
        noteRecords[index].name = title
        noteRecords[index].isTitleAutomatic = false
        saveNote(noteRecords[index])
    }

    func moveNote(_ note: Note, to folder: Folder) {
        guard canEdit, folders.contains(where: { $0.id == folder.id }),
              let index = noteRecords.firstIndex(where: { $0.id == note.id && $0.deletedAt == nil }) else { return }
        noteRecords[index].folderID = folder.id
        saveNote(noteRecords[index])
    }

    func deleteNote(_ note: Note) {
        guard canEdit, let index = noteRecords.firstIndex(where: { $0.id == note.id && $0.deletedAt == nil }) else { return }
        noteRecords[index].deletedAt = Date()
        repairSelection()
        save()
    }

    func restoreNote(_ note: Note) {
        guard canEdit, let index = noteRecords.firstIndex(where: { $0.id == note.id && $0.deletedAt != nil }),
              folders.contains(where: { $0.id == noteRecords[index].folderID }) else { return }
        noteRecords[index].deletedAt = nil
        selectedNoteID = note.id
        save()
    }

    func restoreFolder(_ folder: Folder) {
        guard canEdit, let index = folderRecords.firstIndex(where: { $0.id == folder.id }),
              let deletionDate = folderRecords[index].deletedAt else { return }
        folderRecords[index].deletedAt = nil
        // Notes deleted separately before the folder remain in Recently Deleted.
        for index in noteRecords.indices where noteRecords[index].folderID == folder.id
            && noteRecords[index].deletedAt == deletionDate {
            noteRecords[index].deletedAt = nil
        }
        selectedNoteID = notes.first { $0.folderID == folder.id }?.id ?? selectedNoteID
        save()
    }

    func permanentlyDeleteNote(_ note: Note) {
        guard canEdit, noteRecords.contains(where: { $0.id == note.id && $0.deletedAt != nil }) else { return }
        noteRecords.removeAll { $0.id == note.id }
        save()
    }

    func permanentlyDeleteFolder(_ folder: Folder) {
        guard canEdit, folderRecords.contains(where: { $0.id == folder.id && $0.deletedAt != nil }) else { return }
        noteRecords.removeAll { $0.folderID == folder.id }
        folderRecords.removeAll { $0.id == folder.id }
        save()
    }

    func noteCount(in folder: Folder) -> Int {
        noteRecords.filter { $0.folderID == folder.id }.count
    }

    private func suggestedTitle(_ content: String, excluding id: UUID?) -> String {
        var firstLine: String?
        content.enumerateLines { line, stop in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                firstLine = trimmed
                stop = true
            }
        }
        if let firstLine { return String(firstLine.prefix(80)) }
        return uniqueName("Untitled", among: notes.filter { $0.id != id }.map(\.name))
    }

    private func uniqueName(_ base: String, among names: [String]) -> String {
        let existing = Set(names.map { $0.lowercased() })
        if !existing.contains(base.lowercased()) { return base }
        var suffix = 2
        while existing.contains("\(base) \(suffix)".lowercased()) { suffix += 1 }
        return "\(base) \(suffix)"
    }

    private func repairSelection() {
        if !notes.contains(where: { $0.id == selectedNoteID }) {
            selectedNoteID = notes.first?.id
        }
    }

    private func saveNote(_ note: Note) {
        // A failed earlier operation must also be retried, not hidden by a later edit.
        guard errorMessage.isEmpty else { save(); return }
        do {
            try store?.saveNote(note)
        } catch {
            reportSaveError(error)
        }
    }

    private func reportSaveError(_ error: Error) {
        errorMessage = "Couldn't save your notes. Keep SnippIt open and try again. \(error.localizedDescription)"
    }

    @discardableResult
    func save() -> Bool {
        guard canEdit, let store else { return false }
        do {
            try store.save(folders: folderRecords, notes: noteRecords, selectedNoteID: selectedNoteID)
            errorMessage = ""
            return true
        } catch {
            // Keep unsaved text in memory, report the failure, and allow retry.
            reportSaveError(error)
            return false
        }
    }
}
