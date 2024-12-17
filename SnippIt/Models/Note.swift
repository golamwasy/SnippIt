//
//  Note.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import Foundation

enum NoteType: String, Codable {
    case group
    case file
}

//struct Note: Identifiable, Codable {
//    var id: UUID = UUID()
//    var name: String
//    var type: NoteType
//    var content: String? = nil // Used for file content
//    var children: [Note]? = nil // Used for group children
//}
