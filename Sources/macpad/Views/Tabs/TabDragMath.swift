import SwiftUI

// Chrome-style direct-manipulation tab reorder. Ported from markpad, which
// arrived here after five failed attempts (see that project's CLAUDE.md):
// SwiftUI's .onDrag/.onDrop dead-ends after one position on macOS because
// the mid-drag re-render stales the drag session's target tracking, and a
// plain DragGesture can be cancelled without onEnded by physical-trackpad
// event streams. Input is owned by TabMouseDragSurface (AppKit); this file
// holds only the model of an in-flight drag and the pure math.

/// One in-flight drag. Every tab's visual offset derives from this single
/// session — nothing else stores an offset, so there is no per-tab state the
/// system can fail to reset (that's what stranded tabs half-under neighbors).
struct TabDragSession: Equatable {
    let id: UUID
    var translation: CGFloat
}

final class TabDragController: ObservableObject {
    @Published var session: TabDragSession?

    /// Rest-layout tab frames snapshotted SYNCHRONOUSLY from the AppKit
    /// surfaces at drag start (window coords). Never sourced from SwiftUI
    /// preferences: their delivery is async, so a fast re-grab after a
    /// reorder computes the whole next drag against the previous layout.
    var frames: [UUID: CGRect] = [:]

    /// Per-tab frame providers, installed by each tab's drag surface.
    var surfaces: [UUID: () -> CGRect] = [:]
}

/// Pure drag math — unit-tested. All positions are ORIGINAL (pre-drag) layout
/// midpoints from the session snapshot, never live geometry.
enum TabDragMath {
    /// Final array index for the dragged tab: the count of tabs whose
    /// midpoint its center has passed.
    static func finalIndex(draggedIndex: Int, draggedCenterX: CGFloat, midXs: [CGFloat]) -> Int {
        var target = 0
        for (i, mid) in midXs.enumerated() where i != draggedIndex {
            if mid < draggedCenterX { target += 1 }
        }
        return target
    }

    /// Visual x shift for a non-dragged tab: it parts to make room once the
    /// dragged tab's center crosses its midpoint.
    static func displacement(index: Int, draggedIndex: Int, draggedCenterX: CGFloat,
                             midXs: [CGFloat], draggedWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        guard index != draggedIndex else { return 0 }
        let mid = midXs[index]
        if index > draggedIndex && draggedCenterX > mid { return -(draggedWidth + spacing) }
        if index < draggedIndex && draggedCenterX < mid { return draggedWidth + spacing }
        return 0
    }
}
