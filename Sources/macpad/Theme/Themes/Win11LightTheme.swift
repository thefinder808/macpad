import SwiftUI

// Token values verified against microsoft-ui-xaml:
//   src/controls/dev/CommonStyles/Common_themeresources_any.xaml
// Primary text intentionally `#E4000000` (89% black), not pure — this is
// the Win11 convention for eye comfort against Mica.
struct Win11LightTheme: AppTheme {
    let name = "Win11 Light"
    let isDark = false

    let editorBackground            = Color(hex: 0xF9F9F9)              // SolidBackgroundFillColorTertiary
    let editorText                  = Color(argbHex: 0xE4000000)        // 89% black
    let editorSecondaryText         = Color(argbHex: 0x9E000000)        // 62% black
    let editorSelectionBackground   = Color(argbHex: 0x33007ACC)        // accent @ 20%
    let findHighlight               = Color(argbHex: 0x66FFD700)        // gold-yellow
    let findHighlightActive         = Color(argbHex: 0x99FFA500)        // orange (active match)

    // Same logic as the dark theme — Mica on macOS needs help separating
    // from the editor surface in the absence of wallpaper bleed-through.
    let chromeBackgroundTint        = Color(argbHex: 0x1F000000)        // 12% black wash over Mica
    let tabActiveFill               = Color(hex: 0xF9F9F9)              // same as editor — Win11 "merge" cue
    let tabInactiveText             = Color(argbHex: 0x9E000000)
    let tabActiveText               = Color(argbHex: 0xE4000000)
    let tabHoverFill                = Color(argbHex: 0x14000000)        // bumped from 3.5% black for visibility
    let tabPressedFill              = Color(argbHex: 0x0F000000)
    let subtleHoverFill             = Color(argbHex: 0x14000000)
    let subtlePressedFill           = Color(argbHex: 0x0F000000)

    let divider                     = Color(argbHex: 0x0F000000)        // ControlStrokeColorDefault
    let dividerStrong               = Color(argbHex: 0x29000000)        // ControlStrokeColorSecondary
    let statusBarTopBorder          = Color(argbHex: 0x0F000000)

    let inputBackground             = Color(argbHex: 0xB3FFFFFF)        // ControlFillColorDefault over Mica
    let inputBorder                 = Color(argbHex: 0x29000000)

    let settingsPageBackground      = Color(hex: 0xF3F3F3)              // Mica solid fallback
    let settingsCardBackground      = Color(argbHex: 0x80FFFFFF)        // LayerFillColorDefault
    let settingsCardBorder          = Color(argbHex: 0x0F000000)
    let settingsRowSeparator        = Color(argbHex: 0x0F000000)

    // ── Elevated direction (04A) ───────────────────────────────────────────
    let accent                      = Color(hex: 0x6C4CEF)              // indigo
    let accentMuted                 = Color(hex: 0x6C4CEF)
    let chromeRail                  = Color(argbHex: 0x1A000000)        // 10% black over Mica — the darker rail
    let editorPanelBackground       = Color(hex: 0xF9F9F9)             // == editorBackground (the raised surface)
    let tabFloatingActiveFill       = Color(hex: 0xFFFFFF)             // pure white chip lifts off the off-white rail
    let tabFloatingActiveBorder     = Color(argbHex: 0x736C4CEF)        // accent @ ~45%
    let tabFloatingInactiveFill     = Color(argbHex: 0x08000000)        // 3% black
    let tabFloatingInactiveBorder   = Color(argbHex: 0x17000000)        // 9% black
    let tabFloatingInactiveText     = Color(hex: 0x666666)
}
