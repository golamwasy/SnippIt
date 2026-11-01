import Foundation
import SwiftData

// Stored entity and attribute names (StoredGroup, StoredFile, parentId, selectedFileID) are part of
// the on-disk schema. Keep them unchanged so existing libraries open without a migration.
@Model
final class StoredGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var position: Int
    var deletedAt: Date? = nil

    init(id: UUID, name: String, position: Int) {
        self.id = id
        self.name = name
        self.position = position
    }
}

@Model
final class StoredFile {
    @Attribute(.unique) var id: UUID
    var name: String
    var content: String
    var parentId: UUID
    var position: Int
    var deletedAt: Date? = nil
    var isTitleAutomatic: Bool = false

    init(note: Note, position: Int) {
        id = note.id
        name = note.name
        content = note.content
        parentId = note.folderID
        self.position = position
        deletedAt = note.deletedAt
        isTitleAutomatic = note.isTitleAutomatic
    }
}

@Model
final class LibraryPreferences {
    @Attribute(.unique) var key: String
    var selectedFileID: UUID?

    init(selectedNoteID: UUID?) {
        key = "library"
        self.selectedFileID = selectedNoteID
    }
}

@MainActor
protocol LibraryPersisting {
    func load() throws -> (folders: [Folder], notes: [Note], selectedNoteID: UUID?)
    func save(folders: [Folder], notes: [Note], selectedNoteID: UUID?) throws
    func saveNote(_ note: Note) throws
    func saveSelection(_ id: UUID?) throws
}

/// One local database for the whole app. No network services required.
@MainActor
final class LibraryStore: LibraryPersisting {
    private let container: ModelContainer
    private let context: ModelContext
    private var noteRecords: [UUID: StoredFile] = [:]
    private var preferences: LibraryPreferences?

    init(url: URL? = nil) throws {
        let databaseURL: URL
        if let url {
            databaseURL = url
        } else {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            databaseURL = support.appendingPathComponent("SnippIt", isDirectory: true)
                .appendingPathComponent("Library.store")
        }
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let schema = Schema([StoredGroup.self, StoredFile.self, LibraryPreferences.self])
        let configuration = ModelConfiguration(schema: schema, url: databaseURL, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func load() throws -> (folders: [Folder], notes: [Note], selectedNoteID: UUID?) {
        let folders = try context.fetch(FetchDescriptor<StoredGroup>(sortBy: [SortDescriptor(\.position)]))
            .map { Folder(id: $0.id, name: $0.name, deletedAt: $0.deletedAt) }
        let records = try context.fetch(FetchDescriptor<StoredFile>(sortBy: [SortDescriptor(\.position)]))
        noteRecords = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        let notes = records.map {
            Note(id: $0.id, name: $0.name, content: $0.content, folderID: $0.parentId,
                 deletedAt: $0.deletedAt, isTitleAutomatic: $0.isTitleAutomatic)
        }
        preferences = try context.fetch(FetchDescriptor<LibraryPreferences>()).first
        return (folders, notes, preferences?.selectedFileID)
    }

    func save(folders: [Folder], notes: [Note], selectedNoteID: UUID?) throws {
        do {
            let existingFolders = try context.fetch(FetchDescriptor<StoredGroup>())
            let existingNotes = try context.fetch(FetchDescriptor<StoredFile>())
            let folderIDs = Set(folders.map(\.id))
            let noteIDs = Set(notes.map(\.id))
            for record in existingFolders where !folderIDs.contains(record.id) { context.delete(record) }
            for record in existingNotes where !noteIDs.contains(record.id) { context.delete(record) }

            let folderRecords = Dictionary(uniqueKeysWithValues: existingFolders.map { ($0.id, $0) })
            for (position, folder) in folders.enumerated() {
                if let record = folderRecords[folder.id] {
                    if record.name != folder.name { record.name = folder.name }
                    if record.position != position { record.position = position }
                    if record.deletedAt != folder.deletedAt { record.deletedAt = folder.deletedAt }
                } else {
                    let record = StoredGroup(id: folder.id, name: folder.name, position: position)
                    record.deletedAt = folder.deletedAt
                    context.insert(record)
                }
            }
            let noteRecords = Dictionary(uniqueKeysWithValues: existingNotes.map { ($0.id, $0) })
            for (position, note) in notes.enumerated() {
                if let record = noteRecords[note.id] {
                    if record.name != note.name { record.name = note.name }
                    if record.content != note.content { record.content = note.content }
                    if record.parentId != note.folderID { record.parentId = note.folderID }
                    if record.position != position { record.position = position }
                    if record.deletedAt != note.deletedAt { record.deletedAt = note.deletedAt }
                    if record.isTitleAutomatic != note.isTitleAutomatic { record.isTitleAutomatic = note.isTitleAutomatic }
                } else {
                    context.insert(StoredFile(note: note, position: position))
                }
            }
            if let preferences = try context.fetch(FetchDescriptor<LibraryPreferences>()).first {
                if preferences.selectedFileID != selectedNoteID { preferences.selectedFileID = selectedNoteID }
            } else {
                context.insert(LibraryPreferences(selectedNoteID: selectedNoteID))
            }
            if context.hasChanges { try context.save() }
            // Structural edits refresh the cache. Ordinary typing touches one record.
            self.noteRecords = Dictionary(uniqueKeysWithValues:
                try context.fetch(FetchDescriptor<StoredFile>()).map { ($0.id, $0) })
            self.preferences = try context.fetch(FetchDescriptor<LibraryPreferences>()).first
        } catch {
            context.rollback()
            throw error
        }
    }

    func saveNote(_ note: Note) throws {
        guard let record = noteRecords[note.id] else {
            throw CocoaError(.fileNoSuchFile)
        }
        do {
            record.name = note.name
            record.content = note.content
            record.parentId = note.folderID
            record.deletedAt = note.deletedAt
            record.isTitleAutomatic = note.isTitleAutomatic
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func saveSelection(_ id: UUID?) throws {
        do {
            if let preferences {
                preferences.selectedFileID = id
            } else {
                let record = LibraryPreferences(selectedNoteID: id)
                context.insert(record)
                preferences = record
            }
            if context.hasChanges { try context.save() }
        } catch {
            context.rollback()
            preferences = try? context.fetch(FetchDescriptor<LibraryPreferences>()).first
            throw error
        }
    }
}
