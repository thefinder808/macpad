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
//
// Elevated direction (04A): indigo accent, a rounded inset text field, a
// prominent "New tab" action, and a refined "Open macpad" affordance with a
// proper external-link glyph (replacing the old stray ↗).
struct MenuBarScratchpadView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.486, green: 0.361, blue: 1.0)   // #7C5CFF
                             : Color(red: 0.424, green: 0.298, blue: 0.937) // #6C4CEF
    }

    private var isBlank: Bool {
        settingsManager.scratchpadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 7) {
                Image(systemName: "note.text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(accent.opacity(0.15)))
                Text("Scratchpad")
                    .font(.system(size: 13, weight: .semibold))
            }

            // Inset, rounded text field
            TextEditor(text: $settingsManager.scratchpadText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(width: 264, height: 132)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(colorScheme == .dark ? 0.35 : 0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.12))
                )

            // Primary actions
            HStack(spacing: 8) {
                Button { send(into: .newTab) } label: {
                    Text("New tab").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(isBlank)

                Button { send(into: .currentTab) } label: {
                    Text("Add to current").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBlank)
            }
            .controlSize(.large)

            Divider()

            // Tertiary row
            HStack {
                Button("Clear") { settingsManager.scratchpadText = "" }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(settingsManager.scratchpadText.isEmpty)

                Spacer()

                Button { openMacpad() } label: {
                    HStack(spacing: 5) {
                        Text("Open macpad")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(accent.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
            }
        }
        .padding(14)
        .frame(width: 292)
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
