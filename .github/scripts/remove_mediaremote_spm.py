from pathlib import Path
import re

ROOT = Path('.')
workspace = ROOT / 'Halo/Core/WorkspaceStore.swift'
vendor_controller = ROOT / 'Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/MediaController.swift'
vendor_track = ROOT / 'Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/TrackInfo.swift'
controller_dest = ROOT / 'Halo/Core/MediaRemoteController.swift'
track_dest = ROOT / 'Halo/Core/MediaRemoteTrackInfo.swift'
pbx = ROOT / 'Halo.xcodeproj/project.pbxproj'

# 1. WorkspaceStore uses bridge types compiled directly into the Halo target.
s = workspace.read_text()
s = s.replace('import MediaRemoteAdapter\n', '')
workspace.write_text(s)

# 2. Copy the adapter's Swift surface into Halo/Core and adapt only the package-specific paths.
s = vendor_controller.read_text()
old_script = '''    private var perlScriptPath: String? {
        guard let path = Bundle.module.path(forResource: "run", ofType: "pl") else {
            assertionFailure("run.pl script not found in bundle resources.")
            return nil
        }
        return path
    }
'''
new_script = '''    private var perlScriptPath: String? {
        guard let path = Bundle.main.path(forResource: "run", ofType: "pl") else {
            assertionFailure("run.pl script not found in Halo resources.")
            return nil
        }
        return path
    }
'''
if old_script not in s:
    # Accept a previously adapted source, but normalize it to Halo's direct-build form.
    start = s.find('    private var perlScriptPath: String? {')
    end = s.find('\n    private var libraryPath: String? {', start)
    if start < 0 or end < 0:
        raise SystemExit('MediaController perlScriptPath block not found')
    s = s[:start] + new_script.rstrip('\n') + s[end:]
else:
    s = s.replace(old_script, new_script, 1)

old_library_start = s.find('    private var libraryPath: String? {')
old_library_end = s.find('\n    @discardableResult', old_library_start)
if old_library_start < 0 or old_library_end < 0:
    raise SystemExit('MediaController libraryPath block not found')
new_library = '''    private var libraryPath: String? {
        guard let frameworksURL = Bundle.main.privateFrameworksURL else {
            assertionFailure("Could not locate Halo's Frameworks directory.")
            return nil
        }
        let url = frameworksURL.appendingPathComponent("libHaloMediaRemoteBridge.dylib")
        guard FileManager.default.fileExists(atPath: url.path) else {
            assertionFailure("Halo MediaRemote bridge dylib is missing at \\(url.path).")
            return nil
        }
        return url.path
    }
'''
s = s[:old_library_start] + new_library.rstrip('\n') + s[old_library_end:]

controller_dest.write_text(s)
track_dest.write_text(vendor_track.read_text())

# 3. Replace MediaRemoteAdapter SwiftPM with ordinary Halo source membership.
p = pbx.read_text()

# Remove package framework build file/reference from target/project.
p = re.sub(r'\n\t\tA11C0F1A0000000000000380 /\* MediaRemoteAdapter in Frameworks \*/ = \{isa = PBXBuildFile; productRef = A11C0F1A0000000000000381 /\* MediaRemoteAdapter \*/; \};', '', p)
p = p.replace('\n\t\t\t\tA11C0F1A0000000000000380 /* MediaRemoteAdapter in Frameworks */,', '')
p = p.replace('\n\t\t\t\tA11C0F1A0000000000000381 /* MediaRemoteAdapter */,', '')
p = p.replace('\n\t\t\t\tA11C0F1A0000000000000382 /* XCLocalSwiftPackageReference "Vendor/MediaRemoteAdapter" */,', '')
p = re.sub(r'\n/\* Begin XCLocalSwiftPackageReference section \*/\n.*?/\* End XCLocalSwiftPackageReference section \*/\n', '\n', p, flags=re.S)
p = re.sub(
    r'\n\t\tA11C0F1A0000000000000381 /\* MediaRemoteAdapter \*/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = A11C0F1A0000000000000382 /\* XCLocalSwiftPackageReference "Vendor/MediaRemoteAdapter" \*/;\n\t\t\tproductName = MediaRemoteAdapter;\n\t\t\};',
    '', p)

# Add build-file records.
build_marker = '/* End PBXBuildFile section */'
build_entries = '''\t\tA11C0F1A0000000000000390 /* Core/MediaRemoteController.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000392 /* Core/MediaRemoteController.swift */; };
\t\tA11C0F1A0000000000000391 /* Core/MediaRemoteTrackInfo.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000393 /* Core/MediaRemoteTrackInfo.swift */; };
'''
if 'A11C0F1A0000000000000390 /* Core/MediaRemoteController.swift in Sources */' not in p:
    if build_marker not in p:
        raise SystemExit('PBXBuildFile marker missing')
    p = p.replace(build_marker, build_entries + build_marker, 1)

# Add file refs with paths relative to the existing Halo group (path = Halo).
file_marker = '/* End PBXFileReference section */'
file_entries = '''\t\tA11C0F1A0000000000000392 /* Core/MediaRemoteController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/MediaRemoteController.swift; sourceTree = "<group>"; };
\t\tA11C0F1A0000000000000393 /* Core/MediaRemoteTrackInfo.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Core/MediaRemoteTrackInfo.swift; sourceTree = "<group>"; };
'''
if 'A11C0F1A0000000000000392 /* Core/MediaRemoteController.swift */' not in p:
    if file_marker not in p:
        raise SystemExit('PBXFileReference marker missing')
    p = p.replace(file_marker, file_entries + file_marker, 1)

# Add file refs to the concrete Halo PBXGroup so Xcode resolves their <group> paths.
halo_group_pattern = re.compile(
    r'(\t\t000000000000000000000003 /\* Halo \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)(.*?)(\t\t\t\);\n\t\t\tpath = Halo;)',
    re.S,
)
m = halo_group_pattern.search(p)
if not m:
    raise SystemExit('Halo PBXGroup not found')
group_body = m.group(2)
if 'A11C0F1A0000000000000392 /* Core/MediaRemoteController.swift */' not in group_body:
    group_body = (
        '\t\t\t\tA11C0F1A0000000000000392 /* Core/MediaRemoteController.swift */,\n'
        '\t\t\t\tA11C0F1A0000000000000393 /* Core/MediaRemoteTrackInfo.swift */,\n'
        + group_body
    )
    p = p[:m.start()] + m.group(1) + group_body + m.group(3) + p[m.end():]

# Add build-file records to the actual Halo PBXSourcesBuildPhase, scoped by phase ID.
sources_pattern = re.compile(
    r'(\t\t000000000000000000000007 /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = \(\n)(.*?)(\t\t\t\);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t\};)',
    re.S,
)
m = sources_pattern.search(p)
if not m:
    raise SystemExit('Halo PBXSourcesBuildPhase not found')
source_body = m.group(2)
if 'A11C0F1A0000000000000390 /* Core/MediaRemoteController.swift in Sources */' not in source_body:
    source_body = (
        '\t\t\t\tA11C0F1A0000000000000390 /* Core/MediaRemoteController.swift in Sources */,\n'
        '\t\t\t\tA11C0F1A0000000000000391 /* Core/MediaRemoteTrackInfo.swift in Sources */,\n'
        + source_body
    )
    p = p[:m.start()] + m.group(1) + source_body + m.group(3) + p[m.end():]

# Add the native bridge build phase to the Halo target.
target_phases = '''\t\t\tbuildPhases = (
\t\t\t\t000000000000000000000007 /* Sources */,
\t\t\t\t000000000000000000000008 /* Frameworks */,
\t\t\t\t000000000000000000000009 /* Resources */,
\t\t\t);'''
new_target_phases = '''\t\t\tbuildPhases = (
\t\t\t\t000000000000000000000007 /* Sources */,
\t\t\t\t000000000000000000000008 /* Frameworks */,
\t\t\t\t000000000000000000000009 /* Resources */,
\t\t\t\tA11C0F1A0000000000000394 /* Build native MediaRemote bridge */,
\t\t\t);'''
if 'A11C0F1A0000000000000394 /* Build native MediaRemote bridge */' not in p:
    if target_phases not in p:
        raise SystemExit('Halo buildPhases block not found')
    p = p.replace(target_phases, new_target_phases, 1)

# Build the tiny Objective-C dylib and copy run.pl directly into Halo.app.
if '/* Begin PBXShellScriptBuildPhase section */' not in p:
    shell_section = r'''/* Begin PBXShellScriptBuildPhase section */
		A11C0F1A0000000000000394 /* Build native MediaRemote bridge */ = {
			isa = PBXShellScriptBuildPhase;
			alwaysOutOfDate = 1;
			buildActionMask = 2147483647;
			files = (
			);
			inputPaths = (
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/MediaRemote.m",
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/MediaRemoteAdapter.m",
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/MediaRemoteAdapterKeys.m",
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/include/MediaRemote.h",
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/include/MediaRemoteAdapter.h",
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote/include/MediaRemoteAdapterKeys.h",
				"$(SRCROOT)/Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/Resources/run.pl",
			);
			name = "Build native MediaRemote bridge";
			outputPaths = (
				"$(TARGET_BUILD_DIR)/$(FRAMEWORKS_FOLDER_PATH)/libHaloMediaRemoteBridge.dylib",
				"$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/run.pl",
			);
			runOnlyForDeploymentPostprocessing = 0;
			shellPath = /bin/sh;
			shellScript = "set -euo pipefail\nSRC=\"$SRCROOT/Vendor/MediaRemoteAdapter/Sources/CIMediaRemote\"\nINC=\"$SRC/include\"\nFRAMEWORKS=\"$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH\"\nRESOURCES=\"$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH\"\nOUT=\"$FRAMEWORKS/libHaloMediaRemoteBridge.dylib\"\nmkdir -p \"$FRAMEWORKS\" \"$RESOURCES\" \"$DERIVED_FILE_DIR/HaloMediaRemoteBridge\"\nBUILT=\"\"\nfor ARCH in $ARCHS; do\n  PART=\"$DERIVED_FILE_DIR/HaloMediaRemoteBridge/libHaloMediaRemoteBridge-$ARCH.dylib\"\n  \"${CC:-/usr/bin/clang}\" -arch \"$ARCH\" -isysroot \"$SDKROOT\" -mmacosx-version-min=\"$MACOSX_DEPLOYMENT_TARGET\" -dynamiclib -fobjc-arc -fblocks -I\"$INC\" \"$SRC/MediaRemote.m\" \"$SRC/MediaRemoteAdapter.m\" \"$SRC/MediaRemoteAdapterKeys.m\" -framework Foundation -framework AppKit -install_name @rpath/libHaloMediaRemoteBridge.dylib -o \"$PART\"\n  BUILT=\"$BUILT $PART\"\ndone\nset -- $BUILT\nif [ \"$#\" -gt 1 ]; then /usr/bin/lipo -create \"$@\" -output \"$OUT\"; else /bin/cp \"$1\" \"$OUT\"; fi\n/bin/cp \"$SRCROOT/Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/Resources/run.pl\" \"$RESOURCES/run.pl\"\n/bin/chmod 755 \"$RESOURCES/run.pl\"\nif [ \"${CODE_SIGNING_ALLOWED:-NO}\" = \"YES\" ]; then\n  IDENTITY=\"${EXPANDED_CODE_SIGN_IDENTITY:-}\"\n  if [ -n \"$IDENTITY\" ]; then /usr/bin/codesign --force --sign \"$IDENTITY\" --timestamp=none \"$OUT\"; else /usr/bin/codesign --force --sign - --timestamp=none \"$OUT\"; fi\nfi\n";
		};
/* End PBXShellScriptBuildPhase section */

'''
    marker = '/* Begin PBXSourcesBuildPhase section */'
    if marker not in p:
        raise SystemExit('PBXSourcesBuildPhase marker not found')
    p = p.replace(marker, shell_section + marker, 1)

pbx.write_text(p)

# Hard contract: no MediaRemote Swift package dependency, and both direct files truly belong to Halo.
final = pbx.read_text()
for forbidden in [
    'XCLocalSwiftPackageReference "Vendor/MediaRemoteAdapter"',
    'MediaRemoteAdapter in Frameworks',
    'A11C0F1A0000000000000381 /* MediaRemoteAdapter */',
]:
    if forbidden in final:
        raise SystemExit(f'Forbidden package reference remains: {forbidden}')

m = sources_pattern.search(final)
if not m:
    raise SystemExit('Final Halo Sources phase missing')
for required in [
    'A11C0F1A0000000000000390 /* Core/MediaRemoteController.swift in Sources */',
    'A11C0F1A0000000000000391 /* Core/MediaRemoteTrackInfo.swift in Sources */',
]:
    if required not in m.group(2):
        raise SystemExit(f'Direct bridge source not in Halo Sources phase: {required}')

m = halo_group_pattern.search(final)
if not m:
    raise SystemExit('Final Halo group missing')
for required in [
    'A11C0F1A0000000000000392 /* Core/MediaRemoteController.swift */',
    'A11C0F1A0000000000000393 /* Core/MediaRemoteTrackInfo.swift */',
]:
    if required not in m.group(2):
        raise SystemExit(f'Direct bridge file not in Halo group: {required}')

if 'Build native MediaRemote bridge' not in final:
    raise SystemExit('Native bridge build phase missing')
if 'import MediaRemoteAdapter' in workspace.read_text():
    raise SystemExit('WorkspaceStore still imports MediaRemoteAdapter')
if not controller_dest.exists() or not track_dest.exists():
    raise SystemExit('Halo bridge source files were not created')

print('MediaRemoteAdapter SwiftPM dependency removed; native Halo bridge sources are target members.')
