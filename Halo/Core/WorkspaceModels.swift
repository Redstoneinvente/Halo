import Foundation

enum ModuleID: String, Codable, CaseIterable, Identifiable {
    case clock, timer, shelf, media, audio, calendar, clipboard, system, launcher, activities, pet, developer, notes, capture, stopwatch
    static var allCases: [ModuleID] { [.clock, .timer, .shelf, .media, .audio, .calendar, .clipboard, .system, .launcher, .activities, .pet, .notes, .capture, .stopwatch] }
    var id: String { rawValue }
    var title: String { rawValue == "shelf" ? "File shelf" : (self == .pet ? "Pixel Pal" : rawValue.capitalized) }
    var symbol: String {
        switch self {
        case .clock: return "clock"
        case .timer: return "timer"
        case .shelf: return "tray"
        case .media: return "music.note"
        case .audio: return "speaker.wave.2"
        case .calendar: return "calendar"
        case .clipboard: return "doc.on.clipboard"
        case .system: return "gauge"
        case .launcher: return "app.dashed"
        case .activities: return "waveform.path"
        case .pet: return "pawprint.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .notes: return "note.text"
        case .capture: return "camera.viewfinder"
        case .stopwatch: return "stopwatch"
        }
    }
}


enum HaloNotchMode: String, Codable, CaseIterable, Identifiable {
    case simple = "Simple"
    case advanced = "Advanced"
    var id: String { rawValue }

    var detail: String {
        switch self {
        case .simple: return "A focused notch with fixed widgets, drag-to-reorder, and no Context Interfaces."
        case .advanced: return "The complete Halo workspace, including your current layouts, CIs, profiles, and customization."
        }
    }
}

enum SimpleNotchWidgetStyle: String, Codable, CaseIterable, Identifiable {
    // Keep the original raw values stable so settings saved by earlier Simple Mode
    // builds continue to decode. The additional cases are clock-only face families.
    case clean = "Clean"
    case glass = "Glass"
    case vibrant = "Vibrant"
    case stackedDigital = "Stacked Digital"
    case flipClock = "Flip Clock"
    case minimalDial = "Minimal Dial"
    case romanDial = "Roman Dial"
    var id: String { rawValue }

    static let coreCases: [SimpleNotchWidgetStyle] = [.clean, .glass, .vibrant]
    static let clockCases: [SimpleNotchWidgetStyle] = coreCases + [.stackedDigital, .flipClock, .minimalDial, .romanDial]

    var isClockExclusive: Bool {
        switch self {
        case .stackedDigital, .flipClock, .minimalDial, .romanDial: return true
        case .clean, .glass, .vibrant: return false
        }
    }

    var title: String {
        switch self {
        case .clean: return "Inline"
        case .glass: return "Spotlight"
        case .vibrant: return "Info Panel"
        case .stackedDigital: return "Stacked Digital"
        case .flipClock: return "Flip Clock"
        case .minimalDial: return "Minimal Dial"
        case .romanDial: return "Roman Dial"
        }
    }

    var detail: String {
        switch self {
        case .clean: return "A compact inline layout that keeps the key information immediately readable."
        case .glass: return "A larger focal layout built around the widget's primary content."
        case .vibrant: return "A structured information panel with secondary details and controls."
        case .stackedDigital: return "Large stacked hour and minute digits inspired by segmented digital clocks."
        case .flipClock: return "Mechanical flip-style hour and minute tiles with compact date details."
        case .minimalDial: return "A restrained analog face with sparse markers and lightweight date information."
        case .romanDial: return "A classic analog face using Roman quarter-hour markers."
        }
    }

    var symbol: String {
        switch self {
        case .clean: return "rectangle.compress.vertical"
        case .glass: return "viewfinder"
        case .vibrant: return "rectangle.3.group"
        case .stackedDigital: return "textformat.123"
        case .flipClock: return "rectangle.split.2x1"
        case .minimalDial: return "clock"
        case .romanDial: return "clock.fill"
        }
    }
}

enum SimpleNotchSize: String, Codable, CaseIterable, Identifiable {
    case standard = "Standard"
    case medium = "Medium"
    case big = "Big"
    var id: String { rawValue }

    var scale: Double {
        switch self {
        case .standard: return 0.90
        case .medium: return 1.0
        case .big: return 1.12
        }
    }
}

struct SimpleNotchSettings: Codable, Equatable {
    static let availableWidgets: [ModuleID] = [.clock, .stopwatch, .shelf, .calendar, .pet, .timer, .media]
    static let closedEligibleWidgets: [ModuleID] = [.clock, .stopwatch, .timer, .media, .calendar]

    /// Order is also the enabled set: widgets absent from this array stay hidden.
    var widgets: [ModuleID] = [.clock, .media, .timer]
    var styles: [String: SimpleNotchWidgetStyle] = [:]
    /// Optional for backwards compatibility with Simple settings saved before size presets.
    var size: SimpleNotchSize?
    var resolvedSize: SimpleNotchSize { size ?? .standard }
    /// Optional so Simple settings saved before notch color customization remain compatible.
    var backgroundColor: WidgetColor?
    var resolvedBackgroundColor: WidgetColor { backgroundColor ?? .black }
    /// Priority order for automatic closed-notch slots. Active transient widgets win
    /// before the Clock fallback.
    var closedWidgets: [ModuleID] = []

    func normalized() -> SimpleNotchSettings {
        var value = self
        var seen = Set<ModuleID>()
        value.widgets = widgets.filter {
            Self.availableWidgets.contains($0) && seen.insert($0).inserted
        }
        // Simple Mode must never open to an empty black surface.
        if value.widgets.isEmpty {
            value.widgets = [.clock]
        }
        var closedSeen = Set<ModuleID>()
        value.closedWidgets = closedWidgets.filter {
            Self.closedEligibleWidgets.contains($0) && closedSeen.insert($0).inserted
        }
        value.styles = styles.filter { key, style in
            guard let module = ModuleID(rawValue: key),
                  Self.availableWidgets.contains(module) else { return false }
            // New face families belong only to Clock. If an imported/hand-edited
            // settings file assigns one elsewhere, gracefully fall back to Inline.
            return module == .clock || !style.isClockExclusive
        }
        return value
    }

    func style(for widget: ModuleID) -> SimpleNotchWidgetStyle {
        styles[widget.rawValue] ?? .clean
    }

    func contains(_ widget: ModuleID) -> Bool {
        normalized().widgets.contains(widget)
    }

    func allowsClosed(_ widget: ModuleID) -> Bool {
        normalized().closedWidgets.contains(widget)
    }

    func activeClosedWidgets(
        timerActive: Bool,
        stopwatchActive: Bool,
        mediaActive: Bool,
        calendarActive: Bool
    ) -> [ModuleID] {
        let state = normalized()
        return Array(state.closedWidgets.filter { widget in
            guard state.widgets.contains(widget) else { return false }
            switch widget {
            case .timer: return timerActive
            case .stopwatch: return stopwatchActive
            case .media: return mediaActive
            case .calendar: return calendarActive
            case .clock: return true
            default: return false
            }
        }.prefix(2))
    }
}

enum SimpleNotchMetrics {
    /// Non-notched displays use these as the collapsed pill. A real notch applies an
    /// additional hardware floor in WindowManager.
    static func closedPillWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 220; case .medium: return 250; case .big: return 285 }
    }
    static func closedHeight(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 34; case .medium: return 38; case .big: return 42 }
    }

    /// Simple is intentionally a wide, shallow shelf rather than a stack of tall cards.
    static func widgetWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 212; case .medium: return 238; case .big: return 270 }
    }
    static func pixelPalWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 164; case .medium: return 188; case .big: return 214 }
    }
    static func widgetHeight(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 112; case .medium: return 126; case .big: return 144 }
    }
    static func widgetSpacing(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 10; case .medium: return 12; case .big: return 14 }
    }
    static func horizontalPadding(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 10; case .medium: return 12; case .big: return 14 }
    }
    static func verticalPadding(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 8; case .medium: return 9; case .big: return 10 }
    }
    static func closedSlotWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 118; case .medium: return 132; case .big: return 148 }
    }
    static func closedSlotGap(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 6; case .medium: return 8; case .big: return 10 }
    }

    /// Content sets the width above the collapsed preset and physical camera floor.
    static func minimumOpenShelfWidth(_ size: SimpleNotchSize, hardwareWidth: Double = 0) -> Double {
        max(closedPillWidth(size), hardwareWidth)
    }

    struct Arrangement {
        var rows: [[ModuleID]]
        var width: Double
        var height: Double
    }

    static func requiredContentWidth(settings: SimpleNotchSettings) -> Double {
        let settings = settings.normalized()
        let size = settings.resolvedSize
        let widgets = settings.widgets
        return widgets.reduce(0.0) {
            $0 + width(for: $1, size: size)
        } + Double(max(0, widgets.count - 1)) * widgetSpacing(size)
          + horizontalPadding(size) * 2
    }

    static func fits(settings: SimpleNotchSettings, availableWidth: Double,
                     hardwareWidth: Double = 0) -> Bool {
        let maximum = max(1, availableWidth)
        let required = max(
            minimumOpenShelfWidth(settings.resolvedSize, hardwareWidth: hardwareWidth),
            requiredContentWidth(settings: settings)
        )
        return required <= maximum + 0.5
    }

    static func fittingSettings(settings: SimpleNotchSettings, availableWidth: Double,
                                hardwareWidth: Double = 0) -> SimpleNotchSettings {
        var value = settings.normalized()
        guard !fits(settings: value, availableWidth: availableWidth, hardwareWidth: hardwareWidth) else {
            return value
        }

        // Preserve order and remove the newest/right-most widgets until the row fits.
        while value.widgets.count > 1 &&
              !fits(settings: value, availableWidth: availableWidth, hardwareWidth: hardwareWidth) {
            value.widgets.removeLast()
        }
        return value.normalized()
    }

    /// Simple Mode is strictly one row. The notch expands with its enabled widgets.
    /// Settings prevents additions that would exceed the usable screen width; this
    /// arrangement still defensively trims legacy/oversized settings so runtime never wraps,
    /// scrolls or scales the cards.
    static func arrangement(settings: SimpleNotchSettings, availableWidth: Double,
                            hardwareWidth: Double = 0) -> Arrangement {
        let settings = fittingSettings(
            settings: settings,
            availableWidth: availableWidth,
            hardwareWidth: hardwareWidth
        )
        let size = settings.resolvedSize
        let widgets = settings.widgets
        let requestedWidth = max(
            minimumOpenShelfWidth(size, hardwareWidth: hardwareWidth),
            requiredContentWidth(settings: settings)
        )
        let tallest = widgets.map {
            height(for: $0, style: settings.style(for: $0), size: size)
        }.max() ?? widgetHeight(size)

        return Arrangement(
            rows: [widgets],
            width: min(max(1, availableWidth), requestedWidth),
            height: tallest + verticalPadding(size) * 2
        )
    }

    static func calendarWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 272; case .medium: return 306; case .big: return 342 }
    }

    static func calendarMonthHeight(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 148; case .medium: return 166; case .big: return 188 }
    }

    static func mediaWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 264; case .medium: return 300; case .big: return 336 }
    }

    static func clockWidth(_ size: SimpleNotchSize) -> Double {
        switch size { case .standard: return 220; case .medium: return 248; case .big: return 278 }
    }

    static func width(for widget: ModuleID, size: SimpleNotchSize) -> Double {
        switch widget {
        case .calendar: return calendarWidth(size)
        case .media: return mediaWidth(size)
        case .clock: return clockWidth(size)
        case .pet: return pixelPalWidth(size)
        default: return widgetWidth(size)
        }
    }

    static func height(for widget: ModuleID, style: SimpleNotchWidgetStyle, size: SimpleNotchSize) -> Double {
        if widget == .calendar && style == .glass { return calendarMonthHeight(size) }
        return widgetHeight(size) + (style == .vibrant ? 24 * size.scale : 0)
    }

    static func expandedWidth(widgets: [ModuleID], size: SimpleNotchSize) -> Double {
        let widgets = widgets.filter { SimpleNotchSettings.availableWidgets.contains($0) }
        guard !widgets.isEmpty else { return minimumOpenShelfWidth(size) }
        let content = widgets.reduce(0.0) { $0 + width(for: $1, size: size) }
        let gaps = Double(max(0, widgets.count - 1)) * widgetSpacing(size)
        return max(
            minimumOpenShelfWidth(size),
            content + gaps + horizontalPadding(size) * 2
        )
    }

    static func expandedBodyHeight(settings: SimpleNotchSettings) -> Double {
        let size = settings.resolvedSize
        let tallest = settings.widgets.map {
            height(for: $0, style: settings.style(for: $0), size: size)
        }.max() ?? widgetHeight(size)
        return tallest + verticalPadding(size) * 2
    }
}

enum BackgroundKind: String, Codable, CaseIterable { case gradient, solid, glass, image, video }

struct GlassOptions: Codable, Equatable {
    /// 0 = dense / strongly treated, 1 = very transparent.
    var clarity = 0.72
    /// Controls the native material family Halo asks macOS to use.
    var frost = 0.46
    /// Darkens transmitted light without replacing the live backdrop.
    var lightAbsorption = 0.16
    /// Warps the actual content behind Halo through a Core Image backdrop filter.
    var refraction = 0.14
    /// Adds subtle cyan/magenta separation to the glass coloration.
    var chromaticShift = 0.08
    var tint = WidgetColor(red: 0.72, green: 0.82, blue: 1.0)
    var tintAmount = 0.04
    var highlight = 0.12
    var edgeDepth = 0.10

    func normalized() -> GlassOptions {
        var value = self
        let finite = [clarity, frost, lightAbsorption, refraction, chromaticShift, tintAmount, highlight, edgeDepth]
        guard finite.allSatisfy(\.isFinite) else { return GlassOptions() }
        value.clarity = min(1, max(0, clarity))
        value.frost = min(1, max(0, frost))
        value.lightAbsorption = min(1, max(0, lightAbsorption))
        value.refraction = min(1, max(0, refraction))
        value.chromaticShift = min(1, max(0, chromaticShift))
        value.tintAmount = min(0.5, max(0, tintAmount))
        value.highlight = min(1, max(0, highlight))
        value.edgeDepth = min(1, max(0, edgeDepth))
        value.tint = (try? tint.validated()) ?? GlassOptions().tint
        return value
    }
}

enum NotchSkinPreset: String, CaseIterable, Identifiable, Codable {
    case haloGlow = "Halo Glow"
    case carbonWeave = "Carbon Weave"
    case neonCircuit = "Neon Circuit"
    case retroScanlines = "Retro Scanlines"
    case pixelMatrix = "Pixel Matrix"
    case constellation = "Constellation"
    case aurora = "Aurora"
    case synthwave = "Synthwave Sunset"
    case sakuraNight = "Sakura Night"
    case oceanCurrent = "Ocean Current"
    case emberCore = "Ember Core"
    case blueprint = "Blueprint"
    case matrixRain = "Matrix Rain"
    case nebula = "Nebula"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .haloGlow: return "sparkles"
        case .carbonWeave: return "square.grid.3x3.fill"
        case .neonCircuit: return "point.3.connected.trianglepath.dotted"
        case .retroScanlines: return "line.3.horizontal"
        case .pixelMatrix: return "circle.grid.3x3.fill"
        case .constellation: return "sparkle"
        case .aurora: return "wave.3.right"
        case .synthwave: return "sun.horizon.fill"
        case .sakuraNight: return "leaf.fill"
        case .oceanCurrent: return "water.waves"
        case .emberCore: return "flame.fill"
        case .blueprint: return "ruler.fill"
        case .matrixRain: return "textformat.abc"
        case .nebula: return "cloud.moon.fill"
        }
    }

    // Custom Image existed in early Notch Skins builds. Decode it as Halo Glow so saved
    // profiles continue loading even though image-backed skins are no longer exposed.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? Self.haloGlow.rawValue
        self = raw == "Custom Image" ? .haloGlow : (Self(rawValue: raw) ?? .haloGlow)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum NotchSkinVisibility: String, Codable, CaseIterable, Identifiable {
    case always = "Opened + Closed"
    case opened = "Opened only"
    case closed = "Closed only"
    var id: String { rawValue }
}

enum NotchSkinBlend: String, Codable, CaseIterable, Identifiable {
    case normal = "Normal"
    case overlay = "Overlay"
    case softLight = "Soft Light"
    case screen = "Screen"
    case multiply = "Multiply"
    var id: String { rawValue }
}



struct NotchSkinOptions: Codable, Equatable {
    var enabled = false
    var preset: NotchSkinPreset = .haloGlow
    var visibility: NotchSkinVisibility = .always
    var opacity = 0.30
    var blend: NotchSkinBlend = .screen
    var usesThemeTint = true
    var tint = WidgetColor(red: 0.34, green: 0.72, blue: 1.0)
    var scale = 1.0

    func normalized() -> NotchSkinOptions {
        var value = self
        value.opacity = min(1, max(0, opacity.isFinite ? opacity : 0.30))
        value.scale = min(3, max(0.4, scale.isFinite ? scale : 1.0))
        value.tint = (try? tint.validated()) ?? WidgetColor(red: 0.34, green: 0.72, blue: 1.0)
        return value
    }
}
enum AnimationPreset: String, Codable, CaseIterable {
    case macOS, dynamic, smooth, snappy, elastic, minimal, none
    var duration: Double {
        switch self { case .none: return 0; case .snappy, .minimal: return 0.12; case .elastic: return 0.45; default: return 0.24 }
    }
}
struct Appearance: Codable, Equatable {
    var grain: GrainOptions?
    var backgroundSchedule: [TimedBackground]?
    var surface = SurfaceOptions()
    var background: BackgroundKind = .gradient
    var skin = NotchSkinOptions()
    var glass = GlassOptions()
    var solidColor: WidgetColor?
    var gradientStartColor: WidgetColor?
    var gradientEndColor: WidgetColor?
    var assetPath = ""
    var blur = 0.0
    var saturation = 1.0
    var brightness = 0.0
    var expandedHeight = 500.0
    var compactWidth = 190.0
    var spacing = 12.0
    var animation: AnimationPreset = .smooth
    var pauseVideoOnBattery = true
    init() {}
    private enum CodingKeys: String, CodingKey {
        case grain, backgroundSchedule, surface, background, skin, glass, solidColor, gradientStartColor, gradientEndColor, assetPath, blur, saturation, brightness, expandedHeight, compactWidth, spacing, animation, pauseVideoOnBattery
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grain = try c.decodeIfPresent(GrainOptions.self, forKey: .grain)
        backgroundSchedule = try c.decodeIfPresent([TimedBackground].self, forKey: .backgroundSchedule)
        surface = try c.decodeIfPresent(SurfaceOptions.self, forKey: .surface) ?? SurfaceOptions()
        background = try c.decodeIfPresent(BackgroundKind.self, forKey: .background) ?? .gradient
        skin = (try c.decodeIfPresent(NotchSkinOptions.self, forKey: .skin) ?? NotchSkinOptions()).normalized()
        glass = (try c.decodeIfPresent(GlassOptions.self, forKey: .glass) ?? GlassOptions()).normalized()
        solidColor = try c.decodeIfPresent(WidgetColor.self, forKey: .solidColor)
        gradientStartColor = try c.decodeIfPresent(WidgetColor.self, forKey: .gradientStartColor)
        gradientEndColor = try c.decodeIfPresent(WidgetColor.self, forKey: .gradientEndColor)
        assetPath = try c.decodeIfPresent(String.self, forKey: .assetPath) ?? ""
        blur = try c.decodeIfPresent(Double.self, forKey: .blur) ?? 0
        saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0
        expandedHeight = try c.decodeIfPresent(Double.self, forKey: .expandedHeight) ?? 500
        compactWidth = try c.decodeIfPresent(Double.self, forKey: .compactWidth) ?? 190
        spacing = try c.decodeIfPresent(Double.self, forKey: .spacing) ?? 12
        animation = try c.decodeIfPresent(AnimationPreset.self, forKey: .animation) ?? .smooth
        pauseVideoOnBattery = try c.decodeIfPresent(Bool.self, forKey: .pauseVideoOnBattery) ?? true
    }
}
struct DisplayOverride: Codable, Identifiable, Equatable {
    var id: String
    var enabled = true
    var theme = Theme()
    var layout: WorkspaceLayout?
    // When set, this display follows the saved profile live instead of keeping a copied layout.
    var profileID: UUID?
}
enum OpenNotchContentMode: String, Codable, CaseIterable, Identifiable {
    case fixed = "Fixed Canvas"
    case scroll = "Scroll"
    case pages = "Pages"
    var id: String { rawValue }
}

struct WorkspaceLayout: Codable, Equatable {
    var contextMusic: ContextMusicOptions?
    var hud: HaloHUDSettings?
    var horizontalWidgets: Bool?
    var horizontalPages: Bool?
    var horizontalHeight: Double?
    // Optional so existing workspaces and exported profiles decode unchanged.
    var openNotchContentMode: OpenNotchContentMode?
    var openHorizontalPadding: Double?
    var openVerticalPadding: Double?
    var openFixedColumns: Int?
    // The modular workspace is optional. nil preserves behavior for users who
    // already customized it before this toggle existed; legacy profiles with no
    // OpenNotchLayout stay on the original Fixed / Scroll / Pages renderer.
    var useCustomOpenNotchWorkspace: Bool?
    var openNotch: OpenNotchLayout?
    var widgets: [String: WidgetStyle]?
    var closedNotch: ClosedNotchOptions?

    var resolvedOpenNotchContentMode: OpenNotchContentMode {
        if let openNotchContentMode { return openNotchContentMode }
        return (horizontalPages ?? false) ? .pages : .scroll
    }
    var resolvedOpenHorizontalPadding: Double {
        min(72, max(8, openHorizontalPadding ?? max(20, appearance.surface.shoulder + 12)))
    }
    var resolvedOpenVerticalPadding: Double {
        min(72, max(8, openVerticalPadding ?? 20))
    }
    var resolvedOpenFixedColumns: Int {
        min(4, max(1, openFixedColumns ?? 2))
    }
    var resolvedUsesCustomOpenNotchWorkspace: Bool {
        if let useCustomOpenNotchWorkspace { return useCustomOpenNotchWorkspace }
        return openNotch != nil
    }

    var resolvedOpenNotchLayout: OpenNotchLayout {
        // An explicitly saved empty workspace is intentional. Only migrate the
        // legacy dashboard when no custom OpenNotchLayout has ever been created.
        if let openNotch { return openNotch }
        return OpenNotchLayout.migrated(
            modules: normalizedOrder().filter { enabled.contains($0) },
            horizontal: horizontalWidgets ?? false
        )
    }

    mutating func materializeOpenNotchLayout() {
        if openNotch == nil { openNotch = resolvedOpenNotchLayout }
        openNotch?.materializeGridItems()
    }

    mutating func setCustomOpenNotchWorkspaceEnabled(_ enabled: Bool) {
        useCustomOpenNotchWorkspace = enabled
        if enabled { materializeOpenNotchLayout() }
    }

    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {
        openNotch = OpenNotchLayout.made(preset)
        openNotch?.materializeGridItems()
        let modules = openNotch?.allItems.compactMap(\.module) ?? []
        enabled.formUnion(modules)
    }

    func widgetStyle(for id: ModuleID) -> WidgetStyle {
        if let saved = widgets?[id.rawValue] { return saved }
        var style = WidgetStyle()
        if id == .clock { style.fontSize = 30; style.fontFamily = .rounded; style.weight = .light; style.showTitle = false }
        if id == .pet { style.showTitle = false }
        return style
    }
    mutating func setWidgetStyle(_ style: WidgetStyle, for id: ModuleID) {
        if widgets == nil { widgets = [:] }; widgets?[id.rawValue] = style
    }
    var order = ModuleID.allCases
    var enabled: Set<ModuleID> = [.clock, .timer, .shelf, .system, .launcher]
    var appearance = Appearance()
    func normalizedOrder() -> [ModuleID] {
        var seen = Set<ModuleID>()
        return (order + ModuleID.allCases).filter { $0 != .developer && seen.insert($0).inserted }
    }
    mutating func move(_ module: ModuleID, before target: ModuleID) {
        guard module != target else { return }
        var updated = normalizedOrder(); updated.removeAll { $0 == module }
        guard let index = updated.firstIndex(of: target) else { return }
        updated.insert(module, at: index); order = updated
    }
}

enum OpenNotchAxis: String, Codable, CaseIterable, Identifiable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    var id: String { rawValue }
}

enum OpenNotchRegionPlacement: String, Codable, CaseIterable, Identifiable {
    case topLeft, topCenter, topRight
    case middleLeft, middleCenter, middleRight
    case bottomLeft, bottomCenter, bottomRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .middleLeft: return "Middle Left"
        case .middleCenter: return "Middle Center"
        case .middleRight: return "Middle Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        }
    }
}

enum OpenNotchGroupAlignment: String, Codable, CaseIterable, Identifiable {
    case leading = "Leading"
    case center = "Center"
    case trailing = "Trailing"
    case stretch = "Stretch"
    var id: String { rawValue }
}

struct OpenNotchInsets: Codable, Equatable {
    var top = 6.0
    var leading = 6.0
    var bottom = 6.0
    var trailing = 6.0
    func validated() throws -> OpenNotchInsets {
        guard [top, leading, bottom, trailing].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.top = min(96, max(0, top)); v.leading = min(96, max(0, leading))
        v.bottom = min(96, max(0, bottom)); v.trailing = min(96, max(0, trailing))
        return v
    }
}

enum OpenNotchSizingMode: String, Codable, CaseIterable, Identifiable {
    case fixed = "Fixed"
    case fitContent = "Fit Content"
    case flexible = "Flexible"
    case fill = "Fill Remaining Space"
    var id: String { rawValue }
}

struct OpenNotchSizing: Codable, Equatable {
    var mode: OpenNotchSizingMode = .flexible
    var minimumWidth = 80.0
    var preferredWidth = 260.0
    var maximumWidth = 900.0
    var minimumHeight = 44.0
    var preferredHeight = 150.0
    var maximumHeight = 700.0
    func validated() throws -> OpenNotchSizing {
        let values = [minimumWidth, preferredWidth, maximumWidth, minimumHeight, preferredHeight, maximumHeight]
        guard values.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.minimumWidth = min(1200, max(20, minimumWidth))
        v.maximumWidth = min(1600, max(v.minimumWidth, maximumWidth))
        v.preferredWidth = min(v.maximumWidth, max(v.minimumWidth, preferredWidth))
        v.minimumHeight = min(1100, max(18, minimumHeight))
        v.maximumHeight = min(1400, max(v.minimumHeight, maximumHeight))
        v.preferredHeight = min(v.maximumHeight, max(v.minimumHeight, preferredHeight))
        return v
    }
}

enum OpenNotchGridSizePreset: String, Codable, CaseIterable, Identifiable {
    // Every legal Halo widget footprint. Keep raw values stable: they are persisted in UI state.
    case oneByOne = "1×1", twoByOne = "2×1", threeByOne = "3×1", fourByOne = "4×1"
    case fiveByOne = "5×1", sixByOne = "6×1", sevenByOne = "7×1", eightByOne = "8×1"
    case oneByTwo = "1×2", twoByTwo = "2×2", threeByTwo = "3×2", fourByTwo = "4×2"
    case fiveByTwo = "5×2", sixByTwo = "6×2", sevenByTwo = "7×2", eightByTwo = "8×2"
    case oneByThree = "1×3", twoByThree = "2×3", threeByThree = "3×3", fourByThree = "4×3"
    case fiveByThree = "5×3", sixByThree = "6×3", sevenByThree = "7×3", eightByThree = "8×3"
    case oneByFour = "1×4", twoByFour = "2×4", threeByFour = "3×4", fourByFour = "4×4"
    case fiveByFour = "5×4", sixByFour = "6×4", sevenByFour = "7×4", eightByFour = "8×4"
    case custom = "Custom"

    var id: String { rawValue }
    var span: (columns: Int, rows: Int)? {
        switch self {
        case .oneByOne: return (1, 1); case .twoByOne: return (2, 1); case .threeByOne: return (3, 1); case .fourByOne: return (4, 1)
        case .fiveByOne: return (5, 1); case .sixByOne: return (6, 1); case .sevenByOne: return (7, 1); case .eightByOne: return (8, 1)
        case .oneByTwo: return (1, 2); case .twoByTwo: return (2, 2); case .threeByTwo: return (3, 2); case .fourByTwo: return (4, 2)
        case .fiveByTwo: return (5, 2); case .sixByTwo: return (6, 2); case .sevenByTwo: return (7, 2); case .eightByTwo: return (8, 2)
        case .oneByThree: return (1, 3); case .twoByThree: return (2, 3); case .threeByThree: return (3, 3); case .fourByThree: return (4, 3)
        case .fiveByThree: return (5, 3); case .sixByThree: return (6, 3); case .sevenByThree: return (7, 3); case .eightByThree: return (8, 3)
        case .oneByFour: return (1, 4); case .twoByFour: return (2, 4); case .threeByFour: return (3, 4); case .fourByFour: return (4, 4)
        case .fiveByFour: return (5, 4); case .sixByFour: return (6, 4); case .sevenByFour: return (7, 4); case .eightByFour: return (8, 4)
        case .custom: return nil
        }
    }
    static func matching(columns: Int, rows: Int) -> OpenNotchGridSizePreset {
        allCases.first { $0.span?.columns == columns && $0.span?.rows == rows } ?? .custom
    }
}

struct OpenNotchGridPlacement: Codable, Equatable {
    var column = 0
    var row = 0
    var columnSpan = 2
    var rowSpan = 1

    func clamped(columns: Int) -> OpenNotchGridPlacement {
        let columnCount = min(8, max(1, columns))
        var value = self
        value.columnSpan = min(columnCount, max(1, columnSpan))
        value.rowSpan = min(4, max(1, rowSpan))
        value.column = min(max(0, columnCount - value.columnSpan), max(0, column))
        value.row = min(max(0, 4 - value.rowSpan), max(0, row))
        return value
    }
    func validated() throws -> OpenNotchGridPlacement {
        var value = self
        value.columnSpan = min(8, max(1, columnSpan))
        value.rowSpan = min(4, max(1, rowSpan))
        value.column = min(max(0, 8 - value.columnSpan), max(0, column))
        value.row = min(max(0, 4 - value.rowSpan), max(0, row))
        return value
    }
}

enum OpenNotchPresentation: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case compact = "Compact"
    case regular = "Regular"
    case expanded = "Expanded"
    var id: String { rawValue }
}

enum OpenNotchPriority: String, Codable, CaseIterable, Identifiable {
    case alwaysVisible = "Always Visible"
    case high = "High"
    case normal = "Normal"
    case low = "Low"
    case optional = "Optional"
    var id: String { rawValue }
}

enum OpenNotchItemKind: String, Codable, CaseIterable, Identifiable {
    // element/spacer/divider remain decodable for legacy saved layouts only.
    case module, element, spacer, divider
    static var allCases: [OpenNotchItemKind] { [.module] }
    var id: String { rawValue }
}

enum OpenNotchBlockVerticalAlignment: String, Codable, CaseIterable, Identifiable {
    case top = "Top"
    case center = "Center"
    case bottom = "Bottom"
    var id: String { rawValue }
}

enum OpenNotchElementKind: String, Codable, CaseIterable, Identifiable {
    // Legacy decoding shim. Lightweight elements are no longer Workspace content.
    case clock, date, battery, batteryPercentage, chargingState
    case appIcon, appName, volume, brightness, timer, stopwatch
    case mediaTitle, artist, albumArt, playbackControls, playbackProgress
    case cpu, ram, storage, networkActivity
    case customText, customIcon, customImage, customGIF, button, spacer, divider
    static var allCases: [OpenNotchElementKind] { [] }
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clock: return "Clock"
        case .date: return "Date"
        case .battery: return "Battery"
        case .batteryPercentage: return "Battery Percentage"
        case .chargingState: return "Charging State"
        case .appIcon: return "Active App Icon"
        case .appName: return "Active App Name"
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .timer: return "Timer"
        case .stopwatch: return "Stopwatch"
        case .mediaTitle: return "Media Title"
        case .artist: return "Artist"
        case .albumArt: return "Album Art"
        case .playbackControls: return "Playback Controls"
        case .playbackProgress: return "Playback Progress"
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .storage: return "Storage"
        case .networkActivity: return "Network Activity"
        case .customText: return "Custom Text"
        case .customIcon: return "Custom Icon"
        case .customImage: return "Custom Image"
        case .customGIF: return "Custom GIF"
        case .button: return "Button"
        case .spacer: return "Spacer"
        case .divider: return "Divider"
        }
    }
    var symbol: String {
        switch self {
        case .clock: return "clock"
        case .date: return "calendar"
        case .battery, .batteryPercentage: return "battery.100"
        case .chargingState: return "bolt.fill"
        case .appIcon: return "app.fill"
        case .appName: return "app.badge"
        case .volume: return "speaker.wave.2"
        case .brightness: return "sun.max"
        case .timer: return "timer"
        case .stopwatch: return "stopwatch"
        case .mediaTitle: return "music.note"
        case .artist: return "person.wave.2"
        case .albumArt: return "photo"
        case .playbackControls: return "playpause.fill"
        case .playbackProgress: return "slider.horizontal.3"
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .storage: return "internaldrive"
        case .networkActivity: return "network"
        case .customText: return "textformat"
        case .customIcon: return "star"
        case .customImage: return "photo"
        case .customGIF: return "photo.stack"
        case .button: return "button.programmable"
        case .spacer: return "arrow.left.and.right"
        case .divider: return "minus"
        }
    }
}

enum OpenNotchVisibilityMetric: String, Codable, CaseIterable, Identifiable {
    case always = "Always"
    case batteryLevel = "Battery Level"
    case charging = "Charging"
    case mediaPlaying = "Media Playing"
    case timerActive = "Timer Active"
    case stopwatchRunning = "Stopwatch Running"
    case cpuUsage = "CPU Usage"
    case lowPowerMode = "Low Power Mode"
    var id: String { rawValue }
    var isBoolean: Bool { [.charging, .mediaPlaying, .timerActive, .stopwatchRunning, .lowPowerMode].contains(self) }
}

enum OpenNotchVisibilityComparison: String, Codable, CaseIterable, Identifiable {
    case equal = "Equals"
    case notEqual = "Not Equal"
    case lessThan = "Below"
    case lessThanOrEqual = "At Most"
    case greaterThan = "Above"
    case greaterThanOrEqual = "At Least"
    var id: String { rawValue }
}

enum OpenNotchVisibilityLogic: String, Codable, CaseIterable, Identifiable {
    case all = "All rules"
    case any = "Any rule"
    var id: String { rawValue }
}

struct OpenNotchVisibilityRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var metric: OpenNotchVisibilityMetric = .always
    var comparison: OpenNotchVisibilityComparison = .equal
    // Boolean metrics use 0 / 1. Numeric metrics use their native percentage value.
    var value = 1.0
}

enum OpenNotchInteractionAction: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case togglePlayback = "Play / Pause"
    case nextTrack = "Next Track"
    case previousTrack = "Previous Track"
    case openPlayer = "Open Player"
    case adjustVolume = "Adjust Volume"
    case seekMedia = "Seek Media"
    case toggleTimer = "Toggle Timer"
    case toggleStopwatch = "Toggle Stopwatch"
    case openSystemSettings = "Open System Settings"
    var id: String { rawValue }
}

struct OpenNotchInteractions: Codable, Equatable {
    var singleClick: OpenNotchInteractionAction = .none
    var doubleClick: OpenNotchInteractionAction = .none
    var rightClick: OpenNotchInteractionAction = .none
    var scroll: OpenNotchInteractionAction = .none
    var drag: OpenNotchInteractionAction = .none
    var modifierClick: OpenNotchInteractionAction = .none
}

struct OpenNotchItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: OpenNotchItemKind = .module
    var module: ModuleID?
    var element: OpenNotchElementKind?
    var customText = ""
    var customIcon = "sparkles"
    var customAssetPath = ""
    var buttonLabel = "Action"
    var buttonURL = ""
    var hidden = false
    var sizing = OpenNotchSizing()
    // Visual Workspace v2 places items directly on a grid. Optional keeps every
    // region-based saved workspace decodable and migratable.
    var gridPlacement: OpenNotchGridPlacement?
    var presentation: OpenNotchPresentation = .automatic
    var priority: OpenNotchPriority = .normal
    var visibilityLogic: OpenNotchVisibilityLogic = .all
    var visibilityRules: [OpenNotchVisibilityRule] = []
    var style: WidgetElementStyle?
    // Visual Workspace module instances may override the shared module style without
    // affecting the legacy opened dashboard or another copy of the same module.
    var widgetStyle: WidgetStyle?
    var verticalAlignment: OpenNotchBlockVerticalAlignment?
    var resolvedVerticalAlignment: OpenNotchBlockVerticalAlignment { verticalAlignment ?? .center }
    var interactions = OpenNotchInteractions()

    static func moduleItem(_ module: ModuleID, presentation: OpenNotchPresentation = .automatic,
                           priority: OpenNotchPriority = .normal) -> OpenNotchItem {
        var value = OpenNotchItem()
        value.kind = .module; value.module = module; value.presentation = presentation; value.priority = priority
        value.verticalAlignment = .center
        value.sizing = OpenNotchSizing(mode: .fill, minimumWidth: 120, preferredWidth: 300, maximumWidth: 1200,
                                       minimumHeight: 70, preferredHeight: 170, maximumHeight: 720)
        return value
    }
    static func elementItem(_ element: OpenNotchElementKind, priority: OpenNotchPriority = .normal) -> OpenNotchItem {
        var value = OpenNotchItem()
        value.kind = element == .spacer ? .spacer : element == .divider ? .divider : .element
        value.element = element; value.priority = priority
        value.sizing = OpenNotchSizing(mode: element == .spacer ? .fill : .fitContent,
                                       minimumWidth: 20, preferredWidth: 110, maximumWidth: 500,
                                       minimumHeight: 18, preferredHeight: 34, maximumHeight: 180)
        return value
    }
    func validated() throws -> OpenNotchItem {
        var value = self
        value.sizing = try sizing.validated()
        value.gridPlacement = try gridPlacement?.validated()
        if module == .pet, var placement = value.gridPlacement {
            let side = HaloPixelPalLayout.squareSide(columns: placement.columnSpan, rows: placement.rowSpan)
            placement.columnSpan = side
            placement.rowSpan = side
            placement.column = min(max(0, 8 - side), max(0, placement.column))
            placement.row = min(max(0, 4 - side), max(0, placement.row))
            value.gridPlacement = placement
        }
        if let style { value.style = try style.validated() }
        if let widgetStyle { value.widgetStyle = try widgetStyle.validated() }
        value.customText = String(customText.prefix(500))
        value.customIcon = String(customIcon.prefix(120))
        value.customAssetPath = String(customAssetPath.prefix(2048))
        value.buttonLabel = String(buttonLabel.prefix(120))
        value.buttonURL = String(buttonURL.prefix(2048))
        value.visibilityRules = Array(visibilityRules.prefix(8))
        return value
    }
}

struct OpenNotchGroup: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = "Group"
    var axis: OpenNotchAxis = .vertical
    var alignment: OpenNotchGroupAlignment = .stretch
    var spacing = 10.0
    var padding = OpenNotchInsets()
    var items: [OpenNotchItem] = []
    func validated() throws -> OpenNotchGroup {
        guard spacing.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        value.name = String(name.prefix(80)); value.spacing = min(48, max(0, spacing))
        value.padding = try padding.validated()
        value.items = try items.prefix(80)
            .filter { $0.kind == .module && $0.module != nil }
            .map { try $0.validated() }
        return value
    }
}

struct OpenNotchRegionFrame: Codable, Equatable {
    // Normalized coordinates inside the opened Visual Workspace canvas.
    // Optional use on OpenNotchRegion keeps every pre-freeform layout decodable.
    var x = 0.0
    var y = 0.0
    var width = 1.0
    var height = 1.0

    static let full = OpenNotchRegionFrame()

    func clamped(minimumSize: Double = 0.10) -> OpenNotchRegionFrame {
        var value = self
        value.width = min(1, max(minimumSize, width))
        value.height = min(1, max(minimumSize, height))
        value.x = min(1 - value.width, max(0, x))
        value.y = min(1 - value.height, max(0, y))
        return value
    }

    func union(_ other: OpenNotchRegionFrame) -> OpenNotchRegionFrame {
        let left = min(x, other.x)
        let top = min(y, other.y)
        let right = max(x + width, other.x + other.width)
        let bottom = max(y + height, other.y + other.height)
        return OpenNotchRegionFrame(x: left, y: top, width: right - left, height: bottom - top).clamped()
    }

    func validated() throws -> OpenNotchRegionFrame {
        guard [x, y, width, height].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        return clamped()
    }
}

struct OpenNotchRegion: Codable, Equatable, Identifiable {
    var id = UUID()
    var placement: OpenNotchRegionPlacement = .middleCenter
    var padding = OpenNotchInsets()
    // Fractions are relative to the legacy grid track. They remain for old layouts.
    var widthFraction: Double?
    var heightFraction: Double?
    // Once set, frame replaces the legacy 3x3 track geometry for Fixed Canvas.
    var frame: OpenNotchRegionFrame?
    var groups: [OpenNotchGroup] = []
    var resolvedWidthFraction: Double { min(1, max(0.15, widthFraction ?? 1)) }
    var resolvedHeightFraction: Double { min(1, max(0.15, heightFraction ?? 1)) }
    func validated() throws -> OpenNotchRegion {
        var value = self
        if let widthFraction { guard widthFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.widthFraction = min(1, max(0.15, widthFraction)) }
        if let heightFraction { guard heightFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.heightFraction = min(1, max(0.15, heightFraction)) }
        value.frame = try frame?.validated()
        value.padding = try padding.validated(); value.groups = try groups.prefix(16).map { try $0.validated() }
        return value
    }
}

enum OpenNotchPreset: String, Codable, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case media = "Media"
    case productivity = "Productivity"
    case systemMonitor = "System Monitor"
    case focus = "Focus"
    case developer = "Developer"
    case informationDense = "Information Dense"
    case showcase = "Showcase"
    case pixelPal = "Pixel Pal"
    case custom = "Custom"
    var id: String { rawValue }
}

struct OpenNotchAppearance: Codable, Equatable {
    // nil values inherit the existing workspace appearance, preserving old layouts exactly.
    var background: BackgroundKind?
    var solidColor: WidgetColor?
    var gradientStartColor: WidgetColor?
    var gradientEndColor: WidgetColor?
    var assetPath = ""
    var blur: Double?
    var saturation: Double?
    var brightness: Double?
    var contrast: Double?
    var glass: GlassOptions?
    var tintColor: WidgetColor?
    var tintOpacity: Double?
    var grain: Double?
    var warmth: Double?
    var borderColor: WidgetColor?
    var borderWidth: Double?
    var borderOpacity: Double?
    var innerHighlight: Double?
    // Explicit opt-in. Older layouts may contain shadow tuning values from the
    // previous slider-only UI; keeping this nil/false prevents that shadow from
    // unexpectedly appearing inside the Visual Workspace surface.
    var shadowEnabled: Bool?
    var shadowBlur: Double?
    var shadowOpacity: Double?
    var glow: Double?

    func baseAppearance(_ fallback: Appearance) -> Appearance {
        var value = fallback
        if let background { value.background = background }
        if let solidColor { value.solidColor = solidColor }
        if let gradientStartColor { value.gradientStartColor = gradientStartColor }
        if let gradientEndColor { value.gradientEndColor = gradientEndColor }
        if !assetPath.isEmpty { value.assetPath = assetPath }
        if let blur { value.blur = blur }
        if let saturation { value.saturation = saturation }
        if let brightness { value.brightness = brightness }
        if let glass {
            value.glass = glass.normalized()
        } else if (background ?? fallback.background) == .glass, let blur {
            // Preserve the old Visual Workspace "Glass blur" control as a frost migration.
            var migrated = value.glass
            migrated.frost = min(1, max(0, blur / 30))
            value.glass = migrated.normalized()
        }
        return value
    }
    func validated() throws -> OpenNotchAppearance {
        let values: [Double] = [
            blur ?? 0,
            saturation ?? 1,
            brightness ?? 0,
            contrast ?? 1,
            tintOpacity ?? 0,
            grain ?? 0,
            warmth ?? 0,
            borderWidth ?? 0,
            borderOpacity ?? 0,
            innerHighlight ?? 0,
            shadowBlur ?? 0,
            shadowOpacity ?? 0,
            glow ?? 0
        ]
        guard values.allSatisfy({ $0.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        if let blur { v.blur = min(30, max(0, blur)) }
        if let saturation { v.saturation = min(2.5, max(0, saturation)) }
        if let brightness { v.brightness = min(0.5, max(-0.5, brightness)) }
        if let contrast { v.contrast = min(2, max(0.5, contrast)) }
        if let tintOpacity { v.tintOpacity = min(0.5, max(0, tintOpacity)) }
        if let grain { v.grain = min(0.35, max(0, grain)) }
        if let warmth { v.warmth = min(1, max(-1, warmth)) }
        if let borderWidth { v.borderWidth = min(6, max(0, borderWidth)) }
        if let borderOpacity { v.borderOpacity = min(1, max(0, borderOpacity)) }
        if let innerHighlight { v.innerHighlight = min(0.5, max(0, innerHighlight)) }
        if let shadowBlur { v.shadowBlur = min(50, max(0, shadowBlur)) }
        if let shadowOpacity { v.shadowOpacity = min(0.7, max(0, shadowOpacity)) }
        if let glow { v.glow = min(0.5, max(0, glow)) }
        v.solidColor = try solidColor?.validated(); v.gradientStartColor = try gradientStartColor?.validated()
        v.gradientEndColor = try gradientEndColor?.validated(); v.tintColor = try tintColor?.validated(); v.borderColor = try borderColor?.validated()
        if let glass { v.glass = glass.normalized() }
        v.assetPath = String(assetPath.prefix(2048))
        return v
    }
}

struct OpenNotchLayout: Codable, Equatable {
    var version = 1
    var preset: OpenNotchPreset = .custom
    // Custom-workspace mode is intentionally independent from the legacy
    // opened-notch Fixed / Scroll / Pages setting.
    var contentMode: OpenNotchContentMode?
    var regions: [OpenNotchRegion] = []
    // Visual Workspace v2. Items live directly on a standard grid; regions/groups
    // remain only as a backwards-compatible migration source.
    var gridItems: [OpenNotchItem]?
    var gridColumns: Int?
    var gridRows: Int?
    var gridGap: Double?
    var gridCellHeight: Double?
    var gridPadding: OpenNotchInsets?
    // Relative track weights for left/center/right and top/middle/bottom.
    // Optional fields preserve the first custom-workspace archive format.
    var columnWeights: [Double]?
    var rowWeights: [Double]?
    var appearance = OpenNotchAppearance()

    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }
    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }
    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }
    var usesFreeformRegions: Bool { regions.contains { $0.frame != nil } }
    var resolvedGridColumns: Int { min(8, max(2, gridColumns ?? 4)) }
    var resolvedGridRows: Int { min(4, max(1, gridRows ?? 3)) }
    var resolvedGridGap: Double {
        let value = gridGap ?? 8
        return value.isFinite ? min(32, max(0, value)) : 8
    }
    var resolvedGridCellHeight: Double {
        let value = gridCellHeight ?? 104
        return value.isFinite ? min(320, max(56, value)) : 104
    }
    var resolvedGridPadding: OpenNotchInsets { gridPadding ?? OpenNotchInsets(top: 8, leading: 8, bottom: 8, trailing: 8) }
    var allItems: [OpenNotchItem] {
        Self.workspaceWidgetItems(gridItems ?? regions.flatMap(\.groups).flatMap(\.items))
    }
    var resolvedGridItems: [OpenNotchItem] {
        if let gridItems { return Self.workspaceWidgetItems(gridItems) }
        return Self.packedGridItems(
            from: Self.workspaceWidgetItems(regions.flatMap(\.groups).flatMap(\.items)),
            columns: resolvedGridColumns
        )
    }
    var requiredGridRows: Int {
        max(resolvedGridRows, resolvedGridItems.compactMap { item in
            item.gridPlacement.map { $0.row + $0.rowSpan }
        }.max() ?? 0)
    }

    mutating func materializeGridItems() {
        if let gridItems {
            self.gridItems = Self.workspaceWidgetItems(gridItems)
        } else {
            gridItems = resolvedGridItems
        }
        normalizeGridItems()
    }

    mutating func normalizeGridItems(pinnedID: UUID? = nil) {
        guard var items = gridItems else { return }
        items = Self.workspaceWidgetItems(items)
        let columns = resolvedGridColumns
        var occupied = Set<Int>()
        let ordered: [Int]
        if let pinnedID, let pinned = items.firstIndex(where: { $0.id == pinnedID }) {
            ordered = [pinned] + items.indices.filter { $0 != pinned }
        } else {
            ordered = Array(items.indices)
        }
        for index in ordered {
            let fallback = Self.defaultGridSpan(for: items[index])
            var placement = (items[index].gridPlacement ?? OpenNotchGridPlacement(columnSpan: fallback.columns, rowSpan: fallback.rows)).clamped(columns: columns)
            if items[index].module == .pet {
                let side = min(columns, HaloPixelPalLayout.squareSide(columns: placement.columnSpan, rows: placement.rowSpan))
                placement.columnSpan = side
                placement.rowSpan = side
                placement.column = min(max(0, columns - side), max(0, placement.column))
                placement.row = min(max(0, 4 - side), max(0, placement.row))
            }
            if !Self.canPlace(placement, columns: columns, occupied: occupied) {
                placement = Self.firstAvailablePlacement(columnSpan: placement.columnSpan, rowSpan: placement.rowSpan,
                                                         columns: columns, occupied: occupied)
            }
            items[index].gridPlacement = placement
            Self.mark(placement, columns: columns, occupied: &occupied)
        }
        gridItems = items
    }

    private static func workspaceWidgetItems(_ source: [OpenNotchItem]) -> [OpenNotchItem] {
        source.filter { $0.kind == .module && $0.module != nil }
    }

    private static func packedGridItems(from source: [OpenNotchItem], columns: Int) -> [OpenNotchItem] {
        var items = workspaceWidgetItems(source)
        var occupied = Set<Int>()
        for index in items.indices {
            let span = defaultGridSpan(for: items[index])
            let placement = firstAvailablePlacement(columnSpan: min(columns, span.columns), rowSpan: span.rows,
                                                    columns: columns, occupied: occupied)
            items[index].gridPlacement = placement
            mark(placement, columns: columns, occupied: &occupied)
        }
        return items
    }

    private static func defaultGridSpan(for item: OpenNotchItem) -> (columns: Int, rows: Int) {
        if let module = item.module {
            switch module {
            case .media, .calendar, .system: return (3, 2)
            case .pet: return (2, 2)
            case .shelf, .clipboard, .launcher, .activities, .notes: return (2, 2)
            case .clock, .timer, .audio, .capture, .stopwatch, .developer: return (2, 1)
            }
        }
        switch item.element {
        case .albumArt, .customImage, .customGIF: return (2, 2)
        case .playbackControls, .playbackProgress, .customText: return (2, 1)
        default: return (1, 1)
        }
    }

    private static func canPlace(_ placement: OpenNotchGridPlacement, columns: Int, occupied: Set<Int>) -> Bool {
        guard placement.column >= 0, placement.row >= 0,
              placement.column + placement.columnSpan <= columns,
              placement.row + placement.rowSpan <= 4 else { return false }
        for row in placement.row..<(placement.row + placement.rowSpan) {
            for column in placement.column..<(placement.column + placement.columnSpan) {
                if occupied.contains(row * 64 + column) { return false }
            }
        }
        return true
    }

    private static func mark(_ placement: OpenNotchGridPlacement, columns: Int, occupied: inout Set<Int>) {
        for row in placement.row..<(placement.row + placement.rowSpan) {
            for column in placement.column..<min(columns, placement.column + placement.columnSpan) {
                occupied.insert(row * 64 + column)
            }
        }
    }

    private static func firstAvailablePlacement(columnSpan: Int, rowSpan: Int, columns: Int,
                                                occupied: Set<Int>) -> OpenNotchGridPlacement {
        let span = min(columns, max(1, columnSpan))
        for row in 0..<4 {
            for column in 0...max(0, columns - span) {
                let candidate = OpenNotchGridPlacement(column: column, row: row, columnSpan: span, rowSpan: max(1, rowSpan))
                if canPlace(candidate, columns: columns, occupied: occupied) { return candidate }
            }
        }
        let boundedRows = min(4, max(1, rowSpan))
        return OpenNotchGridPlacement(column: 0, row: max(0, 4 - boundedRows), columnSpan: span, rowSpan: boundedRows)
    }

    private static func resolvedTrackWeights(_ saved: [Double]?) -> [Double] {
        var values = Array((saved ?? []).prefix(3))
        while values.count < 3 { values.append(1) }
        return values.map { value in value.isFinite ? min(6, max(0.1, value)) : 1 }
    }
    mutating func setColumnWeight(_ value: Double, at index: Int) {
        guard (0..<3).contains(index) else { return }
        var values = resolvedColumnWeights; values[index] = min(6, max(0.1, value)); columnWeights = values
    }
    mutating func setRowWeight(_ value: Double, at index: Int) {
        guard (0..<3).contains(index) else { return }
        var values = resolvedRowWeights; values[index] = min(6, max(0.1, value)); rowWeights = values
    }

    // Converts the legacy collapsed 3x3 tracks into normalized freeform frames.
    // This only happens when a user starts editing region geometry, so old profiles
    // keep their exact legacy behavior until then.
    mutating func materializeRegionFrames() {
        guard !regions.isEmpty else { return }
        let occupiedColumns = (0..<3).map { column in regions.contains { Self.columnIndex($0.placement) == column } }
        let occupiedRows = (0..<3).map { row in regions.contains { Self.rowIndex($0.placement) == row } }
        let columnTracks = Self.normalizedTracks(weights: resolvedColumnWeights, occupied: occupiedColumns)
        let rowTracks = Self.normalizedTracks(weights: resolvedRowWeights, occupied: occupiedRows)

        for index in regions.indices where regions[index].frame == nil {
            let region = regions[index]
            let column = columnTracks[Self.columnIndex(region.placement)]
            let row = rowTracks[Self.rowIndex(region.placement)]
            let width = column.length * region.resolvedWidthFraction
            let height = row.length * region.resolvedHeightFraction
            let x = column.start + (column.length - width) * Self.horizontalAnchor(region.placement)
            let y = row.start + (row.length - height) * Self.verticalAnchor(region.placement)
            regions[index].frame = OpenNotchRegionFrame(x: x, y: y, width: width, height: height).clamped()
        }
    }

    private static func normalizedTracks(weights: [Double], occupied: [Bool]) -> [(start: Double, length: Double)] {
        let active = zip(weights, occupied).map { max(0, $1 ? $0 : 0) }
        let total = active.reduce(0, +)
        guard total > 0 else { return [(0, 1.0 / 3), (1.0 / 3, 1.0 / 3), (2.0 / 3, 1.0 / 3)] }
        var cursor = 0.0
        return active.map { weight in
            let length = weight > 0 ? weight / total : 0
            defer { cursor += length }
            return (cursor, length)
        }
    }

    private static func rowIndex(_ placement: OpenNotchRegionPlacement) -> Int {
        switch placement { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 1; case .bottomLeft, .bottomCenter, .bottomRight: return 2 }
    }
    private static func columnIndex(_ placement: OpenNotchRegionPlacement) -> Int {
        switch placement { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 1; case .topRight, .middleRight, .bottomRight: return 2 }
    }
    private static func horizontalAnchor(_ placement: OpenNotchRegionPlacement) -> Double {
        switch placement { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 0.5; case .topRight, .middleRight, .bottomRight: return 1 }
    }
    private static func verticalAnchor(_ placement: OpenNotchRegionPlacement) -> Double {
        switch placement { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 0.5; case .bottomLeft, .bottomCenter, .bottomRight: return 1 }
    }

    static func migrated(modules: [ModuleID], horizontal: Bool) -> OpenNotchLayout {
        var group = OpenNotchGroup(name: "Legacy widgets", axis: horizontal ? .horizontal : .vertical,
                                   alignment: .stretch, spacing: 12, padding: OpenNotchInsets(),
                                   items: modules.map { .moduleItem($0) })
        if modules.isEmpty { group.items = [.moduleItem(.clock, presentation: .expanded, priority: .high)] }
        return OpenNotchLayout(preset: .custom,
            regions: [OpenNotchRegion(placement: .middleCenter, padding: OpenNotchInsets(), groups: [group])])
    }

    static func made(_ preset: OpenNotchPreset) -> OpenNotchLayout {
        func item(_ module: ModuleID, _ column: Int, _ row: Int, _ columns: Int, _ rows: Int,
                  _ presentation: OpenNotchPresentation = .automatic,
                  _ priority: OpenNotchPriority = .normal) -> OpenNotchItem {
            var value = OpenNotchItem.moduleItem(module, presentation: presentation, priority: priority)
            value.gridPlacement = OpenNotchGridPlacement(column: column, row: row, columnSpan: columns, rowSpan: rows)
            return value
        }
        func grid(_ columns: Int = 8, _ rows: Int = 4, cellHeight: Double = 96, gap: Double = 9,
                  _ items: [OpenNotchItem]) -> OpenNotchLayout {
            OpenNotchLayout(preset: preset, regions: [], gridItems: items,
                            gridColumns: columns, gridRows: rows, gridGap: gap,
                            gridCellHeight: cellHeight,
                            gridPadding: OpenNotchInsets(top: 10, leading: 12, bottom: 12, trailing: 12))
        }

        switch preset {
        case .minimal:
            // Intentionally sparse: one large clock floating in the center instead of a generic stack.
            return grid(8, 4, cellHeight: 92, gap: 10, [
                item(.clock, 2, 1, 4, 2, .expanded, .alwaysVisible)
            ])

        case .media:
            // Hero player with a dedicated right-side audio/activity rail.
            return grid(8, 4, cellHeight: 104, gap: 10, [
                item(.media,      0, 0, 6, 4, .expanded, .alwaysVisible),
                item(.audio,      6, 0, 2, 2, .expanded, .high),
                item(.activities, 6, 2, 2, 2, .regular,  .normal)
            ])

        case .productivity:
            // Calendar dominates the canvas; notes/timer sit in a purposeful work rail.
            return grid(8, 4, cellHeight: 102, gap: 9, [
                item(.calendar, 0, 0, 5, 3, .expanded, .alwaysVisible),
                item(.notes,    5, 0, 3, 2, .expanded, .high),
                item(.timer,    5, 2, 3, 1, .compact,  .high),
                item(.shelf,    0, 3, 5, 1, .compact,  .normal),
                item(.launcher, 5, 3, 3, 1, .compact,  .normal)
            ])

        case .systemMonitor:
            // Large telemetry dashboard plus a narrow operational status rail.
            return grid(8, 4, cellHeight: 100, gap: 8, [
                item(.system,     0, 0, 5, 4, .expanded, .alwaysVisible),
                item(.activities, 5, 0, 3, 2, .expanded, .high),
                item(.audio,      5, 2, 3, 1, .compact,  .normal),
                item(.clock,      5, 3, 3, 1, .compact,  .high)
            ])

        case .focus:
            // Timer and writing surface get almost all the visual weight; supporting state is quiet.
            return grid(8, 4, cellHeight: 104, gap: 10, [
                item(.timer,      0, 0, 5, 3, .expanded, .alwaysVisible),
                item(.notes,      5, 0, 3, 3, .expanded, .high),
                item(.clock,      0, 3, 4, 1, .compact,  .high),
                item(.activities, 4, 3, 4, 1, .compact,  .low)
            ])

        case .developer:
            // Four equally strong quadrants: observe, launch, capture and jot context.
            return grid(8, 4, cellHeight: 98, gap: 8, [
                item(.system,   0, 0, 4, 2, .expanded, .high),
                item(.launcher, 4, 0, 4, 2, .expanded, .high),
                item(.capture,  0, 2, 4, 2, .expanded, .high),
                item(.notes,    4, 2, 4, 2, .expanded, .normal)
            ])

        case .informationDense:
            // Maximum-density composition inside Halo's canonical 8×4 workspace.
            return grid(8, 4, cellHeight: 92, gap: 7, [
                item(.clock,      0, 0, 2, 1, .compact, .high),
                item(.timer,      2, 0, 2, 1, .compact, .high),
                item(.audio,      4, 0, 2, 1, .compact, .normal),
                item(.activities, 6, 0, 2, 1, .compact, .normal),
                item(.calendar,   0, 1, 4, 2, .expanded, .high),
                item(.system,     4, 1, 4, 2, .expanded, .high),
                item(.clipboard,  0, 3, 2, 1, .compact, .normal),
                item(.shelf,      2, 3, 2, 1, .compact, .normal),
                item(.launcher,   4, 3, 2, 1, .compact, .normal),
                item(.notes,      6, 3, 2, 1, .compact, .normal)
            ])

        case .showcase:
            // Asymmetric demo composition: one cinematic hero with a compact feature rail.
            return grid(8, 4, cellHeight: 108, gap: 10, [
                item(.media,      0, 0, 6, 4, .expanded, .alwaysVisible),
                item(.clock,      6, 0, 2, 1, .compact,  .high),
                item(.audio,      6, 1, 2, 1, .compact,  .high),
                item(.activities, 6, 2, 2, 1, .compact,  .normal),
                item(.capture,    6, 3, 2, 1, .compact,  .normal)
            ])

        case .pixelPal:
            // Pixel Pal is the visual hero: a full 4×4 square on the left with two
            // equally sized companion widgets stacked on the right.
            return grid(8, 4, cellHeight: 104, gap: 10, [
                item(.pet,   0, 0, 4, 4, .expanded, .alwaysVisible),
                item(.clock, 4, 0, 4, 2, .expanded, .high),
                item(.media, 4, 2, 4, 2, .expanded, .high)
            ])

        case .custom:
            return migrated(modules: ModuleID.allCases.filter { $0 != .developer }, horizontal: false)
        }
    }

    func validated() throws -> OpenNotchLayout {
        guard version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        if let columnWeights { guard columnWeights.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }; value.columnWeights = Self.resolvedTrackWeights(columnWeights) }
        if let rowWeights { guard rowWeights.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }; value.rowWeights = Self.resolvedTrackWeights(rowWeights) }
        value.regions = try regions.prefix(9).map { try $0.validated() }
        value.gridItems = try gridItems.map { try $0.prefix(80).map { try $0.validated() } }
        if let gridColumns { value.gridColumns = min(8, max(2, gridColumns)) }
        if let gridRows { value.gridRows = min(4, max(1, gridRows)) }
        if let gridGap { guard gridGap.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.gridGap = min(32, max(0, gridGap)) }
        if let gridCellHeight { guard gridCellHeight.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.gridCellHeight = min(320, max(56, gridCellHeight)) }
        value.gridPadding = try gridPadding?.validated()
        value.appearance = try appearance.validated()
        if value.gridItems != nil { value.normalizeGridItems() }
        return value
    }
}

struct ThemeArchive: Codable {
    var version = 2
    var theme: Theme
    var layout: WorkspaceLayout
    func validated() throws -> ThemeArchive {
        guard version == 2 else { throw CocoaError(.fileReadCorruptFile) }
        var archive = self; archive.theme = try theme.validated()
        var appearance = layout.appearance
        guard [appearance.blur, appearance.saturation, appearance.brightness, appearance.expandedHeight, appearance.compactWidth, appearance.spacing].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        appearance.blur = min(20, max(0, appearance.blur))
        appearance.saturation = min(2, max(0, appearance.saturation))
        appearance.brightness = min(0.5, max(-0.5, appearance.brightness))
        appearance.expandedHeight = min(1100, max(280, appearance.expandedHeight))
        appearance.compactWidth = min(640, max(16, appearance.compactWidth))
        appearance.surface = try appearance.surface.validated()
        appearance.spacing = min(48, max(4, appearance.spacing))
        appearance.solidColor = try appearance.solidColor?.validated()
        appearance.gradientStartColor = try appearance.gradientStartColor?.validated()
        appearance.gradientEndColor = try appearance.gradientEndColor?.validated()
        appearance.assetPath = ""
        if appearance.background == .video || appearance.background == .image { appearance.background = .gradient }
        appearance.grain = try appearance.grain?.validated()
        appearance.backgroundSchedule = try appearance.backgroundSchedule?.map { entry in
            guard entry.blur.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            var v = entry; v.blur = min(20, max(0, v.blur)); v.grain = try v.grain.validated(); v.assetPath = ""
            if v.kind == .image || v.kind == .video { v.kind = .gradient }
            return v
        }
        if let height = layout.horizontalHeight {
            guard height.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            archive.layout.horizontalHeight = min(1100, max(200, height))
        }
        if let value = layout.openHorizontalPadding {
            guard value.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            archive.layout.openHorizontalPadding = min(72, max(8, value))
        }
        if let value = layout.openVerticalPadding {
            guard value.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            archive.layout.openVerticalPadding = min(72, max(8, value))
        }
        if let columns = layout.openFixedColumns {
            archive.layout.openFixedColumns = min(4, max(1, columns))
        }
        archive.layout.appearance = appearance
        archive.layout.order = layout.normalizedOrder()
        archive.layout.widgets = try layout.widgets?.mapValues { try $0.validated() }
        if var opened = try layout.openNotch?.validated() {
            // Theme archives cannot safely carry machine-local image/video paths.
            opened.appearance.assetPath = ""
            if opened.appearance.background == .image || opened.appearance.background == .video { opened.appearance.background = .gradient }
            archive.layout.openNotch = opened
        }
        archive.layout.closedNotch = try layout.closedNotch?.validated()
        archive.layout.contextMusic = try layout.contextMusic?.validated()
        archive.layout.hud = try layout.hud?.validated()
        return archive
    }
}
struct Profile: Codable, Identifiable {
    var icon: String?
    var description: String?
    var id = UUID()
    var name: String
    var theme = Theme()
    var layout = WorkspaceLayout()
    static var presets: [Profile] {
        [("Default", Set<ModuleID>([.clock, .timer, .shelf, .system, .launcher])),
         ("Minimal", [.clock]), ("Work", [.calendar, .timer, .shelf, .notes]),
         ("Coding", [.notes, .system, .timer, .shelf]), ("Media", [.media, .audio]),
         ("Gaming", [.system, .audio]), ("Presentation", [.clock, .timer]),
         ("Battery Saver", [.clock, .system])].map { name, modules in
            var p = Profile(name: name); p.layout.enabled = modules
            if name == "Battery Saver" { p.theme.animations = false; p.layout.appearance.background = .solid }
            return p
        }
    }
}
enum RuleTrigger: String, Codable, CaseIterable { case activeApp, batteryBelow, charging, displayCount, hour }
struct AutomationRule: Codable, Identifiable {
    var id = UUID()
    var enabled = true
    var trigger: RuleTrigger = .activeApp
    var value = "com.apple.dt.Xcode"
    var profileID: UUID
    func matches(app: String, battery: Int?, charging: Bool, displays: Int, hour: Int) -> Bool {
        guard enabled else { return false }
        switch trigger {
        case .activeApp: return app == value
        case .batteryBelow: return battery.map { $0 < (Int(value) ?? 0) } ?? false
        case .charging: return charging == (value == "true")
        case .displayCount: return displays == Int(value)
        case .hour: return hour == Int(value)
        }
    }
}
struct WorkspaceSettings: Codable {
    /// Optional fields keep settings created before Notch Mode fully backwards compatible.
    var notchMode: HaloNotchMode?
    var simpleNotch: SimpleNotchSettings?
    var resolvedNotchMode: HaloNotchMode { notchMode ?? .advanced }
    var resolvedSimpleNotch: SimpleNotchSettings { (simpleNotch ?? SimpleNotchSettings()).normalized() }

    var automaticMedia: Bool?
    var profileSchedules: [ProfileSchedule]?
    var version = 1
    var layout = WorkspaceLayout()
    var profiles = Profile.presets
    var rules: [AutomationRule] = []
    var displays: [DisplayOverride] = []
    var clipboardEnabled = false
    var clipboardExcludedApps = "com.1password.1password,com.agilebits.onepassword7,com.apple.keychainaccess,com.bitwarden.desktop"
    var shelfRetentionMinutes = 0
    var persistShelf = false
    var mediaApp = "com.apple.Music"
    var notes = ""
    var hotkeyEnabled = true
    var hotkeyCode: UInt32 = 49
    var hotkeyModifiers: UInt32 = 2304
}
enum LiveActivityKind: String, Codable, CaseIterable {
    case generic
    case notification
    case message
    case call
    case timer
    case progress
    case download
    case calendar
    case bluetooth
    case custom
}

enum LiveActivityState: String, Codable, CaseIterable {
    case incoming
    case active
    case ended
}

enum LiveActivityActionKind: String, Codable {
    case press
    case textReply
}

enum LiveActivityActionRole: String, Codable {
    case normal
    case primary
    case destructive
}

struct LiveActivityAction: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var symbolName: String? = nil
    var kind: LiveActivityActionKind = .press
    var role: LiveActivityActionRole = .normal

    // The action descriptor is serializable; source-specific runtime objects such as
    // AXUIElement never leak into the Live Activity model.
    var targetLabel: String
    var inputPlaceholder: String? = nil
}

enum LiveActivityActionFactory {
    static func actions(fromButtonLabels labels: [String], kind: LiveActivityKind) -> [LiveActivityAction] {
        var seen = Set<String>()
        var result: [LiveActivityAction] = []

        for raw in labels {
            let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let normalized = title.lowercased()
            guard !["options", "show", "more", "less", "actions"].contains(normalized) else { continue }
            guard seen.insert(normalized).inserted else { continue }

            let actionKind: LiveActivityActionKind =
                normalized == "reply" || normalized.hasPrefix("reply ") ? .textReply : .press

            let role: LiveActivityActionRole
            if ["accept", "answer", "join"].contains(where: { normalized == $0 || normalized.hasPrefix($0 + " ") }) {
                role = .primary
            } else if ["decline", "reject", "end", "hang up", "clear", "close", "dismiss"].contains(where: {
                normalized == $0 || normalized.hasPrefix($0 + " ")
            }) {
                role = .destructive
            } else if actionKind == .textReply || normalized.contains("mark as read") {
                role = .primary
            } else {
                role = .normal
            }

            let symbol: String
            if actionKind == .textReply {
                symbol = "arrowshape.turn.up.left.fill"
            } else if normalized.contains("mark as read") || normalized == "read" {
                symbol = "checkmark.circle.fill"
            } else if normalized.contains("mute") {
                symbol = "mic.slash.fill"
            } else if normalized.contains("decline") || normalized.contains("reject") ||
                        normalized.contains("hang up") || normalized == "end" {
                symbol = "phone.down.fill"
            } else if normalized.contains("accept") || normalized.contains("answer") || normalized.contains("join") {
                symbol = "phone.fill"
            } else if normalized.contains("clear") || normalized.contains("close") || normalized.contains("dismiss") {
                symbol = "xmark.circle.fill"
            } else {
                symbol = kind == .call ? "phone.fill" : "bolt.fill"
            }

            let slug = normalized
                .unicodeScalars
                .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
                .reduce(into: "") { partial, character in
                    if character != "-" || partial.last != "-" { partial.append(character) }
                }
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

            result.append(LiveActivityAction(
                id: "system.ax." + (slug.isEmpty ? "action" : slug),
                title: title,
                symbolName: symbol,
                kind: actionKind,
                role: role,
                targetLabel: title,
                inputPlaceholder: actionKind == .textReply ? "Reply…" : nil
            ))

            if result.count == 6 { break }
        }

        return result
    }
}

enum LiveActivityClassifier {
    private static let messageSources = [
        "messages", "whatsapp", "telegram", "signal", "discord",
        "slack", "microsoft teams", "messenger"
    ]

    static func kind(sourceName: String?, title: String, detail: String) -> LiveActivityKind {
        let combined = [sourceName, title, detail]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        if combined.contains("incoming call") ||
            combined.contains("video call") ||
            combined.contains("audio call") ||
            sourceName?.caseInsensitiveCompare("FaceTime") == .orderedSame {
            return .call
        }

        if let sourceName,
           messageSources.contains(where: { sourceName.localizedCaseInsensitiveContains($0) }) {
            return .message
        }

        return .notification
    }
}

struct LiveActivity: Identifiable, Codable {
    var bluetoothDeviceVisual: BluetoothDeviceVisual? = nil
    var id = UUID()

    // Optional additive metadata keeps older in-memory/persisted payloads decodable while
    // allowing system and partner sources to update one stable activity over time.
    var externalID: String? = nil
    var sourceBundleIdentifier: String? = nil
    var sourceName: String? = nil
    var kind: LiveActivityKind? = nil
    var state: LiveActivityState? = nil
    var symbolName: String? = nil

    var title: String
    var detail = ""
    var progress: Double?

    var startedAt: Date? = nil
    var updatedAt: Date? = nil
    var expiresAt: Date? = nil
    var priority: Double? = nil
    var persistent: Bool? = nil
    var actions: [LiveActivityAction]? = nil

    var created = Date()

    var resolvedKind: LiveActivityKind { kind ?? .generic }
    var resolvedState: LiveActivityState { state ?? .active }
    var resolvedUpdatedAt: Date { updatedAt ?? created }
    var resolvedPriority: Double { min(100, max(0, priority ?? 50)) }
    var isPersistent: Bool { persistent ?? false }
    var resolvedActions: [LiveActivityAction] { actions ?? [] }

    var resolvedSymbolName: String {
        if let symbolName, !symbolName.isEmpty { return symbolName }
        switch resolvedKind {
        case .notification: return "bell.fill"
        case .message: return "message.fill"
        case .call: return "phone.fill"
        case .timer: return "timer"
        case .progress: return "chart.bar.fill"
        case .download: return "arrow.down.circle.fill"
        case .calendar: return "calendar"
        case .bluetooth: return "wave.3.right"
        case .generic, .custom: return "waveform.path"
        }
    }
}
enum LiveActivitySelection {
    static func primary(
        in activities: [LiveActivity],
        now: Date = Date(),
        excluding excludedKinds: Set<LiveActivityKind> = []
    ) -> LiveActivity? {
        activities
            .filter { activity in
                guard !excludedKinds.contains(activity.resolvedKind) else { return false }
                if activity.isPersistent {
                    return activity.resolvedState != .ended || (activity.expiresAt ?? .distantFuture) > now
                }
                return (activity.expiresAt ?? activity.created.addingTimeInterval(12)) > now
            }
            .sorted {
                if $0.resolvedPriority != $1.resolvedPriority {
                    return $0.resolvedPriority > $1.resolvedPriority
                }
                return $0.resolvedUpdatedAt > $1.resolvedUpdatedAt
            }
            .first
    }
}

protocol LiveActivityProvider { var activities: [LiveActivity] { get } }
struct PluginCommand: Codable, Identifiable {
    var id: String
    var title: String
    var url: String
}
struct PluginManifest: Codable, Identifiable {
    var version: Int
    var id: String
    var name: String
    var permissions: [String]
    var commands: [PluginCommand]
    func validated() throws -> PluginManifest {
        guard version == 1, !id.isEmpty, id.count <= 120, !name.isEmpty,
              commands.count <= 50, Set(commands.map(\.id)).count == commands.count,
              permissions.allSatisfy({ $0 == "openURL" }) else { throw CocoaError(.fileReadCorruptFile) }
        for command in commands {
            guard !command.title.isEmpty, let url = URL(string: command.url),
                  ["https", "shortcuts"].contains(url.scheme?.lowercased() ?? ""),
                  permissions.contains("openURL") else { throw CocoaError(.fileReadCorruptFile) }
        }
        return self
    }
}
enum CommandSearch {
    static func matches(_ query: String, in candidate: String) -> Bool {
        var remaining = candidate.lowercased()[...]
        for character in query.lowercased() where !character.isWhitespace {
            guard let index = remaining.firstIndex(of: character) else { return false }
            remaining = remaining[remaining.index(after: index)...]
        }
        return true
    }
}

enum ContextMusicLayoutMode: String, Codable, CaseIterable, Identifiable {
    case hero, split, compact, minimal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hero: return "Hero"
        case .split: return "Split"
        case .compact: return "Compact"
        case .minimal: return "Minimal"
        }
    }
}

enum ContextArtworkPresentation: String, Codable, CaseIterable, Identifiable {
    case none, cover, vinyl
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ContextContentAlignment: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ContextLyricTransition: String, Codable, CaseIterable, Identifiable {
    case none, fade, slide, lift, scale, blur

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .fade: return "Fade"
        case .slide: return "Slide"
        case .lift: return "Lift"
        case .scale: return "Scale"
        case .blur: return "Blur + fade"
        }
    }
}

struct ContextMusicOptions: Codable, Equatable {
    var enabled = false
    var showArtwork = true
    var showTitle = true
    var showArtist = true
    var showControls = true
    var showVisualizer = false
    var artworkSize = 100.0
    var fontSize = 22.0
    var background: BackgroundKind = .glass
    var backgroundOpacity = 0.5
    var textColor = WidgetColor.white
    var layoutMode: ContextMusicLayoutMode?
    var foregroundArtwork: ContextArtworkPresentation?
    var artworkBackground: Bool?
    var artworkBackgroundBlur: Double?
    var artworkBackgroundDim: Double?
    var contentAlignment: ContextContentAlignment?
    var spacing: Double?
    var cornerRadius: Double?
    var controlSize: Double?
    var vinylRPM: Double?
    var showLyrics: Bool?
    var lyricDisplay: LyricDisplayMode?
    var lyricSyncOffset: Double?
    var lyricsOnline: Bool?
    var lyricFontSize: Double?
    var lyricTransition: ContextLyricTransition?
    var lyricTransitionDuration: Double?
    var visualizerStyle: PlaybackAnimation?
    var songTextColors: Bool?
    var songControlColors: Bool?
    var songVisualizerColors: Bool?
    var songBackgroundColors: Bool?
    var readableSongForegroundColors: Bool?
    var adaptiveElementColors: Bool?
    var adaptiveColorDistribution: AudioCIColorDistribution?
    var horizontalMargin: Double?
    var topMargin: Double?
    var bottomMargin: Double?
    var resolvedLayoutMode: ContextMusicLayoutMode { layoutMode ?? .hero }
    var resolvedForegroundArtwork: ContextArtworkPresentation { foregroundArtwork ?? (showArtwork ? .cover : .none) }
    var usesArtworkBackground: Bool { artworkBackground ?? false }
    var resolvedArtworkBackgroundBlur: Double { min(30, max(0, artworkBackgroundBlur ?? 12)) }
    var resolvedArtworkBackgroundDim: Double { min(0.9, max(0, artworkBackgroundDim ?? 0.38)) }
    var resolvedContentAlignment: ContextContentAlignment { contentAlignment ?? .center }
    var resolvedSpacing: Double { min(32, max(4, spacing ?? 12)) }
    var resolvedCornerRadius: Double { min(48, max(0, cornerRadius ?? 18)) }
    var resolvedControlSize: Double { min(42, max(14, controlSize ?? 24)) }
    var resolvedVinylRPM: Double { min(45, max(1, vinylRPM ?? 8)) }
    var showsLyrics: Bool { showLyrics ?? false }
    var resolvedLyricDisplay: LyricDisplayMode { lyricDisplay ?? .line }
    var resolvedLyricSyncOffset: Double { min(5, max(-5, lyricSyncOffset ?? 0)) }
    var usesOnlineLyrics: Bool { lyricsOnline ?? true }
    var resolvedLyricFontSize: Double { min(44, max(10, lyricFontSize ?? max(14, fontSize * 0.72))) }
    var resolvedLyricTransition: ContextLyricTransition { lyricTransition ?? .lift }
    var resolvedLyricTransitionDuration: Double { min(1.2, max(0.08, lyricTransitionDuration ?? 0.28)) }
    var resolvedVisualizerStyle: PlaybackAnimation { visualizerStyle ?? .bars }
    var usesSongTextColors: Bool { songTextColors ?? false }
    var usesSongControlColors: Bool { songControlColors ?? false }
    var usesSongVisualizerColors: Bool { songVisualizerColors ?? true }
    var usesSongBackgroundColors: Bool { songBackgroundColors ?? false }
    var usesReadableSongForegroundColors: Bool { readableSongForegroundColors ?? false }
    var usesAdaptiveElementColors: Bool { adaptiveElementColors ?? false }
    var resolvedAdaptiveColorDistribution: AudioCIColorDistribution { adaptiveColorDistribution ?? .automatic }
    var resolvedHorizontalMargin: Double { min(120, max(0, horizontalMargin ?? max(18, resolvedSpacing * 1.25))) }
    var resolvedTopMargin: Double { min(160, max(0, topMargin ?? 0)) }
    var resolvedBottomMargin: Double { min(120, max(0, bottomMargin ?? max(10, resolvedSpacing * 0.55))) }
    func validated() throws -> ContextMusicOptions {
        let numericValues: [Double] = [
            artworkSize,
            fontSize,
            backgroundOpacity,
            artworkBackgroundBlur ?? 12,
            artworkBackgroundDim ?? 0.38,
            spacing ?? 12,
            cornerRadius ?? 18,
            controlSize ?? 24,
            vinylRPM ?? 8,
            lyricSyncOffset ?? 0,
            lyricFontSize ?? 16,
            lyricTransitionDuration ?? 0.28,
            horizontalMargin ?? 18,
            topMargin ?? 0,
            bottomMargin ?? 10
        ]
        guard numericValues.allSatisfy({ $0.isFinite }) else { throw CocoaError(.fileReadCorruptFile) }
        var result = self
        result.artworkSize = min(240, max(32, artworkSize))
        result.fontSize = min(48, max(12, fontSize))
        result.backgroundOpacity = min(1, max(0, backgroundOpacity))
        result.textColor = try textColor.validated()
        if ![BackgroundKind.glass, .gradient, .solid].contains(background) { result.background = .glass }
        if layoutMode != nil { result.layoutMode = resolvedLayoutMode }
        if foregroundArtwork != nil { result.foregroundArtwork = resolvedForegroundArtwork }
        if artworkBackgroundBlur != nil { result.artworkBackgroundBlur = resolvedArtworkBackgroundBlur }
        if artworkBackgroundDim != nil { result.artworkBackgroundDim = resolvedArtworkBackgroundDim }
        if contentAlignment != nil { result.contentAlignment = resolvedContentAlignment }
        if spacing != nil { result.spacing = resolvedSpacing }
        if cornerRadius != nil { result.cornerRadius = resolvedCornerRadius }
        if controlSize != nil { result.controlSize = resolvedControlSize }
        if vinylRPM != nil { result.vinylRPM = resolvedVinylRPM }
        if lyricSyncOffset != nil { result.lyricSyncOffset = resolvedLyricSyncOffset }
        if lyricFontSize != nil { result.lyricFontSize = resolvedLyricFontSize }
        if lyricTransition != nil { result.lyricTransition = resolvedLyricTransition }
        if lyricTransitionDuration != nil { result.lyricTransitionDuration = resolvedLyricTransitionDuration }
        if horizontalMargin != nil { result.horizontalMargin = resolvedHorizontalMargin }
        if topMargin != nil { result.topMargin = resolvedTopMargin }
        if bottomMargin != nil { result.bottomMargin = resolvedBottomMargin }
        return result
    }
}

// MARK: - Halo HUD Engine model

/// Stable event identifiers. Providers translate platform events into these values; renderers never
/// need to know which macOS API produced them.
enum HaloHUDEventKind: String, Codable, CaseIterable, Identifiable {
    case volume, mute, displayBrightness, keyboardBrightness
    case microphoneState, microphoneMute, audioInputChanged, audioOutputChanged, audioDeviceConnected
    case batteryStatus, chargingState, powerSourceChanged, wifiState, bluetoothState, focusState
    case capsLock, screenshotCaptured, screenRecordingState, cameraActivity, microphoneActivity, mediaChanged
    var id: String { rawValue }
    var title: String {
        switch self {
        case .volume: return "Volume"
        case .mute: return "Mute / Unmute"
        case .displayBrightness: return "Display Brightness"
        case .keyboardBrightness: return "Keyboard Brightness"
        case .microphoneState: return "Microphone State"
        case .microphoneMute: return "Microphone Mute"
        case .audioInputChanged: return "Audio Input Changed"
        case .audioOutputChanged: return "Audio Output Changed"
        case .audioDeviceConnected: return "Audio Device Connection"
        case .batteryStatus: return "Battery Status"
        case .chargingState: return "Charging Started / Stopped"
        case .powerSourceChanged: return "Power Source Changed"
        case .wifiState: return "Wi-Fi State"
        case .bluetoothState: return "Bluetooth State"
        case .focusState: return "Focus / Do Not Disturb"
        case .capsLock: return "Caps Lock"
        case .screenshotCaptured: return "Screenshot Captured"
        case .screenRecordingState: return "Screen Recording"
        case .cameraActivity: return "Camera Activity"
        case .microphoneActivity: return "Microphone Activity"
        case .mediaChanged: return "Media Changed"
        }
    }
    var symbol: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .mute: return "speaker.slash.fill"
        case .displayBrightness: return "sun.max.fill"
        case .keyboardBrightness: return "keyboard.fill"
        case .microphoneState, .microphoneMute, .microphoneActivity: return "mic.fill"
        case .audioInputChanged: return "mic.and.signal.meter.fill"
        case .audioOutputChanged, .audioDeviceConnected: return "airpodspro"
        case .batteryStatus: return "battery.75percent"
        case .chargingState: return "bolt.fill"
        case .powerSourceChanged: return "powerplug.fill"
        case .wifiState: return "wifi"
        case .bluetoothState: return "wave.3.right"
        case .focusState: return "moon.fill"
        case .capsLock: return "capslock.fill"
        case .screenshotCaptured: return "camera.viewfinder"
        case .screenRecordingState: return "record.circle"
        case .cameraActivity: return "video.fill"
        case .mediaChanged: return "music.note"
        }
    }
    /// Only these event providers are currently connected to Halo's safe replacement/observer path.
    var providerStatus: HaloHUDProviderStatus {
        switch self {
        case .volume, .mute, .displayBrightness, .keyboardBrightness: return .available
        case .batteryStatus, .chargingState, .powerSourceChanged, .mediaChanged, .capsLock: return .observable
        default: return .architected
        }
    }
}

enum HaloHUDProviderStatus: String, Codable {
    case available, observable, architected
    var title: String {
        switch self {
        case .available: return "Available"
        case .observable: return "Observer-capable"
        case .architected: return "Provider not connected"
        }
    }
}

enum HaloHUDPresentationTarget: String, Codable, CaseIterable, Identifiable {
    case notch, floating, screenEdge, menuBar, nearCursor, disabled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notch: return "Notch"
        case .floating: return "Floating HUD"
        case .screenEdge: return "Screen Edge"
        case .menuBar: return "Menu Bar"
        case .nearCursor: return "Near Cursor"
        case .disabled: return "Disabled"
        }
    }
}
enum HaloHUDNotchSide: String, Codable, CaseIterable, Identifiable { case left, right, automatic, full; var id: String { rawValue }; var title: String { rawValue == "full" ? "Full Notch" : rawValue.capitalized } }
enum HaloHUDCollisionBehavior: String, Codable, CaseIterable, Identifiable { case replace, push, overlay, queue, showExternally; var id: String { rawValue }; var title: String { rawValue == "showExternally" ? "Show Externally" : rawValue.capitalized } }
enum HaloHUDLayoutStyle: String, Codable, CaseIterable, Identifiable { case horizontal, vertical, compact; var id: String { rawValue }; var title: String { rawValue.capitalized } }
enum HaloHUDProgressStyle: String, Codable, CaseIterable, Identifiable {
    case bar, segmentedBar, ring, arc, dots, gauge, glow, numberOnly, iconFill, minimalLine, wave
    var id: String { rawValue }
    var title: String {
        switch self {
        case .segmentedBar: return "Segmented Bar"
        case .numberOnly: return "Number Only"
        case .iconFill: return "Icon Fill"
        case .minimalLine: return "Minimal Line"
        default: return rawValue.capitalized
        }
    }
}
enum HaloHUDBackgroundStyle: String, Codable, CaseIterable, Identifiable { case glass, solid, gradient, clear, image, video; var id: String { rawValue }; var title: String { rawValue.capitalized } }
enum HaloHUDDynamicColorSource: String, Codable, CaseIterable, Identifiable {
    case fixed, systemAccent, wallpaper, albumArtwork, systemAppearance, automaticContrast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fixed: return "Custom / Fixed"
        case .systemAccent: return "System Accent"
        case .wallpaper: return "Wallpaper"
        case .albumArtwork: return "Album Artwork"
        case .systemAppearance: return "System Appearance"
        case .automaticContrast: return "Automatic Contrast"
        }
    }
}
enum HaloHUDEntranceAnimation: String, Codable, CaseIterable, Identifiable { case fade, scale, slide, spring, morph, notchExpand, liquid; var id: String { rawValue }; var title: String { rawValue == "notchExpand" ? "Notch Expand" : rawValue.capitalized } }
enum HaloHUDExitAnimation: String, Codable, CaseIterable, Identifiable { case fade, collapse, slide, scale, morphBack; var id: String { rawValue }; var title: String { rawValue == "morphBack" ? "Morph Back" : rawValue.capitalized } }
enum HaloHUDProgressAnimation: String, Codable, CaseIterable, Identifiable { case smooth, spring, instant; var id: String { rawValue }; var title: String { rawValue.capitalized } }
enum HaloHUDInterruptBehavior: String, Codable, CaseIterable, Identifiable { case restart, `continue`, blend; var id: String { rawValue }; var title: String { rawValue.capitalized } }
enum HaloHUDFloatingPosition: String, Codable, CaseIterable, Identifiable { case topLeft, top, topRight, center, bottomLeft, bottom, bottomRight, custom; var id: String { rawValue }; var title: String { rawValue.replacingOccurrences(of: "Left", with: " Left").replacingOccurrences(of: "Right", with: " Right").capitalized } }
enum HaloHUDScreenEdge: String, Codable, CaseIterable, Identifiable { case left, right, top, bottom; var id: String { rawValue }; var title: String { rawValue.capitalized } }
enum HaloHUDDisplayTarget: String, Codable, CaseIterable, Identifiable { case mouse, active, builtIn, main; var id: String { rawValue }; var title: String { rawValue == "builtIn" ? "Built-in Display" : rawValue.capitalized + (rawValue == "mouse" ? " Display" : rawValue == "active" ? " Display" : "") } }

struct HaloHUDComponents: Codable, Equatable {
    var icon = true
    var label = true
    var value = true
    var percentage = true
    var progress = true
    var deviceName = false
}
struct HaloHUDLayoutConfiguration: Codable, Equatable {
    var style: HaloHUDLayoutStyle = .horizontal
    var width = 320.0
    var height = 92.0
    var minimumWidth = 120.0
    var maximumWidth = 520.0
    var horizontalPadding = 16.0
    var verticalPadding = 14.0
    var spacing = 12.0
    var cornerRadius = 24.0
    var offsetX = 0.0
    var offsetY = 0.0
    var edgeMargin = 28.0
    var compact = false
}
struct HaloHUDNotchConfiguration: Codable, Equatable {
    var width = 180.0
    var horizontalPadding = 8.0
    var spacing = 7.0
    var horizontalOffset = 0.0
    var iconSize = 16.0
    var textSize = 12.0
    var progressWidth = 84.0
    var expandVertically: Bool?
    var verticalHeight: Double?

    var usesVerticalExpansion: Bool { expandVertically ?? false }
    var resolvedVerticalHeight: Double { min(220, max(56, verticalHeight ?? 92)) }

    func validated() throws -> HaloHUDNotchConfiguration {
        let numbers = [width, horizontalPadding, spacing, horizontalOffset, iconSize, textSize, progressWidth, verticalHeight ?? 92]
        guard numbers.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var result = self
        result.width = min(600, max(48, width))
        result.horizontalPadding = min(40, max(0, horizontalPadding))
        result.spacing = min(32, max(0, spacing))
        result.horizontalOffset = min(300, max(-300, horizontalOffset))
        result.iconSize = min(32, max(8, iconSize))
        result.textSize = min(24, max(8, textSize))
        result.progressWidth = min(220, max(20, progressWidth))
        if verticalHeight != nil { result.verticalHeight = resolvedVerticalHeight }
        return result
    }
}
struct HaloHUDColorConfiguration: Codable, Equatable {
    var source: HaloHUDDynamicColorSource = .systemAccent
    var hue = 0.59
    var saturation = 0.72
    var brightness = 1.0
    var alpha = 1.0
}
struct HaloHUDAppearanceConfiguration: Codable, Equatable {
    var background: HaloHUDBackgroundStyle = .glass
    var backgroundOpacity = 0.72
    var blur = 14.0
    var glassIntensity = 0.75
    var border = true
    var borderOpacity = 0.12
    var shadow = true
    var glow = false
    var noise = false
    var primary = HaloHUDColorConfiguration()
    var secondary = HaloHUDColorConfiguration(source: .automaticContrast, hue: 0, saturation: 0, brightness: 0.82, alpha: 1)
    var progress = HaloHUDColorConfiguration()
    var borderColor = HaloHUDColorConfiguration(source: .automaticContrast, hue: 0, saturation: 0, brightness: 1, alpha: 0.16)
    var glowColor = HaloHUDColorConfiguration()
}
struct HaloHUDAnimationConfiguration: Codable, Equatable {
    var entrance: HaloHUDEntranceAnimation = .spring
    var exit: HaloHUDExitAnimation = .fade
    var entranceDuration = 0.18
    var exitDuration = 0.20
    var springDamping = 0.82
    var springStiffness = 180.0
    var progress: HaloHUDProgressAnimation = .smooth
    var intensity = 0.72
}
struct HaloHUDBehaviorConfiguration: Codable, Equatable {
    var displayDuration = 1.15
    var interrupt: HaloHUDInterruptBehavior = .blend
    var collision: HaloHUDCollisionBehavior = .showExternally
    var fallbackTarget: HaloHUDPresentationTarget = .floating
}
struct HaloHUDPresentationConfiguration: Codable, Equatable {
    var target: HaloHUDPresentationTarget = .floating
    var notchSide: HaloHUDNotchSide = .automatic
    var notch: HaloHUDNotchConfiguration?
    var floatingPosition: HaloHUDFloatingPosition = .top
    var screenEdge: HaloHUDScreenEdge = .right
    var displayTarget: HaloHUDDisplayTarget = .mouse
    var screenEdgeLength = 220.0
    var screenEdgeThickness = 6.0
    var resolvedNotch: HaloHUDNotchConfiguration { notch ?? HaloHUDNotchConfiguration() }
}
struct HaloHUDConfiguration: Codable, Equatable {
    var presentation = HaloHUDPresentationConfiguration()
    var layout = HaloHUDLayoutConfiguration()
    var components = HaloHUDComponents()
    var progressStyle: HaloHUDProgressStyle = .bar
    var segments = 16
    var iconSize = 24.0
    var textSize = 14.0
    var appearance = HaloHUDAppearanceConfiguration()
    var animation = HaloHUDAnimationConfiguration()
    var behavior = HaloHUDBehaviorConfiguration()
}
struct HaloHUDEventOverride: Codable, Equatable {
    var enabled = true
    var useGlobalSettings = true
    var configuration = HaloHUDConfiguration()
}
struct HaloHUDPreset: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var builtIn: Bool
    var configuration: HaloHUDConfiguration
}
struct HaloHUDAppRule: Codable, Equatable, Identifiable {
    var id = UUID()
    var enabled = true
    var bundleIdentifier = ""
    var target: HaloHUDPresentationTarget = .screenEdge
}
struct HaloHUDSettings: Codable, Equatable {
    var version = 2
    var enabled = true
    var global = HaloHUDConfiguration()
    var events: [String: HaloHUDEventOverride] = [:]
    var customPresets: [HaloHUDPreset] = []
    var appRules: [HaloHUDAppRule] = []

    func override(for kind: HaloHUDEventKind) -> HaloHUDEventOverride {
        events[kind.rawValue] ?? HaloHUDEventOverride()
    }
    func isEnabled(_ kind: HaloHUDEventKind) -> Bool { enabled && override(for: kind).enabled }
    func configuration(for kind: HaloHUDEventKind) -> HaloHUDConfiguration {
        let item = override(for: kind)
        var configuration = item.useGlobalSettings ? global : item.configuration
        if configuration.presentation.target == .notch && configuration.presentation.resolvedNotch.usesVerticalExpansion {
            // Vertical HUDs own the selected notch wing while active. They should never fall back
            // externally just because the normal closed-notch slot already contains a widget.
            configuration.behavior.collision = .replace
        }
        return configuration
    }
    mutating func setOverride(_ value: HaloHUDEventOverride, for kind: HaloHUDEventKind) { events[kind.rawValue] = value }
    func validated() throws -> HaloHUDSettings {
        guard version <= 2 else { throw CocoaError(.fileReadCorruptFile) }
        var result = self
        result.version = 2
        result.global = try global.validated()
        result.events = try events.mapValues { item in
            var value = item
            value.configuration = try item.configuration.validated()
            return value
        }
        result.customPresets = try customPresets.prefix(50).map { preset in
            var value = preset
            value.name = String(value.name.prefix(80))
            value.configuration = try value.configuration.validated()
            return value
        }
        result.appRules = Array(appRules.prefix(100))
        return result
    }
}

extension HaloHUDConfiguration {
    func validated() throws -> HaloHUDConfiguration {
        let numbers = [layout.width, layout.height, layout.minimumWidth, layout.maximumWidth, layout.horizontalPadding,
                       layout.verticalPadding, layout.spacing, layout.cornerRadius, layout.offsetX, layout.offsetY,
                       layout.edgeMargin, iconSize, textSize, appearance.backgroundOpacity, appearance.blur,
                       appearance.glassIntensity, appearance.borderOpacity, animation.entranceDuration,
                       animation.exitDuration, animation.springDamping, animation.springStiffness,
                       animation.intensity, behavior.displayDuration, presentation.screenEdgeLength,
                       presentation.screenEdgeThickness]
        guard numbers.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var result = self
        result.layout.width = min(900, max(80, layout.width))
        result.layout.height = min(500, max(24, layout.height))
        result.layout.minimumWidth = min(900, max(40, layout.minimumWidth))
        result.layout.maximumWidth = min(1200, max(result.layout.minimumWidth, layout.maximumWidth))
        result.layout.horizontalPadding = min(80, max(0, layout.horizontalPadding))
        result.layout.verticalPadding = min(80, max(0, layout.verticalPadding))
        result.layout.spacing = min(60, max(0, layout.spacing))
        result.layout.cornerRadius = min(120, max(0, layout.cornerRadius))
        result.layout.offsetX = min(1000, max(-1000, layout.offsetX))
        result.layout.offsetY = min(1000, max(-1000, layout.offsetY))
        result.layout.edgeMargin = min(200, max(0, layout.edgeMargin))
        result.segments = min(64, max(2, segments))
        result.iconSize = min(96, max(8, iconSize))
        result.textSize = min(64, max(8, textSize))
        result.appearance.backgroundOpacity = min(1, max(0, appearance.backgroundOpacity))
        result.appearance.blur = min(60, max(0, appearance.blur))
        result.appearance.glassIntensity = min(1, max(0, appearance.glassIntensity))
        result.appearance.borderOpacity = min(1, max(0, appearance.borderOpacity))
        result.animation.entranceDuration = min(2, max(0, animation.entranceDuration))
        result.animation.exitDuration = min(2, max(0, animation.exitDuration))
        result.animation.springDamping = min(1, max(0.1, animation.springDamping))
        result.animation.springStiffness = min(600, max(20, animation.springStiffness))
        result.animation.intensity = min(1, max(0, animation.intensity))
        result.behavior.displayDuration = min(10, max(0.2, behavior.displayDuration))
        result.presentation.screenEdgeLength = min(1600, max(40, presentation.screenEdgeLength))
        result.presentation.screenEdgeThickness = min(48, max(1, presentation.screenEdgeThickness))
        if let notch = presentation.notch { result.presentation.notch = try notch.validated() }
        return result
    }

    static func haloPreset() -> HaloHUDConfiguration { HaloHUDConfiguration() }
    static func nativePreset() -> HaloHUDConfiguration {
        var c = HaloHUDConfiguration(); c.presentation.target = .floating; c.layout.style = .vertical; c.layout.width = 180; c.layout.height = 150; c.appearance.background = .glass; c.animation.entrance = .scale; return c
    }
    static func minimalPreset() -> HaloHUDConfiguration {
        var c = HaloHUDConfiguration(); c.presentation.target = .floating; c.layout.style = .compact; c.layout.width = 190; c.layout.height = 52; c.components.label = false; c.components.value = false; c.progressStyle = .minimalLine; c.appearance.shadow = false; c.animation.entrance = .fade; return c
    }
    static func dynamicPreset() -> HaloHUDConfiguration {
        var c = HaloHUDConfiguration(); c.appearance.primary.source = .albumArtwork; c.appearance.progress.source = .albumArtwork; c.appearance.glow = true; c.animation.entrance = .morph; c.animation.exit = .morphBack; return c
    }
    static func compactPreset() -> HaloHUDConfiguration {
        var c = minimalPreset(); c.presentation.target = .notch; c.presentation.notchSide = .automatic; c.presentation.notch = HaloHUDNotchConfiguration(); c.behavior.collision = .push; return c
    }
    static func classicPreset() -> HaloHUDConfiguration { nativePreset() }
    static func cyberPreset() -> HaloHUDConfiguration {
        var c = HaloHUDConfiguration(); c.progressStyle = .gauge; c.appearance.background = .solid; c.appearance.glow = true; c.layout.cornerRadius = 10; c.animation.entrance = .slide; return c
    }
}

extension HaloHUDPreset {
    static var builtIns: [HaloHUDPreset] {
        [
            HaloHUDPreset(id: "builtin.halo", name: "Halo", builtIn: true, configuration: .haloPreset()),
            HaloHUDPreset(id: "builtin.native-plus", name: "Native+", builtIn: true, configuration: .nativePreset()),
            HaloHUDPreset(id: "builtin.minimal", name: "Minimal", builtIn: true, configuration: .minimalPreset()),
            HaloHUDPreset(id: "builtin.dynamic", name: "Dynamic", builtIn: true, configuration: .dynamicPreset()),
            HaloHUDPreset(id: "builtin.compact", name: "Compact", builtIn: true, configuration: .compactPreset()),
            HaloHUDPreset(id: "builtin.classic", name: "Classic", builtIn: true, configuration: .classicPreset()),
            HaloHUDPreset(id: "builtin.cyber", name: "Cyber", builtIn: true, configuration: .cyberPreset())
        ]
    }
}

/// Generic payload consumed by renderers. Platform-specific providers should only construct this type.
struct HaloHUDEvent: Identifiable, Equatable {
    var id = UUID()
    var kind: HaloHUDEventKind
    var icon: String
    var primaryText: String
    var secondaryText: String?
    var value: Double?
    var minimumValue: Double?
    var maximumValue: Double?
    var progress: Double?
    var state: String?
    var timestamp = Date()
    var artworkKey: String?
    var metadata: [String: String] = [:]
    var preferredTarget: HaloHUDPresentationTarget?

    init(kind: HaloHUDEventKind, icon: String? = nil, primaryText: String? = nil, secondaryText: String? = nil,
         value: Double? = nil, minimumValue: Double? = 0, maximumValue: Double? = 1, progress: Double? = nil,
         state: String? = nil, artworkKey: String? = nil, metadata: [String: String] = [:],
         preferredTarget: HaloHUDPresentationTarget? = nil) {
        self.kind = kind; self.icon = icon ?? kind.symbol; self.primaryText = primaryText ?? kind.title
        self.secondaryText = secondaryText; self.value = value; self.minimumValue = minimumValue; self.maximumValue = maximumValue
        if let progress { self.progress = min(1, max(0, progress)) }
        else if let value, let minimumValue, let maximumValue, maximumValue > minimumValue {
            self.progress = min(1, max(0, (value - minimumValue) / (maximumValue - minimumValue)))
        } else { self.progress = nil }
        self.state = state; self.artworkKey = artworkKey; self.metadata = metadata; self.preferredTarget = preferredTarget
    }
}

import Foundation

// MARK: - Halo Custom CI SDK 0.1

enum HaloCISDK {
    static let schemaVersion = 1
    static let sdkVersion = "0.1"
    static let maximumPackageBytes: Int64 = 10_000_000
    static let maximumFileCount = 128
    static let maximumJSONBytes: Int64 = 512_000
    static let maximumComponentCount = 180
    static let maximumTreeDepth = 16
    static let maximumStringLength = 8_192

    static let supportedComponents: Set<String> = [
        "Text", "Image", "Icon", "Button", "Toggle", "Slider", "Progress", "ProgressRing",
        "Spacer", "Divider", "HStack", "VStack", "ZStack", "Grid", "ScrollView", "Badge",
        "NotchContainer", "MediaArtwork", "AppIcon", "DeviceBattery", "SystemMetric", "ActivityIndicator"
    ]
    static let supportedPermissions: Set<String> = [
        "Media.ReadState", "Media.Control", "Applications.Observe", "Clipboard.Write", "URL.Open"
    ]
    static let supportedCapabilities: Set<String> = ["LocalAssets", "LocalState", "AutomaticTriggers", "MediaControls"]
    static let supportedActions: Set<String> = [
        "halo.ci.close", "clipboard.copy", "url.open", "media.playPause", "media.next", "media.previous"
    ]
    static let supportedTriggers: Set<String> = [
        "manual", "mediaPlaying", "activeApplication", "batteryBelow", "batteryAbove", "charging", "timeWindow"
    ]
    static let supportedDataKeys: Set<String> = [
        "halo.surface.state", "halo.surface.isExpanded",
        "system.battery.level", "system.battery.isCharging", "system.lowPowerMode",
        "system.cpu.usedPercent", "system.memory.usedPercent", "system.storage.usedPercent",
        "media.isPlaying", "media.title", "media.artist", "media.album",
        "apps.active.bundleID", "apps.active.name"
    ]

    static func permissionForDataKey(_ key: String) -> String? {
        if key.hasPrefix("media.") { return "Media.ReadState" }
        if key.hasPrefix("apps.") { return "Applications.Observe" }
        return nil
    }
    static func permissionForAction(_ id: String) -> String? {
        switch id {
        case "media.playPause", "media.next", "media.previous": return "Media.Control"
        case "clipboard.copy": return "Clipboard.Write"
        case "url.open": return "URL.Open"
        default: return nil
        }
    }
    static func permissionForTrigger(_ type: String) -> String? {
        switch type {
        case "mediaPlaying": return "Media.ReadState"
        case "activeApplication": return "Applications.Observe"
        default: return nil
        }
    }
}

struct HaloCISizeRule: Codable, Equatable {
    var width: Double?
    var height: Double?
    var minWidth: Double?
    var preferredWidth: Double?
    var maxWidth: Double?
    var minHeight: Double?
    var preferredHeight: Double?
    var maxHeight: Double?

    init(width: Double? = nil, height: Double? = nil,
         minWidth: Double? = nil, preferredWidth: Double? = nil, maxWidth: Double? = nil,
         minHeight: Double? = nil, preferredHeight: Double? = nil, maxHeight: Double? = nil) {
        self.width = width; self.height = height
        self.minWidth = minWidth; self.preferredWidth = preferredWidth; self.maxWidth = maxWidth
        self.minHeight = minHeight; self.preferredHeight = preferredHeight; self.maxHeight = maxHeight
    }
}

struct HaloCISurfaceSizing: Codable, Equatable {
    /// `static` means exact declared dimensions. `dynamic` means Halo measures the rendered
    /// declarative tree and clamps it to the declared min/preferred/max bounds.
    var mode: String
    var closed: HaloCISizeRule?
    var expanded: HaloCISizeRule
}

struct HaloCIBackgroundStyle: Codable, Equatable {
    /// solid, gradient, glass, or clear
    var type: String
    var color: String?
    var secondaryColor: String?
    var opacity: Double?
    var blur: Double?

    init(type: String = "solid", color: String? = "#101014", secondaryColor: String? = nil,
         opacity: Double? = 1, blur: Double? = 0) {
        self.type = type; self.color = color; self.secondaryColor = secondaryColor
        self.opacity = opacity; self.blur = blur
    }
}

struct HaloCIBackgroundContract: Codable, Equatable {
    var closed: HaloCIBackgroundStyle?
    var expanded: HaloCIBackgroundStyle
}

struct HaloCISurfaceContract: Codable, Equatable {
    var sizing: HaloCISurfaceSizing
    var background: HaloCIBackgroundContract

    static let safeDefault = HaloCISurfaceContract(
        sizing: HaloCISurfaceSizing(
            mode: "static",
            closed: HaloCISizeRule(width: 190, height: 40),
            expanded: HaloCISizeRule(width: 560, height: 260)
        ),
        background: HaloCIBackgroundContract(
            closed: HaloCIBackgroundStyle(type: "solid", color: "#101014"),
            expanded: HaloCIBackgroundStyle(type: "solid", color: "#101014")
        )
    )
}

struct HaloCIManifest: Codable, Equatable {
    var schemaVersion: Int
    var sdkVersion: String
    var id: String
    var name: String
    var author: String
    var version: String
    var minimumHaloVersion: String
    var entryInterface: String
    var description: String
    var permissions: [String]
    var capabilities: [String]
    var supportedSurfaces: [String]
    var supportedStates: [String]
    var surface: HaloCISurfaceContract

    init(schemaVersion: Int = 1, sdkVersion: String = "0.1", id: String, name: String,
         author: String, version: String, minimumHaloVersion: String = "1.0.0",
         entryInterface: String = "interface.json", description: String = "",
         permissions: [String] = [], capabilities: [String] = [],
         supportedSurfaces: [String] = ["notch"], supportedStates: [String] = ["closed", "expanded"],
         surface: HaloCISurfaceContract = .safeDefault) {
        self.schemaVersion = schemaVersion; self.sdkVersion = sdkVersion; self.id = id; self.name = name
        self.author = author; self.version = version; self.minimumHaloVersion = minimumHaloVersion
        self.entryInterface = entryInterface; self.description = description; self.permissions = permissions
        self.capabilities = capabilities; self.supportedSurfaces = supportedSurfaces; self.supportedStates = supportedStates
        self.surface = surface
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sdkVersion, id, name, author, version, minimumHaloVersion, entryInterface,
             description, permissions, capabilities, supportedSurfaces, supportedStates, surface
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        sdkVersion = try c.decode(String.self, forKey: .sdkVersion)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        author = try c.decode(String.self, forKey: .author)
        version = try c.decode(String.self, forKey: .version)
        minimumHaloVersion = try c.decodeIfPresent(String.self, forKey: .minimumHaloVersion) ?? "1.0.0"
        entryInterface = try c.decodeIfPresent(String.self, forKey: .entryInterface) ?? "interface.json"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        permissions = try c.decodeIfPresent([String].self, forKey: .permissions) ?? []
        capabilities = try c.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        supportedSurfaces = try c.decodeIfPresent([String].self, forKey: .supportedSurfaces) ?? ["notch"]
        supportedStates = try c.decodeIfPresent([String].self, forKey: .supportedStates) ?? ["expanded"]
        surface = try c.decodeIfPresent(HaloCISurfaceContract.self, forKey: .surface) ?? .safeDefault
    }
}

struct HaloCIActionDescriptor: Codable, Equatable {
    var id: String
    var value: String?
    var arguments: [String: String]?
}

struct HaloCIComponent: Codable, Equatable {
    var type: String
    var id: String?
    var text: String?
    var value: String?
    var source: String?
    var systemName: String?
    var metric: String?
    var children: [HaloCIComponent]?
    var action: HaloCIActionDescriptor?
    var spacing: Double?
    var padding: Double?
    var width: Double?
    var height: Double?
    var cornerRadius: Double?
    var lineLimit: Int?
    var foreground: String?
    var background: String?
    var alignment: String?
    var axis: String?
    var columns: Int?
    var accessibilityLabel: String?
    var stateKey: String?
    var defaultBool: Bool?
    var defaultNumber: Double?
    var minimum: Double?
    var maximum: Double?
    var step: Double?
    var style: String?
}

struct HaloCIInterfaceDocument: Codable, Equatable {
    var closed: HaloCIComponent?
    var expanded: HaloCIComponent
}

struct HaloCITrigger: Codable, Equatable {
    var type: String
    var value: String?
    var number: Double?
    var bool: Bool?
    var startMinute: Int?
    var endMinute: Int?
}

struct HaloCITriggerDocument: Codable, Equatable {
    var match: String = "any"
    var triggers: [HaloCITrigger] = []

    private enum CodingKeys: String, CodingKey { case match, triggers }
    init(match: String = "any", triggers: [HaloCITrigger] = []) { self.match = match; self.triggers = triggers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        match = try c.decodeIfPresent(String.self, forKey: .match) ?? "any"
        triggers = try c.decodeIfPresent([HaloCITrigger].self, forKey: .triggers) ?? []
    }
}

enum HaloCIValidationSeverity: String, Codable { case warning, error }
struct HaloCIValidationIssue: Identifiable, Codable, Equatable {
    var id = UUID()
    var severity: HaloCIValidationSeverity
    var path: String
    var message: String
    init(_ severity: HaloCIValidationSeverity, _ path: String, _ message: String) {
        self.severity = severity; self.path = path; self.message = message
    }
}

struct HaloCIParsedPackage {
    var rootURL: URL
    var manifest: HaloCIManifest
    var interface: HaloCIInterfaceDocument
    var triggers: HaloCITriggerDocument
    var issues: [HaloCIValidationIssue]
}

struct HaloCIValidationReport {
    var package: HaloCIParsedPackage?
    var issues: [HaloCIValidationIssue]
    var isValid: Bool { package != nil && !issues.contains { $0.severity == .error } }
}

struct HaloCITriggerSnapshot: Equatable {
    var mediaIsPlaying = false
    var activeApplicationBundleID = ""
    var batteryLevel: Double?
    var charging = false
    var minuteOfDay = 0
}

enum HaloCITriggerEvaluator {
    static func matches(_ document: HaloCITriggerDocument, snapshot: HaloCITriggerSnapshot,
                        grantedPermissions: Set<String>) -> Bool {
        let automatic = document.triggers.filter { $0.type != "manual" }
        guard !automatic.isEmpty else { return false }
        let values = automatic.map { trigger -> Bool in
            if let permission = HaloCISDK.permissionForTrigger(trigger.type), !grantedPermissions.contains(permission) { return false }
            switch trigger.type {
            case "mediaPlaying": return snapshot.mediaIsPlaying == (trigger.bool ?? true)
            case "activeApplication": return snapshot.activeApplicationBundleID == (trigger.value ?? "")
            case "batteryBelow": guard let level = snapshot.batteryLevel, let threshold = trigger.number else { return false }; return level < threshold
            case "batteryAbove": guard let level = snapshot.batteryLevel, let threshold = trigger.number else { return false }; return level > threshold
            case "charging": return snapshot.charging == (trigger.bool ?? true)
            case "timeWindow":
                guard let start = trigger.startMinute, let end = trigger.endMinute else { return false }
                let minute = min(1439, max(0, snapshot.minuteOfDay))
                if start == end { return true }
                return start < end ? (minute >= start && minute < end) : (minute >= start || minute < end)
            default: return false
            }
        }
        return document.match == "all" ? values.allSatisfy { $0 } : values.contains(true)
    }
}

enum HaloCIBindingResolver {
    private static let regex = try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9._-]+)\s*\}\}"#)

    static func keys(in template: String) -> [String] {
        let ns = template as NSString
        return regex.matches(in: template, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges == 2 else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }

    static func resolve(_ template: String, data: [String: String]) -> String {
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed()
        var result = template
        for match in matches {
            guard let full = Range(match.range(at: 0), in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[keyRange])
            result.replaceSubrange(full, with: data[key] ?? "")
        }
        return result
    }
}

enum HaloCIPackageValidator {
    private static let manifestKeys: Set<String> = [
        "schemaVersion", "sdkVersion", "id", "name", "author", "version", "minimumHaloVersion",
        "entryInterface", "description", "permissions", "capabilities", "supportedSurfaces", "supportedStates", "surface"
    ]
    private static let surfaceKeys: Set<String> = ["sizing", "background"]
    private static let sizingKeys: Set<String> = ["mode", "closed", "expanded"]
    private static let sizeRuleKeys: Set<String> = [
        "width", "height", "minWidth", "preferredWidth", "maxWidth",
        "minHeight", "preferredHeight", "maxHeight"
    ]
    private static let backgroundKeys: Set<String> = ["closed", "expanded"]
    private static let backgroundStyleKeys: Set<String> = ["type", "color", "secondaryColor", "opacity", "blur"]
    private static let interfaceKeys: Set<String> = ["closed", "expanded"]
    private static let componentKeys: Set<String> = [
        "type", "id", "text", "value", "source", "systemName", "metric", "children", "action",
        "spacing", "padding", "width", "height", "cornerRadius", "lineLimit", "foreground", "background",
        "alignment", "axis", "columns", "accessibilityLabel", "stateKey", "defaultBool", "defaultNumber",
        "minimum", "maximum", "step", "style"
    ]
    private static let actionKeys: Set<String> = ["id", "value", "arguments"]
    private static let triggerDocumentKeys: Set<String> = ["match", "triggers"]
    private static let triggerKeys: Set<String> = ["type", "value", "number", "bool", "startMinute", "endMinute"]
    private static let executableExtensions: Set<String> = ["js", "mjs", "cjs", "swift", "dylib", "so", "sh", "command", "scpt", "py", "rb"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "heic", "tiff", "bmp"]

    static func validatePackage(at root: URL) -> HaloCIValidationReport {
        var issues: [HaloCIValidationIssue] = []
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return HaloCIValidationReport(package: nil, issues: [.init(.error, root.lastPathComponent, "Custom CI must currently be an unpacked .haloCI directory.")])
        }
        guard root.pathExtension.lowercased() == "haloci" else {
            return HaloCIValidationReport(package: nil, issues: [.init(.error, root.lastPathComponent, "Package directory must use the .haloCI extension.")])
        }

        var fileCount = 0
        var totalBytes: Int64 = 0
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let relative = String(url.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if relative.split(separator: "/").contains("..") || url.path.contains("/../") {
                    issues.append(.init(.error, relative, "Path traversal is not allowed.")); continue
                }
                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
                    if values.isSymbolicLink == true {
                        issues.append(.init(.error, relative, "Symbolic links are not allowed in CI packages.")); continue
                    }
                    if values.isRegularFile == true {
                        fileCount += 1; totalBytes += Int64(values.fileSize ?? 0)
                        if executableExtensions.contains(url.pathExtension.lowercased()) || relative.lowercased().hasPrefix("scripts/") {
                            issues.append(.init(.error, relative, "Executable/script content is reserved until Halo has an isolated CI runtime host."))
                        }
                    }
                } catch {
                    issues.append(.init(.error, relative, "Could not inspect package entry: \(error.localizedDescription)"))
                }
            }
        }
        if fileCount > HaloCISDK.maximumFileCount { issues.append(.init(.error, ".", "Package contains \(fileCount) files; maximum is \(HaloCISDK.maximumFileCount).")) }
        if totalBytes > HaloCISDK.maximumPackageBytes { issues.append(.init(.error, ".", "Package exceeds the 10 MB SDK 0.1 limit.")) }

        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let manifestData = readJSON(manifestURL, issues: &issues, label: "manifest.json"),
              let manifestObject = jsonObject(manifestData, path: "manifest.json", issues: &issues) as? [String: Any] else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        rejectUnknownKeys(in: manifestObject, allowed: manifestKeys, path: "manifest.json", issues: &issues)
        guard let manifest = decode(HaloCIManifest.self, data: manifestData, path: "manifest.json", issues: &issues) else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        validateManifest(manifest, issues: &issues)
        if let surfaceObject = manifestObject["surface"] as? [String: Any] {
            validateSurfaceRaw(surfaceObject, manifest: manifest, issues: &issues)
        } else {
            issues.append(.init(.error, "manifest.json.surface", "Every Custom CI must declare its notch sizing and background contract."))
        }

        guard safeRelativePath(manifest.entryInterface) else {
            issues.append(.init(.error, "manifest.json.entryInterface", "entryInterface must be a relative path inside the package."))
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        let interfaceURL = root.appendingPathComponent(manifest.entryInterface)
        guard interfaceURL.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            issues.append(.init(.error, "manifest.json.entryInterface", "entryInterface escapes the package root."))
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        guard let interfaceData = readJSON(interfaceURL, issues: &issues, label: manifest.entryInterface),
              let interfaceObject = jsonObject(interfaceData, path: manifest.entryInterface, issues: &issues) as? [String: Any] else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        rejectUnknownKeys(in: interfaceObject, allowed: interfaceKeys, path: manifest.entryInterface, issues: &issues)
        validateInterfaceRaw(interfaceObject, packageRoot: root, manifest: manifest, path: manifest.entryInterface, issues: &issues)
        guard let interface = decode(HaloCIInterfaceDocument.self, data: interfaceData, path: manifest.entryInterface, issues: &issues) else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }

        var triggers = HaloCITriggerDocument()
        let triggerURL = root.appendingPathComponent("triggers.json")
        if fm.fileExists(atPath: triggerURL.path), let data = readJSON(triggerURL, issues: &issues, label: "triggers.json") {
            if let object = jsonObject(data, path: "triggers.json", issues: &issues) as? [String: Any] {
                rejectUnknownKeys(in: object, allowed: triggerDocumentKeys, path: "triggers.json", issues: &issues)
                validateTriggersRaw(object, manifest: manifest, issues: &issues)
            }
            if let decoded = decode(HaloCITriggerDocument.self, data: data, path: "triggers.json", issues: &issues) { triggers = decoded }
        }

        let errors = issues.contains { $0.severity == .error }
        let package = errors ? nil : HaloCIParsedPackage(rootURL: root, manifest: manifest, interface: interface, triggers: triggers, issues: issues)
        return HaloCIValidationReport(package: package, issues: issues)
    }

    private static func readJSON(_ url: URL, issues: inout [HaloCIValidationIssue], label: String) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { issues.append(.init(.error, label, "Required file is missing.")); return nil }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { issues.append(.init(.error, label, "JSON files may not be symbolic links.")); return nil }
            if Int64(values.fileSize ?? 0) > HaloCISDK.maximumJSONBytes { issues.append(.init(.error, label, "JSON file exceeds 512 KB.")); return nil }
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch { issues.append(.init(.error, label, error.localizedDescription)); return nil }
    }

    private static func jsonObject(_ data: Data, path: String, issues: inout [HaloCIValidationIssue]) -> Any? {
        do { return try JSONSerialization.jsonObject(with: data) }
        catch { issues.append(.init(.error, path, "Invalid JSON: \(error.localizedDescription)")); return nil }
    }

    private static func decode<T: Decodable>(_ type: T.Type, data: Data, path: String, issues: inout [HaloCIValidationIssue]) -> T? {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { issues.append(.init(.error, path, "Schema decode failed: \(error.localizedDescription)")); return nil }
    }

    private static func rejectUnknownKeys(in object: [String: Any], allowed: Set<String>, path: String, issues: inout [HaloCIValidationIssue]) {
        for key in object.keys where !allowed.contains(key) { issues.append(.init(.error, path + "." + key, "Unknown SDK 0.1 field.")) }
    }

    private static func validateSurfaceRaw(_ object: [String: Any], manifest: HaloCIManifest,
                                           issues: inout [HaloCIValidationIssue]) {
        rejectUnknownKeys(in: object, allowed: surfaceKeys, path: "manifest.json.surface", issues: &issues)
        guard let sizing = object["sizing"] as? [String: Any] else {
            issues.append(.init(.error, "manifest.json.surface.sizing", "sizing is required.")); return
        }
        rejectUnknownKeys(in: sizing, allowed: sizingKeys, path: "manifest.json.surface.sizing", issues: &issues)
        let mode = sizing["mode"] as? String ?? ""
        guard ["static", "dynamic"].contains(mode) else {
            issues.append(.init(.error, "manifest.json.surface.sizing.mode", "Sizing mode must be static or dynamic.")); return
        }

        func validateRule(_ raw: Any?, state: String, required: Bool) {
            let path = "manifest.json.surface.sizing.\(state)"
            guard let rule = raw as? [String: Any] else {
                if required { issues.append(.init(.error, path, "A \(state) size contract is required.")) }
                return
            }
            rejectUnknownKeys(in: rule, allowed: sizeRuleKeys, path: path, issues: &issues)
            let closed = state == "closed"
            let widthRange: ClosedRange<Double> = closed ? 48...720 : 160...1100
            let heightRange: ClosedRange<Double> = closed ? 16...160 : 96...820
            func checked(_ key: String, range: ClosedRange<Double>) -> Double? {
                guard let value = number(rule[key]), value.isFinite, range.contains(value) else {
                    issues.append(.init(.error, path + "." + key, "Missing or outside the supported \(state) size range.")); return nil
                }
                return value
            }
            if mode == "static" {
                _ = checked("width", range: widthRange); _ = checked("height", range: heightRange)
                for key in ["minWidth", "preferredWidth", "maxWidth", "minHeight", "preferredHeight", "maxHeight"] where rule[key] != nil {
                    issues.append(.init(.error, path + "." + key, "Dynamic bounds are not allowed when sizing.mode is static."))
                }
            } else {
                if rule["width"] != nil || rule["height"] != nil {
                    issues.append(.init(.error, path, "Dynamic sizing uses min/preferred/max bounds instead of width/height."))
                }
                let minW = checked("minWidth", range: widthRange), prefW = checked("preferredWidth", range: widthRange), maxW = checked("maxWidth", range: widthRange)
                let minH = checked("minHeight", range: heightRange), prefH = checked("preferredHeight", range: heightRange), maxH = checked("maxHeight", range: heightRange)
                if let minW, let prefW, let maxW, !(minW <= prefW && prefW <= maxW) { issues.append(.init(.error, path, "Width bounds must satisfy minWidth <= preferredWidth <= maxWidth.")) }
                if let minH, let prefH, let maxH, !(minH <= prefH && prefH <= maxH) { issues.append(.init(.error, path, "Height bounds must satisfy minHeight <= preferredHeight <= maxHeight.")) }
            }
        }
        let states = Set(manifest.supportedStates)
        validateRule(sizing["expanded"], state: "expanded", required: true)
        validateRule(sizing["closed"], state: "closed", required: states.contains("closed"))

        guard let background = object["background"] as? [String: Any] else {
            issues.append(.init(.error, "manifest.json.surface.background", "Every Custom CI must own its background.")); return
        }
        rejectUnknownKeys(in: background, allowed: backgroundKeys, path: "manifest.json.surface.background", issues: &issues)
        func validateBackground(_ raw: Any?, state: String, required: Bool) {
            let path = "manifest.json.surface.background.\(state)"
            guard let style = raw as? [String: Any] else {
                if required { issues.append(.init(.error, path, "A \(state) background is required.")) }
                return
            }
            rejectUnknownKeys(in: style, allowed: backgroundStyleKeys, path: path, issues: &issues)
            guard let type = style["type"] as? String, ["solid", "gradient", "glass", "clear"].contains(type) else {
                issues.append(.init(.error, path + ".type", "Background type must be solid, gradient, glass, or clear.")); return
            }
            if let opacity = number(style["opacity"]), !(0...1).contains(opacity) { issues.append(.init(.error, path + ".opacity", "Opacity must be 0...1.")) }
            if let blur = number(style["blur"]), !(0...40).contains(blur) { issues.append(.init(.error, path + ".blur", "Blur must be 0...40.")) }
            func validColor(_ key: String, required: Bool) {
                guard let raw = style[key] as? String else { if required { issues.append(.init(.error, path + "." + key, "A color is required.")) }; return }
                let named = ["accent", "white", "black", "clear", "secondary", "green", "orange", "red", "blue"].contains(raw.lowercased())
                let hex = matches(raw, #"^#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$"#)
                if !named && !hex { issues.append(.init(.error, path + "." + key, "Use a supported named color or #RRGGBB/#RRGGBBAA.")) }
            }
            validColor("color", required: type == "solid" || type == "gradient" || type == "glass")
            validColor("secondaryColor", required: type == "gradient")
        }
        validateBackground(background["expanded"], state: "expanded", required: true)
        validateBackground(background["closed"], state: "closed", required: states.contains("closed"))
    }

    private static func validateManifest(_ manifest: HaloCIManifest, issues: inout [HaloCIValidationIssue]) {
        if manifest.schemaVersion != HaloCISDK.schemaVersion { issues.append(.init(.error, "manifest.json.schemaVersion", "Unsupported schema version \(manifest.schemaVersion). Halo supports schema 1.")) }
        if manifest.sdkVersion != HaloCISDK.sdkVersion { issues.append(.init(.error, "manifest.json.sdkVersion", "Unsupported SDK version \(manifest.sdkVersion). Halo currently supports 0.1.")) }
        if !matches(manifest.id, #"^[A-Za-z0-9]+(?:[.-][A-Za-z0-9_-]+)+$"#) || manifest.id.count > 160 { issues.append(.init(.error, "manifest.json.id", "Use a stable reverse-DNS style identifier, maximum 160 characters.")) }
        for (value, path) in [(manifest.name, "name"), (manifest.author, "author")] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.count > 120 {
            issues.append(.init(.error, "manifest.json." + path, "Must contain 1–120 characters."))
        }
        if manifest.description.count > 2_000 { issues.append(.init(.error, "manifest.json.description", "Description is limited to 2,000 characters.")) }
        if !matches(manifest.version, #"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$"#) { issues.append(.init(.error, "manifest.json.version", "Version must use semantic versioning.")) }
        if !matches(manifest.minimumHaloVersion, #"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$"#) { issues.append(.init(.error, "manifest.json.minimumHaloVersion", "minimumHaloVersion must use semantic versioning.")) }
        if manifest.supportedSurfaces.isEmpty || manifest.supportedSurfaces.contains(where: { $0 != "notch" }) { issues.append(.init(.error, "manifest.json.supportedSurfaces", "SDK 0.1 supports only the notch surface.")) }
        let states = Set(manifest.supportedStates)
        if states.isEmpty || !states.isSubset(of: ["closed", "expanded"]) || !states.contains("expanded") { issues.append(.init(.error, "manifest.json.supportedStates", "Use closed and/or expanded; expanded is required in SDK 0.1.")) }
        for permission in Set(manifest.permissions) where !HaloCISDK.supportedPermissions.contains(permission) { issues.append(.init(.error, "manifest.json.permissions", "Unsupported permission \(permission).")) }
        for capability in Set(manifest.capabilities) where !HaloCISDK.supportedCapabilities.contains(capability) { issues.append(.init(.error, "manifest.json.capabilities", "Unsupported capability \(capability).")) }
        if Set(manifest.permissions).count != manifest.permissions.count { issues.append(.init(.warning, "manifest.json.permissions", "Duplicate permissions were declared.")) }
    }

    private static func validateInterfaceRaw(_ object: [String: Any], packageRoot: URL, manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        guard let expanded = object["expanded"] as? [String: Any] else { issues.append(.init(.error, path + ".expanded", "expanded root component is required.")); return }
        var count = 0
        validateComponentRaw(expanded, packageRoot: packageRoot, manifest: manifest, path: path + ".expanded", depth: 1, count: &count, issues: &issues)
        if let closed = object["closed"] as? [String: Any] {
            validateComponentRaw(closed, packageRoot: packageRoot, manifest: manifest, path: path + ".closed", depth: 1, count: &count, issues: &issues)
        } else if Set(manifest.supportedStates).contains("closed") {
            issues.append(.init(.warning, path + ".closed", "Manifest declares closed support but no closed component exists; Halo will use a safe package-name fallback."))
        }
    }

    private static func validateComponentRaw(_ object: [String: Any], packageRoot: URL, manifest: HaloCIManifest,
                                             path: String, depth: Int, count: inout Int, issues: inout [HaloCIValidationIssue]) {
        count += 1
        if count > HaloCISDK.maximumComponentCount { issues.append(.init(.error, path, "Component count exceeds \(HaloCISDK.maximumComponentCount).")); return }
        if depth > HaloCISDK.maximumTreeDepth { issues.append(.init(.error, path, "Component tree exceeds depth \(HaloCISDK.maximumTreeDepth).")); return }
        rejectUnknownKeys(in: object, allowed: componentKeys, path: path, issues: &issues)
        guard let type = object["type"] as? String, HaloCISDK.supportedComponents.contains(type) else { issues.append(.init(.error, path + ".type", "Unsupported component type.")); return }
        for (key, value) in object {
            if let string = value as? String, string.count > HaloCISDK.maximumStringLength { issues.append(.init(.error, path + "." + key, "String exceeds \(HaloCISDK.maximumStringLength) characters.")) }
            if let string = value as? String { validateBindings(in: string, manifest: manifest, path: path + "." + key, issues: &issues) }
        }
        if let source = object["source"] as? String, source.hasPrefix("asset:") {
            let relative = String(source.dropFirst("asset:".count))
            if !safeRelativePath(relative) { issues.append(.init(.error, path + ".source", "Asset path must remain inside the package.")) }
            else {
                let url = packageRoot.appendingPathComponent(relative).standardizedFileURL
                if !url.path.hasPrefix(packageRoot.standardizedFileURL.path + "/") { issues.append(.init(.error, path + ".source", "Asset path escapes the package root.")) }
                else if !imageExtensions.contains(url.pathExtension.lowercased()) { issues.append(.init(.error, path + ".source", "SDK 0.1 Image assets must use a supported image format.")) }
                else if !FileManager.default.fileExists(atPath: url.path) { issues.append(.init(.error, path + ".source", "Referenced asset does not exist.")) }
            }
        } else if type == "Image", object["source"] != nil {
            issues.append(.init(.error, path + ".source", "Image source must use asset:<relative-path>. Network image loading is not exposed in SDK 0.1."))
        }
        if type == "MediaArtwork" { requirePermission("Media.ReadState", manifest: manifest, path: path, issues: &issues) }
        if type == "AppIcon" { requirePermission("Applications.Observe", manifest: manifest, path: path, issues: &issues) }
        if type == "SystemMetric", let metric = object["metric"] as? String,
           !["battery", "cpu", "memory", "storage", "networkDown", "networkUp", "thermal"].contains(metric) {
            issues.append(.init(.error, path + ".metric", "Unsupported system metric."))
        }
        if ["Button", "Toggle", "Slider"].contains(type), (object["accessibilityLabel"] as? String)?.isEmpty != false {
            issues.append(.init(.warning, path + ".accessibilityLabel", "Interactive components should declare accessibilityLabel."))
        }
        if type == "Toggle", (object["stateKey"] as? String)?.isEmpty != false { issues.append(.init(.error, path + ".stateKey", "Toggle requires an isolated stateKey.")) }
        if type == "Slider" {
            if (object["stateKey"] as? String)?.isEmpty != false { issues.append(.init(.error, path + ".stateKey", "Slider requires an isolated stateKey.")) }
            if let min = number(object["minimum"]), let max = number(object["maximum"]), min >= max { issues.append(.init(.error, path, "Slider minimum must be below maximum.")) }
        }
        if let action = object["action"] as? [String: Any] { validateActionRaw(action, manifest: manifest, path: path + ".action", issues: &issues) }
        if let children = object["children"] as? [[String: Any]] {
            for (index, child) in children.enumerated() { validateComponentRaw(child, packageRoot: packageRoot, manifest: manifest, path: "\(path).children[\(index)]", depth: depth + 1, count: &count, issues: &issues) }
        }
        validateNumericBounds(object, path: path, issues: &issues)
    }

    private static func validateActionRaw(_ object: [String: Any], manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        rejectUnknownKeys(in: object, allowed: actionKeys, path: path, issues: &issues)
        guard let id = object["id"] as? String, HaloCISDK.supportedActions.contains(id) else { issues.append(.init(.error, path + ".id", "Unsupported action.")); return }
        if let permission = HaloCISDK.permissionForAction(id) { requirePermission(permission, manifest: manifest, path: path, issues: &issues) }
        if let value = object["value"] as? String { validateBindings(in: value, manifest: manifest, path: path + ".value", issues: &issues) }
        if let args = object["arguments"] as? [String: Any] {
            for (key, value) in args {
                guard let string = value as? String else { issues.append(.init(.error, path + ".arguments." + key, "Action arguments must be strings or bindings.")); continue }
                validateBindings(in: string, manifest: manifest, path: path + ".arguments." + key, issues: &issues)
            }
        }
    }

    private static func validateTriggersRaw(_ object: [String: Any], manifest: HaloCIManifest, issues: inout [HaloCIValidationIssue]) {
        let match = object["match"] as? String ?? "any"
        if !["any", "all"].contains(match) { issues.append(.init(.error, "triggers.json.match", "match must be any or all.")) }
        guard let triggers = object["triggers"] as? [[String: Any]] else { issues.append(.init(.error, "triggers.json.triggers", "triggers must be an array.")); return }
        if triggers.count > 32 { issues.append(.init(.error, "triggers.json.triggers", "A CI may define at most 32 triggers.")) }
        for (index, trigger) in triggers.enumerated() {
            let path = "triggers.json.triggers[\(index)]"
            rejectUnknownKeys(in: trigger, allowed: triggerKeys, path: path, issues: &issues)
            guard let type = trigger["type"] as? String, HaloCISDK.supportedTriggers.contains(type) else { issues.append(.init(.error, path + ".type", "Unsupported trigger.")); continue }
            if let permission = HaloCISDK.permissionForTrigger(type) { requirePermission(permission, manifest: manifest, path: path, issues: &issues) }
            switch type {
            case "activeApplication": if (trigger["value"] as? String)?.isEmpty != false { issues.append(.init(.error, path + ".value", "activeApplication requires a bundle identifier.")) }
            case "batteryBelow", "batteryAbove": if number(trigger["number"]) == nil { issues.append(.init(.error, path + ".number", "Battery trigger requires a numeric threshold.")) }
            case "timeWindow":
                guard let start = integer(trigger["startMinute"]), let end = integer(trigger["endMinute"]), (0...1439).contains(start), (0...1439).contains(end) else { issues.append(.init(.error, path, "timeWindow requires startMinute/endMinute in 0...1439.")); continue }
            default: break
            }
        }
    }

    private static func validateBindings(in value: String, manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        let keys = HaloCIBindingResolver.keys(in: value)
        if value.contains("{{") && keys.isEmpty { issues.append(.init(.error, path, "Malformed binding. SDK 0.1 accepts only {{ namespace.key }} bindings.")); return }
        for key in keys {
            guard HaloCISDK.supportedDataKeys.contains(key) else { issues.append(.init(.error, path, "Unsupported binding key \(key).")); continue }
            if let permission = HaloCISDK.permissionForDataKey(key) { requirePermission(permission, manifest: manifest, path: path, issues: &issues) }
        }
    }

    private static func requirePermission(_ permission: String, manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        let declared = Set(manifest.permissions)
        if !declared.contains(permission) { issues.append(.init(.error, path, "Requires \(permission), but the manifest does not declare it.")) }
    }

    private static func validateNumericBounds(_ object: [String: Any], path: String, issues: inout [HaloCIValidationIssue]) {
        let bounds: [String: ClosedRange<Double>] = [
            "spacing": 0...80, "padding": 0...120, "width": 0...1600, "height": 0...1400,
            "cornerRadius": 0...160, "minimum": -100000...100000, "maximum": -100000...100000,
            "step": 0.000001...100000
        ]
        for (key, range) in bounds where object[key] != nil {
            guard let value = number(object[key]), value.isFinite, range.contains(value) else { issues.append(.init(.error, path + "." + key, "Value is outside the supported SDK 0.1 range.")); continue }
        }
        if let line = integer(object["lineLimit"]), !(1...20).contains(line) { issues.append(.init(.error, path + ".lineLimit", "lineLimit must be 1...20.")) }
        if let columns = integer(object["columns"]), !(1...8).contains(columns) { issues.append(.init(.error, path + ".columns", "columns must be 1...8.")) }
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.hasPrefix("~") else { return false }
        let parts = value.replacingOccurrences(of: "\\", with: "/").split(separator: "/", omittingEmptySubsequences: false)
        return !parts.contains("..") && !parts.contains("")
    }
    private static func matches(_ value: String, _ pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }
    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let int = value as? Int { return int }
        return nil
    }
}

// Shared by saved-layout validation, the size picker and the pixel renderer.
enum HaloPixelPalLayout {
    static func squareSide(columns: Int, rows: Int) -> Int {
        min(4, max(1, (columns + rows) / 2))
    }

    static func supports(_ preset: OpenNotchGridSizePreset) -> Bool {
        guard let span = preset.span else { return false }
        return span.columns == span.rows && (1...4).contains(span.columns)
    }
}

struct HaloPixelPalDisplayGeometry {
    let size: CGSize
    let scale: CGFloat
    let fill: Double
    let spacing: Double
    static let grid = 24

    init(size: CGSize, scale: CGFloat, fill: Double, spacing: Double = 1.0) {
        self.size = size
        self.scale = scale
        self.fill = fill
        self.spacing = spacing
    }

    var side: CGFloat { max(0, min(size.width, size.height)) * min(1, max(0.76, fill)) }
    var origin: CGPoint { CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2) }

    // Snap every LED edge and gap to backing pixels so adjustable spacing stays crisp.
    func led(x: Int, y: Int) -> CGRect {
        let backing = max(1, scale)
        let pitch = side / CGFloat(Self.grid)
        let pitchPixels = pitch * backing
        let requestedGapPixels = CGFloat(min(3.0, max(0.0, spacing.rounded())))
        // Always leave at least one physical pixel for the LED itself.
        let maximumGapPixels = max(0, floor(pitchPixels) - 1)
        let gap = min(requestedGapPixels, maximumGapPixels) / backing
        func snap(_ value: CGFloat) -> CGFloat { (value * backing).rounded() / backing }
        let left = snap(origin.x + CGFloat(x) * pitch)
        let top = snap(origin.y + CGFloat(y) * pitch)
        return CGRect(x: left, y: top,
                      width: max(0, snap(origin.x + CGFloat(x + 1) * pitch) - left - gap),
                      height: max(0, snap(origin.y + CGFloat(y + 1) * pitch) - top - gap))
    }
}

// A reaction starts at rest, bounces twice, then settles; idle motion has its own clock.
enum HaloPixelPalAnimationTiming {
    static func bounce(elapsed: TimeInterval, intensity: Double, reduceMotion: Bool) -> Int {
        guard !reduceMotion, elapsed >= 0, elapsed < 1.1 else { return 0 }
        let envelope = pow(1 - elapsed / 1.1, 2)
        return -Int((abs(sin(elapsed * .pi * 2 / 0.55)) * envelope * 3 * min(1, max(0, intensity))).rounded())
    }
}

enum HaloPixelPalLEDShape: String, Codable, CaseIterable, Identifiable {
    case square = "Square"
    case circle = "Circle"
    case triangle = "Triangle"
    case diamond = "Diamond"
    case star = "Star"
    case hexagon = "Hexagon"
    case cross = "Cross"

    var id: String { rawValue }
}

enum HaloPixelPalPowerAnimationStyle: String, Codable, CaseIterable, Identifiable {
    case scanline = "Scanline"
    case cascade = "Pixel Cascade"
    case corePulse = "Core Pulse"
    case sparkle = "Sparkle Burst"
    case none = "None"

    var id: String { rawValue }
}

enum HaloPixelPalPowerAnimationDirection {
    case up
    case down
}

enum HaloPixelPalCloseGatePolicy {
    /// Pixel Pal may delay physical retraction only while Halo's normal workspace owns
    /// the surface. A CI-owned presentation does not render Pixel Pal, so waiting for
    /// Pixel Pal's boot-down there would be invisible dead time.
    static func shouldDelayCollapse(
        layoutContainsPixelPal: Bool,
        activeCIIdentifier: String?
    ) -> Bool {
        layoutContainsPixelPal && activeCIIdentifier == nil
    }
}

enum HaloPixelPalPowerAnimationTiming {
    static let geometrySettleDelay: TimeInterval = 0.09

    static func duration(
        style: HaloPixelPalPowerAnimationStyle,
        direction: HaloPixelPalPowerAnimationDirection,
        speed: Double
    ) -> TimeInterval {
        guard style != .none else { return 0 }
        let base: TimeInterval
        switch (style, direction) {
        case (.scanline, .up): base = 0.48
        case (.scanline, .down): base = 0.30
        case (.cascade, .up): base = 0.58
        case (.cascade, .down): base = 0.44
        case (.corePulse, .up): base = 0.52
        case (.corePulse, .down): base = 0.36
        case (.sparkle, .up): base = 0.56
        case (.sparkle, .down): base = 0.42
        case (.none, _): return 0
        }
        let safeSpeed = min(1.75, max(0.5, speed.isFinite ? speed : 1))
        return base / safeSpeed
    }

    static func closeGateDelay(
        style: HaloPixelPalPowerAnimationStyle,
        speed: Double
    ) -> TimeInterval {
        let animation = duration(style: style, direction: .down, speed: speed)
        return animation > 0 ? animation + 0.04 : 0
    }

    static func fallbackBootDelay(surfaceDuration: TimeInterval) -> TimeInterval {
        let duration = surfaceDuration.isFinite ? surfaceDuration : 0.3
        return min(1.35, max(0.18, duration + 0.10))
    }

    static func progress(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, elapsed / duration))
    }

    static func smoothstep(_ raw: Double) -> Double {
        let value = min(1, max(0, raw))
        return value * value * (3 - 2 * value)
    }
}
