#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="txtin"
APP_PATH="$PROJECT_ROOT/${APP_NAME}.app"
APP_BINARY="$APP_PATH/Contents/MacOS/${APP_NAME}"
ENTITLEMENTS="$PROJECT_ROOT/txtin.entitlements"
DEVELOPER_ID="${DEVELOPER_ID:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_PASSWORD="${APPLE_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"
DIST_DIR="$PROJECT_ROOT/dist"

NOTARIZE=false
if [[ "${1:-}" == "--notarize" ]]; then
  NOTARIZE=true
fi

notarize_dmg() {
  local dmg_path="$1"

  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    echo "Submitting for notarization with profile: $NOTARYTOOL_PROFILE"
    /usr/bin/xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
    return 0
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APPLE_PASSWORD:-}" && -n "${TEAM_ID:-}" ]]; then
    echo "Submitting for notarization with Apple ID credentials (team: $TEAM_ID)"
    /usr/bin/xcrun notarytool submit "$dmg_path" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_PASSWORD" \
      --team-id "$TEAM_ID" \
      --wait
    return 0
  fi

  echo "ERROR: notarization requested, but credentials are missing."
  echo "Set one of the following:"
  echo "  1) NOTARYTOOL_PROFILE=<profile>"
  echo "  2) APPLE_ID, APPLE_PASSWORD (app-specific), TEAM_ID"
  return 1
}

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found, building first..."
  "$PROJECT_ROOT/scripts/build-app.sh"
fi

if [[ ! -f "$APP_BINARY" ]]; then
  echo "ERROR: app binary missing: $APP_BINARY"
  exit 1
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
  echo "ERROR: entitlements file missing: $ENTITLEMENTS"
  exit 1
fi

mkdir -p "$DIST_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.0")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null || date +%s)"
DATE="$(date +%Y%m%d)"
DMG_PATH="$DIST_DIR/${APP_NAME}_v${VERSION}_build${BUILD}_${DATE}.dmg"

echo "Signing app with: $DEVELOPER_ID"

# Sign inner executable first, then app bundle.
/usr/bin/codesign --force \
  --options runtime \
  --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" \
  "$APP_BINARY"

/usr/bin/codesign --force \
  --deep \
  --options runtime \
  --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$DEVELOPER_ID" \
  "$APP_PATH"

/usr/bin/codesign --verify --deep --strict "$APP_PATH"

TMP_DIR="$(mktemp -d /tmp/txtin_dmg.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -R "$APP_PATH" "$TMP_DIR/${APP_NAME}.app"
ln -s /Applications "$TMP_DIR/Applications"

rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$TMP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Signing DMG..."
/usr/bin/codesign --force \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID" \
  "$DMG_PATH"

/usr/bin/codesign --verify --strict "$DMG_PATH"

if [[ "$NOTARIZE" == "true" ]]; then
  notarize_dmg "$DMG_PATH"
  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/bin/xcrun stapler validate "$DMG_PATH"
fi

echo
echo "Done: $DMG_PATH"
echo "Gatekeeper check:"
/usr/sbin/spctl --assess --type open --context context:primary-signature "$DMG_PATH" 2>&1 || true
