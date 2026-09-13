from pathlib import Path
p = Path('Halo/Core/WidgetModels.swift')
s = p.read_text()
s2 = s.replace('if value.cardBackgroundStyle == nil { value.cardBackgroundStyle = .none }', 'if value.cardBackgroundStyle == nil { value.cardBackgroundStyle = WidgetCardBackgroundStyle.none }', 1)
s2 = s2.replace('if value.outlineStyle == nil { value.outlineStyle = .none }', 'if value.outlineStyle == nil { value.outlineStyle = WidgetOutlineStyle.none }', 1)
if s2 == s:
    raise SystemExit('Expected Visual Workspace default anchors not found')
p.write_text(s2)
print('Made Visual Workspace no-background/no-outline defaults explicit.')
