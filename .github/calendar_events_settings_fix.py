from pathlib import Path


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Expected block not found in {path}: {old[:160]!r}")
    p.write_text(text.replace(old, new, 1))


# Calendar runtime permission state must refresh when Halo returns from System Settings.
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
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()
    private var eventObserver: AnyCancellable?
    private var activationObserver: AnyCancellable?

    var hasAccess: Bool { Self.canReadEvents(authorizationStatus) }

    init() {
        eventObserver = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    func requestAccess() {
        syncAuthorizationStatus()
        if hasAccess {
            refresh()
            return
        }
        let completion: (Bool, Error?) -> Void = { [weak self] allowed, error in
            Task { @MainActor in
                guard let self else { return }
                self.syncAuthorizationStatus()
                if let error, !allowed { self.status = error.localizedDescription }
                self.refresh()
            }
        }
        if #available(macOS 14.0, *) { store.requestFullAccessToEvents(completion: completion) }
        else { store.requestAccess(to: .event, completion: completion) }
    }

    func refresh() {
        syncAuthorizationStatus()
        guard hasAccess else {
            events = []
            upcomingEvents = []
            visualDayEvents = []
            visualUpcomingEvents = []
            status = authorizationMessage
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

        visualDayEvents = raw.filter { $0.startDate < tomorrow && $0.endDate > today }
        visualUpcomingEvents = raw.filter { $0.endDate > now }

        // Preserve the regular opened-notch Calendar's existing semantics.
        events = visualDayEvents.filter { $0.endDate > now }
        upcomingEvents = visualUpcomingEvents.filter { $0.startDate < legacyHorizon }

        let sourceCount = calendars.count
        if visualDayEvents.isEmpty {
            status = sourceCount == 0
                ? "Calendar access granted, but no event calendars are exposed by macOS."
                : "Calendar connected · no events today · \(sourceCount) calendar\(sourceCount == 1 ? "" : "s")"
        } else {
            status = "Calendar connected · \(visualDayEvents.count) event\(visualDayEvents.count == 1 ? "" : "s") today · \(sourceCount) calendar\(sourceCount == 1 ? "" : "s")"
        }
        calendarRevision &+= 1
    }

    func events(around anchor: Date) -> [EKEvent] {
        syncAuthorizationStatus()
        guard hasAccess else { return [] }
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

    private func syncAuthorizationStatus() {
        let next = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus != next { authorizationStatus = next }
    }

    private static func canReadEvents(_ status: EKAuthorizationStatus) -> Bool {
        if status == .authorized { return true }
        if #available(macOS 14.0, *), status == .fullAccess { return true }
        return false
    }

    private var authorizationMessage: String {
        if #available(macOS 14.0, *), authorizationStatus == .writeOnly {
            return "Calendar access is write-only. Halo needs Full Access to read events."
        }
        switch authorizationStatus {
        case .notDetermined:
            return "Calendar access has not been granted yet."
        case .denied:
            return "Calendar access is denied. Enable Halo in System Settings → Privacy & Security → Calendars."
        case .restricted:
            return "Calendar access is restricted on this Mac."
        case .authorized:
            return "Calendar connected."
        @unknown default:
            return "Calendar access is unavailable."
        }
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


# Calendar source picker had the same stale authorization state.
path = Path("Halo/Views/WidgetSettingsView.swift")
text = path.read_text()
start = text.index("@MainActor\nprivate final class VisualCalendarSourceBrowser: ObservableObject {")
end = text.index("\n\nstruct PreciseSlider:", start)
new_browser = r'''@MainActor
private final class VisualCalendarSourceBrowser: ObservableObject {
    @Published var sources: [VisualCalendarSourceItem] = []
    @Published var status = "Calendar access has not been checked."
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()
    private var activationObserver: AnyCancellable?
    private var eventObserver: AnyCancellable?

    var hasAccess: Bool { Self.canReadEvents(authorizationStatus) }

    init() {
        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
        eventObserver = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    func requestAccess() {
        syncAuthorizationStatus()
        if hasAccess { refresh(); return }
        let completion: (Bool, Error?) -> Void = { [weak self] allowed, error in
            Task { @MainActor in
                guard let self else { return }
                self.syncAuthorizationStatus()
                if let error, !allowed { self.status = error.localizedDescription }
                self.refresh()
            }
        }
        if #available(macOS 14.0, *) { store.requestFullAccessToEvents(completion: completion) }
        else { store.requestAccess(to: .event, completion: completion) }
    }

    func refresh() {
        syncAuthorizationStatus()
        guard hasAccess else {
            sources = []
            status = authorizationMessage
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
        status = "Calendar access granted · \(sources.count) source\(sources.count == 1 ? "" : "s") available to Halo."
    }

    private func syncAuthorizationStatus() {
        let next = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus != next { authorizationStatus = next }
    }

    private static func canReadEvents(_ status: EKAuthorizationStatus) -> Bool {
        if status == .authorized { return true }
        if #available(macOS 14.0, *), status == .fullAccess { return true }
        return false
    }

    private var authorizationMessage: String {
        if #available(macOS 14.0, *), authorizationStatus == .writeOnly {
            return "Calendar is write-only. Halo needs Full Access to discover calendars and read events."
        }
        switch authorizationStatus {
        case .notDetermined:
            return "Calendar access has not been granted yet."
        case .denied:
            return "Calendar access is denied. Enable Halo in System Settings → Privacy & Security → Calendars."
        case .restricted:
            return "Calendar access is restricted on this Mac."
        case .authorized:
            return "Calendar access granted."
        @unknown default:
            return "Calendar access is unavailable."
        }
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
}'''
text = text[:start] + new_browser + text[end:]
if "import Combine\n" not in text[:300]:
    text = text.replace("import EventKit\n", "import EventKit\nimport Combine\n", 1)
path.write_text(text)


# Restore the existing persisted surface blur to Appearance > Surface.
replace_once(
    "Halo/Views/WorkspaceSettingsView.swift",
    '''    @ViewBuilder private var surface: some View {
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .geometry
        )
    }
''',
    '''    @ViewBuilder private var surface: some View {
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .geometry
        )
        Section("Surface background effects") {
            if workspace.settings.layout.appearance.background == .glass {
                Label("Glass uses Halo's native macOS material", systemImage: "square.on.square")
                    .foregroundStyle(.secondary)
                Text("Background Blur applies to Solid, Gradient, Image, and Video surfaces. Visual Workspace glass strength remains independently configurable in its Background page.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                PreciseSlider(
                    title: "Background blur",
                    value: $workspace.settings.layout.appearance.blur,
                    range: 0...20,
                    step: 0.5,
                    suffix: "pt",
                    decimals: 1
                )
                HStack {
                    Button("Reset blur") { workspace.settings.layout.appearance.blur = 0 }
                    Spacer()
                    Text("Affects the surface background only")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("This is Halo's existing persisted Surface blur; the renderer already applies it to Solid, Gradient, Image, Video, and timed backgrounds.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
'''
)

print("Surface blur and Calendar authorization repair applied")
