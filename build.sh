#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/DeepSeek Harness.app"
HARNESS_SOURCE="${1:-}"

rm -rf "$BUILD_DIR" "$APP_DIR"
mkdir -p "$BUILD_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

/usr/bin/swiftc -swift-version 5 -O "$ROOT_DIR/App.swift" \
  -framework Cocoa -framework WebKit \
  -o "$APP_DIR/Contents/MacOS/DeepSeekHarnessClient"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key><string>DeepSeek Harness</string>
    <key>CFBundleExecutable</key><string>DeepSeekHarnessClient</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>io.github.deepseek-harness-macos-client</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>DeepSeek Harness</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSAppTransportSecurity</key>
    <dict><key>NSAllowsLocalNetworking</key><true/></dict>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

FAVICON="$HARNESS_SOURCE/apps/web/public/favicon.svg"
if [[ -f "$FAVICON" ]]; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  mkdir -p "$ICONSET"
  qlmanage -t -s 1024 -o "$BUILD_DIR" "$FAVICON" >/dev/null 2>&1
  SOURCE_PNG="$BUILD_DIR/favicon.svg.png"
  for spec in \
    'icon_16x16.png:16' 'icon_16x16@2x.png:32' \
    'icon_32x32.png:32' 'icon_32x32@2x.png:64' \
    'icon_128x128.png:128' 'icon_128x128@2x.png:256' \
    'icon_256x256.png:256' 'icon_256x256@2x.png:512' \
    'icon_512x512.png:512' 'icon_512x512@2x.png:1024'; do
    name="${spec%%:*}"
    size="${spec##*:}"
    sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET/$name" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built: $APP_DIR"
