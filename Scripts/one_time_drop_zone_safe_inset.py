from pathlib import Path

path = Path('Halo/NotchEngine/DisplayClock.swift')
text = path.read_text()
old = '''        let padding = max(8, CGFloat(configuration.boardPadding))
        let gap = max(2, CGFloat(configuration.zoneSpacing))
        let top = headerHeight + padding
        let availableWidth = max(1, size.width - padding * 2)
        let availableHeight = max(1, size.height - top - footerHeight - padding)
        let rect = CGRect(
            x: padding,
            y: top,
            width: availableWidth,
            height: availableHeight
        ).intersection(CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4))
'''
new = '''        let padding = max(8, CGFloat(configuration.boardPadding))
        let gap = max(2, CGFloat(configuration.zoneSpacing))
        // Keep card strokes and hover shadows visibly inside the Drop CI surface.
        // The previous bounds intersection did not actually add an inset when the
        // configured padding was already larger than four points.
        let edgeSafety: CGFloat = 8
        let horizontalInset = padding + edgeSafety
        let top = headerHeight + padding + edgeSafety
        let availableWidth = max(1, size.width - horizontalInset * 2)
        let availableHeight = max(1, size.height - top - footerHeight - padding - edgeSafety)
        let rect = CGRect(
            x: horizontalInset,
            y: top,
            width: availableWidth,
            height: availableHeight
        )
'''
if old not in text:
    raise SystemExit('layout resolver marker not found')
text = text.replace(old, new, 1)
path.write_text(text)
