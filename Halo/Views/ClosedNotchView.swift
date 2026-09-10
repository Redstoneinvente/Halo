import SwiftUI
import AppKit
import ImageIO
import AVFoundation

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

private extension ClosedNotchOptions {
    var resolvedArtwork: ClosedArtworkOptions {
        if let artworkOptions { return artworkOptions }
        let legacy = mediaOptions ?? ClosedMediaOptions()
        guard legacy.artwork != .none else { return ClosedArtworkOptions() }
        var value = ClosedArtworkOptions()
        value.enabled = true
        value.mode = legacy.artwork
        value.size = legacy.artworkSize
        value.vinylRPM = legacy.vinylRPM
        value.backgroundOpacity = legacy.backgroundOpacity
        return value
    }
}

private struct MediaBlurTransitionModifier: ViewModifier {
    let blur: CGFloat
    let opacity: Double
    func body(content: Content) -> some View { content.blur(radius: blur).opacity(opacity) }
}

private extension MediaChangeAnimation {
    var transition: AnyTransition {
        switch self {
        case .none: return .identity
        case .fade: return .opacity
        case .slide: return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
        case .scale: return .scale(scale: 0.86).combined(with: .opacity)
        case .blur:
            return .modifier(active: MediaBlurTransitionModifier(blur: 8, opacity: 0), identity: MediaBlurTransitionModifier(blur: 0, opacity: 1))
        }
    }
}

private struct MediaGestureModifier: ViewModifier {
    @ObservedObject var media: MediaService
    let options: ClosedMediaOptions
    let enabled: Bool
    private var preferredApp: String { media.connectedApp ?? "com.apple.Music" }

    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content
                .contentShape(Rectangle())
                .gesture(TapGesture(count: 2).exclusively(before: TapGesture(count: 1)).onEnded { value in
                    switch value {
                    case .first: perform(options.resolvedDoubleTapAction)
                    case .second: perform(options.resolvedTapAction)
                    }
                })
                .simultaneousGesture(DragGesture(minimumDistance: 18).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height), abs(value.translation.width) >= 24 else { return }
                    perform(value.translation.width < 0 ? options.resolvedSwipeLeftAction : options.resolvedSwipeRightAction)
                })
        } else {
            content
        }
    }

    private func perform(_ action: MediaGestureAction) {
        switch action {
        case .none: break
        case .playPause: media.perform("playpause", app: preferredApp)
        case .next: media.perform("next track", app: preferredApp)
        case .previous: media.perform("previous track", app: preferredApp)
        case .openPlayer:
            guard let app = media.connectedApp,
                  let running = NSRunningApplication.runningApplications(withBundleIdentifier: app).first else { return }
            running.activate(options: [.activateAllWindows])
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
            (activity.progress.map { $0 < 1 } ?? false) || activity.created.addingTimeInterval(12) > Date()
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
        else { right = .activity }
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
    private let elementSpacing = 8.0
    private var activeActivity: LiveActivity? {
        workspace.activities.first { activity in
            (activity.progress.map { $0 < 1 } ?? false) || activity.created.addingTimeInterval(12) > Date()
        }
    }
    private var innerHeight: Double { max(1, availableHeight - 2 * options.contentPaddingY) }
    private var innerWidth: Double { max(1, availableWidth - 2 * options.contentPaddingX - options.contentSideMargin - options.contentOuterMargin) }
    private var isMusicItem: Bool { item == .media || item == .visualizer }
    private var itemIsVisible: Bool {
        if isMusicItem { return media.isPlaying }
        if item == .activity { return activeActivity != nil }
        return item != .none
    }
    private var artwork: ClosedArtworkOptions { options.resolvedArtwork }
    private var artworkTargetSide: ClosedNotchSide? {
        guard media.isPlaying, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }
        switch artwork.side {
        case .left: return .left
        case .right: return .right
        case .automatic:
            if options.left == .media || options.left == .visualizer { return .left }
            if options.right == .media || options.right == .visualizer { return .right }
            return .right
        }
    }
    private var showArtwork: Bool { artworkTargetSide == side }
    private var hideMusicContentForArtworkOnly: Bool { showArtwork && artwork.isArtworkOnly && isMusicItem }
    private var powerEvent: PowerEventInfo? {
        let settings = options.powerReaction ?? PowerReactionOptions()
        guard settings.isEnabled, let battery = system.battery else { return nil }
        let kind: PowerEventKind
        let style: PowerReactionStyle
        if battery >= 99 && !system.onBattery { kind = .charged; style = settings.charged }
        else if system.charging { kind = .charging; style = settings.charging }
        else if system.onBattery && battery <= settings.lowThreshold { kind = .low; style = settings.low }
        else { return nil }
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
        v.width = min(v.width, max(1, innerWidth - decorationSize - (decorationSize > 0 ? elementSpacing : 0)))
        v.height = min(v.height, innerHeight)
        return v
    }
    private var closedMediaOptions: ClosedMediaOptions { options.mediaOptions ?? ClosedMediaOptions() }
    private var renderedArtworkSize: Double {
        guard showArtwork else { return 0 }
        return max(1, min(artwork.size, innerHeight - 2 * artwork.padding))
    }
    private var artworkFootprint: Double {
        guard showArtwork else { return 0 }
        return renderedArtworkSize + 2 * artwork.padding + artwork.margin
    }
    private var powerFootprint: Double {
        guard showPowerEvent, let event = powerEvent else { return 0 }
        switch event.style {
        case .off: return 0
        case .icon: return textSize + 6
        case .percent: return textSize * 3.3
        case .iconPercent: return textSize * 4.4
        case .label: return textSize * 7.0
        }
    }
    private var mediaSiblingFootprint: Double {
        var widths: [Double] = []
        if decorationSize > 0 { widths.append(decorationSize) }
        if artworkFootprint > 0 { widths.append(artworkFootprint) }
        if powerFootprint > 0 { widths.append(powerFootprint) }
        return widths.reduce(0, +) + Double(widths.count) * elementSpacing
    }
    private var closedMediaWidth: Double {
        let remaining = max(24, innerWidth - mediaSiblingFootprint)
        if closedMediaOptions.overflow == .truncate || closedMediaOptions.overflow == .marquee {
            return min(remaining, closedMediaOptions.resolvedHorizontalSpace)
        }
        return remaining
    }
    private var mirrorContentWidth: Double {
        // Mirror is deliberately the flexible element. Reserve decoration, artwork, power, every inter-element
        // gap, the camera-side margin, outer margin, and slot padding first; only the remaining content area
        // belongs to the live camera preview. This prevents Mirror from pushing siblings outside the notch.
        max(1, min(112, innerWidth - mediaSiblingFootprint))
    }
    private var renderedArtworkOptions: ClosedArtworkOptions {
        var value = artwork
        value.size = renderedArtworkSize
        return value
    }
    var body: some View {
        HStack(spacing: elementSpacing) {
            if side == .left {
                decorationElement
                artworkElement
                contentElement
                powerElement
            } else {
                powerElement
                contentElement
                artworkElement
                decorationElement
            }
        }
        .font(.system(size: textSize))
        .minimumScaleFactor(0.65)
        .foregroundStyle(effectiveTextColor)
        .frame(maxWidth: .infinity, maxHeight: innerHeight, alignment: .center)
        .padding(.horizontal, options.contentPaddingX)
        .padding(.vertical, options.contentPaddingY)
        .padding(side == .left ? .trailing : .leading, options.contentSideMargin)
        .padding(side == .left ? .leading : .trailing, options.contentOuterMargin)
        .frame(width: availableWidth, height: availableHeight, alignment: .center)
        .clipped()
        .modifier(MediaGestureModifier(media: media, options: closedMediaOptions, enabled: isMusicItem))
    }
    @ViewBuilder private var decorationElement: some View {
        if let decoration, decorationSize > 0 {
            SideDecorationView(options: decoration, playing: media.isPlaying, lowPower: system.lowPower, maximumHeight: decorationSize)
        }
    }
    @ViewBuilder private var artworkElement: some View {
        if showArtwork {
            ClosedArtworkView(media: media, options: renderedArtworkOptions, mediaOptions: closedMediaOptions, lowPower: system.lowPower)
                .padding(artwork.padding)
                .padding(side == .left ? .trailing : .leading, artwork.margin)
                .frame(width: artworkFootprint, height: innerHeight)
                .clipped()
                .layoutPriority(2)
        }
    }
    @ViewBuilder private var contentElement: some View {
        if itemIsVisible && !hideMusicContentForArtworkOnly { content }
    }
    @ViewBuilder private var powerElement: some View {
        if showPowerEvent, let powerEvent { PowerEventBadge(event: powerEvent, options: options.powerReaction ?? PowerReactionOptions()) }
    }
    @ViewBuilder private var content: some View {
        switch item {
        case .none: EmptyView()
        case .clock: WidgetClock(style: compactClock, compact: true)
        case .date: TimelineView(.periodic(from: .now, by: 60)) { context in Text(context.date, format: .dateTime.month().day()).lineLimit(1) }
        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit().lineLimit(1) }
            else { Label(store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready", systemImage: "timer").lineLimit(1) }
        case .battery:
            if let battery = system.battery { Label("\(battery)%", systemImage: system.charging ? "battery.100.bolt" : "battery.100").lineLimit(1) }
            else { Image(systemName: "powerplug") }
        case .media:
            if media.isPlaying {
                ClosedMediaView(media: media, options: closedMediaOptions, fontSize: textSize, availableWidth: closedMediaWidth, lowPower: system.lowPower)
                    .frame(width: closedMediaWidth)
                    .layoutPriority(1)
            }
        case .visualizer:
            if media.isPlaying { PlaybackVisualizer(kind: options.animation, playing: true, enabled: options.animate && !system.lowPower, options: visualizerOptions, palette: media.artworkColors, fallback: effectiveTextColor) }
        case .mirror:
            MirrorWidgetView()
                .frame(width: mirrorContentWidth, height: innerHeight)
                .layoutPriority(0)
        case .files: Label("\(store.files.count)", systemImage: "tray").lineLimit(1)
        case .activity:
            if let activity = activeActivity {
                HStack(spacing: elementSpacing) {
                    Image(systemName: "waveform.path")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title).lineLimit(1)
                        if !activity.detail.isEmpty { Text(activity.detail).font(.system(size: max(8, textSize * 0.78))).opacity(0.72).lineLimit(1) }
                    }
                    if let progress = activity.progress { ProgressView(value: progress).frame(width: 36) }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }
    private var compactClock: WidgetStyle { var value = clock; value.fontSize = textSize; value.textColor = WidgetColor(effectiveTextColor); return value }
}

@MainActor
private final class MirrorCameraService: ObservableObject {
    enum State: Equatable { case idle, requesting, ready, denied, unavailable, failed }
    static let shared = MirrorCameraService()

    @Published private(set) var state: State = .idle
    let session = AVCaptureSession()
    private var configured = false
    private var clients = 0
    private var stopTask: Task<Void, Never>?

    func acquire() {
        clients += 1
        stopTask?.cancel()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            state = .requesting
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { MirrorCameraService.shared.configureAndStart() }
                    else { MirrorCameraService.shared.state = .denied }
                }
            }
        case .denied, .restricted: state = .denied
        @unknown default: state = .failed
        }
    }

    func release() {
        clients = max(0, clients - 1)
        guard clients == 0 else { return }
        stopTask?.cancel()
        stopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self, self.clients == 0 else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.state = self.configured ? .idle : self.state
        }
    }

    private func configureAndStart() {
        guard clients > 0 else { return }
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .medium
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                state = .unavailable
                return
            }
            session.addInput(input)
            session.commitConfiguration()
            configured = true
        }
        if !session.isRunning { session.startRunning() }
        state = session.isRunning ? .ready : .failed
    }
}

private final class MirrorPreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

private struct MirrorPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> MirrorPreviewNSView {
        let view = MirrorPreviewNSView(frame: .zero)
        view.previewLayer.session = session
        return view
    }
    func updateNSView(_ nsView: MirrorPreviewNSView, context: Context) {
        if nsView.previewLayer.session !== session { nsView.previewLayer.session = session }
    }
}

private struct MirrorWidgetView: View {
    @ObservedObject private var camera = MirrorCameraService.shared
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.055))
            switch camera.state {
            case .ready: MirrorPreviewRepresentable(session: camera.session)
            case .idle, .requesting: ProgressView().controlSize(.mini)
            case .denied: Image(systemName: "video.slash.fill").foregroundStyle(.secondary)
            case .unavailable: Image(systemName: "camera.metering.unknown").foregroundStyle(.secondary)
            case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear { camera.acquire() }
        .onDisappear { camera.release() }
        .accessibilityLabel("Mirror")
    }
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
        }.foregroundStyle(powerColor)
    }
    private var powerColor: Color {
        guard options.usesDynamicColor else { return options.color.color }
        let p = min(1, max(0, Double(event.battery) / 100))
        if p <= 0.5 { return interpolate(options.resolvedLowColor, options.resolvedMidColor, p / 0.5).color }
        return interpolate(options.resolvedMidColor, options.resolvedHighColor, (p - 0.5) / 0.5).color
    }
    private func interpolate(_ a: WidgetColor, _ b: WidgetColor, _ t: Double) -> WidgetColor {
        let u = min(1, max(0, t))
        return WidgetColor(red: a.red + (b.red - a.red) * u, green: a.green + (b.green - a.green) * u, blue: a.blue + (b.blue - a.blue) * u)
    }
}

private struct ClosedArtworkView: View {
    @ObservedObject var media: MediaService
    let options: ClosedArtworkOptions
    let mediaOptions: ClosedMediaOptions
    let lowPower: Bool
    @State private var artwork: NSImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var key: String { (media.connectedApp ?? "") + "|" + media.title + "|" + media.artist }
    private var paletteColor: Color { media.artworkColors.first?.color ?? Color.white.opacity(0.78) }
    var body: some View {
        ZStack {
            Group {
                if options.mode == .vinyl { vinylView }
                else if let artwork { artworkImage(artwork).clipShape(RoundedRectangle(cornerRadius: 5)) }
                else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(paletteColor.opacity(0.22))
                        .overlay(Image(systemName: "photo").font(.system(size: max(8, options.size * 0.34))).foregroundStyle(paletteColor))
                        .frame(width: options.size, height: options.size)
                }
            }
            .id(key)
            .transition(reduceMotion ? .opacity : mediaOptions.resolvedChangeAnimation.transition)
        }
        .frame(width: options.size, height: options.size)
        .animation(mediaOptions.resolvedChangeAnimation == .none ? nil : .easeInOut(duration: mediaOptions.resolvedChangeAnimationDuration), value: key)
        .task(id: key + "|\(options.mode.rawValue)") {
            artwork = nil
            guard media.isPlaying else { return }
            artwork = await MediaAssetReader.artwork(app: media.connectedApp, key: key)
        }
    }
    @ViewBuilder private var vinylView: some View {
        if !reduceMotion && !lowPower {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !media.isPlaying)) { context in
                let turns = context.date.timeIntervalSinceReferenceDate * options.vinylRPM / 60
                vinylDisc.rotationEffect(.degrees(turns * 360))
            }
        } else { vinylDisc }
    }
    private var vinylDisc: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.96))
            Circle().stroke(Color.white.opacity(0.12), lineWidth: max(0.5, options.size * 0.025)).padding(options.size * 0.08)
            Circle().stroke(Color.white.opacity(0.08), lineWidth: max(0.5, options.size * 0.02)).padding(options.size * 0.17)
            if let artwork {
                Image(nsImage: artwork).resizable().scaledToFill().frame(width: options.size * 0.62, height: options.size * 0.62).clipShape(Circle())
            } else {
                Circle().fill(paletteColor.opacity(0.88)).frame(width: options.size * 0.62, height: options.size * 0.62)
                    .overlay(Image(systemName: "music.note").font(.system(size: max(7, options.size * 0.22))).foregroundStyle(.black.opacity(0.7)))
            }
            Circle().fill(Color.black).frame(width: max(3, options.size * 0.12), height: max(3, options.size * 0.12))
            Circle().fill(Color.white.opacity(0.48)).frame(width: max(1, options.size * 0.035), height: max(1, options.size * 0.035))
        }
        .frame(width: options.size, height: options.size)
        .accessibilityLabel(artwork == nil ? "Vinyl artwork loading" : "Rotating album artwork")
    }
    private func artworkImage(_ image: NSImage) -> some View { Image(nsImage: image).resizable().scaledToFill().frame(width: options.size, height: options.size).clipped() }
}

private struct TimedLyricLine: Identifiable {
    let id: Int
    let time: Double
    let text: String
}

private struct LyricFrame {
    let current: TimedLyricLine
    let next: TimedLyricLine?
    let start: Double
    let end: Double
    let wordIndex: Int
}

private enum LyricTimeline {
    static func parse(_ value: String, duration: Double) -> [TimedLyricLine] {
        var timed: [TimedLyricLine] = []
        let rawLines = value.split(whereSeparator: \.isNewline).map(String.init)
        let sourceOffset: Double = rawLines.compactMap { raw -> Double? in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.lowercased().hasPrefix("[offset:"), let close = line.firstIndex(of: "]") else { return nil }
            let start = line.index(line.startIndex, offsetBy: 8)
            return Double(line[start..<close]).map { $0 / 1000 }
        }.first ?? 0
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.lowercased().hasPrefix("[offset:") { continue }
            if let close = line.firstIndex(of: "]"), line.first == "[" {
                let stamp = String(line[line.index(after: line.startIndex)..<close])
                let text = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                if let time = timestamp(stamp), !text.isEmpty {
                    timed.append(TimedLyricLine(id: timed.count, time: max(0, time + sourceOffset), text: text))
                }
            }
        }
        guard !timed.isEmpty else { return [] }
        return timed.sorted { $0.time < $1.time }.enumerated().map {
            TimedLyricLine(id: $0.offset, time: $0.element.time, text: $0.element.text)
        }
    }
    static func frame(lines: [TimedLyricLine], position: Double, duration: Double) -> LyricFrame? {
        guard !lines.isEmpty else { return nil }
        let index = lines.lastIndex(where: { $0.time <= position + 0.035 }) ?? 0
        let current = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1] : nil
        let end = max(current.time + 0.35, next?.time ?? (duration > current.time ? duration : current.time + 4))
        let words = current.text.split(whereSeparator: \.isWhitespace)
        let progress = min(0.999, max(0, (position - current.time) / max(0.35, end - current.time)))
        let wordIndex = words.isEmpty ? 0 : min(words.count - 1, Int(progress * Double(words.count)))
        return LyricFrame(current: current, next: next, start: current.time, end: end, wordIndex: wordIndex)
    }
    private static func timestamp(_ raw: String) -> Double? {
        let pieces = raw.split(separator: ":")
        guard pieces.count == 2, let minutes = Double(pieces[0]), let seconds = Double(pieces[1]) else { return nil }
        return minutes * 60 + seconds
    }
}

private struct LyricWidthReporter: View {
    let width: Double
    var body: some View {
        Color.clear.frame(width: 0, height: 0).task(id: Int(width.rounded())) {
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: .init("HaloClosedMediaWidthHint"), object: nil, userInfo: ["width": width])
        }
    }
}

private struct ClosedMediaView: View {
    @ObservedObject var media: MediaService
    let options: ClosedMediaOptions
    let fontSize: Double
    let availableWidth: Double
    let lowPower: Bool
    @State private var lyrics = ""
    @State private var lyricsLoading = false
    @State private var sampledPosition = 0.0
    @State private var sampledDuration = 0.0
    @State private var sampledAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var key: String { (media.connectedApp ?? "") + "|" + media.title + "|" + media.artist }
    private var effectiveWidth: Double {
        let available = max(20, availableWidth)
        if options.overflow == .truncate || options.overflow == .marquee {
            return min(available, options.resolvedHorizontalSpace)
        }
        return available
    }
    var body: some View {
        ZStack {
            mediaText
                .id(key)
                .transition(reduceMotion ? .opacity : options.resolvedChangeAnimation.transition)
        }
        .frame(width: effectiveWidth)
        .animation(options.resolvedChangeAnimation == .none ? nil : .easeInOut(duration: options.resolvedChangeAnimationDuration), value: key)
        .task(id: key + "|\(options.textMode.rawValue)|\(options.usesOnlineLyrics)|\(options.resolvedLyricDisplay.rawValue)") {
            lyrics = ""; sampledPosition = 0; sampledDuration = 0; sampledAt = Date()
            guard options.textMode == .lyrics else { return }
            lyricsLoading = true
            let initial = await MediaAssetReader.playbackTime(app: media.connectedApp)
            if let initial {
                sampledPosition = initial.position
                sampledDuration = initial.duration
                sampledAt = initial.observedAt
            }
            lyrics = await MediaAssetReader.lyrics(app: media.connectedApp, key: key, title: media.title,
                                                   artist: media.artist, duration: initial?.duration,
                                                   onlineFallback: options.usesOnlineLyrics)
            lyricsLoading = false
            await samplePlaybackLoop()
        }
    }
    private func samplePlaybackLoop() async {
        while !Task.isCancelled && media.isPlaying && options.textMode == .lyrics {
            if let sample = await MediaAssetReader.playbackTime(app: media.connectedApp) {
                let now = sample.observedAt
                let predicted = sampledPosition + max(0, now.timeIntervalSince(sampledAt))
                let drift = sample.position - predicted
                if sampledDuration == 0 || abs(drift) > 0.10 {
                    sampledPosition = sample.position
                } else {
                    sampledPosition = predicted + drift * 0.88
                }
                sampledDuration = sample.duration
                sampledAt = now
            }
            try? await Task.sleep(nanoseconds: lowPower ? 600_000_000 : 250_000_000)
        }
    }
    @ViewBuilder private var mediaText: some View {
        let width = effectiveWidth
        switch options.textMode {
        case .titleArtist:
            if options.lines == 2 {
                VStack(alignment: .leading, spacing: 2) {
                    styledText(media.title, width: width)
                    styledText(media.artist.isEmpty ? "Unknown artist" : media.artist, width: width).opacity(0.72).font(.system(size: max(8, fontSize * 0.82)))
                }.frame(maxWidth: width, alignment: .leading)
            } else { inlineText([media.title, media.artist].filter { !$0.isEmpty }.joined(separator: " · "), width: width) }
        case .lyrics: syncedLyricsView(width: width)
        case .title: inlineText(media.title, width: width)
        case .artist: inlineText(media.artist.isEmpty ? media.title : media.artist, width: width)
        }
    }
    @ViewBuilder private func syncedLyricsView(width: Double) -> some View {
        if lyricsLoading && lyrics.isEmpty {
            Label("Loading lyrics…", systemImage: "text.quote").lineLimit(1).opacity(0.72)
        } else if lyrics.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(media.title).lineLimit(1)
                Text("Synced lyrics unavailable").font(.system(size: max(8, fontSize * 0.82))).opacity(0.65).lineLimit(1)
            }.frame(maxWidth: width, alignment: .leading)
        } else {
            TimelineView(.animation(minimumInterval: lowPower ? 0.24 : 0.06, paused: !media.isPlaying)) { context in
                let interpolated = sampledPosition + (media.isPlaying ? max(0, context.date.timeIntervalSince(sampledAt)) : 0)
                let position = max(0, interpolated + options.resolvedLyricSyncOffset)
                let lines = LyricTimeline.parse(lyrics, duration: sampledDuration)
                if let frame = LyricTimeline.frame(lines: lines, position: position, duration: sampledDuration) {
                    lyricPresentation(frame: frame, width: width)
                } else {
                    Text("Synced lyrics unavailable").opacity(0.65).lineLimit(1)
                }
            }
        }
    }
    @ViewBuilder private func lyricPresentation(frame: LyricFrame, width: Double) -> some View {
        switch options.resolvedLyricDisplay {
        case .line:
            if options.lines == 2 {
                VStack(alignment: .leading, spacing: 2) {
                    styledText(frame.current.text, width: width)
                    if let next = frame.next { styledText(next.text, width: width).opacity(0.45) }
                }
                .frame(maxWidth: width, alignment: .leading)
                .background(widthReporter(texts: [frame.current.text, frame.next?.text ?? ""]))
            } else {
                inlineText(frame.current.text, width: width)
                    .background(widthReporter(texts: [frame.current.text]))
            }
        case .word:
            let words = frame.current.text.split(whereSeparator: \.isWhitespace).map(String.init)
            let word = words.indices.contains(frame.wordIndex) ? words[frame.wordIndex] : frame.current.text
            inlineText(word, width: width)
                .background(widthReporter(texts: [word]))
        case .focus:
            VStack(alignment: .leading, spacing: 2) {
                focusedLine(frame.current.text, activeWord: frame.wordIndex, width: width)
                if options.lines == 2, let next = frame.next { styledText(next.text, width: width).opacity(0.35) }
            }
            .frame(maxWidth: width, alignment: .leading)
            .background(widthReporter(texts: options.lines == 2 ? [frame.current.text, frame.next?.text ?? ""] : [frame.current.text]))
        }
    }
    @ViewBuilder private func widthReporter(texts: [String]) -> some View {
        if options.usesDynamicLyricWidth {
            let font = NSFont.systemFont(ofSize: fontSize)
            let natural = texts.filter { !$0.isEmpty }.map { ceil(($0 as NSString).size(withAttributes: [.font: font]).width) }.max() ?? 36
            let icon = options.showPlaybackIcon ? fontSize + 10 : 0
            let maxWidth = (options.overflow == .truncate || options.overflow == .marquee) ? options.resolvedHorizontalSpace : 300
            LyricWidthReporter(width: min(maxWidth, max(28, natural + icon + 8)))
        }
    }
    private func focusedLine(_ text: String, activeWord: Int, width: Double) -> some View {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var result = Text("")
        for (index, word) in words.enumerated() {
            let piece = Text((index == 0 ? "" : " ") + word)
                .fontWeight(index == activeWord ? .bold : .regular)
                .foregroundColor(index == activeWord ? .primary : .secondary)
            result = result + piece
        }
        return result.lineLimit(1).minimumScaleFactor(0.5).frame(maxWidth: width, alignment: .leading)
    }
    @ViewBuilder private func inlineText(_ text: String, width: Double) -> some View {
        HStack(spacing: 6) {
            if options.showPlaybackIcon { Image(systemName: options.textMode == .lyrics ? "text.quote" : "music.note") }
            styledText(text, width: width)
        }.frame(maxWidth: width)
    }
    @ViewBuilder private func styledText(_ text: String, width: Double) -> some View {
        switch options.overflow {
        case .truncate: Text(text).lineLimit(1).truncationMode(.tail)
        case .scale: Text(text).lineLimit(1).minimumScaleFactor(0.45)
        case .marquee: MarqueeText(text: text, speed: options.marqueeSpeed, fontSize: fontSize, width: width, active: media.isPlaying && !lowPower)
        }
    }
}

private struct MarqueeText: View {
    let text: String; let speed: Double; let fontSize: Double; let width: Double; let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var estimatedTextWidth: Double { max(8, Double(text.count) * fontSize * 0.56) }
    var body: some View {
        if !active || reduceMotion || estimatedTextWidth <= width { Text(text).lineLimit(1) }
        else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                let gap = 28.0; let cycle = estimatedTextWidth + gap; let x = -(context.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: cycle)
                HStack(spacing: gap) { Text(text).fixedSize(); Text(text).fixedSize() }.offset(x: x).frame(width: width, alignment: .leading).clipped()
            }.frame(width: width)
        }
    }
}

private enum MediaAssetReader {
    struct PlaybackSample { let position: Double; let duration: Double; let observedAt: Date }
    private static let queue = DispatchQueue(label: "Halo.ClosedMediaAssets", qos: .utility)
    private static let lock = NSLock()
    private static var artworkCache: [String: Data] = [:]
    private static var lyricsCache: [String: String] = [:]
    static func artwork(app: String?, key: String) async -> NSImage? {
        guard let app else { return nil }; lock.lock(); let cached = artworkCache[key]; lock.unlock(); if let cached { return NSImage(data: cached) }
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
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                if failure != nil { continuation.resume(returning: (nil, nil)); return }
                continuation.resume(returning: (app == "com.apple.Music" ? result?.atIndex(2)?.data : nil, app == "com.spotify.client" ? result?.atIndex(2)?.stringValue : nil))
            }
        }
        var data = payload.0
        if data == nil, let urlString = payload.1, let url = URL(string: urlString), url.scheme == "https" {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8); request.setValue("Halo/1.0", forHTTPHeaderField: "User-Agent")
            if let (downloaded, response) = try? await URLSession.shared.data(for: request), downloaded.count <= 5_000_000, (response as? HTTPURLResponse)?.statusCode == 200 { data = downloaded }
        }
        guard let data, data.count <= 5_000_000 else { return nil }; lock.lock(); artworkCache[key] = data; lock.unlock(); return NSImage(data: data)
    }
    static func playbackTime(app: String?) async -> PlaybackSample? {
        guard let app else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async {
                let requestStarted = Date()
                let source = """
                if application id "\(app)" is not running then return {-1, -1}
                with timeout of 2 seconds
                    tell application id "\(app)"
                        try
                            return {(player position as real), (duration of current track as real)}
                        on error
                            return {-1, -1}
                        end try
                    end tell
                end timeout
                """
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                let requestFinished = Date()
                guard failure == nil,
                      let position = result?.atIndex(1)?.doubleValue,
                      let duration = result?.atIndex(2)?.doubleValue,
                      position >= 0, duration > 0 else { continuation.resume(returning: nil); return }
                let observedAt = requestStarted.addingTimeInterval(requestFinished.timeIntervalSince(requestStarted) * 0.5)
                continuation.resume(returning: PlaybackSample(position: position, duration: duration, observedAt: observedAt))
            }
        }
    }
    static func lyrics(app: String?, key: String, title: String, artist: String, duration: Double?, onlineFallback: Bool) async -> String {
        let durationKey = duration.map { String(Int($0.rounded())) } ?? "unknown"
        let cacheKey = key + "|duration:" + durationKey
        lock.lock(); let cached = lyricsCache[cacheKey]; lock.unlock(); if let cached { return cached }
        var value = ""
        if onlineFallback { value = await onlineLyrics(title: title, artist: artist, duration: duration) }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, app == "com.apple.Music" { value = await embeddedAppleMusicLyrics() }
        let bounded = String(value.prefix(20_000)); lock.lock(); lyricsCache[cacheKey] = bounded; lock.unlock(); return bounded
    }
    private static func embeddedAppleMusicLyrics() async -> String {
        await withCheckedContinuation { continuation in queue.async {
            let source = """
            if application id "com.apple.Music" is not running then return ""
            with timeout of 4 seconds
                tell application id "com.apple.Music"
                    try
                        return (get lyrics of current track) as text
                    on error
                        return ""
                    end try
                end tell
            end timeout
            """
            var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure); continuation.resume(returning: failure == nil ? (result?.stringValue ?? "") : "")
        } }
    }
    private struct LRCLyrics: Decodable { let duration: Double?; let plainLyrics: String?; let syncedLyrics: String? }
    private static func onlineLyrics(title: String, artist: String, duration: Double?) async -> String {
        guard !title.isEmpty, !artist.isEmpty else { return "" }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if let duration, duration >= 1, duration <= 3600 {
            components.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        guard let url = components.url else { return "" }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8); request.setValue("Halo/1.0 (https://github.com/Redstoneinvente/Halo)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 1_000_000, let result = try? JSONDecoder().decode(LRCLyrics.self, from: data) else { return "" }
        if let requested = duration, let returned = result.duration, abs(requested - returned) > 2.5 { return "" }
        return result.syncedLyrics ?? ""
    }
}

struct AlbumNotchBackground: View {
    let options: ClosedNotchOptions; @ObservedObject var media: MediaService; @ObservedObject var system: SystemService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion; @State private var artwork: NSImage?
    private var colors: [Color] { media.artworkColors.map(\.color) }; private var artworkOptions: ClosedArtworkOptions { options.resolvedArtwork }
    private var reactive: ReactiveBackgroundOptions { if let saved = options.reactiveBackground { return saved }; var legacy = ReactiveBackgroundOptions(); legacy.enabled = options.albumBackgroundFrequencyEffect ?? false; return legacy }
    private var key: String { (media.connectedApp ?? "") + "|" + media.title + "|" + media.artist }; private var wantsArtworkBackground: Bool { artworkOptions.enabled && artworkOptions.mode == .background }
    private var active: Bool { media.isPlaying && (reactive.enabled || (options.albumBackgroundColor == true && !colors.isEmpty) || (wantsArtworkBackground && artwork != nil)) }
    var body: some View {
        Group {
            if active {
                if reactive.enabled && !reduceMotion && !system.lowPower {
                    RefreshTimeline(active: true) { timestamp in reactiveBackground(signal: signal(at: timestamp)) }
                } else { baseBackground }
            }
        }
        .task(id: key + "|\(wantsArtworkBackground)") { guard media.isPlaying && wantsArtworkBackground else { artwork = nil; return }; artwork = await MediaAssetReader.artwork(app: media.connectedApp, key: key) }
        .task(id: "spectrum|\(media.isPlaying)|\(reactive.enabled)|\(reactive.driver.rawValue)") {
            AudioSpectrumService.shared.setActive(media.isPlaying && reactive.enabled && reactive.driver != .pulse)
        }
        .onDisappear { AudioSpectrumService.shared.setActive(false) }
    }
    private var gradientColors: [Color] { if colors.isEmpty { return [.clear, .clear] }; return colors.count == 1 ? [colors[0], colors[0].opacity(0.72)] : Array(colors.prefix(2)) }
    @ViewBuilder private var baseBackground: some View {
        if wantsArtworkBackground, let artwork { Image(nsImage: artwork).resizable().scaledToFill().opacity(artworkOptions.backgroundOpacity).overlay(LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)) }
        else if options.albumBackgroundColor == true && !colors.isEmpty { LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing) }
        else { Color.white.opacity(reactive.enabled ? 0.035 : 0) }
    }
    private func signal(at timestamp: Double) -> Double {
        if reactive.driver == .pulse { return (sin(timestamp * reactive.speed * 5.2) + 1) / 2 }
        let spectrum = AudioSpectrumService.shared.snapshot()
        guard spectrum.available else { return (sin(timestamp * reactive.speed * 4.1) + 1) * 0.08 + 0.08 }
        let raw: Double
        switch reactive.driver {
        case .pulse: raw = spectrum.overall
        case .bass: raw = spectrum.bass
        case .mids: raw = spectrum.mids
        case .treble: raw = spectrum.treble
        case .spectrum: raw = max(spectrum.bass, max(spectrum.mids, spectrum.treble)) * 0.65 + spectrum.overall * 0.35
        }
        return min(1, max(0, raw * reactive.resolvedAudioSensitivity))
    }
    private func reactiveBackground(signal: Double) -> some View {
        let amount = min(1, max(0, signal)) * reactive.intensity
        return baseBackground.brightness((amount - 0.18) * reactive.brightness).saturation(1 + amount * reactive.saturation).scaleEffect(1 + amount * reactive.scale).hueRotation(.degrees(amount * reactive.hueShift * 360)).blur(radius: amount * reactive.blur).overlay(Color.white.opacity(0.012 + amount * max(0.04, reactive.brightness * 0.18))).overlay(GrainOverlay(options: GrainOptions(enabled: reactive.grain > 0, amount: amount * reactive.grain, size: 1, warmth: 0)))
    }
}

struct PlaybackVisualizer: View {
    let kind: PlaybackAnimation; let playing: Bool; let enabled: Bool; var options = VisualizerOptions(); var palette: [WidgetColor] = []; var fallback: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var animated: Bool { playing && enabled && !reduceMotion }; private var colors: [Color] { let extracted = options.dynamicColors ? palette.map(\.color) : []; return extracted.isEmpty ? [fallback, fallback] : extracted.count == 1 ? [extracted[0], extracted[0]] : extracted }
    var body: some View {
        RefreshTimeline(active: animated) { timestamp in
            let time = animated ? timestamp * options.speed : 0
            Canvas { graphics, size in
                let w = Double(size.width), h = Double(size.height); let paint = GraphicsContext.Shading.linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: w, y: h)); let strength = playing ? options.intensity : 0.12
                switch kind {
                case .waveform, .ribbon:
                    for layer in 0..<(kind == .ribbon ? 3 : 1) { var line = Path(); for index in 0...64 { let x = Double(index) / 64; let envelope = sin(x * .pi); let y = h / 2 + sin(x * .pi * 4 - time * 5 + Double(layer) * 0.8) * h * 0.4 * strength * envelope; if index == 0 { line.move(to: CGPoint(x: x * w, y: y)) } else { line.addLine(to: CGPoint(x: x * w, y: y)) } }; var stroke = graphics; stroke.opacity = layer == 0 ? 1 : 0.45; stroke.stroke(line, with: paint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)) }
                case .rings:
                    for index in 0..<3 { let phase = animated ? (time * 0.65 + Double(index) / 3).truncatingRemainder(dividingBy: 1) : Double(index + 1) / 4; let diameter = max(2, h * (0.2 + phase * 0.75 * strength)); let rect = CGRect(x: (w - diameter) / 2, y: (h - diameter) / 2, width: diameter, height: diameter); var ring = graphics; ring.opacity = 1 - phase * 0.8; ring.stroke(Path(ellipseIn: rect), with: paint, lineWidth: 1.5) }
                case .orbit:
                    for index in 0..<6 { let phase = time * 3 + Double(index) * .pi / 3; let dot = 2.0 + Double(index) * 0.35; let x = w / 2 + cos(phase) * max(0, w / 2 - 4) * strength; let y = h / 2 + sin(phase) * max(0, h / 2 - 3) * strength; graphics.fill(Path(ellipseIn: CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)), with: paint) }
                case .bars, .wave, .pulse, .dots, .spectrum:
                    let count = kind == .pulse ? 3 : kind == .dots ? 7 : 11; let step = w / Double(count)
                    for index in 0..<count { let phase = time * (kind == .wave ? 5 : 8) + Double(index) * (kind == .bars ? 2.3 : 0.8); let signal = animated ? (sin(phase) + 1) / 2 : playing ? 0.5 : 0; let height = max(2, h * (0.12 + 0.88 * signal * strength)); let width = min(kind == .pulse ? 12.0 : 4.0, step * 0.7); let x = Double(index) * step + (step - width) / 2
                        if kind == .spectrum { let levels = max(1, Int(height / 3)); for level in 0..<levels { let rect = CGRect(x: x, y: h - Double(level + 1) * 3, width: width, height: 2); graphics.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: paint) } }
                        else if kind == .dots || kind == .pulse { let diameter = kind == .pulse ? max(2, width * (0.3 + signal * strength * 0.7)) : width; let y = kind == .dots ? (h - diameter) / 2 + sin(phase) * max(0, h / 2 - diameter) * strength : (h - diameter) / 2; graphics.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)), with: paint) }
                        else { let rect = CGRect(x: x, y: (h - height) / 2, width: width, height: height); graphics.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: paint) }
                    }
                }
            }.frame(maxWidth: options.width).frame(height: options.height)
        }.accessibilityLabel(playing ? "Music playing" : "Music paused")
    }
}