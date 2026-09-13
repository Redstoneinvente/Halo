from pathlib import Path
import re

ROOT = Path('.')

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Missing exact marker: {label}')
    return text.replace(old, new, 1)

def sub_once(text, pattern, replacement, label, flags=re.S):
    updated, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'Expected one replacement for {label}, got {count}')
    return updated

# -----------------------------------------------------------------------------
# Clock model
# -----------------------------------------------------------------------------
models_path = ROOT / 'Halo/Core/WidgetModels.swift'
models = models_path.read_text()

old_clock_elements = '''        case .clock:
            return [
                .init("time", "Time", "The primary live clock value."),
                .init("date", "Date", "Formatted calendar date."),
                .init("timezone", "Time zone", "Current time-zone identifier.", defaultVisible: false),
                .init("dayProgress", "Day progress", "A live progress bar for the current day.", defaultVisible: false)
            ]
'''
new_clock_elements = '''        case .clock:
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
'''
models = replace_once(models, old_clock_elements, new_clock_elements, 'clock element descriptors')

clock_model = r'''enum ClockVisualStyle: String, Codable, CaseIterable, Identifiable {
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
'''

models = sub_once(
    models,
    r'struct ClockOptions: Codable, Equatable \{.*?\n\}\n\nenum WidgetContentAlignment',
    clock_model + '\n\nenum WidgetContentAlignment',
    'ClockOptions model'
)

old_validation_guard = '''        guard [fontSize, backgroundOpacity, padding, cornerRadius, width, minimumHeight].allSatisfy(\\.isFinite),
              clock.timeZone.isEmpty || TimeZone(identifier: clock.timeZone) != nil else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
'''
new_validation_guard = '''        guard [fontSize, backgroundOpacity, padding, cornerRadius, width, minimumHeight].allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.clock = try clock.validated()
'''
models = replace_once(models, old_validation_guard, new_validation_guard, 'WidgetStyle clock validation')

old_clock_seed = '''        case .clock:
            seed("time", emphasis: .semibold, scale: 1.28)
            seed("date", foreground: .secondary, scale: 0.88)
            seed("timezone", foreground: .secondary, scale: 0.78)
'''
new_clock_seed = '''        case .clock:
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
'''
models = replace_once(models, old_clock_seed, new_clock_seed, 'visual workspace clock seed')
models_path.write_text(models)

# -----------------------------------------------------------------------------
# Clock renderer
# -----------------------------------------------------------------------------
views_path = ROOT / 'Halo/Views/WidgetViews.swift'
views = views_path.read_text()
views = replace_once(views, 'import AppKit\n', 'import AppKit\nimport EventKit\n', 'EventKit import')

old_env_decl = '''private struct OpenNotchAvailableWidthEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchBlockVerticalAlignmentEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchBlockVerticalAlignment = .top }
'''
new_env_decl = '''private struct OpenNotchAvailableWidthEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchGridColumnSpanEnvironmentKey: EnvironmentKey { static let defaultValue: Int? = nil }
private struct OpenNotchGridRowSpanEnvironmentKey: EnvironmentKey { static let defaultValue: Int? = nil }
private struct OpenNotchBlockVerticalAlignmentEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchBlockVerticalAlignment = .top }
'''
views = replace_once(views, old_env_decl, new_env_decl, 'grid span environment keys')

old_env_access = '''    var openNotchAvailableHeight: CGFloat? {
        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }
        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }
    }
    var openNotchBlockVerticalAlignment: OpenNotchBlockVerticalAlignment {
'''
new_env_access = '''    var openNotchAvailableHeight: CGFloat? {
        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }
        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }
    }
    var openNotchGridColumnSpan: Int? {
        get { self[OpenNotchGridColumnSpanEnvironmentKey.self] }
        set { self[OpenNotchGridColumnSpanEnvironmentKey.self] = newValue }
    }
    var openNotchGridRowSpan: Int? {
        get { self[OpenNotchGridRowSpanEnvironmentKey.self] }
        set { self[OpenNotchGridRowSpanEnvironmentKey.self] = newValue }
    }
    var openNotchBlockVerticalAlignment: OpenNotchBlockVerticalAlignment {
'''
views = replace_once(views, old_env_access, new_env_access, 'grid span environment values')

clock_renderer = r'''private enum ClockLayoutFamily: String, Equatable {
    case micro
    case horizontalCompact
    case verticalCompact
    case standard
    case wide
    case tall
    case large
    case hero

    static func exact(columns: Int, rows: Int) -> ClockLayoutFamily {
        let columns = max(1, columns)
        let rows = max(1, rows)
        if columns == 1 && rows == 1 { return .micro }
        if rows == 1 { return columns <= 3 ? .horizontalCompact : .wide }
        if columns == 1 { return rows <= 2 ? .verticalCompact : .tall }
        if columns >= 7 && rows >= 4 { return .hero }
        if (columns >= 5 && rows >= 3) || columns * rows >= 16 { return .large }
        if columns >= 4 && rows == 2 { return .wide }
        if rows >= 3 && columns <= 2 { return .tall }
        if columns >= 3 && rows >= 3 { return .large }
        return .standard
    }

    static func fallback(width: CGFloat, height: CGFloat, previous: ClockLayoutFamily?) -> ClockLayoutFamily {
        let width = max(1, width)
        let height = max(1, height)
        let aspect = width / height
        if previous == .micro, width < 158, height < 158 { return .micro }
        if previous == .horizontalCompact, aspect > 1.40, height < 188 { return .horizontalCompact }
        if previous == .wide, aspect > 1.48, width > 285 { return .wide }
        if previous == .verticalCompact, aspect < 0.82, width < 214, height < 280 { return .verticalCompact }
        if previous == .tall, aspect < 0.94, height > 220 { return .tall }
        if previous == .hero, width > 470, height > 270 { return .hero }
        if previous == .large, width > 320, height > 205 { return .large }

        if width < 138 && height < 138 { return .micro }
        if width >= 520 && height >= 310 { return .hero }
        if aspect >= 2.25 && height < 190 { return width >= 345 ? .wide : .horizontalCompact }
        if aspect <= 0.70 && width < 210 { return height >= 280 ? .tall : .verticalCompact }
        if width >= 355 && height >= 225 { return .large }
        if aspect >= 1.58 { return .wide }
        if aspect <= 0.84 { return .tall }
        return .standard
    }

    var complicationCapacity: Int {
        switch self {
        case .micro: return 0
        case .horizontalCompact, .verticalCompact: return 1
        case .standard: return 2
        case .wide, .tall: return 3
        case .large: return 4
        case .hero: return 6
        }
    }
}

private extension ClockFontWidth {
    var swiftUI: Font.Width {
        switch self {
        case .compressed: return .compressed
        case .condensed: return .condensed
        case .standard: return .standard
        case .expanded: return .expanded
        }
    }
}

private struct ClockTimeParts {
    let hour: String
    let minute: String
    let second: String
    let ampm: String
}

private struct AdaptiveAnalogClockFace: View {
    let date: Date
    let style: WidgetStyle
    let clock: ClockOptions
    let diameter: CGFloat
    let showSeconds: Bool

    private var options: ClockAnalogOptions { clock.resolvedAnalog }
    private var timeZone: TimeZone { TimeZone(identifier: clock.timeZone) ?? .current }

    var body: some View {
        let size = max(44, diameter)
        ZStack {
            Circle()
                .fill(options.faceColor.color.opacity(options.faceOpacity))
                .overlay(Circle().stroke((clock.secondaryColor ?? style.textColor).color.opacity(0.13), lineWidth: 1))
            Canvas { context, canvas in
                let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let radius = min(canvas.width, canvas.height) / 2
                if options.minuteTicks {
                    for tick in 0..<60 {
                        let major = tick.isMultiple(of: 5)
                        let outer = radius * 0.88
                        let inner = radius * (major ? 0.76 : 0.82)
                        let angle = Double(tick) / 60 * .pi * 2 - .pi / 2
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(path, with: .color(options.tickColor.color.opacity(major ? 0.66 : 0.28)), lineWidth: major ? options.tickThickness * 1.35 : options.tickThickness * 0.65)
                    }
                } else if options.hourTicks {
                    for tick in 0..<12 {
                        let outer = radius * 0.88
                        let inner = radius * 0.76
                        let angle = Double(tick) / 12 * .pi * 2 - .pi / 2
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(path, with: .color(options.tickColor.color.opacity(0.62)), lineWidth: options.tickThickness)
                    }
                }

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
                let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
                let minute = Double(components.minute ?? 0) + Double(components.second ?? 0) / 60
                let smoothSecond = Double(components.second ?? 0) + (options.smoothSecondHand ? Double(components.nanosecond ?? 0) / 1_000_000_000 : 0)

                func hand(angleDegrees: Double, length: Double, width: Double, color: Color) {
                    let angle = angleDegrees * .pi / 180 - .pi / 2
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + cos(angle) * radius * length, y: center.y + sin(angle) * radius * length))
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
                if options.showHourHand { hand(angleDegrees: hour / 12 * 360, length: options.hourHandLength, width: options.handThickness * 1.25, color: options.hourHandColor.color) }
                if options.showMinuteHand { hand(angleDegrees: minute / 60 * 360, length: options.minuteHandLength, width: options.handThickness, color: options.minuteHandColor.color) }
                if showSeconds && options.showSecondHand { hand(angleDegrees: smoothSecond / 60 * 360, length: options.secondHandLength, width: max(0.6, options.handThickness * 0.48), color: options.secondHandColor.color) }
            }
            if options.numerals != .none && size >= 82 {
                GeometryReader { proxy in
                    let radius = min(proxy.size.width, proxy.size.height) * 0.365
                    let roman = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
                    ForEach(0..<12, id: \.self) { index in
                        let angle = Double(index) / 12 * .pi * 2 - .pi / 2
                        let label = options.numerals == .roman ? roman[index] : String(index == 0 ? 12 : index)
                        Text(label)
                            .font(.system(size: max(7, size * 0.075), weight: .medium, design: .rounded))
                            .foregroundStyle((clock.secondaryColor ?? style.textColor).color.opacity(0.72))
                            .position(x: proxy.size.width / 2 + cos(angle) * radius,
                                      y: proxy.size.height / 2 + sin(angle) * radius)
                    }
                }
            }
            if options.centerCap {
                Circle().fill(options.secondHandColor.color).frame(width: max(4, size * 0.045), height: max(4, size * 0.045))
                    .overlay(Circle().stroke(Color.black.opacity(0.28), lineWidth: 0.5))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Analog clock")
    }
}

private struct ClockFlipDigit: View {
    let digit: Character
    let height: CGFloat
    let color: Color
    let accent: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(5, height * 0.10), style: .continuous)
                .fill(Color.black.opacity(0.32))
                .overlay(RoundedRectangle(cornerRadius: max(5, height * 0.10)).stroke(Color.white.opacity(0.08), lineWidth: 1))
            Rectangle().fill(Color.black.opacity(0.35)).frame(height: 1)
            Text(String(digit))
                .font(.system(size: height * 0.62, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .shadow(color: accent.opacity(0.10), radius: 8)
        }
        .frame(width: height * 0.54, height: height)
        .animation(.snappy(duration: 0.24), value: digit)
    }
}

private struct ClockDotMatrixBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 8
            var x: CGFloat = 4
            while x < size.width {
                var y: CGFloat = 4
                while y < size.height {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)), with: .color(.white.opacity(0.055)))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

struct WidgetClock: View {
    let style: WidgetStyle
    var compact = false
    var workspace: WorkspaceStore? = nil
    var store: AppStore? = nil
    var weatherSummary: String? = nil
    var temperatureText: String? = nil
    var sunrise: Date? = nil
    var sunset: Date? = nil

    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumns
    @Environment(\.openNotchGridRowSpan) private var gridRows
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var clockNamespace
    @State private var fallbackFamily: ClockLayoutFamily = .standard

    private var clock: ClockOptions { style.clock }
    private var width: CGFloat { max(72, availableWidth ?? (compact ? 220 : 320)) }
    private var height: CGFloat { max(44, availableHeight ?? (compact ? 58 : 180)) }
    private var sizeOverride: ClockSizeOverride? { clock.sizeOverride(columns: gridColumns, rows: gridRows) }
    private var visualStyle: ClockVisualStyle { sizeOverride?.style ?? clock.resolvedVisualStyle }
    private var family: ClockLayoutFamily {
        if compact { return .horizontalCompact }
        if let gridColumns, let gridRows { return .exact(columns: gridColumns, rows: gridRows) }
        return fallbackFamily
    }
    private var timeZone: TimeZone { TimeZone(identifier: clock.timeZone) ?? .current }
    private var primaryColor: Color { (clock.primaryColor ?? style.textColor).color }
    private var secondaryColor: Color { (clock.secondaryColor ?? style.textColor).color.opacity(0.62) }
    private var separatorColor: Color { (clock.separatorColor ?? style.accentColor).color }
    private var accentColor: Color { style.accentColor.color }
    private var geometrySignature: String { "\(Int(width.rounded()))x\(Int(height.rounded()))" }

    var body: some View {
        Group {
            if visualStyle == .analog && clock.showSeconds && clock.resolvedAnalog.smoothSecondHand && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in clockBody(date: context.date) }
            } else {
                TimelineView(.periodic(from: .now, by: clock.showSeconds || clock.resolvedBlinkingSeparator ? 1 : 15)) { context in clockBody(date: context.date) }
            }
        }
        .onAppear { updateFallbackFamily() }
        .onChange(of: geometrySignature) { _ in updateFallbackFamily() }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: family)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: visualStyle)
    }

    private func updateFallbackFamily() {
        guard gridColumns == nil || gridRows == nil else { return }
        fallbackFamily = .fallback(width: width, height: height, previous: fallbackFamily)
    }

    @ViewBuilder private func clockBody(date: Date) -> some View {
        let complications = visibleComplications(date: date)
        switch family {
        case .micro:
            primaryClock(date: date, family: .micro)
                .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .horizontalCompact:
            if compact {
                primaryClock(date: date, family: .horizontalCompact)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.resolvedContent.alignment.alignment)
            } else {
                HStack(spacing: max(8, style.resolvedContent.spacing * 0.65)) {
                    primaryClock(date: date, family: .horizontalCompact)
                        .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                    if let complication = complications.first {
                        Spacer(minLength: 6)
                        compactComplication(complication, date: date, horizontal: true)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .verticalCompact:
            VStack(spacing: max(6, style.resolvedContent.spacing * 0.60)) {
                primaryClock(date: date, family: .verticalCompact)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                if let complication = complications.first {
                    compactComplication(complication, date: date, horizontal: false)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .standard:
            VStack(spacing: max(6, style.resolvedContent.spacing * 0.72)) {
                Spacer(minLength: 0)
                primaryClock(date: date, family: .standard)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                if let dateComp = complications.first(where: { $0 == .date || $0 == .day }) {
                    compactComplication(dateComp, date: date, horizontal: false)
                        .matchedGeometryEffect(id: "clock-date", in: clockNamespace)
                } else if let complication = complications.first {
                    compactComplication(complication, date: date, horizontal: false)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .wide:
            HStack(alignment: .center, spacing: max(14, style.resolvedContent.spacing)) {
                primaryClock(date: date, family: .wide)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !complications.isEmpty {
                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(Array(complications.prefix(3)), id: \.self) { complication in
                            compactComplication(complication, date: date, horizontal: true)
                        }
                    }
                    .frame(maxWidth: min(230, width * 0.40), alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .tall:
            VStack(spacing: max(10, style.resolvedContent.spacing)) {
                primaryClock(date: date, family: .tall)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                if !complications.isEmpty {
                    Divider().opacity(0.16)
                    VStack(spacing: 7) {
                        ForEach(Array(complications.prefix(3)), id: \.self) { complication in
                            compactComplication(complication, date: date, horizontal: false)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .large:
            VStack(spacing: max(10, style.resolvedContent.spacing * 0.9)) {
                largeHeader(date: date, complications: complications)
                Spacer(minLength: 0)
                primaryClock(date: date, family: .large)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                Spacer(minLength: 0)
                complicationRow(complications, date: date, limit: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .hero:
            heroClock(date: date, complications: complications)
        }
    }

    @ViewBuilder private func primaryClock(date: Date, family: ClockLayoutFamily) -> some View {
        let parts = timeParts(date)
        switch visualStyle {
        case .digital:
            if family == .verticalCompact || family == .tall {
                stackedTime(parts: parts, family: family, editorial: false)
            } else {
                digitalTime(parts: parts, date: date, family: family)
            }
        case .minimal:
            digitalTime(parts: parts, date: date, family: family, minimal: true)
        case .analog:
            let diameter = analogDiameter(for: family)
            AdaptiveAnalogClockFace(date: date, style: style, clock: clock, diameter: diameter, showSeconds: shouldShowSeconds(in: family))
        case .flip:
            flipTime(parts: parts, family: family)
        case .editorial:
            editorialTime(parts: parts, date: date, family: family)
        case .stacked:
            stackedTime(parts: parts, family: family, editorial: false)
        case .split:
            splitTime(parts: parts, family: family)
        case .terminal:
            terminalTime(parts: parts, family: family)
        case .lcd:
            lcdTime(parts: parts, date: date, family: family)
        case .dotMatrix:
            dotMatrixTime(parts: parts, date: date, family: family)
        case .outline:
            outlineTime(parts: parts, date: date, family: family)
        case .oversizedTypography:
            oversizedTime(parts: parts, date: date, family: family)
        }
    }

    private func timeParts(_ date: Date) -> ClockTimeParts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour24 = components.hour ?? 0
        let displayHour = clock.twentyFourHour ? hour24 : (hour24 % 12 == 0 ? 12 : hour24 % 12)
        let hour = clock.resolvedLeadingZero ? String(format: "%02d", displayHour) : String(displayHour)
        let minute = String(format: "%02d", components.minute ?? 0)
        let second = String(format: "%02d", components.second ?? 0)
        return ClockTimeParts(hour: hour, minute: minute, second: second, ampm: hour24 < 12 ? "AM" : "PM")
    }

    private func shouldShowSeconds(in family: ClockLayoutFamily) -> Bool {
        guard clock.showSeconds else { return false }
        switch family {
        case .micro: return false
        case .horizontalCompact: return width >= 300
        case .verticalCompact: return height >= 220
        default: return true
        }
    }

    private func timeFontSize(for family: ClockLayoutFamily) -> CGFloat {
        if !clock.usesAutomaticTypography {
            let multiplier: CGFloat
            switch family { case .micro: multiplier = 1.45; case .horizontalCompact, .verticalCompact: multiplier = 1.55; case .standard: multiplier = 2; case .wide, .tall: multiplier = 2.25; case .large: multiplier = 2.65; case .hero: multiplier = 3.1 }
            return CGFloat(style.fontSize * clock.resolvedTimeScale) * multiplier
        }
        let raw: CGFloat
        switch family {
        case .micro: raw = min(height * 0.40, width * 0.235)
        case .horizontalCompact: raw = min(height * 0.46, width * 0.17)
        case .verticalCompact: raw = min(height * 0.22, width * 0.42)
        case .standard: raw = min(height * 0.34, width * 0.18)
        case .wide: raw = min(height * 0.46, width * 0.14)
        case .tall: raw = min(height * 0.21, width * 0.42)
        case .large: raw = min(height * 0.31, width * 0.15)
        case .hero: raw = min(height * 0.28, width * 0.105)
        }
        return max(18, raw * CGFloat(clock.resolvedTimeScale))
    }

    private func dateFontSize(for family: ClockLayoutFamily) -> CGFloat {
        let time = timeFontSize(for: family)
        let base = time / CGFloat(clock.resolvedTimeDateRatio) * CGFloat(clock.resolvedDateScale)
        return min(24, max(9, base))
    }

    private func secondaryFontSize(for family: ClockLayoutFamily) -> CGFloat {
        min(18, max(8, dateFontSize(for: family) * 0.88 * CGFloat(clock.resolvedSecondaryScale)))
    }

    private func clockFont(size: CGFloat, weight: Font.Weight? = nil, forceDesign: Font.Design? = nil) -> Font {
        let resolvedWeight = weight ?? style.weight.swiftUIFontWeight
        let font: Font
        if style.fontFamily == .custom {
            font = .custom(style.customFont, size: size).weight(resolvedWeight)
        } else {
            let design: Font.Design
            if let forceDesign { design = forceDesign }
            else {
                switch style.fontFamily { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default; case .custom: design = .default }
            }
            font = .system(size: size, weight: resolvedWeight, design: design)
        }
        return font.width(clock.resolvedFontWidth.swiftUI)
    }

    @ViewBuilder private func digit(_ text: String, size: CGFloat, emphasis: Double = 1, color: Color? = nil, weight: Font.Weight? = nil, forceDesign: Font.Design? = nil) -> some View {
        let view = Text(text)
            .font(clockFont(size: size * CGFloat(emphasis), weight: weight, forceDesign: forceDesign))
            .tracking(clock.resolvedTracking)
            .foregroundStyle(color ?? primaryColor)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
        if clock.usesMonospacedDigits { view.monospacedDigit() } else { view }
    }

    @ViewBuilder private func digitalTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily, minimal: Bool = false) -> some View {
        let size = timeFontSize(for: family)
        let showSeconds = !minimal && shouldShowSeconds(in: family)
        let showAMPM = !clock.twentyFourHour && clock.resolvedShowAMPM && family != .micro && !minimal
        let separatorOpacity = clock.resolvedBlinkingSeparator && !reduceMotion && Int(date.timeIntervalSince1970) % 2 != 0 ? 0.18 : 1.0
        HStack(alignment: .firstTextBaseline, spacing: max(0, clock.resolvedDigitSpacing)) {
            digit(parts.hour, size: size, emphasis: clock.resolvedHourEmphasis)
            Text(clock.resolvedSeparator.glyph)
                .font(clockFont(size: size * 0.86, weight: .regular))
                .foregroundStyle(separatorColor)
                .opacity(separatorOpacity)
            digit(parts.minute, size: size, emphasis: clock.resolvedMinuteEmphasis)
            if showSeconds {
                Text(clock.resolvedSeparator.glyph)
                    .font(clockFont(size: size * 0.54, weight: .regular))
                    .foregroundStyle(separatorColor.opacity(0.78))
                    .opacity(separatorOpacity)
                digit(parts.second, size: size, emphasis: clock.resolvedSecondsEmphasis, color: secondaryColor)
            }
            if showAMPM {
                Text(parts.ampm)
                    .font(clockFont(size: max(8, size * 0.23), weight: .semibold))
                    .foregroundStyle(secondaryColor)
                    .padding(.leading, max(1, size * 0.02))
            }
        }
        .shadow(color: accentColor.opacity(clock.resolvedTextGlow * 0.32), radius: clock.resolvedTextGlow * 16)
        .shadow(color: .black.opacity(clock.resolvedTextShadow * 0.42), radius: clock.resolvedTextShadow * 10, y: clock.resolvedTextShadow * 2)
    }

    @ViewBuilder private func stackedTime(parts: ClockTimeParts, family: ClockLayoutFamily, editorial: Bool) -> some View {
        let size = max(24, min(width * 0.48, height * (family == .verticalCompact ? 0.26 : 0.22))) * CGFloat(clock.resolvedTimeScale)
        VStack(spacing: max(0, size * 0.02)) {
            digit(parts.hour, size: size, emphasis: clock.resolvedHourEmphasis, forceDesign: editorial ? .serif : nil)
            Rectangle().fill(separatorColor.opacity(0.42)).frame(width: min(width * 0.58, size * 1.3), height: 1)
            digit(parts.minute, size: size, emphasis: clock.resolvedMinuteEmphasis, forceDesign: editorial ? .serif : nil)
            if shouldShowSeconds(in: family) {
                digit(parts.second, size: size * 0.42, emphasis: clock.resolvedSecondsEmphasis, color: secondaryColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func splitTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family)
        let vertical = family == .verticalCompact || family == .tall
        if vertical {
            VStack(spacing: 7) { splitCell(parts.hour, size: size); splitCell(parts.minute, size: size) }
        } else {
            HStack(spacing: 8) { splitCell(parts.hour, size: size); splitCell(parts.minute, size: size) }
        }
    }

    private func splitCell(_ text: String, size: CGFloat) -> some View {
        digit(text, size: size * 0.86, weight: .semibold)
            .padding(.horizontal, max(8, size * 0.18)).padding(.vertical, max(6, size * 0.10))
            .background(primaryColor.opacity(0.055), in: RoundedRectangle(cornerRadius: max(8, size * 0.15), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: max(8, size * 0.15)).stroke(primaryColor.opacity(0.10), lineWidth: 1))
    }

    @ViewBuilder private func flipTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> some View {
        let vertical = family == .verticalCompact || family == .tall
        let cellHeight = max(30, min(vertical ? width * 0.34 : height * 0.56, vertical ? height * 0.22 : width * 0.11))
        let seconds = shouldShowSeconds(in: family)
        if vertical {
            VStack(spacing: 7) {
                flipPair(parts.hour, height: cellHeight)
                flipPair(parts.minute, height: cellHeight)
                if seconds { flipPair(parts.second, height: cellHeight * 0.72) }
            }
        } else {
            HStack(spacing: max(5, cellHeight * 0.10)) {
                flipPair(parts.hour, height: cellHeight)
                Text(clock.resolvedSeparator.glyph).font(.system(size: cellHeight * 0.48, weight: .medium, design: .rounded)).foregroundStyle(separatorColor)
                flipPair(parts.minute, height: cellHeight)
                if seconds {
                    Text(clock.resolvedSeparator.glyph).font(.system(size: cellHeight * 0.34, weight: .regular)).foregroundStyle(separatorColor.opacity(0.75))
                    flipPair(parts.second, height: cellHeight * 0.72)
                }
            }
        }
    }

    private func flipPair(_ text: String, height: CGFloat) -> some View {
        HStack(spacing: max(2, height * 0.035)) {
            ForEach(Array(text).indices, id: \.self) { index in
                ClockFlipDigit(digit: Array(text)[index], height: height, color: primaryColor, accent: accentColor)
            }
        }
    }

    @ViewBuilder private func editorialTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family)
        VStack(alignment: family == .wide ? .leading : .center, spacing: max(4, size * 0.08)) {
            Text(adaptiveDate(date, detail: family == .hero || family == .large ? .full : .short))
                .font(clockFont(size: max(9, dateFontSize(for: family) * 0.86), weight: .semibold, forceDesign: .serif))
                .tracking(max(1.5, clock.resolvedTracking + 1.5))
                .foregroundStyle(secondaryColor)
                .textCase(.uppercase)
                .lineLimit(1)
            Rectangle().fill(primaryColor.opacity(0.18)).frame(maxWidth: min(width * 0.72, 420), maxHeight: 1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                digit(parts.hour, size: size * 1.02, emphasis: clock.resolvedHourEmphasis, forceDesign: .serif)
                Text(clock.resolvedSeparator.glyph).font(clockFont(size: size * 0.72, weight: .light, forceDesign: .serif)).foregroundStyle(separatorColor)
                digit(parts.minute, size: size * 1.02, emphasis: clock.resolvedMinuteEmphasis, forceDesign: .serif)
            }
        }
    }

    @ViewBuilder private func terminalTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.86
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("›").font(.system(size: size * 0.68, weight: .bold, design: .monospaced)).foregroundStyle(accentColor)
            Text(rawTime(parts: parts, family: family))
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .foregroundStyle(primaryColor)
                .tracking(max(0, clock.resolvedTracking))
                .monospacedDigit()
                .contentTransition(.numericText())
            if family == .wide || family == .large || family == .hero {
                Text(timeZone.abbreviation() ?? "LOCAL").font(.system(size: max(8, size * 0.23), weight: .medium, design: .monospaced)).foregroundStyle(secondaryColor)
            }
        }
    }

    @ViewBuilder private func lcdTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.88
        Text(rawTime(parts: parts, family: family))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(accentColor.opacity(0.95))
            .monospacedDigit()
            .tracking(max(1, clock.resolvedTracking))
            .padding(.horizontal, max(10, size * 0.18)).padding(.vertical, max(7, size * 0.10))
            .background(accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: max(8, size * 0.11), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: max(8, size * 0.11)).stroke(accentColor.opacity(0.16), lineWidth: 1))
            .shadow(color: accentColor.opacity(0.10), radius: 10)
            .contentTransition(.numericText())
    }

    @ViewBuilder private func dotMatrixTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.82
        Text(rawTime(parts: parts, family: family))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(primaryColor)
            .monospacedDigit()
            .tracking(max(2, clock.resolvedTracking + 2))
            .padding(.horizontal, max(10, size * 0.16)).padding(.vertical, max(7, size * 0.10))
            .background { ClockDotMatrixBackdrop().clipShape(RoundedRectangle(cornerRadius: 10)) }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primaryColor.opacity(0.10), lineWidth: 1))
            .contentTransition(.numericText())
    }

    @ViewBuilder private func outlineTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.90
        Text(rawTime(parts: parts, family: family))
            .font(clockFont(size: size, weight: .medium))
            .foregroundStyle(primaryColor.opacity(0.90))
            .monospacedDigit()
            .tracking(clock.resolvedTracking)
            .padding(.horizontal, max(12, size * 0.22)).padding(.vertical, max(7, size * 0.10))
            .overlay(RoundedRectangle(cornerRadius: max(10, size * 0.15), style: .continuous).stroke(primaryColor.opacity(0.28), lineWidth: 1.2))
            .contentTransition(.numericText())
    }

    @ViewBuilder private func oversizedTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = min(height * 0.58, width * (family == .hero ? 0.13 : family == .wide ? 0.16 : 0.23)) * CGFloat(clock.resolvedTimeScale)
        Text(rawTime(parts: parts, family: family))
            .font(clockFont(size: max(24, size), weight: .bold))
            .foregroundStyle(primaryColor)
            .tracking(min(-1, clock.resolvedTracking - 1))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .contentTransition(.numericText())
    }

    private func rawTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> String {
        var result = parts.hour + clock.resolvedSeparator.glyph + parts.minute
        if shouldShowSeconds(in: family) { result += clock.resolvedSeparator.glyph + parts.second }
        if !clock.twentyFourHour && clock.resolvedShowAMPM && family != .micro { result += " " + parts.ampm }
        return result
    }

    private func analogDiameter(for family: ClockLayoutFamily) -> CGFloat {
        let multiplier: CGFloat
        switch family { case .micro: multiplier = 0.82; case .horizontalCompact: multiplier = 0.82; case .verticalCompact: multiplier = 0.86; case .standard: multiplier = 0.74; case .wide: multiplier = 0.80; case .tall: multiplier = 0.76; case .large: multiplier = 0.66; case .hero: multiplier = 0.62 }
        return max(44, min(width, height) * multiplier)
    }

    private enum DateDetail { case micro, short, medium, full }

    private func adaptiveDate(_ date: Date, detail: DateDetail) -> String {
        guard clock.showDate else { return "" }
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let advanced = clock.showWeekday != nil || clock.showDay != nil || clock.showMonth != nil || clock.showYear != nil || clock.dateOrder != nil || clock.monthStyle != nil || clock.weekdayStyle != nil
        if !advanced {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.timeZone = timeZone
            switch detail {
            case .micro: formatter.dateFormat = "EEE d"
            case .short: formatter.dateFormat = "EEE, MMM d"
            case .medium:
                switch style.resolvedContent.clockDateStyle {
                case .weekdayMonthDay: formatter.dateFormat = "EEE, MMM d"
                case .monthDay: formatter.dateFormat = "MMM d"
                case .full: formatter.dateFormat = "EEEE, MMMM d"
                case .numeric: formatter.dateStyle = .short; formatter.timeStyle = .none
                }
            case .full:
                formatter.dateFormat = style.resolvedContent.clockDateStyle == .numeric ? "yyyy-MM-dd" : "EEEE, MMMM d"
            }
            return applyDateCase(formatter.string(from: date))
        }

        let weekdayFormatter = DateFormatter(); weekdayFormatter.locale = .autoupdatingCurrent; weekdayFormatter.timeZone = timeZone
        let monthFormatter = DateFormatter(); monthFormatter.locale = .autoupdatingCurrent; monthFormatter.timeZone = timeZone
        let forceShort = detail == .micro || detail == .short
        weekdayFormatter.dateFormat = forceShort || clock.resolvedWeekdayStyle == .short ? "EEE" : "EEEE"
        switch clock.resolvedMonthStyle {
        case .short: monthFormatter.dateFormat = "MMM"
        case .full: monthFormatter.dateFormat = forceShort ? "MMM" : "MMMM"
        case .numeric: monthFormatter.dateFormat = "MM"
        }
        let weekday = weekdayFormatter.string(from: date)
        let month = monthFormatter.string(from: date)
        let day = String(calendar.component(.day, from: date))
        let year = String(calendar.component(.year, from: date))
        var pieces: [String] = []
        let addWeekday = clock.resolvedShowWeekday
        let addDay = clock.resolvedShowDay
        let addMonth = clock.resolvedShowMonth
        let addYear = clock.resolvedShowYear && detail != .micro && detail != .short
        switch clock.resolvedDateOrder {
        case .weekdayMonthDay:
            if addWeekday { pieces.append(weekday) }; if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addYear { pieces.append(year) }
        case .monthDayYear:
            if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addYear { pieces.append(year) }; if addWeekday && detail == .full { pieces.append(weekday) }
        case .dayMonthYear:
            if addDay { pieces.append(day) }; if addMonth { pieces.append(month) }; if addYear { pieces.append(year) }; if addWeekday && detail == .full { pieces.append(weekday) }
        case .yearMonthDay:
            if addYear { pieces.append(year) }; if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addWeekday && detail == .full { pieces.append(weekday) }
        case .monthDayWeekday:
            if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addWeekday { pieces.append(weekday) }; if addYear { pieces.append(year) }
        }
        if detail == .micro { pieces = Array(pieces.prefix(2)) }
        return applyDateCase(pieces.joined(separator: detail == .full ? " · " : " "))
    }

    private func applyDateCase(_ value: String) -> String {
        switch clock.resolvedDateTextCase { case .natural: return value; case .uppercase: return value.uppercased(); case .lowercase: return value.lowercased() }
    }

    private func enabledComplications() -> [ClockComplication] {
        if let override = sizeOverride?.complications { return override }
        let enabled = Set(clock.resolvedEnabledComplications)
        return clock.resolvedComplicationPriority.filter { enabled.contains($0) }
    }

    private func visibleComplications(date: Date) -> [ClockComplication] {
        let source = enabledComplications().filter { complicationAvailable($0, date: date) }
        return Array(source.prefix(family.complicationCapacity))
    }

    private func complicationAvailable(_ complication: ClockComplication, date: Date) -> Bool {
        switch complication {
        case .date, .day: return clock.showDate
        case .seconds: return clock.showSeconds
        case .timezone, .location, .utcOffset, .weekNumber: return true
        case .nextEvent: return nextEvent(at: date) != nil
        case .timer: return store?.deadline != nil || (store?.pausedSeconds ?? 0) > 0
        case .weather: return weatherSummary?.isEmpty == false
        case .temperature: return temperatureText?.isEmpty == false
        case .battery: return workspace?.system.battery != nil
        case .sunrise: return sunrise != nil
        case .sunset: return sunset != nil
        case .worldClocks: return !clock.resolvedWorldTimeZones.isEmpty
        }
    }

    private func nextEvent(at date: Date) -> EKEvent? {
        workspace?.calendar.upcomingEvents.first { $0.endDate > date }
    }

    private func complicationValue(_ complication: ClockComplication, date: Date) -> String {
        switch complication {
        case .date: return adaptiveDate(date, detail: family == .hero || family == .large ? .full : .short)
        case .day:
            let formatter = DateFormatter(); formatter.locale = .autoupdatingCurrent; formatter.timeZone = timeZone; formatter.dateFormat = family == .micro ? "EEE" : "EEEE"; return applyDateCase(formatter.string(from: date))
        case .seconds:
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone; return String(format: "%02d", calendar.component(.second, from: date))
        case .timezone: return timeZone.abbreviation(for: date) ?? timeZone.identifier
        case .location:
            if let label = clock.locationLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty { return label }
            return timeZone.identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? timeZone.identifier
        case .utcOffset:
            let seconds = timeZone.secondsFromGMT(for: date); let sign = seconds < 0 ? "−" : "+"; let value = abs(seconds); return String(format: "UTC%@%02d:%02d", sign, value / 3600, value / 60 % 60)
        case .weekNumber:
            var calendar = Calendar.autoupdatingCurrent; calendar.timeZone = timeZone; return "Week \(calendar.component(.weekOfYear, from: date))"
        case .nextEvent:
            guard let event = nextEvent(at: date) else { return "" }
            let formatter = DateFormatter(); formatter.locale = .autoupdatingCurrent; formatter.timeZone = timeZone; formatter.timeStyle = .short
            return "\(event.title ?? "Event") · \(formatter.string(from: event.startDate))"
        case .timer:
            if let deadline = store?.deadline { return formatDuration(max(0, deadline.timeIntervalSince(date))) }
            if let paused = store?.pausedSeconds, paused > 0 { return "Paused · \(formatDuration(paused))" }
            return ""
        case .weather: return weatherSummary ?? ""
        case .temperature: return temperatureText ?? ""
        case .battery:
            guard let battery = workspace?.system.battery else { return "" }
            return workspace?.system.charging == true ? "\(battery)% · Charging" : "\(battery)%"
        case .sunrise: return solarTime(sunrise)
        case .sunset: return solarTime(sunset)
        case .worldClocks:
            return clock.resolvedWorldTimeZones.prefix(3).compactMap { identifier in
                guard let zone = TimeZone(identifier: identifier) else { return nil }
                let formatter = DateFormatter(); formatter.timeZone = zone; formatter.dateFormat = clock.twentyFourHour ? "HH:mm" : "h:mm a"
                let label = identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? identifier
                return "\(label) \(formatter.string(from: date))"
            }.joined(separator: "  ·  ")
        }
    }

    private func solarTime(_ value: Date?) -> String {
        guard let value else { return "" }
        let formatter = DateFormatter(); formatter.locale = .autoupdatingCurrent; formatter.timeZone = timeZone; formatter.timeStyle = .short
        return formatter.string(from: value)
    }

    private func complicationLabel(_ complication: ClockComplication) -> String {
        switch complication {
        case .nextEvent: return "NEXT"
        case .worldClocks: return "WORLD CLOCKS"
        case .utcOffset: return "OFFSET"
        case .weekNumber: return "WEEK"
        default: return complication.title.uppercased()
        }
    }

    @ViewBuilder private func compactComplication(_ complication: ClockComplication, date: Date, horizontal: Bool) -> some View {
        let value = complicationValue(complication, date: date)
        if !value.isEmpty {
            VStack(alignment: horizontal ? .trailing : .center, spacing: 2) {
                if family != .horizontalCompact && family != .verticalCompact {
                    Text(complicationLabel(complication))
                        .font(clockFont(size: max(7, secondaryFontSize(for: family) * 0.70), weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(secondaryColor.opacity(0.72))
                }
                Text(value)
                    .font(clockFont(size: secondaryFontSize(for: family), weight: complication == .date ? .medium : .regular))
                    .foregroundStyle(complication == .date ? secondaryColor.opacity(0.92) : secondaryColor)
                    .lineLimit(complication == .nextEvent ? 2 : 1)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(horizontal ? .trailing : .center)
            }
        }
    }

    @ViewBuilder private func complicationRow(_ complications: [ClockComplication], date: Date, limit: Int) -> some View {
        if !complications.isEmpty {
            HStack(alignment: .top, spacing: max(12, width * 0.035)) {
                ForEach(Array(complications.prefix(limit)), id: \.self) { complication in
                    let value = complicationValue(complication, date: date)
                    if !value.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(complicationLabel(complication), systemImage: complication.symbol)
                                .font(clockFont(size: max(7, secondaryFontSize(for: family) * 0.66), weight: .semibold))
                                .foregroundStyle(secondaryColor.opacity(0.68))
                                .labelStyle(.titleAndIcon)
                            Text(value)
                                .font(clockFont(size: secondaryFontSize(for: family), weight: .medium))
                                .foregroundStyle(secondaryColor)
                                .lineLimit(complication == .nextEvent ? 2 : 1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder private func largeHeader(date: Date, complications: [ClockComplication]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if clock.showDate {
                Text(adaptiveDate(date, detail: .full))
                    .font(clockFont(size: dateFontSize(for: family), weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 12)
            if complications.contains(.location) || complications.contains(.timezone) {
                Text(complicationValue(complications.contains(.location) ? .location : .timezone, date: date))
                    .font(clockFont(size: secondaryFontSize(for: family), weight: .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder private func heroClock(date: Date, complications: [ClockComplication]) -> some View {
        if visualStyle == .analog {
            HStack(spacing: max(28, width * 0.055)) {
                AdaptiveAnalogClockFace(date: date, style: style, clock: clock, diameter: min(height * 0.78, width * 0.42), showSeconds: shouldShowSeconds(in: .hero))
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                VStack(alignment: .leading, spacing: 14) {
                    largeHeader(date: date, complications: complications)
                    Spacer(minLength: 0)
                    complicationRow(complications, date: date, limit: 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(adaptiveDate(date, detail: .full))
                        .font(clockFont(size: max(11, dateFontSize(for: .hero) * 0.92), weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                    Spacer()
                    Text(complicationValue(.location, date: date))
                        .font(clockFont(size: max(10, secondaryFontSize(for: .hero)), weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 14)
                primaryClock(date: date, family: .hero)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                Spacer(minLength: 18)
                complicationRow(complications.filter { $0 != .date && $0 != .location }, date: date, limit: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value >= 3600 { return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
'''

views = sub_once(views, r'struct WidgetClock: View \{.*\Z', clock_renderer, 'WidgetClock renderer')
views_path.write_text(views)

# -----------------------------------------------------------------------------
# Surface: provide exact grid footprint and live workspace services to Clock only.
# -----------------------------------------------------------------------------
surface_path = ROOT / 'Halo/Views/SurfaceView.swift'
surface = surface_path.read_text()
surface = replace_once(surface, '        case .clock: WidgetClock(style: style)\n', '        case .clock: WidgetClock(style: style, workspace: store.workspace, store: store)\n', 'Clock runtime services')
module_env_old = '''                    .environment(\\.openNotchAvailableWidth, slotSize.width)
                    .environment(\\.openNotchAvailableHeight, slotSize.height)
                    .environment(\\.openNotchBlockVerticalAlignment, item.resolvedVerticalAlignment)
'''
module_env_new = '''                    .environment(\\.openNotchAvailableWidth, slotSize.width)
                    .environment(\\.openNotchAvailableHeight, slotSize.height)
                    .environment(\\.openNotchGridColumnSpan, item.gridPlacement?.columnSpan)
                    .environment(\\.openNotchGridRowSpan, item.gridPlacement?.rowSpan)
                    .environment(\\.openNotchBlockVerticalAlignment, item.resolvedVerticalAlignment)
'''
surface = replace_once(surface, module_env_old, module_env_new, 'Clock grid span environment')
surface_path.write_text(surface)

# -----------------------------------------------------------------------------
# Clock controls in both normal Widget settings and Visual Workspace block inspector.
# -----------------------------------------------------------------------------
settings_path = ROOT / 'Halo/Views/WidgetSettingsView.swift'
settings = settings_path.read_text()

clock_controls = r'''
private struct ClockSettingsControls: View {
    @Binding var style: WidgetStyle
    private static let timeZones = TimeZone.knownTimeZoneIdentifiers

    private var clock: Binding<ClockOptions> { $style.clock }
    private var analog: Binding<ClockAnalogOptions> { clock.analog.withDefault(ClockAnalogOptions()) }

    var body: some View {
        Section("Clock Style") {
            Picker("Style", selection: clock.visualStyle.withDefault(.digital)) {
                ForEach(ClockVisualStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            Text("Style changes the actual clock treatment, not just its font. The adaptive layout family still responds independently to the grid footprint.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Time") {
            Toggle("24-hour time", isOn: clock.twentyFourHour)
            Toggle("Show seconds", isOn: clock.showSeconds)
            if !clock.wrappedValue.twentyFourHour {
                Toggle("Show AM / PM", isOn: clock.showAMPM.withDefault(true))
            }
            Toggle("Leading zero", isOn: clock.leadingZero.withDefault(clock.wrappedValue.twentyFourHour))
            Picker("Separator", selection: clock.separator.withDefault(.colon)) {
                ForEach(ClockSeparatorStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("Blink separator", isOn: clock.blinkingSeparator.withDefault(false))
            Picker("Seconds motion", selection: clock.secondMotion.withDefault(.ticking)) {
                ForEach(ClockSecondMotion.allCases) { Text($0.rawValue).tag($0) }
            }
            PreciseSlider(title: "Hour emphasis", value: clock.hourEmphasis.withDefault(1), range: 0.7...1.6, step: 0.05, suffix: "×", decimals: 2)
            PreciseSlider(title: "Minute emphasis", value: clock.minuteEmphasis.withDefault(1), range: 0.7...1.6, step: 0.05, suffix: "×", decimals: 2)
            PreciseSlider(title: "Seconds emphasis", value: clock.secondsEmphasis.withDefault(0.68), range: 0.45...1.3, step: 0.05, suffix: "×", decimals: 2)
            PreciseSlider(title: "Digit spacing", value: clock.digitSpacing.withDefault(0), range: -4...18, step: 0.5, suffix: "pt", decimals: 1)
            SearchableStringPicker(title: "Primary time zone", selection: clock.timeZone, values: [""] + Self.timeZones, emptyLabel: "System time zone")
        }

        Section("Date") {
            Toggle("Show date", isOn: clock.showDate)
            if clock.wrappedValue.showDate {
                Toggle("Weekday", isOn: clock.showWeekday.withDefault(true))
                if clock.wrappedValue.resolvedShowWeekday {
                    Picker("Weekday style", selection: clock.weekdayStyle.withDefault(.full)) { ForEach(ClockWeekdayStyle.allCases) { Text($0.rawValue).tag($0) } }
                }
                Toggle("Day", isOn: clock.showDay.withDefault(true))
                Toggle("Month", isOn: clock.showMonth.withDefault(true))
                if clock.wrappedValue.resolvedShowMonth {
                    Picker("Month style", selection: clock.monthStyle.withDefault(.full)) { ForEach(ClockMonthStyle.allCases) { Text($0.rawValue).tag($0) } }
                }
                Toggle("Year", isOn: clock.showYear.withDefault(false))
                Picker("Order", selection: clock.dateOrder.withDefault(.weekdayMonthDay)) { ForEach(ClockDateOrder.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Case", selection: clock.dateTextCase.withDefault(.natural)) { ForEach(ClockDateTextCase.allCases) { Text($0.rawValue).tag($0) } }
                Text("The renderer automatically simplifies this format at smaller footprints, so a full date can become “SUN 13” rather than being crushed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        Section("Clock Typography") {
            Picker("Font", selection: $style.fontFamily) { ForEach(WidgetFontFamily.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            if style.fontFamily == .custom {
                SearchableStringPicker(title: "Installed font", selection: $style.customFont, values: NSFontManager.shared.availableFontFamilies.sorted())
            }
            Picker("Weight", selection: $style.weight) { ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Font width", selection: clock.fontWidth.withDefault(.standard)) { ForEach(ClockFontWidth.allCases) { Text($0.rawValue).tag($0) } }
            Toggle("Monospaced digits", isOn: clock.monospacedDigits.withDefault(true))
            Toggle("Automatic sizing", isOn: clock.automaticTypography.withDefault(true))
            if !clock.wrappedValue.usesAutomaticTypography {
                PreciseSlider(title: "Time scale", value: clock.timeScale.withDefault(1), range: 0.55...2.5, step: 0.05, suffix: "×", decimals: 2)
                PreciseSlider(title: "Date scale", value: clock.dateScale.withDefault(1), range: 0.55...2.2, step: 0.05, suffix: "×", decimals: 2)
                PreciseSlider(title: "Secondary scale", value: clock.secondaryScale.withDefault(1), range: 0.5...2, step: 0.05, suffix: "×", decimals: 2)
            }
            PreciseSlider(title: "Time / date ratio", value: clock.timeDateRatio.withDefault(2.3), range: 1.1...3.5, step: 0.05, suffix: "×", decimals: 2)
            PreciseSlider(title: "Tracking", value: clock.tracking.withDefault(0), range: -5...18, step: 0.5, suffix: "pt", decimals: 1)
            PreciseSlider(title: "Line spacing", value: clock.lineSpacing.withDefault(2), range: 0...18, step: 1, suffix: "pt")
        }

        Section("Information Priority") {
            Label("Time is always shown", systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
            ForEach(clock.wrappedValue.resolvedComplicationPriority) { complication in
                HStack(spacing: 8) {
                    Toggle(complication.title, isOn: complicationEnabled(complication))
                    Spacer(minLength: 4)
                    Button { move(complication, direction: -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.borderless).disabled(isFirst(complication))
                    Button { move(complication, direction: 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.borderless).disabled(isLast(complication))
                }
            }
            Text("Clock chooses as many enabled items as the current footprint can support, in this order. Weather and solar items stay hidden until a real runtime provider supplies those values.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("World Clocks & Location") {
            TextField("Location label (optional)", text: clock.locationLabel.withDefault(""))
            ForEach(0..<3, id: \.self) { index in
                SearchableStringPicker(title: "World clock \(index + 1)", selection: worldZoneBinding(index), values: [""] + Self.timeZones, emptyLabel: "Off")
            }
        }

        if clock.wrappedValue.resolvedVisualStyle == .analog {
            Section("Analog Face") {
                Picker("Numerals", selection: analog.numerals) { ForEach(ClockNumeralStyle.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Hour ticks", isOn: analog.hourTicks)
                Toggle("Minute ticks", isOn: analog.minuteTicks)
                PreciseSlider(title: "Tick thickness", value: analog.tickThickness, range: 0.35...5, step: 0.05, suffix: "pt", decimals: 2)
                Toggle("Hour hand", isOn: analog.showHourHand)
                Toggle("Minute hand", isOn: analog.showMinuteHand)
                Toggle("Second hand", isOn: analog.showSecondHand)
                PreciseSlider(title: "Hand thickness", value: analog.handThickness, range: 0.5...8, step: 0.1, suffix: "pt", decimals: 1)
                PreciseSlider(title: "Hour hand length", value: analog.hourHandLength, range: 0.2...0.72, step: 0.01, decimals: 2)
                PreciseSlider(title: "Minute hand length", value: analog.minuteHandLength, range: 0.3...0.84, step: 0.01, decimals: 2)
                PreciseSlider(title: "Second hand length", value: analog.secondHandLength, range: 0.35...0.92, step: 0.01, decimals: 2)
                Toggle("Center cap", isOn: analog.centerCap)
                Toggle("Smooth second hand", isOn: analog.smoothSecondHand)
                PreciseSlider(title: "Face opacity", value: analog.faceOpacity, range: 0...0.55, step: 0.01, decimals: 2)
                ColorPicker("Face", selection: Binding(get: { analog.wrappedValue.faceColor.color }, set: { analog.wrappedValue.faceColor = WidgetColor($0) }), supportsOpacity: false)
                ColorPicker("Ticks", selection: Binding(get: { analog.wrappedValue.tickColor.color }, set: { analog.wrappedValue.tickColor = WidgetColor($0) }), supportsOpacity: false)
                ColorPicker("Hour hand", selection: Binding(get: { analog.wrappedValue.hourHandColor.color }, set: { analog.wrappedValue.hourHandColor = WidgetColor($0) }), supportsOpacity: false)
                ColorPicker("Minute hand", selection: Binding(get: { analog.wrappedValue.minuteHandColor.color }, set: { analog.wrappedValue.minuteHandColor = WidgetColor($0) }), supportsOpacity: false)
                ColorPicker("Second hand", selection: Binding(get: { analog.wrappedValue.secondHandColor.color }, set: { analog.wrappedValue.secondHandColor = WidgetColor($0) }), supportsOpacity: false)
            }
        }

        Section("Clock Appearance") {
            ColorPicker("Primary", selection: Binding(get: { (clock.wrappedValue.primaryColor ?? style.textColor).color }, set: { clock.wrappedValue.primaryColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Secondary", selection: Binding(get: { (clock.wrappedValue.secondaryColor ?? style.textColor).color }, set: { clock.wrappedValue.secondaryColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Separator", selection: Binding(get: { (clock.wrappedValue.separatorColor ?? style.accentColor).color }, set: { clock.wrappedValue.separatorColor = WidgetColor($0) }), supportsOpacity: false)
            PreciseSlider(title: "Text shadow", value: clock.textShadow.withDefault(0), range: 0...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Subtle glow", value: clock.textGlow.withDefault(0), range: 0...1, step: 0.05, decimals: 2)
            Text("Card background, gradients, border, corner radius and card shadow remain in Block Styling below so the Clock keeps one coherent appearance system.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func complicationEnabled(_ complication: ClockComplication) -> Binding<Bool> {
        Binding(get: { clock.wrappedValue.resolvedEnabledComplications.contains(complication) }, set: { enabled in
            var values = clock.wrappedValue.resolvedEnabledComplications
            if enabled {
                if !values.contains(complication) { values.append(complication) }
            } else {
                values.removeAll { $0 == complication }
            }
            clock.wrappedValue.enabledComplications = values
        })
    }

    private func move(_ complication: ClockComplication, direction: Int) {
        var values = clock.wrappedValue.resolvedComplicationPriority
        guard let index = values.firstIndex(of: complication) else { return }
        let target = index + direction
        guard values.indices.contains(target) else { return }
        values.swapAt(index, target)
        clock.wrappedValue.complicationPriority = values
    }
    private func isFirst(_ complication: ClockComplication) -> Bool { clock.wrappedValue.resolvedComplicationPriority.first == complication }
    private func isLast(_ complication: ClockComplication) -> Bool { clock.wrappedValue.resolvedComplicationPriority.last == complication }

    private func worldZoneBinding(_ index: Int) -> Binding<String> {
        Binding(get: {
            let values = clock.wrappedValue.worldTimeZones ?? ["Asia/Tokyo", "Europe/London", ""]
            return values.indices.contains(index) ? values[index] : ""
        }, set: { newValue in
            var values = clock.wrappedValue.worldTimeZones ?? ["Asia/Tokyo", "Europe/London", ""]
            while values.count < 3 { values.append("") }
            values[index] = newValue
            clock.wrappedValue.worldTimeZones = values
        })
    }
}
'''

settings = replace_once(settings, 'struct WidgetSettingsView: View {\n', clock_controls + '\nstruct WidgetSettingsView: View {\n', 'ClockSettingsControls insertion')

old_clock_section = '''        if selected == .clock {
            Section("Clock") {
                Toggle("24-hour time", isOn: style.clock.twentyFourHour)
                Toggle("Show seconds", isOn: style.clock.showSeconds)
                Toggle("Show date", isOn: style.clock.showDate)
                if style.wrappedValue.clock.showDate {
                    Picker("Date style", selection: content.clockDateStyle) {
                        ForEach(WidgetClockDateStyle.allCases) { Text($0.title).tag($0) }
                    }
                }
                SearchableStringPicker(title: "Time zone", selection: style.clock.timeZone, values: [""] + Self.timeZones, emptyLabel: "System time zone")
                WidgetClock(style: style.wrappedValue).foregroundStyle(style.wrappedValue.textColor.color)
                    .padding().background(.black, in: RoundedRectangle(cornerRadius: 12))
            }
        }
'''
new_clock_section = '''        if selected == .clock {
            ClockSettingsControls(style: style)
            Section("Clock Preview") {
                WidgetClock(style: style.wrappedValue)
                    .frame(height: 190)
                    .padding(12)
                    .background(.black, in: RoundedRectangle(cornerRadius: 14))
            }
        }
'''
settings = replace_once(settings, old_clock_section, new_clock_section, 'global Clock section')

calendar_marker = '''        if module == .calendar {
'''
clock_visual_inspector = '''        if module == .clock {
            ClockSettingsControls(style: style)
            clockSizeOverrideInspector(itemID: itemID, style: style)
        }
'''
# Only insert in widgetBlockInspector, where this marker first occurs after the function declaration.
block_start = settings.find('    @ViewBuilder private func widgetBlockInspector')
if block_start < 0:
    raise SystemExit('Missing widgetBlockInspector')
calendar_pos = settings.find(calendar_marker, block_start)
if calendar_pos < 0:
    raise SystemExit('Missing calendar marker inside widgetBlockInspector')
settings = settings[:calendar_pos] + clock_visual_inspector + settings[calendar_pos:]

size_override_helper = r'''
    @ViewBuilder private func clockSizeOverrideInspector(itemID: UUID, style: Binding<WidgetStyle>) -> some View {
        let placement = findItem(itemID)?.gridPlacement ?? OpenNotchGridPlacement()
        let columns = min(8, max(1, placement.columnSpan))
        let rows = min(4, max(1, placement.rowSpan))
        let key = ClockOptions.sizeKey(columns: columns, rows: rows)
        let override = Binding<ClockSizeOverride?>(get: {
            style.wrappedValue.clock.sizeOverrides?[key]
        }, set: { replacement in
            var clock = style.wrappedValue.clock
            var values = clock.sizeOverrides ?? [:]
            if let replacement { values[key] = replacement } else { values.removeValue(forKey: key) }
            clock.sizeOverrides = values.isEmpty ? nil : values
            style.wrappedValue.clock = clock
        })
        Section("\(columns)×\(rows) Clock Override") {
            Toggle("Override Automatic", isOn: Binding(get: { override.wrappedValue != nil }, set: { enabled in
                if enabled {
                    override.wrappedValue = ClockSizeOverride(style: style.wrappedValue.clock.resolvedVisualStyle,
                                                             complications: style.wrappedValue.clock.resolvedEnabledComplications)
                } else { override.wrappedValue = nil }
            }))
            if override.wrappedValue != nil {
                let value = override.withDefault(ClockSizeOverride())
                Picker("Style for \(columns)×\(rows)", selection: value.style.withDefault(style.wrappedValue.clock.resolvedVisualStyle)) {
                    ForEach(ClockVisualStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("Complications for this size").font(.caption).foregroundStyle(.secondary)
                ForEach(ClockComplication.allCases) { complication in
                    Toggle(complication.title, isOn: Binding(get: {
                        (value.wrappedValue.complications ?? style.wrappedValue.clock.resolvedEnabledComplications).contains(complication)
                    }, set: { enabled in
                        var items = value.wrappedValue.complications ?? style.wrappedValue.clock.resolvedEnabledComplications
                        if enabled { if !items.contains(complication) { items.append(complication) } }
                        else { items.removeAll { $0 == complication } }
                        value.wrappedValue.complications = items
                    }))
                }
                Button("Reset \(columns)×\(rows) to Automatic") { override.wrappedValue = nil }
            } else {
                Text("Automatic uses footprint, aspect ratio, point size, style and information priority. Override only when this exact grid size needs a deliberately different treatment.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

'''
helper_marker = '    @ViewBuilder private func groupInspector(_ group: OpenNotchGroup) -> some View {\n'
settings = replace_once(settings, helper_marker, size_override_helper + helper_marker, 'clock size override helper')
settings_path.write_text(settings)

print('Clock Showcase patch applied.')
