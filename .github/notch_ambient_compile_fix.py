from pathlib import Path

p = Path('Halo/Views/DecorationsView.swift')
text = p.read_text().replace('\r\n', '\n')

def replace_between(start_marker: str, end_marker: str, replacement: str, label: str):
    global text
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'missing start marker for {label}: {start_marker!r}')
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f'missing end marker for {label}: {end_marker!r}')
    text = text[:start] + replacement + text[end:]

# 1) File ownership can be absent in some checkouts. Replace it when present; otherwise insert it.
file_property = '''    private var fileShelfOwnsNotch: Bool {
        guard !store.pinnedFiles.isEmpty else { return false }
        let leftOwnsFiles = closed.left == .files
        let rightOwnsFiles = closed.right == .files
        return leftOwnsFiles || rightOwnsFiles
    }
'''
old_file_marker = '    private var filesOwnsNotch: Bool {'
mirror_marker = '    private var mirrorOwnsNotch:'
if old_file_marker in text:
    replace_between(old_file_marker, mirror_marker, file_property, 'file ownership')
elif '    private var fileShelfOwnsNotch: Bool {' not in text:
    mirror = text.find(mirror_marker)
    if mirror < 0:
        raise SystemExit('missing mirror ownership insertion point')
    text = text[:mirror] + file_property + text[mirror:]

replace_between(
    '    private var shouldShow: Bool {',
    '    private var notchWidth:',
    '''    private var shouldShow: Bool {
        guard current.enabled, screenAwake, notchLike, hasCommercialAccess else { return false }
        guard !state.expanded, !state.dropTargeted else { return false }
        guard !activeHUD, !activeActivity, !mediaOwnsNotch, !timerOwnsNotch else { return false }
        guard !fileShelfOwnsNotch, !mirrorOwnsNotch, !powerOwnsNotch else { return false }
        if current.yieldToPersistentClosedContent && persistentClosedContent { return false }
        return true
    }
''',
    'shouldShow',
)

# 2) Icicles: explicit types and no Double + Int arithmetic.
replace_between(
    '    private static func drawIcicles(',
    '    private static func drawNature(',
    '''    private static func drawIcicles(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], lowPower: Bool) {
        let densityCount = Int(s.density * 12.0)
        let maximumCount: Int = lowPower ? 16 : 30
        let count: Int = max(4, min(maximumCount, s.count + densityCount))

        for i in 0..<count {
            let denominator = Double(max(1, count - 1))
            let t = Double(i) / denominator
            let x = n.minX + n.width * CGFloat(t)
            let lengthFactor = 0.28 + rand(i, seed: s.seed, salt: 21) * 0.72
            let length = CGFloat(s.length * lengthFactor)

            var icicle = Path()
            icicle.move(to: CGPoint(x: x - 2.0, y: n.maxY))
            icicle.addLine(to: CGPoint(x: x, y: n.maxY + length))
            icicle.addLine(to: CGPoint(x: x + 2.0, y: n.maxY))
            icicle.closeSubpath()
            let icicleOpacity = 0.10 + intensity * 0.30
            ctx.fill(icicle, with: .color(c(palette, i).opacity(icicleOpacity)))

            if rand(i, seed: s.seed, salt: 22) > 0.72 {
                let wave = sin(phase + Double(i))
                let dropletY = n.maxY + length * 0.55 + CGFloat(wave) * 2.0
                let dropletRect = CGRect(x: x - 0.8, y: dropletY, width: 1.6, height: 1.6)
                ellipse(&ctx, rect: dropletRect, color: .white.opacity(intensity * 0.55), fill: true)
            }
        }
    }

''',
    'drawIcicles',
)

# 3) Black Hole ring widths: never mix Int and Double inside CGFloat initializers.
text = text.replace('width:CGFloat(1.2+(i%3))', 'width: CGFloat(1.2 + Double(i % 3))')
text = text.replace('width: CGFloat(1.2+(i%3))', 'width: CGFloat(1.2 + Double(i % 3))')

# 4) Replace the entire Portal case, eliminating both the Int/Double issue and the huge expression.
replace_between(
    '        case .portal:',
    '        case .reactor:',
    '''        case .portal:
            let center = CGPoint(x: n.midX, y: n.midY + 5.0)
            let interaction = cursorInfluence(cursor, point: center, settings: s).strength
            for i in 0..<7 {
                let pad = CGFloat(7 + i * 7)
                let verticalRadius = CGFloat(13 + i * 2)
                let ringHeight = CGFloat(26 + i * 4)
                let ringRect = CGRect(
                    x: center.x - n.width / 2.0 - pad,
                    y: center.y - verticalRadius,
                    width: n.width + pad * 2.0,
                    height: ringHeight
                )
                let baseOpacity = 0.25 - Double(i) * 0.022
                let ringOpacity = intensity * baseOpacity * (1.0 + interaction * 1.3)
                let ringWidth = CGFloat(1.2 + Double(i % 2))
                ellipse(&ctx, rect: ringRect, color: c(palette, i).opacity(ringOpacity), fill: false, width: ringWidth)
            }

            let maximumParticles: Int = lowPower ? 14 : 28
            let particleCount: Int = max(4, min(maximumParticles, Int(5.0 + s.density * 24.0)))
            let portalSpeed: Double = 9.0 + interaction * 6.0
            for i in 0..<particleCount {
                let angleSeed = rand(i, seed: s.seed, salt: 61)
                let angle: Double = angleSeed * Double.pi * 2.0 + phase * 0.12
                let radius = CGFloat(25.0 + rand(i, seed: s.seed, salt: 62) * 80.0)
                let x = center.x + CGFloat(cos(angle)) * radius
                let driftInput: Double = phase * portalSpeed + Double(i) * 7.0
                let drift = driftInput.truncatingRemainder(dividingBy: 18.0)
                let y = center.y + CGFloat(sin(angle)) * radius * 0.36 + CGFloat(drift)
                let opacity = intensity * (0.58 + interaction * 0.32)
                let particleRect = CGRect(x: x - 1.0, y: y - 1.0, width: 2.0, height: 2.0)
                ellipse(&ctx, rect: particleRect, color: c(palette, i).opacity(opacity), fill: true)
            }
''',
    'portal case',
)

# 5) Fix lexer ambiguity for the negative threshold comparison.
text = text.replace('sin(phase*1.6)>-0.15', 'sin(phase * 1.6) > -0.15')
text = text.replace('sin(phase * 1.6)>-0.15', 'sin(phase * 1.6) > -0.15')

p.write_text(text)
print('Notch Ambient compiler fixes applied')
