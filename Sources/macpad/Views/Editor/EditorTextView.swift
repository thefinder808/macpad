import SwiftUI
import AppKit

// SwiftUI wrapper around an NSTextView (TextKit 1) hosted in an
// NSScrollView, bound to a TabState. The TabState's NSTextStorage IS the
// source of truth — there is no `Binding<String>` to keep in sync.
// Re-encoding the full string on every keystroke is what makes SwiftUI's
// built-in `TextEditor` jank, and is what we're explicitly avoiding.
//
// On tab activation (Phase 5+) `updateNSView` will swap the layout
// manager's textStorage and the textView's undoManager to point at the
// newly-active tab. For Phase 4 there's only one tab and the swap is a
// no-op on subsequent updates.
//
// Why TextKit 1: macOS 14.x TextKit 2 has open regressions on temporary
// attribute drawing (used for find highlighting in Phase 9) and IME
// composition. TextKit 1 is mature.
struct EditorTextView: NSViewRepresentable {
    @ObservedObject var tab: TabState
    let theme: any AppTheme
    let font: NSFont
    let wordWrap: Bool
    let spellChecking: Bool

    func makeCoordinator() -> Coordinator { Coordinator(tab: tab) }

    func makeNSView(context: Context) -> NSScrollView {
        let layoutManager = NSLayoutManager()
        tab.textStorage.addLayoutManager(layoutManager)
        tab.textStorage.delegate = context.coordinator

        let container = NSTextContainer(containerSize: NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        ))
        container.widthTracksTextView = wordWrap
        container.heightTracksTextView = false
        layoutManager.addTextContainer(container)

        let textView = NSTextView(frame: .zero, textContainer: container)
        configure(textView)
        applyTheme(to: textView)
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wordWrap
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrap
        textView.autoresizingMask = wordWrap ? [.width] : []

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Re-bind if the active TabState identity changed (Phase 5 hot-swap).
        if context.coordinator.tab !== tab {
            context.coordinator.tab.scrollOffset = scrollView.contentView.bounds.origin
            tab.textStorage.delegate = context.coordinator
            if let lm = textView.layoutManager {
                // Detach from outgoing, attach to incoming.
                context.coordinator.tab.textStorage.removeLayoutManager(lm)
                tab.textStorage.addLayoutManager(lm)
            }
            context.coordinator.tab = tab
            // Restore caret + scroll on incoming tab.
            textView.setSelectedRange(tab.selectedRange)
            DispatchQueue.main.async {
                scrollView.contentView.scroll(to: tab.scrollOffset)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        }

        applyTheme(to: textView)
        textView.font = font
        textView.isContinuousSpellCheckingEnabled = spellChecking
        applyFindHighlights(textView: textView, coordinator: context.coordinator)

        if let container = textView.textContainer {
            container.widthTracksTextView = wordWrap
            textView.isHorizontallyResizable = !wordWrap
            textView.autoresizingMask = wordWrap ? [.width] : []
            scrollView.hasHorizontalScroller = !wordWrap
            if wordWrap {
                container.containerSize = NSSize(
                    width: scrollView.contentSize.width,
                    height: CGFloat.greatestFiniteMagnitude
                )
            } else {
                container.containerSize = NSSize(
                    width: CGFloat.greatestFiniteMagnitude,
                    height: CGFloat.greatestFiniteMagnitude
                )
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var tab: TabState
        weak var textView: NSTextView?
        // The match range we last moved the caret to. Guards against a
        // re-entrant loop: applyFindHighlights runs on every updateNSView,
        // and moving the caret fires textViewDidChangeSelection, which
        // mutates @Published state, which forces another updateNSView. We
        // only navigate when the *target match* actually changes.
        var lastNavigatedRange: NSRange?

        init(tab: TabState) { self.tab = tab }

        // Route NSTextView's undo through the tab's UndoManager so each
        // tab keeps its own history.
        func undoManager(for view: NSTextView) -> UndoManager? {
            tab.undoManager
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            tab.updateSelection(tv.selectedRange())
        }

        func textStorage(_ textStorage: NSTextStorage,
                         didProcessEditing editedMask: NSTextStorageEditActions,
                         range editedRange: NSRange,
                         changeInLength delta: Int) {
            // Only react to character edits — pure attribute changes (e.g.,
            // find-highlight temp attrs in Phase 9) shouldn't mark dirty.
            guard editedMask.contains(.editedCharacters) else { return }
            if !tab.isDirty { tab.isDirty = true }
            tab.recomputeMetrics()
            tab.scheduleAutosave()
        }
    }

    // MARK: - Configuration

    private func configure(_ textView: NSTextView) {
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.smartInsertDeleteEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = spellChecking
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = false              // we render our own (Phase 9)
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isRulerVisible = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsCharacterPickerTouchBarItem = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
    }

    // MARK: - Find highlighting

    private func applyFindHighlights(textView: NSTextView, coordinator: Coordinator) {
        guard let lm = textView.layoutManager else { return }
        let storageLength = tab.textStorage.length
        let fullRange = NSRange(location: 0, length: storageLength)

        // Clear stale highlights from the previous render. This is a
        // temporary-attribute change only — it does NOT mutate the text
        // storage or fire selection/edit delegates, so it's safe to run
        // on every render.
        lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        let fs = tab.findState
        guard fs.isVisible, !fs.matches.isEmpty else {
            // Find closed (or no matches) — reset navigation memory so the
            // next search starts fresh.
            coordinator.lastNavigatedRange = nil
            return
        }

        let normal = NSColor(theme.findHighlight)
        let active = NSColor(theme.findHighlightActive)
        for (idx, range) in fs.matches.enumerated() {
            guard NSMaxRange(range) <= storageLength else { continue }
            let color = (idx == fs.currentMatchIndex) ? active : normal
            lm.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }

        // Move the caret to / scroll to the current match ONLY when that
        // match changed since we last navigated. Doing this unconditionally
        // on every render creates an infinite loop:
        //   setSelectedRange → textViewDidChangeSelection → @Published edit
        //   → re-render → updateNSView → applyFindHighlights → setSelectedRange …
        // Gating on the match range breaks the cycle: after the first move,
        // the re-render sees the same target and skips it.
        guard let idx = fs.currentMatchIndex, fs.matches.indices.contains(idx) else {
            coordinator.lastNavigatedRange = nil
            return
        }
        let r = fs.matches[idx]
        guard NSMaxRange(r) <= storageLength else { return }
        if coordinator.lastNavigatedRange != r {
            coordinator.lastNavigatedRange = r
            textView.scrollRangeToVisible(r)
            textView.setSelectedRange(NSRange(location: NSMaxRange(r), length: 0))
        }
    }

    private func applyTheme(to textView: NSTextView) {
        textView.drawsBackground = true
        textView.backgroundColor = NSColor(theme.editorBackground)
        textView.textColor = NSColor(theme.editorText)
        textView.insertionPointColor = NSColor(theme.editorText)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(theme.editorSelectionBackground)
        ]
        textView.font = font
    }
}
