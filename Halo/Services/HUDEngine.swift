import AppKit
import SwiftUI
import Combine
import ApplicationServices
import CoreGraphics
import IOKit

@MainActor
final class HaloHUDRuntimeState: ObservableObject {
    @Published var event = HaloHUDEvent(kind: .volume, value: 0.5)
    @Published var configuration = HaloHUDConfiguration()
    @Published var palette: [WidgetColor] = []
    @Published var visible = false
    @Published var isExiting = false
    @Published var sequence = 0
}

struct HaloHUDNotchPresentation: Equatable {
    let event: HaloHUDEvent
    let configuration: HaloHUDConfiguration
    let side: HaloHUDNotchSide
    let screenFrame: CGRect
    let persistent: Bool
}

/// One source of truth for an active HUD that is presented by the closed notch.
/// WindowManager sizes the actual Halo surface from this state and ClosedNotchView renders it.
final class HaloHUDNotchBridge: ObservableObject {
    static let shared = HaloHUDNotchBridge()
    @Published private(set) var presentation: HaloHUDNotchPresentation?
    private init() {}

    func present(_ value: HaloHUDNotchPresentation) { presentation = value }
    func dismiss() { presentation = nil }
}

/// Callback-visible replacement state is deliberately isolated from MainActor because a CGEventTap
/// must decide synchronously whether an event is passed through to macOS.
private final class HaloHUDTapState {
    private let lock = NSLock()
    private var keys = Set<Int>()
    func replace(_ value: Set<Int>) { lock.lock(); keys = value; lock.unlock() }
    func contains(_ key: Int) -> Bool { lock.lock(); defer { lock.unlock() }; return keys.contains(key) }
}

private let haloHUDReplacementKeyNotification = Notification.Name("HaloHUDReplacementKey")
private let haloHUDTapReenableNotification = Notification.Name("HaloHUDTapReenable")

/// `CGEvent.tapCreate` requires a true C-compatible function pointer. Keep this callback completely
/// capture-free and pass callback-visible state through `refcon` instead.
private func haloHUDCGEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let state = Unmanaged<HaloHUDTapState>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        NotificationCenter.default.post(name: haloHUDTapReenableNotification, object: nil)
        return Unmanaged.passUnretained(event)
    }

    guard type.rawValue == 14,
          let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == 8 else {
        return Unmanaged.passUnretained(event)
    }

    let data = nsEvent.data1
    let key = (data & 0xFFFF0000) >> 16
    guard state.contains(key) else { return Unmanaged.passUnretained(event) }

    let keyState = ((data & 0xFFFF) & 0xFF00) >> 8
    if keyState == 0xA {
        NotificationCenter.default.post(
            name: haloHUDReplacementKeyNotification,
            object: nil,
            userInfo: ["key": key]
        )
    }

    // Swallow both down and up for keys Halo has explicitly proven it can replace.
    return nil
}

private final class HaloHUDDisplayBrightnessProvider {
    private let parameter = kIODisplayBrightnessKey as CFString
    func current() -> Double? {
        withService { service in
            var value: Float = 0
            guard IODisplayGetFloatParameter(service, 0, parameter, &value) == kIOReturnSuccess else { return nil }
            return Double(min(1, max(0, value)))
        }
    }
    @discardableResult func set(_ value: Double) -> Bool {
        let target = Float(min(1, max(0, value)))
        return withService { service in IODisplaySetFloatParameter(service, 0, parameter, target) == kIOReturnSuccess } ?? false
    }
    func canSet() -> Bool { guard let value = current() else { return false }; return set(value) }
    private func withService<T>(_ body: (io_service_t) -> T?) -> T? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while true {
            let service = IOIteratorNext(iterator); guard service != 0 else { break }
            defer { IOObjectRelease(service) }
            if let result = body(service) { return result }
        }
        return nil
    }
}

private final class HaloHUDKeyboardBrightnessProvider {
    private let classes = ["AppleHIDKeyboardEventDriverV2", "AppleHIDKeyboardEventDriver", "AppleUserHIDEventDriver"]
    private let keys = ["KeyboardBacklightBrightness", "KeyboardBacklightLevel"]
    private var registryOptions: IOOptionBits {
        IOOptionBits(kIORegistryIterateRecursively) | IOOptionBits(kIORegistryIterateParents)
    }
    func current() -> Double? {
        for name in classes {
            if let value = withEntries(name, { self.read($0) }) { return value }
        }
        return nil
    }
    @discardableResult func set(_ value: Double) -> Bool {
        let target = min(1, max(0, value))
        for name in classes {
            if withEntries(name, { self.write($0, target) ? true : nil }) == true { return true }
        }
        return false
    }
    func canSet() -> Bool { guard let value = current() else { return false }; return set(value) }
    private func read(_ entry: io_service_t) -> Double? {
        for keyName in keys {
            let key = keyName as CFString
            if let value = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key, kCFAllocatorDefault, registryOptions),
               let number = value as? NSNumber {
                let raw = number.doubleValue
                let scale = raw <= 1.0001 ? 1.0 : (raw <= 255 ? 255.0 : 4095.0)
                return min(1, max(0, raw / scale))
            }
        }
        return nil
    }
    private func write(_ entry: io_service_t, _ normalized: Double) -> Bool {
        for keyName in keys {
            let key = keyName as CFString
            guard let value = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key, kCFAllocatorDefault, registryOptions),
                  let existing = value as? NSNumber else { continue }
            let raw = existing.doubleValue
            let scale = raw <= 1.0001 ? 1.0 : (raw <= 255 ? 255.0 : 4095.0)
            let output: NSNumber = scale == 1 ? NSNumber(value: normalized) : NSNumber(value: Int((normalized * scale).rounded()))
            if IORegistryEntrySetCFProperty(entry, key, output) == KERN_SUCCESS { return true }
        }
        return false
    }
    private func withEntries<T>(_ className: String, _ body: (io_service_t) -> T?) -> T? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while true {
            let entry = IOIteratorNext(iterator); guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }
            if let result = body(entry) { return result }
        }
        return nil
    }
}

@MainActor
final class HaloHUDEngine {
    private unowned let workspace: WorkspaceStore
    private let model = HaloHUDRuntimeState()
    private let displayBrightness = HaloHUDDisplayBrightnessProvider()
    private let keyboardBrightness = HaloHUDKeyboardBrightnessProvider()
    private let tapState = HaloHUDTapState()
    private var panel: NSPanel?
    private var menuItem: NSStatusItem?
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var previewObserver: NSObjectProtocol?
    private var previewExitObserver: NSObjectProtocol?
    private var replacementObserver: NSObjectProtocol?
    private var tapReenableObserver: NSObjectProtocol?
    private var subscriptions = Set<AnyCancellable>()
    private var hideWork: DispatchWorkItem?
    private var menuHideWork: DispatchWorkItem?
    private var queue: [(HaloHUDEvent, HaloHUDConfiguration)] = []
    private var lastNonZeroVolume: Float32 = 0.5
    private var lastDisplayBrightness = 0.5
    private var lastKeyboardBrightness = 0.5
    private var lastCapsLock = false
    private var hasSeenBattery = false
    private var hasSeenCharging = false
    private var hasSeenPowerSource = false
    private var hasSeenMedia = false
    private var editorPreviewPinned = false

    init(workspace: WorkspaceStore) { self.workspace = workspace }

    func start() {
        createPanel(); configureInput(); installProviders()
        previewObserver = NotificationCenter.default.addObserver(forName: .init("HaloHUDPreview"), object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in self?.preview(note) }
        }
        previewExitObserver = NotificationCenter.default.addObserver(forName: .init("HaloHUDPreviewExit"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.editorPreviewPinned = false
                self?.hide(immediate: false)
                self?.removeMenuPresentation()
            }
        }
        replacementObserver = NotificationCenter.default.addObserver(forName: haloHUDReplacementKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let key = note.userInfo?["key"] as? Int else { return }
            Task { @MainActor in self?.handleReplacementKey(key) }
        }
        tapReenableObserver = NotificationCenter.default.addObserver(forName: haloHUDTapReenableNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reenableTap() }
        }
    }

    func stop() {
        editorPreviewPinned = false
        tearDownInput(); hideWork?.cancel(); menuHideWork?.cancel(); subscriptions.removeAll()
        if let previewObserver { NotificationCenter.default.removeObserver(previewObserver) }
        if let previewExitObserver { NotificationCenter.default.removeObserver(previewExitObserver) }
        if let replacementObserver { NotificationCenter.default.removeObserver(replacementObserver) }
        if let tapReenableObserver { NotificationCenter.default.removeObserver(tapReenableObserver) }
        HaloHUDNotchBridge.shared.dismiss()
        panel?.orderOut(nil); panel = nil
        removeMenuPresentation()
    }

    func configurationDidChange() {
        configureInput()
        if model.visible && !editorPreviewPinned {
            let settings = resolvedSettings
            guard settings.isEnabled(model.event.kind) else { hide(immediate: true); return }
            let next = resolvedConfiguration(for: model.event, settings: settings)
            route(model.event, configuration: next, depth: 0)
        }
    }

    private var resolvedSettings: HaloHUDSettings { workspace.effectiveLayout.hud ?? HaloHUDSettings() }

    private func createPanel() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 92), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .statusBar; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: HaloHUDRuntimeView(model: model)); panel.orderOut(nil); self.panel = panel
    }

    private func configureInput() {
        tearDownInput()
        let settings = resolvedSettings
        guard settings.enabled else { tapState.replace([]); return }
        workspace.audio.refresh()
        var replacement = Set<Int>()
        let defaults = UserDefaults.standard
        if settings.isEnabled(.volume), defaults.bool(forKey: "HaloHUDReplaceVolume"), workspace.audio.canSetVolume { replacement.formUnion([0, 1]) }
        if settings.isEnabled(.mute), defaults.bool(forKey: "HaloHUDReplaceVolume"), workspace.audio.canSetVolume { replacement.insert(7) }
        if settings.isEnabled(.displayBrightness), defaults.bool(forKey: "HaloHUDReplaceBrightness"), displayBrightness.canSet() { replacement.formUnion([2, 3]) }
        if settings.isEnabled(.keyboardBrightness), defaults.bool(forKey: "HaloHUDReplaceKeyboardBrightness"), keyboardBrightness.canSet() { replacement.formUnion([21, 22, 23]) }
        tapState.replace(replacement)
        if !replacement.isEmpty, AXIsProcessTrusted() { _ = installEventTap() }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.systemDefined, .flagsChanged]) { [weak self] event in
            Task { @MainActor in self?.handleObserved(event) }
        }
    }

    private func tearDownInput() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes); self.eventSource = nil }
        if let eventTap { CFMachPortInvalidate(eventTap); self.eventTap = nil }
    }

    private func installEventTap() -> Bool {
        let mask = CGEventMask(1) << 14
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: haloHUDCGEventTapCallback,
            userInfo: Unmanaged.passUnretained(tapState).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes); CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap; eventSource = source; return true
    }
    private func reenableTap() { if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) } }

    private func handleObserved(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let caps = event.modifierFlags.contains(.capsLock)
            guard caps != lastCapsLock else { return }; lastCapsLock = caps
            emit(HaloHUDEvent(kind: .capsLock, primaryText: caps ? "Caps Lock On" : "Caps Lock Off", value: caps ? 1 : 0, state: caps ? "on" : "off")); return
        }
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }
        let data = event.data1, key = (data & 0xFFFF0000) >> 16
        let keyState = ((data & 0xFFFF) & 0xFF00) >> 8
        guard keyState == 0xA, !tapState.contains(key) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in self?.emitObservedKey(key) }
    }

    private func emitObservedKey(_ key: Int) {
        switch key {
        case 0, 1, 7:
            workspace.audio.refresh(); let value = Double(min(1, max(0, workspace.audio.volume)))
            if key == 7 || value <= 0.005 { emit(HaloHUDEvent(kind: .mute, icon: value <= 0.005 ? "speaker.slash.fill" : volumeSymbol(Float32(value)), primaryText: value <= 0.005 ? "Muted" : "Volume", value: value)) }
            else { emit(HaloHUDEvent(kind: .volume, icon: volumeSymbol(Float32(value)), value: value)) }
        case 2, 3:
            let value = displayBrightness.current() ?? min(1, max(0, lastDisplayBrightness + (key == 2 ? 0.0625 : -0.0625)))
            lastDisplayBrightness = value; emit(HaloHUDEvent(kind: .displayBrightness, icon: brightnessSymbol(value), value: value))
        case 21, 22, 23:
            let fallback = key == 23 ? (lastKeyboardBrightness > 0.01 ? 0 : 0.5) : min(1, max(0, lastKeyboardBrightness + (key == 21 ? 0.0625 : -0.0625)))
            let value = keyboardBrightness.current() ?? fallback; lastKeyboardBrightness = value
            emit(HaloHUDEvent(kind: .keyboardBrightness, icon: value <= 0.01 ? "keyboard" : "keyboard.fill", value: value))
        default: break
        }
    }

    private func handleReplacementKey(_ key: Int) {
        switch key {
        case 0, 1, 7:
            workspace.audio.refresh(); let current = min(1, max(0, workspace.audio.volume)); let step: Float32 = 0.0625
            if key == 7 {
                let next: Float32
                if current > 0.005 { lastNonZeroVolume = current; next = 0 } else { next = max(0.05, lastNonZeroVolume) }
                workspace.audio.setVolume(next)
                emit(HaloHUDEvent(kind: .mute, icon: next <= 0.005 ? "speaker.slash.fill" : volumeSymbol(next), primaryText: next <= 0.005 ? "Muted" : "Volume", value: Double(next)))
            } else {
                let next = min(1, max(0, current + (key == 0 ? step : -step)))
                if next > 0.01 { lastNonZeroVolume = next }; workspace.audio.setVolume(next)
                emit(HaloHUDEvent(kind: .volume, icon: volumeSymbol(next), value: Double(next)))
            }
        case 2, 3:
            let current = displayBrightness.current() ?? lastDisplayBrightness
            let next = min(1, max(0, current + (key == 2 ? 0.0625 : -0.0625)))
            if displayBrightness.set(next) { lastDisplayBrightness = next }
            emit(HaloHUDEvent(kind: .displayBrightness, icon: brightnessSymbol(next), value: next))
        case 21, 22, 23:
            let current = keyboardBrightness.current() ?? lastKeyboardBrightness
            let next = key == 23 ? (current > 0.01 ? 0 : max(0.25, lastKeyboardBrightness)) : min(1, max(0, current + (key == 21 ? 0.0625 : -0.0625)))
            if next > 0.01 { lastKeyboardBrightness = next }; _ = keyboardBrightness.set(next)
            emit(HaloHUDEvent(kind: .keyboardBrightness, icon: next <= 0.01 ? "keyboard" : "keyboard.fill", value: next))
        default: break
        }
    }

    private func installProviders() {
        workspace.system.$battery.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] value in
            guard let self, let value else { return }; defer { self.hasSeenBattery = true }; guard self.hasSeenBattery else { return }
            self.emit(HaloHUDEvent(kind: .batteryStatus, secondaryText: "Battery", value: Double(value), minimumValue: 0, maximumValue: 100, progress: Double(value) / 100))
        }.store(in: &subscriptions)
        workspace.system.$charging.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] charging in
            guard let self else { return }; defer { self.hasSeenCharging = true }; guard self.hasSeenCharging else { return }
            self.emit(HaloHUDEvent(kind: .chargingState, icon: charging ? "bolt.fill" : "bolt.slash.fill", primaryText: charging ? "Charging Started" : "Charging Stopped", state: charging ? "charging" : "notCharging"))
        }.store(in: &subscriptions)
        workspace.system.$onBattery.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] onBattery in
            guard let self else { return }; defer { self.hasSeenPowerSource = true }; guard self.hasSeenPowerSource else { return }
            self.emit(HaloHUDEvent(kind: .powerSourceChanged, icon: onBattery ? "battery.75percent" : "powerplug.fill", primaryText: onBattery ? "Using Battery" : "Using Power Adapter", state: onBattery ? "battery" : "adapter"))
        }.store(in: &subscriptions)
        workspace.media.$title.removeDuplicates().receive(on: RunLoop.main).sink { [weak self] title in
            guard let self else { return }; defer { self.hasSeenMedia = true }; guard self.hasSeenMedia, self.workspace.media.isPlaying else { return }
            self.emit(HaloHUDEvent(kind: .mediaChanged, icon: "music.note", primaryText: title, secondaryText: self.workspace.media.artist, artworkKey: title))
        }.store(in: &subscriptions)
        workspace.audio.$selected.removeDuplicates().receive(on: RunLoop.main).dropFirst().sink { [weak self] id in
            guard let self else { return }
            let name = self.workspace.audio.devices.first(where: { $0.id == id })?.name ?? "Audio Output"
            self.emit(HaloHUDEvent(kind: .audioOutputChanged, icon: "speaker.wave.2.fill", primaryText: "Audio Output", secondaryText: name, metadata: ["deviceName": name]))
        }.store(in: &subscriptions)
        workspace.audio.$devices.map { $0.map(\.id) }.removeDuplicates().receive(on: RunLoop.main).dropFirst().sink { [weak self] ids in
            guard let self else { return }
            self.emit(HaloHUDEvent(kind: .audioDeviceConnected, icon: "hifispeaker.fill", primaryText: "Audio Devices", secondaryText: "\(ids.count) available", metadata: ["deviceName": "\(ids.count) available"]))
        }.store(in: &subscriptions)
    }

    private func preview(_ note: Notification) {
        let raw = note.userInfo?["kind"] as? String ?? "volume"
        let value = (note.userInfo?["value"] as? Double) ?? 0.68
        let persistent = note.userInfo?["persistent"] as? Bool ?? false
        let kind: HaloHUDEventKind
        switch raw { case "brightness": kind = .displayBrightness; case "keyboard": kind = .keyboardBrightness; default: kind = HaloHUDEventKind(rawValue: raw) ?? .volume }
        let event = HaloHUDEvent.preview(kind: kind, value: value)
        editorPreviewPinned = persistent

        if let suppliedConfiguration = note.userInfo?["configuration"] as? HaloHUDConfiguration {
            guard suppliedConfiguration.presentation.target != .disabled else {
                hide(immediate: true)
                removeMenuPresentation()
                return
            }
            route(event, configuration: suppliedConfiguration, depth: 0)
        } else {
            emit(event, force: true)
        }
    }

    func emit(_ event: HaloHUDEvent, force: Bool = false) {
        let settings = resolvedSettings
        guard force || settings.isEnabled(event.kind) else { return }
        let configuration = resolvedConfiguration(for: event, settings: settings)
        guard configuration.presentation.target != .disabled else { return }
        route(event, configuration: configuration, depth: 0)
    }

    private func resolvedConfiguration(for event: HaloHUDEvent, settings: HaloHUDSettings) -> HaloHUDConfiguration {
        var configuration = settings.configuration(for: event.kind)
        if let target = event.preferredTarget { configuration.presentation.target = target }
        let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        if let rule = settings.appRules.first(where: { $0.enabled && !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier == bundle }) { configuration.presentation.target = rule.target }
        return configuration
    }

    private func route(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration, depth: Int) {
        guard depth < 3 else { return }
        switch configuration.presentation.target {
        case .disabled: return
        case .menuBar: showMenuBar(event, configuration: configuration)
        case .notch:
            guard let screen = screen(for: configuration), screen.safeAreaInsets.top > 0 else { routeFallback(event, configuration: configuration, depth: depth); return }
            let side = resolvedNotchSide(configuration.presentation.notchSide)
            if configuration.behavior.collision == .showExternally && notchOccupied(side) { routeFallback(event, configuration: configuration, depth: depth); return }
            var resolved = configuration
            resolved.presentation.notchSide = side
            showNotch(event, configuration: resolved, screen: screen)
        case .floating, .nearCursor, .screenEdge: showPanel(event, configuration: configuration)
        }
    }

    private func routeFallback(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration, depth: Int) {
        var fallback = configuration; fallback.presentation.target = configuration.behavior.fallbackTarget
        if fallback.presentation.target == .notch || fallback.presentation.target == .disabled { fallback.presentation.target = .floating }
        route(event, configuration: fallback, depth: depth + 1)
    }

    private func shouldQueue(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration) -> Bool {
        guard model.visible, model.event.kind != event.kind,
              configuration.behavior.collision == .queue, !editorPreviewPinned else { return false }
        if queue.count < 12 { queue.append((event, configuration)) }
        return true
    }

    private func showNotch(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration, screen: NSScreen) {
        if shouldQueue(event, configuration: configuration) { return }
        removeMenuPresentation()
        panel?.orderOut(nil)

        let repeated = model.visible && model.event.kind == event.kind && model.configuration.presentation.target == .notch
        let previousHideWork = hideWork
        model.event = event
        model.configuration = configuration
        model.palette = workspace.media.artworkColors
        model.sequence += 1
        model.isExiting = false
        model.visible = true

        HaloHUDNotchBridge.shared.present(HaloHUDNotchPresentation(
            event: event,
            configuration: configuration,
            side: configuration.presentation.notchSide,
            screenFrame: screen.frame,
            persistent: editorPreviewPinned
        ))

        guard !editorPreviewPinned else { hideWork?.cancel(); return }
        if repeated && configuration.behavior.interrupt == .continue, previousHideWork != nil { return }
        if repeated && configuration.behavior.interrupt == .restart { hideWork?.cancel() }
        scheduleHide(configuration.behavior.displayDuration)
    }

    private func showPanel(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration) {
        guard let panel else { return }
        if shouldQueue(event, configuration: configuration) { return }
        removeMenuPresentation()
        HaloHUDNotchBridge.shared.dismiss()

        let repeated = model.visible && model.event.kind == event.kind && model.configuration.presentation.target != .notch
        let previousHideWork = hideWork
        model.event = event
        model.configuration = configuration
        model.palette = workspace.media.artworkColors
        model.sequence += 1
        position(panel, event: event, configuration: configuration)
        panel.orderFrontRegardless()

        if repeated && !editorPreviewPinned {
            switch configuration.behavior.interrupt {
            case .restart:
                hideWork?.cancel()
                model.isExiting = false
                model.visible = false
                DispatchQueue.main.async { [weak self] in
                    self?.model.isExiting = false
                    self?.model.visible = true
                }
            case .continue:
                model.isExiting = false
                model.visible = true
            case .blend:
                hideWork?.cancel()
                model.isExiting = false
                model.visible = true
            }
        } else if !repeated {
            hideWork?.cancel()
            model.isExiting = false
            model.visible = false
            DispatchQueue.main.async { [weak self] in
                self?.model.isExiting = false
                self?.model.visible = true
            }
        } else {
            model.isExiting = false
            model.visible = true
        }

        guard !editorPreviewPinned else { hideWork?.cancel(); return }
        if repeated && configuration.behavior.interrupt == .continue, previousHideWork != nil { return }
        scheduleHide(configuration.behavior.displayDuration)
    }

    private func scheduleHide(_ delay: Double) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide(immediate: false) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + min(10, max(0.2, delay)), execute: work)
    }

    private func hide(immediate: Bool) {
        hideWork?.cancel(); hideWork = nil
        let wasNotch = model.configuration.presentation.target == .notch
        if immediate {
            model.isExiting = false
            model.visible = false
            if wasNotch { HaloHUDNotchBridge.shared.dismiss() }
            panel?.orderOut(nil)
            presentNext()
            return
        }
        model.isExiting = true
        model.visible = false
        let delay = min(2, max(0, model.configuration.animation.exitDuration))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.model.visible else { return }
            if wasNotch { HaloHUDNotchBridge.shared.dismiss() }
            self.panel?.orderOut(nil)
            self.model.isExiting = false
            self.presentNext()
        }
    }

    private func presentNext() {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        route(next.0, configuration: next.1, depth: 0)
    }

    private func showMenuBar(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration) {
        hideWork?.cancel(); hideWork = nil
        HaloHUDNotchBridge.shared.dismiss()
        model.event = event
        model.configuration = configuration
        model.visible = false
        panel?.orderOut(nil)
        if menuItem == nil { menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength) }
        guard let button = menuItem?.button else { return }
        button.image = configuration.components.icon ? NSImage(systemSymbolName: event.icon, accessibilityDescription: event.primaryText) : nil
        let valueText = HaloHUDRenderFormatting.valueText(event: event, configuration: configuration)
        if configuration.components.label && !valueText.isEmpty {
            button.title = " \(event.primaryText) · \(valueText)"
        } else if configuration.components.label {
            button.title = " \(event.primaryText)"
        } else if !valueText.isEmpty {
            button.title = " \(valueText)"
        } else {
            button.title = ""
        }
        menuHideWork?.cancel()
        guard !editorPreviewPinned else { return }
        let work = DispatchWorkItem { [weak self] in self?.removeMenuPresentation() }
        menuHideWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + configuration.behavior.displayDuration, execute: work)
    }

    private func removeMenuPresentation() {
        menuHideWork?.cancel(); menuHideWork = nil
        if let menuItem { NSStatusBar.system.removeStatusItem(menuItem); self.menuItem = nil }
    }

    private func screen(for configuration: HaloHUDConfiguration) -> NSScreen? {
        switch configuration.presentation.displayTarget {
        case .builtIn: return NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
        case .main: return NSScreen.main ?? NSScreen.screens.first
        case .active: return NSScreen.main ?? mouseScreen()
        case .mouse: return mouseScreen()
        }
    }
    private func mouseScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func closedNotchAppearance(for screen: NSScreen) -> Appearance {
        let id = WindowManager.displayID(screen)
        if let override = workspace.settings.displays.first(where: { $0.id == id && $0.enabled }),
           let layout = override.layout {
            return layout.appearance
        }
        return workspace.effectiveLayout.appearance
    }

    private func position(_ panel: NSPanel, event: HaloHUDEvent, configuration: HaloHUDConfiguration) {
        guard let screen = screen(for: configuration) else { return }
        let visible = screen.visibleFrame, full = screen.frame, margin = CGFloat(max(0, configuration.layout.edgeMargin))
        let resolvedSize = HaloHUDLayoutMetrics.resolvedSize(event: event, configuration: configuration)
        var width = resolvedSize.width
        var height = resolvedSize.height
        var x = visible.midX - width / 2, y = visible.maxY - height - margin
        switch configuration.presentation.target {
        case .screenEdge:
            let length = CGFloat(configuration.presentation.screenEdgeLength), thickness = CGFloat(configuration.presentation.screenEdgeThickness)
            switch configuration.presentation.screenEdge {
            case .left: width = thickness; height = min(visible.height - 2 * margin, length); x = visible.minX + margin; y = visible.midY - height / 2
            case .right: width = thickness; height = min(visible.height - 2 * margin, length); x = visible.maxX - margin - width; y = visible.midY - height / 2
            case .top: width = min(visible.width - 2 * margin, length); height = thickness; x = visible.midX - width / 2; y = visible.maxY - margin - height
            case .bottom: width = min(visible.width - 2 * margin, length); height = thickness; x = visible.midX - width / 2; y = visible.minY + margin
            }
        case .nearCursor:
            let mouse = NSEvent.mouseLocation; x = mouse.x + 18; y = mouse.y - height - 18
        case .notch:
            let appearance = closedNotchAppearance(for: screen)
            let notch = configuration.presentation.resolvedNotch
            let physicalWidth: CGFloat = {
                if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { return max(0, right.minX - left.maxX) }
                return screen.safeAreaInsets.top > 0 ? 190 : 0
            }()
            width = CGFloat(notch.width)
            height = CGFloat(min(100, max(16, appearance.surface.compactHeight)))
            let offsets = appearance.surface.offsets ?? SurfaceOffsets()
            let side = resolvedNotchSide(configuration.presentation.notchSide)
            y = full.maxY - height - CGFloat(offsets.closedY)
            switch side {
            case .left: x = full.midX - physicalWidth / 2 - width
            case .right: x = full.midX + physicalWidth / 2
            case .full, .automatic: x = full.midX - width / 2
            }
            x += CGFloat(offsets.closedX + notch.horizontalOffset)
        default:
            switch configuration.presentation.floatingPosition {
            case .topLeft: x = visible.minX + margin; y = visible.maxY - height - margin
            case .top: x = visible.midX - width / 2; y = visible.maxY - height - margin
            case .topRight: x = visible.maxX - width - margin; y = visible.maxY - height - margin
            case .center, .custom: x = visible.midX - width / 2; y = visible.midY - height / 2
            case .bottomLeft: x = visible.minX + margin; y = visible.minY + margin
            case .bottom: x = visible.midX - width / 2; y = visible.minY + margin
            case .bottomRight: x = visible.maxX - width - margin; y = visible.minY + margin
            }
        }
        if configuration.presentation.target != .notch {
            x += CGFloat(configuration.layout.offsetX)
            y -= CGFloat(configuration.layout.offsetY)
        }
        x = min(visible.maxX - width - 2, max(visible.minX + 2, x))
        if configuration.presentation.target == .notch {
            let appearance = closedNotchAppearance(for: screen)
            let closedY = CGFloat((appearance.surface.offsets ?? SurfaceOffsets()).closedY)
            y = full.maxY - height - closedY
        } else {
            y = min(full.maxY - height, max(visible.minY + 2, y))
        }
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func resolvedNotchSide(_ requested: HaloHUDNotchSide) -> HaloHUDNotchSide {
        guard requested == .automatic else { return requested }
        let closed = workspace.effectiveLayout.closedNotch ?? ClosedNotchOptions()
        let leftBusy = closed.left != .none, rightBusy = closed.right != .none
        if !rightBusy { return .right }; if !leftBusy { return .left }; return .right
    }
    private func notchOccupied(_ side: HaloHUDNotchSide) -> Bool {
        let closed = workspace.effectiveLayout.closedNotch ?? ClosedNotchOptions()
        switch side { case .left: return closed.left != .none; case .right: return closed.right != .none; case .full: return closed.left != .none || closed.right != .none; case .automatic: return false }
    }
    private func volumeSymbol(_ value: Float32) -> String {
        if value <= 0.005 { return "speaker.slash.fill" }; if value < 0.34 { return "speaker.wave.1.fill" }; if value < 0.68 { return "speaker.wave.2.fill" }; return "speaker.wave.3.fill"
    }
    private func brightnessSymbol(_ value: Double) -> String { value <= 0.12 ? "sun.min.fill" : "sun.max.fill" }
}

extension HaloHUDEvent {
    static func preview(kind: HaloHUDEventKind, value: Double) -> HaloHUDEvent {
        let p = min(1, max(0, value))
        switch kind {
        case .volume:
            let icon = p <= 0.005 ? "speaker.slash.fill" : p < 0.34 ? "speaker.wave.1.fill" : p < 0.68 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
            return HaloHUDEvent(kind: kind, icon: icon, value: p)
        case .mute:
            return HaloHUDEvent(kind: kind, icon: p < 0.5 ? "speaker.slash.fill" : "speaker.wave.2.fill", primaryText: p < 0.5 ? "Muted" : "Volume", value: p)
        case .displayBrightness:
            return HaloHUDEvent(kind: kind, icon: p <= 0.12 ? "sun.min.fill" : "sun.max.fill", value: p)
        case .keyboardBrightness:
            return HaloHUDEvent(kind: kind, icon: p <= 0.01 ? "keyboard" : "keyboard.fill", value: p)
        case .batteryStatus:
            let percent = (p * 100).rounded()
            return HaloHUDEvent(kind: kind, secondaryText: "Battery", value: percent, minimumValue: 0, maximumValue: 100, progress: p)
        case .chargingState:
            return HaloHUDEvent(kind: kind, icon: "bolt.fill", primaryText: "Charging Started", state: "charging")
        case .powerSourceChanged:
            return HaloHUDEvent(kind: kind, icon: "powerplug.fill", primaryText: "Using Power Adapter", state: "adapter")
        case .audioOutputChanged:
            return HaloHUDEvent(kind: kind, icon: "speaker.wave.2.fill", primaryText: "Audio Output", secondaryText: "MacBook Pro Speakers", metadata: ["deviceName": "MacBook Pro Speakers"])
        case .audioInputChanged:
            return HaloHUDEvent(kind: kind, icon: "mic.and.signal.meter.fill", primaryText: "Audio Input", secondaryText: "MacBook Microphone", metadata: ["deviceName": "MacBook Microphone"])
        case .audioDeviceConnected:
            return HaloHUDEvent(kind: kind, icon: "hifispeaker.fill", primaryText: "Audio Device Connected", secondaryText: "External Audio Device", metadata: ["deviceName": "External Audio Device"])
        case .capsLock:
            return HaloHUDEvent(kind: kind, icon: "capslock.fill", primaryText: "Caps Lock On", state: "on")
        case .mediaChanged:
            return HaloHUDEvent(kind: kind, icon: "music.note", primaryText: "Example Song", secondaryText: "Example Artist", artworkKey: "preview")
        case .microphoneMute:
            return HaloHUDEvent(kind: kind, icon: "mic.slash.fill", primaryText: "Microphone Muted", state: "muted")
        case .microphoneState, .microphoneActivity:
            return HaloHUDEvent(kind: kind, icon: "mic.fill", primaryText: kind.title, state: "active")
        case .wifiState:
            return HaloHUDEvent(kind: kind, icon: "wifi", primaryText: "Wi-Fi Connected", secondaryText: "Network")
        case .bluetoothState:
            return HaloHUDEvent(kind: kind, icon: "wave.3.right", primaryText: "Bluetooth On", state: "on")
        case .focusState:
            return HaloHUDEvent(kind: kind, icon: "moon.fill", primaryText: "Focus Enabled", secondaryText: "Do Not Disturb")
        case .screenshotCaptured:
            return HaloHUDEvent(kind: kind, icon: "camera.viewfinder", primaryText: "Screenshot Captured")
        case .screenRecordingState:
            return HaloHUDEvent(kind: kind, icon: "record.circle", primaryText: "Screen Recording", state: "active")
        case .cameraActivity:
            return HaloHUDEvent(kind: kind, icon: "video.fill", primaryText: "Camera Active", state: "active")
        }
    }
}

enum HaloHUDRenderFormatting {
    static func valueText(event: HaloHUDEvent, configuration: HaloHUDConfiguration) -> String {
        guard let value = event.value else { return "" }
        if configuration.components.progress && (configuration.progressStyle == .gauge || configuration.progressStyle == .numberOnly) {
            return ""
        }
        let progress = min(1, max(0, event.progress ?? 0))
        let display = event.maximumValue == 100 ? Int(value.rounded()) : Int((progress * 100).rounded())
        if configuration.components.percentage { return "\(display)%" }
        if configuration.components.value { return "\(display)" }
        return ""
    }
}

enum HaloHUDLayoutMetrics {
    static func resolvedSize(event: HaloHUDEvent, configuration: HaloHUDConfiguration) -> CGSize {
        switch configuration.presentation.target {
        case .screenEdge:
            let length = CGFloat(max(40, configuration.presentation.screenEdgeLength))
            let thickness = CGFloat(max(1, configuration.presentation.screenEdgeThickness))
            return (configuration.presentation.screenEdge == .left || configuration.presentation.screenEdge == .right)
                ? CGSize(width: thickness, height: length)
                : CGSize(width: length, height: thickness)
        case .notch:
            let notch = configuration.presentation.resolvedNotch
            let height = max(24, max(notch.iconSize * 1.45, notch.textSize * 1.9))
            return CGSize(width: max(48, notch.width), height: height)
        case .menuBar:
            return .zero
        default:
            break
        }

        let paddingX = max(0, configuration.layout.horizontalPadding)
        let paddingY = max(0, configuration.layout.verticalPadding)
        let spacing = max(0, configuration.layout.spacing)
        let iconWidth = configuration.components.icon ? max(configuration.iconSize * 1.2, 12) : 0
        let iconHeight = configuration.components.icon ? max(configuration.iconSize * 1.25, 12) : 0
        let value = HaloHUDRenderFormatting.valueText(event: event, configuration: configuration)
        let valueWidth = value.isEmpty ? 0 : textWidth(value, size: configuration.textSize, weight: .bold)
        let secondary = event.metadata["deviceName"] ?? event.secondaryText ?? ""
        let labelWidth = configuration.components.label ? textWidth(event.primaryText, size: configuration.textSize, weight: .semibold) : 0
        let secondaryWidth = configuration.components.deviceName && !secondary.isEmpty
            ? textWidth(secondary, size: max(8, configuration.textSize * 0.72), weight: .regular)
            : 0
        let textBlockWidth = max(labelWidth, secondaryWidth)
        let hasText = textBlockWidth > 0 || valueWidth > 0
        let headerGap = textBlockWidth > 0 && valueWidth > 0 ? 8.0 : 0
        let headerWidth = textBlockWidth + headerGap + valueWidth
        let headerHeight: Double = {
            var height = 0.0
            if configuration.components.label { height += configuration.textSize * 1.25 }
            if configuration.components.deviceName && !secondary.isEmpty { height += max(8, configuration.textSize * 0.72) * 1.2 + 1 }
            if height == 0 && valueWidth > 0 { height = configuration.textSize * 1.25 }
            return height
        }()
        let progress = progressFootprint(configuration: configuration)
        let hasProgress = configuration.components.progress && event.progress != nil

        let natural: CGSize
        if configuration.layout.style == .vertical && !configuration.layout.compact {
            var heights: [Double] = []
            if iconHeight > 0 { heights.append(iconHeight) }
            if hasText { heights.append(max(headerHeight, configuration.textSize * 1.25)) }
            if hasProgress { heights.append(progress.height) }
            let gaps = Double(max(0, heights.count - 1)) * spacing
            natural = CGSize(
                width: max(iconWidth, headerWidth, hasProgress ? progress.width : 0) + 2 * paddingX,
                height: heights.reduce(0, +) + gaps + 2 * paddingY
            )
        } else if configuration.layout.style == .compact || configuration.layout.compact {
            var widths: [Double] = []
            if iconWidth > 0 { widths.append(iconWidth) }
            if configuration.components.label { widths.append(labelWidth) }
            if configuration.components.deviceName && secondaryWidth > 0 { widths.append(secondaryWidth) }
            if valueWidth > 0 { widths.append(valueWidth) }
            if hasProgress { widths.append(min(150, progress.width)) }
            natural = CGSize(
                width: widths.reduce(0, +) + Double(max(0, widths.count - 1)) * max(3, spacing) + 2 * paddingX,
                height: max(iconHeight, max(headerHeight, hasProgress ? progress.height : 0)) + 2 * paddingY
            )
        } else {
            let rightWidth = max(headerWidth, hasProgress ? progress.width : 0)
            let rightHeight = headerHeight + (hasText && hasProgress ? max(3, spacing * 0.45) : 0) + (hasProgress ? progress.height : 0)
            let gap = iconWidth > 0 && rightWidth > 0 ? spacing : 0
            natural = CGSize(
                width: iconWidth + gap + rightWidth + 2 * paddingX,
                height: max(iconHeight, rightHeight) + 2 * paddingY
            )
        }

        let requestedWidth = min(configuration.layout.maximumWidth, max(configuration.layout.minimumWidth, configuration.layout.width))
        let requestedHeight = max(24, configuration.layout.height)
        let width = min(configuration.layout.maximumWidth, max(configuration.layout.minimumWidth, max(requestedWidth, Double(natural.width))))
        let height = max(requestedHeight, Double(natural.height))
        return CGSize(width: width, height: height)
    }

    private static func progressFootprint(configuration: HaloHUDConfiguration) -> CGSize {
        switch configuration.progressStyle {
        case .ring, .arc:
            return CGSize(width: 36, height: 36)
        case .gauge:
            return CGSize(width: 40, height: 40)
        case .iconFill:
            let size = max(24, configuration.iconSize)
            return CGSize(width: size, height: size)
        case .numberOnly:
            return CGSize(width: max(34, configuration.textSize * 2.4), height: max(20, configuration.textSize * 1.5))
        case .dots:
            let count = max(2, min(32, configuration.segments))
            return CGSize(width: Double(count * 5 + max(0, count - 1) * 4), height: 7)
        case .wave:
            return CGSize(width: 88, height: 20)
        case .segmentedBar:
            return CGSize(width: 120, height: 7)
        case .minimalLine:
            return CGSize(width: 120, height: 2)
        case .bar, .glow:
            return CGSize(width: 120, height: 7)
        }
    }

    private static func textWidth(_ text: String, size: Double, weight: NSFont.Weight) -> Double {
        guard !text.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: CGFloat(max(8, size)), weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private struct HaloHUDRuntimeView: View {
    @ObservedObject var model: HaloHUDRuntimeState
    var body: some View {
        HaloHUDRenderView(
            event: model.event,
            configuration: model.configuration,
            palette: model.palette,
            visible: model.visible,
            isExiting: model.isExiting
        )
    }
}

struct HaloHUDRenderView: View {
    let event: HaloHUDEvent
    let configuration: HaloHUDConfiguration
    var palette: [WidgetColor] = []
    var visible = true
    var isExiting = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private var isClosedNotchTarget: Bool { configuration.presentation.target == .notch }
    private var notch: HaloHUDNotchConfiguration { configuration.presentation.resolvedNotch }
    private var effectiveIconSize: Double { isClosedNotchTarget ? notch.iconSize : configuration.iconSize }
    private var effectiveTextSize: Double { isClosedNotchTarget ? notch.textSize : configuration.textSize }
    private var effectiveSpacing: Double { isClosedNotchTarget ? notch.spacing : configuration.layout.spacing }
    private var progress: Double { min(1, max(0, event.progress ?? 0)) }
    private var accent: Color { resolvedColor(configuration.appearance.primary) }
    private var secondaryColor: Color { resolvedColor(configuration.appearance.secondary) }
    private var progressColor: Color { resolvedColor(configuration.appearance.progress) }
    private var borderColor: Color { resolvedColor(configuration.appearance.borderColor) }
    private var glowColor: Color { resolvedColor(configuration.appearance.glowColor) }
    private var inactiveColor: Color { secondaryColor.opacity(0.16) }
    private var isVerticalScreenEdge: Bool {
        configuration.presentation.target == .screenEdge &&
            (configuration.presentation.screenEdge == .left || configuration.presentation.screenEdge == .right)
    }
    private var deviceText: String? {
        if let value = event.metadata["deviceName"], !value.isEmpty { return value }
        if let detail = event.secondaryText, !detail.isEmpty { return detail }
        return nil
    }
    private var renderedValueText: String { HaloHUDRenderFormatting.valueText(event: event, configuration: configuration) }
    private var hasHeaderContent: Bool {
        configuration.components.label ||
        (configuration.components.deviceName && deviceText != nil) ||
        !renderedValueText.isEmpty
    }
    private var hasProgressContent: Bool { configuration.components.progress && event.progress != nil }

    var body: some View {
        Group {
            if configuration.presentation.target == .screenEdge { edgeContent }
            else if isClosedNotchTarget { compact }
            else if configuration.layout.style == .vertical { vertical }
            else if configuration.layout.style == .compact || configuration.layout.compact { compact }
            else { horizontal }
        }
        .padding(.horizontal,
                 configuration.presentation.target == .screenEdge ? 0 :
                    isClosedNotchTarget ? notch.horizontalPadding : configuration.layout.horizontalPadding)
        .padding(.vertical,
                 configuration.presentation.target == .screenEdge || isClosedNotchTarget ? 0 : configuration.layout.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background { background }
        .overlay { noiseOverlay }
        .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
            .stroke(borderColor.opacity(!isClosedNotchTarget && configuration.appearance.border ? configuration.appearance.borderOpacity : 0), lineWidth: contrast == .increased ? 1.5 : 1))
        .shadow(color: !isClosedNotchTarget && configuration.appearance.shadow ? .black.opacity(0.32) : .clear, radius: 16, y: 7)
        .shadow(color: !isClosedNotchTarget && configuration.appearance.glow ? glowColor.opacity(0.58) : .clear, radius: !isClosedNotchTarget && configuration.appearance.glow ? 14 : 0)
        .clipped()
        .scaleEffect(x: visible ? 1 : hiddenScale.width, y: visible ? 1 : hiddenScale.height)
        .offset(hiddenOffset)
        .opacity(visible ? 1 : hiddenOpacity)
        .animation(visibilityAnimation, value: visible)
        .animation(progressAnimation, value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(event.primaryText)
        .accessibilityValue(event.progress.map { "\(Int($0 * 100)) percent" } ?? (event.secondaryText ?? ""))
    }

    private var effectiveCornerRadius: Double {
        if isClosedNotchTarget { return 0 }
        return configuration.presentation.target == .screenEdge ? min(configuration.layout.cornerRadius, 8) : configuration.layout.cornerRadius
    }

    private var horizontal: some View {
        HStack(spacing: effectiveSpacing) {
            icon
            if hasHeaderContent || hasProgressContent {
                VStack(alignment: .leading, spacing: hasHeaderContent && hasProgressContent ? max(3, effectiveSpacing * 0.45) : 0) {
                    if hasHeaderContent { header }
                    if hasProgressContent { progressView }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var vertical: some View {
        VStack(spacing: effectiveSpacing) {
            icon
            if hasHeaderContent { header }
            if hasProgressContent { progressView }
        }
    }

    private var compact: some View {
        HStack(spacing: max(3, effectiveSpacing)) {
            icon
            if configuration.components.label { Text(event.primaryText).lineLimit(1) }
            if configuration.components.deviceName, let deviceText { Text(deviceText).foregroundStyle(secondaryColor).lineLimit(1) }
            if !renderedValueText.isEmpty { valueText }
            if hasProgressContent {
                progressView.frame(maxWidth: isClosedNotchTarget ? notch.progressWidth : 150)
            }
        }
        .font(.system(size: effectiveTextSize, weight: .semibold, design: .rounded))
        .minimumScaleFactor(isClosedNotchTarget ? 0.65 : 1)
        .lineLimit(1)
    }

    private var edgeContent: some View {
        GeometryReader { proxy in
            if isVerticalScreenEdge {
                progressView
                    .frame(width: proxy.size.height, height: proxy.size.width)
                    .rotationEffect(.degrees(configuration.presentation.screenEdge == .left ? 90 : -90))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            } else {
                progressView
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .clipped()
    }

    @ViewBuilder private var icon: some View {
        if configuration.components.icon {
            Image(systemName: event.icon)
                .font(.system(size: effectiveIconSize, weight: .semibold))
                .foregroundStyle(accent)
                .frame(minWidth: effectiveIconSize * 1.2)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if configuration.components.label || (configuration.components.deviceName && deviceText != nil) {
                VStack(alignment: .leading, spacing: 1) {
                    if configuration.components.label {
                        Text(event.primaryText)
                            .font(.system(size: effectiveTextSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }
                    if configuration.components.deviceName, let deviceText {
                        Text(deviceText)
                            .font(.system(size: max(8, effectiveTextSize * 0.72)))
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                    } else if configuration.components.label, let secondary = event.secondaryText, !secondary.isEmpty {
                        Text(secondary)
                            .font(.system(size: max(8, effectiveTextSize * 0.72)))
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                    }
                }
            }
            if !renderedValueText.isEmpty {
                Spacer(minLength: 4)
                valueText
            }
        }
    }

    @ViewBuilder private var valueText: some View {
        if !renderedValueText.isEmpty {
            Text(renderedValueText)
                .font(.system(size: effectiveTextSize, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
        }
    }

    @ViewBuilder private var progressView: some View {
        if configuration.components.progress, event.progress != nil {
            switch configuration.progressStyle {
            case .bar:
                GeometryReader { p in
                    ZStack(alignment: .leading) {
                        Capsule().fill(inactiveColor)
                        Capsule().fill(progressColor).frame(width: max(2, p.size.width * progress))
                    }
                }.frame(height: configuration.presentation.target == .screenEdge ? nil : 7)
            case .segmentedBar:
                HStack(spacing: 2) {
                    ForEach(0..<max(2, configuration.segments), id: \.self) { i in
                        Capsule().fill(Double(i + 1) / Double(max(2, configuration.segments)) <= progress ? progressColor : inactiveColor)
                    }
                }.frame(height: 7)
            case .dots:
                HStack(spacing: 4) {
                    ForEach(0..<max(2, min(32, configuration.segments)), id: \.self) { i in
                        Circle().fill(Double(i + 1) / Double(max(2, configuration.segments)) <= progress ? progressColor : inactiveColor).frame(width: 5, height: 5)
                    }
                }
            case .ring:
                circularProgress(trimStart: 0, trimLength: progress)
            case .arc:
                circularProgress(trimStart: 0.12, trimLength: progress * 0.76)
            case .gauge:
                ZStack {
                    Circle().trim(from: 0.12, to: 0.88).stroke(inactiveColor, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(90))
                    Circle().trim(from: 0.12, to: 0.12 + progress * 0.76).stroke(progressColor, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(90))
                    Text("\(Int((progress * 100).rounded()))%").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(accent)
                }.frame(width: isClosedNotchTarget ? 30 : 40, height: isClosedNotchTarget ? 30 : 40)
            case .numberOnly:
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: effectiveTextSize * 1.2, weight: .bold, design: .rounded))
                    .foregroundStyle(progressColor)
            case .iconFill:
                ZStack {
                    Image(systemName: event.icon).foregroundStyle(inactiveColor)
                    Image(systemName: event.icon).foregroundStyle(progressColor).mask(alignment: .bottom) {
                        GeometryReader { p in Rectangle().frame(height: p.size.height * progress).frame(maxHeight: .infinity, alignment: .bottom) }
                    }
                }.font(.system(size: isClosedNotchTarget ? effectiveIconSize : max(24, effectiveIconSize)))
            case .glow:
                GeometryReader { p in
                    ZStack(alignment: .leading) {
                        Capsule().fill(inactiveColor)
                        Capsule().fill(progressColor).frame(width: max(2, p.size.width * progress)).shadow(color: progressColor, radius: 8)
                    }
                }.frame(height: 7)
            case .minimalLine:
                GeometryReader { p in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(inactiveColor)
                        Rectangle().fill(progressColor).frame(width: max(1, p.size.width * progress))
                    }
                }.frame(height: configuration.presentation.target == .screenEdge ? nil : 2)
            case .wave:
                HStack(spacing: 2) {
                    ForEach(0..<18, id: \.self) { i in
                        Capsule()
                            .fill(progressColor.opacity(Double(i + 1) / 18 <= progress ? 1 : 0.18))
                            .frame(width: 3, height: isClosedNotchTarget ? 3 + 9 * abs(sin(Double(i) * 0.82)) : 4 + 13 * abs(sin(Double(i) * 0.82)))
                    }
                }.frame(height: isClosedNotchTarget ? 14 : 20)
            }
        }
    }

    private func circularProgress(trimStart: Double, trimLength: Double) -> some View {
        ZStack {
            Circle().stroke(inactiveColor, lineWidth: isClosedNotchTarget ? 4 : 5)
            Circle()
                .trim(from: trimStart, to: min(1, trimStart + trimLength))
                .stroke(progressColor, style: StrokeStyle(lineWidth: isClosedNotchTarget ? 4 : 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.frame(width: isClosedNotchTarget ? 30 : 36, height: isClosedNotchTarget ? 30 : 36)
    }

    @ViewBuilder private var background: some View {
        if configuration.presentation.target == .screenEdge || isClosedNotchTarget {
            Color.clear
        } else if reduceTransparency || configuration.appearance.background == .solid {
            Color.black.opacity(max(0.45, configuration.appearance.backgroundOpacity))
        } else {
            switch configuration.appearance.background {
            case .clear:
                Color.clear
            case .gradient:
                LinearGradient(colors: [accent.opacity(0.48), secondaryColor.opacity(0.18), .black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blur(radius: configuration.appearance.blur * 0.08)
            case .glass:
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.28 + 0.72 * min(1, max(0, configuration.appearance.glassIntensity)))
                    .overlay(Color.black.opacity(max(0, configuration.appearance.backgroundOpacity - 0.45)))
                    .blur(radius: configuration.appearance.blur * 0.025)
            case .image, .video:
                LinearGradient(colors: [accent.opacity(0.32), secondaryColor.opacity(0.18), .black.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blur(radius: configuration.appearance.blur * 0.08)
            case .solid:
                Color.black.opacity(configuration.appearance.backgroundOpacity)
            }
        }
    }

    @ViewBuilder private var noiseOverlay: some View {
        if configuration.appearance.noise && configuration.presentation.target != .screenEdge && !isClosedNotchTarget {
            Canvas { context, size in
                for index in 0..<96 {
                    let x = pseudoRandom(index * 2 + 1) * size.width
                    let y = pseudoRandom(index * 2 + 2) * size.height
                    let alpha = 0.018 + pseudoRandom(index + 301) * 0.028
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(alpha)))
                }
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }

    private func pseudoRandom(_ seed: Int) -> Double {
        let raw = sin(Double(seed) * 12.9898 + 78.233) * 43758.5453
        return raw - floor(raw)
    }

    private func resolvedColor(_ color: HaloHUDColorConfiguration) -> Color {
        switch color.source {
        case .fixed:
            return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness, opacity: color.alpha)
        case .albumArtwork:
            if let first = palette.first { return first.color.opacity(color.alpha) }
            return .accentColor.opacity(color.alpha)
        case .systemAppearance:
            return .primary.opacity(color.alpha)
        case .automaticContrast:
            return contrast == .increased ? .primary : .white.opacity(color.alpha)
        case .wallpaper, .systemAccent:
            return .accentColor.opacity(color.alpha)
        }
    }

    private var hiddenScale: CGSize {
        guard !reduceMotion else { return CGSize(width: 1, height: 1) }
        if isClosedNotchTarget { return CGSize(width: isExiting ? 0.94 : 0.88, height: 1) }
        if isExiting {
            switch configuration.animation.exit {
            case .fade: return CGSize(width: 1, height: 1)
            case .collapse: return CGSize(width: 0.94, height: 0.25)
            case .slide: return CGSize(width: 1, height: 1)
            case .scale: return CGSize(width: 0.86, height: 0.86)
            case .morphBack: return CGSize(width: 0.92, height: 0.82)
            }
        }
        switch configuration.animation.entrance {
        case .fade, .slide: return CGSize(width: 1, height: 1)
        case .scale: return CGSize(width: 0.86, height: 0.86)
        case .spring: return CGSize(width: 0.92, height: 0.92)
        case .morph: return CGSize(width: 0.90, height: 0.78)
        case .notchExpand: return CGSize(width: 0.96, height: 0.32)
        case .liquid: return CGSize(width: 0.86, height: 0.72)
        }
    }

    private var hiddenOffset: CGSize {
        guard !visible, !reduceMotion else { return .zero }
        if isClosedNotchTarget { return .zero }
        let amount = 18 * max(0.15, configuration.animation.intensity)
        if isExiting {
            switch configuration.animation.exit {
            case .slide: return CGSize(width: 0, height: amount)
            default: return .zero
            }
        }
        switch configuration.animation.entrance {
        case .slide, .notchExpand: return CGSize(width: 0, height: -amount)
        default: return .zero
        }
    }

    private var hiddenOpacity: Double {
        guard !visible else { return 1 }
        if reduceMotion { return 0 }
        return isExiting && configuration.animation.exit == .collapse ? 0.12 : 0
    }

    private var visibilityAnimation: Animation? {
        guard !reduceMotion else { return nil }
        if isClosedNotchTarget {
            return isExiting
                ? .easeInOut(duration: max(0.01, configuration.animation.exitDuration))
                : .easeOut(duration: max(0.01, configuration.animation.entranceDuration))
        }
        if isExiting { return .easeInOut(duration: max(0.01, configuration.animation.exitDuration)) }
        if configuration.animation.entrance == .spring {
            let stiffness = max(20, configuration.animation.springStiffness)
            let damping = max(1, 2 * sqrt(stiffness) * configuration.animation.springDamping)
            return .interpolatingSpring(stiffness: stiffness, damping: damping)
        }
        return .easeOut(duration: max(0.01, configuration.animation.entranceDuration))
    }

    private var progressAnimation: Animation? {
        guard !reduceMotion else { return nil }
        switch configuration.animation.progress {
        case .instant: return nil
        case .spring: return .spring(response: 0.22, dampingFraction: 0.82)
        case .smooth: return .easeOut(duration: 0.16)
        }
    }
}
