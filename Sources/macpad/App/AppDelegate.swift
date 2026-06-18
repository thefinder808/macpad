import AppKit

// Disable AppKit's automatic window tabbing before the main menu is loaded.
// If this runs later (e.g. inside an async WindowAccessor block), the View
// menu gets validated once with tabs allowed, and the dispatched mutation
// forces a re-validation that makes "Show Tab Bar" / "Show All Tabs" /
// "Enter Full Screen" flicker on first menu open.
final class AppDelegate: NSObject, NSApplicationDelegate {
    // The shared AppState — created here so we can flush autosave during
    // termination. SwiftUI also reads it via its own @StateObject in
    // MacpadApp; both refer to the same instance via this property.
    static let shared = AppState()

    // Receives "Send to macpad" Services-menu messages from other apps.
    // Retained here so NSApp.servicesProvider's weak-ish reference stays
    // alive for the app's lifetime.
    private let serviceProvider = ServiceProvider()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire up the macOS Services provider so other apps' right-click →
        // Services → "Send to macpad" reaches us. NSUpdateDynamicServices
        // nudges the system to pick up our Info.plist NSServices entries.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any pending debounced writes so a clean quit captures the
        // last keystroke.
        Self.shared.book.flushAutosave()
    }
}
