import SwiftUI

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

    // Chrome-style drag-reorder. Input comes from an AppKit surface laid over
    // each tab (see TabMouseDragSurface); this controller holds the single
    // in-flight session plus the frame snapshot it was started with.
    @StateObject private var drag = TabDragController()
    @State private var hoveredTabID: UUID?

    /// Trailing slice of each tab left free of the drag surface so the SwiftUI
    /// close button stays clickable — an NSView overlay out-hit-tests it.
    /// Covers the 16pt close button plus the chip's 11pt trailing padding.
    private let closeZoneWidth: CGFloat = 27

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 0) {
            // Small leading inset so the first tab doesn't kiss the window
            // edge. Traffic lights live in the macOS titlebar zone *above*
            // this band, not inside it.
            Color.clear.frame(width: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Dim.tabFloatingSpacing) {
                    ForEach(Array(appState.book.tabs.enumerated()), id: \.element.id) { index, tab in
                        tabChip(tab: tab, index: index, theme: theme)
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

    @ViewBuilder
    private func tabChip(tab: TabState, index: Int, theme: any AppTheme) -> some View {
        let isDragged = drag.session?.id == tab.id
        TabItemView(
            tab: tab,
            isActive: tab.id == appState.book.activeTabID,
            theme: theme,
            surfaceHover: hoveredTabID == tab.id,
            onSelect: { appState.book.select(tab.id) },
            onClose:  { appState.book.close(tab.id) },
            onCloseWithPrompt: {
                appState.book.closeWithPrompt(tab.id) { t in
                    SaveCoordinator.save(t)
                }
            }
        )
        .overlay {
            HStack(spacing: 0) {
                TabMouseDragSurface(
                    register: { [weak drag] view in
                        drag?.surfaces[tab.id] = { [weak view] in
                            guard let view else { return .zero }
                            // The surface stops short of the close zone;
                            // reconstruct the whole chip's frame from it.
                            var frame = view.frameInWindow
                            frame.size.width += closeZoneWidth
                            return frame
                        }
                    },
                    onPressed: { appState.book.select(tab.id) },
                    onDragChanged: { dx in
                        if drag.session == nil { snapshotFrames() }
                        drag.session = TabDragSession(id: tab.id, translation: dx)
                    },
                    onDragEnded: { dx in commit(tab: tab, dx: dx) },
                    onCancelled: { drag.session = nil },
                    onHoverChanged: { hovering in
                        if hovering {
                            hoveredTabID = tab.id
                        } else if hoveredTabID == tab.id {
                            hoveredTabID = nil
                        }
                    }
                )
                Color.clear
                    .frame(width: closeZoneWidth)
                    .allowsHitTesting(false)
            }
        }
        .offset(x: offsetX(for: tab, at: index, isDragged: isDragged))
        .zIndex(isDragged ? 2 : 0)
        .shadow(color: theme.accent.opacity(isDragged ? 0.45 : 0), radius: 10, y: 2)
        // Neighbors animate their parting slide only while a drag is live; the
        // dragged tab follows the cursor unanimated, and the commit never
        // animates (an interrupted presentation transform was part of the bug).
        .animation(drag.session != nil && !isDragged ? .easeOut(duration: Motion.tabClose) : nil,
                   value: offsetX(for: tab, at: index, isDragged: isDragged))
    }

    /// Clears the session and reorders the model TOGETHER with animations off —
    /// the dragged tab already sits at its target position, so the unanimated
    /// swap is seamless and no transition can be interrupted mid-flight.
    /// (`DispatchQueue.main.async` is NOT a render boundary; doing these in
    /// two steps is what left tabs stranded in markpad.)
    private func commit(tab: TabState, dx: CGFloat) {
        guard let draggedIndex = appState.book.tabs.firstIndex(where: { $0.id == tab.id }),
              let midXs = orderedMidXs(),
              let frame = drag.frames[tab.id] else {
            drag.session = nil
            return
        }
        let target = TabDragMath.finalIndex(draggedIndex: draggedIndex,
                                            draggedCenterX: frame.midX + dx,
                                            midXs: midXs)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            drag.session = nil
            appState.book.move(tab.id, toIndex: target)
        }
    }

    /// Snapshots every tab's frame from its AppKit surface, synchronously, at
    /// the instant a drag begins. This is the ONLY geometry source for the
    /// whole session — always the true current layout, never a stale async
    /// delivery that a fast re-grab could outrun.
    private func snapshotFrames() {
        var frames: [UUID: CGRect] = [:]
        for tab in appState.book.tabs {
            if let provider = drag.surfaces[tab.id] {
                frames[tab.id] = provider()
            }
        }
        drag.frames = frames
    }

    /// Midpoints in tab order from the session snapshot; nil if incomplete.
    private func orderedMidXs() -> [CGFloat]? {
        var midXs: [CGFloat] = []
        for tab in appState.book.tabs {
            guard let frame = drag.frames[tab.id] else { return nil }
            midXs.append(frame.midX)
        }
        return midXs
    }

    private func offsetX(for tab: TabState, at index: Int, isDragged: Bool) -> CGFloat {
        guard let session = drag.session,
              let draggedFrame = drag.frames[session.id],
              let draggedIndex = appState.book.tabs.firstIndex(where: { $0.id == session.id }),
              let midXs = orderedMidXs() else { return 0 }
        let center = draggedFrame.midX + session.translation
        if isDragged {
            // Clamp so the tab can't be dragged out of the strip's contents.
            let clamped = min(max(center, midXs.first ?? 0), midXs.last ?? 0)
            return clamped - draggedFrame.midX
        }
        return TabDragMath.displacement(index: index, draggedIndex: draggedIndex,
                                        draggedCenterX: center, midXs: midXs,
                                        draggedWidth: draggedFrame.width,
                                        spacing: Dim.tabFloatingSpacing)
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
