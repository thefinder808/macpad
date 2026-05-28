import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red:     Double((hex >> 16) & 0xFF) / 255,
            green:   Double((hex >>  8) & 0xFF) / 255,
            blue:    Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }

    // Win11 specifies semi-transparent neutral overlays as 8-digit AARRGGBB
    // (e.g. SubtleFillColorSecondary = #09000000 — 3.5% black). This init
    // mirrors that source-of-truth format from microsoft-ui-xaml so token
    // values can be pasted in unchanged.
    init(argbHex: UInt32) {
        let a = Double((argbHex >> 24) & 0xFF) / 255
        let r = Double((argbHex >> 16) & 0xFF) / 255
        let g = Double((argbHex >>  8) & 0xFF) / 255
        let b = Double( argbHex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
