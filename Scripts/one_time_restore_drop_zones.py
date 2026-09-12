from pathlib import Path

p = Path('Halo/NotchEngine/DisplayClock.swift')
text = p.read_text()

old = '''        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.masksToBounds = true
        autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        hosting.sizingOptions = []
'''
new = '''        registerForDraggedTypes([.fileURL])
        autoresizingMask = [.width, .height]
        hosting.sizingOptions = []
'''
if old not in text:
    raise SystemExit('host masking block not found')
text = text.replace(old, new, 1)

old2 = '''        host.frame = view.bounds
        view.addSubview(host, positioned: .above, relativeTo: nil)
    }
'''
new2 = '''        host.frame = view.bounds
        host.needsLayout = true
        host.layoutSubtreeIfNeeded()
        view.addSubview(host, positioned: .above, relativeTo: nil)
    }
'''
if old2 not in text:
    raise SystemExit('host frame block not found')
text = text.replace(old2, new2, 1)

old3 = '''            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
'''
new3 = '''            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
'''
if old3 not in text:
    raise SystemExit('board clip block not found')
text = text.replace(old3, new3, 1)

p.write_text(text)
