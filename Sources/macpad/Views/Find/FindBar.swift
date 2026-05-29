import SwiftUI

// Win11-style find/replace bar that slides down between the tab strip
// and the editor. Single row when find-only (48pt); 88pt with replace
// expanded. Owned by the active tab so the query persists across tab
// switches.
struct FindBar: View {
    @ObservedObject var findState: FindState
    let theme: any AppTheme
    var onFindChanged: () -> Void = {}
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}
    var onReplace: () -> Void = {}
    var onReplaceAll: () -> Void = {}

    @FocusState private var findFieldFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            findRow
            if findState.isReplaceMode {
                replaceRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: findState.isReplaceMode ? Dim.findBarHeightWithReplace : Dim.findBarHeight)
        .background(theme.editorBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.divider).frame(height: 1)
        }
        .onAppear { findFieldFocused = true }
        .onChange(of: findState.isVisible) { _, visible in
            if visible { findFieldFocused = true }
        }
    }

    private var findRow: some View {
        HStack(spacing: 6) {
            Button {
                findState.isReplaceMode.toggle()
            } label: {
                Image(systemName: findState.isReplaceMode ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.editorSecondaryText)
            .help(findState.isReplaceMode ? "Hide Replace" : "Show Replace")

            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(theme.editorSecondaryText)
                .padding(.leading, 2)

            TextField("Find", text: $findState.query)
                .textFieldStyle(.plain)
                .focused($findFieldFocused)
                .onChange(of: findState.query) { _, _ in onFindChanged() }
                .onSubmit { onNext() }
                .frame(maxWidth: .infinity)

            if !findState.matches.isEmpty {
                Text("\((findState.currentMatchIndex ?? 0) + 1) of \(findState.matches.count)")
                    .font(.system(size: FontRole.statusBarSize))
                    .foregroundStyle(theme.editorSecondaryText)
                    .fixedSize()
            } else if !findState.query.isEmpty {
                Text("No matches")
                    .font(.system(size: FontRole.statusBarSize))
                    .foregroundStyle(theme.editorSecondaryText)
                    .fixedSize()
            }

            optionToggle(label: "Aa", help: "Match case", isOn: $findState.matchCase)
            optionToggle(label: "Ab|", help: "Match whole word", isOn: $findState.wholeWord)
            optionToggle(label: ".*", help: "Use regular expression", isOn: $findState.useRegex)

            iconButton(systemName: "chevron.up", help: "Previous match (⇧⌘G)", action: onPrevious)
            iconButton(systemName: "chevron.down", help: "Next match (⌘G)", action: onNext)
            iconButton(systemName: "xmark", help: "Close find bar") { findState.isVisible = false }
        }
        .frame(height: Dim.findInputHeight)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Dim.findInputCornerRadius)
                .fill(theme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Dim.findInputCornerRadius)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
        )
    }

    private var replaceRow: some View {
        HStack(spacing: 6) {
            // Indent to align with find field (icon column + chevron column).
            Spacer().frame(width: 20 + 6 + 12 + 2)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12))
                .foregroundStyle(theme.editorSecondaryText)
                .padding(.leading, 2)

            TextField("Replace", text: $findState.replacement)
                .textFieldStyle(.plain)
                .onSubmit { onReplace() }
                .frame(maxWidth: .infinity)

            Button("Replace", action: onReplace)
                .buttonStyle(.borderless)
            Button("Replace All", action: onReplaceAll)
                .buttonStyle(.borderless)
        }
        .frame(height: Dim.findInputHeight)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: Dim.findInputCornerRadius)
                .fill(theme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Dim.findInputCornerRadius)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func optionToggle(label: String, help: String, isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle(); onFindChanged() } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isOn.wrappedValue ? Color.accentColor.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn.wrappedValue ? Color.accentColor : theme.editorSecondaryText)
        .help(help)
    }

    @ViewBuilder
    private func iconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.editorSecondaryText)
        .help(help)
    }
}
