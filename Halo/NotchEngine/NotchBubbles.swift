import AppKit
import ApplicationServices
import Combine
import EventKit
import QuartzCore
import CoreImage
import CoreMedia
import ScreenCaptureKit
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
    case files
    case appWindow

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
        case .files: return "File Shelf"
        case .appWindow: return "App Window"
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
        case .files: return "tray.full.fill"
        case .appWindow: return "macwindow"
        }
    }

    /// Stable tie-breaker only. Explicit priority and presentation mode always win first.
    var policyRank: Int {
        switch self {
        case .appWindow: return 0
        case .timer: return 1
        case .calendar: return 2
        case .files: return 3
        case .stopwatch: return 4
        case .music: return 5
        case .vinyl: return 6
        case .audio: return 7
        case .system: return 8
        case .clipboard: return 9
        case .clock: return 10
        case .pixelPal: return 11
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

enum NotchBubbleSide: String, Codable, CaseIterable, Identifiable, Hashable {
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

enum NotchBubbleSideMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case automatic = "Auto"
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }
}

enum AppWindowBubblePlacement: String, Codable, CaseIterable, Identifiable, Hashable {
    case left = "Left"
    case right = "Right"
    case belowNotch = "Below Notch"

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

enum NotchBubbleGestureMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case once = "Once per Gesture"
    case continuous = "Continuous"

    var id: String { rawValue }
}

enum NotchBubbleGestureAction: String, Codable, CaseIterable, Identifiable, Hashable {
    case none = "None"
    case primaryAction = "Primary Action"
    case showDetails = "Show Details"
    case openNotch = "Open Notch"
    case dismiss = "Dismiss Bubble"

    case playPause = "Play / Pause"
    case previousTrack = "Previous Track"
    case nextTrack = "Next Track"
    case openMediaPlayer = "Open Media App"
    case seekBackward = "Seek Backward"
    case seekForward = "Seek Forward"

    case timerPauseResume = "Timer Pause / Resume"
    case timerAddFive = "Timer +5 Minutes"

    case stopwatchToggle = "Stopwatch Start / Pause"
    case stopwatchLap = "Stopwatch Lap"
    case stopwatchReset = "Stopwatch Reset"

    case audioVolumeUp = "Volume Up"
    case audioVolumeDown = "Volume Down"
    case audioMuteRestore = "Mute / Restore Volume"
    case openSoundSettings = "Open Sound Settings"

    case refreshSystem = "Refresh System Stats"
    case feedPixelPal = "Feed Pixel Pal"

    var id: String { rawValue }

    var gestureTitle: String {
        switch self {
        case .timerAddFive:
            return "Add Timer Time"
        default:
            return rawValue
        }
    }

    var supportsContinuousGesture: Bool {
        switch self {
        case .audioVolumeUp, .audioVolumeDown, .seekBackward, .seekForward:
            return true
        default:
            return false
        }
    }

    var supportsGestureAmount: Bool {
        switch self {
        case .audioVolumeUp, .audioVolumeDown, .seekBackward, .seekForward, .timerAddFive:
            return true
        default:
            return false
        }
    }

    var defaultGestureAmount: Double {
        switch self {
        case .audioVolumeUp, .audioVolumeDown:
            return 5
        case .seekBackward, .seekForward:
            return 5
        case .timerAddFive:
            return 5
        default:
            return 1
        }
    }

    var gestureAmountRange: ClosedRange<Double> {
        switch self {
        case .audioVolumeUp, .audioVolumeDown:
            return 1...25
        case .seekBackward, .seekForward:
            return 1...60
        case .timerAddFive:
            return 1...60
        default:
            return 1...1
        }
    }

    var gestureAmountStep: Double {
        switch self {
        case .audioVolumeUp, .audioVolumeDown, .seekBackward, .seekForward, .timerAddFive:
            return 1
        default:
            return 1
        }
    }

    var gestureAmountLabel: String {
        switch self {
        case .audioVolumeUp, .audioVolumeDown:
            return "Change per step"
        case .seekBackward, .seekForward:
            return "Seek per step"
        case .timerAddFive:
            return "Minutes to add"
        default:
            return "Amount"
        }
    }

    func normalizedGestureAmount(_ amount: Double?) -> Double {
        let fallback = defaultGestureAmount
        let raw = amount ?? fallback
        let finite = raw.isFinite ? raw : fallback
        return min(gestureAmountRange.upperBound, max(gestureAmountRange.lowerBound, finite))
    }

    func formattedGestureAmount(_ amount: Double) -> String {
        let value = normalizedGestureAmount(amount)
        switch self {
        case .audioVolumeUp, .audioVolumeDown:
            return "\(Int(value.rounded()))%"
        case .seekBackward, .seekForward:
            return "\(Int(value.rounded())) s"
        case .timerAddFive:
            return "\(Int(value.rounded())) min"
        default:
            return String(format: "%.0f", value)
        }
    }

    static func availableActions(for kind: NotchBubbleKind) -> [NotchBubbleGestureAction] {
        let common: [NotchBubbleGestureAction] = [
            .none,
            .primaryAction,
            .showDetails,
            .openNotch,
            .dismiss
        ]

        switch kind {
        case .music, .vinyl:
            return common + [
                .playPause,
                .previousTrack,
                .nextTrack,
                .openMediaPlayer,
                .seekBackward,
                .seekForward
            ]

        case .timer:
            return common + [
                .timerPauseResume,
                .timerAddFive
            ]

        case .stopwatch:
            return common + [
                .stopwatchToggle,
                .stopwatchLap,
                .stopwatchReset
            ]

        case .audio:
            return common + [
                .audioVolumeUp,
                .audioVolumeDown,
                .audioMuteRestore,
                .openSoundSettings
            ]

        case .system:
            return common + [.refreshSystem]

        case .pixelPal:
            return common + [.feedPixelPal]

        case .clock, .clipboard, .calendar, .files, .appWindow:
            return common
        }
    }

    static func sanitized(
        _ action: NotchBubbleGestureAction?,
        for kind: NotchBubbleKind,
        default defaultAction: NotchBubbleGestureAction
    ) -> NotchBubbleGestureAction {
        guard let action else { return defaultAction }
        return availableActions(for: kind).contains(action) ? action : defaultAction
    }
}

struct NotchBubbleGestureConfiguration {
    let action: NotchBubbleGestureAction
    let mode: NotchBubbleGestureMode
    let amount: Double
    let hapticStrength: Int?
    let hapticPattern: HaloHoverHapticPattern?

    var shouldRepeat: Bool {
        mode == .continuous && action.supportsContinuousGesture
    }
}

fileprivate enum NotchBubbleGestureDirection: String {
    case left
    case right
    case up
    case down
}

private extension Notification.Name {
    static let haloNotchBubbleDirectionalGesture = Notification.Name("HaloNotchBubbleDirectionalGesture")
    static let haloNotchBubbleForceTouch = Notification.Name("HaloNotchBubbleForceTouch")
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

enum FileBubbleDisplayMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case latest = "Latest File"
    case count = "Item Count"
    case tray = "Tray Icon"
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
    var accent: WidgetColor? = nil
    var tintAmount: Double? = nil
    var animation: NotchBubbleAnimationPreset? = nil
    var lifecycleDuration: Double? = nil
    var gestureLeftAction: NotchBubbleGestureAction? = nil
    var gestureRightAction: NotchBubbleGestureAction? = nil
    var gestureUpAction: NotchBubbleGestureAction? = nil
    var gestureDownAction: NotchBubbleGestureAction? = nil

    var gestureLeftMode: NotchBubbleGestureMode? = nil
    var gestureRightMode: NotchBubbleGestureMode? = nil
    var gestureUpMode: NotchBubbleGestureMode? = nil
    var gestureDownMode: NotchBubbleGestureMode? = nil

    var gestureLeftAmount: Double? = nil
    var gestureRightAmount: Double? = nil
    var gestureUpAmount: Double? = nil
    var gestureDownAmount: Double? = nil

    var gestureLeftHapticStrength: Int? = nil
    var gestureRightHapticStrength: Int? = nil
    var gestureUpHapticStrength: Int? = nil
    var gestureDownHapticStrength: Int? = nil

    var gestureLeftHapticPattern: HaloHoverHapticPattern? = nil
    var gestureRightHapticPattern: HaloHoverHapticPattern? = nil
    var gestureUpHapticPattern: HaloHoverHapticPattern? = nil
    var gestureDownHapticPattern: HaloHoverHapticPattern? = nil

    var tapHapticStrength: Int? = nil
    var tapHapticPattern: HaloHoverHapticPattern? = nil

    var doubleClickAction: NotchBubbleGestureAction? = nil
    var doubleClickAmount: Double? = nil
    var doubleClickHapticStrength: Int? = nil
    var doubleClickHapticPattern: HaloHoverHapticPattern? = nil

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
        if let lifecycleDuration { value.lifecycleDuration = min(1.5, max(0.10, lifecycleDuration.isFinite ? lifecycleDuration : 0.22)) }

        if let gestureLeftAmount { value.gestureLeftAmount = min(300, max(0.1, gestureLeftAmount.isFinite ? gestureLeftAmount : 5)) }
        if let gestureRightAmount { value.gestureRightAmount = min(300, max(0.1, gestureRightAmount.isFinite ? gestureRightAmount : 5)) }
        if let gestureUpAmount { value.gestureUpAmount = min(300, max(0.1, gestureUpAmount.isFinite ? gestureUpAmount : 5)) }
        if let gestureDownAmount { value.gestureDownAmount = min(300, max(0.1, gestureDownAmount.isFinite ? gestureDownAmount : 5)) }
        if let doubleClickAmount { value.doubleClickAmount = min(300, max(0.1, doubleClickAmount.isFinite ? doubleClickAmount : 5)) }

        if let gestureLeftHapticStrength { value.gestureLeftHapticStrength = min(6, max(0, gestureLeftHapticStrength)) }
        if let gestureRightHapticStrength { value.gestureRightHapticStrength = min(6, max(0, gestureRightHapticStrength)) }
        if let gestureUpHapticStrength { value.gestureUpHapticStrength = min(6, max(0, gestureUpHapticStrength)) }
        if let gestureDownHapticStrength { value.gestureDownHapticStrength = min(6, max(0, gestureDownHapticStrength)) }
        if let tapHapticStrength { value.tapHapticStrength = min(6, max(0, tapHapticStrength)) }
        if let doubleClickHapticStrength { value.doubleClickHapticStrength = min(6, max(0, doubleClickHapticStrength)) }

        if let tint { value.tint = (try? tint.validated()) ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0) }
        if let accent { value.accent = (try? accent.validated()) ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0) }
        return value
    }

    var isEmpty: Bool {
        design == nil && size == nil && shape == nil && background == nil && cornerRadius == nil &&
        glassIntensity == nil && backgroundOpacity == nil && borderOpacity == nil &&
        contentScale == nil && verticalOffset == nil && tint == nil && accent == nil && tintAmount == nil &&
        animation == nil && lifecycleDuration == nil &&
        gestureLeftAction == nil && gestureRightAction == nil &&
        gestureUpAction == nil && gestureDownAction == nil &&
        gestureLeftMode == nil && gestureRightMode == nil &&
        gestureUpMode == nil && gestureDownMode == nil &&
        gestureLeftAmount == nil && gestureRightAmount == nil &&
        gestureUpAmount == nil && gestureDownAmount == nil &&
        gestureLeftHapticStrength == nil && gestureRightHapticStrength == nil &&
        gestureUpHapticStrength == nil && gestureDownHapticStrength == nil &&
        gestureLeftHapticPattern == nil && gestureRightHapticPattern == nil &&
        gestureUpHapticPattern == nil && gestureDownHapticPattern == nil &&
        tapHapticStrength == nil && tapHapticPattern == nil &&
        doubleClickAction == nil && doubleClickAmount == nil &&
        doubleClickHapticStrength == nil && doubleClickHapticPattern == nil
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
    let accent: Color?
    let tintAmount: Double
    let animation: NotchBubbleAnimationPreset
    let lifecycleDuration: TimeInterval
}

struct NotchBubble: Identifiable, Equatable {
    let id: String
    let kind: NotchBubbleKind
    var placement: NotchBubblePlacement = .automatic
    var size: CGFloat
    var shape: NotchBubbleShape
    var isPersistent: Bool
    var timeout: TimeInterval?
    var priority: NotchBubblePriority
}

struct NotchBubbleSettings: Codable, Equatable {
    var version = 2
    var enabled = false

    var layout: NotchBubbleLayout = .satellites
    // Optional keeps settings saved before side placement existed decodable.
    // Side placement is used by Wings, where bubbles live beside the notch.
    var bubbleSideMode: NotchBubbleSideMode?
    var automaticPrioritySide: NotchBubbleSide?
    var spacing = 10.0
    var bubbleSize = 42.0
    // Optional preserves decoding of Notch Bubble settings saved before this control existed.
    // Positive values move bubbles down on screen.
    var verticalOffset: Double?
    var shape: NotchBubbleShape = .glass
    var cornerRadius = 18.0
    var glassIntensity = 0.82
    // Optional global color keeps existing settings visually unchanged. Per-bubble
    // tint overrides continue to take priority over these values.
    var bubbleTint: WidgetColor?
    var bubbleAccent: WidgetColor?
    var bubbleTintAmount: Double?
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
    var filesEnabled: Bool?
    var filesPersistent: Bool?
    var filesDisplayMode: FileBubbleDisplayMode?

    // Experimental App Bubbles. Optional keeps older settings decodable.
    var appMinimizeBubblesEnabled: Bool?
    // 0 means unlimited. Missing values preserve the original single-window behavior.
    var appMinimizeBubbleLimit: Int?
    // App windows can be positioned independently from the global Bubble layout.
    var appMinimizeBubblePlacement: AppWindowBubblePlacement?

    /// Per-provider appearance overrides. Missing entries inherit the global bubble defaults.
    var bubbleStyles: [String: NotchBubbleStyleOverride]?

    func normalized() -> Self {
        var value = self

        // v2: pinned utilities use a single Enable switch. The old bubble-level
        // "Disable" action could leave Enabled=false + Persistent=true, which made
        // re-enabling appear broken. Restore those contradictory v1 states once.
        if value.version < 2 {
            if value.clipboardPersistent == true && value.clipboardEnabled == false {
                value.clipboardEnabled = true
            }
            if value.systemPersistent == true && value.systemEnabled == false {
                value.systemEnabled = true
            }
            if value.audioPersistent == true && value.audioEnabled == false {
                value.audioEnabled = true
            }
        }
        value.version = 2
        value.spacing = min(40, max(0, spacing.isFinite ? spacing : 10))
        value.bubbleSize = min(72, max(24, bubbleSize.isFinite ? bubbleSize : 42))
        if let verticalOffset {
            value.verticalOffset = min(120, max(-120, verticalOffset.isFinite ? verticalOffset : 0))
        }
        value.cornerRadius = min(36, max(0, cornerRadius.isFinite ? cornerRadius : 18))
        value.glassIntensity = min(1, max(0.15, glassIntensity.isFinite ? glassIntensity : 0.82))
        if let bubbleTint {
            value.bubbleTint = (try? bubbleTint.validated()) ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0)
        }
        if let bubbleAccent {
            value.bubbleAccent = (try? bubbleAccent.validated()) ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0)
        }
        if let bubbleTintAmount {
            value.bubbleTintAmount = min(1, max(0, bubbleTintAmount.isFinite ? bubbleTintAmount : 0.35))
        }
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
        if let appMinimizeBubblePlacement {
            value.appMinimizeBubblePlacement = appMinimizeBubblePlacement
        }
        if let appMinimizeBubbleLimit {
            value.appMinimizeBubbleLimit = appMinimizeBubbleLimit <= 0
                ? 0
                : min(99, max(1, appMinimizeBubbleLimit))
        }
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

    var resolvedBubbleSideMode: NotchBubbleSideMode {
        bubbleSideMode ?? .automatic
    }

    var resolvedAutomaticPrioritySide: NotchBubbleSide {
        automaticPrioritySide ?? .left
    }

    var resolvedVerticalOffset: Double {
        let value = verticalOffset ?? 0
        return value.isFinite ? min(120, max(-120, value)) : 0
    }

    var resolvedLifecycleDuration: Double {
        let value = lifecycleDuration ?? 0.22
        return value.isFinite ? min(1.5, max(0.10, value)) : 0.28
    }

    var resolvedBubbleTintAmount: Double {
        let value = bubbleTintAmount ?? (bubbleTint == nil ? 0 : 0.35)
        return value.isFinite ? min(1, max(0, value)) : 0.35
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
    var resolvedCalendarDisplayMode: CalendarBubbleDisplayMode { calendarDisplayMode ?? .nextEvent }
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

    fileprivate func gestureConfiguration(
        for kind: NotchBubbleKind,
        direction: NotchBubbleGestureDirection
    ) -> NotchBubbleGestureConfiguration {
        let override = styleOverride(for: kind)

        let storedAction: NotchBubbleGestureAction?
        let storedMode: NotchBubbleGestureMode?
        let storedAmount: Double?
        let storedHapticStrength: Int?
        let storedHapticPattern: HaloHoverHapticPattern?

        switch direction {
        case .left:
            storedAction = override?.gestureLeftAction
            storedMode = override?.gestureLeftMode
            storedAmount = override?.gestureLeftAmount
            storedHapticStrength = override?.gestureLeftHapticStrength
            storedHapticPattern = override?.gestureLeftHapticPattern
        case .right:
            storedAction = override?.gestureRightAction
            storedMode = override?.gestureRightMode
            storedAmount = override?.gestureRightAmount
            storedHapticStrength = override?.gestureRightHapticStrength
            storedHapticPattern = override?.gestureRightHapticPattern
        case .up:
            storedAction = override?.gestureUpAction
            storedMode = override?.gestureUpMode
            storedAmount = override?.gestureUpAmount
            storedHapticStrength = override?.gestureUpHapticStrength
            storedHapticPattern = override?.gestureUpHapticPattern
        case .down:
            storedAction = override?.gestureDownAction
            storedMode = override?.gestureDownMode
            storedAmount = override?.gestureDownAmount
            storedHapticStrength = override?.gestureDownHapticStrength
            storedHapticPattern = override?.gestureDownHapticPattern
        }

        let action = NotchBubbleGestureAction.sanitized(storedAction, for: kind, default: .none)
        let mode: NotchBubbleGestureMode =
            action.supportsContinuousGesture ? (storedMode ?? .once) : .once

        return NotchBubbleGestureConfiguration(
            action: action,
            mode: mode,
            amount: action.normalizedGestureAmount(storedAmount),
            hapticStrength: storedHapticStrength.map { min(6, max(0, $0)) },
            hapticPattern: storedHapticPattern
        )
    }

    func doubleClickConfiguration(for kind: NotchBubbleKind) -> NotchBubbleGestureConfiguration {
        let override = styleOverride(for: kind)
        let action = NotchBubbleGestureAction.sanitized(
            override?.doubleClickAction,
            for: kind,
            default: .primaryAction
        )

        return NotchBubbleGestureConfiguration(
            action: action,
            mode: .once,
            amount: action.normalizedGestureAmount(override?.doubleClickAmount),
            hapticStrength: (override?.doubleClickHapticStrength).map { min(6, max(0, $0)) },
            hapticPattern: override?.doubleClickHapticPattern
        )
    }

    var resolvedFilesEnabled: Bool { filesEnabled ?? false }
    var resolvedFilesPersistent: Bool { filesPersistent ?? false }
    var resolvedFilesDisplayMode: FileBubbleDisplayMode { filesDisplayMode ?? .latest }
    var resolvedAppMinimizeBubblesEnabled: Bool {
        HaloDistribution.current.supportsAppWindowBubbles && (appMinimizeBubblesEnabled ?? false)
    }

    var resolvedAppMinimizeBubbleLimit: Int {
        let value = appMinimizeBubbleLimit ?? 1
        return value <= 0 ? Int.max : min(99, max(1, value))
    }

    var resolvedAppMinimizeBubblePlacement: AppWindowBubblePlacement {
        appMinimizeBubblePlacement ?? .belowNotch
    }

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

    func isProviderEnabled(_ kind: NotchBubbleKind) -> Bool {
        switch kind {
        case .music: return musicEnabled
        case .timer: return timerEnabled
        case .pixelPal: return pixelPalEnabled
        case .clock: return resolvedClockEnabled
        case .stopwatch: return resolvedStopwatchEnabled
        case .system: return resolvedSystemEnabled
        case .clipboard: return resolvedClipboardEnabled
        case .calendar: return resolvedCalendarEnabled
        case .audio: return resolvedAudioEnabled
        case .vinyl: return resolvedVinylEnabled
        case .files: return resolvedFilesEnabled
        case .appWindow: return resolvedAppMinimizeBubblesEnabled
        }
    }

    func requestsPinnedPresentation(_ kind: NotchBubbleKind) -> Bool {
        switch kind {
        case .music: return resolvedMusicVisibility == .pinned
        case .timer: return timerPersistent
        case .pixelPal: return pixelPalPersistent
        case .clock, .system, .clipboard, .audio: return isProviderEnabled(kind)
        case .stopwatch: return resolvedStopwatchPersistent
        case .calendar: return resolvedCalendarPersistent
        case .vinyl: return resolvedVinylPersistent
        case .files: return resolvedFilesPersistent
        case .appWindow: return false
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
        let tintColor = override?.tint?.color ?? bubbleTint?.color
        // Accent is independent when customized. If not explicitly set, preserve
        // Halo's previous behavior where a custom tint also became the accent.
        let accentColor = override?.accent?.color
            ?? bubbleAccent?.color
            ?? tintColor
        let tintAmount: Double = {
            if override?.tint != nil {
                return override?.tintAmount ?? max(0.22, resolvedBubbleTintAmount)
            }
            return override?.tintAmount ?? resolvedBubbleTintAmount
        }()
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
            accent: accentColor,
            tintAmount: tintAmount,
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
    private var interactingKinds = Set<NotchBubbleKind>()
    private var pausedExpiryRemaining: [String: TimeInterval] = [:]

    private init() {}

    func publishHUD(_ event: HaloHUDEvent, settings: NotchBubbleSettings) {
        guard settings.enabled,
              settings.acceptsHUDEvent(event.kind),
              var activity = Self.activity(from: event, settings: settings) else { return }

        suppressedKinds.remove(activity.kind)

        if interactingKinds.contains(activity.kind), let expiresAt = activity.expiresAt {
            pausedExpiryRemaining[activity.id] = max(
                settings.resolvedConfirmationDuration,
                expiresAt.timeIntervalSinceNow
            )
            activity.expiresAt = nil
        }

        transientActivities[activity.id] = activity
        scheduleExpiry(for: activity)
    }

    func dismiss(kind: NotchBubbleKind) {
        suppressedKinds.insert(kind)
        interactingKinds.remove(kind)
        let ids = transientActivities.values.filter { $0.kind == kind }.map(\.id)
        for id in ids {
            expiryTasks[id]?.cancel()
            expiryTasks.removeValue(forKey: id)
            pausedExpiryRemaining.removeValue(forKey: id)
            transientActivities.removeValue(forKey: id)
        }
    }

    func publishCompletion(
        kind: NotchBubbleKind,
        sourceIdentifier: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        duration: TimeInterval
    ) {
        let now = Date()
        let activity = NotchBubbleActivity(
            id: "completion." + kind.rawValue,
            kind: kind,
            sourceIdentifier: sourceIdentifier,
            mode: .confirmation,
            priority: .urgent,
            title: title,
            subtitle: subtitle,
            icon: icon,
            progress: 1,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(duration)
        )
        suppressedKinds.remove(kind)
        var resolvedActivity = activity
        if interactingKinds.contains(kind), let expiresAt = resolvedActivity.expiresAt {
            pausedExpiryRemaining[resolvedActivity.id] = max(
                duration,
                expiresAt.timeIntervalSinceNow
            )
            resolvedActivity.expiresAt = nil
        }
        transientActivities[resolvedActivity.id] = resolvedActivity
        scheduleExpiry(for: resolvedActivity)
    }

    func clearTransient(kind: NotchBubbleKind) {
        let ids = transientActivities.values.filter { $0.kind == kind }.map(\.id)
        for id in ids {
            expiryTasks[id]?.cancel()
            expiryTasks.removeValue(forKey: id)
            pausedExpiryRemaining.removeValue(forKey: id)
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

    func setInteracting(kind: NotchBubbleKind, interacting: Bool) {
        let ids = transientActivities.values.filter { $0.kind == kind }.map(\.id)
        guard !ids.isEmpty else {
            if interacting { interactingKinds.insert(kind) }
            else { interactingKinds.remove(kind) }
            return
        }

        if interacting {
            interactingKinds.insert(kind)
            let now = Date()
            for id in ids {
                guard var activity = transientActivities[id] else { continue }
                if let expiresAt = activity.expiresAt {
                    pausedExpiryRemaining[id] = max(0.05, expiresAt.timeIntervalSince(now))
                    activity.expiresAt = nil
                    transientActivities[id] = activity
                }
                expiryTasks[id]?.cancel()
                expiryTasks.removeValue(forKey: id)
            }
            return
        }

        interactingKinds.remove(kind)
        let now = Date()
        for id in ids {
            guard var activity = transientActivities[id] else { continue }
            let remaining = pausedExpiryRemaining.removeValue(forKey: id) ?? 0
            guard remaining > 0 else { continue }
            // Give the user enough time to visually reacquire the bubble after leaving it.
            activity.updatedAt = now
            activity.expiresAt = now.addingTimeInterval(max(1.2, remaining))
            transientActivities[id] = activity
            scheduleExpiry(for: activity)
        }
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
extension HaloFeatureAccess {
    /// Bubble settings used for presentation right now. Lite restrictions are
    /// applied to a copy so the user's advanced Full setup stays untouched.
    func effectiveBubbleSettings(_ saved: NotchBubbleSettings) -> NotchBubbleSettings {
        let saved = saved.normalized()
        guard !isFull else { return saved }

        var value = saved

        // Lite keeps the three core providers only.
        value.pixelPalEnabled = false
        value.clockEnabled = false
        value.stopwatchEnabled = false
        value.systemEnabled = false
        value.clipboardEnabled = false
        value.calendarEnabled = false
        value.vinylEnabled = false
        value.filesEnabled = false
        value.appMinimizeBubblesEnabled = false

        // Persistent/pinned provider behavior is part of advanced Bubbles.
        value.musicPersistent = false
        value.timerPersistent = false
        value.pixelPalPersistent = false
        value.stopwatchPersistent = false
        value.calendarPersistent = false
        value.vinylPersistent = false
        value.filesPersistent = false
        value.audioPersistent = false
        value.systemPersistent = false
        value.clipboardPersistent = false

        // Lite Bubbles use Halo's normal visibility behavior rather than
        // retaining Full-only visibility/persistence policies.
        value.showWhenClosed = true
        value.showWhenOpen = true
        value.musicVisibility = .whilePlaying
        // Volume is a transient confirmation in Lite, not a pinned Audio utility.
        value.audioEnabled = false
        value.audioFeedbackEnabled = saved.audioFeedbackEnabled ?? true
        value.brightnessFeedbackEnabled = false
        value.powerFeedbackEnabled = false
        value.deviceFeedbackEnabled = false

        // One automatic/default Bubble with Halo Glass and Fluid motion.
        value.maximumBubbles = 1
        value.layout = .satellites
        value.bubbleSideMode = .automatic
        value.automaticPrioritySide = nil
        value.spacing = 10
        value.bubbleSize = 42
        value.verticalOffset = 0
        value.shape = .glass
        value.cornerRadius = 18
        value.glassIntensity = 0.82
        value.bubbleTint = nil
        value.bubbleAccent = nil
        value.bubbleTintAmount = nil
        value.animation = .fluid
        value.lifecycleDuration = nil

        // Provider-specific display/appearance/gesture customization is Full.
        value.musicDisplayMode = nil
        value.musicShowPlaybackGlyph = nil
        value.musicArtworkZoom = nil
        value.musicTapAction = nil
        value.timerDisplayMode = nil
        value.audioDisplayMode = nil
        value.bubbleStyles = nil

        // Advanced activity-policy knobs fall back to Halo's defaults.
        value.confirmationDuration = nil
        value.completionDuration = nil
        value.showAutomaticInFullscreen = nil
        value.showConfirmationsInFullscreen = nil
        value.replaceHaloHUDFeedback = false

        return value.normalized()
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
final class MinimizedWindowBubbleCenter: ObservableObject {
    static let shared = MinimizedWindowBubbleCenter()

    struct Entry: Identifiable, Equatable {
        let id: String
        let processIdentifier: pid_t
        let bundleIdentifier: String?
        let appName: String
        let windowTitle: String
        let windowFrame: CGRect?
        let minimizedAt: Date
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()

    private struct Snapshot {
        let entry: Entry
        let element: AXUIElement
    }

    private var handles: [String: AXUIElement] = [:]
    private var knownMinimized = Set<String>()
    private var hasBaseline = false
    private var polling: AnyCancellable?
    private var enabled = false

    var current: Entry? { entries.first }

    func entry(activityID: String) -> Entry? {
        guard activityID.hasPrefix("appWindow.") else { return nil }
        let entryID = String(activityID.dropFirst("appWindow.".count))
        return entries.first(where: { $0.id == entryID })
    }

    private init() {}

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled || (enabled && polling == nil) else { return }
        self.enabled = enabled

        if enabled {
            startPolling()
        } else {
            stopPolling()
        }
    }

    func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        if accessibilityGranted {
            hasBaseline = false
            scan()
        }
    }

    func appIcon(for entry: Entry) -> NSImage? {
        if let running = NSRunningApplication(processIdentifier: entry.processIdentifier),
           let icon = running.icon {
            return icon
        }

        guard let bundleIdentifier = entry.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    @discardableResult
    func restoreCurrent() -> Bool {
        guard let entry = current else { return false }
        return restore(entry: entry)
    }

    @discardableResult
    func restore(activityID: String) -> Bool {
        guard let entry = entry(activityID: activityID) else { return false }
        return restore(entry: entry)
    }

    func dismiss(activityID: String) {
        guard let entry = entry(activityID: activityID) else { return }
        removeEntry(id: entry.id)
    }

    @discardableResult
    private func restore(entry: Entry) -> Bool {
        guard let element = handles[entry.id] else {
            removeEntry(id: entry.id)
            return false
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXMinimizedAttribute as CFString,
            kCFBooleanFalse
        )
        guard result == .success else {
            scan()
            return false
        }

        _ = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        if let app = NSRunningApplication(processIdentifier: entry.processIdentifier) {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }

        removeEntry(id: entry.id)
        if !entries.isEmpty {
            NotchBubbleActivityCenter.shared.clearDismissal(kind: .appWindow)
        }
        return true
    }

    private func startPolling() {
        polling?.cancel()
        hasBaseline = false

        scan()
        polling = Timer.publish(every: 0.35, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.scan()
            }
    }

    private func stopPolling() {
        polling?.cancel()
        polling = nil
        hasBaseline = false
        knownMinimized.removeAll()
        handles.removeAll()
        entries.removeAll()
    }

    private func scan() {
        guard enabled else { return }

        let trusted = AXIsProcessTrusted()
        if accessibilityGranted != trusted {
            accessibilityGranted = trusted
        }

        guard trusted else {
            hasBaseline = false
            knownMinimized.removeAll()
            handles.removeAll()
            entries.removeAll()
            return
        }

        var minimized: [String: Snapshot] = [:]
        let ownPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != ownPID,
                  app.activationPolicy == .regular,
                  !app.isTerminated else { continue }

            let application = AXUIElementCreateApplication(app.processIdentifier)
            guard let windows = attribute(kAXWindowsAttribute as CFString, from: application) as? [AXUIElement] else {
                continue
            }

            for window in windows {
                guard booleanAttribute(kAXMinimizedAttribute as CFString, from: window) == true else {
                    continue
                }

                let title = stringAttribute(kAXTitleAttribute as CFString, from: window) ?? "Window"
                let document = stringAttribute(kAXDocumentAttribute as CFString, from: window) ?? ""
                let identifier = stringAttribute(kAXIdentifierAttribute as CFString, from: window)
                let fallbackHash = CFHash(window)
                let identity = identifier?.isEmpty == false
                    ? identifier!
                    : "\(title)|\(document)|\(fallbackHash)"
                let id = "\(app.processIdentifier)|\(identity)"
                let appName = app.localizedName
                    ?? app.bundleIdentifier?.split(separator: ".").last.map(String.init)
                    ?? "App"

                minimized[id] = Snapshot(
                    entry: Entry(
                        id: id,
                        processIdentifier: app.processIdentifier,
                        bundleIdentifier: app.bundleIdentifier,
                        appName: appName,
                        windowTitle: title,
                        windowFrame: windowFrame(for: window),
                        minimizedAt: Date()
                    ),
                    element: window
                )
            }
        }

        let currentKeys = Set(minimized.keys)
        if !hasBaseline {
            knownMinimized = currentKeys
            hasBaseline = true
            return
        }

        let newlyMinimized = currentKeys.subtracting(knownMinimized)
        for key in newlyMinimized {
            guard let snapshot = minimized[key] else { continue }
            entries.removeAll { $0.id == key }
            entries.insert(snapshot.entry, at: 0)
            handles[key] = snapshot.element
        }

        // Keep handles fresh because AX can vend a new wrapper for the same remote window.
        for entry in entries {
            if let snapshot = minimized[entry.id] {
                handles[entry.id] = snapshot.element
            }
        }

        entries.removeAll { !currentKeys.contains($0.id) }
        handles = handles.filter { currentKeys.contains($0.key) }
        knownMinimized = currentKeys

        if !newlyMinimized.isEmpty {
            NotchBubbleActivityCenter.shared.clearDismissal(kind: .appWindow)
        }
    }

    private func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
        handles.removeValue(forKey: id)
        AppWindowPreviewCenter.shared.clear(activityID: "appWindow." + id)
        // Keep the ID in knownMinimized until a scan observes the window restored.
        // This prevents a short AX propagation delay from re-adding the same window.
    }

    private func attribute(_ name: CFString, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
            return nil
        }
        return value
    }

    private func stringAttribute(_ name: CFString, from element: AXUIElement) -> String? {
        attribute(name, from: element) as? String
    }

    private func booleanAttribute(_ name: CFString, from element: AXUIElement) -> Bool? {
        (attribute(name, from: element) as? NSNumber)?.boolValue
    }

    private func windowFrame(for element: AXUIElement) -> CGRect? {
        guard let positionValue = attribute(kAXPositionAttribute as CFString, from: element),
              let sizeValue = attribute(kAXSizeAttribute as CFString, from: element),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        let positionAX = unsafeBitCast(positionValue, to: AXValue.self)
        let sizeAX = unsafeBitCast(sizeValue, to: AXValue.self)
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAX, .cgPoint, &position),
              AXValueGetValue(sizeAX, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }
}

private enum AppWindowPreviewError: LocalizedError {
    case permissionRequired
    case windowUnavailable
    case captureUnavailable
    case encodingFailed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Screen Recording access is required for window previews."
        case .windowUnavailable:
            return "Halo could not find this minimized window in ScreenCaptureKit."
        case .captureUnavailable:
            return "macOS did not return a preview frame for this window."
        case .encodingFailed:
            return "Halo could not prepare the window preview."
        case .timedOut:
            return "The window preview timed out. Force Touch the Bubble again to retry."
        }
    }
}

private final class AppWindowPreviewFrameReceiver: NSObject, SCStreamOutput, @unchecked Sendable {
    let sampleQueue = DispatchQueue(label: "Halo.AppWindowPreview.Frame", qos: .userInitiated)

    private let stateQueue = DispatchQueue(label: "Halo.AppWindowPreview.State")
    private let imageContext = CIContext()
    private var continuation: CheckedContinuation<Data, Error>?
    private var stream: SCStream?
    private var finished = false

    func captureSingleFrame(from stream: SCStream) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            stateQueue.sync {
                self.continuation = continuation
                self.stream = stream
                self.finished = false
            }

            stateQueue.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.finish(.failure(AppWindowPreviewError.timedOut))
            }

            Task { [weak self] in
                do {
                    try await stream.startCapture()
                } catch {
                    self?.finish(.failure(error))
                }
            }
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = imageContext.createCGImage(image, from: image.extent) else {
            finish(.failure(AppWindowPreviewError.captureUnavailable))
            return
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            finish(.failure(AppWindowPreviewError.encodingFailed))
            return
        }

        finish(.success(data))
    }

    private func finish(_ result: Result<Data, Error>) {
        stateQueue.async { [weak self] in
            guard let self, !self.finished else { return }
            self.finished = true

            let continuation = self.continuation
            let stream = self.stream
            self.continuation = nil
            self.stream = nil

            continuation?.resume(with: result)

            if let stream {
                Task {
                    try? await stream.stopCapture()
                }
            }
        }
    }
}

@MainActor
final class AppWindowPreviewCenter: ObservableObject {
    static let shared = AppWindowPreviewCenter()

    @Published private(set) var images: [String: NSImage] = [:]
    @Published private(set) var loadingIDs = Set<String>()
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var screenCaptureGranted = CGPreflightScreenCaptureAccess()

    private init() {}

    func image(for activityID: String) -> NSImage? {
        images[activityID]
    }

    func error(for activityID: String) -> String? {
        errors[activityID]
    }

    func requestScreenCapturePermission() {
        if CGPreflightScreenCaptureAccess() {
            screenCaptureGranted = true
            return
        }

        let granted = CGRequestScreenCaptureAccess()
        screenCaptureGranted = CGPreflightScreenCaptureAccess()
        if granted && !screenCaptureGranted {
            errors["permission"] = "Screen Recording access was granted. Quit and reopen Halo before using App Bubble previews."
        }
    }

    func refreshPermissionState() {
        screenCaptureGranted = CGPreflightScreenCaptureAccess()
    }

    func loadPreview(
        activityID: String,
        entry: MinimizedWindowBubbleCenter.Entry,
        forceRefresh: Bool = true
    ) {
        refreshPermissionState()

        guard screenCaptureGranted else {
            errors[activityID] = "Allow Screen Recording for Halo, then quit and reopen Halo to use Force Touch previews."
            return
        }

        if !forceRefresh, images[activityID] != nil {
            return
        }

        guard !loadingIDs.contains(activityID) else { return }
        loadingIDs.insert(activityID)
        errors.removeValue(forKey: activityID)

        Task { [weak self] in
            guard let self else { return }

            do {
                let data = try await Self.capturePreviewData(for: entry)
                guard let image = NSImage(data: data) else {
                    throw AppWindowPreviewError.encodingFailed
                }
                self.images[activityID] = image
                self.errors.removeValue(forKey: activityID)
            } catch {
                self.errors[activityID] = error.localizedDescription
            }

            self.loadingIDs.remove(activityID)
        }
    }

    func clear(activityID: String) {
        images.removeValue(forKey: activityID)
        errors.removeValue(forKey: activityID)
        loadingIDs.remove(activityID)
    }

    private static func capturePreviewData(
        for entry: MinimizedWindowBubbleCenter.Entry
    ) async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            throw AppWindowPreviewError.permissionRequired
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        let candidates = content.windows.filter {
            $0.owningApplication?.processID == entry.processIdentifier
        }

        guard let window = bestWindow(for: entry, from: candidates) else {
            throw AppWindowPreviewError.windowUnavailable
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        let sourceSize = window.frame.size
        let width = max(1, sourceSize.width)
        let height = max(1, sourceSize.height)
        let longest = max(width, height)
        let scale = min(2.0, 1400.0 / longest)

        configuration.width = max(1, Int((width * scale).rounded()))
        configuration.height = max(1, Int((height * scale).rounded()))
        configuration.queueDepth = 1
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let receiver = AppWindowPreviewFrameReceiver()
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(
            receiver,
            type: .screen,
            sampleHandlerQueue: receiver.sampleQueue
        )

        return try await receiver.captureSingleFrame(from: stream)
    }

    private static func bestWindow(
        for entry: MinimizedWindowBubbleCenter.Entry,
        from candidates: [SCWindow]
    ) -> SCWindow? {
        guard !candidates.isEmpty else { return nil }

        let normalizedTitle = entry.windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleMatches = candidates.filter {
            ($0.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == normalizedTitle
        }
        let pool = titleMatches.isEmpty ? candidates : titleMatches

        guard pool.count > 1, let expectedFrame = entry.windowFrame else {
            return pool.first
        }

        return pool.min {
            frameDistance($0.frame, expectedFrame) < frameDistance($1.frame, expectedFrame)
        }
    }

    private static func frameDistance(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        abs(lhs.width - rhs.width)
            + abs(lhs.height - rhs.height)
            + abs(lhs.minX - rhs.minX) * 0.25
            + abs(lhs.minY - rhs.minY) * 0.25
    }
}

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
        guard settings.timerEnabled, settings.timerPersistent || active else { return nil }
        let mode: NotchBubblePresentationMode = settings.timerPersistent && !active ? .pinned : .activeTask
        return NotchBubbleActivity(
            id: "timer.primary",
            kind: kind,
            sourceIdentifier: "halo.timer",
            mode: mode,
            priority: active ? .important : .background,
            title: "Timer",
            subtitle: nil,
            icon: "timer",
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
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
        let calendar = store.workspace.calendar

        guard let event = calendar.upcomingEvents.first(where: {
            $0.endDate > now &&
            ($0.startDate.timeIntervalSince(now) <= lead || settings.resolvedCalendarPersistent)
        }) else {
            guard settings.resolvedCalendarPersistent else { return nil }
            return NotchBubbleActivity(
                id: "calendar.pinned",
                kind: kind,
                sourceIdentifier: "system.calendar",
                mode: .pinned,
                priority: .background,
                title: "Calendar",
                subtitle: calendar.hasAccess ? "No upcoming events" : "Calendar access needed",
                icon: calendar.hasAccess ? "calendar" : "calendar.badge.exclamationmark",
                progress: nil,
                updatedAt: now,
                expiresAt: nil
            )
        }

        let seconds = max(0, event.startDate.timeIntervalSince(now))
        let priority: NotchBubblePriority = seconds <= 5 * 60 ? .important : .normal
        let eventID = event.eventIdentifier
            ?? "\(event.startDate.timeIntervalSinceReferenceDate)-\(event.title ?? "event")"
        let calendarID = event.calendar?.calendarIdentifier ?? "calendar"
        return NotchBubbleActivity(
            id: "calendar." + eventID,
            kind: kind,
            sourceIdentifier: calendarID,
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
private struct FileShelfBubbleProvider: BubbleProvider {
    let kind: NotchBubbleKind = .files

    func activity(store: AppStore, settings: NotchBubbleSettings) -> NotchBubbleActivity? {
        guard settings.resolvedFilesEnabled else { return nil }
        let hasFiles = !store.files.isEmpty
        guard settings.resolvedFilesPersistent || hasFiles else { return nil }

        return NotchBubbleActivity(
            id: "files.shelf",
            kind: kind,
            sourceIdentifier: "halo.fileShelf",
            mode: settings.resolvedFilesPersistent ? .pinned : .activeTask,
            priority: hasFiles ? .normal : .background,
            title: hasFiles ? "\(store.files.count) staged item\(store.files.count == 1 ? "" : "s")" : "File Shelf",
            subtitle: store.files.last?.lastPathComponent,
            icon: "tray.full.fill",
            progress: nil,
            updatedAt: Date(),
            expiresAt: nil
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
        guard settings.resolvedSystemEnabled else { return nil }
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
        guard settings.resolvedClipboardEnabled else { return nil }
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
        guard settings.resolvedAudioEnabled else { return nil }
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

        let deduplicated = Dictionary(grouping: visible) { activity in
            activity.kind == .appWindow ? activity.id : "kind." + activity.kind.rawValue
        }.compactMap { _, values in
            values.sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.updatedAt > $1.updatedAt
            }.first
        }

        let sorted = deduplicated.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.mode != $1.mode {
                let rank: [NotchBubblePresentationMode: Int] = [
                    .confirmation: 3, .activeTask: 2, .pinned: 1, .onDemand: 0
                ]
                return rank[$0.mode, default: 0] > rank[$1.mode, default: 0]
            }
            if $0.kind.policyRank != $1.kind.policyRank {
                return $0.kind.policyRank < $1.kind.policyRank
            }
            return $0.updatedAt > $1.updatedAt
        }

        var normalCount = 0
        var appWindowCount = 0
        return sorted.filter { activity in
            if activity.kind == .appWindow {
                guard appWindowCount < settings.resolvedAppMinimizeBubbleLimit else { return false }
                appWindowCount += 1
                return true
            }
            guard normalCount < settings.maximumBubbles else { return false }
            normalCount += 1
            return true
        }
    }
}

@MainActor
struct BubbleRegistry {
    private let providers: [any BubbleProvider] = [
        MusicBubbleProvider(),
        TimerBubbleProvider(),
        CalendarBubbleProvider(),
        FileShelfBubbleProvider(),
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
        let access = HaloFeatureAccess.shared
        let effectiveSettings = access.effectiveBubbleSettings(settings)

        var activities = providers
            .filter { access.allows(bubble: $0.kind) }
            .compactMap { $0.activity(store: store, settings: effectiveSettings) }

        if access.allows(bubble: .appWindow),
           effectiveSettings.resolvedAppMinimizeBubblesEnabled {
            activities.append(contentsOf: MinimizedWindowBubbleCenter.shared.entries.map { entry in
                NotchBubbleActivity(
                    id: "appWindow." + entry.id,
                    kind: .appWindow,
                    sourceIdentifier: entry.bundleIdentifier ?? "pid.\(entry.processIdentifier)",
                    mode: .activeTask,
                    priority: .important,
                    title: entry.appName,
                    subtitle: entry.windowTitle,
                    icon: "macwindow",
                    progress: nil,
                    updatedAt: entry.minimizedAt,
                    expiresAt: nil
                )
            })
        }

        activities.append(contentsOf: runtime.activeTransientActivities().filter {
            access.allows(bubble: $0.kind)
        })

        let fullscreen = NSApp.currentSystemPresentationOptions.contains(.fullScreen)
        let selected = policy.select(
            activities,
            settings: effectiveSettings,
            surfaceExpanded: surfaceExpanded,
            fullscreen: fullscreen,
            suppressedKinds: runtime.suppressedKinds
        )

        return selected.map { activity in
            let style = effectiveSettings.resolvedStyle(for: activity.kind)
            return NotchBubble(
                id: activity.kind == .appWindow ? activity.id : activity.kind.rawValue,
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
        settings: NotchBubbleSettings,
        sideAssignments: [String: NotchBubbleSide] = [:]
    ) -> [String: CGRect] {
        guard !bubbles.isEmpty else { return [:] }

        let spacing = CGFloat(settings.spacing)
        let gap = max(5, spacing)
        let globalVerticalOffset = CGFloat(settings.resolvedVerticalOffset)
        let availableWidth = max(1, screenFrame.width - 8)
        var result: [String: CGRect] = [:]

        let standardBubbles = bubbles.filter { $0.kind != .appWindow }
        let appBubbles = bubbles.filter { $0.kind == .appWindow }

        var leftWingOffset: CGFloat = gap
        var rightWingOffset: CGFloat = gap

        switch settings.layout {
        case .satellites:
            var rows: [[NotchBubble]] = []
            var currentRow: [NotchBubble] = []
            var currentWidth: CGFloat = 0

            for bubble in standardBubbles {
                let addedWidth = bubble.size + (currentRow.isEmpty ? 0 : spacing)
                if !currentRow.isEmpty && currentWidth + addedWidth > availableWidth {
                    rows.append(currentRow)
                    currentRow = [bubble]
                    currentWidth = bubble.size
                } else {
                    currentRow.append(bubble)
                    currentWidth += addedWidth
                }
            }
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }

            var yCursor = surfaceFrame.minY - gap - globalVerticalOffset
            for row in rows {
                let rowHeight = row.map(\.size).max() ?? 0
                let totalWidth = row.reduce(CGFloat.zero) { $0 + $1.size }
                    + CGFloat(max(0, row.count - 1)) * spacing
                var x = surfaceFrame.midX - totalWidth / 2
                let rowY = yCursor - rowHeight

                for bubble in row {
                    let style = settings.resolvedStyle(for: bubble.kind)
                    let y = rowY + (rowHeight - bubble.size) / 2 - style.verticalOffset
                    let frame = CGRect(x: x, y: y, width: bubble.size, height: bubble.size)
                    result[bubble.id] = clamped(frame, to: screenFrame)
                    x += bubble.size + spacing
                }

                yCursor = rowY - spacing
            }

        case .wings:
            let menuBarHeight = max(1, compactHeight)
            let menuBarCenterY = screenFrame.maxY - menuBarHeight / 2

            for bubble in standardBubbles {
                let style = settings.resolvedStyle(for: bubble.kind)
                let size = bubble.size
                let y = menuBarCenterY - size / 2 - globalVerticalOffset - style.verticalOffset
                let side = sideAssignments[bubble.id]
                    ?? fallbackSide(for: settings.resolvedBubbleSideMode)
                let frame: CGRect

                switch side {
                case .left:
                    frame = CGRect(
                        x: surfaceFrame.minX - leftWingOffset - size,
                        y: y,
                        width: size,
                        height: size
                    )
                    leftWingOffset += size + spacing

                case .right:
                    frame = CGRect(
                        x: surfaceFrame.maxX + rightWingOffset,
                        y: y,
                        width: size,
                        height: size
                    )
                    rightWingOffset += size + spacing
                }

                result[bubble.id] = clamped(frame, to: screenFrame)
            }

        case .stack:
            var yCursor = surfaceFrame.minY - gap - globalVerticalOffset
            for bubble in standardBubbles {
                let style = settings.resolvedStyle(for: bubble.kind)
                let size = bubble.size
                yCursor -= size + style.verticalOffset
                let frame = CGRect(
                    x: surfaceFrame.midX - size / 2,
                    y: yCursor,
                    width: size,
                    height: size
                )
                result[bubble.id] = clamped(frame, to: screenFrame)
                yCursor -= spacing
            }
        }

        switch settings.resolvedAppMinimizeBubblePlacement {
        case .left, .right:
            let menuBarHeight = max(1, compactHeight)
            let menuBarCenterY = screenFrame.maxY - menuBarHeight / 2
            let appSide: NotchBubbleSide =
                settings.resolvedAppMinimizeBubblePlacement == .left ? .left : .right

            for bubble in appBubbles {
                let style = settings.resolvedStyle(for: bubble.kind)
                let size = bubble.size
                let y = menuBarCenterY - size / 2 - globalVerticalOffset - style.verticalOffset
                let frame: CGRect

                if appSide == .left {
                    frame = CGRect(
                        x: surfaceFrame.minX - leftWingOffset - size,
                        y: y,
                        width: size,
                        height: size
                    )
                    leftWingOffset += size + spacing
                } else {
                    frame = CGRect(
                        x: surfaceFrame.maxX + rightWingOffset,
                        y: y,
                        width: size,
                        height: size
                    )
                    rightWingOffset += size + spacing
                }

                result[bubble.id] = clamped(frame, to: screenFrame)
            }

        case .belowNotch:
            let startY: CGFloat = {
                guard settings.layout != .wings,
                      let lowestStandardY = result.values.map(\.minY).min() else {
                    return surfaceFrame.minY - gap - globalVerticalOffset
                }
                return min(
                    surfaceFrame.minY - gap - globalVerticalOffset,
                    lowestStandardY - spacing
                )
            }()

            var rows: [[NotchBubble]] = []
            var currentRow: [NotchBubble] = []
            var currentWidth: CGFloat = 0

            for bubble in appBubbles {
                let addedWidth = bubble.size + (currentRow.isEmpty ? 0 : spacing)
                if !currentRow.isEmpty && currentWidth + addedWidth > availableWidth {
                    rows.append(currentRow)
                    currentRow = [bubble]
                    currentWidth = bubble.size
                } else {
                    currentRow.append(bubble)
                    currentWidth += addedWidth
                }
            }
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }

            var yCursor = startY
            for row in rows {
                let rowHeight = row.map(\.size).max() ?? 0
                let totalWidth = row.reduce(CGFloat.zero) { $0 + $1.size }
                    + CGFloat(max(0, row.count - 1)) * spacing
                var x = surfaceFrame.midX - totalWidth / 2
                let rowY = yCursor - rowHeight

                for bubble in row {
                    let style = settings.resolvedStyle(for: bubble.kind)
                    let y = rowY + (rowHeight - bubble.size) / 2 - style.verticalOffset
                    let frame = CGRect(x: x, y: y, width: bubble.size, height: bubble.size)
                    result[bubble.id] = clamped(frame, to: screenFrame)
                    x += bubble.size + spacing
                }

                yCursor = rowY - spacing
            }
        }

        return result
    }

    private func fallbackSide(for mode: NotchBubbleSideMode) -> NotchBubbleSide {
        switch mode {
        case .automatic, .left:
            return .left
        case .right:
            return .right
        }
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

    var bubbleKind: NotchBubbleKind?
    var bubbleIdentifier: String?

    private var horizontalAccumulator: CGFloat = 0
    private var verticalAccumulator: CGFloat = 0
    private var triggeredDuringCurrentTrackpadGesture = false

    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel,
           handleBubbleScrollGesture(event) {
            return
        }
        super.sendEvent(event)
    }

    private func handleBubbleScrollGesture(_ event: NSEvent) -> Bool {
        guard let bubbleKind, let bubbleIdentifier else { return false }

        if event.phase == .began || event.phase == .mayBegin {
            horizontalAccumulator = 0
            verticalAccumulator = 0
            triggeredDuringCurrentTrackpadGesture = false
        }

        // Ignore inertial continuation after the user's fingers leave the trackpad.
        if event.momentumPhase != [] {
            if event.momentumPhase == .ended {
                horizontalAccumulator = 0
                verticalAccumulator = 0
                triggeredDuringCurrentTrackpadGesture = false
            }
            return false
        }

        if event.phase == .ended || event.phase == .cancelled {
            let consumed = event.hasPreciseScrollingDeltas && triggeredDuringCurrentTrackpadGesture
            horizontalAccumulator = 0
            verticalAccumulator = 0
            triggeredDuringCurrentTrackpadGesture = false
            return consumed
        }

        // Normalize Natural Scrolling so the setting always describes the physical
        // two-finger direction on the trackpad.
        let inversion: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
        let dx = event.scrollingDeltaX * inversion
        let dy = event.scrollingDeltaY * inversion
        guard abs(dx) > 0.05 || abs(dy) > 0.05 else { return false }

        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 10 : 0.5
        horizontalAccumulator += dx
        verticalAccumulator += dy

        let direction: NotchBubbleGestureDirection?
        if abs(horizontalAccumulator) >= threshold,
           abs(horizontalAccumulator) >= abs(verticalAccumulator) {
            direction = horizontalAccumulator > 0 ? .left : .right
        } else if abs(verticalAccumulator) >= threshold {
            direction = verticalAccumulator < 0 ? .down : .up
        } else {
            direction = nil
        }

        guard let direction else { return false }

        horizontalAccumulator = 0
        verticalAccumulator = 0

        let isRepeat = event.hasPreciseScrollingDeltas && triggeredDuringCurrentTrackpadGesture
        if event.hasPreciseScrollingDeltas {
            triggeredDuringCurrentTrackpadGesture = true
        }

        NotificationCenter.default.post(
            name: .haloNotchBubbleDirectionalGesture,
            object: bubbleIdentifier,
            userInfo: [
                "direction": direction.rawValue,
                "repeat": isRepeat
            ]
        )
        return true
    }
}

private final class TransparentNotchBubbleHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    var forceTouchActivityID: String?
    private var forceTouchTriggered = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryDeepClick)
    }

    override func pressureChange(with event: NSEvent) {
        if event.stage >= 2 {
            if !forceTouchTriggered, let forceTouchActivityID {
                forceTouchTriggered = true
                NotificationCenter.default.post(
                    name: .haloNotchBubbleForceTouch,
                    object: forceTouchActivityID
                )
            }
        } else if event.stage == 0 {
            forceTouchTriggered = false
        }

        super.pressureChange(with: event)
    }
}

@MainActor
private final class FluidNotchBridgePanel {
    private let panel: NSPanel
    private let shapeLayer = CAShapeLayer()

    init() {
        panel = NSPanel(
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
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
        view.layer?.masksToBounds = false

        shapeLayer.fillColor = NSColor.black.withAlphaComponent(0.985).cgColor
        shapeLayer.strokeColor = NSColor.white.withAlphaComponent(0.035).cgColor
        shapeLayer.lineWidth = 0.7
        shapeLayer.actions = [
            "path": NSNull(),
            "opacity": NSNull(),
            "bounds": NSNull(),
            "position": NSNull()
        ]
        view.layer?.addSublayer(shapeLayer)
        panel.contentView = view
    }

    func update(
        notchSource: CGRect,
        bubbleFrame: CGRect,
        direction: CGFloat,
        strength rawStrength: CGFloat,
        bubblePanel: NSPanel
    ) {
        let strength = min(1, max(0, rawStrength))
        guard strength > 0.015,
              direction != 0,
              bubblePanel.isVisible else {
            hide()
            return
        }

        let notchX = notchSource.midX
        let notchY = notchSource.midY
        // fluidNotchDirection points from the bubble toward the notch. Attach the
        // connector to the bubble edge facing that notch.
        let bubbleNearX = direction > 0 ? bubbleFrame.maxX : bubbleFrame.minX
        let distance = abs(bubbleNearX - notchX)

        guard distance > 0.5 else {
            hide()
            return
        }

        let padding: CGFloat = 12
        let minX = min(notchX, bubbleNearX) - padding
        let maxX = max(notchX, bubbleNearX) + padding
        let verticalExtent = max(notchSource.height, bubbleFrame.height) * 0.65 + padding
        let frame = CGRect(
            x: minX,
            y: min(notchY, bubbleFrame.midY) - verticalExtent,
            width: max(1, maxX - minX),
            height: max(1, abs(bubbleFrame.midY - notchY) + verticalExtent * 2)
        )

        panel.setFrame(frame, display: false)
        guard let view = panel.contentView else { return }
        view.frame = CGRect(origin: .zero, size: frame.size)
        shapeLayer.frame = view.bounds

        let localNotch = CGPoint(
            x: notchX - frame.minX,
            y: notchY - frame.minY
        )
        let localBubble = CGPoint(
            x: bubbleNearX - frame.minX,
            y: bubbleFrame.midY - frame.minY
        )

        shapeLayer.path = bridgePath(
            notch: localNotch,
            bubble: localBubble,
            bubbleHeight: bubbleFrame.height,
            direction: direction,
            strength: strength
        )
        shapeLayer.opacity = Float(min(0.995, 0.76 + 0.24 * strength))

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        panel.order(.below, relativeTo: bubblePanel.windowNumber)
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func bridgePath(
        notch: CGPoint,
        bubble: CGPoint,
        bubbleHeight: CGFloat,
        direction: CGFloat,
        strength: CGFloat
    ) -> CGPath {
        let distance = max(1, abs(bubble.x - notch.x))
        let verticalDelta = bubble.y - notch.y
        let bubbleHalf = max(2.5, min(bubbleHeight * 0.38, 4 + bubbleHeight * 0.30 * strength))
        let notchHalf = max(3.5, min(bubbleHeight * 0.34, 5 + bubbleHeight * 0.24 * strength))

        // The neck stays broad near the notch, then pinches closer to the bubble.
        // That asymmetry is what makes the surface read as if it is stretching out
        // rather than a pill simply sliding away from it.
        let neckPinch = max(2.0, bubbleHalf * (0.34 + 0.36 * strength))
        let control = min(distance * 0.52, max(12, bubbleHeight * 0.95))
        let towardBubble: CGFloat = bubble.x >= notch.x ? 1 : -1
        let signedControl = towardBubble * control

        let topNotch = CGPoint(x: notch.x, y: notch.y + notchHalf)
        let bottomNotch = CGPoint(x: notch.x, y: notch.y - notchHalf)
        let topBubble = CGPoint(x: bubble.x, y: bubble.y + neckPinch)
        let bottomBubble = CGPoint(x: bubble.x, y: bubble.y - neckPinch)

        let path = CGMutablePath()
        path.move(to: topNotch)
        path.addCurve(
            to: topBubble,
            control1: CGPoint(
                x: notch.x + signedControl * 0.34,
                y: notch.y + notchHalf + verticalDelta * 0.14
            ),
            control2: CGPoint(
                x: bubble.x - signedControl * 0.58,
                y: bubble.y + bubbleHalf
            )
        )
        path.addLine(to: bottomBubble)
        path.addCurve(
            to: bottomNotch,
            control1: CGPoint(
                x: bubble.x - signedControl * 0.58,
                y: bubble.y - bubbleHalf
            ),
            control2: CGPoint(
                x: notch.x + signedControl * 0.34,
                y: notch.y - notchHalf + verticalDelta * 0.14
            )
        )
        path.closeSubpath()

        // A small lobe at the notch edge makes the bridge visually deform the
        // notch instead of looking like a separate rectangle placed behind it.
        let lobeRadius = max(4, notchHalf * (0.78 + 0.28 * strength))
        path.addEllipse(
            in: CGRect(
                x: notch.x - lobeRadius,
                y: notch.y - lobeRadius,
                width: lobeRadius * 2,
                height: lobeRadius * 2
            )
        )
        return path
    }
}

@MainActor
private final class BubbleFrameAnimator {
    private enum LifecycleMotion {
        case emerge
        case retract
        case restore
    }

    private let clock = DisplayClock()
    private let fluidBridge = FluidNotchBridgePanel()

    func cancel(hideFluidBridge: Bool = true) {
        clock.stop()
        if hideFluidBridge {
            fluidBridge.hide()
        }
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
        case .fluid: duration = 0.22
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

        let notchDirection = fluidNotchDirection(visibleFrame: target, notchFrame: source)
        let usesHorizontalFluid = preset == .fluid && notchDirection != 0

        panel.setFrame(source, display: false)
        panel.alphaValue = 1

        let startTransform: CGAffineTransform
        let startOpacity: Double
        if usesHorizontalFluid {
            startTransform = fluidTransform(
                absorption: 1,
                notchDirection: notchDirection,
                width: target.width
            )
            startOpacity = fluidOpacity(absorption: 1)
        } else {
            startTransform = CGAffineTransform(scaleX: 0.18, y: 0.18)
            startOpacity = 0.58
        }

        view.layer?.setAffineTransform(startTransform)
        view.layer?.opacity = Float(startOpacity)
        panel.orderFrontRegardless()

        animateLifecycle(
            panel: panel,
            view: view,
            from: source,
            to: target,
            preset: preset,
            duration: duration,
            startTransform: startTransform,
            endTransform: .identity,
            startOpacity: startOpacity,
            endOpacity: 1,
            motion: .emerge,
            fluidNotchDirection: notchDirection,
            fluidSourceFrame: source,
            completion: completion
        )
    }

    func restoreFromCurrent(
        panel: NSPanel,
        to target: CGRect,
        notchSource: CGRect,
        preset: NotchBubbleAnimationPreset,
        duration: TimeInterval,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        cancel(hideFluidBridge: false)
        guard let view = panel.contentView else {
            panel.setFrame(target, display: false)
            panel.alphaValue = 1
            completion?()
            return
        }

        let currentTransform = view.layer?.affineTransform() ?? .identity
        let currentOpacity = Double(view.layer?.opacity ?? 1)

        guard animated,
              preset != .none,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(target, display: false)
            resetVisuals(panel: panel)
            completion?()
            return
        }

        let currentFrame = panel.frame
        let dx = target.midX - currentFrame.midX
        let dy = target.midY - currentFrame.midY
        let notchDirection: CGFloat = abs(dx) > 8 && abs(dx) >= abs(dy) * 0.55
            ? (dx > 0 ? -1 : 1)
            : 0

        animateLifecycle(
            panel: panel,
            view: view,
            from: currentFrame,
            to: target,
            preset: preset,
            duration: duration,
            startTransform: currentTransform,
            endTransform: .identity,
            startOpacity: currentOpacity,
            endOpacity: 1,
            motion: .restore,
            fluidNotchDirection: notchDirection,
            fluidSourceFrame: notchSource,
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
        let currentTransform = view.layer?.affineTransform() ?? .identity
        let currentOpacity = Double(view.layer?.opacity ?? 1)
        let notchDirection = fluidNotchDirection(visibleFrame: initial, notchFrame: source)
        let usesHorizontalFluid = preset == .fluid && notchDirection != 0

        let endTransform: CGAffineTransform
        let endOpacity: Double
        if usesHorizontalFluid {
            endTransform = fluidTransform(
                absorption: 1,
                notchDirection: notchDirection,
                width: initial.width
            )
            endOpacity = fluidOpacity(absorption: 1)
        } else {
            endTransform = CGAffineTransform(scaleX: 0.18, y: 0.18)
            endOpacity = 0.58
        }

        animateLifecycle(
            panel: panel,
            view: view,
            from: initial,
            to: source,
            preset: preset,
            duration: duration,
            startTransform: currentTransform,
            endTransform: endTransform,
            startOpacity: currentOpacity,
            endOpacity: endOpacity,
            motion: .retract,
            fluidNotchDirection: notchDirection,
            fluidSourceFrame: source
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
        startTransform: CGAffineTransform,
        endTransform: CGAffineTransform,
        startOpacity: Double,
        endOpacity: Double,
        motion: LifecycleMotion,
        fluidNotchDirection: CGFloat,
        fluidSourceFrame: CGRect?,
        completion: (() -> Void)? = nil
    ) {
        let start = CACurrentMediaTime()
        let duration = max(0.01, duration)
        let horizontalFluid = preset == .fluid && fluidNotchDirection != 0

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

            if horizontalFluid, let fluidSourceFrame {
                self.fluidBridge.update(
                    notchSource: fluidSourceFrame,
                    bubbleFrame: frame,
                    direction: fluidNotchDirection,
                    strength: self.fluidBridgeStrength(
                        t: CGFloat(t),
                        motion: motion,
                        bubbleFrame: frame,
                        notchSource: fluidSourceFrame
                    ),
                    bubblePanel: panel
                )
            } else {
                self.fluidBridge.hide()
            }

            let transform: CGAffineTransform
            let opacity: Double

            if horizontalFluid {
                switch motion {
                case .emerge:
                    let absorption = CGFloat(1 - t)
                    transform = self.fluidTransform(
                        absorption: absorption,
                        notchDirection: fluidNotchDirection,
                        width: max(initial.width, target.width)
                    )
                    opacity = self.fluidOpacity(absorption: absorption)

                case .retract:
                    let absorption = CGFloat(t)
                    transform = self.fluidTransform(
                        absorption: absorption,
                        notchDirection: fluidNotchDirection,
                        width: max(initial.width, target.width)
                    )
                    opacity = self.fluidOpacity(absorption: absorption)

                case .restore:
                    // Restores can begin halfway through a retract. Blend from the exact
                    // presentation transform so reversing direction never snaps.
                    transform = self.interpolateTransform(
                        from: startTransform,
                        to: .identity,
                        progress: p
                    )
                    opacity = startOpacity + (1 - startOpacity) * Double(p)
                }
            } else {
                transform = self.interpolateTransform(
                    from: startTransform,
                    to: endTransform,
                    progress: p
                )
                opacity = startOpacity + (endOpacity - startOpacity) * Double(p)
            }

            view.layer?.setAffineTransform(transform)
            view.layer?.opacity = Float(min(1, max(0, opacity)))

            if t >= 1 {
                self.cancel()
                self.fluidBridge.hide()
                panel.setFrame(target, display: false)
                if endTransform.isIdentity && endOpacity >= 0.999 {
                    self.resetVisuals(panel: panel)
                }
                completion?()
            }
        }
    }

    private func fluidBridgeStrength(
        t: CGFloat,
        motion: LifecycleMotion,
        bubbleFrame: CGRect,
        notchSource: CGRect
    ) -> CGFloat {
        let normalized = min(1, max(0, t))
        let base: CGFloat

        switch motion {
        case .emerge, .retract:
            // Form the neck quickly, keep it through the middle of the travel,
            // then pinch it away before the bubble fully settles.
            let sine = sin(.pi * normalized)
            base = pow(max(0, sine), 0.58)

        case .restore:
            // Reversing a retract should peel the bubble back away from the notch
            // without snapping the connector out on the first frame.
            base = pow(max(0, 1 - normalized), 0.72)
        }

        let distance = abs(bubbleFrame.midX - notchSource.midX)
        let scale = max(1, max(bubbleFrame.width, notchSource.width))
        let separation = min(1, distance / (scale * 0.92))
        return min(1, max(0, base * (0.38 + 0.62 * separation)))
    }

    /// Direction from the visible bubble toward the compact notch edge.
    /// Fluid is intentionally horizontal: vertical/stacked layouts keep the legacy
    /// scale motion rather than producing a sideways-looking liquid effect.
    private func fluidNotchDirection(visibleFrame: CGRect, notchFrame: CGRect) -> CGFloat {
        let dx = notchFrame.midX - visibleFrame.midX
        let dy = notchFrame.midY - visibleFrame.midY
        guard abs(dx) > 8, abs(dx) >= abs(dy) * 0.55 else { return 0 }
        return dx > 0 ? 1 : -1
    }

    /// Metaball-inspired squash/stretch. The bubble first stretches toward the notch,
    /// then narrows while its mass is pulled into the compact surface. Reversing
    /// absorption produces the emergence motion.
    private func fluidTransform(
        absorption rawAbsorption: CGFloat,
        notchDirection: CGFloat,
        width: CGFloat
    ) -> CGAffineTransform {
        let absorption = min(1, max(0, rawAbsorption))

        let stretchPhase = min(1, absorption / 0.82)
        let stretch = sin(.pi * stretchPhase)
        let collapse = smootherstep(min(1, max(0, (absorption - 0.48) / 0.52)))

        let scaleX = 1 + 0.42 * stretch - 0.82 * collapse
        let scaleY = 1 - 0.15 * stretch - 0.32 * collapse

        // Shift the stretched mass toward the notch so the near edge visually stays
        // attached longer instead of reading as a uniformly scaled floating circle.
        let translation = notchDirection * width * (0.14 * stretch + 0.12 * collapse)

        return CGAffineTransform(
            a: max(0.16, scaleX),
            b: 0,
            c: 0,
            d: max(0.62, scaleY),
            tx: translation,
            ty: 0
        )
    }

    private func fluidOpacity(absorption: CGFloat) -> Double {
        let value = Double(min(1, max(0, absorption)))
        // Keep the droplet visually solid almost all the way into the notch. A heavy
        // fade breaks the illusion that it is being absorbed by the surface.
        return 1 - 0.08 * pow(value, 5)
    }

    private func interpolateTransform(
        from start: CGAffineTransform,
        to end: CGAffineTransform,
        progress: CGFloat
    ) -> CGAffineTransform {
        let p = progress
        return CGAffineTransform(
            a: start.a + (end.a - start.a) * p,
            b: start.b + (end.b - start.b) * p,
            c: start.c + (end.c - start.c) * p,
            d: start.d + (end.d - start.d) * p,
            tx: start.tx + (end.tx - start.tx) * p,
            ty: start.ty + (end.ty - start.ty) * p
        )
    }

    private func smootherstep(_ x: CGFloat) -> CGFloat {
        let value = min(1, max(0, x))
        return value * value * value * (value * (value * 6 - 15) + 10)
    }

    private func progress(_ t: CFTimeInterval, preset: NotchBubbleAnimationPreset) -> CGFloat {
        if t >= 1 { return 1 }
        let value: Double
        switch preset {
        case .soft:
            value = -(cos(.pi * t) - 1) / 2
        case .fluid:
            // Symmetric acceleration/deceleration gives the blob enough time to form
            // a visible neck at the surface instead of shooting through the join.
            value = t * t * t * (t * (t * 6 - 15) + 10)
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

    let id: String
    let kind: NotchBubbleKind

    private let panel: NotchBubblePanel
    private let frameAnimator = BubbleFrameAnimator()
    private var removalGeneration = 0
    private var lifecyclePhase: LifecyclePhase = .hidden
    private var desiredFrame: CGRect = .zero

    var frame: CGRect { panel.frame }

    init(id: String, kind: NotchBubbleKind, store: AppStore, state: SurfaceState) {
        self.id = id
        self.kind = kind
        panel = NotchBubblePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.bubbleKind = kind
        panel.bubbleIdentifier = id
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
            activityID: id,
            kind: kind,
            store: store,
            workspace: store.workspace,
            surfaceState: state
        )
        let view = TransparentNotchBubbleHostingView(rootView: root)
        view.forceTouchActivityID = id
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
                notchSource: emergenceFrame,
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
    private let minimizedWindowCenter = MinimizedWindowBubbleCenter.shared
    private let registry = BubbleRegistry()
    private let layoutEngine = BubbleLayoutEngine()

    private weak var surfacePanel: HaloPanel?
    private weak var state: SurfaceState?
    private var screenFrame: CGRect
    private var surfaceFrame: CGRect
    private var surfaceRuntimeEnabled = false
    private var controllers: [String: BubbleWindowController] = [:]
    // Side ownership is intentionally stateful. Auto placement assigns a side when
    // a bubble first appears and never moves an existing bubble across the notch
    // just to rebalance the layout.
    private var bubbleSideAssignments: [String: NotchBubbleSide] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var lastCalendarActivityID: String?
    private var lastObservedSettings: NotchBubbleSettings

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
        self.lastObservedSettings = settingsStore.settings.normalized()
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

    func setSurfaceRuntimeEnabled(_ granted: Bool) {
        guard surfaceRuntimeEnabled != granted else { return }
        surfaceRuntimeEnabled = granted
        refresh(animated: true)
    }

    func stop() {
        subscriptions.removeAll()
        for controller in controllers.values {
            controller.close()
        }
        controllers.removeAll()
        bubbleSideAssignments.removeAll()
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
            .sink { [weak self] value in
                guard let self else { return }
                let settings = value.normalized()
                let previous = self.lastObservedSettings
                self.lastObservedSettings = settings

                for kind in NotchBubbleKind.allCases {
                    let becameEnabled =
                        !previous.isProviderEnabled(kind) &&
                        settings.isProviderEnabled(kind)
                    let becamePinned =
                        !previous.requestsPinnedPresentation(kind) &&
                        settings.requestsPinnedPresentation(kind)
                    if becameEnabled || becamePinned {
                        self.activityCenter.clearDismissal(kind: kind)
                    }
                }

                if settings.resolvedCalendarEnabled,
                   self.store.workspace.calendar.hasAccess {
                    self.store.workspace.calendar.refresh()
                }
                self.refresh(animated: true)
            }
            .store(in: &subscriptions)

        HaloFeatureAccess.shared.$accessLevel
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
            .sink { [weak self] finished in
                guard let self else { return }
                self.activityCenter.clearDismissal(kind: .timer)
                if finished, self.settingsStore.settings.timerEnabled {
                    self.activityCenter.publishCompletion(
                        kind: .timer,
                        sourceIdentifier: "halo.timer",
                        title: "Timer complete",
                        subtitle: "Focus session finished",
                        icon: "checkmark.circle.fill",
                        duration: self.settingsStore.settings.normalized().resolvedCompletionDuration
                    )
                } else if !finished {
                    self.activityCenter.clearTransient(kind: .timer)
                }
                self.refresh(animated: true)
            }
            .store(in: &subscriptions)

        store.workspace.$stopwatchStart
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.activityCenter.clearDismissal(kind: .stopwatch)
                self?.refresh(animated: true)
            }
            .store(in: &subscriptions)

        store.workspace.$stopwatchElapsed
            .map { $0 > 0.001 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.$files
            .map { $0.map(\.path) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.activityCenter.clearDismissal(kind: .files)
                self?.refresh(animated: true)
            }
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
            .sink { [weak self] _ in
                self?.activityCenter.clearDismissal(kind: .pixelPal)
                self?.refresh(animated: true)
            }
            .store(in: &subscriptions)

        activityCenter.$transientActivities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        activityCenter.$suppressedKinds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        minimizedWindowCenter.$entries
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh(animated: true) }
            .store(in: &subscriptions)

        store.workspace.calendar.$calendarRevision
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let nextID = self.currentCalendarActivityIdentity()
                if let previous = self.lastCalendarActivityID,
                   previous != nextID {
                    self.activityCenter.clearDismissal(kind: .calendar)
                }
                self.lastCalendarActivityID = nextID
                self.refresh(animated: true)
            }
            .store(in: &subscriptions)

        Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let settings = self.settingsStore.settings.normalized()
                if settings.resolvedAudioEnabled {
                    self.store.workspace.audio.refresh()
                }
                if settings.resolvedSystemEnabled {
                    self.store.workspace.system.refresh(detailed: true)
                }
            }
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

    private func currentCalendarActivityIdentity() -> String? {
        let settings = settingsStore.settings.normalized()
        guard settings.resolvedCalendarEnabled else { return nil }
        let now = Date()
        let lead = settings.resolvedCalendarLeadMinutes * 60
        guard let event = store.workspace.calendar.upcomingEvents.first(where: {
            $0.endDate > now &&
            ($0.startDate.timeIntervalSince(now) <= lead || settings.resolvedCalendarPersistent)
        }) else { return nil }
        return event.eventIdentifier
            ?? "\(event.startDate.timeIntervalSinceReferenceDate)-\(event.title ?? "event")"
    }

    private func refresh(animated: Bool, trackingSurface: Bool = false) {
        guard let state else {
            removeAll(animated: false)
            return
        }

        let settings = HaloFeatureAccess.shared.effectiveBubbleSettings(
            settingsStore.settings.normalized()
        )
        let allowedBySurfaceState = state.expanded ? settings.showWhenOpen : settings.showWhenClosed

        guard surfaceRuntimeEnabled,
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

        let bubbles = registry.bubbles(
            store: store,
            settings: settings,
            runtime: activityCenter,
            surfaceExpanded: state.expanded
        )
        let sideAssignments = resolvedSideAssignments(
            for: bubbles,
            settings: settings
        )
        let frames = layoutEngine.frames(
            for: bubbles,
            around: surfaceFrame,
            in: screenFrame,
            compactHeight: state.compactHeight,
            settings: settings,
            sideAssignments: sideAssignments
        )
        let activeIDs = Set(bubbles.map(\.id))

        for id in Array(controllers.keys) where !activeIDs.contains(id) {
            guard let controller = controllers[id] else { continue }
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
                      self.controllers[id] === controller else { return }
                controller.close()
                self.controllers.removeValue(forKey: id)
                self.bubbleSideAssignments.removeValue(forKey: id)
            }
        }

        for bubble in bubbles {
            guard let frame = frames[bubble.id] else { continue }
            let controller: BubbleWindowController
            if let existing = controllers[bubble.id] {
                controller = existing
            } else {
                controller = BubbleWindowController(id: bubble.id, kind: bubble.kind, store: store, state: state)
                controllers[bubble.id] = controller
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

    private func resolvedSideAssignments(
        for bubbles: [NotchBubble],
        settings: NotchBubbleSettings
    ) -> [String: NotchBubbleSide] {
        guard settings.layout == .wings else { return [:] }

        let activeIDs = Set(bubbles.map(\.id))
        let retainedIDs = Set(controllers.keys).union(activeIDs)
        bubbleSideAssignments = bubbleSideAssignments.filter {
            retainedIDs.contains($0.key)
        }

        switch settings.resolvedBubbleSideMode {
        case .left:
            for id in activeIDs {
                bubbleSideAssignments[id] = .left
            }

        case .right:
            for id in activeIDs {
                bubbleSideAssignments[id] = .right
            }

        case .automatic:
            // Count currently-owned sides first. Existing bubbles keep their side.
            // Only bubbles without an assignment participate in balancing.
            var leftCount = bubbleSideAssignments.values.reduce(into: 0) { count, side in
                if side == .left { count += 1 }
            }
            var rightCount = bubbleSideAssignments.values.reduce(into: 0) { count, side in
                if side == .right { count += 1 }
            }

            for bubble in bubbles where bubbleSideAssignments[bubble.id] == nil {
                let side: NotchBubbleSide
                if leftCount == rightCount {
                    side = settings.resolvedAutomaticPrioritySide
                } else if leftCount < rightCount {
                    side = .left
                } else {
                    side = .right
                }

                bubbleSideAssignments[bubble.id] = side
                if side == .left {
                    leftCount += 1
                } else {
                    rightCount += 1
                }
            }
        }

        return bubbleSideAssignments
    }

    private func removeAll(animated: Bool) {
        let settings = HaloFeatureAccess.shared.effectiveBubbleSettings(
            settingsStore.settings.normalized()
        )
        let compactWidth: CGFloat = {
            guard let state else { return 190 }
            return state.physicalNotchWidth > 1 ? state.physicalNotchWidth : state.compactWidth
        }()
        let compactHeight: CGFloat = {
            guard let state else { return 40 }
            return state.physicalNotchHeight > 1 ? state.physicalNotchHeight : state.compactHeight
        }()

        for (id, controller) in controllers {
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
                      self.controllers[id] === controller else { return }
                controller.close()
                self.controllers.removeValue(forKey: id)
                self.bubbleSideAssignments.removeValue(forKey: id)
            }
        }
    }
}

@MainActor
final class NotchBubbleManager {
    private let store: AppStore
    private let settingsStore = NotchBubbleSettingsStore.shared
    private let activityCenter = NotchBubbleActivityCenter.shared
    private let minimizedWindowCenter = MinimizedWindowBubbleCenter.shared
    private var hosts: [String: NotchBubbleDisplayHost] = [:]
    private var surfaceRuntimeEnabled = false
    private var subscriptions = Set<AnyCancellable>()

    init(store: AppStore) {
        self.store = store

        NotificationCenter.default.publisher(for: .init("HaloBubbleHUDEvent"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self, let event = note.object as? HaloHUDEvent else { return }
                self.activityCenter.publishHUD(
                    event,
                    settings: HaloFeatureAccess.shared.effectiveBubbleSettings(
                        self.settingsStore.settings.normalized()
                    )
                )
            }
            .store(in: &subscriptions)

        settingsStore.$settings
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAppWindowMonitoring() }
            .store(in: &subscriptions)

        HaloFeatureAccess.shared.$accessLevel
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAppWindowMonitoring() }
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
        host.setSurfaceRuntimeEnabled(surfaceRuntimeEnabled)
        hosts[displayID] = host
    }

    func unregister(displayID: String) {
        hosts.removeValue(forKey: displayID)?.stop()
    }

    func setSurfaceRuntimeEnabled(_ granted: Bool) {
        surfaceRuntimeEnabled = granted
        for host in hosts.values {
            host.setSurfaceRuntimeEnabled(granted)
        }
        refreshAppWindowMonitoring()
    }

    private func refreshAppWindowMonitoring() {
        let settings = HaloFeatureAccess.shared.effectiveBubbleSettings(
            settingsStore.settings.normalized()
        )
        minimizedWindowCenter.setEnabled(
            surfaceRuntimeEnabled &&
            settings.enabled &&
            settings.resolvedAppMinimizeBubblesEnabled
        )
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
    let activityID: String
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
    @ObservedObject private var activityCenter = NotchBubbleActivityCenter.shared
    @ObservedObject private var minimizedWindowCenter = MinimizedWindowBubbleCenter.shared
    @ObservedObject private var appWindowPreviewCenter = AppWindowPreviewCenter.shared

    @State private var hovering = false
    @State private var showingDetail = false
    @State private var showingWindowPreview = false
    @State private var lastForceTouchAt: Date?
    @State private var lastNonZeroAudioVolume: Float = 0.5

    init(activityID: String, kind: NotchBubbleKind, store: AppStore, workspace: WorkspaceStore, surfaceState: SurfaceState) {
        self.activityID = activityID
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
        HaloFeatureAccess.shared.effectiveBubbleSettings(settingsStore.settings.normalized())
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
            .onHover { value in
                if value && !hovering {
                    HaloHoverHaptics.pulse(
                        id: "bubble." + surfaceState.displayID + "." + activityID,
                        strength: store.configuration.resolvedHoverHapticStrength,
                        pattern: store.configuration.resolvedHoverHapticPattern
                    )
                }

                hovering = value
                updateInteractionProtection()
            }
            .onChange(of: showingDetail) { _ in
                updateInteractionProtection()
            }
            .onChange(of: showingWindowPreview) { _ in
                updateInteractionProtection()
            }
            .onReceive(NotificationCenter.default.publisher(for: .haloNotchBubbleForceTouch)) { note in
                guard kind == .appWindow,
                      note.object as? String == activityID,
                      let entry = appWindowEntry else {
                    return
                }

                lastForceTouchAt = Date()
                showingDetail = false
                showingWindowPreview = true
                appWindowPreviewCenter.loadPreview(
                    activityID: activityID,
                    entry: entry,
                    forceRefresh: true
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .haloNotchBubbleDirectionalGesture)) { note in
                guard note.object as? String == activityID,
                      let rawDirection = note.userInfo?["direction"] as? String,
                      let direction = NotchBubbleGestureDirection(rawValue: rawDirection) else {
                    return
                }

                let configuration = settings.gestureConfiguration(
                    for: kind,
                    direction: direction
                )
                let isRepeat = note.userInfo?["repeat"] as? Bool ?? false

                guard !isRepeat || configuration.shouldRepeat else { return }

                _ = performGestureAction(
                    configuration.action,
                    amount: configuration.amount,
                    hapticStrength: configuration.hapticStrength,
                    hapticPattern: configuration.hapticPattern
                )
            }
            .simultaneousGesture(
                TapGesture(count: 2)
                    .exclusively(before: TapGesture(count: 1))
                    .onEnded { result in
                        switch result {
                        case .first:
                            let configuration = settings.doubleClickConfiguration(for: kind)
                            _ = performGestureAction(
                                configuration.action,
                                amount: configuration.amount,
                                hapticStrength: configuration.hapticStrength,
                                hapticPattern: configuration.hapticPattern
                            )
                        case .second:
                            handlePrimaryTap()
                            let override = settings.styleOverride(for: kind)
                            HaloHoverHaptics.pulse(
                                id: "bubble.gesture.tap." + surfaceState.displayID + "." + activityID,
                                strength: override?.tapHapticStrength
                                    ?? store.configuration.resolvedHoverHapticStrength,
                                pattern: override?.tapHapticPattern
                                    ?? store.configuration.resolvedHoverHapticPattern,
                                minimumInterval: 0.04
                            )
                        }
                    }
            )
            .animation(hoverAnimation, value: hovering)
            .popover(isPresented: $showingDetail, arrowEdge: .top) {
                VStack(spacing: 10) {
                    detailView
                    Divider()
                    HStack {
                        Button("Dismiss current activity") {
                            dismissCurrentActivity()
                            showingDetail = false
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Text("Turn bubbles on/off in Notch Bubbles settings")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .padding(14)
                .frame(minWidth: detailWidth)
                .onExitCommand {
                    showingDetail = false
                }
            }
            .popover(isPresented: $showingWindowPreview, arrowEdge: .top) {
                appWindowPreviewCard
                    .onExitCommand {
                        showingWindowPreview = false
                    }
            }
            .contextMenu {
                Button("Dismiss current activity") {
                    dismissCurrentActivity()
                }
            }
            .accessibilityLabel(kind.title)
            .help(helpText)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if let confirmation = activityCenter.currentActivity(for: kind),
           confirmation.mode == .confirmation {
            confirmationBubbleContent(confirmation)
        } else {
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
            case .files:
                fileBubbleContent
            case .appWindow:
                appWindowBubbleContent
            }
        }
    }

    private var appWindowEntry: MinimizedWindowBubbleCenter.Entry? {
        minimizedWindowCenter.entry(activityID: activityID)
    }

    @ViewBuilder
    private var appWindowPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entry = appWindowEntry {
                HStack(spacing: 10) {
                    Group {
                        if let icon = minimizedWindowCenter.appIcon(for: entry) {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "macwindow")
                                .font(.title2)
                        }
                    }
                    .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.appName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(entry.windowTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    Button("Restore") {
                        if minimizedWindowCenter.restore(activityID: activityID) {
                            activityCenter.clearDismissal(kind: .appWindow)
                        }
                        showingWindowPreview = false
                    }
                    .buttonStyle(.borderedProminent)
                }

                Group {
                    if let image = appWindowPreviewCenter.image(for: activityID) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 520, maxHeight: 340)
                            .background(Color.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if appWindowPreviewCenter.loadingIDs.contains(activityID) {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Loading window preview…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let error = appWindowPreviewCenter.error(for: activityID) {
                        VStack(spacing: 10) {
                            Image(systemName: "rectangle.on.rectangle.slash")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text(error)
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)

                            if !appWindowPreviewCenter.screenCaptureGranted {
                                Button("Grant Screen Recording Access") {
                                    appWindowPreviewCenter.requestScreenCapturePermission()
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Retry Preview") {
                                    appWindowPreviewCenter.loadPreview(
                                        activityID: activityID,
                                        entry: entry,
                                        forceRefresh: true
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        Text("Force Touch this App Bubble to load a preview.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }

                Text("Force Touch previews the minimized window without restoring it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("This minimized window is no longer available.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 548)
    }

    @ViewBuilder
    private var appWindowBubbleContent: some View {
        if let entry = appWindowEntry {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let icon = minimizedWindowCenter.appIcon(for: entry) {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "macwindow")
                            .font(.system(size: bubbleStyle.size * 0.38, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(bubbleStyle.size * 0.12)

                if minimizedWindowCenter.entries.count > 1 {
                    Text("\(minimizedWindowCenter.entries.count)")
                        .font(.system(size: max(7, bubbleStyle.size * 0.14), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(providerAccentColor, in: Circle())
                        .padding(2)
                }
            }
        } else {
            Image(systemName: "macwindow")
                .font(.system(size: bubbleStyle.size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func confirmationBubbleContent(_ activity: NotchBubbleActivity) -> some View {
        ZStack {
            if let progress = activity.progress {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 2.8)
                    .padding(3)
                Circle()
                    .trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(
                        providerAccentColor,
                        style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(3)
            }

            VStack(spacing: 1) {
                Image(systemName: activity.icon)
                    .font(.system(
                        size: bubbleStyle.size * (activity.progress == nil ? 0.34 : 0.25),
                        weight: .semibold
                    ))

                if activity.progress == nil,
                   let subtitle = activity.subtitle,
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(
                            size: max(5, bubbleStyle.size * 0.09),
                            weight: .semibold,
                            design: .rounded
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .foregroundStyle(.white)
            .padding(4)
        }
        .accessibilityLabel(activity.title)
        .accessibilityValue(activity.subtitle ?? "")
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
    private var fileBubbleContent: some View {
        switch settings.resolvedFilesDisplayMode {
        case .latest:
            if let url = store.files.last {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .scaledToFit()
                        .padding(bubbleStyle.size * 0.18)
                    if store.files.count > 1 {
                        Text("\(store.files.count)")
                            .font(.system(size: max(7, bubbleStyle.size * 0.14), weight: .bold, design: .rounded))
                            .padding(4)
                            .background(providerAccentColor, in: Circle())
                            .foregroundStyle(.white)
                            .padding(3)
                    }
                }
            } else {
                Image(systemName: "tray")
                    .font(.system(size: bubbleStyle.size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }

        case .count:
            VStack(spacing: 0) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: bubbleStyle.size * 0.20, weight: .semibold))
                    .foregroundStyle(providerAccentColor)
                Text("\(store.files.count)")
                    .font(.system(size: max(12, bubbleStyle.size * 0.31), weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

        case .tray:
            Image(systemName: store.files.isEmpty ? "tray" : "tray.full.fill")
                .font(.system(size: bubbleStyle.size * 0.39, weight: .semibold))
                .foregroundStyle(.white)
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
        bubbleStyle.accent ?? defaultProviderAccentColor
    }

    private var defaultProviderAccentColor: Color {
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
        case .files:
            return Color(red: 0.32, green: 0.78, blue: 0.60)
        case .appWindow:
            return Color(red: 0.36, green: 0.68, blue: 1.0)
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
        let tintAmount = bubbleStyle.tintAmount

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
        case .files:
            moduleDetail(.shelf)
        case .appWindow:
            appWindowDetail
        }
    }

    private var appWindowDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let entry = appWindowEntry {
                HStack(spacing: 12) {
                    Group {
                        if let icon = minimizedWindowCenter.appIcon(for: entry) {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "macwindow")
                                .font(.title2)
                        }
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.appName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(entry.windowTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if minimizedWindowCenter.entries.count > 1 {
                            Text("\(minimizedWindowCenter.entries.count) minimized windows in the stack")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Button("Restore Window") {
                    _ = minimizedWindowCenter.restore(activityID: activityID)
                    activityCenter.clearDismissal(kind: .appWindow)
                    showingDetail = false
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No minimized app window is waiting.")
                    .foregroundStyle(.secondary)
            }
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
                    if let sourceName = connectedMediaAppName, media.isPlaying {
                        Label(sourceName, systemImage: "app.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
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
        case .files: return 354
        case .appWindow: return 360
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

    @discardableResult
    private func performGestureAction(
        _ action: NotchBubbleGestureAction,
        amount: Double,
        hapticStrength: Int?,
        hapticPattern: HaloHoverHapticPattern?
    ) -> Bool {
        let handled: Bool

        switch action {
        case .none:
            return false

        case .primaryAction:
            handlePrimaryTap()
            handled = true

        case .showDetails:
            showingDetail = true
            handled = true

        case .openNotch:
            openNotch()
            handled = true

        case .dismiss:
            dismissCurrentActivity()
            showingDetail = false
            handled = true

        case .playPause:
            guard kind == .music || kind == .vinyl else { return false }
            mediaCommand("playpause")
            handled = true

        case .previousTrack:
            guard kind == .music || kind == .vinyl else { return false }
            mediaCommand("previous track")
            handled = true

        case .nextTrack:
            guard kind == .music || kind == .vinyl else { return false }
            mediaCommand("next track")
            handled = true

        case .openMediaPlayer:
            guard kind == .music || kind == .vinyl else { return false }
            openMediaPlayer()
            handled = true

        case .seekBackward:
            guard (kind == .music || kind == .vinyl), media.duration > 0 else { return false }
            media.seek(to: media.position - action.normalizedGestureAmount(amount))
            handled = true

        case .seekForward:
            guard (kind == .music || kind == .vinyl), media.duration > 0 else { return false }
            media.seek(to: media.position + action.normalizedGestureAmount(amount))
            handled = true

        case .timerPauseResume:
            guard kind == .timer, timerIsActive else { return false }
            store.pauseResume()
            handled = true

        case .timerAddFive:
            guard kind == .timer else { return false }
            let minutes = max(1, Int(action.normalizedGestureAmount(amount).rounded()))
            if timerIsActive {
                store.addTimer(minutes: minutes)
            } else {
                store.startTimer(minutes: minutes)
            }
            handled = true

        case .stopwatchToggle:
            guard kind == .stopwatch else { return false }
            workspace.toggleStopwatch()
            handled = true

        case .stopwatchLap:
            guard kind == .stopwatch, workspace.stopwatchStart != nil else { return false }
            workspace.lapStopwatch()
            handled = true

        case .stopwatchReset:
            guard kind == .stopwatch else { return false }
            workspace.resetStopwatch()
            handled = true

        case .audioVolumeUp:
            guard kind == .audio, audio.canSetVolume else { return false }
            let delta = Float(action.normalizedGestureAmount(amount) / 100)
            let next = min(1, Float(audio.volume) + delta)
            if next > 0.001 { lastNonZeroAudioVolume = next }
            audio.setVolume(next)
            handled = true

        case .audioVolumeDown:
            guard kind == .audio, audio.canSetVolume else { return false }
            let delta = Float(action.normalizedGestureAmount(amount) / 100)
            let current = Float(audio.volume)
            if current > 0.001 { lastNonZeroAudioVolume = current }
            audio.setVolume(max(0, current - delta))
            handled = true

        case .audioMuteRestore:
            guard kind == .audio, audio.canSetVolume else { return false }
            let current = Float(audio.volume)
            if current > 0.001 {
                lastNonZeroAudioVolume = current
                audio.setVolume(0)
            } else {
                audio.setVolume(max(0.05, lastNonZeroAudioVolume))
            }
            handled = true

        case .openSoundSettings:
            guard kind == .audio else { return false }
            openSoundSettings()
            handled = true

        case .refreshSystem:
            guard kind == .system else { return false }
            system.refresh(detailed: true)
            handled = true

        case .feedPixelPal:
            guard kind == .pixelPal else { return false }
            pal.feedCookie()
            handled = true
        }

        if handled {
            HaloHoverHaptics.pulse(
                id: "bubble.gesture." + surfaceState.displayID + "." + kind.rawValue,
                strength: hapticStrength ?? store.configuration.resolvedHoverHapticStrength,
                pattern: hapticPattern ?? store.configuration.resolvedHoverHapticPattern,
                minimumInterval: 0.04
            )
        }

        return handled
    }

    private func handlePrimaryTap() {
        if kind == .appWindow,
           let lastForceTouchAt,
           Date().timeIntervalSince(lastForceTouchAt) < 0.7 {
            return
        }

        if kind == .appWindow {
            if minimizedWindowCenter.restore(activityID: activityID) {
                activityCenter.clearDismissal(kind: .appWindow)
            }
            showingDetail = false
            return
        }

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

    private func openSoundSettings() {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension"),
            URL(string: "x-apple.systempreferences:com.apple.preference.sound")
        ].compactMap { $0 }

        for url in urls where NSWorkspace.shared.open(url) {
            return
        }

        showingDetail = true
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

    private func updateInteractionProtection() {
        activityCenter.setInteracting(
            kind: kind,
            interacting: hovering || showingDetail || showingWindowPreview
        )
    }

    private func dismissCurrentActivity() {
        if kind == .appWindow {
            minimizedWindowCenter.dismiss(activityID: activityID)
        } else {
            activityCenter.dismiss(kind: kind)
        }
    }

    private func mediaCommand(_ command: String) {
        guard let sourceBundleID = media.connectedApp, !sourceBundleID.isEmpty else {
            media.performSystem(command)
            return
        }

        // The bubble must control the source it is displaying. Never show one app's
        // metadata while dispatching play/pause/skip to a separately preferred player.
        media.perform(command, app: sourceBundleID)
    }

    private var connectedMediaAppName: String? {
        guard let bundleID = media.connectedApp, !bundleID.isEmpty else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first?.localizedName ?? bundleID.split(separator: ".").last.map(String.init)
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

        case .timer, .pixelPal, .clock, .stopwatch, .system, .clipboard, .calendar, .audio, .files, .appWindow:
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
        case .files:
            return store.files.isEmpty ? "File Shelf" : "\(store.files.count) staged item\(store.files.count == 1 ? "" : "s")"
        case .appWindow:
            if let entry = appWindowEntry {
                return "\(entry.appName) · \(entry.windowTitle)"
            }
            return "Minimized app window"
        }
    }
}

// MARK: - Settings UI

@MainActor
struct NotchBubbleSettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject private var settingsStore = NotchBubbleSettingsStore.shared
    @ObservedObject private var minimizedWindowCenter = MinimizedWindowBubbleCenter.shared
    @State private var expandedGestureEditors = Set<String>()

    private var settings: NotchBubbleSettings {
        settingsStore.settings.normalized()
    }

    var body: some View {
        Section("Notch Bubbles") {
            Toggle("Enable Notch Bubbles", isOn: binding(\.enabled))
            Text("A selective activity surface for useful state and actions — not a second notification centre.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("App Bubbles") {
            if HaloDistribution.current.supportsAppWindowBubbles {
                Toggle(
                    "Show minimized windows as bubbles",
                    isOn: Binding(
                        get: { settings.resolvedAppMinimizeBubblesEnabled },
                        set: { enabled in
                            var next = settingsStore.settings
                            next.appMinimizeBubblesEnabled = enabled
                            settingsStore.settings = next.normalized()
                            if enabled {
                                MinimizedWindowBubbleCenter.shared.requestAccessibilityPermission()
                            }
                        }
                    )
                )

                Text("When you minimize an app window, Halo keeps it in a Bubble. Click a Bubble to restore that exact window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.resolvedAppMinimizeBubblesEnabled {
                    Picker(
                        "App Bubble placement",
                        selection: Binding(
                            get: { settings.resolvedAppMinimizeBubblePlacement },
                            set: { value in
                                var next = settingsStore.settings
                                next.appMinimizeBubblePlacement = value
                                settingsStore.settings = next.normalized()
                            }
                        )
                    ) {
                        ForEach(AppWindowBubblePlacement.allCases) { placement in
                            Text(placement.rawValue).tag(placement)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(
                        "Maximum minimized windows",
                        selection: Binding(
                            get: { settingsStore.settings.appMinimizeBubbleLimit ?? 1 },
                            set: { value in
                                var next = settingsStore.settings
                                next.appMinimizeBubbleLimit = value
                                settingsStore.settings = next.normalized()
                            }
                        )
                    ) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("8").tag(8)
                        Text("12").tag(12)
                        Text("Unlimited").tag(0)
                    }

                    Text(settings.resolvedAppMinimizeBubbleLimit == Int.max
                         ? "Every minimized window can remain visible as its own App Bubble."
                         : "Up to \(settings.resolvedAppMinimizeBubbleLimit) minimized window\(settings.resolvedAppMinimizeBubbleLimit == 1 ? "" : "s") can remain visible at once.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if minimizedWindowCenter.accessibilityGranted {
                        Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label("Accessibility access is required to detect and restore windows.", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Grant Access") {
                                MinimizedWindowBubbleCenter.shared.requestAccessibilityPermission()
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } else {
                Label("App Bubbles are available in Halo Direct.", systemImage: "lock.fill")
                    .font(.callout.weight(.medium))
                Text("The App Store build runs inside macOS App Sandbox, so Halo does not expose cross-app window control there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Activity policy") {
            Picker("Maximum visible activities", selection: binding(\.maximumBubbles)) {
                Text("1 · Quiet").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
                Text("5 · Advanced").tag(5)
                Text("8 · Experimental").tag(8)
                Text("12 · Experimental").tag(12)
                Text("Unlimited · Experimental").tag(99)
            }

            LabeledContent("Confirmation duration") {
                HStack {
                    Slider(
                        value: optionalBinding(\.confirmationDuration, default: 1.6),
                        in: 0.5...8,
                        step: 0.1
                    )
                    .frame(width: 200)
                    Text(String(format: "%.1f s", settings.resolvedConfirmationDuration))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }

            LabeledContent("Completion summary") {
                HStack {
                    Slider(
                        value: optionalBinding(\.completionDuration, default: 4.0),
                        in: 1...10,
                        step: 0.5
                    )
                    .frame(width: 200)
                    Text(String(format: "%.1f s", settings.resolvedCompletionDuration))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }

            Toggle(
                "Allow confirmations in fullscreen",
                isOn: optionalBinding(\.showConfirmationsInFullscreen, default: true)
            )
            Toggle(
                "Allow automatic/persistent activities in fullscreen",
                isOn: optionalBinding(\.showAutomaticInFullscreen, default: false)
            )

            Toggle(
                "Use Bubbles instead of Halo HUD for accepted system feedback",
                isOn: optionalBinding(\.replaceHaloHUDFeedback, default: false)
            )
            Text("When enabled, accepted volume/brightness/device feedback is shown by Bubbles only, avoiding duplicate Halo HUD presentation.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("System confirmations") {
            Toggle(
                "Volume / mute",
                isOn: optionalBinding(\.audioFeedbackEnabled, default: true)
            )
            Toggle(
                "Display / keyboard brightness",
                isOn: optionalBinding(\.brightnessFeedbackEnabled, default: true)
            )
            Toggle(
                "Power and charging transitions",
                isOn: optionalBinding(\.powerFeedbackEnabled, default: false)
            )
            Toggle(
                "Audio output / device changes",
                isOn: optionalBinding(\.deviceFeedbackEnabled, default: false)
            )

            Text("Repeated changes coalesce into one updating confirmation bubble instead of replaying the entrance animation.")
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

            if settings.layout == .wings {
                Picker(
                    "Bubble side",
                    selection: optionalBinding(
                        \.bubbleSideMode,
                        default: NotchBubbleSideMode.automatic
                    )
                ) {
                    ForEach(NotchBubbleSideMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if settings.resolvedBubbleSideMode == .automatic {
                    Picker(
                        "Priority side",
                        selection: optionalBinding(
                            \.automaticPrioritySide,
                            default: NotchBubbleSide.left
                        )
                    ) {
                        ForEach(NotchBubbleSide.allCases) { side in
                            Text(side.rawValue).tag(side)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Auto puts the first new bubble on the priority side, then assigns later bubbles to the side with fewer bubbles. Existing bubbles keep their side until they disappear.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("All wing bubbles stay on the selected side of the notch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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

            Toggle(
                "Custom bubble color",
                isOn: Binding(
                    get: { settings.bubbleTint != nil },
                    set: { enabled in
                        var next = settingsStore.settings
                        if enabled {
                            if next.bubbleTint == nil {
                                next.bubbleTint = WidgetColor(red: 0.20, green: 0.52, blue: 1.0)
                            }
                            if next.bubbleTintAmount == nil {
                                next.bubbleTintAmount = 0.35
                            }
                        } else {
                            next.bubbleTint = nil
                            next.bubbleTintAmount = nil
                        }
                        settingsStore.settings = next.normalized()
                    }
                )
            )

            if settings.bubbleTint != nil {
                ColorPicker(
                    "Bubble color",
                    selection: Binding(
                        get: {
                            settings.bubbleTint?.color
                                ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0).color
                        },
                        set: { color in
                            var next = settingsStore.settings
                            next.bubbleTint = WidgetColor(color)
                            if next.bubbleTintAmount == nil { next.bubbleTintAmount = 0.35 }
                            settingsStore.settings = next.normalized()
                        }
                    ),
                    supportsOpacity: false
                )

                LabeledContent("Color intensity") {
                    HStack {
                        Slider(
                            value: Binding(
                                get: { settings.resolvedBubbleTintAmount },
                                set: { amount in
                                    var next = settingsStore.settings
                                    next.bubbleTintAmount = amount
                                    settingsStore.settings = next.normalized()
                                }
                            ),
                            in: 0...1,
                            step: 0.05
                        )
                        .frame(width: 210)

                        Text("\(Int(settings.resolvedBubbleTintAmount * 100))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }

                Text("Sets the global bubble background tint. Individual bubble tint overrides still take priority.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Custom bubble accent",
                isOn: Binding(
                    get: { settings.bubbleAccent != nil },
                    set: { enabled in
                        var next = settingsStore.settings
                        if enabled {
                            next.bubbleAccent = next.bubbleAccent
                                ?? next.bubbleTint
                                ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0)
                        } else {
                            next.bubbleAccent = nil
                        }
                        settingsStore.settings = next.normalized()
                    }
                )
            )

            if settings.bubbleAccent != nil {
                ColorPicker(
                    "Accent color",
                    selection: Binding(
                        get: {
                            settings.bubbleAccent?.color
                                ?? settings.bubbleTint?.color
                                ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0).color
                        },
                        set: { color in
                            var next = settingsStore.settings
                            next.bubbleAccent = WidgetColor(color)
                            settingsStore.settings = next.normalized()
                        }
                    ),
                    supportsOpacity: false
                )

                Text("Controls rings, progress, icons, gauges and accent-driven bubble styles independently from the background tint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

        Section("Automatic & ongoing activities") {
            providerToggleRow(
                title: "Music",
                symbol: "music.note",
                enabled: binding(\.musicEnabled),
                detail: "Source-aware Now Playing. Choose while-playing, track-change-only or pinned behaviour in Content."
            )
            providerRow(
                title: "Timer",
                symbol: "timer",
                enabled: binding(\.timerEnabled),
                persistent: binding(\.timerPersistent),
                detail: "An active task: stays visible while timing, then uses the completion-summary duration."
            )
            providerRow(
                title: "Calendar / next meeting",
                symbol: "calendar.badge.clock",
                enabled: calendarEnabledBinding,
                persistent: optionalBinding(\.calendarPersistent, default: false),
                detail: "Shows the next relevant event inside the configured lead window. Persistent keeps Calendar available even when no event is upcoming."
            )
            if settings.resolvedCalendarEnabled && !store.workspace.calendar.hasAccess {
                HStack {
                    Text(store.workspace.calendar.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Calendar Access…") {
                        store.workspace.calendar.requestAccessIfNeeded()
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.leading, 28)
            }
            providerRow(
                title: "File Shelf",
                symbol: "tray.full.fill",
                enabled: optionalBinding(\.filesEnabled, default: false),
                persistent: optionalBinding(\.filesPersistent, default: false),
                detail: "Appears while files are staged for handoff. Pin only if you want the shelf resident."
            )
            providerRow(
                title: "Stopwatch",
                symbol: "stopwatch.fill",
                enabled: optionalBinding(\.stopwatchEnabled, default: false),
                persistent: optionalBinding(\.stopwatchPersistent, default: false),
                detail: "Visible while active; pin only if you deliberately want it resident."
            )
            providerRow(
                title: "Vinyl",
                symbol: "record.circle.fill",
                enabled: optionalBinding(\.vinylEnabled, default: false),
                persistent: optionalBinding(\.vinylPersistent, default: false),
                detail: "Optional music personality using the shared Vinyl Studio configuration."
            )
        }

        Section("Pinned tools") {
            providerRow(
                title: "Pixel Pal",
                symbol: "face.smiling",
                enabled: binding(\.pixelPalEnabled),
                persistent: binding(\.pixelPalPersistent),
                detail: "Off by default. Show only for Pixel Pal activity, or pin it deliberately."
            )
            providerToggleRow(
                title: "Clock",
                symbol: "clock.fill",
                enabled: optionalBinding(\.clockEnabled, default: false),
                detail: "Pinned utility. It never auto-announces itself."
            )
            providerToggleRow(
                title: "System stats",
                symbol: "gauge.with.dots.needle.67percent",
                enabled: optionalBinding(\.systemEnabled, default: false),
                detail: "Pinned utility. Brightness/power confirmations are separate and controlled above."
            )
            providerToggleRow(
                title: "Clipboard",
                symbol: "doc.on.clipboard.fill",
                enabled: optionalBinding(\.clipboardEnabled, default: false),
                detail: "Pinned utility. Enabling it makes Clipboard eligible whenever activity capacity allows."
            )
            providerToggleRow(
                title: "Audio controls",
                symbol: "speaker.wave.2.fill",
                enabled: optionalBinding(\.audioEnabled, default: false),
                detail: "Pinned utility. Transient volume/mute confirmation remains a separate policy above."
            )

            Text("Pinned tools stay eligible while enabled, but higher-priority active tasks and confirmations can temporarily take their slot when Maximum visible activities is full.")
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

            Text("Motion controls how an activity enters and returns to the notch. Confirmation dwell time is configured in Activity policy.")
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
                Picker("Visibility", selection: optionalBinding(\.musicVisibility, default: MusicBubbleVisibility.whilePlaying)) {
                    ForEach(MusicBubbleVisibility.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

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
                LabeledContent("Meeting lead time") {
                    HStack {
                        Slider(
                            value: optionalBinding(\.calendarLeadMinutes, default: 15.0),
                            in: 1...120,
                            step: 1
                        )
                        .frame(width: 175)
                        Text("\(Int(settings.resolvedCalendarLeadMinutes)) min")
                            .monospacedDigit()
                            .frame(width: 54, alignment: .trailing)
                    }
                }

                Picker("Display", selection: optionalBinding(\.calendarDisplayMode, default: CalendarBubbleDisplayMode.nextEvent)) {
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

            case .files:
                Picker("Display", selection: optionalBinding(\.filesDisplayMode, default: FileBubbleDisplayMode.latest)) {
                    ForEach(FileBubbleDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

            case .appWindow:
                Text("Uses the minimized app's icon. Click the Bubble to restore the window. If several windows are minimized, Halo keeps them in a newest-first stack.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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

            DisclosureGroup(
                isExpanded: gestureEditorBinding(kind.rawValue + ".appearance-fine-tune")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Size & Geometry")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)

                    Toggle(
                        "Override size",
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
                                .frame(width: 170)

                                Text("\(Int(resolved.size)) pt")
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Toggle(
                        "Override corner radius",
                        isOn: styleOverrideEnabledBinding(kind, \.cornerRadius, default: settings.cornerRadius)
                    )
                    if override.cornerRadius != nil {
                        LabeledContent("Corner radius") {
                            HStack {
                                Slider(
                                    value: styleValueBinding(kind, \.cornerRadius, default: settings.cornerRadius),
                                    in: 0...48,
                                    step: 1
                                )
                                .frame(width: 170)

                                Text("\(Int(resolved.cornerRadius)) pt")
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Toggle(
                        "Override content scale",
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
                                .frame(width: 170)

                                Text(String(format: "%.2fx", resolved.contentScale))
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Toggle(
                        "Override vertical offset",
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
                                .frame(width: 170)

                                Text(String(format: "%+.0f pt", resolved.verticalOffset))
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Divider()

                    Text("Surface")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)

                    if resolved.background == .glass {
                        Toggle(
                            "Override glass intensity",
                            isOn: styleOverrideEnabledBinding(kind, \.glassIntensity, default: settings.glassIntensity)
                        )
                        if override.glassIntensity != nil {
                            LabeledContent("Glass intensity") {
                                HStack {
                                    Slider(
                                        value: styleValueBinding(kind, \.glassIntensity, default: settings.glassIntensity),
                                        in: 0.05...1,
                                        step: 0.05
                                    )
                                    .frame(width: 170)

                                    Text("\(Int(resolved.glassIntensity * 100))%")
                                        .monospacedDigit()
                                        .frame(width: 58, alignment: .trailing)
                                }
                            }
                        }
                    }

                    Toggle(
                        "Override background opacity",
                        isOn: styleOverrideEnabledBinding(kind, \.backgroundOpacity, default: 0.88)
                    )
                    if override.backgroundOpacity != nil {
                        LabeledContent("Background opacity") {
                            HStack {
                                Slider(
                                    value: styleValueBinding(kind, \.backgroundOpacity, default: 0.88),
                                    in: 0...1,
                                    step: 0.05
                                )
                                .frame(width: 170)

                                Text("\(Int(resolved.backgroundOpacity * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Toggle(
                        "Override border",
                        isOn: styleOverrideEnabledBinding(kind, \.borderOpacity, default: 0.12)
                    )
                    if override.borderOpacity != nil {
                        LabeledContent("Border opacity") {
                            HStack {
                                Slider(
                                    value: styleValueBinding(kind, \.borderOpacity, default: 0.12),
                                    in: 0...1,
                                    step: 0.05
                                )
                                .frame(width: 170)

                                Text("\(Int(resolved.borderOpacity * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Divider()

                    Text("Color")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)

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
                            HStack {
                                Slider(
                                    value: styleValueBinding(kind, \.tintAmount, default: 0.22),
                                    in: 0...1,
                                    step: 0.05
                                )
                                .frame(width: 170)

                                Text("\(Int(resolved.tintAmount * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }

                    Toggle(
                        "Custom accent",
                        isOn: styleOverrideEnabledBinding(
                            kind,
                            \.accent,
                            default: WidgetColor(red: 0.20, green: 0.52, blue: 1.0)
                        )
                    )
                    if override.accent != nil {
                        ColorPicker(
                            "Accent color",
                            selection: Binding(
                                get: {
                                    currentStyleOverride(for: kind).accent?.color
                                        ?? resolved.accent
                                        ?? resolved.tint
                                        ?? WidgetColor(red: 0.20, green: 0.52, blue: 1.0).color
                                },
                                set: { color in
                                    mutateStyleOverride(for: kind) {
                                        $0.accent = WidgetColor(color)
                                    }
                                }
                            ),
                            supportsOpacity: false
                        )

                        Text("Accent affects rings, icons, gauges, progress and accent-driven edges.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Text("Motion")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)

                    Picker("Animation", selection: styleOptionalBinding(kind, \.animation)) {
                        Text("Global · \(settings.animation.rawValue)")
                            .tag(nil as NotchBubbleAnimationPreset?)
                        ForEach(NotchBubbleAnimationPreset.allCases) { preset in
                            Text(preset.rawValue).tag(Optional(preset))
                        }
                    }

                    Toggle(
                        "Override transition duration",
                        isOn: styleOverrideEnabledBinding(
                            kind,
                            \.lifecycleDuration,
                            default: settings.resolvedLifecycleDuration
                        )
                    )
                    if override.lifecycleDuration != nil {
                        LabeledContent("Transition duration") {
                            HStack {
                                Slider(
                                    value: styleValueBinding(
                                        kind,
                                        \.lifecycleDuration,
                                        default: settings.resolvedLifecycleDuration
                                    ),
                                    in: 0.10...1.50,
                                    step: 0.05
                                )
                                .frame(width: 170)

                                Text(String(format: "%.2f s", resolved.lifecycleDuration))
                                    .monospacedDigit()
                                    .frame(width: 58, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 12)
            } label: {
                HStack(spacing: 8) {
                    Text("Fine tune appearance")

                    Spacer()

                    Text(appearanceOverrideSummary(override))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Divider()
                .padding(.vertical, 2)

            Text("Gestures")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Choose what each gesture does. The common controls stay simple; open Fine tune only for repeat behavior, step size, or custom haptics.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Swipe")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            swipeGestureEditor(
                "Left",
                icon: "arrow.left",
                editorID: "swipe-left",
                kind: kind,
                action: \.gestureLeftAction,
                mode: \.gestureLeftMode,
                amount: \.gestureLeftAmount,
                hapticStrength: \.gestureLeftHapticStrength,
                hapticPattern: \.gestureLeftHapticPattern
            )

            swipeGestureEditor(
                "Right",
                icon: "arrow.right",
                editorID: "swipe-right",
                kind: kind,
                action: \.gestureRightAction,
                mode: \.gestureRightMode,
                amount: \.gestureRightAmount,
                hapticStrength: \.gestureRightHapticStrength,
                hapticPattern: \.gestureRightHapticPattern
            )

            swipeGestureEditor(
                "Up",
                icon: "arrow.up",
                editorID: "swipe-up",
                kind: kind,
                action: \.gestureUpAction,
                mode: \.gestureUpMode,
                amount: \.gestureUpAmount,
                hapticStrength: \.gestureUpHapticStrength,
                hapticPattern: \.gestureUpHapticPattern
            )

            swipeGestureEditor(
                "Down",
                icon: "arrow.down",
                editorID: "swipe-down",
                kind: kind,
                action: \.gestureDownAction,
                mode: \.gestureDownMode,
                amount: \.gestureDownAmount,
                hapticStrength: \.gestureDownHapticStrength,
                hapticPattern: \.gestureDownHapticPattern
            )

            Divider()
                .padding(.vertical, 2)

            Text("Click")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            singleClickGestureEditor(kind: kind)
            doubleClickGestureEditor(kind: kind)

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

    @ViewBuilder
    private func swipeGestureEditor(
        _ title: String,
        icon: String,
        editorID: String,
        kind: NotchBubbleKind,
        action actionKeyPath: WritableKeyPath<NotchBubbleStyleOverride, NotchBubbleGestureAction?>,
        mode modeKeyPath: WritableKeyPath<NotchBubbleStyleOverride, NotchBubbleGestureMode?>,
        amount amountKeyPath: WritableKeyPath<NotchBubbleStyleOverride, Double?>,
        hapticStrength hapticStrengthKeyPath: WritableKeyPath<NotchBubbleStyleOverride, Int?>,
        hapticPattern hapticPatternKeyPath: WritableKeyPath<NotchBubbleStyleOverride, HaloHoverHapticPattern?>
    ) -> some View {
        let override = currentStyleOverride(for: kind)
        let action = NotchBubbleGestureAction.sanitized(
            override[keyPath: actionKeyPath],
            for: kind,
            default: .none
        )
        let mode = override[keyPath: modeKeyPath] ?? .once
        let amount = action.normalizedGestureAmount(override[keyPath: amountKeyPath])
        let editorKey = kind.rawValue + "." + editorID

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(title)
                    .frame(width: 48, alignment: .leading)

                Spacer(minLength: 12)

                Picker(
                    "",
                    selection: styleValueBinding(
                        kind,
                        actionKeyPath,
                        default: NotchBubbleGestureAction.none
                    )
                ) {
                    ForEach(NotchBubbleGestureAction.availableActions(for: kind)) { option in
                        Text(option.gestureTitle).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
            }

            if action != .none {
                DisclosureGroup(isExpanded: gestureEditorBinding(editorKey)) {
                    VStack(alignment: .leading, spacing: 10) {
                        if action.supportsContinuousGesture {
                            LabeledContent("Response") {
                                Picker(
                                    "",
                                    selection: styleValueBinding(
                                        kind,
                                        modeKeyPath,
                                        default: NotchBubbleGestureMode.once
                                    )
                                ) {
                                    Text("Once").tag(NotchBubbleGestureMode.once)
                                    Text("Continuous").tag(NotchBubbleGestureMode.continuous)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(width: 210)
                            }

                            Text(
                                mode == .continuous
                                    ? "Repeats while the same swipe keeps travelling."
                                    : "Triggers once, then waits for the next swipe."
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }

                        if action.supportsGestureAmount {
                            compactGestureAmountControl(
                                action: action,
                                kind: kind,
                                keyPath: amountKeyPath
                            )
                        }

                        gestureHapticControls(
                            kind: kind,
                            strength: hapticStrengthKeyPath,
                            pattern: hapticPatternKeyPath
                        )
                    }
                    .padding(.top, 6)
                    .padding(.leading, 26)
                } label: {
                    HStack(spacing: 8) {
                        Text(
                            gestureSummary(
                                action: action,
                                mode: mode,
                                amount: amount,
                                hapticStrength: override[keyPath: hapticStrengthKeyPath],
                                hapticPattern: override[keyPath: hapticPatternKeyPath]
                            )
                        )
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("Fine tune")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func singleClickGestureEditor(kind: NotchBubbleKind) -> some View {
        let override = currentStyleOverride(for: kind)
        let editorKey = kind.rawValue + ".single-click"

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text("Single")
                    .frame(width: 48, alignment: .leading)

                Spacer(minLength: 12)

                Text("Default action")
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup(isExpanded: gestureEditorBinding(editorKey)) {
                gestureHapticControls(
                    kind: kind,
                    strength: \.tapHapticStrength,
                    pattern: \.tapHapticPattern
                )
                .padding(.top, 6)
                .padding(.leading, 26)
            } label: {
                HStack(spacing: 8) {
                    Text(
                        hapticSummary(
                            strength: override.tapHapticStrength,
                            pattern: override.tapHapticPattern
                        )
                    )
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("Fine tune")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
            .padding(.leading, 26)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func doubleClickGestureEditor(kind: NotchBubbleKind) -> some View {
        let override = currentStyleOverride(for: kind)
        let action = NotchBubbleGestureAction.sanitized(
            override.doubleClickAction,
            for: kind,
            default: .primaryAction
        )
        let amount = action.normalizedGestureAmount(override.doubleClickAmount)
        let editorKey = kind.rawValue + ".double-click"

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text("Double")
                    .frame(width: 48, alignment: .leading)

                Spacer(minLength: 12)

                Picker(
                    "",
                    selection: styleValueBinding(
                        kind,
                        \.doubleClickAction,
                        default: NotchBubbleGestureAction.primaryAction
                    )
                ) {
                    ForEach(NotchBubbleGestureAction.availableActions(for: kind)) { option in
                        Text(option.gestureTitle).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
            }

            if action != .none {
                DisclosureGroup(isExpanded: gestureEditorBinding(editorKey)) {
                    VStack(alignment: .leading, spacing: 10) {
                        if action.supportsGestureAmount {
                            compactGestureAmountControl(
                                action: action,
                                kind: kind,
                                keyPath: \.doubleClickAmount
                            )
                        }

                        gestureHapticControls(
                            kind: kind,
                            strength: \.doubleClickHapticStrength,
                            pattern: \.doubleClickHapticPattern
                        )
                    }
                    .padding(.top, 6)
                    .padding(.leading, 26)
                } label: {
                    HStack(spacing: 8) {
                        Text(
                            gestureSummary(
                                action: action,
                                mode: .once,
                                amount: amount,
                                hapticStrength: override.doubleClickHapticStrength,
                                hapticPattern: override.doubleClickHapticPattern
                            )
                        )
                        .foregroundStyle(.secondary)

                        Spacer()

                        Text("Fine tune")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func compactGestureAmountControl(
        action: NotchBubbleGestureAction,
        kind: NotchBubbleKind,
        keyPath: WritableKeyPath<NotchBubbleStyleOverride, Double?>
    ) -> some View {
        let amount = action.normalizedGestureAmount(
            currentStyleOverride(for: kind)[keyPath: keyPath]
        )

        LabeledContent(action.gestureAmountLabel) {
            Stepper(
                value: styleValueBinding(
                    kind,
                    keyPath,
                    default: action.defaultGestureAmount
                ),
                in: action.gestureAmountRange,
                step: action.gestureAmountStep
            ) {
                Text(action.formattedGestureAmount(amount))
                    .monospacedDigit()
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func gestureHapticControls(
        kind: NotchBubbleKind,
        strength strengthKeyPath: WritableKeyPath<NotchBubbleStyleOverride, Int?>,
        pattern patternKeyPath: WritableKeyPath<NotchBubbleStyleOverride, HaloHoverHapticPattern?>
    ) -> some View {
        Picker(
            "Haptic strength",
            selection: styleOptionalBinding(kind, strengthKeyPath)
        ) {
            Text("Use global").tag(nil as Int?)
            Text("Off").tag(Optional(0))
            ForEach(1...6, id: \.self) { strength in
                Text("Level \(strength)").tag(Optional(strength))
            }
        }

        Picker(
            "Haptic pattern",
            selection: styleOptionalBinding(kind, patternKeyPath)
        ) {
            Text("Use global").tag(nil as HaloHoverHapticPattern?)
            ForEach(HaloHoverHapticPattern.allCases) { pattern in
                Text(pattern.rawValue).tag(Optional(pattern))
            }
        }
    }

    private func appearanceOverrideSummary(_ override: NotchBubbleStyleOverride) -> String {
        var count = 0

        if override.size != nil { count += 1 }
        if override.cornerRadius != nil { count += 1 }
        if override.glassIntensity != nil { count += 1 }
        if override.backgroundOpacity != nil { count += 1 }
        if override.borderOpacity != nil { count += 1 }
        if override.tint != nil || override.tintAmount != nil { count += 1 }
        if override.accent != nil { count += 1 }
        if override.contentScale != nil { count += 1 }
        if override.verticalOffset != nil { count += 1 }
        if override.animation != nil { count += 1 }
        if override.lifecycleDuration != nil { count += 1 }

        if count == 0 {
            return "Using defaults"
        }

        return count == 1 ? "1 override" : "\(count) overrides"
    }

    private func gestureSummary(
        action: NotchBubbleGestureAction,
        mode: NotchBubbleGestureMode,
        amount: Double,
        hapticStrength: Int?,
        hapticPattern: HaloHoverHapticPattern?
    ) -> String {
        var parts: [String] = []

        if action.supportsContinuousGesture {
            parts.append(mode == .continuous ? "Continuous" : "Once")
        }

        if action.supportsGestureAmount {
            parts.append(action.formattedGestureAmount(amount))
        }

        parts.append(
            hapticSummary(
                strength: hapticStrength,
                pattern: hapticPattern
            )
        )

        return parts.joined(separator: " · ")
    }

    private func hapticSummary(
        strength: Int?,
        pattern: HaloHoverHapticPattern?
    ) -> String {
        if strength == 0 {
            return "Haptics off"
        }

        if strength == nil && pattern == nil {
            return "Global haptics"
        }

        return "Custom haptics"
    }

    private func gestureEditorBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { expandedGestureEditors.contains(key) },
            set: { expanded in
                if expanded {
                    expandedGestureEditors.insert(key)
                } else {
                    expandedGestureEditors.remove(key)
                }
            }
        )
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

    private var calendarEnabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.settings.calendarEnabled ?? false },
            set: { enabled in
                var next = settingsStore.settings
                next.calendarEnabled = enabled
                settingsStore.settings = next.normalized()
                if enabled {
                    store.workspace.calendar.requestAccessIfNeeded()
                }
            }
        )
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
            let sides: [NotchBubbleSide] = {
                switch settings.resolvedBubbleSideMode {
                case .left:
                    return Array(repeating: .left, count: count)
                case .right:
                    return Array(repeating: .right, count: count)
                case .automatic:
                    var result: [NotchBubbleSide] = []
                    var leftCount = 0
                    var rightCount = 0

                    for _ in 0..<count {
                        let side: NotchBubbleSide
                        if leftCount == rightCount {
                            side = settings.resolvedAutomaticPrioritySide
                        } else if leftCount < rightCount {
                            side = .left
                        } else {
                            side = .right
                        }

                        result.append(side)
                        if side == .left {
                            leftCount += 1
                        } else {
                            rightCount += 1
                        }
                    }

                    return result
                }
            }()

            var leftOffset = spacing
            var rightOffset = spacing
            let y = notch.midY - size / 2 + verticalOffset

            return sides.map { side in
                switch side {
                case .left:
                    let frame = CGRect(
                        x: notch.minX - leftOffset - size,
                        y: y,
                        width: size,
                        height: size
                    )
                    leftOffset += size + spacing
                    return frame

                case .right:
                    let frame = CGRect(
                        x: notch.maxX + rightOffset,
                        y: y,
                        width: size,
                        height: size
                    )
                    rightOffset += size + spacing
                    return frame
                }
            }

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
