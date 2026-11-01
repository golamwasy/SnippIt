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
    /// The name last shown in the field. Only typing a different title renames the note,
    /// so focus changes alone never pin an outdated automatic title.
    @State private var shownName = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("Note title", text: $draft)
            .textFieldStyle(.plain)
            .accessibilityIdentifier("noteTitle")
            .help("Rename this note")
            .focused($isFocused)
            .onAppear { show(note.name) }
            .onChange(of: note.name) { _, title in
                if !isFocused { show(title) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onSubmit {
                commit()
                isFocused = false
            }
            .onExitCommand {
                show(note.name)
                isFocused = false
            }
            .onDisappear {
                if isFocused { commit() }
            }
    }

    private func show(_ name: String) {
        draft = name
        shownName = name
    }

    private func commit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, draft != shownName, title != note.name { onRename(title) }
        else { show(note.name) }
    }
}
