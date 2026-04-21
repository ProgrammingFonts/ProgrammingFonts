#!/bin/bash
set -euo pipefail

APP_NAME="RootFont"
BIN_NAME="RootFontApp"
BUILD_DIR="$(pwd)/.build/app"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swift build -c release --product "$BIN_NAME"

cp ".build/release/$BIN_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "logo-rootfont-300x300.png" "$APP_BUNDLE/Contents/Resources/logo-rootfont-300x300.png"

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
    <string>2</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0-beta</string>
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
