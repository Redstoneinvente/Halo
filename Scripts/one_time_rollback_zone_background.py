from pathlib import Path

path = Path('Halo/NotchEngine/DisplayClock.swift')
text = path.read_text()

old = '''            ZStack(alignment: .topLeading) {
                // Render the exact background configured in Drop Zone Studio in the live Drop CI.
                // Keep the background itself clipped so it never paints outside the CI surface.
                HaloDropCIBackgroundView(configuration: configuration)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: max(18, min(32, CGFloat(configuration.cornerRadius) + 4)),
                            style: .continuous
                        )
                    )
                    .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
'''
new = '''            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
'''

if old not in text:
    raise SystemExit('duplicate runtime background marker not found')

text = text.replace(old, new, 1)
path.write_text(text)
