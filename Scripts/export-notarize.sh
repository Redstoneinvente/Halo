#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 1 ]]; then
  echo "Usage: bash Scripts/export-notarize.sh NOTARYTOOL_KEYCHAIN_PROFILE" >&2
  exit 1
fi
xcodebuild -exportArchive -archivePath build/Halo.xcarchive -exportOptionsPlist Scripts/ExportOptions.plist -exportPath build/export
ditto -c -k --keepParent build/export/Halo.app build/Halo-notarization.zip
xcrun notarytool submit build/Halo-notarization.zip --keychain-profile "$1" --wait
xcrun stapler staple build/export/Halo.app
spctl --assess --type execute --verbose build/export/Halo.app
ditto -c -k --keepParent build/export/Halo.app build/Halo-signed.zip
echo "Signed, stapled archive: build/Halo-signed.zip"
