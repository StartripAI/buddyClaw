#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
CODESIGN_IDENTITY="${BUDDYCLAW_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${BUDDYCLAW_NOTARY_PROFILE:-}"
SKIP_NOTARIZE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") --codesign-identity <identity> --notary-profile <profile> [--output-dir <dir>] [--skip-notarize]

Examples:
  $(basename "$0") --codesign-identity "Developer ID Application: Example, Inc. (TEAMID)" --notary-profile buddyclaw-notary
  $(basename "$0") --codesign-identity - --output-dir ./dist/local --skip-notarize
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codesign-identity)
      CODESIGN_IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$CODESIGN_IDENTITY" ]]; then
  echo "Missing --codesign-identity (use '-' for ad-hoc signing)." >&2
  exit 1
fi

if [[ "$SKIP_NOTARIZE" -eq 0 && -z "$NOTARY_PROFILE" ]]; then
  echo "Missing --notary-profile for notarized release. Pass --skip-notarize for local dry runs." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
LOG_DIR="$OUTPUT_DIR/logs"
mkdir -p "$LOG_DIR"

pushd "$ROOT_DIR" >/dev/null

echo "==> Validating runtime sprites"
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift scripts/validate_runtime_sprites.swift | tee "$LOG_DIR/sprite-validation.log"

echo "==> Cleaning SwiftPM build artifacts"
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift package clean | tee "$LOG_DIR/swift-package-clean.log"

echo "==> Building release binary"
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift build -c release | tee "$LOG_DIR/swift-build.log"
BUILD_DIR="$(DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift build -c release --show-bin-path)"
BINARY_PATH="$BUILD_DIR/BuddyClaw"
RESOURCE_BUNDLE="$BUILD_DIR/DesktopBuddy_DesktopBuddy.bundle"

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "Release binary not found at $BINARY_PATH" >&2
  exit 1
fi

if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "Resource bundle not found at $RESOURCE_BUNDLE" >&2
  exit 1
fi

APP_PATH="$OUTPUT_DIR/BuddyClaw.app"
STAGING_DIR="$OUTPUT_DIR/staging"
DMG_PATH="$OUTPUT_DIR/BuddyClaw.dmg"
ZIP_PATH="$OUTPUT_DIR/BuddyClaw.zip"

rm -rf "$APP_PATH" "$STAGING_DIR" "$DMG_PATH" "$ZIP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$STAGING_DIR"

cp "$ROOT_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$BINARY_PATH" "$APP_PATH/Contents/MacOS/BuddyClaw"
ditto "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/DesktopBuddy_DesktopBuddy.bundle"
rm -rf "$APP_PATH/Contents/Resources/DesktopBuddy_DesktopBuddy.bundle/RuntimeSprites"

if find "$APP_PATH/Contents/Resources" \( -name 'PROMPTS.md' -o -name 'REWORK_PROMPTS.md' -o -name 'process_v2.py' -o -path '*/_backup_originals/*' -o -name 'RuntimeSprites' \) | grep -q .; then
  echo "Authoring or legacy assets leaked into the release app bundle." >&2
  exit 1
fi

echo "==> Signing app"
if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP_PATH"
else
  codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_PATH"
fi
codesign --verify --deep --strict "$APP_PATH" | tee "$LOG_DIR/codesign-verify.log"

echo "==> Creating app archive"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  echo "==> Notarizing app"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait | tee "$LOG_DIR/notary-app.log"
  xcrun stapler staple "$APP_PATH" | tee "$LOG_DIR/stapler-app.log"
fi

echo "==> Creating DMG"
cp -R "$APP_PATH" "$STAGING_DIR/"
hdiutil create -volname "BuddyClaw" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" | tee "$LOG_DIR/hdiutil.log"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  echo "==> Notarizing DMG"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait | tee "$LOG_DIR/notary-dmg.log"
  xcrun stapler staple "$DMG_PATH" | tee "$LOG_DIR/stapler-dmg.log"
fi

if [[ "$SKIP_NOTARIZE" -eq 0 && "$CODESIGN_IDENTITY" != "-" ]]; then
  echo "==> Running Gatekeeper assessment"
  spctl --assess --verbose=4 "$APP_PATH" | tee "$LOG_DIR/spctl-app.log"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH" | tee "$LOG_DIR/spctl-dmg.log"
else
  echo "==> Skipping Gatekeeper assessment for local dry run"
fi

echo "Release artifacts:"
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"
echo "  Logs: $LOG_DIR"

popd >/dev/null
