#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPARKLE_BIN="${SPARKLE_BIN:-}"
DOWNLOAD_PREFIX="${HALO_SPARKLE_DOWNLOAD_URL_PREFIX:-}"
WORK_ROOT="${HALO_SPARKLE_GATE3_DIR:-$HOME/Desktop/Halo-Sparkle-Gate3}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install/open the full Xcode app first." >&2
  exit 1
fi

DEVELOPER_DIR_ACTIVE="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR_ACTIVE" == "/Library/Developer/CommandLineTools" || ! -d "$DEVELOPER_DIR_ACTIVE" ]]; then
  echo "Gate 3 requires the full Xcode developer directory, not Command Line Tools." >&2
  echo "Current developer directory: ${DEVELOPER_DIR_ACTIVE:-<none>}" >&2
  echo "Fix with: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if [[ -z "$SPARKLE_BIN" || ! -x "$SPARKLE_BIN/generate_appcast" ]]; then
  echo "Set SPARKLE_BIN to the bin directory from the full Sparkle 2.9.6 distribution." >&2
  echo "Example: SPARKLE_BIN=$HOME/Downloads/Sparkle-2.9.6/bin" >&2
  exit 1
fi

if [[ -z "$DOWNLOAD_PREFIX" || "$DOWNLOAD_PREFIX" != https://* ]]; then
  echo "Set HALO_SPARKLE_DOWNLOAD_URL_PREFIX to the raw HTTPS folder URL that will host the Gate 3 archives." >&2
  echo "Example: https://halo.redstoneinvente.com/updates/gate3/" >&2
  exit 1
fi

if [[ "$DOWNLOAD_PREFIX" == *'['* || "$DOWNLOAD_PREFIX" == *']'* || "$DOWNLOAD_PREFIX" == *'('* || "$DOWNLOAD_PREFIX" == *')'* ]]; then
  echo "HALO_SPARKLE_DOWNLOAD_URL_PREFIX looks like a Markdown link. Pass only the raw https:// URL." >&2
  exit 1
fi

if [[ "$DOWNLOAD_PREFIX" != */ ]]; then
  DOWNLOAD_PREFIX="$DOWNLOAD_PREFIX/"
fi

SECRETS="$ROOT/Halo/Config/Secrets.xcconfig"
if [[ ! -f "$SECRETS" ]]; then
  echo "Missing $SECRETS" >&2
  echo "Create it with HALO_SPARKLE_PUBLIC_KEY and HALO_SPARKLE_FEED_URL before running Gate 3." >&2
  exit 1
fi

if ! grep -Eq '^HALO_SPARKLE_PUBLIC_KEY[[:space:]]*=[[:space:]]*[^[:space:]]+' "$SECRETS"; then
  echo "HALO_SPARKLE_PUBLIC_KEY is missing from Secrets.xcconfig." >&2
  exit 1
fi

if ! grep -Eq '^HALO_SPARKLE_FEED_URL[[:space:]]*=' "$SECRETS"; then
  echo "HALO_SPARKLE_FEED_URL is missing from Secrets.xcconfig." >&2
  exit 1
fi

rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT/base-derived" "$WORK_ROOT/candidate-derived" "$WORK_ROOT/updates" "$WORK_ROOT/install"

build_halo() {
  local version="$1"
  local build="$2"
  local derived="$3"
  local log="$derived/xcodebuild.log"

  echo "Building Halo $version ($build)…" >&2
  echo "Xcode: $(xcodebuild -version | tr '\n' ' ')" >&2
  echo "Developer dir: $DEVELOPER_DIR_ACTIVE" >&2

  if ! xcodebuild \
    -project "$ROOT/Halo.xcodeproj" \
    -scheme Halo \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived" \
    -allowProvisioningUpdates \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build" \
    build 2>&1 | tee "$log" >&2; then
      echo >&2
      echo "Xcode failed while building Halo $version ($build)." >&2
      echo "Full build log: $log" >&2
      echo "First signing-related diagnostics:" >&2
      grep -E -m 20 'error:|CodeSign|codesign|provision|certificate|identity|Signing' "$log" >&2 || true
      exit 1
  fi

  local app="$derived/Build/Products/Release/Halo.app"
  if [[ ! -d "$app" ]]; then
    echo "Expected app not found after a successful xcodebuild: $app" >&2
    exit 1
  fi

  if ! codesign --verify --deep --strict --verbose=2 "$app" >&2; then
    echo "Built Halo.app exists but failed code-sign verification: $app" >&2
    exit 1
  fi

  local actual_version actual_build feed key
  actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
  actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")"
  feed="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist")"
  key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$app/Contents/Info.plist")"

  [[ "$actual_version" == "$version" ]] || { echo "Version mismatch: $actual_version" >&2; exit 1; }
  [[ "$actual_build" == "$build" ]] || { echo "Build mismatch: $actual_build" >&2; exit 1; }
  [[ "$feed" == https://* ]] || { echo "Built app has invalid SUFeedURL: $feed" >&2; exit 1; }
  [[ -n "$key" && "$key" != *'$('* ]] || { echo "Built app has invalid SUPublicEDKey" >&2; exit 1; }

  printf '%s\n' "$app"
}

BASE_APP="$(build_halo 0.2.0 200 "$WORK_ROOT/base-derived")"
CANDIDATE_APP="$(build_halo 0.2.1 201 "$WORK_ROOT/candidate-derived")"

# Keep a copy of the baseline app that you can launch for the end-to-end update test.
ditto "$BASE_APP" "$WORK_ROOT/install/Halo.app"

# Keep both full archives so generate_appcast can produce a proper version history and delta when compatible.
ditto -c -k --sequesterRsrc --keepParent "$BASE_APP" "$WORK_ROOT/updates/Halo-0.2.0.zip"
ditto -c -k --sequesterRsrc --keepParent "$CANDIDATE_APP" "$WORK_ROOT/updates/Halo-0.2.1.zip"

cat > "$WORK_ROOT/updates/Halo-0.2.1.md" <<'EOF'
# Halo 0.2.1

Gate 3 Sparkle update validation build.

- Validates Ed25519-signed update delivery.
- Validates download, installation, relaunch, and version transition.
EOF

"$SPARKLE_BIN/generate_appcast" \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  --release-notes-url-prefix "$DOWNLOAD_PREFIX" \
  "$WORK_ROOT/updates"

APPCAST="$WORK_ROOT/updates/appcast.xml"
[[ -f "$APPCAST" ]] || { echo "generate_appcast did not create appcast.xml" >&2; exit 1; }
grep -q 'sparkle:version="201"' "$APPCAST" || { echo "Appcast is missing build 201" >&2; exit 1; }
grep -q 'sparkle:edSignature=' "$APPCAST" || { echo "Appcast has no Ed25519 signature" >&2; exit 1; }

echo
echo "Gate 3 artifacts are ready:"
echo "  Base app:     $WORK_ROOT/install/Halo.app"
echo "  Update files: $WORK_ROOT/updates"
echo
echo "Upload the CONTENTS of the updates folder to:"
echo "  $DOWNLOAD_PREFIX"
echo
echo "Then launch the base app and use Halo → Check for Updates…"
echo "Expected result: 0.2.0 (200) → 0.2.1 (201), install, relaunch, and launch cleanly."
