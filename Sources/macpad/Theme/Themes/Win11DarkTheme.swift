import SwiftUI

struct Win11DarkTheme: AppTheme {
    let name = "Win11 Dark"
    let isDark = true

    let editorBackground            = Color(hex: 0x282828)              // SolidBackgroundFillColorTertiary (dark)
    let editorText                  = Color(hex: 0xFFFFFF)
    let editorSecondaryText         = Color(argbHex: 0xC5FFFFFF)        // 77% white
    let editorSelectionBackground   = Color(argbHex: 0x4D60CDFF)        // accent @ 30%
    let findHighlight               = Color(argbHex: 0x66FFD700)
    let findHighlightActive         = Color(argbHex: 0x99FFA500)

    // Tuned for visible separation between chrome and editor: dark Mica
    // alone reads very close to #282828, so we wash it ~25% black to make
    // the title band noticeably darker than the active tab/editor.
    let chromeBackgroundTint        = Color(argbHex: 0x40000000)        // 25% black over dark Mica
    let tabActiveFill               = Color(hex: 0x282828)
    let tabInactiveText             = Color(argbHex: 0xC5FFFFFF)
    let tabActiveText               = Color(hex: 0xFFFFFF)
    // Bumped from 6%/4% white — the original Win11 tokens disappear over
    // Mica-on-macOS without strong wallpaper bleed-through.
    let tabHoverFill                = Color(argbHex: 0x1FFFFFFF)
    let tabPressedFill              = Color(argbHex: 0x14FFFFFF)
    let subtleHoverFill             = Color(argbHex: 0x1FFFFFFF)
    let subtlePressedFill           = Color(argbHex: 0x14FFFFFF)

    let divider                     = Color(argbHex: 0x12FFFFFF)
    let dividerStrong               = Color(argbHex: 0x29FFFFFF)
    let statusBarTopBorder          = Color(argbHex: 0x12FFFFFF)

    let inputBackground             = Color(argbHex: 0x0FFFFFFF)
    let inputBorder                 = Color(argbHex: 0x29FFFFFF)

    let settingsPageBackground      = Color(hex: 0x202020)
    let settingsCardBackground      = Color(argbHex: 0x4C3A3A3A)
    let settingsCardBorder          = Color(argbHex: 0x19000000)
    let settingsRowSeparator        = Color(argbHex: 0x12FFFFFF)
}
