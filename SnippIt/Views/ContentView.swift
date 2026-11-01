import SwiftUI

struct ContentView: View {
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var settings: EditorSettings

    var body: some View {
        VStack(spacing: 0) {
            if !noteManager.errorMessage.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(noteManager.errorMessage)
                        .font(.callout)
                        .textSelection(.enabled)
                    Spacer()
                    if noteManager.canEdit {
                        Button("Retry Save") { noteManager.save() }
                    }
                }
                .padding(12)
                .background(.orange.opacity(0.1))
                Divider()
            }

            NavigationSplitView {
                SidebarView(noteManager: noteManager)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
            } detail: {
                TextEditorView(noteManager: noteManager)
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItemGroup {
                    Button { noteManager.newNote() } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    .help("New Note (⌘N)")
                    .disabled(!noteManager.canEdit)

                    Button {
                        noteManager.addFolder()
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    .help("New Folder (⇧⌘N)")
                    .disabled(!noteManager.canEdit)
                }
            }
            .disabled(!noteManager.canEdit)
        }
        .frame(minWidth: 720, minHeight: 440)
        .environmentObject(settings)
    }

}
