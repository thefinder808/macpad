import SwiftUI
import AppKit

// Hosts the EditorTextView for the active tab. When the active tab
// changes (Phase 5+), SwiftUI re-evaluates this view and EditorTextView's
// updateNSView swaps the underlying textStorage/undoManager.
struct EditorPane: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        let theme = themeManager.current
        Group {
            if let tab = appState.book.activeTab {
                ZoomingEditor(
                    tab: tab,
                    theme: theme,
                    wordWrap: settingsManager.wordWrap,
                    fontName: settingsManager.editorFontName,
                    baseFontSize: CGFloat(settingsManager.editorFontSize),
                    spellChecking: settingsManager.spellChecking
                )
            } else {
                Color.clear
            }
        }
        .background(theme.editorBackground)
    }
}

// Forwards `tab.zoom` + user font preferences into EditorTextView's font
// so SwiftUI re-renders the wrapper when any of them change.
private struct ZoomingEditor: View {
    @ObservedObject var tab: TabState
    let theme: any AppTheme
    let wordWrap: Bool
    let fontName: String
    let baseFontSize: CGFloat
    let spellChecking: Bool

    var body: some View {
        EditorTextView(
            tab: tab,
            theme: theme,
            font: resolveFont(),
            wordWrap: wordWrap,
            spellChecking: spellChecking
        )
    }

    private func resolveFont() -> NSFont {
        let size = baseFontSize * tab.zoom
        if fontName == ".AppleSystemUIFontMonospaced-Regular" {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        return NSFont(name: fontName, size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
