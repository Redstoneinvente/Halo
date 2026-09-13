from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Expected source block not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))

# 1) Calendar-specific model. Keep the legacy opened-notch CalendarWidgetViewStyle intact.
model_path = "Halo/Core/WidgetModels.swift"
model = Path(model_path).read_text()
anchor = '''enum CalendarWidgetViewStyle: String, Codable, CaseIterable, Identifiable {
    case agenda = "Agenda"
    case monthGrid = "Month Grid"
    case weekStrip = "Week Strip"
    case split = "Split"
    var id: String { rawValue }
}
'''
calendar_models = anchor + r'''

enum VisualCalendarViewStyle: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case today = "Today"
    case agenda = "Agenda"
    case dayTimeline = "Day Timeline"
    case week = "Week"
    case month = "Month"
    case monthAgenda = "Month + Agenda"
    case split = "Split"
    case upcoming = "Upcoming"
    case minimal = "Minimal"
    var id: String { rawValue }
}

enum VisualCalendarWeekStart: String, Codable, CaseIterable, Identifiable {
    case system = "System Default"
    case monday = "Monday"
    case sunday = "Sunday"
    var id: String { rawValue }
}

enum VisualCalendarEventIndicatorStyle: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case dots = "Dots"
    case bars = "Bars"
    case underline = "Underline"
    case filledDate = "Filled Date"
    case minimalMarker = "Minimal Marker"
    var id: String { rawValue }
}

enum VisualCalendarTodayStyle: String, Codable, CaseIterable, Identifiable {
    case circle = "Circle"
    case pill = "Pill"
    case filledNumber = "Filled Number"
    case outline = "Outline"
    case accentText = "Accent Text"
    case subtleGlow = "Subtle Glow"
    case minimalDot = "Minimal Dot"
    var id: String { rawValue }
}

enum VisualCalendarDensity: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case compact = "Compact"
    case comfortable = "Comfortable"
    case spacious = "Spacious"
    var id: String { rawValue }
}

enum VisualCalendarWeekendStyle: String, Codable, CaseIterable, Identifiable {
    case normal = "Normal"
    case subtle = "Subtle"
    case muted = "Muted"
    case accent = "Accent"
    var id: String { rawValue }
}

enum VisualCalendarFilterMode: String, Codable, CaseIterable, Identifiable {
    case all = "All Calendars"
    case work = "Work"
    case personal = "Personal"
    case birthdays = "Birthdays"
    case custom = "Custom Selection"
    var id: String { rawValue }
}

enum VisualCalendarInformation: String, Codable, CaseIterable, Identifiable, Hashable {
    case startTime, calendarColor, endTime, location, meetingLink, duration, notes, attendees
    var id: String { rawValue }
    var title: String {
        switch self {
        case .startTime: return "Start time"
        case .calendarColor: return "Calendar color"
        case .endTime: return "End time"
        case .location: return "Location"
        case .meetingLink: return "Meeting link"
        case .duration: return "Duration"
        case .notes: return "Notes preview"
        case .attendees: return "Attendee indicator"
        }
    }
}

struct VisualCalendarTypography: Codable, Equatable {
    var fontFamily: WidgetFontFamily = .system
    var customFont = "Helvetica Neue"
    var weight: WidgetFontWeight = .medium
    var size = 13.0

    func validated() throws -> VisualCalendarTypography {
        guard size.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var value = self
        value.customFont = String(customFont.prefix(120))
        value.size = min(48, max(8, size))
        return value
    }
}

struct VisualCalendarSizeOverride: Codable, Equatable {
    var view: VisualCalendarViewStyle?
    var maxEvents: Int?
    var indicatorStyle: VisualCalendarEventIndicatorStyle?
}

struct VisualCalendarOptions: Codable, Equatable {
    var preferredView: VisualCalendarViewStyle = .automatic
    var weekStart: VisualCalendarWeekStart = .system
    var showWeekNumbers = false
    var showAdjacentMonthDays = true
    var highlightToday = true
    var highlightSelectedDay = true
    var eventIndicatorStyle: VisualCalendarEventIndicatorStyle = .automatic
    var visibleEventIndicators = 3
    var weekendStyle: VisualCalendarWeekendStyle = .subtle
    var density: VisualCalendarDensity = .automatic
    var maxEvents = 8

    var showEventEndTime = true
    var showEventDuration = true
    var showEventLocation = true
    var showMeetingLink = true
    var showNotesPreview = true
    var showAttendees = true
    var enabledInformation: [VisualCalendarInformation] = VisualCalendarInformation.allCases
    var informationPriority: [VisualCalendarInformation] = [.startTime, .calendarColor, .endTime, .location, .meetingLink, .duration, .notes, .attendees]

    var filterMode: VisualCalendarFilterMode = .all
    var customCalendarNames: [String] = []
    var useNativeCalendarColors = true
    var eventColorOverride: WidgetColor?

    var todayStyle: VisualCalendarTodayStyle = .filledNumber
    var todayColor: WidgetColor?
    var selectedDayColor: WidgetColor?
    var eventCornerRadius = 8.0
    var eventOpacity = 0.08
    var showGridLines = false
    var gridLineOpacity = 0.08
    var backgroundOpacity = 0.0

    var dateTypography = VisualCalendarTypography(fontFamily: .rounded, customFont: "Helvetica Neue", weight: .bold, size: 14)
    var eventTypography = VisualCalendarTypography(fontFamily: .system, customFont: "Helvetica Neue", weight: .medium, size: 12)
    var monthTypography = VisualCalendarTypography(fontFamily: .rounded, customFont: "Helvetica Neue", weight: .semibold, size: 13)

    var sizeOverrides: [String: VisualCalendarSizeOverride] = [:]

    static func sizeKey(columns: Int, rows: Int) -> String { "\(min(8, max(1, columns)))x\(min(4, max(1, rows)))" }
    func sizeOverride(columns: Int, rows: Int) -> VisualCalendarSizeOverride? { sizeOverrides[Self.sizeKey(columns: columns, rows: rows)] }

    var resolvedInformationPriority: [VisualCalendarInformation] {
        var result: [VisualCalendarInformation] = []
        for value in informationPriority where !result.contains(value) { result.append(value) }
        for value in VisualCalendarInformation.allCases where !result.contains(value) { result.append(value) }
        return result
    }

    func validated() throws -> VisualCalendarOptions {
        guard eventCornerRadius.isFinite, eventOpacity.isFinite, gridLineOpacity.isFinite, backgroundOpacity.isFinite else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var value = self
        value.visibleEventIndicators = min(6, max(1, visibleEventIndicators))
        value.maxEvents = min(30, max(1, maxEvents))
        value.eventCornerRadius = min(24, max(0, eventCornerRadius))
        value.eventOpacity = min(0.45, max(0, eventOpacity))
        value.gridLineOpacity = min(0.5, max(0, gridLineOpacity))
        value.backgroundOpacity = min(0.6, max(0, backgroundOpacity))
        value.customCalendarNames = customCalendarNames.map { String($0.prefix(120)) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        value.eventColorOverride = try eventColorOverride?.validated()
        value.todayColor = try todayColor?.validated()
        value.selectedDayColor = try selectedDayColor?.validated()
        value.dateTypography = try dateTypography.validated()
        value.eventTypography = try eventTypography.validated()
        value.monthTypography = try monthTypography.validated()
        value.enabledInformation = VisualCalendarInformation.allCases.filter { enabledInformation.contains($0) }
        value.informationPriority = resolvedInformationPriority
        value.sizeOverrides = sizeOverrides.filter { key, override in
            let parts = key.split(separator: "x")
            guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]), (1...8).contains(columns), (1...4).contains(rows) else { return false }
            if let maxEvents = override.maxEvents, !(1...30).contains(maxEvents) { return false }
            return true
        }
        return value
    }
}
'''
if anchor not in model:
    raise SystemExit("CalendarWidgetViewStyle anchor not found")
model = model.replace(anchor, calendar_models, 1)
model = model.replace('''    var showTitle = true
    var clock = ClockOptions()
    var content: WidgetContentOptions?
''', '''    var showTitle = true
    var clock = ClockOptions()
    // Visual Workspace Calendar options live separately so the regular opened-notch Calendar keeps its legacy presentation untouched.
    var visualCalendar: VisualCalendarOptions?
    var content: WidgetContentOptions?
''', 1)
model = model.replace('''    var resolvedContent: WidgetContentOptions { content ?? WidgetContentOptions() }
    var resolvedChrome: WidgetChromeOptions { chrome ?? WidgetChromeOptions() }
''', '''    var resolvedContent: WidgetContentOptions { content ?? WidgetContentOptions() }
    var resolvedVisualCalendar: VisualCalendarOptions { visualCalendar ?? VisualCalendarOptions() }
    var resolvedChrome: WidgetChromeOptions { chrome ?? WidgetChromeOptions() }
''', 1)
model = model.replace('''        var v = self
        v.clock = try clock.validated()
        v.fontSize = min(48, max(10, fontSize)); v.padding = min(32, max(0, padding))
''', '''        var v = self
        v.clock = try clock.validated()
        if visualCalendar != nil { v.visualCalendar = try resolvedVisualCalendar.validated() }
        v.fontSize = min(48, max(10, fontSize)); v.padding = min(32, max(0, padding))
''', 1)
Path(model_path).write_text(model)

# 2) Route only Visual Workspace grid Calendar instances to the new renderer. The legacy renderer remains byte-for-byte below.
module_path = "Halo/Views/ModuleViews.swift"
module = Path(module_path).read_text()
module = module.replace('''    @Environment(\\.openNotchAvailableWidth) private var availableWidth
    @Environment(\\.openNotchAvailableHeight) private var availableHeight
    let id: ModuleID
''', '''    @Environment(\\.openNotchAvailableWidth) private var availableWidth
    @Environment(\\.openNotchAvailableHeight) private var availableHeight
    @Environment(\\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\\.openNotchGridRowSpan) private var gridRowSpan
    let id: ModuleID
''', 1)
module = module.replace('''        case .audio: AudioModuleView(service: workspace.audio)
        case .calendar: CalendarModuleView(service: workspace.calendar)
        case .clipboard: ClipboardModuleView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled)
''', '''        case .audio: AudioModuleView(service: workspace.audio)
        case .calendar:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceCalendarView(service: workspace.calendar) }
            else { CalendarModuleView(service: workspace.calendar) }
        case .clipboard: ClipboardModuleView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled)
''', 1)
calendar_insert_anchor = 'struct CalendarModuleView: View {'
if calendar_insert_anchor not in module:
    raise SystemExit("CalendarModuleView anchor not found")
new_calendar_view = r'''
private enum VisualCalendarFamily: String, Equatable {
    case micro, compactAgenda, horizontalAgenda, verticalAgenda, miniMonth, day, schedule, month, split, hero
}

struct VisualWorkspaceCalendarView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var service: CalendarService

    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthAnchor = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthEvents: [EKEvent] = []
    @State private var selectedEventIdentifier: String?

    private var settings: VisualCalendarOptions { style.resolvedVisualCalendar }
    private var columns: Int { min(8, max(1, gridColumnSpan ?? estimatedColumns)) }
    private var rows: Int { min(4, max(1, gridRowSpan ?? estimatedRows)) }
    private var override: VisualCalendarSizeOverride? { settings.sizeOverride(columns: columns, rows: rows) }
    private var calendar: Calendar {
        var value = Calendar.autoupdatingCurrent
        switch settings.weekStart {
        case .system: break
        case .monday: value.firstWeekday = 2
        case .sunday: value.firstWeekday = 1
        }
        return value
    }
    private var family: VisualCalendarFamily { Self.family(columns: columns, rows: rows, width: availableWidth, height: availableHeight) }
    private var effectiveView: VisualCalendarViewStyle {
        let requested = override?.view ?? settings.preferredView
        guard requested == .automatic else { return degraded(requested) }
        switch family {
        case .micro: return .today
        case .compactAgenda, .horizontalAgenda, .verticalAgenda: return .agenda
        case .miniMonth: return .month
        case .day: return .dayTimeline
        case .schedule: return columns >= 5 ? .week : .upcoming
        case .month: return .monthAgenda
        case .split: return .split
        case .hero: return .split
        }
    }
    private var visibleEventLimit: Int {
        let requested = override?.maxEvents ?? settings.maxEvents
        let capacity: Int
        switch family {
        case .micro: capacity = 0
        case .compactAgenda: capacity = 1
        case .horizontalAgenda: capacity = max(1, min(4, columns - 1))
        case .verticalAgenda: capacity = max(1, min(4, rows))
        case .miniMonth: capacity = 2
        case .day: capacity = max(3, rows * 2)
        case .schedule: capacity = max(3, columns)
        case .month: capacity = max(3, rows + 1)
        case .split: capacity = max(4, rows + 2)
        case .hero: capacity = max(6, rows * 2)
        }
        return min(requested, capacity)
    }

    var body: some View {
        Group {
            switch effectiveView {
            case .automatic: todayTile
            case .today: todayPresentation
            case .agenda: agendaPresentation
            case .dayTimeline: dayTimelinePresentation
            case .week: weekPresentation
            case .month: monthPresentation
            case .monthAgenda: monthAgendaPresentation
            case .split: splitPresentation
            case .upcoming: upcomingPresentation
            case .minimal: minimalPresentation
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(style.backgroundColor.color.opacity(settings.backgroundOpacity))
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: family)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
        .animation(.easeInOut(duration: 0.2), value: selectedEventIdentifier)
        .onAppear { service.refresh(); loadMonth() }
        .onChange(of: monthAnchor) { _ in loadMonth() }
        .onChange(of: service.events.count) { _ in loadMonth() }
    }

    static func family(columns: Int, rows: Int, width: CGFloat?, height: CGFloat?) -> VisualCalendarFamily {
        let c = min(8, max(1, columns)), r = min(4, max(1, rows))
        if c == 1 && r == 1 { return .micro }
        if r == 1 { return c <= 2 ? .compactAgenda : .horizontalAgenda }
        if c == 1 { return .verticalAgenda }
        if c == 2 && r == 2 { return .miniMonth }
        if c >= 7 && r >= 4 { return .hero }
        if c >= 5 && r >= 3 { return .split }
        if c >= 4 && r >= 3 { return .month }
        if r >= 3 && c <= 2 { return .day }
        if c >= 4 && r == 2 { return .schedule }
        if c >= 3 && r >= 3 { return .month }
        if c >= 3 && r == 2 { return .schedule }
        let aspect = (width ?? CGFloat(c)) / max(1, height ?? CGFloat(r))
        return aspect > 1.35 ? .schedule : .day
    }

    private var estimatedColumns: Int { max(1, min(8, Int(round((availableWidth ?? 120) / 120)))) }
    private var estimatedRows: Int { max(1, min(4, Int(round((availableHeight ?? 100) / 100)))) }

    private func degraded(_ requested: VisualCalendarViewStyle) -> VisualCalendarViewStyle {
        switch requested {
        case .month, .monthAgenda, .split where columns == 1 || rows == 1: return rows == 1 ? .agenda : .today
        case .week where columns < 3: return .agenda
        case .dayTimeline where rows < 2: return .agenda
        case .split where columns < 4 || rows < 2: return rows >= 2 ? .monthAgenda : .agenda
        default: return requested
        }
    }

    private var filteredUpcoming: [EKEvent] { service.upcomingEvents.filter(matchesFilter) }
    private var filteredToday: [EKEvent] { service.events.filter(matchesFilter) }
    private var filteredMonth: [EKEvent] { monthEvents.filter(matchesFilter) }
    private var eventsForSelectedDate: [EKEvent] { events(on: selectedDate) }
    private var selectedEvent: EKEvent? {
        guard let selectedEventIdentifier else { return nil }
        return (filteredMonth + filteredUpcoming).first { eventKey($0) == selectedEventIdentifier }
    }

    private var todayPresentation: some View {
        Group {
            switch family {
            case .micro: todayTile
            case .compactAgenda, .horizontalAgenda: horizontalAgenda
            case .verticalAgenda: verticalAgenda
            default:
                VStack(alignment: .leading, spacing: densitySpacing(10)) {
                    todayHeader(prominent: true)
                    if !filteredToday.isEmpty { agendaList(events: filteredToday, limit: visibleEventLimit) }
                    else { subtleEmptyState }
                }
            }
        }
    }

    private var minimalPresentation: some View {
        VStack(spacing: 4) {
            Text(selectedDate, format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent))
                .font(font(settings.dateTypography, size: family == .micro ? 10 : 12)).textCase(.uppercase).foregroundStyle(.secondary)
            Text(selectedDate, format: .dateTime.day())
                .font(font(settings.dateTypography, size: family == .micro ? 36 : 46)).monospacedDigit()
            if family != .micro { Text(selectedDate, format: .dateTime.month(.abbreviated)).font(.caption).foregroundStyle(accent) }
        }
    }

    private var agendaPresentation: some View {
        Group {
            switch family {
            case .micro: todayTile
            case .compactAgenda, .horizontalAgenda: horizontalAgenda
            case .verticalAgenda: verticalAgenda
            default:
                VStack(alignment: .leading, spacing: densitySpacing(8)) {
                    dayNavigationHeader
                    allDayStrip(events: eventsForSelectedDate.filter(\.isAllDay))
                    agendaList(events: eventsForSelectedDate.filter { !$0.isAllDay }, limit: visibleEventLimit)
                    if eventsForSelectedDate.isEmpty { subtleEmptyState }
                }
            }
        }
    }

    private var upcomingPresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(8)) {
            HStack {
                Text("UPCOMING").font(font(settings.monthTypography, size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("\(filteredUpcoming.count)").font(.caption).foregroundStyle(accent)
            }
            agendaList(events: filteredUpcoming, limit: visibleEventLimit)
            if filteredUpcoming.isEmpty { subtleEmptyState }
        }
    }

    private var monthPresentation: some View {
        monthGrid(showAgenda: false)
    }

    private var monthAgendaPresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(8)) {
            monthGrid(showAgenda: false)
            Divider().opacity(0.18)
            selectedDayAgenda
        }
    }

    private var splitPresentation: some View {
        Group {
            if family == .hero || (columns >= 5 && rows >= 3) {
                HStack(alignment: .top, spacing: densitySpacing(14)) {
                    monthGrid(showAgenda: false).frame(maxWidth: .infinity)
                    Divider().opacity(0.18)
                    VStack(alignment: .leading, spacing: densitySpacing(8)) {
                        selectedDayAgenda
                        if let selectedEvent { Divider().opacity(0.16); eventDetail(selectedEvent) }
                    }.frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: densitySpacing(8)) {
                    monthGrid(showAgenda: false)
                    selectedDayAgenda
                }
            }
        }
    }

    private var dayTimelinePresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(7)) {
            dayNavigationHeader
            let allDay = eventsForSelectedDate.filter(\.isAllDay)
            if !allDay.isEmpty { allDayStrip(events: allDay) }
            ScrollView(.vertical, showsIndicators: family == .hero) {
                VStack(spacing: 0) {
                    ForEach(timelineHours, id: \.self) { hour in timelineHourRow(hour) }
                }
            }
        }
    }

    private var weekPresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(7)) {
            HStack {
                Button { selectedDate = calendar.date(byAdding: .day, value: -visibleWeekDays, to: selectedDate) ?? selectedDate; monthAnchor = selectedDate } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                Text(weekTitle).font(font(settings.monthTypography, size: 12))
                Spacer()
                Button("Today") { selectToday() }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
                Button { selectedDate = calendar.date(byAdding: .day, value: visibleWeekDays, to: selectedDate) ?? selectedDate; monthAnchor = selectedDate } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: densitySpacing(5)) {
                ForEach(visibleWeekDates, id: \.self) { day in weekColumn(day) }
            }
        }
    }

    private var todayTile: some View {
        Button { selectedDate = calendar.startOfDay(for: Date()); monthAnchor = selectedDate } label: {
            VStack(spacing: 1) {
                Text(Date(), format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent))
                    .font(font(settings.dateTypography, size: 10)).textCase(.uppercase).foregroundStyle(.secondary)
                Text(Date(), format: .dateTime.day())
                    .font(font(settings.dateTypography, size: 36)).monospacedDigit().foregroundStyle(primary)
                if !filteredToday.isEmpty {
                    Circle().fill(accent).frame(width: 4, height: 4).padding(.top, 3)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { openCalendarApp() })
    }

    private var horizontalAgenda: some View {
        HStack(spacing: densitySpacing(9)) {
            dateBadge
            Divider().opacity(0.22)
            let events = Array(filteredToday.prefix(max(1, min(visibleEventLimit, max(1, columns - 1)))))
            if events.isEmpty {
                Text("Nothing scheduled").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    compactHorizontalEvent(event)
                    if eventKey(event) != eventKey(events.last!) { Divider().opacity(0.12) }
                }
                let more = max(0, filteredToday.count - events.count)
                if more > 0 { Text("+\(more)").font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
    }

    private var verticalAgenda: some View {
        VStack(alignment: .leading, spacing: densitySpacing(7)) {
            todayHeader(prominent: false)
            let events = Array(filteredToday.prefix(max(1, visibleEventLimit)))
            ForEach(Array(events.enumerated()), id: \.offset) { _, event in agendaRow(event, compact: true) }
            let more = max(0, filteredToday.count - events.count)
            if more > 0 { Text("+\(more) more").font(.caption2).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
    }

    private var dateBadge: some View {
        VStack(spacing: -1) {
            Text(Date(), format: .dateTime.weekday(.abbreviated)).font(font(settings.dateTypography, size: 9)).textCase(.uppercase).foregroundStyle(.secondary)
            Text(Date(), format: .dateTime.day()).font(font(settings.dateTypography, size: 28)).monospacedDigit()
        }.frame(minWidth: columns <= 2 ? 34 : 42)
    }

    private func todayHeader(prominent: Bool) -> some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: 1) {
                Text("TODAY").font(font(settings.monthTypography, size: 9)).foregroundStyle(accent)
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day().locale(.autoupdatingCurrent))
                    .font(font(settings.dateTypography, size: prominent ? 16 : 12)).lineLimit(1)
            }
            Spacer()
            if family != .verticalAgenda { Text(filteredToday.isEmpty ? "Clear" : "\(filteredToday.count) event\(filteredToday.count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary) }
        }
    }

    private var dayNavigationHeader: some View {
        HStack(spacing: 8) {
            Button { changeSelectedDay(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedDate, format: .dateTime.weekday(.wide)).font(font(settings.dateTypography, size: 13))
                Text(selectedDate, format: .dateTime.month(.abbreviated).day().year()).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Today") { selectToday() }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
            Button { changeSelectedDay(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
        }
    }

    private func compactHorizontalEvent(_ event: EKEvent) -> some View {
        Button { selectedEventIdentifier = eventKey(event) } label: {
            VStack(alignment: .leading, spacing: 1) {
                if informationVisible(.startTime, level: 1) { Text(timeLabel(event)).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(eventColor(event)) }
                Text(event.title ?? "Untitled event").font(font(settings.eventTypography, size: 10)).lineLimit(1)
            }.frame(maxWidth: columns >= 6 ? 120 : 96, alignment: .leading)
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func agendaList(events: [EKEvent], limit: Int) -> some View {
        let shown = Array(events.prefix(max(0, limit)))
        VStack(spacing: densitySpacing(family == .hero ? 6 : 5)) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, event in agendaRow(event, compact: family == .miniMonth || family == .schedule) }
            let more = max(0, events.count - shown.count)
            if more > 0 { HStack { Spacer(); Text("+\(more) more").font(.caption2).foregroundStyle(.secondary) } }
        }
    }

    private func agendaRow(_ event: EKEvent, compact: Bool = false) -> some View {
        let level = metadataLevel
        return Button { selectedEventIdentifier = eventKey(event) } label: {
            HStack(alignment: .top, spacing: densitySpacing(7)) {
                if informationVisible(.calendarColor, level: level) {
                    Capsule().fill(eventColor(event)).frame(width: 3, height: compact ? 27 : 38)
                }
                if informationVisible(.startTime, level: level) {
                    Text(timeLabel(event)).font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: compact ? 38 : 48, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "Untitled event").font(font(settings.eventTypography, size: compact ? 10 : settings.eventTypography.size)).lineLimit(compact ? 1 : 2)
                    if !compact {
                        HStack(spacing: 5) {
                            if informationVisible(.endTime, level: level), !event.isAllDay { Text("to \(event.endDate.formatted(date: .omitted, time: .shortened))") }
                            if informationVisible(.duration, level: level), !event.isAllDay { Text(durationLabel(event)) }
                            if informationVisible(.location, level: level), let location = event.location, !location.isEmpty { Text(location).lineLimit(1) }
                            if informationVisible(.attendees, level: level), let count = event.attendees?.count, count > 0 { Label("\(count)", systemImage: "person.2") }
                        }.font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        if informationVisible(.notes, level: level), let notes = event.notes, !notes.isEmpty {
                            Text(notes).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 2)
                if informationVisible(.meetingLink, level: level), settings.showMeetingLink, let url = service.meetingURL(for: event) {
                    Link(destination: url) { Image(systemName: "video.fill") }.buttonStyle(.plain).foregroundStyle(accent).help("Join meeting")
                }
            }
            .padding(.horizontal, compact ? 4 : 7).padding(.vertical, compact ? 3 : 5)
            .background(eventColor(event).opacity(settings.eventOpacity), in: RoundedRectangle(cornerRadius: settings.eventCornerRadius, style: .continuous))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func allDayStrip(events: [EKEvent]) -> some View {
        if !events.isEmpty {
            HStack(spacing: 5) {
                Text("ALL DAY").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(Array(events.prefix(columns >= 5 ? 3 : 1).enumerated()), id: \.offset) { _, event in
                    Text(event.title ?? "Untitled").font(.caption2).lineLimit(1).padding(.horizontal, 6).padding(.vertical, 3)
                        .background(eventColor(event).opacity(0.14), in: Capsule())
                }
                let more = max(0, events.count - (columns >= 5 ? 3 : 1))
                if more > 0 { Text("+\(more)").font(.caption2).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
        }
    }

    private func monthGrid(showAgenda: Bool) -> some View {
        VStack(alignment: .leading, spacing: densitySpacing(5)) {
            monthHeader
            if columns >= 3 {
                LazyVGrid(columns: monthColumns, spacing: densitySpacing(2)) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased()).font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                    }
                }
            }
            LazyVGrid(columns: monthColumns, spacing: densitySpacing(2)) {
                ForEach(monthDays, id: \.self) { day in monthDayCell(day) }
            }
            if showAgenda { selectedDayAgenda }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 7) {
            Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
            Text(monthAnchor, format: .dateTime.month(.wide).year()).font(font(settings.monthTypography, size: settings.monthTypography.size)).lineLimit(1)
            Spacer()
            Button("Today") { selectToday() }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
            Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
        }
    }

    private func monthDayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let events = self.events(on: day)
        let weekend = calendar.isDateInWeekend(day)
        let cellWidth = max(16, ((availableWidth ?? CGFloat(columns * 100)) - CGFloat(6 * 3)) / 7)
        let indicator = override?.indicatorStyle ?? settings.eventIndicatorStyle
        return Button { selectedDate = calendar.startOfDay(for: day); selectedEventIdentifier = nil } label: {
            VStack(spacing: 1) {
                if settings.showWeekNumbers && calendar.component(.weekday, from: day) == calendar.firstWeekday {
                    Text("W\(calendar.component(.weekOfYear, from: day))").font(.system(size: 6, weight: .medium)).foregroundStyle(.tertiary)
                }
                Text(day, format: .dateTime.day())
                    .font(font(settings.dateTypography, size: cellWidth < 30 ? 8 : 10))
                    .foregroundStyle(dayTextColor(day: day, inMonth: inMonth, weekend: weekend, today: today))
                monthIndicators(events: events, style: indicator, cellWidth: cellWidth)
                if cellWidth >= 52, rows >= 3, let event = events.first {
                    Text(event.title ?? "Event").font(.system(size: 6.5, weight: .medium)).lineLimit(1).foregroundStyle(eventColor(event))
                }
            }
            .frame(maxWidth: .infinity, minHeight: monthCellHeight)
            .background(dayBackground(selected: selected, today: today), in: RoundedRectangle(cornerRadius: cellWidth < 30 ? 4 : 7, style: .continuous))
            .overlay { if settings.showGridLines { RoundedRectangle(cornerRadius: 6).stroke(style.textColor.color.opacity(settings.gridLineOpacity), lineWidth: 0.5) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(inMonth || settings.showAdjacentMonthDays ? 1 : 0)
        .disabled(!inMonth && !settings.showAdjacentMonthDays)
        .simultaneousGesture(TapGesture(count: 2).onEnded { openCalendarApp() })
    }

    @ViewBuilder private func monthIndicators(events: [EKEvent], style requested: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> some View {
        if !events.isEmpty {
            let effective: VisualCalendarEventIndicatorStyle = {
                if cellWidth < 24 { return .minimalMarker }
                if requested == .automatic { return cellWidth < 38 ? .dots : .bars }
                if cellWidth < 32 && requested != .minimalMarker { return .dots }
                return requested
            }()
            let shown = Array(events.prefix(settings.visibleEventIndicators))
            switch effective {
            case .automatic, .dots:
                HStack(spacing: 1.5) { ForEach(Array(shown.enumerated()), id: \.offset) { _, event in Circle().fill(eventColor(event)).frame(width: 3, height: 3) } }.frame(height: 4)
            case .bars:
                VStack(spacing: 1) { ForEach(Array(shown.prefix(2).enumerated()), id: \.offset) { _, event in Capsule().fill(eventColor(event)).frame(height: 2) } }.frame(height: 5)
            case .underline:
                Capsule().fill(eventColor(shown[0])).frame(height: 2).padding(.horizontal, 3)
            case .filledDate:
                Circle().fill(eventColor(shown[0]).opacity(0.35)).frame(width: 5, height: 5)
            case .minimalMarker:
                Circle().fill(eventColor(shown[0])).frame(width: 2.5, height: 2.5)
            }
        } else { Color.clear.frame(height: 4) }
    }

    private var selectedDayAgenda: some View {
        VStack(alignment: .leading, spacing: densitySpacing(6)) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(selectedDate, format: .dateTime.weekday(.wide)).font(font(settings.dateTypography, size: 12))
                    Text(selectedDate, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(eventsForSelectedDate.isEmpty ? "Clear" : "\(eventsForSelectedDate.count) event\(eventsForSelectedDate.count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary)
            }
            let allDay = eventsForSelectedDate.filter(\.isAllDay)
            if !allDay.isEmpty { allDayStrip(events: allDay) }
            let timed = eventsForSelectedDate.filter { !$0.isAllDay }
            if timed.isEmpty && allDay.isEmpty { subtleEmptyState }
            else { agendaList(events: timed, limit: visibleEventLimit) }
        }
    }

    private var subtleEmptyState: some View {
        HStack(spacing: 6) { Image(systemName: "sparkles").foregroundStyle(accent); Text("Nothing scheduled").foregroundStyle(.secondary); Spacer() }
            .font(.caption).padding(.vertical, 4)
    }

    private func timelineHourRow(_ hour: Int) -> some View {
        let events = eventsForSelectedDate.filter { !$0.isAllDay && calendar.component(.hour, from: $0.startDate) == hour }
        let isCurrentHour = calendar.isDateInToday(selectedDate) && calendar.component(.hour, from: Date()) == hour
        return HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour)).font(.system(size: 9, design: .monospaced)).foregroundStyle(isCurrentHour ? accent : .secondary).frame(width: 38, alignment: .trailing)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(isCurrentHour ? accent.opacity(0.5) : style.textColor.color.opacity(0.08)).frame(width: isCurrentHour ? 2 : 1)
                if events.isEmpty { Color.clear.frame(height: timelineRowHeight) }
                else {
                    HStack(spacing: 4) {
                        ForEach(Array(events.prefix(columns >= 5 ? 2 : 1).enumerated()), id: \.offset) { _, event in
                            Button { selectedEventIdentifier = eventKey(event) } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.title ?? "Untitled").font(.system(size: 9, weight: .semibold)).lineLimit(1)
                                    if rows >= 3 { Text(durationLabel(event)).font(.system(size: 7)).foregroundStyle(.secondary) }
                                }.padding(4).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(eventColor(event).opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }
                        if events.count > (columns >= 5 ? 2 : 1) { Text("+\(events.count - (columns >= 5 ? 2 : 1))").font(.caption2).foregroundStyle(.secondary) }
                    }.padding(.leading, 7)
                }
            }.frame(maxWidth: .infinity, minHeight: timelineRowHeight, alignment: .topLeading)
        }
    }

    private func weekColumn(_ day: Date) -> some View {
        let events = events(on: day)
        let today = calendar.isDateInToday(day)
        return Button { selectedDate = day; monthAnchor = day } label: {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(day, format: .dateTime.weekday(.abbreviated)).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day()).font(font(settings.dateTypography, size: 15)).foregroundStyle(today ? accent : primary)
                }
                ForEach(Array(events.prefix(rows >= 4 ? 3 : 2).enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 3) {
                        Circle().fill(eventColor(event)).frame(width: 3, height: 3)
                        Text(event.isAllDay ? (event.title ?? "Event") : "\(timeLabel(event)) \(event.title ?? "Event")").font(.system(size: 7.5, weight: .medium)).lineLimit(1)
                    }
                }
                if events.count > (rows >= 4 ? 3 : 2) { Text("+\(events.count - (rows >= 4 ? 3 : 2))").font(.system(size: 7)).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
            .padding(5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(today ? accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    private func eventDetail(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(event.title ?? "Untitled event").font(font(settings.eventTypography, size: 13)).lineLimit(2)
            Text(event.isAllDay ? "All day" : "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            Text(event.calendar.title).font(.caption2).foregroundStyle(eventColor(event))
            if let location = event.location, !location.isEmpty {
                Button { openLocation(location) } label: { Label(location, systemImage: "mappin.and.ellipse").lineLimit(1) }.buttonStyle(.plain).font(.caption)
            }
            if let notes = event.notes, !notes.isEmpty { Text(notes).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            if let url = service.meetingURL(for: event) { Link(destination: url) { Label("Join Meeting", systemImage: "video.fill") }.font(.caption).foregroundStyle(accent) }
        }
    }

    private var metadataLevel: Int {
        switch family {
        case .micro: return 0
        case .compactAgenda: return 1
        case .horizontalAgenda, .verticalAgenda, .miniMonth: return 2
        case .day, .schedule: return 4
        case .month: return 5
        case .split: return 6
        case .hero: return 8
        }
    }

    private func informationVisible(_ information: VisualCalendarInformation, level: Int) -> Bool {
        guard settings.enabledInformation.contains(information) else { return false }
        let index = settings.resolvedInformationPriority.firstIndex(of: information) ?? Int.max
        guard index < level else { return false }
        switch information {
        case .endTime: return settings.showEventEndTime
        case .duration: return settings.showEventDuration
        case .location: return settings.showEventLocation
        case .meetingLink: return settings.showMeetingLink
        case .notes: return settings.showNotesPreview
        case .attendees: return settings.showAttendees
        default: return true
        }
    }

    private var monthColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: densitySpacing(2)), count: 7) }
    private var monthCellHeight: CGFloat {
        let base: CGFloat = rows >= 4 ? 30 : rows >= 3 ? 25 : 21
        switch settings.density { case .compact: return base * 0.85; case .spacious: return base * 1.14; default: return base }
    }
    private var timelineRowHeight: CGFloat { rows >= 4 ? 28 : rows >= 3 ? 23 : 19 }
    private var timelineHours: [Int] {
        let timed = eventsForSelectedDate.filter { !$0.isAllDay }
        let minHour = timed.map { calendar.component(.hour, from: $0.startDate) }.min() ?? 8
        let maxHour = timed.map { calendar.component(.hour, from: $0.endDate) }.max() ?? 18
        let start = max(0, min(8, minHour))
        let end = min(23, max(18, maxHour))
        return Array(start...end)
    }
    private var visibleWeekDays: Int { columns >= 7 ? 7 : columns >= 5 ? 5 : columns >= 4 ? 3 : 1 }
    private var visibleWeekDates: [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let count = visibleWeekDays
        let selectedWeekday = calendar.component(.weekday, from: selectedDate)
        let offset: Int
        if count == 7 { offset = 0 }
        else { offset = max(0, min(7 - count, selectedWeekday - calendar.firstWeekday)) }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: offset + $0, to: weekStart) }
    }
    private var weekTitle: String {
        guard let first = visibleWeekDates.first, let last = visibleWeekDates.last else { return "Week" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
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

    private func events(on day: Date) -> [EKEvent] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return filteredMonth.filter { $0.startDate < end && $0.endDate > start }.sorted { $0.startDate < $1.startDate }
    }
    private func matchesFilter(_ event: EKEvent) -> Bool {
        let title = event.calendar.title.lowercased()
        switch settings.filterMode {
        case .all: return true
        case .work: return ["work", "office", "job", "business"].contains { title.contains($0) }
        case .personal: return ["personal", "home", "family", "private"].contains { title.contains($0) }
        case .birthdays: return event.calendar.type == .birthday || title.contains("birthday")
        case .custom:
            let wanted = Set(settings.customCalendarNames.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
            return wanted.isEmpty || wanted.contains(title)
        }
    }
    private func loadMonth() { monthEvents = service.events(around: monthAnchor) }
    private func changeMonth(_ amount: Int) {
        monthAnchor = calendar.date(byAdding: .month, value: amount, to: monthAnchor) ?? monthAnchor
        selectedDate = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
        selectedEventIdentifier = nil
    }
    private func changeSelectedDay(_ amount: Int) {
        selectedDate = calendar.date(byAdding: .day, value: amount, to: selectedDate) ?? selectedDate
        monthAnchor = selectedDate
        selectedEventIdentifier = nil
    }
    private func selectToday() {
        selectedDate = calendar.startOfDay(for: Date())
        monthAnchor = selectedDate
        selectedEventIdentifier = nil
    }
    private func eventKey(_ event: EKEvent) -> String { event.eventIdentifier ?? "\(event.startDate.timeIntervalSinceReferenceDate)|\(event.title ?? "")" }
    private func timeLabel(_ event: EKEvent) -> String { event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened) }
    private func durationLabel(_ event: EKEvent) -> String {
        let minutes = max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        return minutes >= 60 ? "\(minutes / 60)h\(minutes % 60 == 0 ? "" : " \(minutes % 60)m")" : "\(minutes)m"
    }
    private func densitySpacing(_ base: CGFloat) -> CGFloat {
        switch settings.density { case .compact: return base * 0.72; case .spacious: return base * 1.28; default: return base }
    }

    private var primary: Color { style.textColor.color }
    private var accent: Color { style.accentColor.color }
    private func eventColor(_ event: EKEvent) -> Color {
        if !settings.useNativeCalendarColors, let override = settings.eventColorOverride { return override.color }
        if settings.useNativeCalendarColors, let cgColor = event.calendar.cgColor, let native = NSColor(cgColor: cgColor) { return Color(nsColor: native) }
        return settings.eventColorOverride?.color ?? accent
    }
    private func dayTextColor(day: Date, inMonth: Bool, weekend: Bool, today: Bool) -> Color {
        if today && settings.highlightToday && settings.todayStyle == .accentText { return settings.todayColor?.color ?? accent }
        if !inMonth { return primary.opacity(settings.showAdjacentMonthDays ? 0.27 : 0) }
        if weekend {
            switch settings.weekendStyle { case .muted: return primary.opacity(0.45); case .accent: return accent.opacity(0.9); case .subtle: return primary.opacity(0.72); case .normal: break }
        }
        return primary
    }
    private func dayBackground(selected: Bool, today: Bool) -> Color {
        if selected && settings.highlightSelectedDay { return (settings.selectedDayColor?.color ?? accent).opacity(0.24) }
        guard today && settings.highlightToday else { return .clear }
        let color = settings.todayColor?.color ?? accent
        switch settings.todayStyle {
        case .circle, .pill, .filledNumber: return color.opacity(0.20)
        case .outline, .accentText, .minimalDot: return .clear
        case .subtleGlow: return color.opacity(0.11)
        }
    }
    private func font(_ typography: VisualCalendarTypography, size: Double) -> Font {
        let weight = typography.weight.swiftUIFontWeight
        let actual = max(7, size)
        if typography.fontFamily == .custom { return .custom(typography.customFont, size: actual).weight(weight) }
        let design: Font.Design
        switch typography.fontFamily { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: actual, weight: weight, design: design)
    }
    private func openCalendarApp() { _ = NSWorkspace.shared.launchApplication("Calendar") }
    private func openLocation(_ location: String) {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: location)]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }
}

'''
module = module.replace(calendar_insert_anchor, new_calendar_view + calendar_insert_anchor, 1)
Path(module_path).write_text(module)

# 3) Visual Workspace Calendar inspector only. Leave the normal opened-dashboard Calendar controls above untouched.
settings_path = "Halo/Views/WidgetSettingsView.swift"
settings = Path(settings_path).read_text()
old_calendar_inspector = '''        if module == .calendar {
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
'''
new_calendar_inspector = '''        if module == .calendar {
            visualCalendarSettings(style: style)
            visualCalendarSizeOverrideInspector(itemID: itemID, style: style)
        }
'''
if old_calendar_inspector not in settings:
    raise SystemExit("Visual Workspace Calendar inspector block not found")
settings = settings.replace(old_calendar_inspector, new_calendar_inspector, 1)
helper_anchor = '''    @ViewBuilder private func groupInspector(_ group: OpenNotchGroup) -> some View {
'''
if helper_anchor not in settings:
    raise SystemExit("groupInspector anchor not found")
calendar_helpers = r'''
    @ViewBuilder private func visualCalendarSettings(style: Binding<WidgetStyle>) -> some View {
        let calendar = style.visualCalendar.withDefault(VisualCalendarOptions())
        Section("Calendar View") {
            Picker("Preferred view", selection: calendar.preferredView) {
                ForEach(VisualCalendarViewStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            Text("Automatic chooses a deliberately different Calendar composition for the current footprint. Narrow rows become agenda strips, tall columns become day agendas, and larger blocks become month, timeline, week or split views.")
                .font(.caption).foregroundStyle(.secondary)
            PreciseSlider(title: "Maximum events", value: Binding(get: { Double(calendar.wrappedValue.maxEvents) }, set: { calendar.wrappedValue.maxEvents = Int($0) }), range: 1...30, step: 1)
            Picker("Density", selection: calendar.density) { ForEach(VisualCalendarDensity.allCases) { Text($0.rawValue).tag($0) } }
        }
        Section("Month View") {
            Picker("Week starts", selection: calendar.weekStart) { ForEach(VisualCalendarWeekStart.allCases) { Text($0.rawValue).tag($0) } }
            Toggle("Week numbers", isOn: calendar.showWeekNumbers)
            Toggle("Adjacent-month days", isOn: calendar.showAdjacentMonthDays)
            Toggle("Highlight today", isOn: calendar.highlightToday)
            Toggle("Highlight selected day", isOn: calendar.highlightSelectedDay)
            Picker("Event indicators", selection: calendar.eventIndicatorStyle) { ForEach(VisualCalendarEventIndicatorStyle.allCases) { Text($0.rawValue).tag($0) } }
            Stepper("Visible indicators: \(calendar.wrappedValue.visibleEventIndicators)", value: calendar.visibleEventIndicators, in: 1...6)
            Picker("Today treatment", selection: calendar.todayStyle) { ForEach(VisualCalendarTodayStyle.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Weekend treatment", selection: calendar.weekendStyle) { ForEach(VisualCalendarWeekendStyle.allCases) { Text($0.rawValue).tag($0) } }
            Toggle("Grid lines", isOn: calendar.showGridLines)
            if calendar.wrappedValue.showGridLines { PreciseSlider(title: "Grid line opacity", value: calendar.gridLineOpacity, range: 0...0.5, step: 0.01, decimals: 2) }
        }
        Section("Agenda Information Priority") {
            Text("Date and event title are always preserved. Lower-priority metadata disappears first as the widget becomes constrained.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(calendar.wrappedValue.resolvedInformationPriority) { information in
                HStack(spacing: 8) {
                    Toggle(information.title, isOn: calendarInformationEnabled(calendar, information))
                    Spacer(minLength: 4)
                    Button { moveCalendarInformation(calendar, information, -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.borderless).disabled(calendar.wrappedValue.resolvedInformationPriority.first == information)
                    Button { moveCalendarInformation(calendar, information, 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.borderless).disabled(calendar.wrappedValue.resolvedInformationPriority.last == information)
                }
            }
        }
        Section("Calendar Filtering") {
            Picker("Show", selection: calendar.filterMode) { ForEach(VisualCalendarFilterMode.allCases) { Text($0.rawValue).tag($0) } }
            if calendar.wrappedValue.filterMode == .custom {
                TextField("Calendar names (comma separated)", text: visualCalendarNamesBinding(calendar))
                Text("Names are matched against the macOS Calendar names attached to EventKit events.").font(.caption2).foregroundStyle(.secondary)
            } else if calendar.wrappedValue.filterMode == .work || calendar.wrappedValue.filterMode == .personal {
                Text("Work and Personal intelligently match common calendar names. Use Custom Selection when your calendars use different names.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Toggle("Use native calendar colors", isOn: calendar.useNativeCalendarColors)
            if !calendar.wrappedValue.useNativeCalendarColors {
                ColorPicker("Event color", selection: Binding(get: { (calendar.wrappedValue.eventColorOverride ?? style.wrappedValue.accentColor).color }, set: { calendar.wrappedValue.eventColorOverride = WidgetColor($0) }), supportsOpacity: false)
            }
        }
        Section("Calendar Appearance") {
            ColorPicker("Today", selection: Binding(get: { (calendar.wrappedValue.todayColor ?? style.wrappedValue.accentColor).color }, set: { calendar.wrappedValue.todayColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Selected day", selection: Binding(get: { (calendar.wrappedValue.selectedDayColor ?? style.wrappedValue.accentColor).color }, set: { calendar.wrappedValue.selectedDayColor = WidgetColor($0) }), supportsOpacity: false)
            PreciseSlider(title: "Event corner radius", value: calendar.eventCornerRadius, range: 0...24, step: 1, suffix: "pt")
            PreciseSlider(title: "Event fill opacity", value: calendar.eventOpacity, range: 0...0.45, step: 0.01, decimals: 2)
            PreciseSlider(title: "Calendar background", value: calendar.backgroundOpacity, range: 0...0.6, step: 0.01, decimals: 2)
        }
        Section("Calendar Typography") {
            visualCalendarTypographyEditor("Date", calendar.dateTypography)
            visualCalendarTypographyEditor("Events", calendar.eventTypography)
            visualCalendarTypographyEditor("Month title", calendar.monthTypography)
        }
    }

    @ViewBuilder private func visualCalendarTypographyEditor(_ title: String, _ typography: Binding<VisualCalendarTypography>) -> some View {
        DisclosureGroup(title) {
            Picker("Font", selection: typography.fontFamily) { ForEach(WidgetFontFamily.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            if typography.wrappedValue.fontFamily == .custom { TextField("Installed font", text: typography.customFont) }
            Picker("Weight", selection: typography.weight) { ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            PreciseSlider(title: "Size", value: typography.size, range: 8...48, step: 1, suffix: "pt")
        }
    }

    private func calendarInformationEnabled(_ calendar: Binding<VisualCalendarOptions>, _ information: VisualCalendarInformation) -> Binding<Bool> {
        Binding(get: { calendar.wrappedValue.enabledInformation.contains(information) }, set: { enabled in
            var values = calendar.wrappedValue.enabledInformation
            if enabled { if !values.contains(information) { values.append(information) } }
            else { values.removeAll { $0 == information } }
            calendar.wrappedValue.enabledInformation = values
        })
    }

    private func moveCalendarInformation(_ calendar: Binding<VisualCalendarOptions>, _ information: VisualCalendarInformation, _ direction: Int) {
        var values = calendar.wrappedValue.resolvedInformationPriority
        guard let index = values.firstIndex(of: information) else { return }
        let target = index + direction
        guard values.indices.contains(target) else { return }
        values.swapAt(index, target)
        calendar.wrappedValue.informationPriority = values
    }

    private func visualCalendarNamesBinding(_ calendar: Binding<VisualCalendarOptions>) -> Binding<String> {
        Binding(get: { calendar.wrappedValue.customCalendarNames.joined(separator: ", ") }, set: { text in
            calendar.wrappedValue.customCalendarNames = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        })
    }

    @ViewBuilder private func visualCalendarSizeOverrideInspector(itemID: UUID, style: Binding<WidgetStyle>) -> some View {
        let placement = findItem(itemID)?.gridPlacement ?? OpenNotchGridPlacement()
        let columns = min(8, max(1, placement.columnSpan))
        let rows = min(4, max(1, placement.rowSpan))
        let key = VisualCalendarOptions.sizeKey(columns: columns, rows: rows)
        let override = Binding<VisualCalendarSizeOverride?>(get: {
            style.wrappedValue.visualCalendar?.sizeOverrides[key]
        }, set: { replacement in
            var options = style.wrappedValue.resolvedVisualCalendar
            if let replacement { options.sizeOverrides[key] = replacement } else { options.sizeOverrides.removeValue(forKey: key) }
            style.wrappedValue.visualCalendar = options
        })
        Section("\(columns)×\(rows) Calendar Override") {
            Toggle("Override Automatic", isOn: Binding(get: { override.wrappedValue != nil }, set: { enabled in
                if enabled {
                    override.wrappedValue = VisualCalendarSizeOverride(view: style.wrappedValue.resolvedVisualCalendar.preferredView,
                                                                      maxEvents: style.wrappedValue.resolvedVisualCalendar.maxEvents,
                                                                      indicatorStyle: style.wrappedValue.resolvedVisualCalendar.eventIndicatorStyle)
                } else { override.wrappedValue = nil }
            }))
            if override.wrappedValue != nil {
                let value = override.withDefault(VisualCalendarSizeOverride())
                Picker("View", selection: value.view.withDefault(.automatic)) { ForEach(VisualCalendarViewStyle.allCases) { Text($0.rawValue).tag($0) } }
                PreciseSlider(title: "Events shown", value: Binding(get: { Double(value.wrappedValue.maxEvents ?? style.wrappedValue.resolvedVisualCalendar.maxEvents) }, set: { value.wrappedValue.maxEvents = Int($0) }), range: 1...30, step: 1)
                Picker("Month indicators", selection: value.indicatorStyle.withDefault(style.wrappedValue.resolvedVisualCalendar.eventIndicatorStyle)) { ForEach(VisualCalendarEventIndicatorStyle.allCases) { Text($0.rawValue).tag($0) } }
                Button("Reset \(columns)×\(rows) to Automatic") { override.wrappedValue = nil }
            } else {
                Text("Automatic uses the exact grid footprint, actual point dimensions, event density and Calendar preferences. Override only when this exact size needs a different emphasis.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

'''
settings = settings.replace(helper_anchor, calendar_helpers + helper_anchor, 1)
Path(settings_path).write_text(settings)

print("Visual Workspace Calendar Showcase patch applied")
