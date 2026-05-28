import SwiftUI

// "+" button immediately after the last tab. Matches Win11's tab strip
// layout (the button moves rightward as tabs open, not fixed at the
// right edge of the window).
struct NewTabButton: View {
    let theme: any AppTheme
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .frame(width: Dim.chromeButtonSize, height: Dim.chromeButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: Dim.chromeButtonCornerRadius)
                        .fill(isHovering ? theme.subtleHoverFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.tabActiveText)
        .padding(.top, Dim.titleBarHeight - Dim.chromeButtonSize)
        .onHover { hovering in
            withAnimation(.easeOut(duration: Motion.hover)) { isHovering = hovering }
        }
    }
}
