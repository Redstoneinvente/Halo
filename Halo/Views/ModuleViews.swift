import SwiftUI
import AppKit
import AVKit
import ImageIO

@MainActor
protocol HaloModule {
    var id: ModuleID { get }
    func makeView(context: ModuleContext) -> AnyView
}
struct ModuleContext { let store: AppStore; let workspace: WorkspaceStore }
struct IntegrationModule: HaloModule {
    let id: ModuleID
    func makeView(context: ModuleContext) -> AnyView {
        AnyView(IntegrationModuleView(id: id, store: context.store, workspace: context.workspace))
    }
}
@MainActor
struct ModuleRegistry {
    let modules: [ModuleID: IntegrationModule] = Dictionary(uniqueKeysWithValues: ModuleID.allCases.map { ($0, IntegrationModule(id: $0)) })
    func view(for id: ModuleID, store: AppStore) -> AnyView {
        modules[id]?.makeView(context: ModuleContext(store: store, workspace: store.workspace)) ?? AnyView(EmptyView())
    }
}
struct IntegrationModuleView: View {
    @Environment(\.widgetStyle) private var style
    let id: ModuleID
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    private var options: WidgetContentOptions { style.resolvedContent }
    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if style.showTitle {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    if options.iconSize > 0 { Image(systemName: id.symbol).font(.system(size: options.iconSize, weight: .semibold)).foregroundStyle(style.accentColor.color) }
                    Text(id.title).font(style.font())
                }
            }
            content
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
    @ViewBuilder private var content: some View {
        switch id {
        case .media: MediaModuleView(service: workspace.media, app: workspace.settings.mediaApp)
        case .audio: AudioModuleView(service: workspace.audio)
        case .calendar: CalendarModuleView(service: workspace.calendar)
        case .clipboard: ClipboardModuleView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled)
        case .system: SystemModuleView(service: workspace.system)
        case .launcher: LauncherModuleView(store: store, workspace: workspace)
        case .activities:
            if workspace.activities.isEmpty, options.showStatus {
                Text("Timer completions appear here.").font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            }
            ForEach(Array(workspace.activities.prefix(options.maxItems))) { activity in
                HStack(spacing: options.spacing) {
                    VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                        Text(activity.title)
                        if options.activitiesShowDetail && options.showSecondaryText && !activity.detail.isEmpty {
                            Text(activity.detail).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
                        }
                        if options.showProgress, let progress = activity.progress { ProgressView(value: progress) }
                    }
                    Spacer()
                    if options.showControls {
                        Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss activity")
                    }
                }
            }
        case .developer: EmptyView() // Legacy saved module, no longer displayed.
        case .notes: TextEditor(text: $workspace.settings.notes).frame(height: options.notesHeight).accessibilityLabel("Quick note")
        case .capture: CaptureModuleView(service: workspace.capture, store: store)
        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = Int(workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0))
                Text(String(format: "%02d:%02d:%02d", elapsed / 3600, elapsed / 60 % 60, elapsed % 60))
                    .font(style.font(scale: options.stopwatchScale)).monospacedDigit()
            }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                    Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
                }
            }
        default: EmptyView()
        }
    }
}
struct CaptureModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: CaptureService
    @ObservedObject var store: AppStore
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.captureShowHelp && options.showSecondaryText { Text("Capture asks for Screen Recording access.").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button("Capture region…") { service.capture { store.addFiles([$0]) } }
                    Button("Extract text from image…") { service.chooseImage() }
                }.disabled(service.busy)
            }
            if service.busy && options.showStatus { ProgressView() }
            if !service.recognizedText.isEmpty {
                Text(service.recognizedText).font(style.font(scale: 0.85)).textSelection(.enabled).lineLimit(options.captureTextLines)
                if options.showControls {
                    HStack(spacing: options.spacing) {
                        Button("Copy extracted text") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }
                        Button("Clear extracted text") { service.recognizedText = "" }
                    }
                }
            }
            if options.showStatus, let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}
struct MediaModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: MediaService
    let app: String
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            Text(service.title).lineLimit(options.mediaTitleLines)
            if options.mediaShowSource && options.showSecondaryText, let source = service.connectedApp {
                Text(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio")
                    .font(style.font(scale: 0.75)).foregroundStyle(.secondary)
            }
            if options.mediaShowArtist && options.showSecondaryText && !service.artist.isEmpty {
                Text(service.artist).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            }
            if options.showControls {
                HStack(spacing: options.spacing) {
                    Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                    Button { service.perform("playpause", app: app) } label: { Image(systemName: "playpause.fill") }.accessibilityLabel("Play or pause")
                    Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                    Spacer()
                    Button("Retry detection") { service.retryDetection(preferred: app) }
                }.disabled(service.busy)
            }
            if options.showStatus, let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}
struct AudioModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: AudioService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }
            }
            if service.canSetVolume && options.showControls {
                Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
            } else if !service.canSetVolume && options.showStatus {
                Text("Use this device's hardware volume controls.").font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            }
            if options.showQuickActions { Button("Refresh devices") { service.refresh() } }
            if options.showStatus, let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
}
struct CalendarModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: CalendarService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.showStatus { Text(service.status).font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            ForEach(Array(service.events.prefix(options.maxItems)), id: \.eventIdentifier) { event in
                HStack(spacing: options.spacing) {
                    VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                        Text(event.title ?? "Untitled event").lineLimit(1)
                        if options.calendarShowTimes && options.showSecondaryText { Text(event.startDate, style: .time).font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) { Link("Join", destination: url) }
                }
            }
            if options.showQuickActions { Button("Enable / Refresh calendar") { service.requestAccess() } }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
}
struct ClipboardModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: ClipboardService
    let enabled: Bool
    @State private var search = ""
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if !enabled { if options.showStatus { Text("Off. Enable text history in Privacy settings.").font(style.font(scale: 0.85)) } }
            else {
                if options.showSearch { TextField("Search clipboard", text: $search) }
                ForEach(Array(service.entries.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }.prefix(options.maxItems))) { entry in
                    HStack(spacing: options.spacing) {
                        Text(entry.text).font(style.font(scale: 0.85)).lineLimit(2)
                        Spacer()
                        if options.showControls {
                            Button("Copy") { service.copy(entry) }
                            Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Remove clipboard item")
                        }
                    }
                }
                if options.showQuickActions { Button("Clear history") { service.reset() } }
                if options.showFooter { Text("Text only · 50 items · memory only · copying does not paste into another app").font(style.font(scale: 0.75)).foregroundStyle(.secondary) }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}
struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: SystemService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.systemBattery, let battery = service.battery {
                HStack(spacing: max(4, options.spacing * 0.55)) {
                    Image(systemName: service.charging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: options.iconSize)).foregroundStyle(style.accentColor.color)
                    Text("\(battery)% · \(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power")")
                }
                if options.showProgress { ProgressView(value: Double(battery), total: 100) }
            }
            if options.systemMemory { Text(service.memory) }
            if options.systemStorage { Text(service.storage) }
            if options.systemUptime { Text(service.uptime + (service.lowPower ? " · Low Power Mode" : "")) }
        }.font(style.font(scale: 0.85)).frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}
struct LauncherModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @State private var query = ""
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if options.showSearch { TextField("Search apps and commands", text: $query) }
            if options.launcherTimers {
                ForEach([5, 15, 25], id: \.self) { minutes in
                    if CommandSearch.matches(query, in: "Start timer \(minutes)") {
                        Button("Start \(minutes)-minute timer") { store.startTimer(minutes: minutes) }
                    }
                }
            }
            if options.launcherRunningApps {
                ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(query, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \.processIdentifier) { app in
                    Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                        Label(app.localizedName ?? "Application", systemImage: "app")
                    }
                }
            }
            if options.launcherPlugins {
                ForEach(workspace.plugins) { plugin in
                    ForEach(plugin.commands.filter { CommandSearch.matches(query, in: $0.title) }.prefix(options.maxItems)) { command in
                        Button(command.title) { workspace.run(command) }
                    }
                }
            }
            if options.showQuickActions {
                HStack(spacing: options.spacing) {
                    Button("Open application…") {
                        let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
                        if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
                    }
                    Button("Downloads") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
                }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { workspace.refreshApps() }
    }
}

struct SurfaceBackground: View {
    let appearance: Appearance
    let theme: Theme
    let expanded: Bool
    @ObservedObject var system: SystemService
    var body: some View {
        TimelineView(.periodic(from: Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60), by: 60)) { context in
            ResolvedSurfaceBackground(appearance: appearance.resolved(at: context.date), theme: theme, expanded: expanded, system: system)
        }
    }
}
struct ResolvedSurfaceBackground: View {
    let appearance: Appearance
    let theme: Theme
    let expanded: Bool
    @ObservedObject var system: SystemService
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        material.overlay { GrainOverlay(options: appearance.grain ?? GrainOptions()) }
    }
    @ViewBuilder private var material: some View {
        if appearance.background == .glass {
            if reduceTransparency {
                Color.black
            } else {
                DesktopGlass()
                    .overlay(Color.black.opacity(GlassRendering.tintOpacity(themeOpacity: theme.opacity)))
            }
        } else { decoratedBackground }
    }
    private var decoratedBackground: some View {
        ZStack {
            Color.black.opacity(reduceTransparency ? 1 : theme.opacity)
            switch appearance.background {
            case .solid:
                (appearance.solidColor?.color ?? Color.black)
                    .opacity(reduceTransparency ? 1 : theme.opacity)
            case .glass: EmptyView()
            case .gradient:
                LinearGradient(
                    colors: [
                        appearance.gradientStartColor?.color ?? Color(hue: theme.tint, saturation: 0.7, brightness: 0.35),
                        appearance.gradientEndColor?.color ?? Color.black
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            case .image:
                CachedBackgroundImage(path: appearance.assetPath)
            case .video:
                LoopingVideo(path: appearance.assetPath, playing: expanded && !(appearance.pauseVideoOnBattery && system.onBattery))
            }
        }.blur(radius: reduceTransparency ? 0 : appearance.blur).saturation(appearance.saturation).brightness(appearance.brightness)
    }
}
/// Native backdrop sampling must stay out of SwiftUI blur/offscreen filter groups.
struct DesktopGlass: NSViewRepresentable {
    final class EffectView: NSVisualEffectView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
    func makeNSView(context: Context) -> EffectView {
        let view = EffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: EffectView, context: Context) {}
}
struct CachedBackgroundImage: View {
    let path: String
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Color.clear }
        }.task(id: path) {
            image = nil
            let currentPath = path
            let decoded = await Task.detached(priority: .utility) { () -> CGImage? in
                guard !currentPath.isEmpty,
                      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: currentPath) as CFURL, nil) else { return nil }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1280,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary)
            }.value
            guard !Task.isCancelled else { return }
            if let decoded { image = NSImage(cgImage: decoded, size: .zero) }
        }
    }
}
struct LoopingVideo: NSViewRepresentable {
    let path: String
    let playing: Bool
    final class Coordinator {
        var path = ""
        var player = AVQueuePlayer()
        var looper: AVPlayerLooper?
        var playing = false
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView(); view.controlsStyle = .none; view.videoGravity = .resizeAspectFill
        view.player = context.coordinator.player; context.coordinator.player.isMuted = true
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {
        let state = context.coordinator
        if state.path != path {
            state.player.pause(); state.playing = false; state.looper = nil; state.player.removeAllItems(); state.path = path
            if FileManager.default.fileExists(atPath: path) { state.looper = AVPlayerLooper(player: state.player, templateItem: AVPlayerItem(url: URL(fileURLWithPath: path))) }
        }
        if state.playing != playing {
            state.playing = playing
            if playing { state.player.play() } else { state.player.pause() }
        }
    }
    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) { coordinator.player.pause(); coordinator.looper = nil; coordinator.player.removeAllItems() }
}