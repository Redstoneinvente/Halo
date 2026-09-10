import Foundation

enum ModuleID: String, Codable, CaseIterable, Identifiable {
    case clock, timer, shelf, media, audio, calendar, clipboard, system, launcher, activities, developer, notes, capture, stopwatch
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
        return (order + ModuleID.allCases).filter { seen.insert($0).inserted }
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
        // Imports must not implicitly read arbitrary local file paths supplied by another person.
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
         ("Coding", [.developer, .system, .timer, .shelf]), ("Media", [.media, .audio]),
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
    var repositoryPath = ""
    var hotkeyEnabled = true
    var hotkeyCode: UInt32 = 49
    var hotkeyModifiers: UInt32 = 2304 // option + command
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
