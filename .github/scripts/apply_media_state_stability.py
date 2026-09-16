from pathlib import Path

path = Path('Halo/Views/SurfaceView.swift')
text = path.read_text()
old = '        let scrubHeight = playbackDuration > 0.5 ? 30.0 : 0\n'
new = '''        // Keep Audio CI geometry stable across MediaRemote metadata refreshes. Duration can\n        // briefly disappear and return for the same track; that must not resize the notch.\n        let scrubHeight = 30.0\n'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'Audio CI scrub-height anchor count={count}, expected 1')
path.write_text(text.replace(old, new, 1))
print('Applied stable Audio CI sizing hotfix')
