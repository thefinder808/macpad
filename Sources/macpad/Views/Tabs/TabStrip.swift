import SwiftUI
import UniformTypeIdentifiers

// The full title band: traffic-light inset + horizontal tab list +
// new-tab button + spacer + settings gear. Lives in the 40pt zone above
// the editor panel.
//
// Elevated direction (04A): the band is drawn over the darker `chromeRail`
// (set on the parent EditorLayer), and the tabs are floating chips centered
// vertically in the band rather than bottom-anchored merged tabs.
struct TabStrip: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 0) {
            // Small leading inset so the first tab doesn't kiss the window
            // edge. Traffic lights live in the macOS titlebar zone *above*
            // this band, not inside it.
            Color.clear.frame(width: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Dim.tabFloatingSpacing) {
                    ForEach(appState.book.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == appState.book.activeTabID,
                            theme: theme,
                            onSelect: { appState.book.select(tab.id) },
                            onClose:  { appState.book.close(tab.id) },
                            onCloseWithPrompt: {
                                appState.book.closeWithPrompt(tab.id) { t in
                                    SaveCoordinator.save(t)
                                }
                            }
                        )
                        // Tab drag-reorder: drag carries the tab's UUID;
                        // drop receiver swaps source and target indices.
                        .onDrag {
                            NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            target: tab,
                            book: appState.book
                        ))
                    }
                    NewTabButton(theme: theme) {
                        appState.book.newUntitled()
                    }
                    .padding(.leading, 2)
                }
            }

            Spacer(minLength: 0)

            SettingsGearButton(theme: theme) {
                appState.isShowingSettings.toggle()
            }
            .padding(.trailing, 4)
        }
        .frame(height: Dim.titleBarHeight)
        // Background comes from EditorLayer's chromeRail; keep this clear so
        // the rail reads as one continuous surface behind tabs and panel.
        .background(Color.clear)
    }
}

private struct SettingsGearButton: View {
    let theme: any AppTheme
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .frame(width: Dim.chromeButtonSize, height: Dim.chromeButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: Dim.chromeButtonCornerRadius)
                        .fill(isHovering ? theme.subtleHoverFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.tabActiveText)
        .onHover { hovering in
            withAnimation(.easeOut(duration: Motion.hover)) { isHovering = hovering }
        }
    }
}
