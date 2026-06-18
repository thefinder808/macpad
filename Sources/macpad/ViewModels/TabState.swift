import AppKit
import Combine

// One open document. Reference type because:
//   - NSTextStorage and NSUndoManager have identity (the shared NSTextView
//     swaps these on activation; weak refs from views must remain valid).
//   - We hold strong refs to it from both the TabBookViewModel collection
//     and the active NSTextView's layout manager.
//
// Phase 4 introduces this with an initial chunk of seed content for a
// single tab. Phase 5 will populate TabBookViewModel with many.
final class TabState: Identifiable, ObservableObject {
    let id: UUID
    let textStorage: NSTextStorage
    let undoManager: UndoManager
    let autosaveID: UUID
    let findState: FindState

    @Published var displayName: String
    @Published var fileURL: URL?
    @Published var encoding: TextEncoding
    @Published var lineEnding: LineEnding
    @Published var isDirty: Bool
    @Published var line: Int = 1
    @Published var col: Int = 1
    @Published var charCount: Int = 0
    @Published var wordCount: Int = 0
    @Published var selectedRange: NSRange = NSRange(location: 0, length: 0)
    @Published var zoom: Double = 1.0      // 1.0 = 100%; legal steps: 0.5, 0.75, 1.0, 1.5, 2.0
    var scrollOffset: CGPoint = .zero      // Not @Published — written from scroll observer.
    // The live NSTextView this tab is currently bound to. The editor swaps one
    // shared text view between tabs (see EditorTextView), so only the active
    // tab has this set. Programmatic edits (find/replace, Send-to-macpad) route
    // through it via shouldChangeText/didChangeText so they register undo on
    // `undoManager` — a bare NSTextStorage edit does not. weak: the view
    // hierarchy owns the text view.
    weak var boundTextView: NSTextView?

    private var findStateCancellable: AnyCancellable?
    private let autosaveDebouncer = Debouncer(delay: 0.75)
    private let metaDebouncer = Debouncer(delay: 2.0)

    init(displayName: String = "Untitled",
         fileURL: URL? = nil,
         initialText: String = "",
         encoding: TextEncoding = .utf8,
         lineEnding: LineEnding = .lf,
         autosaveID: UUID = UUID()) {
        self.id = UUID()
        self.autosaveID = autosaveID
        self.displayName = displayName
        self.fileURL = fileURL
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.isDirty = false
        self.textStorage = NSTextStorage(string: initialText)
        self.undoManager = UndoManager()
        self.findState = FindState()
        // Forward nested findState changes through TabState so SwiftUI
        // views that observe the tab re-render when find matches update.
        self.findStateCancellable = self.findState.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
        recomputeMetrics()
    }

    /// Replace the entire buffer contents and reset dirty state (used after
    /// opening a file from disk). Wraps the storage edit in a single undo
    /// group so the user can ⌘Z back to the previous buffer if they want.
    func replaceContents(with text: String) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: fullRange, with: text)
        textStorage.endEditing()
        isDirty = false
        selectedRange = NSRange(location: 0, length: 0)
        recomputeMetrics()
    }

    /// Refresh derived properties (counts, line/col) from current storage state.
    func recomputeMetrics() {
        let ns = textStorage.string as NSString
        self.charCount = ns.length
        self.wordCount = wordCount(in: textStorage.string)
        let (l, c) = LineColTracker.lineCol(for: selectedRange.location, in: ns)
        self.line = l
        self.col = c
    }

    func updateSelection(_ range: NSRange) {
        selectedRange = range
        let (l, c) = LineColTracker.lineCol(for: range.location, in: textStorage.string as NSString)
        line = l
        col = c
        scheduleMetaAutosave()
    }

    /// Schedule a debounced full autosave (content.txt + meta.json).
    func scheduleAutosave() {
        autosaveDebouncer.schedule { [weak self] in
            guard let self else { return }
            AutosaveStore.write(tab: self)
        }
    }

    /// Schedule a debounced meta-only autosave (cursor/scroll/encoding).
    /// Cheaper than scheduleAutosave when the buffer hasn't changed.
    func scheduleMetaAutosave() {
        metaDebouncer.schedule { [weak self] in
            guard let self else { return }
            AutosaveStore.write(tab: self)
        }
    }

    /// Force any pending writes to flush (called on app quit).
    func flushAutosave() {
        autosaveDebouncer.flush()
        metaDebouncer.flush()
    }

    private func wordCount(in string: String) -> Int {
        var count = 0
        string.enumerateSubstrings(in: string.startIndex..<string.endIndex,
                                   options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
