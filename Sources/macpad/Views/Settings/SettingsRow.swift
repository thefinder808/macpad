import SwiftUI

// One row in a Win11 settings card. 48pt min height; an optional leading
// icon + bold primary title + optional secondary description; trailing
// content fills the right-hand control area (toggle, picker, button, etc).
struct SettingsRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let theme: any AppTheme
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(theme.editorText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: FontRole.settingsRowSize, weight: .semibold))
                    .foregroundStyle(theme.editorText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.editorSecondaryText)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, Dim.settingsRowHorizontalPadding)
        .padding(.vertical, 10)
        .frame(minHeight: Dim.settingsRowHeight)
    }
}
