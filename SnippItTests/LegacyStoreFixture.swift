import Foundation
import SwiftData

/// Frozen model shapes from the first local-storage release.
/// Keeping their entity names unchanged exercises the real on-disk upgrade.
enum LegacyStoreFixture {
    @Model final class StoredGroup {
        @Attribute(.unique) var id: UUID
        var name: String
        var position: Int
        init(id: UUID, name: String, position: Int) {
            self.id = id
            self.name = name
            self.position = position
        }
    }

    @Model final class StoredFile {
        @Attribute(.unique) var id: UUID
        var name: String
        var content: String
        var parentId: UUID
        var position: Int
        init(id: UUID, parentId: UUID) {
            self.id = id
            self.parentId = parentId
            name = "My original title"
            content = "Existing text\nবাংলা 👋"
            position = 0
        }
    }

    @Model final class LibraryPreferences {
        @Attribute(.unique) var key: String
        var selectedFileID: UUID?
        init(selectedFileID: UUID) {
            key = "library"
            self.selectedFileID = selectedFileID
        }
    }

    @MainActor
    static func create(at url: URL) throws -> (groupID: UUID, fileID: UUID) {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let schema = Schema([StoredGroup.self, StoredFile.self, LibraryPreferences.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        ])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let groupID = UUID()
        let fileID = UUID()
        context.insert(StoredGroup(id: groupID, name: "Original folder", position: 0))
        context.insert(StoredFile(id: fileID, parentId: groupID))
        context.insert(LibraryPreferences(selectedFileID: fileID))
        try context.save()
        return (groupID, fileID)
    }
}
