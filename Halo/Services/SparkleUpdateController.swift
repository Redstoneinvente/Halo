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
        if ["0.2.1", "0.2.2"].contains(v) {
            return .init(version: v, title: "Halo keeps getting sharper.", subtitle: "A cleaner update experience, a proper What's New surface, and another round of polish across the notch.", highlights: [
                .init(symbol: "arrow.triangle.2.circlepath.circle.fill", title: "Sparkle 2 updates", detail: "Secure signed updates without leaving Halo.", accent: .green),
                .init(symbol: "gearshape.2.fill", title: "Update controls", detail: "Check manually and manage automatic checks and downloads.", accent: .cyan),
                .init(symbol: "sparkles.rectangle.stack.fill", title: "What's New", detail: "See the important changes after each Halo update.", accent: .purple),
                .init(symbol: "checkmark.seal.fill", title: "Release polish", detail: "A cleaner signed appcast and release pipeline.", accent: .orange)
            ])
        }
        return .init(version: v, title: "Halo just got better.", subtitle: "This release brings another round of polish, fixes, and improvements.", highlights: [
            .init(symbol: "wand.and.stars", title: "Refined experience", detail: "Cleaner everyday interactions.", accent: .purple),
            .init(symbol: "gauge.with.dots.needle.67percent", title: "Performance", detail: "Background work remains restrained.", accent: .cyan),
            .init(symbol: "checkmark.seal.fill", title: "Quality fixes", detail: "Reliability improvements throughout Halo.", accent: .green)
        ])
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
        guard !checkedThisLaunch else { return }; checkedThisLaunch = true
        let current = currentVersion, previous = defaults.string(forKey: key)
        guard previous != current else { return }
        if previous == nil {
            let existing = defaults.object(forKey: "HaloSetupCompletedV1") != nil || defaults.object(forKey: "onboarded") != nil
            if !existing { defaults.set(current, forKey: key); return }
        }
        present()
    }
    func present() {
        defaults.set(currentVersion, forKey: key)
        if let window { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 690), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "What's New in Halo"; w.titleVisibility = .hidden; w.titlebarAppearsTransparent = true; w.isMovableByWindowBackground = true
        w.backgroundColor = .clear; w.contentMinSize = NSSize(width: 640, height: 560); w.isReleasedWhenClosed = false; w.center()
        w.contentView = NSHostingView(rootView: HaloWhatsNewView { [weak self, weak w] in w?.close(); self?.window = nil })
        window = w; NSApp.activate(ignoringOtherApps: true); w.makeKeyAndOrderFront(nil)
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
                            }.padding(15).frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    HStack {
                        Button("Check for Updates") { HaloUpdateController.shared.checkForUpdates() }
                        Spacer(); Button("Continue") { onDone() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    }
                }.padding(36)
            }
        }.preferredColorScheme(.dark)
    }
}

@MainActor
private final class HaloUpdatePreviewModel: ObservableObject {
    @Published var progress = 0.0
    @Published var phase = "Ready"
    @Published var installing = false
    @Published var poweredDown = false
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
        task?.cancel(); show(version: version)
        let stored = d.double(forKey: "HaloUpdateAnimationSpeed"), speed = max(0.5, stored == 0 ? 1 : stored)
        model.progress = 0; model.phase = "Downloading"; model.installing = false; model.poweredDown = false
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            withAnimation(.linear(duration: 1.8 / speed)) { model.progress = 1 }
            try? await Task.sleep(nanoseconds: UInt64(1.9 / speed * 1_000_000_000)); guard !Task.isCancelled else { return }
            model.phase = "Verifying"
            try? await Task.sleep(nanoseconds: UInt64(0.55 / speed * 1_000_000_000)); guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.28 / speed, dampingFraction: 0.72)) { model.phase = "Installing"; model.installing = true }
            try? await Task.sleep(nanoseconds: UInt64(0.65 / speed * 1_000_000_000)); guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25 / speed)) { model.phase = "Updated ✓"; model.installing = false }
            try? await Task.sleep(nanoseconds: UInt64(0.62 / speed * 1_000_000_000)); guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.24 / speed)) { model.phase = "Relaunching"; model.poweredDown = true }
            try? await Task.sleep(nanoseconds: UInt64(0.36 / speed * 1_000_000_000)); guard !Task.isCancelled else { return }
            dismiss()
        }
    }
    func dismiss() { task?.cancel(); task = nil; panel?.orderOut(nil); panel = nil; model.progress = 0; model.phase = "Ready"; model.installing = false; model.poweredDown = false }
    private func show(version: String) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let width: CGFloat = min(480, max(360, screen.frame.width * 0.30)), height: CGFloat = 118
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        let root = HaloPhysicalUpdatePreview(model: model, version: version)
        if let panel { panel.setFrame(frame, display: true); panel.contentView = NSHostingView(rootView: root); panel.orderFrontRegardless(); return }
        let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false; p.ignoresMouseEvents = true; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = NSHostingView(rootView: root); panel = p; p.orderFrontRegardless()
    }
}

private struct HaloPhysicalUpdatePreview: View {
    @ObservedObject var model: HaloUpdatePreviewModel
    let version: String
    @AppStorage("HaloUpdateAnimationStyle") private var style = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var intensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var presentation = "Bottom Edge"
    @AppStorage("HaloUpdateGlowStrength") private var glow = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var thickness = 2.0
    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true
    private var multiplier: Double { intensity == "Subtle" ? 0.55 : intensity == "Expressive" ? 1.4 : 1 }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.clear
                let width = min(proxy.size.width - 12, 430.0)
                ZStack(alignment: .bottom) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.black)
                        Rectangle().fill(.black).frame(height: 28).frame(maxHeight: .infinity, alignment: .top)
                        if ["Energy", "Portal", "Circuit"].contains(style) {
                            RoundedRectangle(cornerRadius: 24).stroke(Color.accentColor.opacity(0.24 * multiplier), lineWidth: max(1, thickness)).blur(radius: 3 + 4 * glow)
                        }
                        VStack(spacing: 3) {
                            if showPercentage { Text("\(Int(model.progress * 100))%").font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit() }
                            if showStatus { Text(model.phase).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary) }
                            if showVersion { Text("Halo \(version)").font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary) }
                        }.padding(.top, 14)
                    }
                    progress(width: width - 34).padding(.bottom, 7)
                }
                .frame(width: width, height: 96)
                .shadow(color: Color.accentColor.opacity(glow * multiplier), radius: 14 + 10 * glow)
                .opacity(model.poweredDown ? 0 : 1)
                .scaleEffect(x: model.installing ? 0.965 : 1, y: model.installing ? 0.93 : 1, anchor: .top)
                .animation(.easeInOut(duration: 0.24), value: model.installing)
                .animation(.easeIn(duration: 0.22), value: model.poweredDown)
            }.frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }.preferredColorScheme(.dark)
    }
    @ViewBuilder private func progress(width: CGFloat) -> some View {
        switch presentation {
        case "Hidden", "Percentage Only": EmptyView()
        case "Full Perimeter": RoundedRectangle(cornerRadius: 21).trim(from: 0, to: min(1, model.progress)).stroke(Color.accentColor, style: StrokeStyle(lineWidth: thickness, lineCap: .round)).frame(width: width + 20, height: 76).rotationEffect(.degrees(-90)).shadow(color: Color.accentColor.opacity(glow), radius: 6)
        case "Ring": Circle().trim(from: 0, to: min(1, model.progress)).stroke(Color.accentColor, style: StrokeStyle(lineWidth: max(2, thickness), lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 30, height: 30)
        case "Segments": HStack(spacing: 3) { ForEach(0..<12, id: \.self) { i in Capsule().fill(Double(i) / 12 <= model.progress ? Color.accentColor : Color.white.opacity(0.12)).frame(width: max(3, (width - 33) / 12), height: max(1, thickness)) } }
        default: ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.1)).frame(width: width, height: max(1, thickness)); Capsule().fill(Color.accentColor).frame(width: max(0, width * model.progress), height: max(1, thickness)).shadow(color: Color.accentColor.opacity(glow * multiplier), radius: 6) }
        }
    }
}

@MainActor
struct UpdateAnimationSettingsView: View {
    private let updates = HaloUpdateController.shared
    @AppStorage("HaloUpdateAnimationStyle") private var style = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var intensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var presentation = "Bottom Edge"
    @AppStorage("HaloUpdateAnimationSpeed") private var speed = 1.0
    @AppStorage("HaloUpdateGlowStrength") private var glow = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var thickness = 2.0
    @AppStorage("HaloUpdateShowPercentage") private var showPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var showVersion = true
    @AppStorage("HaloUpdateShowStatus") private var showStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var showSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var showSpeed = false
    @AppStorage("HaloUpdateShowETA") private var showETA = false
    @AppStorage("HaloUpdateSoundsEnabled") private var sounds = true
    @AppStorage("HaloUpdateSoundVolume") private var volume = 0.55
    @AppStorage("HaloUpdateAutoPreview") private var autoPreview = true
    @State private var localProgress = 0.0
    @State private var localPhase = "Ready"
    @State private var runID = UUID()
    @State private var debounceTask: Task<Void, Never>?
    private var signature: String { [style, intensity, presentation, String(speed), String(glow), String(thickness), String(showPercentage), String(showVersion), String(showStatus), String(showSize), String(showSpeed), String(showETA)].joined(separator: "|") }

    var body: some View {
        Section("Presentation") {
            Text("Customize how Halo presents update progress at the physical notch. Sparkle still owns the real download, verification, installation, and relaunch process.").font(.caption).foregroundStyle(.secondary)
            Picker("Style", selection: $style) { ForEach(["Minimal", "Edge Fill", "Energy", "Particles", "Liquid", "Portal", "Digital", "Circuit", "None"], id: \.self) { Text($0).tag($0) } }
            Picker("Intensity", selection: $intensity) { ForEach(["Subtle", "Balanced", "Expressive"], id: \.self) { Text($0).tag($0) } }
            Picker("Progress presentation", selection: $presentation) { ForEach(["Bottom Edge", "Full Perimeter", "Inside Fill", "Ring", "Segments", "Particles", "Percentage Only", "Hidden"], id: \.self) { Text($0).tag($0) } }
        }
        Section("Motion & Glow") {
            LabeledContent("Animation speed") { Slider(value: $speed, in: 0.5...2, step: 0.05).frame(width: 220); Text("\(speed, specifier: "%.2f")×").monospacedDigit().frame(width: 52) }
            LabeledContent("Glow strength") { Slider(value: $glow, in: 0...1, step: 0.05).frame(width: 220); Text("\(Int(glow * 100))%").monospacedDigit().frame(width: 52) }
            LabeledContent("Progress thickness") { Slider(value: $thickness, in: 1...8, step: 0.5).frame(width: 220); Text("\(thickness, specifier: "%.1f") pt").monospacedDigit().frame(width: 62) }
        }
        Section("Progress Information") {
            Toggle("Show percentage", isOn: $showPercentage); Toggle("Show version", isOn: $showVersion); Toggle("Show current phase", isOn: $showStatus)
            Toggle("Show downloaded / total size", isOn: $showSize); Toggle("Show download speed", isOn: $showSpeed); Toggle("Show estimated time", isOn: $showETA)
        }
        Section("Sounds") {
            Toggle("Enable update sounds", isOn: $sounds)
            LabeledContent("Volume") { Slider(value: $volume, in: 0...1, step: 0.05).frame(width: 220).disabled(!sounds); Text("\(Int(volume * 100))%").monospacedDigit().frame(width: 52) }
        }
        Section("Preview") {
            Toggle("Automatically preview animation changes", isOn: $autoPreview)
            HStack {
                Button { playPreview() } label: { Label("Preview on Notch", systemImage: "play.fill") }.buttonStyle(.borderedProminent)
                Button("Stop Preview") { stopPreview() }
                Spacer(); Text(autoPreview ? "Physical notch auto-preview enabled" : "Manual physical preview").font(.caption).foregroundStyle(.secondary)
            }
            Text("The preview appears at the physical notch on your active display. It is synthetic and never starts a Sparkle check, download, or installation.").font(.caption).foregroundStyle(.secondary)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16).fill(.black).frame(width: 360, height: 92).shadow(color: Color.accentColor.opacity(glow), radius: 18)
                VStack(spacing: 4) { if showPercentage { Text("\(Int(localProgress * 100))%").font(.title3.bold()).monospacedDigit() }; if showStatus { Text(localPhase).font(.caption).foregroundStyle(.secondary) }; if showVersion { Text("Halo \(updates.currentVersion)").font(.caption2).foregroundStyle(.tertiary) } }.padding(.bottom, 14)
                GeometryReader { proxy in Capsule().fill(Color.white.opacity(0.12)).overlay(alignment: .leading) { Capsule().fill(Color.accentColor).frame(width: proxy.size.width * localProgress) } }.frame(width: 330, height: max(1, thickness)).padding(.bottom, 5)
            }.frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .onChange(of: signature) { _ in if autoPreview { schedulePreview() } }
        .onDisappear { debounceTask?.cancel(); HaloUpdateAnimationPreviewController.shared.dismiss() }
    }
    private func schedulePreview() { debounceTask?.cancel(); debounceTask = Task { @MainActor in try? await Task.sleep(nanoseconds: 220_000_000); guard !Task.isCancelled else { return }; playPreview() } }
    private func stopPreview() { runID = UUID(); debounceTask?.cancel(); HaloUpdateAnimationPreviewController.shared.dismiss(); localProgress = 0; localPhase = "Ready" }
    private func playPreview() {
        guard style != "None" else { HaloUpdateAnimationPreviewController.shared.dismiss(); localProgress = 0; localPhase = "Standard Sparkle UI"; return }
        HaloUpdateAnimationPreviewController.shared.play(version: updates.currentVersion)
        let id = UUID(); runID = id; let s = max(speed, 0.5); localProgress = 0; localPhase = "Downloading"
        Task { @MainActor in
            withAnimation(.linear(duration: 1.8 / s)) { localProgress = 1 }
            try? await Task.sleep(nanoseconds: UInt64(1.9 / s * 1_000_000_000)); guard runID == id else { return }; localPhase = "Verifying"
            try? await Task.sleep(nanoseconds: UInt64(0.55 / s * 1_000_000_000)); guard runID == id else { return }; localPhase = "Installing"
            try? await Task.sleep(nanoseconds: UInt64(0.65 / s * 1_000_000_000)); guard runID == id else { return }; localPhase = "Updated ✓"
            try? await Task.sleep(nanoseconds: UInt64(0.62 / s * 1_000_000_000)); guard runID == id else { return }; localPhase = "Relaunching"
            try? await Task.sleep(nanoseconds: UInt64(0.36 / s * 1_000_000_000)); guard runID == id else { return }; localProgress = 0; localPhase = "Ready"
        }
    }
}
