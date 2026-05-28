import Foundation

// Compute 1-based (line, column) for a UTF-16 offset into an NSString.
// `NSString.getLineStart:end:contentsEnd:forRange:` walks linewise without
// allocating substrings — fast enough for files <10 MB.
//
// For very large files (Phase 11+) we may want to cache a sorted array
// of line-start indices and invalidate on edit. Defer until profiling
// proves it's needed.
enum LineColTracker {
    static func lineCol(for utf16Offset: Int, in nsString: NSString) -> (line: Int, col: Int) {
        let clampedOffset = max(0, min(utf16Offset, nsString.length))
        var line = 1
        var lineStart = 0
        var idx = 0

        while idx < clampedOffset {
            var start = 0
            var end = 0
            var contentsEnd = 0
            nsString.getLineStart(&start,
                                  end: &end,
                                  contentsEnd: &contentsEnd,
                                  for: NSRange(location: idx, length: 0))
            if end <= idx { break }
            // Only advance the line counter if this line is actually
            // terminated by a newline character (end > contentsEnd). At
            // EOF with no trailing newline, end == contentsEnd and the
            // cursor stays on the current line.
            if end <= clampedOffset && end > contentsEnd {
                line += 1
                lineStart = end
                idx = end
            } else {
                break
            }
        }
        let col = clampedOffset - lineStart + 1
        return (line, col)
    }
}
