import AppKit

// Receives text from other apps via the macOS Services menu
// ("Send to macpad (New Tab) / (Current Tab)"). Registered as
// NSApp.servicesProvider in AppDelegate. The two @objc methods are named to
// match the NSMessage values declared in build.sh's Info.plist NSServices
// array: the system invokes the selector `<NSMessage>:userData:error:`.
//
// Reaches the running tab book through AppDelegate.shared (the single shared
// AppState).
//
// Focus handling: macOS activates the service *provider* (macpad) before it
// calls our handler, so we can't read the source app from inside the handler
// — by then we're already frontmost. Instead we track the last non-macpad
// app to become active via an NSWorkspace observer, then re-activate it after
// inserting. The net effect: the text lands in macpad and focus returns to
// the app the user was working in, matching the "without changing app focus"
// intent.
final class ServiceProvider: NSObject {
    // The most recent app *other than macpad* to become frontmost — i.e. the
    // app the user was working in when they invoked the service.
    private var lastExternalApp: NSRunningApplication?

    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        lastExternalApp = app
    }

    @objc func sendSelectionToNewTab(_ pboard: NSPasteboard,
                                     userData: String?,
                                     error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        receive(from: pboard, into: .newTab, error: error)
    }

    @objc func sendSelectionToCurrentTab(_ pboard: NSPasteboard,
                                         userData: String?,
                                         error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        receive(from: pboard, into: .currentTab, error: error)
    }

    private func receive(from pboard: NSPasteboard,
                         into destination: ExternalTextDestination,
                         error: AutoreleasingUnsafeMutablePointer<NSString>?) {
        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            error?.pointee = "No text to send to macpad." as NSString
            return
        }
        // Service messages can arrive off the main thread; all tab/UI
        // mutation must happen on main.
        DispatchQueue.main.async {
            AppDelegate.shared.book.receiveExternalText(text, into: destination)
            // Bounce focus back to the app the text came from, so stashing
            // text into macpad doesn't pull the user out of their workflow.
            self.lastExternalApp?.activate()
        }
    }
}
