# macpad

A native macOS text editor inspired by the Windows 11 Notepad.

> **Disclaimer:** macpad is an independent, unofficial fan project. It is **not affiliated with, endorsed by, or sponsored by Microsoft Corporation**. "Windows," "Windows 11," and "Notepad" are trademarks of Microsoft Corporation. macpad ships none of Microsoft's proprietary code, fonts, or assets — only open-source components from third parties (see [Credits](#credits)).

## Features

- **Multi-tab editing** with a Win11-style tab strip
- **TextKit 1** `NSTextView` core with all auto-substitutions disabled (no smart quotes, no autocorrect, no link detection)
- **Find / Replace** overlay with regex, match-case, and whole-word toggles
- **BOM-aware file open** — UTF-8 (with or without BOM), UTF-16 LE/BE, Windows-1252
- **Line-ending conversion** — LF, CRLF, CR (undoable)
- **Per-tab zoom**, configurable font family and size, word wrap toggle
- **Live status bar** — line/column, character count, word count, encoding, EOL, zoom
- **Autosave** — every keystroke (debounced 750 ms) writes to `~/Library/Application Support/macpad/Sessions/`
- **Session restore** — quit with tabs open, relaunch with the same tabs, cursor positions, and scroll offsets
- **Dark / Light / System** themes (Win11 color tokens verified against the open-source `microsoft-ui-xaml` repo)
- **Finder integration** — Open With, drag-and-drop a file onto the window to open as a new tab
- **Tab drag-reorder**
- **Notarized .dmg distribution** via `./build.sh notarize`

## Install

Download the latest signed and notarized `.dmg` from [Releases](https://github.com/thefinder808/macpad/releases), drag `macpad.app` to `/Applications`, and launch.

The DMG is signed with a Developer ID and notarized by Apple, so Gatekeeper will accept it without any "untrusted developer" prompts.

## Build from source

Requires Xcode command-line tools (Swift 5.9+) and macOS 14 (Sonoma) or later.

```bash
git clone https://github.com/thefinder808/macpad.git
cd macpad
./build.sh run         # debug build, exec binary with stdout visible
./build.sh open        # debug build, launch as a normal app
./build.sh release     # release .app, ad-hoc signed
./build.sh install     # release .app copied to /Applications
./build.sh clean       # remove build artifacts
```

For notarized distribution (requires a Developer ID cert and `xcrun notarytool` keychain profile):

```bash
brew install create-dmg
xcrun notarytool store-credentials macpad-notary \
    --apple-id <email> --team-id <TEAMID> --password <app-specific>
./build.sh notarize    # produces dist/macpad-<version>.dmg
```

## Architecture

- **Swift Package Manager**, single executable target — no `.xcodeproj`.
- **SwiftUI** for layout and state; **AppKit interop** (`NSViewRepresentable`) for the editor (`NSTextView`), window chrome, and the `NSVisualEffectView` backdrop.
- **`@main` App** + `NSApplicationDelegateAdaptor` + a shared `AppState` (`static let shared`) so the AppDelegate can reach the same instance SwiftUI uses for autosave flush on termination.
- **One shared `NSTextView`** with `textStorage` and `undoManager` swapped on tab activation — O(1) views, O(N) storages, matches Sublime / VS Code.
- **Reference-type `TabState`** because `NSTextStorage` and `NSUndoManager` have identity.
- **TextKit 1**, not TextKit 2 — macOS 14.x TextKit 2 has open regressions on temporary-attribute drawing (used for find highlights) and IME composition.

See [CLAUDE.md](CLAUDE.md) for build commands, gotchas, and design conventions.

## Credits

macpad would not have been possible without these open-source components:

- **[Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons)** — MIT-licensed icon set by Microsoft, used for tabs, status bar, and settings.
- **[Cascadia Mono](https://github.com/microsoft/cascadia-code)** — OFL-licensed monospace font by Microsoft (optional editor font).
- **[`microsoft-ui-xaml`](https://github.com/microsoft/microsoft-ui-xaml)** — MIT-licensed Win11 design token reference (`Common_themeresources_any.xaml`, `TabView_themeresources.xaml`).

All three of these are explicitly open-sourced by Microsoft under permissive licenses. No proprietary Microsoft code, fonts, or assets are bundled with macpad.

The macOS-side architecture borrows conventions established in two of my earlier macOS apps, [MacPerf](https://github.com/thefinder808/macperf) and [TraceView](https://github.com/thefinder808/traceview) — `build.sh` notarize pipeline, `AppTheme` protocol, the `isMenuTracking` gate against menu-tracking flicker, and the SwiftPM-only project layout.

## License

[MIT](LICENSE) © 2026 Nathaniel Graham
