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
    @Published var sequence = 0
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

    init(workspace: WorkspaceStore) { self.workspace = workspace }

    func start() {
        createPanel(); configureInput(); installProviders()
        previewObserver = NotificationCenter.default.addObserver(forName: .init("HaloHUDPreview"), object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in self?.preview(note) }
        }
        previewExitObserver = NotificationCenter.default.addObserver(forName: .init("HaloHUDPreviewExit"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hide(immediate: false) }
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
        tearDownInput(); hideWork?.cancel(); menuHideWork?.cancel(); subscriptions.removeAll()
        if let previewObserver { NotificationCenter.default.removeObserver(previewObserver) }
        if let previewExitObserver { NotificationCenter.default.removeObserver(previewExitObserver) }
        if let replacementObserver { NotificationCenter.default.removeObserver(replacementObserver) }
        if let tapReenableObserver { NotificationCenter.default.removeObserver(tapReenableObserver) }
        panel?.orderOut(nil); panel = nil
        if let menuItem { NSStatusBar.system.removeStatusItem(menuItem); self.menuItem = nil }
    }

    func configurationDidChange() {
        configureInput()
        if model.visible {
            let settings = resolvedSettings
            guard settings.isEnabled(model.event.kind) else { hide(immediate: true); return }
            model.configuration = resolvedConfiguration(for: model.event, settings: settings)
            model.palette = workspace.media.artworkColors
            if let panel { position(panel, configuration: model.configuration) }
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
        // Native suppression remains explicitly opt-in and is enabled only after a writable backend probe.
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
            self.emit(HaloHUDEvent(kind: .audioOutputChanged, icon: "speaker.wave.2.fill", primaryText: "Audio Output", secondaryText: name))
        }.store(in: &subscriptions)
        workspace.audio.$devices.map { $0.map(\.id) }.removeDuplicates().receive(on: RunLoop.main).dropFirst().sink { [weak self] ids in
            guard let self else { return }
            self.emit(HaloHUDEvent(kind: .audioDeviceConnected, icon: "hifispeaker.fill", primaryText: "Audio Devices", secondaryText: "\(ids.count) available"))
        }.store(in: &subscriptions)
    }

    private func preview(_ note: Notification) {
        let raw = note.userInfo?["kind"] as? String ?? "volume"
        let value = (note.userInfo?["value"] as? Double) ?? 0.68
        let kind: HaloHUDEventKind
        switch raw { case "brightness": kind = .displayBrightness; case "keyboard": kind = .keyboardBrightness; default: kind = HaloHUDEventKind(rawValue: raw) ?? .volume }
        emit(HaloHUDEvent(kind: kind, value: value), force: true)
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
            showPanel(event, configuration: configuration)
        case .floating, .nearCursor, .screenEdge: showPanel(event, configuration: configuration)
        }
    }
    private func routeFallback(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration, depth: Int) {
        var fallback = configuration; fallback.presentation.target = configuration.behavior.fallbackTarget
        if fallback.presentation.target == .notch || fallback.presentation.target == .disabled { fallback.presentation.target = .floating }
        route(event, configuration: fallback, depth: depth + 1)
    }

    private func showPanel(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration) {
        guard let panel else { return }
        if model.visible, model.event.kind != event.kind, configuration.behavior.collision == .queue {
            if queue.count < 12 { queue.append((event, configuration)) }; return
        }
        let repeated = model.visible && model.event.kind == event.kind
        model.event = event; model.configuration = configuration; model.palette = workspace.media.artworkColors; model.sequence += 1
        position(panel, configuration: configuration); hideWork?.cancel(); panel.orderFrontRegardless()
        if !repeated { model.visible = false; DispatchQueue.main.async { [weak self] in self?.model.visible = true } }
        else { model.visible = true }
        scheduleHide(configuration.behavior.displayDuration)
    }
    private func scheduleHide(_ delay: Double) {
        let work = DispatchWorkItem { [weak self] in self?.hide(immediate: false) }
        hideWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + min(10, max(0.2, delay)), execute: work)
    }
    private func hide(immediate: Bool) {
        hideWork?.cancel(); guard let panel else { return }
        if immediate { model.visible = false; panel.orderOut(nil); presentNext(); return }
        model.visible = false
        let delay = min(2, max(0, model.configuration.animation.exitDuration))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak panel] in
            guard let self, let panel, !self.model.visible else { return }; panel.orderOut(nil); self.presentNext()
        }
    }
    private func presentNext() { guard !queue.isEmpty else { return }; let next = queue.removeFirst(); showPanel(next.0, configuration: next.1) }

    private func showMenuBar(_ event: HaloHUDEvent, configuration: HaloHUDConfiguration) {
        if menuItem == nil { menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength) }
        guard let button = menuItem?.button else { return }
        button.image = NSImage(systemSymbolName: event.icon, accessibilityDescription: event.primaryText)
        button.title = event.progress.map { " \(Int(($0 * 100).rounded()))%" } ?? " " + event.primaryText
        menuHideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in guard let self, let item = self.menuItem else { return }; NSStatusBar.system.removeStatusItem(item); self.menuItem = nil }
        menuHideWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + configuration.behavior.displayDuration, execute: work)
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

    private func position(_ panel: NSPanel, configuration: HaloHUDConfiguration) {
        guard let screen = screen(for: configuration) else { return }
        let visible = screen.visibleFrame, full = screen.frame, margin = CGFloat(max(0, configuration.layout.edgeMargin))
        var width = CGFloat(min(configuration.layout.maximumWidth, max(configuration.layout.minimumWidth, configuration.layout.width)))
        var height = CGFloat(max(24, configuration.layout.height))
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
            let physicalWidth: CGFloat = {
                if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { return max(0, right.minX - left.maxX) }
                return screen.safeAreaInsets.top > 0 ? 190 : 0
            }()
            let side = resolvedNotchSide(configuration.presentation.notchSide); y = full.maxY - height
            switch side { case .left: x = full.midX - physicalWidth / 2 - width; case .right: x = full.midX + physicalWidth / 2; case .full, .automatic: x = full.midX - width / 2 }
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
        x += CGFloat(configuration.layout.offsetX); y -= CGFloat(configuration.layout.offsetY)
        x = min(visible.maxX - width - 2, max(visible.minX + 2, x)); y = min(full.maxY - height, max(visible.minY + 2, y))
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

private struct HaloHUDRuntimeView: View {
    @ObservedObject var model: HaloHUDRuntimeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private var configuration: HaloHUDConfiguration { model.configuration }
    private var progress: Double { min(1, max(0, model.event.progress ?? 0)) }
    private var accent: Color { resolvedColor(configuration.appearance.primary) }
    private var progressColor: Color { resolvedColor(configuration.appearance.progress) }

    var body: some View {
        Group {
            if configuration.presentation.target == .screenEdge { edgeContent }
            else if configuration.layout.style == .vertical { vertical }
            else if configuration.layout.style == .compact || configuration.layout.compact { compact }
            else { horizontal }
        }
        .padding(.horizontal, configuration.presentation.target == .screenEdge ? 0 : configuration.layout.horizontalPadding)
        .padding(.vertical, configuration.presentation.target == .screenEdge ? 0 : configuration.layout.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: configuration.presentation.target == .screenEdge ? min(configuration.layout.cornerRadius, 8) : configuration.layout.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: configuration.presentation.target == .screenEdge ? min(configuration.layout.cornerRadius, 8) : configuration.layout.cornerRadius, style: .continuous).stroke(resolvedColor(configuration.appearance.borderColor).opacity(configuration.appearance.border ? configuration.appearance.borderOpacity : 0), lineWidth: contrast == .increased ? 1.5 : 1))
        .shadow(color: configuration.appearance.shadow ? .black.opacity(0.32) : .clear, radius: 16, y: 7)
        .scaleEffect(model.visible ? 1 : entranceScale).offset(y: model.visible ? 0 : entranceOffset).opacity(model.visible ? 1 : 0)
        .animation(viewAnimation, value: model.visible).animation(progressAnimation, value: progress)
        .accessibilityElement(children: .combine).accessibilityLabel(model.event.primaryText)
        .accessibilityValue(model.event.progress.map { "\(Int($0 * 100)) percent" } ?? (model.event.secondaryText ?? ""))
    }
    private var horizontal: some View { HStack(spacing: configuration.layout.spacing) { icon; VStack(alignment: .leading, spacing: max(3, configuration.layout.spacing * 0.45)) { header; progressView } } }
    private var vertical: some View { VStack(spacing: configuration.layout.spacing) { icon; header; progressView } }
    private var compact: some View { HStack(spacing: max(5, configuration.layout.spacing * 0.7)) { icon; if configuration.components.label { Text(model.event.primaryText).lineLimit(1) }; valueText; if configuration.components.progress { progressView.frame(maxWidth: 150) } } }
    private var edgeContent: some View { progressView.frame(maxWidth: .infinity, maxHeight: .infinity) }
    @ViewBuilder private var icon: some View {
        if configuration.components.icon { Image(systemName: model.event.icon).font(.system(size: configuration.iconSize, weight: .semibold)).foregroundStyle(accent).frame(minWidth: configuration.iconSize * 1.2) }
    }
    private var header: some View {
        HStack(spacing: 8) {
            if configuration.components.label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.event.primaryText).font(.system(size: configuration.textSize, weight: .semibold, design: .rounded)).lineLimit(1)
                    if let secondary = model.event.secondaryText, !secondary.isEmpty { Text(secondary).font(.system(size: max(9, configuration.textSize * 0.72))).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
            Spacer(minLength: 4); valueText
        }
    }
    @ViewBuilder private var valueText: some View {
        if configuration.components.value || configuration.components.percentage, let value = model.event.value {
            let display = model.event.maximumValue == 100 ? Int(value.rounded()) : Int((progress * 100).rounded())
            Text(configuration.components.percentage ? "\(display)%" : "\(display)").font(.system(size: configuration.textSize, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }
    @ViewBuilder private var progressView: some View {
        if configuration.components.progress, model.event.progress != nil {
            switch configuration.progressStyle {
            case .segmentedBar:
                HStack(spacing: 2) { ForEach(0..<max(2, configuration.segments), id: \.self) { i in Capsule().fill(Double(i + 1) / Double(max(2, configuration.segments)) <= progress ? progressColor : Color.white.opacity(0.13)) } }.frame(height: 7)
            case .dots:
                HStack(spacing: 4) { ForEach(0..<max(2, min(32, configuration.segments)), id: \.self) { i in Circle().fill(Double(i + 1) / Double(max(2, configuration.segments)) <= progress ? progressColor : Color.white.opacity(0.13)).frame(width: 5, height: 5) } }
            case .ring, .arc, .gauge:
                ZStack { Circle().stroke(Color.white.opacity(0.13), lineWidth: 5); Circle().trim(from: configuration.progressStyle == .arc ? 0.12 : 0, to: configuration.progressStyle == .arc ? 0.12 + progress * 0.76 : progress).stroke(progressColor, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }.frame(width: 36, height: 36)
            case .numberOnly:
                Text("\(Int((progress * 100).rounded()))").font(.system(size: configuration.textSize * 1.2, weight: .bold, design: .rounded)).foregroundStyle(progressColor)
            case .iconFill:
                ZStack { Image(systemName: model.event.icon).foregroundStyle(Color.white.opacity(0.14)); Image(systemName: model.event.icon).foregroundStyle(progressColor).mask(alignment: .bottom) { GeometryReader { p in Rectangle().frame(height: p.size.height * progress).frame(maxHeight: .infinity, alignment: .bottom) } } }.font(.system(size: max(24, configuration.iconSize)))
            case .glow:
                GeometryReader { p in ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.1)); Capsule().fill(progressColor).frame(width: max(2, p.size.width * progress)).shadow(color: progressColor, radius: 8) } }.frame(height: 7)
            case .minimalLine:
                GeometryReader { p in ZStack(alignment: .leading) { Rectangle().fill(Color.white.opacity(0.12)); Rectangle().fill(progressColor).frame(width: max(1, p.size.width * progress)) } }.frame(height: configuration.presentation.target == .screenEdge ? nil : 2)
            case .wave:
                HStack(spacing: 2) { ForEach(0..<18, id: \.self) { i in Capsule().fill(progressColor.opacity(Double(i + 1) / 18 <= progress ? 1 : 0.18)).frame(width: 3, height: 4 + 13 * abs(sin(Double(i) * 0.82))) } }.frame(height: 20)
            default:
                GeometryReader { p in ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.13)); Capsule().fill(progressColor).frame(width: max(2, p.size.width * progress)) } }.frame(height: configuration.presentation.target == .screenEdge ? nil : 7)
            }
        }
    }
    @ViewBuilder private var background: some View {
        if configuration.presentation.target == .screenEdge { Color.clear }
        else if reduceTransparency || configuration.appearance.background == .solid { Color.black.opacity(max(0.45, configuration.appearance.backgroundOpacity)) }
        else {
            switch configuration.appearance.background {
            case .clear: Color.clear
            case .gradient: LinearGradient(colors: [accent.opacity(0.48), .black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .glass: Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(max(0, configuration.appearance.backgroundOpacity - 0.45)))
            case .image, .video: Rectangle().fill(.ultraThinMaterial).overlay(accent.opacity(0.12))
            case .solid: Color.black.opacity(configuration.appearance.backgroundOpacity)
            }
        }
    }
    private func resolvedColor(_ color: HaloHUDColorConfiguration) -> Color {
        switch color.source {
        case .fixed: return Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness, opacity: color.alpha)
        case .albumArtwork: if let first = model.palette.first { return first.color.opacity(color.alpha) }; return .accentColor.opacity(color.alpha)
        case .systemAppearance: return .primary.opacity(color.alpha)
        case .automaticContrast: return contrast == .increased ? .primary : .white.opacity(color.alpha)
        case .wallpaper, .systemAccent: return .accentColor.opacity(color.alpha)
        }
    }
    private var entranceScale: CGFloat {
        guard !reduceMotion else { return 1 }
        switch configuration.animation.entrance { case .scale, .spring, .morph, .liquid: return 0.92 + 0.06 * (1 - configuration.animation.intensity); default: return 1 }
    }
    private var entranceOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch configuration.animation.entrance { case .slide, .notchExpand: return -12 * configuration.animation.intensity; default: return 0 }
    }
    private var viewAnimation: Animation? {
        guard !reduceMotion else { return nil }
        let duration = configuration.animation.entranceDuration
        if configuration.animation.entrance == .spring { return .spring(response: max(0.12, duration), dampingFraction: configuration.animation.springDamping) }
        return .easeOut(duration: duration)
    }
    private var progressAnimation: Animation? {
        guard !reduceMotion else { return nil }
        switch configuration.animation.progress { case .instant: return nil; case .spring: return .spring(response: 0.22, dampingFraction: 0.82); case .smooth: return .easeOut(duration: 0.16) }
    }
}
