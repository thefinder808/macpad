import SwiftUI

// Single Elevated-style tab (direction 04A). The tab is a floating rounded
// chip that lifts off the darker rail: the active chip carries an indigo
// hairline + a soft accent shadow, inactive chips a subtle fill + border.
// The close button is ALWAYS visible (including on inactive tabs) so a tab
// can be closed without first activating it.
struct TabItemView: View {
    @ObservedObject var tab: TabState
    let isActive: Bool
    let theme: any AppTheme
    /// Hover reported by the AppKit drag surface, which out-hit-tests SwiftUI's
    /// own .onHover across the label area. OR'd with the local hover, which
    /// still covers the trailing close-button zone the surface leaves free.
    let surfaceHover: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onCloseWithPrompt: (() -> Void)?

    init(tab: TabState,
         isActive: Bool,
         theme: any AppTheme,
         surfaceHover: Bool = false,
         onSelect: @escaping () -> Void,
         onClose: @escaping () -> Void,
         onCloseWithPrompt: (() -> Void)? = nil) {
        self.tab = tab
        self.isActive = isActive
        self.theme = theme
        self.surfaceHover = surfaceHover
        self.onSelect = onSelect
        self.onClose = onClose
        self.onCloseWithPrompt = onCloseWithPrompt
    }

    @State private var localHover = false
    @State private var isCloseHovering = false

    private var isHovering: Bool { localHover || surfaceHover }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Dim.tabFloatingCornerRadius, style: .continuous)
        Button(action: onSelect) {
            HStack(spacing: 7) {
                Image(systemName: "doc")
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? theme.accentMuted : theme.tabFloatingInactiveText.opacity(0.85))
                Text(tab.displayName)
                    .font(.system(size: FontRole.tabLabelSize, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if tab.isDirty {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: theme.accent.opacity(0.7), radius: 3)
                }
                closeButton
            }
            .padding(.horizontal, 11)
            .frame(minWidth: Dim.tabMinWidth, maxWidth: Dim.tabMaxWidth, alignment: .leading)
            .frame(height: Dim.tabFloatingHeight)
            .foregroundStyle(isActive ? theme.tabActiveText : theme.tabFloatingInactiveText)
            .background(shape.fill(backgroundFill))
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            .shadow(color: isActive ? theme.accent.opacity(0.28) : .clear, radius: 8, x: 0, y: 2)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .padding(.vertical, (Dim.titleBarHeight - Dim.tabFloatingHeight) / 2)   // center the chip in the title band
        .onHover { hovering in
            withAnimation(.easeOut(duration: Motion.hover)) { localHover = hovering }
        }
    }

    private var backgroundFill: Color {
        if isActive { return theme.tabFloatingActiveFill }
        if isHovering { return theme.subtleHoverFill }
        return theme.tabFloatingInactiveFill
    }

    private var borderColor: Color {
        isActive ? theme.tabFloatingActiveBorder : theme.tabFloatingInactiveBorder
    }

    @ViewBuilder
    private var closeButton: some View {
        // Always visible — on the active AND inactive tabs.
        Button(action: { (onCloseWithPrompt ?? onClose)() }) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .medium))
                .frame(width: Dim.tabCloseSize, height: Dim.tabCloseSize)
                .foregroundStyle(isCloseHovering ? theme.tabActiveText : theme.tabFloatingInactiveText)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isCloseHovering ? theme.subtleHoverFill : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: Motion.hover)) { isCloseHovering = hovering }
        }
    }
}
