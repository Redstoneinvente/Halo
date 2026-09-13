from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'marker not found in {path}')
    p.write_text(text.replace(old, new, 1))

replace_once(
    'Halo/Views/WidgetViews.swift',
    '''        case .glass:\n            shape.fill(.ultraThinMaterial)\n                .overlay(shape.fill(fittedStyle.backgroundColor.color.opacity(fittedStyle.resolvedGlassTintOpacity)))\n''',
    '''        case .glass:\n            shape.fill(.ultraThinMaterial)\n                .opacity(fittedStyle.backgroundOpacity)\n                .overlay(shape.fill(fittedStyle.backgroundColor.color.opacity(fittedStyle.resolvedGlassTintOpacity * fittedStyle.backgroundOpacity)))\n'''
)

replace_once(
    'Halo/Views/WidgetSettingsView.swift',
    '''                colorPicker(style.wrappedValue.resolvedCardBackgroundStyle == .accent ? "Tint base" : "Background", style.backgroundColor)\n''',
    '''                if style.wrappedValue.resolvedCardBackgroundStyle == .accent {\n                    colorPicker("Tint color", style.accentColor)\n                } else {\n                    colorPicker("Background", style.backgroundColor)\n                }\n'''
)

print('widget design polish applied')
