import SwiftUI

// Picking a new EOL rewrites every line break in the buffer through
// EOLConverter (undoable, marks dirty). Save also normalizes on write
// so the file round-trips with the tab's chosen style.
struct EOLPopup: View {
    @ObservedObject var tab: TabState
    let theme: any AppTheme

    var body: some View {
        Menu {
            ForEach(LineEnding.allCases) { eol in
                Button(eol.verboseName) { EOLConverter.convert(tab, to: eol) }
            }
        } label: {
            Text(tab.lineEnding.displayName)
        }
        .menuStyle(StatusBarMenuStyle())
        .fixedSize()
    }
}
