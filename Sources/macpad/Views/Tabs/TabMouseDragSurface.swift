import AppKit
import SwiftUI

// AppKit-owned mouse lifecycle for tab dragging (ported from markpad, where
// this replaced five failed SwiftUI-gesture attempts). SwiftUI's DragGesture
// can be cancelled without ever calling onEnded by physical-trackpad event
// streams — scroll/pressure/accessibility events that synthetic CGEvents
// never produce, which is why automated tests passed while real dragging
// stranded tabs. AppKit's mouseDown/Dragged/Up tracking has no arbitration
// layer: after mouseDown every subsequent event is delivered here until
// mouseUp, a guaranteed terminal transition. SwiftUI keeps the visuals, the
// displacement math, and the final reorder; this view reports x-translation.
struct TabMouseDragSurface: NSViewRepresentable {
    /// Called with the created NSView so the strip can query REAL AppKit
    /// geometry synchronously at drag start — SwiftUI preference delivery is
    /// async and loses the race against a fast re-grab after a reorder.
    var register: (DragTrackingView) -> Void = { _ in }
    var onPressed: () -> Void
    var onDragChanged: (CGFloat) -> Void
    var onDragEnded: (CGFloat) -> Void
    var onCancelled: () -> Void
    var onHoverChanged: (Bool) -> Void

    func makeNSView(context: Context) -> DragTrackingView {
        let view = DragTrackingView()
        configure(view)
        return view
    }

    func updateNSView(_ view: DragTrackingView, context: Context) {
        configure(view)
    }

    static func dismantleNSView(_ view: DragTrackingView, coordinator: ()) {
        view.cancelTracking()
    }

    private func configure(_ view: DragTrackingView) {
        register(view)
        view.onPressed = onPressed
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        view.onCancelled = onCancelled
        view.onHoverChanged = onHoverChanged
    }
}

final class DragTrackingView: NSView {
    var onPressed: (() -> Void)?
    var onDragChanged: ((CGFloat) -> Void)?
    var onDragEnded: ((CGFloat) -> Void)?
    var onCancelled: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    private var startX: CGFloat?
    private var dragging = false
    private let threshold: CGFloat = 3

    /// Receive the mouse-down that activates an inactive window — without this
    /// the first grab is eaten by window activation ("must click-and-hold twice").
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// This surface's frame in WINDOW coordinates — synchronous, straight from
    /// AppKit's current layout.
    var frameInWindow: CGRect {
        guard let superview else { return .zero }
        return superview.convert(frame, to: nil)
    }

    /// The strip must never turn a tab drag into a window drag.
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        startX = event.locationInWindow.x
        dragging = false
        onPressed?()   // grab = activate, Chrome-style
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startX else { return }
        let dx = event.locationInWindow.x - startX
        if !dragging && abs(dx) > threshold { dragging = true }
        if dragging { onDragChanged?(dx) }
    }

    override func mouseUp(with event: NSEvent) {
        guard let startX else { return }
        let dx = event.locationInWindow.x - startX
        self.startX = nil
        let wasDragging = dragging
        dragging = false
        if wasDragging { onDragEnded?(dx) }
        // plain click: activation already happened on mouseDown
    }

    // The surface sits above SwiftUI's hover hit-testing, so it must report
    // hover itself (tracking areas deliver enter/exit to their owner reliably).
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { onHoverChanged?(true) }

    override func mouseExited(with event: NSEvent) { onHoverChanged?(false) }

    override func cancelOperation(_ sender: Any?) { cancelTracking() }

    func cancelTracking() {
        guard startX != nil else { return }
        startX = nil
        dragging = false
        onCancelled?()
    }
}
