from pathlib import Path

app = Path('Halo/Core/AppStore.swift')
settings = Path('Halo/Views/WorkspaceSettingsView.swift')

s = app.read_text()
old = '''        EnvironmentalInterfaceManager.shared.start(workspace: workspace)\n        EnvironmentalInterfaceOwnershipController.shared.start(workspace: workspace)\n'''
new = '''        // Environmental Interface is intentionally dormant for now. Keep the implementation\n        // and assets in the tree so development can resume later without shipping EI at runtime.\n'''
if old not in s:
    raise SystemExit('EI startup calls not found')
s = s.replace(old, new, 1)
app.write_text(s)

s = settings.read_text()
old = '"Closed notch", "Context Notch Interface", "Environmental Interface", "HUD"'
new = '"Closed notch", "Context Notch Interface", "HUD"'
if old not in s:
    raise SystemExit('EI settings section list entry not found')
s = s.replace(old, new, 1)

old = '        case "Environmental Interface": return "sparkles.rectangle.stack"\n'
if old not in s:
    raise SystemExit('EI settings icon case not found')
s = s.replace(old, '', 1)

old = '        case "Environmental Interface": EnvironmentalInterfaceSettingsView()\n'
if old not in s:
    raise SystemExit('EI settings content case not found')
s = s.replace(old, '', 1)
settings.write_text(s)

print('EI startup disabled and settings entry removed')
