#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

CONFIG="${1:-debug}"
APP_NAME="txtin"
APP_BUNDLE="$PROJECT_ROOT/${APP_NAME}.app"
LEGACY_APP_BUNDLE="$PROJECT_ROOT/VoicePasteMenuBarApp.app"
APP_ICON_ICNS="$PROJECT_ROOT/Resources/AppIcon.icns"
BUILD_STAMP="$(date +%s)"

# Keep SwiftPM/Clang caches in workspace-local directories (sandbox-safe).
mkdir -p "$PROJECT_ROOT/.sandbox-home"
mkdir -p "$PROJECT_ROOT/.build/.swiftpm-module-cache"
mkdir -p "$PROJECT_ROOT/.build/.clang-module-cache"
export HOME="$PROJECT_ROOT/.sandbox-home"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_ROOT/.build/.swiftpm-module-cache"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/.clang-module-cache"

resolve_executable() {
  if [[ -x "$PROJECT_ROOT/.build/$CONFIG/$APP_NAME" ]]; then
    echo "$PROJECT_ROOT/.build/$CONFIG/$APP_NAME"
    return 0
  fi
  if [[ -x "$PROJECT_ROOT/.build/arm64-apple-macosx/$CONFIG/$APP_NAME" ]]; then
    echo "$PROJECT_ROOT/.build/arm64-apple-macosx/$CONFIG/$APP_NAME"
    return 0
  fi
  return 1
}

if ! EXECUTABLE="$(resolve_executable)"; then
  echo "No existing binary found. Building ($CONFIG)..."
  swift build -c "$CONFIG"
  EXECUTABLE="$(resolve_executable)"
fi

rm -rf "$APP_BUNDLE"
rm -rf "$LEGACY_APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

if [[ -x "$PROJECT_ROOT/scripts/generate-app-icon.sh" ]]; then
  "$PROJECT_ROOT/scripts/generate-app-icon.sh"
fi

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [[ -f "$APP_ICON_ICNS" ]]; then
  cp "$APP_ICON_ICNS" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.linza.txtin.menubar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_STAMP}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>txtin needs microphone access to record your speech for transcription.</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>txtin needs accessibility access for global hotkey handling and text insertion.</string>
</dict>
</plist>
PLIST

if [[ -f "$PROJECT_ROOT/txtin.entitlements" ]]; then
  /usr/bin/codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "$PROJECT_ROOT/txtin.entitlements" \
    "$APP_BUNDLE"
fi

echo "Created: $APP_BUNDLE"
echo "Run: open '$APP_BUNDLE'"
