from pathlib import Path

path = Path("Halo/Core/PersonalizationModels.swift")
text = path.read_text()

anchor = '''private enum BluetoothDeviceArtwork {
    static func imageData(address: String) -> Data? {
'''
replacement = '''private enum BluetoothDeviceArtwork {
    /// Prefer the artwork macOS itself associates with the paired Bluetooth device.
    /// IOBluetoothUI has historically supplied model-specific images (AirPods, Beats,
    /// Apple keyboards/mice, etc.) through an Objective-C `image` selector. Because
    /// that selector is not public API, resolve it dynamically and fall back cleanly.
    static func imageData(device: IOBluetoothDevice, address: String) -> Data? {
        if let image = bluetoothSystemImage(for: device), let data = pngData(image) {
            return data
        }
        return imageData(address: address)
    }

    private static func bluetoothSystemImage(for device: IOBluetoothDevice) -> NSImage? {
        // The image helpers live in IOBluetoothUI on macOS. Halo does not need to
        // link against the framework just to use a best-effort runtime lookup.
        if let bundle = Bundle(path: "/System/Library/Frameworks/IOBluetoothUI.framework") {
            _ = bundle.load()
        }

        let selector = NSSelectorFromString("image")
        guard device.responds(to: selector),
              let value = device.perform(selector)?.takeUnretainedValue(),
              let image = value as? NSImage,
              image.size.width > 0,
              image.size.height > 0 else { return nil }
        return image
    }

    static func imageData(address: String) -> Data? {
'''

if replacement not in text:
    if anchor not in text:
        raise SystemExit("BluetoothDeviceArtwork anchor not found")
    text = text.replace(anchor, replacement, 1)

call_old = 'visual.imageData = BluetoothDeviceArtwork.imageData(address: rawAddress)'
call_new = 'visual.imageData = BluetoothDeviceArtwork.imageData(device: device, address: rawAddress)'
if call_new not in text:
    if call_old not in text:
        raise SystemExit("Bluetooth artwork call site not found")
    text = text.replace(call_old, call_new, 1)

helper_anchor = '''    private static func normalizedAddress(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
    }
'''
helper_replacement = '''    private static func pngData(_ image: NSImage) -> Data? {
        guard image.size.width > 0, image.size.height > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 128, height: 128).fill()
        let scale = min(128 / image.size.width, 128 / image.size.height)
        let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (128 - target.width) / 2, y: (128 - target.height) / 2,
                             width: target.width, height: target.height),
                   from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func normalizedAddress(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: "")
    }
'''

if 'private static func pngData(_ image: NSImage)' not in text:
    if helper_anchor not in text:
        raise SystemExit("normalizedAddress anchor not found")
    text = text.replace(helper_anchor, helper_replacement, 1)

path.write_text(text)
print("Patched Bluetooth artwork lookup")
