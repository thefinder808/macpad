#!/usr/bin/env bash
# build.sh — build macpad as a real .app bundle and run/install/notarize it.
#
# Without a proper .app bundle, SwiftUI/AppKit misbehave in subtle ways
# (menu bar, UserDefaults domain, file-access TCC prompts, window
# restoration, services menu, etc). This wrapper compiles with SPM and
# assembles a minimal .app around the binary, code-signed ad-hoc (for
# dev) or with a Developer ID cert (for public distribution).
#
# Subcommands:
#   build      — debug binary only (swift build)
#   app        — debug .app bundle in build/macpad.app
#   run        — build .app, exec the binary directly (stdout visible)
#   open       — build .app, launch via `open` (proper LaunchServices launch)
#   release    — release .app bundle (ad-hoc signed, for local use)
#   install    — release .app copied to /Applications
#   notarize   — Developer ID signed .app + DMG, notarized + stapled, ready
#                for a public GitHub Release. Requires the keychain profile
#                set up via `xcrun notarytool store-credentials`.
#   dmg        — rebuild DMG against the existing .app (no notarization)
#   clean      — remove build artifacts
set -euo pipefail

APP_NAME="macpad"
BUNDLE_ID="com.macpad.app"
BUNDLE_VERSION="1.0.4"
BUNDLE_SHORT_VERSION="1.0.4"
OUT_DIR="build"
APP_BUNDLE="${OUT_DIR}/${APP_NAME}.app"
ICON_SRC="Resources/AppIcon.icns"
ICONSET_SRC="Resources/AppIcon.iconset"
ENTITLEMENTS_FILE="Resources/macpad.entitlements"

# Developer ID cert used for distribution (public releases). Run
# `security find-identity -v -p codesigning` to see what's installed.
# Override via env: DEVELOPER_ID="…" ./build.sh notarize
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Nathaniel Graham (Q6LRJQSA42)}"
# Keychain profile storing Apple ID + app-specific password + team ID for
# notarytool. An app-specific password is NOT per-app-you-build — it
# authenticates your Apple ID, and notarization is gated by the Developer
# ID cert / Team ID on the binary. So one profile works for every app
# under the same developer account; we reuse the shared one set up for
# TraceView. Recreate it (or any name) with:
#   xcrun notarytool store-credentials traceview-notary \
#     --apple-id <email> --team-id Q6LRJQSA42 --password <app-specific>
# Override per-invocation with: NOTARY_PROFILE="other-profile" ./build.sh notarize
NOTARY_PROFILE="${NOTARY_PROFILE:-traceview-notary}"

make_info_plist() {
  cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${BUNDLE_SHORT_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUNDLE_VERSION}</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
  <key>NSSupportsSuddenTermination</key>
  <false/>
  <key>NSHumanReadableCopyright</key>
  <string>© 2026 Nathaniel Graham.</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Text File</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.text</string>
        <string>public.plain-text</string>
        <string>public.utf8-plain-text</string>
        <string>public.utf16-plain-text</string>
        <string>public.source-code</string>
      </array>
    </dict>
  </array>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Send to ${APP_NAME} (New Tab)</string>
      </dict>
      <key>NSMessage</key>
      <string>sendSelectionToNewTab</string>
      <key>NSKeyEquivalent</key>
      <dict>
        <key>default</key>
        <string>Y</string>
      </dict>
      <key>NSPortName</key>
      <string>${APP_NAME}</string>
      <key>NSSendTypes</key>
      <array>
        <string>public.utf8-plain-text</string>
        <string>public.plain-text</string>
      </array>
    </dict>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Send to ${APP_NAME} (Current Tab)</string>
      </dict>
      <key>NSMessage</key>
      <string>sendSelectionToCurrentTab</string>
      <key>NSKeyEquivalent</key>
      <dict>
        <key>default</key>
        <string>U</string>
      </dict>
      <key>NSPortName</key>
      <string>${APP_NAME}</string>
      <key>NSSendTypes</key>
      <array>
        <string>public.utf8-plain-text</string>
        <string>public.plain-text</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
EOF
}

build_icon() {
  # Regenerate AppIcon.icns from the iconset if the iconset is newer.
  # No-op if the .icns is already up to date. Requires iconutil (Xcode CLI).
  if [[ -d "$ICONSET_SRC" ]]; then
    if [[ ! -f "$ICON_SRC" ]] || [[ "$ICONSET_SRC" -nt "$ICON_SRC" ]]; then
      iconutil -c icns "$ICONSET_SRC" -o "$ICON_SRC"
      echo "✓ regenerated $ICON_SRC"
    fi
  fi
}

sign_bundle() {
  # Sign the .app. For ad-hoc dev builds pass "-"; for distribution pass
  # the Developer ID identity string.
  local sign_id="$1"
  if [[ "$sign_id" == "-" ]]; then
    codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
  else
    codesign --force --sign "$sign_id" --options runtime --timestamp \
      --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"
  fi
}

build_bundle() {
  local config="$1"       # "debug" or "release"
  local sign_id="${2:--}" # signing identity; "-" = ad-hoc
  local flag=""
  [[ "$config" == "release" ]] && flag="-c release"

  # shellcheck disable=SC2086
  swift build $flag
  build_icon

  local binary_path=".build/${config}/${APP_NAME}"
  [[ -f "$binary_path" ]] || { echo "✗ binary not found at ${binary_path}"; exit 1; }

  rm -rf "$APP_BUNDLE"
  mkdir -p "${APP_BUNDLE}/Contents/MacOS"
  mkdir -p "${APP_BUNDLE}/Contents/Resources"
  cp "$binary_path" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
  [[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
  make_info_plist

  sign_bundle "$sign_id"

  echo "✓ ${APP_BUNDLE}"
}

build_dmg() {
  # Wrap the existing .app in a polished DMG with drag-to-/Applications UX.
  # Requires: brew install create-dmg
  local version="$BUNDLE_SHORT_VERSION"
  local dist_dir="dist"
  local dmg_staging="${OUT_DIR}/dmg-stage"
  local dmg_path="${dist_dir}/${APP_NAME}-${version}.dmg"

  if ! command -v create-dmg >/dev/null 2>&1; then
    echo "✗ create-dmg not installed. Install with: brew install create-dmg"
    exit 1
  fi
  [[ -d "$APP_BUNDLE" ]] || { echo "✗ ${APP_BUNDLE} missing — build the .app first"; exit 1; }

  rm -rf "$dmg_staging"
  mkdir -p "$dmg_staging" "$dist_dir"
  cp -R "$APP_BUNDLE" "$dmg_staging/"
  rm -f "$dmg_path"
  create-dmg \
    --volname "$APP_NAME" \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "${APP_NAME}.app" 140 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 400 190 \
    --no-internet-enable \
    "$dmg_path" \
    "$dmg_staging"
  rm -rf "$dmg_staging"
  echo "✓ ${dmg_path}"
}

build_and_notarize() {
  # Full public-release pipeline: Developer ID sign the .app, verify,
  # wrap it in a DMG with a drag-to-Applications target, sign the DMG,
  # submit to Apple notary, staple the ticket to both, and emit the
  # final DMG at dist/<APP>-<version>.dmg.
  local version="$BUNDLE_SHORT_VERSION"
  local dist_dir="dist"
  local dmg_path="${dist_dir}/${APP_NAME}-${version}.dmg"

  # 1. Check Developer ID cert is installed
  if ! security find-identity -v -p codesigning | grep -q "${DEVELOPER_ID}"; then
    echo "✗ Developer ID cert not found in keychain:"
    echo "    ${DEVELOPER_ID}"
    echo "  Install it from Apple Developer → Certificates, or via Xcode."
    echo "  Or override with: DEVELOPER_ID='Developer ID Application: …' $0 notarize"
    exit 1
  fi
  [[ -f "$ENTITLEMENTS_FILE" ]] || { echo "✗ ${ENTITLEMENTS_FILE} missing"; exit 1; }

  echo "→ Building release .app and signing with Developer ID…"
  build_bundle release "$DEVELOPER_ID"

  echo "→ Verifying signature…"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  codesign --display --verbose=2 "$APP_BUNDLE" 2>&1 | grep -E "Authority|TeamIdentifier|flags" || true

  echo "→ Building DMG…"
  build_dmg

  echo "→ Signing DMG…"
  codesign --force --sign "$DEVELOPER_ID" --timestamp "$dmg_path"

  echo "→ Submitting to Apple notary service (this can take several minutes)…"
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "→ Stapling notarization ticket…"
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler staple "$dmg_path"

  echo "→ Verifying Gatekeeper acceptance…"
  spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"

  echo ""
  echo "✓ Release artifact: ${dmg_path}"
  echo "  Upload with: gh release create v${version} ${dmg_path} --notes-file <notes.md>"
}

case "${1:-run}" in
  build)
    swift build
    ;;
  app)
    build_bundle debug
    ;;
  run)
    build_bundle debug
    # Exec the binary directly: stdout stays visible for dev iteration,
    # but the binary still finds its bundle via NSBundle.main lookup.
    exec "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    ;;
  open)
    build_bundle debug
    open "$APP_BUNDLE"
    ;;
  release)
    build_bundle release
    ;;
  install)
    build_bundle release
    pkill -x "$APP_NAME" 2>/dev/null || true
    DEST="/Applications/${APP_NAME}.app"
    if [[ -w "/Applications" ]]; then
      rm -rf "$DEST"
      cp -R "$APP_BUNDLE" "$DEST"
    else
      echo "→ /Applications requires admin; you'll be prompted for your password"
      sudo rm -rf "$DEST"
      sudo cp -R "$APP_BUNDLE" "$DEST"
    fi
    /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
      -f "$DEST" 2>/dev/null || true
    echo "✓ installed $DEST"
    echo "  launch with: open -a $APP_NAME"
    ;;
  notarize)
    build_and_notarize
    ;;
  dmg)
    build_dmg
    ;;
  clean)
    swift package clean
    rm -rf "$OUT_DIR" dist
    ;;
  *)
    echo "usage: $0 {build|app|run|open|release|install|notarize|dmg|clean}"
    exit 1
    ;;
esac
