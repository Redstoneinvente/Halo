from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

path = Path("Halo/Core/WorkspaceModels.swift")
text = path.read_text()

old_open = '''        let values = [blur ?? 0, saturation ?? 1, brightness ?? 0, contrast ?? 1, tintOpacity ?? 0,
                      grain ?? 0, warmth ?? 0, borderWidth ?? 0, borderOpacity ?? 0,
                      innerHighlight ?? 0, shadowBlur ?? 0, shadowOpacity ?? 0, glow ?? 0]
        guard values.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
'''
new_open = '''        let values: [Double] = [
            blur ?? 0,
            saturation ?? 1,
            brightness ?? 0,
            contrast ?? 1,
            tintOpacity ?? 0,
            grain ?? 0,
            warmth ?? 0,
            borderWidth ?? 0,
            borderOpacity ?? 0,
            innerHighlight ?? 0,
            shadowBlur ?? 0,
            shadowOpacity ?? 0,
            glow ?? 0
        ]
        guard values.allSatisfy({ $0.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
'''
text = replace_once(text, old_open, new_open, "OpenNotchAppearance finite values")

old_music = '''        guard [artworkSize, fontSize, backgroundOpacity, artworkBackgroundBlur ?? 12, artworkBackgroundDim ?? 0.38,
               spacing ?? 12, cornerRadius ?? 18, controlSize ?? 24, vinylRPM ?? 8,
               lyricSyncOffset ?? 0, lyricFontSize ?? 16, horizontalMargin ?? 18, topMargin ?? 0, bottomMargin ?? 10].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
'''
new_music = '''        let numericValues: [Double] = [
            artworkSize,
            fontSize,
            backgroundOpacity,
            artworkBackgroundBlur ?? 12,
            artworkBackgroundDim ?? 0.38,
            spacing ?? 12,
            cornerRadius ?? 18,
            controlSize ?? 24,
            vinylRPM ?? 8,
            lyricSyncOffset ?? 0,
            lyricFontSize ?? 16,
            horizontalMargin ?? 18,
            topMargin ?? 0,
            bottomMargin ?? 10
        ]
        guard numericValues.allSatisfy({ $0.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
'''
text = replace_once(text, old_music, new_music, "ContextMusicOptions finite values")

path.write_text(text)
print("Compiler type-checking fix applied")
# Trigger note: explicit Double arrays keep Swift's type checker deterministic after the skin model expansion.
