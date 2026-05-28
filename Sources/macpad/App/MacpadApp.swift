import SwiftUI
import AppKit

@main
struct MacpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppDelegate.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var settingsManager = SettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .background(WindowAccessor())
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { appState.book.newUntitled() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("Open…") { openFile() }
                    .keyboardShortcut("o", modifiers: .command)

                Divider()

                Button("Save") {
                    if let tab = appState.book.activeTab { SaveCoordinator.save(tab) }
                }
                .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") {
                    if let tab = appState.book.activeTab { SaveCoordinator.saveAs(tab) }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Close Tab") { closeActiveTab() }
                    .keyboardShortcut("w", modifiers: .command)
            }

            // Edit menu additions — find / find next / find prev / replace
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") { showFindBar(replace: false) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") {
                    if let tab = appState.book.activeTab { FindController.next(tab) }
                }
                .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") {
                    if let tab = appState.book.activeTab { FindController.previous(tab) }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Replace…") { showFindBar(replace: true) }
                    .keyboardShortcut("h", modifiers: .command)
            }

            // View menu — word wrap, zoom, tab navigation
            CommandGroup(after: .toolbar) {
                Button(settingsManager.wordWrap ? "Word Wrap ✓" : "Word Wrap") {
                    settingsManager.wordWrap.toggle()
                }
                .keyboardShortcut("w", modifiers: [.command, .option])

                Divider()

                Button("Zoom In") {
                    if let tab = appState.book.activeTab { ZoomCommands.zoomIn(tab) }
                }
                .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") {
                    if let tab = appState.book.activeTab { ZoomCommands.zoomOut(tab) }
                }
                .keyboardShortcut("-", modifiers: .command)
                Button("Reset Zoom") {
                    if let tab = appState.book.activeTab { tab.zoom = 1.0 }
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("Next Tab") { selectRelative(+1) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous Tab") { selectRelative(-1) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
            }

            // Theme submenu under the app menu
            CommandGroup(after: .appSettings) {
                Menu("Theme") {
                    ForEach(ThemeOption.allCases) { opt in
                        Button(opt.displayName) { themeManager.selectedOption = opt }
                    }
                }
            }
        }
    }

    private func showFindBar(replace: Bool) {
        guard let tab = appState.book.activeTab else { return }
        tab.findState.isVisible = true
        tab.findState.isReplaceMode = replace
        FindController.refresh(tab)
    }

    private func openFile() {
        guard let url = DocumentIO.runOpenPanel() else { return }
        do {
            try appState.book.open(url: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func closeActiveTab() {
        guard let id = appState.book.activeTabID else { return }
        appState.book.closeWithPrompt(id) { tab in SaveCoordinator.save(tab) }
    }

    private func selectRelative(_ delta: Int) {
        let book = appState.book
        guard !book.tabs.isEmpty,
              let id = book.activeTabID,
              let idx = book.tabs.firstIndex(where: { $0.id == id }) else { return }
        let next = (idx + delta + book.tabs.count) % book.tabs.count
        book.select(book.tabs[next].id)
    }
}
