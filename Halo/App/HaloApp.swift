import SwiftUI
import AppKit
import ApplicationServices
import CoreGraphics
import IOKit

@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { SettingsView(store: delegate.store).frame(width: 800, height: 640) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = AppStore()
    private var engine: WindowManager?
    private var hudController: HaloHUDController?
    private var status: NSStatusItem?
    private var menuReservation: NSStatusItem?
    private var settings: NSWindow?
    private var hudSettings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: Notification.Name("HaloOpenSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: Notification.Name("HaloToggle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelResized(_:)), name: NSWindow.didResizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelMoved(_:)), name: NSWindow.didMoveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelGeometryChanged(_:)), name: Notification.Name("HaloPanelGeometryChanged"), object: nil)
        store.workspace.start()
        engine = WindowManager(store: store)
        engine?.start()
        hudController = HaloHUDController(audio: store.workspace.audio)
        hudController?.start()

        menuReservation = NSStatusBar.system.statusItem(withLength: 0)
        menuReservation?.button?.title = ""
        menuReservation?.button?.image = nil
        menuReservation?.button?.isEnabled = false
        menuReservation?.button?.toolTip = "Halo menu-bar protection"
        menuReservation?.isVisible = true

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "capsule.tophalf.filled", accessibilityDescription: "Halo")
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Halo", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let hudRoot = NSMenuItem(title: "HUD", action: nil, keyEquivalent: "")
        let hudMenu = NSMenu(title: "HUD")
        let hudSettingsItem = NSMenuItem(title: "HUD Settings…", action: #selector(openHUDSettings), keyEquivalent: "")
        hudSettingsItem.target = self
        hudMenu.addItem(hudSettingsItem)
        hudMenu.addItem(.separator())
        let previewVolume = NSMenuItem(title: "Preview Volume HUD", action: #selector(previewVolumeHUD), keyEquivalent: "")
        previewVolume.target = self
        hudMenu.addItem(previewVolume)
        let previewBrightness = NSMenuItem(title: "Preview Screen Brightness HUD", action: #selector(previewBrightnessHUD), keyEquivalent: "")
        previewBrightness.target = self
        hudMenu.addItem(previewBrightness)
        let previewKeyboard = NSMenuItem(title: "Preview Keyboard Brightness HUD", action: #selector(previewKeyboardHUD), keyEquivalent: "")
        previewKeyboard.target = self
        hudMenu.addItem(previewKeyboard)
        hudRoot.submenu = hudMenu
        menu.addItem(hudRoot)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Halo", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        status?.menu = menu

        if !UserDefaults.standard.bool(forKey: "onboarded") { openSettings() }
    }

    @objc private func haloPanelResized(_ note: Notification) {
        guard let panel = note.object as? HaloPanel else { return }
        updateMenuBarReservation(for: panel)
    }

    @objc private func haloPanelMoved(_ note: Notification) {
        guard let panel = note.object as? HaloPanel else { return }
        updateMenuBarReservation(for: panel)
    }

    @objc private func haloPanelGeometryChanged(_ note: Notification) {
        guard let panel = note.object as? HaloPanel,
              let frame = note.userInfo?["frame"] as? CGRect,
              let screen = panel.screen else { return }
        updateMenuBarReservation(frame: frame, screen: screen)
    }

    private func updateMenuBarReservation(for panel: HaloPanel) {
        guard let screen = panel.screen, panel.isVisible else {
            setMenuBarReservation(0)
            return
        }
        updateMenuBarReservation(frame: panel.frame, screen: screen)
    }

    private func updateMenuBarReservation(frame: CGRect, screen: NSScreen) {
        guard screen.safeAreaInsets.top > 0 else {
            setMenuBarReservation(0)
            return
        }
        let physicalRightEdge: CGFloat
        if let right = screen.auxiliaryTopRightArea { physicalRightEdge = right.minX }
        else { physicalRightEdge = screen.frame.midX + 95 }
        let rightExtension = max(0, frame.maxX - physicalRightEdge)
        let reserve = min(320, rightExtension + (rightExtension > 2 ? 12 : 0))
        setMenuBarReservation(reserve)
    }

    private func setMenuBarReservation(_ width: CGFloat) {
        guard let menuReservation else { return }
        let next = max(0, width)
        guard abs(menuReservation.length - next) > 0.5 else { return }
        menuReservation.length = next
    }

    private func releaseMenuBarReservation() {
        guard let menuReservation else { return }
        NSStatusBar.system.removeStatusItem(menuReservation)
        self.menuReservation = nil
    }

    @objc private func toggle() { engine?.toggleAll() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func previewVolumeHUD() { postHUDPreview("volume") }
    @objc private func previewBrightnessHUD() { postHUDPreview("brightness") }
    @objc private func previewKeyboardHUD() { postHUDPreview("keyboard") }
    private func postHUDPreview(_ kind: String) {
        NotificationCenter.default.post(name: .init("HaloHUDPreview"), object: nil, userInfo: ["kind": kind])
    }

    @objc func openSettings() {
        if settings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Halo · Settings"
            window.titlebarAppearsTransparent = false
            window.contentMinSize = NSSize(width: 700, height: 560)
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    @objc func openHUDSettings() {
        if hudSettings == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Halo · HUD"
            window.contentMinSize = NSSize(width: 520, height: 650)
            window.contentView = NSHostingView(rootView: HaloHUDSettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            hudSettings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        hudSettings?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseMenuBarReservation()
        hudController?.stop()
        engine?.stop(); store.flushConfiguration(); store.workspace.stop()
    }
}

enum HaloHUDKeys {
    static let enabled = "HaloHUDEnabled"
    static let replaceVolume = "HaloHUDReplaceVolume"
    static let replaceBrightness = "HaloHUDReplaceBrightness"
    static let replaceKeyboardBrightness = "HaloHUDReplaceKeyboardBrightness"
    static let volumeHUD = "HaloHUDVolumeEnabled"
    static let muteHUD = "HaloHUDMuteEnabled"
    static let brightnessHUD = "HaloHUDBrightnessEnabled"
    static let keyboardBrightnessHUD = "HaloHUDKeyboardBrightnessEnabled"
    static let layout = "HaloHUDLayout"
    static let position = "HaloHUDPosition"
    static let progress = "HaloHUDProgressStyle"
    static let background = "HaloHUDBackgroundStyle"
    static let width = "HaloHUDWidth"
    static let height = "HaloHUDHeight"
    static let padding = "HaloHUDPadding"
    static let corner = "HaloHUDCornerRadius"
    static let iconSize = "HaloHUDIconSize"
    static let valueSize = "HaloHUDValueSize"
    static let opacity = "HaloHUDBackgroundOpacity"
    static let accentHue = "HaloHUDAccentHue"
    static let saturation = "HaloHUDAccentSaturation"
    static let brightness = "HaloHUDAccentBrightness"
    static let dynamicAccent = "HaloHUDDynamicAccent"
    static let showIcon = "HaloHUDShowIcon"
    static let showLabel = "HaloHUDShowLabel"
    static let showValue = "HaloHUDShowValue"
    static let showProgress = "HaloHUDShowProgress"
    static let segments = "HaloHUDSegments"
    static let timeout = "HaloHUDTimeout"
    static let shadow = "HaloHUDShadow"
    static let offsetX = "HaloHUDOffsetX"
    static let offsetY = "HaloHUDOffsetY"
    static let volumeStep = "HaloHUDVolumeStep"
    static let brightnessStep = "HaloHUDBrightnessStep"
    static let keyboardStep = "HaloHUDKeyboardBrightnessStep"
}

private enum HaloHUDKind { case volume, mute, brightness, keyboardBrightness }

@MainActor
private final class HaloHUDState: ObservableObject {
    @Published var kind: HaloHUDKind = .volume
    @Published var value = 0.5
    @Published var label = "Volume"
    @Published var symbol = "speaker.wave.2.fill"
    @Published var sequence = 0
}

private final class HaloDisplayBrightnessService {
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
        return withService { service in
            IODisplaySetFloatParameter(service, 0, parameter, target) == kIOReturnSuccess
        } ?? false
    }

    func canSet() -> Bool {
        guard let value = current() else { return false }
        return set(value)
    }

    private func withService<T>(_ body: (io_service_t) -> T?) -> T? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            if let value = body(service) {
                IOObjectRelease(service)
                return value
            }
            IOObjectRelease(service)
        }
        return nil
    }
}

private final class HaloKeyboardBrightnessService {
    private let classes = ["AppleHIDKeyboardEventDriverV2", "AppleHIDKeyboardEventDriver", "AppleUserHIDEventDriver"]
    private let keys = ["KeyboardBacklightBrightness", "KeyboardBacklightLevel"]

    func current() -> Double? {
        for className in classes {
            if let value = withEntries(className: className, body: { entry in self.read(entry: entry) }) { return value }
        }
        return nil
    }

    @discardableResult func set(_ value: Double) -> Bool {
        let target = min(1, max(0, value))
        for className in classes {
            if withEntries(className: className, body: { entry in self.write(entry: entry, normalized: target) ? true : nil }) == true { return true }
        }
        return false
    }

    func canSet() -> Bool {
        guard let value = current() else { return false }
        return set(value)
    }

    private func read(entry: io_service_t) -> Double? {
        for keyName in keys {
            let key = keyName as CFString
            if let value = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key, kCFAllocatorDefault,
                                                            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)),
               let number = value as? NSNumber {
                let raw = number.doubleValue
                if raw <= 1.0001 { return min(1, max(0, raw)) }
                if raw <= 255 { return min(1, max(0, raw / 255.0)) }
                return min(1, max(0, raw / 4095.0))
            }
        }
        return nil
    }

    private func write(entry: io_service_t, normalized: Double) -> Bool {
        for keyName in keys {
            let key = keyName as CFString
            guard let value = IORegistryEntrySearchCFProperty(entry, kIOServicePlane, key, kCFAllocatorDefault,
                                                               IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)),
                  let existing = value as? NSNumber else { continue }
            let raw = existing.doubleValue
            let scale: Double = raw <= 1.0001 ? 1 : (raw <= 255 ? 255 : 4095)
            let valueToWrite: NSNumber = scale == 1 ? NSNumber(value: normalized) : NSNumber(value: Int((normalized * scale).rounded()))
            if IORegistryEntrySetCFProperty(entry, key, valueToWrite) == KERN_SUCCESS { return true }
        }
        return false
    }

    private func withEntries<T>(className: String, body: (io_service_t) -> T?) -> T? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            if let result = body(entry) {
                IOObjectRelease(entry)
                return result
            }
            IOObjectRelease(entry)
        }
        return nil
    }
}

@MainActor
private final class HaloHUDController {
    private let audio: AudioService
    private let displayBrightness = HaloDisplayBrightnessService()
    private let keyboardBrightness = HaloKeyboardBrightnessService()
    private let model = HaloHUDState()
    private var panel: NSPanel?
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var defaultsObserver: NSObjectProtocol?
    private var previewObserver: NSObjectProtocol?
    private var hideWork: DispatchWorkItem?
    private var lastNonZeroVolume: Float32 = 0.5
    private var lastDisplayBrightness = 0.5
    private var lastKeyboardBrightness = 0.5
    private var activeReplacementKeys = Set<Int>()

    init(audio: AudioService) { self.audio = audio }

    func start() {
        registerDefaults()
        createPanel()
        configureInput()
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureInput() }
        }
        previewObserver = NotificationCenter.default.addObserver(forName: .init("HaloHUDPreview"), object: nil, queue: .main) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                switch note.userInfo?["kind"] as? String {
                case "brightness": self.show(kind: .brightness, value: 0.68, label: "Screen Brightness", symbol: "sun.max.fill")
                case "keyboard": self.show(kind: .keyboardBrightness, value: 0.58, label: "Keyboard Brightness", symbol: "keyboard")
                default: self.show(kind: .volume, value: 0.68, label: "Volume", symbol: "speaker.wave.2.fill")
                }
            }
        }
    }

    func stop() {
        tearDownInput()
        hideWork?.cancel()
        if let defaultsObserver { NotificationCenter.default.removeObserver(defaultsObserver) }
        if let previewObserver { NotificationCenter.default.removeObserver(previewObserver) }
        panel?.close(); panel = nil
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            HaloHUDKeys.enabled: true,
            HaloHUDKeys.replaceVolume: false,
            HaloHUDKeys.replaceBrightness: false,
            HaloHUDKeys.replaceKeyboardBrightness: false,
            HaloHUDKeys.volumeHUD: true,
            HaloHUDKeys.muteHUD: true,
            HaloHUDKeys.brightnessHUD: true,
            HaloHUDKeys.keyboardBrightnessHUD: true,
            HaloHUDKeys.layout: "horizontal",
            HaloHUDKeys.position: "top",
            HaloHUDKeys.progress: "bar",
            HaloHUDKeys.background: "glass",
            HaloHUDKeys.width: 320.0,
            HaloHUDKeys.height: 92.0,
            HaloHUDKeys.padding: 16.0,
            HaloHUDKeys.corner: 24.0,
            HaloHUDKeys.iconSize: 24.0,
            HaloHUDKeys.valueSize: 14.0,
            HaloHUDKeys.opacity: 0.72,
            HaloHUDKeys.accentHue: 0.59,
            HaloHUDKeys.saturation: 0.72,
            HaloHUDKeys.brightness: 1.0,
            HaloHUDKeys.dynamicAccent: false,
            HaloHUDKeys.showIcon: true,
            HaloHUDKeys.showLabel: true,
            HaloHUDKeys.showValue: true,
            HaloHUDKeys.showProgress: true,
            HaloHUDKeys.segments: 16,
            HaloHUDKeys.timeout: 1.15,
            HaloHUDKeys.shadow: true,
            HaloHUDKeys.offsetX: 0.0,
            HaloHUDKeys.offsetY: 0.0,
            HaloHUDKeys.volumeStep: 0.0625,
            HaloHUDKeys.brightnessStep: 0.0625,
            HaloHUDKeys.keyboardStep: 0.0625
        ])
    }

    private func createPanel() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 92), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: HaloHUDOverlayView(model: model))
        panel.alphaValue = 0
        self.panel = panel
    }

    private func configureInput() {
        tearDownInput()
        activeReplacementKeys.removeAll()
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: HaloHUDKeys.enabled) else { return }

        audio.refresh()
        if defaults.bool(forKey: HaloHUDKeys.replaceVolume), audio.canSetVolume {
            activeReplacementKeys.formUnion([0, 1, 7])
        }
        if defaults.bool(forKey: HaloHUDKeys.replaceBrightness), displayBrightness.canSet() {
            activeReplacementKeys.formUnion([2, 3])
        }
        if defaults.bool(forKey: HaloHUDKeys.replaceKeyboardBrightness), keyboardBrightness.canSet() {
            activeReplacementKeys.formUnion([21, 22, 23])
        }

        if !activeReplacementKeys.isEmpty, AXIsProcessTrusted() { _ = installEventTap() }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in self?.handleObserved(event: event) }
        }
    }

    private func tearDownInput() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor); self.globalMonitor = nil }
        if let eventSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), eventSource, .commonModes); self.eventSource = nil }
        if let eventTap { CFMachPortInvalidate(eventTap); self.eventTap = nil }
    }

    private func installEventTap() -> Bool {
        let mask = CGEventMask(1) << 14
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<HaloHUDController>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type.rawValue == 14, let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
                return Unmanaged.passUnretained(event)
            }
            let data = nsEvent.data1
            let keyCode = (data & 0xFFFF0000) >> 16
            guard controller.activeReplacementKeys.contains(keyCode), UserDefaults.standard.bool(forKey: HaloHUDKeys.enabled) else {
                return Unmanaged.passUnretained(event)
            }
            let keyFlags = data & 0xFFFF
            let keyState = (keyFlags & 0xFF00) >> 8
            if keyState == 0xA {
                Task { @MainActor in controller.handleReplacementKey(keyCode) }
            }
            return nil
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventSource = source
        return true
    }

    private func handleObserved(event: NSEvent) {
        guard event.type == .systemDefined, event.subtype.rawValue == 8 else { return }
        let data = event.data1
        let keyCode = (data & 0xFFFF0000) >> 16
        let keyFlags = data & 0xFFFF
        let keyState = (keyFlags & 0xFF00) >> 8
        guard keyState == 0xA, !activeReplacementKeys.contains(keyCode) else { return }
        showObservedSystemKey(keyCode)
    }

    private func handleReplacementKey(_ keyCode: Int) {
        let defaults = UserDefaults.standard
        switch keyCode {
        case 0, 1, 7:
            audio.refresh()
            let current = min(1, max(0, audio.volume))
            let step = Float32(min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.volumeStep))))
            if keyCode == 0 {
                let next = min(1, current + step)
                if next > 0.01 { lastNonZeroVolume = next }
                audio.setVolume(next)
                if defaults.bool(forKey: HaloHUDKeys.volumeHUD) { showVolume(next) }
            } else if keyCode == 1 {
                let next = max(0, current - step)
                if next > 0.01 { lastNonZeroVolume = next }
                audio.setVolume(next)
                if defaults.bool(forKey: HaloHUDKeys.volumeHUD) { showVolume(next) }
            } else {
                let next: Float32
                if current > 0.005 { lastNonZeroVolume = current; next = 0 }
                else { next = max(0.05, lastNonZeroVolume) }
                audio.setVolume(next)
                if defaults.bool(forKey: HaloHUDKeys.muteHUD) {
                    show(kind: .mute, value: Double(next), label: next <= 0.005 ? "Muted" : "Volume", symbol: next <= 0.005 ? "speaker.slash.fill" : volumeSymbol(next))
                }
            }

        case 2, 3:
            let current = displayBrightness.current() ?? lastDisplayBrightness
            let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.brightnessStep)))
            let next = min(1, max(0, current + (keyCode == 2 ? step : -step)))
            if displayBrightness.set(next) { lastDisplayBrightness = next }
            if defaults.bool(forKey: HaloHUDKeys.brightnessHUD) {
                show(kind: .brightness, value: next, label: "Screen Brightness", symbol: screenBrightnessSymbol(next))
            }

        case 21, 22, 23:
            let current = keyboardBrightness.current() ?? lastKeyboardBrightness
            let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.keyboardStep)))
            let next: Double
            if keyCode == 23 { next = current > 0.01 ? 0 : max(0.25, lastKeyboardBrightness) }
            else { next = min(1, max(0, current + (keyCode == 21 ? step : -step))) }
            if next > 0.01 { lastKeyboardBrightness = next }
            _ = keyboardBrightness.set(next)
            if defaults.bool(forKey: HaloHUDKeys.keyboardBrightnessHUD) {
                show(kind: .keyboardBrightness, value: next, label: "Keyboard Brightness", symbol: keyboardBrightnessSymbol(next))
            }

        default: break
        }
    }

    private func showObservedSystemKey(_ keyCode: Int) {
        let defaults = UserDefaults.standard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else { return }
            switch keyCode {
            case 0, 1, 7:
                self.audio.refresh()
                let value = Double(min(1, max(0, self.audio.volume)))
                if keyCode == 7 {
                    if defaults.bool(forKey: HaloHUDKeys.muteHUD) {
                        self.show(kind: .mute, value: value, label: value <= 0.005 ? "Muted" : "Volume", symbol: value <= 0.005 ? "speaker.slash.fill" : self.volumeSymbol(Float32(value)))
                    }
                } else if defaults.bool(forKey: HaloHUDKeys.volumeHUD) { self.showVolume(Float32(value)) }

            case 2, 3:
                let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.brightnessStep)))
                let value = self.displayBrightness.current() ?? min(1, max(0, self.lastDisplayBrightness + (keyCode == 2 ? step : -step)))
                self.lastDisplayBrightness = value
                if defaults.bool(forKey: HaloHUDKeys.brightnessHUD) {
                    self.show(kind: .brightness, value: value, label: "Screen Brightness", symbol: self.screenBrightnessSymbol(value))
                }

            case 21, 22, 23:
                let step = min(0.25, max(0.01, defaults.double(forKey: HaloHUDKeys.keyboardStep)))
                let fallback: Double
                if keyCode == 23 { fallback = self.lastKeyboardBrightness > 0.01 ? 0 : 0.5 }
                else { fallback = min(1, max(0, self.lastKeyboardBrightness + (keyCode == 21 ? step : -step))) }
                let value = self.keyboardBrightness.current() ?? fallback
                self.lastKeyboardBrightness = value
                if defaults.bool(forKey: HaloHUDKeys.keyboardBrightnessHUD) {
                    self.show(kind: .keyboardBrightness, value: value, label: "Keyboard Brightness", symbol: self.keyboardBrightnessSymbol(value))
                }
            default: break
            }
        }
    }

    private func showVolume(_ value: Float32) {
        show(kind: .volume, value: Double(value), label: "Volume", symbol: volumeSymbol(value))
    }

    private func volumeSymbol(_ value: Float32) -> String {
        if value <= 0.005 { return "speaker.slash.fill" }
        if value < 0.34 { return "speaker.wave.1.fill" }
        if value < 0.68 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func screenBrightnessSymbol(_ value: Double) -> String {
        value <= 0.12 ? "sun.min.fill" : "sun.max.fill"
    }

    private func keyboardBrightnessSymbol(_ value: Double) -> String {
        value <= 0.01 ? "keyboard" : "keyboard.fill"
    }

    private func show(kind: HaloHUDKind, value: Double, label: String, symbol: String) {
        guard UserDefaults.standard.bool(forKey: HaloHUDKeys.enabled), let panel else { return }
        model.kind = kind
        model.value = min(1, max(0, value))
        model.label = label
        model.symbol = symbol
        model.sequence += 1
        position(panel)
        hideWork?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        let timeout = min(4, max(0.35, UserDefaults.standard.double(forKey: HaloHUDKeys.timeout)))
        let work = DispatchWorkItem { [weak panel] in
            guard let panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.20
                panel.animator().alphaValue = 0
            }, completionHandler: { panel.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    private func position(_ panel: NSPanel) {
        let defaults = UserDefaults.standard
        let width = CGFloat(min(520, max(160, defaults.double(forKey: HaloHUDKeys.width))))
        let height = CGFloat(min(260, max(54, defaults.double(forKey: HaloHUDKeys.height))))
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let frame = screen.visibleFrame
        let xOffset = CGFloat(min(300, max(-300, defaults.double(forKey: HaloHUDKeys.offsetX))))
        let yOffset = CGFloat(min(300, max(-300, defaults.double(forKey: HaloHUDKeys.offsetY))))
        let inset: CGFloat = 28
        let position = defaults.string(forKey: HaloHUDKeys.position) ?? "top"
        var x = frame.midX - width / 2
        var y = frame.maxY - height - inset
        switch position {
        case "topLeading": x = frame.minX + inset; y = frame.maxY - height - inset
        case "topTrailing": x = frame.maxX - width - inset; y = frame.maxY - height - inset
        case "center": x = frame.midX - width / 2; y = frame.midY - height / 2
        case "bottom": x = frame.midX - width / 2; y = frame.minY + inset
        case "bottomLeading": x = frame.minX + inset; y = frame.minY + inset
        case "bottomTrailing": x = frame.maxX - width - inset; y = frame.minY + inset
        default: break
        }
        panel.setFrame(NSRect(x: x + xOffset, y: y + yOffset, width: width, height: height), display: true)
    }
}

private struct HaloHUDOverlayView: View {
    @ObservedObject var model: HaloHUDState
    @AppStorage(HaloHUDKeys.layout) private var layout = "horizontal"
    @AppStorage(HaloHUDKeys.progress) private var progressStyle = "bar"
    @AppStorage(HaloHUDKeys.background) private var backgroundStyle = "glass"
    @AppStorage(HaloHUDKeys.padding) private var padding = 16.0
    @AppStorage(HaloHUDKeys.corner) private var corner = 24.0
    @AppStorage(HaloHUDKeys.iconSize) private var iconSize = 24.0
    @AppStorage(HaloHUDKeys.valueSize) private var valueSize = 14.0
    @AppStorage(HaloHUDKeys.opacity) private var backgroundOpacity = 0.72
    @AppStorage(HaloHUDKeys.accentHue) private var accentHue = 0.59
    @AppStorage(HaloHUDKeys.saturation) private var accentSaturation = 0.72
    @AppStorage(HaloHUDKeys.brightness) private var accentBrightness = 1.0
    @AppStorage(HaloHUDKeys.dynamicAccent) private var dynamicAccent = false
    @AppStorage(HaloHUDKeys.showIcon) private var showIcon = true
    @AppStorage(HaloHUDKeys.showLabel) private var showLabel = true
    @AppStorage(HaloHUDKeys.showValue) private var showValue = true
    @AppStorage(HaloHUDKeys.showProgress) private var showProgress = true
    @AppStorage(HaloHUDKeys.segments) private var segments = 16
    @AppStorage(HaloHUDKeys.shadow) private var shadow = true

    private var accent: Color {
        if dynamicAccent {
            let hue = 0.02 + model.value * 0.31
            return Color(hue: hue, saturation: 0.82, brightness: 1)
        }
        return Color(hue: accentHue, saturation: accentSaturation, brightness: accentBrightness)
    }

    var body: some View {
        Group {
            if layout == "vertical" { vertical }
            else if layout == "compact" { compact }
            else { horizontal }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { hudBackground }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: shadow ? .black.opacity(0.34) : .clear, radius: 18, y: 8)
        .foregroundStyle(.white)
        .id(model.sequence)
    }

    private var horizontal: some View {
        HStack(spacing: 14) {
            icon
            VStack(alignment: .leading, spacing: 7) {
                header
                progress
            }
        }
    }

    private var vertical: some View {
        VStack(spacing: 10) {
            icon
            header
            progress
        }
    }

    private var compact: some View {
        HStack(spacing: 10) {
            icon
            if showValue { Text("\(Int((model.value * 100).rounded()))%").font(.system(size: valueSize, weight: .bold, design: .rounded)).monospacedDigit() }
            if showProgress { progress.frame(maxWidth: 150) }
        }
    }

    @ViewBuilder private var icon: some View {
        if showIcon {
            Image(systemName: model.symbol)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: iconSize * 1.45, height: iconSize * 1.45)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if showLabel { Text(model.label).font(.system(size: max(11, valueSize * 0.86), weight: .semibold, design: .rounded)) }
            Spacer(minLength: 4)
            if showValue { Text("\(Int((model.value * 100).rounded()))%").font(.system(size: valueSize, weight: .bold, design: .rounded)).monospacedDigit() }
        }
    }

    @ViewBuilder private var progress: some View {
        if showProgress {
            switch progressStyle {
            case "segments":
                HStack(spacing: 2) {
                    ForEach(0..<max(4, min(32, segments)), id: \.self) { index in
                        Capsule().fill(Double(index + 1) / Double(max(4, segments)) <= model.value ? accent : Color.white.opacity(0.13))
                    }
                }.frame(height: 7)
            case "ring":
                ZStack {
                    Circle().stroke(Color.white.opacity(0.13), lineWidth: 5)
                    Circle().trim(from: 0, to: model.value).stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                }.frame(width: 34, height: 34)
            case "none":
                EmptyView()
            default:
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.13))
                        Capsule().fill(accent).frame(width: max(3, proxy.size.width * model.value))
                    }
                }.frame(height: 7)
            }
        }
    }

    @ViewBuilder private var hudBackground: some View {
        switch backgroundStyle {
        case "clear": Color.clear
        case "solid": Color.black.opacity(backgroundOpacity)
        default: Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(max(0, backgroundOpacity - 0.45)))
        }
    }
}

struct HaloHUDSettingsView: View {
    @AppStorage(HaloHUDKeys.enabled) private var enabled = true
    @AppStorage(HaloHUDKeys.replaceVolume) private var replaceVolume = false
    @AppStorage(HaloHUDKeys.replaceBrightness) private var replaceBrightness = false
    @AppStorage(HaloHUDKeys.replaceKeyboardBrightness) private var replaceKeyboardBrightness = false
    @AppStorage(HaloHUDKeys.volumeHUD) private var volumeHUD = true
    @AppStorage(HaloHUDKeys.muteHUD) private var muteHUD = true
    @AppStorage(HaloHUDKeys.brightnessHUD) private var brightnessHUD = true
    @AppStorage(HaloHUDKeys.keyboardBrightnessHUD) private var keyboardBrightnessHUD = true
    @AppStorage(HaloHUDKeys.layout) private var layout = "horizontal"
    @AppStorage(HaloHUDKeys.position) private var position = "top"
    @AppStorage(HaloHUDKeys.progress) private var progress = "bar"
    @AppStorage(HaloHUDKeys.background) private var background = "glass"
    @AppStorage(HaloHUDKeys.width) private var width = 320.0
    @AppStorage(HaloHUDKeys.height) private var height = 92.0
    @AppStorage(HaloHUDKeys.padding) private var padding = 16.0
    @AppStorage(HaloHUDKeys.corner) private var corner = 24.0
    @AppStorage(HaloHUDKeys.iconSize) private var iconSize = 24.0
    @AppStorage(HaloHUDKeys.valueSize) private var valueSize = 14.0
    @AppStorage(HaloHUDKeys.opacity) private var opacity = 0.72
    @AppStorage(HaloHUDKeys.accentHue) private var accentHue = 0.59
    @AppStorage(HaloHUDKeys.saturation) private var saturation = 0.72
    @AppStorage(HaloHUDKeys.brightness) private var brightness = 1.0
    @AppStorage(HaloHUDKeys.dynamicAccent) private var dynamicAccent = false
    @AppStorage(HaloHUDKeys.showIcon) private var showIcon = true
    @AppStorage(HaloHUDKeys.showLabel) private var showLabel = true
    @AppStorage(HaloHUDKeys.showValue) private var showValue = true
    @AppStorage(HaloHUDKeys.showProgress) private var showProgress = true
    @AppStorage(HaloHUDKeys.segments) private var segments = 16
    @AppStorage(HaloHUDKeys.timeout) private var timeout = 1.15
    @AppStorage(HaloHUDKeys.shadow) private var shadow = true
    @AppStorage(HaloHUDKeys.offsetX) private var offsetX = 0.0
    @AppStorage(HaloHUDKeys.offsetY) private var offsetY = 0.0
    @AppStorage(HaloHUDKeys.volumeStep) private var volumeStep = 0.0625
    @AppStorage(HaloHUDKeys.brightnessStep) private var brightnessStep = 0.0625
    @AppStorage(HaloHUDKeys.keyboardStep) private var keyboardStep = 0.0625

    private var wantsTrueReplacement: Bool { replaceVolume || replaceBrightness || replaceKeyboardBrightness }

    var body: some View {
        Form {
            Section("HUD replacement") {
                Toggle("Enable Halo HUD", isOn: $enabled)
                Toggle("Replace Apple's volume HUD", isOn: $replaceVolume)
                Toggle("Replace Apple's screen brightness HUD", isOn: $replaceBrightness)
                Toggle("Replace Apple's keyboard brightness HUD", isOn: $replaceKeyboardBrightness)
                if wantsTrueReplacement && !AXIsProcessTrusted() {
                    Text("True HUD replacement needs Accessibility permission so Halo can intercept the hardware keys. Without it, Halo observes the keys and leaves macOS behavior untouched.").font(.caption).foregroundStyle(.orange)
                    Button("Open Accessibility Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                    }
                }
                Text("Display replacement is enabled only when the active display exposes a writable IOKit brightness control. Keyboard replacement is enabled only when Halo can prove the Mac's keyboard-backlight registry entry is writable; unsupported Macs safely fall back to observation.").font(.caption).foregroundStyle(.secondary)
            }

            Section("HUD types") {
                Toggle("Volume changes", isOn: $volumeHUD)
                Toggle("Mute / unmute", isOn: $muteHUD)
                Toggle("Screen brightness", isOn: $brightnessHUD)
                Toggle("Keyboard brightness", isOn: $keyboardBrightnessHUD)
                HStack {
                    Button("Preview volume") { preview("volume") }
                    Button("Preview screen") { preview("brightness") }
                    Button("Preview keyboard") { preview("keyboard") }
                }
            }

            Section("Layout") {
                Picker("Layout", selection: $layout) {
                    Text("Horizontal").tag("horizontal")
                    Text("Vertical").tag("vertical")
                    Text("Compact").tag("compact")
                }.pickerStyle(.segmented)
                Picker("Position", selection: $position) {
                    Text("Top left").tag("topLeading"); Text("Top").tag("top"); Text("Top right").tag("topTrailing")
                    Text("Center").tag("center")
                    Text("Bottom left").tag("bottomLeading"); Text("Bottom").tag("bottom"); Text("Bottom right").tag("bottomTrailing")
                }
                Slider(value: $width, in: 160...520) { Text("Width") }
                Slider(value: $height, in: 54...260) { Text("Height") }
                Slider(value: $padding, in: 4...36) { Text("Padding") }
                Slider(value: $offsetX, in: -300...300) { Text("Horizontal offset") }
                Slider(value: $offsetY, in: -300...300) { Text("Vertical offset") }
            }

            Section("Content") {
                Toggle("Show icon", isOn: $showIcon)
                Toggle("Show label", isOn: $showLabel)
                Toggle("Show percentage", isOn: $showValue)
                Toggle("Show progress", isOn: $showProgress)
                if showProgress {
                    Picker("Progress style", selection: $progress) {
                        Text("Bar").tag("bar"); Text("Segments").tag("segments"); Text("Ring").tag("ring"); Text("None").tag("none")
                    }
                    if progress == "segments" { Stepper("Segments: \(segments)", value: $segments, in: 4...32) }
                }
                Slider(value: $iconSize, in: 12...56) { Text("Icon size") }
                Slider(value: $valueSize, in: 10...32) { Text("Text size") }
            }

            Section("Appearance") {
                Picker("Background", selection: $background) {
                    Text("Glass").tag("glass"); Text("Solid").tag("solid"); Text("Transparent").tag("clear")
                }.pickerStyle(.segmented)
                Slider(value: $opacity, in: 0...1) { Text("Background opacity") }
                Slider(value: $corner, in: 0...64) { Text("Corner radius") }
                Toggle("Shadow", isOn: $shadow)
                Toggle("Dynamic accent by level", isOn: $dynamicAccent)
                if !dynamicAccent {
                    Slider(value: $accentHue, in: 0...1) { Text("Accent hue") }
                    Slider(value: $saturation, in: 0...1) { Text("Accent saturation") }
                    Slider(value: $brightness, in: 0.25...1) { Text("Accent brightness") }
                }
            }

            Section("Behavior") {
                Slider(value: $timeout, in: 0.35...4) { Text("Dismiss delay") }
                Slider(value: $volumeStep, in: 0.01...0.25) { Text("Volume key step") }
                Slider(value: $brightnessStep, in: 0.01...0.25) { Text("Screen brightness key step") }
                Slider(value: $keyboardStep, in: 0.01...0.25) { Text("Keyboard brightness key step") }
                Text("Halo intercepts only controls it can actually write. If a replacement backend is unavailable, the hardware key is passed through to macOS and Halo can still show its customized observer HUD.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 650)
    }

    private func preview(_ kind: String) {
        NotificationCenter.default.post(name: .init("HaloHUDPreview"), object: nil, userInfo: ["kind": kind])
    }
}
