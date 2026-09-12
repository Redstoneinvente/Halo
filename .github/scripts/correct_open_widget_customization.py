from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing pattern: {label}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Widget model: opened-dashboard content + card customization.
# The new nested objects are optional so old profiles/themes decode unchanged.
# -----------------------------------------------------------------------------
p = Path("Halo/Core/WidgetModels.swift")
s = p.read_text()
old = '''struct ClockOptions: Codable, Equatable {
    var twentyFourHour = false
    var showSeconds = false
    var showDate = true
    var timeZone = ""
}
struct WidgetStyle: Codable, Equatable {
'''
new = '''struct ClockOptions: Codable, Equatable {
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
        guard [spacing, iconSize, shelfIconSize, notesHeight, stopwatchScale].allSatisfy(\\.isFinite) else {
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
        guard [borderOpacity, borderWidth, shadowOpacity, shadowRadius, shadowY, contentOpacity].allSatisfy(\\.isFinite) else {
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
'''
s = replace_once(s, old, new, "opened widget models")
old = '''    var minimumHeight = 0.0
    var showTitle = true
    var clock = ClockOptions()
    func validated() throws -> WidgetStyle {
'''
new = '''    var minimumHeight = 0.0
    var showTitle = true
    var clock = ClockOptions()
    var content: WidgetContentOptions?
    var chrome: WidgetChromeOptions?
    var resolvedContent: WidgetContentOptions { content ?? WidgetContentOptions() }
    var resolvedChrome: WidgetChromeOptions { chrome ?? WidgetChromeOptions() }
    func validated() throws -> WidgetStyle {
'''
s = replace_once(s, old, new, "opened widget style fields")
old = '''        v.textColor = try textColor.validated(); v.accentColor = try accentColor.validated(); v.backgroundColor = try backgroundColor.validated()
        v.customFont = String(customFont.prefix(120))
        return v
'''
new = '''        v.textColor = try textColor.validated(); v.accentColor = try accentColor.validated(); v.backgroundColor = try backgroundColor.validated()
        v.customFont = String(customFont.prefix(120))
        if content != nil { v.content = try resolvedContent.validated() }
        if chrome != nil { v.chrome = try resolvedChrome.validated() }
        return v
'''
s = replace_once(s, old, new, "opened widget validation")
p.write_text(s)

# -----------------------------------------------------------------------------
# Drop CI state only. WindowManager is restored to pre-mistake before this script runs.
# -----------------------------------------------------------------------------
p = Path("Halo/NotchEngine/WindowManager.swift")
s = p.read_text()
old = '''    @Published var theme = Theme()
    @Published var layoutOverride: WorkspaceLayout?
    @Published var contextPreferredSize: CGSize?
    var collapseTask: Task<Void, Never>?
'''
new = '''    @Published var theme = Theme()
    @Published var layoutOverride: WorkspaceLayout?
    @Published var contextPreferredSize: CGSize?
    /// Per-surface drag state keeps Drop CI scoped to the display beneath the dragged item.
    @Published var dropTargeted = false
    @Published var dropItemCount = 0
    var collapseTask: Task<Void, Never>?
'''
s = replace_once(s, old, new, "drop state after correction")
p.write_text(s)

# -----------------------------------------------------------------------------
# Widget card rendering + clock layout.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WidgetViews.swift")
s = p.read_text()
anchor = '''private struct WidgetStyleKey: EnvironmentKey { static let defaultValue = WidgetStyle() }
'''
insert = '''extension WidgetContentAlignment {
    var horizontal: HorizontalAlignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    var alignment: Alignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}
extension WidgetControlSize {
    var swiftUI: ControlSize {
        switch self { case .mini: return .mini; case .small: return .small; case .regular: return .regular; case .large: return .large }
    }
}
'''
if anchor not in s:
    raise SystemExit("missing WidgetStyleKey anchor")
s = s.replace(anchor, insert + anchor, 1)
old = '''    private var styledContent: some View {
        content.environment(\\.widgetStyle, fittedStyle).font(fittedStyle.font())
            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)
    }
'''
new = '''    private var contentOptions: WidgetContentOptions { fittedStyle.resolvedContent }
    private var chrome: WidgetChromeOptions { fittedStyle.resolvedChrome }
    private var styledContent: some View {
        content.environment(\\.widgetStyle, fittedStyle).font(fittedStyle.font())
            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)
            .controlSize(contentOptions.controlSize.swiftUI)
            .opacity(chrome.contentOpacity)
    }
'''
s = replace_once(s, old, new, "widget card resolved options")
s = s.replace('alignment: .topLeading)', 'alignment: contentOptions.alignment == .center ? .top : (contentOptions.alignment == .trailing ? .topTrailing : .topLeading))', 1)
s = s.replace('alignment: .leading)\n                    .padding(style.padding)', 'alignment: contentOptions.alignment.alignment)\n                    .padding(style.padding)', 1)
old = '''        .background(style.backgroundColor.color.opacity(style.backgroundOpacity), in: RoundedRectangle(cornerRadius: style.cornerRadius))
        .frame(maxWidth: style.width > 0 ? style.width : .infinity)
        .frame(maxWidth: .infinity)
'''
new = '''        .background(style.backgroundColor.color.opacity(style.backgroundOpacity), in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(chrome.borderColor.color.opacity(chrome.borderOpacity), lineWidth: chrome.borderWidth)
        )
        .shadow(color: .black.opacity(chrome.shadowOpacity), radius: chrome.shadowRadius, y: chrome.shadowY)
        .frame(maxWidth: style.width > 0 ? style.width : .infinity)
        .frame(maxWidth: .infinity, alignment: contentOptions.alignment.alignment)
'''
s = replace_once(s, old, new, "widget card chrome")
old = '''    private var dayFormatter: DateFormatter {
        let value = formatter
        value.dateFormat = "EEE, MMM d"
        return value
    }
'''
new = '''    private var dayFormatter: DateFormatter {
        let value = formatter
        switch style.resolvedContent.clockDateStyle {
        case .weekdayMonthDay: value.dateFormat = "EEE, MMM d"
        case .monthDay: value.dateFormat = "MMM d"
        case .full: value.dateFormat = "EEEE, MMMM d"
        case .numeric: value.dateStyle = .short; value.timeStyle = .none
        }
        return value
    }
'''
s = replace_once(s, old, new, "clock date format")
old = '''            VStack(alignment: .leading, spacing: 4) {
                if style.showTitle && !compact { Text("Clock").font(style.font(scale: 0.75)) }
'''
new = '''            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: max(2, min(20, style.resolvedContent.spacing * 0.55))) {
                if style.showTitle && !compact { Text("Clock").font(style.font(scale: 0.75)) }
'''
s = replace_once(s, old, new, "clock alignment")
old = '''            }
        }
    }
}
'''
# only replace the first occurrence after WidgetClock start via split
idx = s.index('struct WidgetClock: View')
pos = s.index(old, idx)
s = s[:pos] + '''            }
            .frame(maxWidth: .infinity, alignment: style.resolvedContent.alignment.alignment)
        }
    }
}
''' + s[pos+len(old):]
p.write_text(s)

# -----------------------------------------------------------------------------
# Module renderers: apply only relevant content settings per widget.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/ModuleViews.swift")
s = p.read_text()
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if style.showTitle { Label(id.title, systemImage: id.symbol).font(style.font()) }
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
'''
new = '''    private var options: WidgetContentOptions { style.resolvedContent }
    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if style.showTitle {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    if options.iconSize > 0 { Image(systemName: id.symbol).font(.system(size: options.iconSize, weight: .semibold)).foregroundStyle(style.accentColor.color) }
                    Text(id.title).font(style.font())
                }
            }
            content
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "integration module layout")
# Activities block.
old = '''        case .activities:
            if workspace.activities.isEmpty { Text("Timer completions appear here.").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            ForEach(workspace.activities) { activity in
                HStack {
                    VStack(alignment: .leading) {
                        Text(activity.title); Text(activity.detail).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
                        if let progress = activity.progress { ProgressView(value: progress) }
                    }
                    Spacer()
                    Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss activity")
                }
            }
'''
new = '''        case .activities:
            if workspace.activities.isEmpty, options.showStatus {
                Text("Timer completions appear here.").font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            }
            ForEach(Array(workspace.activities.prefix(options.maxItems))) { activity in
                HStack(spacing: options.spacing) {
                    VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                        Text(activity.title)
                        if options.activitiesShowDetail && options.showSecondaryText && !activity.detail.isEmpty {
                            Text(activity.detail).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
                        }
                        if options.showProgress, let progress = activity.progress { ProgressView(value: progress) }
                    }
                    Spacer()
                    if options.showControls {
                        Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss activity")
                    }
                }
            }
'''
s = replace_once(s, old, new, "activities options")
s = replace_once(s,
'''        case .notes: TextEditor(text: $workspace.settings.notes).frame(height: 90).accessibilityLabel("Quick note")
''',
'''        case .notes: TextEditor(text: $workspace.settings.notes).frame(height: options.notesHeight).accessibilityLabel("Quick note")
''', "notes height")
old = '''        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = Int(workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0))
                Text(String(format: "%02d:%02d:%02d", elapsed / 3600, elapsed / 60 % 60, elapsed % 60)).font(style.font(scale: 2)).monospacedDigit()
            }
            HStack {
                Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
            }
'''
new = '''        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = Int(workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0))
                Text(String(format: "%02d:%02d:%02d", elapsed / 3600, elapsed / 60 % 60, elapsed % 60))
                    .font(style.font(scale: options.stopwatchScale)).monospacedDigit()
            }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                    Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
                }
            }
'''
s = replace_once(s, old, new, "stopwatch options")
# Capture.
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture asks for Screen Recording access.").font(style.font(scale: 0.85))
            HStack {
                Button("Capture region…") { service.capture { store.addFiles([$0]) } }
                Button("Extract text from image…") { service.chooseImage() }
            }.disabled(service.busy)
            if service.busy { ProgressView() }
            if !service.recognizedText.isEmpty {
                Text(service.recognizedText).font(style.font(scale: 0.85)).textSelection(.enabled).lineLimit(12)
                Button("Copy extracted text") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }
                Button("Clear extracted text") { service.recognizedText = "" }
            }
            if let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.captureShowHelp && options.showSecondaryText { Text("Capture asks for Screen Recording access.").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button("Capture region…") { service.capture { store.addFiles([$0]) } }
                    Button("Extract text from image…") { service.chooseImage() }
                }.disabled(service.busy)
            }
            if service.busy && options.showStatus { ProgressView() }
            if !service.recognizedText.isEmpty {
                Text(service.recognizedText).font(style.font(scale: 0.85)).textSelection(.enabled).lineLimit(options.captureTextLines)
                if options.showControls {
                    HStack(spacing: options.spacing) {
                        Button("Copy extracted text") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }
                        Button("Clear extracted text") { service.recognizedText = "" }
                    }
                }
            }
            if options.showStatus, let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "capture options")
# Media.
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(service.title).lineLimit(2)
            if let source = service.connectedApp { Text(source == "com.apple.Music" ? "Apple Music" : "Spotify").font(style.font(scale: 0.75)).foregroundStyle(.secondary) }
            Text(service.artist).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            HStack {
                Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                Button { service.perform("playpause", app: app) } label: { Image(systemName: "playpause.fill") }.accessibilityLabel("Play or pause")
                Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                Spacer()
                Button("Retry detection") { service.retryDetection(preferred: app) }
            }.disabled(service.busy)
            if let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            Text(service.title).lineLimit(options.mediaTitleLines)
            if options.mediaShowSource && options.showSecondaryText, let source = service.connectedApp {
                Text(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio")
                    .font(style.font(scale: 0.75)).foregroundStyle(.secondary)
            }
            if options.mediaShowArtist && options.showSecondaryText && !service.artist.isEmpty {
                Text(service.artist).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                    Button { service.perform("playpause", app: app) } label: { Image(systemName: "playpause.fill") }.accessibilityLabel("Play or pause")
                    Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                    Spacer()
                    Button("Retry detection") { service.retryDetection(preferred: app) }
                }.disabled(service.busy)
            }
            if options.showStatus, let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "media options")
# Audio.
old = '''    var body: some View {
        VStack(alignment: .leading) {
            Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                ForEach(service.devices) { Text($0.name).tag($0.id) }
            }
            if service.canSetVolume {
                Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
            } else { Text("Use this device's hardware volume controls.").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            Button("Refresh devices") { service.refresh() }
            if let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.onAppear { service.refresh() }
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }
            }
            if service.canSetVolume && options.showControls {
                Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
            } else if !service.canSetVolume && options.showStatus {
                Text("Use this device's hardware volume controls.").font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            }
            if options.showQuickActions { Button("Refresh devices") { service.refresh() } }
            if options.showStatus, let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
'''
s = replace_once(s, old, new, "audio options")
# Calendar.
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(service.status).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            ForEach(service.events, id: \\.eventIdentifier) { event in
                HStack {
                    VStack(alignment: .leading) {
                        Text(event.title ?? "Untitled event").lineLimit(1)
                        Text(event.startDate, style: .time).font(style.font(scale: 0.85))
                    }
                    Spacer()
                    if let url = service.meetingURL(for: event) { Link("Join", destination: url) }
                }
            }
            Button("Enable / Refresh calendar") { service.requestAccess() }
        }.onAppear { service.refresh() }
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.showStatus { Text(service.status).font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            ForEach(Array(service.events.prefix(options.maxItems)), id: \\.eventIdentifier) { event in
                HStack(spacing: options.spacing) {
                    VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                        Text(event.title ?? "Untitled event").lineLimit(1)
                        if options.calendarShowTimes && options.showSecondaryText { Text(event.startDate, style: .time).font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) { Link("Join", destination: url) }
                }
            }
            if options.showQuickActions { Button("Enable / Refresh calendar") { service.requestAccess() } }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
'''
s = replace_once(s, old, new, "calendar options")
# Clipboard.
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !enabled { Text("Off. Enable text history in Privacy settings.").font(style.font(scale: 0.85)) }
            else {
                TextField("Search clipboard", text: $search)
                ForEach(service.entries.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }) { entry in
                    HStack {
                        Text(entry.text).font(style.font(scale: 0.85)).lineLimit(2)
                        Spacer()
                        Button("Copy") { service.copy(entry) }
                        Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Remove clipboard item")
                    }
                }
                Button("Clear history") { service.reset() }
                Text("Text only · 50 items · memory only · copying does not paste into another app").font(style.font(scale: 0.75)).foregroundStyle(.secondary)
            }
        }
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if !enabled { if options.showStatus { Text("Off. Enable text history in Privacy settings.").font(style.font(scale: 0.85)) } }
            else {
                if options.showSearch { TextField("Search clipboard", text: $search) }
                ForEach(Array(service.entries.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }.prefix(options.maxItems))) { entry in
                    HStack(spacing: options.spacing) {
                        Text(entry.text).font(style.font(scale: 0.85)).lineLimit(2)
                        Spacer()
                        if options.showControls {
                            Button("Copy") { service.copy(entry) }
                            Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Remove clipboard item")
                        }
                    }
                }
                if options.showQuickActions { Button("Clear history") { service.reset() } }
                if options.showFooter { Text("Text only · 50 items · memory only · copying does not paste into another app").font(style.font(scale: 0.75)).foregroundStyle(.secondary) }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "clipboard options")
# System.
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let battery = service.battery {
                Label("\\(battery)% · \\(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power")", systemImage: service.charging ? "battery.100.bolt" : "battery.100")
                ProgressView(value: Double(battery), total: 100)
            }
            Text(service.memory); Text(service.storage)
            Text(service.uptime + (service.lowPower ? " · Low Power Mode" : ""))
        }.font(style.font(scale: 0.85))
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.systemBattery, let battery = service.battery {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    Image(systemName: service.charging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color)
                    Text("\\(battery)% · \\(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power")")
                }
                if options.showProgress { ProgressView(value: Double(battery), total: 100) }
            }
            if options.systemMemory { Text(service.memory) }
            if options.systemStorage { Text(service.storage) }
            if options.systemUptime { Text(service.uptime + (service.lowPower ? " · Low Power Mode" : "")) }
        }.font(style.font(scale: 0.85)).frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "system options")
# Launcher.
old = '''    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search apps and commands", text: $query)
            ForEach([5, 15, 25], id: \\.self) { minutes in
                if CommandSearch.matches(query, in: "Start timer \\(minutes)") {
                    Button("Start \\(minutes)-minute timer") { store.startTimer(minutes: minutes) }
                }
            }
            ForEach(workspace.runningApps.filter { CommandSearch.matches(query, in: $0.localizedName ?? "") }, id: \\.processIdentifier) { app in
                Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                    Label(app.localizedName ?? "Application", systemImage: "app")
                }
            }
            ForEach(workspace.plugins) { plugin in
                ForEach(plugin.commands.filter { CommandSearch.matches(query, in: $0.title) }) { command in
                    Button(command.title) { workspace.run(command) }
                }
            }
            HStack {
                Button("Open application…") {
                    let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
                    if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
                }
                Button("Downloads") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
            }
        }.onAppear { workspace.refreshApps() }
    }
'''
new = '''    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.showSearch { TextField("Search apps and commands", text: $query) }
            if options.launcherTimers {
                ForEach([5, 15, 25], id: \\.self) { minutes in
                    if CommandSearch.matches(query, in: "Start timer \\(minutes)") {
                        Button("Start \\(minutes)-minute timer") { store.startTimer(minutes: minutes) }
                    }
                }
            }
            if options.launcherRunningApps {
                ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(query, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \\.processIdentifier) { app in
                    Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                        Label(app.localizedName ?? "Application", systemImage: "app")
                    }
                }
            }
            if options.launcherPlugins {
                ForEach(workspace.plugins) { plugin in
                    ForEach(plugin.commands.filter { CommandSearch.matches(query, in: $0.title) }.prefix(options.maxItems)) { command in
                        Button(command.title) { workspace.run(command) }
                    }
                }
            }
            if options.showQuickActions {
                HStack(spacing: options.spacing) {
                    Button("Open application…") {
                        let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
                        if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
                    }
                    Button("Downloads") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
                }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { workspace.refreshApps() }
    }
'''
s = replace_once(s, old, new, "launcher options")
p.write_text(s)

# -----------------------------------------------------------------------------
# Built-in Timer + Shelf widgets in SurfaceView.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/SurfaceView.swift")
s = p.read_text()
old = '''    private var timer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if style.showTitle { Label("Focus", systemImage: "timer").font(style.font()) }
                Spacer()
                if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
                else if store.pausedSeconds > 0 { Text("Paused · \\(Int(store.pausedSeconds))s").font(style.font(scale: 0.85)) }
                else if store.finished { Text("Session complete").foregroundStyle(.green) }
                else { Text("Make room for deep work").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            }
            HStack {
                if store.deadline != nil || store.pausedSeconds > 0 {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("Reset") { store.resetTimer() }
                } else {
                    ForEach([5, 15, 25], id: \\.self) { minutes in Button("\\(minutes) min") { store.startTimer(minutes: minutes) } }
                }
            }.buttonStyle(.bordered)
        }
    }
'''
new = '''    private var timer: some View {
        let options = style.resolvedContent
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            HStack(spacing: options.spacing) {
                if style.showTitle {
                    HStack(spacing: max(4, options.spacing * 0.55)) {
                        Image(systemName: "timer").font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color)
                        Text("Focus").font(style.font())
                    }
                }
                Spacer()
                if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
                else if options.showSecondaryText, store.pausedSeconds > 0 { Text("Paused · \\(Int(store.pausedSeconds))s").font(style.font(scale: 0.85)) }
                else if store.finished { Text("Session complete").foregroundStyle(.green) }
                else if options.showSecondaryText { Text("Make room for deep work").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    if store.deadline != nil || store.pausedSeconds > 0 {
                        Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                        Button("Reset") { store.resetTimer() }
                    } else {
                        ForEach([options.timerPresetA, options.timerPresetB, options.timerPresetC], id: \\.self) { minutes in
                            Button("\\(minutes) min") { store.startTimer(minutes: minutes) }
                        }
                    }
                }.buttonStyle(.bordered)
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "timer opened customization")
old = '''    private var shelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if style.showTitle { Label("File shelf", systemImage: "tray").font(style.font()) }
                Spacer()
                Button { store.chooseFiles() } label: { Image(systemName: "plus") }.accessibilityLabel("Add files")
            }
            if store.files.isEmpty { Text("Drop files here. Originals stay untouched.").font(style.font(scale: 0.85)).foregroundStyle(.secondary).padding(.vertical, 8) }
            ForEach(store.files, id: \\.self) { url in
                HStack {
                    ShelfFileInfo(url: url)
                    Spacer()
                    Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Keep this file on the shelf")
                    Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal in Finder")
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open file")
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove reference from shelf")
                }.onDrag { NSItemProvider(object: url as NSURL) }
            }
        }
    }
'''
new = '''    private var shelf: some View {
        let options = style.resolvedContent
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            HStack(spacing: options.spacing) {
                if style.showTitle {
                    HStack(spacing: max(4, options.spacing * 0.55)) {
                        Image(systemName: "tray").font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color)
                        Text("File shelf").font(style.font())
                    }
                }
                Spacer()
                if options.showQuickActions { Button { store.chooseFiles() } label: { Image(systemName: "plus") }.accessibilityLabel("Add files") }
            }
            if store.files.isEmpty, options.showSecondaryText {
                Text("Drop files here. Originals stay untouched.").font(style.font(scale: 0.85)).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ForEach(Array(store.files.prefix(options.maxItems)), id: \\.self) { url in
                HStack(spacing: options.spacing) {
                    ShelfFileInfo(url: url, iconSize: options.shelfIconSize, showDetail: options.shelfShowDetails && options.showSecondaryText)
                    Spacer()
                    if options.shelfShowActions && options.showControls {
                        Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Keep this file on the shelf")
                        Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                        Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal in Finder")
                        Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open file")
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                        Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove reference from shelf")
                    }
                }.onDrag { NSItemProvider(object: url as NSURL) }
            }
            if options.showFooter && store.files.count > options.maxItems {
                Text("+\\(store.files.count - options.maxItems) more items").font(style.font(scale: 0.75)).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
'''
s = replace_once(s, old, new, "shelf opened customization")
old = '''struct ShelfFileInfo: View {
    let url: URL
    @Environment(\\.widgetStyle) private var style
    @State private var icon: NSImage?
    @State private var detail = ""
    var body: some View {
        HStack {
            if let icon { Image(nsImage: icon).resizable().frame(width: 24, height: 24) }
            VStack(alignment: .leading) {
                Text(url.lastPathComponent).font(style.font(scale: 0.85)).lineLimit(1)
                Text(detail).font(style.font(scale: 0.75)).foregroundStyle(.secondary).lineLimit(1)
            }
'''
new = '''struct ShelfFileInfo: View {
    let url: URL
    var iconSize = 24.0
    var showDetail = true
    @Environment(\\.widgetStyle) private var style
    @State private var icon: NSImage?
    @State private var detail = ""
    var body: some View {
        HStack(spacing: style.resolvedContent.spacing) {
            if let icon { Image(nsImage: icon).resizable().frame(width: iconSize, height: iconSize) }
            VStack(alignment: style.resolvedContent.alignment.horizontal) {
                Text(url.lastPathComponent).font(style.font(scale: 0.85)).lineLimit(1)
                if showDetail { Text(detail).font(style.font(scale: 0.75)).foregroundStyle(.secondary).lineLimit(1) }
            }
'''
s = replace_once(s, old, new, "shelf file info options")
p.write_text(s)

# -----------------------------------------------------------------------------
# Settings: generic opened-widget studio + widget-specific controls.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()
old = '''    private var style: Binding<WidgetStyle> {
        Binding(get: { layout.widgetStyle(for: selected) }, set: { layout.setWidgetStyle($0, for: selected) })
    }
    var body: some View {
'''
new = '''    private var style: Binding<WidgetStyle> {
        Binding(get: { layout.widgetStyle(for: selected) }, set: { layout.setWidgetStyle($0, for: selected) })
    }
    private var content: Binding<WidgetContentOptions> {
        Binding(get: { style.wrappedValue.resolvedContent }, set: { value in
            var updated = style.wrappedValue; updated.content = value; style.wrappedValue = updated
        })
    }
    private var chrome: Binding<WidgetChromeOptions> {
        Binding(get: { style.wrappedValue.resolvedChrome }, set: { value in
            var updated = style.wrappedValue; updated.chrome = value; style.wrappedValue = updated
        })
    }
    var body: some View {
'''
s = replace_once(s, old, new, "widget settings bindings")
# Add intro + generic layout after picker.
old = '''        Picker("Widget", selection: $selected) {
            ForEach(ModuleID.allCases) { Text($0.title).tag($0) }
        }
        Section("Typography") {
'''
new = '''        Picker("Widget", selection: $selected) {
            ForEach(ModuleID.allCases) { Text($0.title).tag($0) }
        }
        Section("Opened notch widget") {
            Text("Customize \\(selected.title) independently. These settings apply to the widget in Halo's opened dashboard and travel with profiles and display-specific layouts.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Typography") {
'''
s = replace_once(s, old, new, "widget settings intro")
# Replace end of typography + Card section start with new layout section.
old = '''            Toggle("Show title", isOn: style.showTitle)
        }
        Section("Card") {
'''
new = '''            Toggle("Show title", isOn: style.showTitle)
        }
        Section("Content layout") {
            Picker("Alignment", selection: content.alignment) {
                ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            PreciseSlider(title: "Content spacing", value: content.spacing, range: 0...32, step: 1, suffix: "pt")
            Picker("Control size", selection: content.controlSize) {
                ForEach(WidgetControlSize.allCases) { Text($0.title).tag($0) }
            }
            PreciseSlider(title: "Header icon size", value: content.iconSize, range: 8...48, step: 1, suffix: "pt")
        }
        Section("Card") {
'''
s = replace_once(s, old, new, "widget layout section")
# Enhance card section after min height.
old = '''            PreciseSlider(title: "Minimum height", value: style.minimumHeight, range: 0...400, step: 1, suffix: "pt")
        }
        if selected == .clock {
'''
new = '''            PreciseSlider(title: "Minimum height", value: style.minimumHeight, range: 0...400, step: 1, suffix: "pt")
            Divider()
            ColorPicker("Border color", selection: Binding(get: { chrome.wrappedValue.borderColor.color }, set: { chrome.wrappedValue.borderColor = WidgetColor($0) }), supportsOpacity: false)
            PreciseSlider(title: "Border opacity", value: chrome.borderOpacity, range: 0...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Border width", value: chrome.borderWidth, range: 0...6, step: 0.25, suffix: "pt", decimals: 2)
            PreciseSlider(title: "Shadow opacity", value: chrome.shadowOpacity, range: 0...0.8, step: 0.05, decimals: 2)
            if chrome.wrappedValue.shadowOpacity > 0 {
                PreciseSlider(title: "Shadow radius", value: chrome.shadowRadius, range: 0...40, step: 1, suffix: "pt")
                PreciseSlider(title: "Shadow Y", value: chrome.shadowY, range: -30...30, step: 1, suffix: "pt")
            }
            PreciseSlider(title: "Content opacity", value: chrome.contentOpacity, range: 0.15...1, step: 0.05, decimals: 2)
        }
        moduleSpecificSettings
        if selected == .clock {
'''
s = replace_once(s, old, new, "widget card effects")
# Enhance clock section with date style.
old = '''                Toggle("Show date", isOn: style.clock.showDate)
                SearchableStringPicker(title: "Time zone", selection: style.clock.timeZone, values: [""] + Self.timeZones, emptyLabel: "System time zone")
'''
new = '''                Toggle("Show date", isOn: style.clock.showDate)
                if style.wrappedValue.clock.showDate {
                    Picker("Date style", selection: content.clockDateStyle) {
                        ForEach(WidgetClockDateStyle.allCases) { Text($0.title).tag($0) }
                    }
                }
                SearchableStringPicker(title: "Time zone", selection: style.clock.timeZone, values: [""] + Self.timeZones, emptyLabel: "System time zone")
'''
s = replace_once(s, old, new, "clock relevant settings")
# Insert moduleSpecificSettings helper before colorPicker helper.
anchor = '''    private func colorPicker(_ title: String, _ value: Binding<WidgetColor>) -> some View {
'''
helper = '''    @ViewBuilder private var moduleSpecificSettings: some View {
        switch selected {
        case .clock:
            EmptyView()
        case .timer:
            Section("Focus timer") {
                Toggle("Show status / helper text", isOn: content.showSecondaryText)
                Toggle("Show timer controls", isOn: content.showControls)
                PreciseSlider(title: "Preset 1", value: Binding(get: { Double(content.wrappedValue.timerPresetA) }, set: { content.wrappedValue.timerPresetA = Int($0) }), range: 1...180, step: 1, suffix: "min")
                PreciseSlider(title: "Preset 2", value: Binding(get: { Double(content.wrappedValue.timerPresetB) }, set: { content.wrappedValue.timerPresetB = Int($0) }), range: 1...180, step: 1, suffix: "min")
                PreciseSlider(title: "Preset 3", value: Binding(get: { Double(content.wrappedValue.timerPresetC) }, set: { content.wrappedValue.timerPresetC = Int($0) }), range: 1...180, step: 1, suffix: "min")
            }
        case .shelf:
            Section("File Shelf") {
                PreciseSlider(title: "Visible items", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show file details", isOn: content.shelfShowDetails)
                Toggle("Show file actions", isOn: content.shelfShowActions)
                Toggle("Show Add button", isOn: content.showQuickActions)
                Toggle("Show overflow count", isOn: content.showFooter)
                PreciseSlider(title: "File icon size", value: content.shelfIconSize, range: 14...64, step: 1, suffix: "pt")
            }
        case .media:
            Section("Media") {
                Toggle("Show source", isOn: content.mediaShowSource)
                Toggle("Show artist", isOn: content.mediaShowArtist)
                Toggle("Show playback controls", isOn: content.showControls)
                Toggle("Show errors / status", isOn: content.showStatus)
                PreciseSlider(title: "Title lines", value: Binding(get: { Double(content.wrappedValue.mediaTitleLines) }, set: { content.wrappedValue.mediaTitleLines = Int($0) }), range: 1...4, step: 1)
            }
        case .audio:
            Section("Audio") {
                PreciseSlider(title: "Maximum listed outputs", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show volume control", isOn: content.showControls)
                Toggle("Show refresh action", isOn: content.showQuickActions)
                Toggle("Show status / errors", isOn: content.showStatus)
            }
        case .calendar:
            Section("Calendar") {
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show calendar status", isOn: content.showStatus)
                Toggle("Show event times", isOn: content.calendarShowTimes)
                Toggle("Show Join buttons", isOn: content.calendarShowJoin)
                Toggle("Show refresh action", isOn: content.showQuickActions)
            }
        case .clipboard:
            Section("Clipboard") {
                PreciseSlider(title: "Visible entries", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show search", isOn: content.showSearch)
                Toggle("Show Copy / Remove", isOn: content.showControls)
                Toggle("Show Clear history", isOn: content.showQuickActions)
                Toggle("Show privacy footer", isOn: content.showFooter)
            }
        case .system:
            Section("System information") {
                Toggle("Battery", isOn: content.systemBattery)
                Toggle("Battery progress", isOn: content.showProgress)
                Toggle("Memory", isOn: content.systemMemory)
                Toggle("Storage", isOn: content.systemStorage)
                Toggle("Uptime / Low Power Mode", isOn: content.systemUptime)
            }
        case .launcher:
            Section("Launcher") {
                Toggle("Search field", isOn: content.showSearch)
                Toggle("Timer shortcuts", isOn: content.launcherTimers)
                Toggle("Running applications", isOn: content.launcherRunningApps)
                Toggle("Plugin commands", isOn: content.launcherPlugins)
                Toggle("Open App / Downloads shortcuts", isOn: content.showQuickActions)
                PreciseSlider(title: "Maximum apps / commands", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
            }
        case .activities:
            Section("Activities") {
                PreciseSlider(title: "Visible activities", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show detail", isOn: content.activitiesShowDetail)
                Toggle("Show progress", isOn: content.showProgress)
                Toggle("Show dismiss controls", isOn: content.showControls)
                Toggle("Show empty status", isOn: content.showStatus)
            }
        case .notes:
            Section("Notes") {
                PreciseSlider(title: "Editor height", value: content.notesHeight, range: 60...420, step: 5, suffix: "pt")
            }
        case .capture:
            Section("Capture & OCR") {
                Toggle("Show permission hint", isOn: content.captureShowHelp)
                Toggle("Show capture controls", isOn: content.showControls)
                Toggle("Show progress / errors", isOn: content.showStatus)
                PreciseSlider(title: "OCR text lines", value: Binding(get: { Double(content.wrappedValue.captureTextLines) }, set: { content.wrappedValue.captureTextLines = Int($0) }), range: 2...40, step: 1)
            }
        case .stopwatch:
            Section("Stopwatch") {
                PreciseSlider(title: "Time scale", value: content.stopwatchScale, range: 0.8...4, step: 0.1, decimals: 1)
                Toggle("Show controls", isOn: content.showControls)
            }
        case .developer:
            EmptyView()
        }
    }

'''
if anchor not in s:
    raise SystemExit("missing colorPicker anchor")
s = s.replace(anchor, helper + anchor, 1)
p.write_text(s)

# -----------------------------------------------------------------------------
# Documentation wording: clarify opened widget depth, not closed-notch slots.
# -----------------------------------------------------------------------------
p = Path("Docs/WidgetCustomization.md")
s = p.read_text()
old = '''Open Settings → Widgets and select any of the fourteen widgets. Changes apply live to global layouts. Pick system, rounded, serif, monospaced or an installed custom font; set weight, text size, text/accent/card colors, background opacity, padding, corners, maximum card width and minimum height. Cards remain constrained by the dashboard width. Reset affects only the selected widget. System controls may retain platform-specific sizing.
'''
new = '''Open Settings → Widgets and select any opened-dashboard widget. Changes apply live to global layouts. In addition to typography, text/accent/card colors, background opacity, padding, corners, maximum width and minimum height, each widget now has independent content alignment, spacing, control sizing, border/shadow treatment and content opacity. Widget-specific sections expose the controls that actually matter to that module: timer presets, Shelf row/action density, media metadata and controls, Calendar event count/times/Join actions, Clipboard search/history density, System metrics, Launcher sources, Activity detail/progress, Notes height, Capture/OCR density and Stopwatch sizing. These settings are for the opened notch dashboard; Closed Notch slots keep their existing dedicated editor. Cards remain constrained by dashboard width. Reset affects only the selected widget. System controls may retain platform-specific sizing.
'''
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s)

print("Corrected customization target: opened dashboard widgets; Drop CI retained")
