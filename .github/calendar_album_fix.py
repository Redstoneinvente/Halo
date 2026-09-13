from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing {label}")
    return text.replace(old, new, 1)

# Closed notch album-art background must follow the dedicated background flag,
# not the foreground artwork mode.
p = Path('Halo/Views/ClosedNotchView.swift')
text = p.read_text().replace('\r\n', '\n')
text = replace_once(
    text,
    'private var wantsArtworkBackground: Bool { artworkOptions.enabled && artworkOptions.mode == .background }',
    'private var wantsArtworkBackground: Bool { artworkOptions.usesBackgroundArtwork }',
    'album artwork background predicate',
)
p.write_text(text)

# Calendar runtime permission handling.
p = Path('Halo/Services/Integrations.swift')
text = p.read_text().replace('\r\n', '\n')
text = replace_once(text, '    private let store = EKEventStore()\n', '    private var store = EKEventStore()\n', 'CalendarService store mutability')
text = replace_once(
    text,
    '''        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)\n            .receive(on: RunLoop.main)\n            .sink { [weak self] _ in self?.refresh() }\n''',
    '''        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)\n            .receive(on: RunLoop.main)\n            .sink { [weak self] _ in self?.applicationDidBecomeActive() }\n''',
    'CalendarService activation refresh',
)
start = text.find('    func requestAccess() {')
end = text.find('    func refresh() {', start)
if start < 0 or end < 0:
    raise SystemExit('CalendarService requestAccess boundaries not found')
text = text[:start] + '''    func requestAccess() {\n        syncAuthorizationStatus()\n\n        if hasAccess {\n            rebuildEventStore()\n            refresh()\n            return\n        }\n\n        if #available(macOS 14.0, *), authorizationStatus == .writeOnly {\n            status = "Calendar is write-only. Halo needs Full Access to read your calendars."\n            openCalendarPrivacySettings()\n            return\n        }\n\n        switch authorizationStatus {\n        case .denied, .restricted:\n            status = authorizationMessage\n            openCalendarPrivacySettings()\n            return\n        case .notDetermined:\n            break\n        case .authorized:\n            rebuildEventStore()\n            refresh()\n            return\n        @unknown default:\n            break\n        }\n\n        let completion: (Bool, Error?) -> Void = { [weak self] allowed, error in\n            Task { @MainActor in\n                guard let self else { return }\n                // Apple documents that an EKEventStore used before permission can need\n                // reset/recreation before newly granted event data becomes visible.\n                self.rebuildEventStore()\n                self.syncAuthorizationStatus()\n                if let error, !allowed { self.status = error.localizedDescription }\n                self.refresh()\n            }\n        }\n        if #available(macOS 14.0, *) {\n            store.requestFullAccessToEvents(completion: completion)\n        } else {\n            store.requestAccess(to: .event, completion: completion)\n        }\n    }\n\n''' + text[end:]
marker = '    private func syncAuthorizationStatus() {'
pos = text.find(marker)
if pos < 0:
    raise SystemExit('CalendarService syncAuthorizationStatus not found')
helpers = '''    private func applicationDidBecomeActive() {\n        let previous = authorizationStatus\n        syncAuthorizationStatus()\n        let gainedReadableAccess = !Self.canReadEvents(previous) && hasAccess\n        if gainedReadableAccess || hasAccess { rebuildEventStore() }\n        refresh()\n    }\n\n    private func rebuildEventStore() {\n        store.reset()\n        store = EKEventStore()\n    }\n\n    private func openCalendarPrivacySettings() {\n        let candidates = [\n            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",\n            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"\n        ]\n        for raw in candidates {\n            guard let url = URL(string: raw) else { continue }\n            if NSWorkspace.shared.open(url) { return }\n        }\n    }\n\n'''
text = text[:pos] + helpers + text[pos:]
p.write_text(text)

# Calendar-source inspector uses its own EKEventStore, so it needs the same lifecycle repair.
p = Path('Halo/Views/WidgetSettingsView.swift')
text = p.read_text().replace('\r\n', '\n')
text = replace_once(text, '    private let store = EKEventStore()\n', '    private var store = EKEventStore()\n', 'VisualCalendarSourceBrowser store mutability')
text = replace_once(
    text,
    '''        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)\n            .receive(on: RunLoop.main)\n            .sink { [weak self] _ in self?.refresh() }\n''',
    '''        activationObserver = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)\n            .receive(on: RunLoop.main)\n            .sink { [weak self] _ in self?.applicationDidBecomeActive() }\n''',
    'source browser activation refresh',
)
start = text.find('    func requestAccess() {')
end = text.find('    func refresh() {', start)
if start < 0 or end < 0:
    raise SystemExit('VisualCalendarSourceBrowser requestAccess boundaries not found')
text = text[:start] + '''    func requestAccess() {\n        syncAuthorizationStatus()\n\n        if hasAccess {\n            rebuildEventStore()\n            refresh()\n            return\n        }\n\n        if #available(macOS 14.0, *), authorizationStatus == .writeOnly {\n            status = "Calendar is write-only. Halo needs Full Access to discover calendars and read events."\n            openCalendarPrivacySettings()\n            return\n        }\n\n        switch authorizationStatus {\n        case .denied, .restricted:\n            status = authorizationMessage\n            openCalendarPrivacySettings()\n            return\n        case .notDetermined:\n            break\n        case .authorized:\n            rebuildEventStore()\n            refresh()\n            return\n        @unknown default:\n            break\n        }\n\n        let completion: (Bool, Error?) -> Void = { [weak self] allowed, error in\n            Task { @MainActor in\n                guard let self else { return }\n                self.rebuildEventStore()\n                self.syncAuthorizationStatus()\n                if let error, !allowed { self.status = error.localizedDescription }\n                self.refresh()\n            }\n        }\n        if #available(macOS 14.0, *) {\n            store.requestFullAccessToEvents(completion: completion)\n        } else {\n            store.requestAccess(to: .event, completion: completion)\n        }\n    }\n\n''' + text[end:]
marker = '    private func syncAuthorizationStatus() {'
pos = text.find(marker)
if pos < 0:
    raise SystemExit('VisualCalendarSourceBrowser syncAuthorizationStatus not found')
helpers = '''    private func applicationDidBecomeActive() {\n        syncAuthorizationStatus()\n        if hasAccess { rebuildEventStore() }\n        refresh()\n    }\n\n    private func rebuildEventStore() {\n        store.reset()\n        store = EKEventStore()\n    }\n\n    private func openCalendarPrivacySettings() {\n        let candidates = [\n            "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",\n            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars"\n        ]\n        for raw in candidates {\n            guard let url = URL(string: raw) else { continue }\n            if NSWorkspace.shared.open(url) { return }\n        }\n    }\n\n'''
text = text[:pos] + helpers + text[pos:]
p.write_text(text)

# Put the Calendar privacy strings in the source Info.plist too. The target build settings
# already provide them, but carrying them here prevents packaging/configuration drift.
p = Path('Halo/Info.plist')
text = p.read_text().replace('\r\n', '\n')
if '<key>NSCalendarsFullAccessUsageDescription</key>' not in text:
    insertion = '''\t<key>NSCalendarsFullAccessUsageDescription</key>\n\t<string>Halo reads your calendars to show schedules, holidays, and meeting links. Halo does not modify events.</string>\n\t<key>NSCalendarsUsageDescription</key>\n\t<string>Halo reads your calendar events when you enable Calendar.</string>\n'''
    text = text.replace('\t<key>HaloFirebaseAPIKey</key>\n', insertion + '\t<key>HaloFirebaseAPIKey</key>\n', 1)
p.write_text(text)

print('Calendar permission and closed-notch album-art repairs applied')
