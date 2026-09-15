from pathlib import Path

path = Path("Halo/NotchEngine/WindowManager.swift")
text = path.read_text()
old = '''        let physicalHeightFloor = geometry.attachedToNotch && geometry.physicalNotchHeight > 0
            ? geometry.physicalNotchHeight : 16
'''
new = '''        let physicalHeightFloor = geometry.attachedToNotch && host.state.physicalNotchHeight > 0
            ? host.state.physicalNotchHeight : 16
'''
if old not in text:
    raise SystemExit("Expected generated physicalNotchHeight block was not found")
path.write_text(text.replace(old, new, 1))
print("Repaired Custom CI compact-height physical notch source")
