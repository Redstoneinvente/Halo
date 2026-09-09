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
                slot(options.left, width: leftWidth)
                if let occlusion { Color.clear.frame(width: occlusion.width) }
                slot(options.right, width: rightWidth)
            }.frame(height: proxy.size.height)
        }.foregroundStyle(options.color.color)
    }
    private func slot(_ item: ClosedNotchItem, width: CGFloat) -> some View {
        Group {
            if width >= 24 {
                ClosedNotchSlot(item: item, options: options, clock: layout.widgetStyle(for: .clock), store: store,
                                workspace: workspace, media: workspace.media, system: workspace.system)
                    .padding(.horizontal, 6)
            }
        }.frame(width: max(0, width)).clipped()
    }
}
struct ClosedNotchSlot: View {
    let item: ClosedNotchItem
    let options: ClosedNotchOptions
    let clock: WidgetStyle
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var media: MediaService
    @ObservedObject var system: SystemService
    var body: some View {
        content.font(.system(size: options.fontSize)).lineLimit(1)
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
            PlaybackVisualizer(kind: options.animation, playing: media.isPlaying, enabled: options.animate && !system.lowPower)
        case .files: Label("\(store.files.count)", systemImage: "tray")
        case .activity: Text(workspace.activities.last?.title ?? "No activity")
        }
    }
    private var compactClock: WidgetStyle { var value = clock; value.fontSize = options.fontSize; return value }
}
/// Playback decoration, deliberately not microphone or system-audio capture.
struct PlaybackVisualizer: View {
    let kind: PlaybackAnimation
    let playing: Bool
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animated: Bool { playing && enabled && !reduceMotion }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { context in
            let time = animated ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { graphics, size in
                let count = kind == .pulse ? 3 : 9
                let step = size.width / Double(count)
                for index in 0..<count {
                    let phase = time * (kind == .wave ? 5 : 8) + Double(index) * 0.8
                    let fraction = animated ? 0.25 + 0.75 * (sin(phase) + 1) / 2 : playing ? 0.55 : 0.18
                    let height = max(2, size.height * fraction)
                    let width = min(kind == .pulse ? 10.0 : 4.0, step * 0.65)
                    let rect = CGRect(x: Double(index) * step + (step - width) / 2, y: (size.height - height) / 2, width: width, height: kind == .pulse ? min(width, height) : height)
                    graphics.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .foreground)
                }
            }.frame(maxWidth: 64).frame(height: 16)
        }.accessibilityLabel(playing ? "Music playing" : "Music paused")
    }
}
