//
//  SidebarView.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var noteManager: NoteManager
    @Binding var selectedFile: File?
    @Binding var selectedGroup: Group?

    @State private var renamingGroup: Group?
    @State private var renamingFile: File?
    @State private var newName: String = ""

    var body: some View {
        VStack {
            List {
                if noteManager.groups.isEmpty {
                    Text("No groups available").foregroundColor(.gray)
                } else {
                    ForEach(noteManager.groups) { group in
                        GroupView(
                            group: group,
                            noteManager: noteManager,
                            selectedFile: $selectedFile,
                            selectedGroup: $selectedGroup,
                            renamingGroup: $renamingGroup,
                            renamingFile: $renamingFile,
                            newName: $newName
                        )
                    }
                }
            }
            .listStyle(SidebarListStyle())

            Button(action: {
                noteManager.addGroup(name: "New Group")
            }) {
                Label("Add Group", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
        .sheet(item: $renamingGroup) { group in
            RenameView(name: $newName, onSave: {
                noteManager.renameGroup(group, newName: newName)
                renamingGroup = nil
                newName = ""
            }, onCancel: {
                renamingGroup = nil
                newName = ""
            })
        }
        .sheet(item: $renamingFile) { file in
            RenameView(name: $newName, onSave: {
                noteManager.renameFile(file, newName: newName)
                renamingFile = nil
                newName = ""
            }, onCancel: {
                renamingFile = nil
                newName = ""
            })
        }
        .onAppear {
            noteManager.fetchGroups()
            noteManager.fetchFiles()
        }
    }
}

struct GroupView: View {
    let group: Group
    @ObservedObject var noteManager: NoteManager
    @Binding var selectedFile: File?
    @Binding var selectedGroup: Group?
    @Binding var renamingGroup: Group?
    @Binding var renamingFile: File?
    @Binding var newName: String

    var body: some View {
        DisclosureGroup {
            ForEach(noteManager.files.filter { $0.parentId == group.id }) { file in
                FileRowView(
                    file: file,
                    group: group,
                    noteManager: noteManager,
                    selectedFile: $selectedFile,
                    selectedGroup: $selectedGroup,
                    renamingFile: $renamingFile,
                    newName: $newName
                )
            }
        } label: {
            HStack {
                Text(group.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: {
                    noteManager.addFile(to: group, name: "New File", content: "Placeholder Content")
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add File")
            }
            .contextMenu {
                Button("Rename Group") {
                    renamingGroup = group
                    newName = group.name
                }
                Button("Delete Group") {
                    noteManager.deleteGroup(group)
                }
            }
            .padding(.vertical, 5)
        }
    }
}

struct FileRowView: View {
    let file: File
    let group: Group
    @ObservedObject var noteManager: NoteManager
    @Binding var selectedFile: File?
    @Binding var selectedGroup: Group?
    @Binding var renamingFile: File?
    @Binding var newName: String

    var body: some View {
        HStack {
            Text(file.name)
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(file.id == selectedFile?.id ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(5)
                .onTapGesture {
                    selectedFile = file
                    selectedGroup = group
                }
        }
        .contextMenu {
            Button("Rename File") {
                renamingFile = file
                newName = file.name
            }
            Button("Delete File") {
                noteManager.deleteFile(file)
            }
        }
    }
}
