import AppKit
import SwiftUI
import Combine

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

    // Menu-bar scratchpad. Built in AppKit because SwiftUI's MenuBarExtra does
    // not render a status item in this app.
    private var statusItem: NSStatusItem?
    private let scratchpadPopover = NSPopover()
    private var settingsCancellable: AnyCancellable?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire up the macOS Services provider so other apps' right-click →
        // Services → "Send to macpad" reaches us. NSUpdateDynamicServices
        // nudges the system to pick up our Info.plist NSServices entries.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        setUpMenuBarItem()
    }

    // Keep the app (and its menu-bar scratchpad) alive after the window is
    // closed, so "Open macpad" can bring it back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any pending debounced writes so a clean quit captures the
        // last keystroke.
        Self.shared.book.flushAutosave()
    }

    // MARK: - Menu-bar scratchpad

    private func setUpMenuBarItem() {
        scratchpadPopover.behavior = .transient   // dismiss on click-outside
        scratchpadPopover.contentViewController = NSHostingController(
            rootView: MenuBarScratchpadView().environmentObject(SettingsManager.shared)
        )

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "note.text",
                                     accessibilityDescription: "macpad scratchpad")
        item.button?.image?.isTemplate = true
        item.button?.target = self
        item.button?.action = #selector(toggleScratchpad(_:))
        statusItem = item

        // Visibility follows the Settings toggle.
        item.isVisible = SettingsManager.shared.showMenuBarItem
        settingsCancellable = SettingsManager.shared.$showMenuBarItem
            .sink { [weak item] visible in item?.isVisible = visible }
    }

    @objc private func toggleScratchpad(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if scratchpadPopover.isShown {
            scratchpadPopover.performClose(sender)
        } else {
            scratchpadPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover key so its TextEditor takes keyboard focus.
            scratchpadPopover.contentViewController?.view.window?.makeKey()
        }
    }
}
