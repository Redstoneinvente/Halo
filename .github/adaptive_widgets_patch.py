from pathlib import Path
import re

ROOT = Path('.')

# ---------- Widget models ----------
models_path = ROOT / 'Halo/Core/WidgetModels.swift'
models = models_path.read_text()

adaptive_models = r'''
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
        let valid = Set(module.widgetElements.map(\.key))
        for key in informationPriority where valid.contains(key) && !result.contains(key) { result.append(key) }
        for key in module.visualAdaptiveDefaultInformationOrder where valid.contains(key) && !result.contains(key) { result.append(key) }
        for key in module.widgetElements.map(\.key) where !result.contains(key) { result.append(key) }
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
        case .timer, .media, .audio, .clipboard, .system, .launcher, .activities, .notes, .capture, .stopwatch: return true
        default: return false
        }
    }

    var visualAdaptiveAlwaysInformation: [String] {
        switch self {
        case .timer: return ["countdown"]
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
'''

if '// MARK: - Visual Workspace adaptive widget system' not in models:
    marker = 'struct WidgetStyle: Codable, Equatable {'
    if marker not in models: raise SystemExit('WidgetStyle marker missing')
    models = models.replace(marker, adaptive_models + '\n' + marker, 1)

if 'var visualAdaptive: VisualAdaptiveWidgetOptions?' not in models:
    marker = '    var visualCalendar: VisualCalendarOptions?\n'
    if marker not in models: raise SystemExit('visualCalendar property marker missing')
    models = models.replace(marker, marker + '    // Shared Visual Workspace adaptive options for non-Clock/Calendar widgets.\n    var visualAdaptive: VisualAdaptiveWidgetOptions?\n', 1)

if 'func resolvedVisualAdaptive(for module: ModuleID)' not in models:
    marker = '    var resolvedVisualCalendar: VisualCalendarOptions { visualCalendar ?? VisualCalendarOptions() }\n'
    if marker not in models: raise SystemExit('resolvedVisualCalendar marker missing')
    models = models.replace(marker, marker + '    func resolvedVisualAdaptive(for module: ModuleID) -> VisualAdaptiveWidgetOptions { visualAdaptive ?? .defaults(for: module) }\n', 1)

if 'v.visualAdaptive = try resolvedVisualAdaptive' not in models:
    marker = '        if visualCalendar != nil { v.visualCalendar = try resolvedVisualCalendar.validated() }\n'
    if marker not in models: raise SystemExit('WidgetStyle validation marker missing')
    models = models.replace(marker, marker + '        if visualAdaptive != nil { v.visualAdaptive = try resolvedVisualAdaptive(for: .timer).validated() }\n', 1)

models_path.write_text(models)

# ---------- Adaptive view source copied in by workflow; add missing presentation mapping ----------
adaptive_path = ROOT / 'Halo/Views/VisualWorkspaceAdaptiveWidgets.swift'
adaptive = adaptive_path.read_text()
if 'extension VisualAdaptivePresentation' not in adaptive:
    marker = 'enum VisualAdaptiveFamilyResolver {'
    extension = r'''
private extension VisualAdaptivePresentation {
    var family: VisualAdaptiveFamily {
        switch self {
        case .automatic, .standard: return .standard
        case .micro: return .micro
        case .compact: return .compact
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        case .expanded: return .expanded
        case .dashboard: return .dashboard
        case .hero: return .hero
        }
    }
}

'''
    adaptive = adaptive.replace(marker, extension + marker, 1)
adaptive_path.write_text(adaptive)

# ---------- Module routing ----------
module_path = ROOT / 'Halo/Views/ModuleViews.swift'
module = module_path.read_text()
start_marker = '    @ViewBuilder private var content: some View {\n'
end_marker = '    @ViewBuilder private var activitiesContent: some View {'
start = module.find(start_marker)
end = module.find(end_marker, start)
if start < 0 or end < 0: raise SystemExit('IntegrationModuleView content markers missing')
new_content = r'''    @ViewBuilder private var content: some View {
        switch id {
        case .media:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .media, store: store, workspace: workspace) }
            else { MediaModuleView(service: workspace.media, app: workspace.settings.mediaApp) }
        case .audio:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .audio, store: store, workspace: workspace) }
            else { AudioModuleView(service: workspace.audio) }
        case .calendar:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceCalendarView(service: workspace.calendar) }
            else { CalendarModuleView(service: workspace.calendar) }
        case .clipboard:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .clipboard, store: store, workspace: workspace) }
            else { ClipboardModuleView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled) }
        case .system:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .system, store: store, workspace: workspace) }
            else { SystemModuleView(service: workspace.system) }
        case .launcher:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .launcher, store: store, workspace: workspace) }
            else { LauncherModuleView(store: store, workspace: workspace) }
        case .activities:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .activities, store: store, workspace: workspace) }
            else { activitiesContent }
        case .notes:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .notes, store: store, workspace: workspace) }
            else { notesContent }
        case .capture:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .capture, store: store, workspace: workspace) }
            else { CaptureModuleView(service: workspace.capture, store: store) }
        case .stopwatch:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .stopwatch, store: store, workspace: workspace) }
            else { stopwatchContent }
        default: EmptyView()
        }
    }

'''
module = module[:start] + new_content + module[end:]
module_path.write_text(module)

# ---------- Timer routing ----------
surface_path = ROOT / 'Halo/Views/SurfaceView.swift'
surface = surface_path.read_text()
if '@Environment(\\.openNotchGridColumnSpan) private var gridColumnSpan' not in surface[surface.find('struct BuiltinOrIntegrationWidget'):surface.find('struct BuiltinOrIntegrationWidget')+1200]:
    marker = '    @Environment(\\.openNotchCompressionLevel) private var compression\n'
    idx = surface.find(marker, surface.find('struct BuiltinOrIntegrationWidget'))
    if idx < 0: raise SystemExit('BuiltinOrIntegrationWidget environment marker missing')
    surface = surface[:idx+len(marker)] + '    @Environment(\\.openNotchGridColumnSpan) private var gridColumnSpan\n    @Environment(\\.openNotchGridRowSpan) private var gridRowSpan\n' + surface[idx+len(marker):]
old = '        case .timer: timer\n'
new = '        case .timer:\n            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceTimerView(store: store) }\n            else { timer }\n'
idx = surface.find(old, surface.find('struct BuiltinOrIntegrationWidget'))
if idx < 0: raise SystemExit('Timer route marker missing')
surface = surface[:idx] + new + surface[idx+len(old):]
surface_path.write_text(surface)

# ---------- Timer model action ----------
app_path = ROOT / 'Halo/Core/AppStore.swift'
app = app_path.read_text()
if 'func addTimer(minutes: Int)' not in app:
    marker = '    func resetTimer() {\n'
    idx = app.find(marker)
    if idx < 0: raise SystemExit('resetTimer marker missing')
    method = r'''    func addTimer(minutes: Int) {
        let delta = TimeInterval(minutes * 60)
        guard delta != 0 else { return }
        if let current = deadline {
            let next = current.addingTimeInterval(delta)
            deadline = max(next, Date().addingTimeInterval(1))
            timerDurationSeconds = max(1, timerDurationSeconds + delta)
            defaults.set(deadline, forKey: "timer.deadline")
            defaults.set(timerDurationSeconds, forKey: "timer.durationSeconds")
            monitorTimer()
        } else if pausedSeconds > 0 {
            pausedSeconds = max(1, pausedSeconds + delta)
            timerDurationSeconds = max(pausedSeconds, timerDurationSeconds + delta)
        }
    }
'''
    app = app[:idx] + method + app[idx:]
app_path.write_text(app)

# ---------- Stopwatch laps ----------
workspace_path = ROOT / 'Halo/Core/WorkspaceStore.swift'
workspace = workspace_path.read_text()
if '@Published var stopwatchLaps' not in workspace:
    marker = '    @Published var stopwatchElapsed: TimeInterval = 0\n'
    if marker not in workspace: raise SystemExit('stopwatchElapsed marker missing')
    workspace = workspace.replace(marker, marker + '    @Published var stopwatchLaps: [TimeInterval] = []\n', 1)
if 'func lapStopwatch()' not in workspace:
    marker = '    private let hotkey = HotkeyService()\n'
    idx = workspace.find(marker)
    if idx < 0: raise SystemExit('Workspace hotkey marker missing')
    methods = r'''    func lapStopwatch() {
        guard let start = stopwatchStart else { return }
        let total = stopwatchElapsed + Date().timeIntervalSince(start)
        let previous = stopwatchLaps.reduce(0, +)
        let lap = max(0, total - previous)
        guard lap > 0.01 else { return }
        stopwatchLaps.append(lap)
        if stopwatchLaps.count > 50 { stopwatchLaps.removeFirst(stopwatchLaps.count - 50) }
    }
    func resetStopwatch() {
        stopwatchStart = nil
        stopwatchElapsed = 0
        stopwatchLaps = []
    }
'''
    workspace = workspace[:idx] + methods + workspace[idx:]
workspace_path.write_text(workspace)

# ---------- Capture recents ----------
capture_path = ROOT / 'Halo/Services/CaptureService.swift'
capture = capture_path.read_text()
if '@Published var recentCaptures' not in capture:
    capture = capture.replace('    @Published var error: String?\n', '    @Published var error: String?\n    @Published var recentCaptures: [URL] = []\n', 1)
old = '                if task.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) { completion(url) }\n'
new = '                if task.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) {\n                    self?.recentCaptures.removeAll { $0 == url }\n                    self?.recentCaptures.insert(url, at: 0)\n                    if let count = self?.recentCaptures.count, count > 8 { self?.recentCaptures.removeLast(count - 8) }\n                    completion(url)\n                }\n'
if old in capture: capture = capture.replace(old, new, 1)
else: raise SystemExit('Capture completion marker missing')
capture_path.write_text(capture)

# ---------- Audio mute ----------
integrations_path = ROOT / 'Halo/Services/Integrations.swift'
integrations = integrations_path.read_text()
if 'private var preMuteVolume' not in integrations:
    marker = '    @Published var error: String?\n    func refresh() {'
    idx = integrations.find(marker, integrations.find('final class AudioService'))
    if idx < 0: raise SystemExit('AudioService marker missing')
    integrations = integrations[:idx] + '    @Published var error: String?\n    private var preMuteVolume: Float32 = 0.5\n    func refresh() {' + integrations[idx+len(marker):]
old = '        var clamped = min(1, max(0, value))\n'
new = '        var clamped = min(1, max(0, value))\n        if clamped > 0.001 { preMuteVolume = clamped }\n'
idx = integrations.find(old, integrations.find('func setVolume'))
if idx >= 0 and 'preMuteVolume = clamped' not in integrations[idx:idx+250]: integrations = integrations[:idx] + new + integrations[idx+len(old):]
if 'func toggleMute()' not in integrations:
    marker = '\n}\n\n@MainActor\nfinal class MediaService'
    idx = integrations.find(marker, integrations.find('final class AudioService'))
    if idx < 0: raise SystemExit('AudioService end marker missing')
    method = r'''
    func toggleMute() {
        guard canSetVolume else { return }
        if volume > 0.001 {
            preMuteVolume = volume
            setVolume(0)
        } else {
            setVolume(max(0.05, preMuteVolume))
        }
    }
'''
    integrations = integrations[:idx] + method + integrations[idx:]
integrations_path.write_text(integrations)

# ---------- Visual Workspace settings ----------
settings_path = ROOT / 'Halo/Views/WidgetSettingsView.swift'
settings = settings_path.read_text()
route_marker = '''        if module == .calendar {
            visualCalendarSettings(style: style)
            visualCalendarSizeOverrideInspector(itemID: itemID, style: style)
        }
'''
if 'visualAdaptiveSettings(style: style, module: module)' not in settings:
    if route_marker not in settings: raise SystemExit('Calendar inspector route marker missing')
    settings = settings.replace(route_marker, route_marker + '''        if module.visualAdaptiveSupported {
            visualAdaptiveSettings(style: style, module: module)
            visualAdaptiveSizeOverrideInspector(itemID: itemID, style: style, module: module)
        }
''', 1)

helpers = r'''
    @ViewBuilder private func visualAdaptiveSettings(style: Binding<WidgetStyle>, module: ModuleID) -> some View {
        let adaptive = style.visualAdaptive.withDefault(VisualAdaptiveWidgetOptions.defaults(for: module))
        Section("Adaptive Layout") {
            Picker("Presentation", selection: adaptive.preferredPresentation) { ForEach(VisualAdaptivePresentation.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Density", selection: adaptive.density) { ForEach(VisualAdaptiveDensity.allCases) { Text($0.rawValue).tag($0) } }
            Stepper("Maximum items: \(adaptive.wrappedValue.maxItems)", value: adaptive.maxItems, in: 1...30)
            Toggle("Show controls", isOn: adaptive.showControls)
            Button("Reset All Size Overrides") { adaptive.wrappedValue.sizeOverrides = [:] }.disabled(adaptive.wrappedValue.sizeOverrides.isEmpty)
            Text("Automatic is recommended. Width, height and aspect ratio independently choose Micro, Compact, Horizontal, Vertical, Standard, Expanded, Dashboard or Hero layouts.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Information Priority") {
            if !module.visualAdaptiveAlwaysInformation.isEmpty {
                Text("Always").font(.caption2).foregroundStyle(.secondary)
                ForEach(module.visualAdaptiveAlwaysInformation, id: \.self) { key in
                    Label(module.widgetElements.first(where: { $0.key == key })?.title ?? key, systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
                }
            }
            Text("Lower-priority information disappears first as the widget becomes constrained.").font(.caption2).foregroundStyle(.secondary)
            ForEach(adaptive.wrappedValue.resolvedInformationPriority(for: module).filter { !module.visualAdaptiveAlwaysInformation.contains($0) }, id: \.self) { key in
                HStack(spacing: 7) {
                    Toggle(module.widgetElements.first(where: { $0.key == key })?.title ?? key, isOn: adaptiveInformationEnabled(adaptive, key))
                    Spacer(minLength: 2)
                    Button { moveAdaptiveInformation(adaptive, module: module, key: key, direction: -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.borderless)
                    Button { moveAdaptiveInformation(adaptive, module: module, key: key, direction: 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.borderless)
                }
            }
        }
        visualAdaptiveModuleSettings(adaptive, module: module)
    }

    @ViewBuilder private func visualAdaptiveModuleSettings(_ adaptive: Binding<VisualAdaptiveWidgetOptions>, module: ModuleID) -> some View {
        switch module {
        case .timer:
            Section("Timer") {
                Picker("Style", selection: adaptive.timerStyle) { ForEach(VisualTimerStyle.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Primary value", selection: adaptive.timerMode) { ForEach(VisualTimerMode.allCases) { Text($0.rawValue).tag($0) } }
                TextField("Timer name", text: adaptive.timerName)
                Toggle("Show seconds", isOn: adaptive.timerShowSeconds)
                PreciseSlider(title: "Progress thickness", value: Binding(get: { Double(adaptive.wrappedValue.timerProgressThickness) }, set: { adaptive.wrappedValue.timerProgressThickness = CGFloat($0) }), range: 1...18, step: 1, suffix: "pt")
            }
        case .media:
            Section("Media") {
                Picker("Micro style", selection: adaptive.mediaMicroStyle) { ForEach(VisualMediaMicroStyle.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Artwork shape", selection: adaptive.mediaArtworkShape) { ForEach(VisualAdaptiveArtworkShape.allCases) { Text($0.rawValue).tag($0) } }
                PreciseSlider(title: "Artwork scale", value: Binding(get: { Double(adaptive.wrappedValue.mediaArtworkScale) }, set: { adaptive.wrappedValue.mediaArtworkScale = CGFloat($0) }), range: 0.5...1.8, step: 0.05, suffix: "×", decimals: 2)
                PreciseSlider(title: "Artwork corner radius", value: Binding(get: { Double(adaptive.wrappedValue.mediaArtworkCornerRadius) }, set: { adaptive.wrappedValue.mediaArtworkCornerRadius = CGFloat($0) }), range: 0...60, step: 1, suffix: "pt")
                Toggle("Artwork background", isOn: adaptive.mediaArtworkBackground)
                if adaptive.wrappedValue.mediaArtworkBackground { PreciseSlider(title: "Artwork background blur", value: Binding(get: { Double(adaptive.wrappedValue.mediaArtworkBlur) }, set: { adaptive.wrappedValue.mediaArtworkBlur = CGFloat($0) }), range: 0...40, step: 1, suffix: "pt") }
                Toggle("Artwork-derived accent", isOn: adaptive.mediaUseArtworkColors)
                Picker("Progress", selection: adaptive.mediaProgressStyle) { ForEach(VisualAdaptiveProgressStyle.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Visualizer on large layouts", isOn: adaptive.mediaVisualizer)
                if adaptive.wrappedValue.mediaVisualizer { Picker("Visualizer position", selection: adaptive.mediaVisualizerPosition) { ForEach(VisualAdaptiveVisualizerPosition.allCases) { Text($0.rawValue).tag($0) } } }
                Text("Shuffle and repeat only appear when the connected player reports support. Lyrics remain hidden because Halo does not currently expose a reliable lyric source to this widget.").font(.caption2).foregroundStyle(.secondary)
            }
        case .audio:
            Section("Audio") {
                Picker("Slider", selection: adaptive.audioSliderStyle) { ForEach(VisualAdaptiveAudioSliderStyle.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Volume percentage", isOn: adaptive.audioShowPercentage)
                Toggle("Device icon", isOn: adaptive.audioShowDeviceIcon)
                Toggle("Volume slider", isOn: adaptive.audioShowSlider)
                Toggle("Output selector", isOn: adaptive.audioShowOutputSelector)
                Toggle("Quick volume levels", isOn: adaptive.audioShowQuickLevels)
                Text("Input/microphone controls are intentionally absent until Halo has a supported input-audio control path.").font(.caption2).foregroundStyle(.secondary)
            }
        case .clipboard:
            Section("Clipboard") {
                Stepper("Preview length: \(adaptive.wrappedValue.clipboardPreviewLength)", value: adaptive.clipboardPreviewLength, in: 16...500, step: 8)
                Toggle("Timestamps", isOn: adaptive.clipboardShowTimestamp)
                Toggle("Search", isOn: adaptive.clipboardShowSearch)
                Picker("Rows", selection: adaptive.clipboardRowStyle) { ForEach(VisualAdaptiveClipboardRowStyle.allCases) { Text($0.rawValue).tag($0) } }
                Text("Halo currently stores text clipboard history only. Sensitive/concealed pasteboard entries remain excluded rather than being retained and marked.").font(.caption2).foregroundStyle(.secondary)
            }
        case .system:
            Section("System") {
                Picker("Primary metric", selection: adaptive.systemPrimaryMetric) { ForEach(VisualSystemMetric.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("History graphs", isOn: adaptive.systemShowGraphs)
                if adaptive.wrappedValue.systemShowGraphs { Picker("Graph style", selection: adaptive.systemGraphType) { ForEach(VisualSystemGraphType.allCases) { Text($0.rawValue).tag($0) } } }
                PreciseSlider(title: "Warning threshold", value: adaptive.systemWarningThreshold, range: 50...100, step: 1, suffix: "%")
                Text("Metric order: " + adaptive.wrappedValue.resolvedSystemMetrics.map(\.shortTitle).joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                Menu("Move metric to front") { ForEach(VisualSystemMetric.allCases) { metric in Button(metric.rawValue) { var list = adaptive.wrappedValue.systemMetricOrder.filter { $0 != metric }; list.insert(metric, at: 0); adaptive.wrappedValue.systemMetricOrder = list } } }
            }
        case .launcher:
            Section("Launcher") {
                PreciseSlider(title: "Icon size", value: Binding(get: { Double(adaptive.wrappedValue.launcherIconSize) }, set: { adaptive.wrappedValue.launcherIconSize = CGFloat($0) }), range: 16...72, step: 1, suffix: "pt")
                Stepper("Columns: \(adaptive.wrappedValue.launcherColumns)", value: adaptive.launcherColumns, in: 1...8)
                Toggle("Labels", isOn: adaptive.launcherShowLabels)
                Toggle("Search", isOn: adaptive.launcherShowSearch)
                Toggle("Running applications", isOn: adaptive.launcherShowRunningApps)
                Toggle("Downloads action", isOn: adaptive.launcherShowDownloads)
                Toggle("Timer action", isOn: adaptive.launcherShowTimerActions)
                TextField("Favorite app bundle IDs", text: adaptiveFavoriteBundles(adaptive))
                Text("Comma-separated bundle IDs. Halo opens installed apps directly; it does not pretend to provide Spotlight indexing.").font(.caption2).foregroundStyle(.secondary)
            }
        case .activities:
            Section("Activities") {
                Toggle("Progress", isOn: adaptive.activitiesShowProgress)
                Toggle("Details", isOn: adaptive.activitiesShowDetails)
                Toggle("Timestamps", isOn: adaptive.activitiesShowTimestamps)
                Text("This widget uses Halo's live activity store. Completed-history UI is not fabricated when no persisted activity history exists.").font(.caption2).foregroundStyle(.secondary)
            }
        case .notes:
            Section("Notes") {
                PreciseSlider(title: "Line spacing", value: Binding(get: { Double(adaptive.wrappedValue.notesLineSpacing) }, set: { adaptive.wrappedValue.notesLineSpacing = CGFloat($0) }), range: 0...18, step: 1, suffix: "pt")
                PreciseSlider(title: "Editor padding", value: Binding(get: { Double(adaptive.wrappedValue.notesEditorPadding) }, set: { adaptive.wrappedValue.notesEditorPadding = CGFloat($0) }), range: 0...24, step: 1, suffix: "pt")
                Toggle("Word / character count", isOn: adaptive.notesShowCounts)
                TextField("Placeholder", text: adaptive.notesPlaceholder)
            }
        case .capture:
            Section("Capture") {
                Picker("Primary action", selection: adaptive.capturePrimaryAction) { ForEach(VisualCapturePrimaryAction.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Recent capture", isOn: adaptive.captureShowRecent)
                if adaptive.wrappedValue.captureShowRecent { PreciseSlider(title: "Thumbnail size", value: Binding(get: { Double(adaptive.wrappedValue.captureThumbnailSize) }, set: { adaptive.wrappedValue.captureThumbnailSize = CGFloat($0) }), range: 64...320, step: 4, suffix: "pt") }
                Toggle("OCR result", isOn: adaptive.captureShowOCR)
                Text("Only the existing interactive region capture and image OCR paths are exposed; unsupported full-screen/editor tooling is not faked.").font(.caption2).foregroundStyle(.secondary)
            }
        case .stopwatch:
            Section("Stopwatch") {
                Picker("Precision", selection: adaptive.stopwatchPrecision) { ForEach(VisualStopwatchPrecision.allCases) { Text($0.rawValue).tag($0) } }
                Toggle("Laps", isOn: adaptive.stopwatchShowLaps)
                if adaptive.wrappedValue.stopwatchShowLaps { Stepper("Visible laps: \(adaptive.wrappedValue.stopwatchLapCount)", value: adaptive.stopwatchLapCount, in: 1...20); Toggle("Fastest / slowest indicators", isOn: adaptive.stopwatchShowLapExtremes) }
                PreciseSlider(title: "Time scale", value: adaptive.stopwatchTimeScale, range: 0.6...2.5, step: 0.05, suffix: "×", decimals: 2)
            }
        default:
            EmptyView()
        }
    }

    private func adaptiveInformationEnabled(_ adaptive: Binding<VisualAdaptiveWidgetOptions>, _ key: String) -> Binding<Bool> {
        Binding(get: { !adaptive.wrappedValue.hiddenInformation.contains(key) }, set: { enabled in
            var hidden = adaptive.wrappedValue.hiddenInformation
            if enabled { hidden.removeAll { $0 == key } }
            else if !hidden.contains(key) { hidden.append(key) }
            adaptive.wrappedValue.hiddenInformation = hidden
        })
    }

    private func moveAdaptiveInformation(_ adaptive: Binding<VisualAdaptiveWidgetOptions>, module: ModuleID, key: String, direction: Int) {
        var order = adaptive.wrappedValue.resolvedInformationPriority(for: module)
        guard let index = order.firstIndex(of: key) else { return }
        let target = index + direction
        guard order.indices.contains(target), !module.visualAdaptiveAlwaysInformation.contains(order[target]) else { return }
        order.swapAt(index, target)
        adaptive.wrappedValue.informationPriority = order
    }

    private func adaptiveFavoriteBundles(_ adaptive: Binding<VisualAdaptiveWidgetOptions>) -> Binding<String> {
        Binding(get: { adaptive.wrappedValue.launcherFavoriteBundleIDs.joined(separator: ", ") }, set: { text in
            adaptive.wrappedValue.launcherFavoriteBundleIDs = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        })
    }

    @ViewBuilder private func visualAdaptiveSizeOverrideInspector(itemID: UUID, style: Binding<WidgetStyle>, module: ModuleID) -> some View {
        let placement = findItem(itemID)?.gridPlacement ?? OpenNotchGridPlacement()
        let columns = min(8, max(1, placement.columnSpan))
        let rows = min(4, max(1, placement.rowSpan))
        let key = VisualAdaptiveWidgetOptions.sizeKey(columns: columns, rows: rows)
        let adaptive = style.visualAdaptive.withDefault(VisualAdaptiveWidgetOptions.defaults(for: module))
        let override = Binding<VisualAdaptiveSizeOverride?>(get: { adaptive.wrappedValue.sizeOverrides[key] }, set: { replacement in
            var values = adaptive.wrappedValue.sizeOverrides
            if let replacement { values[key] = replacement } else { values.removeValue(forKey: key) }
            adaptive.wrappedValue.sizeOverrides = values
        })
        Section("\(columns)×\(rows) Adaptive Override") {
            Toggle("Override Automatic", isOn: Binding(get: { override.wrappedValue != nil }, set: { enabled in
                override.wrappedValue = enabled ? VisualAdaptiveSizeOverride(presentation: adaptive.wrappedValue.preferredPresentation, density: adaptive.wrappedValue.density, maxItems: adaptive.wrappedValue.maxItems, showControls: adaptive.wrappedValue.showControls, hiddenInformation: adaptive.wrappedValue.hiddenInformation) : nil
            }))
            if override.wrappedValue != nil {
                let value = override.withDefault(VisualAdaptiveSizeOverride())
                Picker("Presentation", selection: value.presentation.withDefault(.automatic)) { ForEach(VisualAdaptivePresentation.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Density", selection: value.density.withDefault(adaptive.wrappedValue.density)) { ForEach(VisualAdaptiveDensity.allCases) { Text($0.rawValue).tag($0) } }
                Stepper("Maximum items: \(value.wrappedValue.maxItems ?? adaptive.wrappedValue.maxItems)", value: value.maxItems.withDefault(adaptive.wrappedValue.maxItems), in: 1...30)
                Toggle("Show controls", isOn: value.showControls.withDefault(adaptive.wrappedValue.showControls))
                Button("Reset This Size to Automatic") { override.wrappedValue = nil }
            } else {
                Text("This exact footprint currently follows the shared automatic layout and information priority.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

'''

if 'private func visualAdaptiveSettings' not in settings:
    marker = '    @ViewBuilder private func clockSizeOverrideInspector'
    idx = settings.find(marker)
    if idx < 0: raise SystemExit('clockSizeOverrideInspector marker missing')
    settings = settings[:idx] + helpers + settings[idx:]
settings_path.write_text(settings)

# ---------- Xcode project source membership ----------
project_path = ROOT / 'Halo.xcodeproj/project.pbxproj'
project = project_path.read_text()
build_id = 'A11C0F1A0000000000000311'
file_id = 'A11C0F1A0000000000000312'
if 'VisualWorkspaceAdaptiveWidgets.swift in Sources' not in project:
    build_marker = '/* End PBXBuildFile section */'
    build_line = f'\t\t{build_id} /* Views/VisualWorkspaceAdaptiveWidgets.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* Views/VisualWorkspaceAdaptiveWidgets.swift */; }};\n'
    project = project.replace(build_marker, build_line + build_marker, 1)

    file_marker = '/* End PBXFileReference section */'
    file_line = f'\t\t{file_id} /* Views/VisualWorkspaceAdaptiveWidgets.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = VisualWorkspaceAdaptiveWidgets.swift; sourceTree = "<group>"; }};\n'
    project = project.replace(file_marker, file_line + file_marker, 1)

    # Add to Views group.
    match = re.search(r'(\t\t[0-9A-F]+ /\* Views \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)', project)
    if not match: raise SystemExit('Views PBXGroup marker missing')
    project = project[:match.end()] + f'\t\t\t\t{file_id} /* VisualWorkspaceAdaptiveWidgets.swift */,\n' + project[match.end():]

    # Add only to the Halo app source phase.
    source_anchor = '\t\t\t\t0000000000000000000000D0 /* Views/ModuleViews.swift in Sources */,\n'
    if source_anchor not in project: raise SystemExit('Halo source phase ModuleViews anchor missing')
    project = project.replace(source_anchor, source_anchor + f'\t\t\t\t{build_id} /* Views/VisualWorkspaceAdaptiveWidgets.swift in Sources */,\n', 1)
project_path.write_text(project)

print('Adaptive Visual Workspace widget suite applied')
