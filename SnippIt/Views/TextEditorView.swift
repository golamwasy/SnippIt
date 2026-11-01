import SwiftUI

struct TextEditorView: View {
    @ObservedObject var noteManager: NoteManager
    @EnvironmentObject private var settings: EditorSettings
    @State private var cursor = TextPosition()

    var body: some View {
        if let note = noteManager.selectedNote {
            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                    Text(noteManager.folders.first { $0.id == note.folderID }?.name ?? "")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    NoteTitleField(note: note) { noteManager.renameNote(note, newName: $0) }
                        .id(note.id)
                        .foregroundStyle(.primary)
                    Menu {
                        MoveNoteMenu(noteManager: noteManager, note: note)
                        Divider()
                        Button("Move to Recently Deleted", systemImage: "trash", role: .destructive) {
                            noteManager.deleteNote(note)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Note actions")
                    .accessibilityLabel("Note actions")
                    .accessibilityIdentifier("noteActions")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)

                Divider()

                NativeTextEditor(text: Binding(
                    get: { note.content },
                    set: { noteManager.updateNoteContent(note, newContent: $0) }
                ), position: $cursor, fontSize: settings.fontSize, showsLineNumbers: settings.showsLineNumbers)
                .id(note.id)
                .onChange(of: note.id, initial: true) { _, _ in cursor = TextPosition() }

                Divider()

                HStack(spacing: 6) {
                    Image(systemName: noteManager.errorMessage.isEmpty ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(noteManager.errorMessage.isEmpty ? Color.secondary : .orange)
                    Text(noteManager.errorMessage.isEmpty ? "Saved on this Mac" : "Changes not saved")
                    Spacer()
                    Text("Ln \(cursor.line), Col \(cursor.column)")
                        .monospacedDigit()
                    Text("·").padding(.horizontal, 4)
                    Text("\(note.content.count) characters")
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .navigationTitle(note.name)
        } else {
            ContentUnavailableView {
                Label("A little space for your thoughts", systemImage: "square.and.pencil")
            } description: {
                Text("Choose a note from the sidebar, or create one with ⌘N.\nYour notes are saved automatically on this Mac.")
            } actions: {
                Button("Create a Note") {
                    noteManager.newNote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!noteManager.canEdit)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .navigationTitle("SnippIt")
        }
    }
}
