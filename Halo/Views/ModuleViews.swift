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
    @Environment(\.openNotchAvailableHeight) private var availableHeight
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
            WidgetElement(key: "summary", defaultPriority: .high) {
                Label("\(workspace.activities.count) live activit\(workspace.activities.count == 1 ? "y" : "ies")", systemImage: "waveform.path")
            }
            if workspace.activities.isEmpty, options.showStatus, presentation != .compact {
                WidgetElement(key: "status") {
                    Text("Timer completions and live progress appear here.").foregroundStyle(.secondary)
                }
            }
            if presentation != .compact { WidgetElement(key: "items") {
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
            } }
        case .notes:
            if presentation != .compact { WidgetElement(key: "stats", defaultPriority: .low) {
                let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count
                HStack { Label("\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\(workspace.settings.notes.count) chars") }
            } }
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
            if presentation == .expanded { WidgetElement(key: "actions", defaultVisible: false, defaultPriority: .low) {
                HStack {
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(workspace.settings.notes, forType: .string) }
                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)
                }
            } }
        case .capture:
            CaptureModuleView(service: workspace.capture, store: store)
        case .stopwatch:
            if presentation != .compact { WidgetElement(key: "state", defaultPriority: .low) {
                Label(workspace.stopwatchStart == nil ? (workspace.stopwatchElapsed > 0 ? "Paused" : "Ready") : "Running",
                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")
            } }
            WidgetElement(key: "time", defaultPriority: .alwaysVisible) {
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { context.date.timeIntervalSince($0) } ?? 0)
                    let whole = Int(elapsed)
                    Text(String(format: "%02d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60))
                        .font(style.font(scale: options.stopwatchScale)).monospacedDigit()
                }
            }
            if options.showControls {
                WidgetElement(key: "controls", defaultPriority: .high) {
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
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: MediaService
    let app: String
    private var options: WidgetContentOptions { style.resolvedContent }
    private var artworkStyle: WidgetElementStyle { style.elementStyle(for: "artwork") }
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
            switch presentation {
            case .compact:
                if (availableWidth ?? 200) < 150 || (availableHeight ?? 100) < 82 { microCompact }
                else { compact }
            case .expanded: expanded
            case .regular, .automatic: regular
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.setArtworkEnabled(true) }
    }

    private var microCompact: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                if let image = service.artworkImage {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: min(38, max(26, (availableHeight ?? 70) * 0.38)),
                               height: min(38, max(26, (availableHeight ?? 70) * 0.38)))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Text(service.title).font(.system(size: 10, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            if options.showControls, service.connectedApp != nil {
                Button { service.perform("playpause", app: app) } label: {
                    Image(systemName: service.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compact: some View {
        HStack(spacing: max(6, options.spacing)) {
            if let image = service.artworkImage {
                WidgetElement(key: "artwork", defaultPriority: .normal) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: compactArtworkSize, height: compactArtworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: min(14, compactArtworkSize * 0.18), style: .continuous))
                }
                .frame(width: compactArtworkSize + 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                WidgetElement(key: "track", defaultPriority: .alwaysVisible) { Text(service.title).lineLimit(1) }
                if options.mediaShowArtist && !service.artist.isEmpty { WidgetElement(key: "artist", defaultPriority: .low) { Text(service.artist).lineLimit(1) } }
            }
            Spacer(minLength: 4)
            if options.showControls, service.connectedApp != nil {
                WidgetElement(key: "controls", defaultPriority: .high) { Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") } }
            }
        }
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
            // Lyrics intentionally render nothing until a supported player exposes real lyric data.
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
    @ObservedObject var service: AudioService
    private var options: WidgetContentOptions { style.resolvedContent }
    private var selectedName: String { service.devices.first(where: { $0.id == service.selected })?.name ?? "Audio Output" }

    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
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
                WidgetElement(key: "volume") {
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
                    }
                    .labelsHidden()
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
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.refresh() }
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
    private var effectiveView: CalendarWidgetViewStyle {
        let width = availableWidth ?? 360
        let height = availableHeight ?? 220
        let aspect = width / max(1, height)
        if height < 92 || (aspect > 2.25 && height < 170) {
            return requestedView == .agenda ? .agenda : .weekStrip
        }
        if width < 205 || (aspect < 0.68 && width < 255) {
            return .agenda
        }
        if presentation == .compact || width < 245 || height < 128 {
            return requestedView == .agenda ? .agenda : .weekStrip
        }
        if requestedView == .split && (width < 410 || height < 185) {
            return height >= 175 && width >= 285 ? .monthGrid : .agenda
        }
        return requestedView
    }

    var body: some View {
        Group {
            switch effectiveView {
            case .agenda: agendaView
            case .monthGrid: monthGridView
            case .weekStrip: weekStripView
            case .split: splitView
            }
        }
        .frame(maxWidth: .infinity, alignment: options.alignment.alignment)
        .onAppear { service.refresh(); loadMonth() }
        .onChange(of: monthAnchor) { _ in loadMonth() }
        .onChange(of: service.events.count) { _ in loadMonth() }
    }

    private var agendaView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") { dateHero }
            if let next = service.upcomingEvents.first {
                WidgetElement(key: "nextEvent") { eventRow(next, prominent: true) }
            }
            if presentation != .compact {
                WidgetElement(key: "events") {
                    VStack(spacing: max(5, options.spacing * 0.65)) {
                        ForEach(Array(service.upcomingEvents.prefix(options.maxItems).enumerated()), id: \.offset) { _, event in
                            eventRow(event)
                        }
                        if service.upcomingEvents.isEmpty { emptyDay }
                    }
                }
            }
            statusAndActions
        }
    }

    private var monthGridView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: max(5, options.spacing * 0.75)) {
            WidgetElement(key: "summary") { miniMonth }
            if options.showsCalendarAgendaBelowGrid && presentation != .compact {
                WidgetElement(key: "events") { selectedDayAgenda }
            }
            statusAndActions
        }
    }

    private var weekStripView: some View {
        VStack(alignment: options.alignment.horizontal, spacing: max(5, options.spacing * 0.75)) {
            WidgetElement(key: "summary") {
                HStack(spacing: 5) {
                    ForEach(weekDays, id: \.self) { day in weekDayButton(day) }
                }
            }
            if presentation != .compact { WidgetElement(key: "events") { selectedDayAgenda } }
            statusAndActions
        }
    }

    private var splitView: some View {
        VStack(spacing: max(4, options.spacing * 0.55)) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: max(8, options.spacing)) {
                    WidgetElement(key: "summary") { miniMonth }.frame(minWidth: 190)
                    Divider().opacity(0.35)
                    WidgetElement(key: "events") { selectedDayAgenda }.frame(minWidth: 170)
                }
                VStack(spacing: max(6, options.spacing * 0.7)) {
                    WidgetElement(key: "summary") { miniMonth }
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
                Text(Date.now, format: .dateTime.day())
                    .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
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
                if options.showControls {
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain)
                }
                Text(monthAnchor, format: .dateTime.month(.wide).year())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button("Today") { monthAnchor = calendar.startOfDay(for: Date()); selectedDate = monthAnchor }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(style.accentColor.color)
                if options.showControls {
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain)
                }
            }
            if options.showsCalendarWeekdayHeader {
                LazyVGrid(columns: dayColumns, spacing: 2) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased()).font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            LazyVGrid(columns: dayColumns, spacing: 2) {
                ForEach(monthDays, id: \.self) { day in dayCell(day) }
            }
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
                Text(events.isEmpty ? "Clear" : "\(events.count) event\(events.count == 1 ? "" : "s")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if events.isEmpty { emptyDay }
            else {
                ForEach(Array(events.prefix(options.maxItems).enumerated()), id: \.offset) { _, event in eventRow(event) }
            }
        }
    }

    private var emptyDay: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles").foregroundStyle(style.accentColor.color)
            Text("Nothing scheduled").foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func eventRow(_ event: EKEvent, prominent: Bool = false) -> some View {
        HStack(spacing: 8) {
            Capsule().fill(style.accentColor.color).frame(width: 3, height: prominent ? 36 : 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled event")
                    .font(.system(size: prominent ? 13 : 12, weight: prominent ? .semibold : .medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if options.calendarShowTimes {
                        Text(event.isAllDay ? "All day" : event.startDate.formatted(date: calendar.isDateInToday(event.startDate) ? .omitted : .abbreviated, time: event.isAllDay ? .omitted : .shortened))
                    }
                    if let location = event.location, !location.isEmpty { Text(location).lineLimit(1) }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if options.calendarShowJoin && options.showControls, let url = service.meetingURL(for: event) {
                Link(destination: url) { Image(systemName: "video.fill") }
                    .buttonStyle(.bordered).controlSize(.mini).help("Join meeting")
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
        return Button {
            selectedDate = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 1) {
                Text(day, format: .dateTime.day())
                    .font(.system(size: 10, weight: today || selected ? .bold : .regular, design: .rounded))
                    .foregroundStyle(inMonth ? style.textColor.color : style.textColor.color.opacity(options.showsCalendarAdjacentDays ? 0.28 : 0))
                if options.showsCalendarEventDots && eventCount > 0 && (inMonth || options.showsCalendarAdjacentDays) {
                    HStack(spacing: 1.5) {
                        ForEach(0..<min(3, eventCount), id: \.self) { _ in Circle().fill(style.accentColor.color).frame(width: 2.5, height: 2.5) }
                    }.frame(height: 3)
                } else { Color.clear.frame(height: 3) }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(selected ? style.accentColor.color.opacity(0.28) : today ? style.accentColor.color.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!inMonth && !options.showsCalendarAdjacentDays)
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
            }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(selected ? style.accentColor.color.opacity(0.22) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var statusAndActions: some View {
        if options.showStatus && presentation == .expanded {
            WidgetElement(key: "status", defaultPriority: .low) { Text(service.status) }
        }
        if options.showQuickActions && presentation == .expanded {
            WidgetElement(key: "actions", defaultPriority: .low) { Button("Enable / Refresh calendar") { service.requestAccess(); loadMonth() } }
        }
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
                if options.showSearch && presentation != .compact { WidgetElement(key: "search") { TextField("Search clipboard", text: $search) } }
                let effectiveSearch = options.showSearch ? search : ""
                WidgetElement(key: "entries") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: presentation == .expanded ? 150 : 220), spacing: 7)], spacing: 7) {
                        ForEach(Array(service.entries.filter { effectiveSearch.isEmpty || $0.text.localizedCaseInsensitiveContains(effectiveSearch) }.prefix(presentation == .compact ? 1 : options.maxItems))) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "quote.opening").font(.caption).foregroundStyle(style.accentColor.color)
                                    Spacer()
                                    Text(entry.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                                }
                                Text(entry.text).lineLimit(presentation == .expanded ? 4 : 2).frame(maxWidth: .infinity, alignment: .leading)
                                if options.showControls {
                                    HStack(spacing: 5) {
                                        Button("Copy") { service.copy(entry) }.buttonStyle(.bordered).controlSize(.mini)
                                        Spacer()
                                        Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                    }
                }
                if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Clear history") { service.reset() } } }
                if options.showFooter && presentation == .expanded { WidgetElement(key: "footer", defaultPriority: .optional) { Text("Text only · up to 50 items · memory only") } }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
    }
}

struct SystemModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchPresentation) private var presentation
    @ObservedObject var service: SystemService
    private var options: WidgetContentOptions { style.resolvedContent }

    var body: some View {
        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if presentation == .compact {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                        WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                        if options.systemBattery, let battery = service.battery {
                            WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 5)], spacing: 5) {
                        WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                        WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                        if options.systemBattery, let battery = service.battery {
                            WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
                        }
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { MetricTile(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color, showProgress: options.showProgress) }
                    WidgetElement(key: "memoryUsage", defaultPriority: .high) { MetricTile(label: "Memory", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color, showProgress: options.showProgress) }
                    WidgetElement(key: "diskUsage", defaultPriority: .normal) { MetricTile(label: "Disk", value: service.diskUsage, icon: "internaldrive", accent: style.accentColor.color, showProgress: options.showProgress) }
                    if options.systemBattery, let battery = service.battery {
                        WidgetElement(key: "battery", defaultPriority: .high) { MetricTile(label: service.charging ? "Charging" : "Battery", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color, showProgress: options.showProgress) }
                    }
                }
                WidgetElement(key: "network", defaultPriority: .normal) {
                    HStack(spacing: 8) {
                        Label("Network", systemImage: "arrow.up.arrow.down")
                        Spacer()
                        Text("↓ \(Self.rate(service.networkDownPerSecond))").monospacedDigit()
                        Text("↑ \(Self.rate(service.networkUpPerSecond))").monospacedDigit()
                    }
                }
                WidgetElement(key: "power", defaultPriority: .normal) {
                    HStack {
                        Label(service.lowPower ? "Low Power Mode" : "Normal power", systemImage: service.lowPower ? "leaf.fill" : "bolt.fill")
                        Spacer(); Text(service.onBattery ? "Battery" : "External power").foregroundStyle(.secondary)
                    }
                }
            }
            if presentation == .expanded {
                WidgetElement(key: "graphs", defaultVisible: false, defaultPriority: .optional) {
                    VStack(spacing: 8) { MiniMetricGraph(title: "CPU", values: service.cpuHistory, accent: style.accentColor.color); MiniMetricGraph(title: "Memory", values: service.memoryHistory, accent: style.accentColor.color.opacity(0.75)); MiniMetricGraph(title: "Network", values: service.networkHistory, accent: style.accentColor.color.opacity(0.55)) }
                }
                WidgetElement(key: "swap", defaultVisible: false, defaultPriority: .low) { MetricRow(label: "Swap", value: service.swapUsage, icon: "arrow.triangle.swap") }
                WidgetElement(key: "thermal", defaultVisible: false, defaultPriority: .low) { HStack { Label("Thermal", systemImage: "thermometer.medium"); Spacer(); Text(service.thermalState) } }
                if options.systemMemory { WidgetElement(key: "memory", defaultPriority: .low) { Label(service.memory, systemImage: "memorychip") } }
                if options.systemStorage { WidgetElement(key: "storage", defaultPriority: .low) { Label(service.storage, systemImage: "internaldrive") } }
                if options.systemUptime { WidgetElement(key: "uptime", defaultPriority: .low) { Label(service.uptime, systemImage: "clock.arrow.circlepath") } }
                WidgetElement(key: "device", defaultVisible: false, defaultPriority: .optional) { VStack(alignment: options.alignment.horizontal, spacing: 3) { Text(ProcessInfo.processInfo.operatingSystemVersionString); Text("\(ProcessInfo.processInfo.processorCount) logical processors").foregroundStyle(.secondary) } }
            }
        }.frame(maxWidth: .infinity, alignment: options.alignment.alignment)
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
                Spacer()
                Text(String(format: "%.0f%%", value)).font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 7)], spacing: 7) {
                        ForEach(Array(workspace.runningApps.filter { CommandSearch.matches(effectiveQuery, in: $0.localizedName ?? "") }.prefix(options.maxItems)), id: \.processIdentifier) { app in
                            Button { app.activate(options: .activateIgnoringOtherApps) } label: {
                                VStack(spacing: 5) {
                                    if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: 30, height: 30) }
                                    else { Image(systemName: "app.fill").font(.system(size: 24)).foregroundStyle(style.accentColor.color) }
                                    Text(app.localizedName ?? "Application").font(.caption2).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 7).padding(.horizontal, 4)
                                .background(style.textColor.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if options.launcherPlugins && presentation != .compact {
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