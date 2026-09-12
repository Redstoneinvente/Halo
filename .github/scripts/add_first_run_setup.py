from pathlib import Path

path = Path('Halo/App/HaloApp.swift')
text = path.read_text()

# AppDelegate state
old = '''    private var hudSettings: NSWindow?\n    private var commercialBag = Set<AnyCancellable>()\n    private var licensedServicesStarted = false\n'''
new = '''    private var hudSettings: NSWindow?\n    private var setupWindow: NSWindow?\n    private var commercialBag = Set<AnyCancellable>()\n    private var licensedServicesStarted = false\n    private var setupShownThisLaunch = false\n    private let setupCompletedKey = "HaloSetupCompletedV1"\n    // Development switch: keep this true while we iterate on onboarding.\n    private let forceSetupEveryLaunch = true\n'''
if old not in text:
    raise SystemExit('AppDelegate state marker not found')
text = text.replace(old, new, 1)

old = '''    private func refreshCommercialAccess() {\n        if commercialAccessGranted {\n            startLicensedServices()\n        } else {\n            stopLicensedServices()\n        }\n    }\n\n    private func startLicensedServices() {\n'''
new = '''    private func refreshCommercialAccess() {\n        if commercialAccessGranted {\n            startLicensedServices()\n            presentSetupIfNeeded()\n        } else {\n            setupWindow?.orderOut(nil)\n            setupWindow = nil\n            setupShownThisLaunch = false\n            stopLicensedServices()\n        }\n    }\n\n    private func presentSetupIfNeeded() {\n        guard commercialAccessGranted, !setupShownThisLaunch else { return }\n        let completed = UserDefaults.standard.bool(forKey: setupCompletedKey)\n        guard forceSetupEveryLaunch || !completed else { return }\n        setupShownThisLaunch = true\n\n        let window = NSWindow(\n            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 720),\n            styleMask: [.titled, .closable, .miniaturizable, .resizable],\n            backing: .buffered,\n            defer: false\n        )\n        window.title = "Welcome to Halo"\n        window.titleVisibility = .hidden\n        window.titlebarAppearsTransparent = true\n        window.isMovableByWindowBackground = true\n        window.backgroundColor = .clear\n        window.contentMinSize = NSSize(width: 900, height: 640)\n        window.isReleasedWhenClosed = false\n        window.center()\n        window.contentView = NSHostingView(rootView: HaloFirstRunSetupView(store: store) { [weak self, weak window] in\n            guard let self else { return }\n            UserDefaults.standard.set(true, forKey: self.setupCompletedKey)\n            window?.close()\n            self.setupWindow = nil\n        })\n        setupWindow = window\n        NSApp.activate(ignoringOtherApps: true)\n        window.makeKeyAndOrderFront(nil)\n    }\n\n    private func startLicensedServices() {\n'''
if old not in text:
    raise SystemExit('refreshCommercialAccess marker not found')
text = text.replace(old, new, 1)

marker = '\n\nenum HaloHUDKeys {'
if marker not in text:
    raise SystemExit('HaloHUDKeys marker not found')

setup_code = r'''

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
'''

text = text.replace(marker, setup_code + marker, 1)
path.write_text(text)
print('Added first-run Halo setup experience')
