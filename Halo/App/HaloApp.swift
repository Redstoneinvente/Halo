import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics
import IOKit
import Combine

@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { SettingsView(store: delegate.store).frame(width: 800, height: 640) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppStore()
    private var engine: WindowManager?
    private var hudController: HaloHUDController?
    private var status: NSStatusItem?
    private var settings: NSWindow?
    private var hudSettings: NSWindow?
    private var setupWindow: NSWindow?
    private var commercialBag = Set<AnyCancellable>()
    private var licensedServicesStarted = false
    private var setupShownThisLaunch = false
    private let setupCompletedKey = "HaloSetupCompletedV1"
    // Development switch: keep this true while we iterate on onboarding.
    private let forceSetupEveryLaunch = true

    private var commercialAccessGranted: Bool {
        let account = HaloAccountManager.shared
        return account.isSignedIn && HaloLicenseManager.shared.accessValid(for: account.userID)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: Notification.Name("HaloOpenSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: Notification.Name("HaloToggle"), object: nil)
        configureCommercialAccessGate()

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "capsule.tophalf.filled", accessibilityDescription: "Halo")
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Halo", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let hudRoot = NSMenuItem(title: "HUD", action: nil, keyEquivalent: "")
        let hudMenu = NSMenu(title: "HUD")
        let hudSettingsItem = NSMenuItem(title: "HUD Settings…", action: #selector(openHUDSettings), keyEquivalent: "")
        hudSettingsItem.target = self
        hudMenu.addItem(hudSettingsItem)
        hudMenu.addItem(.separator())
        let previewVolume = NSMenuItem(title: "Preview Volume HUD", action: #selector(previewVolumeHUD), keyEquivalent: "")
        previewVolume.target = self
        hudMenu.addItem(previewVolume)
        let previewBrightness = NSMenuItem(title: "Preview Screen Brightness HUD", action: #selector(previewBrightnessHUD), keyEquivalent: "")
        previewBrightness.target = self
        hudMenu.addItem(previewBrightness)
        let previewKeyboard = NSMenuItem(title: "Preview Keyboard Brightness HUD", action: #selector(previewKeyboardHUD), keyEquivalent: "")
        previewKeyboard.target = self
        hudMenu.addItem(previewKeyboard)
        hudRoot.submenu = hudMenu
        menu.addItem(hudRoot)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Halo", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        status?.menu = menu
    }

    private func configureCommercialAccessGate() {
        // The panel/geometry engine is always alive. When access is unavailable the router renders
        // only the black locked notch and the sign-in/license flow; normal Halo content never runs.
        let manager = WindowManager(store: store)
        engine = manager
        manager.start()

        Publishers.CombineLatest(
            HaloAccountManager.shared.$isSignedIn.removeDuplicates(),
            HaloLicenseManager.shared.$state.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in self?.refreshCommercialAccess() }
        .store(in: &commercialBag)

        Task { @MainActor [weak self] in
            await HaloAccountManager.shared.restore()
            await HaloLicenseManager.shared.restoreAndValidate()
            self?.refreshCommercialAccess()
        }
    }

    private func refreshCommercialAccess() {
        if commercialAccessGranted {
            startLicensedServices()
            presentSetupIfNeeded()
        } else {
            setupWindow?.orderOut(nil)
            setupWindow = nil
            setupShownThisLaunch = false
            stopLicensedServices()
        }
    }

    private func presentSetupIfNeeded() {
        guard commercialAccessGranted, !setupShownThisLaunch else { return }
        let completed = UserDefaults.standard.bool(forKey: setupCompletedKey)
        guard forceSetupEveryLaunch || !completed else { return }
        setupShownThisLaunch = true

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Halo"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.contentMinSize = NSSize(width: 900, height: 640)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: HaloFirstRunSetupView(store: store) { [weak self, weak window] in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: self.setupCompletedKey)
            window?.close()
            self.setupWindow = nil
        })
        setupWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func startLicensedServices() {
        guard !licensedServicesStarted else { return }
        licensedServicesStarted = true
        store.workspace.start()
        let hud = HaloHUDController(audio: store.workspace.audio)
        hudController = hud
        hud.start()
    }

    private func stopLicensedServices() {
        guard licensedServicesStarted else { return }
        licensedServicesStarted = false
        hudController?.stop()
        hudController = nil
        store.workspace.stop()
    }

    @objc private func toggle() { engine?.toggleAll() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func previewVolumeHUD() { postHUDPreview("volume") }
    @objc private func previewBrightnessHUD() { postHUDPreview("brightness") }
    @objc private func previewKeyboardHUD() { postHUDPreview("keyboard") }
    private func postHUDPreview(_ kind: String) {
        NotificationCenter.default.post(name: .init("HaloHUDPreview"), object: nil, userInfo: ["kind": kind])
    }

    @objc func openSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Halo · Settings"
            window.titlebarAppearsTransparent = false
            window.contentMinSize = NSSize(width: 700, height: 560)
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    @objc func openHUDSettings() {
        guard commercialAccessGranted else { engine?.toggleAll(); return }
        if hudSettings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Halo · HUD"
            window.contentMinSize = NSSize(width: 520, height: 650)
            window.contentView = NSHostingView(rootView: HaloHUDSettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            hudSettings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        hudSettings?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopLicensedServices()
        engine?.stop()
        engine = nil
        store.flushConfiguration()
    }
}


// MARK: - First-run setup

private enum HaloSetupPage: Int, CaseIterable {
    case welcome, method, manual, guided, displays, review
}

private enum HaloSetupMethod: String {
    case manual, guided
}

private enum HaloSetupUseCase: String, CaseIterable, Identifiable {
    case everyday, developer, productivity, creative, student
    var id: String { rawValue }
    var title: String {
        switch self {
        case .everyday: return "Everyday Mac"
        case .developer: return "Build & Code"
        case .productivity: return "Work & Organize"
        case .creative: return "Create & Media"
        case .student: return "Study & Focus"
        }
    }
    var detail: String {
        switch self {
        case .everyday: return "A balanced Halo for daily use."
        case .developer: return "System info, notes, files and quick tools."
        case .productivity: return "Calendar, focus tools, notes and files."
        case .creative: return "Media controls, audio, capture and files."
        case .student: return "Timers, calendar, notes and less distraction."
        }
    }
    var symbol: String {
        switch self {
        case .everyday: return "sparkles"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .productivity: return "checkmark.circle"
        case .creative: return "wand.and.stars"
        case .student: return "graduationcap"
        }
    }
}

private enum HaloSetupPriority: String, CaseIterable, Identifiable {
    case balanced, focus, files, media, system
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var detail: String {
        switch self {
        case .balanced: return "A little of everything."
        case .focus: return "Timers, calendar and notes first."
        case .files: return "Shelf and quick-launch tools first."
        case .media: return "Music, audio and playback first."
        case .system: return "Battery and system information first."
        }
    }
    var symbol: String {
        switch self {
        case .balanced: return "circle.grid.2x2"
        case .focus: return "scope"
        case .files: return "tray.full"
        case .media: return "music.note"
        case .system: return "gauge.with.dots.needle.67percent"
        }
    }
}

private enum HaloSetupDensity: String, CaseIterable, Identifiable {
    case minimal, balanced, rich
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var detail: String {
        switch self {
        case .minimal: return "Only the essentials. Quiet and compact."
        case .balanced: return "Useful without feeling crowded."
        case .rich: return "More modules and a larger workspace."
        }
    }
    var symbol: String {
        switch self {
        case .minimal: return "rectangle.compress.vertical"
        case .balanced: return "rectangle.split.3x1"
        case .rich: return "square.grid.3x3"
        }
    }
}

private enum HaloSetupMotion: String, CaseIterable, Identifiable {
    case calm, fluid, fast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .calm: return "Calm"
        case .fluid: return "Fluid"
        case .fast: return "Fast"
        }
    }
    var detail: String {
        switch self {
        case .calm: return "Subtle movement with minimal flourish."
        case .fluid: return "Smooth, polished motion — the Halo default."
        case .fast: return "Short, responsive transitions."
        }
    }
    var symbol: String {
        switch self {
        case .calm: return "leaf"
        case .fluid: return "water.waves"
        case .fast: return "bolt"
        }
    }
}

private struct HaloSetupDisplayDraft: Identifiable {
    let id: String
    let name: String
    let isNotched: Bool
    var enabled: Bool
    var theme: Theme
    var layout: WorkspaceLayout
}

@MainActor
private struct HaloFirstRunSetupView: View {
    @ObservedObject var store: AppStore
    let onComplete: () -> Void

    @State private var page: HaloSetupPage = .welcome
    @State private var method: HaloSetupMethod?
    @State private var guidedQuestion = 0
    @State private var useCase: HaloSetupUseCase = .everyday
    @State private var priority: HaloSetupPriority = .balanced
    @State private var density: HaloSetupDensity = .balanced
    @State private var motion: HaloSetupMotion = .fluid
    @State private var manualHover: Bool
    @State private var displayDrafts: [HaloSetupDisplayDraft]
    @State private var selectedDisplay = 0
    @State private var generatedProfile: Profile?

    private let moduleChoices: [ModuleID] = [.clock, .timer, .shelf, .media, .audio, .calendar, .notes, .system, .launcher, .capture]
    private let surfaceChoices: [SurfaceStyle] = [.notch, .pill, .island, .shelf, .menuBar, .simulated]

    init(store: AppStore, onComplete: @escaping () -> Void) {
        self.store = store
        self.onComplete = onComplete
        _manualHover = State(initialValue: store.configuration.hoverToExpand)
        let drafts = NSScreen.screens.map { screen -> HaloSetupDisplayDraft in
            let id = WindowManager.displayID(screen)
            let saved = store.workspace.settings.displays.first { $0.id == id }
            var theme = saved?.theme ?? store.configuration.theme
            if saved == nil, screen.safeAreaInsets.top <= 0, theme.style == .notch { theme.style = .pill }
            return HaloSetupDisplayDraft(
                id: id,
                name: screen.localizedName,
                isNotched: screen.safeAreaInsets.top > 0,
                enabled: saved?.enabled ?? true,
                theme: theme,
                layout: saved?.layout ?? store.workspace.settings.layout
            )
        }
        _displayDrafts = State(initialValue: drafts)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.03, blue: 0.06), Color(red: 0.08, green: 0.045, blue: 0.15), Color(red: 0.025, green: 0.07, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: -360, y: -260)
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 390, y: 260)

            VStack(spacing: 0) {
                setupHeader
                Divider().opacity(0.15)
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().opacity(0.15)
                navigationBar
            }
        }
        .foregroundStyle(.white)
        .frame(minWidth: 900, minHeight: 640)
    }

    private var setupHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text("Halo Setup")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Make the notch yours")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Text("DEVELOPMENT · SHOWN EVERY LAUNCH")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.62))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.07), in: Capsule())

            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index <= progressIndex ? Color.white.opacity(0.9) : Color.white.opacity(0.15))
                        .frame(width: index == progressIndex ? 22 : 7, height: 7)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    private var progressIndex: Int {
        switch page {
        case .welcome: return 0
        case .method: return 1
        case .manual, .guided: return 2
        case .displays: return 3
        case .review: return 4
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .welcome: welcomePage
        case .method: methodPage
        case .manual: manualPage
        case .guided: guidedPage
        case .displays: guidedDisplaysPage
        case .review: reviewPage
        }
    }

    private var welcomePage: some View {
        HStack(spacing: 46) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your notch can do\nso much more.")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .tracking(-1.2)
                Text("Halo turns the space around your Mac’s camera into a living, contextual surface — files, focus tools, media, system status, HUDs and more, right where your eyes already are.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 470, alignment: .leading)

                HStack(spacing: 10) {
                    Label("Hover or click to open", systemImage: "cursorarrow.rays")
                    Label("Profiles adapt to you", systemImage: "slider.horizontal.3")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                featureCard("One surface. Many jobs.", "Drop files, control music, run timers, glance at your Mac, launch tools and surface live activity.", "rectangle.3.group")
                featureCard("Context, not clutter.", "Halo can change what it shows based on what you are doing instead of filling your screen all the time.", "sparkles.rectangle.stack")
                featureCard("Built around your Mac.", "Shape, size, modules, motion and each connected display can be tuned independently.", "macbook.and.iphone")
            }
            .frame(width: 360)
        }
        .padding(.horizontal, 54)
        .padding(.vertical, 42)
    }

    private func featureCard(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var methodPage: some View {
        VStack(spacing: 26) {
            VStack(spacing: 7) {
                Text("How do you want to set up Halo?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("You can change absolutely everything later in Settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.58))
            }

            HStack(spacing: 18) {
                methodCard(
                    .manual,
                    title: "I’ll tune it myself",
                    detail: "Choose the basics now — surface style, size, modules, hover behavior and each display.",
                    symbol: "slider.horizontal.3",
                    badge: "Hands-on"
                )
                methodCard(
                    .guided,
                    title: "Build my Halo",
                    detail: "Answer four quick questions and Halo will create a profile around how you use your Mac.",
                    symbol: "wand.and.stars",
                    badge: "Recommended"
                )
            }
            .frame(maxWidth: 820)
        }
        .padding(46)
    }

    private func methodCard(_ value: HaloSetupMethod, title: String, detail: String, symbol: String, badge: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { method = value }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                    Spacer()
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color.white.opacity(0.08), in: Capsule())
                }
                Spacer()
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(value == .manual ? "Customize the essentials" : "4 questions · about a minute")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Image(systemName: method == value ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .padding(22)
            .frame(width: 380, height: 255, alignment: .leading)
            .background(method == value ? Color.white.opacity(0.12) : Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(method == value ? Color.white.opacity(0.42) : Color.white.opacity(0.08), lineWidth: method == value ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private var manualPage: some View {
        VStack(spacing: 18) {
            pageHeading("Tune the essentials", "Start with the things that most change how Halo feels. The deeper controls stay in Settings.")
            displaySelector
            if displayDrafts.indices.contains(selectedDisplay) {
                manualEditor(index: selectedDisplay)
            }
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 24)
    }

    private var displaySelector: some View {
        HStack(spacing: 8) {
            ForEach(displayDrafts.indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDisplay = index }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: displayDrafts[index].isNotched ? "laptopcomputer" : "display")
                        Text(displayDrafts[index].name)
                        if !displayDrafts[index].enabled { Image(systemName: "minus.circle.fill").opacity(0.55) }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(selectedDisplay == index ? Color.white.opacity(0.16) : Color.white.opacity(0.055), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(selectedDisplay == index ? 0.28 : 0.07), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func manualEditor(index: Int) -> some View {
        HStack(alignment: .top, spacing: 18) {
            setupPanel {
                VStack(alignment: .leading, spacing: 15) {
                    sectionLabel("Surface", "rectangle.roundedtop")
                    Toggle("Use Halo on this display", isOn: displayBinding(index, \.enabled))
                    Picker("Style", selection: themeBinding(index, \.style)) {
                        ForEach(surfaceChoices) { style in Text(style.rawValue).tag(style) }
                    }
                    Slider(value: themeBinding(index, \.width), in: 340...640, step: 10) {
                        Text("Open width")
                    }
                    Slider(value: appearanceBinding(index, \.expandedHeight), in: 280...720, step: 10) {
                        Text("Open height")
                    }
                    Toggle("Expand when I hover", isOn: $manualHover)
                }
            }
            .frame(width: 330)

            setupPanel {
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("What lives in Halo", "square.grid.2x2")
                    Text("Pick the modules you want available when Halo opens on this display.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.52))
                    moduleGrid(index: index)
                }
            }
        }
    }

    private func moduleGrid(index: Int) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], spacing: 8) {
            ForEach(moduleChoices, id: \.self) { module in
                let enabled = displayDrafts[index].layout.enabled.contains(module)
                Button {
                    if enabled { displayDrafts[index].layout.enabled.remove(module) }
                    else { displayDrafts[index].layout.enabled.insert(module) }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: module.symbol)
                        Text(module.title)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .background(enabled ? Color.white.opacity(0.15) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(enabled ? 0.24 : 0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var guidedPage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 5) {
                Text("Question \(guidedQuestion + 1) of 4")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.48))
                Text(guidedQuestionTitle)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text(guidedQuestionDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.56))
            }

            guidedChoices
                .frame(maxWidth: 820)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 34)
    }

    private var guidedQuestionTitle: String {
        switch guidedQuestion {
        case 0: return "What do you mostly do on this Mac?"
        case 1: return "What should Halo keep closest?"
        case 2: return "How much information feels right?"
        default: return "How should Halo feel?"
        }
    }

    private var guidedQuestionDetail: String {
        switch guidedQuestion {
        case 0: return "This gives us the foundation for your first profile."
        case 1: return "We’ll prioritize these modules and interactions."
        case 2: return "This controls the workspace size and how many tools are enabled."
        default: return "This tunes the animation and responsiveness preset."
        }
    }

    @ViewBuilder
    private var guidedChoices: some View {
        if guidedQuestion == 0 {
            choiceGrid {
                ForEach(HaloSetupUseCase.allCases) { option in
                    guidedChoice(option.title, option.detail, option.symbol, selected: useCase == option) { useCase = option }
                }
            }
        } else if guidedQuestion == 1 {
            choiceGrid {
                ForEach(HaloSetupPriority.allCases) { option in
                    guidedChoice(option.title, option.detail, option.symbol, selected: priority == option) { priority = option }
                }
            }
        } else if guidedQuestion == 2 {
            choiceGrid {
                ForEach(HaloSetupDensity.allCases) { option in
                    guidedChoice(option.title, option.detail, option.symbol, selected: density == option) { density = option }
                }
            }
        } else {
            choiceGrid {
                ForEach(HaloSetupMotion.allCases) { option in
                    guidedChoice(option.title, option.detail, option.symbol, selected: motion == option) { motion = option }
                }
            }
        }
    }

    private func choiceGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 12)], spacing: 12) { content() }
    }

    private func guidedChoice(_ title: String, _ detail: String, _ symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 35, height: 35)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(.white.opacity(selected ? 0.95 : 0.28))
                    }
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(selected ? Color.white.opacity(0.14) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(selected ? 0.30 : 0.07), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private var guidedDisplaysPage: some View {
        VStack(spacing: 18) {
            pageHeading(displayDrafts.count > 1 ? "Make each display feel right" : "Place Halo on your display",
                        displayDrafts.count > 1 ? "Halo can use a different surface on every connected display." : "We picked a starting point based on your answers. Tweak it if you want.")
            displaySelector
            if displayDrafts.indices.contains(selectedDisplay) {
                setupPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Use Halo on \(displayDrafts[selectedDisplay].name)", isOn: displayBinding(selectedDisplay, \.enabled))
                        Picker("Surface", selection: themeBinding(selectedDisplay, \.style)) {
                            ForEach(surfaceChoices) { style in Text(style.rawValue).tag(style) }
                        }
                        Slider(value: themeBinding(selectedDisplay, \.width), in: 340...640, step: 10) {
                            Text("Open width")
                        }
                        HStack(spacing: 8) {
                            Image(systemName: displayDrafts[selectedDisplay].isNotched ? "camera.metering.center.weighted" : "display")
                            Text(displayDrafts[selectedDisplay].isNotched ? "Halo detected a physical notch and chose a native notch surface." : "Halo detected an external/non-notched display and chose a floating surface.")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .frame(maxWidth: 650)
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 26)
    }

    private var reviewPage: some View {
        VStack(spacing: 22) {
            pageHeading("Your Halo is ready", "This is only the starting point. Every choice here remains editable later.")

            HStack(spacing: 14) {
                reviewCard("Setup", method == .guided ? "Personalized profile" : "Manual essentials", method == .guided ? "wand.and.stars" : "slider.horizontal.3")
                reviewCard("Displays", "\(displayDrafts.filter(\.enabled).count) enabled", "display.2")
                reviewCard("Interaction", manualHover ? "Hover to expand" : "Click to expand", "cursorarrow.rays")
            }
            .frame(maxWidth: 760)

            if let primary = displayDrafts.first(where: { $0.enabled }) {
                setupPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(method == .guided ? (generatedProfile?.name ?? "My Halo") : "My Halo")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Spacer()
                            Text(primary.theme.style.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Text(primary.layout.enabled.map(\.title).sorted().joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.56))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Tip: Profiles can later switch automatically by app, time, battery state or display count.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                .frame(maxWidth: 760)
            }
        }
        .padding(42)
    }

    private func reviewCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.48))
            Text(value).font(.system(size: 13, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func pageHeading(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 27, weight: .bold, design: .rounded))
            Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
        }
    }

    private func sectionLabel(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 12, weight: .bold, design: .rounded))
    }

    private func setupPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.075), lineWidth: 1))
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            if page != .welcome {
                Button("Back", action: goBack)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 14).padding(.vertical, 9)
            }

            Spacer()

            if !hasEnabledDisplay && (page == .manual || page == .displays || page == .review) {
                Label("Enable at least one display", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.9))
            }

            Button(action: advance) {
                HStack(spacing: 7) {
                    Text(nextTitle)
                    Image(systemName: page == .review ? "checkmark" : "arrow.right")
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 17).padding(.vertical, 10)
                .background(Color.white, in: Capsule())
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.35)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private var nextTitle: String {
        if page == .review { return "Finish setup" }
        if page == .guided && guidedQuestion < 3 { return "Next question" }
        return "Continue"
    }

    private var hasEnabledDisplay: Bool { displayDrafts.contains(where: { $0.enabled }) }

    private var canAdvance: Bool {
        switch page {
        case .method: return method != nil
        case .manual, .displays, .review: return hasEnabledDisplay
        default: return true
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch page {
            case .welcome:
                page = .method
            case .method:
                page = method == .guided ? .guided : .manual
            case .manual:
                generatedProfile = nil
                page = .review
            case .guided:
                if guidedQuestion < 3 {
                    guidedQuestion += 1
                } else {
                    buildGuidedDrafts()
                    page = .displays
                }
            case .displays:
                page = .review
            case .review:
                commitSetup()
            }
        }
    }

    private func goBack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch page {
            case .welcome: break
            case .method: page = .welcome
            case .manual: page = .method
            case .guided:
                if guidedQuestion > 0 { guidedQuestion -= 1 }
                else { page = .method }
            case .displays:
                guidedQuestion = 3
                page = .guided
            case .review:
                page = method == .guided ? .displays : .manual
            }
        }
    }

    private func buildGuidedDrafts() {
        let profile = makeGuidedProfile()
        generatedProfile = profile
        manualHover = true
        for index in displayDrafts.indices {
            displayDrafts[index].layout = profile.layout
            displayDrafts[index].theme = profile.theme
            displayDrafts[index].theme.style = displayDrafts[index].isNotched ? .notch : .pill
        }
    }

    private func makeGuidedProfile() -> Profile {
        var base: [ModuleID]
        switch useCase {
        case .everyday: base = [.clock, .timer, .shelf, .system, .launcher]
        case .developer: base = [.timer, .shelf, .system, .notes, .capture, .launcher]
        case .productivity: base = [.clock, .timer, .calendar, .notes, .shelf, .activities]
        case .creative: base = [.media, .audio, .shelf, .capture, .system]
        case .student: base = [.clock, .timer, .calendar, .notes, .shelf]
        }

        let priorityModules: [ModuleID]
        switch priority {
        case .balanced: priorityModules = [.clock, .timer, .shelf, .system, .launcher]
        case .focus: priorityModules = [.timer, .calendar, .notes]
        case .files: priorityModules = [.shelf, .launcher, .notes]
        case .media: priorityModules = [.media, .audio]
        case .system: priorityModules = [.system, .activities]
        }

        var ordered: [ModuleID] = []
        for module in priorityModules + base where !ordered.contains(module) { ordered.append(module) }
        if density == .rich {
            for module in [ModuleID.clock, .timer, .shelf, .media, .audio, .calendar, .notes, .system, .launcher, .capture, .activities] where !ordered.contains(module) {
                ordered.append(module)
            }
        }

        let count: Int
        switch density { case .minimal: count = 3; case .balanced: count = 6; case .rich: count = 10 }
        let enabled = Set(ordered.prefix(count))

        var layout = WorkspaceLayout()
        layout.enabled = enabled
        layout.order = ordered + ModuleID.allCases.filter { !ordered.contains($0) }

        switch density {
        case .minimal:
            layout.appearance.expandedHeight = 360
            layout.appearance.spacing = 8
        case .balanced:
            layout.appearance.expandedHeight = 500
            layout.appearance.spacing = 12
        case .rich:
            layout.appearance.expandedHeight = 620
            layout.appearance.spacing = 14
        }

        switch motion {
        case .calm: layout.appearance.animation = .minimal
        case .fluid: layout.appearance.animation = .smooth
        case .fast: layout.appearance.animation = .snappy
        }

        if enabled.contains(.media) || priority == .media || useCase == .creative {
            var music = ContextMusicOptions()
            music.enabled = true
            music.showVisualizer = density == .rich
            music.layoutMode = density == .minimal ? .compact : .hero
            layout.contextMusic = music
        }

        var theme = Theme()
        theme.name = "Halo Setup"
        theme.width = density == .minimal ? 380 : (density == .balanced ? 440 : 520)
        theme.cornerRadius = density == .minimal ? 20 : 24
        theme.opacity = 0.95
        theme.animations = true
        theme.style = .notch

        var profile = Profile(name: profileName, theme: theme, layout: layout)
        profile.description = "Halo Setup Profile"
        profile.icon = useCase.symbol
        return profile
    }

    private var profileName: String {
        switch useCase {
        case .everyday: return "My Halo"
        case .developer: return "Developer Halo"
        case .productivity: return "Productivity Halo"
        case .creative: return "Creative Halo"
        case .student: return "Study Halo"
        }
    }

    private func commitSetup() {
        guard let primary = displayDrafts.first(where: { $0.enabled }) else { return }

        store.configuration.hoverToExpand = manualHover
        store.configuration.allDisplays = displayDrafts.count > 1
        store.configuration.theme = primary.theme
        store.workspace.settings.layout = primary.layout

        let currentIDs = Set(displayDrafts.map(\.id))
        let preserved = store.workspace.settings.displays.filter { !currentIDs.contains($0.id) }
        let overrides = displayDrafts.map { draft in
            DisplayOverride(id: draft.id, enabled: draft.enabled, theme: draft.theme, layout: draft.layout)
        }
        store.workspace.settings.displays = preserved + overrides

        var profile: Profile
        if method == .guided {
            profile = generatedProfile ?? makeGuidedProfile()
            profile.theme = primary.theme
            profile.layout = primary.layout
        } else {
            profile = Profile(name: "My Halo", theme: primary.theme, layout: primary.layout)
            profile.description = "Halo Setup Profile"
            profile.icon = "slider.horizontal.3"
        }

        if let index = store.workspace.settings.profiles.firstIndex(where: { $0.description == "Halo Setup Profile" }) {
            profile.id = store.workspace.settings.profiles[index].id
            store.workspace.settings.profiles[index] = profile
        } else {
            store.workspace.settings.profiles.append(profile)
        }

        store.flushConfiguration()
        onComplete()
    }

    private func displayBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<HaloSetupDisplayDraft, T>) -> Binding<T> {
        Binding(
            get: { displayDrafts[index][keyPath: keyPath] },
            set: { displayDrafts[index][keyPath: keyPath] = $0 }
        )
    }

    private func themeBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<Theme, T>) -> Binding<T> {
        Binding(
            get: { displayDrafts[index].theme[keyPath: keyPath] },
            set: { displayDrafts[index].theme[keyPath: keyPath] = $0 }
        )
    }

    private func appearanceBinding<T>(_ index: Int, _ keyPath: WritableKeyPath<Appearance, T>) -> Binding<T> {
        Binding(
            get: { displayDrafts[index].layout.appearance[keyPath: keyPath] },
            set: { displayDrafts[index].layout.appearance[keyPath: keyPath] = $0 }
        )
    }
}


enum HaloHUDKeys {
    static let enabled = "HaloHUDEnabled"
    static let replaceVolume = "HaloHUDReplaceVolume"
    static let replaceBrightness = "HaloHUDReplaceBrightness"
    static let replaceKeyboardBrightness = "HaloHUDReplaceKeyboardBrightness"
    static let volumeHUD = "HaloHUDVolumeEnabled"
    static let muteHUD = "HaloHUDMuteEnabled"
    static let brightnessHUD = "HaloHUDBrightnessEnabled"
    static let keyboardBrightnessHUD = "HaloHUDKeyboardBrightnessEnabled"
    static let layout = "HaloHUDLayout"
    static let position = "HaloHUDPosition"
    static let progress = "HaloHUDProgressStyle"
    static let background = "HaloHUDBackgroundStyle"
    static let width = "HaloHUDWidth"
    static let height = "HaloHUDHeight"
    static let padding = "HaloHUDPadding"
    static let corner = "HaloHUDCornerRadius"
    static let iconSize = "HaloHUDIconSize"
    static let valueSize = "HaloHUDValueSize"
    static let opacity = "HaloHUDBackgroundOpacity"
    static let accentHue = "HaloHUDAccentHue"
    static let saturation = "HaloHUDAccentSaturation"
    static let brightness = "HaloHUDAccentBrightness"
    static let dynamicAccent = "HaloHUDDynamicAccent"
    static let showIcon = "HaloHUDShowIcon"
    static let showLabel = "HaloHUDShowLabel"
    static let showValue = "HaloHUDShowValue"
    static let showProgress = "HaloHUDShowProgress"
    static let segments = "HaloHUDSegments"
    static let timeout = "HaloHUDTimeout"
    static let shadow = "HaloHUDShadow"
    static let offsetX = "HaloHUDOffsetX"
    static let offsetY = "HaloHUDOffsetY"
    static let volumeStep = "HaloHUDVolumeStep"
    static let brightnessStep = "HaloHUDBrightnessStep"
    static let keyboardStep = "HaloHUDKeyboardBrightnessStep"
}

private enum HaloHUDKind { case volume, mute, brightness, keyboardBrightness }

@MainActor
private final class HaloHUDState: ObservableObject {
    @Published var kind: HaloHUDKind = .volume
    @Published var value = 0.5
    @Published var label = "Volume"
    @Published var symbol = "speaker.wave.2.fill"
    @Published var sequence = 0
}

private final class HaloDisplayBrightnessService {
    private let parameter = kIODisplayBrightnessKey as CFString

    func current() -> Double? {
        withService { service in
            var value: Float = 0
            guard IODisplayGetFloatParameter(service, 0, parameter, &value) == kIOReturnSuccess else { return nil }
            return Double(min(1, max(0, value)))
        }
    }

    @discardableResult func set(_ value: Double) -> Bool {
        let target = Float(min(1, max(0, value)))
        return withService { service in
            IODisplaySetFloatParameter(service, 0, parameter, target) == kIOReturnSuccess
        } ?? false
    }

    func canSet() -> Bool {
        guard let value = current() else { return false }
        return set(value)
    }

    private func withService<T>(_ body: (io_service_t) -> T?) -> T? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            if let value = body(service) {
                IOObjectRelease(service)
                return value
            }
            IOObjectRelease(service)
        }
        return nil
    }
}

private final class HaloKeyboardBrightnessService {
    private let classes = ["AppleHIDKeyboardEventDriverV2", "AppleHIDKeyboardEventDriver", "AppleUserHIDEventDriver"]
    private let keys = ["KeyboardBacklightBrightness", "KeyboardBacklightLevel"]

    func current() -> Double? {
        for className in classes {
            if let value = withEntries(className: className, body: { entry in self.read(entry: entry) }) { return value }
        }
        return nil
    }

    @discardableResult func set(_ value: Double) -> Bool {
        let target = min(1, max(0, value))
        for className in classes {
            if withEntries(className: className, body: { entry in self.write(entry: entry, normalized: target) ? true : nil }) == true { return true }
        }
        return false
    }

    func canSet() -> Bool {
        guard let value = current() else { return false }
        return set(value)
    }

    private func read(entry: io_service_t) -> Double? {
        for keyName in keys {
            let key = keyName as CFString
            if let value = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key, kCFAllocatorDefault,
                                                            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)),
               let number = value as? NSNumber {
                let raw = number.doubleValue
                if raw <= 1.0001 { return min(1, max(0, raw)) }
                if raw <= 255 { return min(1, max(0, raw / 255.0)) }
                return min(1, max(0, raw / 4095.0))
            }
        }
        return nil
    }

    private func write(entry: io_service_t, normalized: Double) -> Bool {
        for keyName in keys {
            let key = keyName as CFString
            guard let value = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key, kCFAllocatorDefault,
                                                               IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)),
                  let existing = value as? NSNumber else { continue }
            let raw = existing.doubleValue
            let scale: Double = raw <= 1.0001 ? 1 : (raw <= 255 ? 255 : 4095)
            let valueToWrite: NSNumber = scale == 1 ? NSNumber(value: normalized) : NSNumber(value: Int((normalized * scale).rounded()))
            if IORegistryEntrySetCFProperty(entry, key, valueToWrite) == KERN_SUCCESS { return true }
        }
        return false
    }

    private func withEntries<T>(className: String, body: (io_service_t) -> T?) -> T? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            if let result = body(entry) {
                IOObjectRelease(entry)
                return result
            }
            IOObjectRelease(entry)
        }
        return nil
    }
}

@MainActor
private final class HaloHUDController {
    private let audio: AudioService
    private let displayBrightness = HaloDisplayBrightnessService()
    private let keyboardBrightness = HaloKeyboardBrightnessService()
    private let model = HaloHUDState()
    private var panel: NSPanel?
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var defaultsObserver: NSObjectProtocol?
    private var previewObserver: NSObjectProtocol?
    private var hideWork: DispatchWorkItem?
    private var lastNonZeroVolume: Float32 = 0.5
    private var lastDisplayBrightness = 0.5
    private var lastKeyboardBrightness = 0.5
    private var activeReplacementKeys = Set<Int>()

    init(audio: AudioService) { self.audio = audio }

    func start() {
        registerDefaults()
        createPanel()
        configureInput()
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureInput() }
        }
        previewObserver = NotificationCenter.default.addObserver(forName: .init("HaloHUDPreview"), object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                switch note.userInfo?["kind"] as? String {
                case "brightness": self.show(kind: .brightness, value: 0.68, label: "Screen Brightness", symbol: "sun.max.fill")
                case "keyboard": self.show(kind: .keyboardBrightness, value: 0.58, label: "Keyboard Brightness", symbol: "keyboard")
                default: self.show(kind: .volume, value: 0.68, label: "Volume", symbol: "speaker.wave.2.fill")
                }
            }
        }
    }

    func stop() {
        tearDownInput()
        hideWork?.cancel()
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        if let previewObserver { NotificationCenter.default.removeObserver(previewObserver) }
        panel?.close(); panel = nil
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            HaloHUDKeys.enabled: true,
            HaloHUDKeys.replaceVolume: false,
            HaloHUDKeys.replaceBrightness: false,
            HaloHUDKeys.replaceKeyboardBrightness: false,
            HaloHUDKeys.volumeHUD: true,
            HaloHUDKeys.muteHUD: true,
            HaloHUDKeys.brightnessHUD: true,
            HaloHUDKeys.keyboardBrightnessHUD: true,
            HaloHUDKeys.layout: "horizontal",
            HaloHUDKeys.position: "top",
            HaloHUDKeys.progress: "bar",
            HaloHUDKeys.background: "glass",
            HaloHUDKeys.width: 320.0,
            HaloHUDKeys.height: 92.0,
            HaloHUDKeys.padding: 16.0,
            HaloHUDKeys.corner: 24.0,
            HaloHUDKeys.iconSize: 24.0,
            HaloHUDKeys.valueSize: 14.0,
            HaloHUDKeys.opacity: 0.72,
            HaloHUDKeys.accentHue: 0.59,
            HaloHUDKeys.saturation: 0.72,
            HaloHUDKeys.brightness: 1.0,
            HaloHUDKeys.dynamicAccent: false,
            HaloHUDKeys.showIcon: true,
            HaloHUDKeys.showLabel: true,
            HaloHUDKeys.showValue: true,
            HaloHUDKeys.showProgress: true,
            HaloHUDKeys.segments: 16,
            HaloHUDKeys.timeout: 1.15,
            HaloHUDKeys.shadow: true,
            HaloHUDKeys.offsetX: 0.0,
            HaloHUDKeys.offsetY: 0.0,
            HaloHUDKeys.volumeStep: 0.0625,
            HaloHUDKeys.brightnessStep: 0.0625,
            HaloHUDKeys.keyboardStep: 0.0625
        ])
    }

    private func createPanel() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 92), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: HaloHUDOverlayView(model: model))
        panel.alphaValue = 0
        self.panel = panel
    }

    private func configureInput() {
        tearDownInput()
        activeReplacementKeys.removeAll()
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: HaloHUDKeys.enabled) else { return }

        audio.refresh()
        if defaults.bool(forKey: HaloHUDKeys.replaceVolume), audio.canSetVolume {
            activeReplacementKeys.formUnion([0, 1, 7])
        }
        if defaults.bool(forKey: HaloHUDKeys.replaceBrightness), displayBrightness.canSet() {
            activeReplacementKeys.formUnion([2, 3])
        }
        if defaults.bool(forKey: HaloHUDKeys.replaceKeyboardBrightness), keyboardBrightness.canSet() {
            activeReplacementKeys.formUnion([21, 22, 23])
        }

        if !activeReplacementKeys.isEmpty, AXIsProcessTrusted() { _ = installEventTap() }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in self?.handleObserved(event: event) }
        }
    }

    private func tearDownInput() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes); self.eventSource = nil }
        if let eventTap { CFMachPortInvalidate(eventTap); self.eventTap = nil }
    }

    private func installEventTap() -> Bool {
        let mask = CGEventMask(1) << 14
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<HaloHUDController>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
                return Unmanaged.passUnretained(event)
            }
            let data = nsEvent.data1
            let keyCode = (data & 0xFFFF0000) >> 16
            guard controller.activeReplacementKeys.contains(keyCode), UserDefaults.standard.bool(forKey: HaloHUDKeys.enabled) else {
                return Unmanaged.passUnretained(event)
            }
            let keyFlags = data & 0xFFFF
            let keyState = (keyFlags & 0xFF00) >> 8
            if keyState == 0xA {
                Task { @MainActor in controller.handleReplacementKey(keyCode) }
            }
            return nil
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventSource = source
        return true
    }

    private func handleObserved(event: NSEvent) {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }
        let data = event.data1
        let keyCode = (data & 0xFFFF0000) >> 16
        let keyFlags = data & 0xFFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        guard keyState == 0xA, !activeReplacementKeys.contains(keyCode) else { return }
        showObservedSystemKey(keyCode)
    }

    private func handleReplacementKey(_ keyCode: Int) {
        let defaults = UserDefaults.standard
        switch keyCode {
        case 0, 1, 7:
            audio.refresh()
            let current = min(1, max(0, audio.volume))
            let step = Float32(min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.volumeStep))))
            if keyCode == 0 {
                let next = min(1, current + step)
                if next > 0.01 { lastNonZeroVolume = next }
                audio.setVolume(next)
                if defaults.bool(forKey: HaloHUDKeys.volumeHUD) { showVolume(next) }
            } else if keyCode == 1 {
                let next = max(0, current - step)
                if next > 0.01 { lastNonZeroVolume = next }
                audio.setVolume(next)
                if defaults.bool(forKey: HaloHUDKeys.volumeHUD) { showVolume(next) }
            } else {
                let next: Float32
                if current > 0.005 { lastNonZeroVolume = current; next = 0 }
                else { next = max(0.05, lastNonZeroVolume) }
                audio.setVolume(next)
                if defaults.bool(forKey: HaloHUDKeys.muteHUD) {
                    show(kind: .mute, value: Double(next), label: next <= 0.005 ? "Muted" : "Volume", symbol: next <= 0.005 ? "speaker.slash.fill" : volumeSymbol(next))
                }
            }

        case 2, 3:
            let current = displayBrightness.current() ?? lastDisplayBrightness
            let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.brightnessStep)))
            let next = min(1, max(0, current + (keyCode == 2 ? step : -step)))
            if displayBrightness.set(next) { lastDisplayBrightness = next }
            if defaults.bool(forKey: HaloHUDKeys.brightnessHUD) {
                show(kind: .brightness, value: next, label: "Screen Brightness", symbol: screenBrightnessSymbol(next))
            }

        case 21, 22, 23:
            let current = keyboardBrightness.current() ?? lastKeyboardBrightness
            let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.keyboardStep)))
            let next: Double
            if keyCode == 23 { next = current > 0.01 ? 0 : max(0.25, lastKeyboardBrightness) }
            else { next = min(1, max(0, current + (keyCode == 21 ? step : -step))) }
            if next > 0.01 { lastKeyboardBrightness = next }
            _ = keyboardBrightness.set(next)
            if defaults.bool(forKey: HaloHUDKeys.keyboardBrightnessHUD) {
                show(kind: .keyboardBrightness, value: next, label: "Keyboard Brightness", symbol: keyboardBrightnessSymbol(next))
            }

        default: break
        }
    }

    private func showObservedSystemKey(_ keyCode: Int) {
        let defaults = UserDefaults.standard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else { return }
            switch keyCode {
            case 0, 1, 7:
                self.audio.refresh()
                let value = Double(min(1, max(0, self.audio.volume)))
                if keyCode == 7 {
                    if defaults.bool(forKey: HaloHUDKeys.muteHUD) {
                        self.show(kind: .mute, value: value, label: value <= 0.005 ? "Muted" : "Volume", symbol: value <= 0.005 ? "speaker.slash.fill" : self.volumeSymbol(Float32(value)))
                    }
                } else if defaults.bool(forKey: HaloHUDKeys.volumeHUD) { self.showVolume(Float32(value)) }

            case 2, 3:
                let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.brightnessStep)))
                let value = self.displayBrightness.current() ?? min(1, max(0, self.lastDisplayBrightness + (keyCode == 2 ? step : -step)))
                self.lastDisplayBrightness = value
                if defaults.bool(forKey: HaloHUDKeys.brightnessHUD) {
                    self.show(kind: .brightness, value: value, label: "Screen Brightness", symbol: self.screenBrightnessSymbol(value))
                }

            case 21, 22, 23:
                let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.keyboardStep)))
                let fallback: Double
                if keyCode == 23 { fallback = self.lastKeyboardBrightness > 0.01 ? 0 : 0.5 }
                else { fallback = min(1, max(0, self.lastKeyboardBrightness + (keyCode == 21 ? step : -step))) }
                let value = self.keyboardBrightness.current() ?? fallback
                self.lastKeyboardBrightness = value
                if defaults.bool(forKey: HaloHUDKeys.keyboardBrightnessHUD) {
                    self.show(kind: .keyboardBrightness, value: value, label: "Keyboard Brightness", symbol: self.keyboardBrightnessSymbol(value))
                }
            default: break
            }
        }
    }

    private func showVolume(_ value: Float32) {
        show(kind: .volume, value: Double(value), label: "Volume", symbol: volumeSymbol(value))
    }

    private func volumeSymbol(_ value: Float32) -> String {
        if value <= 0.005 { return "speaker.slash.fill" }
        if value < 0.34 { return "speaker.wave.1.fill" }
        if value < 0.68 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func screenBrightnessSymbol(_ value: Double) -> String {
        value <= 0.12 ? "sun.min.fill" : "sun.max.fill"
    }

    private func keyboardBrightnessSymbol(_ value: Double) -> String {
        value <= 0.01 ? "keyboard" : "keyboard.fill"
    }

    private func show(kind: HaloHUDKind, value: Double, label: String, symbol: String) {
        guard UserDefaults.standard.bool(forKey: HaloHUDKeys.enabled), let panel else { return }
        model.kind = kind
        model.value = min(1, max(0, value))
        model.label = label
        model.symbol = symbol
        model.sequence += 1
        position(panel)
        hideWork?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        let timeout = min(4, max(0.35, UserDefaults.standard.double(forKey: HaloHUDKeys.timeout)))
        let work = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.20
                panel.animator().alphaValue = 0
            }, completionHandler: { panel.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    private func position(_ panel: NSPanel) {
        let defaults = UserDefaults.standard
        let width = CGFloat(min(520, max(160, defaults.double(forKey: HaloHUDKeys.width))))
        let height = CGFloat(min(260, max(54, defaults.double(forKey: HaloHUDKeys.height))))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = screen.visibleFrame
        let xOffset = CGFloat(min(300, max(-300, defaults.double(forKey: HaloHUDKeys.offsetX))))
        let yOffset = CGFloat(min(300, max(-300, defaults.double(forKey: HaloHUDKeys.offsetY))))
        let inset: CGFloat = 28
        let position = defaults.string(forKey: HaloHUDKeys.position) ?? "top"
        var x = frame.midX - width / 2
        var y = frame.maxY - height - inset
        switch position {
        case "topLeading": x = frame.minX + inset; y = frame.maxY - height - inset
        case "topTrailing": x = frame.maxX - width - inset; y = frame.maxY - height - inset
        case "center": x = frame.midX - width / 2; y = frame.midY - height / 2
        case "bottom": x = frame.midX - width / 2; y = frame.minY + inset
        case "bottomLeading": x = frame.minX + inset; y = frame.minY + inset
        case "bottomTrailing": x = frame.maxX - width - inset; y = frame.minY + inset
        default: break
        }
        panel.setFrame(NSRect(x: x + xOffset, y: y + yOffset, width: width, height: height), display: true)
    }
}

private struct HaloHUDOverlayView: View {
    @ObservedObject var model: HaloHUDState
    @AppStorage(HaloHUDKeys.layout) private var layout = "horizontal"
    @AppStorage(HaloHUDKeys.progress) private var progressStyle = "bar"
    @AppStorage(HaloHUDKeys.background) private var backgroundStyle = "glass"
    @AppStorage(HaloHUDKeys.padding) private var padding = 16.0
    @AppStorage(HaloHUDKeys.corner) private var corner = 24.0
    @AppStorage(HaloHUDKeys.iconSize) private var iconSize = 24.0
    @AppStorage(HaloHUDKeys.valueSize) private var valueSize = 14.0
    @AppStorage(HaloHUDKeys.opacity) private var backgroundOpacity = 0.72
    @AppStorage(HaloHUDKeys.accentHue) private var accentHue = 0.59
    @AppStorage(HaloHUDKeys.saturation) private var accentSaturation = 0.72
    @AppStorage(HaloHUDKeys.brightness) private var accentBrightness = 1.0
    @AppStorage(HaloHUDKeys.dynamicAccent) private var dynamicAccent = false
    @AppStorage(HaloHUDKeys.showIcon) private var showIcon = true
    @AppStorage(HaloHUDKeys.showLabel) private var showLabel = true
    @AppStorage(HaloHUDKeys.showValue) private var showValue = true
    @AppStorage(HaloHUDKeys.showProgress) private var showProgress = true
    @AppStorage(HaloHUDKeys.segments) private var segments = 16
    @AppStorage(HaloHUDKeys.shadow) private var shadow = true

    private var accent: Color {
        if dynamicAccent {
            let hue = 0.02 + model.value * 0.31
            return Color(hue: hue, saturation: 0.82, brightness: 1)
        }
        return Color(hue: accentHue, saturation: accentSaturation, brightness: accentBrightness)
    }

    var body: some View {
        Group {
            if layout == "vertical" { vertical }
            else if layout == "compact" { compact }
            else { horizontal }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { hudBackground }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: shadow ? .black.opacity(0.34) : .clear, radius: 18, y: 8)
        .foregroundStyle(.white)
        .id(model.sequence)
    }

    private var horizontal: some View {
        HStack(spacing: 14) {
            icon
            VStack(alignment: .leading, spacing: 7) {
                header
                progress
            }
        }
    }

    private var vertical: some View {
        VStack(spacing: 10) {
            icon
            header
            progress
        }
    }

    private var compact: some View {
        HStack(spacing: 10) {
            icon
            if showValue { Text("\(Int((model.value * 100).rounded()))%").font(.system(size: valueSize, weight: .bold, design: .rounded)).monospacedDigit() }
            if showProgress { progress.frame(maxWidth: 150) }
        }
    }

    @ViewBuilder private var icon: some View {
        if showIcon {
            Image(systemName: model.symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: iconSize * 1.45, height: iconSize * 1.45)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if showLabel { Text(model.label).font(.system(size: max(11, valueSize * 0.86), weight: .semibold, design: .rounded)) }
            Spacer(minLength: 4)
            if showValue { Text("\(Int((model.value * 100).rounded()))%").font(.system(size: valueSize, weight: .bold, design: .rounded)).monospacedDigit() }
        }
    }

    @ViewBuilder private var progress: some View {
        if showProgress {
            switch progressStyle {
            case "segments":
                HStack(spacing: 2) {
                    ForEach(0..<max(4, min(32, segments)), id: \.self) { index in
                        Capsule().fill(Double(index + 1) / Double(max(4, segments)) <= model.value ? accent : Color.white.opacity(0.13))
                    }
                }.frame(height: 7)
            case "ring":
                ZStack {
                    Circle().stroke(Color.white.opacity(0.13), lineWidth: 5)
                    Circle().trim(from: 0, to: model.value).stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                }.frame(width: 34, height: 34)
            case "none":
                EmptyView()
            default:
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.13))
                        Capsule().fill(accent).frame(width: max(3, proxy.size.width * model.value))
                    }
                }.frame(height: 7)
            }
        }
    }

    @ViewBuilder private var hudBackground: some View {
        switch backgroundStyle {
        case "clear": Color.clear
        case "solid": Color.black.opacity(backgroundOpacity)
        default: Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(max(0, backgroundOpacity - 0.45)))
        }
    }
}

struct HaloHUDSettingsView: View {
    @AppStorage(HaloHUDKeys.enabled) private var enabled = true
    @AppStorage(HaloHUDKeys.replaceVolume) private var replaceVolume = false
    @AppStorage(HaloHUDKeys.replaceBrightness) private var replaceBrightness = false
    @AppStorage(HaloHUDKeys.replaceKeyboardBrightness) private var replaceKeyboardBrightness = false
    @AppStorage(HaloHUDKeys.volumeHUD) private var volumeHUD = true
    @AppStorage(HaloHUDKeys.muteHUD) private var muteHUD = true
    @AppStorage(HaloHUDKeys.brightnessHUD) private var brightnessHUD = true
    @AppStorage(HaloHUDKeys.keyboardBrightnessHUD) private var keyboardBrightnessHUD = true
    @AppStorage(HaloHUDKeys.layout) private var layout = "horizontal"
    @AppStorage(HaloHUDKeys.position) private var position = "top"
    @AppStorage(HaloHUDKeys.progress) private var progress = "bar"
    @AppStorage(HaloHUDKeys.background) private var background = "glass"
    @AppStorage(HaloHUDKeys.width) private var width = 320.0
    @AppStorage(HaloHUDKeys.height) private var height = 92.0
    @AppStorage(HaloHUDKeys.padding) private var padding = 16.0
    @AppStorage(HaloHUDKeys.corner) private var corner = 24.0
    @AppStorage(HaloHUDKeys.iconSize) private var iconSize = 24.0
    @AppStorage(HaloHUDKeys.valueSize) private var valueSize = 14.0
    @AppStorage(HaloHUDKeys.opacity) private var opacity = 0.72
    @AppStorage(HaloHUDKeys.accentHue) private var accentHue = 0.59
    @AppStorage(HaloHUDKeys.saturation) private var saturation = 0.72
    @AppStorage(HaloHUDKeys.brightness) private var brightness = 1.0
    @AppStorage(HaloHUDKeys.dynamicAccent) private var dynamicAccent = false
    @AppStorage(HaloHUDKeys.showIcon) private var showIcon = true
    @AppStorage(HaloHUDKeys.showLabel) private var showLabel = true
    @AppStorage(HaloHUDKeys.showValue) private var showValue = true
    @AppStorage(HaloHUDKeys.showProgress) private var showProgress = true
    @AppStorage(HaloHUDKeys.segments) private var segments = 16
    @AppStorage(HaloHUDKeys.timeout) private var timeout = 1.15
    @AppStorage(HaloHUDKeys.shadow) private var shadow = true
    @AppStorage(HaloHUDKeys.offsetX) private var offsetX = 0.0
    @AppStorage(HaloHUDKeys.offsetY) private var offsetY = 0.0
    @AppStorage(HaloHUDKeys.volumeStep) private var volumeStep = 0.0625
    @AppStorage(HaloHUDKeys.brightnessStep) private var brightnessStep = 0.0625
    @AppStorage(HaloHUDKeys.keyboardStep) private var keyboardStep = 0.0625

    private var wantsTrueReplacement: Bool { replaceVolume || replaceBrightness || replaceKeyboardBrightness }

    var body: some View {
        Form {
            Section("HUD replacement") {
                Toggle("Enable Halo HUD", isOn: $enabled)
                Toggle("Replace Apple's volume HUD", isOn: $replaceVolume)
                Toggle("Replace Apple's screen brightness HUD", isOn: $replaceBrightness)
                Toggle("Replace Apple's keyboard brightness HUD", isOn: $replaceKeyboardBrightness)
                if wantsTrueReplacement && !AXIsProcessTrusted() {
                    Text("True HUD replacement needs Accessibility permission so Halo can intercept the hardware keys. Without it, Halo observes the keys and leaves macOS behavior untouched.").font(.caption).foregroundStyle(.orange)
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                    }
                }
                Text("Display replacement is enabled only when the active display exposes a writable IOKit brightness control. Keyboard replacement is enabled only when Halo can prove the Mac's keyboard-backlight registry entry is writable; unsupported Macs safely fall back to observation.").font(.caption).foregroundStyle(.secondary)
            }

            Section("HUD types") {
                Toggle("Volume changes", isOn: $volumeHUD)
                Toggle("Mute / unmute", isOn: $muteHUD)
                Toggle("Screen brightness", isOn: $brightnessHUD)
                Toggle("Keyboard brightness", isOn: $keyboardBrightnessHUD)
                HStack {
                    Button("Preview volume") { preview("volume") }
                    Button("Preview screen") { preview("brightness") }
                    Button("Preview keyboard") { preview("keyboard") }
                }
            }

            Section("Layout") {
                Picker("Layout", selection: $layout) {
                    Text("Horizontal").tag("horizontal")
                    Text("Vertical").tag("vertical")
                    Text("Compact").tag("compact")
                }.pickerStyle(.segmented)
                Picker("Position", selection: $position) {
                    Text("Top left").tag("topLeading"); Text("Top").tag("top"); Text("Top right").tag("topTrailing")
                    Text("Center").tag("center")
                    Text("Bottom left").tag("bottomLeading"); Text("Bottom").tag("bottom"); Text("Bottom right").tag("bottomTrailing")
                }
                Slider(value: $width, in: 160...520) { Text("Width") }
                Slider(value: $height, in: 54...260) { Text("Height") }
                Slider(value: $padding, in: 4...36) { Text("Padding") }
                Slider(value: $offsetX, in: -300...300) { Text("Horizontal offset") }
                Slider(value: $offsetY, in: -300...300) { Text("Vertical offset") }
            }

            Section("Content") {
                Toggle("Show icon", isOn: $showIcon)
                Toggle("Show label", isOn: $showLabel)
                Toggle("Show percentage", isOn: $showValue)
                Toggle("Show progress", isOn: $showProgress)
                if showProgress {
                    Picker("Progress style", selection: $progress) {
                        Text("Bar").tag("bar"); Text("Segments").tag("segments"); Text("Ring").tag("ring"); Text("None").tag("none")
                    }
                    if progress == "segments" { Stepper("Segments: \(segments)", value: $segments, in: 4...32) }
                }
                Slider(value: $iconSize, in: 12...56) { Text("Icon size") }
                Slider(value: $valueSize, in: 10...32) { Text("Text size") }
            }

            Section("Appearance") {
                Picker("Background", selection: $background) {
                    Text("Glass").tag("glass"); Text("Solid").tag("solid"); Text("Transparent").tag("clear")
                }.pickerStyle(.segmented)
                Slider(value: $opacity, in: 0...1) { Text("Background opacity") }
                Slider(value: $corner, in: 0...64) { Text("Corner radius") }
                Toggle("Shadow", isOn: $shadow)
                Toggle("Dynamic accent by level", isOn: $dynamicAccent)
                if !dynamicAccent {
                    Slider(value: $accentHue, in: 0...1) { Text("Accent hue") }
                    Slider(value: $saturation, in: 0...1) { Text("Accent saturation") }
                    Slider(value: $brightness, in: 0.25...1) { Text("Accent brightness") }
                }
            }

            Section("Behavior") {
                Slider(value: $timeout, in: 0.35...4) { Text("Dismiss delay") }
                Slider(value: $volumeStep, in: 0.01...0.25) { Text("Volume key step") }
                Slider(value: $brightnessStep, in: 0.01...0.25) { Text("Screen brightness key step") }
                Slider(value: $keyboardStep, in: 0.01...0.25) { Text("Keyboard brightness key step") }
                Text("Halo intercepts only controls it can actually write. If a replacement backend is unavailable, the hardware key is passed through to macOS and Halo can still show its customized observer HUD.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 650)
    }

    private func preview(_ kind: String) {
        NotificationCenter.default.post(name: .init("HaloHUDPreview"), object: nil, userInfo: ["kind": kind])
    }
}
