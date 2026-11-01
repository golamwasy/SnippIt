import SwiftUI

struct SidebarView: View {
    @ObservedObject var noteManager: NoteManager
    @State private var searchText = ""
    @State private var expandedFolders: Set<UUID> = []
    @State private var renamingFolder: Folder?
    @State private var renamingNote: Note?
    @State private var newName = ""
    @State private var deletingFolder: Folder?
    @State private var showsRecentlyDeleted = false

    private var selection: Binding<UUID?> {
        Binding(
            get: { noteManager.selectedNoteID },
            set: { id in
                if id == nil || noteManager.notes.contains(where: { $0.id == id }) {
                    noteManager.selectNote(id)
                }
            }
        )
    }

    /// Visible notes keyed by folder. Built once per render so note contents are searched only once.
    private func matchingNotes() -> [UUID: [Note]] {
        let folderNames = Dictionary(noteManager.folders.map { ($0.id, $0.name) }) { first, _ in first }
        let matches = noteManager.notes.filter { note in
            guard let folderName = folderNames[note.folderID] else { return false }
            return searchText.isEmpty
                || note.name.localizedCaseInsensitiveContains(searchText)
                || note.content.localizedCaseInsensitiveContains(searchText)
                || folderName.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: matches, by: \.folderID)
    }

    var body: some View {
        let matches = matchingNotes()
        VStack(spacing: 0) {
            List(selection: selection) {
                Section("Folders") {
                    ForEach(noteManager.folders) { folder in
                        if searchText.isEmpty || matches[folder.id] != nil {
                            DisclosureGroup(isExpanded: Binding(
                                get: { !searchText.isEmpty || expandedFolders.contains(folder.id) },
                                set: { expanded in
                                    if expanded { expandedFolders.insert(folder.id) }
                                    else { expandedFolders.remove(folder.id) }
                                }
                            )) {
                                ForEach(matches[folder.id] ?? []) { note in
                                    Label(note.name, systemImage: "doc.text")
                                        .lineLimit(1)
                                        .padding(.vertical, 3)
                                        .tag(note.id)
                                        .contextMenu {
                                            Button("Rename…") {
                                                newName = note.name
                                                renamingNote = note
                                            }
                                            MoveNoteMenu(noteManager: noteManager, note: note)
                                            Divider()
                                            Button("Move to Recently Deleted", role: .destructive) {
                                                noteManager.deleteNote(note)
                                            }
                                        }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Label(folder.name, systemImage: "folder")
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        expandedFolders.insert(folder.id)
                                        noteManager.addNote(to: folder)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("New Note in \(folder.name)")
                                    .accessibilityLabel("New Note in \(folder.name)")
                                }
                                .padding(.vertical, 3)
                                .contextMenu {
                                    Button("New Note") {
                                        expandedFolders.insert(folder.id)
                                        noteManager.addNote(to: folder)
                                    }
                                    Button("Rename…") {
                                        newName = folder.name
                                        renamingFolder = folder
                                    }
                                    Button("Move to Recently Deleted…", role: .destructive) {
                                        deletingFolder = folder
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search notes")
            .overlay {
                if noteManager.folders.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("Your notes live here")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Create Folder") { noteManager.addFolder() }
                            .buttonStyle(.link)
                    }
                } else if !searchText.isEmpty && matches.isEmpty {
                    Text("No matching notes")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
            HStack(spacing: 7) {
                Image(systemName: "internaldrive")
                Text("On My Mac")
                Spacer()
                Text("\(noteManager.notes.count) \(noteManager.notes.count == 1 ? "note" : "notes")")
                Button {
                    showsRecentlyDeleted = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Recently Deleted")
                .accessibilityLabel("Recently Deleted")
                .padding(.leading, 4)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("SnippIt")
        .onAppear { expandedFolders.formUnion(noteManager.folders.map(\.id)) }
        .onChange(of: noteManager.folders.map(\.id)) { old, new in
            expandedFolders.formUnion(Set(new).subtracting(old))
        }
        .onChange(of: noteManager.selectedNoteID) { _, _ in
            if let parent = noteManager.selectedNote?.folderID { expandedFolders.insert(parent) }
        }
        .onChange(of: noteManager.notes.map(\.id)) { old, new in
            if let selected = noteManager.selectedNoteID, !old.contains(selected), new.contains(selected) {
                searchText = ""
            }
        }
        .sheet(isPresented: $showsRecentlyDeleted) {
            RecentlyDeletedView(noteManager: noteManager)
        }
        .sheet(item: $renamingFolder) { folder in
            RenameView(name: $newName, onSave: {
                noteManager.renameFolder(folder, newName: newName)
                renamingFolder = nil
            }, onCancel: { renamingFolder = nil })
        }
        .sheet(item: $renamingNote) { note in
            RenameView(name: $newName, onSave: {
                noteManager.renameNote(note, newName: newName)
                renamingNote = nil
            }, onCancel: { renamingNote = nil })
        }
        .alert("Move this folder to Recently Deleted?", isPresented: Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )) {
            Button("Move Folder", role: .destructive) {
                if let folder = deletingFolder { noteManager.deleteFolder(folder) }
                deletingFolder = nil
            }
            Button("Cancel", role: .cancel) { deletingFolder = nil }
        } message: {
            Text("You can restore “\(deletingFolder?.name ?? "")” and its notes from Recently Deleted.")
        }
    }
}
