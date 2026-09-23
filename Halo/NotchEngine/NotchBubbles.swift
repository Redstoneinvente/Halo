import AppKit
import Combine
import QuartzCore
import SwiftUI

// MARK: - Notch Bubble models

enum NotchBubbleKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case music
    case pixelPal
    case timer
    case clock
    case stopwatch
    case system
    case clipboard
    case calendar
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .pixelPal: return "Pixel Pal"
        case .timer: return "Timer"
        case .clock: return "Clock"
        case .stopwatch: return "Stopwatch"
        case .system: return "System"
        case .clipboard: return "Clipboard"
        case .calendar: return "Calendar"
        case .audio: return "Audio"
        }
    }

    var symbol: String {
        switch self {
        case .music: return "music.note"
        case .pixelPal: return "face.smiling"
        case .timer: return "timer"
        case .clock: return "clock.fill"
        case .stopwatch: return "stopwatch.fill"
        case .system: return "gauge.with.dots.needle.67percent"
        case .clipboard: return "doc.on.clipboard.fill"
        case .calendar: return "calendar"
        case .audio: return "speaker.wave.2.fill"
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

enum NotchBubblePriority: Int, Codable, Comparable, Hashable {
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

enum MusicBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case artwork = "Artwork"
    case artworkProgress = "Artwork + Progress"
    case controls = "Playback Control"
    case icon = "Music Icon"
    var id: String { rawValue }
}

enum MusicBubbleTapAction: String, Codable, CaseIterable, Identifiable, Hashable {
    case details = "Show Details"
    case playPause = "Play / Pause"
    case openNotch = "Open Notch"
    case openPlayer = "Open Player"
    var id: String { rawValue }
}

enum SystemBubbleMetric: String, Codable, CaseIterable, Identifiable, Hashable {
    case battery = "Battery"
    case cpu = "CPU"
    case memory = "Memory"
    case storage = "Storage"
    case network = "Network"
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
    // Optional preserves decoding of Notch Bubble settings saved before this control existed.
    // Positive values move bubbles down on screen.
    var verticalOffset: Double?
    var shape: NotchBubbleShape = .glass
    var cornerRadius = 18.0
    var glassIntensity = 0.82
    var animation: NotchBubbleAnimationPreset = .fluid
    // Optional so settings saved before lifecycle timing existed still decode.
    var lifecycleDuration: Double?
    var maximumBubbles = 3

    var showWhenClosed = true
    var showWhenOpen = true

    var musicEnabled = true
    var musicPersistent = false
    var timerEnabled = true
    var timerPersistent = false
    var pixelPalEnabled = true
    var pixelPalPersistent = true

    // Optional fields preserve decoding for existing Notch Bubble settings.
    var musicDisplayMode: MusicBubbleDisplayMode?
    var musicShowPlaybackGlyph: Bool?
    var musicArtworkZoom: Double?
    var musicTapAction: MusicBubbleTapAction?

    var clockEnabled: Bool?
    var stopwatchEnabled: Bool?
    var stopwatchPersistent: Bool?
    var systemEnabled: Bool?
    var systemMetric: SystemBubbleMetric?
    var clipboardEnabled: Bool?
    var calendarEnabled: Bool?
    var audioEnabled: Bool?

    func normalized() -> Self {
        var value = self
        value.version = 1
        value.spacing = min(40, max(0, spacing.isFinite ? spacing : 10))
        value.bubbleSize = min(72, max(24, bubbleSize.isFinite ? bubbleSize : 42))
        if let verticalOffset {
            value.verticalOffset = min(120, max(-120, verticalOffset.isFinite ? verticalOffset : 0))
        }
        value.cornerRadius = min(36, max(0, cornerRadius.isFinite ? cornerRadius : 18))
        value.glassIntensity = min(1, max(0.15, glassIntensity.isFinite ? glassIntensity : 0.82))
        if let lifecycleDuration {
            value.lifecycleDuration = min(1.5, max(0.10, lifecycleDuration.isFinite ? lifecycleDuration : 0.28))
        }
        if let musicArtworkZoom {
            value.musicArtworkZoom = min(1.8, max(1.0, musicArtworkZoom.isFinite ? musicArtworkZoom : 1.0))
        }
        value.maximumBubbles = min(99, max(1, maximumBubbles))
        return value
    }

    var resolvedVerticalOffset: Double {
        let value = verticalOffset ?? 0
        return value.isFinite ? min(120, max(-120, value)) : 0
    }

    var resolvedLifecycleDuration: Double {
        let value = lifecycleDuration ?? 0.28
        return value.isFinite ? min(1.5, max(0.10, value)) : 0.28
    }

    var resolvedMusicDisplayMode: MusicBubbleDisplayMode { musicDisplayMode ?? .artwork }
    var resolvedMusicShowPlaybackGlyph: Bool { musicShowPlaybackGlyph ?? false }
    var resolvedMusicArtworkZoom: Double {
        let value = musicArtworkZoom ?? 1.0
        return value.isFinite ? min(1.8, max(1.0, value)) : 1.0
    }
    var resolvedMusicTapAction: MusicBubbleTapAction { musicTapAction ?? .details }

    var resolvedClockEnabled: Bool { clockEnabled ?? false }
    var resolvedStopwatchEnabled: Bool { stopwatchEnabled ?? false }
    var resolvedStopwatchPersistent: Bool { stopwatchPersistent ?? false }
    var resolvedSystemEnabled: Bool { systemEnabled ?? false }
    var resolvedSystemMetric: SystemBubbleMetric { systemMetric ?? .battery }
    var resolvedClipboardEnabled: Bool { clipboardEnabled ?? false }
    var resolvedCalendarEnabled: Bool { calendarEnabled ?? false }
    var resolvedAudioEnabled: Bool { audioEnabled ?? false }
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
private struct ClockBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .clock
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        guard settings.resolvedClockEnabled else { return nil }
        return NotchBubble(kind: kind, size: CGFloat(settings.bubbleSize), shape: settings.shape,
                           isPersistent: true, timeout: nil, priority: .background)
    }
}

@MainActor
private struct StopwatchBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .stopwatch
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        let active = store.workspace.stopwatchStart != nil || store.workspace.stopwatchElapsed > 0
        guard settings.resolvedStopwatchEnabled,
              settings.resolvedStopwatchPersistent || active else { return nil }
        return NotchBubble(kind: kind, size: CGFloat(settings.bubbleSize), shape: settings.shape,
                           isPersistent: settings.resolvedStopwatchPersistent, timeout: nil,
                           priority: active ? .important : .normal)
    }
}

@MainActor
private struct SystemBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .system
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        guard settings.resolvedSystemEnabled else { return nil }
        return NotchBubble(kind: kind, size: CGFloat(settings.bubbleSize), shape: settings.shape,
                           isPersistent: true, timeout: nil, priority: .background)
    }
}

@MainActor
private struct ClipboardBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .clipboard
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        guard settings.resolvedClipboardEnabled else { return nil }
        return NotchBubble(kind: kind, size: CGFloat(settings.bubbleSize), shape: settings.shape,
                           isPersistent: true, timeout: nil, priority: .background)
    }
}

@MainActor
private struct CalendarBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .calendar
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        guard settings.resolvedCalendarEnabled else { return nil }
        return NotchBubble(kind: kind, size: CGFloat(settings.bubbleSize), shape: settings.shape,
                           isPersistent: true, timeout: nil, priority: .background)
    }
}

@MainActor
private struct AudioBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .audio
    func bubble(store: AppStore, settings: NotchBubbleSettings) -> NotchBubble? {
        guard settings.resolvedAudioEnabled else { return nil }
        return NotchBubble(kind: kind, size: CGFloat(settings.bubbleSize), shape: settings.shape,
                           isPersistent: true, timeout: nil, priority: .background)
    }
}

@MainActor
struct BubbleRegistry {
    private let providers: [any BubbleProvider] = [
        MusicBubbleProvider(),
        PixelPalBubbleProvider(),
        TimerBubbleProvider(),
        ClockBubbleProvider(),
        StopwatchBubbleProvider(),
        SystemBubbleProvider(),
        ClipboardBubbleProvider(),
        CalendarBubbleProvider(),
        AudioBubbleProvider()
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
        case .timer: return 1
        case .pixelPal: return 2
        case .stopwatch: return 3
        case .audio: return 4
        case .calendar: return 5
        case .clipboard: return 6
        case .system: return 7
        case .clock: return 8
        }
    }
}

// MARK: - Layout

struct BubbleLayoutEngine {
    func frames(
        for bubbles: [NotchBubble],
        around surfaceFrame: CGRect,
        in screenFrame: CGRect,
        compactHeight: CGFloat,
        settings: NotchBubbleSettings
    ) -> [NotchBubbleKind: CGRect] {
        guard !bubbles.isEmpty else { return [:] }

        let size = CGFloat(settings.bubbleSize)
        let spacing = CGFloat(settings.spacing)
        let gap = max(5, spacing)
        let verticalOffset = CGFloat(settings.resolvedVerticalOffset)
        var result: [NotchBubbleKind: CGRect] = [:]

        switch settings.layout {
        case .satellites:
            let total = CGFloat(bubbles.count) * size + CGFloat(max(0, bubbles.count - 1)) * spacing
            let startX = surfaceFrame.midX - total / 2
            let y = surfaceFrame.minY - gap - size - verticalOffset
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
            // Wings belong to the menu-bar band, not the expanding body of Halo.
            // Keep their vertical center aligned to the compact notch height even while
            // the main surface grows hundreds of points downward.
            let menuBarHeight = max(1, compactHeight)
            let menuBarCenterY = screenFrame.maxY - menuBarHeight / 2
            let y = menuBarCenterY - size / 2 - verticalOffset
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
                    y: surfaceFrame.minY - gap - size - CGFloat(index) * (size + spacing) - verticalOffset,
                    width: size,
                    height: size
                )
                result[bubble.kind] = clamped(frame, to: screenFrame)
            }
        }

        return result
    }

    func emergenceFrame(
        for targetFrame: CGRect,
        around surfaceFrame: CGRect,
        in screenFrame: CGRect,
        compactWidth: CGFloat,
        compactHeight: CGFloat
    ) -> CGRect {
        // Always use the compact notch footprint as the origin, even when Halo is expanded.
        // That keeps the motion feeling attached to the physical/Dynamic-Island-like source.
        let width = max(1, compactWidth)
        let height = max(1, compactHeight)
        let compactFrame = CGRect(
            x: surfaceFrame.midX - width / 2,
            y: screenFrame.maxY - height,
            width: width,
            height: height
        )

        let targetCenter = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        let anchor: CGPoint

        if targetCenter.x < compactFrame.minX {
            anchor = CGPoint(
                x: compactFrame.minX,
                y: min(compactFrame.maxY, max(compactFrame.minY, targetCenter.y))
            )
        } else if targetCenter.x > compactFrame.maxX {
            anchor = CGPoint(
                x: compactFrame.maxX,
                y: min(compactFrame.maxY, max(compactFrame.minY, targetCenter.y))
            )
        } else if targetCenter.y < compactFrame.minY {
            anchor = CGPoint(
                x: min(compactFrame.maxX, max(compactFrame.minX, targetCenter.x)),
                y: compactFrame.minY
            )
        } else {
            anchor = CGPoint(x: compactFrame.midX, y: compactFrame.midY)
        }

        return CGRect(
            x: anchor.x - targetFrame.width / 2,
            y: anchor.y - targetFrame.height / 2,
            width: targetFrame.width,
            height: targetFrame.height
        )
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

private final class TransparentNotchBubbleHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
    }
}

@MainActor
private final class BubbleFrameAnimator {
    private let clock = DisplayClock()

    func cancel() {
        clock.stop()
    }

    func move(
        panel: NSPanel,
        to target: CGRect,
        preset: NotchBubbleAnimationPreset,
        animated: Bool
    ) {
        cancel()
        resetVisuals(panel: panel)

        guard panel.frame != target else { return }
        guard animated,
              preset != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let view = panel.contentView else {
            panel.setFrame(target, display: false)
            return
        }

        let initial = panel.frame
        let start = CACurrentMediaTime()
        let duration: CFTimeInterval
        switch preset {
        case .soft: duration = 0.24
        case .fluid: duration = 0.19
        case .snappy: duration = 0.12
        case .bouncy: duration = 0.27
        case .none: duration = 0
        }

        clock.start(view: view) { [weak self, weak panel] timestamp in
            guard let self, let panel else {
                self?.cancel()
                return
            }

            let t = min(1, max(0, (timestamp - start) / max(0.01, duration)))
            let p = self.progress(t, preset: preset)
            let frame = CGRect(
                x: initial.origin.x + (target.origin.x - initial.origin.x) * p,
                y: initial.origin.y + (target.origin.y - initial.origin.y) * p,
                width: initial.width + (target.width - initial.width) * p,
                height: initial.height + (target.height - initial.height) * p
            )
            panel.setFrame(frame, display: false)

            if t >= 1 {
                panel.setFrame(target, display: false)
                self.cancel()
            }
        }
    }

    func emerge(
        panel: NSPanel,
        from source: CGRect,
        to target: CGRect,
        preset: NotchBubbleAnimationPreset,
        duration: TimeInterval,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        cancel()
        guard let view = panel.contentView else {
            panel.setFrame(target, display: false)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            completion?()
            return
        }

        resetVisuals(panel: panel)
        guard animated,
              preset != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(target, display: false)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            completion?()
            return
        }

        panel.setFrame(source, display: false)
        panel.alphaValue = 1
        view.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.18, y: 0.18))
        view.layer?.opacity = 0.58
        panel.orderFrontRegardless()

        animateLifecycle(
            panel: panel,
            view: view,
            from: source,
            to: target,
            preset: preset,
            duration: duration,
            startScale: 0.18,
            endScale: 1,
            startOpacity: 0.58,
            endOpacity: 1,
            completion: completion
        )
    }

    func restoreFromCurrent(
        panel: NSPanel,
        to target: CGRect,
        preset: NotchBubbleAnimationPreset,
        duration: TimeInterval,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        cancel()
        guard let view = panel.contentView else {
            panel.setFrame(target, display: false)
            panel.alphaValue = 1
            completion?()
            return
        }

        let currentScale = max(0.18, min(1, view.layer?.affineTransform().a ?? 1))
        let currentOpacity = Double(view.layer?.opacity ?? 1)

        guard animated,
              preset != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(target, display: false)
            resetVisuals(panel: panel)
            completion?()
            return
        }

        animateLifecycle(
            panel: panel,
            view: view,
            from: panel.frame,
            to: target,
            preset: preset,
            duration: duration,
            startScale: currentScale,
            endScale: 1,
            startOpacity: currentOpacity,
            endOpacity: 1,
            completion: completion
        )
    }

    func retract(
        panel: NSPanel,
        to source: CGRect,
        preset: NotchBubbleAnimationPreset,
        duration: TimeInterval,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        cancel()
        guard let view = panel.contentView else {
            panel.orderOut(nil)
            completion()
            return
        }

        guard panel.isVisible,
              animated,
              preset != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            resetVisuals(panel: panel)
            panel.orderOut(nil)
            completion()
            return
        }

        let initial = panel.frame
        let currentScale = max(0.18, min(1, view.layer?.affineTransform().a ?? 1))
        let currentOpacity = Double(view.layer?.opacity ?? 1)
        animateLifecycle(
            panel: panel,
            view: view,
            from: initial,
            to: source,
            preset: preset,
            duration: duration,
            startScale: currentScale,
            endScale: 0.18,
            startOpacity: currentOpacity,
            endOpacity: 0.58
        ) { [weak self, weak panel] in
            guard let self, let panel else { return }
            self.resetVisuals(panel: panel)
            panel.orderOut(nil)
            completion()
        }
    }

    func resetVisuals(panel: NSPanel) {
        panel.alphaValue = 1
        panel.contentView?.layer?.setAffineTransform(.identity)
        panel.contentView?.layer?.opacity = 1
    }

    private func animateLifecycle(
        panel: NSPanel,
        view: NSView,
        from initial: CGRect,
        to target: CGRect,
        preset: NotchBubbleAnimationPreset,
        duration: TimeInterval,
        startScale: CGFloat,
        endScale: CGFloat,
        startOpacity: Double,
        endOpacity: Double,
        completion: (() -> Void)?
    ) {
        let start = CACurrentMediaTime()
        let duration = max(0.01, duration)

        clock.start(view: view) { [weak self, weak panel, weak view] timestamp in
            guard let self, let panel, let view else {
                self?.cancel()
                return
            }

            let t = min(1, max(0, (timestamp - start) / max(0.01, duration)))
            let p = self.progress(t, preset: preset)
            let frame = CGRect(
                x: initial.origin.x + (target.origin.x - initial.origin.x) * p,
                y: initial.origin.y + (target.origin.y - initial.origin.y) * p,
                width: initial.width + (target.width - initial.width) * p,
                height: initial.height + (target.height - initial.height) * p
            )
            panel.setFrame(frame, display: false)

            let scale = startScale + (endScale - startScale) * p
            let opacity = startOpacity + (endOpacity - startOpacity) * Double(p)
            view.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            view.layer?.opacity = Float(opacity)

            if t >= 1 {
                self.cancel()
                panel.setFrame(target, display: false)
                if endScale >= 0.999 && endOpacity >= 0.999 {
                    self.resetVisuals(panel: panel)
                }
                completion?()
            }
        }
    }

    private func progress(_ t: CFTimeInterval, preset: NotchBubbleAnimationPreset) -> CGFloat {
        if t >= 1 { return 1 }
        let value: Double
        switch preset {
        case .soft:
            value = -(cos(.pi * t) - 1) / 2
        case .fluid:
            value = 1 - pow(1 - t, 3)
        case .snappy:
            value = 1 - pow(1 - t, 4)
        case .bouncy:
            // Quick response with a restrained spring overshoot.
            value = 1 - exp(-7.5 * t) * cos(9.0 * t)
        case .none:
            value = 1
        }
        return CGFloat(value)
    }
}

@MainActor
enum BubbleAnimationController {
    static func show(panel: NSPanel, animated: Bool) {
        guard !panel.isVisible else { return }
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.11
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
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
            context.duration = 0.09
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
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
    private enum LifecyclePhase: Equatable {
        case hidden
        case emerging
        case visible
        case retracting
    }

    let kind: NotchBubbleKind

    private let panel: NotchBubblePanel
    private let frameAnimator = BubbleFrameAnimator()
    private var removalGeneration = 0
    private var lifecyclePhase: LifecyclePhase = .hidden
    private var desiredFrame: CGRect = .zero

    var frame: CGRect { panel.frame }

    init(kind: NotchBubbleKind, store: AppStore, state: SurfaceState) {
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
            workspace: store.workspace,
            surfaceState: state
        )
        let view = TransparentNotchBubbleHostingView(rootView: root)
        view.sizingOptions = []
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
        panel.contentView = view
    }

    func present(
        frame: CGRect,
        emergenceFrame: CGRect,
        settings: NotchBubbleSettings,
        animated: Bool,
        trackingSurface: Bool = false
    ) {
        desiredFrame = frame
        let duration = settings.resolvedLifecycleDuration

        switch lifecyclePhase {
        case .hidden:
            removalGeneration += 1
            let generation = removalGeneration
            lifecyclePhase = .emerging
            frameAnimator.emerge(
                panel: panel,
                from: emergenceFrame,
                to: frame,
                preset: settings.animation,
                duration: duration,
                animated: animated && !trackingSurface
            ) { [weak self] in
                guard let self, self.removalGeneration == generation else { return }
                self.lifecyclePhase = .visible
                if self.panel.frame != self.desiredFrame {
                    self.panel.setFrame(self.desiredFrame, display: false)
                }
            }

        case .emerging:
            // Geometry/provider refreshes are expected while the window is already ordered
            // onscreen. Do not cancel or invalidate the lifecycle animation just because
            // another refresh arrived.
            return

        case .retracting:
            // The event came back while merging into the notch. This is a real transition
            // change, so invalidate the retraction and smoothly reverse from its current state.
            removalGeneration += 1
            let generation = removalGeneration
            lifecyclePhase = .emerging
            frameAnimator.restoreFromCurrent(
                panel: panel,
                to: frame,
                preset: settings.animation,
                duration: duration,
                animated: animated && !trackingSurface
            ) { [weak self] in
                guard let self, self.removalGeneration == generation else { return }
                self.lifecyclePhase = .visible
                if self.panel.frame != self.desiredFrame {
                    self.panel.setFrame(self.desiredFrame, display: false)
                }
            }

        case .visible:
            if trackingSurface {
                // SurfaceAnimator already publishes display-linked geometry every frame.
                // Follow it directly; never stack another tween on top.
                frameAnimator.cancel()
                frameAnimator.resetVisuals(panel: panel)
                if panel.frame != frame {
                    panel.setFrame(frame, display: false)
                }
            } else {
                frameAnimator.move(
                    panel: panel,
                    to: frame,
                    preset: settings.animation,
                    animated: animated
                )
            }
        }
    }

    func remove(
        animated: Bool,
        emergenceFrame: CGRect,
        settings: NotchBubbleSettings,
        completion: @escaping () -> Void
    ) {
        if lifecyclePhase == .hidden {
            completion()
            return
        }
        if lifecyclePhase == .retracting {
            // The existing retraction owns its completion. A repeated provider/settings
            // refresh must not invalidate it.
            return
        }

        removalGeneration += 1
        let generation = removalGeneration
        lifecyclePhase = .retracting
        frameAnimator.retract(
            panel: panel,
            to: emergenceFrame,
            preset: settings.animation,
            duration: settings.resolvedLifecycleDuration,
            animated: animated
        ) { [weak self] in
            guard let self, self.removalGeneration == generation else { return }
            self.lifecyclePhase = .hidden
            completion()
        }
    }

    func close() {
        frameAnimator.cancel()
        lifecyclePhase = .hidden
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
            self.refresh(animated: false, trackingSurface: true)
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

        store.workspace.$stopwatchStart
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.workspace.$stopwatchElapsed
            .map { $0 > 0.001 }
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

    private func refresh(animated: Bool, trackingSurface: Bool = false) {
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

        if settings.resolvedAudioEnabled || settings.resolvedSystemEnabled {
            store.workspace.audio.refresh()
            store.workspace.system.refresh(detailed: false)
        }

        let bubbles = registry.bubbles(store: store, settings: settings)
        let frames = layoutEngine.frames(
            for: bubbles,
            around: surfaceFrame,
            in: screenFrame,
            compactHeight: state.compactHeight,
            settings: settings
        )
        let activeKinds = Set(bubbles.map(\.kind))

        for kind in Array(controllers.keys) where !activeKinds.contains(kind) {
            guard let controller = controllers[kind] else { continue }
            let emergenceFrame = layoutEngine.emergenceFrame(
                for: controller.frame,
                around: surfaceFrame,
                in: screenFrame,
                compactWidth: state.physicalNotchWidth > 1 ? state.physicalNotchWidth : state.compactWidth,
                compactHeight: state.physicalNotchHeight > 1 ? state.physicalNotchHeight : state.compactHeight
            )
            controller.remove(
                animated: animated,
                emergenceFrame: emergenceFrame,
                settings: settings
            ) { [weak self, weak controller] in
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
                controller = BubbleWindowController(kind: bubble.kind, store: store, state: state)
                controllers[bubble.kind] = controller
            }
            let emergenceFrame = layoutEngine.emergenceFrame(
                for: frame,
                around: surfaceFrame,
                in: screenFrame,
                compactWidth: state.physicalNotchWidth > 1 ? state.physicalNotchWidth : state.compactWidth,
                compactHeight: state.physicalNotchHeight > 1 ? state.physicalNotchHeight : state.compactHeight
            )
            controller.present(
                frame: frame,
                emergenceFrame: emergenceFrame,
                settings: settings,
                animated: animated,
                trackingSurface: trackingSurface
            )
        }
    }

    private func removeAll(animated: Bool) {
        let settings = settingsStore.settings.normalized()
        let compactWidth: CGFloat = {
            guard let state else { return 190 }
            return state.physicalNotchWidth > 1 ? state.physicalNotchWidth : state.compactWidth
        }()
        let compactHeight: CGFloat = {
            guard let state else { return 40 }
            return state.physicalNotchHeight > 1 ? state.physicalNotchHeight : state.compactHeight
        }()

        for (kind, controller) in controllers {
            let emergenceFrame = layoutEngine.emergenceFrame(
                for: controller.frame,
                around: surfaceFrame,
                in: screenFrame,
                compactWidth: compactWidth,
                compactHeight: compactHeight
            )
            controller.remove(
                animated: animated,
                emergenceFrame: emergenceFrame,
                settings: settings
            ) { [weak self, weak controller] in
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

private struct NotchBubbleMaskShape: Shape {
    let shape: NotchBubbleShape
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .circle:
            return Path(ellipseIn: rect)
        case .capsule:
            return Capsule(style: .continuous).path(in: rect)
        case .roundedSquare, .glass:
            return RoundedRectangle(
                cornerRadius: min(max(0, cornerRadius), min(rect.width, rect.height) / 2),
                style: .continuous
            ).path(in: rect)
        }
    }
}

@MainActor
private struct NotchBubbleView: View {
    let kind: NotchBubbleKind

    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var media: MediaService
    @ObservedObject private var system: SystemService
    @ObservedObject private var audio: AudioService
    @ObservedObject private var pal = HaloPixelPalStore.shared
    @ObservedObject private var settingsStore = NotchBubbleSettingsStore.shared

    @State private var hovering = false
    @State private var showingDetail = false

    init(kind: NotchBubbleKind, store: AppStore, workspace: WorkspaceStore, surfaceState: SurfaceState) {
        self.kind = kind
        self.store = store
        self.workspace = workspace
        self.surfaceState = surfaceState
        _media = ObservedObject(wrappedValue: workspace.media)
        _system = ObservedObject(wrappedValue: workspace.system)
        _audio = ObservedObject(wrappedValue: workspace.audio)
    }

    private var settings: NotchBubbleSettings {
        settingsStore.settings.normalized()
    }

    var body: some View {
        bubbleContent
            .frame(width: CGFloat(settings.bubbleSize), height: CGFloat(settings.bubbleSize))
            .background { bubbleBackground }
            .clipShape(NotchBubbleMaskShape(
                shape: settings.shape,
                cornerRadius: CGFloat(settings.cornerRadius)
            ))
            .contentShape(NotchBubbleMaskShape(
                shape: settings.shape,
                cornerRadius: CGFloat(settings.cornerRadius)
            ))
            .overlay { bubbleBorder }
            .scaleEffect(hovering ? 1.07 : 1)
            .compositingGroup()
            .onHover { hovering = $0 }
            .simultaneousGesture(
                TapGesture().onEnded {
                    handlePrimaryTap()
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
            musicBubbleContent

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

        case .clock:
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(spacing: 0) {
                    Text(clockTime(timeline.date))
                        .font(.system(size: max(9, CGFloat(settings.bubbleSize) * 0.22), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                    Text(clockDay(timeline.date))
                        .font(.system(size: max(6, CGFloat(settings.bubbleSize) * 0.11), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(4)
            }

        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
                let elapsed = stopwatchElapsed(at: timeline.date)
                VStack(spacing: 1) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: CGFloat(settings.bubbleSize) * 0.24, weight: .semibold))
                    Text(shortElapsed(elapsed))
                        .font(.system(size: max(7, CGFloat(settings.bubbleSize) * 0.15), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
            }

        case .system:
            systemBubbleContent

        case .clipboard:
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: CGFloat(settings.bubbleSize) * 0.36, weight: .semibold))
                .foregroundStyle(.white)

        case .calendar:
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                VStack(spacing: -1) {
                    Text(monthAbbreviation(timeline.date))
                        .font(.system(size: max(6, CGFloat(settings.bubbleSize) * 0.11), weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    Text(dayNumber(timeline.date))
                        .font(.system(size: max(12, CGFloat(settings.bubbleSize) * 0.34), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }

        case .audio:
            ZStack {
                Circle()
                    .trim(from: 0, to: audio.canSetVolume ? min(1, max(0, Double(audio.volume))) : 0)
                    .stroke(.white.opacity(0.86), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                Image(systemName: audioSymbol)
                    .font(.system(size: CGFloat(settings.bubbleSize) * 0.28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var musicBubbleContent: some View {
        let mode = settings.resolvedMusicDisplayMode
        ZStack {
            if mode == .icon || media.artworkImage == nil || !media.isPlaying {
                Image(systemName: media.isPlaying ? "music.note" : "music.note.list")
                    .font(.system(size: CGFloat(settings.bubbleSize) * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            } else if let artwork = media.artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(CGFloat(settings.resolvedMusicArtworkZoom))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                if mode == .controls {
                    Color.black.opacity(0.24)
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: CGFloat(settings.bubbleSize) * 0.28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }

            if mode == .artworkProgress {
                musicProgressRing
            }

            if settings.resolvedMusicShowPlaybackGlyph && mode != .controls {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: CGFloat(settings.bubbleSize) * 0.20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.black.opacity(0.42), in: Circle())
            }
        }
    }

    private var musicProgressRing: some View {
        let duration = max(0.001, media.duration)
        let progress = min(1, max(0, media.position / duration))
        return ZStack {
            Circle().stroke(.black.opacity(0.28), lineWidth: 2.4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var systemBubbleContent: some View {
        let metric = settings.resolvedSystemMetric
        VStack(spacing: 1) {
            Image(systemName: systemMetricSymbol(metric))
                .font(.system(size: CGFloat(settings.bubbleSize) * 0.23, weight: .semibold))
            Text(systemMetricValue(metric))
                .font(.system(size: max(7, CGFloat(settings.bubbleSize) * 0.14), weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(.white)
        .padding(3)
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
        case .clock:
            moduleDetail(.clock)
        case .stopwatch:
            moduleDetail(.stopwatch)
        case .system:
            moduleDetail(.system)
        case .clipboard:
            moduleDetail(.clipboard)
        case .calendar:
            moduleDetail(.calendar)
        case .audio:
            moduleDetail(.audio)
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
                Button("Open Notch") { openNotch() }
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
                    Button("Open Notch") { openNotch() }
                }
            } else if timerIsActive {
                HStack {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("+5 min") { store.addTimer(minutes: 5) }
                    Button("Cancel", role: .destructive) { store.resetTimer() }
                    Spacer()
                    Button("Open Notch") { openNotch() }
                }
            } else {
                HStack {
                    Button("5 min") { store.startTimer(minutes: 5) }
                    Button("15 min") { store.startTimer(minutes: 15) }
                    Button("25 min") { store.startTimer(minutes: 25) }
                    Spacer()
                    Button("Open Notch") { openNotch() }
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
                Button("Open Notch") { openNotch() }
            }
            .buttonStyle(.borderless)
        }
    }

    private func moduleDetail(_ module: ModuleID) -> some View {
        let style = workspace.effectiveLayout.widgetStyle(for: module)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(module.title, systemImage: module.symbol)
                    .font(.headline)
                Spacer()
                Button("Open Notch") { openNotch() }
                    .buttonStyle(.borderless)
            }

            WidgetCard(
                style: style,
                availableHeight: 220,
                availableWidth: 330,
                fillsCell: module == .pet
            ) {
                BuiltinOrIntegrationWidget(module: module, store: store)
            }
            .environment(\.openNotchPresentation, .expanded)
            .environment(\.openNotchCompressionLevel, 0)
            .frame(width: 330, height: 220)
        }
    }

    private var detailWidth: CGFloat {
        switch kind {
        case .music: return 310
        case .timer: return 330
        case .pixelPal: return 360
        case .clock, .stopwatch, .system, .clipboard, .calendar, .audio: return 354
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

    private func handlePrimaryTap() {
        guard kind == .music else {
            showingDetail.toggle()
            return
        }

        switch settings.resolvedMusicTapAction {
        case .details:
            showingDetail.toggle()
        case .playPause:
            mediaCommand("playpause")
        case .openNotch:
            openNotch()
        case .openPlayer:
            openMediaPlayer()
        }
    }

    private func openMediaPlayer() {
        guard let bundleID = media.connectedApp,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            showingDetail.toggle()
            return
        }
        app.activate(options: .activateIgnoringOtherApps)
    }

    private func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func clockDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    private func monthAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private func dayNumber(_ date: Date) -> String {
        String(Calendar.autoupdatingCurrent.component(.day, from: date))
    }

    private func stopwatchElapsed(at date: Date) -> TimeInterval {
        workspace.stopwatchElapsed + (workspace.stopwatchStart.map { date.timeIntervalSince($0) } ?? 0)
    }

    private func shortElapsed(_ elapsed: TimeInterval) -> String {
        let seconds = max(0, Int(elapsed))
        if seconds >= 3600 {
            return String(format: "%d:%02d", seconds / 3600, seconds / 60 % 60)
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var audioSymbol: String {
        guard audio.canSetVolume else { return "speaker.slash.fill" }
        switch audio.volume {
        case ..<0.01: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private func systemMetricSymbol(_ metric: SystemBubbleMetric) -> String {
        switch metric {
        case .battery:
            return system.charging ? "battery.100percent.bolt" : "battery.100percent"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .storage: return "internaldrive"
        case .network: return "network"
        }
    }

    private func systemMetricValue(_ metric: SystemBubbleMetric) -> String {
        switch metric {
        case .battery:
            return system.battery.map { "\($0)%" } ?? "—"
        case .cpu:
            return String(format: "%.0f%%", system.cpuUsage)
        case .memory:
            return String(format: "%.0f%%", system.memoryUsage)
        case .storage:
            return String(format: "%.0f%%", system.diskUsage)
        case .network:
            let total = system.networkDownPerSecond + system.networkUpPerSecond
            if total < 1_000 { return "<1K" }
            if total < 1_000_000 { return String(format: "%.0fK", total / 1_000) }
            return String(format: "%.1fM", total / 1_000_000)
        }
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

    private func openNotch() {
        switch kind {
        case .music:
            let layout = surfaceState.layoutOverride ?? workspace.effectiveLayout
            let musicCI = layout.contextMusic ?? ContextMusicOptions()
            let canOpenMusicCI =
                musicCI.enabled &&
                media.isPlaying &&
                media.hasNowPlayingPresentation

            surfaceState.openExplicitly(canOpenMusicCI ? .music : .normal)

        case .timer, .pixelPal, .clock, .stopwatch, .system, .clipboard, .calendar, .audio:
            // These bubbles are shortcuts into the user's normal opened notch.
            // They do not replace the dashboard with a focused widget.
            surfaceState.openExplicitly(.normal)
        }

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
        case .clock:
            return "Clock"
        case .stopwatch:
            return "Stopwatch · \(shortElapsed(stopwatchElapsed(at: Date())))"
        case .system:
            return "\(settings.resolvedSystemMetric.rawValue) · \(systemMetricValue(settings.resolvedSystemMetric))"
        case .clipboard:
            return "Clipboard"
        case .calendar:
            return "Calendar"
        case .audio:
            return audio.canSetVolume ? "Volume \(Int(audio.volume * 100))%" : "Audio"
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

            LabeledContent("Vertical offset") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { settings.resolvedVerticalOffset },
                            set: { value in
                                var next = settingsStore.settings
                                next.verticalOffset = value
                                settingsStore.settings = next.normalized()
                            }
                        ),
                        in: -120...120,
                        step: 1
                    )
                    .frame(width: 210)

                    Text(String(format: "%+.0f pt", settings.resolvedVerticalOffset))
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                }
            }
            Text("Positive values move bubbles downward. Wings stay anchored to the menu-bar band while Halo expands.")
                .font(.caption)
                .foregroundStyle(.secondary)

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

        Section("Music bubble") {
            Picker("Display", selection: optionalBinding(\.musicDisplayMode, default: MusicBubbleDisplayMode.artwork)) {
                ForEach(MusicBubbleDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Toggle(
                "Show playback glyph",
                isOn: optionalBinding(\.musicShowPlaybackGlyph, default: false)
            )
            .disabled(settings.resolvedMusicDisplayMode == .controls)

            LabeledContent("Artwork zoom") {
                HStack {
                    Slider(
                        value: optionalBinding(\.musicArtworkZoom, default: 1.0),
                        in: 1.0...1.8,
                        step: 0.05
                    )
                    .frame(width: 210)
                    Text(String(format: "%.2fx", settings.resolvedMusicArtworkZoom))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .disabled(settings.resolvedMusicDisplayMode == .icon)

            Picker("Click action", selection: optionalBinding(\.musicTapAction, default: MusicBubbleTapAction.details)) {
                ForEach(MusicBubbleTapAction.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }

            Text("Artwork + Progress wraps album art in live playback progress. Playback Control turns the bubble itself into a large play/pause surface.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
            providerToggleRow(
                title: "Clock",
                symbol: "clock.fill",
                enabled: optionalBinding(\.clockEnabled, default: false),
                detail: "A compact live clock bubble with the full Clock widget available on click."
            )
            providerRow(
                title: "Stopwatch",
                symbol: "stopwatch.fill",
                enabled: optionalBinding(\.stopwatchEnabled, default: false),
                persistent: optionalBinding(\.stopwatchPersistent, default: false),
                detail: "Appears while the stopwatch is active or has elapsed time. Persistent keeps it ready at all times."
            )
            providerToggleRow(
                title: "System",
                symbol: "gauge.with.dots.needle.67percent",
                enabled: optionalBinding(\.systemEnabled, default: false),
                detail: "Shows one live system metric directly in the bubble."
            )

            if settings.resolvedSystemEnabled {
                Picker("System metric", selection: optionalBinding(\.systemMetric, default: SystemBubbleMetric.battery)) {
                    ForEach(SystemBubbleMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .padding(.leading, 28)
            }

            providerToggleRow(
                title: "Clipboard",
                symbol: "doc.on.clipboard.fill",
                enabled: optionalBinding(\.clipboardEnabled, default: false),
                detail: "Keeps Halo's Clipboard widget one click away."
            )
            providerToggleRow(
                title: "Calendar",
                symbol: "calendar",
                enabled: optionalBinding(\.calendarEnabled, default: false),
                detail: "Shows today's date and opens the full Calendar widget."
            )
            providerToggleRow(
                title: "Audio",
                symbol: "speaker.wave.2.fill",
                enabled: optionalBinding(\.audioEnabled, default: false),
                detail: "Shows current output volume with a live radial level indicator."
            )

            Text("New bubble types are off by default so existing setups keep their current layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Motion & capacity") {
            Picker("Animation", selection: binding(\.animation)) {
                ForEach(NotchBubbleAnimationPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            LabeledContent("Lifecycle duration") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { settings.resolvedLifecycleDuration },
                            set: { value in
                                var next = settingsStore.settings
                                next.lifecycleDuration = value
                                settingsStore.settings = next.normalized()
                            }
                        ),
                        in: 0.10...1.50,
                        step: 0.05
                    )
                    .frame(width: 210)

                    Text(String(format: "%.2f s", settings.resolvedLifecycleDuration))
                        .monospacedDigit()
                        .frame(width: 54, alignment: .trailing)
                }
            }
            Text("Controls how long bubbles take to emerge from and merge back into the physical notch.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Maximum bubbles", selection: binding(\.maximumBubbles)) {
                Text("3").tag(3)
                Text("5").tag(5)
                Text("8").tag(8)
                Text("12").tag(12)
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

    @ViewBuilder
    private func providerToggleRow(
        title: String,
        symbol: String,
        enabled: Binding<Bool>,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle(isOn: enabled) {
                Label(title, systemImage: symbol)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func optionalBinding<T>(
        _ keyPath: WritableKeyPath<NotchBubbleSettings, T?>,
        default defaultValue: T
    ) -> Binding<T> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] ?? defaultValue },
            set: { value in
                var next = settingsStore.settings
                next[keyPath: keyPath] = value
                settingsStore.settings = next.normalized()
            }
        )
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
            let verticalOffset = CGFloat(settings.resolvedVerticalOffset)
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

                ForEach(Array(previewFrames(notch: notch, size: bubble, spacing: gap, verticalOffset: verticalOffset).enumerated()), id: \.offset) { index, frame in
                    previewBubble(index)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .background(Color.secondary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.secondary.opacity(0.12)))
    }

    private func previewFrames(notch: CGRect, size: CGFloat, spacing: CGFloat, verticalOffset: CGFloat) -> [CGRect] {
        let count = 3
        switch settings.layout {
        case .satellites:
            let total = CGFloat(count) * size + CGFloat(count - 1) * spacing
            let x = notch.midX - total / 2
            let y = notch.maxY + max(7, spacing) + verticalOffset
            return (0..<count).map {
                CGRect(x: x + CGFloat($0) * (size + spacing), y: y, width: size, height: size)
            }

        case .wings:
            return [
                CGRect(x: notch.minX - spacing - size, y: notch.midY - size / 2 + verticalOffset, width: size, height: size),
                CGRect(x: notch.maxX + spacing, y: notch.midY - size / 2 + verticalOffset, width: size, height: size),
                CGRect(x: notch.minX - spacing * 2 - size * 2, y: notch.midY - size / 2 + verticalOffset, width: size, height: size)
            ]

        case .stack:
            return (0..<count).map {
                CGRect(
                    x: notch.midX - size / 2,
                    y: notch.maxY + max(7, spacing) + CGFloat($0) * (size + spacing) + verticalOffset,
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
