import Foundation

enum ModuleID: String, Codable, CaseIterable, Identifiable {
    case clock, timer, shelf, media, audio, calendar, clipboard, system, launcher, activities, developer, notes, capture, stopwatch
    static var allCases: [ModuleID] { [.clock, .timer, .shelf, .media, .audio, .calendar, .clipboard, .system, .launcher, .activities, .notes, .capture, .stopwatch] }
    var id: String { rawValue }
    var title: String { rawValue == "shelf" ? "File shelf" : rawValue.capitalized }
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
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .notes: return "note.text"
        case .capture: return "camera.viewfinder"
        case .stopwatch: return "stopwatch"
        }
    }
}

enum BackgroundKind: String, Codable, CaseIterable { case gradient, solid, glass, image, video }
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
        case grain, backgroundSchedule, surface, background, solidColor, gradientStartColor, gradientEndColor, assetPath, blur, saturation, brightness, expandedHeight, compactWidth, spacing, animation, pauseVideoOnBattery
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grain = try c.decodeIfPresent(GrainOptions.self, forKey: .grain)
        backgroundSchedule = try c.decodeIfPresent([TimedBackground].self, forKey: .backgroundSchedule)
        surface = try c.decodeIfPresent(SurfaceOptions.self, forKey: .surface) ?? SurfaceOptions()
        background = try c.decodeIfPresent(BackgroundKind.self, forKey: .background) ?? .gradient
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
        if let openNotch, !openNotch.regions.isEmpty { return openNotch }
        return OpenNotchLayout.migrated(
            modules: normalizedOrder().filter { enabled.contains($0) },
            horizontal: horizontalWidgets ?? false
        )
    }

    mutating func materializeOpenNotchLayout() {
        if openNotch == nil || openNotch?.regions.isEmpty == true { openNotch = resolvedOpenNotchLayout }
    }

    mutating func setCustomOpenNotchWorkspaceEnabled(_ enabled: Bool) {
        useCustomOpenNotchWorkspace = enabled
        if enabled { materializeOpenNotchLayout() }
    }

    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {
        openNotch = OpenNotchLayout.made(preset)
        let modules = openNotch?.allItems.compactMap(\.module) ?? []
        enabled.formUnion(modules)
    }

    func widgetStyle(for id: ModuleID) -> WidgetStyle {
        if let saved = widgets?[id.rawValue] { return saved }
        var style = WidgetStyle()
        if id == .clock { style.fontSize = 30; style.fontFamily = .rounded; style.weight = .light; style.showTitle = false }
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
    case module, element, spacer, divider
    var id: String { rawValue }
}

enum OpenNotchBlockVerticalAlignment: String, Codable, CaseIterable, Identifiable {
    case top = "Top"
    case center = "Center"
    case bottom = "Bottom"
    var id: String { rawValue }
}

enum OpenNotchElementKind: String, Codable, CaseIterable, Identifiable {
    case clock, date, battery, batteryPercentage, chargingState
    case appIcon, appName, volume, brightness, timer, stopwatch
    case mediaTitle, artist, albumArt, playbackControls, playbackProgress
    case cpu, ram, storage, networkActivity
    case customText, customIcon, customImage, customGIF, button, spacer, divider
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
        value.padding = try padding.validated(); value.items = try items.prefix(80).map { try $0.validated() }
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
    var tintColor: WidgetColor?
    var tintOpacity: Double?
    var grain: Double?
    var warmth: Double?
    var borderColor: WidgetColor?
    var borderWidth: Double?
    var borderOpacity: Double?
    var innerHighlight: Double?
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
        return value
    }
    func validated() throws -> OpenNotchAppearance {
        let values = [blur ?? 0, saturation ?? 1, brightness ?? 0, contrast ?? 1, tintOpacity ?? 0,
                      grain ?? 0, warmth ?? 0, borderWidth ?? 0, borderOpacity ?? 0,
                      innerHighlight ?? 0, shadowBlur ?? 0, shadowOpacity ?? 0, glow ?? 0]
        guard values.allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
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
    // Relative track weights for left/center/right and top/middle/bottom.
    // Optional fields preserve the first custom-workspace archive format.
    var columnWeights: [Double]?
    var rowWeights: [Double]?
    var appearance = OpenNotchAppearance()

    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }
    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }
    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }
    var usesFreeformRegions: Bool { regions.contains { $0.frame != nil } }
    var allItems: [OpenNotchItem] { regions.flatMap(\.groups).flatMap(\.items) }

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
        if modules.isEmpty { group.items = [.elementItem(.clock, priority: .high)] }
        return OpenNotchLayout(preset: .custom,
            regions: [OpenNotchRegion(placement: .middleCenter, padding: OpenNotchInsets(), groups: [group])])
    }

    static func made(_ preset: OpenNotchPreset) -> OpenNotchLayout {
        func g(_ name: String, _ axis: OpenNotchAxis = .vertical, _ items: [OpenNotchItem]) -> OpenNotchGroup {
            OpenNotchGroup(name: name, axis: axis, alignment: .stretch, spacing: 10, padding: OpenNotchInsets(), items: items)
        }
        func r(_ placement: OpenNotchRegionPlacement, _ groups: [OpenNotchGroup]) -> OpenNotchRegion {
            OpenNotchRegion(placement: placement, padding: OpenNotchInsets(), groups: groups)
        }
        switch preset {
        case .minimal:
            return OpenNotchLayout(preset: preset, regions: [
                r(.middleCenter, [g("Essentials", .horizontal, [.elementItem(.clock, priority: .alwaysVisible), .elementItem(.date, priority: .low), .elementItem(.batteryPercentage, priority: .high)])])
            ])
        case .media:
            return OpenNotchLayout(preset: preset, regions: [
                r(.middleCenter, [g("Media", .vertical, [.moduleItem(.media, presentation: .expanded, priority: .alwaysVisible)])]),
                r(.bottomCenter, [g("Audio", .horizontal, [.elementItem(.volume, priority: .high), .moduleItem(.audio, presentation: .compact, priority: .low)])])
            ])
        case .productivity:
            return OpenNotchLayout(preset: preset, regions: [
                r(.topCenter, [g("Overview", .horizontal, [.elementItem(.clock, priority: .high), .elementItem(.date, priority: .normal)])]),
                r(.middleLeft, [g("Schedule", .vertical, [.moduleItem(.calendar, priority: .high), .moduleItem(.timer, priority: .high)])]),
                r(.middleRight, [g("Work", .vertical, [.moduleItem(.notes, priority: .normal), .moduleItem(.shelf, priority: .low)])])
            ])
        case .systemMonitor:
            return OpenNotchLayout(preset: preset, regions: [
                r(.topCenter, [g("Status", .horizontal, [.elementItem(.battery, priority: .high), .elementItem(.cpu, priority: .alwaysVisible), .elementItem(.ram, priority: .high), .elementItem(.networkActivity, priority: .low)])]),
                r(.middleCenter, [g("System", .vertical, [.moduleItem(.system, presentation: .expanded, priority: .alwaysVisible)])])
            ])
        case .focus:
            return OpenNotchLayout(preset: preset, regions: [
                r(.topCenter, [g("Time", .horizontal, [.elementItem(.clock, priority: .high), .elementItem(.date, priority: .low)])]),
                r(.middleCenter, [g("Focus", .vertical, [.moduleItem(.timer, presentation: .expanded, priority: .alwaysVisible), .moduleItem(.notes, presentation: .compact, priority: .low)])])
            ])
        case .developer:
            return OpenNotchLayout(preset: preset, regions: [
                r(.topCenter, [g("Machine", .horizontal, [.elementItem(.cpu, priority: .high), .elementItem(.ram, priority: .high), .elementItem(.networkActivity, priority: .normal)])]),
                r(.middleLeft, [g("Tools", .vertical, [.moduleItem(.launcher, priority: .high), .moduleItem(.capture, priority: .normal)])]),
                r(.middleRight, [g("Context", .vertical, [.moduleItem(.system, priority: .normal), .moduleItem(.notes, priority: .low)])])
            ])
        case .informationDense:
            return OpenNotchLayout(preset: preset, regions: [
                r(.topLeft, [g("Time", .horizontal, [.elementItem(.clock, priority: .high), .elementItem(.date, priority: .low)])]),
                r(.topRight, [g("System", .horizontal, [.elementItem(.batteryPercentage, priority: .high), .elementItem(.cpu, priority: .normal), .elementItem(.ram, priority: .normal)])]),
                r(.middleLeft, [g("Agenda", .vertical, [.moduleItem(.calendar, presentation: .compact, priority: .high), .moduleItem(.timer, presentation: .compact, priority: .normal)])]),
                r(.middleRight, [g("Utilities", .vertical, [.moduleItem(.clipboard, presentation: .compact, priority: .normal), .moduleItem(.shelf, presentation: .compact, priority: .low)])]),
                r(.bottomCenter, [g("Media", .horizontal, [.elementItem(.mediaTitle, priority: .normal), .elementItem(.playbackControls, priority: .high), .elementItem(.volume, priority: .normal)])])
            ])
        case .showcase:
            return OpenNotchLayout(preset: preset, regions: [
                r(.topCenter, [g("Header", .horizontal, [.elementItem(.date, priority: .low), .elementItem(.clock, priority: .high), .elementItem(.batteryPercentage, priority: .normal)])]),
                r(.middleCenter, [g("Hero", .vertical, [.moduleItem(.media, presentation: .expanded, priority: .alwaysVisible)])]),
                r(.bottomCenter, [g("Controls", .horizontal, [.elementItem(.playbackControls, priority: .high), .elementItem(.volume, priority: .normal)])])
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
        value.appearance = try appearance.validated()
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
struct LiveActivity: Identifiable, Codable {
    var id = UUID()
    var title: String
    var detail = ""
    var progress: Double?
    var created = Date()
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
    var visualizerStyle: PlaybackAnimation?
    var songTextColors: Bool?
    var songControlColors: Bool?
    var songVisualizerColors: Bool?
    var songBackgroundColors: Bool?
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
    var resolvedVisualizerStyle: PlaybackAnimation { visualizerStyle ?? .bars }
    var usesSongTextColors: Bool { songTextColors ?? false }
    var usesSongControlColors: Bool { songControlColors ?? false }
    var usesSongVisualizerColors: Bool { songVisualizerColors ?? true }
    var usesSongBackgroundColors: Bool { songBackgroundColors ?? false }
    var resolvedHorizontalMargin: Double { min(120, max(0, horizontalMargin ?? max(18, resolvedSpacing * 1.25))) }
    var resolvedTopMargin: Double { min(160, max(0, topMargin ?? 0)) }
    var resolvedBottomMargin: Double { min(120, max(0, bottomMargin ?? max(10, resolvedSpacing * 0.55))) }
    func validated() throws -> ContextMusicOptions {
        guard [artworkSize, fontSize, backgroundOpacity, artworkBackgroundBlur ?? 12, artworkBackgroundDim ?? 0.38,
               spacing ?? 12, cornerRadius ?? 18, controlSize ?? 24, vinylRPM ?? 8,
               lyricSyncOffset ?? 0, lyricFontSize ?? 16, horizontalMargin ?? 18, topMargin ?? 0, bottomMargin ?? 10].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
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