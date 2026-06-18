import AppKit

// Stateless helpers operating on a TabState's findState + textStorage.
// Keeps the controller logic out of the view layer so commands (⌘F, ⌘G,
// ⌘H) and the find bar share one implementation.
enum FindController {

    /// Recompute matches from the current query + options.
    static func refresh(_ tab: TabState) {
        let fs = tab.findState
        guard fs.isVisible, !fs.query.isEmpty else {
            fs.matches = []
            fs.currentMatchIndex = nil
            return
        }
        let opts = FindEngine.Options(
            matchCase: fs.matchCase,
            wholeWord: fs.wholeWord,
            useRegex: fs.useRegex
        )
        do {
            let m = try FindEngine.matches(in: tab.textStorage.string,
                                            query: fs.query,
                                            options: opts)
            fs.matches = m
            fs.currentMatchIndex = m.isEmpty ? nil : 0
        } catch {
            fs.matches = []
            fs.currentMatchIndex = nil
        }
    }

    /// Move to the next match (wrap around) and emit a selection request.
    static func next(_ tab: TabState) {
        let fs = tab.findState
        guard !fs.matches.isEmpty else { return }
        let current = fs.currentMatchIndex ?? -1
        fs.currentMatchIndex = (current + 1) % fs.matches.count
    }

    static func previous(_ tab: TabState) {
        let fs = tab.findState
        guard !fs.matches.isEmpty else { return }
        let current = fs.currentMatchIndex ?? 0
        let prev = current - 1
        fs.currentMatchIndex = prev < 0 ? fs.matches.count - 1 : prev
    }

    /// Replace the current match, then refresh.
    static func replace(_ tab: TabState) {
        let fs = tab.findState
        guard let idx = fs.currentMatchIndex,
              fs.matches.indices.contains(idx) else { return }
        let range = fs.matches[idx]
        applyReplacement(in: tab, range: range, with: fs.replacement)
        refresh(tab)
        // Keep currentMatchIndex pointing somewhere sensible.
        if let new = fs.matches.indices.first(where: { $0 >= idx }) {
            fs.currentMatchIndex = new
        } else {
            fs.currentMatchIndex = fs.matches.isEmpty ? nil : fs.matches.count - 1
        }
    }

    /// Replace all matches as a single undoable change. Walk in reverse so
    /// earlier ranges aren't invalidated by later replacements.
    static func replaceAll(_ tab: TabState) {
        let fs = tab.findState
        guard !fs.matches.isEmpty else { return }
        let storage = tab.textStorage
        let ranges = fs.matches
        let replacement = fs.replacement

        // Route through the live text view so the change registers undo on the
        // tab's UndoManager (a bare NSTextStorage edit does not). shouldChange
        // /didChangeText also coalesces all the replacements into one ⌘Z step.
        if let tv = tab.boundTextView,
           tv.shouldChangeText(inRanges: ranges.map { NSValue(range: $0) },
                               replacementStrings: Array(repeating: replacement, count: ranges.count)) {
            storage.beginEditing()
            for range in ranges.reversed() {
                storage.replaceCharacters(in: range, with: replacement)
            }
            storage.endEditing()
            tv.didChangeText()
        } else {
            // Fallback (tab not bound to a text view — shouldn't happen for the
            // active tab the find bar operates on): edit directly, no undo.
            storage.beginEditing()
            for range in ranges.reversed() {
                storage.replaceCharacters(in: range, with: replacement)
            }
            storage.endEditing()
        }

        // Force a metric refresh — the storage delegate fires per-edit but
        // we want a clean final reading.
        tab.recomputeMetrics()
        refresh(tab)
    }

    private static func applyReplacement(in tab: TabState,
                                          range: NSRange,
                                          with replacement: String) {
        let storage = tab.textStorage
        // See replaceAll: route through the text view so ⌘Z can undo the edit.
        if let tv = tab.boundTextView, tv.shouldChangeText(in: range, replacementString: replacement) {
            storage.replaceCharacters(in: range, with: replacement)
            tv.didChangeText()
        } else {
            storage.beginEditing()
            storage.replaceCharacters(in: range, with: replacement)
            storage.endEditing()
        }
    }
}
