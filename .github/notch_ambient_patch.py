from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Expected block not found in {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, 1))

# -----------------------------------------------------------------------------
# DecorationsView: append the modular Notch Ambient subsystem to an existing
# compiled source file so no fragile pbxproj source-phase surgery is needed.
# -----------------------------------------------------------------------------
payload = Path('/tmp/notch_ambient_payload.swift').read_text()
# Small correctness refinements before the payload is committed to main.
payload = payload.replace('''        next.presetID = "custom"\n        settings = next.normalized()\n''', '''        settings = next.normalized()\n''', 1)
payload = payload.replace('''        next.enabled = wasEnabled || preset.settings.enabled\n''', '''        next.enabled = wasEnabled\n''', 1)
payload = payload.replace('''        savedPresets.append(preset)\n        return preset\n''', '''        savedPresets.append(preset)\n        settings = value\n        return preset\n''', 1)
payload = payload.replace('''    private var screenFrame: CGRect { state.screenFrame }\n''', '''    private var screenFrame: CGRect { state.screenFrame }\n''')
# The branch payload originally used the existing screen-frame Environment value;
# runtime geometry is more robust when it follows the host's published frame.
payload = payload.replace('''    @Environment(\\.haloScreenFrame) private var screenFrame\n    @Environment(\\.accessibilityReduceMotion) private var reduceMotion\n''', '''    @Environment(\\.accessibilityReduceMotion) private var reduceMotion\n''', 1)
payload = payload.replace('''    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }\n''', '''    private var screenFrame: CGRect { state.screenFrame }\n    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }\n''', 1)
# Rotation is event-driven: no minute timer exists while rotation is off.
payload = payload.replace('''        .task(id: workspace.activities.map { $0.id }) {\n''', '''        .task(id: ambient.settings.rotationMode) {\n            let mode = ambient.settings.rotationMode\n            guard mode != .off && mode != .everySession else { return }\n            while !Task.isCancelled {\n                let interval: TimeInterval\n                switch mode {\n                case .random: interval = 30 * 60\n                case .everyHour: interval = 60 * 60\n                case .daily: interval = 6 * 60 * 60\n                case .timeOfDay: interval = 5 * 60\n                default: interval = 60 * 60\n                }\n                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))\n                guard !Task.isCancelled else { return }\n                activityClock = Date()\n            }\n        }\n        .task(id: workspace.activities.map { $0.id }) {\n''', 1)
# Time-based appearance changes ambience even when a custom palette is selected.
payload = payload.replace('''        let intensity = effectiveIntensity(s, audio: audio, lowPower: lowPower)\n''', '''        let hour = Calendar.autoupdatingCurrent.component(.hour, from: date)\n        let timeFactor = s.timeBasedAppearance ? (hour < 6 ? 0.68 : hour < 12 ? 1.08 : hour < 18 ? 1.0 : 0.82) : 1.0\n        let intensity = min(1, effectiveIntensity(s, audio: audio, lowPower: lowPower) * timeFactor)\n''', 1)
# Automatic portal styles get genuinely different palettes rather than a cosmetic picker.
payload = payload.replace('''        case .automatic: return defaults(for: settings.decoration)\n''', '''        case .automatic:\n            if settings.decoration == .portal {\n                switch settings.portalStyle {\n                case .space: return [Color(red:0.30,green:0.52,blue:1), Color(red:0.12,green:0.18,blue:0.48), .white]\n                case .nebula: return [Color(red:0.68,green:0.30,blue:1), Color(red:0.20,green:0.82,blue:1), Color(red:1,green:0.34,blue:0.72)]\n                case .cyber: return [Color(red:0.08,green:0.94,blue:1), Color(red:1,green:0.12,blue:0.74), .white]\n                case .fire: return [Color(red:1,green:0.52,blue:0.12), Color(red:1,green:0.12,blue:0.06), Color.yellow]\n                case .ice: return [Color(red:0.58,green:0.88,blue:1), Color(red:0.18,green:0.48,blue:1), .white]\n                case .void: return [Color(red:0.34,green:0.20,blue:0.58), Color(red:0.08,green:0.06,blue:0.14), Color(red:0.72,green:0.58,blue:1)]\n                case .fantasy: return [Color(red:0.36,green:1,blue:0.66), Color(red:0.76,green:0.32,blue:1), Color(red:1,green:0.78,blue:0.30)]\n                }\n            }\n            return defaults(for: settings.decoration)\n''', 1)

p = Path('Halo/Views/DecorationsView.swift')
text = p.read_text()
if 'import Combine\n' not in text:
    text = text.replace('import QuartzCore\n', 'import QuartzCore\nimport Combine\n', 1)
if '// MARK: - Notch Ambient' in text:
    raise SystemExit('Notch Ambient already exists in DecorationsView.swift')
p.write_text(text.rstrip() + '\n' + payload.rstrip() + '\n')

# -----------------------------------------------------------------------------
# Dedicated Settings destination.
# -----------------------------------------------------------------------------
path = 'Halo/Views/WorkspaceSettingsView.swift'
replace_once(path,
'''    private let sections = ["General", "Account & License", "Appearance", "Modules", "Widgets", "Closed notch", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "About"]\n''',
'''    private let sections = ["General", "Account & License", "Appearance", "Modules", "Widgets", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "About"]\n''')
replace_once(path,
'''        case "Closed notch": return "rectangle.topthird.inset.filled"\n        case "Media & Files": return "play.rectangle"\n''',
'''        case "Closed notch": return "rectangle.topthird.inset.filled"\n        case "Notch Ambient": return "sparkles"\n        case "Media & Files": return "play.rectangle"\n''')
replace_once(path,
'''        case "Closed notch": ClosedNotchSettingsView(layout: $workspace.settings.layout, media: workspace.media, app: workspace.settings.mediaApp)\n        case "HUD": HaloHUDWorkspaceSettingsView(layout: $workspace.settings.layout, profileNames: workspace.settings.profiles.map(\\.name))\n''',
'''        case "Closed notch": ClosedNotchSettingsView(layout: $workspace.settings.layout, media: workspace.media, app: workspace.settings.mediaApp)\n        case "Notch Ambient": NotchAmbientSettingsView(store: store, workspace: workspace)\n        case "HUD": HaloHUDWorkspaceSettingsView(layout: $workspace.settings.layout, profileNames: workspace.settings.profiles.map(\\.name))\n''')

# -----------------------------------------------------------------------------
# Window manager: a separate click-through ambient layer keeps decoration extent
# independent from Halo's interactive closed-notch hit target.
# -----------------------------------------------------------------------------
path = 'Halo/NotchEngine/WindowManager.swift'
replace_once(path,
'''    @Published var compactHeight: CGFloat = 40\n    @Published var theme = Theme()\n''',
'''    @Published var compactHeight: CGFloat = 40\n    @Published var physicalNotchWidth: CGFloat = 190\n    @Published var physicalNotchHeight: CGFloat = 32\n    @Published var screenFrame: CGRect = .zero\n    @Published var theme = Theme()\n''')
replace_once(path,
'''    @MainActor private final class Host {\n        let panel: HaloPanel\n        let state = SurfaceState()\n        let animator = SurfaceAnimator()\n        var geometry: SurfaceGeometry?\n        var targetFrame: CGRect?\n        var subscription: AnyCancellable?\n        var contextSizeSubscription: AnyCancellable?\n        init() {\n            panel = HaloPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)\n            panel.isReleasedWhenClosed = false\n            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true\n            panel.hidesOnDeactivate = false; panel.level = .statusBar\n            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]\n        }\n        func stop() {\n            animator.cancel(); state.collapseTask?.cancel(); state.dropExitTask?.cancel()\n            subscription?.cancel(); contextSizeSubscription?.cancel(); panel.close()\n        }\n    }\n''',
'''    @MainActor private final class Host {\n        let panel: HaloPanel\n        let ambientPanel: NSPanel\n        let state = SurfaceState()\n        let animator = SurfaceAnimator()\n        var geometry: SurfaceGeometry?\n        var targetFrame: CGRect?\n        var subscription: AnyCancellable?\n        var contextSizeSubscription: AnyCancellable?\n        init() {\n            panel = HaloPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)\n            panel.isReleasedWhenClosed = false\n            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true\n            panel.hidesOnDeactivate = false; panel.level = .statusBar\n            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]\n\n            ambientPanel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)\n            ambientPanel.isReleasedWhenClosed = false\n            ambientPanel.backgroundColor = .clear; ambientPanel.isOpaque = false; ambientPanel.hasShadow = false\n            ambientPanel.hidesOnDeactivate = false; ambientPanel.level = .statusBar\n            ambientPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]\n            ambientPanel.ignoresMouseEvents = true\n            ambientPanel.acceptsMouseMovedEvents = false\n            ambientPanel.animationBehavior = .none\n        }\n        func stop() {\n            animator.cancel(); state.collapseTask?.cancel(); state.dropExitTask?.cancel()\n            subscription?.cancel(); contextSizeSubscription?.cancel(); panel.close(); ambientPanel.close()\n        }\n    }\n''')
replace_once(path,
'''        store.$configuration.dropFirst().receive(on: DispatchQueue.main)\n            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)\n''',
'''        store.$configuration.dropFirst().receive(on: DispatchQueue.main)\n            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)\n        NotchAmbientStore.shared.$settings.dropFirst().removeDuplicates()\n            .debounce(for: .milliseconds(45), scheduler: RunLoop.main)\n            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)\n''')
# Keep the ambient panel geometry current when closed-notch dynamic sizing settles.
replace_once(path,
'''            guard let geometry = host.geometry else { continue }\n            let newWidth = geometry.compactWidth\n''',
'''            guard let geometry = host.geometry else { continue }\n            updateAmbientPanelFrame(host: host, geometry: geometry)\n            let newWidth = geometry.compactWidth\n''')
# Add ambient geometry helpers immediately before reconcile.
replace_once(path,
'''    private func reconcile() {\n''',
'''    private func notchAmbientFrame(for geometry: SurfaceGeometry) -> CGRect {\n        let settings = NotchAmbientStore.shared.settings.normalized()\n        let closed = geometry.frame(expanded: false)\n        let notchWidth = geometry.physicalNotchWidth > 0 ? geometry.physicalNotchWidth : min(190, closed.width)\n        let notchHeight = geometry.safeAreaTop > 0 ? geometry.safeAreaTop : min(34, closed.height)\n        let width = min(geometry.screen.width, max(320, notchWidth + settings.horizontalExtent * 2))\n        let height = min(geometry.screen.height, max(100, notchHeight + settings.verticalExtent))\n        let top = min(geometry.screen.maxY, closed.maxY)\n        var x = closed.midX - width / 2\n        x = min(max(geometry.screen.minX, x), geometry.screen.maxX - width)\n        let y = max(geometry.screen.minY, top - height)\n        return CGRect(x: x, y: y, width: width, height: min(height, top - y))\n    }\n\n    private func updateAmbientPanelFrame(host: Host, geometry: SurfaceGeometry) {\n        let frame = notchAmbientFrame(for: geometry)\n        if host.ambientPanel.frame != frame { host.ambientPanel.setFrame(frame, display: false) }\n    }\n\n    private func reconcile() {\n''')
# Publish geometry used by the click-through renderer and size the ambient panel.
replace_once(path,
'''            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)\n            if host.state.theme != theme { host.state.theme = theme }\n''',
'''            host.geometry = Self.geometry(screen: screen, theme: theme, appearance: appearance)\n            if host.state.screenFrame != screen.frame { host.state.screenFrame = screen.frame }\n            let ambientPhysicalWidth = host.geometry!.physicalNotchWidth > 0 ? host.geometry!.physicalNotchWidth : min(190, host.geometry!.compactWidth)\n            let ambientPhysicalHeight = host.geometry!.safeAreaTop > 0 ? host.geometry!.safeAreaTop : min(34, host.geometry!.compactHeight)\n            if host.state.physicalNotchWidth != ambientPhysicalWidth { host.state.physicalNotchWidth = ambientPhysicalWidth }\n            if host.state.physicalNotchHeight != ambientPhysicalHeight { host.state.physicalNotchHeight = ambientPhysicalHeight }\n            updateAmbientPanelFrame(host: host, geometry: host.geometry!)\n            if host.state.theme != theme { host.state.theme = theme }\n''')
# Initialize ambient host beside the normal interactive host.
replace_once(path,
'''            if existing == nil {\n                let root = HaloSurfaceRouter(viewport: host.state.viewport,\n''',
'''            if existing == nil {\n                let ambientRoot = NotchAmbientOverlayView(store: store, state: host.state, workspace: store.workspace)\n                let ambientView = NSHostingView(rootView: ambientRoot)\n                ambientView.sizingOptions = []\n                host.ambientPanel.contentView = ambientView\n                updateAmbientPanelFrame(host: host, geometry: host.geometry!)\n\n                let root = HaloSurfaceRouter(viewport: host.state.viewport,\n''')
replace_once(path,
'''                host.panel.orderFrontRegardless()\n                hosts[id] = host\n''',
'''                // Ambient is ordered first and is mouse-pass-through; the normal Halo panel\n                // remains the interactive/top owner of the notch.\n                host.ambientPanel.orderFrontRegardless()\n                host.panel.orderFrontRegardless()\n                host.ambientPanel.order(.below, relativeTo: host.panel.windowNumber)\n                hosts[id] = host\n''')

print('Notch Ambient source integration applied')
