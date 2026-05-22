#!/usr/bin/env bash
# Builds a release binary and assembles Stats.app — a menu-bar agent
# (LSUIElement, no Dock icon). App icon is optional: if
# art/AppIcon-source.png is absent, the bundle ships without a custom
# icon (slot in the unified coffee-cup art later, same as Port).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP="$ROOT/Stats.app"
SRC_ICON="$ROOT/art/AppIcon-source.png"
VERSION="0.3.2"
# Same Developer ID as the rest of the suite. Override SIGN_IDENTITY=- for ad-hoc.
SIGN_IDENTITY="${SIGN_IDENTITY:-0948896DC970503ADEF5B5070E0BB3E9D9047757}"
DMG="$ROOT/Stats-$VERSION.dmg"

echo "› swift build -c release"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

echo "› assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Stats" "$APP/Contents/MacOS/Stats"

# ── Embed + (below) sign the SuiteKit contract and this
# app's pane dylib so the MattsSoftware launcher can load
# the SAME code out of this installed .app. rpath lets the
# bundled exe find them under Contents/Frameworks.
mkdir -p "$APP/Contents/Frameworks"
cp "$BIN/libSuiteKit.dylib" "$APP/Contents/Frameworks/"
cp "$BIN/libStatsPane.dylib" "$APP/Contents/Frameworks/"
if [ -d "$BIN/StatsPane_StatsPane.bundle" ]; then cp -R "$BIN/StatsPane_StatsPane.bundle" "$APP/Contents/Frameworks/"; fi
install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Stats" 2>/dev/null || true


ICON_KEY=""
if [ -f "$SRC_ICON" ]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" \
              "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" \
              "512:512x512" "1024:512x512@2x"; do
    px="${spec%%:*}"; name="${spec##*:}"
    sips -z "$px" "$px" "$SRC_ICON" --out "$ICONSET/icon_${name}.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="  <key>CFBundleIconFile</key><string>AppIcon</string>"
else
  echo "⚠ no art/AppIcon-source.png — building without a custom app icon"
fi

# ── Widget extension (.appex) ─────────────────────────────────────
# Built by Xcode, not SwiftPM. SwiftPM has no `productType = app-
# extension` (SR-14944), and without it ExtensionFoundation fatal-
# errors with "Unrecognized extension type" at launch. The widget
# is a tiny Xcode subproject at `Widget/StatsWidgets.xcodeproj` that
# consumes `StatsShared` from this package via a local-package
# dependency so the host pane and the widget share one source of
# truth for the App Group + SharedStats snapshot model.
#
# SKIP_WIDGET=1 lets you iterate on the host without the xcodebuild
# round-trip on every build.
if [ "${SKIP_WIDGET:-0}" != "1" ]; then
  if command -v xcodegen >/dev/null; then
    ( cd "$ROOT/Widget" && xcodegen generate --quiet )
  fi
  echo "› xcodebuild StatsWidgets.appex"
  XCB_OUT="$ROOT/.build/xcode"
  xcodebuild \
    -project "$ROOT/Widget/StatsWidgets.xcodeproj" \
    -scheme StatsWidgets \
    -configuration Release \
    -derivedDataPath "$XCB_OUT" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$VERSION" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build
  WIDGET_APPEX="$XCB_OUT/Build/Products/Release/StatsWidgets.appex"
  if [ -d "$WIDGET_APPEX" ]; then
    mkdir -p "$APP/Contents/PlugIns"
    rm -rf "$APP/Contents/PlugIns/StatsWidgets.appex"
    ditto "$WIDGET_APPEX" "$APP/Contents/PlugIns/StatsWidgets.appex"
    echo "✓ embedded $APP/Contents/PlugIns/StatsWidgets.appex"
  else
    echo "⚠ widget build produced no .appex at $WIDGET_APPEX"
  fi
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Stats</string>
  <key>CFBundleDisplayName</key><string>Stats</string>
  <key>CFBundleIdentifier</key><string>com.mattssoftware.stats</string>
  <key>CFBundleExecutable</key><string>Stats</string>
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLName</key><string>com.mattssoftware.stats</string>
    <key>CFBundleURLSchemes</key><array><string>stats</string></array>
  </dict></array>
$ICON_KEY
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Stats</string>
</dict>
</plist>
PLIST

# Inside-out signing — codesign rejects a parent bundle whose
# children aren't already signed:
#   dylibs → widget exe (extension entitlements) → widget bundle
#   → host exe (host entitlements) → host bundle.
# The host's App Group entitlement is what lets it write
# `shared-stats.json` to the Group Container the widget reads from;
# drift between `Stats.entitlements` and
# `Widget/Supporting Files/StatsWidgets.entitlements` silently
# breaks the data path with no error at the codesign stage.
HOST_ENT="$ROOT/Stats.entitlements"
WIDGET_ENT="$ROOT/Widget/Supporting Files/StatsWidgets.entitlements"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/libSuiteKit.dylib"
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Frameworks/libStatsPane.dylib"
  if [ -d "$APP/Contents/PlugIns/StatsWidgets.appex" ]; then
    codesign --force --options runtime --timestamp \
      --entitlements "$WIDGET_ENT" \
      --sign "$SIGN_IDENTITY" \
      "$APP/Contents/PlugIns/StatsWidgets.appex/Contents/MacOS/StatsWidgets"
    codesign --force --options runtime --timestamp \
      --entitlements "$WIDGET_ENT" \
      --sign "$SIGN_IDENTITY" \
      "$APP/Contents/PlugIns/StatsWidgets.appex"
  fi
  codesign --force --options runtime --timestamp \
    --entitlements "$HOST_ENT" \
    --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/Stats"
  codesign --force --options runtime --timestamp \
    --entitlements "$HOST_ENT" \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=1 "$APP" && echo "✓ signed: $SIGN_IDENTITY"
else
  echo "⚠ signing identity not found — ad-hoc signing instead"
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi
echo "✓ built $APP"

# ── Notarize + staple the .app (Developer ID builds only) ─────────
# Runs BEFORE the .dmg is built so the disk image wraps an
# already-stapled app — the copy a user drags to /Applications is
# Gatekeeper-trusted even offline. We notarize the zipped app, so the
# ticket rides on the .app; the .dmg is signed but not stapled (its
# first mount does a one-time online check, fine for a freshly
# downloaded installer). Non-fatal: a creds-less or rejected build
# still completes, just signed-only.
NOTARY_PROFILE="${NOTARY_PROFILE:-Notary}"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  echo "› notarizing $APP (waits on Apple)…"
  NZIP="$(mktemp -d)/notarize.zip"
  ditto -c -k --keepParent "$APP" "$NZIP"
  if xcrun notarytool submit "$NZIP" \
       --keychain-profile "$NOTARY_PROFILE" --wait; then
    if xcrun stapler staple "$APP"; then
      if xcrun stapler validate "$APP"; then
        echo "✓ notarized + stapled $APP"
      else
        echo "⚠ staple validate failed for $APP"
      fi
    else
      echo "⚠ stapling failed for $APP"
    fi
  else
    echo "⚠ notarization skipped/failed — $APP signed but not notarized"
  fi
fi

# Build a downloadable .dmg from the (now-stapled) Stats.app.
STAGE="$(mktemp -d)/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Stats.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Stats" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG" || true
fi
echo "✓ built $DMG"
