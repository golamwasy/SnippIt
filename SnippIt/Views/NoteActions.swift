import SwiftUI

struct MoveNoteMenu: View {
    @ObservedObject var noteManager: NoteManager
    let note: Note

    var body: some View {
        Menu("Move to Folder", systemImage: "folder") {
            ForEach(noteManager.folders.filter { $0.id != note.folderID }) { folder in
                Button(folder.name) { noteManager.moveNote(note, to: folder) }
            }
        }
        .disabled(noteManager.folders.count < 2)
    }
}

struct NoteTitleField: View {
    let note: Note
    let onRename: (String) -> Void
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Note title", text: $draft)
            .textFieldStyle(.plain)
            .accessibilityIdentifier("noteTitle")
            .help("Rename this note")
            .focused($isFocused)
            .onAppear { draft = note.name }
            .onChange(of: note.name) { _, title in
                if !isFocused { draft = title }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onSubmit {
                commit()
                isFocused = false
            }
            .onExitCommand {
                draft = note.name
                isFocused = false
            }
            .onDisappear {
                if isFocused { commit() }
            }
    }

    private func commit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, title != note.name { onRename(title) }
        else { draft = note.name }
    }
}
