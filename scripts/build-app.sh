#!/bin/bash
set -euo pipefail

APP_NAME="rootfont"
BIN_NAME="RootFontApp"
BUILD_DIR="$(pwd)/.build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
VERSION_CONFIG="Sources/RootFontApp/Resources/AppVersion.json"
ICON_PNG="Sources/RootFontApp/Resources/logo-rootfont-300x300.png"
ICON_ICNS="Sources/RootFontApp/Resources/rootfont.icns"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

SHORT_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["shortVersion"])' "$VERSION_CONFIG")"
BUILD_NUMBER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["buildNumber"])' "$VERSION_CONFIG")"
COMMIT_SHA="$(git rev-parse --short=7 HEAD 2>/dev/null || true)"

swift build -c release --product "$BIN_NAME"

cp ".build/release/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ICON_PNG" "$APP_BUNDLE/Contents/Resources/logo-rootfont-300x300.png"
if [[ -f "$ICON_ICNS" ]]; then
  cp "$ICON_ICNS" "$APP_BUNDLE/Contents/Resources/rootfont.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.rootfont.app</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>$( [[ -f "$ICON_ICNS" ]] && echo "rootfont.icns" || echo "logo-rootfont-300x300.png" )</string>
    <key>RootFontCommitSha</key>
    <string>$COMMIT_SHA</string>
</dict>
</plist>
PLIST

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
  echo "Signed with identity: $CODESIGN_IDENTITY"
fi

echo "Built: $APP_BUNDLE"
echo "Run:   open \"$APP_BUNDLE\""
