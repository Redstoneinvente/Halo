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
        case grain, backgroundSchedule, surface, background, assetPath, blur, saturation, brightness, expandedHeight, compactWidth, spacing, animation, pauseVideoOnBattery
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grain = try c.decodeIfPresent(GrainOptions.self, forKey: .grain)
        backgroundSchedule = try c.decodeIfPresent([TimedBackground].self, forKey: .backgroundSchedule)
        surface = try c.decodeIfPresent(SurfaceOptions.self, forKey: .surface) ?? SurfaceOptions()
        background = try c.decodeIfPresent(BackgroundKind.self, forKey: .background) ?? .gradient
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
}
struct WorkspaceLayout: Codable, Equatable {
    var contextMusic: ContextMusicOptions?
    var hud: HaloHUDSettings?
    var horizontalWidgets: Bool?
    var horizontalPages: Bool?
    var horizontalHeight: Double?
    var widgets: [String: WidgetStyle]?
    var closedNotch: ClosedNotchOptions?
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
        appearance.expandedHeight = min(800, max(280, appearance.expandedHeight))
        appearance.compactWidth = min(640, max(16, appearance.compactWidth))
        appearance.surface = try appearance.surface.validated()
        appearance.spacing = min(28, max(4, appearance.spacing))
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
            archive.layout.horizontalHeight = min(500, max(200, height))
        }
        archive.layout.appearance = appearance
        archive.layout.order = layout.normalizedOrder()
        archive.layout.widgets = try layout.widgets?.mapValues { try $0.validated() }
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
    func validated() throws -> ContextMusicOptions {
        guard [artworkSize, fontSize, backgroundOpacity, artworkBackgroundBlur ?? 12, artworkBackgroundDim ?? 0.38,
               spacing ?? 12, cornerRadius ?? 18, controlSize ?? 24, vinylRPM ?? 8,
               lyricSyncOffset ?? 0, lyricFontSize ?? 16].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
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
        return item.useGlobalSettings ? global : item.configuration
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
