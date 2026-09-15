import SwiftUI
import AppKit
import AVKit
import ImageIO
import EventKit

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
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    let id: ModuleID
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    private var options: WidgetContentOptions { style.resolvedContent }
    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }

    var body: some View {
        Group {
            if id == .pet || footprint == .glance {
                content
            } else {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: footprint == .glance ? .center : options.alignment.alignment)
        .animation(.easeInOut(duration: 0.18), value: footprint)
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
        case .media:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .media, store: store, workspace: workspace) }
            else { MediaModuleView(service: workspace.media, app: workspace.settings.mediaApp) }
        case .audio:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .audio, store: store, workspace: workspace) }
            else { AudioModuleView(service: workspace.audio) }
        case .calendar:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceCalendarView(service: workspace.calendar) }
            else { CalendarModuleView(service: workspace.calendar) }
        case .clipboard:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .clipboard, store: store, workspace: workspace) }
            else { ClipboardModuleView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled) }
        case .system:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .system, store: store, workspace: workspace) }
            else { SystemModuleView(service: workspace.system) }
        case .launcher:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .launcher, store: store, workspace: workspace) }
            else { LauncherModuleView(store: store, workspace: workspace) }
        case .activities:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .activities, store: store, workspace: workspace) }
            else { activitiesContent }
        case .notes:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .notes, store: store, workspace: workspace) }
            else { notesContent }
        case .capture:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .capture, store: store, workspace: workspace) }
            else { CaptureModuleView(service: workspace.capture, store: store) }
        case .stopwatch:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .stopwatch, store: store, workspace: workspace) }
            else { stopwatchContent }
        case .pet:
            HaloPixelPetWidget(store: store, workspace: workspace)
        default: EmptyView()
        }
    }

    @ViewBuilder private var activitiesContent: some View {
        switch footprint {
        case .glance:
            VStack(spacing: 4) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
                Text("\(workspace.activities.count)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(workspace.activities.count == 1 ? "activity" : "activities")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .horizontal:
            HStack(spacing: 8) {
                Label("\(workspace.activities.count)", systemImage: "waveform.path")
                    .font(.system(size: 15, weight: .semibold))
                if let activity = workspace.activities.first {
                    Divider().opacity(0.35)
                    Text(activity.title).lineLimit(1)
                } else {
                    Text("No live activity").foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        case .vertical:
            VStack(alignment: .leading, spacing: 7) {
                Label("\(workspace.activities.count) live", systemImage: "waveform.path")
                    .font(.system(size: 13, weight: .semibold))
                ForEach(Array(workspace.activities.prefix(2))) { activity in
                    HStack(spacing: 6) {
                        Circle().fill(style.accentColor.color).frame(width: 5, height: 5)
                        Text(activity.title).lineLimit(1)
                    }
                }
                if workspace.activities.isEmpty { Text("Nothing active").foregroundStyle(.secondary) }
            }
        case .standard, .expanded, .none:
            WidgetElement(key: "summary", defaultPriority: .high) {
                Label("\(workspace.activities.count) live activit\(workspace.activities.count == 1 ? "y" : "ies")", systemImage: "waveform.path")
            }
            if workspace.activities.isEmpty, options.showStatus, presentation != .compact {
                WidgetElement(key: "status") {
                    Text("Timer completions and live progress appear here.").foregroundStyle(.secondary)
                }
            }
            if presentation != .compact {
                WidgetElement(key: "items") {
                    VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                        ForEach(Array(workspace.activities.prefix(presentation == .expanded ? options.maxItems : min(3, options.maxItems)))) { activity in
                            HStack(spacing: options.spacing) {
                                VStack(alignment: options.alignment.horizontal, spacing: max(2, options.spacing * 0.35)) {
                                    Text(activity.title)
                                    if presentation == .expanded && options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }
                                    if options.showProgress, let progress = activity.progress { ProgressView(value: progress) }
                                }
                                Spacer()
                                if options.showControls { Button { workspace.activities.removeAll { $0.id == activity.id } } label: { Image(systemName: "xmark") } }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var notesContent: some View {
        switch footprint {
        case .glance:
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: "note.text").foregroundStyle(style.accentColor.color)
                Text(notePreview).font(.system(size: 11, weight: .medium)).lineLimit(4)
                    .foregroundStyle(workspace.settings.notes.isEmpty ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .horizontal:
            HStack(spacing: 8) {
                Image(systemName: "note.text").foregroundStyle(style.accentColor.color)
                Text(notePreview).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }
        case .vertical:
            VStack(alignment: .leading, spacing: 7) {
                Label("Quick Note", systemImage: "note.text").font(.system(size: 12, weight: .semibold))
                Text(notePreview).lineLimit(7).foregroundStyle(workspace.settings.notes.isEmpty ? .secondary : .primary)
                Spacer(minLength: 0)
            }
        case .standard, .expanded, .none:
            if presentation != .compact {
                WidgetElement(key: "stats", defaultPriority: .low) {
                    let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count
                    HStack { Label("\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\(workspace.settings.notes.count) chars") }
                }
            }
            WidgetElement(key: "editor", defaultPriority: .high) {
                TextEditor(text: $workspace.settings.notes)
                    .frame(height: {
                        let available = max(34, (availableHeight ?? options.notesHeight) - (presentation == .compact ? 10 : 44))
                        switch presentation {
                        case .compact: return min(58, available)
                        case .expanded: return min(max(90, options.notesHeight), available)
                        case .regular, .automatic: return min(options.notesHeight, available)
                        }
                    }())
                    .accessibilityLabel("Quick note")
            }
            if presentation == .expanded {
                WidgetElement(key: "actions", defaultVisible: false, defaultPriority: .low) {
                    HStack {
                        Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(workspace.settings.notes, forType: .string) }
                        Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)
                    }
                }
            }
        }
    }

    private var notePreview: String {
        let value = workspace.settings.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Tap into a larger Notes widget to start writing." : value
    }

    @ViewBuilder private var stopwatchContent: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0)
            let whole = Int(elapsed)
            let time = String(format: "%02d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60)
            switch footprint {
            case .glance:
                Text(time).font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1)
            case .horizontal:
                HStack(spacing: 8) {
                    Text(time).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
                    Spacer(minLength: 0)
                    if options.showControls {
                        Button { workspace.toggleStopwatch() } label: { Image(systemName: workspace.stopwatchStart == nil ? "play.fill" : "pause.fill") }.buttonStyle(.plain)
                    }
                }
            case .vertical:
                VStack(spacing: 8) {
                    Text(time).font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit()
                    if options.showControls {
                        HStack {
                            Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                            Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
                        }.controlSize(.mini)
                    }
                }
            case .standard, .expanded, .none:
                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
                    if presentation != .compact {
                        WidgetElement(key: "state", defaultPriority: .low) {
                            Label(workspace.stopwatchStart == nil ? (workspace.stopwatchElapsed > 0 ? "Paused" : "Ready") : "Running",
                                  systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")
                        }
                    }
                    WidgetElement(key: "time", defaultPriority: .alwaysVisible) {
                        Text(time).font(style.font(scale: options.stopwatchScale)).monospacedDigit()
                    }
                    if options.showControls {
                        WidgetElement(key: "controls", defaultPriority: .high) {
                            HStack(spacing: options.spacing) {
                                Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                                Button("Reset") { workspace.stopwatchStart = nil; workspace.stopwatchElapsed = 0 }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CaptureModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: CaptureService
    @ObservedObject var store: AppStore
    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }

    var body: some View {
        let options = style.resolvedContent
        Group {
            switch footprint {
            case .glance:
                Button { service.capture { store.addFiles([$0]) } } label: {
                    Image(systemName: service.busy ? "hourglass" : "viewfinder")
                        .font(.system(size: 24, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.buttonStyle(.plain).disabled(service.busy).help("Capture region")
            case .horizontal:
                HStack(spacing: 12) {
                    compactCaptureButton("viewfinder", "Capture") { service.capture { store.addFiles([$0]) } }
                    compactCaptureButton("text.viewfinder", "Text") { service.chooseImage() }
                }.disabled(service.busy)
            case .vertical:
                VStack(spacing: 8) {
                    compactCaptureButton("viewfinder", "Capture region") { service.capture { store.addFiles([$0]) } }
                    compactCaptureButton("text.viewfinder", "Extract text") { service.chooseImage() }
                    if service.busy { ProgressView().controlSize(.small) }
                }.disabled(service.busy)
            case .standard, .expanded, .none:
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
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment)
    }

    private func compactCaptureButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).lineLimit(1)
                .frame(maxWidth: .infinity)
        }.buttonStyle(.bordered).controlSize(.small)
    }
}

struct MediaModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: MediaService
    let app: String
    private var options: WidgetContentOptions { style.resolvedContent }
    private var artworkStyle: WidgetElementStyle { style.elementStyle(for: "artwork") }
    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }
    private var compactArtworkSize: CGFloat {
        let requested = CGFloat(artworkStyle.iconSize ?? 54)
        return min(max(38, requested), max(38, min(72, (availableHeight ?? 92) * 0.62)))
    }
    private var regularArtworkSize: CGFloat {
        let requested = CGFloat(artworkStyle.iconSize ?? 82)
        return min(max(52, requested), max(52, min(112, (availableHeight ?? 150) * 0.72)))
    }
    private var expandedArtworkHeight: CGFloat {
        min(240, max(110, (availableHeight ?? 260) * 0.48))
    }

    var body: some View {
        Group {
            if let footprint {
                switch footprint {
                case .glance: glance
                case .horizontal: compact
                case .vertical: verticalCompact
                case .standard: regular
                case .expanded: expanded
                }
            } else {
                switch presentation {
                case .compact:
                    if (availableWidth ?? 200) < 150 || (availableHeight ?? 100) < 82 { glance }
                    else { compact }
                case .expanded: expanded
                case .regular, .automatic: regular
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment)
        .animation(.easeInOut(duration: 0.18), value: footprint)
        .onAppear { service.setArtworkEnabled(true) }
    }

    private var glance: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = service.artworkImage {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        style.accentColor.color.opacity(0.10)
                        Image(systemName: "music.note").font(.system(size: 26, weight: .medium)).foregroundStyle(style.accentColor.color)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if options.showControls, service.connectedApp != nil {
                Button { service.perform("playpause", app: app) } label: {
                    Image(systemName: service.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 25, height: 25)
                        .background(.ultraThinMaterial, in: Circle())
                }.buttonStyle(.plain).padding(5)
            }
        }
    }

    private var compact: some View {
        HStack(spacing: max(6, options.spacing)) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .high) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: compactArtworkSize, height: compactArtworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: min(14, compactArtworkSize * 0.18), style: .continuous))
                }
                .frame(width: compactArtworkSize + 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                WidgetElement(key: "track", defaultPriority: .alwaysVisible) { Text(service.title).lineLimit(1) }
                if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist", defaultPriority: .high) { Text(service.artist).lineLimit(1) } }
            }
            Spacer(minLength: 4)
            if options.showControls, service.connectedApp != nil {
                WidgetElement(key: "controls", defaultPriority: .high) { Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") } }
            }
        }
    }

    private var verticalCompact: some View {
        VStack(spacing: max(5, options.spacing * 0.65)) {
            if let image = service.artworkImage {
                let size = min(max(48, (availableWidth ?? 120) * 0.66), max(48, (availableHeight ?? 180) * 0.42))
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: min(16, size * 0.18), style: .continuous))
            } else {
                Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(style.accentColor.color)
            }
            Text(service.title).font(.system(size: 11, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
            if options.mediaShowArtist && !service.artist.isEmpty { Text(service.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            if options.showControls, service.connectedApp != nil {
                Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") }.buttonStyle(.plain)
            }
        }.frame(maxWidth: .infinity)
    }

    private var regular: some View {
        HStack(alignment: .top, spacing: options.spacing) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .normal) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: regularArtworkSize, height: regularArtworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: min(18, regularArtworkSize * 0.16), style: .continuous))
                }
                .frame(width: regularArtworkSize + 6)
            }
            VStack(alignment: .leading, spacing: max(4, options.spacing * 0.65)) { metadata; progress; controls }
        }
    }

    private var expanded: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .normal) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(maxWidth: min(320, (availableWidth ?? 360) - 24), minHeight: expandedArtworkHeight, maxHeight: expandedArtworkHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            metadata
            progress
            controls
            if service.shuffleSupported || service.repeatSupported {
                HStack {
                    if service.shuffleSupported { WidgetElement(key: "shuffle", defaultVisible: false, defaultPriority: .low) { Button { service.toggleShuffle() } label: { Label("Shuffle", systemImage: service.shuffleEnabled ? "shuffle.circle.fill" : "shuffle") } } }
                    if service.repeatSupported { WidgetElement(key: "repeat", defaultVisible: false, defaultPriority: .low) { Button { service.cycleRepeat() } label: { Label(service.repeatMode.isEmpty ? "Repeat" : service.repeatMode, systemImage: "repeat") } } }
                }
            }
            WidgetElement(key: "visualizer", defaultVisible: false, defaultPriority: .optional) { OpenMediaSpectrumView(accent: style.accentColor.color) }
            if options.showQuickActions { WidgetElement(key: "detection", defaultVisible: false, defaultPriority: .optional) { Button("Retry player detection") { service.retryDetection(preferred: app) } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status", defaultPriority: .normal) { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
    }

    @ViewBuilder private var metadata: some View {
        WidgetElement(key: "track", defaultPriority: .alwaysVisible) { Text(service.title).lineLimit(options.mediaTitleLines) }
        if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist", defaultPriority: .normal) { Text(service.artist) } }
        if !service.album.isEmpty { WidgetElement(key: "album", defaultVisible: false, defaultPriority: .low) { Text(service.album) } }
        if options.mediaShowSource, let source = service.connectedApp {
            WidgetElement(key: "source", defaultPriority: .low) { Label(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio", systemImage: "app.badge") }
        }
        WidgetElement(key: "playback", defaultPriority: .low) { Label(service.connectedApp == nil ? "Waiting for a player" : (service.isPlaying ? "Playing" : "Paused"), systemImage: service.connectedApp == nil ? "music.note" : (service.isPlaying ? "play.fill" : "pause.fill")) }
    }

    @ViewBuilder private var progress: some View {
        if service.duration > 0 {
            WidgetElement(key: "progress", defaultPriority: .normal) { Slider(value: Binding(get: { service.position }, set: { service.seek(to: $0) }), in: 0...max(1, service.duration)) { Text("Playback position") } }
            WidgetElement(key: "timing", defaultPriority: .low) {
                HStack { Text(Self.time(service.position)); Spacer(); Text("−" + Self.time(max(0, service.duration - service.position))) }.monospacedDigit()
            }
        }
    }

    @ViewBuilder private var controls: some View {
        if options.showControls, service.connectedApp != nil {
            WidgetElement(key: "controls", defaultPriority: .high) {
                HStack(spacing: options.spacing) {
                    Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") }
                    Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") }
                    Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") }
                }.disabled(service.busy)
            }
        }
    }
    private static func time(_ seconds: Double) -> String { let value = max(0, Int(seconds)); return String(format: "%d:%02d", value / 60, value % 60) }
}

private struct OpenMediaSpectrumView: View {
    let accent: Color
    @State private var snapshot = AudioSpectrumSnapshot()
    @State private var owner = UUID().uuidString
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            GeometryReader { proxy in
                let values = [snapshot.bass, snapshot.mids, snapshot.treble, snapshot.overall]
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        Capsule().fill(accent.opacity(0.78)).frame(maxWidth: .infinity, minHeight: 2, maxHeight: max(2, proxy.size.height * value))
                    }
                }
            }
        }
        .frame(height: 34)
        .onAppear { AudioSpectrumService.shared.setActive(true, owner: owner) }
        .onDisappear { AudioSpectrumService.shared.setActive(false, owner: owner) }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in snapshot = AudioSpectrumService.shared.snapshot() }
    }
}

struct AudioModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: AudioService
    private var options: WidgetContentOptions { style.resolvedContent }
    private var selectedName: String { service.devices.first(where: { $0.id == service.selected })?.name ?? "Audio Output" }
    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }

    var body: some View {
        Group {
            switch footprint {
            case .glance: glance
            case .horizontal: horizontalCompact
            case .vertical: verticalCompact
            case .standard, .expanded, .none: fullContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.refresh() }
    }

    private var glance: some View {
        VStack(spacing: 3) {
            Image(systemName: service.volume <= 0.001 ? "speaker.slash.fill" : service.volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(style.accentColor.color)
            Text("\(Int(service.volume * 100))%")
                .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }

    private var horizontalCompact: some View {
        HStack(spacing: 8) {
            Image(systemName: service.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill").foregroundStyle(style.accentColor.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedName).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Text("\(service.devices.count) outputs").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(Int(service.volume * 100))%").font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit()
        }
    }

    private var verticalCompact: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: service.volume <= 0.001 ? "speaker.slash.fill" : "speaker.wave.2.fill").foregroundStyle(style.accentColor.color)
                Text("\(Int(service.volume * 100))%").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
            }
            Text(selectedName).font(.caption).lineLimit(2).multilineTextAlignment(.center)
            if service.canSetVolume && options.showControls {
                Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
                    .controlSize(.mini)
            }
        }
    }

    private var fullContent: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary", defaultPriority: .high) {
                HStack(spacing: 10) {
                    Image(systemName: service.volume <= 0.001 ? "speaker.slash.fill" : service.volume < 0.5 ? "speaker.wave.1.fill" : "speaker.wave.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(style.accentColor.color)
                        .frame(width: 34, height: 34)
                        .background(style.accentColor.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedName).lineLimit(1).font(.system(size: 13, weight: .semibold))
                        Text("\(service.devices.count) output\(service.devices.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text("\(Int(service.volume * 100))")
                        .font(.system(size: presentation == .compact ? 24 : 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%").font(.caption).foregroundStyle(.secondary)
                }
            }
            if service.canSetVolume && options.showControls {
                WidgetElement(key: "volume", defaultPriority: .high) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1) { Text("Volume") }
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
                if presentation != .compact {
                    WidgetElement(key: "volumeValue", defaultPriority: .low) {
                        HStack { Text("Output volume"); Spacer(); Text("\(Int(service.volume * 100))%").monospacedDigit().foregroundStyle(style.accentColor.color) }
                    }
                }
            } else if !service.canSetVolume && options.showStatus {
                WidgetElement(key: "status") { Label("This output uses hardware volume controls.", systemImage: "dial.medium") }
            }
            if presentation != .compact {
                WidgetElement(key: "output") {
                    Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {
                        ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }
                    }.labelsHidden()
                }
            }
            WidgetElement(key: "levels", defaultVisible: false) {
                HStack(spacing: 6) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { value in
                        Button("\(value)%") { service.setVolume(Float(value) / 100) }.buttonStyle(.bordered)
                    }
                }
            }
            if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Refresh devices") { service.refresh() } } }
            if options.showStatus, let error = service.error { WidgetElement(key: "status") { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) } }
        }
    }
}


private enum VisualCalendarFamily: String, Equatable {
    case micro, compactAgenda, horizontalAgenda, verticalAgenda, miniMonth, day, schedule, month, split, hero
}

struct VisualWorkspaceCalendarView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var service: CalendarService

    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthAnchor = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthEvents: [EKEvent] = []
    @State private var selectedEventIdentifier: String?

    private var settings: VisualCalendarOptions { style.resolvedVisualCalendar }
    private var columns: Int { min(8, max(1, gridColumnSpan ?? estimatedColumns)) }
    private var rows: Int { min(4, max(1, gridRowSpan ?? estimatedRows)) }
    private var override: VisualCalendarSizeOverride? { settings.sizeOverride(columns: columns, rows: rows) }
    private var calendar: Calendar {
        var value = Calendar.autoupdatingCurrent
        switch settings.weekStart {
        case .system: break
        case .monday: value.firstWeekday = 2
        case .sunday: value.firstWeekday = 1
        }
        return value
    }
    private var family: VisualCalendarFamily { Self.family(columns: columns, rows: rows, width: availableWidth, height: availableHeight) }
    private var effectiveView: VisualCalendarViewStyle {
        let requested = override?.view ?? settings.preferredView
        guard requested == .automatic else { return degraded(requested) }
        switch family {
        case .micro: return .today
        case .compactAgenda, .horizontalAgenda, .verticalAgenda: return .agenda
        case .miniMonth: return .month
        case .day: return .dayTimeline
        case .schedule: return columns >= 5 ? .week : .upcoming
        case .month: return .monthAgenda
        case .split: return .split
        case .hero: return .split
        }
    }
    private var visibleEventLimit: Int {
        let requested = override?.maxEvents ?? settings.maxEvents
        let capacity: Int
        switch family {
        case .micro: capacity = 0
        case .compactAgenda: capacity = 1
        case .horizontalAgenda: capacity = max(1, min(4, columns - 1))
        case .verticalAgenda: capacity = max(1, min(4, rows))
        case .miniMonth: capacity = 2
        case .day: capacity = max(3, rows * 2)
        case .schedule: capacity = max(3, columns)
        case .month: capacity = max(3, rows + 1)
        case .split: capacity = max(4, rows + 2)
        case .hero: capacity = max(6, rows * 2)
        }
        return min(requested, capacity)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch effectiveView {
                case .automatic: todayTile
                case .today: todayPresentation
                case .agenda: agendaPresentation
                case .dayTimeline: dayTimelinePresentation
                case .week: weekPresentation
                case .month: monthPresentation
                case .monthAgenda: monthAgendaPresentation
                case .split: splitPresentation
                case .upcoming: upcomingPresentation
                case .minimal: minimalPresentation
                }
            }
            if !service.hasAccess { calendarPermissionBadge }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(style.backgroundColor.color.opacity(settings.backgroundOpacity))
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: family)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
        .animation(.easeInOut(duration: 0.2), value: selectedEventIdentifier)
        .onAppear {
            service.refresh()
            loadMonth()
            // Calendar dates/month navigation are local and permission-free. Event access is
            // requested once, only to enrich the widget with real events.
            service.requestAccessIfNeeded()
        }
        .onChange(of: monthAnchor) { _ in loadMonth() }
        .onChange(of: service.calendarRevision) { _ in loadMonth() }
    }

    private var calendarPermissionBadge: some View {
        Button { service.requestAccess() } label: {
            Group {
                if family == .micro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7, weight: .bold))
                        .frame(width: 16, height: 16)
                } else {
                    Label("Events Off", systemImage: "calendar.badge.exclamationmark")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                }
            }
            .foregroundStyle(accent)
            .background(Color.black.opacity(0.28), in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(family == .micro ? 3 : 5)
        .help(service.status + " Calendar dates and navigation remain available without event permission.")
    }

    private static func family(columns: Int, rows: Int, width: CGFloat?, height: CGFloat?) -> VisualCalendarFamily {
        let c = min(8, max(1, columns)), r = min(4, max(1, rows))
        if c == 1 && r == 1 { return .micro }
        if r == 1 { return c <= 2 ? .compactAgenda : .horizontalAgenda }
        if c == 1 { return .verticalAgenda }
        if c == 2 && r == 2 { return .miniMonth }
        if c >= 7 && r >= 4 { return .hero }
        if c >= 5 && r >= 3 { return .split }
        if c >= 4 && r >= 3 { return .month }
        if r >= 3 && c <= 2 { return .day }
        if c >= 4 && r == 2 { return .schedule }
        if c >= 3 && r >= 3 { return .month }
        if c >= 3 && r == 2 { return .schedule }
        let aspect = (width ?? CGFloat(c)) / max(1, height ?? CGFloat(r))
        return aspect > 1.35 ? .schedule : .day
    }

    private var estimatedColumns: Int { max(1, min(8, Int(round((availableWidth ?? 120) / 120)))) }
    private var estimatedRows: Int { max(1, min(4, Int(round((availableHeight ?? 100) / 100)))) }

    private func degraded(_ requested: VisualCalendarViewStyle) -> VisualCalendarViewStyle {
        switch requested {
        case .month, .monthAgenda, .split where columns == 1 || rows == 1: return rows == 1 ? .agenda : .today
        case .week where columns < 3: return .agenda
        case .dayTimeline where rows < 2: return .agenda
        case .split where columns < 4 || rows < 2: return rows >= 2 ? .monthAgenda : .agenda
        default: return requested
        }
    }

    private var filteredUpcoming: [EKEvent] { service.visualUpcomingEvents.filter(matchesFilter) }
    private var filteredToday: [EKEvent] { service.visualDayEvents.filter(matchesFilter) }
    private var filteredMonth: [EKEvent] { monthEvents.filter(matchesFilter) }
    private var eventsForSelectedDate: [EKEvent] { events(on: selectedDate) }
    private var selectedEvent: EKEvent? {
        guard let selectedEventIdentifier else { return nil }
        return (filteredMonth + filteredUpcoming).first { eventKey($0) == selectedEventIdentifier }
    }

    private var todayPresentation: some View {
        Group {
            switch family {
            case .micro: todayTile
            case .compactAgenda, .horizontalAgenda: horizontalAgenda
            case .verticalAgenda: verticalAgenda
            default:
                VStack(alignment: .leading, spacing: densitySpacing(10)) {
                    todayHeader(prominent: true)
                    if !filteredToday.isEmpty { agendaList(events: filteredToday, limit: visibleEventLimit) }
                    else { subtleEmptyState }
                }
            }
        }
    }

    private var minimalPresentation: some View {
        VStack(spacing: 4) {
            Text(selectedDate, format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent))
                .font(dateFont(family == .micro ? 10 : 12)).textCase(.uppercase).foregroundStyle(.secondary)
            Text(selectedDate, format: .dateTime.day())
                .font(dateFont(family == .micro ? 36 : 46)).monospacedDigit()
            if family != .micro { Text(selectedDate, format: .dateTime.month(.abbreviated)).font(.caption).foregroundStyle(accent) }
        }
    }

    private var agendaPresentation: some View {
        Group {
            switch family {
            case .micro: todayTile
            case .compactAgenda, .horizontalAgenda: horizontalAgenda
            case .verticalAgenda: verticalAgenda
            default:
                VStack(alignment: .leading, spacing: densitySpacing(8)) {
                    dayNavigationHeader
                    allDayStrip(events: eventsForSelectedDate.filter(\.isAllDay))
                    agendaList(events: eventsForSelectedDate.filter { !$0.isAllDay }, limit: visibleEventLimit)
                    if eventsForSelectedDate.isEmpty { subtleEmptyState }
                }
            }
        }
    }

    private var upcomingPresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(8)) {
            HStack {
                Text("UPCOMING").font(monthFont(11)).foregroundStyle(.secondary)
                Spacer()
                Text("\(filteredUpcoming.count)").font(.caption).foregroundStyle(accent)
            }
            agendaList(events: filteredUpcoming, limit: visibleEventLimit)
            if filteredUpcoming.isEmpty { subtleEmptyState }
        }
    }

    private var monthPresentation: some View {
        monthGrid(showAgenda: false)
    }

    private var monthAgendaPresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(8)) {
            monthGrid(showAgenda: false)
            Divider().opacity(0.18)
            selectedDayAgenda
        }
    }

    private var splitPresentation: some View {
        Group {
            if family == .hero || (columns >= 5 && rows >= 3) {
                HStack(alignment: .top, spacing: densitySpacing(14)) {
                    monthGrid(showAgenda: false).frame(maxWidth: .infinity)
                    Divider().opacity(0.18)
                    VStack(alignment: .leading, spacing: densitySpacing(8)) {
                        selectedDayAgenda
                        if let selectedEvent { Divider().opacity(0.16); eventDetail(selectedEvent) }
                    }.frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: densitySpacing(8)) {
                    monthGrid(showAgenda: false)
                    selectedDayAgenda
                }
            }
        }
    }

    private var dayTimelinePresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(7)) {
            dayNavigationHeader
            let allDay = eventsForSelectedDate.filter(\.isAllDay)
            if !allDay.isEmpty { allDayStrip(events: allDay) }
            ScrollView(.vertical, showsIndicators: family == .hero) {
                VStack(spacing: 0) {
                    ForEach(timelineHours, id: \.self) { hour in timelineHourRow(hour) }
                }
            }
        }
    }

    private var weekPresentation: some View {
        VStack(alignment: .leading, spacing: densitySpacing(7)) {
            HStack {
                Button { selectedDate = calendar.date(byAdding: .day, value: -visibleWeekDays, to: selectedDate) ?? selectedDate; monthAnchor = selectedDate } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                Text(weekTitle).font(monthFont(12))
                Spacer()
                Button("Today") { selectToday() }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
                Button { selectedDate = calendar.date(byAdding: .day, value: visibleWeekDays, to: selectedDate) ?? selectedDate; monthAnchor = selectedDate } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: densitySpacing(5)) {
                ForEach(visibleWeekDates, id: \.self) { day in weekColumn(day) }
            }
        }
    }

    private var todayTile: some View {
        let next = filteredToday.first { $0.endDate > Date() }
        let minutesUntil = next.map { Int(ceil($0.startDate.timeIntervalSinceNow / 60)) }
        let imminent = minutesUntil.map { $0 >= 0 && $0 <= 60 } ?? false
        return Group {
            if imminent, let minutesUntil {
                VStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    Text("\(minutesUntil)m").font(dateFont(30)).monospacedDigit().minimumScaleFactor(0.65)
                    Text("NEXT").font(dateFont(7)).foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 1) {
                    Text(Date(), format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent)).font(dateFont(9)).textCase(.uppercase).foregroundStyle(.secondary)
                    todayHeroNumber
                    if !filteredToday.isEmpty { Circle().fill(accent).frame(width: 4, height: 4).padding(.top, 3) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .haloMicroInteraction(accent: accent, help: imminent ? "Next event in \(minutesUntil ?? 0) minutes" : "Calendar · click for today · hold for agenda", tapShowsPopover: true, onTap: {}) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day()).font(.headline)
                if filteredToday.isEmpty { Text(service.hasAccess ? "No more events today" : "Event access is off — dates still work normally.").foregroundStyle(.secondary) }
                ForEach(filteredToday.prefix(5), id: \.eventIdentifier) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title).lineLimit(1)
                        Text(event.startDate, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(width: 280)
        }
    }

    private var horizontalAgenda: some View {
        HStack(spacing: densitySpacing(9)) {
            dateBadge
            Divider().opacity(0.22)
            let events = Array(filteredToday.prefix(max(1, min(visibleEventLimit, max(1, columns - 1)))))
            if events.isEmpty {
                Text(service.hasAccess ? "Nothing scheduled" : "Events off").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    compactHorizontalEvent(event)
                    if eventKey(event) != eventKey(events.last!) { Divider().opacity(0.12) }
                }
                let more = max(0, filteredToday.count - events.count)
                if more > 0 { Text("+\(more)").font(.caption2).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
    }

    private var verticalAgenda: some View {
        VStack(alignment: .leading, spacing: densitySpacing(7)) {
            todayHeader(prominent: false)
            let events = Array(filteredToday.prefix(max(1, visibleEventLimit)))
            ForEach(Array(events.enumerated()), id: \.offset) { _, event in agendaRow(event, compact: true) }
            let more = max(0, filteredToday.count - events.count)
            if more > 0 { Text("+\(more) more").font(.caption2).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
    }

    private var dateBadge: some View {
        VStack(spacing: -1) {
            Text(Date(), format: .dateTime.weekday(.abbreviated)).font(dateFont(9)).textCase(.uppercase).foregroundStyle(.secondary)
            Text(Date(), format: .dateTime.day()).font(dateFont(28)).monospacedDigit()
        }.frame(minWidth: columns <= 2 ? 34 : 42)
    }

    private func todayHeader(prominent: Bool) -> some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: 1) {
                Text("TODAY").font(monthFont(9)).foregroundStyle(accent)
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day().locale(.autoupdatingCurrent))
                    .font(dateFont(prominent ? 16 : 12)).lineLimit(1)
            }
            Spacer()
            if family != .verticalAgenda { Text(!service.hasAccess ? "Events off" : (filteredToday.isEmpty ? "Clear" : "\(filteredToday.count) event\(filteredToday.count == 1 ? "" : "s")")).font(.caption2).foregroundStyle(.secondary) }
        }
    }

    private var dayNavigationHeader: some View {
        HStack(spacing: 8) {
            Button { changeSelectedDay(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedDate, format: .dateTime.weekday(.wide)).font(dateFont(13))
                Text(selectedDate, format: .dateTime.month(.abbreviated).day().year()).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Today") { selectToday() }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
            Button { changeSelectedDay(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
        }
    }

    private func compactHorizontalEvent(_ event: EKEvent) -> some View {
        Button { selectedEventIdentifier = eventKey(event) } label: {
            VStack(alignment: .leading, spacing: 1) {
                if informationVisible(.startTime, level: 1) { Text(timeLabel(event)).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(eventColor(event)) }
                Text(event.title ?? "Untitled event").font(eventFont(10)).lineLimit(1)
            }.frame(maxWidth: columns >= 6 ? 120 : 96, alignment: .leading)
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func agendaList(events: [EKEvent], limit: Int) -> some View {
        let shown = Array(events.prefix(max(0, limit)))
        VStack(spacing: densitySpacing(family == .hero ? 6 : 5)) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, event in agendaRow(event, compact: family == .miniMonth || family == .schedule) }
            let more = max(0, events.count - shown.count)
            if more > 0 { HStack { Spacer(); Text("+\(more) more").font(.caption2).foregroundStyle(.secondary) } }
        }
    }

    private func agendaRow(_ event: EKEvent, compact: Bool = false) -> some View {
        let level = metadataLevel
        return Button { selectedEventIdentifier = eventKey(event) } label: {
            HStack(alignment: .top, spacing: densitySpacing(7)) {
                if informationVisible(.calendarColor, level: level) {
                    Capsule().fill(eventColor(event)).frame(width: 3, height: compact ? 27 : 38)
                }
                if informationVisible(.startTime, level: level) {
                    Text(timeLabel(event)).font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.secondary).frame(width: compact ? 38 : 48, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title ?? "Untitled event").font(eventFont(compact ? 10 : 12)).lineLimit(compact ? 1 : 2)
                    if !compact {
                        HStack(spacing: 5) {
                            if informationVisible(.endTime, level: level), !event.isAllDay { Text("to \(event.endDate.formatted(date: .omitted, time: .shortened))") }
                            if informationVisible(.duration, level: level), !event.isAllDay { Text(durationLabel(event)) }
                            if informationVisible(.location, level: level), let location = event.location, !location.isEmpty { Text(location).lineLimit(1) }
                            if informationVisible(.attendees, level: level), let count = event.attendees?.count, count > 0 { Label("\(count)", systemImage: "person.2") }
                        }.font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        if informationVisible(.notes, level: level), let notes = event.notes, !notes.isEmpty {
                            Text(notes).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 2)
                if informationVisible(.meetingLink, level: level), settings.showMeetingLink, let url = service.meetingURL(for: event) {
                    Link(destination: url) { Image(systemName: "video.fill") }.buttonStyle(.plain).foregroundStyle(accent).help("Join meeting")
                }
            }
            .padding(.horizontal, compact ? 4 : 7).padding(.vertical, compact ? 3 : 5)
            .background(eventColor(event).opacity(settings.eventOpacity), in: RoundedRectangle(cornerRadius: settings.eventCornerRadius, style: .continuous))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func allDayStrip(events: [EKEvent]) -> some View {
        if !events.isEmpty {
            HStack(spacing: 5) {
                Text("ALL DAY").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(Array(events.prefix(columns >= 5 ? 3 : 1).enumerated()), id: \.offset) { _, event in
                    Text(event.title ?? "Untitled").font(.caption2).lineLimit(1).padding(.horizontal, 6).padding(.vertical, 3)
                        .background(eventColor(event).opacity(0.14), in: Capsule())
                }
                let more = max(0, events.count - (columns >= 5 ? 3 : 1))
                if more > 0 { Text("+\(more)").font(.caption2).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
        }
    }

    private func monthGrid(showAgenda: Bool) -> some View {
        VStack(alignment: .leading, spacing: densitySpacing(5)) {
            monthHeader
            if columns >= 3 {
                LazyVGrid(columns: monthColumns, spacing: densitySpacing(2)) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased()).font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                    }
                }
            }
            LazyVGrid(columns: monthColumns, spacing: densitySpacing(2)) {
                ForEach(monthDays, id: \.self) { day in monthDayCell(day) }
            }
            if showAgenda { selectedDayAgenda }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 7) {
            Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
            Text(monthAnchor, format: .dateTime.month(.wide).year()).font(monthFont(13)).lineLimit(1)
            Spacer()
            Button("Today") { selectToday() }.buttonStyle(.plain).font(.caption).foregroundStyle(accent)
            Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
        }
    }

    private func monthDayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let events = self.events(on: day)
        let weekend = calendar.isDateInWeekend(day)
        let cellWidth = max(16, ((availableWidth ?? CGFloat(columns * 100)) - CGFloat(6 * 3)) / 7)
        let indicator = override?.indicatorStyle ?? settings.eventIndicatorStyle
        return Button { selectedDate = calendar.startOfDay(for: day); selectedEventIdentifier = nil } label: {
            VStack(spacing: 1) {
                if settings.showWeekNumbers && calendar.component(.weekday, from: day) == calendar.firstWeekday {
                    Text("W\(calendar.component(.weekOfYear, from: day))").font(.system(size: 6, weight: .medium)).foregroundStyle(.tertiary)
                }
                calendarDayNumber(day, inMonth: inMonth, weekend: weekend, today: today, events: events, requestedIndicator: indicator, cellWidth: cellWidth)
                monthIndicators(events: events, style: indicator, cellWidth: cellWidth)
                if cellWidth >= 52, rows >= 3, let event = events.first {
                    Text(event.title ?? "Event").font(.system(size: 6.5, weight: .medium)).lineLimit(1).foregroundStyle(eventColor(event))
                }
            }
            .frame(maxWidth: .infinity, minHeight: monthCellHeight)
            .background(dayBackground(selected: selected, today: today), in: RoundedRectangle(cornerRadius: cellWidth < 30 ? 4 : 7, style: .continuous))
            .overlay { if settings.showGridLines { RoundedRectangle(cornerRadius: 6).stroke(style.textColor.color.opacity(settings.gridLineOpacity), lineWidth: 0.5) } }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(inMonth || settings.showAdjacentMonthDays ? 1 : 0)
        .disabled(!inMonth && !settings.showAdjacentMonthDays)
        .simultaneousGesture(TapGesture(count: 2).onEnded { openCalendarApp() })
    }

    @ViewBuilder private func monthIndicators(events: [EKEvent], style requested: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> some View {
        if !events.isEmpty {
            let effective = resolvedIndicatorStyle(requested, cellWidth: cellWidth)
            let shown = Array(events.prefix(settings.visibleEventIndicators))
            switch effective {
            case .automatic, .dots:
                HStack(spacing: 1.5) { ForEach(Array(shown.enumerated()), id: \.offset) { _, event in Circle().fill(eventColor(event)).frame(width: 3, height: 3) } }.frame(height: 4)
            case .bars:
                VStack(spacing: 1) { ForEach(Array(shown.prefix(2).enumerated()), id: \.offset) { _, event in Capsule().fill(eventColor(event)).frame(height: 2) } }.frame(height: 5)
            case .underline:
                Capsule().fill(eventColor(shown[0])).frame(height: 2).padding(.horizontal, 3)
            case .filledDate:
                Color.clear.frame(height: 4)
            case .minimalMarker:
                Circle().fill(eventColor(shown[0])).frame(width: 2.5, height: 2.5)
            }
        } else { Color.clear.frame(height: 4) }
    }

    private func resolvedIndicatorStyle(_ requested: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> VisualCalendarEventIndicatorStyle {
        if cellWidth < 24 { return .minimalMarker }
        if requested == .automatic { return cellWidth < 38 ? .dots : .bars }
        if cellWidth < 32 && requested != .minimalMarker && requested != .filledDate { return .dots }
        return requested
    }

    private var selectedDayAgenda: some View {
        VStack(alignment: .leading, spacing: densitySpacing(6)) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(selectedDate, format: .dateTime.weekday(.wide)).font(dateFont(12))
                    Text(selectedDate, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(eventsForSelectedDate.isEmpty ? "Clear" : "\(eventsForSelectedDate.count) event\(eventsForSelectedDate.count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary)
            }
            let allDay = eventsForSelectedDate.filter(\.isAllDay)
            if !allDay.isEmpty { allDayStrip(events: allDay) }
            let timed = eventsForSelectedDate.filter { !$0.isAllDay }
            if timed.isEmpty && allDay.isEmpty { subtleEmptyState }
            else { agendaList(events: timed, limit: visibleEventLimit) }
        }
    }

    private var subtleEmptyState: some View {
        HStack(spacing: 6) {
            Image(systemName: service.hasAccess ? "sparkles" : "calendar.badge.exclamationmark").foregroundStyle(accent)
            Text(service.hasAccess ? "Nothing scheduled" : "Calendar works · enable Events to show your schedule")
                .foregroundStyle(.secondary).lineLimit(2)
            Spacer()
        }
        .font(.caption).padding(.vertical, 4)
    }

    private func timelineHourRow(_ hour: Int) -> some View {
        let events = eventsForSelectedDate.filter { !$0.isAllDay && calendar.component(.hour, from: $0.startDate) == hour }
        let isCurrentHour = calendar.isDateInToday(selectedDate) && calendar.component(.hour, from: Date()) == hour
        return HStack(alignment: .top, spacing: 8) {
            Text(String(format: "%02d:00", hour)).font(.system(size: 9, design: .monospaced)).foregroundStyle(isCurrentHour ? accent : .secondary).frame(width: 38, alignment: .trailing)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(isCurrentHour ? accent.opacity(0.5) : style.textColor.color.opacity(0.08)).frame(width: isCurrentHour ? 2 : 1)
                if events.isEmpty { Color.clear.frame(height: timelineRowHeight) }
                else {
                    HStack(spacing: 4) {
                        ForEach(Array(events.prefix(columns >= 5 ? 2 : 1).enumerated()), id: \.offset) { _, event in
                            Button { selectedEventIdentifier = eventKey(event) } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.title ?? "Untitled").font(.system(size: 9, weight: .semibold)).lineLimit(1)
                                    if rows >= 3 { Text(durationLabel(event)).font(.system(size: 7)).foregroundStyle(.secondary) }
                                }.padding(4).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(eventColor(event).opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }
                        if events.count > (columns >= 5 ? 2 : 1) { Text("+\(events.count - (columns >= 5 ? 2 : 1))").font(.caption2).foregroundStyle(.secondary) }
                    }.padding(.leading, 7)
                }
            }.frame(maxWidth: .infinity, minHeight: timelineRowHeight, alignment: .topLeading)
        }
    }

    private func weekColumn(_ day: Date) -> some View {
        let events = events(on: day)
        let today = calendar.isDateInToday(day)
        return Button { selectedDate = day; monthAnchor = day } label: {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(day, format: .dateTime.weekday(.abbreviated)).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
                    Text(day, format: .dateTime.day()).font(dateFont(15)).foregroundStyle(today ? accent : primary)
                }
                ForEach(Array(events.prefix(rows >= 4 ? 3 : 2).enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 3) {
                        Circle().fill(eventColor(event)).frame(width: 3, height: 3)
                        Text(event.isAllDay ? (event.title ?? "Event") : "\(timeLabel(event)) \(event.title ?? "Event")").font(.system(size: 7.5, weight: .medium)).lineLimit(1)
                    }
                }
                if events.count > (rows >= 4 ? 3 : 2) { Text("+\(events.count - (rows >= 4 ? 3 : 2))").font(.system(size: 7)).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
            .padding(5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(today ? accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }

    private func eventDetail(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(event.title ?? "Untitled event").font(eventFont(13)).lineLimit(2)
            Text(event.isAllDay ? "All day" : "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            Text(event.calendar.title).font(.caption2).foregroundStyle(eventColor(event))
            if let location = event.location, !location.isEmpty {
                Button { openLocation(location) } label: { Label(location, systemImage: "mappin.and.ellipse").lineLimit(1) }.buttonStyle(.plain).font(.caption)
            }
            if let notes = event.notes, !notes.isEmpty { Text(notes).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
            if let url = service.meetingURL(for: event) { Link(destination: url) { Label("Join Meeting", systemImage: "video.fill") }.font(.caption).foregroundStyle(accent) }
        }
    }

    private var metadataLevel: Int {
        switch family {
        case .micro: return 0
        case .compactAgenda: return 1
        case .horizontalAgenda, .verticalAgenda, .miniMonth: return 2
        case .day, .schedule: return 4
        case .month: return 5
        case .split: return 6
        case .hero: return 8
        }
    }

    private func informationVisible(_ information: VisualCalendarInformation, level: Int) -> Bool {
        guard settings.enabledInformation.contains(information) else { return false }
        let index = settings.resolvedInformationPriority.firstIndex(of: information) ?? Int.max
        guard index < level else { return false }
        switch information {
        case .endTime: return settings.showEventEndTime
        case .duration: return settings.showEventDuration
        case .location: return settings.showEventLocation
        case .meetingLink: return settings.showMeetingLink
        case .notes: return settings.showNotesPreview
        case .attendees: return settings.showAttendees
        default: return true
        }
    }

    private var monthColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: densitySpacing(2)), count: 7) }
    private var monthCellHeight: CGFloat {
        let base: CGFloat = rows >= 4 ? 30 : rows >= 3 ? 25 : 21
        switch settings.density { case .compact: return base * 0.85; case .spacious: return base * 1.14; default: return base }
    }
    private var timelineRowHeight: CGFloat { rows >= 4 ? 28 : rows >= 3 ? 23 : 19 }
    private var timelineHours: [Int] {
        let timed = eventsForSelectedDate.filter { !$0.isAllDay }
        let minHour = timed.map { calendar.component(.hour, from: $0.startDate) }.min() ?? 8
        let maxHour = timed.map { calendar.component(.hour, from: $0.endDate) }.max() ?? 18
        let start = max(0, min(8, minHour))
        let end = min(23, max(18, maxHour))
        return Array(start...end)
    }
    private var visibleWeekDays: Int { columns >= 7 ? 7 : columns >= 5 ? 5 : columns >= 4 ? 3 : 1 }
    private var visibleWeekDates: [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let count = visibleWeekDays
        let selectedWeekday = calendar.component(.weekday, from: selectedDate)
        let offset: Int
        if count == 7 { offset = 0 }
        else { offset = max(0, min(7 - count, selectedWeekday - calendar.firstWeekday)) }
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: offset + $0, to: weekStart) }
    }
    private var weekTitle: String {
        guard let first = visibleWeekDates.first, let last = visibleWeekDates.last else { return "Week" }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
    private var weekdaySymbols: [String] {
        let values = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, min(6, calendar.firstWeekday - 1))
        return (0..<7).map { values[(offset + $0) % values.count] }
    }
    private var monthDays: [Date] {
        let start = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
        let grid = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: grid) }
    }

    private func events(on day: Date) -> [EKEvent] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return filteredMonth.filter { $0.startDate < end && $0.endDate > start }.sorted { $0.startDate < $1.startDate }
    }
    private func matchesFilter(_ event: EKEvent) -> Bool {
        let calendarTitle = event.calendar.title.lowercased()
        switch settings.filterMode {
        case .all:
            return true
        case .selected:
            return Set(settings.selectedCalendarIdentifiers).contains(event.calendar.calendarIdentifier)
        case .work:
            return ["work", "office", "job", "business", "company", "team"].contains { calendarTitle.contains($0) }
        case .personal:
            return ["personal", "home", "family", "private", "icloud"].contains { calendarTitle.contains($0) }
        case .birthdays:
            return event.calendar.type == .birthday || calendarTitle.contains("birthday") || (event.title ?? "").localizedCaseInsensitiveContains("birthday")
        case .holidaysFestivals:
            return isHolidayOrFestival(event)
        case .custom:
            let wanted = Set(settings.customCalendarNames.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
            return wanted.isEmpty || wanted.contains(calendarTitle)
        }
    }

    private func isHolidayOrFestival(_ event: EKEvent) -> Bool {
        let haystack = "\(event.calendar.title) \(event.title ?? "")".lowercased()
        let keywords = [
            "holiday", "holidays", "observance", "festival", "festivals", "public holiday", "bank holiday",
            "new year", "christmas", "easter", "eid", "diwali", "divali", "holi", "vesak", "ramadan",
            "maha shivaratree", "shivaratri", "cavadee", "ugadi", "ganesh chaturthi", "all saints", "spring festival"
        ]
        if keywords.contains(where: { haystack.contains($0) }) { return true }
        // macOS exposes many regional holiday calendars as read-only subscriptions.
        // Restrict the fallback to all-day entries to avoid classifying ordinary
        // subscribed schedules (sports, releases, etc.) as holidays.
        return event.calendar.type == .subscription && event.isAllDay
    }
    private func loadMonth() { monthEvents = service.events(around: monthAnchor) }
    private func changeMonth(_ amount: Int) {
        monthAnchor = calendar.date(byAdding: .month, value: amount, to: monthAnchor) ?? monthAnchor
        selectedDate = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
        selectedEventIdentifier = nil
    }
    private func changeSelectedDay(_ amount: Int) {
        selectedDate = calendar.date(byAdding: .day, value: amount, to: selectedDate) ?? selectedDate
        monthAnchor = selectedDate
        selectedEventIdentifier = nil
    }
    private func selectToday() {
        selectedDate = calendar.startOfDay(for: Date())
        monthAnchor = selectedDate
        selectedEventIdentifier = nil
    }
    private func eventKey(_ event: EKEvent) -> String { event.eventIdentifier ?? "\(event.startDate.timeIntervalSinceReferenceDate)|\(event.title ?? "")" }
    private func timeLabel(_ event: EKEvent) -> String { event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened) }
    private func durationLabel(_ event: EKEvent) -> String {
        let minutes = max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        return minutes >= 60 ? "\(minutes / 60)h\(minutes % 60 == 0 ? "" : " \(minutes % 60)m")" : "\(minutes)m"
    }
    private func densitySpacing(_ base: CGFloat) -> CGFloat {
        switch settings.density { case .compact: return base * 0.72; case .spacious: return base * 1.28; default: return base }
    }

    @ViewBuilder private var todayHeroNumber: some View {
        let color = settings.todayColor?.color ?? accent
        let number = Text(Date(), format: .dateTime.day()).font(dateFont(36)).monospacedDigit()
        if !settings.highlightToday {
            number.foregroundStyle(primary)
        } else {
            switch settings.todayStyle {
            case .circle:
                number.foregroundStyle(primary).padding(5).background(color.opacity(0.20), in: Circle())
            case .pill:
                number.foregroundStyle(primary).padding(.horizontal, 9).padding(.vertical, 3).background(color.opacity(0.20), in: Capsule())
            case .filledNumber:
                number.foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3).background(color.opacity(0.88), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            case .outline:
                number.foregroundStyle(primary).padding(5).overlay(Circle().stroke(color.opacity(0.9), lineWidth: 1.25))
            case .accentText:
                number.foregroundStyle(color)
            case .subtleGlow:
                number.foregroundStyle(primary).shadow(color: color.opacity(0.65), radius: 5)
            case .minimalDot:
                VStack(spacing: 1) { number.foregroundStyle(primary); Circle().fill(color).frame(width: 4, height: 4) }
            }
        }
    }

    @ViewBuilder private func calendarDayNumber(_ day: Date, inMonth: Bool, weekend: Bool, today: Bool, events: [EKEvent], requestedIndicator: VisualCalendarEventIndicatorStyle, cellWidth: CGFloat) -> some View {
        let normalColor = dayTextColor(day: day, inMonth: inMonth, weekend: weekend, today: today)
        let number = Text(day, format: .dateTime.day()).font(dateFont(cellWidth < 30 ? 8 : 10)).foregroundStyle(normalColor)
        let indicator = resolvedIndicatorStyle(requestedIndicator, cellWidth: cellWidth)
        if indicator == .filledDate, let event = events.first {
            number.padding(.horizontal, 3).padding(.vertical, 2)
                .background(eventColor(event).opacity(0.30), in: Circle())
        } else if today && settings.highlightToday {
            let color = settings.todayColor?.color ?? accent
            switch settings.todayStyle {
            case .circle:
                number.padding(3).background(color.opacity(0.20), in: Circle())
            case .pill:
                number.padding(.horizontal, 5).padding(.vertical, 2).background(color.opacity(0.20), in: Capsule())
            case .filledNumber:
                number.foregroundStyle(.white).padding(.horizontal, 4).padding(.vertical, 2).background(color.opacity(0.86), in: Circle())
            case .outline:
                number.padding(3).overlay(Circle().stroke(color.opacity(0.9), lineWidth: 1))
            case .accentText:
                number.foregroundStyle(color)
            case .subtleGlow:
                number.shadow(color: color.opacity(0.65), radius: 3)
            case .minimalDot:
                VStack(spacing: 0) { number; Circle().fill(color).frame(width: 2.5, height: 2.5) }
            }
        } else {
            number
        }
    }

    private var primary: Color { style.textColor.color }
    private var accent: Color { style.accentColor.color }
    private func eventColor(_ event: EKEvent) -> Color {
        if !settings.useNativeCalendarColors, let override = settings.eventColorOverride { return override.color }
        if settings.useNativeCalendarColors, let cgColor = event.calendar.cgColor, let native = NSColor(cgColor: cgColor) { return Color(nsColor: native) }
        return settings.eventColorOverride?.color ?? accent
    }
    private func dayTextColor(day: Date, inMonth: Bool, weekend: Bool, today: Bool) -> Color {
        if today && settings.highlightToday && settings.todayStyle == .accentText { return settings.todayColor?.color ?? accent }
        if !inMonth { return primary.opacity(settings.showAdjacentMonthDays ? 0.27 : 0) }
        if weekend {
            switch settings.weekendStyle { case .muted: return primary.opacity(0.45); case .accent: return accent.opacity(0.9); case .subtle: return primary.opacity(0.72); case .normal: break }
        }
        return primary
    }
    private func dayBackground(selected: Bool, today: Bool) -> Color {
        if selected && settings.highlightSelectedDay { return (settings.selectedDayColor?.color ?? accent).opacity(0.24) }
        if today && settings.highlightToday && settings.todayStyle == .subtleGlow {
            return (settings.todayColor?.color ?? accent).opacity(0.045)
        }
        return .clear
    }
    private func dateFont(_ designSize: Double) -> Font { styledCalendarFont(settings.dateTypography, size: designSize * settings.dateTypography.size / 14.0) }
    private func eventFont(_ designSize: Double) -> Font { styledCalendarFont(settings.eventTypography, size: designSize * settings.eventTypography.size / 12.0) }
    private func monthFont(_ designSize: Double) -> Font { styledCalendarFont(settings.monthTypography, size: designSize * settings.monthTypography.size / 13.0) }

    private func styledCalendarFont(_ typography: VisualCalendarTypography, size: Double) -> Font {
        let weight = typography.weight.swiftUIFontWeight
        let actual = max(7, min(56, size))
        if typography.fontFamily == .custom { return .custom(typography.customFont, size: actual).weight(weight) }
        let design: Font.Design
        switch typography.fontFamily { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: actual, weight: weight, design: design)
    }
    private func openCalendarApp() { _ = NSWorkspace.shared.launchApplication("Calendar") }
    private func openLocation(_ location: String) {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: location)]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }
}

struct CalendarModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: CalendarService
    @State private var selectedDate = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthAnchor = Calendar.autoupdatingCurrent.startOfDay(for: Date())
    @State private var monthEvents: [EKEvent] = []

    private var options: WidgetContentOptions { style.resolvedContent }
    private var calendar: Calendar { Calendar.autoupdatingCurrent }
    private var requestedView: CalendarWidgetViewStyle { options.resolvedCalendarViewStyle }
    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }
    private var effectiveView: CalendarWidgetViewStyle {
        let width = availableWidth ?? 360
        let height = availableHeight ?? 220
        let aspect = width / max(1, height)
        if height < 92 || (aspect > 2.25 && height < 170) { return requestedView == .agenda ? .agenda : .weekStrip }
        if width < 205 || (aspect < 0.68 && width < 255) { return .agenda }
        if presentation == .compact || width < 245 || height < 128 { return requestedView == .agenda ? .agenda : .weekStrip }
        if requestedView == .split && (width < 410 || height < 185) { return height >= 175 && width >= 285 ? .monthGrid : .agenda }
        return requestedView
    }

    var body: some View {
        Group {
            if let footprint {
                switch footprint {
                case .glance: glanceView
                case .horizontal: horizontalCompactView
                case .vertical: verticalCompactView
                case .standard, .expanded: requestedCalendarView
                }
            } else { requestedCalendarView }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment)
        .animation(.easeInOut(duration: 0.18), value: footprint)
        .onAppear { service.refresh(); loadMonth() }
        .onChange(of: monthAnchor) { _ in loadMonth() }
        .onChange(of: service.events.count) { _ in loadMonth() }
    }

    @ViewBuilder private var requestedCalendarView: some View {
        switch effectiveView {
        case .agenda: agendaView
        case .monthGrid: monthGridView
        case .weekStrip: weekStripView
        case .split: splitView
        }
    }

    private var glanceView: some View {
        VStack(spacing: 0) {
            Text(Date.now, format: .dateTime.month(.abbreviated).locale(.autoupdatingCurrent))
                .font(.system(size: 10, weight: .bold, design: .rounded)).textCase(.uppercase).foregroundStyle(style.accentColor.color)
            Text(Date.now, format: .dateTime.day())
                .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
            Text(Date.now, format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent))
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            if !service.events.isEmpty {
                Text("\(service.events.count) event\(service.events.count == 1 ? "" : "s")")
                    .font(.system(size: 8, weight: .medium)).foregroundStyle(style.accentColor.color).padding(.top, 3)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var horizontalCompactView: some View {
        HStack(spacing: 10) {
            VStack(spacing: -1) {
                Text(Date.now, format: .dateTime.month(.abbreviated).locale(.autoupdatingCurrent))
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(style.accentColor.color).textCase(.uppercase)
                Text(Date.now, format: .dateTime.day()).font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit()
            }.frame(minWidth: 38)
            Divider().opacity(0.35)
            if let next = service.upcomingEvents.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(next.title ?? "Untitled event").font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    if options.calendarShowTimes {
                        Text(next.isAllDay ? "All day" : next.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing scheduled").font(.system(size: 11, weight: .semibold))
                    Text(Date.now, format: .dateTime.weekday(.wide).locale(.autoupdatingCurrent)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var verticalCompactView: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Date.now, format: .dateTime.weekday(.wide).locale(.autoupdatingCurrent)).font(.system(size: 12, weight: .semibold))
                    Text(Date.now, format: .dateTime.month(.abbreviated).day().locale(.autoupdatingCurrent)).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(service.events.count)").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(style.accentColor.color)
            }
            ForEach(Array(service.upcomingEvents.prefix(2).enumerated()), id: \.offset) { _, event in
                compactEventRow(event)
            }
            if service.upcomingEvents.isEmpty { emptyDay }
            Spacer(minLength: 0)
        }
    }

    private func compactEventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(style.accentColor.color).frame(width: 2.5, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled event").font(.system(size: 10, weight: .semibold)).lineLimit(1)
                if options.calendarShowTimes { Text(event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened)).font(.system(size: 8)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
        }
    }

    private var agendaView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary", defaultPriority: .high) { dateHero }
            if let next = service.upcomingEvents.first { WidgetElement(key: "nextEvent", defaultPriority: .high) { eventRow(next, prominent: true) } }
            if presentation != .compact {
                WidgetElement(key: "events") {
                    VStack(spacing: max(5, options.spacing * 0.65)) {
                        ForEach(Array(service.upcomingEvents.prefix(options.maxItems).enumerated()), id: \.offset) { _, event in eventRow(event) }
                        if service.upcomingEvents.isEmpty { emptyDay }
                    }
                }
            }
            statusAndActions
        }
    }

    private var monthGridView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: max(5, options.spacing * 0.75)) {
            WidgetElement(key: "summary", defaultPriority: .high) { miniMonth }
            if options.showsCalendarAgendaBelowGrid && presentation != .compact { WidgetElement(key: "events") { selectedDayAgenda } }
            statusAndActions
        }
    }

    private var weekStripView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: max(5, options.spacing * 0.75)) {
            WidgetElement(key: "summary", defaultPriority: .high) {
                HStack(spacing: 5) { ForEach(weekDays, id: \.self) { day in weekDayButton(day) } }
            }
            if presentation != .compact { WidgetElement(key: "events") { selectedDayAgenda } }
            statusAndActions
        }
    }

    private var splitView: some View {
        VStack(spacing: max(4, options.spacing * 0.55)) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: max(8, options.spacing)) {
                    WidgetElement(key: "summary", defaultPriority: .high) { miniMonth }.frame(minWidth: 190)
                    Divider().opacity(0.35)
                    WidgetElement(key: "events") { selectedDayAgenda }.frame(minWidth: 170)
                }
                VStack(spacing: max(6, options.spacing * 0.7)) {
                    WidgetElement(key: "summary", defaultPriority: .high) { miniMonth }
                    WidgetElement(key: "events") { selectedDayAgenda }
                }
            }
            statusAndActions
        }
    }

    private var dateHero: some View {
        HStack(alignment: .center, spacing: 11) {
            VStack(spacing: -2) {
                Text(Date.now, format: .dateTime.month(.abbreviated).locale(.autoupdatingCurrent))
                    .font(.system(size: 11, weight: .bold, design: .rounded)).textCase(.uppercase).foregroundStyle(style.accentColor.color)
                Text(Date.now, format: .dateTime.day()).font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide)).font(.system(size: 15, weight: .semibold))
                Text(service.events.isEmpty ? "Your day is clear" : "\(service.events.count) event\(service.events.count == 1 ? "" : "s") left today")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var miniMonth: some View {
        VStack(spacing: 5) {
            HStack {
                if options.showControls { Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain) }
                Text(monthAnchor, format: .dateTime.month(.wide).year()).font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button("Today") { monthAnchor = calendar.startOfDay(for: Date()); selectedDate = monthAnchor }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(style.accentColor.color)
                if options.showControls { Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain) }
            }
            if options.showsCalendarWeekdayHeader {
                LazyVGrid(columns: dayColumns, spacing: 2) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in Text(symbol.uppercased()).font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary) }
                }
            }
            LazyVGrid(columns: dayColumns, spacing: 2) { ForEach(monthDays, id: \.self) { day in dayCell(day) } }
        }
    }

    private var selectedDayAgenda: some View {
        let events = events(on: selectedDate)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedDate, format: .dateTime.weekday(.wide)).font(.system(size: 13, weight: .semibold))
                    Text(selectedDate, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(events.isEmpty ? "Clear" : "\(events.count) event\(events.count == 1 ? "" : "s")").font(.caption2).foregroundStyle(.secondary)
            }
            if events.isEmpty { emptyDay }
            else { ForEach(Array(events.prefix(options.maxItems).enumerated()), id: \.offset) { _, event in eventRow(event) } }
        }
    }

    private var emptyDay: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles").foregroundStyle(style.accentColor.color)
            Text("Nothing scheduled").foregroundStyle(.secondary)
            Spacer()
        }.padding(.vertical, 6)
    }

    private func eventRow(_ event: EKEvent, prominent: Bool = false) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(style.accentColor.color).frame(width: 3, height: prominent ? 36 : 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled event").font(.system(size: prominent ? 13 : 12, weight: prominent ? .semibold : .medium)).lineLimit(1)
                HStack(spacing: 5) {
                    if options.calendarShowTimes { Text(event.isAllDay ? "All day" : event.startDate.formatted(date: calendar.isDateInToday(event.startDate) ? .omitted : .abbreviated, time: event.isAllDay ? .omitted : .shortened)) }
                    if let location = event.location, !location.isEmpty { Text(location).lineLimit(1) }
                }.font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) {
                Link(destination: url) { Image(systemName: "video.fill") }.buttonStyle(.bordered).controlSize(.mini).help("Join meeting")
            }
        }
        .padding(.horizontal, 8).padding(.vertical, prominent ? 7 : 5)
        .background(style.textColor.color.opacity(prominent ? 0.07 : 0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let eventCount = events(on: day).count
        return Button { selectedDate = calendar.startOfDay(for: day) } label: {
            VStack(spacing: 1) {
                Text(day, format: .dateTime.day())
                    .font(.system(size: 10, weight: today || selected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(inMonth ? style.textColor.color : style.textColor.color.opacity(options.showsCalendarAdjacentDays ? 0.28 : 0))
                if options.showsCalendarEventDots && eventCount > 0 && (inMonth || options.showsCalendarAdjacentDays) {
                    HStack(spacing: 1.5) { ForEach(0..<min(3, eventCount), id: \.self) { _ in Circle().fill(style.accentColor.color).frame(width: 2.5, height: 2.5) } }.frame(height: 3)
                } else { Color.clear.frame(height: 3) }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(selected ? style.accentColor.color.opacity(0.28) : today ? style.accentColor.color.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }.buttonStyle(.plain).disabled(!inMonth && !options.showsCalendarAdjacentDays)
    }

    private func weekDayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let count = events(on: day).count
        return Button { selectedDate = calendar.startOfDay(for: day); monthAnchor = day } label: {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                Text(day, format: .dateTime.day()).font(.system(size: 14, weight: selected || today ? .bold : .medium, design: .rounded))
                Circle().fill(count > 0 ? style.accentColor.color : Color.clear).frame(width: 4, height: 4)
            }.frame(maxWidth: .infinity).padding(.vertical, 6)
                .background(selected ? style.accentColor.color.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var statusAndActions: some View {
        if options.showStatus && presentation == .expanded { WidgetElement(key: "status", defaultPriority: .low) { Text(service.status) } }
        if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Enable / Refresh calendar") { service.requestAccess(); loadMonth() } } }
    }

    private var dayColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 2), count: 7) }
    private var weekdaySymbols: [String] {
        let values = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(0, min(6, calendar.firstWeekday - 1))
        return (0..<7).map { values[(offset + $0) % values.count] }
    }
    private var monthDays: [Date] {
        let start = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
        let grid = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: grid) }
    }
    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    private func events(on day: Date) -> [EKEvent] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return monthEvents.filter { $0.startDate < end && $0.endDate > start }
    }
    private func changeMonth(_ amount: Int) {
        monthAnchor = calendar.date(byAdding: .month, value: amount, to: monthAnchor) ?? monthAnchor
        selectedDate = calendar.dateInterval(of: .month, for: monthAnchor)?.start ?? monthAnchor
    }
    private func loadMonth() { monthEvents = service.events(around: monthAnchor) }
}

struct ClipboardModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: ClipboardService
    let enabled: Bool
    @State private var search = ""
    private var footprint: VisualWorkspaceWidgetSize? { VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation) }

    var body: some View {
        let options = style.resolvedContent
        Group {
            if !enabled { disabledState }
            else {
                switch footprint {
                case .glance: clipboardGlance
                case .horizontal: clipboardHorizontal
                case .vertical: clipboardVertical
                case .standard, .expanded, .none: clipboardFull
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment)
    }

    private var disabledState: some View {
        VStack(spacing: 5) {
            Image(systemName: "clipboard").foregroundStyle(style.accentColor.color)
            Text(footprint?.isCompact == true ? "Clipboard off" : "Clipboard history is off. Enable it in Privacy settings.")
                .font(footprint?.isCompact == true ? .caption : .body).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
    private var clipboardGlance: some View {
        VStack(spacing: 4) {
            Image(systemName: "doc.on.clipboard").font(.system(size: 20)).foregroundStyle(style.accentColor.color)
            Text("\(service.entries.count)").font(.system(size: 25, weight: .bold, design: .rounded)).monospacedDigit()
            if let newest = service.entries.first { Text(newest.text).font(.system(size: 9)).lineLimit(1).foregroundStyle(.secondary) }
        }
    }
    private var clipboardHorizontal: some View {
        HStack(spacing: 8) {
            Label("\(service.entries.count)", systemImage: "doc.on.clipboard").foregroundStyle(style.accentColor.color)
            Divider().opacity(0.35)
            Text(service.entries.first?.text ?? "Clipboard is empty").lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var clipboardVertical: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("\(service.entries.count) entries", systemImage: "doc.on.clipboard").font(.system(size: 12, weight: .semibold))
            ForEach(Array(service.entries.prefix(2))) { entry in
                Text(entry.text).font(.system(size: 10)).lineLimit(3).padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }
            if service.entries.isEmpty { Text("Clipboard is empty").foregroundStyle(.secondary) }
        }
    }
    private var clipboardFull: some View {
        let options = style.resolvedContent
        let effectiveSearch = options.showSearch ? search : ""
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary", defaultPriority: .high) {
                HStack { Label("\(service.entries.count) entries", systemImage: "doc.on.clipboard"); Spacer(); if let newest = service.entries.first { Text(newest.date, style: .relative).foregroundStyle(.secondary) } }
            }
            if options.showSearch && presentation != .compact { WidgetElement(key: "search") { TextField("Search clipboard", text: $search) } }
            WidgetElement(key: "entries") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: presentation == .expanded ? 150 : 220), spacing: 7)], spacing: 7) {
                    ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(presentation == .compact ? 1 : options.maxItems))) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Image(systemName: "quote.opening").font(.caption).foregroundStyle(style.accentColor.color); Spacer(); Text(entry.date, style: .relative).font(.caption2).foregroundStyle(.secondary) }
                            Text(entry.text).lineLimit(presentation == .expanded ? 4 : 2).frame(maxWidth: .infinity, alignment: .leading)
                            if options.showControls {
                                HStack(spacing: 5) {
                                    Button("Copy") { service.copy(entry) }.buttonStyle(.bordered).controlSize(.mini)
                                    Spacer(); Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                                }
                            }
                        }.padding(8).background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
            if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Clear history") { service.reset() } } }
            if options.showFooter && presentation == .expanded { WidgetElement(key: "footer", defaultPriority: .optional) { Text("Text only · up to 50 items · memory only") } }
        }
    }
}

struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: SystemService
    private var options: WidgetContentOptions { style.resolvedContent }
    private var footprint: VisualWorkspaceWidgetSize? { VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation) }

    var body: some View {
        Group {
            switch footprint {
            case .glance: systemGlance
            case .horizontal: systemHorizontal
            case .vertical: systemVertical
            case .standard, .expanded, .none: systemFull
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment)
    }

    private var systemGlance: some View {
        VStack(spacing: 2) {
            Image(systemName: "cpu").font(.system(size: 17, weight: .semibold)).foregroundStyle(style.accentColor.color)
            Text(String(format: "%.0f%%", service.cpuUsage)).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
            Text("CPU").font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
        }
    }
    private var systemHorizontal: some View {
        HStack(spacing: 8) {
            CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color)
            Divider().opacity(0.3)
            CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color)
        }
    }
    private var systemVertical: some View {
        VStack(spacing: 7) {
            CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color)
            CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color)
            if options.systemBattery, let battery = service.battery { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
        }
    }
    private var systemFull: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if presentation == .compact {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                        WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                        if options.systemBattery, let battery = service.battery { WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) } }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 5)], spacing: 5) {
                        WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                        WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                        if options.systemBattery, let battery = service.battery { WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) } }
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { MetricTile(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color, showProgress: options.showProgress) }
                    WidgetElement(key: "memoryUsage", defaultPriority: .high) { MetricTile(label: "Memory", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color, showProgress: options.showProgress) }
                    WidgetElement(key: "diskUsage", defaultPriority: .normal) { MetricTile(label: "Disk", value: service.diskUsage, icon: "internaldrive", accent: style.accentColor.color, showProgress: options.showProgress) }
                    if options.systemBattery, let battery = service.battery { WidgetElement(key: "battery", defaultPriority: .high) { MetricTile(label: service.charging ? "Charging" : "Battery", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color, showProgress: options.showProgress) } }
                }
                WidgetElement(key: "network", defaultPriority: .normal) {
                    HStack(spacing: 8) { Label("Network", systemImage: "arrow.up.arrow.down"); Spacer(); Text("↓ \(Self.rate(service.networkDownPerSecond))").monospacedDigit(); Text("↑ \(Self.rate(service.networkUpPerSecond))").monospacedDigit() }
                }
                WidgetElement(key: "power", defaultPriority: .normal) {
                    HStack { Label(service.lowPower ? "Low Power Mode" : "Normal power", systemImage: service.lowPower ? "leaf.fill" : "bolt.fill"); Spacer(); Text(service.onBattery ? "Battery" : "External power").foregroundStyle(.secondary) }
                }
            }
            if presentation == .expanded {
                WidgetElement(key: "graphs", defaultVisible: false, defaultPriority: .optional) { VStack(spacing: 8) { MiniMetricGraph(title: "CPU", values: service.cpuHistory, accent: style.accentColor.color); MiniMetricGraph(title: "Memory", values: service.memoryHistory, accent: style.accentColor.color.opacity(0.75)); MiniMetricGraph(title: "Network", values: service.networkHistory, accent: style.accentColor.color.opacity(0.55)) } }
                WidgetElement(key: "swap", defaultVisible: false, defaultPriority: .low) { MetricRow(label: "Swap", value: service.swapUsage, icon: "arrow.triangle.swap") }
                WidgetElement(key: "thermal", defaultVisible: false, defaultPriority: .low) { HStack { Label("Thermal", systemImage: "thermometer.medium"); Spacer(); Text(service.thermalState) } }
                if options.systemMemory { WidgetElement(key: "memory", defaultPriority: .low) { Label(service.memory, systemImage: "memorychip") } }
                if options.systemStorage { WidgetElement(key: "storage", defaultPriority: .low) { Label(service.storage, systemImage: "internaldrive") } }
                if options.systemUptime { WidgetElement(key: "uptime", defaultPriority: .low) { Label(service.uptime, systemImage: "clock.arrow.circlepath") } }
                WidgetElement(key: "device", defaultVisible: false, defaultPriority: .optional) { VStack(alignment: options.alignment.horizontal, spacing: 3) { Text(ProcessInfo.processInfo.operatingSystemVersionString); Text("\(ProcessInfo.processInfo.processorCount) logical processors").foregroundStyle(.secondary) } }
            }
        }
    }
    private static func rate(_ value: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file) + "/s" }
}

private struct CompactMetric: View {
    let label: String; let value: Double; let icon: String; let accent: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.0f%%", value)).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(label).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct MetricTile: View {
    let label: String; let value: Double; let icon: String; let accent: Color; let showProgress: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                    .frame(width: 26, height: 26).background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer(); Text(String(format: "%.0f%%", value)).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
            if showProgress { ProgressView(value: value, total: 100).controlSize(.mini) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct MetricRow: View {
    let label: String; let value: Double; let icon: String
    var body: some View { VStack(spacing: 4) { HStack { Label(label, systemImage: icon); Spacer(); Text(String(format: "%.0f%%", value)).monospacedDigit() }; ProgressView(value: value, total: 100) } }
}
private struct MiniMetricGraph: View {
    let title: String; let values: [Double]; let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            GeometryReader { proxy in
                Path { path in
                    guard values.count > 1 else { return }
                    let step = proxy.size.width / CGFloat(values.count - 1)
                    for (index, value) in values.enumerated() {
                        let point = CGPoint(x: CGFloat(index) * step, y: proxy.size.height * (1 - CGFloat(min(100, max(0, value)) / 100)))
                        index == 0 ? path.move(to: point) : path.addLine(to: point)
                    }
                }.stroke(accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }.frame(height: 30)
        }
    }
}

struct LauncherModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @State private var query = ""
    private var footprint: VisualWorkspaceWidgetSize? { VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation) }

    var body: some View {
        let options = style.resolvedContent
        Group {
            switch footprint {
            case .glance: launcherGlance
            case .horizontal: launcherHorizontal
            case .vertical: launcherVertical
            case .standard, .expanded, .none: launcherFull
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: options.alignment.alignment).onAppear { workspace.refreshApps() }
    }

    @ViewBuilder private var launcherGlance: some View {
        if let app = workspace.runningApps.first {
            Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                VStack(spacing: 5) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: 34, height: 34) }
                    else { Image(systemName: "app.fill").font(.system(size: 28)).foregroundStyle(style.accentColor.color) }
                    Text(app.localizedName ?? "Application").font(.system(size: 9, weight: .medium)).lineLimit(1)
                }
            }.buttonStyle(.plain)
        } else {
            VStack(spacing: 4) { Image(systemName: "square.grid.2x2").font(.system(size: 25)).foregroundStyle(style.accentColor.color); Text("Apps").font(.caption2) }
        }
    }
    private var launcherHorizontal: some View {
        HStack(spacing: 7) {
            ForEach(Array(workspace.runningApps.prefix(3)), id: \.processIdentifier) { app in appButton(app, vertical: false) }
            if workspace.runningApps.isEmpty { Label("No running apps", systemImage: "square.grid.2x2").foregroundStyle(.secondary) }
        }
    }
    private var launcherVertical: some View {
        VStack(spacing: 7) {
            ForEach(Array(workspace.runningApps.prefix(3)), id: \.processIdentifier) { app in appButton(app, vertical: true) }
            if workspace.runningApps.isEmpty { Label("No running apps", systemImage: "square.grid.2x2").foregroundStyle(.secondary) }
        }
    }
    private var launcherFull: some View {
        let options = style.resolvedContent
        let effectiveQuery = options.showSearch ? query : ""
        return VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary", defaultVisible: false) { HStack { Label("\(workspace.runningApps.count) apps", systemImage: "square.grid.2x2"); Spacer(); Text("\(workspace.plugins.reduce(0) { $0 + $1.commands.count }) plugin commands") } }
            if options.showSearch { WidgetElement(key: "search") { TextField("Search apps and commands", text: $query) } }
            if options.launcherTimers { WidgetElement(key: "timers") { HStack { ForEach([5, 15, 25], id: \.self) { minutes in Button("\(minutes)m") { store.startTimer(minutes: minutes) } } } } }
            if options.launcherRunningApps {
                WidgetElement(key: "apps") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 7)], spacing: 7) {
                        ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \.processIdentifier) { app in
                            Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                                VStack(spacing: 5) {
                                    if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: 30, height: 30) }
                                    else { Image(systemName: "app.fill").font(.system(size: 24)).foregroundStyle(style.accentColor.color) }
                                    Text(app.localizedName ?? "Application").font(.caption2).lineLimit(1)
                                }.frame(maxWidth: .infinity).padding(.vertical, 7).padding(.horizontal, 4)
                                    .background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if options.launcherPlugins && presentation != .compact {
                WidgetElement(key: "plugins") {
                    VStack(alignment: options.alignment.horizontal, spacing: max(4, options.spacing * 0.65)) {
                        ForEach(workspace.plugins) { plugin in ForEach(plugin.commands.filter { CommandSearch.matches(effectiveQuery, in: $0.title) }.prefix(options.maxItems)) { command in Button(command.title) { workspace.run(command) } } }
                    }
                }
            }
            if options.showQuickActions && presentation == .expanded {
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
        }
    }

    private func appButton(_ app: NSRunningApplication, vertical: Bool) -> some View {
        Button { app.activate(options: .activateIgnoringOtherApps) } label: {
            Group {
                if vertical {
                    HStack(spacing: 7) {
                        appIcon(app, size: 22)
                        Text(app.localizedName ?? "Application").font(.system(size: 10, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(spacing: 3) {
                        appIcon(app, size: 25)
                        Text(app.localizedName ?? "App").font(.system(size: 8, weight: .medium)).lineLimit(1)
                    }
                }
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
    }
    @ViewBuilder private func appIcon(_ app: NSRunningApplication, size: CGFloat) -> some View {
        if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: size, height: size) }
        else { Image(systemName: "app.fill").font(.system(size: size * 0.8)).foregroundStyle(style.accentColor.color) }
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
    var body: some View { material.overlay { GrainOverlay(options: appearance.grain ?? GrainOptions()) } }
    @ViewBuilder private var material: some View {
        if appearance.background == .glass {
            if reduceTransparency { Color.black }
            else { DesktopGlass().overlay(Color.black.opacity(GlassRendering.tintOpacity(themeOpacity: theme.opacity))) }
        } else { decoratedBackground }
    }
    private var decoratedBackground: some View {
        ZStack {
            Color.black.opacity(reduceTransparency ? 1 : theme.opacity)
            switch appearance.background {
            case .solid: (appearance.solidColor?.color ?? Color.black).opacity(reduceTransparency ? 1 : theme.opacity)
            case .glass: EmptyView()
            case .gradient:
                LinearGradient(colors: [appearance.gradientStartColor?.color ?? Color(hue: theme.tint, saturation: 0.7, brightness: 0.35), appearance.gradientEndColor?.color ?? Color.black], startPoint: .bottomLeading, endPoint: .topTrailing)
            case .image: CachedBackgroundImage(path: appearance.assetPath)
            case .video: LoopingVideo(path: appearance.assetPath, playing: expanded && !(appearance.pauseVideoOnBattery && system.onBattery))
            }
        }.blur(radius: reduceTransparency ? 0 : appearance.blur).saturation(appearance.saturation).brightness(appearance.brightness)
    }
}
/// Native backdrop sampling must stay out of SwiftUI blur/offscreen filter groups.
struct DesktopGlass: NSViewRepresentable {
    final class EffectView: NSVisualEffectView { override func hitTest(_ point: NSPoint) -> NSView? { nil } }
    func makeNSView(context: Context) -> EffectView {
        let view = EffectView(); view.blendingMode = .behindWindow; view.material = .hudWindow; view.state = .active; view.appearance = NSAppearance(named: .darkAqua); return view
    }
    func updateNSView(_ view: EffectView, context: Context) {}
}
struct CachedBackgroundImage: View {
    let path: String
    @State private var image: NSImage?
    var body: some View {
        Group { if let image { Image(nsImage: image).resizable().scaledToFill() } else { Color.clear } }
            .task(id: path) {
                image = nil
                let currentPath = path
                let decoded = await Task.detached(priority: .utility) { () -> CGImage? in
                    guard !currentPath.isEmpty, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: currentPath) as CFURL, nil) else { return nil }
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1280, kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
                }.value
                guard !Task.isCancelled else { return }
                if let decoded { image = NSImage(cgImage: decoded, size: .zero) }
            }
    }
}
struct LoopingVideo: NSViewRepresentable {
    let path: String
    let playing: Bool
    final class Coordinator { var path = ""; var player = AVQueuePlayer(); var looper: AVPlayerLooper?; var playing = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView(); view.controlsStyle = .none; view.videoGravity = .resizeAspectFill; view.player = context.coordinator.player; context.coordinator.player.isMuted = true; return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {
        let state = context.coordinator
        if state.path != path {
            state.player.pause(); state.playing = false; state.looper = nil; state.player.removeAllItems(); state.path = path
            if FileManager.default.fileExists(atPath: path) { state.looper = AVPlayerLooper(player: state.player, templateItem: AVPlayerItem(url: URL(fileURLWithPath: path))) }
        }
        if state.playing != playing { state.playing = playing; if playing { state.player.play() } else { state.player.pause() } }
    }
    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) { coordinator.player.pause(); coordinator.looper = nil; coordinator.player.removeAllItems() }
}
