import Foundation
import Testing
@testable import SnippIt

@MainActor
struct SnippItTests {
    private func databaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SnippIt-Unit-Tests")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Library.store")
    }

    @Test func editsAndSelectionPersistWithoutExplicitSave() throws {
        let url = databaseURL()
        let original: (folders: [Folder], notes: [Note], selectedID: UUID?) = try {
            let manager = NoteManager(storageURL: url)
            #expect(manager.canEdit)
            let first = try #require(manager.addFolder(name: "Ideas"))
            let second = try #require(manager.addFolder(name: "Code"))
            let noteA = try #require(manager.addNote(to: first, name: "First"))
            let noteB = try #require(manager.addNote(to: second, name: "Second"))
            manager.updateNoteContent(noteA, newContent: "Hello 👋\nSuomi: äö\nবাংলা\n")
            manager.updateNoteContent(noteB, newContent: "Second note\r\nwith Windows newlines")
            manager.renameFolder(first, newName: "Personal")
            manager.renameNote(noteA, newName: "Thoughts")
            manager.selectNote(noteA.id)
            return (manager.folders, manager.notes, manager.selectedNoteID)
        }()

        // A new container reads disk, without a quit handler or a final manual save.
        let reopened = NoteManager(storageURL: url)
        #expect(reopened.errorMessage.isEmpty)
        #expect(reopened.folders == original.folders)
        #expect(reopened.notes == original.notes)
        #expect(reopened.selectedNoteID == original.selectedID)
    }

    @Test func folderDeletionAndSelectionPersist() throws {
        let url = databaseURL()
        let survivorID: UUID = try {
            let manager = NoteManager(storageURL: url)
            let doomed = try #require(manager.addFolder(name: "Delete me"))
            let kept = try #require(manager.addFolder(name: "Keep me"))
            let survivor = try #require(manager.addNote(to: kept, content: "Keep this text"))
            let doomedNote = try #require(manager.addNote(to: doomed, content: "Delete this"))
            manager.selectNote(doomedNote.id)
            manager.deleteFolder(doomed)
            #expect(manager.selectedNoteID == survivor.id)
            return survivor.id
        }()

        let reopened = NoteManager(storageURL: url)
        #expect(reopened.folders.map(\.name) == ["Keep me"])
        #expect(reopened.notes.map(\.id) == [survivorID])
        #expect(reopened.selectedNote?.content == "Keep this text")
        reopened.deleteNote(try #require(reopened.selectedNote))
        let empty = NoteManager(storageURL: url)
        #expect(empty.notes.isEmpty)
        #expect(empty.selectedNoteID == nil)
    }

    @Test func saveFailureKeepsTextAndRetryPersistsIt() throws {
        let url = databaseURL()
        let store = FailingStore(wrapping: try LibraryStore(url: url))
        let manager = NoteManager(store: store)
        let folder = try #require(manager.addFolder())
        let note = try #require(manager.addNote(to: folder, content: "Before"))
        store.failSaving = true
        manager.updateNoteContent(note, newContent: "Don't lose this")
        #expect(!manager.errorMessage.isEmpty)
        #expect(manager.selectedNote?.content == "Don't lose this")
        #expect(NoteManager(storageURL: url).selectedNote?.content == "Before")

        store.failSaving = false
        #expect(manager.save())
        #expect(manager.errorMessage.isEmpty)
        #expect(NoteManager(storageURL: url).selectedNote?.content == "Don't lose this")
    }

    @Test func failedLoadDoesNotAllowOverwritingLibrary() throws {
        let store = FailingStore(wrapping: try LibraryStore(url: databaseURL()))
        store.failLoading = true
        let manager = NoteManager(store: store)
        #expect(!manager.canEdit)
        #expect(!manager.errorMessage.isEmpty)
        #expect(manager.addFolder() == nil)
        #expect(!manager.save())
        #expect(store.saveCalls == 0)
    }

    @Test func logicalLinesIncludeEmptyAndTrailingLines() {
        #expect(TextLineMap("").starts == [0])
        #expect(TextLineMap("one\ntwo\n").starts == [0, 4, 8])
        #expect(TextLineMap("one\r\ntwo\r\n").starts == [0, 5, 10])
        #expect(TextLineMap("a\rb\u{2028}c\u{2029}").starts == [0, 2, 4, 6])
        let map = TextLineMap("👋ä\nবাংলা")
        #expect(map.starts == [0, 4])
        #expect(map.position(at: 3) == TextPosition(line: 1, column: 3))
        #expect(map.position(at: 4) == TextPosition(line: 2, column: 1))
    }

    @Test func existingLibraryUpgradesWithoutChangingTextOrNames() throws {
        let url = databaseURL()
        let original = try LegacyStoreFixture.create(at: url)
        let manager = NoteManager(storageURL: url)
        #expect(manager.canEdit, "\(manager.errorMessage)")
        #expect(manager.folders.first?.id == original.groupID)
        #expect(manager.selectedNoteID == original.fileID)
        #expect(manager.selectedNote?.name == "My original title")
        #expect(manager.selectedNote?.content == "Existing text\nবাংলা 👋")
        #expect(!manager.hasDeletedItems)
        manager.updateNoteContent(try #require(manager.selectedNote), newContent: "Edited after upgrade")
        let reopened = NoteManager(storageURL: url)
        #expect(reopened.selectedNote?.name == "My original title")
        #expect(reopened.selectedNote?.content == "Edited after upgrade")
    }

    @Test func automaticTitlesStopWhenRenamedAndMovingPersists() throws {
        let url = databaseURL()
        let manager = NoteManager(storageURL: url)
        let note = try #require(manager.newNote())
        manager.updateNoteContent(note, newContent: "\n  Shopping list  \nMilk")
        #expect(manager.selectedNote?.name == "Shopping list")
        manager.renameNote(note, newName: "Groceries")
        manager.updateNoteContent(note, newContent: "Different first line")
        #expect(manager.selectedNote?.name == "Groceries")
        let destination = try #require(manager.addFolder(name: "Home"))
        manager.moveNote(note, to: destination)
        let reopened = NoteManager(storageURL: url)
        #expect(reopened.selectedNote?.name == "Groceries")
        #expect(reopened.selectedNote?.folderID == destination.id)
        #expect(reopened.selectedNote?.content == "Different first line")
    }

    @Test func trashAndRestoreSurviveRelaunchAndPreservePriorDeletions() throws {
        let url = databaseURL()
        let manager = NoteManager(storageURL: url)
        let folder = try #require(manager.addFolder(name: "Projects"))
        let oldDeletion = try #require(manager.addNote(to: folder, name: "Previously deleted", content: "Old text"))
        let current = try #require(manager.addNote(to: folder, name: "Keep", content: "Important text"))
        manager.deleteNote(oldDeletion)
        manager.deleteFolder(folder)
        #expect(manager.notes.isEmpty)

        let reopened = NoteManager(storageURL: url)
        #expect(reopened.deletedFolders.count == 1)
        #expect(reopened.deletedNoteCount == 2)
        reopened.restoreFolder(folder)
        #expect(reopened.notes.map(\.id) == [current.id])
        #expect(reopened.deletedNotes.map(\.id) == [oldDeletion.id])
        reopened.restoreNote(oldDeletion)
        let restored = NoteManager(storageURL: url)
        #expect(restored.notes.count == 2)
        #expect(restored.selectedNote?.content == "Old text")
        #expect(!restored.hasDeletedItems)
    }

    @Test func permanentDeletionOnlyAppliesToTrashedItems() throws {
        let url = databaseURL()
        let manager = NoteManager(storageURL: url)
        let note = try #require(manager.newNote())
        manager.permanentlyDeleteNote(note)
        #expect(manager.notes.count == 1)
        manager.deleteNote(note)
        manager.permanentlyDeleteNote(note)
        let reopened = NoteManager(storageURL: url)
        #expect(reopened.notes.isEmpty)
        #expect(reopened.deletedNoteCount == 0)
    }

    @Test func typingSavesOnlyTheChangedNote() throws {
        let store = FailingStore(wrapping: try LibraryStore(url: databaseURL()))
        let manager = NoteManager(store: store)
        let note = try #require(manager.newNote())
        let fullSavesBeforeTyping = store.fullSaveCalls
        manager.updateNoteContent(note, newContent: "A")
        manager.updateNoteContent(note, newContent: "AB")
        manager.updateNoteContent(note, newContent: "ABC")
        #expect(store.fullSaveCalls == fullSavesBeforeTyping)
        #expect(try store.load().notes.first?.content == "ABC")
    }

    @Test func editorPreferencesPersist() {
        let suite = "SnippIt-Preferences-Test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = EditorSettings(defaults: defaults)
        #expect(settings.fontSize == 14)
        #expect(settings.showsLineNumbers)
        settings.fontSize = 19
        settings.showsLineNumbers = false
        let reopened = EditorSettings(defaults: defaults)
        #expect(reopened.fontSize == 19)
        #expect(!reopened.showsLineNumbers)
    }
}

@MainActor
private final class FailingStore: LibraryPersisting {
    let store: LibraryStore
    var failSaving = false
    var failLoading = false
    var saveCalls = 0
    var fullSaveCalls = 0

    init(wrapping store: LibraryStore) { self.store = store }

    func load() throws -> (folders: [Folder], notes: [Note], selectedNoteID: UUID?) {
        if failLoading { throw CocoaError(.fileReadCorruptFile) }
        return try store.load()
    }

    func save(folders: [Folder], notes: [Note], selectedNoteID: UUID?) throws {
        saveCalls += 1
        fullSaveCalls += 1
        if failSaving { throw CocoaError(.fileWriteOutOfSpace) }
        try store.save(folders: folders, notes: notes, selectedNoteID: selectedNoteID)
    }

    func saveNote(_ note: Note) throws {
        saveCalls += 1
        if failSaving { throw CocoaError(.fileWriteOutOfSpace) }
        try store.saveNote(note)
    }

    func saveSelection(_ id: UUID?) throws {
        saveCalls += 1
        if failSaving { throw CocoaError(.fileWriteOutOfSpace) }
        try store.saveSelection(id)
    }
}
