from pathlib import Path

app = Path('Halo/Core/AppStore.swift')
ext = Path('Halo/Core/ExtensionContracts.swift')

s = app.read_text()

anchor = '''@MainActor final class EIRoamModel: ObservableObject {
    @Published var right = true
    @Published var walking = false
}
'''
insert = '''@MainActor final class EIRoamModel: ObservableObject {
    @Published var right = true
    @Published var walking = false
}

@MainActor final class EINotchPeekModel: ObservableObject {
    @Published var motion: HaloCompanionMotion = .peekEyes
    @Published var notchWidth: CGFloat = 180
    @Published var notchHeight: CGFloat = 32
}
'''
if anchor not in s:
    raise SystemExit('EIRoamModel anchor not found')
s = s.replace(anchor, insert, 1)

anchor = '''    @MainActor private final class RoamHost {
        let panel: NSPanel
        let model: EIRoamModel
        var frame = CGRect.zero
        init() {
            model = EIRoamModel()
            panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            let view = NSHostingView(rootView: EIRoamingPetView(model: model))
            view.sizingOptions = []
            panel.contentView = view
        }
    }
'''
insert = anchor + '''
    @MainActor private final class PeekHost {
        let panel: NSPanel
        let model: EINotchPeekModel
        init() {
            model = EINotchPeekModel()
            panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.ignoresMouseEvents = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 4)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            let view = NSHostingView(rootView: EIPhysicalNotchPetPeek(model: model))
            view.sizingOptions = []
            panel.contentView = view
        }
    }
'''
if anchor not in s:
    raise SystemExit('RoamHost anchor not found')
s = s.replace(anchor, insert, 1)

old = '''    private var surfaces: [ObjectIdentifier: SurfaceSnapshot] = [:]
    private var roam: [String: RoamHost] = [:]
'''
new = '''    private var surfaces: [ObjectIdentifier: SurfaceSnapshot] = [:]
    private var roam: [String: RoamHost] = [:]
    private var peekHosts: [String: PeekHost] = [:]
'''
if old not in s:
    raise SystemExit('host storage anchor not found')
s = s.replace(old, new, 1)

old = '''                    self?.hotkeyUpdate()
                    self?.refreshPlacements()
                    self?.roaming(true)
'''
new = '''                    self?.hotkeyUpdate()
                    self?.refreshPlacements()
                    self?.roaming(true)
                    self?.refreshNotchPeek()
'''
if old not in s:
    raise SystemExit('preferences sink anchor not found')
s = s.replace(old, new, 1)

old = '''                    if settings.mode == .off, self.requested { self.closeNow() }
                    self.refreshPlacements()
                    self.roaming(true)
'''
new = '''                    if settings.mode == .off, self.requested { self.closeNow() }
                    self.refreshPlacements()
                    self.roaming(true)
                    self.refreshNotchPeek()
'''
if old not in s:
    raise SystemExit('settings sink anchor not found')
s = s.replace(old, new, 1)

old = '''        hotkeyUpdate()
        refreshPlacements()
        roaming(false)
'''
new = '''        hotkeyUpdate()
        refreshPlacements()
        roaming(false)
        refreshNotchPeek()
'''
if old not in s:
    raise SystemExit('start tail anchor not found')
s = s.replace(old, new, 1)

old = '''        refreshPlacements()
        roaming(false)
    }

    private func closeNow() {
'''
new = '''        refreshPlacements()
        roaming(false)
        refreshNotchPeek()
    }

    private func closeNow() {
'''
if old not in s:
    raise SystemExit('openNow tail anchor not found')
s = s.replace(old, new, 1)

old = '''        refreshPlacements()
        roaming(true)
        if shouldCollapse {
'''
new = '''        refreshPlacements()
        roaming(true)
        refreshNotchPeek()
        if shouldCollapse {
'''
if old not in s:
    raise SystemExit('closeNow tail anchor not found')
s = s.replace(old, new, 1)

old = '''    private func deferRefresh(animatedRoaming: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshPlacements()
            self?.roaming(animatedRoaming)
        }
    }
'''
new = '''    private func deferRefresh(animatedRoaming: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshPlacements()
            self?.roaming(animatedRoaming)
            self?.refreshNotchPeek()
        }
    }
'''
if old not in s:
    raise SystemExit('deferRefresh anchor not found')
s = s.replace(old, new, 1)

old = '''        publishPlacement(for: snapshot)
        roaming(false)
    }

    private func refreshPlacements() {
'''
new = '''        publishPlacement(for: snapshot)
        roaming(false)
        refreshNotchPeek()
    }

    private func refreshPlacements() {
'''
if old not in s:
    raise SystemExit('geometry tail anchor not found')
s = s.replace(old, new, 1)

anchor = '''    private func roaming(_ animated: Bool) {
'''
helper = '''    private func activePeekMotion() -> HaloCompanionMotion? {
        let settings = EISettingsStore.shared.settings
        let engine = EnvironmentalInterfaceEngine.shared
        guard settings.mode == .pet, engine.shouldRender,
              let kind = engine.currentReaction?.kind else { return nil }
        switch kind {
        case .petPeekEyes: return .peekEyes
        case .petPeekEars: return .peekEars
        case .petPeekUnder: return .peek
        case .petPeekLeft: return .peekLeft
        case .petPeekRight: return .peekRight
        case .petPawFirst: return .paw
        case .petTailFirst: return .tail
        default: return nil
        }
    }

    private func targetPeekScreen() -> NSScreen? {
        let notched = NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }
        guard !notched.isEmpty else { return nil }

        if requested {
            let ordered = surfaces.values.sorted { lhs, rhs in lhs.frame.height > rhs.frame.height }
            for snapshot in ordered where !snapshot.screenID.isEmpty {
                if let screen = notched.first(where: { WindowManager.displayID($0) == snapshot.screenID }) {
                    return screen
                }
            }
        }
        if let main = NSScreen.main, main.safeAreaInsets.top > 0 { return main }
        return notched.first
    }

    private func notchGeometry(for screen: NSScreen) -> CGSize {
        let height = max(22, screen.safeAreaInsets.top)
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX {
            return CGSize(width: max(92, right.minX - left.maxX), height: height)
        }
        return CGSize(width: 180, height: height)
    }

    private func refreshNotchPeek() {
        guard let motion = activePeekMotion(), let screen = targetPeekScreen() else {
            peekHosts.values.forEach { $0.panel.orderOut(nil) }
            return
        }

        let id = WindowManager.displayID(screen)
        let host = peekHosts[id] ?? PeekHost()
        peekHosts[id] = host
        let notch = notchGeometry(for: screen)
        if host.model.motion != motion { host.model.motion = motion }
        if abs(host.model.notchWidth - notch.width) > 0.5 { host.model.notchWidth = notch.width }
        if abs(host.model.notchHeight - notch.height) > 0.5 { host.model.notchHeight = notch.height }

        let zoom = min(1.6, max(0.7, CGFloat(EISettingsStore.shared.settings.petScale)))
        let spriteSize = min(168, max(116, notch.width * 0.78)) * zoom
        let width = max(360, notch.width + spriteSize * 1.55)
        let height = max(150, notch.height + spriteSize * 0.88)
        let frame = CGRect(x: screen.frame.midX - width / 2,
                           y: screen.frame.maxY - height,
                           width: width,
                           height: height)
        if host.panel.frame != frame { host.panel.setFrame(frame, display: false) }

        for (otherID, other) in peekHosts where otherID != id { other.panel.orderOut(nil) }
        host.panel.orderFrontRegardless()
    }

'''
if anchor not in s:
    raise SystemExit('roaming anchor not found')
s = s.replace(anchor, helper + anchor, 1)

app.write_text(s)

s = ext.read_text()

# Remove the in-Halo physical peek renderer entirely. It can never escape the Halo NSPanel.
start = s.find('''    private var physicalNotchPeekMotion: HaloCompanionMotion? {\n''')
body = s.find('''    var body: some View {\n''', start)
if start == -1 or body == -1:
    raise SystemExit('router physicalNotchPeekMotion block not found')
s = s[:start] + s[body:]

old = '''
                // Physical-notch peeks must not be children of EIOpenSurface: that surface is clipped
                // to Halo's contour. Render the pet above the owned surface so only the real hardware
                // notch/reveal window occludes it, making it genuinely emerge from the camera housing.
                if let peekMotion = physicalNotchPeekMotion {
                    EIPhysicalNotchPetPeek(surfaceState: state, motion: peekMotion)
                        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                        .zIndex(50)
                }
'''
if old not in s:
    raise SystemExit('router physical renderer block not found')
s = s.replace(old, '\n', 1)

# Only suppress the room pet for a physical-notch reaction if this Mac actually has a notch.
old = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard let kind = engine.currentReaction?.kind else { return nil }
'''
new = '''    private var physicalNotchPeekMotion: HaloCompanionMotion? {
        guard NSScreen.screens.contains(where: { $0.safeAreaInsets.top > 0 }),
              let kind = engine.currentReaction?.kind else { return nil }
'''
if old not in s:
    raise SystemExit('EIOpenSurface physical motion block not found')
s = s.replace(old, new, 1)

# Replace the old SurfaceState-bound view with a screen-overlay model view.
old_start = s.find('''@MainActor\nprivate struct EIPhysicalNotchPetPeek: View {\n''')
old_end = s.find('''\n@MainActor\nstruct EIRoamingPetView: View {\n''', old_start)
if old_start == -1 or old_end == -1:
    raise SystemExit('old physical notch view not found')
new_view = '''@MainActor
struct EIPhysicalNotchPetPeek: View {
    @ObservedObject var model: EINotchPeekModel
    @ObservedObject private var preferences = EIOpenPreferencesStore.shared
    @ObservedObject private var settings = EISettingsStore.shared

    var body: some View {
        GeometryReader { proxy in
            let notchWidth = max(92, model.notchWidth)
            let notchHeight = max(22, model.notchHeight)
            let zoom = min(1.6, max(0.7, CGFloat(settings.settings.petScale)))
            let spriteSize = min(168, max(116, notchWidth * 0.78)) * zoom
            let centerX = horizontalCenter(in: proxy.size, notchWidth: notchWidth, spriteSize: spriteSize)
            let centerY = verticalCenter(notchHeight: notchHeight, spriteSize: spriteSize)

            HaloCompanionSprite(kind: settings.settings.petKind,
                                style: preferences.value.petVisual == .pixel ? .smooth : preferences.value.petVisual,
                                size: spriteSize,
                                primary: settings.settings.petPrimaryColor.color,
                                accent: settings.settings.petAccentColor.color,
                                motion: model.motion,
                                facingRight: model.motion != .peekRight)
                .position(x: centerX, y: centerY)
                .mask {
                    revealMask(size: proxy.size,
                               notchWidth: notchWidth,
                               notchHeight: notchHeight,
                               spriteSize: spriteSize)
                }
                .shadow(color: .black.opacity(0.20), radius: 4, y: 2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func horizontalCenter(in size: CGSize, notchWidth: CGFloat, spriteSize: CGFloat) -> CGFloat {
        let notchLeft = size.width / 2 - notchWidth / 2
        let notchRight = size.width / 2 + notchWidth / 2
        switch model.motion {
        case .peekLeft:
            return notchLeft - spriteSize * 0.16
        case .peekRight:
            return notchRight + spriteSize * 0.16
        case .tail:
            return size.width / 2 + notchWidth * 0.20
        default:
            return size.width / 2
        }
    }

    private func verticalCenter(notchHeight: CGFloat, spriteSize: CGFloat) -> CGFloat {
        switch model.motion {
        case .peekEyes: return notchHeight + spriteSize * 0.05
        case .peekEars: return notchHeight + spriteSize * 0.08
        case .peek: return notchHeight + spriteSize * 0.16
        case .paw: return notchHeight + spriteSize * 0.19
        case .tail: return notchHeight + spriteSize * 0.12
        case .peekLeft, .peekRight: return notchHeight + spriteSize * 0.09
        default: return notchHeight + spriteSize * 0.14
        }
    }

    private func centralRevealSize(notchWidth: CGFloat, spriteSize: CGFloat) -> CGSize {
        switch model.motion {
        case .peekEyes:
            return CGSize(width: min(notchWidth * 0.80, spriteSize * 0.86), height: spriteSize * 0.24)
        case .peekEars:
            return CGSize(width: min(notchWidth * 0.88, spriteSize * 0.94), height: spriteSize * 0.31)
        case .peek:
            return CGSize(width: min(notchWidth, spriteSize), height: spriteSize * 0.50)
        case .paw:
            return CGSize(width: min(notchWidth * 1.04, spriteSize), height: spriteSize * 0.52)
        case .tail:
            return CGSize(width: min(notchWidth * 0.90, spriteSize * 0.94), height: spriteSize * 0.38)
        default:
            return CGSize(width: min(notchWidth * 0.94, spriteSize), height: spriteSize * 0.42)
        }
    }

    @ViewBuilder
    private func revealMask(size: CGSize, notchWidth: CGFloat, notchHeight: CGFloat, spriteSize: CGFloat) -> some View {
        let notchLeft = size.width / 2 - notchWidth / 2
        let notchRight = size.width / 2 + notchWidth / 2
        switch model.motion {
        case .peekLeft:
            Rectangle()
                .frame(width: spriteSize * 0.68, height: spriteSize * 0.76)
                .position(x: notchLeft - spriteSize * 0.24,
                          y: notchHeight + spriteSize * 0.18)
        case .peekRight:
            Rectangle()
                .frame(width: spriteSize * 0.68, height: spriteSize * 0.76)
                .position(x: notchRight + spriteSize * 0.24,
                          y: notchHeight + spriteSize * 0.18)
        default:
            let reveal = centralRevealSize(notchWidth: notchWidth, spriteSize: spriteSize)
            Rectangle()
                .frame(width: reveal.width, height: reveal.height)
                .position(x: size.width / 2,
                          y: notchHeight + reveal.height / 2)
        }
    }
}
'''
s = s[:old_start] + new_view + s[old_end:]
ext.write_text(s)

print('Moved physical notch peeks into a dedicated transparent screen overlay panel')
