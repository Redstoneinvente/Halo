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
        NotificationCenter.default.addObserver(self, selector: #selector(haloPanelGeometryChanged(_:)), name: Notification.Name("HaloPanelGeometryChanged"), object: nil)
        store.workspace.start()
        engine = WindowManager(store: store)
        engine?.start()

        // Keep this reservation item alive for the entire app session. Creating/removing it on demand
        // lets macOS reinsert it at a different menu-bar position, which can fail to push the existing
        // menu extras. A persistent zero-width item retains its ordering and simply expands when needed.
        menuReservation = NSStatusBar.system.statusItem(withLength: 0)
        menuReservation?.button?.title = ""
        menuReservation?.button?.image = nil
        menuReservation?.button?.isEnabled = false
        menuReservation?.button?.toolTip = "Halo menu-bar protection"
        menuReservation?.isVisible = true

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

    @objc private func haloPanelResized(_ note: Notification) {
        guard let panel = note.object as? HaloPanel else { return }
        updateMenuBarReservation(for: panel)
    }

    @objc private func haloPanelMoved(_ note: Notification) {
        guard let panel = note.object as? HaloPanel else { return }
        updateMenuBarReservation(for: panel)
    }

    /// WindowManager posts this while animating because NSWindow resize/move notifications may be
    /// coalesced. Using the explicit frame keeps the menu reservation synchronized with Halo at 120 Hz.
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
        if let right = screen.auxiliaryTopRightArea {
            physicalRightEdge = right.minX
        } else {
            physicalRightEdge = screen.frame.midX + 95
        }
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
