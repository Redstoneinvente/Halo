from pathlib import Path
import plistlib

root = Path('.')
plist_path = root / 'Halo/Info.plist'
project_path = root / 'Halo.xcodeproj/project.pbxproj'
base_path = root / 'Halo/Config/Base.xcconfig'
example_path = root / 'Halo/Config/Secrets.xcconfig.example'

# 1) Keep only build-setting placeholders in the committed plist.
with plist_path.open('rb') as f:
    plist = plistlib.load(f)
plist['CFBundleIconFile'] = 'AppIcon'
plist['HaloFirebaseAPIKey'] = '$(HALO_FIREBASE_API_KEY)'
plist['HaloLicenseSeatPublishableKey'] = '$(HALO_LICENSESEAT_PUBLISHABLE_KEY)'
plist['HaloLicenseSeatProductSlug'] = '$(HALO_LICENSESEAT_PRODUCT_SLUG)'
with plist_path.open('wb') as f:
    plistlib.dump(plist, f, sort_keys=False)

# 2) A committed base config provides safe defaults and optionally overlays local secrets.
base_path.parent.mkdir(parents=True, exist_ok=True)
base_path.write_text('''// Committed build configuration for Halo commercial services.\n// Real local values belong in Secrets.xcconfig, which is ignored by Git.\nHALO_FIREBASE_API_KEY =\nHALO_LICENSESEAT_PUBLISHABLE_KEY =\nHALO_LICENSESEAT_PRODUCT_SLUG = halo-macos-notch-utility\n\n#include? "Secrets.xcconfig"\n''')

example_path.write_text('''// Copy this file to Secrets.xcconfig and replace the placeholders.\nHALO_FIREBASE_API_KEY = YOUR_FIREBASE_WEB_API_KEY\nHALO_LICENSESEAT_PUBLISHABLE_KEY = pk_live_REPLACE_ME\nHALO_LICENSESEAT_PRODUCT_SLUG = halo-macos-notch-utility\n''')

# 3) Wire Base.xcconfig to the Halo target's Debug + Release configurations.
s = project_path.read_text()
file_ref_id = 'A11C0F1A0000000000000001'
file_ref_line = f'\t\t{file_ref_id} /* Base.xcconfig */ = {{isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Halo/Config/Base.xcconfig; sourceTree = SOURCE_ROOT; }};\n'
if file_ref_id not in s:
    marker = '/* End PBXFileReference section */'
    if marker not in s:
        raise SystemExit('PBXFileReference section not found')
    s = s.replace(marker, file_ref_line + marker, 1)

for config_id, label in [
    ('00000000000000000000000E', 'Debug'),
    ('00000000000000000000000F', 'Release'),
]:
    anchor = f'\t\t{config_id} /* {label} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n'
    replacement = anchor + f'\t\t\tbaseConfigurationReference = {file_ref_id} /* Base.xcconfig */;\n'
    if replacement in s:
        continue
    if anchor not in s:
        raise SystemExit(f'Target {label} build configuration not found')
    s = s.replace(anchor, replacement, 1)

project_path.write_text(s)
print('Commercial secret configuration corrected and wired to Xcode')
