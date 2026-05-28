import SwiftUI
import AppKit

// Configures the host NSWindow after SwiftUI attaches it: transparent
// titlebar + full-size content view (so the tab strip can extend into the
// title bar zone) + sensible min size + per-window tabbing disabled
// (belt-and-suspenders with AppDelegate's global flag).
//
// Window is `nil` until AppKit assigns it, so the work is dispatched
// async — same pattern as MacPerf's WindowAccessor.swift.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
            window.isMovableByWindowBackground = false
            window.tabbingMode = .disallowed
            window.minSize = NSSize(width: Dim.windowMinWidth, height: Dim.windowMinHeight)
            // Toolbar would draw on top of our custom tab strip; ensure none.
            window.toolbar = nil
            // Kill the AppKit-drawn separator/gradient that macOS injects at
            // the bottom of the titlebar zone — otherwise it cuts a visible
            // horizontal line through our 40pt tab band.
            window.titlebarSeparatorStyle = .none
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
