import AppKit
import Quartz

@MainActor
final class ShelfPreview: NSObject {
    private var window: NSWindow?
    private var preview: QLPreviewView?
    func show(_ url: URL) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let preview = QLPreviewView(frame: window.contentView!.bounds, style: .normal)!
            preview.autoresizingMask = [.width, .height]
            window.contentView = preview
            window.center(); self.window = window; self.preview = preview
        }
        preview?.previewItem = url as NSURL
        window?.title = url.lastPathComponent
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}
