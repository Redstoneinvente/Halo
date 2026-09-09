#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "macOS and Xcode are required for compilation and tests." >&2
  exit 1
fi
xcodebuild -project Halo.xcodeproj -scheme Halo -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build test
swift test
plutil -lint Halo/Halo.entitlements
