import Foundation

// Reconstruct open tabs from disk at launch — before the SwiftUI scene
// mounts, so the window paints with tabs already populated instead of
// flashing the default "Untitled" and then swapping in real state.
//
// Called from AppDelegate.applicationDidFinishLaunching. If no manifest
// or autosaved tabs exist, returns nil and TabBookViewModel.init falls
// back to a single empty Untitled tab.
enum SessionRestore {

    static func loadTabs() -> (tabs: [TabState], activeID: UUID?)? {
        guard let manifest = AutosaveStore.readManifest() else { return nil }
        var restored: [(tab: TabState, autosaveID: UUID)] = []
        for autosaveID in manifest.tabOrder {
            guard let r = AutosaveStore.readTab(autosaveID: autosaveID) else { continue }
            let tab = TabState(
                displayName: r.meta.displayName,
                fileURL: r.meta.fileURL,
                initialText: r.text,
                encoding: r.encoding,
                lineEnding: r.lineEnding,
                autosaveID: autosaveID
            )
            tab.isDirty = r.meta.isDirty
            tab.zoom = r.meta.zoom
            tab.selectedRange = NSRange(location: r.meta.cursorLocation,
                                         length: r.meta.selectionLength)
            tab.scrollOffset = CGPoint(x: 0, y: r.meta.scrollY)
            restored.append((tab, autosaveID))
        }
        guard !restored.isEmpty else { return nil }
        let activeID: UUID? = manifest.activeTabID.flatMap { saved in
            restored.first(where: { $0.autosaveID == saved })?.tab.id
        }
        return (restored.map(\.tab), activeID ?? restored.first?.tab.id)
    }
}
