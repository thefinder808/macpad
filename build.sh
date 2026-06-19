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
#   publish-appcast — push the generated Sparkle appcast.xml + DMGs to the
#                gh-pages branch so installed apps see the new version
#   clean      — remove build artifacts
set -euo pipefail

APP_NAME="macpad"
BUNDLE_ID="com.macpad.app"
BUNDLE_VERSION="1.0.6"
BUNDLE_SHORT_VERSION="1.0.6"
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

# Sparkle auto-update. The appcast feed + signed DMGs are published to the
# public gh-pages branch (macpad's repo is public); enclosures live under
# /releases/.
SU_FEED_URL="https://thefinder808.github.io/macpad/appcast.xml"
# generate_appcast emits flat URLs; this prefix must match where
# publish-appcast actually places the DMGs (/releases/) or Sparkle reports
# "no update" with a silent 404 from GitHub Pages.
SU_DOWNLOAD_URL_PREFIX="https://thefinder808.github.io/macpad/releases/"
# EdDSA public key. This is the SHARED fleet key — the same Sparkle key used by
# TraceView (private key lives once in the login Keychain as
# "https://sparkle-project.org"; never lose it — it signs every future update).
# generate_appcast signs the DMG with that private key automatically. To rotate
# or mint a dedicated key: .build/artifacts/sparkle/Sparkle/bin/generate_keys
# Override via env: SU_PUBLIC_ED_KEY="…" ./build.sh notarize
SU_PUBLIC_ED_KEY="${SU_PUBLIC_ED_KEY:-OkisT+RinXia2GCpnFmXZ2ArHab4lYWXa9LPg4IsGoM=}"

make_info_plist() {
  # Emit SUPublicEDKey only when a key is set; an empty value would tell
  # Sparkle to skip verification with a malformed key.
  local sparkle_ed_key_block=""
  if [[ -n "$SU_PUBLIC_ED_KEY" ]]; then
    sparkle_ed_key_block="  <key>SUPublicEDKey</key>
  <string>${SU_PUBLIC_ED_KEY}</string>
"
  fi
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
  <key>NSAppleEventsUsageDescription</key>
  <string>macpad uses Apple events to relaunch itself after installing an automatic update.</string>
  <key>SUFeedURL</key>
  <string>${SU_FEED_URL}</string>
${sparkle_ed_key_block}  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUScheduledCheckInterval</key>
  <integer>86400</integer>
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

embed_sparkle() {
  # Copy Sparkle.framework from the SwiftPM artifact cache into the .app.
  # SPM extracts the XCFramework under .build/artifacts/sparkle/Sparkle/
  # Sparkle.xcframework/<slice>/Sparkle.framework. Skip the /index-build/
  # mirror (that copy is SourceKit's, not for shipping).
  local sparkle_src
  sparkle_src=$(find .build/artifacts -type d -name 'Sparkle.framework' 2>/dev/null \
                | grep -v '/index-build/' | head -1)
  if [[ -z "$sparkle_src" || ! -d "$sparkle_src" ]]; then
    echo "✗ Sparkle.framework not found under .build/artifacts/."
    echo "  Run 'swift package resolve' to fetch it, then retry."
    exit 1
  fi
  mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
  rm -rf "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
  cp -R "$sparkle_src" "${APP_BUNDLE}/Contents/Frameworks/"
}

sign_bundle() {
  # Sign the .app INSIDE-OUT. For ad-hoc dev builds pass "-"; for distribution
  # pass the Developer ID identity. NEVER use `codesign --deep` — it signs
  # Sparkle's nested XPC services in the wrong order / with the wrong
  # entitlements and breaks auto-update. Sign each Sparkle component, then the
  # framework, then the .app. Downloader.xpc ships
  # com.apple.security.network.client; --preserve-metadata=entitlements keeps
  # it when re-signing with Developer ID (strip it → downloads fail silently).
  local sign_id="$1"
  local sparkle_versions="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B"

  if [[ "$sign_id" == "-" ]]; then
    if [[ -d "$sparkle_versions" ]]; then
      codesign --force --sign - "${sparkle_versions}/XPCServices/Installer.xpc" >/dev/null 2>&1 || true
      codesign --force --sign - "${sparkle_versions}/XPCServices/Downloader.xpc" >/dev/null 2>&1 || true
      codesign --force --sign - "${sparkle_versions}/Autoupdate" >/dev/null 2>&1 || true
      codesign --force --sign - "${sparkle_versions}/Updater.app" >/dev/null 2>&1 || true
      codesign --force --sign - "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework" >/dev/null 2>&1 || true
    fi
    codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
  else
    local cs=(--force --sign "$sign_id" --options runtime --timestamp)
    if [[ -d "$sparkle_versions" ]]; then
      codesign "${cs[@]}" "${sparkle_versions}/XPCServices/Installer.xpc"
      codesign "${cs[@]}" --preserve-metadata=entitlements "${sparkle_versions}/XPCServices/Downloader.xpc"
      codesign "${cs[@]}" "${sparkle_versions}/Autoupdate"
      codesign "${cs[@]}" "${sparkle_versions}/Updater.app"
      codesign "${cs[@]}" "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"
    fi
    codesign "${cs[@]}" --entitlements "$ENTITLEMENTS_FILE" "$APP_BUNDLE"
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

  embed_sparkle

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

  # 0. Refuse to ship without the Sparkle EdDSA public key — without it
  # Sparkle skips update-signature verification and releases can be MITM'd.
  if [[ -z "$SU_PUBLIC_ED_KEY" ]]; then
    echo "✗ SU_PUBLIC_ED_KEY is empty — refusing to notarize an unverified build."
    echo "  Generate the key once with:"
    echo "    .build/artifacts/sparkle/Sparkle/bin/generate_keys"
    echo "  then export SU_PUBLIC_ED_KEY=… (or set it at the top of build.sh)."
    exit 1
  fi

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

  echo "→ Generating Sparkle appcast (diffs against prior gh-pages releases)…"
  generate_appcast_for_release "$dmg_path"

  echo ""
  echo "✓ Release artifact: ${dmg_path}"
  echo "  Next steps:"
  echo "    1. gh release create v${version} ${dmg_path} --notes-file <notes.md>"
  echo "    2. ./build.sh publish-appcast    # push appcast.xml + DMG to gh-pages"
}

generate_appcast_for_release() {
  # Stage the new DMG alongside prior releases pulled from gh-pages, then run
  # generate_appcast against the combined folder (it emits delta updates vs
  # prior versions). Output: build/appcast/{appcast.xml,*.dmg,*.delta}.
  local new_dmg="$1"
  local appcast_dir="${OUT_DIR}/appcast"
  local gh_pages_wt="${OUT_DIR}/gh-pages"
  local generate_appcast
  generate_appcast=$(find .build/artifacts -type f -name generate_appcast 2>/dev/null \
                     | grep -v '/index-build/' | head -1)
  if [[ -z "$generate_appcast" || ! -x "$generate_appcast" ]]; then
    echo "✗ generate_appcast not found under .build/artifacts — run 'swift package resolve'."
    exit 1
  fi

  rm -rf "$appcast_dir"
  mkdir -p "$appcast_dir"
  cp "$new_dmg" "$appcast_dir/"

  # Pull prior releases from gh-pages so generate_appcast can build deltas.
  # No-op on the first release (branch doesn't exist yet).
  rm -rf "$gh_pages_wt"
  if git show-ref --verify --quiet refs/remotes/origin/gh-pages \
     || git show-ref --verify --quiet refs/heads/gh-pages; then
    git worktree add "$gh_pages_wt" gh-pages 2>/dev/null \
      || { git fetch origin gh-pages && git worktree add "$gh_pages_wt" gh-pages; }
    if [[ -d "${gh_pages_wt}/releases" ]]; then
      cp -R "${gh_pages_wt}/releases/." "$appcast_dir/" 2>/dev/null || true
    fi
  else
    echo "  (no gh-pages branch yet — generating the initial appcast only)"
  fi

  "$generate_appcast" --download-url-prefix "$SU_DOWNLOAD_URL_PREFIX" "$appcast_dir"
  echo "✓ Appcast at ${appcast_dir}/appcast.xml"
}

publish_appcast() {
  # Copy appcast.xml (root) + DMGs/deltas (releases/) onto the gh-pages
  # worktree, commit, push. Kept separate from notarize so re-notarizing
  # doesn't touch the public feed. Sparkle URLs in the appcast are relative
  # to SU_DOWNLOAD_URL_PREFIX, so the DMGs MUST land under releases/.
  local appcast_dir="${OUT_DIR}/appcast"
  local gh_pages_wt="${OUT_DIR}/gh-pages"

  if [[ ! -f "${appcast_dir}/appcast.xml" ]]; then
    echo "✗ No appcast at ${appcast_dir}/appcast.xml — run './build.sh notarize' first."
    exit 1
  fi
  if [[ ! -d "$gh_pages_wt" ]]; then
    git worktree add "$gh_pages_wt" gh-pages 2>/dev/null \
      || { git fetch origin gh-pages && git worktree add "$gh_pages_wt" gh-pages; }
  fi

  mkdir -p "${gh_pages_wt}/releases"
  cp "${appcast_dir}/appcast.xml" "${gh_pages_wt}/appcast.xml"
  find "$appcast_dir" -maxdepth 1 -type f \( -name '*.dmg' -o -name '*.delta' \) \
    -exec cp {} "${gh_pages_wt}/releases/" \;

  (
    cd "$gh_pages_wt"
    git add appcast.xml releases/
    if git diff --cached --quiet; then
      echo "✓ Nothing to publish — appcast already current."
    else
      git commit -m "Publish appcast for v${BUNDLE_SHORT_VERSION}"
      echo "→ Pushing gh-pages…"
      git push origin gh-pages
      echo "✓ Published. Feed: ${SU_FEED_URL}"
    fi
  )
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
  publish-appcast)
    publish_appcast
    ;;
  clean)
    swift package clean
    rm -rf "$OUT_DIR" dist
    ;;
  *)
    echo "usage: $0 {build|app|run|open|release|install|notarize|dmg|publish-appcast|clean}"
    exit 1
    ;;
esac
