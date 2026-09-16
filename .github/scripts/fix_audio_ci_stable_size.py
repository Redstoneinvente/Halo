from pathlib import Path

path = Path('Halo/Views/SurfaceView.swift')
text = path.read_text()
old = '        let scrubHeight = playbackDuration > 0.5 ? 30.0 : 0\n'
new = '''        // Keep the Audio CI geometry stable for the lifetime of the music surface.\n        // MediaRemote can briefly omit duration while metadata refreshes; tying preferred size\n        // to that transient value makes the notch randomly grow/shrink when the scrubber appears.\n        // Reserve the progress-row footprint even while duration is temporarily unavailable.\n        let scrubHeight = 30.0\n'''
if old not in text:
    raise SystemExit('Audio CI scrub-height anchor not found')
if text.count(old) != 1:
    raise SystemExit(f'Audio CI scrub-height anchor count={text.count(old)}')
path.write_text(text.replace(old, new, 1))
