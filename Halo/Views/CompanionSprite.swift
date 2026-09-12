import SwiftUI

/// Shared companion renderer used by Environmental Interface and Retro Game CI.
/// Keeping the character in one renderer means animation/style improvements automatically
/// carry across the ambient pet, the owned EI room, and the arcade mascot.
enum HaloCompanionMotion: String, CaseIterable {
    case idle, walk, look, greet, celebrate, sleep, snack, dance, peek
}

struct HaloCompanionSprite: View {
    let kind: EIPetKind
    let style: EIPetVisualStyle
    var size: CGFloat
    var primary: Color
    var accent: Color
    var motion: HaloCompanionMotion = .idle
    var facingRight = true
    var displayPreset: EIPixelDisplayPreset = .clean
    var pixelGrid = false
    var pixelGlow = true
    var scanlines = false
    var ghosting = false
    var brightnessVariation = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.24 : animationInterval, paused: false)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            content(phase: phase)
                .scaleEffect(x: facingRight ? 1 : -1, y: 1)
                .offset(y: verticalBob(phase))
                .rotationEffect(.degrees(rotation(phase)))
        }
        .frame(width: size, height: size * 0.78)
        .accessibilityLabel("\(kind.rawValue) companion")
    }

    private var animationInterval: Double {
        switch motion {
        case .walk, .dance, .celebrate: return 1.0 / 30.0
        case .greet, .snack, .peek: return 1.0 / 20.0
        default: return 0.10
        }
    }

    @ViewBuilder
    private func content(phase: Double) -> some View {
        switch style {
        case .pixel:
            PixelDisplayRenderer(
                scene: pixelScene(phase),
                preset: displayPreset,
                pixelGrid: pixelGrid,
                glow: pixelGlow,
                scanlines: scanlines,
                ghosting: ghosting,
                brightnessVariation: brightnessVariation,
                phase: phase
            )
            .interpolation(.none)
        case .smooth:
            vectorCompanion(phase: phase, outlined: false)
        case .illustrated:
            illustratedCompanion(phase: phase)
        case .minimal:
            vectorCompanion(phase: phase, outlined: true)
        }
    }

    private func verticalBob(_ phase: Double) -> CGFloat {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .walk: return CGFloat(abs(sin(phase * 9.0)) * -2.5)
        case .dance, .celebrate: return CGFloat(abs(sin(phase * 7.0)) * -4.0)
        case .sleep: return 2
        case .peek: return CGFloat(sin(phase * 2.2) * 1.2)
        default: return CGFloat(sin(phase * 1.35) * 0.7)
        }
    }

    private func rotation(_ phase: Double) -> Double {
        guard !reduceMotion else { return 0 }
        switch motion {
        case .dance: return sin(phase * 6.5) * 6
        case .celebrate: return sin(phase * 8.0) * 4
        default: return 0
        }
    }

    private func illustratedCompanion(phase: Double) -> some View {
        ZStack {
            Circle()
                .fill(primary.opacity(0.18))
                .frame(width: size * 0.72, height: size * 0.72)
                .blur(radius: size * 0.06)
            Text(emoji)
                .font(.system(size: size * 0.62))
                .shadow(color: accent.opacity(0.34), radius: size * 0.08, y: size * 0.025)
            if motion == .greet || motion == .celebrate {
                Image(systemName: motion == .greet ? "sparkle" : "star.fill")
                    .font(.system(size: size * 0.17, weight: .bold))
                    .foregroundStyle(accent)
                    .offset(x: size * 0.28, y: -size * 0.20)
                    .scaleEffect(0.86 + abs(sin(phase * 5.5)) * 0.24)
            }
        }
    }

    private func vectorCompanion(phase: Double, outlined: Bool) -> some View {
        let stroke = outlined ? primary : Color.clear
        let fill = outlined ? primary.opacity(0.10) : primary
        let lineWidth = max(1.2, size * 0.025)
        let blink = Int(phase * 2.0).isMultiple(of: 11)
        let legSwing = motion == .walk ? CGFloat(sin(phase * 9.0) * size * 0.035) : 0
        let tailSwing = CGFloat(sin(phase * (motion == .dance ? 6.0 : 2.4)) * 12)
        let pawRaised = motion == .greet || motion == .celebrate

        return ZStack {
            Capsule()
                .fill(fill)
                .overlay(Capsule().stroke(stroke, lineWidth: lineWidth))
                .frame(width: size * 0.52, height: size * 0.28)
                .offset(x: -size * 0.08, y: size * 0.08)

            Circle()
                .fill(fill)
                .overlay(Circle().stroke(stroke, lineWidth: lineWidth))
                .frame(width: size * 0.34, height: size * 0.34)
                .offset(x: size * 0.20, y: -size * 0.04)

            ears(fill: fill, stroke: stroke, lineWidth: lineWidth)
                .offset(x: size * 0.20, y: -size * 0.20)

            HStack(spacing: size * 0.075) {
                Capsule().fill(outlined ? primary : Color.black.opacity(0.78))
                    .frame(width: size * 0.035, height: blink ? size * 0.012 : size * 0.055)
                Capsule().fill(outlined ? primary : Color.black.opacity(0.78))
                    .frame(width: size * 0.035, height: blink ? size * 0.012 : size * 0.055)
            }
            .offset(x: size * 0.23, y: -size * 0.06)

            Circle()
                .fill(accent)
                .frame(width: size * 0.045, height: size * 0.038)
                .offset(x: size * 0.31, y: size * 0.01)

            Capsule()
                .fill(fill)
                .overlay(Capsule().stroke(stroke, lineWidth: lineWidth))
                .frame(width: size * 0.12, height: size * 0.27)
                .rotationEffect(.degrees(-42 + tailSwing))
                .offset(x: -size * 0.34, y: -size * 0.005)

            Capsule()
                .fill(fill)
                .overlay(Capsule().stroke(stroke, lineWidth: lineWidth))
                .frame(width: size * 0.105, height: size * 0.22)
                .offset(x: -size * 0.16 + legSwing, y: size * 0.24)
            Capsule()
                .fill(fill)
                .overlay(Capsule().stroke(stroke, lineWidth: lineWidth))
                .frame(width: size * 0.105, height: size * 0.22)
                .offset(x: size * 0.03 - legSwing, y: size * 0.24)

            if pawRaised {
                Capsule()
                    .fill(fill)
                    .overlay(Capsule().stroke(stroke, lineWidth: lineWidth))
                    .frame(width: size * 0.095, height: size * 0.23)
                    .rotationEffect(.degrees(-35 + sin(phase * 6) * 14))
                    .offset(x: size * 0.34, y: size * 0.12)
            }

            if motion == .sleep {
                Text("z")
                    .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.8))
                    .offset(x: size * 0.37, y: -size * 0.28)
            } else if motion == .snack {
                Circle().fill(accent).frame(width: size * 0.10, height: size * 0.10)
                    .offset(x: size * 0.43, y: size * 0.10)
            }
        }
        .frame(width: size, height: size * 0.78)
        .scaleEffect(y: motion == .sleep ? 0.78 : 1, anchor: .bottom)
    }

    @ViewBuilder
    private func ears(fill: Color, stroke: Color, lineWidth: CGFloat) -> some View {
        switch kind {
        case .dog:
            HStack(spacing: size * 0.13) {
                Capsule().fill(accent.opacity(0.9)).frame(width: size * 0.11, height: size * 0.20).rotationEffect(.degrees(22))
                Capsule().fill(accent.opacity(0.9)).frame(width: size * 0.11, height: size * 0.20).rotationEffect(.degrees(-22))
            }
        case .cat, .fox:
            HStack(spacing: size * 0.08) {
                CompanionEarShape().fill(fill).overlay(CompanionEarShape().stroke(stroke, lineWidth: lineWidth)).frame(width: size * 0.16, height: size * 0.18)
                CompanionEarShape().fill(fill).overlay(CompanionEarShape().stroke(stroke, lineWidth: lineWidth)).frame(width: size * 0.16, height: size * 0.18)
            }
        }
    }

    private var emoji: String {
        switch kind {
        case .cat: return "🐱"
        case .dog: return "🐶"
        case .fox: return "🦊"
        }
    }

    private func pixelScene(_ phase: Double) -> EIPixelScene {
        let body = primary
        let detail = accent
        let blink = Int(phase * 2.2).isMultiple(of: 13)
        let walkFrame = Int(phase * 8).isMultiple(of: 2)
        let bob = (motion == .walk || motion == .dance) && walkFrame ? -1 : 0
        let tailY = Int(round(sin(phase * (motion == .dance ? 7 : 2.6))))
        let raised = motion == .greet || motion == .celebrate
        let crouched = motion == .sleep
        let baseY = 8 + bob + (crouched ? 2 : 0)
        var pixels: [EIPixel] = [
            .init(x: 7, y: baseY, width: 11, height: crouched ? 3 : 5, color: body),
            .init(x: 16, y: baseY - 4, width: 7, height: 6, color: body),
            .init(x: 18, y: baseY - 2, width: blink ? 3 : 1, height: 1, color: Color.black.opacity(0.82)),
            .init(x: 22, y: baseY, width: 2, height: 1, color: detail),
            .init(x: 4, y: baseY + 1 + tailY, width: 4, height: 1, color: body),
            .init(x: 3, y: baseY + tailY, width: 2, height: 2, color: body)
        ]

        if !crouched {
            pixels += [
                .init(x: 9, y: baseY + 5, width: 2, height: walkFrame ? 3 : 2, color: body),
                .init(x: 15, y: baseY + 5, width: 2, height: walkFrame ? 2 : 3, color: body)
            ]
        }

        switch kind {
        case .cat:
            pixels += [.init(x: 16, y: baseY - 6, width: 2, height: 3, color: body), .init(x: 21, y: baseY - 6, width: 2, height: 3, color: body)]
        case .dog:
            pixels += [.init(x: 15, y: baseY - 4, width: 2, height: 4, color: detail), .init(x: 22, y: baseY - 4, width: 2, height: 4, color: detail)]
        case .fox:
            pixels += [.init(x: 16, y: baseY - 7, width: 2, height: 4, color: body), .init(x: 21, y: baseY - 7, width: 2, height: 4, color: body), .init(x: 19, y: baseY + 1, width: 3, height: 1, color: detail)]
        }

        if raised {
            pixels += [.init(x: 22, y: baseY + 2, width: 2, height: 4, color: body), .init(x: 23, y: baseY + 1 + Int(round(sin(phase * 7))), width: 2, color: detail)]
        }
        if motion == .snack { pixels.append(.init(x: 25, y: baseY + 3, width: 2, height: 2, color: detail)) }
        if motion == .sleep { pixels += [.init(x: 24, y: baseY - 5, width: 2, color: detail, opacity: 0.7), .init(x: 26, y: baseY - 7, width: 2, color: detail, opacity: 0.45)] }
        if motion == .celebrate { pixels += [.init(x: 5, y: 3, color: detail), .init(x: 27, y: 4, color: detail), .init(x: 25, y: 1, color: Color.white.opacity(0.85))] }

        return EIPixelScene(columns: 31, rows: 19, pixels: pixels)
    }
}

private struct CompanionEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
