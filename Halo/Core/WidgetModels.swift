import Foundation

enum WidgetFontFamily: String, Codable, CaseIterable { case system, rounded, serif, monospaced, custom }
enum WidgetFontWeight: String, Codable, CaseIterable { case light, regular, medium, semibold, bold }

enum WidgetLayoutMode: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case compact = "Compact"
    case hero = "Hero"
    case minimal = "Minimal"
    case dense = "Dense"
    var id: String { rawValue }
}

enum WidgetCardBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case solid = "Solid"
    case gradient = "Gradient"
    case glass = "Glass"
    case accent = "Accent Tint"
    var id: String { rawValue }
}

enum WidgetOutlineStyle: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case solid = "Solid"
    case dashed = "Dashed"
    case double = "Double"
    case glow = "Glow"
    var id: String { rawValue }
}

enum WidgetVisualPreset: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case glass = "Glass"
    case filled = "Filled"
    case outline = "Outline"
    case floating = "Floating"
    case minimal = "Minimal"
    var id: String { rawValue }
}

enum WidgetElementForegroundStyle: String, Codable, CaseIterable, Identifiable {
    case inherit = "Widget Text"
    case secondary = "Secondary"
    case accent = "Accent"
    case custom = "Custom"
    var id: String { rawValue }
}

enum WidgetElementBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case subtle = "Subtle"
    case accent = "Accent"
    case glass = "Glass"
    case custom = "Custom"
    var id: String { rawValue }
}

enum WidgetElementEmphasis: String, Codable, CaseIterable, Identifiable {
    case regular = "Regular"
    case medium = "Medium"
    case semibold = "Semibold"
    case bold = "Bold"
    var id: String { rawValue }
}

struct WidgetElementStyle: Codable, Equatable {
    var visible = true
    var fontScale = 1.0
    var opacity = 1.0
    var foreground: WidgetElementForegroundStyle = .inherit
    var customForeground = WidgetColor.white
    var background: WidgetElementBackgroundStyle = .none
    var backgroundColor = WidgetColor.white
    var backgroundOpacity = 0.10
    var padding = 0.0
    var cornerRadius = 8.0
    var emphasis: WidgetElementEmphasis = .regular
    var dividerAfter = false

    // Opened-notch element layout/chrome overrides. Optional fields keep older saved element styles decodable.
    var alignment: WidgetContentAlignment?
    var externalSpacing: Double?
    var xOffset: Double?
    var yOffset: Double?
    var textAlignment: WidgetContentAlignment?
    var fontFamily: WidgetFontFamily?
    var customFont: String?
    var fontSize: Double?
    var fontWeight: WidgetFontWeight?
    var borderColor: WidgetColor?
    var borderWidth: Double?
    var borderOpacity: Double?
    var shadowBlur: Double?
    var shadowOpacity: Double?
    var tintColor: WidgetColor?
    var tintOpacity: Double?
    var iconSize: Double?
    var contentDensity: Double?
    var priority: OpenNotchPriority?

    func validated() throws -> WidgetElementStyle {
        let extended = [externalSpacing, xOffset, yOffset, fontSize, borderWidth, borderOpacity, shadowBlur, shadowOpacity, tintOpacity, iconSize, contentDensity].compactMap { $0 }
        guard [fontScale, opacity, backgroundOpacity, padding, cornerRadius].allSatisfy(\.isFinite), extended.allSatisfy(\.isFinite) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var value = self
        value.fontScale = min(2.5, max(0.55, fontScale))
        value.opacity = min(1, max(0.15, opacity))
        value.backgroundOpacity = min(1, max(0, backgroundOpacity))
        value.padding = min(24, max(0, padding))
        value.cornerRadius = min(32, max(0, cornerRadius))
        value.customForeground = try customForeground.validated()
        value.backgroundColor = try backgroundColor.validated()
        if let externalSpacing { value.externalSpacing = min(48, max(0, externalSpacing)) }
        if let xOffset { value.xOffset = min(200, max(-200, xOffset)) }
        if let yOffset { value.yOffset = min(200, max(-200, yOffset)) }
        if let fontSize { value.fontSize = min(72, max(8, fontSize)) }
        if let borderWidth { value.borderWidth = min(8, max(0, borderWidth)) }
        if let borderOpacity { value.borderOpacity = min(1, max(0, borderOpacity)) }
        if let shadowBlur { value.shadowBlur = min(48, max(0, shadowBlur)) }
        if let shadowOpacity { value.shadowOpacity = min(0.8, max(0, shadowOpacity)) }
        if let tintOpacity { value.tintOpacity = min(1, max(0, tintOpacity)) }
        if let iconSize { value.iconSize = min(96, max(6, iconSize)) }
        if let contentDensity { value.contentDensity = min(1.5, max(0.5, contentDensity)) }
        value.borderColor = try borderColor?.validated()
        value.tintColor = try tintColor?.validated()
        if let customFont { value.customFont = String(customFont.prefix(120)) }
        return value
    }
}

struct WidgetElementDescriptor: Identifiable {
    let key: String
    let title: String
    let detail: String
    let defaultVisible: Bool
    var id: String { key }

    init(_ key: String, _ title: String, _ detail: String, defaultVisible: Bool = true) {
        self.key = key
        self.title = title
        self.detail = detail
        self.defaultVisible = defaultVisible
    }
}

extension ModuleID {
    var widgetElements: [WidgetElementDescriptor] {
        switch self {
        case .clock:
            return [
                .init("time", "Time", "The primary live clock value."),
                .init("date", "Date", "Formatted calendar date."),
                .init("timezone", "Time zone", "Current time-zone identifier.", defaultVisible: false),
                .init("dayProgress", "Day progress", "A live progress bar for the current day.", defaultVisible: false)
            ]
        case .timer:
            return [
                .init("countdown", "Countdown", "Remaining focus time."),
                .init("progress", "Session progress", "Progress through the current focus session."),
                .init("endTime", "Finish time", "Expected completion time.", defaultVisible: false),
                .init("status", "Status text", "Idle, paused, or completed state."),
                .init("presets", "Preset buttons", "Quick focus-duration buttons."),
                .init("controls", "Session controls", "Pause, resume, and reset actions.")
            ]
        case .shelf:
            return [
                .init("summary", "Shelf summary", "File and pinned-item counts."),
                .init("files", "File list", "Files currently held by the shelf."),
                .init("actions", "Shelf actions", "Add and clear actions."),
                .init("footer", "Overflow footer", "Count of additional hidden shelf items.")
            ]
        case .media:
            return [
                .init("track", "Track title", "Current track or media title."),
                .init("artist", "Artist", "Current artist / creator."),
                .init("source", "Player source", "Apple Music, Spotify, or system source."),
                .init("playback", "Playback state", "Playing, paused, or waiting state."),
                .init("artwork", "Album artwork", "Current track artwork."),
                .init("album", "Album", "Current album metadata.", defaultVisible: false),
                .init("progress", "Playback progress", "Seekable track progress where supported."),
                .init("timing", "Elapsed / remaining", "Track timing where supported."),
                .init("palette", "Artwork palette", "Colors extracted from current artwork.", defaultVisible: false),
                .init("controls", "Playback controls", "Previous, play/pause, and next."),
                .init("shuffle", "Shuffle", "Shuffle control where supported.", defaultVisible: false),
                .init("repeat", "Repeat", "Repeat control where supported.", defaultVisible: false),
                .init("visualizer", "Audio visualizer", "Measured system-audio spectrum while the opened notch is visible.", defaultVisible: false),
                .init("lyrics", "Lyrics area", "Reserved for players that expose real lyric data.", defaultVisible: false),
                .init("detection", "Detection action", "Retry player detection.", defaultVisible: false),
                .init("status", "Media status", "Connection and error information.")
            ]
        case .audio:
            return [
                .init("summary", "Audio summary", "Selected output and available-device count."),
                .init("output", "Output selector", "Choose the active output device."),
                .init("volume", "Volume slider", "Software volume control when supported."),
                .init("volumeValue", "Volume value", "Numeric volume percentage."),
                .init("levels", "Quick levels", "One-click 0/25/50/75/100% volume.", defaultVisible: false),
                .init("actions", "Audio actions", "Refresh available devices."),
                .init("status", "Audio status", "Hardware-volume notes and errors.")
            ]
        case .calendar:
            return [
                .init("summary", "Day summary", "Today's date and remaining-event count."),
                .init("nextEvent", "Next event", "Next event with relative countdown."),
                .init("events", "Event list", "Upcoming events and join links."),
                .init("actions", "Calendar actions", "Enable or refresh calendar access."),
                .init("status", "Calendar status", "Connection / empty-day state.")
            ]
        case .clipboard:
            return [
                .init("summary", "Clipboard summary", "Entry count and age of the newest entry."),
                .init("search", "Search field", "Filter clipboard history."),
                .init("entries", "Clipboard entries", "Recent copied text with actions."),
                .init("actions", "Clipboard actions", "Clear history."),
                .init("footer", "Privacy footer", "Storage and privacy explanation.")
            ]
        case .system:
            return [
                .init("battery", "Battery", "Battery percentage and charging state."),
                .init("batteryProgress", "Battery bar", "Visual battery-level progress."),
                .init("power", "Power mode", "AC/battery and Low Power Mode status."),
                .init("memory", "Memory", "Installed physical memory."),
                .init("storage", "Storage", "Available disk capacity."),
                .init("uptime", "Uptime", "Current system uptime."),
                .init("cpu", "CPU usage", "Current CPU utilization."),
                .init("memoryUsage", "Memory usage", "Current physical-memory utilization."),
                .init("swap", "Swap", "Current swap utilization.", defaultVisible: false),
                .init("diskUsage", "Disk usage", "Current disk utilization."),
                .init("network", "Network throughput", "Current network receive/transmit rate."),
                .init("thermal", "Thermal state", "macOS thermal-pressure state.", defaultVisible: false),
                .init("graphs", "Compact graphs", "Recent CPU, memory and network history.", defaultVisible: false),
                .init("device", "Mac details", "macOS version and logical processor count.", defaultVisible: false)
            ]
        case .launcher:
            return [
                .init("summary", "Launcher summary", "Running-app and plugin-command counts.", defaultVisible: false),
                .init("search", "Search field", "Search apps and commands."),
                .init("timers", "Timer shortcuts", "Quick focus-timer launches."),
                .init("apps", "Running apps", "Activate running applications."),
                .init("plugins", "Plugin commands", "Commands exposed by Halo plugins."),
                .init("shortcuts", "Quick locations", "Open an app or Downloads.")
            ]
        case .activities:
            return [
                .init("summary", "Activity summary", "Number of current live activities."),
                .init("items", "Activity list", "Activity titles, details, progress and dismiss actions."),
                .init("status", "Empty state", "Message shown when no activity is live.")
            ]
        case .notes:
            return [
                .init("editor", "Notes editor", "Editable quick-note area."),
                .init("stats", "Note statistics", "Word and character counts."),
                .init("actions", "Note actions", "Copy and clear the note.", defaultVisible: false)
            ]
        case .capture:
            return [
                .init("hint", "Permission hint", "Screen Recording permission guidance."),
                .init("actions", "Capture actions", "Capture region and OCR image actions."),
                .init("progress", "Busy indicator", "Progress while capture/OCR is running."),
                .init("result", "OCR result", "Recognized text."),
                .init("resultActions", "Result actions", "Copy or clear recognized text."),
                .init("status", "Capture status", "Errors and capture status.")
            ]
        case .stopwatch:
            return [
                .init("time", "Elapsed time", "Live stopwatch value."),
                .init("state", "Stopwatch state", "Running or paused state."),
                .init("controls", "Stopwatch controls", "Start, pause, and reset.")
            ]
        case .developer:
            return []
        }
    }
}

struct WidgetColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    static let white = WidgetColor(red: 1, green: 1, blue: 1)
    static let accent = WidgetColor(red: 0.4, green: 0.7, blue: 1)
    func validated() throws -> WidgetColor {
        guard [red, green, blue].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        return WidgetColor(red: min(1, max(0, red)), green: min(1, max(0, green)), blue: min(1, max(0, blue)))
    }
}
struct ClockOptions: Codable, Equatable {
    var twentyFourHour = false
    var showSeconds = false
    var showDate = true
    var timeZone = ""
}

enum WidgetContentAlignment: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum WidgetControlSize: String, Codable, CaseIterable, Identifiable {
    case mini, small, regular, large
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum WidgetClockDateStyle: String, Codable, CaseIterable, Identifiable {
    case weekdayMonthDay, monthDay, full, numeric
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weekdayMonthDay: return "Mon, Sep 28"
        case .monthDay: return "Sep 28"
        case .full: return "Monday, September 28"
        case .numeric: return "09/28/2026"
        }
    }
}

/// Content controls for the opened-notch widget dashboard. One instance belongs to one ModuleID,
/// so the editor can expose only the controls relevant to that widget while profiles keep them all.
struct WidgetContentOptions: Codable, Equatable {
    var alignment: WidgetContentAlignment = .leading
    var spacing = 10.0
    var controlSize: WidgetControlSize = .regular
    var iconSize = 16.0
    var maxItems = 6
    var showSecondaryText = true
    var showControls = true
    var showProgress = true
    var showStatus = true
    var showSearch = true
    var showFooter = true
    var showQuickActions = true

    var clockDateStyle: WidgetClockDateStyle = .weekdayMonthDay

    var timerPresetA = 5
    var timerPresetB = 15
    var timerPresetC = 25

    var shelfShowDetails = true
    var shelfShowActions = true
    var shelfIconSize = 24.0

    var mediaShowSource = true
    var mediaShowArtist = true
    var mediaTitleLines = 2

    var calendarShowTimes = true
    var calendarShowJoin = true

    var systemBattery = true
    var systemMemory = true
    var systemStorage = true
    var systemUptime = true

    var launcherTimers = true
    var launcherRunningApps = true
    var launcherPlugins = true

    var activitiesShowDetail = true
    var notesHeight = 90.0
    var captureShowHelp = true
    var captureTextLines = 12
    var stopwatchScale = 2.0

    func validated() throws -> WidgetContentOptions {
        guard [spacing, iconSize, shelfIconSize, notesHeight, stopwatchScale].allSatisfy(\.isFinite) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var value = self
        value.spacing = min(32, max(0, spacing))
        value.iconSize = min(48, max(8, iconSize))
        value.maxItems = min(30, max(1, maxItems))
        value.timerPresetA = min(180, max(1, timerPresetA))
        value.timerPresetB = min(180, max(1, timerPresetB))
        value.timerPresetC = min(180, max(1, timerPresetC))
        value.shelfIconSize = min(64, max(14, shelfIconSize))
        value.mediaTitleLines = min(4, max(1, mediaTitleLines))
        value.notesHeight = min(420, max(60, notesHeight))
        value.captureTextLines = min(40, max(2, captureTextLines))
        value.stopwatchScale = min(4, max(0.8, stopwatchScale))
        return value
    }
}

struct WidgetChromeOptions: Codable, Equatable {
    var borderColor = WidgetColor.white
    var borderOpacity = 0.0
    var borderWidth = 0.0
    var shadowOpacity = 0.0
    var shadowRadius = 8.0
    var shadowY = 2.0
    var contentOpacity = 1.0

    func validated() throws -> WidgetChromeOptions {
        guard [borderOpacity, borderWidth, shadowOpacity, shadowRadius, shadowY, contentOpacity].allSatisfy(\.isFinite) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var value = self
        value.borderColor = try borderColor.validated()
        value.borderOpacity = min(1, max(0, borderOpacity))
        value.borderWidth = min(6, max(0, borderWidth))
        value.shadowOpacity = min(0.8, max(0, shadowOpacity))
        value.shadowRadius = min(40, max(0, shadowRadius))
        value.shadowY = min(30, max(-30, shadowY))
        value.contentOpacity = min(1, max(0.15, contentOpacity))
        return value
    }
}

struct WidgetStyle: Codable, Equatable {
    var fontFamily: WidgetFontFamily = .system
    var customFont = "Helvetica Neue"
    var weight: WidgetFontWeight = .regular
    var fontSize = 14.0
    var textColor = WidgetColor.white
    var accentColor = WidgetColor.accent
    var backgroundColor = WidgetColor.white
    var backgroundOpacity = 0.06
    var padding = 12.0
    var cornerRadius = 14.0
    var width = 0.0
    var minimumHeight = 0.0
    var showTitle = true
    var clock = ClockOptions()
    var content: WidgetContentOptions?
    var chrome: WidgetChromeOptions?

    // Optional so profiles created before the opened-widget design system decode unchanged.
    var layoutMode: WidgetLayoutMode?
    var cardBackgroundStyle: WidgetCardBackgroundStyle?
    var backgroundSecondaryColor: WidgetColor?
    var outlineStyle: WidgetOutlineStyle?
    var showHeaderIcon: Bool?
    var gradientAngle: Double?
    var glassTintOpacity: Double?
    var elementStyles: [String: WidgetElementStyle]?

    var resolvedContent: WidgetContentOptions { content ?? WidgetContentOptions() }
    var resolvedChrome: WidgetChromeOptions { chrome ?? WidgetChromeOptions() }
    var resolvedLayoutMode: WidgetLayoutMode { layoutMode ?? .standard }
    var resolvedCardBackgroundStyle: WidgetCardBackgroundStyle { cardBackgroundStyle ?? .solid }
    var resolvedBackgroundSecondaryColor: WidgetColor { backgroundSecondaryColor ?? accentColor }
    var resolvedOutlineStyle: WidgetOutlineStyle {
        if let outlineStyle { return outlineStyle }
        return resolvedChrome.borderOpacity > 0 && resolvedChrome.borderWidth > 0 ? .solid : .none
    }
    var showsHeaderIcon: Bool { showHeaderIcon ?? true }
    var resolvedGradientAngle: Double { min(360, max(-360, gradientAngle ?? 135)) }
    var resolvedGlassTintOpacity: Double { min(0.6, max(0, glassTintOpacity ?? 0.10)) }
    func elementStyle(for key: String, defaultVisible: Bool = true) -> WidgetElementStyle {
        if let saved = elementStyles?[key] { return saved }
        var value = WidgetElementStyle()
        value.visible = defaultVisible
        return value
    }
    func elementStyle(for descriptor: WidgetElementDescriptor) -> WidgetElementStyle {
        elementStyle(for: descriptor.key, defaultVisible: descriptor.defaultVisible)
    }
    func validated() throws -> WidgetStyle {
        guard [fontSize, backgroundOpacity, padding, cornerRadius, width, minimumHeight].allSatisfy(\.isFinite),
              clock.timeZone.isEmpty || TimeZone(identifier: clock.timeZone) != nil else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.fontSize = min(48, max(10, fontSize)); v.padding = min(32, max(0, padding))
        v.cornerRadius = min(40, max(0, cornerRadius)); v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        v.width = width <= 0 ? 0 : min(640, max(120, width))
        v.minimumHeight = min(400, max(0, minimumHeight))
        v.textColor = try textColor.validated(); v.accentColor = try accentColor.validated(); v.backgroundColor = try backgroundColor.validated()
        if backgroundSecondaryColor != nil { v.backgroundSecondaryColor = try resolvedBackgroundSecondaryColor.validated() }
        if let angle = gradientAngle {
            guard angle.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            v.gradientAngle = min(360, max(-360, angle))
        }
        if let tint = glassTintOpacity {
            guard tint.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            v.glassTintOpacity = min(0.6, max(0, tint))
        }
        if elementStyles != nil { v.elementStyles = try elementStyles?.mapValues { try $0.validated() } }
        v.customFont = String(customFont.prefix(120))
        if content != nil { v.content = try resolvedContent.validated() }
        if chrome != nil { v.chrome = try resolvedChrome.validated() }
        return v
    }
}
enum ClosedNotchItem: String, Codable, CaseIterable, Identifiable {
    case none, clock, date, timer, battery, media, visualizer, mirror, files, activity
    var id: String { rawValue }
}
enum PlaybackAnimation: String, Codable, CaseIterable { case bars, wave, pulse, waveform, ribbon, dots, rings, orbit, spectrum }
struct ClosedExpansionOptions: Codable, Equatable {
    // Content-fit is the stable default. Users can opt into a fixed active width for a more
    // dramatic music/live-activity expansion without making every transient event 400 pt wide.
    var enabled = false
    var width = 400.0
}
struct VisualizerOptions: Codable, Equatable {
    var dynamicColors = false
    var speed = 1.0
    var intensity = 1.0
    var width = 64.0
    var height = 16.0
    func validated() throws -> VisualizerOptions {
        guard [speed, intensity, width, height].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.speed = min(2, max(0.25, speed)); v.intensity = min(1, max(0.1, intensity))
        v.width = min(160, max(32, width)); v.height = min(48, max(8, height))
        return v
    }
}

enum MediaTextMode: String, Codable, CaseIterable { case title, artist, titleArtist, lyrics }
enum MediaOverflowMode: String, Codable, CaseIterable { case truncate, scale, marquee }
enum LyricDisplayMode: String, Codable, CaseIterable { case line, focus, word }
enum MediaChangeAnimation: String, Codable, CaseIterable { case none, fade, slide, scale, blur }
enum MediaGestureAction: String, Codable, CaseIterable { case none, playPause, next, previous, openPlayer }
enum MediaArtworkMode: String, Codable, CaseIterable { case none, cover, background, vinyl }
struct ClosedMediaOptions: Codable, Equatable {
    var textMode: MediaTextMode = .titleArtist
    var overflow: MediaOverflowMode = .truncate
    var lines = 1
    var onlineLyrics: Bool?
    var lyricDisplay: LyricDisplayMode?
    var lyricSyncOffset: Double?
    var dynamicLyricWidth: Bool?
    var horizontalSpace: Double?
    var changeAnimation: MediaChangeAnimation?
    var changeAnimationDuration: Double?
    var tapAction: MediaGestureAction?
    var doubleTapAction: MediaGestureAction?
    var swipeLeftAction: MediaGestureAction?
    var swipeRightAction: MediaGestureAction?
    var usesOnlineLyrics: Bool { onlineLyrics ?? true }
    var resolvedLyricDisplay: LyricDisplayMode { lyricDisplay ?? .line }
    var resolvedLyricSyncOffset: Double { min(5, max(-5, lyricSyncOffset ?? 0)) }
    var usesDynamicLyricWidth: Bool { dynamicLyricWidth ?? true }
    var resolvedHorizontalSpace: Double { min(360, max(48, horizontalSpace ?? 180)) }
    var resolvedChangeAnimation: MediaChangeAnimation { changeAnimation ?? .slide }
    var resolvedChangeAnimationDuration: Double { min(1.2, max(0.08, changeAnimationDuration ?? 0.28)) }
    var resolvedTapAction: MediaGestureAction { tapAction ?? .playPause }
    var resolvedDoubleTapAction: MediaGestureAction { doubleTapAction ?? .none }
    var resolvedSwipeLeftAction: MediaGestureAction { swipeLeftAction ?? .next }
    var resolvedSwipeRightAction: MediaGestureAction { swipeRightAction ?? .previous }
    var artwork: MediaArtworkMode = .none
    var artworkSize = 28.0
    var marqueeSpeed = 28.0
    var vinylRPM = 8.0
    var backgroundOpacity = 0.32
    var showPlaybackIcon = true
    func validated() throws -> ClosedMediaOptions {
        guard [artworkSize, marqueeSpeed, vinylRPM, backgroundOpacity, lyricSyncOffset ?? 0, horizontalSpace ?? 180, changeAnimationDuration ?? 0.28].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lines = min(2, max(1, lines))
        v.artworkSize = min(72, max(14, artworkSize))
        v.marqueeSpeed = min(120, max(8, marqueeSpeed))
        v.vinylRPM = min(45, max(1, vinylRPM))
        v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        if lyricSyncOffset != nil { v.lyricSyncOffset = resolvedLyricSyncOffset }
        if horizontalSpace != nil { v.horizontalSpace = resolvedHorizontalSpace }
        if changeAnimationDuration != nil { v.changeAnimationDuration = resolvedChangeAnimationDuration }
        return v
    }
}

struct ClosedArtworkOptions: Codable, Equatable {
    var enabled = false
    var mode: MediaArtworkMode = .cover
    var side: ClosedNotchSideChoice = .automatic
    var size = 28.0
    var padding = 0.0
    var margin = 7.0
    var vinylRPM = 8.0
    var backgroundOpacity = 0.32
    var backgroundEnabled: Bool?
    var artworkOnly: Bool?
    var isArtworkOnly: Bool { artworkOnly ?? false }
    // Older profiles used mode == .background. New profiles can enable the background independently
    // while keeping mode set to cover or vinyl for foreground artwork.
    var usesBackgroundArtwork: Bool { backgroundEnabled ?? (mode == .background) }
    func validated() throws -> ClosedArtworkOptions {
        guard [size, padding, margin, vinylRPM, backgroundOpacity].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        if v.mode == .none && !v.usesBackgroundArtwork { v.enabled = false }
        v.size = min(72, max(14, size))
        v.padding = min(24, max(0, padding))
        v.margin = min(48, max(0, margin))
        v.vinylRPM = min(45, max(1, vinylRPM))
        v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        return v
    }
}

enum ReactiveDriver: String, Codable, CaseIterable { case pulse, bass, mids, treble, spectrum }
struct ReactiveBackgroundOptions: Codable, Equatable {
    var enabled = false
    var driver: ReactiveDriver = .pulse
    var speed = 1.0
    var intensity = 0.5
    var brightness = 0.22
    var saturation = 0.15
    var scale = 0.015
    var hueShift = 0.0
    var blur = 0.0
    var grain = 0.0
    var audioSensitivity: Double?
    var resolvedAudioSensitivity: Double { min(4, max(0.25, audioSensitivity ?? 1.35)) }
    func validated() throws -> ReactiveBackgroundOptions {
        guard [speed, intensity, brightness, saturation, scale, hueShift, blur, grain, audioSensitivity ?? 1.35].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.speed = min(3, max(0.2, speed)); v.intensity = min(1, max(0, intensity))
        v.brightness = min(0.8, max(0, brightness)); v.saturation = min(1, max(0, saturation))
        v.scale = min(0.12, max(0, scale)); v.hueShift = min(1, max(0, hueShift))
        v.blur = min(12, max(0, blur)); v.grain = min(0.6, max(0, grain))
        if audioSensitivity != nil { v.audioSensitivity = resolvedAudioSensitivity }
        return v
    }
}

enum PowerReactionStyle: String, Codable, CaseIterable { case off, icon, percent, iconPercent, label }
enum ClosedNotchSideChoice: String, Codable, CaseIterable { case automatic, left, right }
struct PowerReactionOptions: Codable, Equatable {
    var enabled: Bool?
    var isEnabled: Bool { enabled ?? true }
    var lowThreshold = 20
    var side: ClosedNotchSideChoice = .automatic
    var charging: PowerReactionStyle = .iconPercent
    var low: PowerReactionStyle = .iconPercent
    var charged: PowerReactionStyle = .icon
    var expandForEvent = true
    // Legacy field retained so older saved profiles continue to decode. Power events are now
    // content-sized instead of forcing this value as a minimum wing width.
    var eventWidth = 96.0
    var notchMargin: Double?
    var extraEventSpace: Double?
    var resolvedNotchMargin: Double { min(48, max(0, notchMargin ?? 4)) }
    var resolvedExtraEventSpace: Double { min(120, max(0, extraEventSpace ?? 0)) }
    var color = WidgetColor.accent
    var dynamicColor: Bool?
    var usesDynamicColor: Bool { dynamicColor ?? false }
    var lowColor: WidgetColor?
    var midColor: WidgetColor?
    var highColor: WidgetColor?
    var resolvedLowColor: WidgetColor { lowColor ?? WidgetColor(red: 1.0, green: 0.22, blue: 0.18) }
    var resolvedMidColor: WidgetColor { midColor ?? WidgetColor(red: 1.0, green: 0.72, blue: 0.12) }
    var resolvedHighColor: WidgetColor { highColor ?? WidgetColor(red: 0.28, green: 0.92, blue: 0.42) }
    func validated() throws -> PowerReactionOptions {
        guard [eventWidth, notchMargin ?? 4, extraEventSpace ?? 0].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lowThreshold = min(50, max(5, lowThreshold))
        v.eventWidth = min(240, max(48, eventWidth))
        if notchMargin != nil { v.notchMargin = resolvedNotchMargin }
        if extraEventSpace != nil { v.extraEventSpace = resolvedExtraEventSpace }
        v.color = try color.validated()
        if lowColor != nil { v.lowColor = try resolvedLowColor.validated() }
        if midColor != nil { v.midColor = try resolvedMidColor.validated() }
        if highColor != nil { v.highColor = try resolvedHighColor.validated() }
        return v
    }
}

struct ClosedNotchOptions: Codable, Equatable {
    var applyBackgroundWhenOpened: Bool?
    var autoFitContent: Bool?
    var horizontalPadding: Double?
    var verticalPadding: Double?
    var sideMargin: Double?
    var outerMargin: Double?
    var albumTextColor: Bool?
    var albumBackgroundColor: Bool?
    var albumBackgroundFrequencyEffect: Bool?
    var mediaOptions: ClosedMediaOptions?
    var artworkOptions: ClosedArtworkOptions?
    var reactiveBackground: ReactiveBackgroundOptions?
    var powerReaction: PowerReactionOptions?
    var contentPaddingX: Double { min(24, max(0, horizontalPadding ?? 8)) }
    var contentPaddingY: Double { min(12, max(0, verticalPadding ?? 2)) }
    var contentSideMargin: Double { min(48, max(0, sideMargin ?? 4)) }
    var contentOuterMargin: Double { min(48, max(0, outerMargin ?? 4)) }
    var leftDecoration: SideDecoration?
    var rightDecoration: SideDecoration?
    var visualizer: VisualizerOptions?
    var expansion: ClosedExpansionOptions?
    var left: ClosedNotchItem = .clock
    var right: ClosedNotchItem = .visualizer
    var fontSize = 12.0
    var color = WidgetColor.white
    var animation: PlaybackAnimation = .bars
    var animate = true
    func validated() throws -> ClosedNotchOptions {
        guard fontSize.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        guard (horizontalPadding ?? 8).isFinite, (verticalPadding ?? 2).isFinite, (sideMargin ?? 4).isFinite, (outerMargin ?? 4).isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        if horizontalPadding != nil { v.horizontalPadding = contentPaddingX }
        if verticalPadding != nil { v.verticalPadding = contentPaddingY }
        if sideMargin != nil { v.sideMargin = contentSideMargin }
        if outerMargin != nil { v.outerMargin = contentOuterMargin }
        v.fontSize = min(24, max(8, fontSize)); v.color = try color.validated()
        v.leftDecoration = try leftDecoration?.validatedForImport()
        v.rightDecoration = try rightDecoration?.validatedForImport()
        v.visualizer = try visualizer?.validated()
        v.mediaOptions = try mediaOptions?.validated()
        v.artworkOptions = try artworkOptions?.validated()
        v.reactiveBackground = try reactiveBackground?.validated()
        v.powerReaction = try powerReaction?.validated()
        if var expansion {
            guard expansion.width.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            expansion.width = min(640, max(120, expansion.width)); v.expansion = expansion
        }
        return v
    }
}

enum MusicPalette {
    static func colors(from samples: [WidgetColor]) -> [WidgetColor] {
        var bins: [Int: Int] = [:]
        for sample in samples {
            guard let c = try? sample.validated() else { continue }
            let high = max(c.red, max(c.green, c.blue))
            let low = min(c.red, min(c.green, c.blue))
            guard high > 0.12, low < 0.92 else { continue }
            let key = Int(c.red * 7) * 64 + Int(c.green * 7) * 8 + Int(c.blue * 7)
            bins[key, default: 0] += high - low > 0.15 ? 3 : 1
        }
        let ranked = bins.keys.sorted { bins[$0] == bins[$1] ? $0 < $1 : bins[$0]! > bins[$1]! }
        var result: [WidgetColor] = []
        for key in ranked {
            var c = WidgetColor(red: Double(key / 64) / 7, green: Double(key / 8 % 8) / 7, blue: Double(key % 8) / 7)
            let high = max(c.red, max(c.green, c.blue))
            let lift = max(0, 0.65 - high)
            c.red += lift; c.green += lift; c.blue += lift
            if result.allSatisfy({ abs($0.red - c.red) + abs($0.green - c.green) + abs($0.blue - c.blue) > 0.35 }) { result.append(c) }
            if result.count == 2 { break }
        }
        return result
    }
}