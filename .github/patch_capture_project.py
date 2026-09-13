from pathlib import Path
p = Path('Halo.xcodeproj/project.pbxproj')
s = p.read_text()

# Build-file records.
anchor = '\t\tA11C0F1A0000000000000311 /* Views/VisualWorkspaceAdaptiveWidgets.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000312 /* Views/VisualWorkspaceAdaptiveWidgets.swift */; };\n'
if anchor not in s: raise SystemExit('PBX build anchor missing')
addition = anchor + '''\t\tA11C0F1A0000000000000321 /* Views/CaptureWorkspaceView.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000322 /* Views/CaptureWorkspaceView.swift */; };\n\t\tA11C0F1A0000000000000323 /* Views/CaptureSettingsControls.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000324 /* Views/CaptureSettingsControls.swift */; };\n\t\tA11C0F1A0000000000000325 /* Services/CaptureServiceUtilities.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000326 /* Services/CaptureServiceUtilities.swift */; };\n'''
s = s.replace(anchor, addition, 1)

# File references.
anchor = '\t\tA11C0F1A0000000000000312 /* Views/VisualWorkspaceAdaptiveWidgets.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/VisualWorkspaceAdaptiveWidgets.swift; sourceTree = "<group>"; };\n'
if anchor not in s: raise SystemExit('PBX file ref anchor missing')
addition = anchor + '''\t\tA11C0F1A0000000000000322 /* Views/CaptureWorkspaceView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/CaptureWorkspaceView.swift; sourceTree = "<group>"; };\n\t\tA11C0F1A0000000000000324 /* Views/CaptureSettingsControls.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/CaptureSettingsControls.swift; sourceTree = "<group>"; };\n\t\tA11C0F1A0000000000000326 /* Services/CaptureServiceUtilities.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Services/CaptureServiceUtilities.swift; sourceTree = "<group>"; };\n'''
s = s.replace(anchor, addition, 1)

# Main Halo group.
anchor = '\t\t\t\tA11C0F1A0000000000000312 /* Views/VisualWorkspaceAdaptiveWidgets.swift */,\n'
if anchor not in s: raise SystemExit('PBX group anchor missing')
addition = anchor + '''\t\t\t\tA11C0F1A0000000000000322 /* Views/CaptureWorkspaceView.swift */,\n\t\t\t\tA11C0F1A0000000000000324 /* Views/CaptureSettingsControls.swift */,\n\t\t\t\tA11C0F1A0000000000000326 /* Services/CaptureServiceUtilities.swift */,\n'''
s = s.replace(anchor, addition, 1)

# Halo target Sources phase.
anchor = '\t\t\t\tA11C0F1A0000000000000311 /* Views/VisualWorkspaceAdaptiveWidgets.swift in Sources */,\n'
if anchor not in s: raise SystemExit('PBX sources anchor missing')
addition = anchor + '''\t\t\t\tA11C0F1A0000000000000321 /* Views/CaptureWorkspaceView.swift in Sources */,\n\t\t\t\tA11C0F1A0000000000000323 /* Views/CaptureSettingsControls.swift in Sources */,\n\t\t\t\tA11C0F1A0000000000000325 /* Services/CaptureServiceUtilities.swift in Sources */,\n'''
s = s.replace(anchor, addition, 1)

camera = '\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Halo uses the camera only when you enable the Mirror widget. Camera frames stay on your Mac and are not saved or transmitted.";\n'
if s.count(camera) != 2: raise SystemExit(f'Expected two camera usage anchors, got {s.count(camera)}')
s = s.replace(camera, camera + '\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = "Halo records microphone audio only when you explicitly enable microphone audio for a screen recording.";\n')

p.write_text(s)
