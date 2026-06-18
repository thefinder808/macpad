import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let theme = themeManager.current
        ZStack {
            MicaBackdrop(isDark: theme.isDark)
            ZStack {
                // EditorLayer takes the active tab as an @ObservedObject so
                // it re-renders on the tab's *own* publishes (e.g. the find
                // bar toggling visible). ContentView observes only appState,
                // and a nested findState change does NOT reach appState —
                // @Published var tabs fires on array mutation, not on a
                // member object's property change. Routing the find-bar
                // conditional through a view that directly observes the tab
                // is what makes ⌘F actually show the bar.
                if let tab = appState.book.activeTab {
                    EditorLayer(tab: tab, theme: theme)
                } else {
                    Color.clear
                }
                if appState.isShowingSettings {
                    SettingsRoot()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: Motion.slow), value: appState.isShowingSettings)
        }
        .frame(minWidth: Dim.windowMinWidth, minHeight: Dim.windowMinHeight)
        // We *don't* ignoresSafeArea(.top): on macOS the system titlebar
        // zone is its own region (~28pt) where AppKit draws the traffic
        // lights and a subtle separator. Trying to overlay our 40pt tab
        // band on top of it causes either a visible gradient line cutting
        // through tabs, or vertically-truncated tabs as macOS reasserts
        // its layout. Letting the titlebar live above our tab band reads
        // more like Chrome / Sublime / VS Code on macOS and is robust
        // across macOS versions.
        // Files dragged from Finder onto the window open as new tabs.
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers: providers)
        }
        // Files opened via macOS "Open With macpad" or `open -a macpad <file>`.
        .onOpenURL { url in
            do {
                try appState.book.open(url: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        // Capture the scene's openWindow action so the AppKit menu-bar popover
        // can bring this window forward / reopen it if closed.
        .onAppear {
            appState.presentMainWindow = {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            accepted = true
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    do { try appState.book.open(url: url) }
                    catch { NSAlert(error: error).runModal() }
                }
            }
        }
        return accepted
    }

}

// The tab-strip / find-bar / editor / status-bar stack for the active tab.
// Holds the active tab as @ObservedObject so it re-renders on the tab's own
// publishes — crucially, when findState.isVisible toggles (⌘F / ⌘H). See the
// note in ContentView.body for why this can't live inline in ContentView.
private struct EditorLayer: View {
    @ObservedObject var tab: TabState
    let theme: any AppTheme

    var body: some View {
        VStack(spacing: 0) {
            TabStrip()
            if tab.findState.isVisible {
                FindBar(
                    findState: tab.findState,
                    theme: theme,
                    onFindChanged: { FindController.refresh(tab) },
                    onNext:        { FindController.next(tab) },
                    onPrevious:    { FindController.previous(tab) },
                    onReplace:     { FindController.replace(tab) },
                    onReplaceAll:  { FindController.replaceAll(tab) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            EditorPane()
            StatusBarView(tab: tab, theme: theme)
        }
        .animation(.easeOut(duration: Motion.findBarSlide), value: tab.findState.isVisible)
    }
}

