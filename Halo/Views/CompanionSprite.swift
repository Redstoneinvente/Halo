import SwiftUI

// MARK: - Premium EI vector content

/// Shared motion vocabulary. The same semantic states drive the compact ambient pet,
/// the dedicated EI surface and future pet definitions; species only decide how they express them.
enum HaloCompanionMotion: String, CaseIterable {
    case hidden, peekEyes, peekEars, peek, observe, idle, walk, look, greet, celebrate
    case sleep, snack, dance, stretch, groom, playful, affectionate, tired, excited, paw, tail
}

/// Smooth vector companion renderer. `style == .pixel` is intentionally treated as the
/// premium soft-vector style so installations that saved the legacy preference never fall
/// back to pixel art.
struct HaloCompanionSprite: View {
    let kind: EIPetKind
    let style: EIPetVisualStyle
    var size: CGFloat
    var primary: Color
    var accent: Color
    var motion: HaloCompanionMotion = .idle
    var facingRight = true

    // Kept for source/settings compatibility with pre-EI-v2 builds. They no longer affect EI art.
    var displayPreset: EIPixelDisplayPreset = .clean
    var pixelGrid = false
    var pixelGlow = true
    var scanlines = false
    var ghosting = false
    var brightnessVariation = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.20 : animationInterval, paused: false)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                companion(in: proxy.size, phase: phase)
                    .scaleEffect(x: facingRight ? 1 : -1, y: 1)
                    .offset(y: verticalOffset(phase))
                    .rotationEffect(.degrees(bodyRotation(phase)))
                    .opacity(motion == .hidden ? 0 : 1)
            }
        }
        .frame(width: size, height: size * 0.82)
        .accessibilityLabel("\(kind.rawValue) companion")
    }

    private var animationInterval: Double {
        switch motion {
        case .walk, .dance, .celebrate, .playful, .excited: return 1.0 / 36.0
        case .greet, .snack, .peek, .observe, .paw, .tail, .stretch, .groom: return 1.0 / 28.0
        default: return 1.0 / 18.0
        }
    }

    private var renderedStyle: EIPetVisualStyle { style == .pixel ? .smooth : style }

    private func verticalOffset(_ phase: Double) -> CGFloat {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .walk: return CGFloat(-abs(sin(phase * 9.0)) * 2.2)
        case .dance, .celebrate, .excited: return CGFloat(-abs(sin(phase * 6.8)) * 4.4)
        case .peek, .peekEyes, .peekEars: return CGFloat(sin(phase * 1.7) * 0.8)
        case .sleep: return 2
        default: return CGFloat(sin(phase * 1.15) * 0.7)
        }
    }

    private func bodyRotation(_ phase: Double) -> Double {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .dance: return sin(phase * 5.6) * 5.5
        case .celebrate, .excited: return sin(phase * 7.2) * 3.2
        case .look, .observe: return sin(phase * 0.8) * 1.8
        default: return 0
        }
    }

    @ViewBuilder
    private func companion(in available: CGSize, phase: Double) -> some View {
        let s = min(available.width, available.height / 0.82)
        let blink = blinkAmount(phase)
        let look = eyeLook(phase)
        let breathing = reduceMotion ? 1.0 : 1.0 + sin(phase * 1.35) * 0.012
        let tailAngle = tailMotion(phase)
        let earAngle = earMotion(phase)
        let leg = reduceMotion ? 0 : sin(phase * 9.0) * (motion == .walk ? 10 : 1.2)
        let bodyFill = companionGradient(base: primary)
        let faceFill = companionGradient(base: faceColor)
        let line = renderedStyle == .minimal ? primary.opacity(0.86) : Color.white.opacity(0.07)
        let lineWidth = renderedStyle == .minimal ? max(1.25, s * 0.012) : max(0.6, s * 0.006)
        let reveal = revealAmount

        ZStack {
            // Ground contact shadow gives the animal weight without turning it into a card.
            Ellipse()
                .fill(Color.black.opacity(motion == .sleep ? 0.28 : 0.20))
                .frame(width: s * (motion == .sleep ? 0.58 : 0.50), height: s * 0.075)
                .blur(radius: s * 0.018)
                .offset(x: -s * 0.02, y: s * 0.285)

            // Tail is behind the body and deliberately settles after the body motion.
            CompanionTailShape(kind: kind, curl: tailCurl)
                .stroke(tailGradient, style: StrokeStyle(lineWidth: tailWidth(s), lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.38, height: s * 0.48)
                .rotationEffect(.degrees(tailAngle), anchor: .bottomLeading)
                .offset(x: -s * 0.29, y: s * 0.055)
                .opacity(motion == .peekEyes || motion == .peekEars ? 0 : 1)

            // Rear leg.
            Capsule(style: .continuous)
                .fill(bodyFill)
                .overlay(Capsule().stroke(line, lineWidth: lineWidth))
                .frame(width: s * 0.135, height: s * 0.27)
                .rotationEffect(.degrees(-leg), anchor: .top)
                .offset(x: -s * 0.15, y: s * 0.22)

            // Body.
            Ellipse()
                .fill(bodyFill)
                .overlay(Ellipse().stroke(line, lineWidth: lineWidth))
                .frame(width: s * 0.58, height: s * (motion == .sleep ? 0.31 : 0.36))
                .scaleEffect(x: motion == .stretch ? 1.16 : 1, y: motion == .sleep ? 0.78 : breathing, anchor: .bottom)
                .offset(x: -s * 0.05, y: s * (motion == .sleep ? 0.16 : 0.11))

            speciesChest(size: s)

            // Front leg / paw with secondary motion.
            Capsule(style: .continuous)
                .fill(faceFill)
                .overlay(Capsule().stroke(line, lineWidth: lineWidth))
                .frame(width: s * 0.12, height: s * 0.255)
                .rotationEffect(.degrees(frontLegAngle(phase)), anchor: .top)
                .offset(x: s * 0.11, y: s * 0.235)

            // Head follows body with a tiny delay.
            head(size: s, phase: phase, fill: faceFill, line: line, lineWidth: lineWidth,
                 blink: blink, look: look, earAngle: earAngle)
                .offset(x: s * 0.205, y: -s * 0.07 + headYOffset(phase))

            accessory(size: s, phase: phase)
        }
        .frame(width: s, height: s * 0.82)
        .drawingGroup(opaque: false, colorMode: .linear)
        .offset(y: (1 - reveal) * s * 0.42)
        .mask(alignment: .bottom) {
            Rectangle().frame(height: max(1, s * 0.82 * reveal), alignment: .bottom)
        }
    }

    private var faceColor: Color {
        switch kind {
        case .cat: return primary.opacity(0.98)
        case .dog: return primary.opacity(0.96)
        case .fox: return Color(red: 0.93, green: 0.39, blue: 0.16).mix(with: primary, amount: 0.22)
        }
    }

    private var revealAmount: CGFloat {
        switch motion {
        case .hidden: return 0
        case .peekEyes: return 0.23
        case .peekEars: return 0.34
        case .peek, .paw, .tail: return 0.58
        default: return 1
        }
    }

    private var tailCurl: CGFloat {
        switch kind { case .fox: return 0.92; case .cat: return 0.62; case .dog: return 0.34 }
    }

    private func companionGradient(base: Color) -> LinearGradient {
        let top: Color
        switch renderedStyle {
        case .illustrated: top = base.mix(with: .white, amount: 0.22)
        case .minimal: top = base.opacity(0.18)
        default: top = base.mix(with: .white, amount: 0.10)
        }
        let bottom = renderedStyle == .minimal ? base.opacity(0.08) : base.mix(with: .black, amount: 0.18)
        return LinearGradient(colors: [top, base, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var tailGradient: LinearGradient {
        LinearGradient(colors: [faceColor.mix(with: .white, amount: 0.08), faceColor.mix(with: .black, amount: 0.22)], startPoint: .top, endPoint: .bottom)
    }

    private func tailWidth(_ s: CGFloat) -> CGFloat {
        switch kind { case .fox: return s * 0.12; case .cat: return s * 0.072; case .dog: return s * 0.083 }
    }

    private func blinkAmount(_ phase: Double) -> CGFloat {
        if motion == .sleep || motion == .tired { return 0.08 }
        let cycle = phase.truncatingRemainder(dividingBy: 5.7)
        if cycle > 5.30 && cycle < 5.46 { return 0.10 }
        if cycle > 2.18 && cycle < 2.28 { return 0.16 }
        return 1
    }

    private func eyeLook(_ phase: Double) -> CGFloat {
        guard motion == .look || motion == .observe || motion == .curiousMotion else { return 0 }
        return CGFloat(sin(phase * 0.72) * 0.52)
    }

    private func tailMotion(_ phase: Double) -> Double {
        guard !reduceMotion else { return 0 }
        let speed: Double
        let amplitude: Double
        switch motion {
        case .greet, .excited, .affectionate: speed = kind == .dog ? 8.5 : 4.8; amplitude = kind == .dog ? 25 : 12
        case .dance, .playful: speed = 6.0; amplitude = 18
        case .sleep: speed = 0.65; amplitude = 2.4
        default: speed = kind == .fox ? 1.05 : 1.65; amplitude = kind == .fox ? 5 : 8
        }
        return sin(phase * speed - 0.55) * amplitude
    }

    private func earMotion(_ phase: Double) -> Double {
        guard !reduceMotion else { return 0 }
        if motion == .observe || motion == .look || motion == .peek { return sin(phase * 1.9) * 7 }
        if motion == .excited || motion == .greet { return sin(phase * 5.2) * 5 }
        return sin(phase * 0.75) * 1.8
    }

    private func headYOffset(_ phase: Double) -> CGFloat {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .groom: return CGFloat(sin(phase * 2.8) * 4 + 5)
        case .sleep: return 8
        case .stretch: return 3
        case .dance: return CGFloat(sin(phase * 5.4 - 0.25) * 3)
        default: return CGFloat(sin(phase * 1.2 - 0.18) * 0.7)
        }
    }

    private func frontLegAngle(_ phase: Double) -> Double {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .walk: return sin(phase * 9.0) * 12
        case .greet, .paw, .affectionate: return -34 + sin(phase * 5.5) * 12
        case .groom: return -48 + sin(phase * 3.4) * 6
        case .stretch: return 28
        default: return 0
        }
    }

    @ViewBuilder
    private func head(size s: CGFloat, phase: Double, fill: LinearGradient, line: Color,
                      lineWidth: CGFloat, blink: CGFloat, look: CGFloat, earAngle: Double) -> some View {
        ZStack {
            ears(size: s, fill: fill, line: line, lineWidth: lineWidth, phase: phase, earAngle: earAngle)
                .offset(y: -s * 0.135)

            Ellipse()
                .fill(fill)
                .overlay(Ellipse().stroke(line, lineWidth: lineWidth))
                .frame(width: s * headWidth, height: s * headHeight)

            if kind == .fox {
                FoxCheekShape()
                    .fill(Color.white.opacity(0.82))
                    .frame(width: s * 0.27, height: s * 0.13)
                    .offset(x: s * 0.045, y: s * 0.075)
            }

            if kind == .dog {
                Ellipse().fill(Color.white.opacity(0.20))
                    .frame(width: s * 0.20, height: s * 0.12)
                    .offset(x: s * 0.055, y: s * 0.075)
            }

            eyes(size: s, blink: blink, look: look)
                .offset(y: -s * 0.012)

            noseAndMouth(size: s)
                .offset(x: s * 0.055, y: s * 0.073)

            if motion == .tired {
                Capsule().fill(Color.white.opacity(0.46)).frame(width: s * 0.055, height: 1.4)
                    .rotationEffect(.degrees(-12)).offset(x: s * 0.11, y: -s * 0.02)
            }
        }
        .frame(width: s * 0.42, height: s * 0.40)
        .rotationEffect(.degrees(headTilt(phase)))
    }

    private var headWidth: CGFloat { kind == .fox ? 0.36 : kind == .dog ? 0.38 : 0.35 }
    private var headHeight: CGFloat { kind == .fox ? 0.31 : kind == .dog ? 0.33 : 0.32 }

    @ViewBuilder
    private func ears(size s: CGFloat, fill: LinearGradient, line: Color, lineWidth: CGFloat,
                      phase: Double, earAngle: Double) -> some View {
        switch kind {
        case .dog:
            HStack(spacing: s * 0.17) {
                CompanionFloppyEarShape().fill(accent.mix(with: primary, amount: 0.35))
                    .overlay(CompanionFloppyEarShape().stroke(line, lineWidth: lineWidth))
                    .frame(width: s * 0.13, height: s * 0.20)
                    .rotationEffect(.degrees(17 + earAngle), anchor: .top)
                CompanionFloppyEarShape().fill(accent.mix(with: primary, amount: 0.35))
                    .overlay(CompanionFloppyEarShape().stroke(line, lineWidth: lineWidth))
                    .frame(width: s * 0.13, height: s * 0.20)
                    .scaleEffect(x: -1, y: 1)
                    .rotationEffect(.degrees(-17 - earAngle), anchor: .top)
            }
        case .cat, .fox:
            HStack(spacing: s * (kind == .fox ? 0.105 : 0.09)) {
                CompanionEarShape().fill(fill)
                    .overlay(CompanionEarShape().stroke(line, lineWidth: lineWidth))
                    .overlay(CompanionEarShape().fill(accent.opacity(kind == .fox ? 0.40 : 0.28)).scaleEffect(0.55).offset(y: s * 0.012))
                    .frame(width: s * 0.15, height: s * (kind == .fox ? 0.20 : 0.17))
                    .rotationEffect(.degrees(-4 + earAngle), anchor: .bottom)
                CompanionEarShape().fill(fill)
                    .overlay(CompanionEarShape().stroke(line, lineWidth: lineWidth))
                    .overlay(CompanionEarShape().fill(accent.opacity(kind == .fox ? 0.40 : 0.28)).scaleEffect(0.55).offset(y: s * 0.012))
                    .frame(width: s * 0.15, height: s * (kind == .fox ? 0.20 : 0.17))
                    .rotationEffect(.degrees(4 - earAngle * 0.7), anchor: .bottom)
            }
        }
    }

    private func eyes(size s: CGFloat, blink: CGFloat, look: CGFloat) -> some View {
        HStack(spacing: s * 0.075) {
            CompanionEye(blink: blink, look: look, size: s, iris: eyeColor)
            CompanionEye(blink: blink, look: look, size: s, iris: eyeColor)
        }
    }

    private var eyeColor: Color {
        switch kind {
        case .cat: return Color(red: 0.65, green: 0.82, blue: 0.38)
        case .dog: return Color(red: 0.45, green: 0.29, blue: 0.17)
        case .fox: return Color(red: 0.68, green: 0.56, blue: 0.30)
        }
    }

    private func noseAndMouth(size s: CGFloat) -> some View {
        VStack(spacing: s * 0.008) {
            RoundedRectangle(cornerRadius: s * 0.02, style: .continuous)
                .fill(kind == .cat ? accent.mix(with: .pink, amount: 0.25) : Color.black.opacity(0.74))
                .frame(width: s * 0.052, height: s * 0.035)
            CompanionMouthShape()
                .stroke(Color.black.opacity(0.43), style: StrokeStyle(lineWidth: max(0.8, s * 0.008), lineCap: .round))
                .frame(width: s * 0.075, height: s * 0.038)
        }
    }

    private func headTilt(_ phase: Double) -> Double {
        guard !reduceMotion else { return 0 }
        if kind == .dog && (motion == .observe || motion == .look) { return 8 + sin(phase * 0.8) * 5 }
        if kind == .fox && motion == .observe { return sin(phase * 0.55) * 4 }
        if motion == .curiousMotion { return 6 + sin(phase * 0.8) * 3 }
        return 0
    }

    @ViewBuilder
    private func speciesChest(size s: CGFloat) -> some View {
        if kind == .fox {
            CompanionChestShape().fill(Color.white.opacity(0.78))
                .frame(width: s * 0.20, height: s * 0.22)
                .offset(x: s * 0.13, y: s * 0.12)
        } else if kind == .dog {
            CompanionChestShape().fill(Color.white.opacity(0.16))
                .frame(width: s * 0.18, height: s * 0.20)
                .offset(x: s * 0.12, y: s * 0.13)
        }
    }

    @ViewBuilder
    private func accessory(size s: CGFloat, phase: Double) -> some View {
        switch motion {
        case .sleep:
            ZStack {
                Capsule().fill(accent.opacity(0.20)).frame(width: s * 0.38, height: s * 0.10)
                    .offset(x: -s * 0.02, y: s * 0.27)
                Text("z")
                    .font(.system(size: s * 0.105, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.48))
                    .offset(x: s * 0.33, y: -s * 0.23)
            }
        case .snack:
            RoundedRectangle(cornerRadius: s * 0.018, style: .continuous)
                .fill(accent)
                .frame(width: s * 0.085, height: s * 0.055)
                .rotationEffect(.degrees(18))
                .offset(x: s * 0.39, y: s * 0.11)
        case .celebrate:
            Image(systemName: "sparkles")
                .font(.system(size: s * 0.13, weight: .medium))
                .foregroundStyle(accent.opacity(0.86))
                .offset(x: s * 0.33, y: -s * 0.22)
                .scaleEffect(0.85 + abs(sin(phase * 4.8)) * 0.18)
        case .affectionate:
            Image(systemName: "heart.fill")
                .font(.system(size: s * 0.095, weight: .medium))
                .foregroundStyle(Color.pink.opacity(0.78))
                .offset(x: s * 0.34, y: -s * 0.20)
                .scaleEffect(0.9 + abs(sin(phase * 3.5)) * 0.12)
        case .tired:
            CupShape().fill(accent.opacity(0.88)).frame(width: s * 0.10, height: s * 0.08)
                .offset(x: s * 0.33, y: s * 0.13)
        case .playful:
            Circle().fill(accent.opacity(0.92)).frame(width: s * 0.075, height: s * 0.075)
                .offset(x: s * 0.39 + CGFloat(sin(phase * 5.2)) * s * 0.035, y: s * 0.18)
        default:
            EmptyView()
        }
    }
}

private extension HaloCompanionMotion {
    var curiousMotion: Bool { self == .look || self == .observe || self == .peek }
}

private struct CompanionEye: View {
    let blink: CGFloat
    let look: CGFloat
    let size: CGFloat
    let iris: Color
    var body: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.065, height: max(1.2, size * 0.072 * blink))
            Circle().fill(iris).frame(width: size * 0.030, height: size * 0.030)
                .overlay(Circle().fill(Color.black.opacity(0.82)).frame(width: size * 0.014, height: size * 0.014))
                .overlay(Circle().fill(Color.white.opacity(0.88)).frame(width: size * 0.007, height: size * 0.007).offset(x: -size * 0.006, y: -size * 0.006))
                .offset(x: look * size * 0.013)
                .opacity(blink < 0.3 ? 0 : 1)
        }
        .frame(width: size * 0.07, height: size * 0.08)
    }
}

// MARK: - Premium plant renderer

struct HaloPlantRenderer: View {
    let kind: EIPlantKind
    var size: CGFloat
    var plantColor: Color
    var potColor: Color
    var growth: Double
    var environment: EIEnvironment
    var reaction: EIReactionKind?
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.30 : 1.0 / 24.0, paused: false)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            plant(phase: phase)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(kind.rawValue) environmental plant")
    }

    private func plant(phase: Double) -> some View {
        let g = CGFloat(min(1, max(0.06, growth)))
        let night = environment.timeOfDay == .night || reaction == .plantNight
        let rain = environment.weather?.isRaining == true || reaction == .plantRain
        let music = environment.isMusicPlaying
        let wind = reduceMotion ? 0 : sin(phase * (music ? 1.8 : 0.75)) * (music ? 3.2 : 1.4)
        let ambient = night ? 0.80 : 1.0

        return ZStack(alignment: .bottom) {
            Ellipse().fill(Color.black.opacity(0.20)).frame(width: size * 0.54, height: size * 0.10)
                .blur(radius: size * 0.015).offset(y: size * 0.025)

            pot(size: size)

            switch kind {
            case .bonsai:
                bonsai(size: size, growth: g, wind: wind, ambient: ambient, phase: phase)
            case .flower:
                flowering(size: size, growth: g, wind: wind, ambient: ambient, phase: phase)
            case .vine:
                vine(size: size, growth: g, wind: wind, ambient: ambient, phase: phase)
            case .succulent:
                succulent(size: size, growth: g, ambient: ambient, phase: phase)
            case .fern:
                fern(size: size, growth: g, wind: wind, ambient: ambient, phase: phase)
            }

            if rain {
                rainDrops(size: size, phase: phase)
            }
        }
        .frame(width: size, height: size)
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private func pot(size s: CGFloat) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: s * 0.025, style: .continuous)
                .fill(potColor.mix(with: .white, amount: 0.12))
                .frame(width: s * 0.40, height: s * 0.075)
            PlantPotShape()
                .fill(LinearGradient(colors: [potColor, potColor.mix(with: .black, amount: 0.28)], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.34, height: s * 0.22)
        }
        .shadow(color: Color.black.opacity(0.20), radius: s * 0.025, y: s * 0.018)
    }

    private func bonsai(size s: CGFloat, growth g: CGFloat, wind: Double, ambient: Double, phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            BonsaiTrunkShape(growth: g)
                .stroke(potColor.mix(with: .black, amount: 0.36), style: StrokeStyle(lineWidth: max(3, s * 0.055), lineCap: .round, lineJoin: .round))
                .frame(width: s * 0.48, height: s * 0.60)
                .offset(y: -s * 0.18)
            ForEach(0..<9, id: \.self) { index in
                let visible = CGFloat(index + 1) / 9.0 <= max(0.22, g + 0.14)
                if visible {
                    let x = CGFloat([-0.20, 0.10, -0.03, 0.22, -0.17, 0.05, 0.25, -0.06, 0.15][index]) * s
                    let y = CGFloat([-0.48, -0.43, -0.55, -0.37, -0.31, -0.28, -0.23, -0.18, -0.15][index]) * s
                    leafCluster(size: s * (0.20 + CGFloat(index % 3) * 0.018), phase: phase + Double(index), ambient: ambient)
                        .rotationEffect(.degrees(wind * (index.isMultiple(of: 2) ? 1 : -0.7)), anchor: .bottom)
                        .offset(x: x, y: y)
                }
            }
        }
    }

    private func flowering(size s: CGFloat, growth g: CGFloat, wind: Double, ambient: Double, phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<5, id: \.self) { index in
                let angle = Double(index - 2) * 12.0
                Capsule(style: .continuous).fill(plantColor.mix(with: .black, amount: 0.18).opacity(ambient))
                    .frame(width: s * 0.025, height: s * (0.38 + g * 0.20))
                    .rotationEffect(.degrees(angle + wind * 0.45), anchor: .bottom)
                    .offset(y: -s * 0.18)
                leaf(size: s * 0.17, ambient: ambient)
                    .rotationEffect(.degrees(angle - 32 + wind), anchor: .trailing)
                    .offset(x: CGFloat(index - 2) * s * 0.055, y: -s * (0.30 + CGFloat(index % 2) * 0.08))
            }
            if g > 0.34 || reaction == .plantBloom {
                ForEach(0..<3, id: \.self) { index in
                    flower(size: s * 0.16, open: reaction == .plantBloom ? 1 : min(1, (g - 0.30) * 1.8), phase: phase + Double(index))
                        .offset(x: CGFloat(index - 1) * s * 0.13, y: -s * (0.61 + CGFloat(index % 2) * 0.055))
                        .rotationEffect(.degrees(wind * 0.65))
                }
            }
        }
    }

    private func vine(size s: CGFloat, growth g: CGFloat, wind: Double, ambient: Double, phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            VineStemShape(progress: g)
                .trim(from: 0, to: g)
                .stroke(plantColor.mix(with: .black, amount: 0.22).opacity(ambient), style: StrokeStyle(lineWidth: max(2, s * 0.025), lineCap: .round))
                .frame(width: s * 0.64, height: s * 0.70)
                .offset(y: -s * 0.16)
            ForEach(0..<10, id: \.self) { index in
                if CGFloat(index) / 10.0 < g {
                    leaf(size: s * 0.13, ambient: ambient)
                        .rotationEffect(.degrees(Double(index.isMultiple(of: 2) ? -38 : 38) + wind * 0.6))
                        .offset(x: sin(Double(index) * 1.17) * s * 0.22,
                                y: -s * (0.24 + CGFloat(index) * 0.047))
                }
            }
            if reaction == .plantBloom && g > 0.45 {
                flower(size: s * 0.12, open: 1, phase: phase).offset(x: s * 0.20, y: -s * 0.62)
            }
        }
    }

    private func succulent(size s: CGFloat, growth g: CGFloat, ambient: Double, phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<11, id: \.self) { index in
                let angle = Double(index) / 11.0 * 320 - 160
                let inner = index >= 7
                PlantSucculentLeaf()
                    .fill(LinearGradient(colors: [plantColor.mix(with: .white, amount: 0.20).opacity(ambient), plantColor.mix(with: .black, amount: 0.20).opacity(ambient)], startPoint: .top, endPoint: .bottom))
                    .frame(width: s * (inner ? 0.15 : 0.19), height: s * (inner ? 0.28 : 0.36) * max(0.58, g))
                    .rotationEffect(.degrees(angle * (inner ? 0.38 : 0.58)), anchor: .bottom)
                    .offset(y: -s * 0.17)
            }
        }
    }

    private func fern(size s: CGFloat, growth g: CGFloat, wind: Double, ambient: Double, phase: Double) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<7, id: \.self) { index in
                let angle = Double(index - 3) * 13.0 + wind
                FernFrondShape()
                    .stroke(plantColor.opacity(ambient), style: StrokeStyle(lineWidth: max(2, s * 0.022), lineCap: .round))
                    .overlay(FernLeaflets().stroke(plantColor.mix(with: .white, amount: 0.10).opacity(ambient), lineWidth: max(1, s * 0.012)))
                    .frame(width: s * 0.22, height: s * (0.42 + g * 0.18))
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .offset(y: -s * 0.18)
            }
        }
    }

    private func leaf(size: CGFloat, ambient: Double) -> some View {
        PlantLeafShape()
            .fill(LinearGradient(colors: [plantColor.mix(with: .white, amount: 0.18).opacity(ambient), plantColor.mix(with: .black, amount: 0.16).opacity(ambient)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size * 0.58)
            .overlay(PlantLeafVein().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
    }

    private func leafCluster(size: CGFloat, phase: Double, ambient: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                leaf(size: size * 0.72, ambient: ambient)
                    .rotationEffect(.degrees(Double(index) * 55 - 105 + sin(phase * 0.6 + Double(index)) * 2.2), anchor: .trailing)
                    .offset(x: CGFloat(index - 2) * size * 0.09)
            }
        }
    }

    private func flower(size: CGFloat, open: Double, phase: Double) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Ellipse().fill(Color.pink.mix(with: plantColor, amount: 0.18).opacity(0.92))
                    .frame(width: size * 0.58, height: size)
                    .rotationEffect(.degrees(Double(index) * 72))
                    .scaleEffect(CGFloat(0.40 + open * 0.60))
            }
            Circle().fill(Color.yellow.opacity(0.88)).frame(width: size * 0.25, height: size * 0.25)
        }
        .rotationEffect(.degrees(sin(phase * 0.5) * 2))
    }

    @ViewBuilder
    private func rainDrops(size s: CGFloat, phase: Double) -> some View {
        ForEach(0..<6, id: \.self) { index in
            let travel = (phase * 0.48 + Double(index) * 0.17).truncatingRemainder(dividingBy: 1)
            Capsule().fill(Color.cyan.opacity(0.40)).frame(width: 1.5, height: s * 0.055)
                .offset(x: CGFloat(index - 3) * s * 0.12,
                        y: -s * 0.72 + CGFloat(travel) * s * 0.56)
        }
    }
}

// MARK: - Tiny City vector simulation

struct HaloCityRenderer: View {
    var accent: Color
    var environment: EIEnvironment
    var reaction: EIReactionKind?
    var seed: Int
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30.0, paused: false)) { timeline in
            GeometryReader { proxy in
                city(size: proxy.size, phase: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .accessibilityLabel("Tiny City environmental simulation")
    }

    private func city(size: CGSize, phase: Double) -> some View {
        let night = environment.timeOfDay == .night || reaction == .cityNight
        let evening = environment.timeOfDay == .evening
        let rain = environment.weather?.isRaining == true || reaction == .cityRain
        let busy = reaction == .cityBusy || environment.timeOfDay == .day
        let music = environment.isMusicPlaying || reaction == .cityMusic
        let roadY = size.height * 0.76
        let speed = reduceMotion ? 0 : (busy ? 34.0 : night ? 12.0 : 24.0)
        let carX = CGFloat((phase * speed).truncatingRemainder(dividingBy: max(1, size.width + 70))) - 35
        let taxiX = size.width - CGFloat((phase * speed * 0.68 + 96).truncatingRemainder(dividingBy: max(1, size.width + 80))) + 40
        let sky: [Color] = night
            ? [Color(red: 0.025, green: 0.035, blue: 0.09), Color(red: 0.07, green: 0.09, blue: 0.17)]
            : evening
                ? [Color(red: 0.20, green: 0.12, blue: 0.22), Color(red: 0.54, green: 0.25, blue: 0.20)]
                : [Color(red: 0.08, green: 0.14, blue: 0.22), Color(red: 0.13, green: 0.24, blue: 0.32)]

        return ZStack(alignment: .bottom) {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)

            // The dark central structure deliberately borrows the notch silhouette so the city
            // reads as built around Halo rather than pasted into a rectangular viewport.
            RoundedRectangle(cornerRadius: min(22, size.height * 0.16), style: .continuous)
                .fill(Color.black.opacity(0.88))
                .frame(width: min(size.width * 0.26, 150), height: size.height * 0.55)
                .overlay(alignment: .bottom) {
                    Capsule().fill(accent.opacity(0.32)).frame(width: min(64, size.width * 0.12), height: 3).padding(.bottom, 7)
                }
                .offset(y: -size.height * 0.19)

            buildings(size: size, night: night, music: music, phase: phase)

            Rectangle().fill(Color.black.opacity(0.48)).frame(height: size.height * 0.22)
            Rectangle().fill(Color.white.opacity(0.055)).frame(height: 1).offset(y: -size.height * 0.20)

            cityCar(color: accent, taxi: false).frame(width: 32, height: 15)
                .position(x: carX, y: roadY)
            cityCar(color: Color.yellow.opacity(0.86), taxi: true).frame(width: 34, height: 15)
                .scaleEffect(x: -1, y: 1)
                .position(x: taxiX, y: roadY + size.height * 0.075)

            pedestrians(size: size, phase: phase, busy: busy, night: night, rain: rain)

            if music { club(size: size, phase: phase) }
            if rain { rainLayer(size: size, phase: phase) }
            randomMoment(size: size, phase: phase)
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private func buildings(size: CGSize, night: Bool, music: Bool, phase: Double) -> some View {
        let heights: [CGFloat] = [0.35, 0.49, 0.31, 0.44, 0.38, 0.52, 0.34, 0.42]
        return HStack(alignment: .bottom, spacing: max(2, size.width * 0.008)) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, ratio in
                let centralGap = index == 3 || index == 4
                if centralGap {
                    Color.clear.frame(width: size.width * 0.12)
                } else {
                    let buildingWidth = max(18, size.width * 0.075)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.32)], startPoint: .top, endPoint: .bottom))
                        .frame(width: buildingWidth, height: size.height * ratio)
                        .overlay(windowGrid(index: index, night: night, music: music, phase: phase).padding(5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .offset(y: -size.height * 0.20)
    }

    private func windowGrid(index: Int, night: Bool, music: Bool, phase: Double) -> some View {
        let active = night || environment.timeOfDay == .evening
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
            ForEach(0..<8, id: \.self) { window in
                let lit = active && ((window + index + seed) % 3 != 0)
                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? Color.yellow.opacity(0.45 + (music && index == 6 ? abs(sin(phase * 2.2)) * 0.28 : 0)) : Color.white.opacity(0.055))
                    .frame(height: 4)
            }
        }
    }

    private func cityCar(color: Color, taxi: Bool) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color)
                .frame(width: 30, height: 10)
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(color.mix(with: .white, amount: 0.14))
                .frame(width: 17, height: 8).offset(x: 2, y: -5)
            HStack(spacing: 14) {
                Circle().fill(Color.black.opacity(0.88)).frame(width: 6, height: 6)
                Circle().fill(Color.black.opacity(0.88)).frame(width: 6, height: 6)
            }.offset(y: 2)
            if taxi { Capsule().fill(Color.white.opacity(0.55)).frame(width: 8, height: 2).offset(y: -10) }
        }
    }

    @ViewBuilder
    private func pedestrians(size: CGSize, phase: Double, busy: Bool, night: Bool, rain: Bool) -> some View {
        let count = night ? 2 : busy ? 7 : 4
        ForEach(0..<count, id: \.self) { index in
            let lane = CGFloat(index % 2)
            let speed = reduceMotion ? 0 : Double(6 + (index * 3) % 7)
            let travel = CGFloat((phase * speed + Double(index * 53)).truncatingRemainder(dividingBy: Double(max(1, size.width + 40)))) - 20
            CityPerson(umbrella: rain && index.isMultiple(of: 2), accent: index.isMultiple(of: 3) ? accent : Color.white.opacity(0.68))
                .frame(width: 12, height: 22)
                .position(x: index.isMultiple(of: 2) ? travel : size.width - travel,
                          y: size.height * (0.68 + lane * 0.09))
        }
    }

    private func club(size: CGSize, phase: Double) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(accent.opacity(0.16 + abs(sin(phase * 2.0)) * 0.14))
            .frame(width: max(28, size.width * 0.07), height: max(18, size.height * 0.10))
            .overlay(Image(systemName: "music.note").font(.system(size: 8, weight: .bold)).foregroundStyle(accent.opacity(0.8)))
            .position(x: size.width * 0.82, y: size.height * 0.55)
    }

    @ViewBuilder
    private func rainLayer(size: CGSize, phase: Double) -> some View {
        ForEach(0..<18, id: \.self) { index in
            let travel = (phase * 0.58 + Double(index) * 0.071).truncatingRemainder(dividingBy: 1)
            Capsule().fill(Color.cyan.opacity(0.20 + Double(index % 3) * 0.04))
                .frame(width: 1, height: 9)
                .rotationEffect(.degrees(8))
                .position(x: CGFloat(index) / 18 * size.width,
                          y: CGFloat(travel) * size.height)
        }
        Rectangle().fill(Color.cyan.opacity(0.07)).frame(height: 2).blur(radius: 2).offset(y: -size.height * 0.18)
    }

    @ViewBuilder
    private func randomMoment(size: CGSize, phase: Double) -> some View {
        // Deterministic minute-scale moments: continuity without per-second simulation while asleep.
        let slot = (Int(phase / 19) + seed) % 11
        switch slot {
        case 2:
            Circle().fill(Color.red.opacity(0.76)).frame(width: 9, height: 9)
                .overlay(Rectangle().fill(Color.white.opacity(0.5)).frame(width: 1, height: 18).offset(y: 11))
                .position(x: size.width * 0.18, y: size.height * 0.23)
        case 5:
            Image(systemName: "bird.fill").font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.42))
                .position(x: CGFloat((phase * 8).truncatingRemainder(dividingBy: Double(max(1, size.width)))), y: size.height * 0.19)
        case 8:
            RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.72)).frame(width: 38, height: 15)
                .overlay(Text("DELIVERY").font(.system(size: 4, weight: .bold)).foregroundStyle(.white.opacity(0.8)))
                .position(x: size.width * 0.70, y: size.height * 0.76)
        default:
            EmptyView()
        }
    }
}

private struct CityPerson: View {
    let umbrella: Bool
    let accent: Color
    var body: some View {
        ZStack(alignment: .top) {
            if umbrella {
                ArcShape().stroke(accent.opacity(0.65), lineWidth: 1.5).frame(width: 12, height: 7).offset(y: -3)
            }
            Circle().fill(accent).frame(width: 4.5, height: 4.5)
            Capsule().fill(accent.opacity(0.88)).frame(width: 4, height: 10).offset(y: 4)
            HStack(spacing: 2) {
                Capsule().fill(accent.opacity(0.70)).frame(width: 1.5, height: 7).rotationEffect(.degrees(10))
                Capsule().fill(accent.opacity(0.70)).frame(width: 1.5, height: 7).rotationEffect(.degrees(-10))
            }.offset(y: 13)
        }
    }
}

// MARK: - Vector shapes

private struct CompanionEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control1: CGPoint(x: rect.maxX * 0.72, y: rect.height * 0.22), control2: CGPoint(x: rect.maxX * 0.95, y: rect.height * 0.70))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control1: CGPoint(x: rect.width * 0.72, y: rect.height * 0.95), control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.95))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.width * 0.05, y: rect.height * 0.70), control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.22))
        return p
    }
}

private struct CompanionFloppyEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.64), control1: CGPoint(x: rect.maxX, y: rect.height * 0.10), control2: CGPoint(x: rect.maxX, y: rect.height * 0.38))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX * 0.92, y: rect.maxY), control2: CGPoint(x: rect.width * 0.66, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.36), control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.84), control2: CGPoint(x: rect.minX, y: rect.height * 0.58))
        p.closeSubpath()
        return p
    }
}

private struct CompanionTailShape: Shape {
    let kind: EIPetKind
    let curl: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.maxY * 0.92))
        if kind == .dog {
            p.addCurve(to: CGPoint(x: rect.width * 0.74, y: rect.height * 0.26), control1: CGPoint(x: rect.width * 0.36, y: rect.height * 0.80), control2: CGPoint(x: rect.width * 0.46, y: rect.height * 0.20))
        } else {
            p.addCurve(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.20), control1: CGPoint(x: rect.width * (0.20 + curl * 0.22), y: rect.height * 0.92), control2: CGPoint(x: rect.width * (0.92 - curl * 0.08), y: rect.height * 0.78))
            p.addCurve(to: CGPoint(x: rect.width * 0.60, y: rect.height * 0.06), control1: CGPoint(x: rect.width * 0.94, y: rect.height * 0.10), control2: CGPoint(x: rect.width * 0.77, y: rect.minY))
        }
        return p
    }
}

private struct CompanionMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control1: CGPoint(x: rect.midX, y: rect.height * 0.62), control2: CGPoint(x: rect.width * 0.20, y: rect.maxY))
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control1: CGPoint(x: rect.midX, y: rect.height * 0.62), control2: CGPoint(x: rect.width * 0.80, y: rect.maxY))
        return p
    }
}

private struct CompanionChestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.52), control1: CGPoint(x: rect.width * 0.88, y: rect.height * 0.13), control2: CGPoint(x: rect.maxX, y: rect.height * 0.34))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX * 0.82, y: rect.height * 0.78), control2: CGPoint(x: rect.width * 0.62, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.height * 0.52), control1: CGPoint(x: rect.width * 0.38, y: rect.maxY), control2: CGPoint(x: rect.width * 0.12, y: rect.height * 0.78))
        p.closeSubpath()
        return p
    }
}

private struct FoxCheekShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.width * 0.18, y: rect.maxY), control2: CGPoint(x: rect.width * 0.36, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.width * 0.64, y: rect.maxY), control2: CGPoint(x: rect.width * 0.82, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.width * 0.82, y: rect.height * 0.18), control2: CGPoint(x: rect.width * 0.63, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.72, height: rect.height), cornerRadius: rect.height * 0.16)
        p.addEllipse(in: CGRect(x: rect.width * 0.62, y: rect.height * 0.22, width: rect.width * 0.34, height: rect.height * 0.48))
        return p
    }
}

private struct PlantPotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.width * 0.22, y: rect.maxY), control1: CGPoint(x: rect.width * 0.65, y: rect.maxY), control2: CGPoint(x: rect.width * 0.35, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct BonsaiTrunkShape: Shape {
    let growth: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.52), control1: CGPoint(x: rect.width * 0.48, y: rect.height * 0.82), control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.68))
        p.addCurve(to: CGPoint(x: rect.width * 0.58, y: rect.height * 0.14), control1: CGPoint(x: rect.width * 0.58, y: rect.height * 0.40), control2: CGPoint(x: rect.width * 0.65, y: rect.height * 0.28))
        p.move(to: CGPoint(x: rect.width * 0.44, y: rect.height * 0.54))
        p.addCurve(to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.34), control1: CGPoint(x: rect.width * 0.31, y: rect.height * 0.48), control2: CGPoint(x: rect.width * 0.24, y: rect.height * 0.38))
        p.move(to: CGPoint(x: rect.width * 0.52, y: rect.height * 0.34))
        p.addCurve(to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.25), control1: CGPoint(x: rect.width * 0.64, y: rect.height * 0.30), control2: CGPoint(x: rect.width * 0.72, y: rect.height * 0.25))
        return p
    }
}

private struct VineStemShape: Shape {
    let progress: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.width * 0.26, y: rect.height * 0.63), control1: CGPoint(x: rect.width * 0.70, y: rect.height * 0.86), control2: CGPoint(x: rect.width * 0.18, y: rect.height * 0.76))
        p.addCurve(to: CGPoint(x: rect.width * 0.70, y: rect.height * 0.31), control1: CGPoint(x: rect.width * 0.35, y: rect.height * 0.51), control2: CGPoint(x: rect.width * 0.78, y: rect.height * 0.48))
        p.addCurve(to: CGPoint(x: rect.width * 0.48, y: rect.minY), control1: CGPoint(x: rect.width * 0.61, y: rect.height * 0.20), control2: CGPoint(x: rect.width * 0.38, y: rect.height * 0.12))
        return p
    }
}

private struct PlantLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control1: CGPoint(x: rect.width * 0.30, y: rect.minY), control2: CGPoint(x: rect.width * 0.72, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.midY), control1: CGPoint(x: rect.width * 0.70, y: rect.maxY), control2: CGPoint(x: rect.width * 0.28, y: rect.maxY))
        return p
    }
}

private struct PlantLeafVein: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p
    }
}

private struct PlantSucculentLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control1: CGPoint(x: rect.maxX, y: rect.height * 0.34), control2: CGPoint(x: rect.maxX, y: rect.height * 0.77))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control1: CGPoint(x: rect.width * 0.72, y: rect.height * 0.91), control2: CGPoint(x: rect.width * 0.28, y: rect.height * 0.91))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.minX, y: rect.height * 0.77), control2: CGPoint(x: rect.minX, y: rect.height * 0.34))
        return p
    }
}

private struct FernFrondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: rect.midX, y: rect.maxY)); p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY), control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.62), control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.34)); return p
    }
}

private struct FernLeaflets: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 1..<7 {
            let y = rect.maxY - CGFloat(i) / 7 * rect.height
            let x = rect.midX + sin(CGFloat(i) * 0.9) * rect.width * 0.10
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: rect.minX, y: y - rect.height * 0.06))
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y - rect.height * 0.06))
        }
        return p
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width * 0.48, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false); return p
    }
}

private extension Color {
    func mix(with other: Color, amount: CGFloat) -> Color {
        let a = max(0, min(1, amount))
        let lhs = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.white
        let rhs = NSColor(other).usingColorSpace(.deviceRGB) ?? NSColor.white
        return Color(red: lhs.redComponent * (1 - a) + rhs.redComponent * a,
                     green: lhs.greenComponent * (1 - a) + rhs.greenComponent * a,
                     blue: lhs.blueComponent * (1 - a) + rhs.blueComponent * a,
                     opacity: lhs.alphaComponent * (1 - a) + rhs.alphaComponent * a)
    }
}
