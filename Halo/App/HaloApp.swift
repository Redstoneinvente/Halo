import SwiftUI
import AppKit

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
    private var status: NSStatusItem?
    private var menuReservation: NSStatusItem?
    private var settings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: Notification.Name("HaloOpenSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: Notification.Name("HaloToggle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelResized(_:)), name: NSWindow.didResizeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelMoved(_:)), name: NSWindow.didMoveNotification, object: nil)
        store.workspace.start()
        engine = WindowManager(store: store)
        engine?.start()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "capsule.tophalf.filled", accessibilityDescription: "Halo")
        let menu = NSMenu()
        for (title, action, key) in [("Toggle Halo", #selector(toggle), ""), ("Settings…", #selector(openSettings), ","), ("Quit Halo", #selector(quit), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        status?.menu = menu
        if !UserDefaults.standard.bool(forKey: "onboarded") { openSettings() }
    }

    /// macOS does not expose a supported API for moving another app's menu-bar items. Instead Halo
    /// reserves space with its own invisible status item while a notch panel grows beyond the physical
    /// camera cutout. This nudges compatible right-side menu extras away and releases the space again
    /// when Halo returns to the physical-notch width.
    @objc private func haloPanelResized(_ note: Notification) {
        guard let panel = note.object as? HaloPanel else { return }
        updateMenuBarReservation(for: panel)
    }

    @objc private func haloPanelMoved(_ note: Notification) {
        guard let panel = note.object as? HaloPanel else { return }
        updateMenuBarReservation(for: panel)
    }

    private func updateMenuBarReservation(for panel: HaloPanel) {
        guard let screen = panel.screen,
              screen.safeAreaInsets.top > 0,
              panel.isVisible else {
            releaseMenuBarReservation()
            return
        }

        let physicalWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            physicalWidth = max(0, right.minX - left.maxX)
        } else {
            physicalWidth = 190
        }

        // A status item can only influence the right-hand menu extras. Reserve the amount Halo extends
        // beyond the right edge of the physical notch, plus a small breathing margin.
        let extensionPerSide = max(0, (panel.frame.width - physicalWidth) / 2)
        let reserve = min(240, extensionPerSide + (extensionPerSide > 2 ? 10 : 0))
        guard reserve > 2 else {
            releaseMenuBarReservation()
            return
        }

        if menuReservation == nil {
            let item = NSStatusBar.system.statusItem(withLength: reserve)
            item.button?.title = ""
            item.button?.image = nil
            item.button?.isEnabled = false
            item.button?.toolTip = "Halo menu-bar protection"
            menuReservation = item
        }
        menuReservation?.isVisible = true
        menuReservation?.length = reserve
    }

    private func releaseMenuBarReservation() {
        guard let menuReservation else { return }
        NSStatusBar.system.removeStatusItem(menuReservation)
        self.menuReservation = nil
    }

    @objc private func toggle() { engine?.toggleAll() }
    @objc private func quit() { NSApp.terminate(nil) }
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
    func applicationWillTerminate(_ notification: Notification) {
        releaseMenuBarReservation()
        engine?.stop(); store.flushConfiguration(); store.workspace.stop()
    }
}