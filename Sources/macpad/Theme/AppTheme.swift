import SwiftUI

// Each theme is a flat bag of named colors. Dimensions/motion live in
// DesignTokens.swift (not per-theme). Add a property here only when at
// least one theme needs to override it — resist the urge to add a knob
// "in case we ever want it."
protocol AppTheme {
    var name: String { get }
    var isDark: Bool { get }

    // Editor surface — the opaque content layer that sits on top of Mica.
    var editorBackground: Color { get }
    var editorText: Color { get }
    var editorSecondaryText: Color { get }
    var editorSelectionBackground: Color { get }
    var findHighlight: Color { get }
    var findHighlightActive: Color { get }

    // Chrome (titlebar zone, tab strip, status bar) — sits over Mica, mostly transparent.
    var chromeBackgroundTint: Color { get }       // overlaid on NSVisualEffectView
    var tabActiveFill: Color { get }               // == editorBackground; tab "merges with content"
    var tabInactiveText: Color { get }
    var tabActiveText: Color { get }
    var tabHoverFill: Color { get }
    var tabPressedFill: Color { get }
    var subtleHoverFill: Color { get }             // generic chrome button hover
    var subtlePressedFill: Color { get }

    // Borders / dividers — universally subtle in Win11.
    var divider: Color { get }                     // ControlStrokeColorDefault
    var dividerStrong: Color { get }               // ControlStrokeColorSecondary
    var statusBarTopBorder: Color { get }

    // Input fields (find bar, settings)
    var inputBackground: Color { get }
    var inputBorder: Color { get }

    // Settings cards
    var settingsPageBackground: Color { get }
    var settingsCardBackground: Color { get }
    var settingsCardBorder: Color { get }
    var settingsRowSeparator: Color { get }

    // ── Elevated direction (04A) ───────────────────────────────────────────
    // Indigo accent, floating tab chips, and a raised editor panel that sits
    // on a darker "rail." See ContentView.EditorLayer and TabItemView.
    var accent: Color { get }                      // primary indigo (dirty dot, 100% zoom, active border)
    var accentMuted: Color { get }                 // softer indigo for the active tab's doc icon
    var chromeRail: Color { get }                  // tint drawn over Mica behind tabs + around the panel
    var editorPanelBackground: Color { get }       // raised editor surface (== editorBackground)
    var tabFloatingActiveFill: Color { get }       // active chip fill (lifts off the rail)
    var tabFloatingActiveBorder: Color { get }     // accent-tinted hairline around the active chip
    var tabFloatingInactiveFill: Color { get }
    var tabFloatingInactiveBorder: Color { get }
    var tabFloatingInactiveText: Color { get }
}
