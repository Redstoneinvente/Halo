import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SurfaceViewportView: View {
    @ObservedObject var viewport: SurfaceViewport
    let content: SurfaceView
    var body: some View {
        content.frame(width: viewport.size.width, height: viewport.size.height, alignment: .top).clipped()
    }
}

struct SurfaceView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var state: SurfaceState
    @ObservedObject var workspace: WorkspaceStore
    private var theme: Theme { state.theme }
    private var layout: WorkspaceLayout { state.layoutOverride ?? workspace.effectiveLayout }
    private var contextOptions: ContextMusicOptions { layout.contextMusic ?? ContextMusicOptions() }
    private var contextMusicActive: Bool { contextOptions.enabled && workspace.media.isPlaying }
    private var closedBackgroundOptions: ClosedNotchOptions {
        var value = layout.closedNotch ?? ClosedNotchOptions()
        if var artwork = value.artworkOptions, artwork.usesBackgroundArtwork, artwork.mode != .background {
            artwork.mode = .background
            value.artworkOptions = artwork
        }
        return value
    }
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
                Image(systemName: state.pinned ? "pin.fill" : "chevron.up").font(.system(size: 9, weight: .bold))
              } }
            }
            .padding(.horizontal, !state.expanded ? 0 : max(16, layout.appearance.surface.shoulder + 8))
            .frame(height: state.expanded ? max(40, state.compactHeight) : state.compactHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                if state.expanded && state.pinned { return }
                state.expanded.toggle()
            }
            .accessibilityLabel("Toggle Halo dashboard")
            .accessibilityAddTraits(.isButton)
            if state.expanded {
                if contextMusicActive {
                    ContextMusicView(media: workspace.media, options: contextOptions,
                                     visualizer: layout.closedNotch?.visualizer ?? VisualizerOptions(), surfaceState: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
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
                        HStack {
                            Spacer()
                            Button("Settings") { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) }
                        }
                    }.padding(.horizontal, max(20, layout.appearance.surface.shoulder + 12)).padding(.vertical, 20).frame(width: state.dashboardWidth).transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                SurfaceBackground(appearance: layout.appearance, theme: theme, expanded: state.expanded, system: workspace.system)
                if !state.expanded || layout.closedNotch?.applyBackgroundWhenOpened == true {
                    AlbumNotchBackground(options: closedBackgroundOptions, media: workspace.media, system: workspace.system)
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
        .onChange(of: contextMusicActive) { active in
            if !active { state.contextPreferredSize = nil }
        }
        .onChange(of: state.expanded) { expanded in
            if !expanded { state.contextPreferredSize = nil }
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
                if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit() }
                else if store.pausedSeconds > 0 { Text("Paused · \(Int(store.pausedSeconds))s").font(style.font(scale: 0.85)) }
                else if store.finished { Text("Session complete").foregroundStyle(.green) }
                else { Text("Make room for deep work").font(style.font(scale: 0.85)).foregroundStyle(.secondary) }
            }
            HStack {
                if store.deadline != nil || store.pausedSeconds > 0 {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }
                    Button("Reset") { store.resetTimer() }
                } else {
                    ForEach([5, 15, 25], id: \.self) { minutes in Button("\(minutes) min") { store.startTimer(minutes: minutes) } }
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
            if store.files.isEmpty { Text("Drop files here. Originals stay untouched.").font(style.font(scale: 0.85)).foregroundStyle(.secondary).padding(.vertical, 8) }
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

private struct ContextMusicView: View {
    @ObservedObject var media: MediaService
    let options: ContextMusicOptions
    let visualizer: VisualizerOptions
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextVisualizerFullWidth") private var visualizerFullWidth = false
    @State private var artwork: NSImage?
    @State private var playbackPosition = 0.0
    @State private var playbackDuration = 0.0
    @State private var scrubValue = 0.0
    @State private var isScrubbing = false
    @State private var lyrics = ""
    @State private var lyricsLoading = false
    @State private var vinylRotation = 0.0
    @State private var vinylLastTick = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var safeInset: Double { max(18, options.resolvedSpacing * 1.25) }
    private var artworkKey: String {
        "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(options.resolvedForegroundArtwork.rawValue)|\(options.usesArtworkBackground)"
    }
    private var playbackKey: String { "\(media.connectedApp ?? "")|\(media.title)|\(media.artist)|\(media.isPlaying)" }
    private var lyricKey: String { playbackKey + "|lyrics|\(options.showsLyrics)|\(options.usesOnlineLyrics)" }
    private var sizingKey: String {
        [options.resolvedLayoutMode.rawValue, options.resolvedForegroundArtwork.rawValue,
         String(options.artworkSize), String(options.showTitle), String(options.showArtist), String(options.showControls),
         String(options.showVisualizer), String(options.showsLyrics), options.resolvedLyricDisplay.rawValue,
         String(options.resolvedLyricFontSize), options.resolvedVisualizerStyle.rawValue,
         String(options.resolvedSpacing), String(options.resolvedControlSize), String(visualizerFullWidth)].joined(separator: "|")
    }
    private var songColors: [Color] { media.artworkColors.map(\.color) }
    private var primarySongColor: Color { songColors.first ?? options.textColor.color }
    private var effectiveTextColor: Color { options.usesSongTextColors && !songColors.isEmpty ? primarySongColor : options.textColor.color }
    private var effectiveControlColor: Color { options.usesSongControlColors && !songColors.isEmpty ? primarySongColor : effectiveTextColor }
    private var horizontalAlignment: HorizontalAlignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    private var frameAlignment: Alignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                contextBackground(size: proxy.size)
                Group {
                    switch options.resolvedLayoutMode {
                    case .hero: heroLayout(proxy: proxy)
                    case .split: splitLayout(proxy: proxy)
                    case .compact: compactLayout(proxy: proxy)
                    case .minimal: minimalLayout(proxy: proxy)
                    }
                }
                .padding(.horizontal, safeInset)
                .padding(.top, max(16, safeInset * 0.75))
                .padding(.bottom, max(10, safeInset * 0.55))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: options.resolvedCornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Button { surfaceState.pinned.toggle() } label: {
                        Image(systemName: surfaceState.pinned ? "pin.fill" : "pin").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(effectiveControlColor)
                    .help(surfaceState.pinned ? "Allow Halo to close" : "Keep Halo open")
                    .accessibilityLabel(surfaceState.pinned ? "Unpin Halo" : "Keep Halo open")
                    Button { NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil) } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(effectiveControlColor)
                    .help("Open Halo settings")
                }
                .padding(.top, max(12, safeInset * 0.65))
                .padding(.trailing, safeInset)
            }
            .foregroundStyle(effectiveTextColor)
        }
        .task(id: artworkKey) {
            artwork = nil
            let needsArtwork = options.resolvedForegroundArtwork != .none || options.usesArtworkBackground
            guard needsArtwork else { return }
            let result = await ContextMusicArtworkReader.artwork(app: media.connectedApp, key: artworkKey)
            guard !Task.isCancelled else { return }
            artwork = result
        }
        .task(id: playbackKey) { await playbackLoop() }
        .task(id: lyricKey) { await loadLyrics() }
        .task(id: sizingKey) { publishPreferredSize() }
        .onChange(of: playbackDuration) { _ in publishPreferredSize() }
        .onDisappear { surfaceState.contextPreferredSize = nil }
    }

    private func publishPreferredSize() {
        let next = preferredSurfaceSize
        if let current = surfaceState.contextPreferredSize,
           abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
        surfaceState.contextPreferredSize = next
    }

    private var preferredSurfaceSize: CGSize {
        let spacing = options.resolvedSpacing
        let metadataHeight = (options.showTitle ? options.fontSize * 1.35 : 0) + (options.showArtist ? max(12, options.fontSize * 0.72) : 0)
        let lyricsHeight = options.showsLyrics ? options.resolvedLyricFontSize * (options.resolvedLyricDisplay == .word ? 1.25 : 2.05) : 0
        let scrubHeight = playbackDuration > 0.5 ? 30.0 : 0
        let controlsHeight = options.showControls ? options.resolvedControlSize * 1.35 : 0
        let visualizerHeight = options.showVisualizer ? max(18, min(64, visualizer.height)) : 0
        let artworkSize = options.resolvedForegroundArtwork == .none ? 0 : options.artworkSize
        let activeBlocks = [metadataHeight, lyricsHeight, scrubHeight, controlsHeight, visualizerHeight].filter { $0 > 0 }.count
        let gaps = Double(max(0, activeBlocks - 1)) * spacing
        let textColumn = metadataHeight + lyricsHeight + scrubHeight + controlsHeight + visualizerHeight + gaps
        let innerHeight: Double
        let width: Double
        switch options.resolvedLayoutMode {
        case .hero:
            innerHeight = artworkSize + textColumn + (artworkSize > 0 && textColumn > 0 ? spacing : 0)
            width = max(360, min(640, max(420, artworkSize * 2.4)))
        case .split:
            innerHeight = max(artworkSize, textColumn)
            width = max(430, min(700, 310 + artworkSize))
        case .compact:
            innerHeight = max(artworkSize, textColumn)
            width = max(440, min(720, 340 + artworkSize))
        case .minimal:
            innerHeight = artworkSize + textColumn + (artworkSize > 0 && textColumn > 0 ? spacing * 0.7 : 0)
            width = max(340, min(580, max(380, artworkSize * 2.15)))
        }
        // WindowManager already contributes the panel-level safety budget and top strip.
        // Keep this estimate close to the content itself so the player does not accumulate dead space.
        return CGSize(width: width, height: min(700, max(150, innerHeight + 18)))
    }

    @ViewBuilder private func contextBackground(size: CGSize) -> some View {
        ZStack {
            switch options.background {
            case .glass:
                Rectangle().fill(.ultraThinMaterial).opacity(max(0.12, options.backgroundOpacity))
            case .gradient:
                LinearGradient(colors: songColors.isEmpty ? [.blue, .purple] : Array(songColors.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(options.backgroundOpacity)
            default:
                Color.black.opacity(options.backgroundOpacity)
            }
            if options.usesSongBackgroundColors, !songColors.isEmpty {
                LinearGradient(colors: Array(songColors.prefix(2)), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(min(0.78, max(0.16, options.backgroundOpacity)))
                    .blendMode(.plusLighter)
            }
            if options.usesArtworkBackground, let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .blur(radius: options.resolvedArtworkBackgroundBlur)
                    .overlay(Color.black.opacity(options.resolvedArtworkBackgroundDim))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func heroLayout(proxy: GeometryProxy) -> some View {
        VStack(alignment: horizontalAlignment, spacing: options.resolvedSpacing) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(48, proxy.size.height * 0.34))) }
            metadata
            lyricsView
            scrubber
            controls
            visualizerView
            errorView
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func splitLayout(proxy: GeometryProxy) -> some View {
        HStack(spacing: options.resolvedSpacing * 1.4) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(52, proxy.size.height * 0.50))) }
            VStack(alignment: horizontalAlignment, spacing: options.resolvedSpacing) {
                metadata
                lyricsView
                scrubber
                controls
                visualizerView
                errorView
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func compactLayout(proxy: GeometryProxy) -> some View {
        HStack(spacing: options.resolvedSpacing) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(42, proxy.size.height * 0.24))) }
            VStack(alignment: .leading, spacing: max(3, options.resolvedSpacing * 0.45)) {
                metadata
                lyricsView
                scrubber
                visualizerView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            controls
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func minimalLayout(proxy: GeometryProxy) -> some View {
        VStack(alignment: horizontalAlignment, spacing: max(4, options.resolvedSpacing * 0.6)) {
            if options.resolvedForegroundArtwork != .none { foregroundArtwork(size: min(options.artworkSize, max(36, proxy.size.height * 0.20))) }
            metadata
            lyricsView
            scrubber
            controls
            visualizerView
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func foregroundArtwork(size: Double) -> some View {
        Group {
            switch options.resolvedForegroundArtwork {
            case .none:
                EmptyView()
            case .cover:
                Group {
                    if let artwork { Image(nsImage: artwork).resizable().scaledToFill() }
                    else { artworkPlaceholder }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: min(options.resolvedCornerRadius, size * 0.18), style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: size * 0.055, y: size * 0.025)
            case .vinyl:
                vinylArtwork(size: size)
            }
        }
        .id(options.resolvedForegroundArtwork.rawValue)
    }

    @ViewBuilder
    private func vinylArtwork(size: Double) -> some View {
        if reduceMotion {
            vinylDisc(size: size)
        } else {
            vinylDisc(size: size)
                .rotationEffect(.degrees(vinylRotation))
                .onReceive(
                    Timer.publish(
                        every: 1.0 / 60.0,
                        on: .main,
                        in: .common
                    ).autoconnect()
                ) { now in
                    defer { vinylLastTick = now }

                    guard media.isPlaying else { return }

                    let delta = min(
                        0.1,
                        max(0, now.timeIntervalSince(vinylLastTick))
                    )

                    let degreesPerSecond =
                        options.resolvedVinylRPM * 360.0 / 60.0

                    vinylRotation += degreesPerSecond * delta

                    if vinylRotation >= 360 {
                        vinylRotation.formTruncatingRemainder(
                            dividingBy: 360
                        )
                    }
                }
                .onAppear {
                    vinylLastTick = Date()
                }
                .onChange(of: media.isPlaying) { _ in
                    vinylLastTick = Date()
                }
        }
    }

    private func vinylDisc(size: Double) -> some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.black.opacity(0.84), .black, .black.opacity(0.92)], center: .center, startRadius: size * 0.05, endRadius: size * 0.5))
            ForEach(1..<8, id: \.self) { ring in
                Circle().stroke(Color.white.opacity(ring.isMultiple(of: 2) ? 0.10 : 0.045), lineWidth: max(0.45, size * 0.005)).padding(size * (0.055 + Double(ring) * 0.038))
            }
            Circle().trim(from: 0.08, to: 0.31)
                .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: max(0.7, size * 0.009), lineCap: .round))
                .padding(size * 0.055).rotationEffect(.degrees(-28))
            Group {
                if let artwork { Image(nsImage: artwork).resizable().scaledToFill() }
                else { Color.white.opacity(0.14).overlay(Image(systemName: "music.note").opacity(0.65)) }
            }
            .frame(width: size * 0.46, height: size * 0.46).clipShape(Circle())
            Circle().stroke(Color.white.opacity(0.32), lineWidth: max(0.8, size * 0.007)).frame(width: size * 0.49, height: size * 0.49)
            Circle().fill(Color.black).frame(width: max(7, size * 0.105), height: max(7, size * 0.105))
            Circle().fill(Color.white.opacity(0.72)).frame(width: max(1.5, size * 0.024), height: max(1.5, size * 0.024))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.36), radius: size * 0.06, y: size * 0.025)
        .accessibilityLabel("Spinning vinyl record")
    }

    private var artworkPlaceholder: some View {
        ZStack { Color.white.opacity(0.07); Image(systemName: "music.note").font(.system(size: 28, weight: .medium)).opacity(0.75) }
    }

    private var metadata: some View {
        VStack(alignment: horizontalAlignment, spacing: max(2, options.resolvedSpacing * 0.28)) {
            if options.showTitle {
                Text(media.title).font(.system(size: options.fontSize, weight: .semibold, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
            }
            if options.showArtist {
                Text(media.artist.isEmpty ? "Unknown artist" : media.artist).font(.system(size: max(10, options.fontSize * 0.68), weight: .medium)).opacity(0.72).lineLimit(1)
            }
        }
        .foregroundStyle(effectiveTextColor)
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder private var lyricsView: some View {
        if options.showsLyrics {
            if lyricsLoading && lyrics.isEmpty {
                Label("Loading lyrics…", systemImage: "text.quote").font(.system(size: options.resolvedLyricFontSize)).opacity(0.72)
            } else if lyrics.isEmpty {
                Text("Synced lyrics unavailable").font(.system(size: options.resolvedLyricFontSize)).opacity(0.55)
            } else {
                TimelineView(.animation(minimumInterval: 0.06, paused: !media.isPlaying)) { _ in
                    let position = (isScrubbing ? scrubValue : playbackPosition) + options.resolvedLyricSyncOffset
                    let lines = ContextLyricTimeline.parse(lyrics)
                    if let frame = ContextLyricTimeline.frame(lines: lines, position: max(0, position), duration: playbackDuration) {
                        contextLyric(frame)
                    }
                }
            }
        }
    }

    @ViewBuilder private func contextLyric(_ frame: ContextLyricFrame) -> some View {
        switch options.resolvedLyricDisplay {
        case .line:
            VStack(alignment: horizontalAlignment, spacing: 3) {
                Text(frame.current.text).font(.system(size: options.resolvedLyricFontSize, weight: .semibold, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
                if let next = frame.next { Text(next.text).font(.system(size: max(10, options.resolvedLyricFontSize * 0.74))).opacity(0.35).lineLimit(1) }
            }
        case .word:
            let words = frame.current.text.split(whereSeparator: \.isWhitespace).map(String.init)
            Text(words.indices.contains(frame.wordIndex) ? words[frame.wordIndex] : frame.current.text)
                .font(.system(size: options.resolvedLyricFontSize, weight: .bold, design: .rounded)).lineLimit(1)
        case .focus:
            focusedLyricLine(frame.current.text, activeWord: frame.wordIndex)
        }
    }

    private func focusedLyricLine(_ text: String, activeWord: Int) -> some View {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var result = Text("")
        for (index, word) in words.enumerated() {
            result = result + Text((index == 0 ? "" : " ") + word)
                .fontWeight(index == activeWord ? .bold : .regular)
                .foregroundColor(index == activeWord ? primarySongColor : effectiveTextColor.opacity(0.5))
        }
        return result.font(.system(size: options.resolvedLyricFontSize, design: .rounded)).lineLimit(2).multilineTextAlignment(textAlignment)
    }

    @ViewBuilder private var scrubber: some View {
        if playbackDuration > 0.5 {
            VStack(spacing: 3) {
                Slider(value: Binding(
                    get: { isScrubbing ? scrubValue : min(playbackDuration, max(0, playbackPosition)) },
                    set: { newValue in
                        if !isScrubbing { scrubValue = playbackPosition }
                        isScrubbing = true
                        scrubValue = min(playbackDuration, max(0, newValue))
                    }
                ), in: 0...max(1, playbackDuration), onEditingChanged: { editing in
                    if editing {
                        scrubValue = min(playbackDuration, max(0, playbackPosition)); isScrubbing = true
                    } else {
                        let target = min(playbackDuration, max(0, scrubValue)); playbackPosition = target; isScrubbing = false
                        Task {
                            let result = await ContextMusicArtworkReader.seek(app: media.connectedApp, position: target)
                            guard !Task.isCancelled, let result else { return }
                            playbackPosition = result.position; playbackDuration = result.duration
                        }
                    }
                }).controlSize(.small).tint(effectiveControlColor)
                HStack {
                    Text(formatTime(isScrubbing ? scrubValue : playbackPosition)); Spacer()
                    Text("−" + formatTime(max(0, playbackDuration - (isScrubbing ? scrubValue : playbackPosition))))
                }.font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.62)
            }.frame(maxWidth: 440)
        }
    }

    @ViewBuilder private var controls: some View {
        if options.showControls {
            HStack(spacing: options.resolvedControlSize * 1.05) {
                control("backward.end.fill", action: "previous track", label: "Previous track")
                control(media.isPlaying ? "pause.fill" : "play.fill", action: "playpause", label: "Play or pause")
                control("forward.end.fill", action: "next track", label: "Next track")
            }
            .font(.system(size: options.resolvedControlSize, weight: .semibold))
            .foregroundStyle(effectiveControlColor)
            .disabled(media.busy)
        }
    }

    @ViewBuilder private var visualizerView: some View {
        if options.showVisualizer {
            let configured = contextVisualizerOptions
            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.isPlaying, enabled: true,
                               options: configured, palette: media.artworkColors, fallback: effectiveControlColor)
                .frame(maxWidth: visualizerFullWidth ? .infinity : CGFloat(configured.width), alignment: .center)
                .frame(height: max(18, min(64, configured.height)))
                .contentShape(Rectangle())
                .contextMenu {
                    Toggle("Fill interface width", isOn: $visualizerFullWidth)
                }
                .overlay(alignment: .topTrailing) {
                    Button { visualizerFullWidth.toggle() } label: {
                        Image(systemName: visualizerFullWidth ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(effectiveControlColor.opacity(0.72))
                    .help(visualizerFullWidth ? "Use visualizer's normal width" : "Fill the interface width")
                    .padding(.trailing, 2)
                }
        }
    }

    private var contextVisualizerOptions: VisualizerOptions {
        var value = visualizer
        value.dynamicColors = options.usesSongVisualizerColors
        value.width = visualizerFullWidth ? max(120, surfaceState.dashboardWidth - safeInset * 2) : max(value.width, 120)
        return value
    }

    @ViewBuilder private var errorView: some View {
        if let error = media.error { Text(error).font(.caption).foregroundStyle(.orange) }
    }

    private var textAlignment: TextAlignment {
        switch options.resolvedContentAlignment { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }

    private func control(_ symbol: String, action: String, label: String) -> some View {
        Button { if let app = media.connectedApp { media.perform(action, app: app) } } label: { Image(systemName: symbol) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }

    private func playbackLoop() async {
        playbackPosition = 0; playbackDuration = 0
        while !Task.isCancelled {
            if !isScrubbing, let sample = await ContextMusicArtworkReader.playback(app: media.connectedApp) {
                playbackPosition = sample.position; playbackDuration = sample.duration
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func loadLyrics() async {
        lyrics = ""; lyricsLoading = false
        guard options.showsLyrics else { return }
        lyricsLoading = true
        let duration = playbackDuration > 0 ? playbackDuration : (await ContextMusicArtworkReader.playback(app: media.connectedApp))?.duration
        lyrics = await ContextMusicArtworkReader.lyrics(app: media.connectedApp, key: lyricKey, title: media.title,
                                                        artist: media.artist, duration: duration,
                                                        onlineFallback: options.usesOnlineLyrics)
        lyricsLoading = false
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down)); let hours = total / 3600; let minutes = (total % 3600) / 60; let secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}

private struct ContextLyricLine: Identifiable {
    let id: Int
    let time: Double
    let text: String
}
private struct ContextLyricFrame {
    let current: ContextLyricLine
    let next: ContextLyricLine?
    let wordIndex: Int
}
private enum ContextLyricTimeline {
    static func parse(_ value: String) -> [ContextLyricLine] {
        let rawLines = value.split(whereSeparator: \.isNewline).map(String.init)
        let offset = rawLines.compactMap { raw -> Double? in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.lowercased().hasPrefix("[offset:"), let close = line.firstIndex(of: "]") else { return nil }
            let start = line.index(line.startIndex, offsetBy: 8)
            return Double(line[start..<close]).map { $0 / 1000 }
        }.first ?? 0
        var lines: [ContextLyricLine] = []
        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.lowercased().hasPrefix("[offset:"), line.first == "[", let close = line.firstIndex(of: "]") else { continue }
            let stamp = String(line[line.index(after: line.startIndex)..<close])
            let text = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
            let parts = stamp.split(separator: ":")
            guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]), !text.isEmpty else { continue }
            lines.append(ContextLyricLine(id: lines.count, time: max(0, minutes * 60 + seconds + offset), text: text))
        }
        return lines.sorted { $0.time < $1.time }.enumerated().map { ContextLyricLine(id: $0.offset, time: $0.element.time, text: $0.element.text) }
    }
    static func frame(lines: [ContextLyricLine], position: Double, duration: Double) -> ContextLyricFrame? {
        guard !lines.isEmpty else { return nil }
        let index = lines.lastIndex(where: { $0.time <= position + 0.035 }) ?? 0
        let current = lines[index]; let next = index + 1 < lines.count ? lines[index + 1] : nil
        let end = max(current.time + 0.35, next?.time ?? (duration > current.time ? duration : current.time + 4))
        let words = current.text.split(whereSeparator: \.isWhitespace)
        let progress = min(0.999, max(0, (position - current.time) / max(0.35, end - current.time)))
        return ContextLyricFrame(current: current, next: next, wordIndex: words.isEmpty ? 0 : min(words.count - 1, Int(progress * Double(words.count))))
    }
}

private enum ContextMusicArtworkReader {
    struct PlaybackSample { let position: Double; let duration: Double }
    private struct LRCLyrics: Decodable { let duration: Double?; let plainLyrics: String?; let syncedLyrics: String? }
    private static let queue = DispatchQueue(label: "Halo.ContextMusicArtwork", qos: .utility)
    private static let lock = NSLock()
    private static var cache: [String: Data] = [:]
    private static var lyricsCache: [String: String] = [:]

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
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                if failure != nil { continuation.resume(returning: (nil, nil)); return }
                continuation.resume(returning: (app == "com.apple.Music" ? result?.atIndex(2)?.data : nil,
                                                app == "com.spotify.client" ? result?.atIndex(2)?.stringValue : nil))
            }
        }
        var data = payload.0
        if data == nil, let urlString = payload.1, let url = URL(string: urlString), url.scheme == "https" {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8); request.setValue("Halo/1.0", forHTTPHeaderField: "User-Agent")
            if let (downloaded, response) = try? await URLSession.shared.data(for: request), downloaded.count <= 5_000_000,
               (response as? HTTPURLResponse)?.statusCode == 200 { data = downloaded }
        }
        guard let data, data.count <= 5_000_000 else { return nil }
        lock.lock(); cache[key] = data; lock.unlock(); return NSImage(data: data)
    }

    static func playback(app: String?) async -> PlaybackSample? {
        guard let app, ["com.apple.Music", "com.spotify.client"].contains(app) else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async {
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
                guard failure == nil, let position = result?.atIndex(1)?.doubleValue, let duration = result?.atIndex(2)?.doubleValue,
                      position >= 0, duration > 0 else { continuation.resume(returning: nil); return }
                continuation.resume(returning: PlaybackSample(position: min(duration, position), duration: duration))
            }
        }
    }

    static func seek(app: String?, position: Double) async -> PlaybackSample? {
        guard let app, ["com.apple.Music", "com.spotify.client"].contains(app), position.isFinite else { return nil }
        let requested = max(0, position)
        return await withCheckedContinuation { continuation in
            queue.async {
                let source = """
                if application id "\(app)" is not running then return {-1, -1}
                with timeout of 3 seconds
                    tell application id "\(app)"
                        try
                            set player position to \(requested)
                            return {(player position as real), (duration of current track as real)}
                        on error
                            return {-1, -1}
                        end try
                    end tell
                end timeout
                """
                var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
                guard failure == nil, let actual = result?.atIndex(1)?.doubleValue, let duration = result?.atIndex(2)?.doubleValue,
                      actual >= 0, duration > 0 else { continuation.resume(returning: nil); return }
                continuation.resume(returning: PlaybackSample(position: min(duration, actual), duration: duration))
            }
        }
    }

    static func lyrics(app: String?, key: String, title: String, artist: String, duration: Double?, onlineFallback: Bool) async -> String {
        let cacheKey = key + "|duration:" + (duration.map { String(Int($0.rounded())) } ?? "unknown")
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
            var failure: NSDictionary?; let result = NSAppleScript(source: source)?.executeAndReturnError(&failure)
            continuation.resume(returning: failure == nil ? (result?.stringValue ?? "") : "")
        } }
    }

    private static func onlineLyrics(title: String, artist: String, duration: Double?) async -> String {
        guard !title.isEmpty, !artist.isEmpty else { return "" }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if let duration, duration >= 1, duration <= 3600 { components.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
        guard let url = components.url else { return "" }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.setValue("Halo/1.0 (https://github.com/Redstoneinvente/Halo)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200,
              data.count <= 1_000_000, let result = try? JSONDecoder().decode(LRCLyrics.self, from: data) else { return "" }
        if let requested = duration, let returned = result.duration, abs(requested - returned) > 2.5 { return "" }
        return result.syncedLyrics ?? ""
    }
}
