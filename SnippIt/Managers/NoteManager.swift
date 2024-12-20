//
//  NoteManager.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import Foundation

enum Note: Codable {
    case group(Group)
    case file(File)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "group":
            self = .group(try Group(from: decoder))
        case "file":
            self = .file(try File(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unexpected type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .group(let group):
            try group.encode(to: encoder)
        case .file(let file):
            try file.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }
}

struct File: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    let type: String
    var content: String?
    let parentId: UUID?
}

struct Group: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    let type: String
    let parentId: UUID?
    var files: [File] = [] // Files stored in this group
}

struct NoteUpdateResponse: Codable {
    let message: String
    let note: File
}

struct ServerFileResponse: Decodable {
    let file: File
}

struct ServerGroupResponse: Decodable {
    let group: Group
}

class NoteManager: ObservableObject {
    // MARK: - Published Properties
    @Published var groups: [Group] = []           // All groups and their files
    @Published var files: [File] = []
    @Published var isLoggedIn = false             // Tracks login state
    @Published var errorMessage = ""              // Error messages for the UI
    @Published var isSaving: Bool = false

    private var saveWorkItem: DispatchWorkItem?   // For debounced saving

    // Server related
    private let serverURL = "http://127.0.0.1:3000"
    private var token: String = ""

    // MARK: - Initialization
    init() {}

    func saveNotes(for file: File, in group: Group) {
        guard let url = URL(string: "\(serverURL)/notes/\(file.id)") else {
            print("Invalid URL for note update")
            return
        }
        guard let fileIndex = files.firstIndex(where: { $0.id == file.id }) else {
            print("Error: Group or file not found.")
            return
        }

        let updatedFile = files[fileIndex]

        // Prepare the request body
        let body: [String: Any] = [
            "name": updatedFile.name,
            "content": updatedFile.content ?? "",
            "type": updatedFile.type
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Indicate that saving is in progress
        DispatchQueue.main.async {
            self.isSaving = true
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSaving = false // Reset saving indicator
            }
            
            if let error = error {
                print("Failed to save note: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Failed to save note: Invalid server response")
                return
            }

            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(NoteUpdateResponse.self, from: data)
                    let updatedNote = decodedResponse.note
                    
                    DispatchQueue.main.async {
                        // Update the local state with the server response
                        self.files[fileIndex] = updatedNote
                        print("Note updated successfully")
                    }
                } catch {
                    print("Failed to decode server response: \(error)")
                }
            }
        }.resume()
    }

    // MARK: - Group Operations
    func addGroup(name: String) {
        guard let url = URL(string: "\(serverURL)/groups") else { return }

        let body: [String: Any] = [
            "name": name
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to add group: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                let newGroup = try JSONDecoder().decode(Group.self, from: data)
                DispatchQueue.main.async {
                    self.groups.append(newGroup)
                    print("Group added successfully: \(newGroup.name)")
                }
            } catch {
                print("Failed to decode server response: \(error)")
            }
        }.resume()
    }

    func renameGroup(_ group: Group, newName: String) {
        guard let url = URL(string: "\(serverURL)/notes/group/\(group.id.uuidString.lowercased())/rename") else { return }

        let body: [String: Any] = ["newName": newName]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to rename group: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                // Decode the server response to get the `file` object
                let serverResponse = try JSONDecoder().decode(ServerGroupResponse.self, from: data)
                let updatedGroup = serverResponse.group
                
                print(updatedGroup)
                
                DispatchQueue.main.async {
                    if let groupIndex = self.groups.firstIndex(where: { $0.id == updatedGroup.id }) {
                        // Update the corresponding file in your array
                        self.groups[groupIndex] = updatedGroup
                        print("Group renamed successfully to: \(updatedGroup.name)")
                    }
                }
            } catch {
                print("Failed to decode server response: \(error)")
            }
        }.resume()
    }
    
    func renameFile(_ file: File, in group: Group, newName: String) {
        guard let url = URL(string: "\(serverURL)/notes/file/\(file.id.uuidString.lowercased())/rename") else { return }

        let body: [String: Any] = ["newName": newName]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to rename file: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                // Decode the server response to get the `file` object
                let serverResponse = try JSONDecoder().decode(ServerFileResponse.self, from: data)
                let updatedFile = serverResponse.file

                DispatchQueue.main.async {
                    if let fileIndex = self.files.firstIndex(where: { $0.id == updatedFile.id }) {
                        // Update the corresponding file in your array
                        self.files[fileIndex] = updatedFile
                        print("File renamed successfully to: \(updatedFile.name)")
                    }
                }
            } catch {
                print("Failed to decode server response: \(error)")
            }
        }.resume()
    }

    func deleteGroup(_ group: Group) {
        guard let url = URL(string: "\(serverURL)/notes/group/\(group.id.uuidString.lowercased())") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Failed to delete group: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.groups.removeAll { $0.id == group.id }
                print("Group deleted successfully")
            }
        }.resume()
    }

    // MARK: - File Operations
    func addFile(to group: Group, name: String, content: String) {
        guard let url = URL(string: "\(serverURL)/notes") else { return }

        let body: [String: Any] = [
            "name": name,
            "content": content,
            "parentId": group.id.uuidString.lowercased()
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to add file: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                let newFile = try JSONDecoder().decode(File.self, from: data)
                DispatchQueue.main.async {
                    if self.groups.firstIndex(where: { $0.id == group.id }) != nil {
                        self.files.append(newFile)
                    }
                    print("File added successfully: \(newFile.name)")
                }
            } catch {
                print("Failed to decode server response: \(error)")
            }
        }.resume()
    }

    func updateFileContent(_ file: File, in group: Group, newContent: String) {
        // Ensure the file exists in our list
        guard let fileIndex = files.firstIndex(where: { $0.id == file.id }) else {
            return
        }

        // Check if the content has changed
        if files[fileIndex].content != newContent {
            // Update the file content in memory
            files[fileIndex].content = newContent

            // Cancel any previously scheduled save operation
            saveWorkItem?.cancel()

            // Schedule a new save operation after a delay (debounce)
            let workItem = DispatchWorkItem { [weak self] in
                self?.saveNotes(for: file, in: group)
            }
            saveWorkItem = workItem

            // Set the debounce delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem) // 5-second delay
        }
    }

    func deleteFile(_ file: File, from group: Group) {
        guard let url = URL(string: "\(serverURL)/notes/file/\(file.id.uuidString)") else { return }
        print(url)

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Failed to delete file: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.async {
                self.files.removeAll() { $0.id == file.id }
                print("File deleted successfully")
            }
        }.resume()
    }
    
    // MARK: - Register
    func register(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(serverURL)/register") else { return }

        let body = ["username": username, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Registration failed: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "Invalid server response")
                }
                return
            }

            if httpResponse.statusCode == 200,
               let data = data,
               let response = try? JSONDecoder().decode([String: String].self, from: data),
               let message = response["message"] {
                if message == "User registered successfully" {
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false, message)
                    }
                }
            } else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    completion(false, "Registration failed: \(errorMessage)")
                }
            }
        }.resume()
    }

    // MARK: - Authentication
    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(serverURL)/login") else { return }

        let body = ["username": username, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, "Login failed: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(false, "Invalid server response")
                }
                return
            }

            if httpResponse.statusCode == 200,
               let data = data,
               let response = try? JSONDecoder().decode([String: String].self, from: data),
               let token = response["token"] {
                DispatchQueue.main.async {
                    self.token = token
                    self.isLoggedIn = true
                    self.fetchNotes()
                    completion(true, nil)
                }
            } else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                DispatchQueue.main.async {
                    completion(false, "Login failed: \(errorMessage)")
                }
            }
        }.resume()
    }

    func fetchNotes() {
        guard let url = URL(string: "\(serverURL)/notes") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Failed to fetch notes: \(error.localizedDescription)")
                return
            }

            guard let data = data else { return }

            do {
                // Decode the response into the Note enum
                let decodedNotes = try JSONDecoder().decode([Note].self, from: data)

                DispatchQueue.main.async {
                    // Separate groups and files
                    self.groups = decodedNotes.compactMap { note in
                        if case .group(let group) = note {
                            print(note)
                            return group
                        }
                        return nil
                    }

                    self.files = decodedNotes.compactMap { note in
                        if case .file(let file) = note {
                            return file
                        }
                        return nil
                    }

                    // Log for debugging
//                    print("Groups: \(self.groups)")
//                    print("Files: \(self.files)")
                }
            } catch {
                print("Failed to decode notes: \(error)")
            }
        }.resume()
    }
}
