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
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if style.showTitle { Label(id.title, systemImage: id.symbol).font(style.font()) }
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
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
            if workspace.activities.isEmpty { Text("Timer completions appear here.").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            ForEach(workspace.activities) { activity in
                HStack {
                    VStack(alignment: .leading) {
                        Text(activity.title); Text(activity.detail).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
                        if let progress = activity.progress { ProgressView(value: progress) }
                    }
                    Spacer()
                    Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss activity")
                }
            }
        case .developer:
            Text(workspace.gitSummary).font(style.font()).textSelection(.enabled)
            HStack {
                Button("Choose repository…") { workspace.chooseRepository() }
                Button(workspace.gitBusy ? "Refreshing…" : "Refresh") { workspace.refreshGit() }.disabled(workspace.gitBusy)
            }
        case .notes: TextEditor(text: $workspace.settings.notes).frame(height: 90).accessibilityLabel("Quick note")
        case .capture: CaptureModuleView(service: workspace.capture, store: store)
        case .stopwatch:
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = Int(workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0))
                Text(String(format: "%02d:%02d:%02d", elapsed / 3600, elapsed / 60 % 60, elapsed % 60)).font(style.font(scale: 2)).monospacedDigit()
            }
            HStack {
                Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture asks for Screen Recording access.").font(style.font(scale: 0.85))
            HStack {
                Button("Capture region…") { service.capture { store.addFiles([$0]) } }
                Button("Extract text from image…") { service.chooseImage() }
            }.disabled(service.busy)
            if service.busy { ProgressView() }
            if !service.recognizedText.isEmpty {
                Text(service.recognizedText).font(style.font(scale: 0.85)).textSelection(.enabled).lineLimit(12)
                Button("Copy extracted text") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }
                Button("Clear extracted text") { service.recognizedText = "" }
            }
            if let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }
    }
}
struct MediaModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: MediaService
    let app: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(service.title).lineLimit(2)
            if let source = service.connectedApp { Text(source == "com.apple.Music" ? "Apple Music" : "Spotify").font(style.font(scale: 0.75)).foregroundStyle(.secondary) }
            Text(service.artist).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            HStack {
                Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("Previous track")
                Button { service.perform("playpause", app: app) } label: { Image(systemName: "playpause.fill") }.accessibilityLabel("Play or pause")
                Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Next track")
                Spacer()
                Button("Retry detection") { service.retryDetection(preferred: app) }
            }.disabled(service.busy)
            if let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }
    }
}
struct AudioModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: AudioService
    var body: some View {
        VStack(alignment: .leading) {
            Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                ForEach(service.devices) { Text($0.name).tag($0.id) }
            }
            if service.canSetVolume {
                Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
            } else { Text("Use this device's hardware volume controls.").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            Button("Refresh devices") { service.refresh() }
            if let error = service.error { Text(error).font(style.font(scale: 0.85)).foregroundStyle(.orange) }
        }.onAppear { service.refresh() }
    }
}
struct CalendarModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: CalendarService
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(service.status).font(style.font(scale: 0.85)).foregroundStyle(.secondary)
            ForEach(service.events, id: \.eventIdentifier) { event in
                HStack {
                    VStack(alignment: .leading) {
                        Text(event.title ?? "Untitled event").lineLimit(1)
                        Text(event.startDate, style: .time).font(style.font(scale: 0.85))
                    }
                    Spacer()
                    if let url = service.meetingURL(for: event) { Link("Join", destination: url) }
                }
            }
            Button("Enable / Refresh calendar") { service.requestAccess() }
        }.onAppear { service.refresh() }
    }
}
struct ClipboardModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: ClipboardService
    let enabled: Bool
    @State private var search = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !enabled { Text("Off. Enable text history in Privacy settings.").font(style.font(scale: 0.85)) }
            else {
                TextField("Search clipboard", text: $search)
                ForEach(service.entries.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }) { entry in
                    HStack {
                        Text(entry.text).font(style.font(scale: 0.85)).lineLimit(2)
                        Spacer()
                        Button("Copy") { service.copy(entry) }
                        Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.accessibilityLabel("Remove clipboard item")
                    }
                }
                Button("Clear history") { service.reset() }
                Text("Text only · 50 items · memory only · copying does not paste into another app").font(style.font(scale: 0.75)).foregroundStyle(.secondary)
            }
        }
    }
}
struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var service: SystemService
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let battery = service.battery {
                Label("\(battery)% · \(service.charging ? "Charging" : service.onBattery ? "Battery" : "AC power")", systemImage: service.charging ? "battery.100.bolt" : "battery.100")
                ProgressView(value: Double(battery), total: 100)
            }
            Text(service.memory); Text(service.storage)
            Text(service.uptime + (service.lowPower ? " · Low Power Mode" : ""))
        }.font(style.font(scale: 0.85))
    }
}
struct LauncherModuleView: View {
    @Environment(\.widgetStyle) private var style
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @State private var query = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search apps and commands", text: $query)
            ForEach([5, 15, 25], id: \.self) { minutes in
                if CommandSearch.matches(query, in: "Start timer \(minutes)") {
                    Button("Start \(minutes)-minute timer") { store.startTimer(minutes: minutes) }
                }
            }
            ForEach(workspace.runningApps.filter { CommandSearch.matches(query, in: $0.localizedName ?? "") }, id: \.processIdentifier) { app in
                Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                    Label(app.localizedName ?? "Application", systemImage: "app")
                }
            }
            ForEach(workspace.plugins) { plugin in
                ForEach(plugin.commands.filter { CommandSearch.matches(query, in: $0.title) }) { command in
                    Button(command.title) { workspace.run(command) }
                }
            }
            HStack {
                Button("Open application…") {
                    let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
                    if panel.runModal() == .OK, let url = panel.url { NSWorkspace.shared.open(url) }
                }
                Button("Downloads") { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) }
            }
        }.onAppear { workspace.refreshApps() }
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
            case .solid: EmptyView()
            case .glass: EmptyView()
            case .gradient:
                LinearGradient(colors: [Color(hue: theme.tint, saturation: 0.7, brightness: 0.35), .black], startPoint: .bottomLeading, endPoint: .topTrailing)
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
