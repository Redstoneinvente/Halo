from pathlib import Path
import re

ROOT = Path('.')

def read(path): return (ROOT / path).read_text()
def write(path, text): (ROOT / path).write_text(text)
def insert_once(text, anchor, addition, *, after=True):
    if addition.strip() in text:
        return text
    if anchor not in text:
        raise SystemExit(f'anchor not found: {anchor[:100]}')
    return text.replace(anchor, anchor + addition if after else addition + anchor, 1)

# -----------------------------------------------------------------------------
# Workspace models: one opened-notch configuration system with legacy migration.
# -----------------------------------------------------------------------------
p = 'Halo/Core/WorkspaceModels.swift'
s = read(p)
if 'var openNotch: OpenNotchLayout?' not in s:
    s = s.replace('    var openFixedColumns: Int?\n    var widgets: [String: WidgetStyle]?\n',
                  '    var openFixedColumns: Int?\n    // New opened-notch workspace model. Optional for backwards compatibility.\n    var openNotch: OpenNotchLayout?\n    var widgets: [String: WidgetStyle]?\n', 1)

resolved_anchor = '''    var resolvedOpenFixedColumns: Int {\n        min(4, max(1, openFixedColumns ?? 2))\n    }\n'''
resolved_add = '''\n    var resolvedOpenNotchLayout: OpenNotchLayout {\n        if let openNotch, !openNotch.regions.isEmpty { return openNotch }\n        return OpenNotchLayout.migrated(\n            modules: normalizedOrder().filter { enabled.contains($0) },\n            horizontal: horizontalWidgets ?? false\n        )\n    }\n\n    mutating func materializeOpenNotchLayout() {\n        if openNotch == nil || openNotch?.regions.isEmpty == true { openNotch = resolvedOpenNotchLayout }\n    }\n\n    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {\n        openNotch = OpenNotchLayout.made(preset)\n        let modules = openNotch?.allItems.compactMap(\\.module) ?? []\n        enabled.formUnion(modules)\n    }\n'''
s = insert_once(s, resolved_anchor, resolved_add)

models = r'''

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
    var interactions = OpenNotchInteractions()

    static func moduleItem(_ module: ModuleID, presentation: OpenNotchPresentation = .automatic,
                           priority: OpenNotchPriority = .normal) -> OpenNotchItem {
        var value = OpenNotchItem()
        value.kind = .module; value.module = module; value.presentation = presentation; value.priority = priority
        value.sizing = OpenNotchSizing(mode: .flexible, minimumWidth: 150, preferredWidth: 300, maximumWidth: 900,
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

struct OpenNotchRegion: Codable, Equatable, Identifiable {
    var id = UUID()
    var placement: OpenNotchRegionPlacement = .middleCenter
    var padding = OpenNotchInsets()
    var groups: [OpenNotchGroup] = []
    func validated() throws -> OpenNotchRegion {
        var value = self
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
    var regions: [OpenNotchRegion] = []
    var appearance = OpenNotchAppearance()

    var allItems: [OpenNotchItem] { regions.flatMap(\.groups).flatMap(\.items) }

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
        value.regions = try regions.prefix(9).map { try $0.validated() }
        value.appearance = try appearance.validated()
        return value
    }
}
'''
if 'enum OpenNotchAxis:' not in s:
    s = s.replace('\nstruct ThemeArchive: Codable {', models + '\nstruct ThemeArchive: Codable {', 1)

validation_anchor = '        archive.layout.widgets = try layout.widgets?.mapValues { try $0.validated() }\n'
validation_add = '''        if var opened = try layout.openNotch?.validated() {\n            // Theme archives cannot safely carry machine-local image/video paths.\n            opened.appearance.assetPath = ""\n            if opened.appearance.background == .image || opened.appearance.background == .video { opened.appearance.background = .gradient }\n            archive.layout.openNotch = opened\n        }\n'''
s = insert_once(s, validation_anchor, validation_add)
write(p, s)

# -----------------------------------------------------------------------------
# Element style: expand the existing reusable styling model rather than duplicate it.
# -----------------------------------------------------------------------------
p = 'Halo/Core/WidgetModels.swift'
s = read(p)
style_anchor = '    var dividerAfter = false\n\n    func validated() throws -> WidgetElementStyle {'
style_add = '''    // Opened-notch element layout/chrome overrides. Optional fields keep older saved element styles decodable.\n    var alignment: WidgetContentAlignment?\n    var externalSpacing: Double?\n    var xOffset: Double?\n    var yOffset: Double?\n    var textAlignment: WidgetContentAlignment?\n    var fontFamily: WidgetFontFamily?\n    var customFont: String?\n    var fontSize: Double?\n    var fontWeight: WidgetFontWeight?\n    var borderColor: WidgetColor?\n    var borderWidth: Double?\n    var borderOpacity: Double?\n    var shadowBlur: Double?\n    var shadowOpacity: Double?\n    var tintColor: WidgetColor?\n    var tintOpacity: Double?\n    var iconSize: Double?\n    var contentDensity: Double?\n    var priority: OpenNotchPriority?\n\n'''
if 'var externalSpacing: Double?' not in s:
    s = s.replace(style_anchor, '    var dividerAfter = false\n\n' + style_add + '    func validated() throws -> WidgetElementStyle {', 1)

old_guard = '''        guard [fontScale, opacity, backgroundOpacity, padding, cornerRadius].allSatisfy(\\.isFinite) else {\n            throw CocoaError(.fileReadCorruptFile)\n        }'''
new_guard = '''        let extended = [externalSpacing, xOffset, yOffset, fontSize, borderWidth, borderOpacity, shadowBlur, shadowOpacity, tintOpacity, iconSize, contentDensity].compactMap { $0 }\n        guard [fontScale, opacity, backgroundOpacity, padding, cornerRadius].allSatisfy(\\.isFinite), extended.allSatisfy(\\.isFinite) else {\n            throw CocoaError(.fileReadCorruptFile)\n        }'''
s = s.replace(old_guard, new_guard, 1)
validate_anchor = '''        value.customForeground = try customForeground.validated()\n        value.backgroundColor = try backgroundColor.validated()\n        return value\n'''
validate_add = '''        value.customForeground = try customForeground.validated()\n        value.backgroundColor = try backgroundColor.validated()\n        if let externalSpacing { value.externalSpacing = min(48, max(0, externalSpacing)) }\n        if let xOffset { value.xOffset = min(200, max(-200, xOffset)) }\n        if let yOffset { value.yOffset = min(200, max(-200, yOffset)) }\n        if let fontSize { value.fontSize = min(72, max(8, fontSize)) }\n        if let borderWidth { value.borderWidth = min(8, max(0, borderWidth)) }\n        if let borderOpacity { value.borderOpacity = min(1, max(0, borderOpacity)) }\n        if let shadowBlur { value.shadowBlur = min(48, max(0, shadowBlur)) }\n        if let shadowOpacity { value.shadowOpacity = min(0.8, max(0, shadowOpacity)) }\n        if let tintOpacity { value.tintOpacity = min(1, max(0, tintOpacity)) }\n        if let iconSize { value.iconSize = min(96, max(6, iconSize)) }\n        if let contentDensity { value.contentDensity = min(1.5, max(0.5, contentDensity)) }\n        value.borderColor = try borderColor?.validated()\n        value.tintColor = try tintColor?.validated()\n        if let customFont { value.customFont = String(customFont.prefix(120)) }\n        return value\n'''
s = s.replace(validate_anchor, validate_add, 1)
write(p, s)

# -----------------------------------------------------------------------------
# Widget rendering: shared element surface + compression/presentation environment.
# -----------------------------------------------------------------------------
p = 'Halo/Views/WidgetViews.swift'
s = read(p)
env_anchor = '''extension EnvironmentValues {\n    var widgetStyle: WidgetStyle {\n        get { self[WidgetStyleKey.self] }\n        set { self[WidgetStyleKey.self] = newValue }\n    }\n}\n'''
env_add = r'''

private struct OpenNotchPresentationEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchPresentation = .regular }
private struct OpenNotchCompressionEnvironmentKey: EnvironmentKey { static let defaultValue = 0 }
extension EnvironmentValues {
    var openNotchPresentation: OpenNotchPresentation {
        get { self[OpenNotchPresentationEnvironmentKey.self] }
        set { self[OpenNotchPresentationEnvironmentKey.self] = newValue }
    }
    var openNotchCompressionLevel: Int {
        get { self[OpenNotchCompressionEnvironmentKey.self] }
        set { self[OpenNotchCompressionEnvironmentKey.self] = newValue }
    }
}

extension OpenNotchPriority {
    func remainsVisible(at compression: Int) -> Bool {
        switch self {
        case .alwaysVisible, .high: return true
        case .normal: return compression < 5
        case .low: return compression < 3
        case .optional: return compression < 2
        }
    }
}

extension WidgetFontWeight {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension WidgetContentAlignment {
    var textAlignment: TextAlignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}
'''
s = insert_once(s, env_anchor, env_add)

# Replace WidgetElement implementation with a shared surface reusable by lightweight workspace items.
start = s.index('struct WidgetElement<Content: View>: View {')
end = s.index('\nstruct WidgetCard<Content: View>: View {', start)
new_element = r'''struct WidgetElementSurface<Content: View>: View {
    let element: WidgetElementStyle
    let widgetStyle: WidgetStyle
    var defaultPriority: OpenNotchPriority = .normal
    @ViewBuilder var content: Content
    @Environment(\.openNotchCompressionLevel) private var compression

    private var priority: OpenNotchPriority { element.priority ?? defaultPriority }
    private var alignment: WidgetContentAlignment { element.alignment ?? widgetStyle.resolvedContent.alignment }
    private var textAlignment: WidgetContentAlignment { element.textAlignment ?? alignment }
    private var foreground: Color {
        switch element.foreground {
        case .inherit: return widgetStyle.textColor.color
        case .secondary: return widgetStyle.textColor.color.opacity(0.62)
        case .accent: return widgetStyle.accentColor.color
        case .custom: return element.customForeground.color
        }
    }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous) }
    private var font: Font {
        let family = element.fontFamily ?? widgetStyle.fontFamily
        let size = element.fontSize ?? (widgetStyle.fontSize * element.fontScale)
        let weight = element.fontWeight?.swiftUIFontWeight ?? element.emphasis.fontWeight
        if family == .custom { return .custom(element.customFont ?? widgetStyle.customFont, size: size).weight(weight) }
        let design: Font.Design
        switch family { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: size, weight: weight, design: design)
    }
    private var controlSize: ControlSize {
        let density = element.contentDensity ?? 1
        if density <= 0.7 { return .mini }
        if density <= 0.9 { return .small }
        if density >= 1.3 { return .large }
        return widgetStyle.resolvedContent.controlSize.swiftUI
    }

    @ViewBuilder private var elementBackground: some View {
        switch element.background {
        case .none: EmptyView()
        case .subtle: shape.fill(widgetStyle.textColor.color.opacity(element.backgroundOpacity * 0.16))
        case .accent: shape.fill(widgetStyle.accentColor.color.opacity(element.backgroundOpacity))
        case .glass: shape.fill(.ultraThinMaterial).opacity(max(0.15, element.backgroundOpacity))
        case .custom: shape.fill(element.backgroundColor.color.opacity(element.backgroundOpacity))
        }
    }

    var body: some View {
        if element.visible && priority.remainsVisible(at: compression) {
            content
                .font(font)
                .foregroundStyle(foreground)
                .tint((element.tintColor ?? widgetStyle.accentColor).color.opacity(element.tintOpacity ?? 1))
                .multilineTextAlignment(textAlignment.textAlignment)
                .controlSize(controlSize)
                .opacity(element.opacity)
                .lineLimit(compression >= 4 ? 1 : nil)
                .padding(element.padding)
                .background { elementBackground }
                .overlay {
                    if (element.borderWidth ?? 0) > 0 && (element.borderOpacity ?? 0) > 0 {
                        shape.stroke((element.borderColor ?? widgetStyle.textColor).color.opacity(element.borderOpacity ?? 0), lineWidth: element.borderWidth ?? 0)
                    }
                }
                .shadow(color: .black.opacity(element.shadowOpacity ?? 0), radius: element.shadowBlur ?? 0)
                .offset(x: element.xOffset ?? 0, y: element.yOffset ?? 0)
                .padding(.vertical, (element.externalSpacing ?? 0) * 0.5)
                .frame(maxWidth: .infinity, alignment: alignment.alignment)
        }
    }
}

struct WidgetElement<Content: View>: View {
    let key: String
    var defaultVisible = true
    var defaultPriority: OpenNotchPriority = .normal
    @ViewBuilder var content: Content
    @Environment(\.widgetStyle) private var style

    init(key: String, defaultVisible: Bool = true, defaultPriority: OpenNotchPriority = .normal,
         @ViewBuilder content: () -> Content) {
        self.key = key; self.defaultVisible = defaultVisible; self.defaultPriority = defaultPriority; self.content = content()
    }

    var body: some View {
        let element = style.elementStyle(for: key, defaultVisible: defaultVisible)
        if element.visible {
            VStack(alignment: (element.alignment ?? style.resolvedContent.alignment).horizontal, spacing: 4) {
                WidgetElementSurface(element: element, widgetStyle: style, defaultPriority: defaultPriority) { content }
                if element.dividerAfter { Divider().opacity(0.45) }
            }
            .frame(maxWidth: .infinity, alignment: (element.alignment ?? style.resolvedContent.alignment).alignment)
        }
    }
}
'''
s = s[:start] + new_element + s[end:]
write(p, s)

# -----------------------------------------------------------------------------
# Surface runtime: all normal opened content now flows through regions/groups/items.
# -----------------------------------------------------------------------------
p = 'Halo/Views/SurfaceView.swift'
s = read(p)
if '@State private var openVisibilityToken = UUID()' not in s:
    s = s.replace('    @State private var page = 0\n', '    @State private var page = 0\n    @State private var openVisibilityToken = UUID()\n', 1)

old_background = '''        .background {\n            ZStack {\n                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)\n                if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {\n                    AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)\n                }\n            }\n        }\n'''
new_background = '''        .background {\n            ZStack {\n                if state.expanded && activeContext == nil {\n                    OpenNotchBackgroundView(options: layout.resolvedOpenNotchLayout.appearance, fallback: layout.appearance, theme: theme, system: workspace.system)\n                } else {\n                    SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)\n                }\n                if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {\n                    AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)\n                }\n            }\n        }\n'''
if old_background not in s: raise SystemExit('Surface background block not found')
s = s.replace(old_background, new_background, 1)

old_overlay = '        .overlay(contour.stroke(state.dropTargeted ? accent : .white.opacity(0.12), lineWidth: state.dropTargeted ? 1.6 : 1))\n'
new_overlay = '''        .overlay {\n            contour.stroke(state.dropTargeted ? accent : .white.opacity(0.12), lineWidth: state.dropTargeted ? 1.6 : 1)\n            if state.expanded && activeContext == nil { OpenNotchSurfaceChrome(contour: contour, options: layout.resolvedOpenNotchLayout.appearance) }\n        }\n'''
s = s.replace(old_overlay, new_overlay, 1)

onchange = '''        .onChange(of: state.expanded) { expanded in\n            if !expanded {\n                state.contextPreferredSize = nil\n                retroGameRequested = false\n            }\n        }\n'''
change2 = '''        .onAppear { workspace.setOpenedNotchVisible(state.expanded && activeContext == nil, token: openVisibilityToken) }\n        .onDisappear { workspace.setOpenedNotchVisible(false, token: openVisibilityToken) }\n        .onChange(of: state.expanded) { expanded in\n            workspace.setOpenedNotchVisible(expanded && activeContext == nil, token: openVisibilityToken)\n            if !expanded {\n                state.contextPreferredSize = nil\n                retroGameRequested = false\n            }\n        }\n        .onChange(of: activeContext) { _ in\n            workspace.setOpenedNotchVisible(state.expanded && activeContext == nil, token: openVisibilityToken)\n        }\n'''
if onchange not in s: raise SystemExit('state expanded block not found')
s = s.replace(onchange, change2, 1)

# Replace legacy open dashboard helpers. Scroll/Pages remain modes, but use the same region/group/item renderer.
pattern = re.compile(r'    private func horizontalWidget\(_ module: ModuleID\) -> some View \{.*?\n    @ViewBuilder private func widgetCards\(horizontal: Bool\) -> some View \{.*?\n    \}\n\}', re.S)
match = pattern.search(s)
if not match: raise SystemExit('legacy opened dashboard helper block not found')
replacement = '''    private var openDashboardContent: some View {\n        OpenNotchWorkspaceView(layout: layout, store: store, mode: layout.resolvedOpenNotchContentMode, page: $page)\n    }\n}'''
s = s[:match.start()] + replacement + s[match.end():]

runtime = r'''

private struct OpenNotchBackgroundView: View {
    let options: OpenNotchAppearance
    let fallback: Appearance
    let theme: Theme
    @ObservedObject var system: SystemService
    var body: some View {
        SurfaceBackground(appearance: options.baseAppearance(fallback), theme: theme, expanded: true, system: system)
            .contrast(options.contrast ?? 1)
            .overlay((options.tintColor ?? WidgetColor(red: 0.35, green: 0.55, blue: 1)).color.opacity(options.tintOpacity ?? 0))
            .overlay(Color.orange.opacity(max(0, options.warmth ?? 0) * 0.06))
            .overlay(Color.blue.opacity(max(0, -(options.warmth ?? 0)) * 0.05))
            .overlay {
                if (options.grain ?? 0) > 0 {
                    Canvas { context, size in
                        let amount = min(0.35, max(0, options.grain ?? 0))
                        let step: CGFloat = 7
                        var x: CGFloat = 1
                        var seed: UInt64 = UInt64(size.width * 31 + size.height * 17)
                        while x < size.width {
                            var y: CGFloat = 1
                            while y < size.height {
                                seed = seed &* 2862933555777941757 &+ 3037000493
                                let n = Double((seed >> 33) & 255) / 255.0
                                if n > 0.64 { context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(amount * 0.18))) }
                                y += step
                            }
                            x += step
                        }
                    }.allowsHitTesting(false)
                }
            }
    }
}

private struct OpenNotchSurfaceChrome: View {
    let contour: HaloContour
    let options: OpenNotchAppearance
    var body: some View {
        ZStack {
            if (options.borderWidth ?? 0) > 0 {
                contour.stroke((options.borderColor ?? .white).color.opacity(options.borderOpacity ?? 0.2), lineWidth: options.borderWidth ?? 0)
            }
            if (options.innerHighlight ?? 0) > 0 {
                contour.stroke(.white.opacity(options.innerHighlight ?? 0), lineWidth: 1).padding(1)
            }
            if (options.glow ?? 0) > 0 {
                contour.stroke(.white.opacity((options.glow ?? 0) * 0.32), lineWidth: 1.2)
                    .shadow(color: .white.opacity(options.glow ?? 0), radius: 12)
            }
            if (options.shadowOpacity ?? 0) > 0 {
                contour.stroke(.black.opacity(options.shadowOpacity ?? 0), lineWidth: 1)
                    .shadow(color: .black.opacity(options.shadowOpacity ?? 0), radius: options.shadowBlur ?? 12, y: 3)
            }
        }.allowsHitTesting(false)
    }
}

private struct OpenNotchRuntimeContext {
    let store: AppStore
    var battery: Double? { store.workspace.system.battery.map(Double.init) }
    var cpu: Double { store.workspace.system.cpuUsage }
    var valueForMetric: (OpenNotchVisibilityMetric) -> Double? {
        { metric in
            switch metric {
            case .always: return 1
            case .batteryLevel: return battery
            case .charging: return store.workspace.system.charging ? 1 : 0
            case .mediaPlaying: return store.workspace.media.isPlaying ? 1 : 0
            case .timerActive: return (store.deadline != nil || store.pausedSeconds > 0) ? 1 : 0
            case .stopwatchRunning: return store.workspace.stopwatchStart != nil ? 1 : 0
            case .cpuUsage: return cpu
            case .lowPowerMode: return store.workspace.system.lowPower ? 1 : 0
            }
        }
    }
    func matches(_ rule: OpenNotchVisibilityRule) -> Bool {
        guard let lhs = valueForMetric(rule.metric) else { return false }
        let rhs = rule.value
        switch rule.comparison {
        case .equal: return abs(lhs - rhs) < 0.0001
        case .notEqual: return abs(lhs - rhs) >= 0.0001
        case .lessThan: return lhs < rhs
        case .lessThanOrEqual: return lhs <= rhs
        case .greaterThan: return lhs > rhs
        case .greaterThanOrEqual: return lhs >= rhs
        }
    }
    func isVisible(_ item: OpenNotchItem) -> Bool {
        guard !item.hidden else { return false }
        guard !item.visibilityRules.isEmpty else { return true }
        switch item.visibilityLogic {
        case .all: return item.visibilityRules.allSatisfy(matches)
        case .any: return item.visibilityRules.contains(where: matches)
        }
    }
}

private struct OpenNotchWorkspaceView: View {
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    let mode: OpenNotchContentMode
    @Binding var page: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }
    private var regions: [OpenNotchRegion] { opened.regions.sorted { $0.placement.sortIndex < $1.placement.sortIndex } }
    private var groups: [OpenNotchGroup] { regions.flatMap(\.groups) }

    var body: some View {
        Group {
            switch mode {
            case .fixed: fixedCanvas
            case .scroll: scrollCanvas
            case .pages: pagesCanvas
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: opened)
    }

    private var fixedCanvas: some View {
        GeometryReader { proxy in
            VStack(spacing: max(4, layout.appearance.spacing)) {
                regionRow(.topLeft, .topCenter, .topRight, height: proxy.size.height / 3)
                regionRow(.middleLeft, .middleCenter, .middleRight, height: proxy.size.height / 3)
                regionRow(.bottomLeft, .bottomCenter, .bottomRight, height: proxy.size.height / 3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private func regionRow(_ left: OpenNotchRegionPlacement, _ center: OpenNotchRegionPlacement,
                                        _ right: OpenNotchRegionPlacement, height: CGFloat) -> some View {
        let placements = [left, center, right]
        if placements.contains(where: { region($0) != nil }) {
            HStack(alignment: .top, spacing: max(4, layout.appearance.spacing)) {
                ForEach(placements) { placement in
                    if let value = region(placement) {
                        OpenNotchRegionView(region: value, layout: layout, store: store)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: placement.regionAlignment)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }.frame(height: max(1, height - layout.appearance.spacing * 0.66))
        }
    }

    private var scrollCanvas: some View {
        Group {
            if layout.horizontalWidgets ?? false {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: layout.appearance.spacing) {
                        ForEach(groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store).frame(minWidth: 220) }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: layout.appearance.spacing) {
                        ForEach(groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store) }
                    }
                }
            }
        }
    }

    private var pagesCanvas: some View {
        VStack(spacing: 8) {
            if groups.isEmpty {
                Text("Enable widgets or add opened-notch elements in Settings.").foregroundStyle(.secondary)
            } else {
                let index = min(max(0, page), groups.count - 1)
                OpenNotchGroupView(group: groups[index], layout: layout, store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0)
                    Spacer(); Text("\(groups[index].name) · \(index + 1) / \(groups.count)").font(.caption); Spacer()
                    Button { page = min(groups.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }.disabled(index == groups.count - 1)
                }
            }
        }
    }

    private func region(_ placement: OpenNotchRegionPlacement) -> OpenNotchRegion? { regions.first { $0.placement == placement } }
}

private struct OpenNotchRegionView: View {
    let region: OpenNotchRegion
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(spacing: max(4, layout.appearance.spacing)) {
            ForEach(region.groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store) }
        }
        .padding(.top, region.padding.top).padding(.leading, region.padding.leading)
        .padding(.bottom, region.padding.bottom).padding(.trailing, region.padding.trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: region.placement.regionAlignment)
    }
}

private struct OpenNotchGroupView: View {
    let group: OpenNotchGroup
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    private var context: OpenNotchRuntimeContext { OpenNotchRuntimeContext(store: store) }

    var body: some View {
        GeometryReader { proxy in
            let candidates = group.items.filter(context.isVisible)
            let mainAvailable = group.axis == .horizontal ? proxy.size.width : proxy.size.height
            let wanted = candidates.reduce(0.0) { partial, item in
                partial + (group.axis == .horizontal ? item.sizing.preferredWidth : item.sizing.preferredHeight)
            } + max(0, Double(candidates.count - 1)) * group.spacing
            let compression = compressionLevel(available: mainAvailable, wanted: wanted)
            let spacing = max(2, group.spacing * (compression >= 1 ? 0.66 : 1))
            let visible = candidates.filter { $0.priority.remainsVisible(at: compression) }
            Group {
                if compression >= 5 {
                    ScrollView(group.axis == .horizontal ? .horizontal : .vertical) { stack(items: visible, spacing: spacing, compression: compression) }
                } else {
                    stack(items: visible, spacing: spacing, compression: compression)
                }
            }
            .padding(.top, group.padding.top).padding(.leading, group.padding.leading)
            .padding(.bottom, group.padding.bottom).padding(.trailing, group.padding.trailing)
        }
        .frame(minHeight: group.axis == .vertical ? estimatedHeight : 54)
    }

    @ViewBuilder private func stack(items: [OpenNotchItem], spacing: Double, compression: Int) -> some View {
        if group.axis == .horizontal {
            HStack(alignment: group.alignment.verticalAlignment, spacing: spacing) {
                ForEach(items) { item in OpenNotchItemView(item: item, layout: layout, store: store, compression: compression) }
            }.frame(maxWidth: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        } else {
            VStack(alignment: group.alignment.horizontalAlignment, spacing: spacing) {
                ForEach(items) { item in OpenNotchItemView(item: item, layout: layout, store: store, compression: compression) }
            }.frame(maxWidth: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        }
    }

    private var estimatedHeight: CGFloat {
        let h = group.items.reduce(0.0) { $0 + min($1.sizing.preferredHeight, 260) } + max(0, Double(group.items.count - 1)) * group.spacing
        return CGFloat(min(720, max(54, h + group.padding.top + group.padding.bottom)))
    }
    private func compressionLevel(available: CGFloat, wanted: Double) -> Int {
        guard wanted > 0, available > 0 else { return 0 }
        let ratio = Double(available) / wanted
        if ratio >= 1 { return 0 }
        if ratio >= 0.86 { return 1 }   // spacing
        if ratio >= 0.72 { return 2 }   // secondary / optional metadata
        if ratio >= 0.58 { return 3 }   // compact presentation
        if ratio >= 0.44 { return 4 }   // truncate text
        return 5                         // scroll as a last resort
    }
}

private struct OpenNotchItemView: View {
    let item: OpenNotchItem
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    let compression: Int
    @State private var hover = false

    var body: some View {
        let presentation = resolvedPresentation
        let style = adaptedWidgetStyle(presentation: presentation)
        let itemStyle = item.style ?? WidgetElementStyle()
        Group {
            switch item.kind {
            case .module:
                if let module = item.module, layout.enabled.contains(module) {
                    WidgetCard(style: style) { BuiltinOrIntegrationWidget(module: module, store: store) }
                        .environment(\.openNotchPresentation, presentation)
                        .environment(\.openNotchCompressionLevel, compression)
                }
            case .element:
                if let element = item.element {
                    WidgetElementSurface(element: itemStyle, widgetStyle: style, defaultPriority: item.priority) {
                        OpenNotchLightweightElement(kind: element, item: item, store: store)
                    }
                    .environment(\.openNotchPresentation, presentation)
                    .environment(\.openNotchCompressionLevel, compression)
                }
            case .spacer:
                Spacer(minLength: CGFloat(max(8, item.sizing.minimumWidth)))
            case .divider:
                Divider().opacity(itemStyle.opacity)
            }
        }
        .modifier(OpenNotchSizingModifier(sizing: item.sizing))
        .contentShape(Rectangle())
        .opacity(hover ? 1 : 0.985)
        .onHover { hover = $0 }
        .modifier(OpenNotchInteractionModifier(item: item, store: store))
        .transition(.opacity.combined(with: .scale(scale: 0.975)))
    }

    private var resolvedPresentation: OpenNotchPresentation {
        if item.presentation != .automatic { return item.presentation }
        if compression >= 3 { return .compact }
        if item.sizing.preferredWidth >= 420 || item.sizing.preferredHeight >= 240 { return .expanded }
        if item.sizing.preferredWidth < 220 || item.sizing.preferredHeight < 90 { return .compact }
        return .regular
    }
    private func adaptedWidgetStyle(presentation: OpenNotchPresentation) -> WidgetStyle {
        guard let module = item.module else { return WidgetStyle() }
        var style = layout.widgetStyle(for: module)
        switch presentation {
        case .compact: style.layoutMode = .compact
        case .expanded: style.layoutMode = .hero
        case .regular, .automatic: style.layoutMode = .standard
        }
        if compression >= 2 {
            var content = style.resolvedContent
            content.showSecondaryText = false; content.mediaShowArtist = false; content.mediaShowSource = false
            content.calendarShowTimes = false; content.shelfShowDetails = false; content.activitiesShowDetail = false
            style.content = content
        }
        if compression >= 4 {
            var content = style.resolvedContent
            content.mediaTitleLines = 1; content.maxItems = min(3, content.maxItems)
            style.content = content
        }
        return style
    }
}

private struct OpenNotchSizingModifier: ViewModifier {
    let sizing: OpenNotchSizing
    func body(content: Content) -> some View {
        switch sizing.mode {
        case .fixed:
            content.frame(width: sizing.preferredWidth, height: sizing.preferredHeight)
        case .fitContent:
            content.frame(minWidth: sizing.minimumWidth, idealWidth: sizing.preferredWidth, maxWidth: sizing.maximumWidth,
                          minHeight: sizing.minimumHeight, idealHeight: sizing.preferredHeight, maxHeight: sizing.maximumHeight)
                .fixedSize(horizontal: false, vertical: false)
        case .flexible:
            content.frame(minWidth: sizing.minimumWidth, idealWidth: sizing.preferredWidth, maxWidth: sizing.maximumWidth,
                          minHeight: sizing.minimumHeight, idealHeight: sizing.preferredHeight, maxHeight: sizing.maximumHeight)
        case .fill:
            content.frame(minWidth: sizing.minimumWidth, maxWidth: .infinity, minHeight: sizing.minimumHeight, maxHeight: .infinity)
        }
    }
}

private struct OpenNotchLightweightElement: View {
    let kind: OpenNotchElementKind
    let item: OpenNotchItem
    @ObservedObject var store: AppStore
    @State private var image: NSImage?
    var body: some View {
        let workspace = store.workspace
        switch kind {
        case .clock:
            TimelineView(.periodic(from: .now, by: 1)) { context in Text(context.date, style: .time).monospacedDigit() }
        case .date: Text(Date(), style: .date)
        case .battery:
            if let battery = workspace.system.battery { Label("\(battery)%", systemImage: workspace.system.charging ? "battery.100.bolt" : "battery.100") }
        case .batteryPercentage:
            if let battery = workspace.system.battery { Text("\(battery)%").monospacedDigit() }
        case .chargingState:
            if workspace.system.charging { Label("Charging", systemImage: "bolt.fill") }
        case .appIcon:
            if let icon = NSWorkspace.shared.frontmostApplication?.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: item.style?.iconSize ?? 24, height: item.style?.iconSize ?? 24) }
        case .appName: Text(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
        case .volume:
            if workspace.audio.canSetVolume {
                HStack { Image(systemName: "speaker.wave.2"); Slider(value: Binding(get: { Double(workspace.audio.volume) }, set: { workspace.audio.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }; Text("\(Int(workspace.audio.volume * 100))%").monospacedDigit() }
            }
        case .brightness:
            if let brightness = workspace.system.brightness {
                HStack { Image(systemName: "sun.max"); Slider(value: Binding(get: { brightness }, set: { workspace.system.setBrightness($0) }), in: 0...1) { Text("Brightness") } }
            }
        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
            else if store.pausedSeconds > 0 { Text("Paused · \(Int(store.pausedSeconds))s").monospacedDigit() }
            else { Text("Timer ready") }
        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0)
                Text(String(format: "%02d:%02d:%02d", Int(elapsed) / 3600, Int(elapsed) / 60 % 60, Int(elapsed) % 60)).monospacedDigit()
            }
        case .mediaTitle: if workspace.media.connectedApp != nil { Text(workspace.media.title).lineLimit(1) }
        case .artist: if !workspace.media.artist.isEmpty { Text(workspace.media.artist).lineLimit(1) }
        case .albumArt:
            if let art = workspace.media.artworkImage { Image(nsImage: art).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 8)) }
        case .playbackControls:
            if workspace.media.connectedApp != nil {
                HStack {
                    Button { workspace.media.perform("previous track", app: workspace.settings.mediaApp) } label: { Image(systemName: "backward.end.fill") }
                    Button { workspace.media.perform("playpause", app: workspace.settings.mediaApp) } label: { Image(systemName: workspace.media.isPlaying ? "pause.fill" : "play.fill") }
                    Button { workspace.media.perform("next track", app: workspace.settings.mediaApp) } label: { Image(systemName: "forward.end.fill") }
                }
            }
        case .playbackProgress:
            if workspace.media.duration > 0 {
                Slider(value: Binding(get: { workspace.media.position }, set: { workspace.media.seek(to: $0) }), in: 0...max(1, workspace.media.duration)) { Text("Playback progress") }
            }
        case .cpu: Label(String(format: "CPU %.0f%%", workspace.system.cpuUsage), systemImage: "cpu")
        case .ram: Label(String(format: "RAM %.0f%%", workspace.system.memoryUsage), systemImage: "memorychip")
        case .storage: Label(String(format: "Disk %.0f%%", workspace.system.diskUsage), systemImage: "internaldrive")
        case .networkActivity:
            Label("↓ \(Self.rate(workspace.system.networkDownPerSecond))  ↑ \(Self.rate(workspace.system.networkUpPerSecond))", systemImage: "network")
        case .customText: Text(item.customText)
        case .customIcon: Image(systemName: item.customIcon.isEmpty ? "sparkles" : item.customIcon).font(.system(size: item.style?.iconSize ?? 20))
        case .customImage, .customGIF:
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").foregroundStyle(.secondary).task { image = NSImage(contentsOfFile: item.customAssetPath) } }
        case .button:
            Button(item.buttonLabel) { if let url = URL(string: item.buttonURL), ["https", "http", "shortcuts"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) } }
        case .spacer: Spacer(minLength: 8)
        case .divider: Divider()
        }
    }
    private static func rate(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file) + "/s" }
}

private struct OpenNotchInteractionModifier: ViewModifier {
    let item: OpenNotchItem
    @ObservedObject var store: AppStore
    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 2) { perform(item.interactions.doubleClick) }
            .simultaneousGesture(TapGesture(count: 1).onEnded {
                let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                perform(modifiers.isEmpty ? item.interactions.singleClick : item.interactions.modifierClick)
            })
            .contextMenu {
                if item.interactions.rightClick != .none { Button(item.interactions.rightClick.rawValue) { perform(item.interactions.rightClick) } }
            }
            .background {
                if item.interactions.scroll != .none { OpenNotchScrollCapture { perform(item.interactions.scroll, delta: $0) }.allowsHitTesting(true) }
            }
            .onDrag {
                if item.interactions.drag != .none { perform(item.interactions.drag) }
                return NSItemProvider(object: item.id.uuidString as NSString)
            }
    }
    private func perform(_ action: OpenNotchInteractionAction, delta: Double = 0) {
        let workspace = store.workspace
        switch action {
        case .none: break
        case .togglePlayback: workspace.media.perform("playpause", app: workspace.settings.mediaApp)
        case .nextTrack: workspace.media.perform("next track", app: workspace.settings.mediaApp)
        case .previousTrack: workspace.media.perform("previous track", app: workspace.settings.mediaApp)
        case .openPlayer:
            if let id = workspace.media.connectedApp, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first { app.activate(options: .activateIgnoringOtherApps) }
        case .adjustVolume:
            guard workspace.audio.canSetVolume else { return }
            workspace.audio.setVolume(min(1, max(0, workspace.audio.volume + Float(delta > 0 ? 0.04 : -0.04))))
        case .seekMedia: if workspace.media.duration > 0 { workspace.media.seek(to: min(workspace.media.duration, max(0, workspace.media.position + (delta > 0 ? 5 : -5)))) }
        case .toggleTimer:
            if store.deadline != nil || store.pausedSeconds > 0 { store.pauseResume() } else { store.startTimer(minutes: 25) }
        case .toggleStopwatch: workspace.toggleStopwatch()
        case .openSystemSettings:
            if let url = URL(string: "x-apple.systempreferences:") { NSWorkspace.shared.open(url) }
        }
    }
}

private struct OpenNotchScrollCapture: NSViewRepresentable {
    let onScroll: (Double) -> Void
    final class View: NSView {
        var callback: ((Double) -> Void)?
        override func scrollWheel(with event: NSEvent) { callback?(event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY) }
    }
    func makeNSView(context: Context) -> View { let v = View(); v.callback = onScroll; return v }
    func updateNSView(_ nsView: View, context: Context) { nsView.callback = onScroll }
}

private extension OpenNotchRegionPlacement {
    var sortIndex: Int { OpenNotchRegionPlacement.allCases.firstIndex(of: self) ?? 0 }
    var regionAlignment: Alignment {
        switch self {
        case .topLeft: return .topLeading; case .topCenter: return .top; case .topRight: return .topTrailing
        case .middleLeft: return .leading; case .middleCenter: return .center; case .middleRight: return .trailing
        case .bottomLeft: return .bottomLeading; case .bottomCenter: return .bottom; case .bottomRight: return .bottomTrailing
        }
    }
}
private extension OpenNotchGroupAlignment {
    var horizontalAlignment: HorizontalAlignment { switch self { case .center: return .center; case .trailing: return .trailing; default: return .leading } }
    var verticalAlignment: VerticalAlignment { switch self { case .center: return .center; case .trailing: return .bottom; default: return .top } }
    var horizontalFrameAlignment: Alignment { switch self { case .center: return .center; case .trailing: return .trailing; default: return .leading } }
}
'''
if 'private struct OpenNotchWorkspaceView:' not in s:
    s = s.replace('\nprivate struct DropContextView: View {', runtime + '\nprivate struct DropContextView: View {', 1)
write(p, s)

# -----------------------------------------------------------------------------
# Visual editor: live structural preview + DnD + inspector; avoids one giant form.
# -----------------------------------------------------------------------------
p = 'Halo/Views/WidgetSettingsView.swift'
s = read(p)
if 'import UniformTypeIdentifiers' not in s:
    s = s.replace('import AppKit\n', 'import AppKit\nimport UniformTypeIdentifiers\n', 1)
if '@State private var showingOpenWorkspaceEditor' not in s:
    s = s.replace('    @State private var installedFonts: [String] = []\n', '    @State private var installedFonts: [String] = []\n    @State private var showingOpenWorkspaceEditor = false\n', 1)

intro = '''        Section("Opened notch widget") {\n            Text("Customize \\(selected.title) independently. These settings apply to the widget in Halo's opened dashboard and travel with profiles and display-specific layouts.")\n                .font(.caption).foregroundStyle(.secondary)\n        }\n'''
intro2 = '''        Section("Opened notch workspace") {\n            Button { showingOpenWorkspaceEditor = true } label: { Label("Open Visual Workspace Editor…", systemImage: "rectangle.3.group") }\n            Text("Arrange regions, groups, modules and lightweight elements visually. Widget styling below remains available for deep per-module tuning.")\n                .font(.caption).foregroundStyle(.secondary)\n        }\n        .sheet(isPresented: $showingOpenWorkspaceEditor) {\n            OpenedNotchWorkspaceEditor(layout: $layout)\n                .frame(minWidth: 980, idealWidth: 1120, minHeight: 680, idealHeight: 760)\n        }\n        Section("Opened notch widget") {\n            Text("Customize \\(selected.title) independently. These settings apply to the widget in Halo's opened dashboard and travel with profiles and display-specific layouts.")\n                .font(.caption).foregroundStyle(.secondary)\n        }\n'''
if 'Open Visual Workspace Editor' not in s:
    if intro not in s: raise SystemExit('widget intro section not found')
    s = s.replace(intro, intro2, 1)

# Add priority control to the existing per-element disclosure.
needle = '''                        Picker("Emphasis", selection: value.emphasis) {\n                            ForEach(WidgetElementEmphasis.allCases) { Text($0.rawValue).tag($0) }\n                        }\n'''
priority_ui = '''                        Picker("Emphasis", selection: value.emphasis) {\n                            ForEach(WidgetElementEmphasis.allCases) { Text($0.rawValue).tag($0) }\n                        }\n                        Picker("Collapse priority", selection: Binding(\n                            get: { value.wrappedValue.priority ?? .normal },\n                            set: { value.wrappedValue.priority = $0 }\n                        )) { ForEach(OpenNotchPriority.allCases) { Text($0.rawValue).tag($0) } }\n'''
s = s.replace(needle, priority_ui, 1)

editor = r'''

private struct OpenedNotchWorkspaceEditor: View {
    @Binding var layout: WorkspaceLayout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedItem: UUID?
    @State private var selectedGroup: UUID?
    @State private var selectedRegion: UUID?
    @State private var backgroundMode = false

    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                toolbar
                Divider()
                ScrollView([.horizontal, .vertical]) { preview.padding(26).frame(minWidth: 640, minHeight: 560) }
            }.frame(minWidth: 650)
            inspector.frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
        }
        .onAppear { materialize() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("Layout", selection: Binding(get: { layout.resolvedOpenNotchContentMode }, set: { layout.openNotchContentMode = $0 })) {
                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 250)
            Picker("Preset", selection: Binding(get: { opened.preset }, set: { applyPreset($0) })) {
                ForEach(OpenNotchPreset.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 190)
            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            Button { duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.disabled(selectedItem == nil).help("Duplicate selected item")
            Button { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil } label: { Image(systemName: "paintbrush") }.help("Opened surface appearance")
            Spacer()
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }.padding(12)
    }

    @ViewBuilder private var addMenu: some View {
        Menu("Module") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }
        Menu("Lightweight element") { ForEach(OpenNotchElementKind.allCases) { element in Button(element.title) { addElement(element) } } }
        Divider()
        Button("Group") { addGroup() }
        Menu("Region") { ForEach(OpenNotchRegionPlacement.allCases) { placement in Button(placement.title) { ensureRegion(placement, select: true) } } }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text("Opened Notch").font(.headline); Text(opened.preset.rawValue).font(.caption).foregroundStyle(.secondary) }
                Spacer(); Text("Drag items between regions · drag corner to resize").font(.caption).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay {
                    VStack(spacing: 8) {
                        editorRow([.topLeft, .topCenter, .topRight])
                        editorRow([.middleLeft, .middleCenter, .middleRight])
                        editorRow([.bottomLeft, .bottomCenter, .bottomRight])
                    }.padding(14)
                }
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                .frame(width: 610, height: 470)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)
        }
    }

    @ViewBuilder private func editorRow(_ placements: [OpenNotchRegionPlacement]) -> some View {
        HStack(spacing: 8) {
            ForEach(placements) { placement in regionCell(placement).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.frame(maxHeight: .infinity)
    }

    private func regionCell(_ placement: OpenNotchRegionPlacement) -> some View {
        let region = opened.regions.first { $0.placement == placement }
        return VStack(alignment: .leading, spacing: 6) {
            HStack { Text(placement.title).font(.system(size: 9, weight: .semibold)); Spacer(); if region != nil { Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.green) } }
            if let region {
                ForEach(region.groups) { group in groupPreview(group, region: region) }
            } else {
                Spacer(); Text("Drop here").font(.caption2).foregroundStyle(.tertiary).frame(maxWidth: .infinity); Spacer()
            }
        }
        .padding(7)
        .background((selectedRegion == region?.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.035)), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedRegion == region?.id ? Color.accentColor.opacity(0.6) : .white.opacity(0.06)))
        .contentShape(Rectangle())
        .onTapGesture { if let region { selectedRegion = region.id; selectedGroup = nil; selectedItem = nil; backgroundMode = false } }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, placement: placement) }
    }

    private func groupPreview(_ group: OpenNotchGroup, region: OpenNotchRegion) -> some View {
        let stack = Group {
            if group.axis == .horizontal {
                HStack(spacing: min(6, group.spacing)) { itemList(group, region: region) }
            } else {
                VStack(alignment: .leading, spacing: min(6, group.spacing)) { itemList(group, region: region) }
            }
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack { Text(group.name).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary); Spacer(); Image(systemName: group.axis == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down").font(.system(size: 8)) }
            stack
        }
        .padding(5)
        .background(selectedGroup == group.id ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { selectedGroup = group.id; selectedRegion = region.id; selectedItem = nil; backgroundMode = false }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, groupID: group.id) }
    }

    @ViewBuilder private func itemList(_ group: OpenNotchGroup, region: OpenNotchRegion) -> some View {
        ForEach(group.items) { item in itemPreview(item, group: group, region: region) }
    }

    private func itemPreview(_ item: OpenNotchItem, group: OpenNotchGroup, region: OpenNotchRegion) -> some View {
        let label = item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized
        return HStack(spacing: 4) {
            Image(systemName: item.module?.symbol ?? item.element?.symbol ?? (item.kind == .divider ? "minus" : "rectangle"))
            Text(label).lineLimit(1)
            if item.hidden { Image(systemName: "eye.slash").foregroundStyle(.secondary) }
        }
        .font(.system(size: 9, weight: item.priority == .alwaysVisible || item.priority == .high ? .semibold : .regular))
        .padding(.horizontal, 6).padding(.vertical, 5)
        .frame(minWidth: max(42, min(150, item.sizing.preferredWidth * 0.28)), alignment: .leading)
        .background(selectedItem == item.id ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
        .overlay(alignment: .bottomTrailing) {
            if selectedItem == item.id {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 7)).padding(3).background(.ultraThinMaterial, in: Circle()).offset(x: 4, y: 4)
                    .gesture(DragGesture().onChanged { value in resize(item.id, translation: value.translation) })
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedItem = item.id; selectedGroup = group.id; selectedRegion = region.id; backgroundMode = false }
        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, groupID: group.id, before: item.id) }
        .contextMenu {
            Button(item.hidden ? "Show" : "Hide") { mutateItem(item.id) { $0.hidden.toggle() } }
            Button("Duplicate") { duplicate(item.id) }
            Button("Move to New Group") { groupSelectedItem() }
            Divider(); Button("Remove", role: .destructive) { remove(item.id) }
        }
    }

    @ViewBuilder private var inspector: some View {
        Form {
            if backgroundMode { backgroundInspector }
            else if let item = selectedItem.flatMap(findItem) { itemInspector(item) }
            else if let group = selectedGroup.flatMap(findGroup) { groupInspector(group) }
            else if let region = selectedRegion.flatMap(findRegion) { regionInspector(region) }
            else {
                Section("Opened workspace") {
                    Text("Select an item, group, or region in the preview. Drag modules between regions and use the resize handle on a selected item.").foregroundStyle(.secondary)
                    Button("Customize Surface Appearance") { backgroundMode = true }
                }
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }

    @ViewBuilder private func itemInspector(_ item: OpenNotchItem) -> some View {
        let binding = itemBinding(item.id)
        Section("Item") {
            Text(item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized).font(.headline)
            Toggle("Visible", isOn: Binding(get: { !binding.wrappedValue.hidden }, set: { binding.wrappedValue.hidden = !$0 }))
            Picker("Presentation", selection: binding.presentation) { ForEach(OpenNotchPresentation.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Priority", selection: binding.priority) { ForEach(OpenNotchPriority.allCases) { Text($0.rawValue).tag($0) } }
        }
        Section("Responsive sizing") {
            Picker("Behavior", selection: binding.sizing.mode) { ForEach(OpenNotchSizingMode.allCases) { Text($0.rawValue).tag($0) } }
            sizingSlider("Min width", binding.sizing.minimumWidth, 20...1200)
            sizingSlider("Preferred width", binding.sizing.preferredWidth, 20...1200)
            sizingSlider("Max width", binding.sizing.maximumWidth, 20...1600)
            sizingSlider("Min height", binding.sizing.minimumHeight, 18...900)
            sizingSlider("Preferred height", binding.sizing.preferredHeight, 18...1100)
            sizingSlider("Max height", binding.sizing.maximumHeight, 18...1400)
        }
        Section("Element styling") { styleInspector(binding.style) }
        Section("Visibility rules") {
            Picker("Match", selection: binding.visibilityLogic) { ForEach(OpenNotchVisibilityLogic.allCases) { Text($0.rawValue).tag($0) } }
            ForEach(Array(binding.wrappedValue.visibilityRules.enumerated()), id: \.element.id) { index, rule in
                let rb = ruleBinding(item.id, index: index)
                HStack { Picker("Metric", selection: rb.metric) { ForEach(OpenNotchVisibilityMetric.allCases) { Text($0.rawValue).tag($0) } }; Button { removeRule(item.id, index: index) } label: { Image(systemName: "minus.circle") } }
                Picker("Condition", selection: rb.comparison) { ForEach(OpenNotchVisibilityComparison.allCases) { Text($0.rawValue).tag($0) } }
                if rb.wrappedValue.metric.isBoolean { Toggle("Required state", isOn: Binding(get: { rb.wrappedValue.value >= 0.5 }, set: { rb.wrappedValue.value = $0 ? 1 : 0 })) }
                else { PreciseSlider(title: "Value", value: rb.value, range: 0...100, step: 1, suffix: "%") }
                if index < binding.wrappedValue.visibilityRules.count - 1 { Divider() }
            }
            Button("Add Rule") { binding.wrappedValue.visibilityRules.append(OpenNotchVisibilityRule()) }
        }
        Section("Interactions") {
            interactionPicker("Single click", binding.interactions.singleClick)
            interactionPicker("Double click", binding.interactions.doubleClick)
            interactionPicker("Right click", binding.interactions.rightClick)
            interactionPicker("Scroll", binding.interactions.scroll)
            interactionPicker("Drag", binding.interactions.drag)
            interactionPicker("Modifier click", binding.interactions.modifierClick)
        }
        if item.element == .customText { Section("Content") { TextField("Text", text: binding.customText) } }
        if item.element == .customIcon { Section("Content") { TextField("SF Symbol", text: binding.customIcon) } }
        if item.element == .customImage || item.element == .customGIF { Section("Content") { TextField("Image / GIF path", text: binding.customAssetPath) } }
        if item.element == .button { Section("Content") { TextField("Label", text: binding.buttonLabel); TextField("URL", text: binding.buttonURL) } }
        Section { HStack { Button("Duplicate") { duplicate(item.id) }; Button("New Group") { groupSelectedItem() }; Spacer(); Button("Remove", role: .destructive) { remove(item.id) } } }
    }

    @ViewBuilder private func groupInspector(_ group: OpenNotchGroup) -> some View {
        let b = groupBinding(group.id)
        Section("Group") {
            TextField("Name", text: b.name)
            Picker("Direction", selection: b.axis) { ForEach(OpenNotchAxis.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Alignment", selection: b.alignment) { ForEach(OpenNotchGroupAlignment.allCases) { Text($0.rawValue).tag($0) } }
            PreciseSlider(title: "Spacing", value: b.spacing, range: 0...48, step: 1, suffix: "pt")
        }
        Section("Group padding") { insetsEditor(b.padding) }
    }

    @ViewBuilder private func regionInspector(_ region: OpenNotchRegion) -> some View {
        let b = regionBinding(region.id)
        Section("Region") { Picker("Placement", selection: b.placement) { ForEach(OpenNotchRegionPlacement.allCases) { Text($0.title).tag($0) } } }
        Section("Region padding") { insetsEditor(b.padding) }
        Section { Button("Add Group") { addGroup(regionID: region.id) } }
    }

    @ViewBuilder private var backgroundInspector: some View {
        let b = openBinding()
        Section("Opened notch surface") {
            Picker("Background", selection: Binding(get: { b.wrappedValue.appearance.background ?? layout.appearance.background }, set: { b.wrappedValue.appearance.background = $0 })) {
                ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            ColorPicker("Solid / tint color", selection: Binding(get: { (b.wrappedValue.appearance.solidColor ?? layout.appearance.solidColor ?? .white).color }, set: { b.wrappedValue.appearance.solidColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Gradient start", selection: Binding(get: { (b.wrappedValue.appearance.gradientStartColor ?? layout.appearance.gradientStartColor ?? WidgetColor(red: 0.07, green: 0.09, blue: 0.14)).color }, set: { b.wrappedValue.appearance.gradientStartColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Gradient end", selection: Binding(get: { (b.wrappedValue.appearance.gradientEndColor ?? layout.appearance.gradientEndColor ?? WidgetColor(red: 0.01, green: 0.02, blue: 0.04)).color }, set: { b.wrappedValue.appearance.gradientEndColor = WidgetColor($0) }), supportsOpacity: false)
            TextField("Image / video path", text: b.appearance.assetPath)
        }
        Section("Material") {
            optionalSlider("Blur", b.appearance.blur, fallback: layout.appearance.blur, range: 0...30, suffix: "pt")
            optionalSlider("Saturation", b.appearance.saturation, fallback: layout.appearance.saturation, range: 0...2.5, step: 0.05, suffix: "×", decimals: 2)
            optionalSlider("Brightness", b.appearance.brightness, fallback: layout.appearance.brightness, range: -0.5...0.5, step: 0.02, decimals: 2)
            optionalSlider("Contrast", b.appearance.contrast, fallback: 1, range: 0.5...2, step: 0.05, suffix: "×", decimals: 2)
            optionalSlider("Grain", b.appearance.grain, fallback: 0, range: 0...0.35, step: 0.01, decimals: 2)
            optionalSlider("Warmth", b.appearance.warmth, fallback: 0, range: -1...1, step: 0.05, decimals: 2)
            ColorPicker("Tint", selection: Binding(get: { (b.wrappedValue.appearance.tintColor ?? WidgetColor(red: 0.35, green: 0.55, blue: 1)).color }, set: { b.wrappedValue.appearance.tintColor = WidgetColor($0) }), supportsOpacity: false)
            optionalSlider("Tint opacity", b.appearance.tintOpacity, fallback: 0, range: 0...0.5, step: 0.01, decimals: 2)
        }
        Section("Edge & depth") {
            ColorPicker("Border", selection: Binding(get: { (b.wrappedValue.appearance.borderColor ?? .white).color }, set: { b.wrappedValue.appearance.borderColor = WidgetColor($0) }), supportsOpacity: false)
            optionalSlider("Border width", b.appearance.borderWidth, fallback: 0, range: 0...6, step: 0.25, suffix: "pt", decimals: 2)
            optionalSlider("Border opacity", b.appearance.borderOpacity, fallback: 0.2, range: 0...1, step: 0.05, decimals: 2)
            optionalSlider("Inner highlight", b.appearance.innerHighlight, fallback: 0, range: 0...0.5, step: 0.02, decimals: 2)
            optionalSlider("Shadow blur", b.appearance.shadowBlur, fallback: 12, range: 0...50, step: 1, suffix: "pt")
            optionalSlider("Shadow opacity", b.appearance.shadowOpacity, fallback: 0, range: 0...0.7, step: 0.02, decimals: 2)
            optionalSlider("Subtle glow", b.appearance.glow, fallback: 0, range: 0...0.5, step: 0.02, decimals: 2)
        }
    }

    @ViewBuilder private func styleInspector(_ optional: Binding<WidgetElementStyle?>) -> some View {
        let b = Binding<WidgetElementStyle>(get: { optional.wrappedValue ?? WidgetElementStyle() }, set: { optional.wrappedValue = $0 })
        Picker("Alignment", selection: Binding(get: { b.wrappedValue.alignment ?? .leading }, set: { b.wrappedValue.alignment = $0 })) { ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) } }
        Picker("Text alignment", selection: Binding(get: { b.wrappedValue.textAlignment ?? .leading }, set: { b.wrappedValue.textAlignment = $0 })) { ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) } }
        PreciseSlider(title: "Scale", value: b.fontScale, range: 0.55...2.5, step: 0.05, suffix: "×", decimals: 2)
        PreciseSlider(title: "Opacity", value: b.opacity, range: 0.15...1, step: 0.05, decimals: 2)
        PreciseSlider(title: "Internal padding", value: b.padding, range: 0...24, step: 1, suffix: "pt")
        optionalSlider("External spacing", b.externalSpacing, fallback: 0, range: 0...48, step: 1, suffix: "pt")
        optionalSlider("X offset", b.xOffset, fallback: 0, range: -100...100, step: 1, suffix: "pt")
        optionalSlider("Y offset", b.yOffset, fallback: 0, range: -100...100, step: 1, suffix: "pt")
        Picker("Font", selection: Binding(get: { b.wrappedValue.fontFamily ?? .system }, set: { b.wrappedValue.fontFamily = $0 })) { ForEach(WidgetFontFamily.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
        optionalSlider("Font size", b.fontSize, fallback: 14, range: 8...72, step: 1, suffix: "pt")
        Picker("Weight", selection: Binding(get: { b.wrappedValue.fontWeight ?? .regular }, set: { b.wrappedValue.fontWeight = $0 })) { ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
        Picker("Foreground", selection: b.foreground) { ForEach(WidgetElementForegroundStyle.allCases) { Text($0.rawValue).tag($0) } }
        if b.wrappedValue.foreground == .custom { ColorPicker("Foreground color", selection: Binding(get: { b.wrappedValue.customForeground.color }, set: { b.wrappedValue.customForeground = WidgetColor($0) }), supportsOpacity: false) }
        Picker("Background", selection: b.background) { ForEach(WidgetElementBackgroundStyle.allCases) { Text($0.rawValue).tag($0) } }
        if b.wrappedValue.background == .custom { ColorPicker("Background color", selection: Binding(get: { b.wrappedValue.backgroundColor.color }, set: { b.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false) }
        PreciseSlider(title: "Background opacity", value: b.backgroundOpacity, range: 0...1, step: 0.05, decimals: 2)
        PreciseSlider(title: "Corner radius", value: b.cornerRadius, range: 0...32, step: 1, suffix: "pt")
        optionalSlider("Border width", b.borderWidth, fallback: 0, range: 0...8, step: 0.25, suffix: "pt", decimals: 2)
        optionalSlider("Border opacity", b.borderOpacity, fallback: 0, range: 0...1, step: 0.05, decimals: 2)
        optionalSlider("Shadow blur", b.shadowBlur, fallback: 0, range: 0...48, step: 1, suffix: "pt")
        optionalSlider("Shadow opacity", b.shadowOpacity, fallback: 0, range: 0...0.8, step: 0.05, decimals: 2)
        optionalSlider("Tint opacity", b.tintOpacity, fallback: 1, range: 0...1, step: 0.05, decimals: 2)
        optionalSlider("Icon size", b.iconSize, fallback: 20, range: 6...96, step: 1, suffix: "pt")
        optionalSlider("Content density", b.contentDensity, fallback: 1, range: 0.5...1.5, step: 0.05, suffix: "×", decimals: 2)
    }

    @ViewBuilder private func insetsEditor(_ b: Binding<OpenNotchInsets>) -> some View {
        PreciseSlider(title: "Top", value: b.top, range: 0...96, step: 1, suffix: "pt")
        PreciseSlider(title: "Leading", value: b.leading, range: 0...96, step: 1, suffix: "pt")
        PreciseSlider(title: "Bottom", value: b.bottom, range: 0...96, step: 1, suffix: "pt")
        PreciseSlider(title: "Trailing", value: b.trailing, range: 0...96, step: 1, suffix: "pt")
    }
    @ViewBuilder private func sizingSlider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View { PreciseSlider(title: title, value: value, range: range, step: 1, suffix: "pt") }
    @ViewBuilder private func optionalSlider(_ title: String, _ value: Binding<Double?>, fallback: Double, range: ClosedRange<Double>, step: Double = 1, suffix: String = "", decimals: Int = 0) -> some View {
        PreciseSlider(title: title, value: Binding(get: { value.wrappedValue ?? fallback }, set: { value.wrappedValue = $0 }), range: range, step: step, suffix: suffix, decimals: decimals)
    }
    @ViewBuilder private func interactionPicker(_ title: String, _ value: Binding<OpenNotchInteractionAction>) -> some View { Picker(title, selection: value) { ForEach(OpenNotchInteractionAction.allCases) { Text($0.rawValue).tag($0) } } }

    private func materialize() { if layout.openNotch == nil { layout.materializeOpenNotchLayout() } }
    private func openBinding() -> Binding<OpenNotchLayout> { Binding(get: { layout.resolvedOpenNotchLayout }, set: { layout.openNotch = $0 }) }
    private func itemBinding(_ id: UUID) -> Binding<OpenNotchItem> { Binding(get: { findItem(id) ?? OpenNotchItem() }, set: { replacement in mutateItem(id) { $0 = replacement } }) }
    private func groupBinding(_ id: UUID) -> Binding<OpenNotchGroup> { Binding(get: { findGroup(id) ?? OpenNotchGroup() }, set: { replacement in mutateOpen { open in for ri in open.regions.indices { if let gi = open.regions[ri].groups.firstIndex(where: { $0.id == id }) { open.regions[ri].groups[gi] = replacement; return } } } }) }
    private func regionBinding(_ id: UUID) -> Binding<OpenNotchRegion> { Binding(get: { findRegion(id) ?? OpenNotchRegion() }, set: { replacement in mutateOpen { open in if let i = open.regions.firstIndex(where: { $0.id == id }) { open.regions[i] = replacement } } }) }
    private func ruleBinding(_ itemID: UUID, index: Int) -> Binding<OpenNotchVisibilityRule> { Binding(get: { findItem(itemID)?.visibilityRules.indices.contains(index) == true ? findItem(itemID)!.visibilityRules[index] : OpenNotchVisibilityRule() }, set: { replacement in mutateItem(itemID) { if $0.visibilityRules.indices.contains(index) { $0.visibilityRules[index] = replacement } } }) }
    private func findItem(_ id: UUID) -> OpenNotchItem? { opened.allItems.first { $0.id == id } }
    private func findGroup(_ id: UUID) -> OpenNotchGroup? { opened.regions.flatMap(\.groups).first { $0.id == id } }
    private func findRegion(_ id: UUID) -> OpenNotchRegion? { opened.regions.first { $0.id == id } }
    private func mutateOpen(_ body: (inout OpenNotchLayout) -> Void) { var value = opened; body(&value); value.preset = .custom; layout.openNotch = value }
    private func mutateItem(_ id: UUID, _ body: (inout OpenNotchItem) -> Void) { mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { if let ii = open.regions[ri].groups[gi].items.firstIndex(where: { $0.id == id }) { body(&open.regions[ri].groups[gi].items[ii]); return } } } } }
    private func removeRule(_ id: UUID, index: Int) { mutateItem(id) { if $0.visibilityRules.indices.contains(index) { $0.visibilityRules.remove(at: index) } } }

    private func ensureRegion(_ placement: OpenNotchRegionPlacement, select: Bool = false) {
        mutateOpen { open in
            if !open.regions.contains(where: { $0.placement == placement }) { open.regions.append(OpenNotchRegion(placement: placement, padding: OpenNotchInsets(), groups: [OpenNotchGroup(name: placement.title)])) }
        }
        if select, let r = opened.regions.first(where: { $0.placement == placement }) { selectedRegion = r.id }
    }
    private func defaultGroupID() -> UUID {
        if let selectedGroup, findGroup(selectedGroup) != nil { return selectedGroup }
        ensureRegion(.middleCenter)
        if let id = opened.regions.first(where: { $0.placement == .middleCenter })?.groups.first?.id { return id }
        let id = UUID(); mutateOpen { open in if let ri = open.regions.firstIndex(where: { $0.placement == .middleCenter }) { open.regions[ri].groups.append(OpenNotchGroup(id: id, name: "Main")) } }; return id
    }
    private func addModule(_ module: ModuleID) { var item = OpenNotchItem.moduleItem(module); let gid = defaultGroupID(); mutateOpen { open in append(item, to: gid, open: &open) }; layout.enabled.insert(module); selectedItem = item.id; selectedGroup = gid }
    private func addElement(_ element: OpenNotchElementKind) { let item = OpenNotchItem.elementItem(element); let gid = defaultGroupID(); mutateOpen { open in append(item, to: gid, open: &open) }; selectedItem = item.id; selectedGroup = gid }
    private func addGroup(regionID: UUID? = nil) { let rid = regionID ?? selectedRegion ?? { ensureRegion(.middleCenter); return opened.regions.first(where: { $0.placement == .middleCenter })?.id }()!; let group = OpenNotchGroup(name: "Group"); mutateOpen { open in if let ri = open.regions.firstIndex(where: { $0.id == rid }) { open.regions[ri].groups.append(group) } }; selectedGroup = group.id; selectedRegion = rid }
    private func append(_ item: OpenNotchItem, to groupID: UUID, open: inout OpenNotchLayout) { for ri in open.regions.indices { if let gi = open.regions[ri].groups.firstIndex(where: { $0.id == groupID }) { open.regions[ri].groups[gi].items.append(item); return } } }
    private func remove(_ id: UUID) { mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } } } }; selectedItem = nil }
    private func duplicate(_ id: UUID) { guard var copy = findItem(id) else { return }; copy.id = UUID(); let gid = selectedGroup ?? defaultGroupID(); mutateOpen { open in append(copy, to: gid, open: &open) }; selectedItem = copy.id }
    private func duplicateSelected() { if let selectedItem { duplicate(selectedItem) } }
    private func groupSelectedItem() { guard let id = selectedItem, let item = findItem(id) else { return }; let regionID = selectedRegion ?? opened.regions.first?.id; guard let regionID else { return }; let group = OpenNotchGroup(name: "Group", items: [item]); mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } }; if open.regions[ri].id == regionID { open.regions[ri].groups.append(group) } } }; selectedGroup = group.id }
    private func resize(_ id: UUID, translation: CGSize) { mutateItem(id) { item in item.sizing.mode = .flexible; item.sizing.preferredWidth = min(item.sizing.maximumWidth, max(item.sizing.minimumWidth, item.sizing.preferredWidth + translation.width * 0.08)); item.sizing.preferredHeight = min(item.sizing.maximumHeight, max(item.sizing.minimumHeight, item.sizing.preferredHeight + translation.height * 0.08)) } }
    private func applyPreset(_ preset: OpenNotchPreset) { guard preset != .custom else { mutateOpen { $0.preset = .custom }; return }; layout.applyOpenNotchPreset(preset); selectedItem = nil; selectedGroup = nil; selectedRegion = nil }

    private func acceptDrop(_ providers: [NSItemProvider], placement: OpenNotchRegionPlacement) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in guard let text = object as? String, let id = UUID(uuidString: text) else { return }; DispatchQueue.main.async { ensureRegion(placement); guard let gid = opened.regions.first(where: { $0.placement == placement })?.groups.first?.id else { return }; move(id, to: gid, before: nil) } }; return true
    }
    private func acceptDrop(_ providers: [NSItemProvider], groupID: UUID, before target: UUID? = nil) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in guard let text = object as? String, let id = UUID(uuidString: text) else { return }; DispatchQueue.main.async { move(id, to: groupID, before: target) } }; return true
    }
    private func move(_ id: UUID, to groupID: UUID, before target: UUID?) {
        guard let item = findItem(id) else { return }
        mutateOpen { open in
            for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } } }
            for ri in open.regions.indices { if let gi = open.regions[ri].groups.firstIndex(where: { $0.id == groupID }) { if let target, let index = open.regions[ri].groups[gi].items.firstIndex(where: { $0.id == target }) { open.regions[ri].groups[gi].items.insert(item, at: index) } else { open.regions[ri].groups[gi].items.append(item) }; return } }
        }
        selectedItem = id; selectedGroup = groupID
    }
}
'''
if 'private struct OpenedNotchWorkspaceEditor:' not in s:
    s += editor
write(p, s)

print('Opened-notch workspace architecture patch applied.')
