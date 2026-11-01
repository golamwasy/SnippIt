import Foundation

struct Note: Identifiable, Equatable {
    let id: UUID
    var name: String
    var content: String
    var folderID: UUID
    var deletedAt: Date? = nil
    var isTitleAutomatic = false
}

struct Folder: Identifiable, Equatable {
    let id: UUID
    var name: String
    var deletedAt: Date? = nil
}
