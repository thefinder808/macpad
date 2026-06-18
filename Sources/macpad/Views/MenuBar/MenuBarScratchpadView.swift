import SwiftUI
import AppKit

// The pop-down shown by the menu-bar item (MenuBarExtra `.window` style): a
// small persistent scratchpad you can paste into / copy from, plus actions to
// push the text into a macpad tab, clear it, or bring the main window forward.
//
// The text is bound to `SettingsManager.scratchpadText` (UserDefaults-backed),
// so it survives quit; Clear empties it. Sending reuses the same
// `TabBookViewModel.receiveExternalText` plumbing as the "Send to macpad"
// Services feature, reached via the `AppDelegate.shared` singleton.
struct MenuBarScratchpadView: View {
    @EnvironmentObject private var settingsManager: SettingsManager

    private var isBlank: Bool {
        settingsManager.scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scratchpad")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $settingsManager.scratchpadText)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 264, height: 150)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.3))
                )

            HStack(spacing: 8) {
                Button("New tab") { send(into: .newTab) }
                    .disabled(isBlank)
                Button("Add to current tab") { send(into: .currentTab) }
                    .disabled(isBlank)
            }

            Divider()

            HStack {
                Button("Clear") { settingsManager.scratchpadText = "" }
                    .disabled(settingsManager.scratchpadText.isEmpty)
                Spacer()
                Button("Open macpad") { openMacpad() }
            }
        }
        .padding(12)
        .frame(width: 288)
    }

    // Push the scratchpad text into a macpad tab, then surface the window so
    // the result is visible. Leaves the scratchpad intact (Clear is manual).
    private func send(into destination: ExternalTextDestination) {
        guard !isBlank else { return }
        AppDelegate.shared.book.receiveExternalText(settingsManager.scratchpadText, into: destination)
        openMacpad()
    }

    private func openMacpad() {
        // Bridged out to the SwiftUI scene's openWindow (see AppState
        // .presentMainWindow); falls back to a plain activate if not captured.
        if let present = AppDelegate.shared.presentMainWindow {
            present()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
