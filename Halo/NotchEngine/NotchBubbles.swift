import AppKit
import Combine
import EventKit
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
    case vinyl

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
        case .vinyl: return "Vinyl"
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
        case .vinyl: return "record.circle.fill"
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

enum NotchBubblePresentationMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case confirmation = "Confirmation"
    case activeTask = "While Active"
    case onDemand = "On Demand"
    case pinned = "Pinned"
    var id: String { rawValue }
}

enum MusicBubbleVisibility: String, Codable, CaseIterable, Identifiable, Hashable {
    case whilePlaying = "While Playing"
    case trackChanges = "Track Changes Only"
    case pinned = "Pinned"
    var id: String { rawValue }
}

struct NotchBubbleActivity: Identifiable, Equatable {
    let id: String
    let kind: NotchBubbleKind
    let sourceIdentifier: String
    let mode: NotchBubblePresentationMode
    let priority: NotchBubblePriority
    var title: String
    var subtitle: String?
    var icon: String
    var progress: Double?
    var updatedAt: Date
    var expiresAt: Date?

    var isExpired: Bool {
        if let expiresAt { return expiresAt <= Date() }
        return false
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

enum NotchBubbleBackgroundStyle: String, Codable, CaseIterable, Identifiable, Hashable {
    case solid = "Solid"
    case glass = "Glass"
    case clear = "Clear"
    var id: String { rawValue }
}

enum NotchBubbleDesignPreset: String, Codable, CaseIterable, Identifiable, Hashable {
    case halo = "Halo Glass"
    case aurora = "Aurora"
    case neon = "Neon Edge"
    case obsidian = "Obsidian"
    case prism = "Prism"
    case ember = "Ember"
    case midnight = "Midnight"
    case minimal = "Minimal"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .halo: return "Layered dark glass with a soft inner highlight."
        case .aurora: return "A flowing blue-violet gradient with luminous depth."
        case .neon: return "Near-black center with a vivid double-edge glow."
        case .obsidian: return "Dense graphite with restrained radial reflections."
        case .prism: return "Dark glass washed with a subtle spectral gradient."
        case .ember: return "Warm crimson and amber depth with a hot inner edge."
        case .midnight: return "Deep navy glass with cool atmospheric highlights."
        case .minimal: return "Almost transparent, with only a precise hairline edge."
        }
    }
}

enum TimerBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case ring = "Ring + Time"
    case digits = "Digits"
    case arc = "Progress Arc"
    case icon = "Icon"
    var id: String { rawValue }
}

enum ClockBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case digital = "Digital"
    case seconds = "Digital + Seconds"
    case analog = "Analog"
    case date = "Date + Time"
    var id: String { rawValue }
}

enum StopwatchBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case compact = "Compact"
    case digits = "Digits"
    case ring = "Ring"
    case laps = "Lap Count"
    var id: String { rawValue }
}

enum SystemBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case value = "Icon + Value"
    case gauge = "Radial Gauge"
    case bars = "Meter Bars"
    case icon = "Icon"
    var id: String { rawValue }
}

enum ClipboardBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case icon = "Icon"
    case preview = "Latest Text"
    case count = "Item Count"
    var id: String { rawValue }
}

enum CalendarBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case date = "Date"
    case weekday = "Date + Weekday"
    case nextEvent = "Next Event"
    var id: String { rawValue }
}

enum AudioBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case ring = "Volume Ring"
    case percentage = "Percentage"
    case icon = "Speaker Icon"
    case device = "Output Device"
    var id: String { rawValue }
}

enum VinylBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case fullRecord = "Full Record"
    case labelFocus = "Label Focus"
    case recordProgress = "Record + Progress"
    var id: String { rawValue }
}

enum PixelPalBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case full = "Full Pixel Pal"
    case closeUp = "Close-up"
    case icon = "Icon"
    var id: String { rawValue }
}

struct NotchBubbleStyleOverride: Codable, Equatable {
    var design: NotchBubbleDesignPreset? = nil
    var size: Double? = nil
    var shape: NotchBubbleShape? = nil
    var background: NotchBubbleBackgroundStyle? = nil
    var cornerRadius: Double? = nil
    var glassIntensity: Double? = nil
    var backgroundOpacity: Double? = nil
    var borderOpacity: Double? = nil
    var contentScale: Double? = nil
    var verticalOffset: Double? = nil
    var tint: WidgetColor? = nil
    var tintAmount: Double? = nil
    var animation: NotchBubbleAnimationPreset? = nil
    var lifecycleDuration: Double? = nil

    func normalized() -> Self {
        var value = self
        if let size { value.size = min(96, max(20, size.isFinite ? size : 42)) }
        if let cornerRadius { value.cornerRadius = min(48, max(0, cornerRadius.isFinite ? cornerRadius : 18)) }
        if let glassIntensity { value.glassIntensity = min(1, max(0.05, glassIntensity.isFinite ? glassIntensity : 0.82)) }
        if let backgroundOpacity { value.backgroundOpacity = min(1, max(0, backgroundOpacity.isFinite ? backgroundOpacity : 0.88)) }
        if let borderOpacity { value.borderOpacity = min(1, max(0, borderOpacity.isFinite ? borderOpacity : 0.12)) }
        if let contentScale { value.contentScale = min(1.6, max(0.55, contentScale.isFinite ? contentScale : 1)) }
        if let verticalOffset { value.verticalOffset = min(120, max(-120, verticalOffset.isFinite ? verticalOffset : 0)) }
        if let tintAmount { value.tintAmount = min(1, max(0, tintAmount.isFinite ? tintAmount : 0)) }
        if let lifecycleDuration { value.lifecycleDuration = min(1.5, max(0.10, lifecycleDuration.isFinite ? lifecycleDuration : 0.28)) }
        if let tint { value.tint = (try? tint.validated()) ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0) }
        return value
    }

    var isEmpty: Bool {
        design == nil && size == nil && shape == nil && background == nil && cornerRadius == nil &&
        glassIntensity == nil && backgroundOpacity == nil && borderOpacity == nil &&
        contentScale == nil && verticalOffset == nil && tint == nil && tintAmount == nil &&
        animation == nil && lifecycleDuration == nil
    }
}

struct ResolvedNotchBubbleStyle {
    let design: NotchBubbleDesignPreset
    let size: CGFloat
    let shape: NotchBubbleShape
    let background: NotchBubbleBackgroundStyle
    let cornerRadius: CGFloat
    let glassIntensity: Double
    let backgroundOpacity: Double
    let borderOpacity: Double
    let contentScale: CGFloat
    let verticalOffset: CGFloat
    let tint: Color?
    let tintAmount: Double
    let animation: NotchBubbleAnimationPreset
    let lifecycleDuration: TimeInterval
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
    var animation: NotchBubbleAnimationPreset = .soft
    // Optional so settings saved before lifecycle timing existed still decode.
    var lifecycleDuration: Double?
    var maximumBubbles = 1

    var showWhenClosed = true
    var showWhenOpen = true

    var musicEnabled = true
    var musicPersistent = false
    var timerEnabled = true
    var timerPersistent = false
    var pixelPalEnabled = false
    var pixelPalPersistent = false

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
    var vinylEnabled: Bool?
    var vinylPersistent: Bool?

    // Provider-specific content choices. Optional keeps older saved settings decodable.
    var timerDisplayMode: TimerBubbleDisplayMode?
    var clockDisplayMode: ClockBubbleDisplayMode?
    var clockUse24Hour: Bool?
    var stopwatchDisplayMode: StopwatchBubbleDisplayMode?
    var systemDisplayMode: SystemBubbleDisplayMode?
    var clipboardDisplayMode: ClipboardBubbleDisplayMode?
    var calendarDisplayMode: CalendarBubbleDisplayMode?
    var audioDisplayMode: AudioBubbleDisplayMode?
    var vinylDisplayMode: VinylBubbleDisplayMode?
    var pixelPalDisplayMode: PixelPalBubbleDisplayMode?

    // Evidence-led behaviour/policy controls. Optional fields preserve existing settings.
    var confirmationDuration: Double?
    var completionDuration: Double?
    var musicVisibility: MusicBubbleVisibility?
    var audioFeedbackEnabled: Bool?
    var brightnessFeedbackEnabled: Bool?
    var powerFeedbackEnabled: Bool?
    var deviceFeedbackEnabled: Bool?
    var replaceHaloHUDFeedback: Bool?
    var calendarLeadMinutes: Double?
    var calendarPersistent: Bool?
    var audioPersistent: Bool?
    var systemPersistent: Bool?
    var clipboardPersistent: Bool?
    var showAutomaticInFullscreen: Bool?
    var showConfirmationsInFullscreen: Bool?

    /// Per-provider appearance overrides. Missing entries inherit the global bubble defaults.
    var bubbleStyles: [String: NotchBubbleStyleOverride]?

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
        if let confirmationDuration {
            value.confirmationDuration = min(8, max(0.5, confirmationDuration.isFinite ? confirmationDuration : 1.6))
        }
        if let completionDuration {
            value.completionDuration = min(10, max(1, completionDuration.isFinite ? completionDuration : 4.0))
        }
        if let calendarLeadMinutes {
            value.calendarLeadMinutes = min(120, max(1, calendarLeadMinutes.isFinite ? calendarLeadMinutes : 15))
        }
        if let musicArtworkZoom {
            value.musicArtworkZoom = min(1.8, max(1.0, musicArtworkZoom.isFinite ? musicArtworkZoom : 1.0))
        }
        value.maximumBubbles = min(99, max(1, maximumBubbles))
        if let bubbleStyles {
            var normalizedStyles: [String: NotchBubbleStyleOverride] = [:]
            for (key, override) in bubbleStyles {
                let normalized = override.normalized()
                if !normalized.isEmpty { normalizedStyles[key] = normalized }
            }
            value.bubbleStyles = normalizedStyles.isEmpty ? nil : normalizedStyles
        }
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
    var resolvedVinylEnabled: Bool { vinylEnabled ?? false }
    var resolvedVinylPersistent: Bool { vinylPersistent ?? false }

    var resolvedTimerDisplayMode: TimerBubbleDisplayMode { timerDisplayMode ?? .ring }
    var resolvedClockDisplayMode: ClockBubbleDisplayMode { clockDisplayMode ?? .digital }
    var resolvedClockUse24Hour: Bool { clockUse24Hour ?? false }
    var resolvedStopwatchDisplayMode: StopwatchBubbleDisplayMode { stopwatchDisplayMode ?? .compact }
    var resolvedSystemDisplayMode: SystemBubbleDisplayMode { systemDisplayMode ?? .value }
    var resolvedClipboardDisplayMode: ClipboardBubbleDisplayMode { clipboardDisplayMode ?? .icon }
    var resolvedCalendarDisplayMode: CalendarBubbleDisplayMode { calendarDisplayMode ?? .date }
    var resolvedAudioDisplayMode: AudioBubbleDisplayMode { audioDisplayMode ?? .ring }
    var resolvedVinylDisplayMode: VinylBubbleDisplayMode { vinylDisplayMode ?? .fullRecord }
    var resolvedPixelPalDisplayMode: PixelPalBubbleDisplayMode { pixelPalDisplayMode ?? .full }

    var resolvedConfirmationDuration: Double { min(8, max(0.5, confirmationDuration ?? 1.6)) }
    var resolvedCompletionDuration: Double { min(10, max(1, completionDuration ?? 4.0)) }
    var resolvedMusicVisibility: MusicBubbleVisibility { musicVisibility ?? (musicPersistent ? .pinned : .whilePlaying) }
    var resolvedAudioFeedbackEnabled: Bool { audioFeedbackEnabled ?? true }
    var resolvedBrightnessFeedbackEnabled: Bool { brightnessFeedbackEnabled ?? true }
    var resolvedPowerFeedbackEnabled: Bool { powerFeedbackEnabled ?? false }
    var resolvedDeviceFeedbackEnabled: Bool { deviceFeedbackEnabled ?? false }
    var resolvedReplaceHaloHUDFeedback: Bool { replaceHaloHUDFeedback ?? false }
    var resolvedCalendarLeadMinutes: Double { min(120, max(1, calendarLeadMinutes ?? 15)) }
    var resolvedCalendarPersistent: Bool { calendarPersistent ?? false }
    var resolvedAudioPersistent: Bool { audioPersistent ?? false }
    var resolvedSystemPersistent: Bool { systemPersistent ?? false }
    var resolvedClipboardPersistent: Bool { clipboardPersistent ?? false }
    var resolvedShowAutomaticInFullscreen: Bool { showAutomaticInFullscreen ?? false }
    var resolvedShowConfirmationsInFullscreen: Bool { showConfirmationsInFullscreen ?? true }

    func acceptsHUDEvent(_ kind: HaloHUDEventKind) -> Bool {
        switch kind {
        case .volume, .mute:
            return resolvedAudioFeedbackEnabled
        case .displayBrightness, .keyboardBrightness:
            return resolvedBrightnessFeedbackEnabled
        case .batteryStatus, .chargingState, .powerSourceChanged:
            return resolvedPowerFeedbackEnabled
        case .audioOutputChanged, .audioDeviceConnected:
            return resolvedDeviceFeedbackEnabled
        case .mediaChanged:
            return musicEnabled && resolvedMusicVisibility == .trackChanges
        default:
            return false
        }
    }

    func styleOverride(for kind: NotchBubbleKind) -> NotchBubbleStyleOverride? {
        bubbleStyles?[kind.rawValue]?.normalized()
    }

    func resolvedStyle(for kind: NotchBubbleKind) -> ResolvedNotchBubbleStyle {
        let override = styleOverride(for: kind)
        let resolvedShape = override?.shape ?? shape
        let resolvedBackground: NotchBubbleBackgroundStyle = override?.background
            ?? (shape == .glass ? .glass : .solid)
        let tintColor = override?.tint?.color
        return ResolvedNotchBubbleStyle(
            design: override?.design ?? .halo,
            size: CGFloat(override?.size ?? bubbleSize),
            shape: resolvedShape,
            background: resolvedBackground,
            cornerRadius: CGFloat(override?.cornerRadius ?? cornerRadius),
            glassIntensity: override?.glassIntensity ?? glassIntensity,
            backgroundOpacity: override?.backgroundOpacity ?? 0.88,
            borderOpacity: override?.borderOpacity ?? 0.12,
            contentScale: CGFloat(override?.contentScale ?? 1.0),
            verticalOffset: CGFloat(override?.verticalOffset ?? 0),
            tint: tintColor,
            tintAmount: override?.tintAmount ?? 0,
            animation: override?.animation ?? animation,
            lifecycleDuration: override?.lifecycleDuration ?? resolvedLifecycleDuration
        )
    }
}

@MainActor
final class NotchBubbleActivityCenter: ObservableObject {
    static let shared = NotchBubbleActivityCenter()

    @Published private(set) var transientActivities: [String: NotchBubbleActivity] = [:]
    @Published private(set) var suppressedKinds: Set<NotchBubbleKind> = []

    private var expiryTasks: [String: Task<Void, Never>] = [:]

    private init() {}

    func publishHUD(_ event: HaloHUDEvent, settings: NotchBubbleSettings) {
        guard settings.acceptsHUDEvent(event.kind),
              let activity = Self.activity(from: event, settings: settings) else { return }

        suppressedKinds.remove(activity.kind)
        transientActivities[activity.id] = activity
        scheduleExpiry(for: activity)
    }

    func dismiss(kind: NotchBubbleKind) {
        suppressedKinds.insert(kind)
        let ids = transientActivities.values.filter { $0.kind == kind }.map(\.id)
        for id in ids {
            expiryTasks[id]?.cancel()
            expiryTasks.removeValue(forKey: id)
            transientActivities.removeValue(forKey: id)
        }
    }

    func clearDismissal(kind: NotchBubbleKind) {
        suppressedKinds.remove(kind)
    }

    func currentActivity(for kind: NotchBubbleKind) -> NotchBubbleActivity? {
        transientActivities.values
            .filter { $0.kind == kind && !$0.isExpired }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.updatedAt > $1.updatedAt
            }
            .first
    }

    func activeTransientActivities() -> [NotchBubbleActivity] {
        transientActivities.values.filter { !$0.isExpired }
    }

    private func scheduleExpiry(for activity: NotchBubbleActivity) {
        expiryTasks[activity.id]?.cancel()
        guard let expiresAt = activity.expiresAt else { return }
        let delay = max(0.05, expiresAt.timeIntervalSinceNow)
        expiryTasks[activity.id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self,
                      self.transientActivities[activity.id]?.updatedAt == activity.updatedAt else { return }
                self.transientActivities.removeValue(forKey: activity.id)
                self.expiryTasks.removeValue(forKey: activity.id)
            }
        }
    }

    private static func activity(from event: HaloHUDEvent, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        let now = Date()
        let duration = settings.resolvedConfirmationDuration
        let expiry = now.addingTimeInterval(duration)

        switch event.kind {
        case .volume, .mute:
            return NotchBubbleActivity(
                id: "confirmation.audio",
                kind: .audio,
                sourceIdentifier: "system.audio",
                mode: .confirmation,
                priority: .urgent,
                title: event.primaryText,
                subtitle: event.secondaryText,
                icon: event.icon,
                progress: event.progress,
                updatedAt: now,
                expiresAt: expiry
            )

        case .displayBrightness, .keyboardBrightness:
            return NotchBubbleActivity(
                id: "confirmation.systemBrightness",
                kind: .system,
                sourceIdentifier: event.kind.rawValue,
                mode: .confirmation,
                priority: .urgent,
                title: event.primaryText,
                subtitle: event.kind == .keyboardBrightness ? "Keyboard" : "Display",
                icon: event.icon,
                progress: event.progress,
                updatedAt: now,
                expiresAt: expiry
            )

        case .batteryStatus, .chargingState, .powerSourceChanged:
            return NotchBubbleActivity(
                id: "confirmation.power",
                kind: .system,
                sourceIdentifier: "system.power",
                mode: .confirmation,
                priority: .important,
                title: event.primaryText,
                subtitle: event.secondaryText,
                icon: event.icon,
                progress: event.progress,
                updatedAt: now,
                expiresAt: expiry
            )

        case .audioOutputChanged, .audioDeviceConnected:
            return NotchBubbleActivity(
                id: "confirmation.audioDevice",
                kind: .audio,
                sourceIdentifier: "system.audioDevice",
                mode: .confirmation,
                priority: .important,
                title: event.primaryText,
                subtitle: event.secondaryText ?? event.metadata["deviceName"],
                icon: event.icon,
                progress: event.progress,
                updatedAt: now,
                expiresAt: expiry
            )

        case .mediaChanged:
            return NotchBubbleActivity(
                id: "confirmation.music",
                kind: .music,
                sourceIdentifier: "media." + (event.metadata["bundleIdentifier"] ?? "current"),
                mode: .confirmation,
                priority: .normal,
                title: event.primaryText,
                subtitle: event.secondaryText,
                icon: event.icon,
                progress: event.progress,
                updatedAt: now,
                expiresAt: expiry
            )

        default:
            return nil
        }
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

// MARK: - Providers, activity state and policy

@MainActor
protocol BubbleProvider {
    var kind: NotchBubbleKind { get }
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity?
}

@MainActor
private struct MusicBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .music

    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.musicEnabled else { return nil }
        let media = store.workspace.media
        switch settings.resolvedMusicVisibility {
        case .trackChanges:
            return nil
        case .whilePlaying:
            guard media.isPlaying else { return nil }
        case .pinned:
            break
        }

        return NotchBubbleActivity(
            id: "media.nowPlaying",
            kind: kind,
            sourceIdentifier: media.connectedApp ?? "system.media",
            mode: settings.resolvedMusicVisibility == .pinned ? .pinned : .activeTask,
            priority: media.isPlaying ? .normal : .background,
            title: media.title,
            subtitle: media.artist,
            icon: "music.note",
            progress: media.duration > 0 ? min(1, max(0, media.position / media.duration)) : nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct TimerBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .timer

    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        let active = store.deadline != nil || store.pausedSeconds > 0
        guard settings.timerEnabled, settings.timerPersistent || active || store.finished else { return nil }
        let mode: NotchBubblePresentationMode = settings.timerPersistent && !active && !store.finished ? .pinned : .activeTask
        return NotchBubbleActivity(
            id: "timer.primary",
            kind: kind,
            sourceIdentifier: "halo.timer",
            mode: mode,
            priority: store.finished ? .urgent : (active ? .important : .normal),
            title: store.finished ? "Timer complete" : "Timer",
            subtitle: nil,
            icon: store.finished ? "checkmark.circle.fill" : "timer",
            progress: nil,
            updatedAt: Date(),
            expiresAt: store.finished && !settings.timerPersistent
                ? Date().addingTimeInterval(settings.resolvedCompletionDuration)
                : nil
        )
    }
}

@MainActor
private struct CalendarBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .calendar

    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.resolvedCalendarEnabled else { return nil }
        let now = Date()
        let lead = settings.resolvedCalendarLeadMinutes * 60

        guard let event = store.workspace.calendar.upcomingEvents.first(where: {
            $0.endDate > now && ($0.startDate.timeIntervalSince(now) <= lead || settings.resolvedCalendarPersistent)
        }) else { return nil }

        let seconds = max(0, event.startDate.timeIntervalSince(now))
        let priority: NotchBubblePriority = seconds <= 5 * 60 ? .important : .normal
        return NotchBubbleActivity(
            id: "calendar." + event.eventIdentifier,
            kind: kind,
            sourceIdentifier: event.calendar.calendarIdentifier,
            mode: settings.resolvedCalendarPersistent ? .pinned : .activeTask,
            priority: priority,
            title: event.title ?? "Upcoming event",
            subtitle: seconds > 0 ? "Starts in \(Int(ceil(seconds / 60))) min" : "Now",
            icon: "calendar.badge.clock",
            progress: nil,
            updatedAt: now,
            expiresAt: event.endDate
        )
    }
}

@MainActor
private struct StopwatchBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .stopwatch
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        let active = store.workspace.stopwatchStart != nil || store.workspace.stopwatchElapsed > 0
        guard settings.resolvedStopwatchEnabled,
              settings.resolvedStopwatchPersistent || active else { return nil }
        return NotchBubbleActivity(
            id: "stopwatch.primary",
            kind: kind,
            sourceIdentifier: "halo.stopwatch",
            mode: settings.resolvedStopwatchPersistent ? .pinned : .activeTask,
            priority: active ? .important : .background,
            title: "Stopwatch",
            subtitle: nil,
            icon: "stopwatch.fill",
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct VinylBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .vinyl
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        let active = store.workspace.media.isPlaying && store.workspace.media.hasNowPlayingPresentation
        guard settings.resolvedVinylEnabled,
              settings.resolvedVinylPersistent || active else { return nil }
        return NotchBubbleActivity(
            id: "media.vinyl",
            kind: kind,
            sourceIdentifier: store.workspace.media.connectedApp ?? "system.media",
            mode: settings.resolvedVinylPersistent ? .pinned : .activeTask,
            priority: active ? .normal : .background,
            title: store.workspace.media.title,
            subtitle: store.workspace.media.artist,
            icon: "record.circle.fill",
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct PixelPalBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .pixelPal
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.pixelPalEnabled else { return nil }
        let contextual = HaloPixelPalStore.shared.reaction != nil
        guard settings.pixelPalPersistent || contextual else { return nil }
        return NotchBubbleActivity(
            id: "pixelPal",
            kind: kind,
            sourceIdentifier: "halo.pixelPal",
            mode: settings.pixelPalPersistent ? .pinned : .activeTask,
            priority: .background,
            title: "Pixel Pal",
            subtitle: nil,
            icon: "face.smiling",
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct ClockBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .clock
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.resolvedClockEnabled else { return nil }
        return NotchBubbleActivity(
            id: "clock",
            kind: kind,
            sourceIdentifier: "system.clock",
            mode: .pinned,
            priority: .background,
            title: "Clock",
            subtitle: nil,
            icon: "clock.fill",
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct SystemBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .system
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.resolvedSystemEnabled, settings.resolvedSystemPersistent else { return nil }
        return NotchBubbleActivity(
            id: "system.stats",
            kind: kind,
            sourceIdentifier: "system.metrics",
            mode: .pinned,
            priority: .background,
            title: settings.resolvedSystemMetric.rawValue,
            subtitle: nil,
            icon: kind.symbol,
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct ClipboardBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .clipboard
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.resolvedClipboardEnabled, settings.resolvedClipboardPersistent else { return nil }
        return NotchBubbleActivity(
            id: "clipboard",
            kind: kind,
            sourceIdentifier: "system.clipboard",
            mode: .pinned,
            priority: .background,
            title: "Clipboard",
            subtitle: nil,
            icon: kind.symbol,
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

@MainActor
private struct AudioBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .audio
    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.resolvedAudioEnabled, settings.resolvedAudioPersistent else { return nil }
        return NotchBubbleActivity(
            id: "audio.controls",
            kind: kind,
            sourceIdentifier: "system.audio",
            mode: .pinned,
            priority: .background,
            title: "Audio",
            subtitle: nil,
            icon: kind.symbol,
            progress: Double(store.workspace.audio.volume),
            updatedAt: Date(),
            expiresAt: nil
        )
    }
}

struct NotchBubblePolicyEngine {
    func select(
        _ activities: [NotchBubbleActivity],
        settings: NotchBubbleSettings,
        surfaceExpanded: Bool,
        fullscreen: Bool,
        suppressedKinds: Set<NotchBubbleKind>
    ) -> [NotchBubbleActivity] {
        let now = Date()
        let visible = activities.filter { activity in
            guard !suppressedKinds.contains(activity.kind) else { return false }
            if let expiresAt = activity.expiresAt, expiresAt <= now { return false }
            if fullscreen {
                if activity.mode == .confirmation {
                    return settings.resolvedShowConfirmationsInFullscreen
                }
                return settings.resolvedShowAutomaticInFullscreen || activity.mode == .pinned
            }
            return true
        }

        let deduplicated = Dictionary(grouping: visible, by: \.kind).compactMap { _, values in
            values.sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.updatedAt > $1.updatedAt
            }.first
        }

        return deduplicated
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                if $0.mode != $1.mode {
                    let rank: [NotchBubblePresentationMode: Int] = [
                        .confirmation: 3, .activeTask: 2, .pinned: 1, .onDemand: 0
                    ]
                    return rank[$0.mode, default: 0] > rank[$1.mode, default: 0]
                }
                return $0.updatedAt > $1.updatedAt
            }
            .prefix(settings.maximumBubbles)
            .map { $0 }
    }
}

@MainActor
struct BubbleRegistry {
    private let providers: [any BubbleProvider] = [
        MusicBubbleProvider(),
        TimerBubbleProvider(),
        CalendarBubbleProvider(),
        StopwatchBubbleProvider(),
        VinylBubbleProvider(),
        PixelPalBubbleProvider(),
        ClockBubbleProvider(),
        SystemBubbleProvider(),
        ClipboardBubbleProvider(),
        AudioBubbleProvider()
    ]
    private let policy = NotchBubblePolicyEngine()

    func bubbles(
        store: AppStore,
        settings: NotchBubbleSettings,
        runtime: NotchBubbleActivityCenter,
        surfaceExpanded: Bool
    ) -> [NotchBubble] {
        var activities = providers.compactMap { $0.activity(store: store, settings: settings) }
        activities.append(contentsOf: runtime.activeTransientActivities())

        let fullscreen = NSApp.currentSystemPresentationOptions.contains(.fullScreen)
        let selected = policy.select(
            activities,
            settings: settings,
            surfaceExpanded: surfaceExpanded,
            fullscreen: fullscreen,
            suppressedKinds: runtime.suppressedKinds
        )

        return selected.map { activity in
            let style = settings.resolvedStyle(for: activity.kind)
            return NotchBubble(
                kind: activity.kind,
                size: style.size,
                shape: style.shape,
                isPersistent: activity.mode == .pinned,
                timeout: activity.expiresAt?.timeIntervalSinceNow,
                priority: activity.priority
            )
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

        let spacing = CGFloat(settings.spacing)
        let gap = max(5, spacing)
        let globalVerticalOffset = CGFloat(settings.resolvedVerticalOffset)
        var result: [NotchBubbleKind: CGRect] = [:]

        switch settings.layout {
        case .satellites:
            let totalWidth = bubbles.reduce(CGFloat.zero) { $0 + $1.size }
                + CGFloat(max(0, bubbles.count - 1)) * spacing
            var x = surfaceFrame.midX - totalWidth / 2

            for bubble in bubbles {
                let style = settings.resolvedStyle(for: bubble.kind)
                let size = bubble.size
                let y = surfaceFrame.minY - gap - size - globalVerticalOffset - style.verticalOffset
                let frame = CGRect(x: x, y: y, width: size, height: size)
                result[bubble.kind] = clamped(frame, to: screenFrame)
                x += size + spacing
            }

        case .wings:
            // Wings belong to the menu-bar band, not the expanding body of Halo.
            let menuBarHeight = max(1, compactHeight)
            let menuBarCenterY = screenFrame.maxY - menuBarHeight / 2
            var leftOffset: CGFloat = gap
            var rightOffset: CGFloat = gap

            for (index, bubble) in bubbles.enumerated() {
                let style = settings.resolvedStyle(for: bubble.kind)
                let size = bubble.size
                let y = menuBarCenterY - size / 2 - globalVerticalOffset - style.verticalOffset
                let frame: CGRect

                if index.isMultiple(of: 2) {
                    frame = CGRect(
                        x: surfaceFrame.minX - leftOffset - size,
                        y: y,
                        width: size,
                        height: size
                    )
                    leftOffset += size + spacing
                } else {
                    frame = CGRect(
                        x: surfaceFrame.maxX + rightOffset,
                        y: y,
                        width: size,
                        height: size
                    )
                    rightOffset += size + spacing
                }
                result[bubble.kind] = clamped(frame, to: screenFrame)
            }

        case .stack:
            var yCursor = surfaceFrame.minY - gap - globalVerticalOffset
            for bubble in bubbles {
                let style = settings.resolvedStyle(for: bubble.kind)
                let size = bubble.size
                yCursor -= size + style.verticalOffset
                let frame = CGRect(
                    x: surfaceFrame.midX - size / 2,
                    y: yCursor,
                    width: size,
                    height: size
                )
                result[bubble.kind] = clamped(frame, to: screenFrame)
                yCursor -= spacing
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
        let style = settings.resolvedStyle(for: kind)
        let duration = style.lifecycleDuration

        switch lifecyclePhase {
        case .hidden:
            removalGeneration += 1
            let generation = removalGeneration
            lifecyclePhase = .emerging
            frameAnimator.emerge(
                panel: panel,
                from: emergenceFrame,
                to: frame,
                preset: style.animation,
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
                preset: style.animation,
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
                    preset: style.animation,
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
        let style = settings.resolvedStyle(for: kind)
        frameAnimator.retract(
            panel: panel,
            to: emergenceFrame,
            preset: style.animation,
            duration: style.lifecycleDuration,
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
    private let activityCenter = NotchBubbleActivityCenter.shared
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
            .sink { [weak self] _ in
                self?.activityCenter.clearDismissal(kind: .timer)
                self?.refresh(animated: true)
            }
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
            .sink { [weak self] _ in
                self?.activityCenter.clearDismissal(kind: .music)
                self?.activityCenter.clearDismissal(kind: .vinyl)
                self?.refresh(animated: true)
            }
            .store(in: &subscriptions)

        HaloPixelPalStore.shared.$reaction
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        activityCenter.$transientActivities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        activityCenter.$suppressedKinds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.workspace.calendar.$calendarRevision
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let settings = self.settingsStore.settings.normalized()
                if settings.resolvedCalendarEnabled, self.store.workspace.calendar.hasAccess {
                    self.store.workspace.calendar.refresh()
                }
                self.refresh(animated: false)
            }
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

        if settings.resolvedAudioEnabled || settings.resolvedSystemEnabled ||
            settings.resolvedAudioFeedbackEnabled || settings.resolvedBrightnessFeedbackEnabled {
            store.workspace.audio.refresh()
            store.workspace.system.refresh(detailed: settings.resolvedSystemPersistent)
        }

        if settings.resolvedCalendarEnabled, store.workspace.calendar.hasAccess {
            store.workspace.calendar.refresh()
        }

        let bubbles = registry.bubbles(
            store: store,
            settings: settings,
            runtime: activityCenter,
            surfaceExpanded: state.expanded
        )
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
    private let activityCenter = NotchBubbleActivityCenter.shared
    private var hosts: [String: NotchBubbleDisplayHost] = [:]
    private var commercialAccessGranted = false
    private var subscriptions = Set<AnyCancellable>()

    init(store: AppStore) {
        self.store = store

        NotificationCenter.default.publisher(for: .init("HaloBubbleHUDEvent"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self, let event = note.object as? HaloHUDEvent else { return }
                self.activityCenter.publishHUD(
                    event,
                    settings: self.settingsStore.settings.normalized()
                )
            }
            .store(in: &subscriptions)
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
    @ObservedObject private var clipboard: ClipboardService
    @ObservedObject private var calendar: CalendarService
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
        _clipboard = ObservedObject(wrappedValue: workspace.clipboard)
        _calendar = ObservedObject(wrappedValue: workspace.calendar)
    }

    private var settings: NotchBubbleSettings {
        settingsStore.settings.normalized()
    }

    private var bubbleStyle: ResolvedNotchBubbleStyle {
        settings.resolvedStyle(for: kind)
    }

    var body: some View {
        bubbleContent
            .scaleEffect(bubbleStyle.contentScale)
            .frame(width: bubbleStyle.size, height: bubbleStyle.size)
            .background { bubbleBackground }
            .clipShape(NotchBubbleMaskShape(
                shape: bubbleStyle.shape,
                cornerRadius: bubbleStyle.cornerRadius
            ))
            .contentShape(NotchBubbleMaskShape(
                shape: bubbleStyle.shape,
                cornerRadius: bubbleStyle.cornerRadius
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
            timerBubbleContent
        case .pixelPal:
            pixelPalBubbleContent
        case .clock:
            clockBubbleContent
        case .stopwatch:
            stopwatchBubbleContent
        case .system:
            systemBubbleContent
        case .clipboard:
            clipboardBubbleContent
        case .calendar:
            calendarBubbleContent
        case .audio:
            audioBubbleContent
        case .vinyl:
            vinylBubbleContent
        }
    }

    @ViewBuilder
    private var timerBubbleContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let mode = settings.resolvedTimerDisplayMode
            let remaining = timerRemaining(at: timeline.date)

            ZStack {
                switch mode {
                case .ring:
                    timerProgressRing(at: timeline.date)
                    if timerIsActive {
                        Text(compactTimerText(at: timeline.date))
                            .font(.system(size: max(8, bubbleStyle.size * 0.20), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.55)
                            .lineLimit(1)
                            .padding(5)
                    } else {
                        Image(systemName: store.finished ? "checkmark" : "timer")
                            .font(.system(size: bubbleStyle.size * 0.34, weight: .semibold))
                    }

                case .digits:
                    Text(timerIsActive ? compactTimerText(at: timeline.date) : (store.finished ? "DONE" : "—"))
                        .font(.system(size: max(9, bubbleStyle.size * 0.25), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.42)
                        .lineLimit(1)
                        .padding(4)

                case .arc:
                    Circle()
                        .trim(from: 0.10, to: 0.90)
                        .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                        .rotationEffect(.degrees(108))
                        .padding(3)
                    Circle()
                        .trim(
                            from: 0.10,
                            to: 0.10 + 0.80 * timerProgress(at: timeline.date)
                        )
                        .stroke(
                            store.finished ? Color.green : providerAccentColor,
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(108))
                        .padding(3)
                    VStack(spacing: 0) {
                        Image(systemName: store.finished ? "checkmark" : "timer")
                            .font(.system(size: bubbleStyle.size * 0.20, weight: .bold))
                        if timerIsActive {
                            Text(shortMinuteValue(remaining))
                                .font(.system(size: max(7, bubbleStyle.size * 0.13), weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }

                case .icon:
                    Image(systemName: store.finished ? "checkmark.circle.fill" : "timer")
                        .font(.system(size: bubbleStyle.size * 0.40, weight: .semibold))
                }
            }
            .foregroundStyle(store.finished ? Color.green : Color.white)
        }
    }

    @ViewBuilder
    private var pixelPalBubbleContent: some View {
        switch settings.resolvedPixelPalDisplayMode {
        case .full:
            HaloPixelPetWidget(store: store, workspace: workspace)
                .environment(\.haloPixelPalHostExpanded, true)
                .environment(\.haloPixelPalHostTransitionDuration, 0.16)
                .padding(2)

        case .closeUp:
            HaloPixelPetWidget(store: store, workspace: workspace)
                .environment(\.haloPixelPalHostExpanded, true)
                .environment(\.haloPixelPalHostTransitionDuration, 0.16)
                .scaleEffect(1.30)
                .padding(-3)

        case .icon:
            Image(systemName: "face.smiling.inverse")
                .font(.system(size: bubbleStyle.size * 0.42, weight: .bold))
                .foregroundStyle(providerAccentColor)
        }
    }

    @ViewBuilder
    private var clockBubbleContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            switch settings.resolvedClockDisplayMode {
            case .digital:
                VStack(spacing: 0) {
                    Text(clockTime(timeline.date))
                        .font(.system(size: max(9, bubbleStyle.size * 0.22), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.52)
                        .lineLimit(1)
                    Text(clockDay(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.105), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(4)

            case .seconds:
                VStack(spacing: 0) {
                    Text(clockTimeWithSeconds(timeline.date))
                        .font(.system(size: max(8, bubbleStyle.size * 0.19), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.42)
                        .lineLimit(1)
                    Text(clockDay(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.10), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(3)

            case .analog:
                analogClock(date: timeline.date)

            case .date:
                VStack(spacing: -1) {
                    Text(dayNumber(timeline.date))
                        .font(.system(size: max(13, bubbleStyle.size * 0.34), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(monthAbbreviation(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.105), weight: .bold, design: .rounded))
                        .foregroundStyle(providerAccentColor)
                    Text(clockTime(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.095), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var stopwatchBubbleContent: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
            let elapsed = stopwatchElapsed(at: timeline.date)
            switch settings.resolvedStopwatchDisplayMode {
            case .compact:
                VStack(spacing: 1) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: bubbleStyle.size * 0.23, weight: .semibold))
                    Text(shortElapsed(elapsed))
                        .font(.system(size: max(7, bubbleStyle.size * 0.145), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                }

            case .digits:
                Text(shortElapsed(elapsed))
                    .font(.system(size: max(9, bubbleStyle.size * 0.25), weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.44)
                    .lineLimit(1)
                    .padding(4)

            case .ring:
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 2.7)
                        .padding(3)
                    Circle()
                        .trim(from: 0, to: (elapsed.truncatingRemainder(dividingBy: 60)) / 60)
                        .stroke(providerAccentColor, style: StrokeStyle(lineWidth: 2.7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(3)
                    Text(shortElapsed(elapsed))
                        .font(.system(size: max(7, bubbleStyle.size * 0.15), weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                }

            case .laps:
                VStack(spacing: 1) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: bubbleStyle.size * 0.23, weight: .semibold))
                    Text("\(workspace.stopwatchLaps.count)")
                        .font(.system(size: max(10, bubbleStyle.size * 0.25), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var clipboardBubbleContent: some View {
        switch settings.resolvedClipboardDisplayMode {
        case .icon:
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: bubbleStyle.size * 0.36, weight: .semibold))
                .foregroundStyle(.white)

        case .preview:
            if let text = clipboard.entries.first?.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: max(6, bubbleStyle.size * 0.12), weight: .semibold, design: .rounded))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.62)
                    .foregroundStyle(.white)
                    .padding(5)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: bubbleStyle.size * 0.34, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

        case .count:
            VStack(spacing: 0) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: bubbleStyle.size * 0.20, weight: .semibold))
                Text("\(clipboard.entries.count)")
                    .font(.system(size: max(11, bubbleStyle.size * 0.29), weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var calendarBubbleContent: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            switch settings.resolvedCalendarDisplayMode {
            case .date:
                VStack(spacing: -1) {
                    Text(monthAbbreviation(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.11), weight: .bold, design: .rounded))
                        .foregroundStyle(providerAccentColor)
                    Text(dayNumber(timeline.date))
                        .font(.system(size: max(12, bubbleStyle.size * 0.34), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

            case .weekday:
                VStack(spacing: -1) {
                    Text(clockDay(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.10), weight: .bold, design: .rounded))
                        .foregroundStyle(providerAccentColor)
                    Text(dayNumber(timeline.date))
                        .font(.system(size: max(12, bubbleStyle.size * 0.33), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(monthAbbreviation(timeline.date))
                        .font(.system(size: max(6, bubbleStyle.size * 0.095), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.white)

            case .nextEvent:
                if let event = calendar.upcomingEvents.first {
                    VStack(spacing: 1) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: bubbleStyle.size * 0.19, weight: .semibold))
                            .foregroundStyle(providerAccentColor)
                        Text(eventTime(event.startDate))
                            .font(.system(size: max(7, bubbleStyle.size * 0.14), weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(event.title ?? "Event")
                            .font(.system(size: max(5, bubbleStyle.size * 0.09), weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                    .foregroundStyle(.white)
                    .padding(3)
                } else {
                    VStack(spacing: 1) {
                        Image(systemName: "calendar")
                            .font(.system(size: bubbleStyle.size * 0.25, weight: .semibold))
                        Text("Free")
                            .font(.system(size: max(7, bubbleStyle.size * 0.13), weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var audioBubbleContent: some View {
        let level = audio.canSetVolume ? min(1, max(0, Double(audio.volume))) : 0

        switch settings.resolvedAudioDisplayMode {
        case .ring:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 2.6)
                    .padding(3)
                Circle()
                    .trim(from: 0, to: level)
                    .stroke(providerAccentColor, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                Image(systemName: audioSymbol)
                    .font(.system(size: bubbleStyle.size * 0.27, weight: .semibold))
            }
            .foregroundStyle(.white)

        case .percentage:
            VStack(spacing: 0) {
                Text("\(Int((level * 100).rounded()))")
                    .font(.system(size: max(12, bubbleStyle.size * 0.31), weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: max(6, bubbleStyle.size * 0.10), weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)

        case .icon:
            Image(systemName: audioSymbol)
                .font(.system(size: bubbleStyle.size * 0.39, weight: .semibold))
                .foregroundStyle(.white)

        case .device:
            VStack(spacing: 1) {
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: bubbleStyle.size * 0.20, weight: .semibold))
                    .foregroundStyle(providerAccentColor)
                Text(currentAudioDeviceName)
                    .font(.system(size: max(5, bubbleStyle.size * 0.10), weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.52)
                    .foregroundStyle(.white)
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private var vinylBubbleContent: some View {
        let size = Double(max(18, bubbleStyle.size * 0.98))

        switch settings.resolvedVinylDisplayMode {
        case .fullRecord:
            VinylRecordView(
                artwork: media.artworkImage,
                size: size,
                palette: media.artworkColors,
                playing: media.isPlaying,
                lowPower: system.lowPower,
                interactive: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .labelFocus:
            VinylRecordView(
                artwork: media.artworkImage,
                size: size * 1.52,
                palette: media.artworkColors,
                playing: media.isPlaying,
                lowPower: system.lowPower,
                interactive: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

        case .recordProgress:
            ZStack {
                VinylRecordView(
                    artwork: media.artworkImage,
                    size: size * 0.88,
                    palette: media.artworkColors,
                    playing: media.isPlaying,
                    lowPower: system.lowPower,
                    interactive: false
                )
                musicProgressRing
            }
        }
    }

    @ViewBuilder
    private var musicBubbleContent: some View {
        let mode = settings.resolvedMusicDisplayMode
        ZStack {
            if mode == .icon || media.artworkImage == nil || !media.isPlaying {
                Image(systemName: media.isPlaying ? "music.note" : "music.note.list")
                    .font(.system(size: bubbleStyle.size * 0.36, weight: .semibold))
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
                        .font(.system(size: bubbleStyle.size * 0.28, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }

            if mode == .artworkProgress {
                musicProgressRing
            }

            if settings.resolvedMusicShowPlaybackGlyph && mode != .controls {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: bubbleStyle.size * 0.20, weight: .bold))
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
        let level = systemMetricFraction(metric)

        switch settings.resolvedSystemDisplayMode {
        case .value:
            VStack(spacing: 1) {
                Image(systemName: systemMetricSymbol(metric))
                    .font(.system(size: bubbleStyle.size * 0.23, weight: .semibold))
                    .foregroundStyle(providerAccentColor)
                Text(systemMetricValue(metric))
                    .font(.system(size: max(7, bubbleStyle.size * 0.14), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(.white)
            .padding(3)

        case .gauge:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 3)
                    .padding(3)
                Circle()
                    .trim(from: 0, to: level)
                    .stroke(
                        providerAccentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                Text(systemMetricCompactValue(metric))
                    .font(.system(size: max(7, bubbleStyle.size * 0.15), weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .padding(6)
            }

        case .bars:
            VStack(spacing: 2) {
                HStack(alignment: .bottom, spacing: max(1.5, bubbleStyle.size * 0.045)) {
                    ForEach(0..<5, id: \.self) { index in
                        let threshold = Double(index + 1) / 5.0
                        Capsule()
                            .fill(level >= threshold ? providerAccentColor : Color.white.opacity(0.10))
                            .frame(
                                width: max(2.5, bubbleStyle.size * 0.065),
                                height: bubbleStyle.size * (0.13 + CGFloat(index) * 0.055)
                            )
                    }
                }
                Text(systemMetricCompactValue(metric))
                    .font(.system(size: max(6, bubbleStyle.size * 0.11), weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

        case .icon:
            Image(systemName: systemMetricSymbol(metric))
                .font(.system(size: bubbleStyle.size * 0.39, weight: .semibold))
                .foregroundStyle(providerAccentColor)
        }
    }

    private var providerAccentColor: Color {
        if let custom = bubbleStyle.tint { return custom }
        switch kind {
        case .music, .vinyl:
            return media.artworkColors.first?.color ?? Color(red: 0.42, green: 0.48, blue: 1.0)
        case .timer:
            return store.finished ? .green : Color(red: 0.30, green: 0.62, blue: 1.0)
        case .pixelPal:
            return Color(red: 1.0, green: 0.42, blue: 0.66)
        case .clock:
            return Color(red: 0.34, green: 0.72, blue: 1.0)
        case .stopwatch:
            return Color(red: 1.0, green: 0.58, blue: 0.22)
        case .system:
            return Color(red: 0.33, green: 0.88, blue: 0.77)
        case .clipboard:
            return Color(red: 0.65, green: 0.46, blue: 1.0)
        case .calendar:
            return Color(red: 1.0, green: 0.34, blue: 0.38)
        case .audio:
            return Color(red: 0.26, green: 0.66, blue: 1.0)
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        let shape = NotchBubbleMaskShape(
            shape: bubbleStyle.shape,
            cornerRadius: bubbleStyle.cornerRadius
        )
        let accent = providerAccentColor
        let customTint = bubbleStyle.tint ?? accent
        let tintAmount = max(bubbleStyle.tintAmount, bubbleStyle.tint == nil ? 0 : bubbleStyle.tintAmount)

        switch bubbleStyle.design {
        case .halo:
            switch bubbleStyle.background {
            case .solid:
                shape
                    .fill(Color.black.opacity(bubbleStyle.backgroundOpacity))
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    .overlay {
                        if tintAmount > 0 { shape.fill(customTint.opacity(tintAmount)) }
                    }

            case .glass:
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(bubbleStyle.glassIntensity)
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    Color.black.opacity(0.26 * bubbleStyle.backgroundOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    .overlay {
                        if tintAmount > 0 { shape.fill(customTint.opacity(tintAmount)) }
                    }

            case .clear:
                shape
                    .fill(Color.clear)
                    .overlay {
                        if tintAmount > 0 { shape.fill(customTint.opacity(tintAmount)) }
                    }
            }

        case .aurora:
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.94),
                            Color(red: 0.45, green: 0.28, blue: 0.96).opacity(0.92),
                            Color(red: 0.16, green: 0.72, blue: 0.92).opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    shape.fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.24), Color.clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: bubbleStyle.size * 0.72
                        )
                    )
                }

        case .neon:
            shape
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.22),
                            Color.black.opacity(0.94)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: bubbleStyle.size * 0.58
                    )
                )
                .overlay {
                    shape
                        .stroke(accent.opacity(0.92), lineWidth: 1.8)
                        .padding(1.5)
                }
                .overlay {
                    shape
                        .stroke(accent.opacity(0.28), lineWidth: 5)
                        .blur(radius: 3)
                        .padding(3)
                        .clipShape(shape)
                }

        case .obsidian:
            shape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color(red: 0.08, green: 0.085, blue: 0.10),
                            Color.black.opacity(0.98)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: bubbleStyle.size * 0.82
                    )
                )
                .overlay {
                    shape.fill(accent.opacity(0.08))
                }

        case .prism:
            shape
                .fill(.ultraThinMaterial)
                .opacity(max(0.60, bubbleStyle.glassIntensity))
                .overlay {
                    shape.fill(
                        AngularGradient(
                            colors: [
                                Color(red: 1.0, green: 0.34, blue: 0.65).opacity(0.36),
                                Color(red: 0.54, green: 0.38, blue: 1.0).opacity(0.42),
                                Color(red: 0.20, green: 0.76, blue: 1.0).opacity(0.38),
                                Color(red: 0.22, green: 0.92, blue: 0.72).opacity(0.28),
                                Color(red: 1.0, green: 0.34, blue: 0.65).opacity(0.36)
                            ],
                            center: .center
                        )
                    )
                }
                .overlay {
                    shape.fill(Color.black.opacity(0.20))
                }

        case .ember:
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.30, blue: 0.16),
                            Color(red: 0.72, green: 0.10, blue: 0.16),
                            Color(red: 0.16, green: 0.035, blue: 0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    shape.fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.32), Color.clear],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: bubbleStyle.size * 0.70
                        )
                    )
                }

        case .midnight:
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.18, blue: 0.38),
                            Color(red: 0.035, green: 0.065, blue: 0.15),
                            Color.black.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    shape.fill(accent.opacity(0.13))
                }

        case .minimal:
            shape
                .fill(Color.black.opacity(0.16 * bubbleStyle.backgroundOpacity))
                .overlay {
                    shape.fill(accent.opacity(0.045))
                }
        }
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        let shape = NotchBubbleMaskShape(
            shape: bubbleStyle.shape,
            cornerRadius: bubbleStyle.cornerRadius
        )
        let accent = providerAccentColor

        switch bubbleStyle.design {
        case .halo:
            shape.stroke(
                Color.white.opacity(min(1, bubbleStyle.borderOpacity * (hovering ? 1.8 : 1.0))),
                lineWidth: bubbleStyle.borderOpacity > 0 ? 1 : 0
            )
        case .aurora:
            shape.stroke(Color.white.opacity(hovering ? 0.42 : 0.22), lineWidth: 1)
        case .neon:
            shape.stroke(accent.opacity(hovering ? 1.0 : 0.80), lineWidth: hovering ? 2.4 : 1.8)
        case .obsidian:
            shape.stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        case .prism:
            shape.stroke(
                AngularGradient(
                    colors: [
                        Color.pink.opacity(hovering ? 0.72 : 0.42),
                        Color.purple.opacity(hovering ? 0.72 : 0.42),
                        Color.blue.opacity(hovering ? 0.72 : 0.42),
                        Color.cyan.opacity(hovering ? 0.72 : 0.42),
                        Color.pink.opacity(hovering ? 0.72 : 0.42)
                    ],
                    center: .center
                ),
                lineWidth: 1.2
            )
        case .ember:
            shape.stroke(Color.orange.opacity(hovering ? 0.82 : 0.42), lineWidth: 1.1)
        case .midnight:
            shape.stroke(Color.blue.opacity(hovering ? 0.65 : 0.26), lineWidth: 1)
        case .minimal:
            shape.stroke(Color.white.opacity(hovering ? 0.38 : 0.18), lineWidth: 0.8)
        }
    }

    private var hoverAnimation: Animation? {
        switch bubbleStyle.animation {
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
        case .vinyl:
            vinylDetail
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

    private var vinylDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                VinylRecordView(
                    artwork: media.artworkImage,
                    size: 92,
                    palette: media.artworkColors,
                    playing: media.isPlaying,
                    lowPower: system.lowPower,
                    interactive: true
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(media.isPlaying ? media.title : "Vinyl")
                        .font(.headline)
                        .lineLimit(1)
                    Text(media.isPlaying ? media.artist : "Uses Halo's shared Vinyl Studio style")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack {
                Button("Vinyl Studio…") {
                    VinylStyleWindowController.shared.show()
                }
                Button(media.isPlaying ? "Pause" : "Play") {
                    mediaCommand("playpause")
                }
                Spacer()
                Button("Open Notch") { openNotch() }
            }
            .buttonStyle(.borderless)

            Text("This is the same VinylStyleStore used by Halo's Audio/Music CI and other vinyl surfaces.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        case .vinyl: return 360
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

    private func timerProgress(at date: Date) -> CGFloat {
        if store.finished { return 1 }
        guard timerIsActive else { return 0 }
        let duration = max(1, store.timerDurationSeconds)
        return CGFloat(min(1, max(0, timerRemaining(at: date) / duration)))
    }

    private func shortMinuteValue(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        if seconds >= 3600 { return "\(seconds / 3600)h" }
        if seconds >= 60 { return "\(max(1, seconds / 60))m" }
        return "\(seconds)s"
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
        formatter.dateFormat = settings.resolvedClockUse24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    private func clockTimeWithSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = settings.resolvedClockUse24Hour ? "HH:mm:ss" : "h:mm:ss"
        return formatter.string(from: date)
    }

    private func eventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = settings.resolvedClockUse24Hour ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    private func analogClock(date: Date) -> some View {
        let calendar = Calendar.autoupdatingCurrent
        let hour = Double(calendar.component(.hour, from: date) % 12)
        let minute = Double(calendar.component(.minute, from: date))
        let second = Double(calendar.component(.second, from: date))
        let hourAngle = (hour + minute / 60) * 30
        let minuteAngle = (minute + second / 60) * 6
        let secondAngle = second * 6

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)

            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? Color.white.opacity(0.72) : Color.white.opacity(0.30))
                    .frame(width: index.isMultiple(of: 3) ? 1.8 : 1.0, height: index.isMultiple(of: 3) ? 4.5 : 3)
                    .offset(y: -bubbleStyle.size * 0.37)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            Capsule()
                .fill(Color.white.opacity(0.92))
                .frame(width: 2.2, height: bubbleStyle.size * 0.22)
                .offset(y: -bubbleStyle.size * 0.10)
                .rotationEffect(.degrees(hourAngle))

            Capsule()
                .fill(Color.white)
                .frame(width: 1.7, height: bubbleStyle.size * 0.29)
                .offset(y: -bubbleStyle.size * 0.14)
                .rotationEffect(.degrees(minuteAngle))

            Capsule()
                .fill(providerAccentColor)
                .frame(width: 1.0, height: bubbleStyle.size * 0.31)
                .offset(y: -bubbleStyle.size * 0.15)
                .rotationEffect(.degrees(secondAngle))

            Circle()
                .fill(providerAccentColor)
                .frame(width: 4.5, height: 4.5)
        }
        .padding(5)
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

    private var currentAudioDeviceName: String {
        audio.devices.first(where: { $0.id == audio.selected })?.name ?? "Output"
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

    private func systemMetricFraction(_ metric: SystemBubbleMetric) -> Double {
        switch metric {
        case .battery:
            return min(1, max(0, Double(system.battery ?? 0) / 100))
        case .cpu:
            return min(1, max(0, system.cpuUsage / 100))
        case .memory:
            return min(1, max(0, system.memoryUsage / 100))
        case .storage:
            return min(1, max(0, system.diskUsage / 100))
        case .network:
            let total = system.networkDownPerSecond + system.networkUpPerSecond
            return min(1, max(0, total / 20_000_000))
        }
    }

    private func systemMetricCompactValue(_ metric: SystemBubbleMetric) -> String {
        switch metric {
        case .battery:
            return system.battery.map { "\($0)" } ?? "—"
        case .cpu:
            return String(format: "%.0f", system.cpuUsage)
        case .memory:
            return String(format: "%.0f", system.memoryUsage)
        case .storage:
            return String(format: "%.0f", system.diskUsage)
        case .network:
            let total = system.networkDownPerSecond + system.networkUpPerSecond
            if total < 1_000_000 { return String(format: "%.0fK", total / 1_000) }
            return String(format: "%.1fM", total / 1_000_000)
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
        case .music, .vinyl:
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
        case .vinyl:
            return media.isPlaying ? "Vinyl · \(media.title)" : "Vinyl"
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

        Section("Vinyl bubble") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shared Vinyl Studio")
                        .font(.headline)
                    Text("Uses the exact same vinyl style as Halo's Audio/Music CI and other record surfaces.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Vinyl Studio…") {
                    VinylStyleWindowController.shared.show()
                }
            }

            Text("Preset, disc color, album-color palette, grooves, label artwork, gloss, glow, RPM and reverse all come from VinylStyleStore.shared.")
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
            providerRow(
                title: "Vinyl",
                symbol: "record.circle.fill",
                enabled: optionalBinding(\.vinylEnabled, default: false),
                persistent: optionalBinding(\.vinylPersistent, default: false),
                detail: "A live record using Halo's shared Vinyl Studio configuration. Normally appears while media is playing."
            )

            Text("New bubble types are off by default so existing setups keep their current layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Per-bubble design & content") {
            Text("Every provider inherits the global bubble style until you override it here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(NotchBubbleKind.allCases) { kind in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        bubbleContentEditor(kind)
                        Divider()
                        bubbleStyleEditor(kind)
                    }
                    .padding(.top, 6)
                } label: {
                    Label(kind.title, systemImage: kind.symbol)
                }
            }

            Button("Reset all bubble appearance overrides") {
                var next = settingsStore.settings
                next.bubbleStyles = nil
                settingsStore.settings = next.normalized()
            }
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
            Text("Priority decides which bubbles stay visible when more providers are active than the selected capacity.")
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
    private func bubbleContentEditor(_ kind: NotchBubbleKind) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Content")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            switch kind {
            case .music:
                Picker("Display", selection: optionalBinding(\.musicDisplayMode, default: MusicBubbleDisplayMode.artwork)) {
                    ForEach(MusicBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Toggle(
                    "Playback glyph",
                    isOn: optionalBinding(\.musicShowPlaybackGlyph, default: false)
                )
                .disabled(settings.resolvedMusicDisplayMode == .controls)

                if settings.resolvedMusicDisplayMode != .icon {
                    LabeledContent("Artwork zoom") {
                        HStack {
                            Slider(
                                value: optionalBinding(\.musicArtworkZoom, default: 1.0),
                                in: 1.0...1.8,
                                step: 0.05
                            )
                            .frame(width: 180)
                            Text(String(format: "%.2fx", settings.resolvedMusicArtworkZoom))
                                .font(.caption.monospacedDigit())
                                .frame(width: 46, alignment: .trailing)
                        }
                    }
                }

                Picker("Click", selection: optionalBinding(\.musicTapAction, default: MusicBubbleTapAction.details)) {
                    ForEach(MusicBubbleTapAction.allCases) { action in
                        Text(action.rawValue).tag(action)
                    }
                }

            case .timer:
                Picker("Display", selection: optionalBinding(\.timerDisplayMode, default: TimerBubbleDisplayMode.ring)) {
                    ForEach(TimerBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .pixelPal:
                Picker("Display", selection: optionalBinding(\.pixelPalDisplayMode, default: PixelPalBubbleDisplayMode.full)) {
                    ForEach(PixelPalBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .clock:
                Picker("Display", selection: optionalBinding(\.clockDisplayMode, default: ClockBubbleDisplayMode.digital)) {
                    ForEach(ClockBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Toggle("24-hour time", isOn: optionalBinding(\.clockUse24Hour, default: false))

            case .stopwatch:
                Picker("Display", selection: optionalBinding(\.stopwatchDisplayMode, default: StopwatchBubbleDisplayMode.compact)) {
                    ForEach(StopwatchBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .system:
                Picker("Metric", selection: optionalBinding(\.systemMetric, default: SystemBubbleMetric.battery)) {
                    ForEach(SystemBubbleMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                Picker("Display", selection: optionalBinding(\.systemDisplayMode, default: SystemBubbleDisplayMode.value)) {
                    ForEach(SystemBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .clipboard:
                Picker("Display", selection: optionalBinding(\.clipboardDisplayMode, default: ClipboardBubbleDisplayMode.icon)) {
                    ForEach(ClipboardBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .calendar:
                Picker("Display", selection: optionalBinding(\.calendarDisplayMode, default: CalendarBubbleDisplayMode.date)) {
                    ForEach(CalendarBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .audio:
                Picker("Display", selection: optionalBinding(\.audioDisplayMode, default: AudioBubbleDisplayMode.ring)) {
                    ForEach(AudioBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .vinyl:
                Picker("Display", selection: optionalBinding(\.vinylDisplayMode, default: VinylBubbleDisplayMode.fullRecord)) {
                    ForEach(VinylBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                HStack {
                    Text("Record appearance comes from the shared Vinyl Studio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Vinyl Studio…") { VinylStyleWindowController.shared.show() }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    @ViewBuilder
    private func bubbleStyleEditor(_ kind: NotchBubbleKind) -> some View {
        let override = currentStyleOverride(for: kind)
        let resolved = settings.resolvedStyle(for: kind)
        let globalBackground: NotchBubbleBackgroundStyle = settings.shape == .glass ? .glass : .solid

        VStack(alignment: .leading, spacing: 10) {
            Text("Design")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("Style", selection: styleOptionalBinding(kind, \.design)) {
                Text("Default · Halo Glass")
                    .tag(nil as NotchBubbleDesignPreset?)
                ForEach(NotchBubbleDesignPreset.allCases) { preset in
                    Text(preset.rawValue).tag(Optional(preset))
                }
            }

            Text(resolved.design.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "Custom size",
                isOn: styleOverrideEnabledBinding(kind, \.size, default: settings.bubbleSize)
            )
            if override.size != nil {
                LabeledContent("Size") {
                    HStack {
                        Slider(
                            value: styleValueBinding(kind, \.size, default: settings.bubbleSize),
                            in: 20...96,
                            step: 1
                        )
                        .frame(width: 190)
                        Text("\(Int(resolved.size)) pt")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Picker("Shape", selection: styleOptionalBinding(kind, \.shape)) {
                Text("Global · \(settings.shape.rawValue)")
                    .tag(nil as NotchBubbleShape?)
                ForEach(NotchBubbleShape.allCases) { shape in
                    Text(shape.rawValue).tag(Optional(shape))
                }
            }

            Picker("Background", selection: styleOptionalBinding(kind, \.background)) {
                Text("Global · \(globalBackground.rawValue)")
                    .tag(nil as NotchBubbleBackgroundStyle?)
                ForEach(NotchBubbleBackgroundStyle.allCases) { style in
                    Text(style.rawValue).tag(Optional(style))
                }
            }

            Toggle(
                "Custom corner radius",
                isOn: styleOverrideEnabledBinding(kind, \.cornerRadius, default: settings.cornerRadius)
            )
            if override.cornerRadius != nil {
                LabeledContent("Corner radius") {
                    Slider(
                        value: styleValueBinding(kind, \.cornerRadius, default: settings.cornerRadius),
                        in: 0...48,
                        step: 1
                    )
                    .frame(width: 238)
                }
            }

            if resolved.background == .glass {
                Toggle(
                    "Custom glass intensity",
                    isOn: styleOverrideEnabledBinding(kind, \.glassIntensity, default: settings.glassIntensity)
                )
                if override.glassIntensity != nil {
                    LabeledContent("Glass intensity") {
                        Slider(
                            value: styleValueBinding(kind, \.glassIntensity, default: settings.glassIntensity),
                            in: 0.05...1,
                            step: 0.05
                        )
                        .frame(width: 238)
                    }
                }
            }

            Toggle(
                "Custom background opacity",
                isOn: styleOverrideEnabledBinding(kind, \.backgroundOpacity, default: 0.88)
            )
            if override.backgroundOpacity != nil {
                LabeledContent("Background opacity") {
                    Slider(
                        value: styleValueBinding(kind, \.backgroundOpacity, default: 0.88),
                        in: 0...1,
                        step: 0.05
                    )
                    .frame(width: 238)
                }
            }

            Toggle(
                "Custom border",
                isOn: styleOverrideEnabledBinding(kind, \.borderOpacity, default: 0.12)
            )
            if override.borderOpacity != nil {
                LabeledContent("Border opacity") {
                    Slider(
                        value: styleValueBinding(kind, \.borderOpacity, default: 0.12),
                        in: 0...1,
                        step: 0.05
                    )
                    .frame(width: 238)
                }
            }

            Toggle(
                "Custom tint",
                isOn: styleOverrideEnabledBinding(
                    kind,
                    \.tint,
                    default: WidgetColor(red: 0.20, green: 0.52, blue: 1.0)
                )
            )
            if override.tint != nil {
                ColorPicker(
                    "Tint color",
                    selection: Binding(
                        get: {
                            currentStyleOverride(for: kind).tint?.color
                                ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0).color
                        },
                        set: { color in
                            mutateStyleOverride(for: kind) {
                                $0.tint = WidgetColor(color)
                                if $0.tintAmount == nil { $0.tintAmount = 0.22 }
                            }
                        }
                    ),
                    supportsOpacity: false
                )

                LabeledContent("Tint strength") {
                    Slider(
                        value: styleValueBinding(kind, \.tintAmount, default: 0.22),
                        in: 0...1,
                        step: 0.05
                    )
                    .frame(width: 238)
                }
            }

            Toggle(
                "Custom content scale",
                isOn: styleOverrideEnabledBinding(kind, \.contentScale, default: 1.0)
            )
            if override.contentScale != nil {
                LabeledContent("Content scale") {
                    HStack {
                        Slider(
                            value: styleValueBinding(kind, \.contentScale, default: 1.0),
                            in: 0.55...1.6,
                            step: 0.05
                        )
                        .frame(width: 190)
                        Text(String(format: "%.2fx", resolved.contentScale))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Toggle(
                "Custom vertical offset",
                isOn: styleOverrideEnabledBinding(kind, \.verticalOffset, default: 0.0)
            )
            if override.verticalOffset != nil {
                LabeledContent("Vertical offset") {
                    HStack {
                        Slider(
                            value: styleValueBinding(kind, \.verticalOffset, default: 0.0),
                            in: -120...120,
                            step: 1
                        )
                        .frame(width: 190)
                        Text(String(format: "%+.0f", resolved.verticalOffset))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Picker("Motion", selection: styleOptionalBinding(kind, \.animation)) {
                Text("Global · \(settings.animation.rawValue)")
                    .tag(nil as NotchBubbleAnimationPreset?)
                ForEach(NotchBubbleAnimationPreset.allCases) { preset in
                    Text(preset.rawValue).tag(Optional(preset))
                }
            }

            Toggle(
                "Custom lifecycle duration",
                isOn: styleOverrideEnabledBinding(kind, \.lifecycleDuration, default: settings.resolvedLifecycleDuration)
            )
            if override.lifecycleDuration != nil {
                LabeledContent("Lifecycle duration") {
                    HStack {
                        Slider(
                            value: styleValueBinding(kind, \.lifecycleDuration, default: settings.resolvedLifecycleDuration),
                            in: 0.10...1.50,
                            step: 0.05
                        )
                        .frame(width: 190)
                        Text(String(format: "%.2f s", resolved.lifecycleDuration))
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }

            HStack {
                Text("Resolved: \(Int(resolved.size)) pt · \(resolved.shape.rawValue) · \(resolved.background.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset") {
                    resetStyleOverride(for: kind)
                }
                .buttonStyle(.borderless)
                .disabled(override.isEmpty)
            }
        }
        .padding(.leading, 4)
    }

    private func currentStyleOverride(for kind: NotchBubbleKind) -> NotchBubbleStyleOverride {
        settingsStore.settings.bubbleStyles?[kind.rawValue]?.normalized() ?? NotchBubbleStyleOverride()
    }

    private func mutateStyleOverride(
        for kind: NotchBubbleKind,
        _ mutation: (inout NotchBubbleStyleOverride) -> Void
    ) {
        var next = settingsStore.settings
        var styles = next.bubbleStyles ?? [:]
        var override = styles[kind.rawValue]?.normalized() ?? NotchBubbleStyleOverride()
        mutation(&override)
        override = override.normalized()
        if override.isEmpty {
            styles.removeValue(forKey: kind.rawValue)
        } else {
            styles[kind.rawValue] = override
        }
        next.bubbleStyles = styles.isEmpty ? nil : styles
        settingsStore.settings = next.normalized()
    }

    private func resetStyleOverride(for kind: NotchBubbleKind) {
        var next = settingsStore.settings
        guard var styles = next.bubbleStyles else { return }
        styles.removeValue(forKey: kind.rawValue)
        next.bubbleStyles = styles.isEmpty ? nil : styles
        settingsStore.settings = next.normalized()
    }

    private func styleOptionalBinding<T>(
        _ kind: NotchBubbleKind,
        _ keyPath: WritableKeyPath<NotchBubbleStyleOverride, T?>
    ) -> Binding<T?> {
        Binding(
            get: { currentStyleOverride(for: kind)[keyPath: keyPath] },
            set: { value in
                mutateStyleOverride(for: kind) { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func styleValueBinding<T>(
        _ kind: NotchBubbleKind,
        _ keyPath: WritableKeyPath<NotchBubbleStyleOverride, T?>,
        default defaultValue: T
    ) -> Binding<T> {
        Binding(
            get: { currentStyleOverride(for: kind)[keyPath: keyPath] ?? defaultValue },
            set: { value in
                mutateStyleOverride(for: kind) { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func styleOverrideEnabledBinding<T>(
        _ kind: NotchBubbleKind,
        _ keyPath: WritableKeyPath<NotchBubbleStyleOverride, T?>,
        default defaultValue: T
    ) -> Binding<Bool> {
        Binding(
            get: { currentStyleOverride(for: kind)[keyPath: keyPath] != nil },
            set: { enabled in
                mutateStyleOverride(for: kind) {
                    $0[keyPath: keyPath] = enabled ? defaultValue : nil
                }
            }
        )
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
