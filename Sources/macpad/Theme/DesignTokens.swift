import Foundation
import CoreGraphics

// Win11 Fluent dimensions, in points (= Win11 epx). Sourced from
// microsoft-ui-xaml/src/controls/dev/CommonStyles/Common_themeresources_any.xaml
// and TabView_themeresources.xaml.
enum Dim {
    // Window chrome
    static let titleBarHeight: CGFloat = 40        // Win11 tab strip + title band
    static let trafficLightInset: CGFloat = 80     // reserve leading clearance for macOS traffic lights
    static let windowMinWidth: CGFloat = 640
    static let windowMinHeight: CGFloat = 400

    // Tabs
    static let tabHeight: CGFloat = 36
    static let tabMinWidth: CGFloat = 100
    static let tabMaxWidth: CGFloat = 240
    static let tabCornerRadius: CGFloat = 6        // top corners only
    static let tabHorizontalPadding: CGFloat = 8

    // Buttons (new tab, settings gear, find bar)
    static let chromeButtonSize: CGFloat = 32
    static let chromeButtonIcon: CGFloat = 16
    static let chromeButtonCornerRadius: CGFloat = 4
    static let tabCloseSize: CGFloat = 16
    static let tabCloseIcon: CGFloat = 12

    // Status bar
    static let statusBarHeight: CGFloat = 24
    static let statusItemHorizontalPadding: CGFloat = 12

    // Find bar
    static let findBarHeight: CGFloat = 48
    static let findBarHeightWithReplace: CGFloat = 88
    static let findInputHeight: CGFloat = 32
    static let findInputCornerRadius: CGFloat = 4

    // Settings
    static let settingsRowHeight: CGFloat = 48
    static let settingsCardCornerRadius: CGFloat = 8
    static let settingsRowHorizontalPadding: CGFloat = 16

    // Mica overlay accent tint strength (multiplied into controlAccentColor)
    static let micaAccentTintLight: Double = 0.08
    static let micaAccentTintDark: Double = 0.10
}

enum Motion {
    // WinUI ControlFastAnimationDuration = 83ms (5 frames @ 60fps).
    static let hover: Double = 0.083
    // WinUI ControlNormalAnimationDuration = 167ms.
    static let normal: Double = 0.167
    // ControlSlowAnimationDuration = 333ms; used for theme switch / settings page.
    static let slow: Double = 0.250
    static let tabOpen: Double = 0.200
    static let tabClose: Double = 0.167
    static let findBarSlide: Double = 0.167
}

enum FontRole {
    // SF Pro Text substitutes Segoe UI Variable for chrome.
    static let tabLabelSize: CGFloat = 12
    static let statusBarSize: CGFloat = 12
    static let menuItemSize: CGFloat = 14
    static let settingsRowSize: CGFloat = 14
    static let settingsSectionHeaderSize: CGFloat = 20
    static let settingsPageTitleSize: CGFloat = 28
    // Editor body default — replaced by user-chosen font in Phase 13.
    static let editorDefaultSize: CGFloat = 13
}
