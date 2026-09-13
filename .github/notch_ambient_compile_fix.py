from pathlib import Path

p = Path('Halo/Views/DecorationsView.swift')
text = p.read_text()

def rep(old: str, new: str, label: str):
    global text
    if old not in text:
        raise SystemExit(f'missing {label}: {old[:160]!r}')
    text = text.replace(old, new, 1)

# Make idle ownership checks intentionally simple for Swift's type checker.
rep('''    private var filesOwnsNotch: Bool {
        guard !store.pinnedFiles.isEmpty else { return false }
        return closed.left == .files || closed.right == .files
    }
''', '''    private var fileShelfOwnsNotch: Bool {
        guard !store.pinnedFiles.isEmpty else { return false }
        let leftOwnsFiles = closed.left == .files
        let rightOwnsFiles = closed.right == .files
        return leftOwnsFiles || rightOwnsFiles
    }
''', 'file ownership')

rep('''    private var shouldShow: Bool {
        current.enabled && screenAwake && notchLike && hasCommercialAccess && !state.expanded && !state.dropTargeted &&
        !activeHUD && !activeActivity && !mediaOwnsNotch && !timerOwnsNotch && !filesOwnsNotch && !mirrorOwnsNotch && !powerOwnsNotch &&
        !(current.yieldToPersistentClosedContent && persistentClosedContent)
    }
''', '''    private var shouldShow: Bool {
        guard current.enabled, screenAwake, notchLike, hasCommercialAccess else { return false }
        guard !state.expanded, !state.dropTargeted else { return false }
        guard !activeHUD, !activeActivity, !mediaOwnsNotch, !timerOwnsNotch else { return false }
        guard !fileShelfOwnsNotch, !mirrorOwnsNotch, !powerOwnsNotch else { return false }
        if current.yieldToPersistentClosedContent && persistentClosedContent { return false }
        return true
    }
''', 'should show')

# Break icicle drawing into typed subexpressions and fix Double + Int arithmetic.
start = text.index('    private static func drawIcicles(')
end = text.index('\n    private static func drawNature(', start)
text = text[:start] + '''    private static func drawIcicles(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], lowPower: Bool) {
        let densityCount = Int(s.density * 12)
        let maximumCount = lowPower ? 16 : 30
        let count = max(4, min(maximumCount, s.count + densityCount))

        for i in 0..<count {
            let denominator = Double(max(1, count - 1))
            let t = Double(i) / denominator
            let x = n.minX + n.width * CGFloat(t)
            let lengthFactor = 0.28 + rand(i, seed: s.seed, salt: 21) * 0.72
            let length = CGFloat(s.length * lengthFactor)

            var icicle = Path()
            icicle.move(to: CGPoint(x: x - 2, y: n.maxY))
            icicle.addLine(to: CGPoint(x: x, y: n.maxY + length))
            icicle.addLine(to: CGPoint(x: x + 2, y: n.maxY))
            icicle.closeSubpath()
            let icicleOpacity = 0.10 + intensity * 0.30
            ctx.fill(icicle, with: .color(c(palette, i).opacity(icicleOpacity)))

            if rand(i, seed: s.seed, salt: 22) > 0.72 {
                let wave = sin(phase + Double(i))
                let dropletY = n.maxY + length * 0.55 + CGFloat(wave) * 2
                let dropletRect = CGRect(x: x - 0.8, y: dropletY, width: 1.6, height: 1.6)
                ellipse(&ctx, rect: dropletRect, color: .white.opacity(intensity * 0.55), fill: true)
            }
        }
    }
''' + text[end:]

# Mixed Int/Double arithmetic in ring widths was ambiguous on the local compiler.
text = text.replace('width:CGFloat(1.2+(i%3))', 'width: CGFloat(1.2 + Double(i % 3))')
text = text.replace('width:CGFloat(1.2+(i%2))', 'width: CGFloat(1.2 + Double(i % 2))')

# Keep comparison lexing unambiguous (`> -x`, not `>-x`).
text = text.replace('sin(phase*1.6)>-0.15', 'sin(phase * 1.6) > -0.15')

# A few other hot expressions are deliberately split to reduce type-checker pressure.
old_portal = '''            let count=max(4,min(lowPower ? 14:28,Int(5+s.density*24))); for i in 0..<count { let a=rand(i,seed:s.seed,salt:61)*Double.pi*2+phase*0.12; let r=CGFloat(25+rand(i,seed:s.seed,salt:62)*80); let x=center.x+cos(a)*r; let y=center.y+sin(a)*r*0.36+CGFloat((phase*(9+interaction*6)+Double(i)*7).truncatingRemainder(dividingBy:18)); ellipse(&ctx,rect:CGRect(x:x-1,y:y-1,width:2,height:2),color:c(palette,i).opacity(intensity*(0.58+interaction*0.32)),fill:true) }
'''
new_portal = '''            let maximumParticles = lowPower ? 14 : 28
            let particleCount = max(4, min(maximumParticles, Int(5 + s.density * 24)))
            let portalSpeed = 9.0 + interaction * 6.0
            for i in 0..<particleCount {
                let angleSeed = rand(i, seed: s.seed, salt: 61)
                let angle = angleSeed * Double.pi * 2.0 + phase * 0.12
                let radius = CGFloat(25.0 + rand(i, seed: s.seed, salt: 62) * 80.0)
                let x = center.x + CGFloat(cos(angle)) * radius
                let drift = (phase * portalSpeed + Double(i) * 7.0).truncatingRemainder(dividingBy: 18.0)
                let y = center.y + CGFloat(sin(angle)) * radius * 0.36 + CGFloat(drift)
                let opacity = intensity * (0.58 + interaction * 0.32)
                let particleRect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                ellipse(&ctx, rect: particleRect, color: c(palette, i).opacity(opacity), fill: true)
            }
'''
rep(old_portal, new_portal, 'portal particles')

p.write_text(text)
print('Notch Ambient compiler fixes applied')
