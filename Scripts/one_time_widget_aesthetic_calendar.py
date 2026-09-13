from pathlib import Path

ROOT = Path('.')

def read(path):
    return (ROOT / path).read_text()

def write(path, text):
    (ROOT / path).write_text(text)

def replace_once(path, old, new):
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:120]!r}')
    write(path, text.replace(old, new, 1))

def replace_between(path, start_marker, end_marker, replacement):
    text = read(path)
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'{path}: start marker not found: {start_marker}')
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f'{path}: end marker not found: {end_marker}')
    write(path, text[:start] + replacement + text[end:])

# 1. Explicitly empty Visual Workspaces must stay empty.
replace_once('Halo/Core/WorkspaceModels.swift', '''    var resolvedOpenNotchLayout: OpenNotchLayout {
        if let openNotch, !openNotch.regions.isEmpty { return openNotch }
        return OpenNotchLayout.migrated(
            modules: normalizedOrder().filter { enabled.contains($0) },
            horizontal: horizontalWidgets ?? false
        )
    }

    mutating func materializeOpenNotchLayout() {
        if openNotch == nil || openNotch?.regions.isEmpty == true { openNotch = resolvedOpenNotchLayout }
    }
''', '''    var resolvedOpenNotchLayout: OpenNotchLayout {
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
    }
''')

# 2. Calendar presentation modes + backwards-compatible content controls.
widget_models = read('Halo/Core/WidgetModels.swift')
marker = '''/// Content controls for the opened-notch widget dashboard. One instance belongs to one ModuleID,
'''
if 'enum CalendarWidgetViewStyle' not in widget_models:
    enums = '''enum CalendarWidgetViewStyle: String, Codable, CaseIterable, Identifiable {
    case agenda = "Agenda"
    case monthGrid = "Month Grid"
    case weekStrip = "Week Strip"
    case split = "Split"
    var id: String { rawValue }
}

'''
    idx = widget_models.find(marker)
    if idx < 0:
        raise SystemExit('WidgetModels: content marker not found')
    widget_models = widget_models[:idx] + enums + widget_models[idx:]
    write('Halo/Core/WidgetModels.swift', widget_models)

replace_once('Halo/Core/WidgetModels.swift', '''    var calendarShowTimes = true
    var calendarShowJoin = true

    var systemBattery = true
''', '''    var calendarShowTimes = true
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
''')

# Make every Visual Workspace module start from a more considered visual treatment.
replace_between('Halo/Core/WidgetModels.swift', 'extension WidgetStyle {\n    /// A restrained, integrated default for module blocks inside the Visual Workspace.', '\n\nenum ClosedNotchItem:', '''extension WidgetStyle {
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
        case .developer:
            break
        }
        value.elementStyles = elements
        return value
    }
}''')

# 3. Calendar service now supports true month/week views while preserving today's event API.
replace_once('Halo/Services/Integrations.swift', '''    @Published var events: [EKEvent] = []
    @Published var status = "Calendar access is off. Enable it to show today's schedule."
''', '''    @Published var events: [EKEvent] = []
    @Published var upcomingEvents: [EKEvent] = []
    @Published var status = "Calendar access is off. Enable it to show today's schedule."
''')
replace_between('Halo/Services/Integrations.swift', '    func refresh() {\n', '    func meetingURL(for event: EKEvent) -> URL? {', '''    func refresh() {
        guard isAuthorized else { events = []; upcomingEvents = []; return }
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
        let horizon = calendar.date(byAdding: .day, value: 14, to: today) ?? now.addingTimeInterval(14 * 86_400)
        let all = store.events(matching: store.predicateForEvents(withStart: today, end: horizon, calendars: nil))
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        upcomingEvents = all
        events = all.filter { $0.startDate < tomorrow && $0.endDate > now }
        status = events.isEmpty ? "No more events today" : "Today's schedule"
    }

    func events(around anchor: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.autoupdatingCurrent
        let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start ?? calendar.startOfDay(for: anchor)
        let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        let gridEnd = calendar.date(byAdding: .day, value: 42, to: gridStart) ?? gridStart.addingTimeInterval(42 * 86_400)
        return store.events(matching: store.predicateForEvents(withStart: gridStart, end: gridEnd, calendars: nil))
            .sorted { $0.startDate < $1.startDate }
    }

    private var isAuthorized: Bool {
        let authorization = EKEventStore.authorizationStatus(for: .event)
        if authorization == .authorized { return true }
        if #available(macOS 14.0, *) { return authorization == .fullAccess }
        return false
    }
''')

# 4. Runtime uses module-aware polished defaults.
surface = read('Halo/Views/SurfaceView.swift')
surface = surface.replace('layout.widgetStyle(for: module).visualWorkspacePolished()', 'layout.widgetStyle(for: module).visualWorkspacePolished(for: module)')
write('Halo/Views/SurfaceView.swift', surface)

# 5. Rich calendar UI plus stronger audio/system/clipboard/launcher visual compositions.
module_path = 'Halo/Views/ModuleViews.swift'
module_text = read(module_path)
if 'import EventKit' not in module_text:
    module_text = module_text.replace('import ImageIO\n', 'import ImageIO\nimport EventKit\n', 1)
write(module_path, module_text)

replace_between(module_path, 'struct AudioModuleView: View {', '\nstruct CalendarModuleView: View {', '''struct AudioModuleView: View {
    @Environment(\\.widgetStyle) private var style
    @Environment(\\.openNotchPresentation) private var presentation
    @ObservedObject var service: AudioService
    private var options: WidgetContentOptions { style.resolvedContent }
    private var selectedName: String { service.devices.first(where: { $0.id == service.selected })?.name ?? "Audio Output" }

    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
                HStack(spacing: 10) {
                    Image(systemName: service.volume <= 0.001 ? "speaker.slash.fill" : service.volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(style.accentColor.color)
                        .frame(width: 34, height: 34)
                        .background(style.accentColor.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedName).lineLimit(1).font(.system(size: 13, weight: .semibold))
                        Text("\\(service.devices.count) output\\(service.devices.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text("\\(Int(service.volume * 100))")
                        .font(.system(size: presentation == .compact ? 24 : 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%").font(.caption).foregroundStyle(.secondary)
                }
            }
            if service.canSetVolume && options.showControls {
                WidgetElement(key: "volume") {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
                if presentation != .compact {
                    WidgetElement(key: "volumeValue", defaultPriority: .low) {
                        HStack { Text("Output volume"); Spacer(); Text("\\(Int(service.volume * 100))%").monospacedDigit().foregroundStyle(style.accentColor.color) }
                    }
                }
            } else if !service.canSetVolume && options.showStatus {
                WidgetElement(key: "status") { Label("This output uses hardware volume controls.", systemImage: "dial.medium") }
            }
            if presentation != .compact {
                WidgetElement(key: "output") {
                    Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                        ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                }
            }
            WidgetElement(key: "levels", defaultVisible: false) {
                HStack(spacing: 6) {
                    ForEach([0, 25, 50, 75, 100], id: \\.self) { value in
                        Button("\\(value)%") { service.setVolume(Float(value) / 100) }.buttonStyle(.bordered)
                    }
                }
            }
            if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Refresh devices") { service.refresh() } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.refresh() }
    }
}
''')

calendar_view = r'''struct CalendarModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: CalendarService
    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthAnchor = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthEvents: [EKEvent] = []

    private var options: WidgetContentOptions { style.resolvedContent }
    private var calendar: Calendar { Calendar.autoupdatingCurrent }
    private var requestedView: CalendarWidgetViewStyle { options.resolvedCalendarViewStyle }
    private var effectiveView: CalendarWidgetViewStyle {
        let width = availableWidth ?? 360
        let height = availableHeight ?? 220
        if presentation == .compact || width < 230 || height < 120 {
            return requestedView == .agenda ? .agenda : .weekStrip
        }
        if requestedView == .split && width < 390 { return .monthGrid }
        return requestedView
    }

    var body: some View {
        Group {
            switch effectiveView {
            case .agenda: agendaView
            case .monthGrid: monthGridView
            case .weekStrip: weekStripView
            case .split: splitView
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.refresh(); loadMonth() }
        .onChange(of: monthAnchor) { _ in loadMonth() }
        .onChange(of: service.events.count) { _ in loadMonth() }
    }

    private var agendaView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") { dateHero }
            if let next = service.upcomingEvents.first {
                WidgetElement(key: "nextEvent") { eventRow(next, prominent: true) }
            }
            if presentation != .compact {
                WidgetElement(key: "events") {
                    VStack(spacing: max(5, options.spacing * 0.65)) {
                        ForEach(Array(service.upcomingEvents.prefix(options.maxItems).enumerated()), id: \.offset) { _, event in
                            eventRow(event)
                        }
                        if service.upcomingEvents.isEmpty { emptyDay }
                    }
                }
            }
            statusAndActions
        }
    }

    private var monthGridView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: max(5, options.spacing * 0.75)) {
            WidgetElement(key: "summary") { miniMonth }
            if options.showsCalendarAgendaBelowGrid && presentation != .compact {
                WidgetElement(key: "events") { selectedDayAgenda }
            }
            statusAndActions
        }
    }

    private var weekStripView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: max(5, options.spacing * 0.75)) {
            WidgetElement(key: "summary") {
                HStack(spacing: 5) {
                    ForEach(weekDays, id: \.self) { day in weekDayButton(day) }
                }
            }
            if presentation != .compact { WidgetElement(key: "events") { selectedDayAgenda } }
            statusAndActions
        }
    }

    private var splitView: some View {
        VStack(spacing: max(4, options.spacing * 0.55)) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: max(8, options.spacing)) {
                    WidgetElement(key: "summary") { miniMonth }.frame(minWidth: 190)
                    Divider().opacity(0.35)
                    WidgetElement(key: "events") { selectedDayAgenda }.frame(minWidth: 170)
                }
                VStack(spacing: max(6, options.spacing * 0.7)) {
                    WidgetElement(key: "summary") { miniMonth }
                    WidgetElement(key: "events") { selectedDayAgenda }
                }
            }
            statusAndActions
        }
    }

    private var dateHero: some View {
        HStack(alignment: .center, spacing: 11) {
            VStack(spacing: -2) {
                Text(Date.now, format: .dateTime.month(.abbreviated).locale(.autoupdatingCurrent))
                    .font(.system(size: 11, weight: .bold, design: .rounded)).textCase(.uppercase).foregroundStyle(style.accentColor.color)
                Text(Date.now, format: .dateTime.day())
                    .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide)).font(.system(size: 15, weight: .semibold))
                Text(service.events.isEmpty ? "Your day is clear" : "\\(service.events.count) event\\(service.events.count == 1 ? "" : "s") left today")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var miniMonth: some View {
        VStack(spacing: 5) {
            HStack {
                if options.showControls {
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                }
                Text(monthAnchor, format: .dateTime.month(.wide).year())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button("Today") { monthAnchor = calendar.startOfDay(for: Date()); selectedDate = monthAnchor }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(style.accentColor.color)
                if options.showControls {
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
                }
            }
            if options.showsCalendarWeekdayHeader {
                LazyVGrid(columns: dayColumns, spacing: 2) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased()).font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            LazyVGrid(columns: dayColumns, spacing: 2) {
                ForEach(monthDays, id: \.self) { day in dayCell(day) }
            }
        }
    }

    private var selectedDayAgenda: some View {
        let events = events(on: selectedDate)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedDate, format: .dateTime.weekday(.wide)).font(.system(size: 13, weight: .semibold))
                    Text(selectedDate, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(events.isEmpty ? "Clear" : "\\(events.count) event\\(events.count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if events.isEmpty { emptyDay }
            else {
                ForEach(Array(events.prefix(options.maxItems).enumerated()), id: \.offset) { _, event in eventRow(event) }
            }
        }
    }

    private var emptyDay: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles").foregroundStyle(style.accentColor.color)
            Text("Nothing scheduled").foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func eventRow(_ event: EKEvent, prominent: Bool = false) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(style.accentColor.color).frame(width: 3, height: prominent ? 36 : 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled event")
                    .font(.system(size: prominent ? 13 : 12, weight: prominent ? .semibold : .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if options.calendarShowTimes {
                        Text(event.isAllDay ? "All day" : event.startDate.formatted(date: calendar.isDateInToday(event.startDate) ? .omitted : .abbreviated, time: event.isAllDay ? .omitted : .shortened))
                    }
                    if !event.location.isEmpty { Text(event.location).lineLimit(1) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) {
                Link(destination: url) { Image(systemName: "video.fill") }
                    .buttonStyle(.bordered).controlSize(.mini).help("Join meeting")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, prominent ? 7 : 5)
        .background(style.textColor.color.opacity(prominent ? 0.07 : 0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let eventCount = events(on: day).count
        return Button {
            selectedDate = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 1) {
                Text(day, format: .dateTime.day())
                    .font(.system(size: 10, weight: today || selected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(inMonth ? style.textColor.color : style.textColor.color.opacity(options.showsCalendarAdjacentDays ? 0.28 : 0))
                if options.showsCalendarEventDots && eventCount > 0 && (inMonth || options.showsCalendarAdjacentDays) {
                    HStack(spacing: 1.5) {
                        ForEach(0..<min(3, eventCount), id: \.self) { _ in Circle().fill(style.accentColor.color).frame(width: 2.5, height: 2.5) }
                    }.frame(height: 3)
                } else { Color.clear.frame(height: 3) }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(selected ? style.accentColor.color.opacity(0.28) : today ? style.accentColor.color.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!inMonth && !options.showsCalendarAdjacentDays)
    }

    private func weekDayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let count = events(on: day).count
        return Button { selectedDate = calendar.startOfDay(for: day); monthAnchor = day } label: {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                Text(day, format: .dateTime.day()).font(.system(size: 14, weight: selected || today ? .bold : .medium, design: .rounded))
                Circle().fill(count > 0 ? style.accentColor.color : Color.clear).frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(selected ? style.accentColor.color.opacity(0.22) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var statusAndActions: some View {
        if options.showStatus && presentation == .expanded {
            WidgetElement(key: "status", defaultPriority: .low) { Text(service.status) }
        }
        if options.showQuickActions && presentation == .expanded {
            WidgetElement(key: "actions", defaultPriority: .low) { Button("Enable / Refresh calendar") { service.requestAccess(); loadMonth() } }
        }
    }

    private var dayColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 2), count: 7) }
    private var weekdaySymbols: [String] {
        let values = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, min(6, calendar.firstWeekday - 1))
        return (0..<7).map { values[(offset + $0) % values.count] }
    }
    private var monthDays: [Date] {
        let start = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
        let grid = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: grid) }
    }
    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    private func events(on day: Date) -> [EKEvent] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return monthEvents.filter { $0.startDate < end && $0.endDate > start }
    }
    private func changeMonth(_ amount: Int) {
        monthAnchor = calendar.date(byAdding: .month, value: amount, to: monthAnchor) ?? monthAnchor
        selectedDate = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
    }
    private func loadMonth() { monthEvents = service.events(around: monthAnchor) }
}
'''
replace_between(module_path, 'struct CalendarModuleView: View {', '\nstruct ClipboardModuleView: View {', calendar_view)

# Clipboard history reads like compact content cards instead of a raw list.
replace_once(module_path, '''                WidgetElement(key: "entries") {
                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(presentation == .compact ? 1 : options.maxItems))) { entry in
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
''', '''                WidgetElement(key: "entries") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: presentation == .expanded ? 150 : 220), spacing: 7)], spacing: 7) {
                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(presentation == .compact ? 1 : options.maxItems))) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "quote.opening").font(.caption).foregroundStyle(style.accentColor.color)
                                    Spacer()
                                    Text(entry.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                                }
                                Text(entry.text).lineLimit(presentation == .expanded ? 4 : 2).frame(maxWidth: .infinity, alignment: .leading)
                                if options.showControls {
                                    HStack(spacing: 5) {
                                        Button("Copy") { service.copy(entry) }.buttonStyle(.bordered).controlSize(.mini)
                                        Spacer()
                                        Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                    }
                }
''')

# System monitor uses compact dashboard tiles instead of four identical progress rows.
system_replacement = r'''struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @ObservedObject var service: SystemService
    private var options: WidgetContentOptions { style.resolvedContent }

    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if presentation == .compact {
                HStack(spacing: 7) {
                    WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                    WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                    if options.systemBattery, let battery = service.battery {
                        WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { MetricTile(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color, showProgress: options.showProgress) }
                    WidgetElement(key: "memoryUsage", defaultPriority: .high) { MetricTile(label: "Memory", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color, showProgress: options.showProgress) }
                    WidgetElement(key: "diskUsage", defaultPriority: .normal) { MetricTile(label: "Disk", value: service.diskUsage, icon: "internaldrive", accent: style.accentColor.color, showProgress: options.showProgress) }
                    if options.systemBattery, let battery = service.battery {
                        WidgetElement(key: "battery", defaultPriority: .high) { MetricTile(label: service.charging ? "Charging" : "Battery", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color, showProgress: options.showProgress) }
                    }
                }
                WidgetElement(key: "network", defaultPriority: .normal) {
                    HStack(spacing: 8) {
                        Label("Network", systemImage: "arrow.up.arrow.down")
                        Spacer()
                        Text("↓ \\(Self.rate(service.networkDownPerSecond))").monospacedDigit()
                        Text("↑ \\(Self.rate(service.networkUpPerSecond))").monospacedDigit()
                    }
                }
                WidgetElement(key: "power", defaultPriority: .normal) {
                    HStack {
                        Label(service.lowPower ? "Low Power Mode" : "Normal power", systemImage: service.lowPower ? "leaf.fill" : "bolt.fill")
                        Spacer(); Text(service.onBattery ? "Battery" : "External power").foregroundStyle(.secondary)
                    }
                }
            }
            if presentation == .expanded {
                WidgetElement(key: "graphs", defaultVisible: false, defaultPriority: .optional) {
                    VStack(spacing: 8) { MiniMetricGraph(title: "CPU", values: service.cpuHistory, accent: style.accentColor.color); MiniMetricGraph(title: "Memory", values: service.memoryHistory, accent: style.accentColor.color.opacity(0.75)); MiniMetricGraph(title: "Network", values: service.networkHistory, accent: style.accentColor.color.opacity(0.55)) }
                }
                WidgetElement(key: "swap", defaultVisible: false, defaultPriority: .low) { MetricRow(label: "Swap", value: service.swapUsage, icon: "arrow.triangle.swap") }
                WidgetElement(key: "thermal", defaultVisible: false, defaultPriority: .low) { HStack { Label("Thermal", systemImage: "thermometer.medium"); Spacer(); Text(service.thermalState) } }
                if options.systemMemory { WidgetElement(key: "memory", defaultPriority: .low) { Label(service.memory, systemImage: "memorychip") } }
                if options.systemStorage { WidgetElement(key: "storage", defaultPriority: .low) { Label(service.storage, systemImage: "internaldrive") } }
                if options.systemUptime { WidgetElement(key: "uptime", defaultPriority: .low) { Label(service.uptime, systemImage: "clock.arrow.circlepath") } }
                WidgetElement(key: "device", defaultVisible: false, defaultPriority: .optional) { VStack(alignment: options.alignment.horizontal, spacing: 3) { Text(ProcessInfo.processInfo.operatingSystemVersionString); Text("\\(ProcessInfo.processInfo.processorCount) logical processors").foregroundStyle(.secondary) } }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
    private static func rate(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file) + "/s" }
}

private struct CompactMetric: View {
    let label: String; let value: Double; let icon: String; let accent: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.0f%%", value)).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(label).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricTile: View {
    let label: String; let value: Double; let icon: String; let accent: Color; let showProgress: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    .frame(width: 26, height: 26).background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
                Text(String(format: "%.0f%%", value)).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
            if showProgress { ProgressView(value: value, total: 100).controlSize(.mini) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricRow: View {
    let label: String; let value: Double; let icon: String
    var body: some View { VStack(spacing: 4) { HStack { Label(label, systemImage: icon); Spacer(); Text(String(format: "%.0f%%", value)).monospacedDigit() }; ProgressView(value: value, total: 100) } }
}

'''
replace_between(module_path, 'struct SystemModuleView: View {', 'private struct MiniMetricGraph: View {', system_replacement)

# Launcher becomes an icon launcher rather than a text-button list.
replace_once(module_path, '''            if options.launcherRunningApps {
                WidgetElement(key: "apps") {
                    VStack(alignment: options.alignment.horizontal, spacing: max(4, options.spacing * 0.65)) {
                        ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \\.processIdentifier) { app in
                            Button { app.activate(options: .activateIgnoringOtherApps) } label: { Label(app.localizedName ?? "Application", systemImage: "app") }
                        }
                    }
                }
            }
''', '''            if options.launcherRunningApps {
                WidgetElement(key: "apps") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 7)], spacing: 7) {
                        ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \\.processIdentifier) { app in
                            Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                                VStack(spacing: 5) {
                                    if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: 30, height: 30) }
                                    else { Image(systemName: "app.fill").font(.system(size: 24)).foregroundStyle(style.accentColor.color) }
                                    Text(app.localizedName ?? "Application").font(.caption2).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 7).padding(.horizontal, 4)
                                .background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
''')

# 6. Settings: expose calendar compositions globally and per Visual Workspace instance.
settings_path = 'Halo/Views/WidgetSettingsView.swift'
settings = read(settings_path)
settings = settings.replace('.visualWorkspacePolished()', '.visualWorkspacePolished(for: module)')
write(settings_path, settings)

replace_once(settings_path, '''        case .calendar:
            Section("Calendar") {
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show calendar status", isOn: content.showStatus)
                Toggle("Show event times", isOn: content.calendarShowTimes)
                Toggle("Show Join buttons", isOn: content.calendarShowJoin)
                Toggle("Show refresh action", isOn: content.showQuickActions)
            }
''', '''        case .calendar:
            Section("Calendar") {
                Picker("View", selection: content.calendarViewStyle.withDefault(.agenda)) {
                    ForEach(CalendarWidgetViewStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show weekday labels", isOn: content.calendarShowWeekdayHeader.withDefault(true))
                Toggle("Show adjacent-month days", isOn: content.calendarShowAdjacentDays.withDefault(true))
                Toggle("Show event dots", isOn: content.calendarShowEventDots.withDefault(true))
                if content.wrappedValue.resolvedCalendarViewStyle == .monthGrid {
                    Toggle("Show selected-day agenda", isOn: content.calendarShowAgendaBelowGrid.withDefault(true))
                }
                Toggle("Show calendar status", isOn: content.showStatus)
                Toggle("Show event times", isOn: content.calendarShowTimes)
                Toggle("Show Join buttons", isOn: content.calendarShowJoin)
                Toggle("Show refresh action", isOn: content.showQuickActions)
            }
''')

replace_once(settings_path, '''        Section("Block Styling") {
''', '''        if module == .calendar {
            let content = style.content.withDefault(WidgetContentOptions())
            Section("Calendar Presentation") {
                Picker("View", selection: content.calendarViewStyle.withDefault(.split)) {
                    ForEach(CalendarWidgetViewStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("Agenda emphasizes upcoming events, Month Grid is a real navigable calendar, Week Strip is compact, and Split pairs the month with the selected day's agenda.")
                    .font(.caption).foregroundStyle(.secondary)
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...20, step: 1)
                Toggle("Weekday labels", isOn: content.calendarShowWeekdayHeader.withDefault(true))
                Toggle("Adjacent-month days", isOn: content.calendarShowAdjacentDays.withDefault(true))
                Toggle("Event dots", isOn: content.calendarShowEventDots.withDefault(true))
                if content.wrappedValue.resolvedCalendarViewStyle == .monthGrid {
                    Toggle("Agenda below month", isOn: content.calendarShowAgendaBelowGrid.withDefault(true))
                }
                Toggle("Event times", isOn: content.calendarShowTimes)
                Toggle("Join buttons", isOn: content.calendarShowJoin)
            }
        }
        Section("Block Styling") {
''')

# Empty workspace editor state instead of confusing blank legacy tracks.
replace_once(settings_path, '''                        if opened.resolvedContentMode == .fixed && opened.usesFreeformRegions {
                            freeformPreview(canvasSize: canvasSize)
                                .padding(inset)
                        } else {
''', '''                        if opened.regions.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "rectangle.dashed").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
                                Text("No regions").font(.headline)
                                Text("This workspace is intentionally empty.").font(.caption).foregroundStyle(.secondary)
                                Button("Add Region") { addRegion() }.buttonStyle(.borderedProminent)
                            }
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .padding(inset)
                        } else if opened.resolvedContentMode == .fixed && opened.usesFreeformRegions {
                            freeformPreview(canvasSize: canvasSize)
                                .padding(inset)
                        } else {
''')

print('Applied empty-workspace fix, calendar presentation modes, and aesthetic widget polish.')
