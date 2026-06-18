import AppKit
import Combine

// Top-level shared state. v1 holds menu-tracking gate plumbing and
// (in later phases) the TabBookViewModel that owns all open tabs.
//
// `isMenuTracking` gate: when a child ObservableObject publishes while a
// macOS menu is being tracked, SwiftUI re-evaluates the @main App's body
// and the .commands block. That rebuilds the menu bar's NSMenu, which
// makes AppKit cancel tracking on any open menu — items appear for ~1s
// then disappear. Fix: install NSMenu.didBegin/EndTrackingNotification
// observers and short-circuit child publish forwarding while a menu is
// open. (Hit this before on MacPerf + TraceView.)
final class AppState: ObservableObject {
    @Published var isShowingSettings: Bool = false
    private(set) var isMenuTracking = false
    // Bridges the SwiftUI `openWindow` action out to AppKit (the menu-bar
    // popover, built outside the scene). Captured by ContentView; calling it
    // brings the main window forward / reopens it if closed.
    var presentMainWindow: (() -> Void)?
    let book: TabBookViewModel
    private var subscriptions: Set<AnyCancellable> = []

    init() {
        if let restored = SessionRestore.loadTabs() {
            self.book = TabBookViewModel(initialTabs: restored.tabs,
                                          initialActive: restored.activeID)
        } else {
            self.book = TabBookViewModel()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(menuStartedTracking),
            name: NSMenu.didBeginTrackingNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(menuEndedTracking),
            name: NSMenu.didEndTrackingNotification, object: nil
        )
        forwardPublishes(of: book)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Forward a child ObservableObject's publishes to AppState UNLESS a
    // menu is currently being tracked. Call once per child during init.
    func forwardPublishes<O: ObservableObject>(of child: O) where O.ObjectWillChangePublisher == ObservableObjectPublisher {
        child.objectWillChange
            .sink { [weak self] _ in
                guard let self, !self.isMenuTracking else { return }
                self.objectWillChange.send()
            }
            .store(in: &subscriptions)
    }

    @objc private func menuStartedTracking(_ note: Notification) {
        isMenuTracking = true
    }

    @objc private func menuEndedTracking(_ note: Notification) {
        isMenuTracking = false
    }
}
