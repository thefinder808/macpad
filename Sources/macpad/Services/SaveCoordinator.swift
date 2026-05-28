import AppKit

// Thin wrapper around DocumentIO that handles the "where do I save?"
// question — if the tab already has a fileURL we save in place;
// otherwise we present a Save panel. Used by ⌘S, ⇧⌘S, and the
// dirty-close prompt.
enum SaveCoordinator {

    /// Save `tab` to its existing fileURL. Returns true on success.
    @discardableResult
    static func save(_ tab: TabState) -> Bool {
        if let url = tab.fileURL {
            return write(tab, to: url)
        } else {
            return saveAs(tab)
        }
    }

    /// Prompt for a new filename and save. Returns true on success.
    @discardableResult
    static func saveAs(_ tab: TabState) -> Bool {
        let defaultName = tab.displayName.replacingOccurrences(of: ".txt", with: "")
        guard let url = DocumentIO.runSavePanel(suggesting: tab.fileURL,
                                                defaultName: defaultName) else {
            return false
        }
        return write(tab, to: url)
    }

    private static func write(_ tab: TabState, to url: URL) -> Bool {
        do {
            try DocumentIO.write(
                text: tab.textStorage.string,
                encoding: tab.encoding,
                lineEnding: tab.lineEnding,
                to: url
            )
            tab.fileURL = url
            tab.displayName = url.lastPathComponent
            tab.isDirty = false
            return true
        } catch {
            presentError(error)
            return false
        }
    }

    private static func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
