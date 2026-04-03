#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/release}"
CODESIGN_IDENTITY="${BUDDYCLAW_CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${BUDDYCLAW_NOTARY_PROFILE:-}"
TEAM_ID="${BUDDYCLAW_DEVELOPMENT_TEAM:-}"
SKIP_NOTARIZE=0
PROJECT_PATH="$ROOT_DIR/BuddyClaw.xcodeproj"

usage() {
  cat <<EOF
Usage: $(basename "$0") --codesign-identity <identity> [--team-id <team-id>] [--notary-profile <profile>] [--output-dir <dir>] [--skip-notarize]

Examples:
  $(basename "$0") --codesign-identity "Developer ID Application: Example, Inc. (TEAMID)" --team-id TEAMID --notary-profile buddyclaw-notary
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
    --team-id)
      TEAM_ID="$2"
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

if [[ "$CODESIGN_IDENTITY" != "-" && -z "$TEAM_ID" ]]; then
  echo "Missing --team-id (or BUDDYCLAW_DEVELOPMENT_TEAM) for Developer ID release export." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
LOG_DIR="$OUTPUT_DIR/logs"
mkdir -p "$LOG_DIR"

pushd "$ROOT_DIR" >/dev/null

echo "==> Validating runtime sprites"
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun swift scripts/validate_runtime_sprites.swift | tee "$LOG_DIR/sprite-validation.log"

echo "==> Generating Xcode project"
ruby scripts/generate_xcodeproj.rb | tee "$LOG_DIR/generate-xcodeproj.log"

APP_PATH="$OUTPUT_DIR/BuddyClaw.app"
DMG_PATH="$OUTPUT_DIR/BuddyClaw.dmg"
ZIP_PATH="$OUTPUT_DIR/BuddyClaw.zip"
ARCHIVE_PATH="$OUTPUT_DIR/BuddyClawDirect.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/DirectExportOptions.plist"

rm -rf "$APP_PATH" "$DMG_PATH" "$ZIP_PATH" "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "==> Resolving package dependencies"
DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  | tee "$LOG_DIR/resolve-packages.log"

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
  echo "==> Archiving local dry-run build"
  DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme BuddyClawDirect \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    archive \
    | tee "$LOG_DIR/archive.log"

  APP_PATH="$ARCHIVE_PATH/Products/Applications/BuddyClaw.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Archived app not found at $APP_PATH" >&2
    exit 1
  fi

  ditto "$APP_PATH" "$OUTPUT_DIR/BuddyClaw.app"
  APP_PATH="$OUTPUT_DIR/BuddyClaw.app"
  codesign --force --deep --sign - "$APP_PATH"
else
  cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingCertificate</key>
  <string>${CODESIGN_IDENTITY}</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

  echo "==> Archiving Developer ID build"
  DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme BuddyClawDirect \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    archive \
    | tee "$LOG_DIR/archive.log"

  echo "==> Exporting Developer ID app"
  DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    | tee "$LOG_DIR/export.log"

  APP_PATH="$EXPORT_PATH/BuddyClaw.app"
fi

codesign --verify --deep --strict "$APP_PATH" | tee "$LOG_DIR/codesign-verify.log"

if find "$APP_PATH/Contents/Resources" \( -name 'PROMPTS.md' -o -name 'REWORK_PROMPTS.md' -o -name 'process_v2.py' -o -path '*/_backup_originals/*' -o -name 'RuntimeSprites' \) | grep -q .; then
  echo "Authoring or legacy assets leaked into the release app bundle." >&2
  exit 1
fi

echo "==> Creating app archive"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  echo "==> Notarizing app"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait | tee "$LOG_DIR/notary-app.log"
  xcrun stapler staple "$APP_PATH" | tee "$LOG_DIR/stapler-app.log"
fi

echo "==> Creating DMG"
TMP_DMG_DIR="$OUTPUT_DIR/dmg-staging"
rm -rf "$TMP_DMG_DIR"
mkdir -p "$TMP_DMG_DIR"
cp -R "$APP_PATH" "$TMP_DMG_DIR/"
hdiutil create -volname "BuddyClaw" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DMG_PATH" | tee "$LOG_DIR/hdiutil.log"
rm -rf "$TMP_DMG_DIR"

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
