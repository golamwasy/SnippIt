import SwiftUI

struct SnippItCommands: Commands {
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var settings: EditorSettings

    var body: some Commands {
        // Replaces New Window: selection is shared, so a second window would only mirror the first.
        CommandGroup(replacing: .newItem) {
            Button("New Note") { noteManager.newNote() }
                .keyboardShortcut("n")
                .disabled(!noteManager.canEdit)
            Button("New Folder") { noteManager.addFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!noteManager.canEdit)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { noteManager.save() }
                .keyboardShortcut("s")
                .disabled(!noteManager.canEdit)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            Toggle("Show Line Numbers", isOn: $settings.showsLineNumbers)
            Divider()
            Button("Increase Text Size") { settings.fontSize = min(28, settings.fontSize + 1) }
                .keyboardShortcut("+")
                .disabled(settings.fontSize >= 28)
            Button("Decrease Text Size") { settings.fontSize = max(11, settings.fontSize - 1) }
                .keyboardShortcut("-")
                .disabled(settings.fontSize <= 11)
            Button("Actual Text Size") { settings.fontSize = 14 }
                .keyboardShortcut("0")
        }
    }

}
