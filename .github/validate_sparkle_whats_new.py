from pathlib import Path

# Normalize a Swift tuple loop for compatibility across compiler modes.
p = Path('Halo/Services/UpdateManager.swift')
s = p.read_text()
s = s.replace(
'''                ForEach(intervals, id: \\.1) { label, interval in
                    Text(label).tag(interval)
                }
''',
'''                ForEach(intervals.indices, id: \\.self) { index in
                    Text(intervals[index].0).tag(intervals[index].1)
                }
'''
)
p.write_text(s)

pbx = Path('Halo.xcodeproj/project.pbxproj').read_text()
for token in [
    'repositoryURL = "https://github.com/sparkle-project/Sparkle";',
    'version = 2.9.6;',
    'Sparkle in Frameworks',
    'Services/UpdateManager.swift in Sources',
    'Views/WhatsNewView.swift in Sources',
]:
    if token not in pbx:
        raise SystemExit(f'missing Xcode wiring: {token}')

plist = Path('Halo/Info.plist').read_text()
for token in ['SUFeedURL', 'SUPublicEDKey', 'SUEnableAutomaticChecks', 'SUAutomaticallyUpdate', 'SUShowReleaseNotes']:
    if token not in plist:
        raise SystemExit(f'missing Sparkle plist key: {token}')

app = Path('Halo/App/HaloApp.swift').read_text()
for token in ['Check for Updates…', "What's New…", 'whatsNew.presentIfNeeded()', 'updater.start()']:
    if token not in app:
        raise SystemExit(f'missing app integration: {token}')

settings = Path('Halo/Views/WorkspaceSettingsView.swift').read_text()
if 'case "Updates": HaloUpdateSettingsView()' not in settings:
    raise SystemExit('Updates settings destination missing')

whats = Path('Halo/Views/WhatsNewView.swift').read_text()
for token in ['Visual Workspace, refined', 'Notch Ambient', 'Activation Sequence', 'Updates, built in']:
    if token not in whats:
        raise SystemExit(f'Whats New content missing: {token}')

print('Sparkle and Whats New source audit passed.')
