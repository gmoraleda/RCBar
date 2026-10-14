#!/bin/sh
# Builds RCBar.app and installs it to ~/Applications.
set -e
cd "$(dirname "$0")"
swift build -c release
.build/release/RCBar --selftest

APP=~/Applications/RCBar.app
pkill -x RCBar || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/RCBar "$APP/Contents/MacOS/RCBar"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.gmoraleda.rcbar</string>
  <key>CFBundleName</key><string>RCBar</string>
  <key>CFBundleExecutable</key><string>RCBar</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign --force --sign - "$APP"
open "$APP"
echo "Installed $APP"
