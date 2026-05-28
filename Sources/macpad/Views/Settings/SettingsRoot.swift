import SwiftUI
import AppKit

// Full-window takeover styled like Win11 Settings. Slides in from the
// right over the editor area, with a back arrow returning to tabs.
struct SettingsRoot: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            header(theme: theme)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appearanceSection(theme: theme)
                    textFormattingSection(theme: theme)
                    autosaveSection(theme: theme)
                }
                .padding(.horizontal, 56)
                .padding(.top, 36)
                .padding(.bottom, 24)
                .frame(maxWidth: 800, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.settingsPageBackground)
    }

    private func header(theme: any AppTheme) -> some View {
        HStack(spacing: 8) {
            Button {
                appState.isShowingSettings = false
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.editorText)
            .padding(.leading, 12)

            Text("Settings")
                .font(.system(size: FontRole.settingsPageTitleSize, weight: .semibold))
                .foregroundStyle(theme.editorText)
            Spacer()
        }
        .padding(.vertical, 4)
        .frame(height: 60)
    }

    // MARK: - Sections

    private func appearanceSection(theme: any AppTheme) -> some View {
        SettingsSection(title: "Appearance", theme: theme) {
            SettingsRow(title: "Theme",
                        subtitle: "Match your system, or pick light or dark.",
                        icon: "paintbrush",
                        theme: theme) {
                Picker("", selection: $themeManager.selectedOption) {
                    ForEach(ThemeOption.allCases) { opt in
                        Text(opt.displayName).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private func textFormattingSection(theme: any AppTheme) -> some View {
        SettingsSection(title: "Text formatting", theme: theme) {
            SettingsRow(title: "Font family",
                        subtitle: "Monospaced fonts installed on your system.",
                        icon: "textformat",
                        theme: theme) {
                Picker("", selection: $settingsManager.editorFontName) {
                    ForEach(availableMonoFonts(), id: \.self) { fontName in
                        Text(displayName(for: fontName)).tag(fontName)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(minWidth: 220)
            }
            SettingsRowDivider(theme: theme)
            SettingsRow(title: "Font size",
                        subtitle: "Editor body size in points. Zoom is separate (View → Zoom In).",
                        icon: "textformat.size",
                        theme: theme) {
                HStack(spacing: 8) {
                    Stepper(value: $settingsManager.editorFontSize, in: 9...32, step: 1) {
                        Text("\(Int(settingsManager.editorFontSize)) pt")
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .labelsHidden()
                    Text("\(Int(settingsManager.editorFontSize)) pt")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }
            }
            SettingsRowDivider(theme: theme)
            SettingsRow(title: "Word wrap",
                        subtitle: "Break long lines at the right edge of the editor.",
                        icon: "text.alignleft",
                        theme: theme) {
                Toggle("", isOn: $settingsManager.wordWrap)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private func autosaveSection(theme: any AppTheme) -> some View {
        SettingsSection(title: "Sessions", theme: theme) {
            SettingsRow(title: "Restore tabs on launch",
                        subtitle: "Open the same tabs and cursors you had when you quit.",
                        icon: "arrow.counterclockwise",
                        theme: theme) {
                Toggle("", isOn: $settingsManager.restoreOnLaunch)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Font discovery

    // Curated list ordered by likely user preference. We always include
    // the system monospaced font and a few legacy macOS staples; if the
    // user has Cascadia Mono (Win11's default), it bubbles to the top.
    private func availableMonoFonts() -> [String] {
        let manager = NSFontManager.shared
        let preferred: [String] = [
            "CascadiaMono-Regular", "CascadiaCode-Regular",
            ".AppleSystemUIFontMonospaced-Regular",
            "SFMono-Regular", "Menlo-Regular", "Monaco",
            "CourierNewPSMT", "AndaleMono"
        ]
        let installedFamilies = Set(manager.availableFontFamilies)
        return preferred.filter { name in
            // System mono and SF mono are always available.
            if name == ".AppleSystemUIFontMonospaced-Regular" || name == "SFMono-Regular" {
                return true
            }
            return NSFont(name: name, size: 12) != nil ||
                   installedFamilies.contains(name.replacingOccurrences(of: "-Regular", with: ""))
        }
    }

    private func displayName(for fontName: String) -> String {
        switch fontName {
        case ".AppleSystemUIFontMonospaced-Regular": return "System Mono"
        case "SFMono-Regular":      return "SF Mono"
        case "CascadiaMono-Regular": return "Cascadia Mono"
        case "CascadiaCode-Regular": return "Cascadia Code"
        case "Menlo-Regular":       return "Menlo"
        case "Monaco":              return "Monaco"
        case "CourierNewPSMT":      return "Courier New"
        case "AndaleMono":          return "Andale Mono"
        default:                    return fontName
        }
    }
}
