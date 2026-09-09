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
    private var settings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: Notification.Name("HaloOpenSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: Notification.Name("HaloToggle"), object: nil)
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
    func applicationWillTerminate(_ notification: Notification) { engine?.stop(); store.workspace.stop() }
}
