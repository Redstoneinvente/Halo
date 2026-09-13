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
        Group {
            switch style.resolvedLayoutMode {
            case .compact:
                HStack(alignment: .top, spacing: max(6, options.spacing)) {
                    if style.showTitle { header(scale: 0.82) }
                    content
                }
            case .hero:
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing * 1.15) {
                    if style.showTitle { header(scale: 1.08) }
                    content
                }
            case .minimal:
                VStack(alignment: options.alignment.horizontal, spacing: max(3, options.spacing * 0.65)) {
                    if style.showTitle { header(scale: 0.72) }
                    content
                }
            case .dense:
                VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.55)) {
                    if style.showTitle { header(scale: 0.78) }
                    content
                }
            case .standard:
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    if style.showTitle { header(scale: 1) }
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }

    @ViewBuilder private func header(scale: Double) -> some View {
        HStack(spacing: max(4, options.spacing * 0.55)) {
            if style.showsHeaderIcon && options.iconSize > 0 {
                Image(systemName: id.symbol)
                    .font(.system(size: options.iconSize, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
            }
            Text(id.title).font(style.font(scale: scale))
        }
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
            WidgetElement(key: "summary") {
                Label("\(workspace.activities.count) live activit\(workspace.activities.count == 1 ? "y" : "ies")", systemImage: "waveform.path")
            }
            if workspace.activities.isEmpty, options.showStatus {
                WidgetElement(key: "status") {
                    Text("Timer completions and live progress appear here.").foregroundStyle(.secondary)
                }
            }
            WidgetElement(key: "items") {
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    ForEach(Array(workspace.activities.prefix(options.maxItems))) { activity in
                        HStack(spacing: options.spacing) {
                            VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                                Text(activity.title)
                                if options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }
                                if options.showProgress, let progress = activity.progress { ProgressView(value: progress) }
                            }
                            Spacer()
                            if options.showControls { Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") } }
                        }
                    }
                }
            }
        case .notes:
            WidgetElement(key: "stats") {
                let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count
                HStack { Label("\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\(workspace.settings.notes.count) chars") }
            }
            WidgetElement(key: "editor") {
                TextEditor(text: $workspace.settings.notes).frame(height: options.notesHeight).accessibilityLabel("Quick note")
            }
            WidgetElement(key: "actions", defaultVisible: false) {
                HStack {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(workspace.settings.notes, forType: .string) }
                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)
                }
            }
        case .capture:
            CaptureModuleView(service: workspace.capture, store: store)
        case .stopwatch:
            WidgetElement(key: "state") {
                Label(workspace.stopwatchStart == nil ? (workspace.stopwatchElapsed > 0 ? "Paused" : "Ready") : "Running",
                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")
            }
            WidgetElement(key: "time") {
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0)
                    let whole = Int(elapsed)
                    Text(String(format: "%02d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60))
                        .font(style.font(scale: options.stopwatchScale)).monospacedDigit()
                }
            }
            if options.showControls {
                WidgetElement(key: "controls") {
                    HStack(spacing: options.spacing) {
                        Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                        Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
                    }
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
            if options.captureShowHelp {
                WidgetElement(key: "hint") { Label("Screen Recording access is used only when you capture.", systemImage: "lock.shield") }
            }
            if options.showControls {
                WidgetElement(key: "actions") {
                    HStack(spacing: options.spacing) {
                        Button("Capture region…") { service.capture { store.addFiles([$0]) } }
                        Button("Extract text from image…") { service.chooseImage() }
                    }.disabled(service.busy)
                }
            }
            if service.busy && options.showStatus { WidgetElement(key: "progress") { ProgressView("Working…") } }
            if !service.recognizedText.isEmpty {
                WidgetElement(key: "result") { Text(service.recognizedText).textSelection(.enabled).lineLimit(options.captureTextLines) }
                if options.showControls {
                    WidgetElement(key: "resultActions") {
                        HStack(spacing: options.spacing) {
                            Button("Copy text") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }
                            Button("Clear") { service.recognizedText = "" }
                        }
                    }
                }
            }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
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
            WidgetElement(key: "track") { Text(service.title).lineLimit(options.mediaTitleLines) }
            if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist") { Text(service.artist) } }
            if options.mediaShowSource, let source = service.connectedApp {
                WidgetElement(key: "source") {
                    Label(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio", systemImage: "app.badge")
                }
            }
            WidgetElement(key: "playback") {
                Label(service.connectedApp == nil ? "Waiting for a player" : (service.isPlaying ? "Playing" : "Paused"),
                      systemImage: service.connectedApp == nil ? "music.note" : (service.isPlaying ? "play.fill" : "pause.fill"))
            }
            WidgetElement(key: "palette", defaultVisible: false) {
                HStack(spacing: 6) {
                    Text("Artwork colors")
                    ForEach(Array(service.artworkColors.prefix(5).enumerated()), id: \.offset) { _, color in
                        Circle().fill(color.color).frame(width: 14, height: 14)
                    }
                }
            }
            if options.showControls {
                WidgetElement(key: "controls") {
                    HStack(spacing: options.spacing) {
                        Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }
                        Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") }
                        Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }
                    }.disabled(service.busy)
                }
            }
            if options.showQuickActions { WidgetElement(key: "detection", defaultVisible: false) { Button("Retry player detection") { service.retryDetection(preferred: app) } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.setArtworkEnabled(true) }
    }
}

struct AudioModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: AudioService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
                HStack { Label("\(service.devices.count) outputs", systemImage: "speaker.wave.2"); Spacer(); Text("\(Int(service.volume * 100))%") }
            }
            WidgetElement(key: "output") {
                Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                    ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }
                }
            }
            if service.canSetVolume && options.showControls {
                WidgetElement(key: "volume") {
                    Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
                }
                WidgetElement(key: "volumeValue") { Text("Volume \(Int(service.volume * 100))%").monospacedDigit() }
                WidgetElement(key: "levels", defaultVisible: false) {
                    HStack { ForEach([0, 25, 50, 75, 100], id: \.self) { value in Button("\(value)%") { service.setVolume(Float(value) / 100) } } }
                }
            } else if !service.canSetVolume && options.showStatus {
                WidgetElement(key: "status") { Text("This output uses hardware volume controls.") }
            }
            if options.showQuickActions { WidgetElement(key: "actions") { Button("Refresh devices") { service.refresh() } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment).onAppear { service.refresh() }
    }
}

struct CalendarModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: CalendarService
    var body: some View {
        let options = style.resolvedContent
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
                HStack { Text(Date(), style: .date); Spacer(); Text("\(service.events.count) remaining") }
            }
            if let next = service.events.first {
                WidgetElement(key: "nextEvent") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) { Text(next.title ?? "Untitled event"); Text(next.startDate, style: .relative).foregroundStyle(.secondary) }
                        Spacer()
                        if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: next) { Link("Join", destination: url) }
                    }
                }
            }
            if options.showStatus { WidgetElement(key: "status") { Text(service.status) } }
            WidgetElement(key: "events") {
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    ForEach(Array(service.events.prefix(options.maxItems)), id: \.eventIdentifier) { event in
                        HStack(spacing: options.spacing) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title ?? "Untitled event").lineLimit(1)
                                if options.calendarShowTimes { Text(event.startDate, style: .time).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) { Link("Join", destination: url) }
                        }
                    }
                }
            }
            if options.showQuickActions { WidgetElement(key: "actions") { Button("Enable / Refresh calendar") { service.requestAccess() } } }
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
            if !enabled {
                if options.showStatus { WidgetElement(key: "summary") { Text("Clipboard history is off. Enable it in Privacy settings.") } }
            } else {
                WidgetElement(key: "summary") {
                    HStack {
                        Label("\(service.entries.count) entries", systemImage: "doc.on.clipboard")
                        Spacer()
                        if let newest = service.entries.first { Text(newest.date, style: .relative).foregroundStyle(.secondary) }
                    }
                }
                if options.showSearch { WidgetElement(key: "search") { TextField("Search clipboard", text: $search) } }
                let effectiveSearch = options.showSearch ? search : ""
                WidgetElement(key: "entries") {
                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(options.maxItems))) { entry in
                            HStack(spacing: options.spacing) {
                                VStack(alignment: .leading, spacing: 2) { Text(entry.text).lineLimit(2); Text(entry.date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if options.showControls {
                                    Button("Copy") { service.copy(entry) }
                                    Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }
                                }
                            }
                        }
                    }
                }
                if options.showQuickActions { WidgetElement(key: "actions") { Button("Clear history") { service.reset() } } }
                if options.showFooter { WidgetElement(key: "footer") { Text("Text only · up to 50 items · memory only") } }
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
                WidgetElement(key: "battery") {
                    HStack { Label("\(battery)%", systemImage: service.charging ? "battery.100.bolt" : "battery.100"); Spacer(); Text(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power") }
                }
                if options.showProgress { WidgetElement(key: "batteryProgress") { ProgressView(value: Double(battery), total: 100) } }
            }
            WidgetElement(key: "power") {
                HStack { Label(service.lowPower ? "Low Power Mode" : "Normal power", systemImage: service.lowPower ? "leaf.fill" : "bolt.fill"); Spacer(); Text(service.onBattery ? "On battery" : "External power") }
            }
            if options.systemMemory { WidgetElement(key: "memory") { Label(service.memory, systemImage: "memorychip") } }
            if options.systemStorage { WidgetElement(key: "storage") { Label(service.storage, systemImage: "internaldrive") } }
            if options.systemUptime { WidgetElement(key: "uptime") { Label(service.uptime, systemImage: "clock.arrow.circlepath") } }
            WidgetElement(key: "device", defaultVisible: false) {
                VStack(alignment: options.alignment.horizontal, spacing: 3) {
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                    Text("\(ProcessInfo.processInfo.processorCount) logical processors").foregroundStyle(.secondary)
                }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
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
            WidgetElement(key: "summary", defaultVisible: false) {
                HStack { Label("\(workspace.runningApps.count) apps", systemImage: "square.grid.2x2"); Spacer(); Text("\(workspace.plugins.reduce(0) { $0 + $1.commands.count }) plugin commands") }
            }
            if options.showSearch { WidgetElement(key: "search") { TextField("Search apps and commands", text: $query) } }
            let effectiveQuery = options.showSearch ? query : ""
            if options.launcherTimers {
                WidgetElement(key: "timers") {
                    HStack { ForEach([5, 15, 25], id: \.self) { minutes in Button("\(minutes)m") { store.startTimer(minutes: minutes) } } }
                }
            }
            if options.launcherRunningApps {
                WidgetElement(key: "apps") {
                    VStack(alignment: options.alignment.horizontal, spacing: max(4, options.spacing * 0.65)) {
                        ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \.processIdentifier) { app in
                            Button { app.activate(options: .activateIgnoringOtherApps) } label: { Label(app.localizedName ?? "Application", systemImage: "app") }
                        }
                    }
                }
            }
            if options.launcherPlugins {
                WidgetElement(key: "plugins") {
                    VStack(alignment: options.alignment.horizontal, spacing: max(4, options.spacing * 0.65)) {
                        ForEach(workspace.plugins) { plugin in
                            ForEach(plugin.commands.filter { CommandSearch.matches(effectiveQuery, in: $0.title) }.prefix(options.maxItems)) { command in
                                Button(command.title) { workspace.run(command) }
                            }
                        }
                    }
                }
            }
            if options.showQuickActions {
                WidgetElement(key: "shortcuts") {
                    HStack(spacing: options.spacing) {
                        Button("Open application…") {
                            let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
                            if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
                        }
                        Button("Downloads") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
                    }
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