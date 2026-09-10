import SwiftUI
import AppKit
import ImageIO

enum ClosedNotchSide { case left, right }

private enum PowerEventKind { case charging, low, charged }
private struct PowerEventInfo {
    let kind: PowerEventKind
    let style: PowerReactionStyle
    let battery: Int
    var symbol: String {
        switch kind {
        case .charging: return "bolt.fill"
        case .low: return "battery.25"
        case .charged: return "battery.100.bolt"
        }
    }
    var label: String {
        switch kind {
        case .charging: return "Charging"
        case .low: return "Low battery"
        case .charged: return "Charged"
        }
    }
}

struct ClosedNotchView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    let layout: WorkspaceLayout
    let occlusion: CGRect?
    let referenceWidth: CGFloat
    private var options: ClosedNotchOptions { layout.closedNotch ?? ClosedNotchOptions() }
    private var activeActivity: LiveActivity? {
        workspace.activities.first { activity in
            (activity.progress.map { $0 < 1 } ?? false) || activity.created.addingTimeInterval(8) > Date()
        }
    }
    private var resolvedItems: (left: ClosedNotchItem, right: ClosedNotchItem) {
        var left = options.left
        var right = options.right
        guard activeActivity != nil, left != .activity, right != .activity else { return (left, right) }
        let rightAvailable = right == .none || ((right == .media || right == .visualizer) && !workspace.media.isPlaying)
        let leftAvailable = left == .none || ((left == .media || left == .visualizer) && !workspace.media.isPlaying)
        if rightAvailable { right = .activity }
        else if leftAvailable { left = .activity }
        return (left, right)
    }
    var body: some View {
        GeometryReader { proxy in
            let reservation = cameraReservation(width: proxy.size.width, height: proxy.size.height)
            let leftWidth = reservation?.minX ?? proxy.size.width / 2
            let rightWidth = reservation.map { proxy.size.width - $0.maxX } ?? proxy.size.width / 2
            let items = resolvedItems
            HStack(spacing: 0) {
                slot(items.left, decoration: options.leftDecoration, side: .left, width: leftWidth, height: proxy.size.height)
                if let reservation { Color.clear.frame(width: reservation.width) }
                slot(items.right, decoration: options.rightDecoration, side: .right, width: rightWidth, height: proxy.size.height)
            }.frame(height: proxy.size.height)
        }.foregroundStyle(options.color.color)
    }
    private func cameraReservation(width: CGFloat, height: CGFloat) -> CGRect? {
        guard var camera = occlusion else { return nil }
        camera.origin.x += (width - referenceWidth) / 2
        let intersection = camera.intersection(CGRect(x: 0, y: 0, width: width, height: max(1, height)))
        return intersection.isNull || intersection.isEmpty ? nil : intersection
    }
    private func slot(_ item: ClosedNotchItem, decoration: SideDecoration?, side: ClosedNotchSide, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if width >= 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin + 8 {
                ClosedNotchSlot(item: item, decoration: decoration, side: side, availableHeight: height, availableWidth: width,
                                options: options, clock: layout.widgetStyle(for: .clock), store: store, workspace: workspace,
                                media: workspace.media, system: workspace.system)
            }
        }.frame(width: max(0, width)).clipped()
    }
}

struct ClosedNotchSlot: View {
    let item: ClosedNotchItem
    let decoration: SideDecoration?
    let side: ClosedNotchSide
    let availableHeight: CGFloat
    let availableWidth: CGFloat
    let options: ClosedNotchOptions
    let clock: WidgetStyle
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var media: MediaService
    @ObservedObject var system: SystemService
    private var activeActivity: LiveActivity? {
        workspace.activities.first { activity in
            (activity.progress.map { $0 < 1 } ?? false) || activity.created.addingTimeInterval(8) > Date()
        }
    }
    private var innerHeight: Double { max(1, availableHeight - 2 * options.contentPaddingY) }
    private var innerWidth: Double {
        max(1, availableWidth - 2 * options.contentPaddingX - options.contentSideMargin - options.contentOuterMargin)
    }
    private var isMusicItem: Bool { item == .media || item == .visualizer }
    private var itemIsVisible: Bool {
        if isMusicItem { return media.isPlaying }
        if item == .activity { return activeActivity != nil }
        return item != .none
    }
    private var powerEvent: PowerEventInfo? {
        let settings = options.powerReaction ?? PowerReactionOptions()
        guard let battery = system.battery else { return nil }
        let kind: PowerEventKind
        let style: PowerReactionStyle
        if battery >= 99 && !system.onBattery {
            kind = .charged; style = settings.charged
        } else if system.charging {
            kind = .charging; style = settings.charging
        } else if system.onBattery && battery <= settings.lowThreshold {
            kind = .low; style = settings.low
        } else { return nil }
        guard style != .off else { return nil }
        return PowerEventInfo(kind: kind, style: style, battery: battery)
    }
    private var powerTargetSide: ClosedNotchSide? {
        guard powerEvent != nil else { return nil }
        let settings = options.powerReaction ?? PowerReactionOptions()
        switch settings.side {
        case .left: return .left
        case .right: return .right
        case .automatic:
            let rightFree = options.right == .none || ((options.right == .media || options.right == .visualizer) && !media.isPlaying)
            let leftFree = options.left == .none || ((options.left == .media || options.left == .visualizer) && !media.isPlaying)
            if rightFree { return .right }
            if leftFree { return .left }
            return .right
        }
    }
    private var showPowerEvent: Bool { powerTargetSide == side }
    private var decorationSize: Double {
        guard let decoration, decoration.isVisible(playing: media.isPlaying) else { return 0 }
        return min(decoration.size, min(innerHeight, itemIsVisible ? innerWidth / 3 : innerWidth))
    }
    private var textSize: Double { min(options.fontSize, innerHeight / 1.25) }
    private var effectiveTextColor: Color {
        if options.albumTextColor == true, media.isPlaying, let album = media.artworkColors.first { return album.color }
        return options.color.color
    }
    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        v.width = min(v.width, max(1, innerWidth - decorationSize - (decorationSize > 0 ? 5 : 0)))
        v.height = min(v.height, innerHeight)
        return v
    }
    var body: some View {
        HStack(spacing: 6) {
            if let decoration, decorationSize > 0 {
                SideDecorationView(options: decoration, playing: media.isPlaying, lowPower: system.lowPower, maximumHeight: decorationSize)
            }
            if itemIsVisible { content }
            if showPowerEvent, let powerEvent { PowerEventBadge(event: powerEvent, options: options.powerReaction ?? PowerReactionOptions()) }
        }
        .font(.system(size: textSize))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .foregroundStyle(effectiveTextColor)
        .frame(maxWidth: .infinity, maxHeight: innerHeight, alignment: .center)
        .padding(.horizontal, options.contentPaddingX)
        .padding(.vertical, options.contentPaddingY)
        .padding(side == .left ? .trailing : .leading, options.contentSideMargin)
        .padding(side == .left ? .leading : .trailing, options.contentOuterMargin)
        .frame(width: availableWidth, height: availableHeight, alignment: .center)
        .clipped()
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
            if media.isPlaying {
                ClosedMediaView(media: media, options: options.mediaOptions ?? ClosedMediaOptions(), fontSize: textSize,
                                availableWidth: max(24, innerWidth), lowPower: system.lowPower)
            }
        case .visualizer:
            if media.isPlaying {
                PlaybackVisualizer(kind: options.animation, playing: true, enabled: options.animate && !system.lowPower,
                                   options: visualizerOptions, palette: media.artworkColors, fallback: effectiveTextColor)
            }
        case .files:
            Label("\(store.files.count)", systemImage: "tray")
        case .activity:
            if let activity = activeActivity {
                HStack(spacing: 5) {
                    Image(systemName: "waveform.path")
                    Text(activity.title)
                    if let progress = activity.progress { ProgressView(value: progress).frame(width: 36) }
                }
            }
        }
    }
    private var compactClock: WidgetStyle { var value = clock; value.fontSize = textSize; value.textColor = WidgetColor(effectiveTextColor); return value }
}

private struct PowerEventBadge: View {
    let event: PowerEventInfo
    let options: PowerReactionOptions
    var body: some View {
        Group {
            switch event.style {
            case .off: EmptyView()
            case .icon: Image(systemName: event.symbol)
            case .percent: Text("\(event.battery)%").monospacedDigit()
            case .iconPercent: Label("\(event.battery)%", systemImage: event.symbol).monospacedDigit()
            case .label: Label(event.label, systemImage: event.symbol)
            }
        }.foregroundStyle(options.color.color)
    }
}

private struct ClosedMediaView: View {
    @ObservedObject var media: MediaService
    let options: ClosedMediaOptions
    let fontSize: Double
    let availableWidth: Double
    let lowPower: Bool
    @State private var artwork: NSImage?
    @State private var lyrics = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var key: String { (media.connectedApp ?? "") + "|" + media.title + "|" + media.artist }
    private var displayText: String {
        switch options.textMode {
        case .title: return media.title
        case .artist: return media.artist.isEmpty ? media.title : media.artist
        case .titleArtist: return options.lines == 1 ? [media.title, media.artist].filter { !$0.isEmpty }.joined(separator: " · ") : media.title
        case .lyrics:
            let cleaned = lyrics.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return cleaned.isEmpty ? [media.title, media.artist].filter { !$0.isEmpty }.joined(separator: " · ") : cleaned.prefix(options.lines).joined(separator: "  •  ")
        }
    }
    var body: some View {
        HStack(spacing: 7) {
            if options.artwork == .cover || options.artwork == .vinyl {
                artworkView
            }
            mediaText
        }
        .task(id: key) {
            artwork = nil; lyrics = ""
            async let art = MediaAssetReader.artwork(app: media.connectedApp, key: key)
            async let words = MediaAssetReader.lyrics(app: media.connectedApp, key: key)
            artwork = await art
            lyrics = await words
        }
    }
    @ViewBuilder private var artworkView: some View {
        if let artwork {
            if options.artwork == .vinyl && !reduceMotion && !lowPower {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !media.isPlaying)) { context in
                    let turns = context.date.timeIntervalSinceReferenceDate * options.vinylRPM / 60
                    Image(nsImage: artwork).resizable().scaledToFill()
                        .frame(width: options.artworkSize, height: options.artworkSize)
                        .clipShape(Circle())
                        .overlay(Circle().fill(.black).frame(width: options.artworkSize * 0.16, height: options.artworkSize * 0.16))
                        .rotationEffect(.degrees(turns * 360))
                }
            } else {
                Image(nsImage: artwork).resizable().scaledToFill()
                    .frame(width: options.artworkSize, height: options.artworkSize)
                    .clipShape(options.artwork == .vinyl ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 5)))
            }
        }
    }
    @ViewBuilder private var mediaText: some View {
        let width = max(20, availableWidth - ((options.artwork == .cover || options.artwork == .vinyl) ? options.artworkSize + 7 : 0))
        if options.textMode == .titleArtist && options.lines == 2 {
            VStack(alignment: .leading, spacing: 1) {
                styledText(media.title, width: width)
                styledText(media.artist, width: width).opacity(0.72).font(.system(size: max(8, fontSize * 0.82)))
            }.frame(maxWidth: width, alignment: .leading)
        } else {
            HStack(spacing: 4) {
                if options.showPlaybackIcon { Image(systemName: "music.note") }
                styledText(displayText, width: width)
            }.frame(maxWidth: width)
        }
    }
    @ViewBuilder private func styledText(_ text: String, width: Double) -> some View {
        switch options.overflow {
        case .truncate: Text(text).lineLimit(1).truncationMode(.tail)
        case .scale: Text(text).lineLimit(1).minimumScaleFactor(0.45)
        case .marquee: MarqueeText(text: text, speed: options.marqueeSpeed, fontSize: fontSize, width: width, active: media.isPlaying && !lowPower)
        }
    }
}

private struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { pathBuilder = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { pathBuilder(rect) }
}

private struct MarqueeText: View {
    let text: String
    let speed: Double
    let fontSize: Double
    let width: Double
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var estimatedTextWidth: Double { max(8, Double(text.count) * fontSize * 0.56) }
    var body: some View {
        if !active || reduceMotion || estimatedTextWidth <= width {
            Text(text).lineLimit(1)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                let gap = 28.0
                let cycle = estimatedTextWidth + gap
                let x = -(context.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: cycle)
                HStack(spacing: gap) {
                    Text(text).fixedSize()
                    Text(text).fixedSize()
                }.offset(x: x).frame(width: width, alignment: .leading).clipped()
            }.frame(width: width)
        }
    }
}

private enum MediaAssetReader {
    private static let queue = DispatchQueue(label: "Halo.ClosedMediaAssets", qos: .utility)
    private static let lock = NSLock()
    private static var artworkCache: [String: Data] = [:]
    private static var lyricsCache: [String: String] = [:]

    static func artwork(app: String?, key: String) async -> NSImage? {
        guard let app else { return nil }
        lock.lock(); let cached = artworkCache[key]; lock.unlock()
        if let cached { return NSImage(data: cached) }
        let payload: (Data?, String?) = await withCheckedContinuation { continuation in
            queue.async {
                let artworkExpression = app == "com.spotify.client" ? "artwork url of current track" : "raw data of artwork 1 of current track"
                let source = """
                if application id "\(app)" is not running then return {"", ""}
                with timeout of 5 seconds
                    tell application id "\(app)"
                        return {(name of current track as text), \(artworkExpression)}
                    end tell
                end timeout
                """
                var failure: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                if failure != nil { continuation.resume(returning: (nil, nil)); return }
                let data = app == "com.apple.Music" ? result?.atIndex(2)?.data : nil
                let url = app == "com.spotify.client" ? result?.atIndex(2)?.stringValue : nil
                continuation.resume(returning: (data, url))
            }
        }
        var data = payload.0
        if data == nil, let urlString = payload.1, let url = URL(string: urlString), url.scheme == "https" {
            if let (downloaded, response) = try? await URLSession.shared.data(from: url), downloaded.count <= 5_000_000,
               (response as? HTTPURLResponse)?.statusCode == 200 { data = downloaded }
        }
        guard let data, data.count <= 5_000_000 else { return nil }
        lock.lock(); artworkCache[key] = data; lock.unlock()
        return NSImage(data: data)
    }

    static func lyrics(app: String?, key: String) async -> String {
        guard app == "com.apple.Music" else { return "" }
        lock.lock(); let cached = lyricsCache[key]; lock.unlock()
        if let cached { return cached }
        let value: String = await withCheckedContinuation { continuation in
            queue.async {
                let source = """
                if application id "com.apple.Music" is not running then return ""
                with timeout of 4 seconds
                    tell application id "com.apple.Music"
                        try
                            return lyrics of current track as text
                        on error
                            return ""
                        end try
                    end tell
                end timeout
                """
                var failure: NSDictionary?
                let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                continuation.resume(returning: failure == nil ? (result?.stringValue ?? "") : "")
            }
        }
        let bounded = String(value.prefix(12_000))
        lock.lock(); lyricsCache[key] = bounded; lock.unlock()
        return bounded
    }
}

struct AlbumNotchBackground: View {
    let options: ClosedNotchOptions
    @ObservedObject var media: MediaService
    @ObservedObject var system: SystemService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var artwork: NSImage?
    private var colors: [Color] { media.artworkColors.map(\.color) }
    private var mediaOptions: ClosedMediaOptions { options.mediaOptions ?? ClosedMediaOptions() }
    private var reactive: ReactiveBackgroundOptions {
        if let saved = options.reactiveBackground { return saved }
        var legacy = ReactiveBackgroundOptions(); legacy.enabled = options.albumBackgroundFrequencyEffect ?? false
        return legacy
    }
    private var key: String { (media.connectedApp ?? "") + "|" + media.title + "|" + media.artist }
    private var wantsArtworkBackground: Bool { mediaOptions.artwork == .background }
    private var active: Bool {
        media.isPlaying && ((options.albumBackgroundColor == true && !colors.isEmpty) || (wantsArtworkBackground && artwork != nil))
    }
    var body: some View {
        Group {
            if active {
                if reactive.enabled && !reduceMotion && !system.lowPower {
                    RefreshTimeline(active: true) { timestamp in reactiveBackground(signal: signal(at: timestamp)) }
                } else { baseBackground }
            }
        }
        .task(id: key) {
            guard media.isPlaying && wantsArtworkBackground else { artwork = nil; return }
            artwork = await MediaAssetReader.artwork(app: media.connectedApp, key: key)
        }
    }
    private var gradientColors: [Color] {
        if colors.isEmpty { return [.black, .black] }
        return colors.count == 1 ? [colors[0], colors[0].opacity(0.72)] : Array(colors.prefix(2))
    }
    @ViewBuilder private var baseBackground: some View {
        if wantsArtworkBackground, let artwork {
            Image(nsImage: artwork).resizable().scaledToFill().opacity(mediaOptions.backgroundOpacity)
                .overlay(LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom))
        } else {
            LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
        }
    }
    private func signal(at timestamp: Double) -> Double {
        let t = timestamp * reactive.speed
        switch reactive.driver {
        case .pulse: return (sin(t * 5.2) + 1) / 2
        case .bass: return pow((sin(t * 3.1) + 1) / 2, 1.7)
        case .mids: return ((sin(t * 7.3) + sin(t * 4.7) * 0.5) + 1.5) / 3
        case .treble: return ((sin(t * 13.1) + sin(t * 17.7) * 0.4) + 1.4) / 2.8
        case .spectrum: return ((sin(t * 3.2) + sin(t * 8.6) + sin(t * 15.4)) + 3) / 6
        }
    }
    private func reactiveBackground(signal: Double) -> some View {
        let amount = min(1, max(0, signal)) * reactive.intensity
        return baseBackground
            .brightness((amount - 0.35) * reactive.brightness)
            .saturation(1 + amount * reactive.saturation)
            .scaleEffect(1 + amount * reactive.scale)
            .hueRotation(.degrees(amount * reactive.hueShift * 360))
            .blur(radius: amount * reactive.blur)
            .overlay(GrainOverlay(options: GrainOptions(enabled: reactive.grain > 0, amount: amount * reactive.grain, size: 1, warmth: 0)))
    }
}

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
        RefreshTimeline(active: animated) { timestamp in
            let time = animated ? timestamp * options.speed : 0
            Canvas { graphics, size in
                let w = Double(size.width), h = Double(size.height)
                let paint = GraphicsContext.Shading.linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: w, y: h))
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
