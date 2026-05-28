import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        ZStack {
            MicaBackdrop(isDark: theme.isDark)
            ZStack {
                editorLayer(theme: theme)
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

    @ViewBuilder
    private func editorLayer(theme: any AppTheme) -> some View {
        VStack(spacing: 0) {
            TabStrip()
            if let tab = appState.book.activeTab, tab.findState.isVisible {
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
            if let tab = appState.book.activeTab {
                StatusBarView(tab: tab, theme: theme)
            } else {
                Color.clear.frame(height: Dim.statusBarHeight)
            }
        }
        .animation(.easeOut(duration: Motion.findBarSlide),
                   value: appState.book.activeTab?.findState.isVisible)
    }
}

