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
    // An NSPanel (not NSPopover) so the pop-down draws OVER another app's native
    // fullscreen Space. A .regular (Dock) app's NSPopover triggers a Space-switch
    // and won't render over a fullscreen app; a borderless .nonactivatingPanel
    // shows in place without activating macpad. Recipe mirrors MacPerf's
    // StatusBarController. It's a KeyablePanel (see below) because a borderless
    // panel can't become key by default — without that the TextEditor can't type.
    private var scratchpadPanel: KeyablePanel!
    private var eventMonitor: Any?
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
        // A borderless panel has no chrome of its own, so the SwiftUI content
        // supplies the material background + rounded corners the popover used to.
        let host = NSHostingController(
            rootView: MenuBarScratchpadView()
                .environmentObject(SettingsManager.shared)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        )
        let panel = KeyablePanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: true)
        panel.contentViewController = host
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        scratchpadPanel = panel

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
        scratchpadPanel.isVisible ? closeScratchpad() : openScratchpad()
    }

    private func openScratchpad() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }

        // Size the panel to fit the SwiftUI content.
        scratchpadPanel.contentViewController?.view.needsLayout = true
        scratchpadPanel.contentViewController?.view.layoutSubtreeIfNeeded()
        let size = scratchpadPanel.contentViewController?.view.fittingSize
            ?? NSSize(width: 288, height: 320)

        // Position centered just below the status-item button.
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let frame = NSRect(x: buttonRect.midX - size.width / 2,
                           y: buttonRect.minY - size.height - 4,
                           width: size.width, height: size.height)
        scratchpadPanel.setFrame(frame, display: true)
        // KeyablePanel overrides canBecomeKey, so this borderless .nonactivatingPanel
        // takes keyboard focus WITHOUT activating macpad — the scratchpad's TextEditor
        // accepts typing while another app (including a fullscreen one) stays frontmost.
        scratchpadPanel.makeKeyAndOrderFront(nil)

        // Mimic the popover's .transient dismissal: close on any click outside.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.closeScratchpad()
        }
    }

    private func closeScratchpad() {
        scratchpadPanel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

/// A borderless `NSWindow`/`NSPanel` returns `canBecomeKey == false` by default,
/// which blocks the scratchpad's `TextEditor` from ever receiving keystrokes.
/// Overriding it — together with the `.nonactivatingPanel` style — lets the panel
/// take keyboard focus without activating macpad, so typing works even while
/// another app (including one in native fullscreen) stays frontmost.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
