import XCTest
import AppKit
@testable import macpad

// EOL conversion must be undoable. Like every programmatic edit it has to
// route through the bound NSTextView's shouldChangeText/didChangeText path —
// a bare NSTextStorage edit registers nothing on the tab's UndoManager (see
// CLAUDE.md; FindController got the same fix in 3072b02).
final class EOLConverterUndoTests: XCTestCase {

    // Minimal replica of EditorTextView's wiring: explicit TK1 stack, a
    // delegate routing the view's undo to tab.undoManager, boundTextView set.
    private final class UndoRoutingDelegate: NSObject, NSTextViewDelegate {
        let tab: TabState
        init(tab: TabState) { self.tab = tab }
        func undoManager(for view: NSTextView) -> UndoManager? { tab.undoManager }
    }

    private var tab: TabState!
    private var textView: NSTextView!
    private var delegate: UndoRoutingDelegate!

    override func tearDown() {
        tab?.boundTextView = nil
        tab = nil
        textView = nil
        delegate = nil
        super.tearDown()
    }

    private func makeBoundTab(text: String, lineEnding: LineEnding) {
        tab = TabState(initialText: text, lineEnding: lineEnding)
        let layoutManager = NSLayoutManager()
        tab.textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(containerSize: NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        layoutManager.addTextContainer(container)
        textView = NSTextView(frame: .zero, textContainer: container)
        textView.isRichText = false
        textView.isEditable = true
        textView.allowsUndo = true
        delegate = UndoRoutingDelegate(tab: tab)
        textView.delegate = delegate
        tab.boundTextView = textView
    }

    // NSUndoManager (groupsByEvent) closes its top-level group at the end of
    // the runloop cycle; drain one so undo/redo see a closed group, exactly
    // as they do in the app between the conversion and a later ⌘Z.
    private func drainRunLoop() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    func testUndoRestoresPreConversionTextAndLineEnding() {
        makeBoundTab(text: "alpha\nbeta\ngamma", lineEnding: .lf)

        EOLConverter.convert(tab, to: .crlf)
        XCTAssertEqual(tab.textStorage.string, "alpha\r\nbeta\r\ngamma")
        XCTAssertEqual(tab.lineEnding, .crlf)
        XCTAssertTrue(tab.isDirty)
        drainRunLoop()

        XCTAssertTrue(tab.undoManager.canUndo,
                      "conversion must register an undo action")
        tab.undoManager.undo()
        XCTAssertEqual(tab.textStorage.string, "alpha\nbeta\ngamma",
                       "one ⌘Z must restore the pre-conversion text")
        XCTAssertEqual(tab.lineEnding, .lf,
                       "⌘Z must restore the EOL state too — save normalizes to tab.lineEnding, so a stale value would silently re-convert the file")
    }

    func testRedoReappliesConversion() {
        makeBoundTab(text: "one\ntwo", lineEnding: .lf)

        EOLConverter.convert(tab, to: .crlf)
        drainRunLoop()
        tab.undoManager.undo()
        drainRunLoop()

        XCTAssertTrue(tab.undoManager.canRedo, "undone conversion must be redoable")
        tab.undoManager.redo()
        XCTAssertEqual(tab.textStorage.string, "one\r\ntwo",
                       "⇧⌘Z must re-apply the conversion")
        XCTAssertEqual(tab.lineEnding, .crlf,
                       "⇧⌘Z must re-apply the EOL state")
    }

    func testUnboundTabStillConvertsWithoutRegisteringUndo() {
        // No bound text view (tab not active in the editor): the conversion
        // must still apply, and must NOT leave an empty undo group that
        // pretends to be undoable.
        tab = TabState(initialText: "a\nb", lineEnding: .lf)

        EOLConverter.convert(tab, to: .crlf)
        XCTAssertEqual(tab.textStorage.string, "a\r\nb")
        XCTAssertEqual(tab.lineEnding, .crlf)
        drainRunLoop()

        XCTAssertFalse(tab.undoManager.canUndo,
                       "unbound fallback registers no undo — an empty group here is the original bug")
    }
}
