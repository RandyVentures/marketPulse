#!/bin/zsh
set -euo pipefail

APP_NAME="MarketPulseBar"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"

rm -rf "$ROOT_DIR/dist"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cd "$ROOT_DIR"
swift build -c release
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
if [[ -f "$ROOT_DIR/Resources/MarketPulseBar.icns" ]]; then
  cp "$ROOT_DIR/Resources/MarketPulseBar.icns" "$APP_DIR/Contents/Resources/MarketPulseBar.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.marketpulse.$APP_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>MarketPulseBar.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

cd "$ROOT_DIR/dist"
zip -r "$APP_NAME.app.zip" "$APP_NAME.app"

echo "Built $APP_NAME.app.zip in $ROOT_DIR/dist"
