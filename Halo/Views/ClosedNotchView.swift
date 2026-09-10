import SwiftUI

struct ClosedNotchView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    let layout: WorkspaceLayout
    let occlusion: CGRect?
    private var options: ClosedNotchOptions { layout.closedNotch ?? ClosedNotchOptions() }
    var body: some View {
        GeometryReader { proxy in
            let leftWidth = occlusion?.minX ?? proxy.size.width / 2
            let rightWidth = occlusion.map { proxy.size.width - $0.maxX } ?? proxy.size.width / 2
            HStack(spacing: 0) {
                slot(options.left, decoration: options.leftDecoration, width: leftWidth, height: proxy.size.height)
                if let occlusion { Color.clear.frame(width: occlusion.width) }
                slot(options.right, decoration: options.rightDecoration, width: rightWidth, height: proxy.size.height)
            }.frame(height: proxy.size.height)
        }.foregroundStyle(options.color.color)
    }
    private func slot(_ item: ClosedNotchItem, decoration: SideDecoration?, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if width >= 24 {
                ClosedNotchSlot(item: item, decoration: decoration, availableHeight: height, options: options, clock: layout.widgetStyle(for: .clock), store: store,
                                workspace: workspace, media: workspace.media, system: workspace.system)
                    .padding(.horizontal, 6)
            }
        }.frame(width: max(0, width)).clipped()
    }
}
struct ClosedNotchSlot: View {
    let item: ClosedNotchItem
    let decoration: SideDecoration?
    let availableHeight: CGFloat
    let options: ClosedNotchOptions
    let clock: WidgetStyle
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var media: MediaService
    @ObservedObject var system: SystemService
    var body: some View {
        HStack(spacing: 5) {
            if let decoration { SideDecorationView(options: decoration, playing: media.isPlaying, lowPower: system.lowPower, maximumHeight: max(8, availableHeight - 2)) }
            content
        }.font(.system(size: options.fontSize)).lineLimit(1)
    }
    @ViewBuilder private var content: some View {
        switch item {
        case .none: EmptyView()
        case .clock:
            WidgetClock(style: compactClock, compact: true)
        case .date:
            TimelineView(.periodic(from: .now, by: 60)) { context in Text(context.date, format: .dateTime.month().day()) }
        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
            else { Label(store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready", systemImage: "timer") }
        case .battery:
            if let battery = system.battery { Label("\(battery)%", systemImage: system.charging ? "battery.100.bolt" : "battery.100") }
            else { Image(systemName: "powerplug") }
        case .media:
            Label(media.title, systemImage: media.isPlaying ? "music.note" : "pause.fill")
        case .visualizer:
            PlaybackVisualizer(kind: options.animation, playing: media.isPlaying, enabled: options.animate && !system.lowPower,
                               options: options.visualizer ?? VisualizerOptions(), palette: media.artworkColors, fallback: options.color.color)
        case .files: Label("\(store.files.count)", systemImage: "tray")
        case .activity: Text(workspace.activities.first?.title ?? "No activity")
        }
    }
    private var compactClock: WidgetStyle { var value = clock; value.fontSize = options.fontSize; return value }
}
/// Playback decoration, deliberately not microphone or system-audio capture.
struct PlaybackVisualizer: View {
    let kind: PlaybackAnimation
    let playing: Bool
    let enabled: Bool
    var options = VisualizerOptions()
    var palette: [WidgetColor] = []
    var fallback: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animated: Bool { playing && enabled && !reduceMotion }
    private var colors: [Color] {
        let extracted = options.dynamicColors ? palette.map(\.color) : []
        return extracted.isEmpty ? [fallback, fallback] : extracted.count == 1 ? [extracted[0], extracted[0]] : extracted
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { context in
            let time = animated ? context.date.timeIntervalSinceReferenceDate * options.speed : 0
            Canvas { graphics, size in
                let w = Double(size.width), h = Double(size.height)
                let paint = GraphicsContext.Shading.linearGradient(Gradient(colors: colors),
                    startPoint: .zero, endPoint: CGPoint(x: w, y: h))
                let strength = playing ? options.intensity : 0.12
                switch kind {
                case .waveform, .ribbon:
                    for layer in 0..<(kind == .ribbon ? 3 : 1) {
                        var line = Path()
                        for index in 0...64 {
                            let x = Double(index) / 64
                            let envelope = sin(x * .pi)
                            let y = h / 2 + sin(x * .pi * 4 - time * 5 + Double(layer) * 0.8) * h * 0.4 * strength * envelope
                            if index == 0 { line.move(to: CGPoint(x: x * w, y: y)) }
                            else { line.addLine(to: CGPoint(x: x * w, y: y)) }
                        }
                        var stroke = graphics; stroke.opacity = layer == 0 ? 1 : 0.45
                        stroke.stroke(line, with: paint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                case .rings:
                    for index in 0..<3 {
                        let phase = animated ? (time * 0.65 + Double(index) / 3).truncatingRemainder(dividingBy: 1) : Double(index + 1) / 4
                        let diameter = max(2, h * (0.2 + phase * 0.75 * strength))
                        let rect = CGRect(x: (w - diameter) / 2, y: (h - diameter) / 2, width: diameter, height: diameter)
                        var ring = graphics; ring.opacity = 1 - phase * 0.8
                        ring.stroke(Path(ellipseIn: rect), with: paint, lineWidth: 1.5)
                    }
                case .orbit:
                    for index in 0..<6 {
                        let phase = time * 3 + Double(index) * .pi / 3
                        let dot = 2.0 + Double(index) * 0.35
                        let x = w / 2 + cos(phase) * max(0, w / 2 - 4) * strength
                        let y = h / 2 + sin(phase) * max(0, h / 2 - 3) * strength
                        graphics.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)), with: paint)
                    }
                case .bars, .wave, .pulse, .dots, .spectrum:
                    let count = kind == .pulse ? 3 : kind == .dots ? 7 : 11
                    let step = w / Double(count)
                    for index in 0..<count {
                        let phase = time * (kind == .wave ? 5 : 8) + Double(index) * (kind == .bars ? 2.3 : 0.8)
                        let signal = animated ? (sin(phase) + 1) / 2 : playing ? 0.5 : 0
                        let height = max(2, h * (0.12 + 0.88 * signal * strength))
                        let width = min(kind == .pulse ? 12.0 : 4.0, step * 0.7)
                        let x = Double(index) * step + (step - width) / 2
                        if kind == .spectrum {
                            let levels = max(1, Int(height / 3))
                            for level in 0..<levels {
                                let rect = CGRect(x: x, y: h - Double(level + 1) * 3, width: width, height: 2)
                                graphics.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: paint)
                            }
                        } else if kind == .dots || kind == .pulse {
                            let diameter = kind == .pulse ? max(2, width * (0.3 + signal * strength * 0.7)) : width
                            let y = kind == .dots ? (h - diameter) / 2 + sin(phase) * max(0, h / 2 - diameter) * strength : (h - diameter) / 2
                            graphics.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)), with: paint)
                        } else {
                            let rect = CGRect(x: x, y: (h - height) / 2, width: width, height: height)
                            graphics.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: paint)
                        }
                    }
                }
            }.frame(maxWidth: options.width).frame(height: options.height)
        }.accessibilityLabel(playing ? "Music playing" : "Music paused")
    }
}
