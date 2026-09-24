#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derived-data-web}"
OUTPUT="${1:-$ROOT/WebRepresentation}"

xcodebuild \
  -project "$ROOT/Halo.xcodeproj" \
  -scheme Halo \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Halo.app"
if [[ ! -d "$APP" ]]; then
  echo "Halo.app was not found at $APP" >&2
  exit 1
fi

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

open -n "$APP" --args --export-web-representation "$OUTPUT"

echo "Halo launched in web export mode."
echo "Output: $OUTPUT"
