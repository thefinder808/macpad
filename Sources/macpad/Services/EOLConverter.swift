import AppKit

// Rewrite every line ending in a tab's text storage to a new style.
// The rewrite routes through the tab's bound NSTextView so one ⌘Z undoes
// it — text and lineEnding together. Used by the status bar EOL popup;
// also runs implicitly on save (DocumentIO's `normalizeLineEndings`) so
// files round-trip with the selected style even if the user never
// explicitly converts.
enum EOLConverter {

    static func convert(_ tab: TabState, to target: LineEnding) {
        guard tab.lineEnding != target else { return }
        let storage = tab.textStorage
        let original = storage.string
        let converted = normalize(original, to: target)
        guard converted != original else {
            tab.lineEnding = target
            return
        }

        let previous = tab.lineEnding
        let fullRange = NSRange(location: 0, length: storage.length)
        // Route through the live text view so the rewrite registers undo on
        // the tab's UndoManager — a bare NSTextStorage edit does not, and
        // wrapping one in begin/endUndoGrouping just makes an empty group
        // (the same bug FindController had; see CLAUDE.md).
        if let tv = tab.boundTextView,
           tv.shouldChangeText(in: fullRange, replacementString: converted) {
            storage.replaceCharacters(in: fullRange, with: converted)
            tv.didChangeText()
            // Same undo group (one ⌘Z): roll lineEnding back with the text,
            // or save — which normalizes to tab.lineEnding — would silently
            // re-convert the undone buffer.
            registerLineEndingUndo(tab, from: previous, to: target)
        } else {
            // Fallback (tab not bound to a text view): edit directly, no undo.
            storage.beginEditing()
            storage.replaceCharacters(in: fullRange, with: converted)
            storage.endEditing()
        }

        tab.lineEnding = target
        tab.isDirty = true
        tab.recomputeMetrics()
    }

    // Mutually re-registers on each invocation so undo ⇄ redo cycles.
    private static func registerLineEndingUndo(_ tab: TabState,
                                               from old: LineEnding,
                                               to new: LineEnding) {
        tab.undoManager.registerUndo(withTarget: tab) { t in
            registerLineEndingUndo(t, from: new, to: old)
            t.lineEnding = old
        }
    }

    private static func normalize(_ text: String, to target: LineEnding) -> String {
        // Two-pass: collapse mixed endings to LF, then expand to target.
        var s = text.replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "\r", with: "\n")
        switch target {
        case .lf:   return s
        case .crlf: return s.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:   return s.replacingOccurrences(of: "\n", with: "\r")
        }
    }
}
