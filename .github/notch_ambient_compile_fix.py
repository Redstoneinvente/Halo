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

# 1) Ownership checks: keep each boolean simple so the compiler never has to infer a giant chain.
replace_between(
    '    private var filesOwnsNotch: Bool {',
    '    private var mirrorOwnsNotch:',
    '''    private var fileShelfOwnsNotch: Bool {
        guard !store.pinnedFiles.isEmpty else { return false }
        let leftOwnsFiles = closed.left == .files
        let rightOwnsFiles = closed.right == .files
        return leftOwnsFiles || rightOwnsFiles
    }
''',
    'file ownership',
)

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

# 3) Mixed Int/Double arithmetic in Black Hole and Portal ring widths.
text = text.replace('width:CGFloat(1.2+(i%3))', 'width: CGFloat(1.2 + Double(i % 3))')
text = text.replace('width:CGFloat(1.2+(i%2))', 'width: CGFloat(1.2 + Double(i % 2))')

# 4) Portal particle loop: split the giant expression so Swift does not time out type-checking it.
replace_between(
    '            let count=max(4,min(lowPower ? 14:28,Int(5+s.density*24)))',
    '        case .reactor:',
    '''            let maximumParticles: Int = lowPower ? 14 : 28
            let particleCount: Int = max(4, min(maximumParticles, Int(5.0 + s.density * 24.0)))
            let portalSpeed: Double = 9.0 + interaction * 6.0
            for i in 0..<particleCount {
                let angleSeed = rand(i, seed: s.seed, salt: 61)
                let angle: Double = angleSeed * Double.pi * 2.0 + phase * 0.12
                let radius = CGFloat(25.0 + rand(i, seed: s.seed, salt: 62) * 80.0)
                let x = center.x + CGFloat(cos(angle)) * radius
                let driftInput: Double = phase * portalSpeed + Double(i) * 7.0
                let drift: Double = driftInput.truncatingRemainder(dividingBy: 18.0)
                let y = center.y + CGFloat(sin(angle)) * radius * 0.36 + CGFloat(drift)
                let opacity: Double = intensity * (0.58 + interaction * 0.32)
                let particleRect = CGRect(x: x - 1.0, y: y - 1.0, width: 2.0, height: 2.0)
                ellipse(&ctx, rect: particleRect, color: c(palette, i).opacity(opacity), fill: true)
            }
''',
    'portal particles',
)

# 5) The lexer interprets `>-` badly here; keep the negative comparison explicit.
text = text.replace('sin(phase*1.6)>-0.15', 'sin(phase * 1.6) > -0.15')

p.write_text(text)
print('Notch Ambient compiler fixes applied')
