import AppKit
import SwiftUI
import Vision
import CoreGraphics
import Combine

@MainActor
final class CaptureService: ObservableObject {
    @Published var busy = false
    @Published var recognizedText = ""
    @Published var error: String?
    @Published var recentCaptures: [URL] = []

    init() {
        TeleprompterCoordinator.shared.install()
    }

    func capture(completion: @escaping (URL) -> Void) {
        guard !busy else { return }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            error = "Allow Screen Recording in System Settings, then relaunch Halo if macOS requests it."; return
        }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.png]; panel.nameFieldStringValue = "Halo-\(Int(Date().timeIntervalSince1970)).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-x", "-t", "png", url.path]
        task.terminationHandler = { [weak self] task in
            Task { @MainActor in
                self?.busy = false
                if task.terminationStatus == 0, FileManager.default.fileExists(atPath: url.path) {
                    self?.recentCaptures.removeAll { $0 == url }
                    self?.recentCaptures.insert(url, at: 0)
                    if let count = self?.recentCaptures.count, count > 8 { self?.recentCaptures.removeLast(count - 8) }
                    completion(url)
                }
            }
        }
        do { try task.run() } catch { busy = false; self.error = error.localizedDescription }
    }

    func recognize(_ url: URL) {
        guard !busy else { return }; busy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
                try VNImageRequestHandler(url: url, options: [:]).perform([request])
                let text = request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") ?? ""
                Task { @MainActor in self?.recognizedText = text; self?.busy = false }
            } catch { Task { @MainActor in self?.error = error.localizedDescription; self?.busy = false } }
        }
    }

    func chooseImage() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url { recognize(url) }
    }
}

// MARK: - Teleprompter CI

enum TeleprompterTriggerKind: String, Codable, CaseIterable, Identifiable {
    case keyboard = "Keyboard Shortcut"
    case mouseButton = "Mouse Shortcut"
    case trackpadSwipe = "Trackpad Swipe"
    case trackpadPinch = "Trackpad Pinch"
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
    case any = "Any Trigger", all = "All Triggers"
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
    case all = "All Contexts", any = "Any Context"
    var id: String { rawValue }
}

enum TeleprompterDisplayMode: String, Codable, CaseIterable, Identifiable {
    case focus = "Focus Line", paragraphs = "Paragraphs", singleLine = "Single Line", cueCards = "Cue Cards"
    var id: String { rawValue }
}

enum TeleprompterAdvanceMode: String, Codable, CaseIterable, Identifiable {
    case automatic = "Auto", manual = "Manual"
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
    var resumeLastPosition = true
    var gestureControlsEnabled = true
    var mouseControlsEnabled = true
}

struct TeleprompterProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Creator Recording"
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
        let chunks = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return chunks.isEmpty ? ["Your script is empty."] : chunks
    }
}

@MainActor
final class TeleprompterStore: ObservableObject {
    static let shared = TeleprompterStore()
    @Published var profiles: [TeleprompterProfile] = [] { didSet { save() } }
    @Published var selectedProfileID: UUID? { didSet { saveSelection() } }
    private let profilesKey = "HaloTeleprompterProfilesV1"
    private let selectedKey = "HaloTeleprompterSelectedProfileV1"
    private var loading = true

    private init() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([TeleprompterProfile].self, from: data), !decoded.isEmpty {
            profiles = decoded
        } else {
            var profile = TeleprompterProfile()
            var keyboard = TeleprompterTrigger(); keyboard.kind = .keyboard; keyboard.shortcut = .optionCommandT
            var recording = TeleprompterTrigger(); recording.kind = .screenRecording; recording.recordingStarts = true
            profile.triggers = [keyboard, recording]
            profiles = [profile]
        }
        if let raw = UserDefaults.standard.string(forKey: selectedKey), let id = UUID(uuidString: raw) { selectedProfileID = id }
        else { selectedProfileID = profiles.first?.id }
        loading = false
    }

    var selectedIndex: Int? { profiles.firstIndex { $0.id == selectedProfileID } }
    var selectedProfile: TeleprompterProfile? { selectedIndex.map { profiles[$0] } }

    func addProfile() {
        var profile = TeleprompterProfile(); profile.id = UUID(); profile.name = "New Teleprompter"
        profiles.append(profile); selectedProfileID = profile.id
    }
    func duplicateSelected() {
        guard var profile = selectedProfile else { return }
        profile.id = UUID(); profile.name += " Copy"; profiles.append(profile); selectedProfileID = profile.id
    }
    func deleteSelected() {
        guard profiles.count > 1, let selectedProfileID else { return }
        profiles.removeAll { $0.id == selectedProfileID }; self.selectedProfileID = profiles.first?.id
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

@MainActor
final class TeleprompterRuntime: ObservableObject {
    @Published var profile: TeleprompterProfile
    @Published var chunkIndex: Int
    @Published var playing = false
    @Published var countdown: Int?
    private var timer: Timer?
    private var chunkElapsed = 0.0

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
        guard profile.behavior.countdownSeconds > 0 else { play(); return }
        countdown = profile.behavior.countdownSeconds
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else { t.invalidate(); return }
                if let value = self.countdown, value > 1 { self.countdown = value - 1 }
                else { self.countdown = nil; t.invalidate(); self.play() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    func play() { guard !playing else { return }; playing = true; chunkElapsed = 0; installTimer() }
    func pause() { playing = false; timer?.invalidate(); timer = nil }
    func toggle() { playing ? pause() : play() }
    func nextChunk() {
        if chunkIndex + 1 < chunks.count { chunkIndex += 1; chunkElapsed = 0 }
        else if profile.behavior.loop { chunkIndex = 0; chunkElapsed = 0 }
        else { pause(); if profile.behavior.closeWhenFinished { TeleprompterCoordinator.shared.hidePrompt() } }
        TeleprompterStore.shared.updateLastChunk(profileID: profile.id, chunk: chunkIndex)
    }
    func previousChunk() { chunkIndex = max(0, chunkIndex - 1); chunkElapsed = 0; TeleprompterStore.shared.updateLastChunk(profileID: profile.id, chunk: chunkIndex) }
    func adjustWPM(_ delta: Double) { profile.behavior.wordsPerMinute = min(400, max(40, profile.behavior.wordsPerMinute + delta)) }
    private func installTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick(0.12) } }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    private func tick(_ delta: Double) {
        guard playing, profile.behavior.advanceMode == .automatic else { return }
        chunkElapsed += delta
        let words = max(1, current.split { $0.isWhitespace || $0.isNewline }.count)
        let duration = max(1, Double(words) / max(40, profile.behavior.wordsPerMinute) * 60)
        if chunkElapsed >= duration { nextChunk() }
    }
}

@MainActor
final class TeleprompterCoordinator: NSObject {
    static let shared = TeleprompterCoordinator()
    private let store = TeleprompterStore.shared
    private var promptPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var runtime: TeleprompterRuntime?
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var recordingTimer: Timer?
    private var contextTimer: Timer?
    private var lastRecordingState = false
    private var triggerLatch: [UUID: Set<UUID>] = [:]
    private var contextMatchState: [UUID: Bool] = [:]
    private var contextOwnedProfileID: UUID?
    private var installed = false

    func install() {
        guard !installed else { return }; installed = true
        installInputMonitors(); installWorkspaceObservers(); installRecordingPolling(); installContextAutomation()
        NotificationCenter.default.addObserver(self, selector: #selector(openSettingsNotification), name: .init("HaloOpenTeleprompterSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggleNotification), name: .init("HaloToggleTeleprompter"), object: nil)
        for name in ["HaloScreenRecordingStateChanged", "HaloHUDScreenRecordingStateChanged"] {
            observers.append(NotificationCenter.default.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] note in
                let active = (note.userInfo?["active"] as? Bool) ?? (note.userInfo?["recording"] as? Bool) ?? false
                Task { @MainActor in self?.recordingStateChanged(active) }
            })
        }
    }

    @objc private func openSettingsNotification() { showSettings() }
    @objc private func toggleNotification() { toggleSelectedProfile() }

    func toggleSelectedProfile() {
        contextOwnedProfileID = nil
        if promptPanel?.isVisible == true { hidePrompt() }
        else if let profile = store.selectedProfile { show(profile: profile) }
        else { showSettings() }
    }

    func show(profile: TeleprompterProfile) {
        guard profile.enabled else { return }
        contextOwnedProfileID = nil
        hidePrompt()
        let runtime = TeleprompterRuntime(profile: profile); self.runtime = runtime
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = true
        panel.sharingType = profile.appearance.hideFromCapture ? .none : .readOnly
        panel.contentView = NSHostingView(rootView: TeleprompterPromptView(runtime: runtime))
        panel.setContentSize(NSSize(width: profile.appearance.width, height: profile.appearance.height))
        promptPanel = panel; position(panel, appearance: profile.appearance); panel.orderFrontRegardless()
        if profile.behavior.autoStart { runtime.begin() }
    }

    private func showFromContext(profile: TeleprompterProfile) {
        show(profile: profile)
        contextOwnedProfileID = profile.id
    }

    func hidePrompt() { runtime?.pause(); runtime = nil; promptPanel?.orderOut(nil); promptPanel = nil }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Halo · Teleprompter CI"; window.contentMinSize = NSSize(width: 820, height: 620)
            window.contentView = NSHostingView(rootView: TeleprompterSettingsView()); window.isReleasedWhenClosed = false; window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func position(_ panel: NSPanel, appearance: TeleprompterAppearance) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let top = appearance.keepNearCamera ? screen.frame.maxY - max(8, screen.safeAreaInsets.top) - appearance.eyeLineOffset : screen.visibleFrame.maxY - 24
        panel.setFrameOrigin(NSPoint(x: screen.frame.midX - appearance.width / 2, y: top - appearance.height))
    }

    private func installInputMonitors() {
        let inputMask: NSEvent.EventTypeMask = [.keyDown, .otherMouseDown, .rightMouseDown]
        if let local = NSEvent.addLocalMonitorForEvents(matching: inputMask, handler: { [weak self] event in Task { @MainActor in self?.handleInput(event) }; return event }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: inputMask, handler: { [weak self] event in Task { @MainActor in self?.handleInput(event) } }) { monitors.append(global) }
        let gestureMask: NSEvent.EventTypeMask = [.swipe, .magnify, .scrollWheel]
        if let local = NSEvent.addLocalMonitorForEvents(matching: gestureMask, handler: { [weak self] event in Task { @MainActor in self?.handleGesture(event) }; return event }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: gestureMask, handler: { [weak self] event in Task { @MainActor in self?.handleGesture(event) } }) { monitors.append(global) }
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in Task { @MainActor in self?.handleApplication(note, kind: .appOpened) } })
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in Task { @MainActor in self?.handleApplication(note, kind: .appActivated) } })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.evaluateContextAutomation() } })
    }

    private func installRecordingPolling() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in Task { @MainActor in guard let self else { return }; self.recordingStateChanged(self.heuristicScreenRecordingActive()) } }
        if let recordingTimer { RunLoop.main.add(recordingTimer, forMode: .common) }
    }

    private func installContextAutomation() {
        contextTimer?.invalidate()
        contextTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateContextAutomation() }
        }
        if let contextTimer { RunLoop.main.add(contextTimer, forMode: .common) }
        DispatchQueue.main.async { [weak self] in self?.evaluateContextAutomation() }
    }

    private func evaluateContextAutomation() {
        let contextProfiles = store.profiles.filter { profile in
            profile.enabled && profile.contexts.contains(where: \.enabled)
        }
        let liveIDs = Set(contextProfiles.map(\.id))
        contextMatchState = contextMatchState.filter { liveIDs.contains($0.key) }

        var rising: [TeleprompterProfile] = []
        for profile in contextProfiles {
            let matches = contextsMatch(profile)
            let previous = contextMatchState[profile.id] ?? false
            contextMatchState[profile.id] = matches
            if matches && !previous { rising.append(profile) }
            if !matches && previous && contextOwnedProfileID == profile.id {
                if runtime?.profile.id == profile.id { hidePrompt() }
                contextOwnedProfileID = nil
            }
        }

        guard !rising.isEmpty else { return }
        let chosen: TeleprompterProfile
        if let selected = store.selectedProfile, let selectedRising = rising.first(where: { $0.id == selected.id }) {
            chosen = selectedRising
        } else {
            chosen = rising[0]
        }

        // Context is an automation trigger, not a hard lock. Never steal a Teleprompter that
        // the user opened manually or through another explicit trigger.
        if promptPanel?.isVisible == true, contextOwnedProfileID == nil { return }
        showFromContext(profile: chosen)
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
                    let significant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                    let actual = event.modifierFlags.intersection(significant).rawValue
                    let expected = NSEvent.ModifierFlags(rawValue: trigger.shortcut.modifiers).intersection(significant).rawValue
                    if event.keyCode == trigger.shortcut.keyCode && actual == expected { fire(trigger: trigger, profile: profile) }
                case .mouseButton where event.type == .otherMouseDown || event.type == .rightMouseDown:
                    if event.buttonNumber == trigger.mouseButton && event.modifierFlags.isSuperset(of: NSEvent.ModifierFlags(rawValue: trigger.requiredModifiers)) { fire(trigger: trigger, profile: profile) }
                default: break
                }
            }
        }
    }

    private func handleGesture(_ event: NSEvent) {
        if promptPanel?.isVisible == true, runtime?.profile.behavior.gestureControlsEnabled == true, event.type == .scrollWheel, abs(event.scrollingDeltaY) > 1 {
            if event.scrollingDeltaY > 0 { runtime?.previousChunk() } else { runtime?.nextChunk() }
            return
        }
        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled {
                if trigger.kind == .trackpadSwipe, event.type == .swipe {
                    let direction: TeleprompterGestureDirection = abs(event.deltaX) > abs(event.deltaY) ? (event.deltaX > 0 ? .right : .left) : (event.deltaY > 0 ? .up : .down)
                    if direction == trigger.gesture { fire(trigger: trigger, profile: profile) }
                } else if trigger.kind == .trackpadPinch, event.type == .magnify {
                    let direction: TeleprompterGestureDirection = event.magnification >= 0 ? .pinchOut : .pinchIn
                    if direction == trigger.gesture { fire(trigger: trigger, profile: profile) }
                }
            }
        }
    }

    private func handleApplication(_ note: Notification, kind: TeleprompterTriggerKind) {
        evaluateContextAutomation()
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let values = [app.localizedName ?? "", app.bundleIdentifier ?? ""]
        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled && trigger.kind == kind {
                let queries = trigger.applicationNames.flatMap { contextQueries($0) }
                if queries.isEmpty || queries.contains(where: { query in values.contains(where: { $0.localizedCaseInsensitiveContains(query) }) }) {
                    fire(trigger: trigger, profile: profile)
                }
            }
        }
    }

    private func recordingStateChanged(_ active: Bool) {
        let changed = active != lastRecordingState
        lastRecordingState = active
        evaluateContextAutomation()
        guard changed else { return }
        for profile in store.profiles where profile.enabled {
            for trigger in profile.triggers where trigger.enabled && trigger.kind == .screenRecording && trigger.recordingStarts == active { fire(trigger: trigger, profile: profile) }
        }
    }

    private func fire(trigger: TeleprompterTrigger, profile: TeleprompterProfile) {
        guard contextsMatch(profile) else { return }
        contextOwnedProfileID = nil
        if profile.triggerJoin == .any { show(profile: profile); return }
        var latch = triggerLatch[profile.id, default: []]; latch.insert(trigger.id); triggerLatch[profile.id] = latch
        let required = Set(profile.triggers.filter { $0.enabled && $0.kind != .manual }.map(\.id))
        if !required.isEmpty && required.isSubset(of: latch) { triggerLatch[profile.id] = []; show(profile: profile) }
    }

    private func contextsMatch(_ profile: TeleprompterProfile) -> Bool {
        let rules = profile.contexts.filter(\.enabled)
        guard !rules.isEmpty else { return true }
        let results = rules.map(evaluateContext)
        return profile.contextJoin == .all ? results.allSatisfy { $0 } : results.contains(true)
    }

    private func evaluateContext(_ rule: TeleprompterContextRule) -> Bool {
        let queries = contextQueries(rule.value)
        switch rule.kind {
        case .frontmostApp:
            guard !queries.isEmpty, let app = NSWorkspace.shared.frontmostApplication else { return false }
            return appMatches(app, queries: queries)
        case .runningApp:
            guard !queries.isEmpty else { return false }
            return NSWorkspace.shared.runningApplications.contains { appMatches($0, queries: queries) }
        case .windowTitle:
            guard !queries.isEmpty else { return false }
            let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            return windowDescriptions(frontmostPID: frontPID).contains { description in
                queries.contains { description.localizedCaseInsensitiveContains($0) }
            }
        case .recordingActive:
            return heuristicScreenRecordingActive() == rule.boolValue
        case .displayCount:
            return NSScreen.screens.count == max(1, rule.numberValue)
        case .timeRange:
            let hour = Calendar.current.component(.hour, from: Date())
            if rule.startHour == rule.endHour { return true }
            return rule.startHour < rule.endHour
                ? (hour >= rule.startHour && hour < rule.endHour)
                : (hour >= rule.startHour || hour < rule.endHour)
        }
    }

    private func contextQueries(_ raw: String) -> [String] {
        raw.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func appMatches(_ app: NSRunningApplication, queries: [String]) -> Bool {
        let values = [app.localizedName ?? "", app.bundleIdentifier ?? ""]
        return queries.contains { query in
            values.contains { value in value.localizedCaseInsensitiveContains(query) }
        }
    }

    private func windowDescriptions(frontmostPID: pid_t? = nil) -> [String] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            if let frontmostPID,
               let pidNumber = info[kCGWindowOwnerPID as String] as? NSNumber,
               pidNumber.int32Value != frontmostPID { return nil }
            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = info[kCGWindowName as String] as? String ?? ""
            guard !owner.isEmpty || !name.isEmpty else { return nil }
            return "\(owner) \(name)"
        }
    }

    private func heuristicScreenRecordingActive() -> Bool {
        let windows = windowDescriptions().map { $0.lowercased() }
        let recorders = ["obs", "screenflow", "camtasia", "loom"]
        let running = NSWorkspace.shared.runningApplications.compactMap(\.localizedName).map { $0.lowercased() }
        let recorderRunning = running.contains { name in recorders.contains(where: name.contains) }
        let recordingWindow = windows.contains { description in
            recorders.contains(where: description.contains) && (description.contains("record") || description.contains("studio"))
        }
        return recorderRunning && recordingWindow
    }
}

private struct TeleprompterVisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView { let view = NSVisualEffectView(); view.material = .hudWindow; view.blendingMode = .behindWindow; view.state = .active; return view }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct TeleprompterPromptView: View {
    @ObservedObject var runtime: TeleprompterRuntime
    @State private var hover = false
    private var appearance: TeleprompterAppearance { runtime.profile.appearance }
    private var weight: Font.Weight { appearance.fontWeight > 0.72 ? .bold : appearance.fontWeight > 0.52 ? .semibold : appearance.fontWeight > 0.32 ? .medium : .regular }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous).fill(.black.opacity(appearance.backgroundOpacity))
                .background { if appearance.blurBackground { TeleprompterVisualEffectBlur().clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)) } }
                .overlay(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
            VStack(spacing: 9) {
                if let countdown = runtime.countdown { Text("\(countdown)").font(.system(size: 58, weight: .bold, design: .rounded)) }
                else {
                    promptContent
                    if appearance.showControls && hover { controls }
                    if appearance.showProgress { ProgressView(value: runtime.progress).tint(.white.opacity(0.8)).scaleEffect(x: 1, y: 0.65) }
                }
            }.padding(.horizontal, appearance.horizontalPadding).padding(.vertical, 15)
        }
        .foregroundStyle(.white).scaleEffect(x: appearance.mirrorHorizontally ? -1 : 1, y: 1).onHover { hover = $0 }
        .contextMenu {
            Button(runtime.playing ? "Pause" : "Play") { runtime.toggle() }
            Button("Previous") { runtime.previousChunk() }; Button("Next") { runtime.nextChunk() }
            Divider(); Button("Teleprompter Settings…") { TeleprompterCoordinator.shared.showSettings() }; Button("Close") { TeleprompterCoordinator.shared.hidePrompt() }
        }
    }

    @ViewBuilder private var promptContent: some View {
        switch runtime.profile.behavior.displayMode {
        case .singleLine:
            Text(runtime.current.replacingOccurrences(of: "\n", with: " ")).font(.system(size: appearance.fontSize, weight: weight, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
        case .cueCards:
            Text(runtime.current).font(.system(size: appearance.fontSize, weight: weight, design: .rounded)).multilineTextAlignment(.center).lineSpacing(appearance.lineSpacing).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .focus, .paragraphs:
            VStack(spacing: max(4, appearance.lineSpacing)) {
                if runtime.profile.behavior.displayMode == .paragraphs, let previous = runtime.previous { Text(previous).opacity(appearance.surroundingOpacity).font(.system(size: appearance.fontSize * 0.72)).lineLimit(2) }
                Text(runtime.current).font(.system(size: appearance.fontSize, weight: weight, design: .rounded)).opacity(appearance.textOpacity).multilineTextAlignment(.center).lineSpacing(appearance.lineSpacing)
                if let next = runtime.next { Text(next).opacity(appearance.surroundingOpacity).font(.system(size: appearance.fontSize * 0.72)).lineLimit(runtime.profile.behavior.displayMode == .focus ? 2 : 3) }
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
            Text("\(Int(runtime.profile.behavior.wordsPerMinute)) WPM").font(.caption.monospacedDigit()).frame(width: 76)
            Button { runtime.adjustWPM(5) } label: { Image(systemName: "plus") }
            Spacer(); Text("\(runtime.chunkIndex + 1)/\(runtime.chunks.count)").font(.caption2.monospacedDigit()).opacity(0.65)
            Button { TeleprompterCoordinator.shared.showSettings() } label: { Image(systemName: "gearshape") }
            Button { TeleprompterCoordinator.shared.hidePrompt() } label: { Image(systemName: "xmark") }
        }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
    }
}

struct TeleprompterSettingsView: View {
    @ObservedObject private var store = TeleprompterStore.shared

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $store.selectedProfileID) {
                    ForEach(store.profiles) { profile in Label(profile.name, systemImage: "text.bubble").tag(profile.id as UUID?) }
                }
                HStack {
                    Button { store.addProfile() } label: { Image(systemName: "plus") }
                    Button { store.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }
                    Button(role: .destructive) { store.deleteSelected() } label: { Image(systemName: "trash") }.disabled(store.profiles.count <= 1)
                    Spacer()
                }.padding(10)
            }.navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            if let index = store.selectedIndex { TeleprompterProfileEditor(profile: $store.profiles[index]) }
            else { VStack(spacing: 8) { Image(systemName: "text.bubble").font(.largeTitle); Text("Select a Teleprompter").font(.headline) }.foregroundStyle(.secondary) }
        }
    }
}

private struct TeleprompterProfileEditor: View {
    @Binding var profile: TeleprompterProfile
    @State private var section = "Script"
    private let sections = ["Script", "Appearance", "Playback", "Triggers", "Context"]

    var body: some View {
        VStack(spacing: 0) {
            HStack { TextField("Profile name", text: $profile.name).font(.title2.bold()).textFieldStyle(.plain); Toggle("Enabled", isOn: $profile.enabled).toggleStyle(.switch); Button("Preview") { TeleprompterCoordinator.shared.show(profile: profile) } }.padding(18)
            Divider(); Picker("Section", selection: $section) { ForEach(sections, id: \.self) { Text($0) } }.pickerStyle(.segmented).padding(14)
            ScrollView { Group { if section == "Script" { scriptEditor } else if section == "Appearance" { appearanceEditor } else if section == "Playback" { playbackEditor } else if section == "Triggers" { triggerEditor } else { contextEditor } }.padding(18) }
        }
    }

    private var scriptEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label("Script", systemImage: "doc.text"); Spacer(); Text("\(profile.script.split { $0.isWhitespace || $0.isNewline }.count) words · \(profile.chunks.count) chunks").foregroundStyle(.secondary) }.font(.headline)
            TextEditor(text: $profile.script).font(.system(size: 15, design: .rounded)).frame(minHeight: 390).padding(8).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            Text("Separate focus chunks or cue cards with a blank line.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var appearanceEditor: some View {
        Form {
            Picker("Mode", selection: $profile.behavior.displayMode) { ForEach(TeleprompterDisplayMode.allCases) { Text($0.rawValue).tag($0) } }
            LabeledContent("Width") { Slider(value: $profile.appearance.width, in: 360...1100); Text("\(Int(profile.appearance.width)) pt").frame(width: 62) }
            LabeledContent("Height") { Slider(value: $profile.appearance.height, in: 100...520); Text("\(Int(profile.appearance.height)) pt").frame(width: 62) }
            LabeledContent("Eye-line offset") { Slider(value: $profile.appearance.eyeLineOffset, in: 0...120); Text("\(Int(profile.appearance.eyeLineOffset)) pt").frame(width: 62) }
            Toggle("Keep near camera / notch", isOn: $profile.appearance.keepNearCamera)
            LabeledContent("Font size") { Slider(value: $profile.appearance.fontSize, in: 14...72); Text("\(Int(profile.appearance.fontSize))").frame(width: 44) }
            LabeledContent("Weight") { Slider(value: $profile.appearance.fontWeight, in: 0...1) }
            LabeledContent("Line spacing") { Slider(value: $profile.appearance.lineSpacing, in: 0...30) }
            LabeledContent("Surrounding opacity") { Slider(value: $profile.appearance.surroundingOpacity, in: 0...0.8) }
            LabeledContent("Background opacity") { Slider(value: $profile.appearance.backgroundOpacity, in: 0.1...1) }
            LabeledContent("Corner radius") { Slider(value: $profile.appearance.cornerRadius, in: 0...40) }
            Toggle("Glass blur", isOn: $profile.appearance.blurBackground)
            Toggle("Hide from screen capture", isOn: $profile.appearance.hideFromCapture)
            Toggle("Mirror horizontally", isOn: $profile.appearance.mirrorHorizontally)
            Toggle("Show controls on hover", isOn: $profile.appearance.showControls)
            Toggle("Show progress", isOn: $profile.appearance.showProgress)
        }.formStyle(.grouped)
    }

    private var playbackEditor: some View {
        Form {
            Picker("Advance", selection: $profile.behavior.advanceMode) { ForEach(TeleprompterAdvanceMode.allCases) { Text($0.rawValue).tag($0) } }
            LabeledContent("Reading speed") { Slider(value: $profile.behavior.wordsPerMinute, in: 40...400); Text("\(Int(profile.behavior.wordsPerMinute)) WPM").frame(width: 80) }
            Stepper("Countdown: \(profile.behavior.countdownSeconds)s", value: $profile.behavior.countdownSeconds, in: 0...10)
            Toggle("Start automatically", isOn: $profile.behavior.autoStart); Toggle("Loop script", isOn: $profile.behavior.loop); Toggle("Close when finished", isOn: $profile.behavior.closeWhenFinished); Toggle("Resume last position", isOn: $profile.behavior.resumeLastPosition)
            Toggle("Trackpad/scroll controls", isOn: $profile.behavior.gestureControlsEnabled); Toggle("Mouse side-button controls", isOn: $profile.behavior.mouseControlsEnabled)
            Text("While visible: Space = play/pause · ←/→ = previous/next · Esc = close · mouse buttons 3/4 = previous/next.").font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }

    private var triggerEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Picker("Matching", selection: $profile.triggerJoin) { ForEach(TeleprompterTriggerJoin.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 210); Spacer(); Button("Add Trigger") { profile.triggers.append(TeleprompterTrigger()) } }
            Text("Profiles can have multiple launch sources. Use Any for independent triggers or All to require every enabled trigger to fire. Contexts are also able to launch a profile on their own.").font(.caption).foregroundStyle(.secondary)
            ForEach($profile.triggers) { $trigger in
                VStack(alignment: .leading, spacing: 9) {
                    HStack { Toggle("", isOn: $trigger.enabled).labelsHidden(); Picker("Trigger", selection: $trigger.kind) { ForEach(TeleprompterTriggerKind.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 210); Spacer(); Button(role: .destructive) { profile.triggers.removeAll { $0.id == trigger.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                    triggerFields($trigger)
                }.padding(12).background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder private func triggerFields(_ trigger: Binding<TeleprompterTrigger>) -> some View {
        switch trigger.wrappedValue.kind {
        case .keyboard: Picker("Shortcut", selection: trigger.shortcut) { ForEach(TeleprompterShortcutPreset.allCases) { Text($0.rawValue).tag($0) } }.frame(maxWidth: 300)
        case .mouseButton: Stepper("Mouse button: \(trigger.wrappedValue.mouseButton)", value: trigger.mouseButton, in: 2...12)
        case .trackpadSwipe: Picker("Direction", selection: trigger.gesture) { ForEach([TeleprompterGestureDirection.up, .down, .left, .right]) { Text($0.rawValue).tag($0) } }.frame(maxWidth: 300)
        case .trackpadPinch: Picker("Gesture", selection: trigger.gesture) { Text("Pinch In").tag(TeleprompterGestureDirection.pinchIn); Text("Pinch Out").tag(TeleprompterGestureDirection.pinchOut) }.frame(maxWidth: 300)
        case .appOpened, .appActivated:
            TextField("App names / bundle IDs, comma separated", text: Binding(get: { trigger.wrappedValue.applicationNames.joined(separator: ", ") }, set: { trigger.wrappedValue.applicationNames = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }))
        case .screenRecording:
            Picker("When", selection: trigger.recordingStarts) { Text("Recording starts").tag(true); Text("Recording stops").tag(false) }.frame(maxWidth: 300)
            Text("Uses Halo recording-state notifications when available and an OBS / ScreenFlow / Camtasia / Loom local fallback.").font(.caption).foregroundStyle(.secondary)
        case .manual: Text("Launch this profile from Preview or HaloOpenTeleprompterSettings / HaloToggleTeleprompter notifications.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var contextEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Picker("Matching", selection: $profile.contextJoin) { ForEach(TeleprompterContextJoin.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 210); Spacer(); Button("Add Context") { profile.contexts.append(TeleprompterContextRule()) } }
            Text("Contexts actively launch this Teleprompter when they change from false to true. Any/All controls how multiple contexts combine. A context-opened Teleprompter closes when that context stops matching; manually opened Teleprompters are left alone.").font(.caption).foregroundStyle(.secondary)
            ForEach($profile.contexts) { $rule in
                VStack(alignment: .leading, spacing: 9) {
                    HStack { Toggle("", isOn: $rule.enabled).labelsHidden(); Picker("Context", selection: $rule.kind) { ForEach(TeleprompterContextKind.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 220); Spacer(); Button(role: .destructive) { profile.contexts.removeAll { $0.id == rule.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                    contextFields($rule)
                }.padding(12).background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            }
            if profile.contexts.isEmpty { Text("No context automation. Add a context to let app/window/recording/display/time state launch this profile automatically.").foregroundStyle(.secondary).padding(.vertical, 20) }
        }
    }

    @ViewBuilder private func contextFields(_ rule: Binding<TeleprompterContextRule>) -> some View {
        switch rule.wrappedValue.kind {
        case .frontmostApp, .runningApp, .windowTitle: TextField("Match app/title/bundle ID (comma separated)", text: rule.value)
        case .recordingActive: Picker("State", selection: rule.boolValue) { Text("Recording").tag(true); Text("Not recording").tag(false) }.frame(maxWidth: 280)
        case .displayCount: Stepper("Display count = \(rule.wrappedValue.numberValue)", value: rule.numberValue, in: 1...8)
        case .timeRange: HStack { Stepper("From \(rule.wrappedValue.startHour):00", value: rule.startHour, in: 0...23); Stepper("To \(rule.wrappedValue.endHour):00", value: rule.endHour, in: 0...23) }
        }
    }
}
