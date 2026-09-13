from pathlib import Path
import re

p = Path('Halo.xcodeproj/project.pbxproj')
s = p.read_text()

# Remove the manual SwiftPM copy/embed wiring that causes Xcode to look for
# a synthetic "Sparkle-product" path. Keep the normal SPM link dependency.
s, n1 = re.subn(
    r'^\t\tA11C0F1A0000000000000356 /\* Sparkle in Embed Frameworks \*/ = \{isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /\* Sparkle \*/; settings = \{ATTRIBUTES = \(CodeSignOnCopy, RemoveHeadersOnCopy, \); \}; \};\n',
    '', s, count=1, flags=re.M
)

s, n2 = re.subn(
    r'/\* Begin PBXCopyFilesBuildPhase section \*/\n\t\tA11C0F1A0000000000000357 /\* Embed Frameworks \*/ = \{\n(?:.*\n)*?\t\t\};\n/\* End PBXCopyFilesBuildPhase section \*/\n\n',
    '', s, count=1
)

s, n3 = re.subn(
    r'^\t\t\t\tA11C0F1A0000000000000357 /\* Embed Frameworks \*/,\n',
    '', s, count=1, flags=re.M
)

if n1 != 1 or n2 != 1 or n3 != 1:
    raise SystemExit(f'Unexpected manual embed structure: buildFile={n1}, phase={n2}, targetEntry={n3}')

# The actual runtime issue from the original dyld trace was that Halo did not
# search Contents/Frameworks. Preserve/require this app runpath.
if '@executable_path/../Frameworks' not in s:
    raise SystemExit('Frameworks runpath missing; refusing to remove embed phase')

if 'Sparkle in Frameworks' not in s or 'productName = Sparkle;' not in s:
    raise SystemExit('Normal Sparkle SPM link dependency is missing')

p.write_text(s)
print('Removed manual Sparkle copy phase; retained SPM link + Frameworks runpath.')
