#!/bin/sh
# Builds Pilot Light.app into ~/Applications. Re-run after editing main.swift.
set -e
cd "$(dirname "$0")"
APP="$HOME/Applications/Pilot Light.app"
mkdir -p "$APP/Contents/MacOS"
# Universal (Apple Silicon + Intel), runs on macOS 13 Ventura and later.
MIN=13.0
VERSION=${VERSION:-0.9.0}
TMP=$(mktemp -d)
swiftc -O -target arm64-apple-macos$MIN main.swift -o "$TMP/arm64"
swiftc -O -target x86_64-apple-macos$MIN main.swift -o "$TMP/x86_64"
lipo -create "$TMP/arm64" "$TMP/x86_64" -output "$APP/Contents/MacOS/PilotLight"
rm -rf "$TMP"
mkdir -p "$APP/Contents/Resources"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" # regenerate: swift assets/render-icon.swift
mkdir -p "$APP/Contents/Library/LaunchAgents"
cp nz.sudolabs.pilotlight.watchdog.plist "$APP/Contents/Library/LaunchAgents/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>PilotLight</string>
  <key>CFBundleIdentifier</key><string>nz.sudolabs.pilotlight</string>
  <key>CFBundleName</key><string>Pilot Light</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 sudolabs. MIT license.</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>$MIN</string>
</dict></plist>
EOF
codesign -fs - "$APP"
echo "Built $APP"
