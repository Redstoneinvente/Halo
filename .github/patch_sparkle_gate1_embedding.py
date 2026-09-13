from pathlib import Path

p = Path('Halo.xcodeproj/project.pbxproj')
s = p.read_text()

if 'Sparkle in Embed Frameworks' in s:
    raise SystemExit('Sparkle embed wiring already present')

# 1) Build file for copy phase, using the existing SPM product ref.
anchor = '\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; };\n'
insert = anchor + '\t\tA11C0F1A0000000000000356 /* Sparkle in Embed Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };\n'
if s.count(anchor) != 1:
    raise SystemExit('Sparkle framework build-file anchor not found exactly once')
s = s.replace(anchor, insert, 1)

# 2) Copy phase into Contents/Frameworks.
phase_marker = '/* Begin PBXFrameworksBuildPhase section */\n'
copy_phase = '''/* Begin PBXCopyFilesBuildPhase section */
\t\tA11C0F1A0000000000000357 /* Embed Frameworks */ = {
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 10;
\t\t\tfiles = (
\t\t\t\tA11C0F1A0000000000000356 /* Sparkle in Embed Frameworks */,
\t\t\t);
\t\t\tname = "Embed Frameworks";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXCopyFilesBuildPhase section */

'''
if s.count(phase_marker) != 1:
    raise SystemExit('Framework phase marker not found exactly once')
s = s.replace(phase_marker, copy_phase + phase_marker, 1)

# 3) Add copy phase to the Halo application target only.
target_anchor = '''\t\t\tbuildPhases = (\n\t\t\t\t000000000000000000000007 /* Sources */,\n\t\t\t\t000000000000000000000008 /* Frameworks */,\n\t\t\t\t000000000000000000000009 /* Resources */,\n\t\t\t);\n'''
target_repl = '''\t\t\tbuildPhases = (\n\t\t\t\t000000000000000000000007 /* Sources */,\n\t\t\t\t000000000000000000000008 /* Frameworks */,\n\t\t\t\tA11C0F1A0000000000000357 /* Embed Frameworks */,\n\t\t\t\t000000000000000000000009 /* Resources */,\n\t\t\t);\n'''
if s.count(target_anchor) != 1:
    raise SystemExit('Halo build phase anchor not found exactly once')
s = s.replace(target_anchor, target_repl, 1)

# 4) Ensure both app target configs search the bundled Frameworks directory.
needle = '\t\t\t\tMARKETING_VERSION = 0.2.0;\n'
replacement = '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");\n' + needle
count = s.count(needle)
if count != 2:
    raise SystemExit(f'Expected two Halo MARKETING_VERSION anchors, found {count}')
s = s.replace(needle, replacement)

p.write_text(s)
print('Applied explicit Sparkle Embed & Sign + app Frameworks runpath for Gate 1.')
