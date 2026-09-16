import AppKit
import Combine
import UserNotifications
import CoreAudio
import Darwin

@MainActor
final class WorkspaceStore: ObservableObject, LiveActivityProvider {
    static let systemAudioSource = "com.redstoneinvente.halo.system-audio"

    @Published var settings: WorkspaceSettings { didSet {
        schedulePersistence()

        let hotkeyChanged = oldValue.hotkeyEnabled != settings.hotkeyEnabled ||
            oldValue.hotkeyCode != settings.hotkeyCode ||
            oldValue.hotkeyModifiers != settings.hotkeyModifiers
        if hotkeyChanged { updateHotkey() }

        let mediaSourceChanged = oldValue.mediaApp != settings.mediaApp || oldValue.automaticMedia != settings.automaticMedia
        if mediaSourceChanged { media.disconnect() }

        let baseArtworkInputsChanged = oldValue.layout.contextMusic != settings.layout.contextMusic ||
            oldValue.layout.hud != settings.layout.hud ||
            oldValue.layout.closedNotch != settings.layout.closedNotch ||
            oldValue.layout.enabled != settings.layout.enabled ||
            oldValue.displays != settings.displays || mediaSourceChanged
        let activeProfileArtworkInputsChanged: Bool = {
            guard let id = scheduledProfileID else { return false }
            let oldLayout = oldValue.profiles.first(where: { $0.id == id })?.layout
            let newLayout = settings.profiles.first(where: { $0.id == id })?.layout
            return oldLayout?.contextMusic != newLayout?.contextMusic ||
                oldLayout?.hud != newLayout?.hud ||
                oldLayout?.closedNotch != newLayout?.closedNotch ||
                oldLayout?.enabled != newLayout?.enabled
        }()
        let displayProfileInputsChanged: Bool = {
            let ids = Set(settings.displays.compactMap(\.profileID))
            return ids.contains { id in
                oldValue.profiles.first(where: { $0.id == id })?.layout != settings.profiles.first(where: { $0.id == id })?.layout
            }
        }()
        if baseArtworkInputsChanged || activeProfileArtworkInputsChanged || displayProfileInputsChanged { updateArtworkPreference() }

        let activeProfileHUDChanged: Bool = {
            guard let id = scheduledProfileID else { return false }
            return oldValue.profiles.first(where: { $0.id == id })?.layout.hud != settings.profiles.first(where: { $0.id == id })?.layout.hud
        }()
        if oldValue.layout.hud != settings.layout.hud || oldValue.displays != settings.displays || activeProfileHUDChanged || displayProfileInputsChanged {
            hudEngine?.configurationDidChange()
        }

        queueScheduleEvaluation()
    } }
    @Published private(set) var scheduledProfileID: UUID?
    var effectiveLayout: WorkspaceLayout { settings.profiles.first { $0.id == scheduledProfileID }?.layout ?? settings.layout }
    var scheduledTheme: Theme? { settings.profiles.first { $0.id == scheduledProfileID }?.theme }
    private var suppressedOccurrence: String?
    private var scheduleEvaluationQueued = false
    private var lastScheduleMinute: Int?
    @Published var activities: [LiveActivity] = []
    @Published var plugins: [PluginManifest] = []
    @Published var error: String?
    @Published var runningApps: [NSRunningApplication] = []
    @Published private(set) var openedNotchVisible = false
    private var openedNotchVisibilityTokens = Set<UUID>()
    let calendar = CalendarService()
    let clipboard = ClipboardService()
    let system = SystemService()
    let audio = AudioService()
    let media = MediaService()
    let capture = CaptureService()
    let bluetooth = BluetoothStateService.shared
    @Published var stopwatchStart: Date?
    @Published var stopwatchElapsed: TimeInterval = 0
    @Published var stopwatchLaps: [TimeInterval] = []
    func setOpenedNotchVisible(_ visible: Bool, token: UUID) {
        if visible { openedNotchVisibilityTokens.insert(token) } else { openedNotchVisibilityTokens.remove(token) }
        let next = !openedNotchVisibilityTokens.isEmpty
        guard next != openedNotchVisible else { return }
        openedNotchVisible = next
        media.setOpenedDetailEnabled(next)
        if next { system.refresh(detailed: true); audio.refresh() }
    }
    func toggleStopwatch() {
        if let start = stopwatchStart { stopwatchElapsed += Date().timeIntervalSince(start); stopwatchStart = nil }
        else { stopwatchStart = Date() }
    }
    func lapStopwatch() {
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
    private let hotkey = HotkeyService()
    private let retroGameHotkey = HotkeyService(identifierID: 2, notificationName: .init("HaloRetroGameToggle"))
    private let clipboardCIHotkey = HotkeyService(identifierID: 3, notificationName: .init("HaloClipboardCIToggle"))
    private let defaults: UserDefaults
    private var ticker: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var matchedRules = Set<UUID>()
    private var tick = 0
    private var installedHotkey = ""
    private var installedRetroGameHotkey = ""
    private var installedClipboardCIHotkey = ""
    private var pendingSave: DispatchWorkItem?
    private var hudEngine: HaloHUDEngine?
    private var systemAudioFallback: SystemAudioMediaFallback?
    var applyTheme: ((Theme) -> Void)?
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "workspace.v1"), let saved = try? JSONDecoder().decode(WorkspaceSettings.self, from: data), saved.version == 1 {
            settings = saved
        } else { settings = WorkspaceSettings() }
        if let data = defaults.data(forKey: "plugins.v1"), let saved = try? JSONDecoder().decode([PluginManifest].self, from: data) {
            plugins = saved.compactMap { try? $0.validated() }
        }
    }
    private func updateArtworkPreference() {
        let displayLayouts = settings.displays.compactMap { item -> WorkspaceLayout? in
            guard item.enabled else { return nil }
            if let profileID = item.profileID, let profile = settings.profiles.first(where: { $0.id == profileID }) { return profile.layout }
            return item.layout
        }
        let layouts = [effectiveLayout] + displayLayouts
        media.setArtworkEnabled(layouts.contains { layout in
            let context = layout.contextMusic
            let contextNeedsArtwork = context?.enabled == true && (
                context?.showArtwork == true || context?.usesArtworkBackground == true
            )
            let contextNeedsPalette = context?.enabled == true && (
                context?.usesSongTextColors == true ||
                context?.usesSongControlColors == true ||
                context?.usesSongVisualizerColors == true ||
                context?.usesSongBackgroundColors == true ||
                context?.background == .gradient
            )
            let hudNeedsPalette = layout.hud?.enabled == true && HaloHUDEventKind.allCases.contains { kind in
                let configuration = layout.hud?.configuration(for: kind)
                return configuration?.appearance.primary.source == .albumArtwork ||
                       configuration?.appearance.progress.source == .albumArtwork
            }
            return contextNeedsArtwork || contextNeedsPalette || hudNeedsPalette ||
                layout.closedNotch?.visualizer?.dynamicColors == true ||
                layout.closedNotch?.albumTextColor == true ||
                layout.closedNotch?.albumBackgroundColor == true
        })
    }
    private var isAutomaticMediaSource: Bool { settings.automaticMedia ?? true }
    private var isSystemAudioOnly: Bool { !isAutomaticMediaSource && settings.mediaApp == Self.systemAudioSource }
    private var wantsSystemAudioFallback: Bool {
        if isSystemAudioOnly { return true }
        guard isAutomaticMediaSource else { return false }
        let layout = effectiveLayout
        let contextUsesMedia = layout.contextMusic?.enabled == true
        let moduleUsesMedia = layout.enabled.contains(.media)
        let closed = layout.closedNotch
        let closedUsesMedia = closed?.left == .media || closed?.left == .visualizer ||
            closed?.right == .media || closed?.right == .visualizer ||
            closed?.artworkOptions?.enabled == true || closed?.reactiveBackground?.enabled == true
        return contextUsesMedia || moduleUsesMedia || closedUsesMedia
    }
    func refreshMediaSource() {
        media.disconnect()
        pollMedia()
    }
    private func pollMedia() {
        if systemAudioFallback == nil { systemAudioFallback = SystemAudioMediaFallback(media: media) }
        systemAudioFallback?.setEnabled(wantsSystemAudioFallback)

        if isSystemAudioOnly {
            systemAudioFallback?.refresh()
            return
        }

        let preferred = settings.mediaApp == Self.systemAudioSource ? "com.apple.Music" : settings.mediaApp
        media.poll(app: preferred, automatic: isAutomaticMediaSource)
        systemAudioFallback?.refresh()
    }
    private func disableLegacyHUDRenderer() {
        if defaults.object(forKey: HaloHUDKeys.enabled) as? Bool != false {
            defaults.set(false, forKey: HaloHUDKeys.enabled)
        }
    }
    func start() {
        disableLegacyHUDRenderer()
        updateArtworkPreference()
        if hudEngine == nil { hudEngine = HaloHUDEngine(workspace: self); hudEngine?.start() }
        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey(); updateRetroGameHotkey(); updateClipboardCIHotkey()
        HaloCustomCIRuntimeStore.shared.attach(to: self)
        pollMedia()

        bluetooth.$lastEvent
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.publishBluetoothClosedNotchEvent(event)
            }
            .store(in: &subscriptions)
        bluetooth.start()

        ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            self.tick += 1
            self.pollMedia()
            let minute = Int(Date().timeIntervalSince1970 / 60)
            if self.lastScheduleMinute != minute { self.lastScheduleMinute = minute; self.evaluateSchedules() }
            self.clipboard.poll(enabled: self.settings.clipboardEnabled, excluded: self.settings.clipboardExcludedApps)
            if self.openedNotchVisible { self.system.refresh(detailed: true) }
            else if self.tick % 5 == 0 { self.system.refresh() }
            if self.tick % 5 == 0 { self.evaluateRules() }
            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.disableLegacyHUDRenderer()
                self?.updateRetroGameHotkey()
                self?.updateClipboardCIHotkey()
            }
            .store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
                self?.refreshApps(); self?.evaluateRules(); self?.evaluateSchedules(); self?.hudEngine?.configurationDidChange()
                self?.pollMedia(); self?.bluetooth.refresh()
            }.store(in: &subscriptions)
        }
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            DistributedNotificationCenter.default().publisher(for: Notification.Name(name))
                .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in self?.pollMedia() }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.evaluateRules(); self?.hudEngine?.configurationDidChange() }.store(in: &subscriptions)
    }
    func stop() { HaloCustomCIRuntimeStore.shared.detach(); pendingSave?.cancel(); persist(); ticker?.cancel(); subscriptions.removeAll(); bluetooth.stop(); systemAudioFallback?.stop(); systemAudioFallback = nil; hudEngine?.stop(); hudEngine = nil; hotkey.stop(); retroGameHotkey.stop(); clipboardCIHotkey.stop(); clipboard.reset(); media.disconnect() }
    private func schedulePersistence() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    private func persist() {
        do { defaults.set(try JSONEncoder().encode(settings), forKey: "workspace.v1") }
        catch { self.error = error.localizedDescription }
    }
    private func updateHotkey() {
        let key = "\(settings.hotkeyEnabled)-\(settings.hotkeyCode)-\(settings.hotkeyModifiers)"
        guard key != installedHotkey else { return }; installedHotkey = key
        hotkey.stop()
        if settings.hotkeyEnabled, !hotkey.register(code: settings.hotkeyCode, modifiers: settings.hotkeyModifiers) {
            DispatchQueue.main.async { [weak self] in self?.error = "The global shortcut is unavailable or already used. Choose another shortcut." }
        }
    }
    private func updateRetroGameHotkey() {
        let ciEnabled = defaults.object(forKey: "HaloContextRetroEnabled") as? Bool ?? false
        let shortcutEnabled = defaults.object(forKey: "HaloContextRetroShortcutEnabled") as? Bool ?? true
        let code = defaults.object(forKey: "HaloContextRetroShortcutCode") == nil ? 5 : defaults.integer(forKey: "HaloContextRetroShortcutCode")
        let modifiers = defaults.object(forKey: "HaloContextRetroShortcutModifiers") == nil ? 2304 : defaults.integer(forKey: "HaloContextRetroShortcutModifiers")
        let key = "\(ciEnabled)-\(shortcutEnabled)-\(code)-\(modifiers)"
        guard key != installedRetroGameHotkey else { return }
        installedRetroGameHotkey = key
        retroGameHotkey.stop()
        guard ciEnabled, shortcutEnabled else { return }
        if !retroGameHotkey.register(code: UInt32(max(0, code)), modifiers: UInt32(max(0, modifiers))) {
            DispatchQueue.main.async { [weak self] in
                self?.error = "The Retro Game CI shortcut is unavailable or already used. Choose another shortcut."
            }
        }
    }
    private func updateClipboardCIHotkey() {
        let ciEnabled = defaults.object(forKey: "HaloContextClipboardEnabled") as? Bool ?? true
        let shortcutEnabled = defaults.object(forKey: "HaloContextClipboardShortcutEnabled") as? Bool ?? true
        let code = defaults.object(forKey: "HaloContextClipboardShortcutCode") == nil ? 9 : defaults.integer(forKey: "HaloContextClipboardShortcutCode")
        let modifiers = defaults.object(forKey: "HaloContextClipboardShortcutModifiers") == nil ? 6144 : defaults.integer(forKey: "HaloContextClipboardShortcutModifiers")
        let key = "\(ciEnabled)-\(shortcutEnabled)-\(code)-\(modifiers)"
        guard key != installedClipboardCIHotkey else { return }
        installedClipboardCIHotkey = key
        clipboardCIHotkey.stop()
        guard ciEnabled, shortcutEnabled else { return }
        if !clipboardCIHotkey.register(code: UInt32(max(0, code)), modifiers: UInt32(max(0, modifiers))) {
            DispatchQueue.main.async { [weak self] in
                self?.error = "The Clipboard CI shortcut is unavailable or already used. Choose another shortcut."
            }
        }
    }
    private func scheduleWinner(at date: Date) -> (UUID, String)? {
        for entry in settings.profileSchedules ?? [] where entry.enabled {
            guard settings.profiles.contains(where: { $0.id == entry.profileID }),
                  let day = entry.window.occurrence(at: date) else { continue }
            return (entry.profileID, entry.id.uuidString + ":" + String(day.timeIntervalSince1970))
        }
        return nil
    }
    private func queueScheduleEvaluation() {
        guard !scheduleEvaluationQueued else { return }; scheduleEvaluationQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.scheduleEvaluationQueued = false; self?.evaluateSchedules()
        }
    }
    func evaluateSchedules() {
        let winner = scheduleWinner(at: Date())
        let selected = winner?.1 == suppressedOccurrence ? nil : winner?.0
        if scheduledProfileID != selected { scheduledProfileID = selected; updateArtworkPreference(); hudEngine?.configurationDidChange() }
    }
    func resumeSchedules() { suppressedOccurrence = nil; evaluateSchedules() }
    func apply(_ profile: Profile) {
        suppressedOccurrence = scheduleWinner(at: Date())?.1
        scheduledProfileID = nil
        settings.layout = profile.layout; applyTheme?(profile.theme)
    }
    func saveProfile(name: String, theme: Theme) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        settings.profiles.append(Profile(name: name, theme: theme, layout: settings.layout))
    }
    func deleteProfile(_ id: UUID) {
        settings.profiles.removeAll { $0.id == id }; settings.rules.removeAll { $0.profileID == id }; settings.profileSchedules?.removeAll { $0.profileID == id }
    }
    func renameProfile(_ id: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = settings.profiles.firstIndex(where: { $0.id == id }) else { return }
        settings.profiles[index].name = String(name.prefix(80))
    }
    func moveModule(_ module: ModuleID, by delta: Int) {
        var order = settings.layout.normalizedOrder()
        guard let index = order.firstIndex(of: module), order.indices.contains(index + delta) else { return }
        order.swapAt(index, index + delta); settings.layout.order = order
    }
    func evaluateRules() {
        var current = Set<UUID>()
        var selected: Profile?
        for rule in settings.rules where rule.matches(app: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "", battery: system.battery, charging: system.charging, displays: NSScreen.screens.count, hour: Calendar.current.component(.hour, from: Date())) {
            current.insert(rule.id)
            if !matchedRules.contains(rule.id), selected == nil { selected = settings.profiles.first { $0.id == rule.profileID } }
        }
        matchedRules = current
        if let selected { apply(selected) }
    }
    private func bluetoothClosedNotchEventEnabled(_ kind: BluetoothConnectionEventKind) -> Bool {
        guard defaults.object(forKey: "HaloBluetoothClosedNotchEvents") as? Bool ?? true else { return false }
        let key: String
        switch kind {
        case .connected: key = "HaloBluetoothClosedNotchConnected"
        case .disconnected: key = "HaloBluetoothClosedNotchDisconnected"
        case .poweredOn: key = "HaloBluetoothClosedNotchPoweredOn"
        case .poweredOff: key = "HaloBluetoothClosedNotchPoweredOff"
        }
        return defaults.object(forKey: key) as? Bool ?? true
    }
    private func publishBluetoothClosedNotchEvent(_ event: BluetoothConnectionEvent) {
        guard bluetoothClosedNotchEventEnabled(event.kind) else { return }
        let activity = LiveActivity(bluetoothDeviceVisual: event.deviceVisual, title: event.title, detail: event.detail, progress: nil)
        activities = [activity] + Array(activities.prefix(19))

        let configured = (defaults.object(forKey: "HaloBluetoothClosedNotchDuration") as? NSNumber)?.doubleValue ?? 10
        let duration = min(20, max(2, configured))
        let activityID = activity.id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.activities.removeAll { $0.id == activityID }
        }
    }
    func publish(_ title: String, detail: String = "", progress: Double? = nil) {
        let activity = LiveActivity(title: title, detail: detail, progress: progress.map { min(1, max(0, $0)) })
        activities = [activity] + Array(activities.prefix(19))
    }
    func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, error in
            if let error { Task { @MainActor in self?.error = error.localizedDescription } }
        }
    }
    func notify(_ title: String) {
        UNUserNotificationCenter.current().getNotificationSettings { status in
            guard status.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent(); content.title = title; content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
    func refreshApps() {
        let updated = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        if runningApps.map(\.processIdentifier) != updated.map(\.processIdentifier) { runningApps = updated }
    }
    func chooseBackground() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.layout.appearance.assetPath = url.path
        settings.layout.appearance.background = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) ? .video : .image
    }
    func importPlugin() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) < 100_000 else { throw CocoaError(.fileReadTooLarge) }
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: url)).validated()
            let alert = NSAlert(); alert.messageText = "Install \(manifest.name)?"
            alert.informativeText = "This plugin adds \(manifest.commands.count) commands. Each URL is shown for confirmation before opening. No executable code is loaded."
            alert.addButton(withTitle: "Install"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            plugins.removeAll { $0.id == manifest.id }; plugins.append(manifest); savePlugins()
        } catch { self.error = "Plugin rejected: \(error.localizedDescription)" }
    }
    func removePlugin(_ id: String) { plugins.removeAll { $0.id == id }; savePlugins() }
    private func savePlugins() {
        do { defaults.set(try JSONEncoder().encode(plugins), forKey: "plugins.v1") }
        catch { self.error = error.localizedDescription }
    }
    func run(_ command: PluginCommand) {
        guard let url = URL(string: command.url) else { return }
        let alert = NSAlert(); alert.messageText = command.title
        alert.informativeText = "Open this URL? Shortcuts may perform actions configured in the Shortcuts app.\n\n\(command.url)"
        alert.addButton(withTitle: "Open"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
    }
}

@available(macOS 14.2, *)
private enum SafariAudioProcessDetector {
    private static let safariBundleID = "com.apple.Safari"
    private static let safariWebContentBundleID = "com.apple.WebKit.WebContent"

    static func isProducingOutput() -> Bool {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).isEmpty else { return false }

        var listAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &listAddress, 0, nil, &byteCount) == noErr, byteCount > 0 else { return false }

        var processObjects = [AudioObjectID](
            repeating: kAudioObjectUnknown,
            count: Int(byteCount) / MemoryLayout<AudioObjectID>.size
        )
        guard !processObjects.isEmpty,
              AudioObjectGetPropertyData(system, &listAddress, 0, nil, &byteCount, &processObjects) == noErr else { return false }

        for object in processObjects {
            guard readUInt32(object, selector: kAudioProcessPropertyIsRunningOutput) != 0 else { continue }
            let bundleID = readString(object, selector: kAudioProcessPropertyBundleID) ?? ""
            let pid = readPID(object)
            if belongsToSafari(pid: pid, bundleID: bundleID) { return true }
        }
        return false
    }

    private static func readUInt32(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func readPID(_ object: AudioObjectID) -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func readString(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        let string = value as String
        return string.isEmpty ? nil : string
    }

    private static func belongsToSafari(pid: pid_t, bundleID: String) -> Bool {
        if bundleID == safariBundleID { return true }
        guard bundleID == safariWebContentBundleID || bundleID.hasPrefix("com.apple.WebKit.") else { return false }

        // Safari hands actual web media output to WebKit helper processes. Walk the normal
        // parent chain first so we can attribute a helper to Safari without guessing.
        var current = pid
        var visited = Set<pid_t>()
        for _ in 0..<8 {
            guard current > 0, visited.insert(current).inserted else { break }
            if NSRunningApplication(processIdentifier: current)?.bundleIdentifier == safariBundleID { return true }
            guard let parent = parentPID(of: current), parent > 0, parent != current else { break }
            current = parent
        }

        // WebKit helpers can be re-parented through launchd/XPC. If Safari itself is running,
        // an active Apple WebKit WebContent output process is still a strong Safari signal.
        return !NSRunningApplication.runningApplications(withBundleIdentifier: safariBundleID).isEmpty
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let expected = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, expected) == expected else { return nil }
        return pid_t(info.pbi_ppid)
    }
}

private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
    let artworkData: Data?
    let artworkURL: String?
}

private final class MediaRemoteNowPlayingReader {
    static let shared = MediaRemoteNowPlayingReader()

    private typealias InfoCallback = @convention(block) (CFDictionary?) -> Void
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, InfoCallback) -> Void

    private let handle: UnsafeMutableRawPointer?
    private let getInfo: GetInfoFunction?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            getInfo = unsafeBitCast(symbol, to: GetInfoFunction.self)
        } else {
            getInfo = nil
        }
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    func fetch(_ completion: @escaping (MediaRemoteNowPlayingSnapshot?) -> Void) {
        guard let getInfo else { completion(nil); return }
        let callback: InfoCallback = { dictionary in
            guard let dictionary else { completion(nil); return }
            let info = dictionary as NSDictionary

            func firstString(_ keys: [String]) -> String? {
                for key in keys {
                    if let value = info[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
                }
                return nil
            }
            func firstDouble(_ keys: [String]) -> Double? {
                for key in keys {
                    if let value = info[key] as? NSNumber { return value.doubleValue }
                    if let value = info[key] as? Double { return value }
                }
                return nil
            }
            func firstData(_ keys: [String]) -> Data? {
                for key in keys {
                    if let value = info[key] as? Data, !value.isEmpty { return value }
                    if let value = info[key] as? NSData, value.length > 0 { return value as Data }
                }
                return nil
            }
            func firstHTTPSURL(_ keys: [String]) -> String? {
                for key in keys {
                    let raw: String?
                    if let value = info[key] as? URL { raw = value.absoluteString }
                    else if let value = info[key] as? NSURL { raw = value.absoluteString }
                    else { raw = info[key] as? String }
                    if let raw, URL(string: raw)?.scheme == "https" { return raw }
                }
                return nil
            }

            guard let title = firstString(["kMRMediaRemoteNowPlayingInfoTitle", "title"]) else {
                completion(nil)
                return
            }
            let artist = firstString(["kMRMediaRemoteNowPlayingInfoArtist", "artist"]) ?? ""
            let album = firstString(["kMRMediaRemoteNowPlayingInfoAlbum", "album"]) ?? ""
            let duration = firstDouble(["kMRMediaRemoteNowPlayingInfoDuration", "duration"])
            let elapsed = firstDouble(["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime"])
            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            let artworkData = firstData(["kMRMediaRemoteNowPlayingInfoArtworkData", "artworkData"])
            let artworkURL = firstHTTPSURL(["kMRMediaRemoteNowPlayingInfoArtworkURL", "artworkURL",
                                            "kMRMediaRemoteNowPlayingInfoArtworkIdentifier", "artworkIdentifier"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed,
                                                     artworkData: artworkData, artworkURL: artworkURL))
        }
        getInfo(DispatchQueue.global(qos: .utility), callback)
    }
}

@MainActor
private final class SystemAudioMediaFallback {
    private weak var media: MediaService?
    private var enabled = false
    private var ownsFallback = false
    private var lastHeard = Date.distantPast
    private var lastSafariOutput = Date.distantPast
    private var lastRemoteMetadata = Date.distantPast
    private var remoteRequestInFlight = false
    private var safariAudibleSince: Date?
    private var recognitionInFlight = false
    private var lastRecognitionAttempt = Date.distantPast

    init(media: MediaService) { self.media = media }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        AudioSpectrumService.shared.setActive(enabled)
        if !enabled {
            AudioSpectrumService.shared.cancelRecognition()
            recognitionInFlight = false
            safariAudibleSince = nil
            clearIfOwned()
        }
    }

    func refresh() {
        guard enabled, let media else { return }

        // A genuinely playing rich provider still wins. Paused/stopped Apple Music or Spotify
        // must not block Safari/system audio from claiming the surface.
        if media.connectedApp != nil && media.isPlaying {
            ownsFallback = false
            return
        }

        let now = Date()
        let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        let safariOutputActive: Bool
        if #available(macOS 14.2, *) {
            safariOutputActive = SafariAudioProcessDetector.isProducingOutput()
        } else {
            safariOutputActive = false
        }
        if safariOutputActive { lastSafariOutput = now }

        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let pcmAudible = isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutputActive)
        let audibleNow = safariOutputActive || pcmAudible
        let safariLikely = safariOutputActive || (safariRunning && pcmAudible)
        if audibleNow { lastHeard = now }
        if safariLikely && audibleNow {
            if safariAudibleSince == nil { safariAudibleSince = now }
        } else if now.timeIntervalSince(lastHeard) > 4.5 {
            safariAudibleSince = nil
        }

        // If a stale paused rich provider is still attached, release it as soon as real system
        // output is observed. This is the main failure mode when Safari plays while Music/Spotify
        // happens to be open in the background.
        if audibleNow, media.connectedApp != nil, !media.isPlaying { media.disconnect() }

        requestMediaRemoteMetadata()

        let safariRecentlyActive = now.timeIntervalSince(lastSafariOutput) < 2.0
        let releaseWindow = (safariRunning || safariRecentlyActive) ? 4.0 : 2.75
        let withinReleaseWindow = now.timeIntervalSince(lastHeard) < releaseWindow
        let remoteMetadataFresh = now.timeIntervalSince(lastRemoteMetadata) < 5.0
        let systemAudioPlaying = audibleNow || (ownsFallback && withinReleaseWindow)

        if systemAudioPlaying {
            if media.connectedApp == nil {
                if !remoteMetadataFresh {
                    if safariOutputActive || safariRecentlyActive {
                        media.title = "Safari Audio"
                        media.artist = "Playing from Safari"
                    } else {
                        media.title = "System Audio"
                        media.artist = "Playing from your Mac"
                    }
                }
                media.isPlaying = true
                media.error = nil
                ownsFallback = true
            }
            requestRecognitionIfNeeded(media: media, safariLikely: safariLikely, audibleNow: audibleNow, now: now)
            return
        }

        // Keep fresh MediaRemote metadata visible while paused, but do not mark the source as playing.
        if ownsFallback && remoteMetadataFresh && media.connectedApp == nil {
            media.isPlaying = false
            return
        }

        clearIfOwned()
    }

    func stop() {
        enabled = false
        AudioSpectrumService.shared.cancelRecognition()
        recognitionInFlight = false
        safariAudibleSince = nil
        AudioSpectrumService.shared.setActive(false)
        clearIfOwned()
    }

    private func requestMediaRemoteMetadata() {
        guard !remoteRequestInFlight else { return }
        remoteRequestInFlight = true
        MediaRemoteNowPlayingReader.shared.fetch { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                self.remoteRequestInFlight = false
                guard self.enabled, let media = self.media, media.connectedApp == nil, let snapshot else { return }

                let audioSnapshot = AudioSpectrumService.shared.snapshot()
                let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
                let safariOutput: Bool
                if #available(macOS 14.2, *) { safariOutput = SafariAudioProcessDetector.isProducingOutput() }
                else { safariOutput = false }
                let pcmAudible = self.isPCMAudible(audioSnapshot, safariHint: safariRunning || safariOutput)
                let safariLikely = safariOutput || (safariRunning && pcmAudible)
                let audibleNow = safariOutput || pcmAudible

                // A paused MediaRemote entry is often stale Music/Spotify metadata. If Safari is
                // demonstrably making sound, do not paint that stale track over Safari; Shazam gets
                // a chance to resolve the audible track instead.
                guard snapshot.playing || !safariLikely else {
                    media.isPlaying = audibleNow
                    return
                }

                self.lastRemoteMetadata = Date()
                self.ownsFallback = true
                let displayArtist = !snapshot.artist.isEmpty ? snapshot.artist : (!snapshot.album.isEmpty ? snapshot.album : "System Audio")
                let sourceKey = [snapshot.title, snapshot.artist, snapshot.album]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "|")
                media.acceptExternalMedia(title: snapshot.title,
                                          artist: displayArtist,
                                          album: snapshot.album,
                                          duration: snapshot.duration,
                                          position: snapshot.elapsed,
                                          playing: snapshot.playing || audibleNow,
                                          artworkData: snapshot.artworkData,
                                          artworkURL: snapshot.artworkURL,
                                          sourceKey: sourceKey)
            }
        }
    }

    private func requestRecognitionIfNeeded(media: MediaService, safariLikely: Bool, audibleNow: Bool, now: Date) {
        guard safariLikely, audibleNow, !recognitionInFlight,
              let since = safariAudibleSince, now.timeIntervalSince(since) >= 2.4,
              now.timeIntervalSince(lastRecognitionAttempt) >= 15 else { return }

        let generic = isGenericExternalMetadata(title: media.title, artist: media.artist)
        guard generic || media.artworkImage == nil else { return }

        recognitionInFlight = true
        lastRecognitionAttempt = now
        AudioSpectrumService.shared.recognizeCurrentAudio(timeout: 8) { [weak self] match in
            Task { @MainActor in
                guard let self else { return }
                self.recognitionInFlight = false
                guard self.enabled, let media = self.media, let match else { return }

                let keepExistingMetadata = !self.isGenericExternalMetadata(title: media.title, artist: media.artist)
                let title = keepExistingMetadata ? media.title : match.title
                let artist = keepExistingMetadata ? media.artist : match.artist
                let sourceKey = [title, artist, media.album]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "|")
                media.acceptExternalMedia(title: title,
                                          artist: artist,
                                          album: media.album,
                                          duration: media.duration > 0 ? media.duration : nil,
                                          position: media.position >= 0 ? media.position : nil,
                                          playing: media.isPlaying,
                                          artworkURL: match.artworkURL?.absoluteString,
                                          sourceKey: sourceKey)
            }
        }
    }

    private func isGenericExternalMetadata(title: String, artist: String) -> Bool {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let artist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return title.isEmpty || title == "system audio" || title == "safari audio" || title == "connect a player" ||
            artist.isEmpty || artist == "system audio" || artist == "playing from safari" || artist == "playing from your mac"
    }

    private func isPCMAudible(_ snapshot: AudioSpectrumSnapshot, safariHint: Bool) -> Bool {
        guard snapshot.available else { return false }
        // Browser video, speech, and WebAudio can sit far below music-mastering levels. Mids are
        // especially useful for quiet speech, so blend the bands instead of relying on RMS alone.
        let signal = max(snapshot.overall, snapshot.mids * 0.82, snapshot.bass * 0.62, snapshot.treble * 0.68)
        return signal > (safariHint ? 0.016 : 0.040)
    }

    private func clearIfOwned() {
        guard ownsFallback, let media else { ownsFallback = false; return }
        if media.connectedApp == nil {
            media.isPlaying = false
            media.title = "System Audio"
            media.artist = "Waiting for audio from your Mac"
        }
        ownsFallback = false
    }
}

// MARK: - Custom CI runtime

struct HaloCustomCIInvalidPackage: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let issues: [HaloCIValidationIssue]
}

struct HaloCustomCICandidate {
    let package: HaloCIParsedPackage
    let priority: Double
    let manual: Bool
}

private struct HaloCustomCIStoredState: Codable {
    var boolValues: [String: Bool] = [:]
    var numberValues: [String: Double] = [:]
}

private struct HaloCustomCIPackagePreferences: Codable {
    var enabled = true
    var priority = 50.0
    var grantedPermissions: Set<String> = []
    var state = HaloCustomCIStoredState()
}

@MainActor
final class HaloCustomCIRuntimeStore: ObservableObject {
    static let shared = HaloCustomCIRuntimeStore()

    @Published private(set) var packages: [HaloCIParsedPackage] = []
    @Published private(set) var invalidPackages: [HaloCustomCIInvalidPackage] = []
    @Published private(set) var manualActivationID: String?
    @Published private(set) var contextRevision = 0
    @Published var notice: String?
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let preferencesKey = "HaloCustomCI.packagePreferences.v1"
    private var preferences: [String: HaloCustomCIPackagePreferences] = [:]
    private var suppressedPackageIDs = Set<String>()
    private var subscriptions = Set<AnyCancellable>()
    private weak var workspace: WorkspaceStore?

    private init() {
        if let data = defaults.data(forKey: preferencesKey),
           let saved = try? JSONDecoder().decode([String: HaloCustomCIPackagePreferences].self, from: data) {
            preferences = saved
        }
        reload()
    }

    private var installRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Halo", isDirectory: true).appendingPathComponent("CustomCI", isDirectory: true)
    }

    func attach(to workspace: WorkspaceStore) {
        if self.workspace === workspace, !subscriptions.isEmpty { return }
        self.workspace = workspace
        subscriptions.removeAll()

        workspace.media.$isPlaying.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        workspace.system.$battery.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        workspace.system.$charging.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        workspace.$runningApps.receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main).sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.contextDidChange() }.store(in: &subscriptions)
    }

    func detach() {
        subscriptions.removeAll()
        workspace = nil
        manualActivationID = nil
        suppressedPackageIDs.removeAll()
    }

    func reload() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)
            let urls = try fm.contentsOfDirectory(at: installRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "haloci" }
            var valid: [HaloCIParsedPackage] = []
            var invalid: [HaloCustomCIInvalidPackage] = []
            for url in urls {
                let report = HaloCIPackageValidator.validatePackage(at: url)
                if let package = report.package {
                    valid.append(package)
                } else {
                    invalid.append(HaloCustomCIInvalidPackage(name: url.deletingPathExtension().lastPathComponent, url: url, issues: report.issues))
                }
            }
            packages = valid.sorted { lhs, rhs in
                if lhs.manifest.name.localizedCaseInsensitiveCompare(rhs.manifest.name) == .orderedSame {
                    return lhs.manifest.id < rhs.manifest.id
                }
                return lhs.manifest.name.localizedCaseInsensitiveCompare(rhs.manifest.name) == .orderedAscending
            }
            invalidPackages = invalid.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if let manualActivationID, !packages.contains(where: { $0.manifest.id == manualActivationID }) { self.manualActivationID = nil }
            contextDidChange()
        } catch {
            errorMessage = "Could not load Custom CI packages: \(error.localizedDescription)"
        }
    }

    func chooseAndImportPackage() {
        let panel = NSOpenPanel()
        panel.title = "Import Custom CI"
        panel.message = "Choose an unpacked .haloCI package directory. Halo validates it before installation."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPackage(from: url)
    }

    func importPackage(from source: URL) {
        notice = nil; errorMessage = nil
        let sourceReport = HaloCIPackageValidator.validatePackage(at: source)
        guard let sourcePackage = sourceReport.package else {
            errorMessage = validationMessage(prefix: "Custom CI validation failed", issues: sourceReport.issues)
            return
        }

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: installRoot, withIntermediateDirectories: true)
            let destination = installRoot.appendingPathComponent(sourcePackage.manifest.id).appendingPathExtension("haloCI")
            if source.standardizedFileURL == destination.standardizedFileURL { reload(); return }

            let staging = installRoot.appendingPathComponent(".staging-\(UUID().uuidString)").appendingPathExtension("haloCI")
            let backup = installRoot.appendingPathComponent(".backup-\(UUID().uuidString)")
            defer { try? fm.removeItem(at: staging); try? fm.removeItem(at: backup) }
            try fm.copyItem(at: source, to: staging)
            let stagedReport = HaloCIPackageValidator.validatePackage(at: staging)
            guard stagedReport.package != nil else { throw HaloCustomCIImportError.invalid(validationMessage(prefix: "Staged package validation failed", issues: stagedReport.issues)) }

            if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: backup) }
            do {
                try fm.moveItem(at: staging, to: destination)
                if fm.fileExists(atPath: backup.path) { try? fm.removeItem(at: backup) }
            } catch {
                if fm.fileExists(atPath: backup.path), !fm.fileExists(atPath: destination.path) { try? fm.moveItem(at: backup, to: destination) }
                throw error
            }

            reload()
            notice = "Installed \(sourcePackage.manifest.name) \(sourcePackage.manifest.version). Permissions remain user-controlled."
        } catch let error as HaloCustomCIImportError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not install Custom CI: \(error.localizedDescription)"
        }
    }

    func removePackage(_ id: String) {
        guard let package = package(id: id) else { return }
        do {
            try FileManager.default.removeItem(at: package.rootURL)
            preferences.removeValue(forKey: id)
            suppressedPackageIDs.remove(id)
            if manualActivationID == id { manualActivationID = nil }
            persistPreferences()
            reload()
        } catch { errorMessage = "Could not remove \(package.manifest.name): \(error.localizedDescription)" }
    }

    func package(id: String) -> HaloCIParsedPackage? { packages.first { $0.manifest.id == id } }
    func isEnabled(_ id: String) -> Bool { preferences[id]?.enabled ?? true }
    func priority(_ id: String) -> Double { min(100, max(0, preferences[id]?.priority ?? 50)) }
    func grantedPermissions(_ id: String) -> Set<String> { preferences[id]?.grantedPermissions ?? [] }
    func requestedPermissions(_ package: HaloCIParsedPackage) -> [String] {
        Array(Set(package.manifest.permissions)).sorted()
    }
    func hasPermission(_ id: String, _ permission: String) -> Bool { grantedPermissions(id).contains(permission) }

    func setEnabled(_ enabled: Bool, packageID: String) {
        mutatePreferences(packageID) { $0.enabled = enabled }
        if !enabled {
            if manualActivationID == packageID { manualActivationID = nil }
            suppressedPackageIDs.remove(packageID)
        }
        contextDidChange()
    }

    func setPriority(_ priority: Double, packageID: String) {
        mutatePreferences(packageID) { $0.priority = min(100, max(0, priority)) }
        contextDidChange()
    }

    func setPermission(_ permission: String, granted: Bool, packageID: String) {
        guard let package = package(id: packageID), requestedPermissions(package).contains(permission), HaloCISDK.supportedPermissions.contains(permission) else { return }
        mutatePreferences(packageID) { prefs in
            if granted { prefs.grantedPermissions.insert(permission) } else { prefs.grantedPermissions.remove(permission) }
        }
        contextDidChange()
    }

    func requestManualActivation(_ id: String) {
        guard package(id: id) != nil, isEnabled(id) else { return }
        suppressedPackageIDs.remove(id)
        manualActivationID = id
        contextRevision &+= 1
        NotificationCenter.default.post(name: .init("HaloCustomCIOpenRequested"), object: id)
    }

    func clearManualActivation() {
        guard manualActivationID != nil else { return }
        manualActivationID = nil
        contextRevision &+= 1
    }

    func dismiss(_ id: String) {
        if manualActivationID == id { manualActivationID = nil }
        suppressedPackageIDs.insert(id)
        contextRevision &+= 1
        NotificationCenter.default.post(name: .init("HaloCustomCICloseRequested"), object: id)
    }

    func activeCandidate(workspace: WorkspaceStore, globalDisabled: Bool,
                         blockingPriority: Double? = nil) -> HaloCustomCICandidate? {
        guard !globalDisabled else { return nil }
        let floor = blockingPriority ?? -Double.infinity
        let snapshot = triggerSnapshot(workspace: workspace)
        let ordered = packages.filter { package in
            let id = package.manifest.id
            return isEnabled(id) && priority(id) >= floor &&
                (!suppressedPackageIDs.contains(id) || manualActivationID == id)
        }.sorted { lhs, rhs in
            let lp = priority(lhs.manifest.id), rp = priority(rhs.manifest.id)
            if lp != rp { return lp > rp }
            let lm = manualActivationID == lhs.manifest.id, rm = manualActivationID == rhs.manifest.id
            if lm != rm { return lm }
            return lhs.manifest.id < rhs.manifest.id
        }

        // Arbitration happens before trigger evaluation. Once a higher-priority package
        // claims the surface, lower-priority packages are not evaluated at all.
        for package in ordered {
            let id = package.manifest.id
            if manualActivationID == id {
                return HaloCustomCICandidate(package: package, priority: priority(id), manual: true)
            }
            if HaloCITriggerEvaluator.matches(package.triggers, snapshot: snapshot,
                                              grantedPermissions: grantedPermissions(id)) {
                return HaloCustomCICandidate(package: package, priority: priority(id), manual: false)
            }
        }
        return nil
    }

    func dataBus(for package: HaloCIParsedPackage, workspace: WorkspaceStore, expanded: Bool) -> [String: String] {
        let grants = grantedPermissions(package.manifest.id)
        var data: [String: String] = [
            "halo.surface.state": expanded ? "expanded" : "closed",
            "halo.surface.isExpanded": expanded ? "true" : "false",
            "system.battery.isCharging": workspace.system.charging ? "true" : "false",
            "system.lowPowerMode": workspace.system.lowPower ? "true" : "false",
            "system.cpu.usedPercent": format(workspace.system.cpuUsage),
            "system.memory.usedPercent": format(workspace.system.memoryUsage),
            "system.storage.usedPercent": format(workspace.system.diskUsage)
        ]
        if let battery = workspace.system.battery { data["system.battery.level"] = String(battery) }
        if grants.contains("Media.ReadState") {
            data["media.isPlaying"] = workspace.media.isPlaying ? "true" : "false"
            data["media.title"] = workspace.media.title
            data["media.artist"] = workspace.media.artist
            data["media.album"] = workspace.media.album
        }
        if grants.contains("Applications.Observe") {
            let app = NSWorkspace.shared.frontmostApplication
            data["apps.active.bundleID"] = app?.bundleIdentifier ?? ""
            data["apps.active.name"] = app?.localizedName ?? ""
        }
        return data
    }

    func boolState(packageID: String, key: String, default defaultValue: Bool) -> Bool {
        preferences[packageID]?.state.boolValues[key] ?? defaultValue
    }
    func setBoolState(_ value: Bool, packageID: String, key: String) {
        mutateState(packageID) { $0.boolValues[key] = value }
    }
    func numberState(packageID: String, key: String, default defaultValue: Double) -> Double {
        preferences[packageID]?.state.numberValues[key] ?? defaultValue
    }
    func setNumberState(_ value: Double, packageID: String, key: String) {
        guard value.isFinite else { return }
        mutateState(packageID) { $0.numberValues[key] = value }
    }

    func assetURL(packageID: String, source: String) -> URL? {
        guard source.hasPrefix("asset:"), let package = package(id: packageID) else { return nil }
        let relative = String(source.dropFirst("asset:".count))
        guard !relative.hasPrefix("/"), !relative.contains("..") else { return nil }
        let url = package.rootURL.appendingPathComponent(relative).standardizedFileURL
        guard url.path.hasPrefix(package.rootURL.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func perform(_ action: HaloCIActionDescriptor, package: HaloCIParsedPackage, workspace: WorkspaceStore, data: [String: String]) {
        let id = package.manifest.id
        if let permission = HaloCISDK.permissionForAction(action.id), !hasPermission(id, permission) {
            errorMessage = "\(package.manifest.name) needs \(permission) before it can perform \(action.id)."
            return
        }
        let value = HaloCIBindingResolver.resolve(action.value ?? action.arguments?["value"] ?? action.arguments?["url"] ?? "", data: data)
        switch action.id {
        case "halo.ci.close": dismiss(id)
        case "clipboard.copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        case "url.open":
            guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), ["https", "http", "mailto"].contains(scheme) else {
                errorMessage = "Custom CI tried to open an unsupported URL."; return
            }
            let alert = NSAlert()
            alert.messageText = "Allow \(package.manifest.name) to open this URL?"
            alert.informativeText = url.absoluteString
            alert.addButton(withTitle: "Open")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
        case "media.playPause": workspace.media.perform("playpause", app: workspace.settings.mediaApp)
        case "media.next": workspace.media.perform("next track", app: workspace.settings.mediaApp)
        case "media.previous": workspace.media.perform("previous track", app: workspace.settings.mediaApp)
        default: errorMessage = "Unsupported Custom CI action: \(action.id)"
        }
    }

    private func contextDidChange() {
        if let workspace, !suppressedPackageIDs.isEmpty {
            let snapshot = triggerSnapshot(workspace: workspace)
            let removable = suppressedPackageIDs.filter { id in
                guard let package = package(id: id) else { return true }
                return !HaloCITriggerEvaluator.matches(package.triggers, snapshot: snapshot, grantedPermissions: grantedPermissions(id))
            }
            suppressedPackageIDs.subtract(removable)
        }
        contextRevision &+= 1
    }

    private func triggerSnapshot(workspace: WorkspaceStore) -> HaloCITriggerSnapshot {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: Date())
        return HaloCITriggerSnapshot(
            mediaIsPlaying: workspace.media.isPlaying,
            activeApplicationBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
            batteryLevel: workspace.system.battery.map(Double.init),
            charging: workspace.system.charging,
            minuteOfDay: (components.hour ?? 0) * 60 + (components.minute ?? 0)
        )
    }

    private func mutatePreferences(_ id: String, _ body: (inout HaloCustomCIPackagePreferences) -> Void) {
        var value = preferences[id] ?? HaloCustomCIPackagePreferences()
        body(&value)
        preferences[id] = value
        persistPreferences()
        objectWillChange.send()
    }

    private func mutateState(_ id: String, _ body: (inout HaloCustomCIStoredState) -> Void) {
        var prefs = preferences[id] ?? HaloCustomCIPackagePreferences()
        let previous = prefs.state
        body(&prefs.state)
        let totalKeys = prefs.state.boolValues.count + prefs.state.numberValues.count
        guard totalKeys <= 64, let encoded = try? JSONEncoder().encode(prefs.state), encoded.count <= 32_768 else {
            prefs.state = previous
            errorMessage = "Custom CI state quota exceeded (64 keys / 32 KB)."
            return
        }
        preferences[id] = prefs
        persistPreferences()
        objectWillChange.send()
    }

    private func persistPreferences() {
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: preferencesKey) }
    }

    private func validationMessage(prefix: String, issues: [HaloCIValidationIssue]) -> String {
        let details = issues.filter { $0.severity == .error }.prefix(4).map { "\($0.path): \($0.message)" }.joined(separator: "\n")
        return details.isEmpty ? prefix : prefix + "\n" + details
    }
    private func format(_ value: Double) -> String { String(format: "%.2f", value) }
}

private enum HaloCustomCIImportError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): return message } }
}
