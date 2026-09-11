import AppKit
import SwiftUI
import Combine
import UserNotifications
import Darwin
import ObjectiveC.runtime

@MainActor
final class WorkspaceStore: ObservableObject, LiveActivityProvider {
    static let systemAudioSource = "com.redstoneinvente.halo.system-audio"

    @Published var settings: WorkspaceSettings { didSet {
        schedulePersistence()
        updateHotkey()
        if oldValue.mediaApp != settings.mediaApp || oldValue.automaticMedia != settings.automaticMedia { media.disconnect() }
        updateArtworkPreference()
        hudEngine?.configurationDidChange()
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
    let calendar = CalendarService()
    let clipboard = ClipboardService()
    let system = SystemService()
    let audio = AudioService()
    let media = MediaService()
    let capture = CaptureService()
    @Published var stopwatchStart: Date?
    @Published var stopwatchElapsed: TimeInterval = 0
    func toggleStopwatch() {
        if let start = stopwatchStart { stopwatchElapsed += Date().timeIntervalSince(start); stopwatchStart = nil }
        else { stopwatchStart = Date() }
    }
    private let hotkey = HotkeyService()
    private let defaults: UserDefaults
    private var ticker: AnyCancellable?
    private var subscriptions = Set<AnyCancellable>()
    private var matchedRules = Set<UUID>()
    private var tick = 0
    private var installedHotkey = ""
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
        let layouts = [effectiveLayout] + settings.displays.compactMap { $0.enabled ? $0.layout : nil }
        media.setArtworkEnabled(layouts.contains { layout in
            let context = layout.contextMusic
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
            return contextNeedsPalette || hudNeedsPalette ||
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
        if DemoMarketingStudio.shared.isEnabled {
            systemAudioFallback?.setEnabled(false)
            DemoMarketingStudio.shared.apply(to: self)
            return
        }
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
        evaluateSchedules(); system.refresh(); audio.refresh(); refreshApps(); updateHotkey()
        pollMedia()
        DemoMarketingStudio.shared.attach(workspace: self)
        ticker = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            self.tick += 1
            self.pollMedia()
            let minute = Int(Date().timeIntervalSince1970 / 60)
            if self.lastScheduleMinute != minute { self.lastScheduleMinute = minute; self.evaluateSchedules() }
            self.clipboard.poll(enabled: self.settings.clipboardEnabled, excluded: self.settings.clipboardExcludedApps)
            if self.tick % 5 == 0 {
                if DemoMarketingStudio.shared.isEnabled { DemoMarketingStudio.shared.apply(to: self) }
                else { self.system.refresh() }
                self.evaluateRules()
            }
            if self.tick % 30 == 0, self.settings.layout.enabled.contains(.calendar) { self.calendar.refresh() }
        }
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.disableLegacyHUDRenderer() }
            .store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
                self?.refreshApps(); self?.evaluateRules(); self?.evaluateSchedules(); self?.hudEngine?.configurationDidChange()
                self?.pollMedia()
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
    func stop() { pendingSave?.cancel(); persist(); ticker?.cancel(); subscriptions.removeAll(); systemAudioFallback?.stop(); systemAudioFallback = nil; hudEngine?.stop(); hudEngine = nil; hotkey.stop(); clipboard.reset(); media.disconnect() }
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

private struct MediaRemoteNowPlayingSnapshot {
    let title: String
    let artist: String
    let album: String
    let playing: Bool
    let duration: Double?
    let elapsed: Double?
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

            guard let title = firstString(["kMRMediaRemoteNowPlayingInfoTitle", "title"]) else {
                completion(nil)
                return
            }
            let artist = firstString(["kMRMediaRemoteNowPlayingInfoArtist", "artist"]) ?? ""
            let album = firstString(["kMRMediaRemoteNowPlayingInfoAlbum", "album"]) ?? ""
            let duration = firstDouble(["kMRMediaRemoteNowPlayingInfoDuration", "duration"])
            let elapsed = firstDouble(["kMRMediaRemoteNowPlayingInfoElapsedTime", "elapsedTime"])
            let rate = firstDouble(["kMRMediaRemoteNowPlayingInfoPlaybackRate", "playbackRate"])
            completion(MediaRemoteNowPlayingSnapshot(title: title, artist: artist, album: album,
                                                     playing: (rate ?? 0) > 0.001,
                                                     duration: duration, elapsed: elapsed))
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
    private var lastRemoteMetadata = Date.distantPast
    private var remoteRequestInFlight = false

    init(media: MediaService) { self.media = media }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        AudioSpectrumService.shared.setActive(enabled)
        if !enabled { clearIfOwned() }
    }

    func refresh() {
        guard enabled, let media else { return }
        if media.connectedApp != nil && media.isPlaying {
            ownsFallback = false
            return
        }

        requestMediaRemoteMetadata()

        let audioSnapshot = AudioSpectrumService.shared.snapshot()
        let audibleNow = audioSnapshot.available && audioSnapshot.overall > 0.045
        if audibleNow { lastHeard = Date() }
        let withinReleaseWindow = Date().timeIntervalSince(lastHeard) < 2.75
        let remoteMetadataFresh = Date().timeIntervalSince(lastRemoteMetadata) < 5.0
        let systemAudioPlaying = audibleNow || (ownsFallback && withinReleaseWindow)

        if systemAudioPlaying {
            if media.connectedApp == nil {
                if !remoteMetadataFresh {
                    media.title = "System Audio"
                    media.artist = "Playing from your Mac"
                }
                media.isPlaying = true
                media.error = nil
                ownsFallback = true
            }
            return
        }

        if ownsFallback && remoteMetadataFresh && media.connectedApp == nil {
            media.isPlaying = false
            return
        }

        clearIfOwned()
    }

    func stop() {
        enabled = false
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

                self.lastRemoteMetadata = Date()
                self.ownsFallback = true
                media.title = snapshot.title
                if !snapshot.artist.isEmpty { media.artist = snapshot.artist }
                else if !snapshot.album.isEmpty { media.artist = snapshot.album }
                else { media.artist = "System Audio" }
                let audio = AudioSpectrumService.shared.snapshot()
                media.isPlaying = snapshot.playing || (audio.available && audio.overall > 0.045)
                media.error = nil
            }
        }
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

private enum DemoAppleScriptBridge {
    private static var installed = false
    static func install() {
        guard !installed else { return }
        installed = true
        guard let original = class_getInstanceMethod(NSAppleScript.self, #selector(NSAppleScript.executeAndReturnError(_:))),
              let replacement = class_getInstanceMethod(NSAppleScript.self, #selector(NSAppleScript.halo_demoExecuteAndReturnError(_:))) else { return }
        method_exchangeImplementations(original, replacement)
    }
}

private extension NSAppleScript {
    @objc func halo_demoExecuteAndReturnError(_ errorInfo: AutoreleasingUnsafeMutablePointer<NSDictionary?>?) -> NSAppleEventDescriptor {
        guard UserDefaults.standard.bool(forKey: DemoMarketingStudio.enabledKey), let source = self.source else {
            return halo_demoExecuteAndReturnError(errorInfo)
        }

        let descriptor: NSAppleEventDescriptor?
        if Thread.isMainThread {
            descriptor = MainActor.assumeIsolated {
                DemoMarketingStudio.shared.appleEventDescriptor(for: source)
            }
        } else {
            descriptor = DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    DemoMarketingStudio.shared.appleEventDescriptor(for: source)
                }
            }
        }

        if let descriptor {
            errorInfo?.pointee = nil
            return descriptor
        }
        return halo_demoExecuteAndReturnError(errorInfo)
    }
}

@MainActor
final class DemoMarketingStudio {
    static let shared = DemoMarketingStudio()

    static let enabledKey = "HaloMarketingDemoEnabled"
    static let titleKey = "HaloMarketingDemoTitle"
    static let artistKey = "HaloMarketingDemoArtist"
    static let albumKey = "HaloMarketingDemoAlbum"
    static let lyricsKey = "HaloMarketingDemoLyrics"
    static let durationKey = "HaloMarketingDemoDuration"
    static let positionKey = "HaloMarketingDemoPosition"
    static let artworkStyleKey = "HaloMarketingDemoArtworkStyle"
    static let playingKey = "HaloMarketingDemoPlaying"
    static let batteryKey = "HaloMarketingDemoBattery"
    static let chargingKey = "HaloMarketingDemoCharging"
    static let onBatteryKey = "HaloMarketingDemoOnBattery"
    static let lowPowerKey = "HaloMarketingDemoLowPower"

    private weak var workspace: WorkspaceStore?
    private var window: NSWindow?
    private var playbackAnchorDate = Date()
    private var playbackAnchorPosition = 34.0
    private var previewCache: [String: NSImage] = [:]
    private var pngCache: [String: Data] = [:]

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    private let defaultLyrics = """
    [00:00.00]City lights dissolve into the blue
    [00:06.50]Every quiet signal leads me back to you
    [00:13.20]We trace the skyline where the colors glow
    [00:20.10]Hold the moment softly, let the afterglow
    [00:27.00]Nothing has to hurry, nothing has to fade
    [00:34.30]Stay inside the halo that the night has made
    [00:42.10]Neon on the water, silver in the air
    [00:50.00]Every little frequency says you're still there
    """

    private init() {
        UserDefaults.standard.register(defaults: [
            Self.enabledKey: false,
            Self.titleKey: "Neon Afterglow",
            Self.artistKey: "Luma Vale",
            Self.albumKey: "Halo Nights",
            Self.lyricsKey: defaultLyrics,
            Self.durationKey: 188.0,
            Self.positionKey: 34.0,
            Self.artworkStyleKey: "Neon",
            Self.playingKey: true,
            Self.batteryKey: 78.0,
            Self.chargingKey: true,
            Self.onBatteryKey: false,
            Self.lowPowerKey: false
        ])
        playbackAnchorPosition = UserDefaults.standard.double(forKey: Self.positionKey)
        playbackAnchorDate = Date()
        DemoAppleScriptBridge.install()
    }

    func attach(workspace: WorkspaceStore) {
        self.workspace = workspace
        syncPlaybackAnchor(to: UserDefaults.standard.double(forKey: Self.positionKey))
        show()
        if isEnabled { apply(to: workspace) }
    }

    func show() {
        guard let workspace else { return }
        if window == nil {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 470, height: 840),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Halo · Marketing Demo Studio"
            panel.contentMinSize = NSSize(width: 430, height: 640)
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: DemoMarketingView(workspace: workspace))
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func currentPlaybackPosition(at now: Date = Date()) -> Double {
        let defaults = UserDefaults.standard
        let duration = max(1, defaults.double(forKey: Self.durationKey))
        guard defaults.bool(forKey: Self.playingKey) else {
            return min(duration, max(0, playbackAnchorPosition))
        }
        let elapsed = max(0, now.timeIntervalSince(playbackAnchorDate))
        return (playbackAnchorPosition + elapsed).truncatingRemainder(dividingBy: duration)
    }

    func syncPlaybackAnchor(to position: Double) {
        let duration = max(1, UserDefaults.standard.double(forKey: Self.durationKey))
        playbackAnchorPosition = min(duration, max(0, position))
        playbackAnchorDate = Date()
        UserDefaults.standard.set(playbackAnchorPosition, forKey: Self.positionKey)
    }

    func apply(to workspace: WorkspaceStore) {
        guard isEnabled else { return }
        let defaults = UserDefaults.standard
        workspace.media.applyDemoSnapshot(
            title: defaults.string(forKey: Self.titleKey) ?? "Neon Afterglow",
            artist: defaults.string(forKey: Self.artistKey) ?? "Luma Vale",
            playing: defaults.bool(forKey: Self.playingKey)
        )
        workspace.system.battery = Int(defaults.double(forKey: Self.batteryKey).rounded())
        workspace.system.charging = defaults.bool(forKey: Self.chargingKey)
        workspace.system.onBattery = defaults.bool(forKey: Self.onBatteryKey)
        workspace.system.lowPower = defaults.bool(forKey: Self.lowPowerKey)
    }

    func clear(from workspace: WorkspaceStore) {
        syncPlaybackAnchor(to: currentPlaybackPosition())
        workspace.media.disconnect()
        workspace.system.refresh()
    }

    func prepareMusicHero(in workspace: WorkspaceStore) {
        var context = workspace.settings.layout.contextMusic ?? ContextMusicOptions()
        context.enabled = true
        context.showArtwork = true
        context.foregroundArtwork = .vinyl
        context.showTitle = true
        context.showArtist = true
        context.showControls = true
        context.showVisualizer = true
        context.showLyrics = true
        context.lyricsOnline = false
        context.layoutMode = .hero
        context.artworkSize = 154
        context.fontSize = 24
        context.lyricFontSize = 18
        context.songTextColors = true
        context.songControlColors = true
        context.songVisualizerColors = true
        context.songBackgroundColors = true
        workspace.settings.layout.contextMusic = context
        apply(to: workspace)
    }

    func handleMediaCommand(_ command: String, media: MediaService) {
        let defaults = UserDefaults.standard
        let current = currentPlaybackPosition()
        switch command {
        case "playpause":
            let wasPlaying = defaults.bool(forKey: Self.playingKey)
            syncPlaybackAnchor(to: current)
            defaults.set(!wasPlaying, forKey: Self.playingKey)
            playbackAnchorDate = Date()
        case "next track":
            setPreset(index: 1)
        case "previous track":
            setPreset(index: 0)
        default: break
        }
        if let workspace { apply(to: workspace) }
        else {
            media.applyDemoSnapshot(title: defaults.string(forKey: Self.titleKey) ?? "Neon Afterglow",
                                    artist: defaults.string(forKey: Self.artistKey) ?? "Luma Vale",
                                    playing: defaults.bool(forKey: Self.playingKey))
        }
    }

    private func setPreset(index: Int) {
        let defaults = UserDefaults.standard
        if index == 0 {
            defaults.set("Neon Afterglow", forKey: Self.titleKey)
            defaults.set("Luma Vale", forKey: Self.artistKey)
            defaults.set("Halo Nights", forKey: Self.albumKey)
            defaults.set("Neon", forKey: Self.artworkStyleKey)
            defaults.set(188.0, forKey: Self.durationKey)
            syncPlaybackAnchor(to: 34.0)
        } else {
            defaults.set("Glass Horizon", forKey: Self.titleKey)
            defaults.set("Aster & Co.", forKey: Self.artistKey)
            defaults.set("Refractions", forKey: Self.albumKey)
            defaults.set("Ocean", forKey: Self.artworkStyleKey)
            defaults.set(214.0, forKey: Self.durationKey)
            syncPlaybackAnchor(to: 72.0)
        }
        defaults.set(true, forKey: Self.playingKey)
        playbackAnchorDate = Date()
    }

    func appleEventDescriptor(for script: String) -> NSAppleEventDescriptor? {
        guard isEnabled else { return nil }
        let defaults = UserDefaults.standard
        let lower = script.lowercased()

        if lower.contains("raw data of artwork 1 of current track") {
            return descriptorList([
                NSAppleEventDescriptor(string: "halo-demo-track"),
                NSAppleEventDescriptor(descriptorType: 0x74647461, data: artworkData())
            ])
        }

        if lower.contains("get lyrics of current track") {
            return NSAppleEventDescriptor(string: defaults.string(forKey: Self.lyricsKey) ?? defaultLyrics)
        }

        if lower.contains("player position as real") && lower.contains("duration of current track as real") {
            if let range = lower.range(of: "set player position to ") {
                let suffix = lower[range.upperBound...]
                let number = suffix.prefix { $0.isNumber || $0 == "." || $0 == "-" }
                if let value = Double(number) { syncPlaybackAnchor(to: value) }
            }
            let duration = max(1, defaults.double(forKey: Self.durationKey))
            let position = currentPlaybackPosition()
            return descriptorList([NSAppleEventDescriptor(double: position), NSAppleEventDescriptor(double: duration)])
        }

        if lower.contains("player state") && lower.contains("current track") {
            return descriptorList([
                NSAppleEventDescriptor(string: defaults.string(forKey: Self.titleKey) ?? "Neon Afterglow"),
                NSAppleEventDescriptor(string: defaults.string(forKey: Self.artistKey) ?? "Luma Vale"),
                NSAppleEventDescriptor(boolean: defaults.bool(forKey: Self.playingKey)),
                NSAppleEventDescriptor(string: "halo-demo-track")
            ])
        }

        return nil
    }

    private var artworkRevision: String {
        let defaults = UserDefaults.standard
        let style = defaults.string(forKey: Self.artworkStyleKey) ?? "Neon"
        let title = defaults.string(forKey: Self.titleKey) ?? "Neon Afterglow"
        return style + "|" + title
    }

    private func descriptorList(_ items: [NSAppleEventDescriptor?]) -> NSAppleEventDescriptor {
        let list = NSAppleEventDescriptor.list()
        for (index, item) in items.compactMap({ $0 }).enumerated() { list.insert(item, at: index + 1) }
        return list
    }

    func artworkPreview(style: String) -> NSImage {
        let title = UserDefaults.standard.string(forKey: Self.titleKey) ?? "Neon Afterglow"
        let key = style + "|" + title
        if let cached = previewCache[key] { return cached }
        let image = makeArtwork(style: style, title: title)
        previewCache[key] = image
        return image
    }

    private func artworkData() -> Data {
        let key = artworkRevision
        if let cached = pngCache[key] { return cached }
        let defaults = UserDefaults.standard
        let image = artworkPreview(style: defaults.string(forKey: Self.artworkStyleKey) ?? "Neon")
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.92]) else {
            return image.tiffRepresentation ?? Data()
        }
        pngCache[key] = png
        return png
    }

    private func makeArtwork(style: String, title: String) -> NSImage {
        let size = NSSize(width: 640, height: 640)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = NSRect(origin: .zero, size: size)
        let inset = canvas.insetBy(dx: 26, dy: 26)

        switch style {
        case "Sunset":
            NSGradient(colors: [
                NSColor(calibratedRed: 0.10, green: 0.04, blue: 0.16, alpha: 1),
                NSColor(calibratedRed: 0.64, green: 0.12, blue: 0.28, alpha: 1),
                NSColor(calibratedRed: 0.98, green: 0.50, blue: 0.24, alpha: 1)
            ])?.draw(in: canvas, angle: 88)
            let sun = NSBezierPath(ovalIn: NSRect(x: 170, y: 204, width: 300, height: 300))
            NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.55, alpha: 0.92).setFill(); sun.fill()
            for y in stride(from: 214.0, through: 408.0, by: 24.0) {
                NSColor(calibratedWhite: 0.08, alpha: 0.32).setFill()
                NSBezierPath(rect: NSRect(x: 150, y: y, width: 340, height: 8)).fill()
            }
            let horizon = NSBezierPath()
            horizon.move(to: NSPoint(x: 0, y: 170)); horizon.line(to: NSPoint(x: 640, y: 170)); horizon.line(to: NSPoint(x: 640, y: 0)); horizon.line(to: NSPoint(x: 0, y: 0)); horizon.close()
            NSColor(calibratedRed: 0.04, green: 0.02, blue: 0.07, alpha: 0.86).setFill(); horizon.fill()
            for i in 0..<5 {
                let y = CGFloat(120 - i * 18)
                let wave = NSBezierPath()
                wave.move(to: NSPoint(x: 0, y: y))
                wave.curve(to: NSPoint(x: 640, y: y - 5), controlPoint1: NSPoint(x: 180, y: y + 28), controlPoint2: NSPoint(x: 430, y: y - 30))
                NSColor.white.withAlphaComponent(0.08 + CGFloat(i) * 0.015).setStroke(); wave.lineWidth = 2; wave.stroke()
            }
        case "Ocean":
            NSGradient(colors: [
                NSColor(calibratedRed: 0.015, green: 0.055, blue: 0.15, alpha: 1),
                NSColor(calibratedRed: 0.02, green: 0.31, blue: 0.48, alpha: 1),
                NSColor(calibratedRed: 0.09, green: 0.74, blue: 0.72, alpha: 1)
            ])?.draw(in: canvas, angle: -58)
            for i in 0..<7 {
                let path = NSBezierPath()
                let y = CGFloat(110 + i * 44)
                path.move(to: NSPoint(x: -30, y: y))
                path.curve(to: NSPoint(x: 680, y: y + CGFloat((i % 2) * 10 - 5)), controlPoint1: NSPoint(x: 170, y: y + 62), controlPoint2: NSPoint(x: 420, y: y - 54))
                NSColor.white.withAlphaComponent(0.055 + CGFloat(i) * 0.014).setStroke(); path.lineWidth = CGFloat(2 + i % 3); path.stroke()
            }
            let moon = NSBezierPath(ovalIn: NSRect(x: 390, y: 365, width: 132, height: 132))
            NSColor.white.withAlphaComponent(0.92).setFill(); moon.fill()
            let cut = NSBezierPath(ovalIn: NSRect(x: 425, y: 390, width: 126, height: 126))
            NSColor(calibratedRed: 0.03, green: 0.23, blue: 0.34, alpha: 1).setFill(); cut.fill()
            for i in 0..<26 {
                let x = CGFloat((i * 97) % 610 + 15)
                let y = CGFloat((i * 151) % 600 + 20)
                NSColor.white.withAlphaComponent(i % 4 == 0 ? 0.72 : 0.34).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: i % 4 == 0 ? 3 : 1.5, height: i % 4 == 0 ? 3 : 1.5)).fill()
            }
        default:
            NSGradient(colors: [
                NSColor(calibratedRed: 0.025, green: 0.018, blue: 0.075, alpha: 1),
                NSColor(calibratedRed: 0.18, green: 0.045, blue: 0.38, alpha: 1),
                NSColor(calibratedRed: 0.76, green: 0.10, blue: 0.48, alpha: 1)
            ])?.draw(in: canvas, angle: -35)
            NSGraphicsContext.saveGraphicsState()
            let glowShadow = NSShadow(); glowShadow.shadowColor = NSColor(calibratedRed: 0.64, green: 0.28, blue: 1, alpha: 0.85); glowShadow.shadowBlurRadius = 36; glowShadow.set()
            for i in 0..<4 {
                let r = CGFloat(470 - i * 72)
                let ring = NSBezierPath(ovalIn: NSRect(x: (640 - r) / 2, y: (640 - r) / 2 + CGFloat(i * 8), width: r, height: r))
                NSColor(calibratedRed: 0.78, green: 0.30, blue: 1, alpha: 0.11 + CGFloat(i) * 0.045).setStroke(); ring.lineWidth = CGFloat(7 - i); ring.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
            let slash = NSBezierPath()
            slash.move(to: NSPoint(x: 80, y: 160)); slash.line(to: NSPoint(x: 560, y: 470))
            NSColor.white.withAlphaComponent(0.15).setStroke(); slash.lineWidth = 2; slash.stroke()
            for i in 0..<18 {
                let x = CGFloat((i * 71) % 560 + 38)
                let y = CGFloat((i * 123) % 540 + 50)
                NSColor.white.withAlphaComponent(i % 3 == 0 ? 0.42 : 0.17).setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: i % 3 == 0 ? 4 : 2, height: i % 3 == 0 ? 4 : 2)).fill()
            }
        }

        NSColor.black.withAlphaComponent(0.12).setStroke()
        let border = NSBezierPath(roundedRect: inset, xRadius: 42, yRadius: 42); border.lineWidth = 2; border.stroke()

        let subtitle = style.uppercased() + " / HALO SESSION"
        let subtitleStyle = NSMutableParagraphStyle(); subtitleStyle.alignment = .left
        NSString(string: subtitle).draw(in: NSRect(x: 48, y: 54, width: 540, height: 28), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.62),
            .paragraphStyle: subtitleStyle,
            .kern: 2.6
        ])

        let titleStyle = NSMutableParagraphStyle(); titleStyle.alignment = .left
        let displayTitle = title.isEmpty ? "HALO" : title
        NSString(string: displayTitle).draw(in: NSRect(x: 46, y: 92, width: 530, height: 150), withAttributes: [
            .font: NSFont.systemFont(ofSize: displayTitle.count > 18 ? 52 : 64, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.96),
            .paragraphStyle: titleStyle,
            .kern: -1.2
        ])

        NSString(string: "REDSTONEINVENTE / DEMO EDITION").draw(in: NSRect(x: 48, y: 558, width: 530, height: 26), withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.45),
            .kern: 1.8
        ])
        return image
    }
}

@MainActor
private struct DemoMarketingView: View {
    @ObservedObject var workspace: WorkspaceStore

    @AppStorage(DemoMarketingStudio.enabledKey) private var enabled = false
    @AppStorage(DemoMarketingStudio.titleKey) private var title = "Neon Afterglow"
    @AppStorage(DemoMarketingStudio.artistKey) private var artist = "Luma Vale"
    @AppStorage(DemoMarketingStudio.albumKey) private var album = "Halo Nights"
    @AppStorage(DemoMarketingStudio.lyricsKey) private var lyrics = ""
    @AppStorage(DemoMarketingStudio.durationKey) private var duration = 188.0
    @AppStorage(DemoMarketingStudio.positionKey) private var position = 34.0
    @AppStorage(DemoMarketingStudio.artworkStyleKey) private var artworkStyle = "Neon"
    @AppStorage(DemoMarketingStudio.playingKey) private var playing = true
    @AppStorage(DemoMarketingStudio.batteryKey) private var battery = 78.0
    @AppStorage(DemoMarketingStudio.chargingKey) private var charging = true
    @AppStorage(DemoMarketingStudio.onBatteryKey) private var onBattery = false
    @AppStorage(DemoMarketingStudio.lowPowerKey) private var lowPower = false

    @State private var activityTitle = "Focus Session"
    @State private var activityDetail = "Deep work · 18 min remaining"
    @State private var activityProgress = 0.64
    @State private var hudValue = 0.72

    var body: some View {
        Form {
            Section("Marketing Demo") {
                Toggle("Enable dummy data", isOn: $enabled)
                    .onChange(of: enabled) { value in
                        if value {
                            DemoMarketingStudio.shared.syncPlaybackAnchor(to: position)
                            apply()
                        } else { DemoMarketingStudio.shared.clear(from: workspace) }
                    }
                Text("This panel exists only on the Demo branch. Music metadata, artwork, lyrics, playback progress and system state are synthetic and repeatable for capture.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Music") {
                TextField("Track title", text: $title)
                TextField("Artist", text: $artist)
                TextField("Album", text: $album)

                Text("Cover art").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(["Neon", "Sunset", "Ocean"], id: \.self) { style in
                        Button {
                            artworkStyle = style
                            workspace.media.disconnect()
                            DispatchQueue.main.async { apply() }
                        } label: {
                            VStack(spacing: 6) {
                                Image(nsImage: DemoMarketingStudio.shared.artworkPreview(style: style))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 92, height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(artworkStyle == style ? Color.accentColor : Color.white.opacity(0.14), lineWidth: artworkStyle == style ? 2 : 1)
                                    }
                                    .shadow(radius: artworkStyle == style ? 8 : 2)
                                Text(style).font(.caption2).fontWeight(artworkStyle == style ? .semibold : .regular)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle("Playing", isOn: $playing)
                    .onChange(of: playing) { _ in
                        DemoMarketingStudio.shared.syncPlaybackAnchor(to: DemoMarketingStudio.shared.currentPlaybackPosition())
                        apply()
                    }
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack {
                        Text("Position")
                        Spacer()
                        Text("\(formatTime(DemoMarketingStudio.shared.currentPlaybackPosition())) / \(formatTime(duration))")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                SwiftUI.Slider(value: Binding(
                    get: { position },
                    set: { newValue in
                        position = newValue
                        DemoMarketingStudio.shared.syncPlaybackAnchor(to: newValue)
                    }
                ), in: 0...max(1, duration))
                HStack {
                    Text("Track length"); Spacer(); Text(formatTime(duration)).monospacedDigit().foregroundStyle(.secondary)
                }
                SwiftUI.Slider(value: $duration, in: 30...420, step: 1)
                Text("The playhead is calculated from a lightweight clock, so it advances and loops without continuously writing to UserDefaults or forcing Halo to redraw.")
                    .font(.caption2).foregroundStyle(.secondary)

                Text("Synced lyrics (LRC)").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $lyrics).font(.system(.caption, design: .monospaced)).frame(minHeight: 90)
                HStack {
                    Button("Hero preset") {
                        title = "Neon Afterglow"; artist = "Luma Vale"; album = "Halo Nights"; artworkStyle = "Neon"; duration = 188; position = 34; playing = true
                        DemoMarketingStudio.shared.syncPlaybackAnchor(to: 34); apply()
                    }
                    Button("Ambient preset") {
                        title = "Glass Horizon"; artist = "Aster & Co."; album = "Refractions"; artworkStyle = "Ocean"; duration = 214; position = 72; playing = true
                        DemoMarketingStudio.shared.syncPlaybackAnchor(to: 72); apply()
                    }
                    Button("Paused") {
                        position = DemoMarketingStudio.shared.currentPlaybackPosition(); DemoMarketingStudio.shared.syncPlaybackAnchor(to: position); playing = false; apply()
                    }
                }
                Button("Prepare Context Music hero") {
                    if !enabled { enabled = true }
                    DemoMarketingStudio.shared.prepareMusicHero(in: workspace)
                }
                .buttonStyle(.borderedProminent)
                Button("Apply music data") { apply() }
            }

            Section("System") {
                HStack { Text("Battery"); Spacer(); Text("\(Int(battery.rounded()))%").monospacedDigit().foregroundStyle(.secondary) }
                SwiftUI.Slider(value: $battery, in: 1...100, step: 1).onChange(of: battery) { _ in apply() }
                Toggle("Charging", isOn: $charging).onChange(of: charging) { _ in apply() }
                Toggle("On battery power", isOn: $onBattery).onChange(of: onBattery) { _ in apply() }
                Toggle("Low Power Mode", isOn: $lowPower).onChange(of: lowPower) { _ in apply() }
                HStack {
                    Button("Charging 78%") { battery = 78; charging = true; onBattery = false; lowPower = false; apply() }
                    Button("Low battery 18%") { battery = 18; charging = false; onBattery = true; lowPower = true; apply() }
                }
            }

            Section("Live Activity") {
                TextField("Title", text: $activityTitle)
                TextField("Detail", text: $activityDetail)
                HStack { Text("Progress"); Spacer(); Text("\(Int(activityProgress * 100))%").monospacedDigit().foregroundStyle(.secondary) }
                SwiftUI.Slider(value: $activityProgress, in: 0...1)
                HStack {
                    Button("Show activity") { workspace.publish(activityTitle, detail: activityDetail, progress: activityProgress) }
                    Button("Clear") { workspace.activities = [] }
                }
            }

            Section("HUD shots") {
                HStack { Text("Preview value"); Spacer(); Text("\(Int(hudValue * 100))%").monospacedDigit().foregroundStyle(.secondary) }
                SwiftUI.Slider(value: $hudValue, in: 0...1)
                HStack {
                    Button("Volume") { previewHUD("volume") }
                    Button("Brightness") { previewHUD("displayBrightness") }
                    Button("Keyboard") { previewHUD("keyboardBrightness") }
                }
                HStack {
                    Button("Battery") { previewHUD("batteryStatus") }
                    Button("Charging") { previewHUD("chargingState") }
                    Button("Media") { previewHUD("mediaChanged") }
                }
            }

            Section("Capture controls") {
                HStack {
                    Button("Toggle Halo") { NotificationCenter.default.post(name: .init("HaloToggle"), object: nil) }
                    Button("Open Settings") { NotificationCenter.default.post(name: .init("HaloOpenSettings"), object: nil) }
                }
                Button("Apply everything now") { apply() }.keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 430, minHeight: 640)
        .onAppear {
            DemoMarketingStudio.shared.syncPlaybackAnchor(to: position)
            if enabled { apply() }
        }
        .onChange(of: title) { _ in if enabled { apply() } }
        .onChange(of: artist) { _ in if enabled { apply() } }
        .onChange(of: album) { _ in if enabled { apply() } }
        .onChange(of: artworkStyle) { _ in if enabled { apply() } }
        .onChange(of: duration) { _ in
            DemoMarketingStudio.shared.syncPlaybackAnchor(to: min(duration, DemoMarketingStudio.shared.currentPlaybackPosition()))
            if enabled { apply() }
        }
    }

    private func apply() {
        guard enabled else { return }
        DemoMarketingStudio.shared.apply(to: workspace)
    }

    private func previewHUD(_ kind: String) {
        NotificationCenter.default.post(name: .init("HaloHUDPreview"), object: nil, userInfo: ["kind": kind, "value": hudValue])
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}