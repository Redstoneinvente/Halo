import AppKit
import Sparkle
import SwiftUI

@MainActor
final class HaloUpdateController: NSObject {
    static let shared = HaloUpdateController()

    private let controller: SPUStandardUpdaterController
    private var updaterStarted = false

    private override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    var isConfigured: Bool {
        guard
            let feedValue = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            !feedValue.isEmpty,
            !feedValue.contains("$("),
            let feedURL = URL(string: feedValue),
            feedURL.scheme?.lowercased() == "https",
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !publicKey.contains("$(")
        else {
            return false
        }
        return true
    }

    var canCheckForUpdates: Bool {
        guard ensureUpdaterStarted() else { return false }
        return controller.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        guard ensureUpdaterStarted() else { return false }
        return controller.updater.automaticallyChecksForUpdates
    }

    var automaticallyDownloadsUpdates: Bool {
        guard ensureUpdaterStarted() else { return false }
        return controller.updater.automaticallyDownloadsUpdates
    }

    var lastUpdateCheckDate: Date? {
        guard ensureUpdaterStarted() else { return nil }
        return controller.updater.lastUpdateCheckDate
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        guard ensureUpdaterStarted() else { return }
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        guard ensureUpdaterStarted() else { return }
        controller.updater.automaticallyDownloadsUpdates = enabled
    }

    func checkForUpdates() {
        guard isConfigured else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Updates are not configured yet"
            alert.informativeText = "Sparkle is linked correctly, but Halo still needs an HTTPS appcast URL and its Ed25519 public signing key. Configure those locally before starting the updater."
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
    let eyebrow: String
    let title: String
    let subtitle: String
    let highlights: [HaloReleaseHighlight]

    static func forCurrentBuild() -> HaloReleaseStory {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

        switch version {
        case "0.2.1", "0.2.2":
            return HaloReleaseStory(
                version: version,
                eyebrow: "HALO \(version)",
                title: "Halo keeps getting sharper.",
                subtitle: "A cleaner update experience, a proper What's New surface, and another round of polish across the notch.",
                highlights: [
                    .init(
                        symbol: "arrow.triangle.2.circlepath.circle.fill",
                        title: "Sparkle 2 updates",
                        detail: "Halo can securely check, download, verify, and install signed updates without sending you off to a browser.",
                        accent: .green
                    ),
                    .init(
                        symbol: "gearshape.2.fill",
                        title: "Update controls in Settings",
                        detail: "Check manually, choose whether Halo checks automatically, and control automatic downloads from inside Halo.",
                        accent: .cyan
                    ),
                    .init(
                        symbol: "sparkles.rectangle.stack.fill",
                        title: "What's New",
                        detail: "Each release now has a native Halo release story so the important changes are easy to discover after updating.",
                        accent: .purple
                    ),
                    .init(
                        symbol: "checkmark.seal.fill",
                        title: "Release pipeline polish",
                        detail: "Signed appcasts, delta-ready builds, and safer Gate 3 packaging make future Halo releases considerably less painful.",
                        accent: .orange
                    )
                ]
            )
        default:
            return HaloReleaseStory(
                version: version,
                eyebrow: "HALO \(version)",
                title: "Halo just got better.",
                subtitle: "This release brings another round of polish, fixes, and improvements across your notch experience.",
                highlights: [
                    .init(symbol: "wand.and.stars", title: "Refined experience", detail: "Everyday interactions have been tuned for clarity, responsiveness, and visual consistency.", accent: .purple),
                    .init(symbol: "gauge.with.dots.needle.67percent", title: "Performance work", detail: "Background work stays restrained so Halo can remain present without becoming demanding.", accent: .cyan),
                    .init(symbol: "checkmark.seal.fill", title: "Quality fixes", detail: "This build includes reliability and compatibility improvements throughout Halo.", accent: .green)
                ]
            )
        }
    }
}

@MainActor
final class HaloWhatsNewCoordinator {
    static let shared = HaloWhatsNewCoordinator()

    private let defaults = UserDefaults.standard
    private let lastSeenKey = "HaloWhatsNewLastSeenVersion"
    private var window: NSWindow?
    private var checkedThisLaunch = false

    private init() {}

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func presentIfNeeded() {
        guard !checkedThisLaunch else { return }
        checkedThisLaunch = true

        let current = currentVersion
        let previous = defaults.string(forKey: lastSeenKey)
        guard previous != current else { return }

        if previous == nil {
            let looksLikeExistingInstall = defaults.object(forKey: "HaloSetupCompletedV1") != nil ||
                defaults.object(forKey: "onboarded") != nil
            if !looksLikeExistingInstall {
                defaults.set(current, forKey: lastSeenKey)
                return
            }
        }

        present()
    }

    func present() {
        defaults.set(currentVersion, forKey: lastSeenKey)

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "What's New in Halo"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.contentMinSize = NSSize(width: 660, height: 600)
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
    private let story = HaloReleaseStory.forCurrentBuild()

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

            Circle()
                .fill(Color.purple.opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 260, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: -300, y: 260)

            ScrollView {
                VStack(spacing: 26) {
                    hero
                    highlights
                    footer
                }
                .padding(.horizontal, 38)
                .padding(.top, 42)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 112, height: 112)
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1).frame(width: 112, height: 112)
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 82, height: 82)
                    .shadow(color: .purple.opacity(0.5), radius: 28)
            }

            Text(story.eyebrow)
                .font(.caption.weight(.bold))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.62))

            Text(story.title)
                .font(.system(size: 35, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(story.subtitle)
                .font(.title3)
                .foregroundStyle(Color.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 610)
        }
    }

    private var highlights: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(story.highlights) { item in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(item.accent)
                        .frame(width: 38, height: 38)
                        .background(item.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title).font(.headline)
                        Text(item.detail)
                            .font(.callout)
                            .foregroundStyle(Color.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(17)
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                HaloUpdateController.shared.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("Thanks for using Halo.")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.48))

            Spacer()

            Button("Continue") { onDone() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 2)
    }
}

@MainActor
struct UpdateAnimationSettingsView: View {
    private let updates = HaloUpdateController.shared

    @AppStorage("HaloUpdateAnimationStyle") private var updateAnimationStyle = "Edge Fill"
    @AppStorage("HaloUpdateAnimationIntensity") private var updateAnimationIntensity = "Balanced"
    @AppStorage("HaloUpdateProgressPresentation") private var updateProgressPresentation = "Bottom Edge"
    @AppStorage("HaloUpdateAnimationSpeed") private var updateAnimationSpeed = 1.0
    @AppStorage("HaloUpdateGlowStrength") private var updateGlowStrength = 0.45
    @AppStorage("HaloUpdateProgressThickness") private var updateProgressThickness = 2.0
    @AppStorage("HaloUpdateShowPercentage") private var updateShowPercentage = true
    @AppStorage("HaloUpdateShowVersion") private var updateShowVersion = true
    @AppStorage("HaloUpdateShowStatus") private var updateShowStatus = true
    @AppStorage("HaloUpdateShowDownloadedSize") private var updateShowDownloadedSize = false
    @AppStorage("HaloUpdateShowDownloadSpeed") private var updateShowDownloadSpeed = false
    @AppStorage("HaloUpdateShowETA") private var updateShowETA = false
    @AppStorage("HaloUpdateSoundsEnabled") private var updateSoundsEnabled = true
    @AppStorage("HaloUpdateSoundVolume") private var updateSoundVolume = 0.55
    @AppStorage("HaloUpdateAutoPreview") private var autoPreview = true

    @State private var previewProgress = 0.0
    @State private var previewPhase = "Ready"
    @State private var previewRunID = UUID()

    private var previewSettingsSignature: String {
        [
            updateAnimationStyle,
            updateAnimationIntensity,
            updateProgressPresentation,
            String(updateAnimationSpeed),
            String(updateGlowStrength),
            String(updateProgressThickness),
            String(updateShowPercentage),
            String(updateShowVersion),
            String(updateShowStatus),
            String(updateShowDownloadedSize),
            String(updateShowDownloadSpeed),
            String(updateShowETA)
        ].joined(separator: "|")
    }

    var body: some View {
        Section("Presentation") {
            Text("Customize how update progress is presented through Halo's notch. Sparkle still owns the real download, verification, installation, and relaunch process.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Style", selection: $updateAnimationStyle) {
                ForEach(["Minimal", "Edge Fill", "Energy", "Particles", "Liquid", "Portal", "Digital", "Circuit", "None"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Intensity", selection: $updateAnimationIntensity) {
                ForEach(["Subtle", "Balanced", "Expressive"], id: \.self) { Text($0).tag($0) }
            }
            Picker("Progress presentation", selection: $updateProgressPresentation) {
                ForEach(["Bottom Edge", "Full Perimeter", "Inside Fill", "Ring", "Segments", "Particles", "Percentage Only", "Hidden"], id: \.self) { Text($0).tag($0) }
            }
        }

        Section("Motion & Glow") {
            LabeledContent("Animation speed") {
                Slider(value: $updateAnimationSpeed, in: 0.5...2.0, step: 0.05).frame(width: 220)
                Text("\(updateAnimationSpeed, specifier: "%.2f")×").monospacedDigit().frame(width: 52, alignment: .trailing)
            }
            LabeledContent("Glow strength") {
                Slider(value: $updateGlowStrength, in: 0...1, step: 0.05).frame(width: 220)
                Text("\(Int(updateGlowStrength * 100))%").monospacedDigit().frame(width: 52, alignment: .trailing)
            }
            LabeledContent("Progress thickness") {
                Slider(value: $updateProgressThickness, in: 1...8, step: 0.5).frame(width: 220)
                Text("\(updateProgressThickness, specifier: "%.1f") pt").monospacedDigit().frame(width: 62, alignment: .trailing)
            }
        }

        Section("Progress Information") {
            Toggle("Show percentage", isOn: $updateShowPercentage)
            Toggle("Show version", isOn: $updateShowVersion)
            Toggle("Show current phase", isOn: $updateShowStatus)
            Toggle("Show downloaded / total size", isOn: $updateShowDownloadedSize)
            Toggle("Show download speed", isOn: $updateShowDownloadSpeed)
            Toggle("Show estimated time", isOn: $updateShowETA)
        }

        Section("Sounds") {
            Toggle("Enable update sounds", isOn: $updateSoundsEnabled)
            LabeledContent("Volume") {
                Slider(value: $updateSoundVolume, in: 0...1, step: 0.05)
                    .frame(width: 220)
                    .disabled(!updateSoundsEnabled)
                Text("\(Int(updateSoundVolume * 100))%")
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
        }

        Section("Preview") {
            Toggle("Automatically preview animation changes", isOn: $autoPreview)

            HStack {
                Button {
                    playPreview()
                } label: {
                    Label("Preview Animation", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button("Reset Preview") {
                    previewRunID = UUID()
                    withAnimation(.easeOut(duration: 0.2)) {
                        previewProgress = 0
                        previewPhase = "Ready"
                    }
                }

                Spacer()

                Text(autoPreview ? "Live preview enabled" : "Manual preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.black)
                        .frame(width: 360, height: 92)
                        .shadow(color: Color.accentColor.opacity(updateGlowStrength), radius: 18)
                        .scaleEffect(previewPhase == "Installing" ? 0.985 : 1)
                        .animation(.easeInOut(duration: 0.22 / max(updateAnimationSpeed, 0.5)), value: previewPhase)

                    VStack(spacing: 4) {
                        if updateShowPercentage { Text("\(Int(previewProgress * 100))%").font(.title3.bold()).monospacedDigit() }
                        if updateShowStatus { Text(previewPhase).font(.caption).foregroundStyle(.secondary) }
                        if updateShowVersion { Text("Halo \(updates.currentVersion)").font(.caption2).foregroundStyle(.tertiary) }
                    }
                    .padding(.bottom, 14)

                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(height: updateProgressThickness)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: proxy.size.width * previewProgress, height: updateProgressThickness)
                                    .shadow(color: Color.accentColor.opacity(updateGlowStrength), radius: 6)
                            }
                    }
                    .frame(width: 330, height: updateProgressThickness)
                    .padding(.bottom, 5)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .onChange(of: previewSettingsSignature) { _ in
            guard autoPreview else { return }
            playPreview()
        }
    }

    private func playPreview() {
        guard updateAnimationStyle != "None" else {
            previewRunID = UUID()
            withAnimation(.easeOut(duration: 0.2)) {
                previewProgress = 0
                previewPhase = "Standard Sparkle UI"
            }
            return
        }

        let runID = UUID()
        previewRunID = runID
        let speed = max(updateAnimationSpeed, 0.5)

        previewProgress = 0
        previewPhase = "Downloading"

        Task { @MainActor in
            withAnimation(.linear(duration: 1.8 / speed)) {
                previewProgress = 1
            }

            try? await Task.sleep(nanoseconds: UInt64((1.9 / speed) * 1_000_000_000))
            guard previewRunID == runID else { return }

            previewPhase = "Verifying"
            try? await Task.sleep(nanoseconds: UInt64((0.55 / speed) * 1_000_000_000))
            guard previewRunID == runID else { return }

            previewPhase = "Installing"
            try? await Task.sleep(nanoseconds: UInt64((0.65 / speed) * 1_000_000_000))
            guard previewRunID == runID else { return }

            previewPhase = "Updated ✓"
            try? await Task.sleep(nanoseconds: UInt64((0.8 / speed) * 1_000_000_000))
            guard previewRunID == runID else { return }

            withAnimation(.easeOut(duration: 0.25 / speed)) {
                previewProgress = 0
                previewPhase = "Ready"
            }
        }
    }
}
