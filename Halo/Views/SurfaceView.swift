import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SurfaceViewportView: View {
    @ObservedObject var viewport: SurfaceViewport
    let content: SurfaceView
    var body: some View {
        content.equatable().frame(width: viewport.size.width, height: viewport.size.height, alignment: .top).clipped()
    }
}

struct SurfaceView: View, Equatable {
    static func == (lhs: SurfaceView, rhs: SurfaceView) -> Bool {
        lhs.store === rhs.store && lhs.state === rhs.state && lhs.workspace === rhs.workspace
    }
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    private var theme: Theme { state.theme }
    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }
    private var contour: HaloContour {
        HaloContour(kind: effectiveShape, radius: (layout.appearance.surface.useStyleContour ?? true) ? (theme.style == .menuBar ? 4 : theme.style == .pill ? 40 : theme.cornerRadius) : theme.cornerRadius,
                    topRadius: layout.appearance.surface.topRadius, bottomRadius: layout.appearance.surface.bottomRadius,
                    shoulder: layout.appearance.surface.shoulder)
    }
    private var effectiveShape: SurfaceShapeKind {
        guard layout.appearance.surface.useStyleContour ?? true else { return layout.appearance.surface.shape }
        switch theme.style {
        case .pill: return state.expanded ? .rounded : .capsule
        case .island: return state.expanded ? .rounded : .capsule
        case .simulated, .notch: return .scoop
        case .shelf: return .chamfer
        case .detached: return .rounded
        case .menuBar: return .rounded
        default: return layout.appearance.surface.shape
        }
    }
    @State private var page = 0
    private var modules: [ModuleID] { layout.normalizedOrder().filter { layout.enabled.contains($0) } }
    @State private var targeted = false
    private var accent: Color { Color(hue: theme.tint, saturation: 0.65, brightness: 1) }
    var body: some View {
        VStack(spacing: 0) {
            Group {
              if !state.expanded && (state.compactWidth < 48 || state.compactHeight < 16) {
                Circle().fill(store.deadline == nil ? accent : .green).frame(width: 6, height: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else if !state.expanded {
                ClosedNotchView(store: store, workspace: workspace, layout: layout, occlusion: state.closedOcclusion, referenceWidth: state.compactWidth)
              } else { HStack {
                Circle().fill(store.deadline == nil ? accent : .green).frame(width: 7, height: 7)
                Spacer()
                Image(systemName: state.expanded ? "chevron.up" : "chevron.down").font(.system(size: 9, weight: .bold))
              } }
            }
            .padding(.horizontal, !state.expanded ? 0 : max(16, layout.appearance.surface.shoulder + 8))
            .frame(height: state.expanded ? max(40, state.compactHeight) : state.compactHeight)
            .contentShape(Rectangle())
            .onTapGesture { state.expanded.toggle() }
            .accessibilityLabel("Toggle Halo dashboard")
            .accessibilityAddTraits(.isButton)
            if state.expanded {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Your space, within reach.").font(.headline)
                            Text("HALO / PERSONAL WORKSPACE").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(accent)
                        }
                        Spacer()
                        Button { state.pinned.toggle() } label: { Image(systemName: state.pinned ? "pin.fill" : "pin") }
                            .help("Keep expanded").accessibilityLabel("Keep expanded")
                    }
                    ContextNotchInterface(media: workspace.media, options: layout.contextMusic ?? ContextMusicOptions(), visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions()) {
                    if layout.horizontalWidgets ?? false {
                        if layout.horizontalPages ?? false {
                            VStack(spacing: 8) {
                                if !modules.isEmpty {
                                    let index = min(page, modules.count - 1)
                                    horizontalWidget(modules[index])
                                    HStack {
                                        Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }
                                            .disabled(index == 0).accessibilityLabel("Previous widget")
                                        Spacer()
                                        Text("\(modules[index].title) · \(index + 1) / \(modules.count)").font(.caption)
                                        Spacer()
                                        Button { page = min(modules.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }
                                            .disabled(index == modules.count - 1).accessibilityLabel("Next widget")
                                    }
                                } else { Text("Enable widgets in Settings → Modules.").foregroundStyle(.secondary) }
                            }
                        } else { ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: layout.appearance.spacing) {
                                widgetCards(horizontal: true)
                            }
                        } }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: layout.appearance.spacing) {
                                widgetCards(horizontal: false)
                            }
                        }
                    }
                    }
                    HStack {
                        Spacer()
                        Button("Settings") { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) }
                    }
                }.padding(.horizontal, max(20, layout.appearance.surface.shoulder + 12)).padding(.vertical, 20).frame(width: state.dashboardWidth).transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
                if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {
                    AlbumNotchBackground(options: layout.closedNotch ?? ClosedNotchOptions(), media: workspace.media, system: workspace.system)
                }
            }
        }
        .clipShape(contour)
        .contentShape(contour)
        .overlay(contour.stroke(targeted ? accent : .white.opacity(0.12), lineWidth: 1))
        .foregroundStyle(.white).preferredColorScheme(.dark)
        .buttonStyle(.borderless)
        .contextMenu {
            Button(state.pinned ? "Unpin" : "Keep open") { state.pinned.toggle() }
            ForEach(workspace.settings.profiles) { profile in Button(profile.name) { workspace.apply(profile) } }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in store.expireFiles() }
        .onHover { state.hover($0, enabled: store.configuration.hoverToExpand) }
        .onChange(of: targeted) { active in
            if active { state.collapseTask?.cancel(); state.expanded = true }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
            state.expanded = true
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in store.addFiles([url]) }
                }
            }
            return !providers.isEmpty
        }
    }
    private func horizontalWidget(_ module: ModuleID) -> some View {
        GeometryReader { proxy in
            WidgetCard(style: layout.widgetStyle(for: module), availableHeight: proxy.size.height) {
                BuiltinOrIntegrationWidget(module: module, store: store)
            }
        }
    }
    @ViewBuilder private func widgetCards(horizontal: Bool) -> some View {
        ForEach(layout.normalizedOrder().filter { layout.enabled.contains($0) }) { module in
            if horizontal {
                horizontalWidget(module).frame(width: max(240, state.dashboardWidth - 64))
            } else {
                WidgetCard(style: layout.widgetStyle(for: module)) {
                    BuiltinOrIntegrationWidget(module: module, store: store)
                }
            }
        }
    }

}

struct BuiltinOrIntegrationWidget: View {
    let module: ModuleID
    @ObservedObject var store: AppStore
    @Environment(\.widgetStyle) private var style
    @ViewBuilder var body: some View {
        switch module {
        case .clock: WidgetClock(style: style)
        case .timer: timer
        case .shelf: shelf
        default: ModuleRegistry().view(for: module, store: store)
        }
    }
    private var timer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if style.showTitle { Label("Focus", systemImage: "timer").font(style.font()) }
                Spacer()
                if let deadline = store.deadline {
                    Text(deadline, style: .timer).monospacedDigit()
                } else if store.pausedSeconds > 0 {
                    Text("Paused · \(Int(store.pausedSeconds))s").font(style.font(scale: 0.85))
                } else if store.finished { Text("Session complete").foregroundStyle(.green) }
                else { Text("Make room for deep work").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            }
            HStack {
                if store.deadline != nil || store.pausedSeconds > 0 {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("Reset") { store.resetTimer() }
                } else {
                    ForEach([5, 15, 25], id: \.self) { minutes in
                        Button("\(minutes) min") { store.startTimer(minutes: minutes) }
                    }
                }
            }.buttonStyle(.bordered)
        }
    }
    private var shelf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if style.showTitle { Label("File shelf", systemImage: "tray").font(style.font()) }
                Spacer()
                Button { store.chooseFiles() } label: { Image(systemName: "plus") }.accessibilityLabel("Add files")
            }
            if store.files.isEmpty {
                Text("Drop files here. Originals stay untouched.").font(style.font(scale: 0.85)).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ForEach(store.files, id: \.self) { url in
                HStack {
                    ShelfFileInfo(url: url)
                    Spacer()
                    Button { store.toggleFilePin(url) } label: { Image(systemName: store.pinnedFiles.contains(url) ? "pin.fill" : "pin") }.help("Keep this file on the shelf")
                    Button { store.shelfPreview.show(url) } label: { Image(systemName: "eye") }.help("Quick Look")
                    Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }.help("Reveal in Finder")
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }.help("Open file")
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    Button { store.removeFile(url) } label: { Image(systemName: "xmark") }.help("Remove reference from shelf")
                }.onDrag { NSItemProvider(object: url as NSURL) }
            }
        }
    }
}

struct ShelfFileInfo: View {
    let url: URL
    @Environment(\.widgetStyle) private var style
    @State private var icon: NSImage?
    @State private var detail = ""
    var body: some View {
        HStack {
            if let icon { Image(nsImage: icon).resizable().frame(width: 24, height: 24) }
            VStack(alignment: .leading) {
                Text(url.lastPathComponent).font(style.font(scale: 0.85)).lineLimit(1)
                Text(detail).font(style.font(scale: 0.75)).foregroundStyle(.secondary).lineLimit(1)
            }
        }.onAppear {
            guard icon == nil else { return }
            icon = NSWorkspace.shared.icon(forFile: url.path)
            detail = fileDetail(url)
        }
    }
    private func fileDetail(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { return "Original unavailable" }
        if values.isDirectory == true { return "Folder" }
        return url.pathExtension.uppercased() + " · " + ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
    }
}

private struct ContextNotchInterface<Dashboard: View>: View {
    @ObservedObject var media: MediaService
    let options: ContextMusicOptions
    let visualizer: VisualizerOptions
    @ViewBuilder var dashboard: Dashboard
    @State private var showDashboard = false
    var body: some View {
        VStack(spacing: 8) {
            if options.enabled && media.isPlaying && !showDashboard {
                ContextMusicView(media: media, options: options, visualizer: visualizer)
                Button("Show widgets") { showDashboard = true }.font(.caption)
            } else {
                dashboard
                if options.enabled && media.isPlaying {
                    Button("Show music") { showDashboard = false }.font(.caption)
                }
            }
        }
        .onChange(of: media.isPlaying) { playing in if !playing { showDashboard = false } }
    }
}

private struct ContextMusicView: View {
    @ObservedObject var media: MediaService
    let options: ContextMusicOptions
    let visualizer: VisualizerOptions
    @State private var artwork: NSImage?
    private var artworkKey: String { "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(options.showArtwork)" }
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    if options.showArtwork {
                        Group {
                            if let artwork { Image(nsImage: artwork).resizable().scaledToFit() }
                            else { Image(systemName: "music.note").resizable().scaledToFit().padding(16) }
                        }.frame(width: min(options.artworkSize, max(32, proxy.size.height * 0.35)), height: min(options.artworkSize, max(32, proxy.size.height * 0.35)))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    if options.showTitle { Text(media.title).font(.system(size: options.fontSize, weight: .semibold)).multilineTextAlignment(.center) }
                    if options.showArtist { Text(media.artist).font(.system(size: max(10, options.fontSize * 0.7))).opacity(0.75) }
                    if options.showControls {
                        HStack(spacing: 28) {
                            control("backward.end.fill", action: "previous track", label: "Previous track")
                            control(media.isPlaying ? "pause.fill" : "play.fill", action: "playpause", label: "Play or pause")
                            control("forward.end.fill", action: "next track", label: "Next track")
                        }.font(.title2).disabled(media.busy)
                    }
                    if options.showVisualizer {
                        PlaybackVisualizer(kind: .bars, playing: media.isPlaying, enabled: true, options: visualizer, palette: media.artworkColors, fallback: options.textColor.color)
                            .frame(height: 32)
                    }
                    if let error = media.error { Text(error).font(.caption).foregroundStyle(.orange) }
                }.padding(16).frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }.foregroundStyle(options.textColor.color)
                .background {
                    if options.background == .glass { RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial).opacity(options.backgroundOpacity) }
                    else if options.background == .gradient {
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(options.backgroundOpacity)
                    } else { Color.black.opacity(options.backgroundOpacity) }
                }.clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .task(id: artworkKey) {
            artwork = nil
            guard options.showArtwork else { return }
            let result = await ContextMusicArtworkReader.artwork(app: media.connectedApp, key: artworkKey)
            guard !Task.isCancelled else { return }; artwork = result
        }
    }
    private func control(_ symbol: String, action: String, label: String) -> some View {
        Button { if let app = media.connectedApp { media.perform(action, app: app) } } label: { Image(systemName: symbol) }.accessibilityLabel(label)
    }
}

private enum ContextMusicArtworkReader {
    private static let queue = DispatchQueue(label: "Halo.ContextMusicArtwork", qos: .utility)
    private static let lock = NSLock()
    private static var cache: [String: Data] = [:]

    static func artwork(app: String?, key: String) async -> NSImage? {
        guard let app else { return nil }
        lock.lock(); let cached = cache[key]; lock.unlock()
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
                continuation.resume(returning: (
                    app == "com.apple.Music" ? result?.atIndex(2)?.data : nil,
                    app == "com.spotify.client" ? result?.atIndex(2)?.stringValue : nil
                ))
            }
        }

        var data = payload.0
        if data == nil, let urlString = payload.1, let url = URL(string: urlString), url.scheme == "https" {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
            request.setValue("Halo/1.0", forHTTPHeaderField: "User-Agent")
            if let (downloaded, response) = try? await URLSession.shared.data(for: request),
               downloaded.count <= 5_000_000,
               (response as? HTTPURLResponse)?.statusCode == 200 {
                data = downloaded
            }
        }

        guard let data, data.count <= 5_000_000 else { return nil }
        lock.lock(); cache[key] = data; lock.unlock()
        return NSImage(data: data)
    }
}
