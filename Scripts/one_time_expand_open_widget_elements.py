from pathlib import Path
import re


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"missing anchor: {label}")
    return text.replace(old, new, 1)


def sub_once(text, pattern, repl, label):
    out, count = re.subn(pattern, repl, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"regex {label}: expected 1 match, got {count}")
    return out

# -----------------------------------------------------------------------------
# Widget model: per-element catalog + style model.
# -----------------------------------------------------------------------------
p = "Halo/Core/WidgetModels.swift"
s = read(p)
insert = r'''
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

    func validated() throws -> WidgetElementStyle {
        guard [fontScale, opacity, backgroundOpacity, padding, cornerRadius].allSatisfy(\.isFinite) else {
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
                .init("palette", "Artwork palette", "Colors extracted from current artwork.", defaultVisible: false),
                .init("controls", "Playback controls", "Previous, play/pause, and next."),
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

'''
s = replace_once(s, 'struct WidgetColor: Codable, Equatable {', insert + 'struct WidgetColor: Codable, Equatable {', 'widget element declarations')
s = replace_once(s, '    var glassTintOpacity: Double?\n', '    var glassTintOpacity: Double?\n    var elementStyles: [String: WidgetElementStyle]?\n', 'WidgetStyle elementStyles field')
s = replace_once(s,
'''    var resolvedGlassTintOpacity: Double { min(0.6, max(0, glassTintOpacity ?? 0.10)) }
    func validated() throws -> WidgetStyle {''',
'''    var resolvedGlassTintOpacity: Double { min(0.6, max(0, glassTintOpacity ?? 0.10)) }
    func elementStyle(for key: String, defaultVisible: Bool = true) -> WidgetElementStyle {
        if let saved = elementStyles?[key] { return saved }
        var value = WidgetElementStyle()
        value.visible = defaultVisible
        return value
    }
    func elementStyle(for descriptor: WidgetElementDescriptor) -> WidgetElementStyle {
        elementStyle(for: descriptor.key, defaultVisible: descriptor.defaultVisible)
    }
    func validated() throws -> WidgetStyle {''', 'WidgetStyle element resolver')
s = replace_once(s,
'''        if let tint = glassTintOpacity {
            guard tint.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            v.glassTintOpacity = min(0.6, max(0, tint))
        }
        v.customFont''',
'''        if let tint = glassTintOpacity {
            guard tint.isFinite else { throw CocoaError(.fileReadCorruptFile) }
            v.glassTintOpacity = min(0.6, max(0, tint))
        }
        if elementStyles != nil { v.elementStyles = try elementStyles?.mapValues { try $0.validated() } }
        v.customFont''', 'WidgetStyle element validation')
write(p, s)

# -----------------------------------------------------------------------------
# Widget view primitives + richer clock elements.
# -----------------------------------------------------------------------------
p = "Halo/Views/WidgetViews.swift"
s = read(p)
primitive = r'''
extension WidgetElementEmphasis {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

struct WidgetElement<Content: View>: View {
    let key: String
    var defaultVisible = true
    @ViewBuilder var content: Content
    @Environment(\.widgetStyle) private var style

    private var element: WidgetElementStyle { style.elementStyle(for: key, defaultVisible: defaultVisible) }
    private var foreground: Color {
        switch element.foreground {
        case .inherit: return style.textColor.color
        case .secondary: return style.textColor.color.opacity(0.62)
        case .accent: return style.accentColor.color
        case .custom: return element.customForeground.color
        }
    }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous) }

    @ViewBuilder private var elementBackground: some View {
        switch element.background {
        case .none:
            EmptyView()
        case .subtle:
            shape.fill(style.textColor.color.opacity(element.backgroundOpacity * 0.16))
        case .accent:
            shape.fill(style.accentColor.color.opacity(element.backgroundOpacity))
        case .glass:
            shape.fill(.ultraThinMaterial).opacity(max(0.15, element.backgroundOpacity))
        case .custom:
            shape.fill(element.backgroundColor.color.opacity(element.backgroundOpacity))
        }
    }

    var body: some View {
        if element.visible {
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: 4) {
                content
                    .font(style.font(scale: element.fontScale))
                    .fontWeight(element.emphasis.fontWeight)
                    .foregroundStyle(foreground)
                    .opacity(element.opacity)
                    .padding(element.padding)
                    .background { elementBackground }
                    .frame(maxWidth: .infinity, alignment: style.resolvedContent.alignment.alignment)
                if element.dividerAfter { Divider().opacity(0.45) }
            }
            .frame(maxWidth: .infinity, alignment: style.resolvedContent.alignment.alignment)
        }
    }
}

'''
s = replace_once(s, 'struct WidgetCard<Content: View>: View {', primitive + 'struct WidgetCard<Content: View>: View {', 'WidgetElement primitive')
clock = r'''struct WidgetClock: View {
    let style: WidgetStyle
    var compact = false
    private var formatter: DateFormatter {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: style.clock.timeZone) ?? .current
        value.dateFormat = (style.clock.twentyFourHour ? "HH:mm" : "h:mm") + (style.clock.showSeconds ? ":ss" : "") + (style.clock.twentyFourHour ? "" : " a")
        return value
    }
    private var dayFormatter: DateFormatter {
        let value = formatter
        switch style.resolvedContent.clockDateStyle {
        case .weekdayMonthDay: value.dateFormat = "EEE, MMM d"
        case .monthDay: value.dateFormat = "MMM d"
        case .full: value.dateFormat = "EEEE, MMMM d"
        case .numeric: value.dateStyle = .short; value.timeStyle = .none
        }
        return value
    }
    private var timeZoneLabel: String { style.clock.timeZone.isEmpty ? TimeZone.current.identifier : style.clock.timeZone }

    var body: some View {
        let clockFormatter = formatter
        let dateFormatter = dayFormatter
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60)
        TimelineView(.periodic(from: start, by: style.clock.showSeconds ? 1 : 30)) { context in
            let spacing = max(2, min(20, style.resolvedContent.spacing * 0.55))
            Group {
                switch style.resolvedLayoutMode {
                case .compact:
                    HStack(spacing: spacing) {
                        if style.showTitle && !compact { clockHeader(scale: 0.68) }
                        WidgetElement(key: "time") { Text(clockFormatter.string(from: context.date)).monospacedDigit() }
                        if style.clock.showDate && !compact {
                            WidgetElement(key: "date") { Text(dateFormatter.string(from: context.date)) }
                        }
                    }
                case .hero:
                    VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                        if style.showTitle && !compact { clockHeader(scale: 0.75) }
                        WidgetElement(key: "time") { Text(clockFormatter.string(from: context.date)).font(style.font(scale: 1.35)).monospacedDigit() }
                        extras(dateFormatter: dateFormatter, date: context.date)
                    }
                case .minimal:
                    VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                        WidgetElement(key: "time") { Text(clockFormatter.string(from: context.date)).monospacedDigit() }
                        extras(dateFormatter: dateFormatter, date: context.date)
                    }
                case .dense, .standard:
                    VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: style.resolvedLayoutMode == .dense ? max(2, spacing * 0.55) : spacing) {
                        if style.showTitle && !compact { clockHeader(scale: 0.75) }
                        WidgetElement(key: "time") { Text(clockFormatter.string(from: context.date)).monospacedDigit() }
                        extras(dateFormatter: dateFormatter, date: context.date)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: style.resolvedContent.alignment.alignment)
        }
    }

    @ViewBuilder private func extras(dateFormatter: DateFormatter, date: Date) -> some View {
        if style.clock.showDate && !compact {
            WidgetElement(key: "date") { Text(dateFormatter.string(from: date)) }
        }
        WidgetElement(key: "timezone", defaultVisible: false) {
            Label(timeZoneLabel, systemImage: "globe")
        }
        WidgetElement(key: "dayProgress", defaultVisible: false) {
            let interval = Calendar.current.dateInterval(of: .day, for: date)
            let progress = interval.map { min(1, max(0, date.timeIntervalSince($0.start) / $0.duration)) } ?? 0
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: 4) {
                HStack { Text("Day progress"); Spacer(); Text("\(Int(progress * 100))%") }
                ProgressView(value: progress)
            }
        }
    }

    @ViewBuilder private func clockHeader(scale: Double) -> some View {
        HStack(spacing: max(4, style.resolvedContent.spacing * 0.55)) {
            if style.showsHeaderIcon {
                Image(systemName: "clock")
                    .font(.system(size: style.resolvedContent.iconSize, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
            }
            Text("Clock").font(style.font(scale: scale))
        }
    }
}
'''
s = sub_once(s, r'struct WidgetClock: View \{.*\Z', clock, 'replace WidgetClock')
write(p, s)

# -----------------------------------------------------------------------------
# AppStore: persist timer duration so progress can be meaningful.
# -----------------------------------------------------------------------------
p = "Halo/Core/AppStore.swift"
s = read(p)
s = replace_once(s, '    @Published var pausedSeconds: TimeInterval = 0\n', '    @Published var pausedSeconds: TimeInterval = 0\n    @Published var timerDurationSeconds: TimeInterval = 0\n', 'timer duration property')
s = replace_once(s,
'''        if let end = defaults.object(forKey: "timer.deadline") as? Date {
            if end > Date() { deadline = end; monitorTimer() }
            else { finished = true; defaults.removeObject(forKey: "timer.deadline") }
        }''',
'''        if let end = defaults.object(forKey: "timer.deadline") as? Date {
            if end > Date() {
                deadline = end
                timerDurationSeconds = max(end.timeIntervalSinceNow, defaults.double(forKey: "timer.durationSeconds"))
                monitorTimer()
            } else {
                finished = true
                defaults.removeObject(forKey: "timer.deadline")
                defaults.removeObject(forKey: "timer.durationSeconds")
            }
        }''', 'timer restore')
s = replace_once(s,
'''        pausedSeconds = 0
        deadline = Date().addingTimeInterval(Double(minutes * 60))
        defaults.set(deadline, forKey: "timer.deadline")''',
'''        pausedSeconds = 0
        timerDurationSeconds = Double(minutes * 60)
        deadline = Date().addingTimeInterval(timerDurationSeconds)
        defaults.set(deadline, forKey: "timer.deadline")
        defaults.set(timerDurationSeconds, forKey: "timer.durationSeconds")''', 'timer start duration')
s = replace_once(s,
'''            self.finished = true
            self.defaults.removeObject(forKey: "timer.deadline")''',
'''            self.finished = true
            self.timerDurationSeconds = 0
            self.defaults.removeObject(forKey: "timer.deadline")
            self.defaults.removeObject(forKey: "timer.durationSeconds")''', 'timer finish duration')
s = replace_once(s,
'''    func resetTimer() { deadline = nil; pausedSeconds = 0; finished = false; ticker?.cancel(); defaults.removeObject(forKey: "timer.deadline") }''',
'''    func resetTimer() {
        deadline = nil; pausedSeconds = 0; timerDurationSeconds = 0; finished = false; ticker?.cancel()
        defaults.removeObject(forKey: "timer.deadline")
        defaults.removeObject(forKey: "timer.durationSeconds")
    }''', 'timer reset duration')
write(p, s)

# -----------------------------------------------------------------------------
# Open widget runtime content: many more real elements.
# -----------------------------------------------------------------------------
p = "Halo/Views/ModuleViews.swift"
s = read(p)
block = r'''struct IntegrationModuleView: View {
    @Environment(\.widgetStyle) private var style
    let id: ModuleID
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    private var options: WidgetContentOptions { style.resolvedContent }
    var body: some View {
        Group {
            switch style.resolvedLayoutMode {
            case .compact:
                HStack(alignment: .top, spacing: max(6, options.spacing)) {
                    if style.showTitle { header(scale: 0.82) }
                    content
                }
            case .hero:
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing * 1.15) {
                    if style.showTitle { header(scale: 1.08) }
                    content
                }
            case .minimal:
                VStack(alignment: options.alignment.horizontal, spacing: max(3, options.spacing * 0.65)) {
                    if style.showTitle { header(scale: 0.72) }
                    content
                }
            case .dense:
                VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.55)) {
                    if style.showTitle { header(scale: 0.78) }
                    content
                }
            case .standard:
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    if style.showTitle { header(scale: 1) }
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }

    @ViewBuilder private func header(scale: Double) -> some View {
        HStack(spacing: max(4, options.spacing * 0.55)) {
            if style.showsHeaderIcon && options.iconSize > 0 {
                Image(systemName: id.symbol)
                    .font(.system(size: options.iconSize, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
            }
            Text(id.title).font(style.font(scale: scale))
        }
    }

    @ViewBuilder private var content: some View {
        switch id {
        case .media: MediaModuleView(service: workspace.media, app: workspace.settings.mediaApp)
        case .audio: AudioModuleView(service: workspace.audio)
        case .calendar: CalendarModuleView(service: workspace.calendar)
        case .clipboard: ClipboardModuleView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled)
        case .system: SystemModuleView(service: workspace.system)
        case .launcher: LauncherModuleView(store: store, workspace: workspace)
        case .activities:
            WidgetElement(key: "summary") {
                Label("\(workspace.activities.count) live activit\(workspace.activities.count == 1 ? "y" : "ies")", systemImage: "waveform.path")
            }
            if workspace.activities.isEmpty, options.showStatus {
                WidgetElement(key: "status") {
                    Text("Timer completions and live progress appear here.").foregroundStyle(.secondary)
                }
            }
            WidgetElement(key: "items") {
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    ForEach(Array(workspace.activities.prefix(options.maxItems))) { activity in
                        HStack(spacing: options.spacing) {
                            VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                                Text(activity.title)
                                if options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }
                                if options.showProgress, let progress = activity.progress { ProgressView(value: progress) }
                            }
                            Spacer()
                            if options.showControls { Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") } }
                        }
                    }
                }
            }
        case .notes:
            WidgetElement(key: "stats") {
                let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count
                HStack { Label("\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\(workspace.settings.notes.count) chars") }
            }
            WidgetElement(key: "editor") {
                TextEditor(text: $workspace.settings.notes).frame(height: options.notesHeight).accessibilityLabel("Quick note")
            }
            WidgetElement(key: "actions", defaultVisible: false) {
                HStack {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(workspace.settings.notes, forType: .string) }
                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)
                }
            }
        case .capture:
            CaptureModuleView(service: workspace.capture, store: store)
        case .stopwatch:
            WidgetElement(key: "state") {
                Label(workspace.stopwatchStart == nil ? (workspace.stopwatchElapsed > 0 ? "Paused" : "Ready") : "Running",
                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")
            }
            WidgetElement(key: "time") {
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0)
                    let whole = Int(elapsed)
                    Text(String(format: "%02d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60))
                        .font(style.font(scale: options.stopwatchScale)).monospacedDigit()
                }
            }
            if options.showControls {
                WidgetElement(key: "controls") {
                    HStack(spacing: options.spacing) {
                        Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                        Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
                    }
                }
            }
        default: EmptyView()
        }
    }
}

struct CaptureModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: CaptureService
    @ObservedObject var store: AppStore
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.captureShowHelp {
                WidgetElement(key: "hint") { Label("Screen Recording access is used only when you capture.", systemImage: "lock.shield") }
            }
            if options.showControls {
                WidgetElement(key: "actions") {
                    HStack(spacing: options.spacing) {
                        Button("Capture region…") { service.capture { store.addFiles([$0]) } }
                        Button("Extract text from image…") { service.chooseImage() }
                    }.disabled(service.busy)
                }
            }
            if service.busy && options.showStatus { WidgetElement(key: "progress") { ProgressView("Working…") } }
            if !service.recognizedText.isEmpty {
                WidgetElement(key: "result") { Text(service.recognizedText).textSelection(.enabled).lineLimit(options.captureTextLines) }
                if options.showControls {
                    WidgetElement(key: "resultActions") {
                        HStack(spacing: options.spacing) {
                            Button("Copy text") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }
                            Button("Clear") { service.recognizedText = "" }
                        }
                    }
                }
            }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}

struct MediaModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: MediaService
    let app: String
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "track") { Text(service.title).lineLimit(options.mediaTitleLines) }
            if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist") { Text(service.artist) } }
            if options.mediaShowSource, let source = service.connectedApp {
                WidgetElement(key: "source") {
                    Label(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio", systemImage: "app.badge")
                }
            }
            WidgetElement(key: "playback") {
                Label(service.connectedApp == nil ? "Waiting for a player" : (service.isPlaying ? "Playing" : "Paused"),
                      systemImage: service.connectedApp == nil ? "music.note" : (service.isPlaying ? "play.fill" : "pause.fill"))
            }
            WidgetElement(key: "palette", defaultVisible: false) {
                HStack(spacing: 6) {
                    Text("Artwork colors")
                    ForEach(Array(service.artworkColors.prefix(5).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color.color).frame(width: 14, height: 14)
                    }
                }
            }
            if options.showControls {
                WidgetElement(key: "controls") {
                    HStack(spacing: options.spacing) {
                        Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }
                        Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") }
                        Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }
                    }.disabled(service.busy)
                }
            }
            if options.showQuickActions { WidgetElement(key: "detection", defaultVisible: false) { Button("Retry player detection") { service.retryDetection(preferred: app) } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.setArtworkEnabled(true) }
    }
}

struct AudioModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: AudioService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
                HStack { Label("\(service.devices.count) outputs", systemImage: "speaker.wave.2"); Spacer(); Text("\(Int(service.volume * 100))%") }
            }
            WidgetElement(key: "output") {
                Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                    ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }
                }
            }
            if service.canSetVolume && options.showControls {
                WidgetElement(key: "volume") {
                    Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
                }
                WidgetElement(key: "volumeValue") { Text("Volume \(Int(service.volume * 100))%").monospacedDigit() }
                WidgetElement(key: "levels", defaultVisible: false) {
                    HStack { ForEach([0, 25, 50, 75, 100], id: \.self) { value in Button("\(value)%") { service.setVolume(Float(value) / 100) } } }
                }
            } else if !service.canSetVolume && options.showStatus {
                WidgetElement(key: "status") { Text("This output uses hardware volume controls.") }
            }
            if options.showQuickActions { WidgetElement(key: "actions") { Button("Refresh devices") { service.refresh() } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
}

struct CalendarModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: CalendarService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
                HStack { Text(Date(), style: .date); Spacer(); Text("\(service.events.count) remaining") }
            }
            if let next = service.events.first {
                WidgetElement(key: "nextEvent") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text(next.title ?? "Untitled event"); Text(next.startDate, style: .relative).foregroundStyle(.secondary) }
                        Spacer()
                        if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: next) { Link("Join", destination: url) }
                    }
                }
            }
            if options.showStatus { WidgetElement(key: "status") { Text(service.status) } }
            WidgetElement(key: "events") {
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    ForEach(Array(service.events.prefix(options.maxItems)), id: \.eventIdentifier) { event in
                        HStack(spacing: options.spacing) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title ?? "Untitled event").lineLimit(1)
                                if options.calendarShowTimes { Text(event.startDate, style: .time).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) { Link("Join", destination: url) }
                        }
                    }
                }
            }
            if options.showQuickActions { WidgetElement(key: "actions") { Button("Enable / Refresh calendar") { service.requestAccess() } } }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
}

struct ClipboardModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: ClipboardService
    let enabled: Bool
    @State private var search = ""
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if !enabled {
                if options.showStatus { WidgetElement(key: "summary") { Text("Clipboard history is off. Enable it in Privacy settings.") } }
            } else {
                WidgetElement(key: "summary") {
                    HStack {
                        Label("\(service.entries.count) entries", systemImage: "doc.on.clipboard")
                        Spacer()
                        if let newest = service.entries.first { Text(newest.date, style: .relative).foregroundStyle(.secondary) }
                    }
                }
                if options.showSearch { WidgetElement(key: "search") { TextField("Search clipboard", text: $search) } }
                let effectiveSearch = options.showSearch ? search : ""
                WidgetElement(key: "entries") {
                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(options.maxItems))) { entry in
                            HStack(spacing: options.spacing) {
                                VStack(alignment: .leading, spacing: 2) { Text(entry.text).lineLimit(2); Text(entry.date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if options.showControls {
                                    Button("Copy") { service.copy(entry) }
                                    Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }
                                }
                            }
                        }
                    }
                }
                if options.showQuickActions { WidgetElement(key: "actions") { Button("Clear history") { service.reset() } } }
                if options.showFooter { WidgetElement(key: "footer") { Text("Text only · up to 50 items · memory only") } }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}

struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: SystemService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.systemBattery, let battery = service.battery {
                WidgetElement(key: "battery") {
                    HStack { Label("\(battery)%", systemImage: service.charging ? "battery.100.bolt" : "battery.100"); Spacer(); Text(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power") }
                }
                if options.showProgress { WidgetElement(key: "batteryProgress") { ProgressView(value: Double(battery), total: 100) } }
            }
            WidgetElement(key: "power") {
                HStack { Label(service.lowPower ? "Low Power Mode" : "Normal power", systemImage: service.lowPower ? "leaf.fill" : "bolt.fill"); Spacer(); Text(service.onBattery ? "On battery" : "External power") }
            }
            if options.systemMemory { WidgetElement(key: "memory") { Label(service.memory, systemImage: "memorychip") } }
            if options.systemStorage { WidgetElement(key: "storage") { Label(service.storage, systemImage: "internaldrive") } }
            if options.systemUptime { WidgetElement(key: "uptime") { Label(service.uptime, systemImage: "clock.arrow.circlepath") } }
            WidgetElement(key: "device", defaultVisible: false) {
                VStack(alignment: options.alignment.horizontal, spacing: 3) {
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                    Text("\(ProcessInfo.processInfo.processorCount) logical processors").foregroundStyle(.secondary)
                }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}

struct LauncherModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @State private var query = ""
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary", defaultVisible: false) {
                HStack { Label("\(workspace.runningApps.count) apps", systemImage: "square.grid.2x2"); Spacer(); Text("\(workspace.plugins.reduce(0) { $0 + $1.commands.count }) plugin commands") }
            }
            if options.showSearch { WidgetElement(key: "search") { TextField("Search apps and commands", text: $query) } }
            let effectiveQuery = options.showSearch ? query : ""
            if options.launcherTimers {
                WidgetElement(key: "timers") {
                    HStack { ForEach([5, 15, 25], id: \.self) { minutes in Button("\(minutes)m") { store.startTimer(minutes: minutes) } } }
                }
            }
            if options.launcherRunningApps {
                WidgetElement(key: "apps") {
                    VStack(alignment: options.alignment.horizontal, spacing: max(4, options.spacing * 0.65)) {
                        ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \.processIdentifier) { app in
                            Button { app.activate(options: .activateIgnoringOtherApps) } label: { Label(app.localizedName ?? "Application", systemImage: "app") }
                        }
                    }
                }
            }
            if options.launcherPlugins {
                WidgetElement(key: "plugins") {
                    VStack(alignment: options.alignment.horizontal, spacing: max(4, options.spacing * 0.65)) {
                        ForEach(workspace.plugins) { plugin in
                            ForEach(plugin.commands.filter { CommandSearch.matches(effectiveQuery, in: $0.title) }.prefix(options.maxItems)) { command in
                                Button(command.title) { workspace.run(command) }
                            }
                        }
                    }
                }
            }
            if options.showQuickActions {
                WidgetElement(key: "shortcuts") {
                    HStack(spacing: options.spacing) {
                        Button("Open application…") {
                            let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
                            if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
                        }
                        Button("Downloads") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { workspace.refreshApps() }
    }
}

struct SurfaceBackground: View {'''
s = sub_once(s, r'struct IntegrationModuleView: View \{.*?\nstruct SurfaceBackground: View \{', block, 'module widget block')
write(p, s)

# -----------------------------------------------------------------------------
# Built-in Timer + Shelf elements.
# -----------------------------------------------------------------------------
p = "Halo/Views/SurfaceView.swift"
s = read(p)
builtin = r'''struct BuiltinOrIntegrationWidget: View {
    let module: ModuleID
    @ObservedObject var store: AppStore
    @Environment(\.widgetStyle) private var style
    @ViewBuilder var body: some View {
        switch module {
        case .clock: WidgetClock(style: style)
        case .timer: timer
        case .shelf: shelf
        default: ModuleRegistry().view(for: module, store: store)
        }
    }

    private var timer: some View {
        let options = style.resolvedContent
        let remaining = max(0, store.deadline?.timeIntervalSinceNow ?? store.pausedSeconds)
        let duration = max(0, store.timerDurationSeconds)
        let progress = duration > 0 ? min(1, max(0, 1 - remaining / duration)) : (store.finished ? 1 : 0)
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if style.showTitle {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    if style.showsHeaderIcon { Image(systemName: "timer").font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color) }
                    Text("Focus").font(style.font())
                }
            }
            WidgetElement(key: "countdown") {
                if let deadline = store.deadline { Text(deadline, style: .timer).font(style.font(scale: 1.35)).monospacedDigit() }
                else if store.pausedSeconds > 0 { Text(formatDuration(store.pausedSeconds)).font(style.font(scale: 1.35)).monospacedDigit() }
                else { Text("Ready").font(style.font(scale: 1.15)) }
            }
            WidgetElement(key: "progress") { ProgressView(value: progress) }
            WidgetElement(key: "endTime", defaultVisible: false) {
                if let deadline = store.deadline { HStack { Text("Finishes"); Spacer(); Text(deadline, style: .time) } }
                else if store.pausedSeconds > 0 { Text("Paused with \(formatDuration(store.pausedSeconds)) remaining") }
                else { Text("Choose a duration to begin") }
            }
            if options.showSecondaryText {
                WidgetElement(key: "status") {
                    Label(store.finished ? "Session complete" : store.deadline != nil ? "Deep work in progress" : store.pausedSeconds > 0 ? "Session paused" : "Make room for deep work",
                          systemImage: store.finished ? "checkmark.circle.fill" : store.deadline != nil ? "brain.head.profile" : store.pausedSeconds > 0 ? "pause.circle" : "sparkles")
                }
            }
            if options.showControls {
                if store.deadline == nil && store.pausedSeconds <= 0 {
                    WidgetElement(key: "presets") {
                        HStack(spacing: options.spacing) {
                            ForEach([options.timerPresetA, options.timerPresetB, options.timerPresetC], id: \.self) { minutes in
                                Button("\(minutes) min") { store.startTimer(minutes: minutes) }
                            }
                        }.buttonStyle(.bordered)
                    }
                } else {
                    WidgetElement(key: "controls") {
                        HStack(spacing: options.spacing) {
                            Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                            Button("Reset") { store.resetTimer() }
                        }.buttonStyle(.bordered)
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }

    private var shelf: some View {
        let options = style.resolvedContent
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if style.showTitle {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    if style.showsHeaderIcon { Image(systemName: "tray").font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color) }
                    Text("File shelf").font(style.font())
                }
            }
            WidgetElement(key: "summary") {
                HStack {
                    Label("\(store.files.count) item\(store.files.count == 1 ? "" : "s")", systemImage: "tray.full")
                    Spacer()
                    Text("\(store.pinnedFiles.count) pinned")
                }
            }
            if store.files.isEmpty, options.showSecondaryText {
                WidgetElement(key: "files") { Text("Drop files here. Originals stay untouched.").foregroundStyle(.secondary) }
            } else {
                WidgetElement(key: "files") {
                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                        ForEach(Array(store.files.prefix(options.maxItems)), id: \.self) { url in
                            HStack(spacing: options.spacing) {
                                ShelfFileInfo(url: url, iconSize: options.shelfIconSize, showDetail: options.shelfShowDetails)
                                Spacer()
                                if options.shelfShowActions && options.showControls {
                                    Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Pin")
                                    Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal")
                                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open")
                                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                                    Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove")
                                }
                            }.onDrag { NSItemProvider(object: url as NSURL) }
                        }
                    }
                }
            }
            if options.showQuickActions {
                WidgetElement(key: "actions") {
                    HStack {
                        Button("Add files…") { store.chooseFiles() }
                        Button("Clear shelf") { store.clearShelf() }.disabled(store.files.isEmpty)
                    }
                }
            }
            if options.showFooter && store.files.count > options.maxItems {
                WidgetElement(key: "footer") { Text("+\(store.files.count - options.maxItems) more items") }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) : String(format: "%02d:%02d", value / 60, value % 60)
    }
}

struct ShelfFileInfo: View {'''
s = sub_once(s, r'struct BuiltinOrIntegrationWidget: View \{.*?\nstruct ShelfFileInfo: View \{', builtin, 'built-in widget block')
write(p, s)

# -----------------------------------------------------------------------------
# Settings: per-element editor.
# -----------------------------------------------------------------------------
p = "Halo/Views/WidgetSettingsView.swift"
s = read(p)
elements_section = r'''        Section("Elements") {
            Text("Each functional piece can be shown or hidden and styled independently. This includes real controls such as sliders, progress bars, status rows, lists and actions — not just text.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(selected.widgetElements) { descriptor in
                let value = elementBinding(descriptor)
                DisclosureGroup {
                    Toggle("Visible", isOn: value.visible)
                    if value.wrappedValue.visible {
                        Picker("Text color", selection: value.foreground) {
                            ForEach(WidgetElementForegroundStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if value.wrappedValue.foreground == .custom {
                            ColorPicker("Custom text", selection: Binding(get: { value.wrappedValue.customForeground.color }, set: { value.wrappedValue.customForeground = WidgetColor($0) }), supportsOpacity: false)
                        }
                        Picker("Emphasis", selection: value.emphasis) {
                            ForEach(WidgetElementEmphasis.allCases) { Text($0.rawValue).tag($0) }
                        }
                        PreciseSlider(title: "Text scale", value: value.fontScale, range: 0.55...2.5, step: 0.05, suffix: "×", decimals: 2)
                        PreciseSlider(title: "Opacity", value: value.opacity, range: 0.15...1, step: 0.05, decimals: 2)
                        Picker("Element background", selection: value.background) {
                            ForEach(WidgetElementBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if value.wrappedValue.background == .custom {
                            ColorPicker("Background color", selection: Binding(get: { value.wrappedValue.backgroundColor.color }, set: { value.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false)
                        }
                        if value.wrappedValue.background != .none {
                            PreciseSlider(title: "Background opacity", value: value.backgroundOpacity, range: 0...1, step: 0.05, decimals: 2)
                            PreciseSlider(title: "Element padding", value: value.padding, range: 0...24, step: 1, suffix: "pt")
                            PreciseSlider(title: "Element radius", value: value.cornerRadius, range: 0...32, step: 1, suffix: "pt")
                        }
                        Toggle("Divider after element", isOn: value.dividerAfter)
                        Button("Reset element style") { resetElement(descriptor) }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(descriptor.title)
                            Text(descriptor.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(value.wrappedValue.visible ? "On" : "Off").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
'''
s = replace_once(s, '        Section("Typography") {', elements_section + '        Section("Typography") {', 'elements settings section')
helpers = r'''    private func elementBinding(_ descriptor: WidgetElementDescriptor) -> Binding<WidgetElementStyle> {
        Binding(get: {
            style.wrappedValue.elementStyle(for: descriptor)
        }, set: { value in
            var updated = style.wrappedValue
            if updated.elementStyles == nil { updated.elementStyles = [:] }
            updated.elementStyles?[descriptor.key] = value
            style.wrappedValue = updated
        })
    }

    private func resetElement(_ descriptor: WidgetElementDescriptor) {
        var updated = style.wrappedValue
        updated.elementStyles?.removeValue(forKey: descriptor.key)
        style.wrappedValue = updated
    }

'''
s = replace_once(s, '    @ViewBuilder private var moduleSpecificSettings: some View {', helpers + '    @ViewBuilder private var moduleSpecificSettings: some View {', 'element settings helpers')
write(p, s)

print("opened widget element system patched")
