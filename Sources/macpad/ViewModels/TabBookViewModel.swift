import AppKit
import Combine

// Where "Send to macpad" (the macOS Services menu) should drop incoming text.
enum ExternalTextDestination {
    case newTab
    case currentTab
}

// The collection of open tabs and which one is active. Phase 4 ships
// with a single seed tab; Phase 5 wires the tab strip and add/close/
// reorder operations.
final class TabBookViewModel: ObservableObject {
    @Published var tabs: [TabState] {
        didSet { persistManifest() }
    }
    @Published var activeTabID: UUID? {
        didSet { persistManifest() }
    }

    private let manifestDebouncer = Debouncer(delay: 0.5)

    init(initialTabs: [TabState]? = nil, initialActive: UUID? = nil) {
        if let initialTabs, !initialTabs.isEmpty {
            self.tabs = initialTabs
            self.activeTabID = initialActive ?? initialTabs.first?.id
        } else {
            let first = TabState(displayName: "Untitled", initialText: "")
            self.tabs = [first]
            self.activeTabID = first.id
        }
    }

    private func persistManifest() {
        manifestDebouncer.schedule { [weak self] in
            guard let self else { return }
            AutosaveStore.writeManifest(tabs: self.tabs, activeID: self.activeTabID)
        }
    }

    func flushAutosave() {
        manifestDebouncer.flush()
        AutosaveStore.writeManifest(tabs: tabs, activeID: activeTabID)
        for tab in tabs {
            tab.flushAutosave()
            AutosaveStore.write(tab: tab)
        }
    }

    var activeTab: TabState? {
        guard let id = activeTabID else { return nil }
        return tabs.first(where: { $0.id == id })
    }

    @discardableResult
    func newUntitled() -> TabState {
        // Win11 Notepad labels every untitled tab just "Untitled" — no
        // suffix or counter even when several are open simultaneously.
        let tab = TabState(displayName: "Untitled")
        tabs.append(tab)
        activeTabID = tab.id
        return tab
    }

    /// Close a tab unconditionally. Callers handling dirty state should
    /// prompt the user first (see `closeWithPrompt`).
    func close(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = (activeTabID == id)
        let removed = tabs.remove(at: idx)
        AutosaveStore.removeTabDir(autosaveID: removed.autosaveID)
        if tabs.isEmpty {
            newUntitled()
        } else if wasActive {
            let nextIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[nextIdx].id
        }
    }

    /// Close a tab, prompting if it has unsaved changes.
    /// Returns true if the tab was closed, false if the user canceled.
    @discardableResult
    func closeWithPrompt(_ id: UUID,
                         saveHandler: (TabState) -> Bool) -> Bool {
        guard let tab = tabs.first(where: { $0.id == id }) else { return false }
        if tab.isDirty {
            switch DirtyClosePrompt.run(tabName: tab.displayName) {
            case .save:
                guard saveHandler(tab) else { return false }
                close(id)
                return true
            case .discard:
                close(id)
                return true
            case .cancel:
                return false
            }
        } else {
            close(id)
            return true
        }
    }

    /// Open a file at `url` into a new tab (or focus an already-open tab
    /// pointing at the same URL). Throws on read failure so the caller
    /// can surface an error dialog.
    @discardableResult
    func open(url: URL) throws -> TabState {
        if let existing = tabs.first(where: { $0.fileURL == url }) {
            activeTabID = existing.id
            return existing
        }
        let result = try DocumentIO.read(from: url)
        let tab = TabState(
            displayName: url.lastPathComponent,
            fileURL: url,
            initialText: result.text,
            encoding: result.encoding,
            lineEnding: result.lineEnding
        )
        tabs.append(tab)
        activeTabID = tab.id
        // Write content.txt + meta.json now. Opening a file doesn't go
        // through the text-edit autosave path (the initial string is set
        // before the NSTextStorage delegate is attached), so without this
        // the tab would have no session record until first edit.
        AutosaveStore.write(tab: tab)
        return tab
    }

    func select(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    /// Insert text received from another app (via the macOS Services menu)
    /// into a new tab or the current tab, appended as a trailing line. Called
    /// off the Services provider; does not activate the app, so the source
    /// app keeps focus. Mirrors `open(url:)`'s immediate-autosave so the
    /// addition survives even when macpad is in the background.
    func receiveExternalText(_ text: String, into destination: ExternalTextDestination) {
        switch destination {
        case .newTab:
            let tab = TabState(displayName: "Untitled", initialText: text)
            tabs.append(tab)
            activeTabID = tab.id
            tab.isDirty = true
            AutosaveStore.write(tab: tab)
        case .currentTab:
            let tab = activeTab ?? newUntitled()
            let storage = tab.textStorage
            let existing = storage.string as NSString
            let needsNewline = existing.length > 0 && !existing.hasSuffix("\n")
            let insert = (needsNewline ? "\n" : "") + text
            let end = NSRange(location: storage.length, length: 0)
            // Route through the live text view (when the tab is bound) so the
            // insert registers undo on the tab's UndoManager and ⌘Z removes it;
            // fall back to a direct edit for an unmounted tab. Either way the
            // storage delegate re-lays-out + marks dirty.
            if let tv = tab.boundTextView, tv.shouldChangeText(in: end, replacementString: insert) {
                storage.replaceCharacters(in: end, with: insert)
                tv.didChangeText()
            } else {
                storage.beginEditing()
                storage.replaceCharacters(in: end, with: insert)
                storage.endEditing()
            }
            tab.isDirty = true
            tab.recomputeMetrics()
            AutosaveStore.write(tab: tab)
        }
    }

    func reorder(from source: Int, to destination: Int) {
        guard source != destination,
              tabs.indices.contains(source),
              destination >= 0, destination <= tabs.count else { return }
        let item = tabs.remove(at: source)
        let dest = destination > source ? destination - 1 : destination
        tabs.insert(item, at: dest)
    }
}
