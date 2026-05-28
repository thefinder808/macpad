import SwiftUI

// Win11-style 24pt status bar: line/col + char/word counts on the left,
// encoding + EOL + zoom popups on the right. Each item is its own button-
// shaped hit zone with a top divider running the full width.
struct StatusBarView: View {
    @ObservedObject var tab: TabState
    let theme: any AppTheme

    var body: some View {
        HStack(spacing: 0) {
            statusItem { Text("Ln \(tab.line), Col \(tab.col)") }
            statusItem { Text("\(tab.charCount) character\(tab.charCount == 1 ? "" : "s")") }
            statusItem { Text("\(tab.wordCount) word\(tab.wordCount == 1 ? "" : "s")") }
            Spacer(minLength: 0)
            statusItem { EncodingPopup(tab: tab, theme: theme) }
            statusItem { EOLPopup(tab: tab, theme: theme) }
            statusItem { ZoomPopup(tab: tab, theme: theme) }
        }
        .font(.system(size: FontRole.statusBarSize))
        .foregroundStyle(theme.editorSecondaryText)
        .frame(height: Dim.statusBarHeight)
        .background(
            VStack(spacing: 0) {
                Rectangle().fill(theme.statusBarTopBorder).frame(height: 1)
                Rectangle().fill(theme.chromeBackgroundTint)
            }
        )
    }

    @ViewBuilder
    private func statusItem<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Dim.statusItemHorizontalPadding)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}

// SwiftUI's default Menu styling has chevrons and indicator paddings that
// don't match Win11's flat status-bar buttons. This style strips them.
struct StatusBarMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
    }
}
