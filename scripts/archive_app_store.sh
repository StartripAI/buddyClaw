#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
PROJECT_PATH="$ROOT_DIR/BuddyClaw.xcodeproj"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/app-store}"
ARCHIVE_PATH="$OUTPUT_DIR/BuddyClawAppStore.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"
LOG_DIR="$OUTPUT_DIR/logs"
TEAM_ID="${BUDDYCLAW_DEVELOPMENT_TEAM:-}"
EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/AppStoreExportOptions.plist"
SKIP_EXPORT=0
ALLOW_PROVISIONING_UPDATES=1

usage() {
  cat <<EOF
Usage: $(basename "$0") [--team-id <team-id>] [--output-dir <dir>] [--skip-export] [--no-provisioning-updates]

Examples:
  $(basename "$0") --team-id ABC123XYZ9
  $(basename "$0") --skip-export --output-dir ./dist/app-store-local
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id)
      TEAM_ID="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      ARCHIVE_PATH="$OUTPUT_DIR/BuddyClawAppStore.xcarchive"
      EXPORT_PATH="$OUTPUT_DIR/export"
      LOG_DIR="$OUTPUT_DIR/logs"
      EXPORT_OPTIONS_PLIST="$OUTPUT_DIR/AppStoreExportOptions.plist"
      shift 2
      ;;
    --skip-export)
      SKIP_EXPORT=1
      shift
      ;;
    --no-provisioning-updates)
      ALLOW_PROVISIONING_UPDATES=0
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

if [[ "$SKIP_EXPORT" -eq 0 && -z "$TEAM_ID" ]]; then
  echo "Missing --team-id or BUDDYCLAW_DEVELOPMENT_TEAM." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

if [[ "$SKIP_EXPORT" -eq 0 ]]; then
cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF
fi

pushd "$ROOT_DIR" >/dev/null

if [[ ! -d "$PROJECT_PATH" ]]; then
  ruby scripts/generate_xcodeproj.rb
fi

echo "==> Resolving package dependencies"
DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild -resolvePackageDependencies \
  -project "$PROJECT_PATH" \
  | tee "$LOG_DIR/resolve-packages.log"

echo "==> Archiving Mac App Store build"
XCODEBUILD_ARCHIVE_ARGS=(
  -project "$PROJECT_PATH"
  -scheme BuddyClawAppStore
  -configuration Release
  -destination 'generic/platform=macOS'
  -archivePath "$ARCHIVE_PATH"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" -eq 1 ]]; then
  XCODEBUILD_ARCHIVE_ARGS+=(-allowProvisioningUpdates)
fi

if [[ -n "$TEAM_ID" ]]; then
  XCODEBUILD_ARCHIVE_ARGS+=(DEVELOPMENT_TEAM="$TEAM_ID")
fi

DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
  "${XCODEBUILD_ARCHIVE_ARGS[@]}" \
  archive \
  | tee "$LOG_DIR/archive.log"

if [[ "$SKIP_EXPORT" -eq 0 ]]; then
  echo "==> Exporting App Store package"
  XCODEBUILD_EXPORT_ARGS=(
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_PATH"
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  )

  if [[ "$ALLOW_PROVISIONING_UPDATES" -eq 1 ]]; then
    XCODEBUILD_EXPORT_ARGS+=(-allowProvisioningUpdates)
  fi

  DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild \
    "${XCODEBUILD_EXPORT_ARGS[@]}" \
    | tee "$LOG_DIR/export.log"
fi

echo "App Store artifacts:"
echo "  Archive: $ARCHIVE_PATH"
if [[ "$SKIP_EXPORT" -eq 0 ]]; then
  echo "  Export:  $EXPORT_PATH"
else
  echo "  Export:  skipped (--skip-export)"
fi
echo "  Logs:    $LOG_DIR"

popd >/dev/null
