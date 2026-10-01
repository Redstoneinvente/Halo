from pathlib import Path

path = Path('.github/lock-screen-presence-patch.py')
text = path.read_text()
old = "        'case \"Lock Screen\": LockScreenSettingsPane()\\n',\n        'case \"Lock Screen\": LockScreenSettingsPane(store: store, workspace: workspace)\\n',"
new = "        'case \"Lock Screen\":\\n            LockScreenSettingsPane()\\n',\n        'case \"Lock Screen\":\\n            LockScreenSettingsPane(store: store, workspace: workspace)\\n',"
if old not in text:
    raise SystemExit('Presence patch route anchor text not found')
path.write_text(text.replace(old, new, 1))
print('Presence patch route anchor corrected')
