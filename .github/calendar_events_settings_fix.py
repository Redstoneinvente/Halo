from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Expected block not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1))

# -----------------------------------------------------------------------------
# 1. Calendar model: real source selection + Holidays/Festivals filtering.
# -----------------------------------------------------------------------------
path = Path("Halo/Core/WidgetModels.swift")
text = path.read_text()
text = text.replace('''enum VisualCalendarFilterMode: String, Codable, CaseIterable, Identifiable {
    case all = "All Calendars"
    case work = "Work"
    case personal = "Personal"
    case birthdays = "Birthdays"
    case custom = "Custom Selection"
    var id: String { rawValue }
}
''', '''enum VisualCalendarFilterMode: String, Codable, CaseIterable, Identifiable {
    case all = "All Calendars"
    case selected = "Selected Calendars"
    case work = "Work"
    case personal = "Personal"
    case birthdays = "Birthdays"
    case holidaysFestivals = "Holidays & Festivals"
    case custom = "Calendar Names"
    var id: String { rawValue }
}
''', 1)
text = text.replace('''    var filterMode: VisualCalendarFilterMode = .all
    var customCalendarNames: [String] = []
    var useNativeCalendarColors = true
''', '''    var filterMode: VisualCalendarFilterMode = .all
    var customCalendarNames: [String] = []
    var selectedCalendarIdentifiers: [String] = []
    var useNativeCalendarColors = true
''', 1)
text = text.replace('''        value.customCalendarNames = customCalendarNames.map { String($0.prefix(120)) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        value.eventColorOverride = try eventColorOverride?.validated()
''', '''        value.customCalendarNames = customCalendarNames.map { String($0.prefix(120)) }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        value.selectedCalendarIdentifiers = Array(Set(selectedCalendarIdentifiers.map { String($0.prefix(240)) }.filter { !$0.isEmpty })).sorted()
        value.eventColorOverride = try eventColorOverride?.validated()
''', 1)
path.write_text(text)

# -----------------------------------------------------------------------------
# 2. Calendar service: expose access state, full-day events, longer visual
#    horizon, explicit EventKit calendar discovery, and a revision signal.
#    Legacy opened-notch arrays keep their existing semantics.
# -----------------------------------------------------------------------------
path = Path("Halo/Services/Integrations.swift")
text = path.read_text()
start = text.index("@MainActor\nfinal class CalendarService: ObservableObject {")
end = text.index("\n\nstruct ClipboardEntry:", start)
new_service = r'''@MainActor
final class CalendarService: ObservableObject {
    @Published var events: [EKEvent] = []
    @Published var upcomingEvents: [EKEvent] = []
    @Published var visualDayEvents: [EKEvent] = []
    @Published var visualUpcomingEvents: [EKEvent] = []
    @Published var calendarRevision = 0
    @Published var status = "Calendar access is off. Enable it to show today's schedule."
    private let store = EKEventStore()
    private var observer: AnyCancellable?

    var hasAccess: Bool { isAuthorized }

    init() {
        observer = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.refresh() }
    }

    func requestAccess() {
        if isAuthorized {
            refresh()
            return
        }
        let completion: (Bool, Error?) -> Void = { [weak self] allowed, error in
            Task { @MainActor in
                self?.status = allowed ? "Calendar connected" : (error?.localizedDescription ?? "Access denied. Change it in System Settings → Privacy & Security → Calendars.")
                self?.refresh()
            }
        }
        if #available(macOS 14.0, *) { store.requestFullAccessToEvents(completion: completion) }
        else { store.requestAccess(to: .event, completion: completion) }
    }

    func refresh() {
        guard isAuthorized else {
            events = []
            upcomingEvents = []
            visualDayEvents = []
            visualUpcomingEvents = []
            status = "Calendar access is off. Enable it to show events."
            calendarRevision &+= 1
            return
        }

        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
        let legacyHorizon = calendar.date(byAdding: .day, value: 14, to: today) ?? now.addingTimeInterval(14 * 86_400)
        let visualHorizon = calendar.date(byAdding: .day, value: 90, to: today) ?? now.addingTimeInterval(90 * 86_400)
        let calendars = store.calendars(for: .event)
        let predicate = store.predicateForEvents(withStart: today, end: visualHorizon, calendars: calendars.isEmpty ? nil : calendars)
        let raw = store.events(matching: predicate).sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate { return (lhs.title ?? "") < (rhs.title ?? "") }
            return lhs.startDate < rhs.startDate
        }

        // Visual Workspace keeps all events for the current day, including events
        // that already ended. This matters for all-day holidays/observances and for
        // a calendar that is opened late in the day.
        visualDayEvents = raw.filter { $0.startDate < tomorrow && $0.endDate > today }
        visualUpcomingEvents = raw.filter { $0.endDate > now }

        // Preserve the regular opened-notch Calendar's existing "remaining today"
        // and 14-day upcoming semantics.
        events = visualDayEvents.filter { $0.endDate > now }
        upcomingEvents = visualUpcomingEvents.filter { $0.startDate < legacyHorizon }

        let sourceCount = calendars.count
        if visualDayEvents.isEmpty {
            status = sourceCount == 0 ? "No Calendar sources are available" : "No events today · \(sourceCount) calendar\(sourceCount == 1 ? "" : "s") connected"
        } else {
            status = "\(visualDayEvents.count) event\(visualDayEvents.count == 1 ? "" : "s") today · \(sourceCount) calendar\(sourceCount == 1 ? "" : "s") connected"
        }
        calendarRevision &+= 1
    }

    func events(around anchor: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.autoupdatingCurrent
        let monthStart = calendar.dateInterval(of: .month, for: anchor)?.start ?? calendar.startOfDay(for: anchor)
        let gridStart = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        let gridEnd = calendar.date(byAdding: .day, value: 42, to: gridStart) ?? gridStart.addingTimeInterval(42 * 86_400)
        let calendars = store.calendars(for: .event)
        return store.events(matching: store.predicateForEvents(withStart: gridStart, end: gridEnd, calendars: calendars.isEmpty ? nil : calendars))
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate { return (lhs.title ?? "") < (rhs.title ?? "") }
                return lhs.startDate < rhs.startDate
            }
    }

    private var isAuthorized: Bool {
        let authorization = EKEventStore.authorizationStatus(for: .event)
        if authorization == .authorized { return true }
        if #available(macOS 14.0, *) { return authorization == .fullAccess }
        return false
    }

    func meetingURL(for event: EKEvent) -> URL? {
        let candidates = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.matches(in: candidates, range: NSRange(candidates.startIndex..., in: candidates)).compactMap(\.url).first {
            guard $0.scheme == "https", let host = $0.host?.lowercased() else { return false }
            return ["zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }
}'''
text = text[:start] + new_service + text[end:]
path.write_text(text)

# -----------------------------------------------------------------------------
# 3. Visual Workspace Calendar renderer: permission state, source-aware filters,
#    real Today treatments, real Filled Date indicators, and typography sliders
#    that actually scale every footprint.
# -----------------------------------------------------------------------------
path = Path("Halo/Views/ModuleViews.swift")
text = path.read_text()
text = text.replace('''    private var filteredUpcoming: [EKEvent] { service.upcomingEvents.filter(matchesFilter) }
    private var filteredToday: [EKEvent] { service.events.filter(matchesFilter) }
''', '''    private var filteredUpcoming: [EKEvent] { service.visualUpcomingEvents.filter(matchesFilter) }
    private var filteredToday: [EKEvent] { service.visualDayEvents.filter(matchesFilter) }
''', 1)

old_body = '''    var body: some View {
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
'''
new_body = '''    var body: some View {
        Group {
            if service.hasAccess {
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
            } else {
                calendarAccessState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(style.backgroundColor.color.opacity(settings.backgroundOpacity))
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: family)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
        .animation(.easeInOut(duration: 0.2), value: selectedEventIdentifier)
        .onAppear { service.refresh(); loadMonth() }
        .onChange(of: monthAnchor) { _ in loadMonth() }
        .onChange(of: service.calendarRevision) { _ in loadMonth() }
    }

    private var calendarAccessState: some View {
        Button { service.requestAccess() } label: {
            VStack(spacing: family == .micro ? 3 : 7) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: family == .micro ? 18 : 26, weight: .medium))
                    .foregroundStyle(accent)
                if family != .micro {
                    Text("Calendar Access")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text("Allow Halo to read your calendars, including subscribed holiday and observance calendars.")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(3)
                    Text("Enable Calendar")
                        .font(.caption).foregroundStyle(accent)
                }
            }
            .padding(family == .micro ? 2 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .help(service.status)
    }
'''
if old_body not in text:
    raise SystemExit("Visual Calendar body block not found")
text = text.replace(old_body, new_body, 1)

# Today tile: use the actual selected Today treatment instead of one fixed number.
text = text.replace('''                Text(Date(), format: .dateTime.day())
                    .font(font(settings.dateTypography, size: 36)).monospacedDigit().foregroundStyle(primary)
''', '''                todayHeroNumber
''', 1)

# Month cell: route the date number through its adaptive decoration helper.
text = text.replace('''                Text(day, format: .dateTime.day())
                    .font(font(settings.dateTypography, size: cellWidth < 30 ? 8 : 10))
                    .foregroundStyle(dayTextColor(day: day, inMonth: inMonth, weekend: weekend, today: today))
                monthIndicators(events: events, style: indicator, cellWidth: cellWidth)
''', '''                calendarDayNumber(day, inMonth: inMonth, weekend: weekend, today: today, events: events, requestedIndicator: indicator, cellWidth: cellWidth)
                monthIndicators(events: events, style: indicator, cellWidth: cellWidth)
''', 1)

# Centralize the indicator simplification so Filled Date can decorate the date
# itself rather than rendering a misleading tiny marker.
old_indicators = '''    @ViewBuilder private func monthIndicators(events: [EKEvent], style requested: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> some View {
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
'''
new_indicators = '''    @ViewBuilder private func monthIndicators(events: [EKEvent], style requested: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> some View {
        if !events.isEmpty {
            let effective = resolvedIndicatorStyle(requested, cellWidth: cellWidth)
            let shown = Array(events.prefix(settings.visibleEventIndicators))
            switch effective {
            case .automatic, .dots:
                HStack(spacing: 1.5) { ForEach(Array(shown.enumerated()), id: \.offset) { _, event in Circle().fill(eventColor(event)).frame(width: 3, height: 3) } }.frame(height: 4)
            case .bars:
                VStack(spacing: 1) { ForEach(Array(shown.prefix(2).enumerated()), id: \.offset) { _, event in Capsule().fill(eventColor(event)).frame(height: 2) } }.frame(height: 5)
            case .underline:
                Capsule().fill(eventColor(shown[0])).frame(height: 2).padding(.horizontal, 3)
            case .filledDate:
                Color.clear.frame(height: 4)
            case .minimalMarker:
                Circle().fill(eventColor(shown[0])).frame(width: 2.5, height: 2.5)
            }
        } else { Color.clear.frame(height: 4) }
    }

    private func resolvedIndicatorStyle(_ requested: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> VisualCalendarEventIndicatorStyle {
        if cellWidth < 24 { return .minimalMarker }
        if requested == .automatic { return cellWidth < 38 ? .dots : .bars }
        if cellWidth < 32 && requested != .minimalMarker && requested != .filledDate { return .dots }
        return requested
    }
'''
if old_indicators not in text:
    raise SystemExit("monthIndicators block not found")
text = text.replace(old_indicators, new_indicators, 1)

# Filtering: identifiers are reliable; holiday/festival mode understands
# subscribed all-day calendars and common observance names.
old_filter = '''    private func matchesFilter(_ event: EKEvent) -> Bool {
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
'''
new_filter = '''    private func matchesFilter(_ event: EKEvent) -> Bool {
        let calendarTitle = event.calendar.title.lowercased()
        switch settings.filterMode {
        case .all:
            return true
        case .selected:
            return Set(settings.selectedCalendarIdentifiers).contains(event.calendar.calendarIdentifier)
        case .work:
            return ["work", "office", "job", "business", "company", "team"].contains { calendarTitle.contains($0) }
        case .personal:
            return ["personal", "home", "family", "private", "icloud"].contains { calendarTitle.contains($0) }
        case .birthdays:
            return event.calendar.type == .birthday || calendarTitle.contains("birthday") || (event.title ?? "").localizedCaseInsensitiveContains("birthday")
        case .holidaysFestivals:
            return isHolidayOrFestival(event)
        case .custom:
            let wanted = Set(settings.customCalendarNames.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
            return wanted.isEmpty || wanted.contains(calendarTitle)
        }
    }

    private func isHolidayOrFestival(_ event: EKEvent) -> Bool {
        let haystack = "\(event.calendar.title) \(event.title ?? "")".lowercased()
        let keywords = [
            "holiday", "holidays", "observance", "festival", "festivals", "public holiday", "bank holiday",
            "new year", "christmas", "easter", "eid", "diwali", "divali", "holi", "vesak", "ramadan",
            "maha shivaratree", "shivaratri", "cavadee", "ugadi", "ganesh chaturthi", "all saints", "spring festival"
        ]
        if keywords.contains(where: { haystack.contains($0) }) { return true }
        // macOS exposes many regional holiday calendars as read-only subscriptions.
        // Restrict the fallback to all-day entries to avoid classifying ordinary
        // subscribed schedules (sports, releases, etc.) as holidays.
        return event.calendar.type == .subscription && event.isAllDay
    }
'''
if old_filter not in text:
    raise SystemExit("matchesFilter block not found")
text = text.replace(old_filter, new_filter, 1)

# Today decorations and month date decorations.
insert_before = '''    private var primary: Color { style.textColor.color }
'''
helpers = r'''    @ViewBuilder private var todayHeroNumber: some View {
        let color = settings.todayColor?.color ?? accent
        let number = Text(Date(), format: .dateTime.day()).font(dateFont(36)).monospacedDigit()
        if !settings.highlightToday {
            number.foregroundStyle(primary)
        } else {
            switch settings.todayStyle {
            case .circle:
                number.foregroundStyle(primary).padding(5).background(color.opacity(0.20), in: Circle())
            case .pill:
                number.foregroundStyle(primary).padding(.horizontal, 9).padding(.vertical, 3).background(color.opacity(0.20), in: Capsule())
            case .filledNumber:
                number.foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3).background(color.opacity(0.88), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            case .outline:
                number.foregroundStyle(primary).padding(5).overlay(Circle().stroke(color.opacity(0.9), lineWidth: 1.25))
            case .accentText:
                number.foregroundStyle(color)
            case .subtleGlow:
                number.foregroundStyle(primary).shadow(color: color.opacity(0.65), radius: 5)
            case .minimalDot:
                VStack(spacing: 1) { number.foregroundStyle(primary); Circle().fill(color).frame(width: 4, height: 4) }
            }
        }
    }

    @ViewBuilder private func calendarDayNumber(_ day: Date, inMonth: Bool, weekend: Bool, today: Bool, events: [EKEvent], requestedIndicator: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> some View {
        let normalColor = dayTextColor(day: day, inMonth: inMonth, weekend: weekend, today: today)
        let number = Text(day, format: .dateTime.day()).font(dateFont(cellWidth < 30 ? 8 : 10)).foregroundStyle(normalColor)
        let indicator = resolvedIndicatorStyle(requestedIndicator, cellWidth: cellWidth)
        if indicator == .filledDate, let event = events.first {
            number.padding(.horizontal, 3).padding(.vertical, 2)
                .background(eventColor(event).opacity(0.30), in: Circle())
        } else if today && settings.highlightToday {
            let color = settings.todayColor?.color ?? accent
            switch settings.todayStyle {
            case .circle:
                number.padding(3).background(color.opacity(0.20), in: Circle())
            case .pill:
                number.padding(.horizontal, 5).padding(.vertical, 2).background(color.opacity(0.20), in: Capsule())
            case .filledNumber:
                number.foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 2).background(color.opacity(0.86), in: Circle())
            case .outline:
                number.padding(3).overlay(Circle().stroke(color.opacity(0.9), lineWidth: 1))
            case .accentText:
                number.foregroundStyle(color)
            case .subtleGlow:
                number.shadow(color: color.opacity(0.65), radius: 3)
            case .minimalDot:
                VStack(spacing: 0) { number; Circle().fill(color).frame(width: 2.5, height: 2.5) }
            }
        } else {
            number
        }
    }

'''
if insert_before not in text:
    raise SystemExit("primary color anchor not found")
text = text.replace(insert_before, helpers + insert_before, 1)

# Selected day remains the cell background. Today styling is now handled by the
# date itself, except a very subtle glow treatment.
old_day_background = '''    private func dayBackground(selected: Bool, today: Bool) -> Color {
        if selected && settings.highlightSelectedDay { return (settings.selectedDayColor?.color ?? accent).opacity(0.24) }
        guard today && settings.highlightToday else { return .clear }
        let color = settings.todayColor?.color ?? accent
        switch settings.todayStyle {
        case .circle, .pill, .filledNumber: return color.opacity(0.20)
        case .outline, .accentText, .minimalDot: return .clear
        case .subtleGlow: return color.opacity(0.11)
        }
    }
'''
new_day_background = '''    private func dayBackground(selected: Bool, today: Bool) -> Color {
        if selected && settings.highlightSelectedDay { return (settings.selectedDayColor?.color ?? accent).opacity(0.24) }
        if today && settings.highlightToday && settings.todayStyle == .subtleGlow {
            return (settings.todayColor?.color ?? accent).opacity(0.045)
        }
        return .clear
    }
'''
if old_day_background not in text:
    raise SystemExit("dayBackground block not found")
text = text.replace(old_day_background, new_day_background, 1)

# Typography repair only inside the Visual Workspace Calendar implementation.
calendar_start = text.index("struct VisualWorkspaceCalendarView: View {")
calendar_end = text.index("\nstruct CalendarModuleView: View {", calendar_start)
section = text[calendar_start:calendar_end]
section = section.replace("font(settings.eventTypography, size: compact ? 10 : settings.eventTypography.size)", "eventFont(compact ? 10 : 12)")
section = section.replace("font(settings.monthTypography, size: settings.monthTypography.size)", "monthFont(13)")
section = section.replace("font(settings.dateTypography, size: ", "dateFont(")
section = section.replace("font(settings.eventTypography, size: ", "eventFont(")
section = section.replace("font(settings.monthTypography, size: ", "monthFont(")
old_font_helper = '''    private func font(_ typography: VisualCalendarTypography, size: Double) -> Font {
        let weight = typography.weight.swiftUIFontWeight
        let actual = max(7, size)
        if typography.fontFamily == .custom { return .custom(typography.customFont, size: actual).weight(weight) }
        let design: Font.Design
        switch typography.fontFamily { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: actual, weight: weight, design: design)
    }
'''
new_font_helper = '''    private func dateFont(_ designSize: Double) -> Font { styledCalendarFont(settings.dateTypography, size: designSize * settings.dateTypography.size / 14.0) }
    private func eventFont(_ designSize: Double) -> Font { styledCalendarFont(settings.eventTypography, size: designSize * settings.eventTypography.size / 12.0) }
    private func monthFont(_ designSize: Double) -> Font { styledCalendarFont(settings.monthTypography, size: designSize * settings.monthTypography.size / 13.0) }

    private func styledCalendarFont(_ typography: VisualCalendarTypography, size: Double) -> Font {
        let weight = typography.weight.swiftUIFontWeight
        let actual = max(7, min(56, size))
        if typography.fontFamily == .custom { return .custom(typography.customFont, size: actual).weight(weight) }
        let design: Font.Design
        switch typography.fontFamily { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: actual, weight: weight, design: design)
    }
'''
if old_font_helper not in section:
    raise SystemExit("Visual Calendar font helper not found")
section = section.replace(old_font_helper, new_font_helper, 1)
text = text[:calendar_start] + section + text[calendar_end:]
path.write_text(text)

# -----------------------------------------------------------------------------
# 4. Visual Workspace editor: source discovery, actual identifier selection,
#    explicit access status, and diagnostic visibility for subscribed calendars.
# -----------------------------------------------------------------------------
path = Path("Halo/Views/WidgetSettingsView.swift")
text = path.read_text()
text = text.replace("import UniformTypeIdentifiers\n", "import UniformTypeIdentifiers\nimport EventKit\n", 1)

source_browser = r'''
private struct VisualCalendarSourceItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let holidayCandidate: Bool
}

@MainActor
private final class VisualCalendarSourceBrowser: ObservableObject {
    @Published var sources: [VisualCalendarSourceItem] = []
    @Published var status = "Calendar access has not been checked."
    private let store = EKEventStore()

    var hasAccess: Bool {
        let value = EKEventStore.authorizationStatus(for: .event)
        if value == .authorized { return true }
        if #available(macOS 14.0, *) { return value == .fullAccess }
        return false
    }

    func requestAccess() {
        if hasAccess { refresh(); return }
        let completion: (Bool, Error?) -> Void = { [weak self] allowed, error in
            Task { @MainActor in
                self?.status = allowed ? "Calendar access granted." : (error?.localizedDescription ?? "Calendar access denied.")
                self?.refresh()
            }
        }
        if #available(macOS 14.0, *) { store.requestFullAccessToEvents(completion: completion) }
        else { store.requestAccess(to: .event, completion: completion) }
    }

    func refresh() {
        guard hasAccess else {
            sources = []
            status = "Calendar access is off. Halo cannot discover events or calendar sources yet."
            return
        }
        sources = store.calendars(for: .event).map { calendar in
            let lower = calendar.title.lowercased()
            let keywords = ["holiday", "observance", "festival", "birthday"]
            let candidate = calendar.type == .subscription || calendar.type == .birthday || keywords.contains(where: { lower.contains($0) })
            return VisualCalendarSourceItem(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                detail: sourceKind(calendar),
                holidayCandidate: candidate
            )
        }.sorted { lhs, rhs in lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
        status = "\(sources.count) calendar source\(sources.count == 1 ? "" : "s") available to Halo."
    }

    private func sourceKind(_ calendar: EKCalendar) -> String {
        switch calendar.type {
        case .local: return "Local"
        case .calDAV: return "CalDAV"
        case .exchange: return "Exchange"
        case .subscription: return "Subscribed"
        case .birthday: return "Birthdays"
        @unknown default: return "Calendar"
        }
    }
}

'''
anchor = "struct PreciseSlider: View {"
if anchor not in text:
    raise SystemExit("PreciseSlider anchor not found")
text = text.replace(anchor, source_browser + anchor, 1)

text = text.replace('''    @State private var backgroundMode = false
    @State private var gridDropTarget: VisualWorkspaceGridDropTarget?
''', '''    @State private var backgroundMode = false
    @State private var gridDropTarget: VisualWorkspaceGridDropTarget?
    @StateObject private var calendarSources = VisualCalendarSourceBrowser()
''', 1)
text = text.replace('''.onAppear { materialize() }
''', '''.onAppear { materialize(); calendarSources.refresh() }
''', 1)

old_filter_ui = '''        Section("Calendar Filtering") {
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
'''
new_filter_ui = '''        Section("Calendar Sources") {
            HStack(spacing: 8) {
                Image(systemName: calendarSources.hasAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(calendarSources.hasAccess ? Color.green : Color.orange)
                Text(calendarSources.status).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if calendarSources.hasAccess {
                    Button("Refresh") { calendarSources.refresh() }.controlSize(.small)
                } else {
                    Button("Enable") { calendarSources.requestAccess() }.controlSize(.small)
                }
            }
            if calendarSources.hasAccess {
                DisclosureGroup("Detected calendars (\(calendarSources.sources.count))") {
                    ForEach(calendarSources.sources) { source in
                        HStack(spacing: 7) {
                            Image(systemName: source.holidayCandidate ? "sparkles" : "calendar")
                                .foregroundStyle(source.holidayCandidate ? style.wrappedValue.accentColor.color : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(source.title)
                                Text(source.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        Section("Calendar Filtering") {
            Picker("Show", selection: calendar.filterMode) { ForEach(VisualCalendarFilterMode.allCases) { Text($0.rawValue).tag($0) } }
            switch calendar.wrappedValue.filterMode {
            case .selected:
                if calendarSources.sources.isEmpty {
                    Text("No Calendar sources are currently available. Enable Calendar access above, then refresh.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    ForEach(calendarSources.sources) { source in
                        Toggle(isOn: calendarSourceSelectionBinding(calendar, source.id)) {
                            HStack(spacing: 6) {
                                Text(source.title)
                                Text(source.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            case .holidaysFestivals:
                let candidates = calendarSources.sources.filter(\.holidayCandidate)
                if candidates.isEmpty {
                    Text("macOS is not currently exposing a holiday/observance calendar to Halo. Add or enable one in Calendar, then press Refresh above.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Detected likely holiday sources: \(candidates.map(\.title).joined(separator: ", ")).")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            case .custom:
                TextField("Calendar names (comma separated)", text: visualCalendarNamesBinding(calendar))
                Text("Legacy name matching. Selected Calendars is more reliable because it uses EventKit identifiers.")
                    .font(.caption2).foregroundStyle(.secondary)
            case .work, .personal:
                Text("Work and Personal match common calendar names. Selected Calendars is recommended when your calendars use custom names.")
                    .font(.caption2).foregroundStyle(.secondary)
            case .all, .birthdays:
                EmptyView()
            }
            Toggle("Use native calendar colors", isOn: calendar.useNativeCalendarColors)
            if !calendar.wrappedValue.useNativeCalendarColors {
                ColorPicker("Event color", selection: Binding(get: { (calendar.wrappedValue.eventColorOverride ?? style.wrappedValue.accentColor).color }, set: { calendar.wrappedValue.eventColorOverride = WidgetColor($0) }), supportsOpacity: false)
            }
        }
'''
if old_filter_ui not in text:
    raise SystemExit("Calendar Filtering UI block not found")
text = text.replace(old_filter_ui, new_filter_ui, 1)

names_helper = '''    private func visualCalendarNamesBinding(_ calendar: Binding<VisualCalendarOptions>) -> Binding<String> {
        Binding(get: { calendar.wrappedValue.customCalendarNames.joined(separator: ", ") }, set: { text in
            calendar.wrappedValue.customCalendarNames = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        })
    }
'''
selection_helper = names_helper + '''
    private func calendarSourceSelectionBinding(_ calendar: Binding<VisualCalendarOptions>, _ identifier: String) -> Binding<Bool> {
        Binding(get: { calendar.wrappedValue.selectedCalendarIdentifiers.contains(identifier) }, set: { enabled in
            var identifiers = calendar.wrappedValue.selectedCalendarIdentifiers
            if enabled {
                if !identifiers.contains(identifier) { identifiers.append(identifier) }
            } else {
                identifiers.removeAll { $0 == identifier }
            }
            calendar.wrappedValue.selectedCalendarIdentifiers = identifiers
        })
    }
'''
if names_helper not in text:
    raise SystemExit("visualCalendarNamesBinding helper not found")
text = text.replace(names_helper, selection_helper, 1)
path.write_text(text)

print("Calendar event/settings repair patch applied")
