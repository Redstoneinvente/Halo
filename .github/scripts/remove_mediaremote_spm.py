from pathlib import Path
import re

ROOT = Path('.')
workspace = ROOT / 'Halo/Core/WorkspaceStore.swift'
controller = ROOT / 'Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/MediaController.swift'
pbx = ROOT / 'Halo.xcodeproj/project.pbxproj'

# 1. WorkspaceStore must use the adapter types compiled directly into Halo.
s = workspace.read_text()
s = s.replace('import MediaRemoteAdapter\n', '')
workspace.write_text(s)

# 2. Make the upstream controller work both as a Swift package and when compiled directly into Halo.
s = controller.read_text()
old_script = '''    private var perlScriptPath: String? {
        guard let path = Bundle.module.path(forResource: "run", ofType: "pl") else {
            assertionFailure("run.pl script not found in bundle resources.")
            return nil
        }
        return path
    }
'''
new_script = '''    private var perlScriptPath: String? {
#if SWIFT_PACKAGE
        guard let path = Bundle.module.path(forResource: "run", ofType: "pl") else {
            assertionFailure("run.pl script not found in bundle resources.")
            return nil
        }
        return path
#else
        guard let path = Bundle.main.path(forResource: "run", ofType: "pl") else {
            assertionFailure("run.pl script not found in Halo resources.")
            return nil
        }
        return path
#endif
    }
'''
if old_script not in s:
    if 'Bundle.main.path(forResource: "run", ofType: "pl")' not in s:
        raise SystemExit('MediaController perlScriptPath block not found')
else:
    s = s.replace(old_script, new_script, 1)

old_library = '''    private var libraryPath: String? {
        let bundle = Bundle(for: MediaController.self)
        guard let path = bundle.executablePath else {
            assertionFailure("Could not locate the executable path for the MediaRemoteAdapter framework.")
            return nil
        }
        return path
    }
'''
new_library = '''    private var libraryPath: String? {
#if SWIFT_PACKAGE
        let bundle = Bundle(for: MediaController.self)
        guard let path = bundle.executablePath else {
            assertionFailure("Could not locate the executable path for the MediaRemoteAdapter framework.")
            return nil
        }
        return path
#else
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
#endif
    }
'''
if old_library not in s:
    if 'libHaloMediaRemoteBridge.dylib' not in s:
        raise SystemExit('MediaController libraryPath block not found')
else:
    s = s.replace(old_library, new_library, 1)
controller.write_text(s)

# 3. Replace the SwiftPM product with direct source membership + a build phase that creates the bridge dylib.
p = pbx.read_text()

# Remove the package framework build file.
p = re.sub(r'\n\t\tA11C0F1A0000000000000380 /\* MediaRemoteAdapter in Frameworks \*/ = \{isa = PBXBuildFile; productRef = A11C0F1A0000000000000381 /\* MediaRemoteAdapter \*/; \};', '', p)

# Add direct-source build/file references if needed.
build_marker = '/* End PBXBuildFile section */'
build_entries = '''\t\tA11C0F1A0000000000000390 /* Vendor MediaController.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000392 /* Vendor MediaController.swift */; };
\t\tA11C0F1A0000000000000391 /* Vendor TrackInfo.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000393 /* Vendor TrackInfo.swift */; };
'''
if 'A11C0F1A0000000000000390 /* Vendor MediaController.swift in Sources */' not in p:
    p = p.replace(build_marker, build_entries + build_marker, 1)

file_marker = '/* End PBXFileReference section */'
file_entries = '''\t\tA11C0F1A0000000000000392 /* Vendor MediaController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/MediaController.swift"; sourceTree = SOURCE_ROOT; };
\t\tA11C0F1A0000000000000393 /* Vendor TrackInfo.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "Vendor/MediaRemoteAdapter/Sources/MediaRemoteAdapter/TrackInfo.swift"; sourceTree = SOURCE_ROOT; };
'''
if 'A11C0F1A0000000000000392 /* Vendor MediaController.swift */' not in p:
    p = p.replace(file_marker, file_entries + file_marker, 1)

# Remove it from the Frameworks phase.
p = p.replace('\n\t\t\t\tA11C0F1A0000000000000380 /* MediaRemoteAdapter in Frameworks */,', '')

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

# Remove package product dependency from Halo target.
p = p.replace('\n\t\t\t\tA11C0F1A0000000000000381 /* MediaRemoteAdapter */,', '')

# Remove local package reference from project packageReferences.
p = p.replace('\n\t\t\t\tA11C0F1A0000000000000382 /* XCLocalSwiftPackageReference "Vendor/MediaRemoteAdapter" */,', '')

# Add Swift files to the app's Sources phase.
sources_anchor = '''\t\t\tfiles = (
\t\t\t\t0000000000000000000002C6 /* NotchEngine/DisplayClock.swift in Sources */,'''
sources_replacement = '''\t\t\tfiles = (
\t\t\t\tA11C0F1A0000000000000390 /* Vendor MediaController.swift in Sources */,
\t\t\t\tA11C0F1A0000000000000391 /* Vendor TrackInfo.swift in Sources */,
\t\t\t\t0000000000000000000002C6 /* NotchEngine/DisplayClock.swift in Sources */,'''
if 'A11C0F1A0000000000000390 /* Vendor MediaController.swift in Sources */,' not in p.split('/* Begin PBXSourcesBuildPhase section */',1)[1]:
    if sources_anchor not in p:
        raise SystemExit('Halo Sources phase anchor not found')
    p = p.replace(sources_anchor, sources_replacement, 1)

# Remove local Swift package section entirely.
p = re.sub(r'\n/\* Begin XCLocalSwiftPackageReference section \*/\n.*?/\* End XCLocalSwiftPackageReference section \*/\n', '\n', p, flags=re.S)

# Remove the MediaRemoteAdapter package product dependency block, leaving Sparkle intact.
p = re.sub(
    r'\n\t\tA11C0F1A0000000000000381 /\* MediaRemoteAdapter \*/ = \{\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = A11C0F1A0000000000000382 /\* XCLocalSwiftPackageReference "Vendor/MediaRemoteAdapter" \*/;\n\t\t\tproductName = MediaRemoteAdapter;\n\t\t\};',
    '', p)

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

# Hard contract: MediaRemoteAdapter is no longer an Xcode package dependency.
final = pbx.read_text()
for forbidden in [
    'XCLocalSwiftPackageReference "Vendor/MediaRemoteAdapter"',
    'MediaRemoteAdapter in Frameworks',
    'A11C0F1A0000000000000381 /* MediaRemoteAdapter */',
]:
    if forbidden in final:
        raise SystemExit(f'Forbidden package reference remains: {forbidden}')

if 'Build native MediaRemote bridge' not in final:
    raise SystemExit('Native bridge build phase missing')
if 'Vendor MediaController.swift in Sources' not in final or 'Vendor TrackInfo.swift in Sources' not in final:
    raise SystemExit('Direct adapter Swift sources are not in Halo target')
if 'import MediaRemoteAdapter' in workspace.read_text():
    raise SystemExit('WorkspaceStore still imports MediaRemoteAdapter')

print('MediaRemoteAdapter SwiftPM dependency removed; native Halo bridge installed.')
