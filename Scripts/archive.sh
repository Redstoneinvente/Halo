#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 1 ]]; then
  echo "Usage: bash Scripts/archive.sh APPLE_DEVELOPMENT_TEAM_ID" >&2
  exit 1
fi
xcodebuild -project Halo.xcodeproj -scheme Halo -configuration Release -archivePath build/Halo.xcarchive DEVELOPMENT_TEAM="$1" archive
echo "Archive created. Use Xcode Organizer to distribute with Developer ID and notarize."
