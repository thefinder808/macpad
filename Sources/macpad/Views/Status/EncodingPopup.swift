import SwiftUI

// Encoding is the save-time format — the text in memory is Unicode
// regardless. Changing it here re-encodes on the next save (and marks
// dirty so the user notices the pending re-write). Re-reading an already-
// opened file with a different encoding is a v2 feature.
struct EncodingPopup: View {
    @ObservedObject var tab: TabState
    let theme: any AppTheme

    var body: some View {
        Menu {
            ForEach(TextEncoding.allCases) { enc in
                Button(enc.displayName) {
                    if tab.encoding != enc {
                        tab.encoding = enc
                        tab.isDirty = true
                    }
                }
            }
        } label: {
            Text(tab.encoding.displayName)
        }
        .menuStyle(StatusBarMenuStyle())
        .fixedSize()
    }
}
