import XCTest
import AppKit
@testable import macpad

// The drag surface's event contract. This is a synthetic-event test: it proves
// the mouseDown → mouseDragged → mouseUp path reports the right translations
// and honours the movement threshold. It deliberately does NOT claim the
// interaction "works" — markpad's saga was six rounds of synthetic tests
// passing while real trackpad drags broke, because physical input carries
// scroll/pressure/accessibility events that CGEvents never emit. Feel still
// has to be checked by hand; this guards the wiring underneath it.
final class TabDragSurfaceTests: XCTestCase {

    private func event(_ type: NSEvent.EventType, x: CGFloat) -> NSEvent {
        NSEvent.mouseEvent(with: type,
                           location: CGPoint(x: x, y: 20),
                           modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: 0,
                           context: nil,
                           eventNumber: 0,
                           clickCount: 1,
                           pressure: 1)!
    }

    private func makeView() -> (DragTrackingView, Recorder) {
        let view = DragTrackingView()
        let rec = Recorder()
        view.onPressed = { rec.pressed += 1 }
        view.onDragChanged = { rec.changes.append($0) }
        view.onDragEnded = { rec.ended.append($0) }
        view.onCancelled = { rec.cancelled += 1 }
        return (view, rec)
    }

    private final class Recorder {
        var pressed = 0
        var changes: [CGFloat] = []
        var ended: [CGFloat] = []
        var cancelled = 0
    }

    // Grab activates immediately, Chrome-style — not on release.
    func testMouseDownActivatesBeforeAnyMovement() {
        let (view, rec) = makeView()
        view.mouseDown(with: event(.leftMouseDown, x: 100))
        XCTAssertEqual(rec.pressed, 1)
        XCTAssertTrue(rec.changes.isEmpty)
    }

    // A plain click must not start a drag or commit a reorder.
    func testClickWithoutMovementNeverReportsADrag() {
        let (view, rec) = makeView()
        view.mouseDown(with: event(.leftMouseDown, x: 100))
        view.mouseDragged(with: event(.leftMouseDragged, x: 102))   // under the 3pt threshold
        view.mouseUp(with: event(.leftMouseUp, x: 102))
        XCTAssertTrue(rec.changes.isEmpty)
        XCTAssertTrue(rec.ended.isEmpty)
    }

    func testDragReportsTranslationFromTheGrabPoint() {
        let (view, rec) = makeView()
        view.mouseDown(with: event(.leftMouseDown, x: 100))
        view.mouseDragged(with: event(.leftMouseDragged, x: 140))
        view.mouseDragged(with: event(.leftMouseDragged, x: 60))
        view.mouseUp(with: event(.leftMouseUp, x: 60))
        XCTAssertEqual(rec.changes, [40, -40])
        XCTAssertEqual(rec.ended, [-40])
    }

    // Once past the threshold the drag stays live even if the cursor comes
    // back through the origin — otherwise it would stutter mid-gesture.
    func testDragStaysLiveAfterReturningToTheGrabPoint() {
        let (view, rec) = makeView()
        view.mouseDown(with: event(.leftMouseDown, x: 100))
        view.mouseDragged(with: event(.leftMouseDragged, x: 110))
        view.mouseDragged(with: event(.leftMouseDragged, x: 100))
        XCTAssertEqual(rec.changes, [10, 0])
    }

    // Events arriving with no prior mouseDown must be inert, not crash or
    // commit a phantom reorder.
    func testDragAndUpWithoutMouseDownAreIgnored() {
        let (view, rec) = makeView()
        view.mouseDragged(with: event(.leftMouseDragged, x: 200))
        view.mouseUp(with: event(.leftMouseUp, x: 200))
        XCTAssertTrue(rec.changes.isEmpty)
        XCTAssertTrue(rec.ended.isEmpty)
    }

    // The view is torn down mid-drag (tab closed, strip rebuilt): the session
    // must be released, never left holding an offset.
    func testCancelTrackingReleasesAnInFlightDrag() {
        let (view, rec) = makeView()
        view.mouseDown(with: event(.leftMouseDown, x: 100))
        view.mouseDragged(with: event(.leftMouseDragged, x: 150))
        view.cancelTracking()
        XCTAssertEqual(rec.cancelled, 1)
        // A later mouseUp belongs to the cancelled session and must not commit.
        view.mouseUp(with: event(.leftMouseUp, x: 150))
        XCTAssertTrue(rec.ended.isEmpty)
    }

    func testCancelTrackingIsInertWhenNoDragIsInFlight() {
        let (view, rec) = makeView()
        view.cancelTracking()
        XCTAssertEqual(rec.cancelled, 0)
    }

    // Without acceptsFirstMouse the click that activates an inactive window is
    // swallowed and the user has to grab the tab twice.
    func testAcceptsFirstMouseSoTheFirstGrabIsNotEaten() {
        XCTAssertTrue(DragTrackingView().acceptsFirstMouse(for: nil))
    }

    // A tab drag must never be reinterpreted as a window drag.
    func testSurfaceNeverMovesTheWindow() {
        XCTAssertFalse(DragTrackingView().mouseDownCanMoveWindow)
    }
}
