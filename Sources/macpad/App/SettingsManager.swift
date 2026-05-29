import Foundation

// Settings persisted to UserDefaults. Keys namespaced "macpad.<name>" to
// avoid collisions when running side-by-side with other apps in dev.
// Mirror of MacPerf/TraceView SettingsManager pattern: @Published with a
// didSet that writes through. Future settings (font, wrap, restore) added
// here as they're wired up in Phase 8/11/13.
final class SettingsManager: ObservableObject {
    private static let wordWrapKey = "macpad.wordWrap"
    private static let restoreOnLaunchKey = "macpad.restoreOnLaunch"
    private static let editorFontNameKey = "macpad.editorFontName"
    private static let editorFontSizeKey = "macpad.editorFontSize"
    private static let spellCheckingKey = "macpad.spellChecking"

    @Published var wordWrap: Bool {
        didSet { UserDefaults.standard.set(wordWrap, forKey: Self.wordWrapKey) }
    }
    @Published var restoreOnLaunch: Bool {
        didSet { UserDefaults.standard.set(restoreOnLaunch, forKey: Self.restoreOnLaunchKey) }
    }
    @Published var editorFontName: String {
        didSet { UserDefaults.standard.set(editorFontName, forKey: Self.editorFontNameKey) }
    }
    @Published var editorFontSize: Double {
        didSet { UserDefaults.standard.set(editorFontSize, forKey: Self.editorFontSizeKey) }
    }
    @Published var spellChecking: Bool {
        didSet { UserDefaults.standard.set(spellChecking, forKey: Self.spellCheckingKey) }
    }

    init() {
        let d = UserDefaults.standard
        self.wordWrap = d.object(forKey: Self.wordWrapKey) as? Bool ?? true
        self.restoreOnLaunch = d.object(forKey: Self.restoreOnLaunchKey) as? Bool ?? true
        self.editorFontName = d.string(forKey: Self.editorFontNameKey) ?? ".AppleSystemUIFontMonospaced-Regular"
        self.editorFontSize = (d.object(forKey: Self.editorFontSizeKey) as? Double) ?? Double(FontRole.editorDefaultSize)
        self.spellChecking = d.object(forKey: Self.spellCheckingKey) as? Bool ?? false
    }
}
