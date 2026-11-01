import SwiftUI
import AppKit

@main
struct SnippItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var noteManager: NoteManager
    @StateObject private var settings: EditorSettings

    init() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let testLibrary = environment["SNIPPIT_TEST_LIBRARY"]
            ?? (environment["XCTestConfigurationFilePath"] == nil ? nil : "unit-host-\(UUID())")
        if let testLibrary {
            _settings = StateObject(wrappedValue: EditorSettings(
                defaults: UserDefaults(suiteName: "SnippIt-Tests-\(testLibrary)")!
            ))
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("SnippIt-Tests", isDirectory: true)
                .appendingPathComponent(testLibrary, isDirectory: true)
                .appendingPathComponent("Library.store")
            _noteManager = StateObject(wrappedValue: NoteManager(storageURL: url))
            return
        }
        #endif
        _settings = StateObject(wrappedValue: EditorSettings())
        _noteManager = StateObject(wrappedValue: NoteManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(noteManager: noteManager, settings: settings)
                .onAppear { appDelegate.noteManager = noteManager }
        }
        .defaultSize(width: 1080, height: 720)
        .commands {
            SnippItCommands(noteManager: noteManager, settings: settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var noteManager: NoteManager?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let noteManager, noteManager.canEdit, !noteManager.save() else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Your latest changes couldn't be saved."
        alert.informativeText = "Keep SnippIt open to retry saving. Quitting now will lose any unsaved changes."
        alert.addButton(withTitle: "Keep Open")
        alert.addButton(withTitle: "Quit Anyway")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
