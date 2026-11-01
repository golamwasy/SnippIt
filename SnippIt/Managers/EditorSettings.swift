import Foundation
import Combine

@MainActor
final class EditorSettings: ObservableObject {
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: "editorFontSize") }
    }
    @Published var showsLineNumbers: Bool {
        didSet { defaults.set(showsLineNumbers, forKey: "showsLineNumbers") }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedSize = defaults.object(forKey: "editorFontSize") as? Double ?? 14
        fontSize = min(28, max(11, savedSize))
        showsLineNumbers = defaults.object(forKey: "showsLineNumbers") as? Bool ?? true
    }
}
