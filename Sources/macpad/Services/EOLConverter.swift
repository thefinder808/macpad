import AppKit

// Rewrite every line ending in a tab's text storage to a new style.
// Wraps the edit in a single undo group so ⌘Z is one keystroke. Used by
// the status bar EOL popup; also runs implicitly on save (DocumentIO's
// `normalizeLineEndings`) so files round-trip with the selected style
// even if the user never explicitly converts.
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

        tab.undoManager.beginUndoGrouping()
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.replaceCharacters(in: fullRange, with: converted)
        storage.endEditing()
        tab.undoManager.endUndoGrouping()

        tab.lineEnding = target
        tab.isDirty = true
        tab.recomputeMetrics()
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
