import SwiftUI

struct RecentlyDeletedView: View {
    @ObservedObject var noteManager: NoteManager
    @Environment(\.dismiss) private var dismiss
    @State private var deletion: DeletedItem?
    @State private var confirmsDeletion = false

    private enum DeletedItem {
        case note(Note)
        case folder(Folder)
        var name: String {
            switch self {
            case .note(let note): note.name
            case .folder(let folder): folder.name
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recently Deleted").font(.title2.weight(.semibold))
                Text("Restore a note whenever you need it. Items stay here until you remove them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(24)

            if noteManager.hasDeletedItems {
                List {
                    if !noteManager.deletedFolders.isEmpty {
                        Section("Folders") {
                            ForEach(noteManager.deletedFolders) { folder in
                                let count = noteManager.noteCount(in: folder)
                                HStack(spacing: 12) {
                                    Image(systemName: "folder").foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(folder.name).lineLimit(1)
                                        Text("\(count) \(count == 1 ? "note" : "notes")")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Restore") { noteManager.restoreFolder(folder) }
                                        .accessibilityIdentifier("restore-folder-\(folder.id)")
                                    removeButton(.folder(folder))
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                    if !noteManager.deletedNotes.isEmpty {
                        Section("Notes") {
                            ForEach(noteManager.deletedNotes) { note in
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text").foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(note.name).lineLimit(1)
                                        if let date = note.deletedAt {
                                            Text(date, format: .dateTime.day().month().year())
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button("Restore") { noteManager.restoreNote(note) }
                                        .accessibilityIdentifier("restore-note-\(note.id)")
                                    removeButton(.note(note))
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .buttonStyle(.borderless)
            } else {
                ContentUnavailableView("Nothing deleted", systemImage: "trash",
                                       description: Text("Notes you delete will appear here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !noteManager.errorMessage.isEmpty {
                Text(noteManager.errorMessage)
                    .font(.caption).foregroundStyle(.orange)
                    .padding(.horizontal, 24)
                Button("Retry Save") { noteManager.save() }
                    .padding(.horizontal, 24)
            }

            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 540, height: 460)
        .alert("Delete permanently?", isPresented: $confirmsDeletion, presenting: deletion) { item in
            Button("Delete Permanently", role: .destructive) {
                switch item {
                case .note(let note): noteManager.permanentlyDeleteNote(note)
                case .folder(let folder): noteManager.permanentlyDeleteFolder(folder)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("“\(item.name)” will be removed permanently. This cannot be undone.")
        }
    }

    private func removeButton(_ item: DeletedItem) -> some View {
        Button {
            deletion = item
            confirmsDeletion = true
        } label: {
            Image(systemName: "trash")
        }
        .foregroundStyle(.secondary)
        .help("Delete permanently")
        .accessibilityLabel("Delete \(item.name) permanently")
    }
}
