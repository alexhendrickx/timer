#!/usr/bin/env bash
# Build, sign and upload Timer to App Store Connect (TestFlight).
#
#   tool/release.sh ios          # iPhone build -> TestFlight
#   tool/release.sh macos        # Mac build    -> TestFlight (Mac)
#   tool/release.sh all
#   DRY_RUN=1 tool/release.sh ios  # archive + export locally, no upload
#
# Needs config/release.env (copy config/release.env.example) and
# config/dart_defines.json (copy config/dart_defines.example.json).
# Build number = UTC timestamp, so every upload is unique.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-}"
[[ "$TARGET" =~ ^(ios|macos|all)$ ]] || { echo "usage: $0 ios|macos|all"; exit 64; }

[[ -f config/release.env ]] || { echo "missing config/release.env (see config/release.env.example)"; exit 1; }
# shellcheck disable=SC1091
source config/release.env
: "${ASC_KEY_ID:?set in config/release.env}"
: "${ASC_ISSUER_ID:?set in config/release.env}"
: "${ASC_KEY_PATH:?set in config/release.env}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "ASC key not found: $ASC_KEY_PATH"; exit 1; }

DEFINES=config/dart_defines.json
[[ -f "$DEFINES" ]] || { echo "missing $DEFINES — a build without it ships with sync OFF"; exit 1; }

BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
DESTINATION=upload
[[ "${DRY_RUN:-0}" == 1 ]] && DESTINATION=export

AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

export_opts() { # $1 = output path; same options work for both platforms
  sed "s#<string>export</string>#<string>$DESTINATION</string>#" ios/ExportOptions.plist > "$1"
}

flutter_config() { # $1 = ios|macos
  flutter build "$1" --release --config-only --build-number="$BUILD_NUMBER" \
    --dart-define-from-file="$DEFINES"
}

archive_and_ship() { # $1 = ios|macos, $2 = xcodebuild destination
  local dir="build/$1"
  xcodebuild -workspace "$1/Runner.xcworkspace" -scheme Runner -configuration Release \
    -destination "$2" -archivePath "$dir/Runner.xcarchive" archive "${AUTH[@]}"
  export_opts "$dir/ExportOptions.gen.plist"
  xcodebuild -exportArchive -archivePath "$dir/Runner.xcarchive" \
    -exportPath "$dir/export" -exportOptionsPlist "$dir/ExportOptions.gen.plist" "${AUTH[@]}"
}

release_ios()   { echo "==> iOS build $BUILD_NUMBER";   flutter_config ios;   archive_and_ship ios   "generic/platform=iOS"; }
release_macos() { echo "==> macOS build $BUILD_NUMBER"; flutter_config macos; archive_and_ship macos "generic/platform=macOS"; }

case "$TARGET" in
  ios) release_ios ;;
  macos) release_macos ;;
  all) release_ios; release_macos ;;
esac
echo "==> done ($DESTINATION). Build $BUILD_NUMBER shows in App Store Connect → TestFlight after processing."
