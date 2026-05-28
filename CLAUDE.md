# macpad

Pixel-perfect Windows 11 Notepad clone for macOS 14+. SwiftPM, SwiftUI + AppKit interop. Distributed as a notarized `.dmg`.

## Build

```bash
./build.sh run         # debug .app, exec binary so stdout stays visible
./build.sh app         # debug .app at build/macpad.app
./build.sh open        # debug .app via LaunchServices (real launch)
./build.sh release     # release .app, ad-hoc signed
./build.sh install     # release .app → /Applications/macpad.app
./build.sh dmg         # rebuild DMG against existing .app (no notary)
./build.sh notarize    # Developer ID + hardened runtime + DMG + notary + staple
./build.sh clean       # rm -rf build dist + swift package clean
```

## One-time setup for notarization

```bash
brew install create-dmg
xcrun notarytool store-credentials macpad-notary \
    --apple-id <email> --team-id Q6LRJQSA42 --password <app-specific>
```

Then `./build.sh notarize` produces `dist/macpad-<version>.dmg`.

## Architecture

See plan at `~/.claude/plans/howdy-claude-i-d-like-lexical-fox.md` (also in Obsidian as `Macpad/Macpad Implementation Plan.md`).

Key decisions:

- **TextKit 1**, not TextKit 2 — macOS 14.x TextKit 2 has regressions on temporary-attribute highlighting (which we use for find matches) and IME composition.
- **One shared `NSTextView`** with `textStorage` + `undoManager` swapped on tab activation. Reference-type `TabState` because `NSTextStorage`/`NSUndoManager` have identity.
- **No `Binding<String>` for editor text** — bind via `@ObservedObject TabState` exposing `NSTextStorage` directly. Re-encoding the full string per keystroke is what makes SwiftUI's `TextEditor` jank.
- **Traffic-light handling**: keep them at default position; reserve 80pt leading padding in the tab strip. Manually moving `standardWindowButton` is fragile across macOS versions — `NSThemeFrame` undoes it.
- **`isMenuTracking` gate in `AppState`** — install `NSMenu.didBegin/EndTrackingNotification` observers; suppress `objectWillChange` forwarding while a menu is open. Already burned twice (MacPerf, TraceView).
- **Autosave restore in `AppDelegate.applicationDidFinishLaunching`** — tabs need to be in `AppState` BEFORE the SwiftUI scene mounts, or the window flashes empty.
- **Mica analog**: `NSVisualEffectView` material `.windowBackground` + `.behindWindow` blending + `controlAccentColor` overlay at 8% (10% in dark).

## Visual fidelity reference

Tokens verified against `microsoft-ui-xaml/src/controls/dev/CommonStyles/Common_themeresources_any.xaml`:

- Tab strip: 40pt tall, tabs 100–240pt wide, 6pt top-only corner radius, no accent underline (the lighter fill color IS the selection cue).
- Editor bg: `#F9F9F9` light / `#282828` dark. Primary text `#E4000000` (89% black, never pure) / `#FFFFFF`.
- Type ramp: 12pt tab labels & status bar, 14pt menu items, 20pt Semibold section headers, 28pt Semibold settings title.
- Animations: 83ms hover, 167ms tab close, 200ms tab open, 250ms settings page transition. Easing: `cubic-bezier(0,0,0,1)` ≈ SwiftUI `.easeOut`.
- Editor font default: SF Mono 11pt. Cascadia Mono shipped as opt-in (OFL).
- Icons: Microsoft Fluent System Icons (MIT) — ship only the ~12 we need.

## Conventions

- **No xcassets** — code-driven `AppTheme` protocol with `Color(hex:)` helper.
- **`UserDefaults` keys namespaced** `"macpad.<key>"`.
- **Bundle ID** `com.macpad.app` (matches MacPerf/TraceView `com.<appname>.app` pattern).
