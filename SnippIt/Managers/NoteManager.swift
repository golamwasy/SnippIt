//
//  NoteManager.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import Foundation
import Combine

struct File: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    var content: String?
    let parentId: UUID?
}

struct Group: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
}

struct ServerFileResponse: Decodable {
    let file: File
}

struct ServerGroupResponse: Decodable {
    let group: Group
}

class NoteManager: ObservableObject {
    // MARK: - Published Properties
    @Published var groups: [Group] = []
    @Published var files: [File] = []
    @Published var isLoggedIn = false
    @Published var errorMessage = ""
    @Published var isSaving: Bool = false

    private var saveWorkItem: DispatchWorkItem?
    private let serverURL = "http://127.0.0.1:3000"
    private var token: String = ""

    // MARK: - Initialization
    init() {}

    // MARK: - Authentication
    func register(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(serverURL)/auth/register") else { return }
        let body = ["username": username, "password": password]
        performRequest(url: url, method: "POST", body: body, token: nil) { (success, data, error) in
            if success {
                completion(true, nil)
            } else {
                completion(false, error?.localizedDescription ?? "Registration failed")
            }
        }
    }

    func login(username: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(serverURL)/auth/login") else { return }
        let body = ["username": username, "password": password]
        performRequest(url: url, method: "POST", body: body, token: nil) { [weak self] (success, data, error) in
            if success, let data = data, let response = try? JSONDecoder().decode([String: String].self, from: data), let token = response["token"] {
                DispatchQueue.main.async {
                    self?.token = token
                    self?.isLoggedIn = true
                    self?.fetchGroups()
                    self?.fetchFiles()
                }
                completion(true, nil)
            } else {
                completion(false, error?.localizedDescription ?? "Login failed")
            }
        }
    }

    // MARK: - Group Operations
    func fetchGroups() {
        guard let url = URL(string: "\(serverURL)/groups") else { return }
        performRequest(url: url, method: "GET", token: token) { [weak self] (success, data, error) in
            if success, let data = data {
                if let fetchedGroups = try? JSONDecoder().decode([Group].self, from: data) {
                    DispatchQueue.main.async {
                        self?.groups = fetchedGroups
                    }
                }
            }
        }
    }

    func addGroup(name: String) {
        guard let url = URL(string: "\(serverURL)/groups") else { return }
        let body = ["name": name]
        performRequest(url: url, method: "POST", body: body, token: token) { [weak self] (success, data, error) in
            if success, let data = data, let newGroup = try? JSONDecoder().decode(Group.self, from: data) {
                DispatchQueue.main.async {
                    self?.groups.append(newGroup)
                }
            }
        }
    }

    func renameGroup(_ group: Group, newName: String) {
        guard let url = URL(string: "\(serverURL)/groups/\(group.id.uuidString.lowercased())") else { return }
        let body = ["name": newName]
        performRequest(url: url, method: "PUT", body: body, token: token) { [weak self] (success, _, _) in
            if success {
                DispatchQueue.main.async {
                    if let index = self?.groups.firstIndex(where: { $0.id == group.id }) {
                        self?.groups[index].name = newName
                    }
                }
            }
        }
    }

    func deleteGroup(_ group: Group) {
        guard let url = URL(string: "\(serverURL)/groups/\(group.id.uuidString.lowercased())") else { return }
        performRequest(url: url, method: "DELETE", token: token) { [weak self] (success, _, _) in
            if success {
                DispatchQueue.main.async {
                    self?.groups.removeAll { $0.id == group.id }
                    self?.files.removeAll { $0.parentId == group.id}
                }
            }
        }
    }

    // MARK: - File Operations
    func fetchFiles() {
        guard let url = URL(string: "\(serverURL)/files") else { return }
        performRequest(url: url, method: "GET", token: token) { [weak self] (success, data, error) in
            if success, let data = data {
                if let fetchedFiles = try? JSONDecoder().decode([File].self, from: data) {
                    DispatchQueue.main.async {
                        self?.files = fetchedFiles
                    }
                }
            }
        }
    }

    func addFile(to group: Group, name: String, content: String) {
        guard let url = URL(string: "\(serverURL)/files") else { return }
        let body = ["name": name, "content": content, "parentId": group.id.uuidString.lowercased()]
        performRequest(url: url, method: "POST", body: body, token: token) { [weak self] (success, data, error) in
            if success, let data = data, let newFile = try? JSONDecoder().decode(File.self, from: data) {
                DispatchQueue.main.async {
                    self?.files.append(newFile)
                }
            }
        }
    }

    func updateFileContent(_ file: File, newContent: String) {
        guard let fileIndex = files.firstIndex(where: { $0.id == file.id }) else { return }
        files[fileIndex].content = newContent

        saveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let url = URL(string: "\(self.serverURL)/files/\(file.id.uuidString.lowercased())") else { return }
            let body = ["content": newContent]
            self.performRequest(url: url, method: "PUT", body: body, token: self.token, completion: nil)
        }
        saveWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
    
    func renameFile(_ file: File, newName: String) {
        guard let url = URL(string: "\(serverURL)/files/\(file.id.uuidString.lowercased())") else { return }
        let body = ["name": newName]
        performRequest(url: url, method: "PUT", body: body, token: token) { [weak self] (success, _, _) in
            if success {
                DispatchQueue.main.async {
                    if let index = self?.files.firstIndex(where: { $0.id == file.id }) {
                        self?.files[index].name = newName
                    }
                }
            }
        }
    }

    func deleteFile(_ file: File) {
        guard let url = URL(string: "\(serverURL)/files/\(file.id.uuidString.lowercased())") else { return }
        performRequest(url: url, method: "DELETE", token: token) { [weak self] (success, _, _) in
            if success {
                DispatchQueue.main.async {
                    self?.files.removeAll { $0.id == file.id }
                }
            }
            else {
                print("error delete")
            }
        }
    }

    // MARK: - Networking Helper
    private func performRequest(url: URL, method: String, body: [String: Any]? = nil, token: String?, completion: ((Bool, Data?, Error?) -> Void)?) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion?(false, nil, error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion?(false, data, nil)
                return
            }
            completion?(true, data, nil)
        }.resume()
    }
}
