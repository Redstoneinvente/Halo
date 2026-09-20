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
                .init("time", "Time", "The primary adaptive clock value."),
                .init("date", "Date", "Adaptive date treatment that simplifies with size."),
                .init("timezone", "Time zone", "Primary time-zone or location context.", defaultVisible: false),
                .init("nextEvent", "Next event", "Next calendar event when Calendar access is available.", defaultVisible: false),
                .init("timer", "Timer", "Current Halo focus timer state.", defaultVisible: false),
                .init("weather", "Weather", "Weather / temperature context when a provider is available.", defaultVisible: false),
                .init("battery", "Battery", "Current Mac battery percentage and charging state.", defaultVisible: false),
                .init("worldClocks", "World clocks", "Secondary configured time zones.", defaultVisible: false),
                .init("solar", "Sunrise / sunset", "Solar times when weather/location context supplies them.", defaultVisible: false),
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
        case .pet, .developer:
            return []
        }
    }
}

struct WidgetColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    static let white = WidgetColor(red: 1, green: 1, blue: 1)
    static let black = WidgetColor(red: 0, green: 0, blue: 0)
    static let accent = WidgetColor(red: 0.4, green: 0.7, blue: 1)
    func validated() throws -> WidgetColor {
        guard [red, green, blue].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        return WidgetColor(red: min(1, max(0, red)), green: min(1, max(0, green)), blue: min(1, max(0, blue)))
    }
}

/// Derives one cohesive foreground theme from album artwork. The generated color keeps the
/// album's hue, softens overly aggressive saturation, and then moves toward a light or dark
/// tonal endpoint until it remains readable across every supplied background sample.
enum AlbumForegroundColorResolver {
    static let minimumContrast = 5.0

    static func readable(_ source: WidgetColor, against background: WidgetColor) -> WidgetColor {
        readable(source, against: [background])
    }

    static func readable(_ source: WidgetColor, against backgrounds: [WidgetColor]) -> WidgetColor {
        let source = clamped(source)
        let backgrounds = backgrounds.isEmpty ? [WidgetColor.black] : backgrounds.map(clamped)
        let softened = soften(source)

        let whiteScore = worstContrast(.white, against: backgrounds)
        let blackScore = worstContrast(.black, against: backgrounds)
        let target = whiteScore >= blackScore ? WidgetColor.white : WidgetColor.black

        // First establish a calmer album-tinted foreground. This runs even when the raw album
        // color technically passes WCAG so highly saturated/neon artwork does not fight the UI.
        let tonalBase = blend(softened, toward: target, amount: target == .white ? 0.18 : 0.12)
        if worstContrast(tonalBase, against: backgrounds) >= minimumContrast { return tonalBase }

        var lower = 0.0
        var upper = 1.0
        for _ in 0..<22 {
            let amount = (lower + upper) * 0.5
            let candidate = blend(tonalBase, toward: target, amount: amount)
            if worstContrast(candidate, against: backgrounds) >= minimumContrast {
                upper = amount
            } else {
                lower = amount
            }
        }

        let resolved = blend(tonalBase, toward: target, amount: upper)
        return worstContrast(resolved, against: backgrounds) >= minimumContrast ? resolved : target
    }

    static func blend(_ source: WidgetColor, toward target: WidgetColor, amount: Double) -> WidgetColor {
        let t = min(1, max(0, amount))
        return WidgetColor(
            red: source.red + (target.red - source.red) * t,
            green: source.green + (target.green - source.green) * t,
            blue: source.blue + (target.blue - source.blue) * t
        )
    }

    static func contrast(_ lhs: WidgetColor, _ rhs: WidgetColor) -> Double {
        let a = relativeLuminance(clamped(lhs))
        let b = relativeLuminance(clamped(rhs))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func worstContrast(_ foreground: WidgetColor, against backgrounds: [WidgetColor]) -> Double {
        backgrounds.map { contrast(foreground, $0) }.min() ?? contrast(foreground, .black)
    }

    private static func soften(_ color: WidgetColor) -> WidgetColor {
        let maxChannel = max(color.red, max(color.green, color.blue))
        let minChannel = min(color.red, min(color.green, color.blue))
        let chroma = maxChannel - minChannel
        guard chroma > 0.0001 else { return color }

        let lightness = (maxChannel + minChannel) * 0.5
        let saturation = chroma / max(0.0001, 1 - abs(2 * lightness - 1))
        let softenedSaturation = min(0.58, saturation * 0.68)

        let hue: Double
        if maxChannel == color.red {
            hue = ((color.green - color.blue) / chroma).truncatingRemainder(dividingBy: 6)
        } else if maxChannel == color.green {
            hue = (color.blue - color.red) / chroma + 2
        } else {
            hue = (color.red - color.green) / chroma + 4
        }
        let normalizedHue = (hue / 6 + 1).truncatingRemainder(dividingBy: 1)
        return hsl(hue: normalizedHue, saturation: softenedSaturation, lightness: lightness)
    }

    private static func hsl(hue: Double, saturation: Double, lightness: Double) -> WidgetColor {
        let h = (hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let s = min(1, max(0, saturation))
        let l = min(1, max(0, lightness))
        let chroma = (1 - abs(2 * l - 1)) * s
        let segment = h * 6
        let x = chroma * (1 - abs(segment.truncatingRemainder(dividingBy: 2) - 1))
        let rgb: (Double, Double, Double)
        switch segment {
        case 0..<1: rgb = (chroma, x, 0)
        case 1..<2: rgb = (x, chroma, 0)
        case 2..<3: rgb = (0, chroma, x)
        case 3..<4: rgb = (0, x, chroma)
        case 4..<5: rgb = (x, 0, chroma)
        default: rgb = (chroma, 0, x)
        }
        let match = l - chroma * 0.5
        return WidgetColor(red: rgb.0 + match, green: rgb.1 + match, blue: rgb.2 + match)
    }

    private static func clamped(_ color: WidgetColor) -> WidgetColor {
        WidgetColor(
            red: min(1, max(0, color.red)),
            green: min(1, max(0, color.green)),
            blue: min(1, max(0, color.blue))
        )
    }

    private static func relativeLuminance(_ color: WidgetColor) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }
}
struct AudioCISemanticColors: Equatable {
    let primaryText: WidgetColor
    let secondaryText: WidgetColor
    let primaryControl: WidgetColor
    let secondaryControl: WidgetColor
    let progressFill: WidgetColor
    let progressTrack: WidgetColor
    let progressThumb: WidgetColor
    let lyricCurrent: WidgetColor
    let lyricUpcoming: WidgetColor
    let visualizer: [WidgetColor]
}

/// Converts an artwork palette into semantic Audio CI roles instead of treating every element as
/// the same accent. Hierarchy-sensitive roles deliberately use different contrast/chroma levels:
/// text stays calm, primary controls are stronger, the scrubber gets separate track/fill/thumb
/// colors, and the visualizer gets a small coordinated palette.
enum AudioCISemanticColorResolver {
    static func resolve(album colors: [WidgetColor], backgrounds: [WidgetColor]) -> AudioCISemanticColors {
        let album = colors.isEmpty ? [WidgetColor.accent] : colors
        let backgrounds = backgrounds.isEmpty ? [WidgetColor.black] : backgrounds
        let dominant = album[0]
        let accentSource = distinctSource(in: Array(album.dropFirst()), from: dominant) ?? dominant
        let tertiarySource = distinctSource(in: Array(album.dropFirst(2)), from: accentSource) ?? dominant

        let primaryText = AlbumForegroundColorResolver.readable(dominant, against: backgrounds)
        let primaryControl = AlbumForegroundColorResolver.readable(accentSource, against: backgrounds)
        let progressFill = AlbumForegroundColorResolver.readable(tertiarySource, against: backgrounds)

        let representativeBackground = average(backgrounds)
        let secondaryText = receded(
            primaryText,
            toward: representativeBackground,
            backgrounds: backgrounds,
            minimum: 3.6
        )
        let secondaryControl = receded(
            primaryControl,
            toward: representativeBackground,
            backgrounds: backgrounds,
            minimum: 4.0
        )

        // The track is intentionally subordinate to the fill. It does not carry text, so it sits
        // much closer to the surface while still retaining enough separation to read as a rail.
        let progressTrack = receded(
            progressFill,
            toward: representativeBackground,
            backgrounds: backgrounds,
            minimum: 1.45
        )
        let progressThumb = bestHighContrastColor(
            preferred: primaryText,
            against: backgrounds + [progressFill, progressTrack]
        )

        let visualizerSecondary = harmonized(
            source: accentSource,
            anchor: progressFill,
            backgrounds: backgrounds,
            amount: 0.34
        )
        let visualizerTertiary = harmonized(
            source: tertiarySource,
            anchor: primaryControl,
            backgrounds: backgrounds,
            amount: 0.42
        )

        return AudioCISemanticColors(
            primaryText: primaryText,
            secondaryText: secondaryText,
            primaryControl: primaryControl,
            secondaryControl: secondaryControl,
            progressFill: progressFill,
            progressTrack: progressTrack,
            progressThumb: progressThumb,
            lyricCurrent: primaryText,
            lyricUpcoming: secondaryText,
            visualizer: deduplicated([primaryControl, visualizerSecondary, visualizerTertiary, progressFill])
        )
    }

    private static func harmonized(
        source: WidgetColor,
        anchor: WidgetColor,
        backgrounds: [WidgetColor],
        amount: Double
    ) -> WidgetColor {
        let readableSource = AlbumForegroundColorResolver.readable(source, against: backgrounds)
        let mixed = AlbumForegroundColorResolver.blend(readableSource, toward: anchor, amount: amount)
        return AlbumForegroundColorResolver.worstContrast(mixed, against: backgrounds) >= 3.5
            ? mixed
            : readableSource
    }

    private static func receded(
        _ foreground: WidgetColor,
        toward background: WidgetColor,
        backgrounds: [WidgetColor],
        minimum: Double
    ) -> WidgetColor {
        guard AlbumForegroundColorResolver.worstContrast(foreground, against: backgrounds) > minimum else {
            return foreground
        }
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<22 {
            let amount = (lower + upper) * 0.5
            let candidate = AlbumForegroundColorResolver.blend(foreground, toward: background, amount: amount)
            if AlbumForegroundColorResolver.worstContrast(candidate, against: backgrounds) >= minimum {
                lower = amount
            } else {
                upper = amount
            }
        }
        return AlbumForegroundColorResolver.blend(foreground, toward: background, amount: lower)
    }

    private static func bestHighContrastColor(
        preferred: WidgetColor,
        against backgrounds: [WidgetColor]
    ) -> WidgetColor {
        let candidates = [
            preferred,
            WidgetColor.white,
            WidgetColor.black
        ]
        return candidates.max {
            AlbumForegroundColorResolver.worstContrast($0, against: backgrounds) <
            AlbumForegroundColorResolver.worstContrast($1, against: backgrounds)
        } ?? preferred
    }

    private static func distinctSource(in colors: [WidgetColor], from reference: WidgetColor) -> WidgetColor? {
        colors.max { colorDistance($0, reference) < colorDistance($1, reference) }
    }

    private static func colorDistance(_ lhs: WidgetColor, _ rhs: WidgetColor) -> Double {
        let dr = lhs.red - rhs.red
        let dg = lhs.green - rhs.green
        let db = lhs.blue - rhs.blue
        return dr * dr + dg * dg + db * db
    }

    private static func average(_ colors: [WidgetColor]) -> WidgetColor {
        guard !colors.isEmpty else { return .black }
        let count = Double(colors.count)
        return WidgetColor(
            red: colors.reduce(0) { $0 + $1.red } / count,
            green: colors.reduce(0) { $0 + $1.green } / count,
            blue: colors.reduce(0) { $0 + $1.blue } / count
        )
    }

    private static func deduplicated(_ colors: [WidgetColor]) -> [WidgetColor] {
        var result: [WidgetColor] = []
        for color in colors {
            guard !result.contains(where: { colorDistance($0, color) < 0.006 }) else { continue }
            result.append(color)
        }
        return result.isEmpty ? [.white] : Array(result.prefix(3))
    }
}

enum ClockVisualStyle: String, Codable, CaseIterable, Identifiable {
    case digital = "Digital"
    case minimal = "Minimal"
    case analog = "Analog"
    case flip = "Flip Clock"
    case editorial = "Editorial"
    case stacked = "Stacked"
    case split = "Split"
    case terminal = "Terminal"
    case lcd = "LCD"
    case dotMatrix = "Dot Matrix"
    case outline = "Outline"
    case oversizedTypography = "Oversized Typography"
    var id: String { rawValue }
}

enum ClockSeparatorStyle: String, Codable, CaseIterable, Identifiable {
    case colon = ":"
    case dot = "."
    case middleDot = "·"
    case space = "Space"
    var id: String { rawValue }
    var glyph: String {
        switch self { case .colon: return ":"; case .dot: return "."; case .middleDot: return "·"; case .space: return " " }
    }
}

enum ClockSecondMotion: String, Codable, CaseIterable, Identifiable {
    case ticking = "Ticking"
    case smooth = "Smooth"
    var id: String { rawValue }
}

enum ClockDateTextCase: String, Codable, CaseIterable, Identifiable {
    case natural = "Natural"
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    var id: String { rawValue }
}

enum ClockDateOrder: String, Codable, CaseIterable, Identifiable {
    case weekdayMonthDay = "Weekday · Month · Day"
    case monthDayYear = "Month · Day · Year"
    case dayMonthYear = "Day · Month · Year"
    case yearMonthDay = "Year · Month · Day"
    case monthDayWeekday = "Month · Day · Weekday"
    var id: String { rawValue }
}

enum ClockWeekdayStyle: String, Codable, CaseIterable, Identifiable {
    case short = "Short"
    case full = "Full"
    var id: String { rawValue }
}

enum ClockMonthStyle: String, Codable, CaseIterable, Identifiable {
    case short = "Short"
    case full = "Full"
    case numeric = "Numeric"
    var id: String { rawValue }
}

enum ClockNumeralStyle: String, Codable, CaseIterable, Identifiable {
    case none = "No numerals"
    case arabic = "Arabic"
    case roman = "Roman"
    var id: String { rawValue }
}

enum ClockFontWidth: String, Codable, CaseIterable, Identifiable {
    case compressed = "Compressed"
    case condensed = "Condensed"
    case standard = "Standard"
    case expanded = "Expanded"
    var id: String { rawValue }
}

enum ClockComplication: String, Codable, CaseIterable, Identifiable, Hashable {
    case date, day, seconds, timezone, location, utcOffset, weekNumber, nextEvent, timer
    case weather, temperature, battery, sunrise, sunset, worldClocks
    var id: String { rawValue }
    var title: String {
        switch self {
        case .date: return "Date"
        case .day: return "Day"
        case .seconds: return "Seconds"
        case .timezone: return "Time zone"
        case .location: return "Location label"
        case .utcOffset: return "UTC offset"
        case .weekNumber: return "Week number"
        case .nextEvent: return "Next calendar event"
        case .timer: return "Timer"
        case .weather: return "Weather"
        case .temperature: return "Temperature"
        case .battery: return "Battery"
        case .sunrise: return "Sunrise"
        case .sunset: return "Sunset"
        case .worldClocks: return "Secondary world clocks"
        }
    }
    var symbol: String {
        switch self {
        case .date: return "calendar"
        case .day: return "sun.max"
        case .seconds: return "stopwatch"
        case .timezone, .utcOffset, .worldClocks: return "globe"
        case .location: return "location"
        case .weekNumber: return "number.square"
        case .nextEvent: return "calendar.badge.clock"
        case .timer: return "timer"
        case .weather: return "cloud.sun"
        case .temperature: return "thermometer.medium"
        case .battery: return "battery.100"
        case .sunrise: return "sunrise"
        case .sunset: return "sunset"
        }
    }
}

struct ClockAnalogOptions: Codable, Equatable {
    var numerals: ClockNumeralStyle = .arabic
    var hourTicks = true
    var minuteTicks = false
    var tickThickness = 1.0
    var showHourHand = true
    var showMinuteHand = true
    var showSecondHand = true
    var handThickness = 2.0
    var hourHandLength = 0.46
    var minuteHandLength = 0.67
    var secondHandLength = 0.74
    var centerCap = true
    var faceColor = WidgetColor.white
    var faceOpacity = 0.055
    var hourHandColor = WidgetColor.white
    var minuteHandColor = WidgetColor.white
    var secondHandColor = WidgetColor.accent
    var tickColor = WidgetColor.white
    var smoothSecondHand = true

    func validated() throws -> ClockAnalogOptions {
        let values: [Double] = [tickThickness, handThickness, hourHandLength, minuteHandLength, secondHandLength, faceOpacity]
        guard values.allSatisfy({ $0.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        value.tickThickness = min(5, max(0.35, tickThickness))
        value.handThickness = min(8, max(0.5, handThickness))
        value.hourHandLength = min(0.72, max(0.20, hourHandLength))
        value.minuteHandLength = min(0.84, max(0.30, minuteHandLength))
        value.secondHandLength = min(0.92, max(0.35, secondHandLength))
        value.faceOpacity = min(0.55, max(0, faceOpacity))
        value.faceColor = try faceColor.validated()
        value.hourHandColor = try hourHandColor.validated()
        value.minuteHandColor = try minuteHandColor.validated()
        value.secondHandColor = try secondHandColor.validated()
        value.tickColor = try tickColor.validated()
        return value
    }
}

struct ClockSizeOverride: Codable, Equatable {
    var style: ClockVisualStyle?
    var complications: [ClockComplication]?
}

struct ClockOptions: Codable, Equatable {
    // Legacy keys remain non-optional so existing profiles keep exactly the behavior they had.
    var twentyFourHour = false
    var showSeconds = false
    var showDate = true
    var timeZone = ""

    // New Clock Showcase settings are optional for backwards-compatible decoding.
    var visualStyle: ClockVisualStyle?
    var showAMPM: Bool?
    var leadingZero: Bool?
    var separator: ClockSeparatorStyle?
    var blinkingSeparator: Bool?
    var secondMotion: ClockSecondMotion?
    var hourEmphasis: Double?
    var minuteEmphasis: Double?
    var secondsEmphasis: Double?
    var digitSpacing: Double?

    var showWeekday: Bool?
    var weekdayStyle: ClockWeekdayStyle?
    var showDay: Bool?
    var showMonth: Bool?
    var monthStyle: ClockMonthStyle?
    var showYear: Bool?
    var dateOrder: ClockDateOrder?
    var dateTextCase: ClockDateTextCase?

    var automaticTypography: Bool?
    var fontWidth: ClockFontWidth?
    var monospacedDigits: Bool?
    var tracking: Double?
    var lineSpacing: Double?
    var timeScale: Double?
    var dateScale: Double?
    var secondaryScale: Double?
    var timeDateRatio: Double?

    var enabledComplications: [ClockComplication]?
    var complicationPriority: [ClockComplication]?
    var worldTimeZones: [String]?
    var locationLabel: String?
    var sizeOverrides: [String: ClockSizeOverride]?

    var primaryColor: WidgetColor?
    var secondaryColor: WidgetColor?
    var separatorColor: WidgetColor?
    var textGlow: Double?
    var textShadow: Double?
    var analog: ClockAnalogOptions?

    var resolvedVisualStyle: ClockVisualStyle { visualStyle ?? .digital }
    var resolvedShowAMPM: Bool { showAMPM ?? true }
    var resolvedLeadingZero: Bool { leadingZero ?? twentyFourHour }
    var resolvedSeparator: ClockSeparatorStyle { separator ?? .colon }
    var resolvedBlinkingSeparator: Bool { blinkingSeparator ?? false }
    var resolvedSecondMotion: ClockSecondMotion { secondMotion ?? .ticking }
    var resolvedHourEmphasis: Double { min(1.6, max(0.7, hourEmphasis ?? 1)) }
    var resolvedMinuteEmphasis: Double { min(1.6, max(0.7, minuteEmphasis ?? 1)) }
    var resolvedSecondsEmphasis: Double { min(1.3, max(0.45, secondsEmphasis ?? 0.68)) }
    var resolvedDigitSpacing: Double { min(18, max(-4, digitSpacing ?? 0)) }

    var resolvedShowWeekday: Bool { showWeekday ?? true }
    var resolvedWeekdayStyle: ClockWeekdayStyle { weekdayStyle ?? .full }
    var resolvedShowDay: Bool { showDay ?? true }
    var resolvedShowMonth: Bool { showMonth ?? true }
    var resolvedMonthStyle: ClockMonthStyle { monthStyle ?? .full }
    var resolvedShowYear: Bool { showYear ?? false }
    var resolvedDateOrder: ClockDateOrder { dateOrder ?? .weekdayMonthDay }
    var resolvedDateTextCase: ClockDateTextCase { dateTextCase ?? .natural }

    var usesAutomaticTypography: Bool { automaticTypography ?? true }
    var resolvedFontWidth: ClockFontWidth { fontWidth ?? .standard }
    var usesMonospacedDigits: Bool { monospacedDigits ?? true }
    var resolvedTracking: Double { min(18, max(-5, tracking ?? 0)) }
    var resolvedLineSpacing: Double { min(18, max(0, lineSpacing ?? 2)) }
    var resolvedTimeScale: Double { min(2.5, max(0.55, timeScale ?? 1)) }
    var resolvedDateScale: Double { min(2.2, max(0.55, dateScale ?? 1)) }
    var resolvedSecondaryScale: Double { min(2, max(0.5, secondaryScale ?? 1)) }
    var resolvedTimeDateRatio: Double { min(3.5, max(1.1, timeDateRatio ?? 2.3)) }

    var resolvedEnabledComplications: [ClockComplication] {
        enabledComplications ?? [.date]
    }
    var resolvedComplicationPriority: [ClockComplication] {
        var result: [ClockComplication] = []
        for value in complicationPriority ?? [.date, .nextEvent, .seconds, .timezone, .weather, .worldClocks, .battery, .timer, .day, .location, .utcOffset, .weekNumber, .temperature, .sunrise, .sunset] where !result.contains(value) {
            result.append(value)
        }
        for value in ClockComplication.allCases where !result.contains(value) { result.append(value) }
        return result
    }
    var resolvedWorldTimeZones: [String] {
        let saved = worldTimeZones ?? ["Asia/Tokyo", "Europe/London"]
        return saved.filter { TimeZone(identifier: $0) != nil }
    }
    var resolvedAnalog: ClockAnalogOptions { analog ?? ClockAnalogOptions() }
    var resolvedTextGlow: Double { min(1, max(0, textGlow ?? 0)) }
    var resolvedTextShadow: Double { min(1, max(0, textShadow ?? 0)) }

    static func sizeKey(columns: Int, rows: Int) -> String { "\(max(1, columns))x\(max(1, rows))" }
    func sizeOverride(columns: Int?, rows: Int?) -> ClockSizeOverride? {
        guard let columns, let rows else { return nil }
        return sizeOverrides?[Self.sizeKey(columns: columns, rows: rows)]
    }

    func validated() throws -> ClockOptions {
        guard timeZone.isEmpty || TimeZone(identifier: timeZone) != nil else { throw CocoaError(.fileReadCorruptFile) }
        let numbers = [hourEmphasis, minuteEmphasis, secondsEmphasis, digitSpacing, tracking, lineSpacing, timeScale, dateScale, secondaryScale, timeDateRatio, textGlow, textShadow].compactMap { $0 }
        guard numbers.allSatisfy({ $0.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        if let hourEmphasis { value.hourEmphasis = min(1.6, max(0.7, hourEmphasis)) }
        if let minuteEmphasis { value.minuteEmphasis = min(1.6, max(0.7, minuteEmphasis)) }
        if let secondsEmphasis { value.secondsEmphasis = min(1.3, max(0.45, secondsEmphasis)) }
        if let digitSpacing { value.digitSpacing = min(18, max(-4, digitSpacing)) }
        if let tracking { value.tracking = min(18, max(-5, tracking)) }
        if let lineSpacing { value.lineSpacing = min(18, max(0, lineSpacing)) }
        if let timeScale { value.timeScale = min(2.5, max(0.55, timeScale)) }
        if let dateScale { value.dateScale = min(2.2, max(0.55, dateScale)) }
        if let secondaryScale { value.secondaryScale = min(2, max(0.5, secondaryScale)) }
        if let timeDateRatio { value.timeDateRatio = min(3.5, max(1.1, timeDateRatio)) }
        if let textGlow { value.textGlow = min(1, max(0, textGlow)) }
        if let textShadow { value.textShadow = min(1, max(0, textShadow)) }
        value.locationLabel = locationLabel.map { String($0.prefix(80)) }
        value.worldTimeZones = resolvedWorldTimeZones
        if let primaryColor { value.primaryColor = try primaryColor.validated() }
        if let secondaryColor { value.secondaryColor = try secondaryColor.validated() }
        if let separatorColor { value.separatorColor = try separatorColor.validated() }
        if analog != nil { value.analog = try resolvedAnalog.validated() }
        if let overrides = sizeOverrides {
            value.sizeOverrides = overrides.filter { key, _ in
                let parts = key.split(separator: "x")
                guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]) else { return false }
                return (1...12).contains(columns) && (1...12).contains(rows)
            }
        }
        return value
    }
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

enum CalendarWidgetViewStyle: String, Codable, CaseIterable, Identifiable {
    case agenda = "Agenda"
    case monthGrid = "Month Grid"
    case weekStrip = "Week Strip"
    case split = "Split"
    var id: String { rawValue }
}


enum VisualCalendarViewStyle: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case today = "Today"
    case agenda = "Agenda"
    case dayTimeline = "Day Timeline"
    case week = "Week"
    case month = "Month"
    case monthAgenda = "Month + Agenda"
    case split = "Split"
    case upcoming = "Upcoming"
    case minimal = "Minimal"
    var id: String { rawValue }
}

enum VisualCalendarWeekStart: String, Codable, CaseIterable, Identifiable {
    case system = "System Default"
    case monday = "Monday"
    case sunday = "Sunday"
    var id: String { rawValue }
}

enum VisualCalendarEventIndicatorStyle: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case dots = "Dots"
    case bars = "Bars"
    case underline = "Underline"
    case filledDate = "Filled Date"
    case minimalMarker = "Minimal Marker"
    var id: String { rawValue }
}

enum VisualCalendarTodayStyle: String, Codable, CaseIterable, Identifiable {
    case circle = "Circle"
    case pill = "Pill"
    case filledNumber = "Filled Number"
    case outline = "Outline"
    case accentText = "Accent Text"
    case subtleGlow = "Subtle Glow"
    case minimalDot = "Minimal Dot"
    var id: String { rawValue }
}

enum VisualCalendarDensity: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case compact = "Compact"
    case comfortable = "Comfortable"
    case spacious = "Spacious"
    var id: String { rawValue }
}

enum VisualCalendarWeekendStyle: String, Codable, CaseIterable, Identifiable {
    case normal = "Normal"
    case subtle = "Subtle"
    case muted = "Muted"
    case accent = "Accent"
    var id: String { rawValue }
}

enum VisualCalendarFilterMode: String, Codable, CaseIterable, Identifiable {
    case all = "All Calendars"
    case selected = "Selected Calendars"
    case work = "Work"
    case personal = "Personal"
    case birthdays = "Birthdays"
    case holidaysFestivals = "Holidays & Festivals"
    case custom = "Calendar Names"
    var id: String { rawValue }
}

enum VisualCalendarInformation: String, Codable, CaseIterable, Identifiable, Hashable {
    case startTime, calendarColor, endTime, location, meetingLink, duration, notes, attendees
    var id: String { rawValue }
    var title: String {
        switch self {
        case .startTime: return "Start time"
        case .calendarColor: return "Calendar color"
        case .endTime: return "End time"
        case .location: return "Location"
        case .meetingLink: return "Meeting link"
        case .duration: return "Duration"
        case .notes: return "Notes preview"
        case .attendees: return "Attendee indicator"
        }
    }
}

struct VisualCalendarTypography: Codable, Equatable {
    var fontFamily: WidgetFontFamily = .system
    var customFont = "Helvetica Neue"
    var weight: WidgetFontWeight = .medium
    var size = 13.0

    func validated() throws -> VisualCalendarTypography {
        guard size.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        value.customFont = String(customFont.prefix(120))
        value.size = min(48, max(8, size))
        return value
    }
}

struct VisualCalendarSizeOverride: Codable, Equatable {
    var view: VisualCalendarViewStyle?
    var maxEvents: Int?
    var indicatorStyle: VisualCalendarEventIndicatorStyle?
}

struct VisualCalendarOptions: Codable, Equatable {
    var preferredView: VisualCalendarViewStyle = .automatic
    var weekStart: VisualCalendarWeekStart = .system
    var showWeekNumbers = false
    var showAdjacentMonthDays = true
    var highlightToday = true
    var highlightSelectedDay = true
    var eventIndicatorStyle: VisualCalendarEventIndicatorStyle = .automatic
    var visibleEventIndicators = 3
    var weekendStyle: VisualCalendarWeekendStyle = .subtle
    var density: VisualCalendarDensity = .automatic
    var maxEvents = 8

    var showEventEndTime = true
    var showEventDuration = true
    var showEventLocation = true
    var showMeetingLink = true
    var showNotesPreview = true
    var showAttendees = true
    var enabledInformation: [VisualCalendarInformation] = VisualCalendarInformation.allCases
    var informationPriority: [VisualCalendarInformation] = [.startTime, .calendarColor, .endTime, .location, .meetingLink, .duration, .notes, .attendees]

    var filterMode: VisualCalendarFilterMode = .all
    var customCalendarNames: [String] = []
    var selectedCalendarIdentifiers: [String] = []
    var useNativeCalendarColors = true
    var eventColorOverride: WidgetColor?

    var todayStyle: VisualCalendarTodayStyle = .filledNumber
    var todayColor: WidgetColor?
    var selectedDayColor: WidgetColor?
    var eventCornerRadius = 8.0
    var eventOpacity = 0.08
    var showGridLines = false
    var gridLineOpacity = 0.08
    var backgroundOpacity = 0.0

    var dateTypography = VisualCalendarTypography(fontFamily: .rounded, customFont: "Helvetica Neue", weight: .bold, size: 14)
    var eventTypography = VisualCalendarTypography(fontFamily: .system, customFont: "Helvetica Neue", weight: .medium, size: 12)
    var monthTypography = VisualCalendarTypography(fontFamily: .rounded, customFont: "Helvetica Neue", weight: .semibold, size: 13)

    var sizeOverrides: [String: VisualCalendarSizeOverride] = [:]

    static func sizeKey(columns: Int, rows: Int) -> String { "\(min(8, max(1, columns)))x\(min(4, max(1, rows)))" }
    func sizeOverride(columns: Int, rows: Int) -> VisualCalendarSizeOverride? { sizeOverrides[Self.sizeKey(columns: columns, rows: rows)] }

    var resolvedInformationPriority: [VisualCalendarInformation] {
        var result: [VisualCalendarInformation] = []
        for value in informationPriority where !result.contains(value) { result.append(value) }
        for value in VisualCalendarInformation.allCases where !result.contains(value) { result.append(value) }
        return result
    }

    func validated() throws -> VisualCalendarOptions {
        guard eventCornerRadius.isFinite, eventOpacity.isFinite, gridLineOpacity.isFinite, backgroundOpacity.isFinite else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var value = self
        value.visibleEventIndicators = min(6, max(1, visibleEventIndicators))
        value.maxEvents = min(30, max(1, maxEvents))
        value.eventCornerRadius = min(24, max(0, eventCornerRadius))
        value.eventOpacity = min(0.45, max(0, eventOpacity))
        value.gridLineOpacity = min(0.5, max(0, gridLineOpacity))
        value.backgroundOpacity = min(0.6, max(0, backgroundOpacity))
        value.customCalendarNames = customCalendarNames.map { String($0.prefix(120)) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        value.selectedCalendarIdentifiers = Array(Set(selectedCalendarIdentifiers.map { String($0.prefix(240)) }.filter { !$0.isEmpty })).sorted()
        value.eventColorOverride = try eventColorOverride?.validated()
        value.todayColor = try todayColor?.validated()
        value.selectedDayColor = try selectedDayColor?.validated()
        value.dateTypography = try dateTypography.validated()
        value.eventTypography = try eventTypography.validated()
        value.monthTypography = try monthTypography.validated()
        value.enabledInformation = VisualCalendarInformation.allCases.filter { enabledInformation.contains($0) }
        value.informationPriority = resolvedInformationPriority
        value.sizeOverrides = sizeOverrides.filter { key, override in
            let parts = key.split(separator: "x")
            guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]), (1...8).contains(columns), (1...4).contains(rows) else { return false }
            if let maxEvents = override.maxEvents, !(1...30).contains(maxEvents) { return false }
            return true
        }
        return value
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
    // Optional additions keep pre-calendar-redesign profiles decodable.
    var calendarViewStyle: CalendarWidgetViewStyle?
    var calendarShowAdjacentDays: Bool?
    var calendarShowEventDots: Bool?
    var calendarShowWeekdayHeader: Bool?
    var calendarShowAgendaBelowGrid: Bool?
    var resolvedCalendarViewStyle: CalendarWidgetViewStyle { calendarViewStyle ?? .agenda }
    var showsCalendarAdjacentDays: Bool { calendarShowAdjacentDays ?? true }
    var showsCalendarEventDots: Bool { calendarShowEventDots ?? true }
    var showsCalendarWeekdayHeader: Bool { calendarShowWeekdayHeader ?? true }
    var showsCalendarAgendaBelowGrid: Bool { calendarShowAgendaBelowGrid ?? true }

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


// MARK: - Canonical widget footprint system

enum VisualWidgetStage: String, Codable, CaseIterable, Identifiable {
    case micro = "Micro", compact = "Compact", rich = "Rich", dashboard = "Dashboard"
    var id: String { rawValue }
}

enum VisualWidgetOrientation: String, Codable { case square, horizontal, vertical }

struct VisualWidgetFootprint: Hashable, Codable {
    let columns: Int
    let rows: Int

    init(columns: Int, rows: Int) {
        self.columns = min(8, max(1, columns))
        self.rows = min(4, max(1, rows))
    }

    var key: String { "\(columns)x\(rows)" }
    var area: Int { columns * rows }
    var orientation: VisualWidgetOrientation { columns == rows ? .square : (columns > rows ? .horizontal : .vertical) }
    var stage: VisualWidgetStage {
        if area <= 2 { return .micro }
        if (rows <= 2 && columns <= 4) || (columns <= 2 && rows <= 4) { return .compact }
        if columns >= 6 && rows >= 3 { return .dashboard }
        return .rich
    }
    var informationCapacity: Int {
        switch stage {
        case .micro: return min(3, 1 + area)
        case .compact: return min(7, 2 + area)
        case .rich: return min(13, 3 + area / 2)
        case .dashboard: return min(18, 6 + area / 2)
        }
    }
    var itemCapacity: Int {
        switch stage {
        case .micro: return max(1, area)
        case .compact: return min(8, max(2, area))
        case .rich: return min(18, max(4, area))
        case .dashboard: return min(32, area)
        }
    }
    func contains(columns requiredColumns: Int, rows requiredRows: Int) -> Bool {
        columns >= requiredColumns && rows >= requiredRows
    }
}

struct VisualWidgetSizeRecommendation: Equatable {
    let minimum: VisualWidgetFootprint
    let everyday: VisualWidgetFootprint
    let rich: VisualWidgetFootprint
}

extension ModuleID {
    var visualWidgetSizeRecommendation: VisualWidgetSizeRecommendation {
        switch self {
        case .timer: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))
        case .shelf: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 3))
        case .media, .audio: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 3))
        case .calendar: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 4))
        case .clipboard: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 5, rows: 3))
        case .system: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 3))
        case .launcher: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 4))
        case .notes: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 4, rows: 4))
        case .capture: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 1), rich: .init(columns: 4, rows: 3))
        case .stopwatch: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))
        case .clock: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 1), rich: .init(columns: 4, rows: 2))
        case .activities, .developer: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))
        case .pet: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 4))
        }
    }

    func visualWidgetSizeHint(for footprint: VisualWidgetFootprint) -> String {
        let recommendation = visualWidgetSizeRecommendation
        if self == .pet {
            if footprint.columns != footprint.rows || !(1...4).contains(footprint.columns) { return "Pixel Pal supports 1×1, 2×2, 3×3 and 4×4 squares." }
            return "Pixel Pal · square face-only retro expression at \(footprint.columns)×\(footprint.rows)."
        }
        if footprint.area == 1 && self == .notes { return "1×1 is Quick Note capture only · actual note content starts at 2×2." }
        if footprint.contains(columns: recommendation.rich.columns, rows: recommendation.rich.rows) { return "Rich layout · secondary panels and deeper controls are available." }
        if footprint.contains(columns: recommendation.everyday.columns, rows: recommendation.everyday.rows) { return "Recommended everyday layout." }
        return "Compact layout · Halo prioritizes glanceable information and safe primary actions."
    }
}

// MARK: - Visual Workspace adaptive widget system

enum VisualAdaptivePresentation: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case micro = "Micro"
    case compact = "Compact"
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case standard = "Standard"
    case expanded = "Expanded"
    case dashboard = "Dashboard"
    case hero = "Hero"
    var id: String { rawValue }
}

enum VisualAdaptiveDensity: String, Codable, CaseIterable, Identifiable {
    case compact = "Compact", comfortable = "Comfortable", spacious = "Spacious"
    var id: String { rawValue }
}

enum VisualTimerStyle: String, Codable, CaseIterable, Identifiable {
    case minimal = "Minimal", digital = "Digital", circular = "Circular", ring = "Ring", progressBar = "Progress Bar", editorial = "Editorial", largeTypography = "Large Typography"
    var id: String { rawValue }
}
enum VisualTimerMode: String, Codable, CaseIterable, Identifiable { case remaining = "Remaining", elapsed = "Elapsed"; var id: String { rawValue } }
enum VisualMediaMicroStyle: String, Codable, CaseIterable, Identifiable { case artwork = "Artwork", artworkPlay = "Artwork + Play", title = "Title"; var id: String { rawValue } }
enum VisualAdaptiveArtworkShape: String, Codable, CaseIterable, Identifiable { case rounded = "Rounded", square = "Square", circle = "Circle"; var id: String { rawValue } }
enum VisualAdaptiveProgressStyle: String, Codable, CaseIterable, Identifiable { case native = "Interactive Slider", thin = "Thin", pill = "Pill"; var id: String { rawValue } }
enum VisualAdaptiveVisualizerPosition: String, Codable, CaseIterable, Identifiable { case inline = "Inline", bottom = "Bottom"; var id: String { rawValue } }
enum VisualAdaptiveAudioSliderStyle: String, Codable, CaseIterable, Identifiable { case standard = "Standard", compact = "Compact"; var id: String { rawValue } }
enum VisualAdaptiveClipboardRowStyle: String, Codable, CaseIterable, Identifiable { case list = "List", tiles = "Tiles", minimal = "Minimal"; var id: String { rawValue } }
enum VisualSystemGraphType: String, Codable, CaseIterable, Identifiable { case line = "Line", bars = "Bars"; var id: String { rawValue } }
enum VisualCapturePrimaryAction: String, Codable, CaseIterable, Identifiable { case region = "Capture Region", ocr = "OCR Image"; var id: String { rawValue } }
enum VisualStopwatchPrecision: String, Codable, CaseIterable, Identifiable {
    case seconds = "Seconds", tenths = "Tenths", hundredths = "Hundredths"
    var id: String { rawValue }
    var interval: TimeInterval { switch self { case .seconds: return 1; case .tenths: return 0.1; case .hundredths: return 0.05 } }
}

enum VisualSystemMetric: String, Codable, CaseIterable, Identifiable {
    case cpu = "CPU", memory = "Memory", storage = "Storage", battery = "Battery", network = "Network", swap = "Swap", thermal = "Thermal", uptime = "Uptime"
    var id: String { rawValue }
    var title: String { rawValue }
    var shortTitle: String { switch self { case .memory: return "RAM"; case .storage: return "SSD"; case .battery: return "BAT"; case .network: return "NET"; case .thermal: return "TEMP"; case .uptime: return "UP"; default: return rawValue.uppercased() } }
    var symbol: String { switch self { case .cpu: return "cpu"; case .memory: return "memorychip"; case .storage: return "internaldrive"; case .battery: return "battery.100"; case .network: return "arrow.down.arrow.up"; case .swap: return "arrow.triangle.swap"; case .thermal: return "thermometer.medium"; case .uptime: return "clock.arrow.circlepath" } }
    var supportsHistory: Bool { self == .cpu || self == .memory || self == .network }
}

struct VisualAdaptiveSizeOverride: Codable, Equatable {
    var presentation: VisualAdaptivePresentation?
    var density: VisualAdaptiveDensity?
    var maxItems: Int?
    var showControls: Bool?
    var hiddenInformation: [String]?
}

struct VisualAdaptiveWidgetOptions: Codable, Equatable {
    var preferredPresentation: VisualAdaptivePresentation = .automatic
    var density: VisualAdaptiveDensity = .comfortable
    var maxItems = 6
    var showControls = true
    var informationPriority: [String] = []
    var hiddenInformation: [String] = []
    var sizeOverrides: [String: VisualAdaptiveSizeOverride] = [:]

    // Timer
    var timerStyle: VisualTimerStyle = .digital
    var timerMode: VisualTimerMode = .remaining
    var timerProgressThickness: CGFloat = 5
    var timerShowSeconds = true
    var timerName = "Focus"

    // Media
    var mediaMicroStyle: VisualMediaMicroStyle = .artworkPlay
    var mediaArtworkShape: VisualAdaptiveArtworkShape = .rounded
    var mediaArtworkCornerRadius: CGFloat = 16
    var mediaArtworkScale: CGFloat = 1
    var mediaArtworkBackground = false
    var mediaArtworkBlur: CGFloat = 14
    var mediaUseArtworkColors = true
    var mediaProgressStyle: VisualAdaptiveProgressStyle = .native
    var mediaVisualizer = false
    var mediaVisualizerPosition: VisualAdaptiveVisualizerPosition = .bottom

    // Audio
    var audioSliderStyle: VisualAdaptiveAudioSliderStyle = .standard
    var audioShowPercentage = true
    var audioShowDeviceIcon = true
    var audioShowSlider = true
    var audioShowOutputSelector = true
    var audioShowQuickLevels = false

    // Clipboard
    var clipboardPreviewLength = 92
    var clipboardShowTimestamp = true
    var clipboardShowSearch = true
    var clipboardRowStyle: VisualAdaptiveClipboardRowStyle = .list

    // System
    var systemPrimaryMetric: VisualSystemMetric = .cpu
    var systemMetricOrder: [VisualSystemMetric] = [.cpu, .memory, .storage, .battery, .network, .swap, .thermal, .uptime]
    var systemShowGraphs = true
    var systemGraphType: VisualSystemGraphType = .line
    var systemWarningThreshold = 85.0

    // Launcher
    var launcherIconSize: CGFloat = 32
    var launcherShowLabels = true
    var launcherColumns = 4
    var launcherFavoriteBundleIDs: [String] = ["com.apple.dt.Xcode", "com.unity3d.UnityEditor5.x", "com.apple.Safari", "com.apple.Terminal"]
    var launcherShowSearch = true
    var launcherShowRunningApps = true
    var launcherShowDownloads = true
    var launcherShowTimerActions = true

    // Activities
    var activitiesShowProgress = true
    var activitiesShowDetails = true
    var activitiesShowTimestamps = true

    // Notes
    var notesLineSpacing: CGFloat = 2
    var notesEditorPadding: CGFloat = 2
    var notesShowCounts = true
    var notesPlaceholder = "Start typing…"

    // Capture
    var capturePrimaryAction: VisualCapturePrimaryAction = .region
    var captureShowRecent = true
    var captureThumbnailSize: CGFloat = 150
    var captureShowOCR = true

    // Stopwatch
    var stopwatchPrecision: VisualStopwatchPrecision = .tenths
    var stopwatchShowLaps = true
    var stopwatchLapCount = 6
    var stopwatchShowLapExtremes = true
    var stopwatchTimeScale = 1.0

    static func sizeKey(columns: Int, rows: Int) -> String { "\(min(8, max(1, columns)))x\(min(4, max(1, rows)))" }
    func sizeOverride(columns: Int, rows: Int) -> VisualAdaptiveSizeOverride? { sizeOverrides[Self.sizeKey(columns: columns, rows: rows)] }

    static func defaults(for module: ModuleID) -> VisualAdaptiveWidgetOptions {
        var value = VisualAdaptiveWidgetOptions()
        value.informationPriority = module.visualAdaptiveDefaultInformationOrder
        switch module {
        case .timer: value.maxItems = 5
        case .shelf: value.maxItems = 12
        case .media: value.maxItems = 8; value.mediaVisualizer = false
        case .audio: value.maxItems = 8
        case .clipboard: value.maxItems = 8
        case .system: value.maxItems = 8
        case .launcher: value.maxItems = 8
        case .activities: value.maxItems = 6
        case .notes: value.maxItems = 1
        case .capture: value.maxItems = 4
        case .stopwatch: value.maxItems = 6
        default: break
        }
        return value
    }

    func effective(columns: Int, rows: Int) -> VisualAdaptiveWidgetOptions {
        guard let override = sizeOverride(columns: columns, rows: rows) else { return self }
        var value = self
        if let presentation = override.presentation { value.preferredPresentation = presentation }
        if let density = override.density { value.density = density }
        if let maxItems = override.maxItems { value.maxItems = maxItems }
        if let showControls = override.showControls { value.showControls = showControls }
        if let hiddenInformation = override.hiddenInformation { value.hiddenInformation = hiddenInformation }
        return value
    }

    func resolvedInformationPriority(for module: ModuleID) -> [String] {
        var result: [String] = []
        let source = module.visualAdaptiveConfigurableElementKeys.isEmpty
            ? module.widgetElements.map(\.key)
            : module.visualAdaptiveConfigurableElementKeys
        let valid = Set(source)
        for key in informationPriority where valid.contains(key) && !result.contains(key) { result.append(key) }
        for key in module.visualAdaptiveDefaultInformationOrder where valid.contains(key) && !result.contains(key) { result.append(key) }
        for key in source where !result.contains(key) { result.append(key) }
        return result
    }

    func visibleInformation(for module: ModuleID, capacity: Int) -> Set<String> {
        let always = module.visualAdaptiveAlwaysInformation
        let hidden = Set(hiddenInformation)
        let ordered = resolvedInformationPriority(for: module).filter { !always.contains($0) && !hidden.contains($0) }
        let room = max(0, capacity - always.count)
        return Set(always + Array(ordered.prefix(room)))
    }

    var resolvedSystemMetrics: [VisualSystemMetric] {
        var result: [VisualSystemMetric] = [systemPrimaryMetric]
        for metric in systemMetricOrder where !result.contains(metric) { result.append(metric) }
        for metric in VisualSystemMetric.allCases where !result.contains(metric) { result.append(metric) }
        return result
    }

    func validated() throws -> VisualAdaptiveWidgetOptions {
        guard timerProgressThickness.isFinite, mediaArtworkCornerRadius.isFinite, mediaArtworkScale.isFinite,
              mediaArtworkBlur.isFinite, systemWarningThreshold.isFinite, launcherIconSize.isFinite,
              notesLineSpacing.isFinite, notesEditorPadding.isFinite, captureThumbnailSize.isFinite,
              stopwatchTimeScale.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        value.maxItems = min(30, max(1, maxItems))
        value.timerProgressThickness = min(18, max(1, timerProgressThickness))
        value.timerName = String(timerName.prefix(60))
        value.mediaArtworkCornerRadius = min(60, max(0, mediaArtworkCornerRadius))
        value.mediaArtworkScale = min(1.8, max(0.5, mediaArtworkScale))
        value.mediaArtworkBlur = min(40, max(0, mediaArtworkBlur))
        value.clipboardPreviewLength = min(500, max(16, clipboardPreviewLength))
        value.systemWarningThreshold = min(100, max(1, systemWarningThreshold))
        value.launcherIconSize = min(72, max(16, launcherIconSize))
        value.launcherColumns = min(8, max(1, launcherColumns))
        value.launcherFavoriteBundleIDs = Array(launcherFavoriteBundleIDs.map { String($0.prefix(180)) }.filter { !$0.isEmpty }.prefix(20))
        value.notesLineSpacing = min(18, max(0, notesLineSpacing))
        value.notesEditorPadding = min(24, max(0, notesEditorPadding))
        value.notesPlaceholder = String(notesPlaceholder.prefix(180))
        value.captureThumbnailSize = min(320, max(64, captureThumbnailSize))
        value.stopwatchLapCount = min(20, max(1, stopwatchLapCount))
        value.stopwatchTimeScale = min(2.5, max(0.6, stopwatchTimeScale))
        value.informationPriority = Array(informationPriority.prefix(40))
        value.hiddenInformation = Array(Set(hiddenInformation)).prefix(40).map { $0 }
        var cleaned: [String: VisualAdaptiveSizeOverride] = [:]
        for (key, item) in sizeOverrides where key.range(of: #"^[1-8]x[1-4]$"#, options: .regularExpression) != nil {
            var next = item
            if let count = next.maxItems { next.maxItems = min(30, max(1, count)) }
            if let hidden = next.hiddenInformation { next.hiddenInformation = Array(Set(hidden)).prefix(40).map { $0 } }
            cleaned[key] = next
        }
        value.sizeOverrides = cleaned
        return value
    }
}

extension ModuleID {
    var visualAdaptiveSupported: Bool {
        switch self {
        case .timer, .shelf, .media, .audio, .clipboard, .system, .launcher, .activities, .notes, .capture, .stopwatch: return true
        default: return false
        }
    }

    var visualAdaptiveAlwaysInformation: [String] {
        switch self {
        case .timer: return ["countdown"]
        case .shelf: return ["files"]
        case .media: return ["artwork", "track"]
        case .audio: return ["volumeValue"]
        case .clipboard: return ["entries"]
        case .launcher: return ["apps"]
        case .activities: return ["summary"]
        case .notes: return ["editor"]
        case .capture: return ["actions"]
        case .stopwatch: return ["time"]
        default: return []
        }
    }

    var visualAdaptiveDefaultInformationOrder: [String] {
        switch self {
        case .timer: return ["countdown", "controls", "progress", "status", "endTime", "presets"]
        case .shelf: return ["files", "summary", "actions", "footer"]
        case .media: return ["artwork", "track", "controls", "artist", "progress", "timing", "album", "shuffle", "repeat", "visualizer", "source", "playback", "status", "detection", "palette", "lyrics"]
        case .audio: return ["volumeValue", "output", "volume", "summary", "levels", "actions", "status"]
        case .clipboard: return ["entries", "search", "summary", "actions", "footer"]
        case .system: return ["cpu", "memoryUsage", "battery", "diskUsage", "network", "graphs", "swap", "thermal", "uptime", "power", "storage", "device", "memory", "batteryProgress"]
        case .launcher: return ["apps", "search", "shortcuts", "timers", "plugins", "summary"]
        case .activities: return ["summary", "items", "status"]
        case .notes: return ["editor", "stats", "actions"]
        case .capture: return ["actions", "result", "progress", "resultActions", "status", "hint"]
        case .stopwatch: return ["time", "controls", "state"]
        default: return widgetElements.map(\.key)
        }
    }
}

struct VisualAdaptiveElementAvailability {
    let available: Bool
    let reason: String?
}

extension ModuleID {
    /// Inspector capability flags. If a setting is not consumed by a renderer, the editor must
    /// not pretend that it is configurable.
    var visualAdaptiveSupportsMaximumItems: Bool {
        switch self {
        case .shelf, .audio, .clipboard, .system, .launcher, .activities: return true
        default: return false
        }
    }

    var visualAdaptiveSupportsControlToggle: Bool {
        switch self {
        case .timer, .media, .audio, .clipboard, .stopwatch: return true
        default: return false
        }
    }

    func visualAdaptiveMaximumItemsAffects(_ footprint: VisualWidgetFootprint) -> Bool {
        guard visualAdaptiveSupportsMaximumItems else { return false }
        switch self {
        case .audio:
            return footprint.area >= 6
        case .shelf, .clipboard, .system, .launcher, .activities:
            return footprint.area > 1
        default:
            return false
        }
    }

    func visualAdaptiveControlToggleAffects(_ footprint: VisualWidgetFootprint) -> Bool {
        guard visualAdaptiveSupportsControlToggle else { return false }
        switch self {
        case .timer, .clipboard, .stopwatch:
            return footprint.area > 1
        case .media, .audio:
            return true
        default:
            return false
        }
    }

    /// Only keys which the adaptive renderer actually consumes belong here. This intentionally
    /// excludes legacy element controls that do nothing in a Visual Workspace renderer.
    var visualAdaptiveConfigurableElementKeys: [String] {
        switch self {
        case .timer:
            return ["countdown", "controls", "progress", "status", "endTime", "presets"]
        case .media:
            return ["artwork", "track", "controls", "artist", "progress", "timing", "album", "source", "shuffle", "repeat", "visualizer"]
        default:
            return []
        }
    }

    func visualAdaptiveElementAvailability(_ key: String, footprint: VisualWidgetFootprint) -> VisualAdaptiveElementAvailability {
        func yes() -> VisualAdaptiveElementAvailability { .init(available: true, reason: nil) }
        func no(_ reason: String) -> VisualAdaptiveElementAvailability { .init(available: false, reason: reason) }

        switch self {
        case .timer:
            switch key {
            case "countdown": return yes()
            case "controls": return footprint.area >= 2 ? yes() : no("Visible controls start at 2×1 / 1×2. The 1×1 tile keeps its click/hold interaction instead.")
            case "progress": return (footprint.area >= 4 || footprint.columns >= 4 || footprint.rows >= 3) ? yes() : no("Progress needs more room; use at least 2×2, 4×1, or a 1×3 vertical tile.")
            case "presets": return footprint.area >= 4 ? yes() : no("Preset buttons need at least a 2×2-sized footprint.")
            case "status", "endTime": return (footprint.rows >= 4 || footprint.stage == .dashboard) ? yes() : no("Timer metadata appears on tall or dashboard layouts.")
            default: return no("This element is not rendered by the adaptive Timer.")
            }
        case .media:
            switch key {
            case "artwork", "track", "controls": return yes()
            case "artist": return footprint.area >= 2 ? yes() : no("Artist metadata starts above 1×1.")
            case "progress": return (footprint.area >= 4 || footprint.columns >= 6 || footprint.rows >= 3) ? yes() : no("Playback progress needs at least a medium footprint.")
            case "album", "source": return footprint.area >= 4 ? yes() : no("Secondary media metadata starts at medium layouts.")
            case "timing": return ((footprint.columns >= 4 && footprint.rows >= 2) || (footprint.columns >= 3 && footprint.rows >= 3)) ? yes() : no("Elapsed / remaining time is reserved for expanded media layouts.")
            case "shuffle", "repeat", "visualizer": return (footprint.columns >= 6 && footprint.rows >= 3) ? yes() : no("This tool is reserved for dashboard/hero media layouts (6×3 or larger).")
            default: return no("This element is not rendered by the adaptive Media widget.")
            }
        default:
            return no("This widget uses dedicated controls instead of legacy per-element toggles.")
        }
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
    // Visual Workspace Calendar options live separately so the regular opened-notch Calendar keeps its legacy presentation untouched.
    var visualCalendar: VisualCalendarOptions?
    // Shared Visual Workspace adaptive options for non-Clock/Calendar widgets.
    var visualAdaptive: VisualAdaptiveWidgetOptions?
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
    var resolvedVisualCalendar: VisualCalendarOptions { visualCalendar ?? VisualCalendarOptions() }
    func resolvedVisualAdaptive(for module: ModuleID) -> VisualAdaptiveWidgetOptions { visualAdaptive ?? .defaults(for: module) }
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
        guard [fontSize, backgroundOpacity, padding, cornerRadius, width, minimumHeight].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.clock = try clock.validated()
        if visualCalendar != nil { v.visualCalendar = try resolvedVisualCalendar.validated() }
        if visualAdaptive != nil { v.visualAdaptive = try resolvedVisualAdaptive(for: .timer).validated() }
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
extension WidgetStyle {
    /// A polished, integrated starting point for module blocks inside the Visual Workspace.
    /// Existing user overrides always win; these values only seed missing per-instance choices.
    func visualWorkspacePolished(for module: ModuleID) -> WidgetStyle {
        var value = self
        value.width = 0
        value.minimumHeight = 0
        value.showTitle = false
        if value.cardBackgroundStyle == nil { value.cardBackgroundStyle = WidgetCardBackgroundStyle.none }
        if value.outlineStyle == nil { value.outlineStyle = WidgetOutlineStyle.none }
        if value.showHeaderIcon == nil { value.showHeaderIcon = false }
        value.padding = min(16, max(8, value.padding))
        value.cornerRadius = min(28, max(14, value.cornerRadius))
        value.fontSize = min(32, max(12, value.fontSize))

        var content = value.resolvedContent
        content.spacing = min(10, max(4, content.spacing * 0.75))
        content.controlSize = .small
        content.iconSize = min(18, max(12, content.iconSize))
        if module == .clock { content.alignment = .center }
        if module == .calendar, content.calendarViewStyle == nil { content.calendarViewStyle = .split }
        value.content = content

        var chrome = value.resolvedChrome
        chrome.shadowOpacity = min(0.18, chrome.shadowOpacity)
        value.chrome = chrome

        var elements = value.elementStyles ?? [:]
        func seed(_ key: String,
                  foreground: WidgetElementForegroundStyle = .inherit,
                  background: WidgetElementBackgroundStyle = .none,
                  backgroundOpacity: Double = 1,
                  padding: Double = 0,
                  radius: Double = 10,
                  emphasis: WidgetElementEmphasis = .regular,
                  scale: Double = 1) {
            guard elements[key] == nil else { return }
            var element = WidgetElementStyle()
            element.foreground = foreground
            element.background = background
            element.backgroundOpacity = backgroundOpacity
            element.padding = padding
            element.cornerRadius = radius
            element.emphasis = emphasis
            element.fontScale = scale
            elements[key] = element
        }

        // Shared hierarchy: important values are stronger, metadata recedes, and functional
        // groups get just enough surface treatment to feel designed without becoming card soup.
        seed("summary", foreground: .secondary, scale: 0.88)
        switch module {
        case .clock:
            seed("time", emphasis: .semibold, scale: 1.28)
            seed("date", foreground: .secondary, scale: 0.88)
            seed("timezone", foreground: .secondary, scale: 0.78)
            seed("nextEvent", foreground: .secondary, scale: 0.82)
            seed("timer", foreground: .secondary, scale: 0.82)
            seed("weather", foreground: .secondary, scale: 0.82)
            seed("battery", foreground: .secondary, scale: 0.82)
            seed("worldClocks", foreground: .secondary, scale: 0.78)
            seed("solar", foreground: .secondary, scale: 0.78)
            if value.clock.enabledComplications == nil {
                value.clock.enabledComplications = [.date, .nextEvent, .timezone, .battery, .worldClocks]
            }
            if value.clock.complicationPriority == nil {
                value.clock.complicationPriority = [.date, .nextEvent, .seconds, .timezone, .worldClocks, .battery, .timer, .weather, .day, .location, .utcOffset, .weekNumber, .temperature, .sunrise, .sunset]
            }
            if value.clock.worldTimeZones == nil { value.clock.worldTimeZones = ["Asia/Tokyo", "Europe/London"] }
        case .timer:
            seed("countdown", emphasis: .bold, scale: 1.55)
            seed("status", foreground: .secondary, scale: 0.88)
            seed("presets", background: .subtle, padding: 7, radius: 12)
            seed("controls", background: .subtle, padding: 6, radius: 12)
        case .shelf:
            seed("files", background: .subtle, padding: 7, radius: 12)
            seed("footer", foreground: .secondary, scale: 0.82)
        case .media:
            seed("track", emphasis: .bold, scale: 1.12)
            seed("artist", foreground: .secondary, emphasis: .medium, scale: 0.92)
            seed("album", foreground: .secondary, scale: 0.82)
            seed("source", foreground: .secondary, scale: 0.78)
            seed("playback", foreground: .secondary, scale: 0.82)
            seed("timing", foreground: .secondary, scale: 0.78)
            seed("controls", background: .subtle, padding: 5, radius: 12)
        case .audio:
            seed("summary", emphasis: .semibold, scale: 1.02)
            seed("volumeValue", emphasis: .bold, scale: 1.45)
            seed("volume", background: .subtle, padding: 7, radius: 12)
            seed("status", foreground: .secondary, scale: 0.82)
        case .calendar:
            seed("summary", emphasis: .semibold, scale: 1.0)
            seed("nextEvent", background: .subtle, padding: 7, radius: 12, emphasis: .medium)
            seed("events", background: .none, padding: 0)
            seed("status", foreground: .secondary, scale: 0.82)
        case .clipboard:
            seed("entries", background: .none, padding: 0)
            seed("footer", foreground: .secondary, scale: 0.78)
        case .system:
            seed("cpu", background: .subtle, padding: 7, radius: 12, emphasis: .semibold)
            seed("memoryUsage", background: .subtle, padding: 7, radius: 12, emphasis: .semibold)
            seed("diskUsage", background: .subtle, padding: 7, radius: 12, emphasis: .semibold)
            seed("network", foreground: .secondary, scale: 0.84)
            seed("power", foreground: .secondary, scale: 0.84)
        case .launcher:
            seed("search", background: .subtle, padding: 5, radius: 10)
            seed("timers", background: .subtle, padding: 6, radius: 12)
        case .activities:
            seed("items", background: .subtle, padding: 7, radius: 12)
            seed("status", foreground: .secondary, scale: 0.86)
        case .notes:
            seed("editor", background: .subtle, padding: 6, radius: 12)
            seed("stats", foreground: .secondary, scale: 0.82)
        case .capture:
            seed("actions", background: .subtle, padding: 7, radius: 12, emphasis: .medium)
            seed("hint", foreground: .secondary, scale: 0.82)
        case .stopwatch:
            seed("time", emphasis: .bold, scale: 1.45)
            seed("state", foreground: .secondary, scale: 0.84)
            seed("controls", background: .subtle, padding: 6, radius: 12)
        case .pet, .developer:
            break
        }
        value.elementStyles = elements
        return value
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
enum MediaChangeAnimation: String, Codable, CaseIterable { case none, fade, slide, lift, scale, blur }
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
    var lyricChangeAnimation: MediaChangeAnimation?
    var lyricChangeAnimationDuration: Double?
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
    var resolvedLyricChangeAnimation: MediaChangeAnimation { lyricChangeAnimation ?? resolvedChangeAnimation }
    var resolvedLyricChangeAnimationDuration: Double { min(1.2, max(0.08, lyricChangeAnimationDuration ?? resolvedChangeAnimationDuration)) }
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
        guard [artworkSize, marqueeSpeed, vinylRPM, backgroundOpacity, lyricSyncOffset ?? 0, horizontalSpace ?? 180, lyricChangeAnimationDuration ?? 0.28, changeAnimationDuration ?? 0.28].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lines = min(2, max(1, lines))
        v.artworkSize = min(72, max(14, artworkSize))
        v.marqueeSpeed = min(120, max(8, marqueeSpeed))
        v.vinylRPM = min(45, max(1, vinylRPM))
        v.backgroundOpacity = min(1, max(0, backgroundOpacity))
        if lyricSyncOffset != nil { v.lyricSyncOffset = resolvedLyricSyncOffset }
        if horizontalSpace != nil { v.horizontalSpace = resolvedHorizontalSpace }
        if lyricChangeAnimation != nil { v.lyricChangeAnimation = resolvedLyricChangeAnimation }
        if lyricChangeAnimationDuration != nil { v.lyricChangeAnimationDuration = resolvedLyricChangeAnimationDuration }
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
    var readableAlbumForegroundColors: Bool?
    var albumBackgroundFrequencyEffect: Bool?
    var usesReadableAlbumForegroundColors: Bool { readableAlbumForegroundColors ?? false }
    var mediaOptions: ClosedMediaOptions?
    var artworkOptions: ClosedArtworkOptions?
    var reactiveBackground: ReactiveBackgroundOptions?
    var powerReaction: PowerReactionOptions?
    var contentPaddingX: Double { min(24, max(0, horizontalPadding ?? 8)) }
    var contentPaddingY: Double { min(12, max(0, verticalPadding ?? 2)) }
    var contentSideMargin: Double { min(48, max(0, sideMargin ?? 4)) }
    var contentOuterMargin: Double { min(48, max(17, outerMargin ?? 17)) }
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
        guard (horizontalPadding ?? 8).isFinite, (verticalPadding ?? 2).isFinite, (sideMargin ?? 4).isFinite, (outerMargin ?? 17).isFinite else { throw CocoaError(.fileReadCorruptFile) }
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