import SwiftUI

// Single Win11-style tab. Sits in the 40pt title band; the visible chip
// is 36pt tall with rounded top corners only — the bottom edge sits
// flush with the editor so the active tab "merges with content."
struct TabItemView: View {
    @ObservedObject var tab: TabState
    let isActive: Bool
    let theme: any AppTheme
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseWithPrompt: (() -> Void)?

    init(tab: TabState,
         isActive: Bool,
         theme: any AppTheme,
         onSelect: @escaping () -> Void,
         onClose: @escaping () -> Void,
         onCloseWithPrompt: (() -> Void)? = nil) {
        self.tab = tab
        self.isActive = isActive
        self.theme = theme
        self.onSelect = onSelect
        self.onClose = onClose
        self.onCloseWithPrompt = onCloseWithPrompt
    }

    @State private var isHovering = false
    @State private var isCloseHovering = false

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: Dim.tabCornerRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Dim.tabCornerRadius
        )
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: "doc")
                    .font(.system(size: 12))
                Text(displayTitle)
                    .font(.system(size: FontRole.tabLabelSize))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                closeButton
            }
            .padding(.horizontal, Dim.tabHorizontalPadding)
            .frame(minWidth: Dim.tabMinWidth, maxWidth: Dim.tabMaxWidth, alignment: .leading)
            .frame(height: Dim.tabHeight)
            .foregroundStyle(isActive ? theme.tabActiveText : theme.tabInactiveText)
            .background(
                shape.fill(backgroundFill)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .padding(.top, Dim.titleBarHeight - Dim.tabHeight)   // anchor to bottom of title band
        .onHover { hovering in
            withAnimation(.easeOut(duration: Motion.hover)) { isHovering = hovering }
        }
    }

    private var displayTitle: String {
        tab.isDirty ? "\(tab.displayName) •" : tab.displayName
    }

    private var backgroundFill: Color {
        if isActive { return theme.tabActiveFill }
        if isHovering { return theme.tabHoverFill }
        return Color.clear
    }

    @ViewBuilder
    private var closeButton: some View {
        // Active tab always shows close; inactive only on hover.
        let visible = isActive || isHovering
        Button(action: { (onCloseWithPrompt ?? onClose)() }) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .medium))
                .frame(width: Dim.tabCloseSize, height: Dim.tabCloseSize)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isCloseHovering ? theme.subtleHoverFill : Color.clear)
                )
                .opacity(visible ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: Motion.hover)) { isCloseHovering = hovering }
        }
    }
}
