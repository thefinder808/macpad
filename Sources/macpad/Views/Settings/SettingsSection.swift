import SwiftUI

// A card containing one or more SettingsRows, with the section title
// floating above the card. Separators between rows are inset 16pt from
// the leading edge (matches Win11).
struct SettingsSection<Content: View>: View {
    let title: String
    let theme: any AppTheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: FontRole.settingsSectionHeaderSize, weight: .semibold))
                .foregroundStyle(theme.editorText)

            VStack(spacing: 0) {
                content()
            }
            .background(theme.settingsCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Dim.settingsCardCornerRadius)
                    .stroke(theme.settingsCardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Dim.settingsCardCornerRadius))
        }
    }
}

/// Thin horizontal divider used between rows inside a SettingsSection.
struct SettingsRowDivider: View {
    let theme: any AppTheme
    var body: some View {
        Rectangle()
            .fill(theme.settingsRowSeparator)
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
