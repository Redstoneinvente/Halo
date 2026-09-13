from pathlib import Path

p = Path('Halo/Views/DecorationsView.swift')
text = p.read_text()

def rep(old: str, new: str, label: str):
    global text
    if old not in text:
        raise SystemExit(f'missing {label}: {old[:120]!r}')
    text = text.replace(old, new, 1)

# A dedicated optional holiday hanging treatment.
rep('    case hangingStars = "Hanging Stars / Moons"\n    case icicles = "Icicles"\n',
    '    case hangingStars = "Hanging Stars / Moons"\n    case christmasOrnaments = "Christmas Ornaments"\n    case icicles = "Icicles"\n', 'ornament enum')
rep('        case .fairyLights, .hangingStars, .icicles: return .hanging\n',
    '        case .fairyLights, .hangingStars, .christmasOrnaments, .icicles: return .hanging\n', 'ornament category')
rep('        case .hangingStars: return "sparkles"\n        case .icicles: return "triangle.fill"\n',
    '        case .hangingStars: return "sparkles"\n        case .christmasOrnaments: return "circle.grid.cross"\n        case .icicles: return "triangle.fill"\n', 'ornament symbol')
rep('        case .hangingStars: return [.count, .spacing, .length, .bloom, .sway, .cursor, .symmetry]\n        case .icicles: return [.count, .spacing, .length, .density, .bloom, .symmetry]\n',
    '        case .hangingStars: return [.count, .spacing, .length, .bloom, .sway, .cursor, .symmetry]\n        case .christmasOrnaments: return [.count, .spacing, .length, .bloom, .sway, .cursor, .symmetry]\n        case .icicles: return [.count, .spacing, .length, .density, .bloom, .symmetry]\n', 'ornament controls')

# Placement is a real transform while seasonal overlays stay attached to the physical notch.
rep('''            let notch = CGRect(x: (size.width - notchWidth) / 2, y: 0, width: notchWidth, height: notchHeight)
            NotchAmbientPainter.draw(kind: settings.decoration, context: &context, size: size, notch: notch,
                                     settings: settings, phase: phase, audio: audio, cursor: cursor,
                                     palette: palette, lowPower: lowPower, date: date)
            if let season = settings.resolvedSeason(at: date) {
                NotchAmbientPainter.drawSeason(season, context: &context, size: size, notch: notch,
''', '''            let physicalNotch = CGRect(x: (size.width - notchWidth) / 2, y: 0, width: notchWidth, height: notchHeight)
            let artworkNotch = NotchAmbientPainter.placedNotch(physicalNotch, settings: settings)
            NotchAmbientPainter.draw(kind: settings.decoration, context: &context, size: size, notch: artworkNotch,
                                     settings: settings, phase: phase, audio: audio, cursor: cursor,
                                     palette: palette, lowPower: lowPower, date: date)
            if let season = settings.resolvedSeason(at: date) {
                NotchAmbientPainter.drawSeason(season, context: &context, size: size, notch: physicalNotch,
''', 'placement canvas')

rep('''        let d = max(1, hypot(dx, dy)); let radius = CGFloat(settings.reactionRadius)
        guard d < radius else { return (0, 0, 0) }
        let strength = Double(1 - d / radius) * settings.reactionStrength
''', '''        let d = max(1, hypot(dx, dy)); let radius = CGFloat(settings.reactionRadius)
        guard d < radius else { return (0, 0, 0) }
        let raw = Double(1 - d / radius)
        let exponent = max(0.35, 1.85 - settings.reactionSmoothing * 1.45)
        let strength = pow(raw, exponent) * settings.reactionStrength
''', 'cursor smoothing')

rep('    static func draw(kind: NotchAmbientDecorationKind, context: inout GraphicsContext, size: CGSize, notch: CGRect,\n', '''    static func placedNotch(_ notch: CGRect, settings s: NotchAmbientSettings) -> CGRect {
        switch s.placement {
        case .above: return notch.offsetBy(dx: 0, dy: -min(10, notch.height * 0.25))
        case .below: return notch.offsetBy(dx: 0, dy: min(18, notch.height * 0.45))
        case .left: return notch.offsetBy(dx: -min(54, notch.width * 0.28), dy: 0)
        case .right: return notch.offsetBy(dx: min(54, notch.width * 0.28), dy: 0)
        case .around, .behind, .edgeAttached: return notch
        }
    }

    static func draw(kind: NotchAmbientDecorationKind, context: inout GraphicsContext, size: CGSize, notch: CGRect,
''', 'placement helper')

rep('''        case .edgeGlow: drawEdgeGlow(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette)
        case .halo: drawHalo(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette)
''', '''        case .edgeGlow: drawEdgeGlow(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor)
        case .halo: drawHalo(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, cursor: cursor)
''', 'minimal cursor dispatch')
rep('''        case .fairyLights: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: false, cursor: cursor, lowPower: lowPower)
        case .hangingStars: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: true, cursor: cursor, lowPower: lowPower)
        case .icicles: drawIcicles(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, lowPower: lowPower)
''', '''        case .fairyLights: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: false, ornaments: false, cursor: cursor, lowPower: lowPower)
        case .hangingStars: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: true, ornaments: false, cursor: cursor, lowPower: lowPower)
        case .christmasOrnaments: drawHanging(&context, size: size, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, stars: false, ornaments: true, cursor: cursor, lowPower: lowPower)
        case .icicles: drawIcicles(&context, notch: notch, s: s, phase: phase, intensity: intensity, palette: palette, lowPower: lowPower)
''', 'hanging dispatch')

rep('''    private static func drawEdgeGlow(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color]) {
        let breathe = 1 + sin(phase * 0.75) * s.pulse * 0.22
        let y = n.maxY + 0.5
        let points = [CGPoint(x: n.minX, y: n.minY + n.height * 0.46), CGPoint(x: n.minX, y: y), CGPoint(x: n.maxX, y: y), CGPoint(x: n.maxX, y: n.minY + n.height * 0.46)]
        glowLine(&ctx, points, color: c(palette, 0).opacity(intensity * breathe), width: CGFloat(s.thickness), bloom: s.softness / 22)
''', '''    private static func drawEdgeGlow(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?) {
        let breathe = 1 + sin(phase * 0.75) * s.pulse * 0.22
        let y = n.maxY + 0.5
        let falloff = 0.52 + s.falloff * 0.48
        let points = [CGPoint(x: n.minX, y: n.minY + n.height * 0.46), CGPoint(x: n.minX, y: y), CGPoint(x: n.maxX, y: y), CGPoint(x: n.maxX, y: n.minY + n.height * 0.46)]
        glowLine(&ctx, points, color: c(palette, 0).opacity(intensity * breathe * falloff), width: CGFloat(s.thickness), bloom: s.softness / 22)
        if let cursor {
            let x = min(n.maxX, max(n.minX, cursor.x))
            let anchor = CGPoint(x: x, y: y)
            let reaction = cursorInfluence(cursor, point: anchor, settings: s)
            if reaction.strength > 0 {
                let half = CGFloat(12 + reaction.strength * 22)
                glowLine(&ctx, [CGPoint(x:max(n.minX,x-half),y:y), CGPoint(x:min(n.maxX,x+half),y:y)], color:c(palette,1).opacity(intensity*(0.35+reaction.strength)), width:CGFloat(s.thickness*1.15), bloom:min(1,s.softness/18))
            }
        }
''', 'edge glow behavior')
rep('''    private static func drawHalo(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color]) {
        let p = 1 + sin(phase * 0.55) * s.pulse * 0.18
''', '''    private static func drawHalo(_ ctx: inout GraphicsContext, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], cursor: CGPoint?) {
        let interaction = cursorInfluence(cursor, point: CGPoint(x:n.midX,y:n.maxY), settings:s).strength
        let p = 1 + sin(phase * 0.55) * s.pulse * 0.18 + interaction * 0.08
        let falloff = 0.52 + s.falloff * 0.48
''', 'halo behavior')
rep('            ellipse(&ctx, rect: rect, color: c(palette, i).opacity(intensity * (0.18 - Double(i) * 0.025)), fill: false, width: CGFloat(5 + i * 3))\n',
    '            ellipse(&ctx, rect: rect, color: c(palette, i).opacity(intensity * falloff * (0.18 - Double(i) * 0.025) * (1 + interaction)), fill: false, width: CGFloat(5 + i * 3))\n', 'halo rings')

rep('''    private static func drawHanging(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], stars: Bool, cursor: CGPoint?, lowPower: Bool) {
        let count = max(2, min(lowPower ? 12 : 24, s.count)); let span = n.width * 0.88
''', '''    private static func drawHanging(_ ctx: inout GraphicsContext, size: CGSize, notch n: CGRect, s: NotchAmbientSettings, phase: Double, intensity: Double, palette: [Color], stars: Bool, ornaments: Bool, cursor: CGPoint?, lowPower: Bool) {
        let count = max(2, min(lowPower ? 12 : 24, s.count)); let span = n.width * CGFloat(min(1.35, max(0.55, 0.55 + s.spacing * 0.33)))
''', 'hanging spacing')
rep('''            if stars {
                let r = CGFloat(2.5 + rand(i, seed: s.seed, salt: 14)*2.2)
                line(&ctx, [CGPoint(x:end.x-r,y:end.y), CGPoint(x:end.x+r,y:end.y)], color: color, width: 1)
                line(&ctx, [CGPoint(x:end.x,y:end.y-r), CGPoint(x:end.x,y:end.y+r)], color: color, width: 1)
                ellipse(&ctx, rect: CGRect(x:end.x-1.2,y:end.y-1.2,width:2.4,height:2.4), color: color, fill: true)
            } else {
''', '''            if stars {
                let r = CGFloat(2.5 + rand(i, seed: s.seed, salt: 14)*2.2)
                if i.isMultiple(of: 3) {
                    var moon = Path(); moon.move(to:CGPoint(x:end.x,y:end.y-r-1)); moon.addCurve(to:CGPoint(x:end.x,y:end.y+r+1),control1:CGPoint(x:end.x-r*1.4,y:end.y-r*0.25),control2:CGPoint(x:end.x-r*1.4,y:end.y+r*0.35)); moon.addCurve(to:CGPoint(x:end.x,y:end.y-r-1),control1:CGPoint(x:end.x-r*0.10,y:end.y+r*0.30),control2:CGPoint(x:end.x-r*0.10,y:end.y-r*0.28)); moon.closeSubpath(); ctx.fill(moon,with:.color(color))
                } else {
                    line(&ctx, [CGPoint(x:end.x-r,y:end.y), CGPoint(x:end.x+r,y:end.y)], color: color, width: 1)
                    line(&ctx, [CGPoint(x:end.x,y:end.y-r), CGPoint(x:end.x,y:end.y+r)], color: color, width: 1)
                    ellipse(&ctx, rect: CGRect(x:end.x-1.2,y:end.y-1.2,width:2.4,height:2.4), color: color, fill: true)
                }
            } else if ornaments {
                let radius=CGFloat(3.2+rand(i,seed:s.seed,salt:16)*2.1)
                line(&ctx,[CGPoint(x:end.x,y:end.y-radius-3),CGPoint(x:end.x,y:end.y-radius)],color:Color.white.opacity(0.28+intensity*0.25),width:0.7)
                ellipse(&ctx,rect:CGRect(x:end.x-radius,y:end.y-radius,width:radius*2,height:radius*2),color:c(palette,i).opacity(0.42+intensity*0.48),fill:true)
                line(&ctx,[CGPoint(x:end.x-radius*0.45,y:end.y-radius*0.45),CGPoint(x:end.x+radius*0.35,y:end.y+radius*0.35)],color:Color.white.opacity(0.22),width:0.65)
            } else {
''', 'hanging art')

rep('''            for i in 0..<count { let side = i.isMultiple(of:2) ? n.minX : n.maxX; let spread=CGFloat(rand(i,seed:s.seed,salt:31)*30); let x=side + (i.isMultiple(of:2) ? -spread:spread); let h=CGFloat(4+rand(i,seed:s.seed,salt:32)*18*s.density); line(&ctx,[CGPoint(x:x,y:n.maxY+2),CGPoint(x:x+CGFloat(sin(phase+Double(i)))*1.8*s.sway,y:n.maxY-h)],color:c(palette,i).opacity(0.32+intensity*0.45),width:1.1) }
''', '''            for i in 0..<count { let side = i.isMultiple(of:2) ? n.minX : n.maxX; let spread=CGFloat(rand(i,seed:s.seed,salt:31)*30); let x=side + (i.isMultiple(of:2) ? -spread:spread); let h=CGFloat(4+rand(i,seed:s.seed,salt:32)*18*s.density); let tip=CGPoint(x:x+CGFloat(sin(phase+Double(i)))*1.8*s.sway,y:n.maxY-h); let react=cursorInfluence(cursor,point:tip,settings:s); line(&ctx,[CGPoint(x:x,y:n.maxY+2),CGPoint(x:tip.x+react.dx,y:tip.y+react.dy)],color:c(palette,i).opacity(0.32+intensity*0.45),width:1.1) }
''', 'moss cursor')

rep('''        case .portal:
            let center=CGPoint(x:n.midX,y:n.midY+5)
            for i in 0..<7 { let pad=CGFloat(7+i*7); ellipse(&ctx,rect:CGRect(x:center.x-n.width/2-pad,y:center.y-CGFloat(13+i*2),width:n.width+pad*2,height:CGFloat(26+i*4)),color:c(palette,i).opacity(intensity*(0.25-Double(i)*0.022)),fill:false,width:CGFloat(1.2+(i%2))) }
''', '''        case .portal:
            let center=CGPoint(x:n.midX,y:n.midY+5)
            let interaction=cursorInfluence(cursor,point:center,settings:s).strength
            for i in 0..<7 { let pad=CGFloat(7+i*7); ellipse(&ctx,rect:CGRect(x:center.x-n.width/2-pad,y:center.y-CGFloat(13+i*2),width:n.width+pad*2,height:CGFloat(26+i*4)),color:c(palette,i).opacity(intensity*(0.25-Double(i)*0.022)*(1+interaction*1.3)),fill:false,width:CGFloat(1.2+(i%2))) }
''', 'portal rings')
# The particle loop is intentionally minified in the renderer; change just the inner expressions.
rep('CGFloat((phase*9+Double(i)*7).truncatingRemainder(dividingBy:18))',
    'CGFloat((phase*(9+interaction*6)+Double(i)*7).truncatingRemainder(dividingBy:18))', 'portal speed')
rep('c(palette,i).opacity(intensity*0.58),fill:true) }\n        case .reactor:',
    'c(palette,i).opacity(intensity*(0.58+interaction*0.32)),fill:true) }\n        case .reactor:', 'portal intensity')

p.write_text(text)
print('Notch Ambient interaction polish v2 applied')
