import AppKit
import Sparkle
import SwiftUI

@MainActor
final class HaloUpdateController: NSObject {
    static let shared = HaloUpdateController()
    private let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    private var updaterStarted = false
    private override init() { super.init() }

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    var currentBuild: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
    var isConfigured: Bool {
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feed.isEmpty, !feed.contains("$("),
              let url = URL(string: feed), url.scheme?.lowercased() == "https",
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !key.contains("$(") else { return false }
        return true
    }
    var canCheckForUpdates: Bool { ensureUpdaterStarted() && controller.updater.canCheckForUpdates }
    var automaticallyChecksForUpdates: Bool { ensureUpdaterStarted() && controller.updater.automaticallyChecksForUpdates }
    var automaticallyDownloadsUpdates: Bool { ensureUpdaterStarted() && controller.updater.automaticallyDownloadsUpdates }
    var lastUpdateCheckDate: Date? { ensureUpdaterStarted() ? controller.updater.lastUpdateCheckDate : nil }

    func setAutomaticallyChecksForUpdates(_ value: Bool) { if ensureUpdaterStarted() { controller.updater.automaticallyChecksForUpdates = value } }
    func setAutomaticallyDownloadsUpdates(_ value: Bool) { if ensureUpdaterStarted() { controller.updater.automaticallyDownloadsUpdates = value } }
    func checkForUpdates() {
        guard isConfigured else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Updates are not configured yet"
            alert.informativeText = "Halo still needs a valid HTTPS appcast URL and Ed25519 public signing key before Sparkle can start."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        guard ensureUpdaterStarted() else { return }
        controller.checkForUpdates(nil)
    }
    @discardableResult private func ensureUpdaterStarted() -> Bool {
        guard isConfigured else { return false }
        if !updaterStarted { controller.startUpdater(); updaterStarted = true }
        return true
    }
}

private struct HaloReleaseHighlight: Identifiable {
    let id = UUID(); let symbol: String; let title: String; let detail: String; let accent: Color
}

private struct HaloReleaseStory {
    let version: String; let title: String; let subtitle: String; let highlights: [HaloReleaseHighlight]
    static func current() -> HaloReleaseStory {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return .init(
            version: v,
            title: "Halo keeps getting sharper.",
            subtitle: "A cleaner update experience, native update visuals, and another round of polish across the notch.",
            highlights: [
                .init(symbol: "arrow.triangle.2.circlepath.circle.fill", title: "Sparkle 2 updates", detail: "Secure signed updates without leaving Halo.", accent: .green),
                .init(symbol: "rectangle.tophalf.inset.filled", title: "HN + SN update visuals", detail: "Effects can animate around the Hardware Notch while the Software Notch expands for richer information.", accent: .cyan),
                .init(symbol: "sparkles.rectangle.stack.fill", title: "What's New", detail: "See the important changes after each Halo update.", accent: .purple),
                .init(symbol: "checkmark.seal.fill", title: "Release polish", detail: "A cleaner signed appcast and release pipeline.", accent: .orange)
            ]
        )
    }
}

@MainActor
final class HaloWhatsNewCoordinator {
    static let shared = HaloWhatsNewCoordinator()
    private let defaults = UserDefaults.standard
    private let key = "HaloWhatsNewLastSeenVersion"
    private var window: NSWindow?
    private var checkedThisLaunch = false
    private init() {}

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    func presentIfNeeded() {
        guard !checkedThisLaunch else { return }
        checkedThisLaunch = true
        let current = currentVersion
        let previous = defaults.string(forKey: key)
        guard previous != current else { return }
        if previous == nil {
            let existing = defaults.object(forKey: "HaloSetupCompletedV1") != nil || defaults.object(forKey: "onboarded") != nil
            if !existing { defaults.set(current, forKey: key); return }
        }
        present()
    }

    func present() {
        defaults.set(currentVersion, forKey: key)
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 690), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "What's New in Halo"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.backgroundColor = .clear
        w.contentMinSize = NSSize(width: 640, height: 560)
        w.isReleasedWhenClosed = false
        w.center()
        w.contentView = NSHostingView(rootView: HaloWhatsNewView { [weak self, weak w] in w?.close(); self?.window = nil })
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

private struct HaloWhatsNewView: View {
    let onDone: () -> Void
    private let story = HaloReleaseStory.current()
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.025, green: 0.03, blue: 0.075), Color(red: 0.105, green: 0.045, blue: 0.18), Color(red: 0.02, green: 0.095, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 82, height: 82).shadow(color: .purple.opacity(0.5), radius: 24)
                    Text("HALO \(story.version)").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                    Text(story.title).font(.system(size: 34, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                    Text(story.subtitle).font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(story.highlights) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.symbol).foregroundStyle(item.accent).frame(width: 34, height: 34).background(item.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.headline); Text(item.detail).font(.callout).foregroundStyle(.secondary) }
                                Spacer()
                            }
                            .padding(15)
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    HStack {
                        Button("Check for Updates") { HaloUpdateController.shared.checkForUpdates() }
                        Spacer()
                        Button("Continue") { onDone() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    }
                }.padding(36)
            }
        }.preferredColorScheme(.dark)
    }
}

// MARK: - Update animation terminology
// HN = Hardware Notch (the physical display cutout)
// SN = Software Notch (Halo's software surface around / below the HN)

private enum HaloUpdatePhase: String {
    case ready = "Ready"
    case downloading = "Downloading"
    case verifying = "Verifying"
    case installing = "Installing"
    case updated = "Updated ✓"
    case relaunching = "Relaunching"
}

@MainActor
private final class HaloUpdatePreviewModel: ObservableObject {
    @Published var progress = 0.0
    @Published var phase: HaloUpdatePhase = .ready
    @Published var verifySweep = -1.0
    @Published var completionPulse = false
    @Published var installing = false
    @Published var poweredDown = false
    @Published var snVisible = false
}

@MainActor
final class HaloUpdateAnimationPreviewController {
    static let shared = HaloUpdateAnimationPreviewController()
    private let model = HaloUpdatePreviewModel()
    private var panel: NSPanel?
    private var task: Task<Void, Never>?
    private init() {}

    func play(version: String) {
        let d = UserDefaults.standard
        guard (d.string(forKey: "HaloUpdateAnimationStyle") ?? "Edge Fill") != "None" else { dismiss(); return }

        task?.cancel()
        show(version: version)
        let storedSpeed = d.double(forKey: "HaloUpdateAnimationSpeed")
        let speed = max(0.5, storedSpeed == 0 ? 1 : storedSpeed)
        let expandSN = d.object(forKey: "HaloUpdateExpandSN") as? Bool ?? true

        model.progress = 0
        model.phase = .downloading
        model.verifySweep = -1
        model.completionPulse = false
        model.installing = false
        model.poweredDown = false
        model.snVisible = false

        playCue("Tink")

        task = Task { @MainActor [weak self] in
            guard let self else { return }

            if expandSN {
                withAnimation(.spring(response: 0.34 / speed, dampingFraction: 0.84)) { model.snVisible = true }
                try? await Task.sleep(nanoseconds: UInt64(0.20 / speed * 1_000_000_000))
                guard !Task.isCancelled else { return }
            }

            withAnimation(.linear(duration: 1.8 / speed)) { model.progress = 1 }
            try? await Task.sleep(nanoseconds: UInt64(1.9 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.22 / speed, dampingFraction: 0.60)) { model.completionPulse = true }
            playCue("Glass")
            try? await Task.sleep(nanoseconds: UInt64(0.18 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16 / speed)) { model.completionPulse = false }

            model.phase = .verifying
            model.verifySweep = -1
            withAnimation(.easeInOut(duration: 0.50 / speed)) { model.verifySweep = 1 }
            playCue("Pop")
            try? await Task.sleep(nanoseconds: UInt64(0.60 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.36 / speed, dampingFraction: 0.76)) {
                model.phase = .installing
                model.installing = true
            }
            playCue("Funk")
            try? await Task.sleep(nanoseconds: UInt64(0.72 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.28 / speed, dampingFraction: 0.68)) {
                model.phase = .updated
                model.installing = false
                model.completionPulse = true
            }
            playCue("Glass")
            try? await Task.sleep(nanoseconds: UInt64(0.46 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.16 / speed)) { model.completionPulse = false }
            try? await Task.sleep(nanoseconds: UInt64(0.22 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            model.phase = .relaunching
            withAnimation(.easeInOut(duration: 0.24 / speed)) { model.snVisible = false }
            try? await Task.sleep(nanoseconds: UInt64(0.20 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.24 / speed)) { model.poweredDown = true }
            try? await Task.sleep(nanoseconds: UInt64(0.34 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func dismiss() {
        task?.cancel(); task = nil
        panel?.orderOut(nil); panel = nil
        model.progress = 0
        model.phase = .ready
        model.verifySweep = -1
        model.completionPulse = false
        model.installing = false
        model.poweredDown = false
        model.snVisible = false
    }

    private func playCue(_ name: String) {
        let d = UserDefaults.standard
        guard d.object(forKey: "HaloUpdateSoundsEnabled") as? Bool ?? true else { return }
        let stored = d.double(forKey: "HaloUpdateSoundVolume")
        let volume = Float(stored == 0 ? 0.55 : min(1, max(0, stored)))
        if let sound = NSSound(named: NSSound.Name(name)) { sound.volume = volume; sound.play() }
    }

    private func show(version: String) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let width: CGFloat = min(620, max(420, screen.frame.width * 0.38))
        let height: CGFloat = 230
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        let root = HaloPhysicalUpdatePreview(model: model, version: version)
        if let panel {
            panel.setFrame(frame, display: true)
            panel.contentView = NSHostingView(rootView: root)
            panel.orderFrontRegardless()
            return
        }
        let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = NSHostingView(rootView: root)
        panel = p
        p.orderFrontRegardless()
    }
}

private struct HaloPhysicalUpdatePreview: View {
    @ObservedObject var model: HaloUpdatePreviewModel
    let version: String

    @AppStorage("HaloUpdateAnimationStyle") private var style = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var intensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var presentation = "HN Edge"
    @AppStorage("HaloUpdateAnimationSpeed") private var speed = 1.0
    @AppStorage("HaloUpdateGlowStrength") private var glow = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var thickness = 2.0

    @AppStorage("HaloUpdateExpandSN") private var expandSN = true
    @AppStorage("HaloUpdateSNWidth") private var snWidth = 390.0
    @AppStorage("HaloUpdateSNHeight") private var snHeight = 112.0
    @AppStorage("HaloUpdateSNCornerRadius") private var snCornerRadius = 24.0
    @AppStorage("HaloUpdateSNOpacity") private var snOpacity = 0.98

    @AppStorage("HaloUpdateHNWidth") private var hnWidth = 182.0
    @AppStorage("HaloUpdateHNHeight") private var hnHeight = 32.0
    @AppStorage("HaloUpdateHNCornerRadius") private var hnCornerRadius = 11.0

    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var showSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var showSpeed = false
    @AppStorage("HaloUpdateShowETA") private var showETA = false

    @AppStorage("HaloUpdatePerimeterBarEnabled") private var perimeterBar = true
    @AppStorage("HaloUpdatePerimeterBarThickness") private var perimeterThickness = 1.5
    @AppStorage("HaloUpdatePerimeterBarOpacity") private var perimeterOpacity = 0.9
    @AppStorage("HaloUpdatePerimeterBarGlow") private var perimeterGlow = 0.35
    @AppStorage("HaloUpdatePerimeterBarColor") private var perimeterColor = "Accent"
    @AppStorage("HaloUpdatePerimeterBarClockwise") private var perimeterClockwise = true

    private var intensityMultiplier: Double {
        intensity == "Subtle" ? 0.55 : intensity == "Expressive" ? 1.4 : 1
    }

    private var barColor: Color {
        switch perimeterColor {
        case "White": return .white
        case "Cyan": return .cyan
        case "Purple": return .purple
        case "Green": return .green
        default: return .accentColor
        }
    }

    private var resolvedSNWidth: CGFloat { CGFloat(min(540, max(hnWidth + 44, snWidth))) }
    private var resolvedSNHeight: CGFloat { CGFloat(min(180, max(hnHeight + 46, snHeight))) }
    private var resolvedHNWidth: CGFloat { CGFloat(min(300, max(110, hnWidth))) }
    private var resolvedHNHeight: CGFloat { CGFloat(min(48, max(22, hnHeight))) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.clear

                if expandSN {
                    snLayer
                        .frame(width: model.snVisible ? resolvedSNWidth : resolvedHNWidth,
                               height: model.snVisible ? resolvedSNHeight : resolvedHNHeight,
                               alignment: .top)
                        .animation(.spring(response: 0.34 / max(speed, 0.5), dampingFraction: 0.84), value: model.snVisible)
                }

                hnLayer
                    .frame(width: resolvedHNWidth, height: resolvedHNHeight)
                    .zIndex(5)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .opacity(model.poweredDown ? 0 : 1)
            .animation(.easeIn(duration: 0.22 / max(speed, 0.5)), value: model.poweredDown)
        }
        .preferredColorScheme(.dark)
    }

    private var hnShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CGFloat(hnCornerRadius), style: .continuous)
    }

    private var snShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CGFloat(snCornerRadius), style: .continuous)
    }

    private var hnLayer: some View {
        ZStack {
            hnShape.fill(.black)
            hnEffects
            if perimeterBar { hnPerimeter }
            if presentation == "HN Edge" { hnEdgeProgress }
        }
        .scaleEffect(model.completionPulse ? 1.035 : 1)
        .scaleEffect(x: model.installing ? 0.92 : 1, y: model.installing ? 0.88 : 1)
        .shadow(color: Color.accentColor.opacity(glow * intensityMultiplier), radius: 3 + 10 * glow)
        .animation(.spring(response: 0.24 / max(speed, 0.5), dampingFraction: 0.62), value: model.completionPulse)
        .animation(.spring(response: 0.34 / max(speed, 0.5), dampingFraction: 0.76), value: model.installing)
    }

    @ViewBuilder private var hnEffects: some View {
        switch style {
        case "Minimal":
            hnShape.stroke(Color.accentColor.opacity(0.24 * intensityMultiplier), lineWidth: 1)

        case "Edge Fill":
            hnShape.stroke(Color.accentColor.opacity(0.12), lineWidth: max(0.8, thickness * 0.75))

        case "Energy":
            hnShape
                .stroke(AngularGradient(colors: [.clear, .accentColor, .clear, .accentColor, .clear], center: .center), lineWidth: max(1, thickness))
                .blur(radius: 1.5 + 3.5 * glow)
                .opacity(0.85 * intensityMultiplier)

        case "Particles":
            ZStack {
                ForEach(0..<16, id: \.self) { index in
                    let angle = Double(index) / 16 * Double.pi * 2
                    let x = cos(angle) * Double(resolvedHNWidth * 0.54)
                    let y = sin(angle) * Double(resolvedHNHeight * 0.80)
                    Circle()
                        .fill(Color.accentColor.opacity(0.28 + Double(index % 4) * 0.12))
                        .frame(width: 2.4 + CGFloat(index % 3), height: 2.4 + CGFloat(index % 3))
                        .offset(x: x, y: y)
                }
            }
            .opacity(0.4 + 0.55 * model.progress)

        case "Liquid":
            hnShape
                .stroke(LinearGradient(colors: [.accentColor.opacity(0.2), .accentColor, .cyan.opacity(0.65)], startPoint: .leading, endPoint: .trailing), lineWidth: max(1.5, thickness))
                .shadow(color: .accentColor.opacity(glow), radius: 5)

        case "Portal":
            ZStack {
                hnShape.stroke(Color.accentColor.opacity(0.62 * intensityMultiplier), lineWidth: max(1, thickness))
                hnShape.stroke(Color.accentColor.opacity(0.18 * intensityMultiplier), lineWidth: max(4, thickness * 3)).blur(radius: 5)
            }

        case "Digital":
            hnShape.stroke(Color.accentColor.opacity(0.64 * intensityMultiplier), style: StrokeStyle(lineWidth: max(1, thickness), dash: [2, 3], dashPhase: -model.progress * 18))

        case "Circuit":
            hnShape.stroke(Color.accentColor.opacity(0.72 * intensityMultiplier), style: StrokeStyle(lineWidth: max(1, thickness), dash: [8, 3, 2, 3], dashPhase: -model.progress * 30))
                .shadow(color: .accentColor.opacity(glow), radius: 4)

        default:
            EmptyView()
        }

        if model.phase == .verifying {
            hnShape
                .stroke(LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing), lineWidth: max(1.5, thickness))
                .mask(
                    Rectangle()
                        .frame(width: 44)
                        .offset(x: CGFloat(model.verifySweep) * resolvedHNWidth * 0.62)
                )
                .blendMode(.plusLighter)
        }
    }

    private var hnPerimeter: some View {
        ZStack {
            hnShape.stroke(barColor.opacity(perimeterOpacity * 0.13), lineWidth: max(0.5, perimeterThickness * 0.7))
            if perimeterClockwise {
                hnShape
                    .trim(from: 0, to: min(1, model.progress))
                    .stroke(barColor.opacity(perimeterOpacity), style: StrokeStyle(lineWidth: perimeterThickness, lineCap: .round, lineJoin: .round))
            } else {
                hnShape
                    .trim(from: max(0, 1 - model.progress), to: 1)
                    .stroke(barColor.opacity(perimeterOpacity), style: StrokeStyle(lineWidth: perimeterThickness, lineCap: .round, lineJoin: .round))
            }
        }
        .padding(max(1, perimeterThickness / 2 + 1))
        .shadow(color: barColor.opacity(perimeterGlow), radius: 1 + 5 * perimeterGlow)
    }

    private var hnEdgeProgress: some View {
        hnShape
            .trim(from: 0, to: min(1, model.progress))
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: max(1, thickness), lineCap: .round, lineJoin: .round))
            .padding(max(1, thickness / 2 + 1))
            .shadow(color: Color.accentColor.opacity(glow), radius: 2 + 5 * glow)
    }

    private var snLayer: some View {
        ZStack(alignment: .top) {
            snShape
                .fill(Color.black.opacity(snOpacity))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 5)

            snShape
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            if model.snVisible {
                snContent
                    .padding(.top, resolvedHNHeight + 10)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(snShape)
    }

    private var snContent: some View {
        VStack(spacing: 6) {
            if showPercentage {
                Text("\(Int(model.progress * 100))%")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                if showStatus {
                    Text(model.phase.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                if showVersion {
                    Text("Halo \(version)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if presentation != "Hidden" && presentation != "HN Edge" && presentation != "Percentage Only" {
                snProgress
                    .frame(maxWidth: .infinity)
            }

            if showSize || showSpeed || showETA {
                HStack(spacing: 9) {
                    if showSize { Text("\(Int(model.progress * 120)) / 120 MB") }
                    if showSpeed { Text("18.4 MB/s") }
                    if showETA { Text(model.progress >= 0.99 ? "0s" : "~\(max(1, Int((1 - model.progress) * 7)))s") }
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder private var snProgress: some View {
        switch presentation {
        case "SN Bottom Bar":
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule().fill(Color.accentColor).frame(width: proxy.size.width * model.progress)
                }
            }
            .frame(height: max(1, thickness))

        case "SN Fill":
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.30))
                            .frame(width: proxy.size.width * model.progress)
                    }
            }
            .frame(height: 20)

        case "SN Segments":
            HStack(spacing: 3) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(Double(i) / 14 <= model.progress ? Color.accentColor : Color.white.opacity(0.10))
                        .frame(height: max(1.5, thickness))
                }
            }

        case "SN Particles":
            GeometryReader { proxy in
                HStack(spacing: 5) {
                    ForEach(0..<18, id: \.self) { i in
                        Circle()
                            .fill(Color.accentColor.opacity(0.28 + Double(i % 5) * 0.12))
                            .frame(width: max(2, thickness), height: max(2, thickness))
                    }
                }
                .frame(width: proxy.size.width * model.progress, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
            .frame(height: max(4, thickness + 2))

        case "Ring":
            Circle()
                .trim(from: 0, to: min(1, model.progress))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: max(2, thickness), lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 28, height: 28)

        default:
            EmptyView()
        }
    }
}

@MainActor
struct UpdateAnimationSettingsView: View {
    private let updates = HaloUpdateController.shared

    @AppStorage("HaloUpdateAnimationStyle") private var style = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var intensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var presentation = "HN Edge"
    @AppStorage("HaloUpdateAnimationSpeed") private var speed = 1.0
    @AppStorage("HaloUpdateGlowStrength") private var glow = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var thickness = 2.0

    @AppStorage("HaloUpdateExpandSN") private var expandSN = true
    @AppStorage("HaloUpdateSNWidth") private var snWidth = 390.0
    @AppStorage("HaloUpdateSNHeight") private var snHeight = 112.0
    @AppStorage("HaloUpdateSNCornerRadius") private var snCornerRadius = 24.0
    @AppStorage("HaloUpdateSNOpacity") private var snOpacity = 0.98

    @AppStorage("HaloUpdateHNWidth") private var hnWidth = 182.0
    @AppStorage("HaloUpdateHNHeight") private var hnHeight = 32.0
    @AppStorage("HaloUpdateHNCornerRadius") private var hnCornerRadius = 11.0

    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var showSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var showSpeed = false
    @AppStorage("HaloUpdateShowETA") private var showETA = false

    @AppStorage("HaloUpdateSoundsEnabled") private var sounds = true
    @AppStorage("HaloUpdateSoundVolume") private var volume = 0.55
    @AppStorage("HaloUpdateAutoPreview") private var autoPreview = true

    @AppStorage("HaloUpdatePerimeterBarEnabled") private var perimeterBar = true
    @AppStorage("HaloUpdatePerimeterBarThickness") private var perimeterThickness = 1.5
    @AppStorage("HaloUpdatePerimeterBarOpacity") private var perimeterOpacity = 0.9
    @AppStorage("HaloUpdatePerimeterBarGlow") private var perimeterGlow = 0.35
    @AppStorage("HaloUpdatePerimeterBarColor") private var perimeterColor = "Accent"
    @AppStorage("HaloUpdatePerimeterBarClockwise") private var perimeterClockwise = true

    @State private var debounceTask: Task<Void, Never>?

    private var signature: String {
        [style, intensity, presentation, String(speed), String(glow), String(thickness), String(expandSN), String(snWidth), String(snHeight), String(snCornerRadius), String(snOpacity), String(hnWidth), String(hnHeight), String(hnCornerRadius), String(showPercentage), String(showVersion), String(showStatus), String(showSize), String(showSpeed), String(showETA), String(perimeterBar), String(perimeterThickness), String(perimeterOpacity), String(perimeterGlow), perimeterColor, String(perimeterClockwise)].joined(separator: "|")
    }

    var body: some View {
        Section("Update Animation Model") {
            Text("HN = Hardware Notch. SN = Software Notch. HN effects hug the physical cutout; SN may expand around and below it for richer update information.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("HN · Hardware Notch") {
            Picker("HN animation", selection: $style) {
                ForEach(["Minimal", "Edge Fill", "Energy", "Particles", "Liquid", "Portal", "Digital", "Circuit", "None"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Intensity", selection: $intensity) {
                ForEach(["Subtle", "Balanced", "Expressive"], id: \.self) { Text($0).tag($0) }
            }
            LabeledContent("HN width") { Slider(value: $hnWidth, in: 110...300, step: 1).frame(width: 220); Text("\(Int(hnWidth)) pt").monospacedDigit().frame(width: 58) }
            LabeledContent("HN height") { Slider(value: $hnHeight, in: 22...48, step: 1).frame(width: 220); Text("\(Int(hnHeight)) pt").monospacedDigit().frame(width: 58) }
            LabeledContent("HN corner radius") { Slider(value: $hnCornerRadius, in: 4...22, step: 1).frame(width: 220); Text("\(Int(hnCornerRadius)) pt").monospacedDigit().frame(width: 58) }
        }

        Section("HN · Progress Around Hardware") {
            Toggle("Show HN perimeter progress", isOn: $perimeterBar)
            if perimeterBar {
                Picker("Color", selection: $perimeterColor) { ForEach(["Accent", "White", "Cyan", "Purple", "Green"], id: \.self) { Text($0).tag($0) } }
                Toggle("Clockwise", isOn: $perimeterClockwise)
                LabeledContent("Thickness") { Slider(value: $perimeterThickness, in: 0.5...5, step: 0.25).frame(width: 220); Text("\(perimeterThickness, specifier: "%.2f") pt").monospacedDigit().frame(width: 66) }
                LabeledContent("Opacity") { Slider(value: $perimeterOpacity, in: 0.1...1, step: 0.05).frame(width: 220); Text("\(Int(perimeterOpacity * 100))%").monospacedDigit().frame(width: 52) }
                LabeledContent("Glow") { Slider(value: $perimeterGlow, in: 0...1, step: 0.05).frame(width: 220); Text("\(Int(perimeterGlow * 100))%").monospacedDigit().frame(width: 52) }
            }
        }

        Section("SN · Software Notch") {
            Toggle("Expand SN during updates", isOn: $expandSN)
            Text("When SN expands, all update text is placed inside SN below HN. Nothing is drawn over the Hardware Notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if expandSN {
                LabeledContent("SN width") { Slider(value: $snWidth, in: 240...540, step: 2).frame(width: 220); Text("\(Int(snWidth)) pt").monospacedDigit().frame(width: 58) }
                LabeledContent("SN height") { Slider(value: $snHeight, in: 78...180, step: 2).frame(width: 220); Text("\(Int(snHeight)) pt").monospacedDigit().frame(width: 58) }
                LabeledContent("SN corner radius") { Slider(value: $snCornerRadius, in: 10...40, step: 1).frame(width: 220); Text("\(Int(snCornerRadius)) pt").monospacedDigit().frame(width: 58) }
                LabeledContent("SN opacity") { Slider(value: $snOpacity, in: 0.55...1, step: 0.05).frame(width: 220); Text("\(Int(snOpacity * 100))%").monospacedDigit().frame(width: 52) }
            }
        }

        Section("Progress Presentation") {
            Picker("Presentation", selection: $presentation) {
                ForEach(["HN Edge", "SN Bottom Bar", "SN Fill", "SN Segments", "SN Particles", "Ring", "Percentage Only", "Hidden"], id: \.self) { Text($0).tag($0) }
            }
            LabeledContent("Animation speed") { Slider(value: $speed, in: 0.5...2, step: 0.05).frame(width: 220); Text("\(speed, specifier: "%.2f")×").monospacedDigit().frame(width: 52) }
            LabeledContent("Glow strength") { Slider(value: $glow, in: 0...1, step: 0.05).frame(width: 220); Text("\(Int(glow * 100))%").monospacedDigit().frame(width: 52) }
            LabeledContent("Progress thickness") { Slider(value: $thickness, in: 1...8, step: 0.5).frame(width: 220); Text("\(thickness, specifier: "%.1f") pt").monospacedDigit().frame(width: 62) }
        }

        Section("SN · Information") {
            Toggle("Show percentage", isOn: $showPercentage)
            Toggle("Show version", isOn: $showVersion)
            Toggle("Show current phase", isOn: $showStatus)
            Toggle("Show downloaded / total size", isOn: $showSize)
            Toggle("Show download speed", isOn: $showSpeed)
            Toggle("Show estimated time", isOn: $showETA)
            if !expandSN {
                Text("SN is disabled, so text information is hidden during the preview. HN-only effects remain visible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Sounds") {
            Toggle("Enable update sounds", isOn: $sounds)
            LabeledContent("Volume") { Slider(value: $volume, in: 0...1, step: 0.05).frame(width: 220).disabled(!sounds); Text("\(Int(volume * 100))%").monospacedDigit().frame(width: 52) }
        }

        Section("Preview") {
            Toggle("Automatically preview animation changes", isOn: $autoPreview)
            HStack {
                Button { playPreview() } label: { Label("Preview HN + SN", systemImage: "play.fill") }.buttonStyle(.borderedProminent)
                Button("Stop Preview") { HaloUpdateAnimationPreviewController.shared.dismiss() }
                Spacer()
                Text(autoPreview ? "Live HN/SN preview" : "Manual preview").font(.caption).foregroundStyle(.secondary)
            }
            Text("Preview is synthetic. HN effects are rendered around the hardware-cutout area; SN expands independently and contains all text below HN.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: signature) { _ in if autoPreview { schedulePreview() } }
        .onDisappear { debounceTask?.cancel(); HaloUpdateAnimationPreviewController.shared.dismiss() }
    }

    private func schedulePreview() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            playPreview()
        }
    }

    private func playPreview() {
        HaloUpdateAnimationPreviewController.shared.play(version: updates.currentVersion)
    }
}
