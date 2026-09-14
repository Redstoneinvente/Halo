import SwiftUI
import AppKit
import CoreGraphics
import Combine

// MARK: - Teleprompter models

enum TeleprompterTriggerKind: String, Codable, CaseIterable, Identifiable {
    case keyboard = "Keyboard Shortcut"
    case mouseButton = "Mouse Shortcut"
    case trackpadSwipe = "Trackpad Swipe"
    case trackpadMagnify = "Trackpad Pinch"
    case appOpened = "App Opened"
    case appActivated = "App Activated"
    case screenRecording = "Screen Recording"
    case manual = "Manual Only"
    var id: String { rawValue }
}

enum TeleprompterGestureDirection: String, Codable, CaseIterable, Identifiable {
    case up = "Up", down = "Down", left = "Left", right = "Right", pinchIn = "Pinch In", pinchOut = "Pinch Out"
    var id: String { rawValue }
}

enum TeleprompterTriggerJoin: String, Codable, CaseIterable, Identifiable {
    case any = "Any Trigger"
    case all = "All Triggers"
    var id: String { rawValue }
}

enum TeleprompterContextKind: String, Codable, CaseIterable, Identifiable {
    case frontmostApp = "Frontmost App"
    case runningApp = "Running App"
    case windowTitle = "Window Title Contains"
    case recordingActive = "Screen Recording Active"
    case displayCount = "Display Count"
    case timeRange = "Time Range"
    var id: String { rawValue }
}

enum TeleprompterContextJoin: String, Codable, CaseIterable, Identifiable {
    case all = "All Contexts"
    case any = "Any Context"
    var id: String { rawValue }
}

enum TeleprompterDisplayMode: String, Codable, CaseIterable, Identifiable {
    case focus = "Focus Line"
    case paragraphs = "Paragraphs"
    case singleLine = "Single Line"
    case cueCards = "Cue Cards"
    var id: String { rawValue }
}

enum TeleprompterAdvanceMode: String, Codable, CaseIterable, Identifiable {
    case automatic = "Auto"
    case manual = "Manual"
    var id: String { rawValue }
}

enum TeleprompterShortcutPreset: String, Codable, CaseIterable, Identifiable {
    case optionCommandT = "⌥⌘T"
    case shiftOptionCommandT = "⇧⌥⌘T"
    case controlOptionT = "⌃⌥T"
    case controlCommandT = "⌃⌘T"
    case optionT = "⌥T"
    var id: String { rawValue }

    var keyCode: UInt16 { 17 }
    var modifiers: UInt {
        switch self {
        case .optionCommandT: return NSEvent.ModifierFlags([.option, .command]).rawValue
        case .shiftOptionCommandT: return NSEvent.ModifierFlags([.shift, .option, .command]).rawValue
        case .controlOptionT: return NSEvent.ModifierFlags([.control, .option]).rawValue
        case .controlCommandT: return NSEvent.ModifierFlags([.control, .command]).rawValue
        case .optionT: return NSEvent.ModifierFlags.option.rawValue
        }
    }
}

struct TeleprompterTrigger: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var kind: TeleprompterTriggerKind = .keyboard
    var shortcut: TeleprompterShortcutPreset = .optionCommandT
    var mouseButton = 3
    var requiredModifiers: UInt = 0
    var gesture: TeleprompterGestureDirection = .up
    var applicationNames: [String] = []
    var recordingStarts = true

    var appQuery: String {
        get { applicationNames.joined(separator: ", ") }
        set { applicationNames = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    }
}

struct TeleprompterContextRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var kind: TeleprompterContextKind = .frontmostApp
    var value = ""
    var numberValue = 1
    var boolValue = true
    var startHour = 0
    var endHour = 23
}

struct TeleprompterAppearance: Codable, Equatable {
    var fontName = "SF Pro Rounded"
    var fontSize = 30.0
    var fontWeight = 0.45
    var lineSpacing = 10.0
    var textOpacity = 1.0
    var surroundingOpacity = 0.24
    var backgroundOpacity = 0.82
    var blurBackground = true
    var cornerRadius = 18.0
    var width = 660.0
    var height = 230.0
    var eyeLineOffset = 12.0
    var horizontalPadding = 24.0
    var hideFromCapture = true
    var showControls = true
    var showProgress = true
    var showTimer = true
    var mirrorHorizontally = false
    var keepNearCamera = true
}

struct TeleprompterBehavior: Codable, Equatable {
    var displayMode: TeleprompterDisplayMode = .focus
    var advanceMode: TeleprompterAdvanceMode = .automatic
    var wordsPerMinute = 145.0
    var countdownSeconds = 3
    var autoStart = true
    var loop = false
    var closeWhenFinished = false
    var pauseWhenAppLosesFocus = false
    var resumeLastPosition = true
    var gestureControlsEnabled = true
    var mouseControlsEnabled = true
}

struct TeleprompterProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Teleprompter"
    var script = "Welcome to Halo Teleprompter.\n\nPaste or write your script here, then trigger it from anywhere on your Mac."
    var enabled = true
    var triggerJoin: TeleprompterTriggerJoin = .any
    var triggers: [TeleprompterTrigger] = [TeleprompterTrigger()]
    var contextJoin: TeleprompterContextJoin = .all
    var contexts: [TeleprompterContextRule] = []
    var appearance = TeleprompterAppearance()
    var behavior = TeleprompterBehavior()
    var lastChunk = 0

    var chunks: [String] {
        let normalized = script.replacingOccurrences(of: "\r\n", with: "\n")
        let paragraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !paragraphs.isEmpty { return paragraphs }
        let fallback = normalized.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        return fallback.isEmpty ? ["Your script is empty."] : fallback
    }
}

// MARK: - Store

@MainActor
final class TeleprompterStore: ObservableObject {
    static let shared = TeleprompterStore()
    @Published var profiles: [TeleprompterProfile] = [] { didSet { save() } }
    @Published var selectedProfileID: UUID? { didSet { saveSelection() } }

    private let profilesKey = "HaloTeleprompterProfilesV1"
    private let selectedKey = "HaloTeleprompterSelectedProfileV1"
    private var loading = false

    private init() {
        loading = true
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([TeleprompterProfile].self, from: data), !decoded.isEmpty {
            profiles = decoded
        } else {
            profiles = [Self.defaultProfile]
        }
        if let raw = UserDefaults.standard.string(forKey: selectedKey), let id = UUID(uuidString: raw) {
            selectedProfileID = id
        } else {
            selectedProfileID = profiles.first?.id
        }
        loading = false
    }

    static var defaultProfile: TeleprompterProfile {
        var p = TeleprompterProfile()
        p.name = "Creator Recording"
        p.triggers = [
            TeleprompterTrigger(kind: .keyboard, shortcut: .optionCommandT),
            TeleprompterTrigger(kind: .screenRecording, recordingStarts: true)
        ]
        p.appearance.hideFromCapture = true
        p.appearance.keepNearCamera = true
        return p
    }

    var selectedIndex: Int? { profiles.firstIndex { $0.id == selectedProfileID } }
    var selectedProfile: TeleprompterProfile? { selectedIndex.map { profiles[$0] } }

    func addProfile() {
        var p = Self.defaultProfile
        p.id = UUID(); p.name = "New Teleprompter"; p.triggers = [TeleprompterTrigger()]
        profiles.append(p); selectedProfileID = p.id
    }

    func duplicateSelected() {
        guard var p = selectedProfile else { return }
        p.id = UUID(); p.name += " Copy"
        profiles.append(p); selectedProfileID = p.id
    }

    func deleteSelected() {
        guard profiles.count > 1, let id = selectedProfileID else { return }
        profiles.removeAll { $0.id == id }
        selectedProfileID = profiles.first?.id
    }

    func updateLastChunk(profileID: UUID, chunk: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].lastChunk = max(0, chunk)
    }

    private func save() {
        guard !loading, let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    private func saveSelection() {
        guard !loading else { return }
        UserDefaults.standard.set(selectedProfileID?.uuidString, forKey: selectedKey)
    }
}

// MARK: - Runtime

@MainActor
final class TeleprompterRuntime: ObservableObject {
    @Published var profile: TeleprompterProfile
    @Published var chunkIndex: Int
    @Published var playing = false
    @Published var countdown: Int?
    @Published var elapsed: TimeInterval = 0
    private var timer: Timer?
    private var chunkElapsed: TimeInterval = 0
    private var startedAt: Date?

    init(profile: TeleprompterProfile) {
        self.profile = profile
        chunkIndex = profile.behavior.resumeLastPosition ? min(profile.lastChunk, max(0, profile.chunks.count - 1)) : 0
    }

    var chunks: [String] { profile.chunks }
    var current: String { chunks.indices.contains(chunkIndex) ? chunks[chunkIndex] : "" }
    var previous: String? { chunkIndex > 0 ? chunks[chunkIndex - 1] : nil }
    var next: String? { chunkIndex + 1 < chunks.count ? chunks[chunkIndex + 1] : nil }
    var progress: Double { chunks.count <= 1 ? 1 : Double(chunkIndex) / Double(chunks.count - 1) }

    func begin() {
        if profile.behavior.countdownSeconds > 0 {
            countdown = profile.behavior.countdownSeconds
            playing = false
            let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor in
                    guard let self else { timer.invalidate(); return }
                    if let value = self.countdown, value > 1 { self.countdown = value - 1 }
                    else { self.countdown = nil; timer.invalidate(); self.play() }
                }
            }
            RunLoop.main.add(t, forMode: .common)
        } else { play() }
    }

    func play() {
        guard !playing else { return }
        playing = true; startedAt = Date(); chunkElapsed = 0
        installTimer()
    }

    func pause() {
        if let startedAt { elapsed += Date().timeIntervalSince(startedAt) }
        startedAt = nil; playing = false; timer?.invalidate(); timer = nil
    }

    func toggle() { playing ? pause() : play() }

    func nextChunk() {
        if chunkIndex + 1 < chunks.count { chunkIndex += 1; chunkElapsed = 0 }
        else if profile.behavior.loop { chunkIndex = 0; chunkElapsed = 0 }
        else { pause(); if profile.behavior.closeWhenFinished { TeleprompterCoordinator.shared.hidePrompt() } }
        TeleprompterStore.shared.updateLastChunk(profileID: profile.id, chunk: chunkIndex)
    }

    func previousChunk() {
        chunkIndex = max(0, chunkIndex - 1); chunkElapsed = 0
        TeleprompterStore.shared.updateLastChunk(profileID: profile.id, chunk: chunkIndex)
    }

    func jump(to index: Int) {
        chunkIndex = min(max(0, index), max(0, chunks.count - 1)); chunkElapsed = 0
        TeleprompterStore.shared.updateLastChunk(profileID: profile.id, chunk: chunkIndex)
    }

    func adjustWPM(_ delta: Double) {
        profile.behavior.wordsPerMinute = min(400, max(40, profile.behavior.wordsPerMinute + delta))
    }

    private func installTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick(0.12) }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func tick(_ delta: TimeInterval) {
        guard playing, profile.behavior.advanceMode == .automatic else { return }
        chunkElapsed += delta
        let wordCount = max(1, current.split { $0.isWhitespace || $0.isNewline }.count)
        let seconds = max(1.0, Double(wordCount) / max(40, profile.behavior.wordsPerMinute) * 60.0)
        if chunkElapsed >= seconds { nextChunk() }
    }
}

// MARK: - Coordinator + trigger engine

@MainActor
final class TeleprompterCoordinator: NSObject {
    static let shared = TeleprompterCoordinator()
    private let store = TeleprompterStore.shared
    private var promptPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var runtime: TeleprompterRuntime?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var gestureLocalMonitor: Any?
    private var gestureGlobalMonitor: Any?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var recordingTimer: Timer?
    private var lastRecordingState = false
    private var installed = false
    private var triggerLatch: [UUID: Set<UUID>] = [:]

    func install() {
        guard !installed else { return }
        installed = true
        installKeyboardAndMouseMonitors()
        installGestureMonitors()
        installWorkspaceObservers()
        installRecordingObserver()
        installRecordingPolling()
        NotificationCenter.default.addObserver(self, selector: #selector(openSettingsNotification), name: .init("HaloOpenTeleprompterSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleNotification), name: .init("HaloToggleTeleprompter"), object: nil)
    }

    @objc private func openSettingsNotification() { showSettings() }
    @objc private func toggleNotification() { toggleSelectedProfile() }

    func toggleSelectedProfile() {
        if promptPanel?.isVisible == true { hidePrompt() }
        else if let profile = store.selectedProfile { show(profile: profile) }
        else { showSettings() }
    }

    func show(profile: TeleprompterProfile) {
        guard profile.enabled else { return }
        hidePrompt()
        let runtime = TeleprompterRuntime(profile: profile)
        self.runtime = runtime
        let root = TeleprompterPromptView(runtime: runtime)
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.sharingType = profile.appearance.hideFromCapture ? .none : .readOnly
        panel.contentView = NSHostingView(rootView: root)
        panel.setContentSize(NSSize(width: profile.appearance.width, height: profile.appearance.height))
        promptPanel = panel
        position(panel, appearance: profile.appearance)
        panel.orderFrontRegardless()
        if profile.behavior.autoStart { runtime.begin() }
    }

    func hidePrompt() {
        runtime?.pause(); runtime = nil
        promptPanel?.orderOut(nil); promptPanel = nil
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered,
                                  defer: false)
            window.title = "Halo · Teleprompter CI"
            window.contentMinSize = NSSize(width: 820, height: 620)
            window.contentView = NSHostingView(rootView: TeleprompterSettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func showSettingsForCurrentPrompt() { showSettings() }

    private func position(_ panel: NSPanel, appearance: TeleprompterAppearance) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let x = frame.midX - appearance.width / 2
        let top = appearance.keepNearCamera ? frame.maxY - max(8, screen.safeAreaInsets.top) - appearance.eyeLineOffset : visible.maxY - 24
        panel.setFrameOrigin(NSPoint(x: x, y: top - appearance.height))
    }

    private func installKeyboardAndMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.keyDown, .otherMouseDown, .rightMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handleInput(event) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handleInput(event) }
        }
    }

    private func installGestureMonitors() {
        let mask: NSEvent.EventTypeMask = [.swipe, .magnify, .scrollWheel]
        gestureLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handleGesture(event) }
            return event
        }
        gestureGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handleGesture(event) }
        }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in self?.handleApplication(note, kind: .appOpened) }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in self?.handleApplication(note, kind: .appActivated) }
        })
    }

    private func installRecordingObserver() {
        for name in ["HaloScreenRecordingStateChanged", "HaloHUDScreenRecordingStateChanged"] {
            let token = NotificationCenter.default.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] note in
                let active = (note.userInfo?["active"] as? Bool) ?? (note.userInfo?["recording"] as? Bool) ?? false
                Task { @MainActor in self?.recordingStateChanged(active) }
            }
            workspaceObservers.append(token)
        }
    }

    private func installRecordingPolling() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recordingStateChanged(self.heuristicScreenRecordingActive())
            }
        }
        if let recordingTimer { RunLoop.main.add(recordingTimer, forMode: .common) }
    }

    private func handleInput(_ event: NSEvent) {
        if promptPanel?.isVisible == true {
            if event.type == .keyDown {
                if event.keyCode == 49 { runtime?.toggle(); return }
                if event.keyCode == 124 { runtime?.nextChunk(); return }
                if event.keyCode == 123 { runtime?.previousChunk(); return }
                if event.keyCode == 53 { hidePrompt(); return }
            }
            if event.type == .otherMouseDown, runtime?.profile.behavior.mouseControlsEnabled == true {
                if event.buttonNumber == 3 { runtime?.previousChunk(); return }
                if event.buttonNumber == 4 { runtime?.nextChunk(); return }
            }
        }

        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled {
                switch trigger.kind {
                case .keyboard where event.type == .keyDown:
                    let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                    let actual = event.modifierFlags.intersection(mask).rawValue
                    if event.keyCode == trigger.shortcut.keyCode && actual == NSEvent.ModifierFlags(rawValue: trigger.shortcut.modifiers).intersection(mask).rawValue {
                        fire(trigger: trigger, profile: profile)
                    }
                case .mouseButton where event.type == .otherMouseDown || event.type == .rightMouseDown:
                    let required = NSEvent.ModifierFlags(rawValue: trigger.requiredModifiers)
                    if event.buttonNumber == trigger.mouseButton && event.modifierFlags.isSuperset(of: required) { fire(trigger: trigger, profile: profile) }
                default: break
                }
            }
        }
    }

    private func handleGesture(_ event: NSEvent) {
        if promptPanel?.isVisible == true, runtime?.profile.behavior.gestureControlsEnabled == true {
            if event.type == .scrollWheel, abs(event.scrollingDeltaY) > 1 {
                event.scrollingDeltaY > 0 ? runtime?.previousChunk() : runtime?.nextChunk()
                return
            }
        }
        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled {
                switch trigger.kind {
                case .trackpadSwipe where event.type == .swipe:
                    let direction: TeleprompterGestureDirection
                    if abs(event.deltaX) > abs(event.deltaY) { direction = event.deltaX > 0 ? .right : .left }
                    else { direction = event.deltaY > 0 ? .up : .down }
                    if direction == trigger.gesture { fire(trigger: trigger, profile: profile) }
                case .trackpadMagnify where event.type == .magnify:
                    let direction: TeleprompterGestureDirection = event.magnification >= 0 ? .pinchOut : .pinchIn
                    if direction == trigger.gesture { fire(trigger: trigger, profile: profile) }
                default: break
                }
            }
        }
    }

    private func handleApplication(_ note: Notification, kind: TeleprompterTriggerKind) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let candidates = [app.localizedName ?? "", app.bundleIdentifier ?? ""]
        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled && trigger.kind == kind {
                let queries = trigger.applicationNames.map { $0.lowercased() }
                if queries.isEmpty || queries.contains(where: { q in candidates.contains(where: { $0.lowercased().contains(q) }) }) {
                    fire(trigger: trigger, profile: profile)
                }
            }
        }
    }

    private func recordingStateChanged(_ active: Bool) {
        guard active != lastRecordingState else { return }
        lastRecordingState = active
        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled && trigger.kind == .screenRecording && trigger.recordingStarts == active {
                fire(trigger: trigger, profile: profile)
            }
        }
    }

    private func fire(trigger: TeleprompterTrigger, profile: TeleprompterProfile) {
        guard contextsMatch(profile) else { return }
        if profile.triggerJoin == .any { show(profile: profile); return }
        var latch = triggerLatch[profile.id, default: []]
        latch.insert(trigger.id); triggerLatch[profile.id] = latch
        let enabledIDs = Set(profile.triggers.filter { $0.enabled && $0.kind != .manual }.map(\.id))
        if !enabledIDs.isEmpty && enabledIDs.isSubset(of: latch) {
            triggerLatch[profile.id] = []
            show(profile: profile)
        }
    }

    private func contextsMatch(_ profile: TeleprompterProfile) -> Bool {
        let rules = profile.contexts.filter(\.enabled)
        guard !rules.isEmpty else { return true }
        let results = rules.map(evaluateContext)
        return profile.contextJoin == .all ? results.allSatisfy { $0 } : results.contains(true)
    }

    private func evaluateContext(_ rule: TeleprompterContextRule) -> Bool {
        let query = rule.value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch rule.kind {
        case .frontmostApp:
            let app = NSWorkspace.shared.frontmostApplication
            return query.isEmpty || (app?.localizedName?.lowercased().contains(query) == true) || (app?.bundleIdentifier?.lowercased().contains(query) == true)
        case .runningApp:
            if query.isEmpty { return !NSWorkspace.shared.runningApplications.isEmpty }
            return NSWorkspace.shared.runningApplications.contains { ($0.localizedName ?? "").lowercased().contains(query) || ($0.bundleIdentifier ?? "").lowercased().contains(query) }
        case .windowTitle:
            if query.isEmpty { return true }
            return windowDescriptions().contains { $0.lowercased().contains(query) }
        case .recordingActive: return lastRecordingState == rule.boolValue
        case .displayCount: return NSScreen.screens.count == max(1, rule.numberValue)
        case .timeRange:
            let hour = Calendar.current.component(.hour, from: Date())
            if rule.startHour <= rule.endHour { return hour >= rule.startHour && hour <= rule.endHour }
            return hour >= rule.startHour || hour <= rule.endHour
        }
    }

    private func windowDescriptions() -> [String] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.map { "\($0[kCGWindowOwnerName as String] as? String ?? "") \($0[kCGWindowName as String] as? String ?? "")" }
    }

    private func heuristicScreenRecordingActive() -> Bool {
        let windows = windowDescriptions().map { $0.lowercased() }
        let recordingTerms = ["obs", "screenflow", "camtasia", "loom", "quicktime player", "screen recording", "recording"]
        let hasRecorderWindow = windows.contains { description in recordingTerms.contains(where: description.contains) }
        let runningNames = NSWorkspace.shared.runningApplications.compactMap(\.localizedName).map { $0.lowercased() }
        let recorderRunning = runningNames.contains { name in ["obs", "screenflow", "camtasia", "loom"].contains(where: name.contains) }
        return hasRecorderWindow && recorderRunning
    }
}

// MARK: - Prompt UI

struct TeleprompterPromptView: View {
    @ObservedObject var runtime: TeleprompterRuntime
    @State private var hover = false

    private var appearance: TeleprompterAppearance { runtime.profile.appearance }
    private var fontWeight: Font.Weight { appearance.fontWeight > 0.72 ? .bold : appearance.fontWeight > 0.52 ? .semibold : appearance.fontWeight > 0.32 ? .medium : .regular }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                .fill(.black.opacity(appearance.backgroundOpacity))
                .background {
                    if appearance.blurBackground { VisualEffectBlur().clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)) }
                }
                .overlay(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))

            VStack(spacing: 9) {
                if let countdown = runtime.countdown {
                    Text("\(countdown)").font(.system(size: 58, weight: .bold, design: .rounded)).transition(.scale.combined(with: .opacity))
                } else {
                    content
                    if appearance.showControls && hover { controls.transition(.opacity.combined(with: .move(edge: .bottom))) }
                    if appearance.showProgress { ProgressView(value: runtime.progress).tint(.white.opacity(0.8)).scaleEffect(x: 1, y: 0.65) }
                }
            }
            .padding(.horizontal, appearance.horizontalPadding)
            .padding(.vertical, 15)
        }
        .foregroundStyle(.white)
        .scaleEffect(x: appearance.mirrorHorizontally ? -1 : 1, y: 1)
        .onHover { hover = $0 }
        .contextMenu {
            Button(runtime.playing ? "Pause" : "Play") { runtime.toggle() }
            Button("Previous") { runtime.previousChunk() }
            Button("Next") { runtime.nextChunk() }
            Divider()
            Button("Teleprompter Settings…") { TeleprompterCoordinator.shared.showSettingsForCurrentPrompt() }
            Button("Close") { TeleprompterCoordinator.shared.hidePrompt() }
        }
    }

    @ViewBuilder private var content: some View {
        switch runtime.profile.behavior.displayMode {
        case .singleLine:
            Text(runtime.current.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: appearance.fontSize, weight: fontWeight, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.65).frame(maxWidth: .infinity)
        case .cueCards:
            Text(runtime.current)
                .font(.system(size: appearance.fontSize, weight: fontWeight, design: .rounded))
                .multilineTextAlignment(.center).lineSpacing(appearance.lineSpacing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .focus, .paragraphs:
            VStack(spacing: max(4, appearance.lineSpacing)) {
                if runtime.profile.behavior.displayMode == .paragraphs, let previous = runtime.previous {
                    Text(previous).opacity(appearance.surroundingOpacity).font(.system(size: appearance.fontSize * 0.72)).lineLimit(2)
                }
                Text(runtime.current)
                    .font(.system(size: appearance.fontSize, weight: fontWeight, design: .rounded))
                    .opacity(appearance.textOpacity)
                    .multilineTextAlignment(.center)
                    .lineSpacing(appearance.lineSpacing)
                    .animation(.easeInOut(duration: 0.22), value: runtime.chunkIndex)
                if let next = runtime.next {
                    Text(next).opacity(appearance.surroundingOpacity).font(.system(size: appearance.fontSize * 0.72)).lineLimit(runtime.profile.behavior.displayMode == .focus ? 2 : 3)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { runtime.previousChunk() } label: { Image(systemName: "backward.end.fill") }
            Button { runtime.toggle() } label: { Image(systemName: runtime.playing ? "pause.fill" : "play.fill") }
            Button { runtime.nextChunk() } label: { Image(systemName: "forward.end.fill") }
            Divider().frame(height: 18)
            Button { runtime.adjustWPM(-5) } label: { Image(systemName: "minus") }
            Text("\(Int(runtime.profile.behavior.wordsPerMinute)) WPM").font(.caption.monospacedDigit()).frame(width: 74)
            Button { runtime.adjustWPM(5) } label: { Image(systemName: "plus") }
            Spacer(minLength: 4)
            Text("\(runtime.chunkIndex + 1)/\(runtime.chunks.count)").font(.caption2.monospacedDigit()).opacity(0.65)
            Button { TeleprompterCoordinator.shared.showSettingsForCurrentPrompt() } label: { Image(systemName: "gearshape") }
            Button { TeleprompterCoordinator.shared.hidePrompt() } label: { Image(systemName: "xmark") }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = .hudWindow; view.blendingMode = .behindWindow; view.state = .active; return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Settings UI

struct TeleprompterSettingsView: View {
    @ObservedObject private var store = TeleprompterStore.shared

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $store.selectedProfileID) {
                    ForEach(store.profiles) { profile in
                        Label(profile.name, systemImage: "text.bubble").tag(profile.id as UUID?)
                    }
                }
                HStack {
                    Button { store.addProfile() } label: { Image(systemName: "plus") }
                    Button { store.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.disabled(store.selectedProfileID == nil)
                    Button(role: .destructive) { store.deleteSelected() } label: { Image(systemName: "trash") }.disabled(store.profiles.count <= 1)
                    Spacer()
                }.padding(10)
            }.navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            if let index = store.selectedIndex {
                TeleprompterProfileEditor(profile: $store.profiles[index])
            } else {
                ContentUnavailableView("Select a Teleprompter", systemImage: "text.bubble")
            }
        }
        .frame(minWidth: 820, minHeight: 620)
    }
}

private struct TeleprompterProfileEditor: View {
    @Binding var profile: TeleprompterProfile
    @State private var section = "Script"
    private let sections = ["Script", "Appearance", "Playback", "Triggers", "Context"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Profile name", text: $profile.name).font(.title2.bold()).textFieldStyle(.plain)
                Toggle("Enabled", isOn: $profile.enabled).toggleStyle(.switch)
                Button("Preview") { TeleprompterCoordinator.shared.show(profile: profile) }.keyboardShortcut(.return, modifiers: [.command])
            }.padding(18)
            Divider()
            Picker("Section", selection: $section) { ForEach(sections, id: \.self) { Text($0) } }.pickerStyle(.segmented).padding(14)
            ScrollView {
                Group {
                    switch section {
                    case "Script": scriptEditor
                    case "Appearance": appearanceEditor
                    case "Playback": playbackEditor
                    case "Triggers": triggerEditor
                    default: contextEditor
                    }
                }.padding(18)
            }
        }
    }

    private var scriptEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Script", systemImage: "doc.text")
                Spacer()
                Text("\(profile.script.split { $0.isWhitespace || $0.isNewline }.count) words · \(profile.chunks.count) chunks").foregroundStyle(.secondary)
            }.font(.headline)
            TextEditor(text: $profile.script).font(.system(size: 15, design: .rounded)).frame(minHeight: 390).padding(8).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            Text("Separate cue cards / focus chunks with a blank line. Halo remembers your last position when enabled.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var appearanceEditor: some View {
        Form {
            Section("Layout") {
                Picker("Mode", selection: $profile.behavior.displayMode) { ForEach(TeleprompterDisplayMode.allCases) { Text($0.rawValue).tag($0) } }
                LabeledContent("Width") { Slider(value: $profile.appearance.width, in: 360...1100); Text("\(Int(profile.appearance.width)) pt").frame(width: 62) }
                LabeledContent("Height") { Slider(value: $profile.appearance.height, in: 100...520); Text("\(Int(profile.appearance.height)) pt").frame(width: 62) }
                LabeledContent("Eye-line offset") { Slider(value: $profile.appearance.eyeLineOffset, in: 0...120); Text("\(Int(profile.appearance.eyeLineOffset)) pt").frame(width: 62) }
                Toggle("Keep near camera / notch", isOn: $profile.appearance.keepNearCamera)
            }
            Section("Typography") {
                LabeledContent("Font size") { Slider(value: $profile.appearance.fontSize, in: 14...72); Text("\(Int(profile.appearance.fontSize))").frame(width: 48) }
                LabeledContent("Weight") { Slider(value: $profile.appearance.fontWeight, in: 0...1) }
                LabeledContent("Line spacing") { Slider(value: $profile.appearance.lineSpacing, in: 0...30) }
                LabeledContent("Surrounding opacity") { Slider(value: $profile.appearance.surroundingOpacity, in: 0...0.8) }
            }
            Section("Surface") {
                LabeledContent("Background opacity") { Slider(value: $profile.appearance.backgroundOpacity, in: 0.1...1) }
                LabeledContent("Corner radius") { Slider(value: $profile.appearance.cornerRadius, in: 0...40) }
                Toggle("Glass blur", isOn: $profile.appearance.blurBackground)
                Toggle("Hide from screen capture", isOn: $profile.appearance.hideFromCapture)
                Toggle("Mirror horizontally", isOn: $profile.appearance.mirrorHorizontally)
                Toggle("Show controls on hover", isOn: $profile.appearance.showControls)
                Toggle("Show progress", isOn: $profile.appearance.showProgress)
            }
        }.formStyle(.grouped)
    }

    private var playbackEditor: some View {
        Form {
            Section("Reading") {
                Picker("Advance", selection: $profile.behavior.advanceMode) { ForEach(TeleprompterAdvanceMode.allCases) { Text($0.rawValue).tag($0) } }
                LabeledContent("Reading speed") { Slider(value: $profile.behavior.wordsPerMinute, in: 40...400); Text("\(Int(profile.behavior.wordsPerMinute)) WPM").frame(width: 76) }
                Stepper("Countdown: \(profile.behavior.countdownSeconds)s", value: $profile.behavior.countdownSeconds, in: 0...10)
                Toggle("Start automatically", isOn: $profile.behavior.autoStart)
                Toggle("Loop script", isOn: $profile.behavior.loop)
                Toggle("Close when finished", isOn: $profile.behavior.closeWhenFinished)
                Toggle("Resume last position", isOn: $profile.behavior.resumeLastPosition)
            }
            Section("Live control") {
                Toggle("Trackpad/scroll controls", isOn: $profile.behavior.gestureControlsEnabled)
                Toggle("Mouse side-button controls", isOn: $profile.behavior.mouseControlsEnabled)
                Text("While visible: Space = play/pause · ←/→ = previous/next · Esc = close · mouse buttons 3/4 = previous/next.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var triggerEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Matching", selection: $profile.triggerJoin) { ForEach(TeleprompterTriggerJoin.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 210)
                Spacer()
                Button("Add Trigger") { profile.triggers.append(TeleprompterTrigger()) }
            }
            Text("Add as many launch sources as you like. ‘Any’ launches on the first matching trigger; ‘All’ latches each enabled trigger until every one has fired.").font(.caption).foregroundStyle(.secondary)
            ForEach($profile.triggers) { $trigger in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Toggle("", isOn: $trigger.enabled).labelsHidden()
                        Picker("Trigger", selection: $trigger.kind) { ForEach(TeleprompterTriggerKind.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 210)
                        Spacer()
                        Button(role: .destructive) { profile.triggers.removeAll { $0.id == trigger.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                    triggerFields($trigger)
                }.padding(12).background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder private func triggerFields(_ trigger: Binding<TeleprompterTrigger>) -> some View {
        switch trigger.wrappedValue.kind {
        case .keyboard:
            Picker("Shortcut", selection: trigger.shortcut) { ForEach(TeleprompterShortcutPreset.allCases) { Text($0.rawValue).tag($0) } }.frame(maxWidth: 300)
        case .mouseButton:
            Stepper("Mouse button: \(trigger.wrappedValue.mouseButton)", value: trigger.mouseButton, in: 2...12)
        case .trackpadSwipe:
            Picker("Direction", selection: trigger.gesture) { ForEach([TeleprompterGestureDirection.up, .down, .left, .right]) { Text($0.rawValue).tag($0) } }.frame(maxWidth: 300)
        case .trackpadMagnify:
            Picker("Gesture", selection: trigger.gesture) { Text("Pinch In").tag(TeleprompterGestureDirection.pinchIn); Text("Pinch Out").tag(TeleprompterGestureDirection.pinchOut) }.frame(maxWidth: 300)
        case .appOpened, .appActivated:
            TextField("App names / bundle IDs, comma separated", text: Binding(get: { trigger.wrappedValue.appQuery }, set: { trigger.wrappedValue.appQuery = $0 }))
        case .screenRecording:
            Picker("When", selection: trigger.recordingStarts) { Text("Recording starts").tag(true); Text("Recording stops").tag(false) }.frame(maxWidth: 300)
            Text("Uses Halo recording-state notifications when available plus a local OBS/ScreenFlow/Camtasia/Loom detection fallback.").font(.caption).foregroundStyle(.secondary)
        case .manual:
            Text("This profile only launches from Preview or another Halo action.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Matching", selection: $profile.contextJoin) { ForEach(TeleprompterContextJoin.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 210)
                Spacer()
                Button("Add Context") { profile.contexts.append(TeleprompterContextRule()) }
            }
            Text("Contexts decide whether a trigger is allowed to launch this profile. Combine app, window, recording, display and time conditions.").font(.caption).foregroundStyle(.secondary)
            ForEach($profile.contexts) { $rule in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Toggle("", isOn: $rule.enabled).labelsHidden()
                        Picker("Context", selection: $rule.kind) { ForEach(TeleprompterContextKind.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 220)
                        Spacer()
                        Button(role: .destructive) { profile.contexts.removeAll { $0.id == rule.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                    contextFields($rule)
                }.padding(12).background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            }
            if profile.contexts.isEmpty { ContentUnavailableView("No Context Restrictions", systemImage: "scope", description: Text("Any matching trigger may launch this profile.")) }
        }
    }

    @ViewBuilder private func contextFields(_ rule: Binding<TeleprompterContextRule>) -> some View {
        switch rule.wrappedValue.kind {
        case .frontmostApp, .runningApp, .windowTitle:
            TextField("Match text / bundle identifier", text: rule.value)
        case .recordingActive:
            Picker("State", selection: rule.boolValue) { Text("Recording").tag(true); Text("Not recording").tag(false) }.frame(maxWidth: 280)
        case .displayCount:
            Stepper("Display count = \(rule.wrappedValue.numberValue)", value: rule.numberValue, in: 1...8)
        case .timeRange:
            HStack { Stepper("From \(rule.wrappedValue.startHour):00", value: rule.startHour, in: 0...23); Stepper("To \(rule.wrappedValue.endHour):00", value: rule.endHour, in: 0...23) }
        }
    }
}

// MARK: - Bootstrap entry point called by TeleprompterBootstrap.m

@_cdecl("HaloTeleprompterInstall")
public func HaloTeleprompterInstall() {
    DispatchQueue.main.async {
        Task { @MainActor in TeleprompterCoordinator.shared.install() }
    }
}
