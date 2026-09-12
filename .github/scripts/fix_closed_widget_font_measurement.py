from pathlib import Path
p = Path('Halo/NotchEngine/WindowManager.swift')
s = p.read_text()
s = s.replace('func itemFont(_ style: ClosedNotchWidgetStyle?, digits: Bool = false)', 'func resolvedItemFont(_ style: ClosedNotchWidgetStyle?, digits: Bool = false)', 1)
s = s.replace('let (mediaFont, mediaSize, mediaGap) = itemFont(widget)', 'let (mediaFont, mediaSize, mediaGap) = resolvedItemFont(widget)', 1)
s = s.replace('let (itemFont, itemSize, itemGap) = itemFont(widget)\n            let digitItemFont = itemFont(widget, digits: true).0', 'let (itemFont, itemSize, itemGap) = resolvedItemFont(widget)\n            let digitItemFont = resolvedItemFont(widget, digits: true).0', 1)
p.write_text(s)
