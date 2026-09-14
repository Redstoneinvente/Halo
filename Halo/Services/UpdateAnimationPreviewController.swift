import AppKit
import SwiftUI

@MainActor
final class HaloUpdateAnimationPreviewModel: ObservableObject {
    @Published var progress = 0.0
    @Published var phase = "Ready"
    @Published var poweredDown = false
    @Published var installing = false
}

@MainActor
final class HaloUpdateAnimationPreviewController {
    static let shared = HaloUpdateAnimationPreviewController()

    private let model = HaloUpdateAnimationPreviewModel()
    private var panel: NSPanel?
    private var runTask: Task<Void, Never>?

    private init() {}

    func play(version: String) {
        let defaults = UserDefaults.standard
        let style = defaults.string(forKey: "HaloUpdateAnimationStyle") ?? "Edge Fill"
        guard style != "None" else {
            dismiss()
            return
        }

        runTask?.cancel()
        showPanel(version: version)

        let storedSpeed = defaults.double(forKey: "HaloUpdateAnimationSpeed")
        let speed = max(0.5, storedSpeed == 0 ? 1 : storedSpeed)
        model.progress = 0
        model.phase = "Downloading"
        model.poweredDown = false
        model.installing = false

        runTask = Task { @MainActor [weak self] in
            guard let self else { return }

            withAnimation(.linear(duration: 1.8 / speed)) {
                model.progress = 1
            }
            try? await Task.sleep(nanoseconds: UInt64((1.9 / speed) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.22 / speed)) {
                model.phase = "Verifying"
            }
            try? await Task.sleep(nanoseconds: UInt64((0.55 / speed) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.28 / speed, dampingFraction: 0.72)) {
                model.phase = "Installing"
                model.installing = true
            }
            try? await Task.sleep(nanoseconds: UInt64((0.65 / speed) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.26 / speed)) {
                model.phase = "Updated ✓"
                model.installing = false
            }
            try? await Task.sleep(nanoseconds: UInt64((0.62 / speed) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.25 / speed)) {
                model.phase = "Relaunching"
                model.poweredDown = true
            }
            try? await Task.sleep(nanoseconds: UInt64((0.36 / speed) * 1_000_000_000))
            guard !Task.isCancelled else { return }

            dismiss()
        }
    }

    func dismiss() {
        runTask?.cancel()
        runTask = nil
        panel?.orderOut(nil)
        panel = nil
        model.progress = 0
        model.phase = "Ready"
        model.poweredDown = false
        model.installing = false
    }

    private func showPanel(version: String) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let width: CGFloat = min(480, max(360, screen.frame.width * 0.30))
        let height: CGFloat = 118
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )

        let rootView = HaloPhysicalUpdatePreviewView(model: model, version: version)

        if let panel {
            panel.setFrame(frame, display: true)
            panel.contentView = NSHostingView(rootView: rootView)
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: rootView)
        self.panel = panel
        panel.orderFrontRegardless()
    }
}

private struct HaloPhysicalUpdatePreviewView: View {
    @ObservedObject var model: HaloUpdateAnimationPreviewModel
    let version: String

    @AppStorage("HaloUpdateAnimationStyle") private var style = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var intensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var presentation = "Bottom Edge"
    @AppStorage("HaloUpdateGlowStrength") private var glowStrength = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var thickness = 2.0
    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true

    private var intensityMultiplier: Double {
        switch intensity {
        case "Subtle": return 0.55
        case "Expressive": return 1.4
        default: return 1
        }
    }

    private var accent: Color { .accentColor }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.clear
                notchShape(size: proxy.size)
                    .opacity(model.poweredDown ? 0 : 1)
                    .scaleEffect(x: model.installing ? 0.965 : 1, y: model.installing ? 0.93 : 1, anchor: .top)
                    .animation(.easeInOut(duration: 0.24), value: model.installing)
                    .animation(.easeIn(duration: 0.22), value: model.poweredDown)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func notchShape(size: CGSize) -> some View {
        let notchWidth = min(size.width - 12, 430)
        let notchHeight: CGFloat = 96

        return ZStack(alignment: .bottom) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.995))
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 28)
                    .frame(maxHeight: .infinity, alignment: .top)

                if style == "Energy" || style == "Portal" || style == "Circuit" {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accent.opacity(0.24 * intensityMultiplier), lineWidth: max(1, thickness))
                        .blur(radius: 3 + 4 * glowStrength)
                }

                VStack(spacing: 3) {
                    if showPercentage {
                        Text("\(Int(model.progress * 100))%")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    if showStatus {
                        Text(model.phase)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    if showVersion {
                        Text("Halo \(version)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 14)
            }

            progressLayer(width: notchWidth - 34)
                .padding(.bottom, 7)
        }
        .frame(width: notchWidth, height: notchHeight)
        .shadow(color: accent.opacity(glowStrength * intensityMultiplier), radius: 14 + 10 * glowStrength)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    @ViewBuilder
    private func progressLayer(width: CGFloat) -> some View {
        switch presentation {
        case "Hidden", "Percentage Only":
            EmptyView()
        case "Full Perimeter":
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .trim(from: 0, to: min(1, model.progress))
                .stroke(accent, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .frame(width: width + 20, height: 76)
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(glowStrength), radius: 6)
                .offset(y: -1)
        case "Inside Fill":
            GeometryReader { proxy in
                Rectangle()
                    .fill(accent.opacity(0.10 + 0.20 * intensityMultiplier))
                    .frame(width: proxy.size.width * model.progress)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: width, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case "Ring":
            Circle()
                .trim(from: 0, to: min(1, model.progress))
                .stroke(accent, style: StrokeStyle(lineWidth: max(2, thickness), lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 30)
                .shadow(color: accent.opacity(glowStrength), radius: 5)
        case "Segments":
            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(Double(index) / 12.0 <= model.progress ? accent : Color.white.opacity(0.12))
                        .frame(width: max(3, (width - 33) / 12), height: max(1, thickness))
                }
            }
        case "Particles":
            ZStack {
                Capsule().fill(Color.white.opacity(0.08)).frame(width: width, height: max(1, thickness))
                HStack(spacing: 8) {
                    ForEach(0..<9, id: \.self) { index in
                        Circle()
                            .fill(accent.opacity(Double(index + 1) / 9.0))
                            .frame(width: 3 + thickness * 0.4, height: 3 + thickness * 0.4)
                    }
                }
                .frame(width: width * model.progress, alignment: .trailing)
                .frame(width: width, alignment: .leading)
                .clipped()
            }
        default:
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10)).frame(width: width, height: max(1, thickness))
                Capsule()
                    .fill(accent)
                    .frame(width: max(0, width * model.progress), height: max(1, thickness))
                    .shadow(color: accent.opacity(glowStrength * intensityMultiplier), radius: 6)
            }
        }
    }
}
