import AppKit
import Combine
import QuartzCore
import SwiftUI

// MARK: - Notch Bubble models

enum NotchBubbleKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case music
    case pixelPal
    case timer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .pixelPal: return "Pixel Pal"
        case .timer: return "Timer"
        }
    }

    var symbol: String {
        switch self {
        case .music: return "music.note"
        case .pixelPal: return "face.smiling"
        case .timer: return "timer"
        }
    }
}

enum NotchBubblePlacement: String, Codable, CaseIterable, Hashable {
    case automatic
    case bottomLeading
    case bottom
    case bottomTrailing
    case leading
    case trailing
}

enum NotchBubbleShape: String, Codable, CaseIterable, Identifiable, Hashable {
    case circle = "Circle"
    case capsule = "Capsule"
    case roundedSquare = "Square"
    case glass = "Glass"

    var id: String { rawValue }
}

enum NotchBubbleLayout: String, Codable, CaseIterable, Identifiable, Hashable {
    case satellites = "Satellites"
    case wings = "Wings"
    case stack = "Stack"

    var id: String { rawValue }
}

enum NotchBubblePriority: Int, Codable, Comparable {
    case background = 0
    case normal = 1
    case important = 2
    case urgent = 3

    static func < (lhs: NotchBubblePriority, rhs: NotchBubblePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum NotchBubbleAnimationPreset: String, Codable, CaseIterable, Identifiable, Hashable {
    case soft = "Soft"
    case fluid = "Fluid"
    case snappy = "Snappy"
    case bouncy = "Bouncy"
    case none = "None"

    var id: String { rawValue }
}

struct NotchBubble: Identifiable, Equatable {
    var id: String { kind.rawValue }

    let kind: NotchBubbleKind
    var placement: NotchBubblePlacement = .automatic
    var size: CGFloat
    var shape: NotchBubbleShape
    var isPersistent: Bool
    var timeout: TimeInterval?
    var priority: NotchBubblePriority
}

struct NotchBubbleSettings: Codable, Equatable {
    var version = 1
    var enabled = false

    var layout: NotchBubbleLayout = .satellites
    var spacing = 10.0
    var bubbleSize = 42.0
    var shape: NotchBubbleShape = .glass
    var cornerRadius = 18.0
    var glassIntensity = 0.82
    var animation: NotchBubbleAnimationPreset = .fluid
    var maximumBubbles = 3

    var showWhenClosed = true
    var showWhenOpen = true

    var musicEnabled = true
    var musicPersistent = false
    var timerEnabled = true
    var timerPersistent = false
    var pixelPalEnabled = true
    var pixelPalPersistent = true

    func normalized() -> Self {
        var value = self
        value.version = 1
        value.spacing = min(40, max(0, spacing.isFinite ? spacing : 10))
        value.bubbleSize = min(72, max(24, bubbleSize.isFinite ? bubbleSize : 42))
        value.cornerRadius = min(36, max(0, cornerRadius.isFinite ? cornerRadius : 18))
        value.glassIntensity = min(1, max(0.15, glassIntensity.isFinite ? glassIntensity : 0.82))
        value.maximumBubbles = min(99, max(1, maximumBubbles))
        return value
    }
}

@MainActor
final class NotchBubbleSettingsStore: ObservableObject {
    static let shared = NotchBubbleSettingsStore()

    @Published var settings: NotchBubbleSettings {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let key = "HaloNotchBubbles.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(NotchBubbleSettings.self, from: data) {
            settings = decoded.normalized()
        } else {
            settings = NotchBubbleSettings()
        }
    }

    func reset() {
        settings = NotchBubbleSettings()
    }

    private func persist() {
        let normalized = settings.normalized()
        if normalized != settings {
            settings = normalized
            return
        }
        if let data = try? JSONEncoder().encode(normalized) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Providers and registry

@MainActor
protocol BubbleProvider {
    var kind: NotchBubbleKind { get }
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble?
}

@MainActor
private struct MusicBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .music

    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        guard settings.musicEnabled,
              settings.musicPersistent || store.workspace.media.isPlaying else { return nil }
        return NotchBubble(
            kind: kind,
            size: CGFloat(settings.bubbleSize),
            shape: settings.shape,
            isPersistent: settings.musicPersistent,
            timeout: nil,
            priority: .normal
        )
    }
}

@MainActor
private struct PixelPalBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .pixelPal

    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        let contextual = HaloPixelPalStore.shared.reaction != nil ||
            store.workspace.media.isPlaying ||
            store.deadline != nil ||
            store.pausedSeconds > 0 ||
            store.finished
        guard settings.pixelPalEnabled,
              settings.pixelPalPersistent || contextual else { return nil }
        return NotchBubble(
            kind: kind,
            size: CGFloat(settings.bubbleSize),
            shape: settings.shape,
            isPersistent: settings.pixelPalPersistent,
            timeout: nil,
            priority: .background
        )
    }
}

@MainActor
private struct TimerBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .timer

    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        let active = store.deadline != nil || store.pausedSeconds > 0 || store.finished
        guard settings.timerEnabled, settings.timerPersistent || active else { return nil }
        return NotchBubble(
            kind: kind,
            size: CGFloat(settings.bubbleSize),
            shape: settings.shape,
            isPersistent: settings.timerPersistent,
            timeout: nil,
            priority: store.finished ? .urgent : (active ? .important : .normal)
        )
    }
}

@MainActor
struct BubbleRegistry {
    private let providers: [any BubbleProvider] = [
        MusicBubbleProvider(),
        PixelPalBubbleProvider(),
        TimerBubbleProvider()
    ]

    func bubbles(store: AppStore, settings: NotchBubbleSettings) -> [NotchBubble] {
        let candidates = providers.compactMap { $0.bubble(store: store, settings: settings) }
        let maximum = settings.maximumBubbles
        guard candidates.count > maximum else { return candidates }

        let selected = Set(
            candidates
                .sorted {
                    if $0.priority != $1.priority { return $0.priority > $1.priority }
                    return providerOrder($0.kind) < providerOrder($1.kind)
                }
                .prefix(maximum)
                .map(\.kind)
        )
        return candidates.filter { selected.contains($0.kind) }
    }

    private func providerOrder(_ kind: NotchBubbleKind) -> Int {
        switch kind {
        case .music: return 0
        case .pixelPal: return 1
        case .timer: return 2
        }
    }
}

// MARK: - Layout

struct BubbleLayoutEngine {
    func frames(
        for bubbles: [NotchBubble],
        around surfaceFrame: CGRect,
        in screenFrame: CGRect,
        settings: NotchBubbleSettings
    ) -> [NotchBubbleKind: CGRect] {
        guard !bubbles.isEmpty else { return [:] }

        let size = CGFloat(settings.bubbleSize)
        let spacing = CGFloat(settings.spacing)
        let gap = max(5, spacing)
        var result: [NotchBubbleKind: CGRect] = [:]

        switch settings.layout {
        case .satellites:
            let total = CGFloat(bubbles.count) * size + CGFloat(max(0, bubbles.count - 1)) * spacing
            let startX = surfaceFrame.midX - total / 2
            let y = surfaceFrame.minY - gap - size
            for (index, bubble) in bubbles.enumerated() {
                let frame = CGRect(
                    x: startX + CGFloat(index) * (size + spacing),
                    y: y,
                    width: size,
                    height: size
                )
                result[bubble.kind] = clamped(frame, to: screenFrame)
            }

        case .wings:
            let y = surfaceFrame.midY - size / 2
            var leftCount = 0
            var rightCount = 0
            for (index, bubble) in bubbles.enumerated() {
                let isLeft = index.isMultiple(of: 2)
                let frame: CGRect
                if isLeft {
                    let x = surfaceFrame.minX - gap - size - CGFloat(leftCount) * (size + spacing)
                    frame = CGRect(x: x, y: y, width: size, height: size)
                    leftCount += 1
                } else {
                    let x = surfaceFrame.maxX + gap + CGFloat(rightCount) * (size + spacing)
                    frame = CGRect(x: x, y: y, width: size, height: size)
                    rightCount += 1
                }
                result[bubble.kind] = clamped(frame, to: screenFrame)
            }

        case .stack:
            for (index, bubble) in bubbles.enumerated() {
                let frame = CGRect(
                    x: surfaceFrame.midX - size / 2,
                    y: surfaceFrame.minY - gap - size - CGFloat(index) * (size + spacing),
                    width: size,
                    height: size
                )
                result[bubble.kind] = clamped(frame, to: screenFrame)
            }
        }

        return result
    }

    private func clamped(_ frame: CGRect, to screen: CGRect) -> CGRect {
        let margin: CGFloat = 4
        var value = frame
        value.origin.x = min(max(screen.minX + margin, value.minX), screen.maxX - margin - value.width)
        value.origin.y = min(max(screen.minY + margin, value.minY), screen.maxY - margin - value.height)
        return value
    }
}

// MARK: - Window and animation

private final class NotchBubblePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
enum BubbleAnimationController {
    static func move(
        panel: NSPanel,
        to frame: CGRect,
        preset: NotchBubbleAnimationPreset,
        animated: Bool
    ) {
        guard panel.frame != frame else { return }
        guard animated,
              preset != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(frame, display: false)
            return
        }

        let duration: TimeInterval
        switch preset {
        case .soft: duration = 0.28
        case .fluid: duration = 0.22
        case .snappy: duration = 0.13
        case .bouncy: duration = 0.30
        case .none: duration = 0
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(
                name: preset == .snappy ? .easeOut : .easeInEaseOut
            )
            panel.animator().setFrame(frame, display: false)
        }
    }

    static func show(panel: NSPanel, animated: Bool) {
        guard !panel.isVisible else { return }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    static func hide(panel: NSPanel, animated: Bool, completion: @escaping () -> Void) {
        guard panel.isVisible else {
            completion()
            return
        }
        guard animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.orderOut(nil)
            completion()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
                completion()
            }
        })
    }
}

@MainActor
final class BubbleWindowController {
    let kind: NotchBubbleKind

    private let panel: NotchBubblePanel
    private var removalGeneration = 0

    init(kind: NotchBubbleKind, store: AppStore) {
        self.kind = kind
        panel = NotchBubblePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let root = NotchBubbleView(
            kind: kind,
            store: store,
            workspace: store.workspace
        )
        let view = NSHostingView(rootView: root)
        view.sizingOptions = []
        panel.contentView = view
    }

    func present(
        frame: CGRect,
        settings: NotchBubbleSettings,
        animated: Bool
    ) {
        removalGeneration += 1
        BubbleAnimationController.move(
            panel: panel,
            to: frame,
            preset: settings.animation,
            animated: animated
        )
        BubbleAnimationController.show(panel: panel, animated: animated)
    }

    func remove(animated: Bool, completion: @escaping () -> Void) {
        removalGeneration += 1
        let generation = removalGeneration
        BubbleAnimationController.hide(panel: panel, animated: animated) { [weak self] in
            guard let self, self.removalGeneration == generation else { return }
            completion()
        }
    }

    func close() {
        panel.close()
    }
}

// MARK: - Display host and manager

@MainActor
private final class NotchBubbleDisplayHost {
    let displayID: String

    private let store: AppStore
    private let settingsStore: NotchBubbleSettingsStore
    private let registry = BubbleRegistry()
    private let layoutEngine = BubbleLayoutEngine()

    private weak var surfacePanel: HaloPanel?
    private weak var state: SurfaceState?
    private var screenFrame: CGRect
    private var surfaceFrame: CGRect
    private var commercialAccessGranted = false
    private var controllers: [NotchBubbleKind: BubbleWindowController] = [:]
    private var subscriptions = Set<AnyCancellable>()

    init(
        displayID: String,
        screen: NSScreen,
        surfacePanel: HaloPanel,
        state: SurfaceState,
        store: AppStore,
        settingsStore: NotchBubbleSettingsStore
    ) {
        self.displayID = displayID
        self.screenFrame = screen.frame
        self.surfaceFrame = surfacePanel.frame
        self.surfacePanel = surfacePanel
        self.state = state
        self.store = store
        self.settingsStore = settingsStore
        bind(surfacePanel: surfacePanel, state: state)
        refresh(animated: false)
    }

    func update(screen: NSScreen, surfacePanel: HaloPanel, state: SurfaceState) {
        screenFrame = screen.frame
        surfaceFrame = surfacePanel.frame
        self.surfacePanel = surfacePanel
        self.state = state
        refresh(animated: false)
    }

    func setCommercialAccessGranted(_ granted: Bool) {
        guard commercialAccessGranted != granted else { return }
        commercialAccessGranted = granted
        refresh(animated: true)
    }

    func stop() {
        subscriptions.removeAll()
        for controller in controllers.values {
            controller.close()
        }
        controllers.removeAll()
    }

    private func bind(surfacePanel: HaloPanel, state: SurfaceState) {
        NotificationCenter.default.publisher(
            for: .init("HaloPanelGeometryChanged"),
            object: surfacePanel
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] note in
            guard let self else { return }
            if let frame = note.userInfo?["frame"] as? CGRect {
                self.surfaceFrame = frame
            } else {
                self.surfaceFrame = surfacePanel.frame
            }
            self.refresh(animated: true)
        }
        .store(in: &subscriptions)

        state.$expanded
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        settingsStore.$settings
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.$deadline
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.$pausedSeconds
            .map { $0 > 0.001 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.$finished
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.workspace.media.$isPlaying
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        HaloPixelPalStore.shared.$reaction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)
    }

    private func refresh(animated: Bool) {
        guard let state else {
            removeAll(animated: false)
            return
        }

        let settings = settingsStore.settings.normalized()
        let allowedBySurfaceState = state.expanded ? settings.showWhenOpen : settings.showWhenClosed

        guard commercialAccessGranted,
              settings.enabled,
              allowedBySurfaceState else {
            removeAll(animated: animated)
            return
        }

        if settings.musicEnabled {
            // Bubble artwork is optional, but when the user has explicitly enabled the
            // music bubble it is worth requesting the same artwork source used elsewhere
            // in Halo. We never force-disable it here because other Halo surfaces may need it.
            store.workspace.media.setArtworkEnabled(true)
        }

        let bubbles = registry.bubbles(store: store, settings: settings)
        let frames = layoutEngine.frames(
            for: bubbles,
            around: surfaceFrame,
            in: screenFrame,
            settings: settings
        )
        let activeKinds = Set(bubbles.map(\.kind))

        for kind in Array(controllers.keys) where !activeKinds.contains(kind) {
            guard let controller = controllers[kind] else { continue }
            controller.remove(animated: animated) { [weak self, weak controller] in
                guard let self, let controller,
                      self.controllers[kind] === controller else { return }
                controller.close()
                self.controllers.removeValue(forKey: kind)
            }
        }

        for bubble in bubbles {
            guard let frame = frames[bubble.kind] else { continue }
            let controller: BubbleWindowController
            if let existing = controllers[bubble.kind] {
                controller = existing
            } else {
                controller = BubbleWindowController(kind: bubble.kind, store: store)
                controllers[bubble.kind] = controller
            }
            controller.present(frame: frame, settings: settings, animated: animated)
        }
    }

    private func removeAll(animated: Bool) {
        for (kind, controller) in controllers {
            controller.remove(animated: animated) { [weak self, weak controller] in
                guard let self, let controller,
                      self.controllers[kind] === controller else { return }
                controller.close()
                self.controllers.removeValue(forKey: kind)
            }
        }
    }
}

@MainActor
final class NotchBubbleManager {
    private let store: AppStore
    private let settingsStore = NotchBubbleSettingsStore.shared
    private var hosts: [String: NotchBubbleDisplayHost] = [:]
    private var commercialAccessGranted = false

    init(store: AppStore) {
        self.store = store
    }

    func register(
        displayID: String,
        screen: NSScreen,
        surfacePanel: HaloPanel,
        state: SurfaceState
    ) {
        if let host = hosts[displayID] {
            host.update(screen: screen, surfacePanel: surfacePanel, state: state)
            return
        }

        let host = NotchBubbleDisplayHost(
            displayID: displayID,
            screen: screen,
            surfacePanel: surfacePanel,
            state: state,
            store: store,
            settingsStore: settingsStore
        )
        host.setCommercialAccessGranted(commercialAccessGranted)
        hosts[displayID] = host
    }

    func unregister(displayID: String) {
        hosts.removeValue(forKey: displayID)?.stop()
    }

    func setCommercialAccessGranted(_ granted: Bool) {
        commercialAccessGranted = granted
        for host in hosts.values {
            host.setCommercialAccessGranted(granted)
        }
    }
}

// MARK: - Bubble UI

@MainActor
private struct NotchBubbleView: View {
    let kind: NotchBubbleKind

    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject private var media: MediaService
    @ObservedObject private var pal = HaloPixelPalStore.shared
    @ObservedObject private var settingsStore = NotchBubbleSettingsStore.shared

    @State private var hovering = false
    @State private var showingDetail = false

    init(kind: NotchBubbleKind, store: AppStore, workspace: WorkspaceStore) {
        self.kind = kind
        self.store = store
        self.workspace = workspace
        _media = ObservedObject(wrappedValue: workspace.media)
    }

    private var settings: NotchBubbleSettings {
        settingsStore.settings.normalized()
    }

    var body: some View {
        bubbleContent
            .frame(width: CGFloat(settings.bubbleSize), height: CGFloat(settings.bubbleSize))
            .background { bubbleBackground }
            .overlay { bubbleBorder }
            .contentShape(Rectangle())
            .scaleEffect(hovering ? 1.07 : 1)
            .shadow(
                color: .black.opacity(hovering ? 0.34 : 0.20),
                radius: hovering ? 13 : 7,
                y: 3
            )
            .onHover { hovering = $0 }
            .simultaneousGesture(
                TapGesture().onEnded {
                    showingDetail.toggle()
                }
            )
            .animation(hoverAnimation, value: hovering)
            .popover(isPresented: $showingDetail, arrowEdge: .top) {
                detailView
                    .padding(14)
                    .frame(minWidth: detailWidth)
            }
            .accessibilityLabel(kind.title)
            .help(helpText)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch kind {
        case .music:
            if let artwork = media.artworkImage, media.isPlaying {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: max(4, CGFloat(settings.cornerRadius) - 4), style: .continuous))
                    .padding(3)
            } else {
                Image(systemName: media.isPlaying ? "music.note" : "music.note.list")
                    .font(.system(size: CGFloat(settings.bubbleSize) * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }

        case .timer:
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ZStack {
                    timerProgressRing(at: timeline.date)
                    if timerIsActive {
                        Text(compactTimerText(at: timeline.date))
                            .font(.system(size: max(8, CGFloat(settings.bubbleSize) * 0.20), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.55)
                            .lineLimit(1)
                            .padding(5)
                    } else {
                        Image(systemName: store.finished ? "checkmark" : "timer")
                            .font(.system(size: CGFloat(settings.bubbleSize) * 0.34, weight: .semibold))
                    }
                }
                .foregroundStyle(store.finished ? Color.green : Color.white)
            }

        case .pixelPal:
            HaloPixelPetWidget(store: store, workspace: workspace)
                .environment(\.haloPixelPalHostExpanded, true)
                .environment(\.haloPixelPalHostTransitionDuration, 0.16)
                .padding(2)
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch settings.shape {
        case .circle:
            Circle()
                .fill(Color.black.opacity(0.88))
        case .capsule:
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
        case .roundedSquare:
            RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
                .fill(Color.black.opacity(0.88))
        case .glass:
            RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(settings.glassIntensity)
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
                        .fill(Color.black.opacity(0.18))
                }
        }
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        switch settings.shape {
        case .circle:
            Circle().stroke(Color.white.opacity(hovering ? 0.24 : 0.12), lineWidth: 1)
        case .capsule:
            Capsule(style: .continuous).stroke(Color.white.opacity(hovering ? 0.24 : 0.12), lineWidth: 1)
        case .roundedSquare, .glass:
            RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
                .stroke(Color.white.opacity(hovering ? 0.24 : 0.12), lineWidth: 1)
        }
    }

    private var hoverAnimation: Animation? {
        switch settings.animation {
        case .none: return nil
        case .soft: return .easeInOut(duration: 0.20)
        case .fluid: return .spring(response: 0.28, dampingFraction: 0.82)
        case .snappy: return .easeOut(duration: 0.10)
        case .bouncy: return .spring(response: 0.32, dampingFraction: 0.58)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch kind {
        case .music:
            musicDetail
        case .timer:
            timerDetail
        case .pixelPal:
            pixelPalDetail
        }
    }

    private var musicDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                if let artwork = media.artworkImage, media.isPlaying {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 54, height: 54)
                        .overlay(Image(systemName: "music.note").font(.title2))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(media.isPlaying ? media.title : "Nothing playing")
                        .font(.headline)
                        .lineLimit(1)
                    Text(media.isPlaying ? media.artist : "Start audio to wake this bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 18) {
                Button { mediaCommand("previous track") } label: {
                    Image(systemName: "backward.fill")
                }
                Button { mediaCommand("playpause") } label: {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                }
                Button { mediaCommand("next track") } label: {
                    Image(systemName: "forward.fill")
                }
                Spacer()
                Button("Open Halo") { openHalo() }
            }
            .buttonStyle(.borderless)
        }
    }

    private var timerDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.finished ? "Timer complete" : (timerIsActive ? "Timer" : "Start a timer"))
                        .font(.headline)
                    Text(timerDetailText(at: timeline.date))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            if store.finished {
                HStack {
                    Button("Reset") { store.resetTimer() }
                    Spacer()
                    Button("Open Halo") { openHalo() }
                }
            } else if timerIsActive {
                HStack {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("+5 min") { store.addTimer(minutes: 5) }
                    Button("Cancel", role: .destructive) { store.resetTimer() }
                    Spacer()
                    Button("Open Halo") { openHalo() }
                }
            } else {
                HStack {
                    Button("5 min") { store.startTimer(minutes: 5) }
                    Button("15 min") { store.startTimer(minutes: 15) }
                    Button("25 min") { store.startTimer(minutes: 25) }
                    Spacer()
                    Button("Open Halo") { openHalo() }
                }
            }
        }
    }

    private var pixelPalDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pixel Pal")
                .font(.headline)
            Text("Pixel Pal is already running live inside the bubble. Keep interacting with the bubble itself, or jump into its full settings.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Feed Cookie") { pal.feedCookie() }
                Button("Pixel Pal Settings…") {
                    HaloPixelPalSettingsWindowController.shared.show()
                }
                Button("Open Halo") { openHalo() }
            }
            .buttonStyle(.borderless)
        }
    }

    private var detailWidth: CGFloat {
        switch kind {
        case .music: return 310
        case .timer: return 330
        case .pixelPal: return 360
        }
    }

    private var timerIsActive: Bool {
        store.deadline != nil || store.pausedSeconds > 0
    }

    private func timerRemaining(at date: Date) -> TimeInterval {
        if let deadline = store.deadline {
            return max(0, deadline.timeIntervalSince(date))
        }
        return max(0, store.pausedSeconds)
    }

    private func compactTimerText(at date: Date) -> String {
        let seconds = Int(timerRemaining(at: date).rounded(.down))
        if seconds >= 3600 {
            return String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func timerDetailText(at date: Date) -> String {
        guard timerIsActive else { return store.finished ? "Done" : "—" }
        let seconds = Int(timerRemaining(at: date).rounded(.down))
        return String(
            format: "%02d:%02d:%02d",
            seconds / 3600,
            (seconds % 3600) / 60,
            seconds % 60
        )
    }

    @ViewBuilder
    private func timerProgressRing(at date: Date) -> some View {
        let remaining = timerRemaining(at: date)
        let duration = max(1, store.timerDurationSeconds)
        let progress = min(1, max(0, remaining / duration))
        Circle()
            .stroke(Color.white.opacity(0.10), lineWidth: 2.5)
        Circle()
            .trim(from: 0, to: timerIsActive ? progress : (store.finished ? 1 : 0))
            .stroke(
                store.finished ? Color.green : Color.white.opacity(0.88),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 0.18), value: progress)
    }

    private func mediaCommand(_ command: String) {
        if media.connectedApp == nil {
            media.performSystem(command)
            return
        }

        let preferred = workspace.settings.mediaApp == WorkspaceStore.systemAudioSource
            ? "com.apple.Music"
            : workspace.settings.mediaApp
        media.perform(command, app: preferred)
    }

    private func openHalo() {
        NotificationCenter.default.post(name: .init("HaloToggle"), object: nil)
        showingDetail = false
    }

    private var helpText: String {
        switch kind {
        case .music:
            return media.isPlaying ? "\(media.title) — \(media.artist)" : "Music"
        case .timer:
            return store.finished ? "Timer complete" : "Timer"
        case .pixelPal:
            return "Pixel Pal"
        }
    }
}

// MARK: - Settings UI

@MainActor
struct NotchBubbleSettingsView: View {
    @ObservedObject private var settingsStore = NotchBubbleSettingsStore.shared

    private var settings: NotchBubbleSettings {
        settingsStore.settings.normalized()
    }

    var body: some View {
        Section("Notch Bubbles") {
            Toggle("Enable Notch Bubbles", isOn: binding(\.enabled))
            Text("Small Halo surfaces stay anchored to the notch for glanceable context and actions without opening the whole workspace.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Preview") {
            NotchBubbleSettingsPreview(settings: settings)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
        }

        Section("Layout") {
            Picker("Arrangement", selection: binding(\.layout)) {
                ForEach(NotchBubbleLayout.allCases) { layout in
                    Text(layout.rawValue).tag(layout)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Spacing") {
                HStack {
                    Slider(value: binding(\.spacing), in: 0...40, step: 1)
                        .frame(width: 210)
                    Text("\(Int(settings.spacing)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            LabeledContent("Bubble size") {
                HStack {
                    Slider(value: binding(\.bubbleSize), in: 24...72, step: 1)
                        .frame(width: 210)
                    Text("\(Int(settings.bubbleSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }

            Picker("Shape", selection: binding(\.shape)) {
                ForEach(NotchBubbleShape.allCases) { shape in
                    Text(shape.rawValue).tag(shape)
                }
            }

            if settings.shape == .roundedSquare || settings.shape == .glass {
                LabeledContent("Corner radius") {
                    Slider(value: binding(\.cornerRadius), in: 0...36, step: 1)
                        .frame(width: 210)
                }
            }

            if settings.shape == .glass {
                LabeledContent("Glass intensity") {
                    Slider(value: binding(\.glassIntensity), in: 0.15...1, step: 0.05)
                        .frame(width: 210)
                }
            }
        }

        Section("Visibility") {
            Toggle("Show while Halo is closed", isOn: binding(\.showWhenClosed))
            Toggle("Show while Halo is open", isOn: binding(\.showWhenOpen))
        }

        Section("Bubble providers") {
            providerRow(
                title: "Music",
                symbol: "music.note",
                enabled: binding(\.musicEnabled),
                persistent: binding(\.musicPersistent),
                detail: "Shows while media is playing, or stays pinned when Persistent is enabled."
            )
            providerRow(
                title: "Timer",
                symbol: "timer",
                enabled: binding(\.timerEnabled),
                persistent: binding(\.timerPersistent),
                detail: "Shows for active, paused and completed timers, or stays available as a quick-start action."
            )
            providerRow(
                title: "Pixel Pal",
                symbol: "face.smiling",
                enabled: binding(\.pixelPalEnabled),
                persistent: binding(\.pixelPalPersistent),
                detail: "Uses Halo's existing Pixel Pal renderer and interactions rather than a separate mascot implementation."
            )
        }

        Section("Motion & capacity") {
            Picker("Animation", selection: binding(\.animation)) {
                ForEach(NotchBubbleAnimationPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            Picker("Maximum bubbles", selection: binding(\.maximumBubbles)) {
                Text("3").tag(3)
                Text("5").tag(5)
                Text("8").tag(8)
                Text("Unlimited").tag(99)
            }
            Text("The first version ships Music, Timer and Pixel Pal. The capacity control is already future-proofed for additional providers and integrations.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section {
            Button("Reset Notch Bubble settings") {
                settingsStore.reset()
            }
        }
    }

    @ViewBuilder
    private func providerRow(
        title: String,
        symbol: String,
        enabled: Binding<Bool>,
        persistent: Binding<Bool>,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Toggle(isOn: enabled) {
                    Label(title, systemImage: symbol)
                }
                Toggle("Persistent", isOn: persistent)
                    .toggleStyle(.switch)
                    .disabled(!enabled.wrappedValue)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func binding<T>(_ keyPath: WritableKeyPath<NotchBubbleSettings, T>) -> Binding<T> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { value in
                var next = settingsStore.settings
                next[keyPath: keyPath] = value
                settingsStore.settings = next.normalized()
            }
        )
    }
}

private struct NotchBubbleSettingsPreview: View {
    let settings: NotchBubbleSettings

    var body: some View {
        GeometryReader { proxy in
            let notchWidth = min(190, proxy.size.width * 0.42)
            let notchHeight: CGFloat = 34
            let bubble = min(CGFloat(settings.bubbleSize), 46)
            let gap = min(CGFloat(settings.spacing), 18)
            let notch = CGRect(
                x: (proxy.size.width - notchWidth) / 2,
                y: 10,
                width: notchWidth,
                height: notchHeight
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.black.opacity(0.92))
                    .frame(width: notch.width, height: notch.height)
                    .position(x: notch.midX, y: notch.midY)

                ForEach(Array(previewFrames(notch: notch, size: bubble, spacing: gap).enumerated()), id: \.offset) { index, frame in
                    previewBubble(index)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .background(Color.secondary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.secondary.opacity(0.12)))
    }

    private func previewFrames(notch: CGRect, size: CGFloat, spacing: CGFloat) -> [CGRect] {
        let count = 3
        switch settings.layout {
        case .satellites:
            let total = CGFloat(count) * size + CGFloat(count - 1) * spacing
            let x = notch.midX - total / 2
            let y = notch.maxY + max(7, spacing)
            return (0..<count).map {
                CGRect(x: x + CGFloat($0) * (size + spacing), y: y, width: size, height: size)
            }

        case .wings:
            return [
                CGRect(x: notch.minX - spacing - size, y: notch.midY - size / 2, width: size, height: size),
                CGRect(x: notch.maxX + spacing, y: notch.midY - size / 2, width: size, height: size),
                CGRect(x: notch.minX - spacing * 2 - size * 2, y: notch.midY - size / 2, width: size, height: size)
            ]

        case .stack:
            return (0..<count).map {
                CGRect(
                    x: notch.midX - size / 2,
                    y: notch.maxY + max(7, spacing) + CGFloat($0) * (size + spacing),
                    width: size,
                    height: size
                )
            }
        }
    }

    @ViewBuilder
    private func previewBubble(_ index: Int) -> some View {
        let icon = ["music.note", "face.smiling", "timer"][min(2, max(0, index))]
        Group {
            switch settings.shape {
            case .circle:
                Circle().fill(Color.black.opacity(0.88))
            case .capsule:
                Capsule(style: .continuous).fill(Color.black.opacity(0.88))
            case .roundedSquare:
                RoundedRectangle(cornerRadius: min(CGFloat(settings.cornerRadius), 16), style: .continuous)
                    .fill(Color.black.opacity(0.88))
            case .glass:
                RoundedRectangle(cornerRadius: min(CGFloat(settings.cornerRadius), 16), style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(settings.glassIntensity)
            }
        }
        .overlay {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
    }
}
