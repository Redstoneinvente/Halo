from pathlib import Path

path = Path('Halo/Views/PixelPetWidget.swift')
text = path.read_text()

old_enum = '''enum HaloPixelPalEyeStyle: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic"
    case dot = "Dot"
    case wide = "Wide"
    case digital = "Digital"
    case sparkle = "Sparkle"

    var id: String { rawValue }
}'''
new_enum = '''enum HaloPixelPalEyeStyle: String, Codable, CaseIterable, Identifiable {
    case classic = "Classic"
    case dot = "Dot"
    case glossy = "Glossy"
    case wide = "Wide"
    case digital = "Digital"
    case sparkle = "Sparkle"

    var id: String { rawValue }
}'''
assert text.count(old_enum) == 1, 'eye-style enum anchor changed'
text = text.replace(old_enum, new_enum)

start = text.index('        func standardEye(_ x: Int, _ y: Int, mirror: Bool = false) {')
end = text.index('        func drawMouth(_ suggested: HaloPixelPalMouthStyle) {', start)
new_helpers = r'''        func eyeStart(_ x: Int, width: Int, mirror: Bool) -> Int {
            let shifted = min(grid - 1, max(0, x + eyeShift))
            if mirror {
                return max(0, min(grid - width, shifted - max(0, width - 1)))
            }
            return max(0, min(grid - width, shifted))
        }

        func standardEye(_ x: Int, _ y: Int, mirror: Bool = false) {
            let resolvedX = min(grid - 1, max(0, x + eyeShift))
            switch preferences.eyeStyle {
            case .dot:
                block(resolvedX, y)

            case .classic:
                if level == 1 {
                    block(resolvedX, y)
                } else {
                    block(resolvedX, y, 1, min(2, grid - y))
                    if level >= 3, y > 0 {
                        block(resolvedX, y - 1, 1, 1, accentColor, opacity: 0.72)
                    }
                }

            case .glossy:
                if level == 1 {
                    block(resolvedX, y)
                } else {
                    let start = eyeStart(x, width: 2, mirror: mirror)
                    block(start, y, 2, min(2, grid - y))
                    // The bright one-pixel catchlight is deliberately different from
                    // the face palette, like the glossy pixel eyes in the reference set.
                    block(start + (mirror ? 0 : 1), y, 1, 1, Color.white)
                    if level >= 3, y + 2 < grid {
                        block(start + (mirror ? 1 : 0), y + 2, 1, 1, accentColor, opacity: 0.78)
                    }
                }

            case .wide:
                let width = level == 1 ? 1 : (level >= 3 ? 3 : 2)
                let start = eyeStart(x, width: width, mirror: mirror)
                block(start, y, width, 1)
                if level >= 3, y + 1 < grid {
                    block(start + width / 2, y + 1, 1, 1, accentColor, opacity: 0.82)
                }

            case .digital:
                if level == 1 {
                    block(resolvedX, y)
                } else {
                    let start = eyeStart(x, width: 2, mirror: mirror)
                    block(start, y, 2, 1)
                    if y + 1 < grid { block(mirror ? start + 1 : start, y + 1) }
                    if level >= 3, y + 2 < grid { block(start, y + 2, 2, 1, accentColor, opacity: 0.78) }
                }

            case .sparkle:
                if level == 1 {
                    block(resolvedX, y, 1, 1, accentColor)
                } else {
                    block(resolvedX, y, 1, 1, Color.white)
                    if resolvedX > 0 { block(resolvedX - 1, y, 1, 1, accentColor) }
                    if resolvedX + 1 < grid { block(resolvedX + 1, y, 1, 1, accentColor) }
                    if y > 0 { block(resolvedX, y - 1, 1, 1, accentColor) }
                    if y + 1 < grid { block(resolvedX, y + 1, 1, 1, accentColor) }
                }
            }
        }

        func lineEye(_ x: Int, _ y: Int, mirror: Bool = false) {
            let width: Int
            switch preferences.eyeStyle {
            case .dot: width = 1
            case .wide: width = level == 1 ? 1 : min(3, grid)
            case .sparkle: width = 1
            case .digital, .classic, .glossy: width = level == 1 ? 1 : 2
            }
            let start = eyeStart(x, width: width, mirror: mirror)
            block(start, y, width, 1)
            if preferences.eyeStyle == .sparkle, level > 1, y > 0 {
                block(start, y - 1, 1, 1, accentColor, opacity: 0.72)
            }
        }

        func happyEye(_ x: Int, _ y: Int, mirror: Bool) {
            switch preferences.eyeStyle {
            case .dot:
                block(min(grid - 1, max(0, x)), min(grid - 1, y + (level > 1 ? 1 : 0)))

            case .sparkle:
                let centerX = min(grid - 1, max(0, x))
                if level == 1 {
                    block(centerX, y, 1, 1, accentColor)
                } else {
                    block(centerX, y, 1, 1, Color.white)
                    if centerX > 0 { block(centerX - 1, y, 1, 1, accentColor) }
                    if centerX + 1 < grid { block(centerX + 1, y, 1, 1, accentColor) }
                    if y + 1 < grid { block(centerX, y + 1, 1, 1, accentColor) }
                }

            case .wide:
                if level == 1 {
                    block(x, y)
                } else {
                    let width = level >= 3 ? 3 : 2
                    let start = eyeStart(x, width: width, mirror: mirror)
                    block(start, y + 1 < grid ? y + 1 : y, width, 1)
                    block(mirror ? start : min(grid - 1, start + width - 1), y)
                }

            case .digital:
                if level == 1 {
                    block(x, y)
                } else {
                    let start = eyeStart(x, width: 2, mirror: mirror)
                    block(start, min(grid - 1, y + 1), 2, 1)
                    block(mirror ? start + 1 : start, y)
                }

            case .classic, .glossy:
                if level == 1 {
                    block(x, y)
                } else if mirror {
                    block(max(0, x - 1), min(grid - 1, y + 1))
                    block(x, y)
                    if preferences.eyeStyle == .glossy, level >= 3, x > 0 {
                        block(x - 1, y, 1, 1, Color.white)
                    }
                } else {
                    block(x, y)
                    block(min(grid - 1, x + 1), min(grid - 1, y + 1))
                    if preferences.eyeStyle == .glossy, level >= 3, x + 1 < grid {
                        block(x + 1, y, 1, 1, Color.white)
                    }
                }
            }
        }

        func heartEye(_ x: Int, _ y: Int, mirror: Bool = false) {
            if level == 1 {
                block(x, y, 1, 1, accentColor)
            } else {
                let start = eyeStart(x, width: 2, mirror: mirror)
                block(start, y, 2, 1, accentColor)
                if y + 1 < grid { block(start, y + 1, 2, 1, accentColor) }
                if y + 2 < grid { block(start + (mirror ? 0 : 1), y + 2, 1, 1, accentColor) }
                if preferences.eyeStyle == .glossy {
                    block(start + (mirror ? 1 : 0), y, 1, 1, Color.white)
                }
            }
        }

'''
text = text[:start] + new_helpers + text[end:]

# Make all eye-driven expressions honor the chosen eye style where they previously bypassed it.
text = text.replace('''        case .blink:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)''', '''        case .blink:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY, mirror: true)''')
text = text.replace('''        case .love:
            heartEye(leftEyeX, eyeY)
            heartEye(rightEyeX, eyeY)''', '''        case .love:
            heartEye(leftEyeX, eyeY)
            heartEye(rightEyeX, eyeY, mirror: true)''')
text = text.replace('''        case .sleepy:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)''', '''        case .sleepy:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY, mirror: true)''')
text = text.replace('''        case .annoyed:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)''', '''        case .annoyed:
            lineEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY, mirror: true)''')
text = text.replace('''        case .confused:
            standardEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)''', '''        case .confused:
            standardEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY, mirror: true)''')
text = text.replace('''        case .bored:
            lineEye(leftEyeX, min(grid - 1, eyeY + 1))
            lineEye(rightEyeX, min(grid - 1, eyeY + 1))''', '''        case .bored:
            lineEye(leftEyeX, min(grid - 1, eyeY + 1))
            lineEye(rightEyeX, min(grid - 1, eyeY + 1), mirror: true)''')
text = text.replace('''        case .mischievous:
            standardEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY)''', '''        case .mischievous:
            standardEye(leftEyeX, eyeY)
            lineEye(rightEyeX, eyeY, mirror: true)''')

# Settings preview must be neutral by default so changing eye styles always shows an immediate difference.
assert text.count('@State private var previewExpression: HaloPixelPalExpression = .happy') == 1
text = text.replace('@State private var previewExpression: HaloPixelPalExpression = .happy', '@State private var previewExpression: HaloPixelPalExpression = .neutral')

# Use a slightly higher-resolution settings preview without changing the real 1×1 grid.
header_old = '''                expression: previewExpression,
                squareSize: 1,
                preferences: pal.preferences,'''
header_new = '''                expression: previewExpression,
                squareSize: 2,
                preferences: pal.preferences,'''
assert text.count(header_old) == 1
text = text.replace(header_old, header_new)

picker_old = '''                Picker("Eyes", selection: bind(\\.eyeStyle)) {
                    ForEach(HaloPixelPalEyeStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Mouth", selection: bind(\\.mouthStyle)) {'''
picker_new = '''                Picker("Eyes", selection: bind(\\.eyeStyle)) {
                    ForEach(HaloPixelPalEyeStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                eyeStyleGallery
                Picker("Mouth", selection: bind(\\.mouthStyle)) {'''
assert text.count(picker_old) == 1, 'eyes picker anchor changed'
text = text.replace(picker_old, picker_new)

insert_anchor = '''    private var interactionSection: some View {'''
gallery = r'''    private var eyeStyleGallery: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(HaloPixelPalEyeStyle.allCases) { style in
                Button {
                    pal.update(\.eyeStyle, style)
                    previewExpression = .neutral
                } label: {
                    VStack(spacing: 5) {
                        HaloPixelPalFace(
                            expression: .neutral,
                            squareSize: 2,
                            preferences: previewPreferences(eyeStyle: style),
                            date: Date(),
                            reduceMotion: true
                        )
                        .frame(width: 54, height: 54)
                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Text(style.rawValue)
                            .font(.caption2.weight(style == pal.preferences.eyeStyle ? .bold : .regular))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(style == pal.preferences.eyeStyle ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(style == pal.preferences.eyeStyle ? Color.accentColor.opacity(0.72) : Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func previewPreferences(eyeStyle: HaloPixelPalEyeStyle) -> HaloPixelPalPreferences {
        var value = pal.preferences
        value.eyeStyle = eyeStyle
        value.mouthStyle = .tiny
        value.showCheeks = false
        value.backgroundStyle = .black
        value.glowIntensity = 0
        return value
    }

'''
assert text.count(insert_anchor) == 1
text = text.replace(insert_anchor, gallery + insert_anchor)

path.write_text(text)
print('Pixel Pal eye styles patched')
