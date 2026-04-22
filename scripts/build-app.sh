#!/bin/bash
set -euo pipefail

APP_NAME="RootFont"
BIN_NAME="RootFontApp"
BUILD_DIR="$(pwd)/.build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
VERSION_CONFIG="Sources/RootFontApp/Resources/AppVersion.json"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

SHORT_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["shortVersion"])' "$VERSION_CONFIG")"
BUILD_NUMBER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["buildNumber"])' "$VERSION_CONFIG")"

swift build -c release --product "$BIN_NAME"

cp ".build/release/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Sources/RootFontApp/Resources/logo-rootfont-300x300.png" "$APP_BUNDLE/Contents/Resources/logo-rootfont-300x300.png"

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
    <string>logo-rootfont-300x300.png</string>
</dict>
</plist>
PLIST

echo "Built: $APP_BUNDLE"
echo "Run:   open \"$APP_BUNDLE\""
