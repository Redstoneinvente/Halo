import SwiftUI
import AppKit
import ImageIO
import QuartzCore

struct GrainOverlay: View {
    let options: GrainOptions
    private static let texture: CGImage? = {
        var state: UInt32 = 0x48414c4f
        let bytes: [UInt8] = (0..<(128 * 128)).map { _ in
            state = state &* 1664525 &+ 1013904223
            return UInt8(truncatingIfNeeded: state >> 24)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: 128, height: 128, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: 128,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()
    var body: some View {
        if options.enabled {
            ZStack {
                Color(red: 1, green: 0.72, blue: 0.4).opacity(options.warmth * 0.12)
                if let texture = Self.texture {
                    Image(nsImage: NSImage(cgImage: texture, size: CGSize(width: 128 * options.size, height: 128 * options.size)))
                        .resizable(resizingMode: .tile).interpolation(.none)
                        .opacity(options.amount).blendMode(.softLight)
                }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

struct SideDecorationView: View {
    let options: SideDecoration
    let playing: Bool
    let lowPower: Bool
    var maximumHeight: CGFloat = .infinity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if options.isVisible(playing: playing) {
            Group {
                if options.kind == .symbol {
                    Image(systemName: options.symbol).resizable().scaledToFit().foregroundStyle(options.color.color)
                } else {
                    AnimatedSideAsset(path: options.assetPath, animate: !reduceMotion && !lowPower)
                }
            }.frame(width: min(options.size, maximumHeight), height: min(options.size, maximumHeight))
                .accessibilityLabel(options.kind == .symbol ? options.symbol : "Custom notch image")
        }
    }
}

/// Decode once per selected file; Core Animation plays cached frames without SwiftUI ticks.
struct AnimatedSideAsset: NSViewRepresentable {
    let path: String
    let animate: Bool
    final class AssetView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
    final class Coordinator {
        var path = ""
        var animate = false
        var frames: [CGImage] = []
        var durations: [Double] = []
        var task: Task<Void, Never>?
        func display(in view: NSView) {
            guard let layer = view.layer else { return }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            layer.removeAnimation(forKey: "gif"); layer.contents = frames.first
            CATransaction.commit()
            guard animate, frames.count > 1 else { return }
            let total = durations.reduce(0, +)
            var elapsed = 0.0
            let times = durations.map { duration -> NSNumber in
                defer { elapsed += duration }; return NSNumber(value: elapsed / total)
            }
            let animation = CAKeyframeAnimation(keyPath: "contents")
            animation.values = frames; animation.keyTimes = times
            animation.calculationMode = .discrete; animation.duration = total; animation.repeatCount = .infinity
            layer.add(animation, forKey: "gif")
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AssetView {
        let view = AssetView(); view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspect
        return view
    }
    func updateNSView(_ view: AssetView, context: Context) {
        let state = context.coordinator
        let changedAnimation = state.animate != animate
        state.animate = animate
        guard state.path != path else { if changedAnimation { state.display(in: view) }; return }
        state.path = path; state.task?.cancel(); state.frames = []; state.durations = []; state.display(in: view)
        let currentPath = path
        state.task = Task { @MainActor [weak state, weak view] in
            let decoded = await Task.detached(priority: .utility) { SideAssetDecoder.read(currentPath) }.value
            guard !Task.isCancelled, let state, let view, state.path == currentPath else { return }
            state.frames = decoded.frames; state.durations = decoded.durations; state.display(in: view)
        }
    }
    static func dismantleNSView(_ view: AssetView, coordinator: Coordinator) {
        coordinator.task?.cancel(); view.layer?.removeAllAnimations(); view.layer?.contents = nil
    }
}
private enum SideAssetDecoder {
    struct Frames { var frames: [CGImage] = []; var durations: [Double] = [] }
    static func read(_ path: String) -> Frames {
        let url = URL(fileURLWithPath: path)
        guard !path.isEmpty, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 10_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return Frames() }
        let count = CGImageSourceGetCount(source)
        guard count > 0, count <= 120 else { return Frames() }
        var result = Frames()
        for index in 0..<count {
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) else { return Frames() }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            result.frames.append(frame); result.durations.append(delay.isFinite ? min(10, max(1.0 / 30, delay)) : 0.1)
        }
        return result
    }
}
