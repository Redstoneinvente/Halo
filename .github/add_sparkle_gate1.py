from pathlib import Path

project = Path('Halo.xcodeproj/project.pbxproj')
text = project.read_text()

if 'A11C0F1A0000000000000353 /* Sparkle in Frameworks */' in text:
    raise SystemExit('Sparkle Gate 1 project wiring already present')

repls = [
(
'\t\tA11C0F1A0000000000000321 /* Views/ActivationSequence.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000322 /* Views/ActivationSequence.swift */; };\n',
'\t\tA11C0F1A0000000000000321 /* Views/ActivationSequence.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000322 /* Views/ActivationSequence.swift */; };\n'
'\t\tA11C0F1A0000000000000351 /* Services/SparkleLinkProbe.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000352 /* Services/SparkleLinkProbe.swift */; };\n'
'\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = A11C0F1A0000000000000354 /* Sparkle */; };\n'
),
(
'\t\tA11C0F1A0000000000000322 /* Views/ActivationSequence.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/ActivationSequence.swift; sourceTree = "<group>"; };\n',
'\t\tA11C0F1A0000000000000322 /* Views/ActivationSequence.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/ActivationSequence.swift; sourceTree = "<group>"; };\n'
'\t\tA11C0F1A0000000000000352 /* Services/SparkleLinkProbe.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Services/SparkleLinkProbe.swift; sourceTree = "<group>"; };\n'
),
(
'\t\t000000000000000000000008 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n',
'\t\t000000000000000000000008 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\tA11C0F1A0000000000000353 /* Sparkle in Frameworks */,\n'
),
(
'\t\t\t\tA11C0F1A0000000000000322 /* Views/ActivationSequence.swift */,\n\t\t\t\t00000000000000000000006D /* Services/Integrations.swift */,\n',
'\t\t\t\tA11C0F1A0000000000000322 /* Views/ActivationSequence.swift */,\n\t\t\t\tA11C0F1A0000000000000352 /* Services/SparkleLinkProbe.swift */,\n\t\t\t\t00000000000000000000006D /* Services/Integrations.swift */,\n'
),
(
'\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Halo;\n',
'\t\t\tdependencies = (\n\t\t\t);\n\t\t\tpackageProductDependencies = (\n\t\t\t\tA11C0F1A0000000000000354 /* Sparkle */,\n\t\t\t);\n\t\t\tname = Halo;\n'
),
(
'\t\t\tmainGroup = 000000000000000000000002;\n\t\t\tproductRefGroup = 000000000000000000000004 /* Products */;\n\t\t\tprojectDirPath = "";\n',
'\t\t\tmainGroup = 000000000000000000000002;\n\t\t\tproductRefGroup = 000000000000000000000004 /* Products */;\n\t\t\tpackageReferences = (\n\t\t\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */,\n\t\t\t);\n\t\t\tprojectDirPath = "";\n'
),
(
'\t\t\t\tA11C0F1A0000000000000321 /* Views/ActivationSequence.swift in Sources */,\n\t\t\t\t0000000000000000000000D1 /* Services/Integrations.swift in Sources */,\n',
'\t\t\t\tA11C0F1A0000000000000321 /* Views/ActivationSequence.swift in Sources */,\n\t\t\t\tA11C0F1A0000000000000351 /* Services/SparkleLinkProbe.swift in Sources */,\n\t\t\t\t0000000000000000000000D1 /* Services/Integrations.swift in Sources */,\n'
),
(
'/* Begin XCConfigurationList section */\n',
'/* Begin XCRemoteSwiftPackageReference section */\n'
'\t\tA11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */ = {\n'
'\t\t\tisa = XCRemoteSwiftPackageReference;\n'
'\t\t\trepositoryURL = "https://github.com/sparkle-project/Sparkle";\n'
'\t\t\trequirement = {\n'
'\t\t\t\tkind = exactVersion;\n'
'\t\t\t\tversion = 2.9.6;\n'
'\t\t\t};\n'
'\t\t};\n'
'/* End XCRemoteSwiftPackageReference section */\n\n'
'/* Begin XCSwiftPackageProductDependency section */\n'
'\t\tA11C0F1A0000000000000354 /* Sparkle */ = {\n'
'\t\t\tisa = XCSwiftPackageProductDependency;\n'
'\t\t\tpackage = A11C0F1A0000000000000355 /* XCRemoteSwiftPackageReference "Sparkle" */;\n'
'\t\t\tproductName = Sparkle;\n'
'\t\t};\n'
'/* End XCSwiftPackageProductDependency section */\n\n'
'/* Begin XCConfigurationList section */\n'
),
]

for old, new in repls:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Expected exactly one project anchor, found {count}: {old[:100]!r}')
    text = text.replace(old, new, 1)

project.write_text(text)
print('Sparkle 2.9.6 Gate 1 project wiring applied.')
