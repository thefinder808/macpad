import AppKit

// NSTextView subclass that adds a Word-style left "selection bar": clicking
// in the left margin (the text container's left inset strip, to the left of
// where glyphs begin) selects the whole logical line; dragging up/down
// extends the selection by whole lines. Every other click defers to
// NSTextView's normal behavior, so caret placement and text selection are
// unchanged.
//
// We use the LEFT margin (not the right) deliberately: it's the classic,
// conflict-free selection bar — the inset strip is empty space no text
// click would otherwise land in, so it never competes with placing the
// caret at the end of a line.
final class LineSelectTextView: NSTextView {
    // Toggled from Settings ("Select line from margin"); when false this
    // subclass behaves exactly like a stock NSTextView.
    var selectLineFromMargin: Bool = true

    // The line range where a margin drag began. While set, mouseDragged
    // extends the selection to the union of this anchor and the line under
    // the cursor, and mouseUp ends the gesture.
    private var marginDragAnchor: NSRange?

    // The selection bar is the left text inset — empty space before glyphs.
    private var selectionBarWidth: CGFloat { textContainerInset.width }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard selectLineFromMargin, isInSelectionBar(event),
              let lineRange = lineRange(at: event) else {
            marginDragAnchor = nil
            super.mouseDown(with: event)
            return
        }
        // Take first-responder so the selection draws with the active
        // (not inactive-gray) highlight and keyboard actions work. Normally
        // super.mouseDown does this, but we're bypassing it for bar clicks.
        window?.makeFirstResponder(self)
        marginDragAnchor = lineRange
        setSelectedRange(lineRange)
        // Intentionally NOT calling super: that would start NSTextView's own
        // character-drag session and move the caret. We own the drag below.
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor = marginDragAnchor else {
            super.mouseDragged(with: event)
            return
        }
        if let current = lineRange(at: event) {
            setSelectedRange(NSUnionRange(anchor, current))
        }
        autoscroll(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if marginDragAnchor != nil {
            marginDragAnchor = nil
            return
        }
        super.mouseUp(with: event)
    }

    // MARK: - Cursor affordance (best-effort)

    override func cursorUpdate(with event: NSEvent) {
        if selectLineFromMargin, isInSelectionBar(event) {
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    // MARK: - Geometry

    private func isInSelectionBar(_ event: NSEvent) -> Bool {
        let p = convert(event.locationInWindow, from: nil)
        return p.x < selectionBarWidth
    }

    // The full logical-line (paragraph) character range for the line under
    // the event's vertical position. NSString.lineRange spans to the next
    // newline, so in word-wrap mode this correctly grabs every wrapped
    // fragment of the line, not just the visual row clicked.
    private func lineRange(at event: NSEvent) -> NSRange? {
        guard let lm = layoutManager, let tc = textContainer else { return nil }
        let ns = string as NSString
        guard ns.length > 0 else { return NSRange(location: 0, length: 0) }

        let viewPoint = convert(event.locationInWindow, from: nil)
        let origin = textContainerOrigin
        // Probe just inside the text area (past the line-fragment padding) at
        // the click's y, so we resolve the correct line regardless of how far
        // left in the bar the click landed.
        let containerPoint = NSPoint(x: tc.lineFragmentPadding + 1,
                                     y: viewPoint.y - origin.y)
        let glyphIndex = lm.glyphIndex(for: containerPoint, in: tc)
        let charIndex = min(lm.characterIndexForGlyph(at: glyphIndex), ns.length - 1)
        return ns.lineRange(for: NSRange(location: charIndex, length: 0))
    }
}
