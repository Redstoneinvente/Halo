from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Anchor missing in {path}: {old[:120]!r}")
    file.write_text(text.replace(old, new, 1))


# App lifecycle: classify the process launch once, hand that immutable context to WindowManager,
# and mark a deliberate quit so a same-boot relaunch can be distinguished from a fresh manual launch.
replace_once(
    "Halo/App/HaloApp.swift",
    """        let manager = WindowManager(store: store)\n        engine = manager\n        manager.start()""",
    """        let activationContext = ActivationSequenceCoordinator.shared.classifyStartup()\n        let manager = WindowManager(store: store, startupActivationContext: activationContext)\n        engine = manager\n        manager.start()""",
)
replace_once(
    "Halo/App/HaloApp.swift",
    """    func applicationWillTerminate(_ notification: Notification) {\n        stopLicensedServices()""",
    """    func applicationWillTerminate(_ notification: Notification) {\n        ActivationSequenceCoordinator.shared.markQuit()\n        stopLicensedServices()""",
)

# Settings navigation and pane.
replace_once(
    "Halo/Views/WorkspaceSettingsView.swift",
    'private let sections = ["General", "Account & License", "Appearance", "Modules",',
    'private let sections = ["General", "Account & License", "Appearance", "Activation Sequence", "Modules",',
)
replace_once(
    "Halo/Views/WorkspaceSettingsView.swift",
    '        case "Appearance": return "paintpalette"\n        case "Modules": return "square.grid.2x2"',
    '        case "Appearance": return "paintpalette"\n        case "Activation Sequence": return "power.circle"\n        case "Modules": return "square.grid.2x2"',
)
replace_once(
    "Halo/Views/WorkspaceSettingsView.swift",
    '        case "Appearance": AppearanceSettingsPane(store: store, workspace: workspace)\n        case "Widgets": WidgetSettingsView(layout: $workspace.settings.layout)',
    '        case "Appearance": AppearanceSettingsPane(store: store, workspace: workspace)\n        case "Activation Sequence": ActivationSequenceSettingsPane()\n        case "Widgets": WidgetSettingsView(layout: $workspace.settings.layout)',
)

# SurfaceState carries the already-resolved current compact geometry knobs. The activation overlay
# reads these instead of inventing a fixed MacBook notch shape.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """    @Published var theme = Theme()\n    @Published var layoutOverride: WorkspaceLayout?""",
    """    @Published var theme = Theme()\n    @Published var activationSurfaceOptions = SurfaceOptions()\n    @Published var layoutOverride: WorkspaceLayout?""",
)

# Manager startup context and subscriptions.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """    private let store: AppStore\n    private var hosts: [String: Host] = [:]""",
    """    private let store: AppStore\n    private let startupActivationContext: ActivationLaunchContext\n    private var initialActivationPending = false\n    private var hosts: [String: Host] = [:]""",
)
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """    init(store: AppStore) { self.store = store }\n\n    func start() {""",
    """    init(store: AppStore,\n         startupActivationContext: ActivationLaunchContext = ActivationLaunchContext(event: .manualLaunch, macJustStarted: false)) {\n        self.store = store\n        self.startupActivationContext = startupActivationContext\n    }\n\n    func start() {""",
)
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)\n            .receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)""",
    """        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)\n            .receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)\n        NotificationCenter.default.publisher(for: .init(\"HaloPreviewActivationSequence\"))\n            .receive(on: RunLoop.main).sink { [weak self] _ in self?.previewActivation() }.store(in: &subscriptions)\n        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)\n            .receive(on: RunLoop.main).sink { [weak self] _ in\n                self?.playActivation(context: ActivationLaunchContext(event: .wake, macJustStarted: false))\n            }.store(in: &subscriptions)""",
)
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """        store.workspace.$activities.receive(on: DispatchQueue.main)\n            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)\n        reconcile()\n    }""",
    """        store.workspace.$activities.receive(on: DispatchQueue.main)\n            .sink { [weak self] _ in self?.refreshDynamicWidths() }.store(in: &subscriptions)\n\n        let shouldHideInitialFrame = ActivationSequenceCoordinator.shared.shouldPlay(startupActivationContext)\n        initialActivationPending = shouldHideInitialFrame\n        reconcile()\n        guard shouldHideInitialFrame else { return }\n        // Let SwiftUI mount at the already-final closed geometry while the panel is transparent.\n        // The presentation is then published before the panel becomes visible, avoiding a one-frame\n        // normal-notch flash on cold launch.\n        DispatchQueue.main.async { [weak self] in\n            guard let self else { return }\n            self.playActivation(context: self.startupActivationContext)\n            DispatchQueue.main.async { [weak self] in\n                guard let self else { return }\n                self.initialActivationPending = false\n                self.hosts.values.forEach { $0.panel.alphaValue = 1 }\n            }\n        }\n    }""",
)

# Current contour/corners must track the resolved per-display appearance.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()\n            let previousOffset = host.geometry?.offset(expanded: host.state.expanded) ?? .zero""",
    """            appearance.surface = (try? appearance.surface.validated()) ?? SurfaceOptions()\n            if host.state.activationSurfaceOptions != appearance.surface {\n                host.state.activationSurfaceOptions = appearance.surface\n            }\n            let previousOffset = host.geometry?.offset(expanded: host.state.expanded) ?? .zero""",
)

# Root overlay: it occupies the exact live panel bounds and never takes hit testing.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """                let root = HaloSurfaceRouter(viewport: host.state.viewport,\n                                             store: store,\n                                             state: host.state,\n                                             workspace: store.workspace)\n                    .environment(\\.haloScreenFrame, screen.frame)\n                let view = HaloDropHostingView(rootView: root)""",
    """                let root = ZStack {\n                    HaloSurfaceRouter(viewport: host.state.viewport,\n                                      store: store,\n                                      state: host.state,\n                                      workspace: store.workspace)\n                    ActivationSequenceOverlay(displayID: id, surfaceState: host.state)\n                }\n                .environment(\\.haloScreenFrame, screen.frame)\n                let view = HaloDropHostingView(rootView: root)""",
)

# Hide only the launch frame that will actually play a sequence.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """                host.panel.contentView = view\n                host.subscription = host.state.$expanded""",
    """                host.panel.contentView = view\n                if initialActivationPending { host.panel.alphaValue = 0 }\n                host.subscription = host.state.$expanded""",
)

# Immediate real user interaction cancels the flourish without delaying the requested interaction.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """                    guard let self, let host, let geometry = host.geometry else { return }\n                    if !expanded { host.state.contextPreferredSize = nil }""",
    """                    guard let self, let host, let geometry = host.geometry else { return }\n                    if expanded { ActivationSequenceCoordinator.shared.cancelForInteraction() }\n                    if !expanded { host.state.contextPreferredSize = nil }""",
)
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """                    if active && ciEnabled {\n                        host.state.beginFileDrop(count: count)""",
    """                    if active && ciEnabled {\n                        ActivationSequenceCoordinator.shared.cancelForInteraction()\n                        host.state.beginFileDrop(count: count)""",
)

# Add manager helpers just before reconcile(). Descriptors are built only from fully reconciled hosts,
# so no activation can run against stale or guessed display geometry.
replace_once(
    "Halo/NotchEngine/WindowManager.swift",
    """    private func reconcile() {\n        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))""",
    """    private func activationDisplays() -> [ActivationDisplayDescriptor] {\n        let mainID = NSScreen.main.map(Self.displayID)\n        return hosts.compactMap { id, host in\n            guard let geometry = host.geometry else { return nil }\n            let screen = NSScreen.screens.first(where: { Self.displayID($0) == id })\n            return ActivationDisplayDescriptor(\n                id: id,\n                screenFrame: geometry.screen,\n                hasNotch: geometry.safeAreaTop > 0 && geometry.physicalNotchWidth > 0,\n                isMain: id == mainID,\n                themeTint: host.state.theme.tint,\n                wallpaperURL: screen.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }\n            )\n        }\n    }\n\n    private func currentActivationSystemVolume() -> Float32? {\n        store.workspace.audio.refresh()\n        return store.workspace.audio.canSetVolume ? store.workspace.audio.volume : nil\n    }\n\n    private func playActivation(context: ActivationLaunchContext) {\n        let displays = activationDisplays()\n        guard !displays.isEmpty else { return }\n        ActivationSequenceCoordinator.shared.play(context: context, displays: displays, systemVolume: currentActivationSystemVolume())\n    }\n\n    private func previewActivation() {\n        let displays = activationDisplays()\n        guard !displays.isEmpty else { return }\n        ActivationSequenceCoordinator.shared.preview(displays: displays, systemVolume: currentActivationSystemVolume())\n    }\n\n    private func reconcile() {\n        let screens = store.configuration.allDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))""",
)

# Use the Motion control and particle speed in the renderer rather than merely storing them.
activation = Path("Halo/Views/ActivationSequence.swift")
text = activation.read_text()
text = text.replace(
    "let t = inward ? progress : (1 - progress)",
    "let paced = min(1, max(0, progress * settings.particleSpeed))\n                let t = inward ? paced : (1 - paced)",
)
text = text.replace(
    "let raw = timeline.date.timeIntervalSince(presentation.startDate) / duration\n                    let progress = min(1, max(0, raw))",
    "let raw = timeline.date.timeIntervalSince(presentation.startDate) / duration\n                    let progress = motionProgress(raw, profile: presentation.settings.motion)",
)
text = text.replace(
    "    private func smoothstep(_ value: Double) -> Double {\n        let x = min(1, max(0, value)); return x * x * (3 - 2 * x)\n    }",
    """    private func motionProgress(_ value: Double, profile: ActivationMotionProfile) -> Double {\n        let x = min(1, max(0, value))\n        switch profile {\n        case .calm:\n            return x * x * x * (x * (x * 6 - 15) + 10)\n        case .fluid:\n            return x * x * (3 - 2 * x)\n        case .snappy:\n            return min(1, 1 - pow(1 - x, 3))\n        }\n    }\n\n    private func smoothstep(_ value: Double) -> Double {\n        let x = min(1, max(0, value)); return x * x * (3 - 2 * x)\n    }""",
)
activation.write_text(text)

# Xcode project registration. IDs are intentionally outside Halo's existing hand-authored sequence.
project_path = Path("Halo.xcodeproj/project.pbxproj")
project = project_path.read_text()
build_id = "A11C0F1A0000000000000321"
file_id = "A11C0F1A0000000000000322"
if "Views/ActivationSequence.swift" not in project:
    build_anchor = "\t\tA11C0F1A0000000000000311 /* Views/VisualWorkspaceAdaptiveWidgets.swift in Sources */ = {isa = PBXBuildFile; fileRef = A11C0F1A0000000000000312 /* Views/VisualWorkspaceAdaptiveWidgets.swift */; };\n"
    if build_anchor not in project: raise SystemExit("PBX build anchor missing")
    project = project.replace(build_anchor, build_anchor + f"\t\t{build_id} /* Views/ActivationSequence.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* Views/ActivationSequence.swift */; }};\n", 1)

    ref_anchor = "\t\tA11C0F1A0000000000000312 /* Views/VisualWorkspaceAdaptiveWidgets.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/VisualWorkspaceAdaptiveWidgets.swift; sourceTree = \"<group>\"; };\n"
    if ref_anchor not in project: raise SystemExit("PBX file reference anchor missing")
    project = project.replace(ref_anchor, ref_anchor + f"\t\t{file_id} /* Views/ActivationSequence.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Views/ActivationSequence.swift; sourceTree = \"<group>\"; }};\n", 1)

    child_anchor = "\t\t\t\tA11C0F1A0000000000000312 /* Views/VisualWorkspaceAdaptiveWidgets.swift */,\n"
    if child_anchor not in project: raise SystemExit("PBX child anchor missing")
    project = project.replace(child_anchor, child_anchor + f"\t\t\t\t{file_id} /* Views/ActivationSequence.swift */,\n", 1)

    source_anchor = "\t\t\t\tA11C0F1A0000000000000311 /* Views/VisualWorkspaceAdaptiveWidgets.swift in Sources */,\n"
    if source_anchor not in project: raise SystemExit("PBX source phase anchor missing")
    project = project.replace(source_anchor, source_anchor + f"\t\t\t\t{build_id} /* Views/ActivationSequence.swift in Sources */,\n", 1)
    project_path.write_text(project)

print("Activation Sequence integration applied")
