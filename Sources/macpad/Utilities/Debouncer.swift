import Foundation

// Trailing-edge debouncer: every call resets the timer; the action fires
// once after `delay` seconds of silence. Used for autosave so a burst of
// keystrokes results in one write, not many.
final class Debouncer {
    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    func schedule(_ action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Fire any pending work immediately, then clear the queue.
    func flush() {
        workItem?.cancel()
        workItem?.perform()
        workItem = nil
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
