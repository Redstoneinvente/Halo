from pathlib import Path

p = Path('Halo.xcodeproj/project.pbxproj')
s = p.read_text()

LINK_ID = 'A11C0F1A0000000000000341'
PRODUCT_ID = 'A11C0F1A0000000000000342'
EMBED_BUILD_ID = 'A11C0F1A0000000000000344'
EMBED_PHASE_ID = 'A11C0F1A0000000000000345'

# 1) A distinct PBXBuildFile for the copy phase. The Frameworks build phase entry remains link-only.
embed_build = f'\t\t{EMBED_BUILD_ID} /* Sparkle in Embed Frameworks */ = {{isa = PBXBuildFile; productRef = {PRODUCT_ID} /* Sparkle */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};\n'
if f'{EMBED_BUILD_ID} /* Sparkle in Embed Frameworks */' not in s:
    anchor = f'\t\t{LINK_ID} /* Sparkle in Frameworks */ = {{isa = PBXBuildFile; productRef = {PRODUCT_ID} /* Sparkle */; }};\n'
    if anchor not in s:
        raise SystemExit('Sparkle link PBXBuildFile anchor not found')
    s = s.replace(anchor, anchor + embed_build, 1)

# 2) Add a Copy Files phase targeting the app Frameworks directory (dstSubfolderSpec 10).
if '/* Begin PBXCopyFilesBuildPhase section */' not in s:
    section = f'''/* Begin PBXCopyFilesBuildPhase section */
\t\t{EMBED_PHASE_ID} /* Embed Frameworks */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 10;
\t\t\tfiles = (
\t\t\t\t{EMBED_BUILD_ID} /* Sparkle in Embed Frameworks */,
\t\t\t);
\t\t\tname = "Embed Frameworks";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

'''
    anchor = '/* Begin PBXFileReference section */\n'
    if anchor not in s:
        raise SystemExit('PBXFileReference section anchor not found')
    s = s.replace(anchor, section + anchor, 1)
elif f'{EMBED_PHASE_ID} /* Embed Frameworks */' not in s:
    raise SystemExit('Existing PBXCopyFilesBuildPhase section needs manual merge')

# 3) Make the app target execute the embed phase after Resources.
phase_entry = f'\t\t\t\t{EMBED_PHASE_ID} /* Embed Frameworks */,\n'
if phase_entry not in s:
    target_phases = '''\t\t\tbuildPhases = (
\t\t\t\t000000000000000000000007 /* Sources */,
\t\t\t\t000000000000000000000008 /* Frameworks */,
\t\t\t\t000000000000000000000009 /* Resources */,
\t\t\t);'''
    replacement = '''\t\t\tbuildPhases = (
\t\t\t\t000000000000000000000007 /* Sources */,
\t\t\t\t000000000000000000000008 /* Frameworks */,
\t\t\t\t000000000000000000000009 /* Resources */,
''' + phase_entry + '''\t\t\t);'''
    if target_phases not in s:
        raise SystemExit('Halo target build phases anchor not found')
    s = s.replace(target_phases, replacement, 1)

# 4) Sparkle is @rpath/Sparkle.framework. Ensure the normal macOS app Frameworks directory is an rpath.
runpath = '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";\n'
# Add once in Halo Debug and once in Halo Release, directly before MARKETING_VERSION.
needed = 2 - s.count('LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";')
while needed > 0:
    marker = '\t\t\t\tMARKETING_VERSION = 0.2.0;\n'
    start = 0
    inserted = False
    while True:
        idx = s.find(marker, start)
        if idx < 0:
            break
        # Do not duplicate in the same buildSettings block.
        block_start = s.rfind('\t\t\tbuildSettings = {', 0, idx)
        block = s[block_start:idx]
        if 'LD_RUNPATH_SEARCH_PATHS' not in block:
            s = s[:idx] + runpath + s[idx:]
            inserted = True
            needed -= 1
            break
        start = idx + len(marker)
    if not inserted:
        break

if s.count('LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";') < 2:
    raise SystemExit('Failed to add Sparkle framework runpath to both Halo configurations')

p.write_text(s)
print('Sparkle Embed & Sign phase and framework runpaths applied.')
