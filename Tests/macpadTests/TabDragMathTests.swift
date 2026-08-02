import XCTest
import CoreGraphics
@testable import macpad

// Chrome-style direct-manipulation drag math (ported with the architecture
// from markpad). Tabs sit at original midX positions [50, 150, 250] — 100pt
// wide with 4pt spacing, so a parting neighbor slides by 104.
final class TabDragMathTests: XCTestCase {

    let midXs: [CGFloat] = [50, 150, 250]

    // MARK: final index

    func testFinalIndexUnmoved() {
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 0, draggedCenterX: 50, midXs: midXs), 0)
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 2, draggedCenterX: 250, midXs: midXs), 2)
    }

    func testFinalIndexDragRightPastOne() {
        // tab 0 dragged to x=160: passed tab 1's mid (150), not tab 2's (250)
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 0, draggedCenterX: 160, midXs: midXs), 1)
    }

    func testFinalIndexDragRightPastAll() {
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 0, draggedCenterX: 300, midXs: midXs), 2)
    }

    func testFinalIndexDragLeftPastAll() {
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 2, draggedCenterX: 40, midXs: midXs), 0)
    }

    func testFinalIndexMiddleTabStaysPutWithinItsSlot() {
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 1, draggedCenterX: 149, midXs: midXs), 1)
        XCTAssertEqual(TabDragMath.finalIndex(draggedIndex: 1, draggedCenterX: 151, midXs: midXs), 1)
    }

    // MARK: neighbor displacement

    func testNeighborsAtRestDoNotShift() {
        XCTAssertEqual(TabDragMath.displacement(index: 1, draggedIndex: 0, draggedCenterX: 50,
                                                midXs: midXs, draggedWidth: 100, spacing: 4), 0)
        XCTAssertEqual(TabDragMath.displacement(index: 2, draggedIndex: 0, draggedCenterX: 160,
                                                midXs: midXs, draggedWidth: 100, spacing: 4), 0)
    }

    func testRightNeighborSlidesLeftWhenPassed() {
        // dragging tab 0 right past tab 1's midpoint: tab 1 slides left by width+spacing
        XCTAssertEqual(TabDragMath.displacement(index: 1, draggedIndex: 0, draggedCenterX: 160,
                                                midXs: midXs, draggedWidth: 100, spacing: 4), -104)
    }

    func testLeftNeighborSlidesRightWhenPassed() {
        // dragging tab 2 left past tab 0's midpoint: both tabs to its left slide right
        XCTAssertEqual(TabDragMath.displacement(index: 0, draggedIndex: 2, draggedCenterX: 40,
                                                midXs: midXs, draggedWidth: 100, spacing: 4), 104)
        XCTAssertEqual(TabDragMath.displacement(index: 1, draggedIndex: 2, draggedCenterX: 40,
                                                midXs: midXs, draggedWidth: 100, spacing: 4), 104)
    }

    func testDraggedTabHasNoComputedDisplacement() {
        XCTAssertEqual(TabDragMath.displacement(index: 1, draggedIndex: 1, draggedCenterX: 999,
                                                midXs: midXs, draggedWidth: 100, spacing: 4), 0)
    }

    // MARK: model move

    @MainActor
    func testMoveReordersWithoutChangingTheActiveTab() {
        let book = TabBookViewModel(initialTabs: [
            TabState(displayName: "A"), TabState(displayName: "B"), TabState(displayName: "C"),
        ])
        let a = book.tabs[0].id
        book.select(book.tabs[1].id)          // B is active
        book.move(a, toIndex: 2)
        XCTAssertEqual(book.tabs.map(\.displayName), ["B", "C", "A"])
        XCTAssertEqual(book.activeTabID, book.tabs.first(where: { $0.displayName == "B" })?.id)
    }

    @MainActor
    func testMoveClampsOutOfRangeIndices() {
        let book = TabBookViewModel(initialTabs: [
            TabState(displayName: "A"), TabState(displayName: "B"), TabState(displayName: "C"),
        ])
        let c = book.tabs[2].id
        book.move(c, toIndex: -5)
        XCTAssertEqual(book.tabs.map(\.displayName), ["C", "A", "B"])
        book.move(c, toIndex: 99)
        XCTAssertEqual(book.tabs.map(\.displayName), ["A", "B", "C"])
    }
}
