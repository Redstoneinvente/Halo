import AppKit
import Sparkle
import SwiftUI

@MainActor
final class HaloUpdateController: NSObject, SPUUpdaterDelegate {
    static let shared = HaloUpdateController()
    private lazy var controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
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

    func setAutomaticallyChecksForUpdates(_ value: Bool) {
        if ensureUpdaterStarted() { controller.updater.automaticallyChecksForUpdates = value }
    }

    func setAutomaticallyDownloadsUpdates(_ value: Bool) {
        if ensureUpdaterStarted() { controller.updater.automaticallyDownloadsUpdates = value }
    }

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

    @discardableResult
    private func ensureUpdaterStarted() -> Bool {
        guard isConfigured else { return false }
        if !updaterStarted {
            controller.startUpdater()
            updaterStarted = true
        }
        return true
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        HaloUpdateAnimationPreviewController.shared.beginRealUpdate(
            version: item.displayVersionString,
            expectedBytes: item.contentLength
        )
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        HaloUpdateAnimationPreviewController.shared.realDownloadFinished()
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        HaloUpdateAnimationPreviewController.shared.dismiss()
    }

    func userDidCancelDownload(_ updater: SPUUpdater) {
        HaloUpdateAnimationPreviewController.shared.dismiss()
    }

    func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
        HaloUpdateAnimationPreviewController.shared.realExtracting()
    }

    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        HaloUpdateAnimationPreviewController.shared.realExtracted()
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        HaloUpdateAnimationPreviewController.shared.realInstalling()
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        HaloUpdateAnimationPreviewController.shared.realWillRelaunch()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        HaloUpdateAnimationPreviewController.shared.dismiss()
    }
}

private struct HaloReleaseHighlight: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String
    let accent: Color
}

private struct HaloReleaseStory {
    let version: String
    let title: String
    let subtitle: String
    let highlights: [HaloReleaseHighlight]

    static func current() -> HaloReleaseStory {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return .init(
            version: version,
            title: "Halo keeps getting sharper.",
            subtitle: "A cleaner update experience and another round of polish across the notch.",
            highlights: [
                .init(symbol: "arrow.triangle.2.circlepath.circle.fill", title: "Sparkle 2 updates", detail: "Secure signed updates without leaving Halo.", accent: .green),
                .init(symbol: "sparkles", title: "Native update progress", detail: "A lightweight progress trace follows the notch while updates install.", accent: .cyan),
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
            if !existing {
                defaults.set(current, forKey: key)
                return
            }
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

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 690),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "What's New in Halo"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.contentMinSize = NSSize(width: 640, height: 560)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: HaloWhatsNewView { [weak self, weak window] in
            window?.close()
            self?.window = nil
        })
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct HaloWhatsNewView: View {
    let onDone: () -> Void
    private let story = HaloReleaseStory.current()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.03, blue: 0.075),
                    Color(red: 0.105, green: 0.045, blue: 0.18),
                    Color(red: 0.02, green: 0.095, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 82, height: 82)
                        .shadow(color: .purple.opacity(0.5), radius: 24)

                    Text("HALO \(story.version)")
                        .font(.caption.bold())
                        .tracking(2)
                        .foregroundStyle(.secondary)

                    Text(story.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(story.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(story.highlights) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.symbol)
                                    .foregroundStyle(item.accent)
                                    .frame(width: 34, height: 34)
                                    .background(item.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).font(.headline)
                                    Text(item.detail).font(.callout).foregroundStyle(.secondary)
                                }
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
                        Button("Continue") { onDone() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(36)
            }
        }
        .preferredColorScheme(.dark)
    }
}

private enum HaloUpdatePhase: String {
    case ready = "Ready"
    case downloading = "Downloading"
    case verifying = "Verifying"
    case finishing = "Finishing"
    case installing = "Installing"
    case updated = "Updated ✓"
}

private struct HaloPhysicalNotchGeometry {
    let screen: NSScreen
    let size: CGSize
    let centerX: CGFloat
    let detected: Bool

    static func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        if let underPointer = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) { return underPointer }
        if let windowScreen = NSApp.keyWindow?.screen { return windowScreen }
        return NSScreen.main ?? NSScreen.screens.first
    }

    static func measure(on screen: NSScreen) -> HaloPhysicalNotchGeometry {
        let frame = screen.frame
        let topInset = screen.safeAreaInsets.top

        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = max(1, right.minX - left.maxX)
            let height = max(1, topInset)
            return .init(
                screen: screen,
                size: CGSize(width: width, height: height),
                centerX: (left.maxX + right.minX) / 2,
                detected: true
            )
        }

        return .init(
            screen: screen,
            size: CGSize(width: 180, height: max(28, topInset)),
            centerX: frame.midX,
            detected: false
        )
    }
}

private struct HaloHardwareNotchShape: InsettableShape {
    var cornerRadius: CGFloat
    var bottomExtension: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let extendedBottom = box.maxY
        let radius = min(max(2, cornerRadius - insetAmount), max(2, (extendedBottom - box.minY) / 2))

        var path = Path()
        path.move(to: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.minX, y: extendedBottom - radius))
        path.addQuadCurve(
            to: CGPoint(x: box.minX + radius, y: extendedBottom),
            control: CGPoint(x: box.minX, y: extendedBottom)
        )
        path.addLine(to: CGPoint(x: box.maxX - radius, y: extendedBottom))
        path.addQuadCurve(
            to: CGPoint(x: box.maxX, y: extendedBottom - radius),
            control: CGPoint(x: box.maxX, y: extendedBottom)
        )
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> HaloHardwareNotchShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

@MainActor
private final class HaloUpdatePreviewModel: ObservableObject {
    @Published var progress = 0.0
    @Published var phase: HaloUpdatePhase = .ready
    @Published var detailsVisible = false
    @Published var pulse = false
    @Published var poweredDown = false
    @Published var downloadedBytes: UInt64 = 0
    @Published var totalBytes: UInt64 = 0
    @Published var bytesPerSecond: Double = 0
    @Published var etaSeconds: Double = 0
}

@MainActor
final class HaloUpdateAnimationPreviewController {
    static let shared = HaloUpdateAnimationPreviewController()

    private let model = HaloUpdatePreviewModel()
    private var panel: NSPanel?
    private var previewTask: Task<Void, Never>?
    private var liveProgressTask: Task<Void, Never>?
    private var realDownloadComplete = false
    private init() {}

    func beginRealUpdate(version: String, expectedBytes: UInt64) {
        previewTask?.cancel()
        liveProgressTask?.cancel()
        realDownloadComplete = false

        guard let screen = HaloPhysicalNotchGeometry.targetScreen() else { return }
        let geometry = HaloPhysicalNotchGeometry.measure(on: screen)
        show(version: version, geometry: geometry)

        let defaults = UserDefaults.standard
        let showDetails = defaults.object(forKey: "HaloUpdateShowExpandedDetails") as? Bool ?? true

        model.progress = 0
        model.phase = .downloading
        model.detailsVisible = false
        model.pulse = false
        model.poweredDown = false
        model.totalBytes = expectedBytes
        model.downloadedBytes = 0
        model.bytesPerSecond = 0
        model.etaSeconds = 0

        if showDetails {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                model.detailsVisible = true
            }
        }

        let fallbackTotal: UInt64 = expectedBytes > 0 ? expectedBytes : 120 * 1024 * 1024
        let startedAt = Date()
        var previousBytes: UInt64 = 0
        var previousDate = startedAt

        liveProgressTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled && !realDownloadComplete {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled, !realDownloadComplete else { break }

                let elapsed = Date().timeIntervalSince(startedAt)
                let eased = min(0.92, 1 - exp(-elapsed / 6.5))
                let nextProgress = min(0.92, max(model.progress, eased))
                model.progress = nextProgress

                let nextBytes = UInt64(Double(fallbackTotal) * nextProgress)
                model.downloadedBytes = nextBytes
                if model.totalBytes == 0 { model.totalBytes = fallbackTotal }

                let now = Date()
                let dt = max(0.001, now.timeIntervalSince(previousDate))
                let delta = nextBytes >= previousBytes ? nextBytes - previousBytes : 0
                let instantSpeed = Double(delta) / dt
                if instantSpeed > 0 {
                    model.bytesPerSecond = model.bytesPerSecond == 0
                        ? instantSpeed
                        : model.bytesPerSecond * 0.72 + instantSpeed * 0.28
                }

                if model.bytesPerSecond > 1, model.totalBytes > model.downloadedBytes {
                    model.etaSeconds = Double(model.totalBytes - model.downloadedBytes) / model.bytesPerSecond
                } else {
                    model.etaSeconds = 0
                }

                previousBytes = nextBytes
                previousDate = now
            }
        }
    }

    func realDownloadFinished() {
        realDownloadComplete = true
        liveProgressTask?.cancel()
        liveProgressTask = nil
        model.phase = .verifying
        model.progress = max(model.progress, 0.94)
        if model.totalBytes > 0 { model.downloadedBytes = model.totalBytes }
        model.etaSeconds = 0
    }

    func realExtracting() {
        model.phase = .verifying
        model.progress = max(model.progress, 0.96)
    }

    func realExtracted() {
        model.phase = .finishing
        model.progress = max(model.progress, 0.98)
    }

    func realInstalling() {
        model.phase = .installing
        model.progress = 1
        model.pulse = true
        model.etaSeconds = 0
    }

    func realWillRelaunch() {
        model.phase = .updated
        withAnimation(.easeOut(duration: 0.18)) { model.pulse = false }
        withAnimation(.easeInOut(duration: 0.22)) { model.detailsVisible = false }
    }

    func play(version: String) {
        previewTask?.cancel()
        liveProgressTask?.cancel()

        guard let screen = HaloPhysicalNotchGeometry.targetScreen() else { return }
        let geometry = HaloPhysicalNotchGeometry.measure(on: screen)
        show(version: version, geometry: geometry)

        let defaults = UserDefaults.standard
        let speed = max(0.5, defaults.double(forKey: "HaloUpdateAnimationSpeed") == 0 ? 1 : defaults.double(forKey: "HaloUpdateAnimationSpeed"))
        let showDetails = defaults.object(forKey: "HaloUpdateShowExpandedDetails") as? Bool ?? true
        let total: UInt64 = 120 * 1024 * 1024

        model.progress = 0
        model.phase = .downloading
        model.detailsVisible = showDetails
        model.pulse = false
        model.poweredDown = false
        model.totalBytes = total
        model.downloadedBytes = 0
        model.bytesPerSecond = 0
        model.etaSeconds = 0

        previewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let steps = 40
            let interval = 1.8 / speed / Double(steps)
            let bytesPerStep = Double(total) * 0.86 / Double(steps)

            for i in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                model.progress = 0.86 * Double(i) / Double(steps)
                model.downloadedBytes = UInt64(Double(total) * model.progress)
                model.bytesPerSecond = bytesPerStep / interval
                model.etaSeconds = max(0, Double(total - model.downloadedBytes) / max(1, model.bytesPerSecond))
            }

            model.phase = .verifying
            model.progress = 0.94
            model.downloadedBytes = total
            model.etaSeconds = 0
            try? await Task.sleep(nanoseconds: UInt64(0.48 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            model.phase = .finishing
            model.progress = 0.98
            try? await Task.sleep(nanoseconds: UInt64(0.36 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            model.phase = .installing
            model.progress = 1
            model.pulse = true
            try? await Task.sleep(nanoseconds: UInt64(0.38 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            model.phase = .updated
            model.pulse = false
            try? await Task.sleep(nanoseconds: UInt64(0.50 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.22 / speed)) { model.detailsVisible = false }
            try? await Task.sleep(nanoseconds: UInt64(0.20 / speed * 1_000_000_000))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func dismiss() {
        previewTask?.cancel()
        liveProgressTask?.cancel()
        previewTask = nil
        liveProgressTask = nil
        realDownloadComplete = false
        panel?.orderOut(nil)
        panel = nil
        model.progress = 0
        model.phase = .ready
        model.detailsVisible = false
        model.pulse = false
        model.poweredDown = false
        model.downloadedBytes = 0
        model.totalBytes = 0
        model.bytesPerSecond = 0
        model.etaSeconds = 0
    }

    private func show(version: String, geometry: HaloPhysicalNotchGeometry) {
        let defaults = UserDefaults.standard
        let bottomOffset = CGFloat(max(0, defaults.double(forKey: "HaloUpdateTraceBottomOffset")))
        let screen = geometry.screen
        let expandedWidth = max(340, geometry.size.width + 120)
        let panelWidth = min(screen.frame.width, max(expandedWidth + 40, geometry.size.width + 48))
        let panelHeight = max(180, geometry.size.height + bottomOffset + 132)
        let frame = NSRect(
            x: geometry.centerX - panelWidth / 2,
            y: screen.frame.maxY - panelHeight,
            width: panelWidth,
            height: panelHeight
        )

        let root = HaloPhysicalUpdatePreview(
            model: model,
            version: version,
            notchSize: geometry.size,
            expandedWidth: expandedWidth,
            notchDetected: geometry.detected
        )

        if let panel {
            panel.setFrame(frame, display: true)
            panel.contentView = NSHostingView(rootView: root)
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
        panel.contentView = NSHostingView(rootView: root)
        self.panel = panel
        panel.orderFrontRegardless()
    }
}

private struct HaloPhysicalUpdatePreview: View {
    @ObservedObject var model: HaloUpdatePreviewModel
    let version: String
    let notchSize: CGSize
    let expandedWidth: CGFloat
    let notchDetected: Bool

    @AppStorage("HaloUpdateAnimationSpeed") private var speed = 1.0
    @AppStorage("HaloUpdateTraceThickness") private var traceThickness = 2.25
    @AppStorage("HaloUpdateTraceGlow") private var traceGlow = 0.45
    @AppStorage("HaloUpdateTraceOpacity") private var traceOpacity = 1.0
    @AppStorage("HaloUpdateTraceColor") private var traceColorName = "Accent"
    @AppStorage("HaloUpdateTraceClockwise") private var clockwise = true
    @AppStorage("HaloUpdateTraceBottomOffset") private var bottomOffset = 0.0

    @AppStorage("HaloUpdateShowExpandedDetails") private var showExpandedDetails = true
    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var showSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var showSpeed = false
    @AppStorage("HaloUpdateShowETA") private var showETA = false

    private var hardwareWidth: CGFloat { max(1, notchSize.width) }
    private var hardwareHeight: CGFloat { max(1, notchSize.height) }
    private var traceHeight: CGFloat { hardwareHeight + CGFloat(max(0, bottomOffset)) }
    private var expandedHeight: CGFloat { traceHeight + 80 }
    private var cornerRadius: CGFloat { min(12, max(5, hardwareHeight * 0.34)) }

    private var traceColor: Color {
        switch traceColorName {
        case "White": return .white
        case "Cyan": return .cyan
        case "Purple": return .purple
        case "Green": return .green
        default: return .accentColor
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.clear

                if showExpandedDetails {
                    expandedSurface
                        .frame(
                            width: model.detailsVisible ? expandedWidth : hardwareWidth,
                            height: model.detailsVisible ? expandedHeight : traceHeight,
                            alignment: .top
                        )
                        .animation(
                            .spring(response: 0.30 / max(speed, 0.5), dampingFraction: 0.86),
                            value: model.detailsVisible
                        )
                }

                hardwareNotch
                    .frame(width: hardwareWidth, height: traceHeight)
                    .zIndex(4)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .opacity(model.poweredDown ? 0 : 1)
        }
        .preferredColorScheme(.dark)
    }

    private var hardwareShape: HaloHardwareNotchShape {
        HaloHardwareNotchShape(
            cornerRadius: cornerRadius,
            bottomExtension: CGFloat(max(0, bottomOffset))
        )
    }

    private var hardwareNotch: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.black)
                .frame(width: hardwareWidth, height: hardwareHeight)
                .frame(maxHeight: .infinity, alignment: .top)

            hardwareShape
                .inset(by: max(0.5, traceThickness * 0.5))
                .stroke(
                    traceColor.opacity(max(0.18, traceOpacity * 0.20)),
                    lineWidth: max(0.75, traceThickness * 0.7)
                )

            if clockwise {
                hardwareShape
                    .inset(by: max(0.5, traceThickness * 0.5))
                    .trim(from: 0, to: min(1, model.progress))
                    .stroke(
                        traceColor.opacity(traceOpacity),
                        style: StrokeStyle(lineWidth: traceThickness, lineCap: .round, lineJoin: .round)
                    )
            } else {
                hardwareShape
                    .inset(by: max(0.5, traceThickness * 0.5))
                    .trim(from: max(0, 1 - model.progress), to: 1)
                    .stroke(
                        traceColor.opacity(traceOpacity),
                        style: StrokeStyle(lineWidth: traceThickness, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .shadow(color: traceColor.opacity(traceGlow), radius: 1 + 7 * traceGlow)
        .scaleEffect(model.pulse ? 1.025 : 1)
        .animation(.spring(response: 0.22 / max(speed, 0.5), dampingFraction: 0.64), value: model.pulse)
    }

    private var expandedSurface: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.985))
                .shadow(color: .black.opacity(0.42), radius: 14, y: 5)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)

            if model.detailsVisible {
                detailContent
                    .padding(.top, traceHeight + 10)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var detailContent: some View {
        VStack(spacing: 5) {
            if showPercentage {
                Text("\(Int((model.progress * 100).rounded()))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
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

            if showSize || showSpeed || showETA {
                HStack(spacing: 9) {
                    if showSize {
                        Text("\(formattedBytes(model.downloadedBytes)) / \(formattedBytes(model.totalBytes))")
                    }
                    if showSpeed {
                        Text(model.bytesPerSecond > 0 ? "\(formattedRate(model.bytesPerSecond))" : "—")
                    }
                    if showETA {
                        Text(model.etaSeconds > 0 ? formattedETA(model.etaSeconds) : "—")
                    }
                }
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.white)
    }

    private func formattedBytes(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1000 { return String(format: "%.2f GB", mb / 1024) }
        return String(format: mb >= 100 ? "%.0f MB" : "%.1f MB", mb)
    }

    private func formattedRate(_ bytesPerSecond: Double) -> String {
        let mb = bytesPerSecond / 1_048_576
        return String(format: "%.1f MB/s", mb)
    }

    private func formattedETA(_ seconds: Double) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value >= 60 { return "~\(value / 60)m \(value % 60)s" }
        return "~\(value)s"
    }
}

@MainActor
struct UpdateAnimationSettingsView: View {
    private let updates = HaloUpdateController.shared

    @AppStorage("HaloUpdateTraceThickness") private var traceThickness = 2.25
    @AppStorage("HaloUpdateTraceGlow") private var traceGlow = 0.45
    @AppStorage("HaloUpdateTraceOpacity") private var traceOpacity = 1.0
    @AppStorage("HaloUpdateTraceColor") private var traceColor = "Accent"
    @AppStorage("HaloUpdateTraceClockwise") private var clockwise = true
    @AppStorage("HaloUpdateTraceBottomOffset") private var bottomOffset = 0.0
    @AppStorage("HaloUpdateAnimationSpeed") private var speed = 1.0

    @AppStorage("HaloUpdateShowExpandedDetails") private var showExpandedDetails = true
    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var showSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var showSpeed = false
    @AppStorage("HaloUpdateShowETA") private var showETA = false

    @AppStorage("HaloUpdateSoundsEnabled") private var sounds = true
    @AppStorage("HaloUpdateSoundVolume") private var volume = 0.55
    @AppStorage("HaloUpdateAutoPreview") private var autoPreview = true

    @State private var debounceTask: Task<Void, Never>?

    private var signature: String {
        [
            traceColor,
            String(traceThickness),
            String(traceGlow),
            String(traceOpacity),
            String(clockwise),
            String(bottomOffset),
            String(speed),
            String(showExpandedDetails),
            String(showPercentage),
            String(showVersion),
            String(showStatus),
            String(showSize),
            String(showSpeed),
            String(showETA)
        ].joined(separator: "|")
    }

    var body: some View {
        Section("Progress Trace") {
            Text("A thin progress line automatically matches the physical notch on the active display and traces it as Halo installs an update.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Color", selection: $traceColor) {
                ForEach(["Accent", "White", "Cyan", "Purple", "Green"], id: \.self) {
                    Text($0).tag($0)
                }
            }

            Toggle("Clockwise", isOn: $clockwise)

            LabeledContent("Thickness") {
                Slider(value: $traceThickness, in: 0.75...5, step: 0.25).frame(width: 220)
                Text("\(traceThickness, specifier: "%.2f") pt").monospacedDigit().frame(width: 66)
            }

            LabeledContent("Bottom edge offset") {
                Slider(value: $bottomOffset, in: 0...12, step: 0.5).frame(width: 220)
                Text("\(bottomOffset, specifier: "%.1f") pt").monospacedDigit().frame(width: 62)
            }

            Text("Adds a small gap below the physical notch so the lower part of the trace can sit slightly lower.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LabeledContent("Glow") {
                Slider(value: $traceGlow, in: 0...1, step: 0.05).frame(width: 220)
                Text("\(Int(traceGlow * 100))%").monospacedDigit().frame(width: 52)
            }

            LabeledContent("Opacity") {
                Slider(value: $traceOpacity, in: 0.2...1, step: 0.05).frame(width: 220)
                Text("\(Int(traceOpacity * 100))%").monospacedDigit().frame(width: 52)
            }

            LabeledContent("Animation speed") {
                Slider(value: $speed, in: 0.5...2, step: 0.05).frame(width: 220)
                Text("\(speed, specifier: "%.2f")×").monospacedDigit().frame(width: 52)
            }
        }

        Section("Expanded Details") {
            Toggle("Expand notch to show update details", isOn: $showExpandedDetails)
            Text("When enabled, Halo expands below the physical notch and keeps all update text inside that expanded area.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if showExpandedDetails {
                Toggle("Show percentage", isOn: $showPercentage)
                Toggle("Show version", isOn: $showVersion)
                Toggle("Show current phase", isOn: $showStatus)
                Toggle("Show downloaded / total size", isOn: $showSize)
                Toggle("Show download speed", isOn: $showSpeed)
                Toggle("Show estimated time", isOn: $showETA)
            }
        }

        Section("Sounds") {
            Toggle("Enable update sounds", isOn: $sounds)
            LabeledContent("Volume") {
                Slider(value: $volume, in: 0...1, step: 0.05)
                    .frame(width: 220)
                    .disabled(!sounds)
                Text("\(Int(volume * 100))%")
                    .monospacedDigit()
                    .frame(width: 52)
            }
        }

        Section("Preview") {
            Toggle("Automatically preview changes", isOn: $autoPreview)

            HStack {
                Button { playPreview() } label: {
                    Label("Preview Animation", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button("Stop Preview") {
                    HaloUpdateAnimationPreviewController.shared.dismiss()
                }

                Spacer()
                Text(autoPreview ? "Live preview enabled" : "Manual preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Preview is synthetic and does not start a real Sparkle update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: signature) { _ in
            if autoPreview { schedulePreview() }
        }
        .onDisappear {
            debounceTask?.cancel()
            HaloUpdateAnimationPreviewController.shared.dismiss()
        }
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
