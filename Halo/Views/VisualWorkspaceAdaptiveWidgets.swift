import SwiftUI
import AppKit

// Visual Workspace-only adaptive renderers. The regular opened-notch widgets continue using
// their existing views; these renderers are selected only when an exact grid footprint exists.

enum VisualAdaptiveFamily: String, Equatable {
    case micro, compact, horizontal, vertical, standard, expanded, dashboard, hero

    var informationCapacity: Int {
        switch self {
        case .micro: return 2
        case .compact: return 3
        case .horizontal, .vertical: return 5
        case .standard: return 6
        case .expanded: return 8
        case .dashboard: return 10
        case .hero: return 14
        }
    }
}


private extension VisualAdaptivePresentation {
    var family: VisualAdaptiveFamily {
        switch self {
        case .automatic, .standard: return .standard
        case .micro: return .micro
        case .compact: return .compact
        case .horizontal: return .horizontal
        case .vertical: return .vertical
        case .expanded: return .expanded
        case .dashboard: return .dashboard
        case .hero: return .hero
        }
    }
}

enum VisualAdaptiveFamilyResolver {
    static func resolve(module: ModuleID,
                        columns: Int,
                        rows: Int,
                        width: CGFloat?,
                        height: CGFloat?,
                        requested: VisualAdaptivePresentation,
                        previous: VisualAdaptiveFamily? = nil) -> VisualAdaptiveFamily {
        if requested != .automatic { return requested.family }
        let c = min(8, max(1, columns))
        let r = min(4, max(1, rows))
        if c == 1 && r == 1 { return .micro }
        if r == 1 { return c == 2 ? .compact : .horizontal }
        if c == 1 { return .vertical }
        if c == 2 && r == 2 { return .compact }
        if c <= 3 && r <= 2 { return .standard }
        if c <= 2 && r >= 3 { return .vertical }
        if c >= 7 && r == 4 { return .hero }
        if c >= 6 && r >= 3 { return .dashboard }
        if c >= 4 && r >= 3 { return .expanded }
        if c >= 4 && r == 2 { return .expanded }
        if c >= 3 && r >= 3 { return .expanded }

        // Point-size fallback is primarily for previews and unusual custom surfaces. Keep a small
        // hysteresis band around the previous family so continuous resizing does not chatter.
        let w = width ?? CGFloat(c * 100)
        let h = height ?? CGFloat(r * 100)
        let aspect = w / max(1, h)
        if let previous {
            switch previous {
            case .horizontal where aspect > 1.85: return .horizontal
            case .vertical where aspect < 0.72: return .vertical
            case .hero where w > 630 && h > 300: return .hero
            case .dashboard where w > 470 && h > 230: return .dashboard
            default: break
            }
        }
        if w < 120 && h < 120 { return .micro }
        if aspect > 2.3 { return .horizontal }
        if aspect < 0.62 { return .vertical }
        if w > 690 && h > 320 { return .hero }
        if w > 520 && h > 250 { return .dashboard }
        if w > 330 && h > 210 { return .expanded }
        return .standard
    }
}

private extension VisualAdaptiveDensity {
    var spacingScale: CGFloat {
        switch self { case .compact: return 0.72; case .comfortable: return 1; case .spacious: return 1.28 }
    }
}

private extension VisualAdaptiveArtworkShape {
    @ViewBuilder func clip<V: View>(_ view: V, radius: CGFloat) -> some View {
        switch self {
        case .rounded: view.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .square: view.clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        case .circle: view.clipShape(Circle())
        }
    }
}

private struct AdaptiveHeader: View {
    let title: String
    let symbol: String
    let style: WidgetStyle
    var body: some View {
        HStack(spacing: 6) {
            if style.showsHeaderIcon { Image(systemName: symbol).foregroundStyle(style.accentColor.color) }
            Text(title).font(style.font(scale: 0.9)).fontWeight(.semibold)
            Spacer(minLength: 0)
        }
    }
}

private struct AdaptiveProgressBar: View {
    let progress: Double
    let accent: Color
    let thickness: CGFloat
    var body: some View {
        GeometryReader { proxy in
            Capsule().fill(Color.primary.opacity(0.09))
                .overlay(alignment: .leading) {
                    Capsule().fill(accent).frame(width: max(thickness, proxy.size.width * min(1, max(0, progress))))
                }
        }.frame(height: thickness)
    }
}

private struct AdaptiveMicroRing<Content: View>: View {
    let progress: Double?
    let accent: Color
    private let content: Content

    init(progress: Double?, accent: Color, @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let side = max(38, min(proxy.size.width, proxy.size.height))
            let lineWidth = max(3, min(5, side * 0.052))
            let resolvedProgress = min(1, max(0, progress ?? 0.16))
            ZStack {
                Circle()
                    .fill(accent.opacity(0.045))
                Circle()
                    .stroke(Color.primary.opacity(0.085), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: resolvedProgress)
                    .stroke(accent.opacity(progress == nil ? 0.58 : 0.98),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                content
                    .frame(maxWidth: side * 0.74, maxHeight: side * 0.74)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement(children: .combine)
    }
}


/// Shared interaction language for deliberate 1x1 widgets. A micro widget should remain
/// understandable without hover, while hover/press add polish and long-press exposes depth.
struct HaloMicroInteractionModifier<PopoverContent: View>: ViewModifier {
    let accent: Color
    let helpText: String
    let tapShowsPopover: Bool
    let onTap: () -> Void
    let popoverContent: () -> PopoverContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var pressing = false
    @State private var suppressNextTap = false
    @State private var showingPopover = false

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(pressing ? 0.965 : (hovering ? 1.012 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(pressing ? 0.095 : hovering ? 0.035 : 0))
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: pressing)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45, maximumDistance: 12)
                    .onChanged { _ in pressing = true }
                    .onEnded { _ in
                        pressing = false
                        suppressNextTap = true
                        showingPopover = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { suppressNextTap = false }
                    }
            )
            .simultaneousGesture(TapGesture().onEnded {
                guard !suppressNextTap else { return }
                if tapShowsPopover { showingPopover = true } else { onTap() }
            })
            .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                popoverContent().padding(12).frame(minWidth: 220)
            }
            .help(helpText)
    }
}

extension View {
    func haloMicroInteraction<PopoverContent: View>(
        accent: Color,
        help: String,
        tapShowsPopover: Bool = false,
        onTap: @escaping () -> Void,
        @ViewBuilder popover: @escaping () -> PopoverContent
    ) -> some View {
        modifier(HaloMicroInteractionModifier(accent: accent, helpText: help,
                                              tapShowsPopover: tapShowsPopover,
                                              onTap: onTap, popoverContent: popover))
    }
}

struct HaloMicroScrollCapture: NSViewRepresentable {
    let onScroll: (Double) -> Void
    final class View: NSView {
        var callback: ((Double) -> Void)?
        override func scrollWheel(with event: NSEvent) {
            callback?(event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY)
        }
    }
    func makeNSView(context: Context) -> View { let view = View(); view.callback = onScroll; return view }
    func updateNSView(_ nsView: View, context: Context) { nsView.callback = onScroll }
}

private struct AdaptiveSpectrumView: View {
    let accent: Color
    @State private var snapshot = AudioSpectrumSnapshot()
    @State private var owner = UUID().uuidString
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 0.5 : 0.12)) { _ in
            GeometryReader { proxy in
                let values = [snapshot.bass, snapshot.mids, snapshot.treble, snapshot.overall, snapshot.mids, snapshot.bass]
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        Capsule().fill(accent.opacity(index.isMultiple(of: 2) ? 0.9 : 0.58))
                            .frame(maxWidth: .infinity, minHeight: 2, maxHeight: max(2, proxy.size.height * value))
                    }
                }
            }
        }
        .onAppear { AudioSpectrumService.shared.setActive(true, owner: owner) }
        .onDisappear { AudioSpectrumService.shared.setActive(false, owner: owner) }
        .onReceive(Timer.publish(every: reduceMotion ? 0.5 : 0.12, on: .main, in: .common).autoconnect()) { _ in
            snapshot = AudioSpectrumService.shared.snapshot()
        }
    }
}

struct VisualWorkspaceAdaptiveModuleView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    let module: ModuleID
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        switch module {
        case .shelf:
            VisualAdaptiveShelfView(store: store)
        case .media:
            VisualAdaptiveMediaView(service: workspace.media, app: workspace.settings.mediaApp)
        case .audio:
            VisualAdaptiveAudioView(service: workspace.audio, media: workspace.media, mediaApp: workspace.settings.mediaApp)
        case .clipboard:
            VisualAdaptiveClipboardView(service: workspace.clipboard, enabled: workspace.settings.clipboardEnabled)
        case .system:
            VisualAdaptiveSystemView(service: workspace.system)
        case .launcher:
            VisualAdaptiveLauncherView(store: store, workspace: workspace)
        case .activities:
            VisualAdaptiveActivitiesView(workspace: workspace)
        case .notes:
            VisualAdaptiveNotesView(workspace: workspace)
        case .capture:
            VisualAdaptiveCaptureView(service: workspace.capture, store: store)
        case .stopwatch:
            VisualAdaptiveStopwatchView(workspace: workspace)
        default:
            EmptyView()
        }
    }
}

// MARK: - Shared adaptive context

private protocol VisualAdaptiveWidgetContext {}

private struct AdaptiveResolvedContext {
    let module: ModuleID
    let style: WidgetStyle
    let columns: Int
    let rows: Int
    let width: CGFloat?
    let height: CGFloat?
    let settings: VisualAdaptiveWidgetOptions
    let footprint: VisualWidgetFootprint
    let family: VisualAdaptiveFamily

    init(module: ModuleID, style: WidgetStyle, columns: Int?, rows: Int?, width: CGFloat?, height: CGFloat?) {
        self.module = module
        self.style = style
        self.columns = min(8, max(1, columns ?? Self.estimateColumns(width)))
        self.rows = min(4, max(1, rows ?? Self.estimateRows(height)))
        self.width = width
        self.height = height
        self.footprint = VisualWidgetFootprint(columns: self.columns, rows: self.rows)
        let base = style.resolvedVisualAdaptive(for: module)
        let effective = base.effective(columns: self.columns, rows: self.rows)
        self.settings = effective
        self.family = VisualAdaptiveFamilyResolver.resolve(module: module,
                                                           columns: self.columns,
                                                           rows: self.rows,
                                                           width: width,
                                                           height: height,
                                                           requested: effective.preferredPresentation)
    }

    private static func estimateColumns(_ width: CGFloat?) -> Int { min(8, max(1, Int(((width ?? 100) / 96).rounded()))) }
    private static func estimateRows(_ height: CGFloat?) -> Int { min(4, max(1, Int(((height ?? 100) / 86).rounded()))) }

    var spacing: CGFloat { max(3, CGFloat(style.resolvedContent.spacing) * settings.density.spacingScale) }
    var contentAlignment: Alignment { style.resolvedContent.alignment.alignment }
    var information: Set<String> { settings.visibleInformation(for: module, capacity: footprint.informationCapacity) }
    var itemLimit: Int { min(settings.maxItems, footprint.itemCapacity) }
    func shows(_ key: String) -> Bool {
        let configurable = module.visualAdaptiveConfigurableElementKeys
        // Dedicated adaptive widgets do not use the legacy element-style map.
        // This prevents old/hidden settings from silently suppressing their UI.
        guard !configurable.isEmpty else { return true }
        guard configurable.contains(key) else { return true }
        guard module.visualAdaptiveElementAvailability(key, footprint: footprint).available else { return false }
        if module.visualAdaptiveAlwaysInformation.contains(key) { return true }
        return information.contains(key)
    }
}

// MARK: - Timer

struct VisualWorkspaceTimerView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: AppStore
    @Namespace private var namespace
    @State private var microPresetMinutes = 5

    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .timer, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: context.settings.timerShowSeconds ? 1 : 15)) { timeline in
            let remaining = max(0, store.deadline?.timeIntervalSince(timeline.date) ?? store.pausedSeconds)
            let duration = max(store.timerDurationSeconds, remaining)
            let elapsed = max(0, duration - remaining)
            let progress = duration > 0 ? min(1, max(0, elapsed / duration)) : (store.finished ? 1 : 0)
            content(remaining: remaining, elapsed: elapsed, progress: progress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: context.family)
    }

    @ViewBuilder private func content(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        switch context.family {
        case .micro:
            microTimer(remaining: remaining, elapsed: elapsed, progress: progress)
        case .compact:
            HStack(spacing: context.spacing) {
                primaryTime(remaining: remaining, elapsed: elapsed, progress: progress, scale: 0.88)
                Spacer(minLength: 2)
                compactPrimaryControl
            }
        case .horizontal:
            horizontalTimer(remaining: remaining, elapsed: elapsed, progress: progress)
        case .vertical:
            verticalTimer(remaining: remaining, elapsed: elapsed, progress: progress)
        case .standard:
            VStack(spacing: context.spacing) {
                if style.showTitle { AdaptiveHeader(title: context.settings.timerName, symbol: "timer", style: style) }
                primaryTime(remaining: remaining, elapsed: elapsed, progress: progress, scale: 1.15)
                if context.shows("progress") { progressTreatment(progress) }
                timerControls(compact: true)
            }
        case .expanded, .dashboard, .hero:
            heroTimer(remaining: remaining, elapsed: elapsed, progress: progress)
        }
    }

    private func microTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        let value = context.settings.timerMode == .elapsed ? elapsed : remaining
        let text = microDuration(value)
        let active = store.deadline != nil || store.pausedSeconds > 0 || store.finished
        let ringProgress = active ? progress : 0
        let symbol = store.finished ? "checkmark" : store.deadline != nil ? "timer" : store.pausedSeconds > 0 ? "pause.fill" : "play.fill"
        return AdaptiveMicroRing(progress: ringProgress, accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(style.accentColor.color)
                Text(store.finished ? "Done" : (active ? text : "\(microPresetMinutes)m"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.56)
                    .contentTransition(.numericText())
            }.padding(5)
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Timer · click to start/pause · hold for presets") {
            if store.finished { store.resetTimer() }
            else if store.deadline != nil || store.pausedSeconds > 0 { store.pauseResume() }
            else { store.startTimer(minutes: microPresetMinutes) }
        } popover: {
            HaloTimerDurationComposer(
                accent: style.accentColor.color,
                textColor: style.textColor.color,
                quickPresets: [1, 5, 10, 15, 30],
                initialMinutes: microPresetMinutes,
                compact: false
            ) { duration in
                microPresetMinutes = max(1, Int((duration / 60).rounded()))
                store.startTimer(duration: duration)
            }
            .padding(10)
            .frame(width: 350)
        }
        .background(HaloMicroScrollCapture { delta in
            guard store.deadline == nil, store.pausedSeconds <= 0 else { return }
            microPresetMinutes = min(120, max(1, microPresetMinutes + (delta > 0 ? 1 : -1)))
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }.allowsHitTesting(true))
        .scaleEffect(store.finished && !reduceMotion ? 1.025 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.42).repeatCount(store.finished ? 2 : 1, autoreverses: true), value: store.finished)
    }

    private func microDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(Int(ceil(Double(seconds) / 60)))m" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
    }

    private func horizontalTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        HStack(spacing: context.spacing) {
            if context.columns >= 5 && style.showTitle { Text(context.settings.timerName).font(style.font(scale: 0.82)).foregroundStyle(.secondary).lineLimit(1) }
            primaryTime(remaining: remaining, elapsed: elapsed, progress: progress, scale: context.columns >= 6 ? 1.12 : 0.94)
            if context.columns >= 4 && context.shows("progress") { progressTreatment(progress).frame(maxWidth: context.columns >= 7 ? 180 : 110) }
            Spacer(minLength: 2)
            timerControls(compact: true)
        }
    }

    private func verticalTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        VStack(spacing: context.spacing) {
            if style.showTitle { Text(context.settings.timerName.uppercased()).font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary) }
            primaryTime(remaining: remaining, elapsed: elapsed, progress: progress, scale: 1.08)
            if context.rows >= 3 && context.shows("progress") { progressTreatment(progress) }
            if context.rows >= 3 { timerControls(compact: true) }
            if context.rows >= 4 { timerMetadata(remaining: remaining, elapsed: elapsed) }
            Spacer(minLength: 0)
        }
    }

    private func heroTimer(remaining: TimeInterval, elapsed: TimeInterval, progress: Double) -> some View {
        VStack(spacing: context.spacing * 1.05) {
            if style.showTitle { AdaptiveHeader(title: context.settings.timerName.uppercased(), symbol: "timer", style: style) }
            Spacer(minLength: 0)
            primaryTime(remaining: remaining, elapsed: elapsed, progress: progress, scale: context.family == .hero ? 1.8 : 1.45)
            if context.shows("progress") { progressTreatment(progress).frame(maxWidth: context.family == .hero ? 520 : 360) }
            timerControls(compact: false)
            if context.family != .expanded { timerMetadata(remaining: remaining, elapsed: elapsed) }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func primaryTime(remaining: TimeInterval, elapsed: TimeInterval, progress: Double, scale: Double) -> some View {
        let value = context.settings.timerMode == .elapsed ? elapsed : remaining
        let text = formatDuration(value)
        let size = max(18, style.fontSize * scale * (context.settings.timerStyle == .largeTypography ? 1.4 : 1))
        Group {
            switch context.settings.timerStyle {
            case .minimal, .digital:
                Text(store.finished ? "Done" : text).font(.system(size: size, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1)
            case .circular, .ring:
                ZStack {
                    Circle().stroke(style.textColor.color.opacity(0.10), lineWidth: context.settings.timerProgressThickness)
                    Circle().trim(from: 0, to: progress).stroke(style.accentColor.color, style: StrokeStyle(lineWidth: context.settings.timerProgressThickness, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(store.finished ? "✓" : text).font(.system(size: max(13, size * 0.55), weight: .bold, design: .rounded)).monospacedDigit()
                }.aspectRatio(1, contentMode: .fit).frame(maxWidth: context.family == .micro ? 74 : 128, maxHeight: context.family == .micro ? 74 : 128)
            case .progressBar:
                VStack(spacing: 5) {
                    Text(store.finished ? "Done" : text).font(.system(size: size, weight: .bold, design: .rounded)).monospacedDigit()
                    AdaptiveProgressBar(progress: progress, accent: style.accentColor.color, thickness: context.settings.timerProgressThickness)
                }
            case .editorial:
                Text(store.finished ? "Complete" : text).font(.system(size: size * 1.02, weight: .semibold, design: .serif)).monospacedDigit()
            case .largeTypography:
                Text(store.finished ? "DONE" : text).font(.system(size: size, weight: .black, design: .rounded)).monospacedDigit().tracking(-1.2)
            }
        }
        .foregroundStyle(store.finished ? style.accentColor.color : style.textColor.color)
        .matchedGeometryEffect(id: "adaptive-timer-time", in: namespace)
        .contentTransition(.numericText())
    }

    @ViewBuilder private func progressTreatment(_ progress: Double) -> some View {
        if context.settings.timerStyle == .circular || context.settings.timerStyle == .ring {
            HStack { Text("\(Int(progress * 100))%").font(.caption2).monospacedDigit().foregroundStyle(.secondary); Spacer() }
        } else {
            AdaptiveProgressBar(progress: progress, accent: style.accentColor.color, thickness: context.settings.timerProgressThickness)
        }
    }

    @ViewBuilder private var compactPrimaryControl: some View {
        if context.settings.showControls && context.shows("controls") {
            if store.deadline != nil || store.pausedSeconds > 0 {
                Button { store.pauseResume() } label: { Image(systemName: store.deadline == nil ? "play.fill" : "pause.fill") }.buttonStyle(.plain)
            } else {
                HaloTimerDurationPopoverButton(
                    accent: style.accentColor.color,
                    textColor: style.textColor.color,
                    quickPresets: [
                        style.resolvedContent.timerPresetA,
                        style.resolvedContent.timerPresetB,
                        style.resolvedContent.timerPresetC
                    ],
                    initialMinutes: style.resolvedContent.timerPresetB,
                    label: "Set"
                ) { duration in
                    store.startTimer(duration: duration)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private func timerControls(compact: Bool) -> some View {
        if context.settings.showControls && context.shows("controls") {
            let controlSize: ControlSize = compact ? .mini : .small
            if store.deadline == nil && store.pausedSeconds <= 0 {
                if context.shows("presets") {
                    if compact {
                        HaloTimerDurationPopoverButton(
                            accent: style.accentColor.color,
                            textColor: style.textColor.color,
                            quickPresets: [
                                style.resolvedContent.timerPresetA,
                                style.resolvedContent.timerPresetB,
                                style.resolvedContent.timerPresetC
                            ],
                            initialMinutes: style.resolvedContent.timerPresetB,
                            label: "Custom timer"
                        ) { duration in
                            store.startTimer(duration: duration)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(controlSize)
                    } else {
                        HaloTimerDurationComposer(
                            accent: style.accentColor.color,
                            textColor: style.textColor.color,
                            quickPresets: [
                                style.resolvedContent.timerPresetA,
                                style.resolvedContent.timerPresetB,
                                style.resolvedContent.timerPresetC,
                                45,
                                60
                            ],
                            initialMinutes: style.resolvedContent.timerPresetB,
                            compact: false
                        ) { duration in
                            store.startTimer(duration: duration)
                        }
                        .frame(maxWidth: 390)
                    }
                }
            } else {
                HStack(spacing: max(5, context.spacing)) {
                    Button(store.deadline == nil ? "Resume" : "Pause") { store.pauseResume() }

                    if !compact || context.columns >= 5 {
                        Button {
                            store.addTimer(minutes: 1)
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        } label: {
                            Label("+1m", systemImage: "plus")
                        }
                    }

                    Button(role: .destructive) {
                        store.resetTimer()
                    } label: {
                        compact ? AnyView(Image(systemName: "xmark")) : AnyView(Label("Stop", systemImage: "stop.fill"))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(controlSize)
            }
        }
    }

    @ViewBuilder private func timerMetadata(remaining: TimeInterval, elapsed: TimeInterval) -> some View {
        HStack(spacing: context.spacing * 1.4) {
            if context.shows("status") {
                Label(store.finished ? "Complete" : store.deadline != nil ? "Running" : store.pausedSeconds > 0 ? "Paused" : "Ready",
                      systemImage: store.finished ? "checkmark.circle.fill" : store.deadline != nil ? "timer" : store.pausedSeconds > 0 ? "pause.circle" : "circle")
            }
            if context.shows("endTime"), let deadline = store.deadline { Label(deadline.formatted(date: .omitted, time: .shortened), systemImage: "flag.checkered") }
            if context.settings.timerMode == .remaining { Text("\(formatDuration(elapsed)) elapsed") }
            else { Text("\(formatDuration(remaining)) remaining") }
        }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        if !context.settings.timerShowSeconds {
            let minutes = Int(ceil(Double(whole) / 60))
            return minutes >= 60 ? String(format: "%d:%02d", minutes / 60, minutes % 60) : "\(minutes)m"
        }
        return whole >= 3600 ? String(format: "%d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60) : String(format: "%02d:%02d", whole / 60, whole % 60)
    }
}


// MARK: - File Shelf

private struct VisualAdaptiveShelfView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var store: AppStore
    @State private var selectedURL: URL?

    private var context: AdaptiveResolvedContext {
        AdaptiveResolvedContext(module: .shelf, style: style, columns: gridColumnSpan, rows: gridRowSpan,
                                width: availableWidth, height: availableHeight)
    }
    private var orderedFiles: [URL] {
        let pinned = store.files.filter { store.pinnedFiles.contains($0) }
        let regular = store.files.filter { !store.pinnedFiles.contains($0) }
        return pinned + regular
    }
    private var effectiveSelection: URL? { selectedURL.flatMap { store.files.contains($0) ? $0 : nil } ?? orderedFiles.first }

    var body: some View {
        Group {
            if context.footprint.area == 1 { microShelf }
            else if context.footprint.rows == 1 { horizontalShelf }
            else if context.footprint.columns == 1 { verticalShelf }
            else if context.footprint.stage == .dashboard || (context.columns >= 5 && context.rows >= 3) { dashboardShelf }
            else { gridShelf }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            guard !files.isEmpty else { return false }
            store.addFiles(files)
            return true
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: context.footprint)
    }

    private var microShelf: some View {
        let shown = Array(orderedFiles.prefix(3))
        return ZStack {
            if shown.isEmpty {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(style.accentColor.color)
            } else {
                ForEach(Array(shown.enumerated().reversed()), id: \.offset) { index, url in
                    shelfIcon(url, size: 34)
                        .offset(x: CGFloat(index) * 3 - 3, y: CGFloat(index) * -3 + 3)
                        .rotationEffect(.degrees(Double(index - 1) * 3.2))
                }
                if store.files.count > 1 {
                    Text("\(store.files.count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(4).background(style.accentColor.color, in: Circle())
                        .foregroundStyle(.white).offset(x: 21, y: -21)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .haloMicroInteraction(accent: style.accentColor.color,
                              help: shown.isEmpty ? "File Shelf · click to add files" : "File Shelf · click latest · hold for shelf") {
            if let first = orderedFiles.first { NSWorkspace.shared.open(first) } else { store.chooseFiles() }
        } popover: {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Text("File Shelf").font(.headline); Spacer(); Button("Add…") { store.chooseFiles() } }
                if shown.isEmpty { Text("Drop files onto Halo or add them here.").foregroundStyle(.secondary) }
                ForEach(Array(orderedFiles.prefix(5).enumerated()), id: \.offset) { _, url in
                    shelfRow(url, compact: true)
                }
            }.frame(width: 280)
        }
    }

    private var horizontalShelf: some View {
        HStack(spacing: max(5, context.spacing * 0.72)) {
            let shown = Array(orderedFiles.prefix(max(1, min(context.itemLimit, context.columns))))
            if shown.isEmpty { emptyShelf }
            else {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, url in
                    Button { NSWorkspace.shared.open(url) } label: {
                        HStack(spacing: 5) {
                            shelfIcon(url, size: context.columns >= 5 ? 28 : 24)
                            if context.columns >= 4 { Text(url.deletingPathExtension().lastPathComponent).font(.caption).lineLimit(1) }
                        }
                    }.buttonStyle(.plain).contextMenu { fileMenu(url) }
                }
                Spacer(minLength: 0)
                if context.columns >= 6 { Button { store.chooseFiles() } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(.plain).help("Add files") }
            }
        }
    }

    private var verticalShelf: some View {
        VStack(spacing: max(5, context.spacing * 0.72)) {
            let shown = Array(orderedFiles.prefix(max(1, min(context.itemLimit, context.rows))))
            if shown.isEmpty { emptyShelf }
            else {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, url in
                    Button { NSWorkspace.shared.open(url) } label: {
                        VStack(spacing: 3) {
                            shelfIcon(url, size: 28)
                            if context.rows >= 3 { Text(url.deletingPathExtension().lastPathComponent).font(.system(size: 8, weight: .medium)).lineLimit(1) }
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain).contextMenu { fileMenu(url) }
                }
                if context.rows >= 4 { Button { store.chooseFiles() } label: { Image(systemName: "plus") }.buttonStyle(.plain) }
            }
        }
    }

    private var gridShelf: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if context.columns >= 3 {
                HStack {
                    Text("FILES").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.files.count)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Button { store.chooseFiles() } label: { Image(systemName: "plus") }.buttonStyle(.plain)
                }
            }
            if orderedFiles.isEmpty { emptyShelf }
            else {
                let gridColumns = max(1, min(context.columns, context.rows == 2 ? 4 : 5))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: gridColumns), spacing: context.spacing) {
                    ForEach(Array(orderedFiles.prefix(context.itemLimit).enumerated()), id: \.offset) { _, url in
                        fileTile(url, detailed: context.rows >= 3)
                    }
                }
            }
        }
    }

    private var dashboardShelf: some View {
        HStack(alignment: .top, spacing: context.spacing * 1.15) {
            VStack(alignment: .leading, spacing: context.spacing) {
                HStack {
                    Label("File Shelf", systemImage: "tray.full.fill").font(.headline)
                    Spacer()
                    Button("Add…") { store.chooseFiles() }.controlSize(.small)
                    if !store.files.isEmpty { Button("Clear") { store.clearShelf() }.controlSize(.small) }
                }
                if orderedFiles.isEmpty { emptyShelf }
                else {
                    let gridColumns = min(5, max(3, context.columns - 2))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: gridColumns), spacing: context.spacing) {
                        ForEach(Array(orderedFiles.prefix(context.itemLimit).enumerated()), id: \.offset) { _, url in
                            fileTile(url, detailed: true)
                        }
                    }
                }
            }.frame(maxWidth: .infinity)
            if context.columns >= 5 {
                Divider().opacity(0.18)
                VStack(alignment: .leading, spacing: 8) {
                    if let url = effectiveSelection {
                        shelfIcon(url, size: min(96, max(56, (availableHeight ?? 220) * 0.28)))
                        Text(url.lastPathComponent).font(.headline).lineLimit(2)
                        Text(fileDetail(url)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        HStack {
                            Button("Open") { NSWorkspace.shared.open(url) }
                            Button("Preview") { store.shelfPreview.show(url) }
                        }.controlSize(.small)
                        Button(store.pinnedFiles.contains(url) ? "Unpin" : "Pin") { store.toggleFilePin(url) }.controlSize(.small)
                    } else {
                        Text("Select a file").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.frame(minWidth: 130, maxWidth: 190, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var emptyShelf: some View {
        Button { store.chooseFiles() } label: {
            VStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(style.accentColor.color)
                if context.footprint.area > 2 { Text("Drop files here or Add…").font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain)
    }

    private func fileTile(_ url: URL, detailed: Bool) -> some View {
        Button { selectedURL = url } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    shelfIcon(url, size: detailed ? 42 : 34)
                    if store.pinnedFiles.contains(url) { Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(style.accentColor.color) }
                }
                Text(url.deletingPathExtension().lastPathComponent).font(.system(size: detailed ? 10 : 9, weight: .medium)).lineLimit(detailed ? 2 : 1).multilineTextAlignment(.center)
                if detailed && context.rows >= 3 { Text(fileKind(url)).font(.system(size: 7, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1) }
            }.frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { NSWorkspace.shared.open(url) })
        .contextMenu { fileMenu(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    }

    private func shelfRow(_ url: URL, compact: Bool) -> some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack(spacing: 8) {
                shelfIcon(url, size: compact ? 24 : 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.lastPathComponent).lineLimit(1)
                    Text(fileDetail(url)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }.buttonStyle(.plain).contextMenu { fileMenu(url) }
    }

    @ViewBuilder private func fileMenu(_ url: URL) -> some View {
        Button("Open") { NSWorkspace.shared.open(url) }
        Button("Quick Look") { store.shelfPreview.show(url) }
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Button(store.pinnedFiles.contains(url) ? "Unpin" : "Pin") { store.toggleFilePin(url) }
        Divider()
        Button("Remove from Shelf") { store.removeFile(url) }
    }

    private func shelfIcon(_ url: URL, size: CGFloat) -> some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit().frame(width: size, height: size)
    }
    private func fileKind(_ url: URL) -> String { url.hasDirectoryPath ? "FOLDER" : (url.pathExtension.isEmpty ? "FILE" : url.pathExtension.uppercased()) }
    private func fileDetail(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { return "Original unavailable" }
        if values.isDirectory == true { return "Folder" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
        let kind = url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased()
        return "\(kind) · \(size)"
    }
}

// MARK: - Media

private struct VisualAdaptiveMediaView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var service: MediaService
    let app: String
    @Namespace private var namespace

    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .media, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    private var settings: VisualAdaptiveWidgetOptions { context.settings }
    private var artworkSize: CGFloat {
        let base = min(availableWidth ?? 250, availableHeight ?? 180)
        let familyScale: CGFloat
        switch context.family { case .micro: familyScale = 0.82; case .compact: familyScale = 0.66; case .horizontal: familyScale = 0.62; case .vertical: familyScale = 0.72; case .standard: familyScale = 0.58; case .expanded: familyScale = 0.62; case .dashboard, .hero: familyScale = 0.70 }
        return min(280, max(42, base * familyScale * settings.mediaArtworkScale))
    }

    var body: some View {
        ZStack {
            if settings.mediaArtworkBackground, let image = service.artworkImage, context.family != .micro {
                Image(nsImage: image).resizable().scaledToFill().blur(radius: settings.mediaArtworkBlur).opacity(0.28)
                    .overlay(Color.black.opacity(0.32)).clipped().transition(.opacity)
            }
            Group {
                switch context.family {
                case .micro: micro
                case .compact: compact
                case .horizontal: horizontal
                case .vertical: vertical
                case .standard: standard
                case .expanded: expanded
                case .dashboard, .hero: hero
                }
            }.padding(settings.mediaArtworkBackground && context.family != .micro ? 6 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
        .onAppear { service.setArtworkEnabled(true) }
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86), value: context.family)
    }

    private var micro: some View {
        Group {
            switch settings.mediaMicroStyle {
            case .artwork:
                artworkView(size: min(artworkSize, 84))
            case .artworkPlay:
                ZStack(alignment: .bottomTrailing) {
                    artworkView(size: min(artworkSize, 84))
                    if settings.showControls && context.shows("controls") { playButton.circleStyle.padding(4) }
                }
            case .title:
                VStack(spacing: 4) {
                    Image(systemName: service.isPlaying ? "waveform" : "play.fill").foregroundStyle(style.accentColor.color)
                    Text(service.connectedApp == nil ? "Nothing Playing" : service.title).font(.system(size: 10, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compact: some View {
        HStack(spacing: context.spacing) {
            artworkView(size: min(artworkSize, 62))
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                if context.shows("artist") { Text(service.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 2)
            if settings.showControls && context.shows("controls") { playButton }
        }
    }

    private var horizontal: some View {
        HStack(spacing: context.spacing) {
            artworkView(size: min(artworkSize, max(44, (availableHeight ?? 90) - 12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                if context.shows("artist") { Text(service.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }.frame(maxWidth: context.columns >= 5 ? 180 : 120, alignment: .leading)
            if context.columns >= 6 && context.shows("progress") { progressBlock(compact: true).frame(maxWidth: 180) }
            Spacer(minLength: 2)
            mediaControls(compact: context.columns < 6)
        }
    }

    private var vertical: some View {
        VStack(spacing: context.spacing) {
            artworkView(size: min(artworkSize, (availableWidth ?? 120) - 14))
            Text(displayTitle).font(.system(size: 12, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
            if context.shows("artist") { Text(service.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            if context.rows >= 3 && context.shows("progress") { progressBlock(compact: true) }
            if settings.showControls { mediaControls(compact: context.rows < 4) }
        }.frame(maxWidth: .infinity)
    }

    private var standard: some View {
        HStack(alignment: .center, spacing: context.spacing) {
            artworkView(size: min(artworkSize, 108))
            VStack(alignment: .leading, spacing: max(4, context.spacing * 0.7)) {
                metadata
                if context.shows("progress") { progressBlock(compact: true) }
                if settings.showControls { mediaControls(compact: false) }
            }
        }
    }

    private var expanded: some View {
        Group {
            if context.columns >= context.rows + 2 {
                HStack(alignment: .center, spacing: context.spacing * 1.2) {
                    artworkView(size: min(artworkSize, 170))
                    VStack(alignment: .leading, spacing: context.spacing) {
                        metadata
                        if context.shows("progress") { progressBlock(compact: false) }
                        if settings.showControls { mediaControls(compact: false) }
                        optionalMediaTools
                    }
                }
            } else {
                VStack(spacing: context.spacing) {
                    artworkView(size: min(artworkSize, 170)); metadata
                    if context.shows("progress") { progressBlock(compact: false) }
                    if settings.showControls { mediaControls(compact: false) }
                }
            }
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: context.spacing * 1.5) {
            artworkView(size: min(artworkSize, context.family == .hero ? 250 : 210))
            VStack(alignment: .leading, spacing: context.spacing) {
                if style.showTitle { AdaptiveHeader(title: service.isPlaying ? "NOW PLAYING" : "MEDIA", symbol: "music.note", style: style) }
                metadata
                Spacer(minLength: 0)
                if context.shows("progress") { progressBlock(compact: false) }
                if settings.showControls { mediaControls(compact: false) }
                optionalMediaTools
                if settings.mediaVisualizer && context.shows("visualizer") {
                    AdaptiveSpectrumView(accent: artworkAccent).frame(height: settings.mediaVisualizerPosition == .bottom ? 38 : 28)
                }
            }.frame(maxHeight: .infinity)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(displayTitle).font(.system(size: context.family == .hero ? 22 : 15, weight: .bold, design: .rounded)).lineLimit(2)
            if context.shows("artist") && !service.artist.isEmpty { Text(service.artist).font(.system(size: context.family == .hero ? 14 : 12, weight: .medium)).foregroundStyle(.secondary).lineLimit(1) }
            if context.shows("album") && !service.album.isEmpty { Text(service.album).font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
            if context.shows("source"), let source = service.connectedApp { Text(source == "com.apple.Music" ? "Apple Music" : source == "com.spotify.client" ? "Spotify" : "System Audio").font(.caption2).foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private func progressBlock(compact: Bool) -> some View {
        if service.duration > 0 {
            VStack(spacing: compact ? 2 : 4) {
                if settings.mediaProgressStyle == .native {
                    Slider(value: Binding(get: { service.position }, set: { service.seek(to: $0) }), in: 0...max(1, service.duration))
                } else {
                    AdaptiveProgressBar(progress: service.position / max(1, service.duration), accent: artworkAccent, thickness: settings.mediaProgressStyle == .thin ? 2 : 5)
                        .contentShape(Rectangle())
                }
                if !compact && context.shows("timing") {
                    HStack { Text(time(service.position)); Spacer(); Text("−" + time(max(0, service.duration - service.position))) }.font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private func mediaControls(compact: Bool) -> some View {
        if settings.showControls && context.shows("controls") && service.connectedApp != nil {
            HStack(spacing: compact ? 9 : 13) {
                if !compact && context.shows("controls") { Button { service.perform("previous track", app: app) } label: { Image(systemName: "backward.end.fill") } }
                playButton
                if !compact && context.shows("controls") { Button { service.perform("next track", app: app) } label: { Image(systemName: "forward.end.fill") } }
            }.buttonStyle(.plain).disabled(service.busy)
        }
    }

    @ViewBuilder private var optionalMediaTools: some View {
        if context.family == .dashboard || context.family == .hero {
            HStack(spacing: 12) {
                if service.shuffleSupported && context.shows("shuffle") { Button { service.toggleShuffle() } label: { Image(systemName: service.shuffleEnabled ? "shuffle.circle.fill" : "shuffle") } }
                if service.repeatSupported && context.shows("repeat") { Button { service.cycleRepeat() } label: { Image(systemName: "repeat") } }
                if settings.mediaVisualizer && settings.mediaVisualizerPosition == .inline && context.shows("visualizer") { AdaptiveSpectrumView(accent: artworkAccent).frame(width: 90, height: 24) }
            }.buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }

    private var playButton: some View {
        Button { service.perform("playpause", app: app) } label: { Image(systemName: service.isPlaying ? "pause.fill" : "play.fill") }.buttonStyle(.plain)
    }

    @ViewBuilder private func artworkView(size: CGFloat) -> some View {
        let view = Group {
            if let image = service.artworkImage { Image(nsImage: image).resizable().scaledToFill() }
            else { ZStack { artworkAccent.opacity(0.16); Image(systemName: "music.note").font(.system(size: max(18, size * 0.28), weight: .medium)).foregroundStyle(artworkAccent) } }
        }
        settings.mediaArtworkShape.clip(view.frame(width: size, height: size), radius: min(settings.mediaArtworkCornerRadius, size * 0.25))
            .matchedGeometryEffect(id: "adaptive-media-artwork", in: namespace)
            .shadow(color: Color.black.opacity(context.family == .hero ? 0.28 : 0.12), radius: context.family == .hero ? 16 : 6, y: 4)
    }

    private var artworkAccent: Color {
        settings.mediaUseArtworkColors ? (service.artworkColors.first?.color ?? style.accentColor.color) : style.accentColor.color
    }
    private var displayTitle: String { service.connectedApp == nil ? "Nothing Playing" : service.title }
    private func time(_ seconds: Double) -> String { let value = max(0, Int(seconds)); return String(format: "%d:%02d", value / 60, value % 60) }
}

private extension View {
    var circleStyle: some View { self.padding(7).background(.ultraThinMaterial, in: Circle()) }
}

// MARK: - Audio

private struct VisualAdaptiveAudioView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var service: AudioService
    @ObservedObject var media: MediaService
    let mediaApp: String

    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .audio, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    private var selectedName: String { service.devices.first(where: { $0.id == service.selected })?.name ?? "Audio Output" }
    private var percent: Int { Int((Double(service.volume) * 100).rounded()) }

    var body: some View {
        Group {
            switch context.family {
            case .micro: micro
            case .compact: compact
            case .horizontal: horizontal
            case .vertical: vertical
            case .standard: standard
            case .expanded, .dashboard, .hero: large
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
            .onAppear { service.refresh() }
    }

    private var speakerSymbol: String { service.volume <= 0.001 ? "speaker.slash.fill" : service.volume < 0.45 ? "speaker.wave.1.fill" : "speaker.wave.3.fill" }
    private var micro: some View {
        Group {
            if media.isPlaying, let artwork = media.artworkImage {
                ZStack {
                    Image(nsImage: artwork).resizable().scaledToFill()
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(style.accentColor.color.opacity(0.72), lineWidth: 2)
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                        .padding(7).background(.ultraThinMaterial, in: Circle())
                }.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                AdaptiveMicroRing(progress: min(1, max(0, Double(service.volume))), accent: style.accentColor.color) {
                    VStack(spacing: 2) {
                        Image(systemName: speakerSymbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(style.accentColor.color)
                        Text("\(percent)%").font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1)
                    }
                }
            }
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Audio · click play/pause · scroll volume · hold for controls") {
            if media.connectedApp != nil || media.isPlaying { media.perform("playpause", app: mediaApp) }
            else if service.canSetVolume { service.toggleMute() }
        } popover: {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedName).font(.headline).lineLimit(1)
                HStack {
                    if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol) }
                    if context.settings.audioShowPercentage { Text("\(percent)%").monospacedDigit() }
                    Spacer()
                    if context.settings.showControls { Button("Mute") { service.toggleMute() }.disabled(!service.canSetVolume) }
                }
                if context.settings.audioShowSlider && service.canSetVolume { volumeSlider }
                if context.settings.audioShowOutputSelector && service.devices.count > 1 { outputPicker }
                if context.settings.showControls && media.connectedApp != nil { HStack { Button { media.perform("previous track", app: mediaApp) } label: { Image(systemName: "backward.fill") }; Button { media.perform("playpause", app: mediaApp) } label: { Image(systemName: "playpause.fill") }; Button { media.perform("next track", app: mediaApp) } label: { Image(systemName: "forward.fill") } } }
            }
        }
        .background(HaloMicroScrollCapture { delta in
            guard service.canSetVolume else { return }
            service.setVolume(min(1, max(0, service.volume + Float(delta > 0 ? 0.04 : -0.04))))
        }.allowsHitTesting(true))
    }
    private var compact: some View { HStack(spacing: 7) { if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).foregroundStyle(style.accentColor.color) }; if context.settings.audioShowPercentage { Text("\(percent)%").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit() }; Spacer(minLength: 2); if context.settings.showControls && service.canSetVolume { Button { service.toggleMute() } label: { Image(systemName: service.volume <= 0.001 ? "speaker.wave.2" : "speaker.slash") }.buttonStyle(.plain) } } }
    private var horizontal: some View {
        HStack(spacing: context.spacing) {
            if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).foregroundStyle(style.accentColor.color) }
            if context.shows("output") { Text(selectedName).font(.system(size: 11, weight: .semibold)).lineLimit(1).frame(maxWidth: 180, alignment: .leading) }
            if context.settings.audioShowSlider && service.canSetVolume { volumeSlider.frame(maxWidth: context.columns >= 6 ? 260 : 150) }
            if context.settings.audioShowPercentage { Text("\(percent)%").font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit() }
            if context.settings.showControls && service.canSetVolume && context.columns >= 5 { Button("Mute") { service.toggleMute() }.buttonStyle(.plain).font(.caption) }
        }
    }
    private var vertical: some View {
        VStack(spacing: context.spacing) {
            if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(style.accentColor.color) }
            if context.settings.audioShowPercentage { Text("\(percent)%").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit() }
            Text(selectedName).font(.caption).lineLimit(2).multilineTextAlignment(.center)
            if context.rows >= 3 && context.settings.audioShowSlider && service.canSetVolume { volumeSlider }
            if context.rows >= 4 && context.settings.audioShowOutputSelector { outputPicker }
        }
    }
    private var standard: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            HStack {
                if context.settings.audioShowDeviceIcon { Image(systemName: speakerSymbol).foregroundStyle(style.accentColor.color) }
                Text(selectedName).lineLimit(1)
                Spacer()
                if context.settings.audioShowPercentage { Text("\(percent)%").font(.title3.bold()).monospacedDigit() }
            }
            if context.settings.audioShowSlider && service.canSetVolume { volumeSlider }
            if context.settings.audioShowOutputSelector { outputPicker }
        }
    }
    private var large: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if style.showTitle { AdaptiveHeader(title: "AUDIO", symbol: speakerSymbol, style: style) }
            HStack { VStack(alignment: .leading, spacing: 2) { Text("OUTPUT").font(.caption2).foregroundStyle(.secondary); Text(selectedName).font(.system(size: 15, weight: .semibold)).lineLimit(1) }; Spacer(); Text("\(percent)%").font(.system(size: 28, weight: .bold, design: .rounded)).monospacedDigit() }
            if context.settings.audioShowSlider && service.canSetVolume { volumeSlider }
            if context.settings.showControls && service.canSetVolume { HStack { Button(service.volume <= 0.001 ? "Unmute" : "Mute") { service.toggleMute() }; if context.settings.audioShowQuickLevels { ForEach([25, 50, 75, 100], id: \.self) { p in Button("\(p)%") { service.setVolume(Float(p) / 100) } } } }.buttonStyle(.bordered).controlSize(.mini) }
            if context.settings.audioShowOutputSelector && context.family != .expanded {
                Text("AVAILABLE DEVICES").font(.caption2).foregroundStyle(.secondary)
                ScrollView(.vertical, showsIndicators: context.family == .hero) {
                    VStack(spacing: 4) {
                        ForEach(service.devices.prefix(context.settings.maxItems)) { device in
                            Button { service.setOutput(device.id) } label: { HStack { Image(systemName: device.id == service.selected ? "checkmark.circle.fill" : "circle").foregroundStyle(device.id == service.selected ? style.accentColor.color : .secondary); Text(device.name).lineLimit(1); Spacer() } }.buttonStyle(.plain)
                        }
                    }
                }
            }
            if let error = service.error { Text(error).font(.caption).foregroundStyle(.orange) }
        }
    }
    private var volumeSlider: some View {
        Slider(value: Binding(get: { Double(service.volume) }, set: { service.setVolume(Float($0)) }), in: 0...1)
            .controlSize(context.settings.audioSliderStyle == .compact ? .mini : .regular)
    }
    private var outputPicker: some View {
        Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) { ForEach(service.devices) { Text($0.name).tag($0.id) } }.labelsHidden()
    }
}

// MARK: - Clipboard

private struct VisualAdaptiveClipboardView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var service: ClipboardService
    let enabled: Bool
    @State private var query = ""

    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .clipboard, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    private var entries: [ClipboardEntry] { service.entries.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) } }

    var body: some View {
        Group {
            if !enabled { empty(icon: "clipboard", text: context.family == .micro ? "Off" : "Clipboard history is off") }
            else {
                switch context.family {
                case .micro: micro
                case .compact: compact
                case .horizontal: horizontal
                case .vertical: vertical
                case .standard: standard
                case .expanded, .dashboard, .hero: large
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
    }

    private var micro: some View {
        Group {
            if let entry = service.entries.first {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(style.accentColor.color.opacity(0.045)).offset(x: 5, y: 5).opacity(service.entries.count > 1 ? 1 : 0)
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(style.textColor.color.opacity(0.055)).offset(x: 2.5, y: 2.5).opacity(service.entries.count > 1 ? 1 : 0)
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(style.textColor.color.opacity(0.035))
                    VStack(spacing: 5) {
                        Image(systemName: contentIcon(entry.text)).font(.system(size: 22, weight: .semibold)).foregroundStyle(style.accentColor.color)
                        Text(contentIcon(entry.text) == "link" ? "LINK" : "TEXT").font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if service.entries.count > 1 {
                        Text("\(service.entries.count)").font(.system(size: 7, weight: .bold, design: .rounded)).padding(4).background(style.accentColor.color, in: Circle()).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(5)
                    }
                }
                .padding(5)
                .haloMicroInteraction(accent: style.accentColor.color, help: "Clipboard · click for preview · hold for history", tapShowsPopover: true, onTap: {}) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Clipboard").font(.headline)
                        ForEach(Array(service.entries.prefix(6))) { item in
                            Button { service.copy(item) } label: {
                                HStack { Image(systemName: contentIcon(item.text)); Text(item.text).lineLimit(1); Spacer() }
                            }.buttonStyle(.plain)
                        }
                        Text("Clipboard history stays in memory and clears when Halo quits.").font(.caption2).foregroundStyle(.secondary)
                    }.frame(width: 280)
                }
            } else {
                VStack(spacing: 5) { Image(systemName: "doc.on.clipboard").font(.system(size: 22)); Text(enabled ? "EMPTY" : "OFF").font(.caption2).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    private var compact: some View {
        HStack(spacing: 7) {
            Image(systemName: service.entries.first.map { contentIcon($0.text) } ?? "doc.on.clipboard").foregroundStyle(style.accentColor.color)
            Text(service.entries.first.map { preview($0.text, limit: context.settings.clipboardPreviewLength) } ?? "Clipboard Empty").lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if let entry = service.entries.first, context.settings.showControls { Button("Copy") { service.copy(entry) }.buttonStyle(.bordered).controlSize(.mini) }
        }
    }
    private var horizontal: some View { compact }
    private var vertical: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if style.showTitle { Text("RECENT").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary) }
            ForEach(Array(service.entries.prefix(min(context.settings.maxItems, max(2, context.rows + 1))))) { entry in clipboardRow(entry, compact: true) }
            if service.entries.isEmpty { Text("Clipboard Empty").foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
    }
    private var standard: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if context.settings.clipboardShowSearch { TextField("Search clipboard", text: $query) }
            ForEach(Array(entries.prefix(min(context.settings.maxItems, 4)))) { clipboardRow($0, compact: true) }
            if entries.isEmpty { Text("Clipboard Empty").foregroundStyle(.secondary) }
        }
    }
    private var large: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            HStack { if style.showTitle { AdaptiveHeader(title: "Clipboard", symbol: "doc.on.clipboard", style: style) }; if context.settings.clipboardShowSearch { TextField("Search", text: $query).frame(maxWidth: 220) } }
            if entries.isEmpty { Spacer(); empty(icon: "doc.on.clipboard", text: "Clipboard Empty"); Spacer() }
            else {
                ScrollView(.vertical, showsIndicators: context.family == .hero) {
                    LazyVGrid(columns: context.settings.clipboardRowStyle == .tiles ? [GridItem(.adaptive(minimum: 170), spacing: context.spacing)] : [GridItem(.flexible())], spacing: context.spacing * 0.7) {
                        ForEach(Array(entries.prefix(context.settings.maxItems))) { clipboardRow($0, compact: false) }
                    }
                }
            }
            if context.settings.showControls && context.family == .hero { HStack { Spacer(); Button("Clear history") { service.reset() }.buttonStyle(.borderless).foregroundStyle(.secondary) } }
        }
    }

    private func clipboardRow(_ entry: ClipboardEntry, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: contentIcon(entry.text)).foregroundStyle(style.accentColor.color).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(preview(entry.text, limit: context.settings.clipboardPreviewLength)).lineLimit(compact ? 2 : 3).frame(maxWidth: .infinity, alignment: .leading)
                if context.settings.clipboardShowTimestamp { Text(entry.date, style: .relative).font(.caption2).foregroundStyle(.secondary) }
            }
            if context.settings.showControls && !compact {
                Button { service.copy(entry) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copy")
                Button { service.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Remove")
            }
        }
        .padding(context.settings.clipboardRowStyle == .minimal ? 2 : 7)
        .background(context.settings.clipboardRowStyle == .tiles ? style.textColor.color.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    private func empty(icon: String, text: String) -> some View { VStack(spacing: 4) { Image(systemName: icon).foregroundStyle(style.accentColor.color); Text(text).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
    private func preview(_ text: String, limit: Int) -> String { let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines); return String(cleaned.prefix(max(8, limit))) + (cleaned.count > limit ? "…" : "") }
    private func contentIcon(_ text: String) -> String { if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), ["http", "https"].contains(url.scheme?.lowercased() ?? "") { return "link" }; return "text.quote" }
}

// MARK: - System

private struct VisualAdaptiveSystemView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var service: SystemService

    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .system, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    @State private var microMetricOffset = 0
    private var orderedMetrics: [VisualSystemMetric] { context.settings.resolvedSystemMetrics }
    private var microSelectedMetric: VisualSystemMetric { orderedMetrics.isEmpty ? context.settings.systemPrimaryMetric : orderedMetrics[abs(microMetricOffset) % orderedMetrics.count] }

    var body: some View {
        Group {
            switch context.family {
            case .micro: microMetric(microSelectedMetric)
            case .compact: HStack(spacing: 6) { ForEach(Array(orderedMetrics.prefix(2))) { metricCard($0, prominent: true) } }
            case .horizontal: horizontal
            case .vertical: vertical
            case .standard: standard
            case .expanded, .dashboard, .hero: dashboard
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
            .onAppear { service.refresh(detailed: true) }
    }

    private func microMetric(_ metric: VisualSystemMetric) -> some View {
        let value = metricValue(metric)
        return AdaptiveMicroRing(progress: value.percent.map { min(1, max(0, $0 / 100)) }, accent: metricColor(metric)) {
            VStack(spacing: 2) {
                Image(systemName: metric.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(metricColor(metric))
                Text(value.text).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.62)
                Text(metric.shortTitle.uppercased()).font(.system(size: 6.5, weight: .bold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1)
            }.padding(4)
        }
        .haloMicroInteraction(accent: metricColor(metric), help: "System · scroll metrics · hold for details", tapShowsPopover: true, onTap: {}) {
            VStack(alignment: .leading, spacing: 8) {
                Text("System").font(.headline)
                ForEach(Array(orderedMetrics.prefix(8).enumerated()), id: \.offset) { _, item in
                    let itemValue = metricValue(item)
                    Button { if let index = orderedMetrics.firstIndex(of: item) { microMetricOffset = index } } label: {
                        HStack { Image(systemName: item.symbol).frame(width: 18); Text(item.title); Spacer(); Text(itemValue.text).monospacedDigit().foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                }
            }.frame(width: 250)
        }
        .background(HaloMicroScrollCapture { delta in
            guard !orderedMetrics.isEmpty else { return }
            microMetricOffset = (microMetricOffset + (delta > 0 ? 1 : -1) + orderedMetrics.count) % orderedMetrics.count
        }.allowsHitTesting(true))
    }

    private var horizontal: some View {
        HStack(spacing: max(5, context.spacing)) {
            ForEach(Array(orderedMetrics.prefix(min(context.settings.maxItems, context.columns >= 7 ? 5 : max(2, context.columns))))) { metric in metricCard(metric, prominent: false) }
        }
    }
    private var vertical: some View {
        VStack(spacing: context.spacing) {
            ForEach(Array(orderedMetrics.prefix(min(context.settings.maxItems, max(2, context.rows + 1))))) { metric in metricRow(metric) }
            Spacer(minLength: 0)
        }
    }
    private var standard: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: context.spacing) { ForEach(Array(orderedMetrics.prefix(min(context.settings.maxItems, 4)))) { metricCard($0, prominent: false) } }
    }
    private var dashboard: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if style.showTitle { AdaptiveHeader(title: "SYSTEM", symbol: "gauge.with.dots.needle.50percent", style: style) }
            let graphMetrics = Array(orderedMetrics.filter { $0.supportsHistory }.prefix(context.family == .hero ? 2 : 1))
            if context.settings.systemShowGraphs && !graphMetrics.isEmpty {
                HStack(spacing: context.spacing) { ForEach(graphMetrics) { metric in VStack(alignment: .leading, spacing: 4) { metricCard(metric, prominent: true); AdaptiveMetricHistoryGraph(values: history(metric), accent: metricColor(metric), type: context.settings.systemGraphType).frame(height: context.family == .hero ? 70 : 46) } } }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: context.family == .hero ? 120 : 92), spacing: context.spacing)], spacing: context.spacing) {
                ForEach(Array(orderedMetrics.prefix(context.settings.maxItems))) { metricCard($0, prominent: false) }
            }
        }
    }

    private func metricCard(_ metric: VisualSystemMetric, prominent: Bool) -> some View {
        let value = metricValue(metric)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) { Image(systemName: metric.symbol).foregroundStyle(metricColor(metric)); Text(metric.shortTitle).font(.caption2).foregroundStyle(.secondary); Spacer(minLength: 0) }
            Text(value.text).font(.system(size: prominent ? 22 : 15, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func metricRow(_ metric: VisualSystemMetric) -> some View {
        let value = metricValue(metric)
        return VStack(spacing: 3) { HStack { Label(metric.title, systemImage: metric.symbol).font(.caption); Spacer(); Text(value.text).font(.caption.bold()).monospacedDigit() }; if let percent = value.percent { AdaptiveProgressBar(progress: percent / 100, accent: metricColor(metric), thickness: 4) } }
    }
    private func metricValue(_ metric: VisualSystemMetric) -> (text: String, percent: Double?) {
        switch metric {
        case .cpu: return (String(format: "%.0f%%", service.cpuUsage), service.cpuUsage)
        case .memory: return (String(format: "%.0f%%", service.memoryUsage), service.memoryUsage)
        case .storage: return (String(format: "%.0f%%", service.diskUsage), service.diskUsage)
        case .battery: let value = Double(service.battery ?? 0); return (service.battery.map { "\($0)%" } ?? "—", service.battery == nil ? nil : value)
        case .network: return (Self.rate(service.networkDownPerSecond) + " ↓", nil)
        case .swap: return (String(format: "%.0f%%", service.swapUsage), service.swapUsage)
        case .thermal: return (service.thermalState, nil)
        case .uptime: return (service.uptime.isEmpty ? "—" : service.uptime.replacingOccurrences(of: " uptime", with: ""), nil)
        }
    }
    private func metricColor(_ metric: VisualSystemMetric) -> Color { if let percent = metricValue(metric).percent, percent >= context.settings.systemWarningThreshold { return .orange }; return style.accentColor.color }
    private func history(_ metric: VisualSystemMetric) -> [Double] { switch metric { case .cpu: return service.cpuHistory; case .memory: return service.memoryHistory; case .network: return service.networkHistory; default: return [] } }
    private static func rate(_ bytes: Double) -> String { ByteCountFormatter.string(fromByteCount: Int64(max(0, bytes)), countStyle: .file) + "/s" }
}

private struct AdaptiveMetricHistoryGraph: View {
    let values: [Double]
    let accent: Color
    let type: VisualSystemGraphType
    var body: some View {
        GeometryReader { proxy in
            if type == .bars {
                HStack(alignment: .bottom, spacing: 1) { ForEach(Array(values.suffix(24).enumerated()), id: \.offset) { _, value in Capsule().fill(accent.opacity(0.75)).frame(maxWidth: .infinity, minHeight: 1, maxHeight: proxy.size.height * CGFloat(min(100, max(0, value)) / 100)) } }
            } else {
                Path { path in let list = Array(values.suffix(32)); guard list.count > 1 else { return }; let step = proxy.size.width / CGFloat(list.count - 1); for (i, value) in list.enumerated() { let point = CGPoint(x: CGFloat(i) * step, y: proxy.size.height * (1 - CGFloat(min(100, max(0, value)) / 100))); if i == 0 { path.move(to: point) } else { path.addLine(to: point) } } }.stroke(accent, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Launcher

private struct VisualAdaptiveLauncherView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @State private var query = ""

    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .launcher, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    private var visibleApps: [NSRunningApplication] { workspace.runningApps.filter { query.isEmpty || ($0.localizedName ?? "").localizedCaseInsensitiveContains(query) } }

    var body: some View {
        Group {
            switch context.family {
            case .micro: micro
            case .compact: appStrip(limit: 2)
            case .horizontal: appStrip(limit: min(6, context.columns))
            case .vertical: appList(limit: min(context.settings.maxItems, context.rows + 1))
            case .standard: standard
            case .expanded, .dashboard, .hero: large
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment).onAppear { workspace.refreshApps() }
    }

    @ViewBuilder private var micro: some View {
        let favorites = favoriteApps
        let primary = favorites.first
        let running = context.settings.launcherShowRunningApps ? workspace.runningApps.first : nil
        ZStack {
            if favorites.count > 1 {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(style.accentColor.color.opacity(0.12)).frame(width: 52, height: 52).offset(x: 7, y: 6)
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(style.textColor.color.opacity(0.08)).frame(width: 52, height: 52).offset(x: 3, y: 3)
            }
            Group {
                if let primary {
                    Button { NSWorkspace.shared.open(primary.url) } label: { Image(nsImage: primary.icon).resizable().scaledToFit().padding(9) }.buttonStyle(.plain)
                } else if let running {
                    Button { running.activate(options: .activateIgnoringOtherApps) } label: { appIcon(running, size: min(50, context.settings.launcherIconSize + 12)).padding(7) }.buttonStyle(.plain)
                } else {
                    Image(systemName: "app.dashed").font(.system(size: 26, weight: .medium)).foregroundStyle(style.accentColor.color)
                }
            }
            .frame(width: 58, height: 58)
            .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if favorites.count > 1 {
                Text("\(favorites.count)").font(.system(size: 7, weight: .bold, design: .rounded)).padding(4).background(style.accentColor.color, in: Circle()).foregroundStyle(.white).offset(x: 25, y: -25)
            }
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Launcher · click app · hold for group", onTap: {
            if let primary { NSWorkspace.shared.open(primary.url) } else { running?.activate(options: .activateIgnoringOtherApps) }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Launcher").font(.headline)
                ForEach(favorites.prefix(8), id: \.bundle) { app in
                    Button { NSWorkspace.shared.open(app.url) } label: { HStack { Image(nsImage: app.icon).resizable().frame(width: 22, height: 22); Text(app.name); Spacer() } }.buttonStyle(.plain)
                }
                if favorites.isEmpty { Text("No favorite apps configured.").font(.caption).foregroundStyle(.secondary) }
            }.frame(width: 230)
        }
    }

    private var microColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)]
    }

    private func microFavoriteButton(_ app: FavoriteApp) -> some View {
        Button { NSWorkspace.shared.open(app.url) } label: {
            Image(nsImage: app.icon)
                .resizable().scaledToFit()
                .frame(width: min(28, context.settings.launcherIconSize), height: min(28, context.settings.launcherIconSize))
                .frame(maxWidth: .infinity, minHeight: 31)
                .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(app.name)
    }

    private func microRunningButton(_ app: NSRunningApplication) -> some View {
        Button { app.activate(options: .activateIgnoringOtherApps) } label: {
            appIcon(app, size: min(28, context.settings.launcherIconSize))
                .frame(maxWidth: .infinity, minHeight: 31)
                .background(style.textColor.color.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(app.localizedName ?? "App")
    }
    private func appStrip(limit: Int) -> some View {
        HStack(spacing: context.spacing) {
            ForEach(Array(favoriteApps.prefix(limit)), id: \.bundle) { favoriteButton($0, compact: true) }
            if favoriteApps.isEmpty && context.settings.launcherShowRunningApps { ForEach(Array(visibleApps.prefix(limit)), id: \.processIdentifier) { runningButton($0, compact: true) } }
        }
    }
    private func appList(limit: Int) -> some View {
        VStack(spacing: context.spacing * 0.7) {
            if context.settings.launcherShowRunningApps { ForEach(Array(visibleApps.prefix(limit)), id: \.processIdentifier) { runningButton($0, compact: false) } }
            if !context.settings.launcherShowRunningApps || visibleApps.isEmpty { Text(context.settings.launcherShowRunningApps ? "No running apps" : "Running apps hidden").font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
    }
    private var standard: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if context.settings.launcherShowSearch { TextField("Search apps", text: $query) }
            if context.settings.launcherShowRunningApps { LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: min(context.settings.launcherColumns, max(2, context.columns))), spacing: context.spacing) { ForEach(Array(visibleApps.prefix(context.settings.maxItems)), id: \.processIdentifier) { runningButton($0, compact: true) } } }
        }
    }
    private var large: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if context.settings.launcherShowSearch { TextField("Search apps, files and actions…", text: $query).textFieldStyle(.roundedBorder) }
            if !favoriteApps.isEmpty {
                Text("FAVORITES").font(.caption2).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: min(context.settings.launcherColumns, max(2, context.columns))), spacing: context.spacing) { ForEach(favoriteApps, id: \.bundle) { favoriteButton($0, compact: true) } }
            }
            if context.settings.launcherShowRunningApps {
                Text("RUNNING").font(.caption2).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: min(context.settings.launcherColumns, max(2, context.columns))), spacing: context.spacing) { ForEach(Array(visibleApps.prefix(context.settings.maxItems)), id: \.processIdentifier) { runningButton($0, compact: true) } }
            }
            if context.family == .dashboard || context.family == .hero {
                HStack(spacing: context.spacing) {
                    if context.settings.launcherShowDownloads { Button { NSWorkspace.shared.open(FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]) } label: { Label("Downloads", systemImage: "arrow.down.circle") } }
                    if context.settings.launcherShowTimerActions { Button { store.startTimer(minutes: 25) } label: { Label("Start 25m Timer", systemImage: "timer") } }
                    if let recent = store.files.last { Button { NSWorkspace.shared.open(recent) } label: { Label(recent.lastPathComponent, systemImage: "clock.arrow.circlepath") }.lineLimit(1) }
                }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private struct FavoriteApp { let bundle: String; let url: URL; let name: String; let icon: NSImage }
    private var favoriteApps: [FavoriteApp] {
        context.settings.launcherFavoriteBundleIDs.compactMap { bundle in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return nil }
            let name = FileManager.default.displayName(atPath: url.path)
            return FavoriteApp(bundle: bundle, url: url, name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
        }
    }
    private func favoriteButton(_ app: FavoriteApp, compact: Bool) -> some View {
        Button { NSWorkspace.shared.open(app.url) } label: {
            if compact { VStack(spacing: 3) { Image(nsImage: app.icon).resizable().scaledToFit().frame(width: context.settings.launcherIconSize, height: context.settings.launcherIconSize); if context.settings.launcherShowLabels { Text(app.name).font(.caption2).lineLimit(1) } }.frame(maxWidth: .infinity) }
            else { HStack { Image(nsImage: app.icon).resizable().scaledToFit().frame(width: 24, height: 24); Text(app.name).lineLimit(1); Spacer() } }
        }.buttonStyle(.plain)
    }
    private func runningButton(_ app: NSRunningApplication, compact: Bool) -> some View {
        Button { app.activate(options: .activateIgnoringOtherApps) } label: {
            if compact { VStack(spacing: 3) { appIcon(app, size: context.settings.launcherIconSize); if context.settings.launcherShowLabels { Text(app.localizedName ?? "App").font(.caption2).lineLimit(1) } }.frame(maxWidth: .infinity) }
            else { HStack { appIcon(app, size: 22); Text(app.localizedName ?? "Application").font(.caption).lineLimit(1); Spacer() } }
        }.buttonStyle(.plain)
    }
    @ViewBuilder private func appIcon(_ app: NSRunningApplication, size: CGFloat) -> some View { if let icon = app.icon { Image(nsImage: icon).resizable().scaledToFit().frame(width: size, height: size) } else { Image(systemName: "app.fill").font(.system(size: size * 0.75)).foregroundStyle(style.accentColor.color) } }
}

// MARK: - Activities

private struct VisualAdaptiveActivitiesView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var workspace: WorkspaceStore
    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .activities, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    private var activities: [LiveActivity] { Array(workspace.activities.prefix(context.settings.maxItems)) }

    var body: some View {
        Group {
            switch context.family {
            case .micro: micro
            case .compact, .horizontal: compact
            case .vertical: list(limit: min(context.settings.maxItems, context.rows + 1), rich: false)
            case .standard: list(limit: min(context.settings.maxItems, 3), rich: false)
            case .expanded, .dashboard, .hero: list(limit: context.settings.maxItems, rich: true)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
    }
    private var micro: some View {
        let first = activities.first
        return AdaptiveMicroRing(progress: first?.progress, accent: style.accentColor.color) {
            VStack(spacing: 1) {
                Image(systemName: workspace.activities.isEmpty ? "checkmark" : "waveform.path")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(style.accentColor.color)
                Text("\(workspace.activities.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(workspace.activities.isEmpty ? "QUIET" : "LIVE")
                    .font(.system(size: 6.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
    private var compact: some View { Group { if let activity = activities.first { HStack(spacing: 8) { Image(systemName: "waveform.path").foregroundStyle(style.accentColor.color); Text(activity.title).font(.system(size: 11, weight: .semibold)).lineLimit(1); Spacer(); if context.settings.activitiesShowProgress, let p = activity.progress { Text("\(Int(p * 100))%").font(.caption).monospacedDigit() } } } else { Label("All Quiet", systemImage: "checkmark.circle").foregroundStyle(.secondary) } } }
    private func list(limit: Int, rich: Bool) -> some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if rich && style.showTitle { AdaptiveHeader(title: "LIVE", symbol: "waveform.path", style: style) }
            if activities.isEmpty { Spacer(); HStack { Spacer(); Label("All Quiet", systemImage: "checkmark.circle").foregroundStyle(.secondary); Spacer() }; Spacer() }
            ForEach(Array(activities.prefix(limit))) { activity in activityRow(activity, rich: rich) }
            Spacer(minLength: 0)
        }
    }
    private func activityRow(_ activity: LiveActivity, rich: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(activity.title).font(.system(size: rich ? 13 : 11, weight: .semibold)).lineLimit(1); Spacer(); if context.settings.activitiesShowProgress, let p = activity.progress { Text("\(Int(p * 100))%").font(.caption).monospacedDigit() } }
            if context.settings.activitiesShowDetails && !activity.detail.isEmpty { Text(activity.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(rich ? 2 : 1) }
            if context.settings.activitiesShowProgress, let p = activity.progress { AdaptiveProgressBar(progress: p, accent: style.accentColor.color, thickness: rich ? 5 : 3) }
            if rich && context.settings.activitiesShowTimestamps { Text(activity.created, style: .relative).font(.caption2).foregroundStyle(.tertiary) }
        }
    }
}

// MARK: - Notes

private struct VisualAdaptiveNotesView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var workspace: WorkspaceStore
    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .notes, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }
    private var note: Binding<String> { $workspace.settings.notes }
    private var trimmed: String { workspace.settings.notes.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Group {
            switch context.family {
            case .micro:
                preview(lines: 3)
                    .haloMicroInteraction(accent: style.accentColor.color, help: "Quick Note · click or hold to write", tapShowsPopover: true, onTap: {}) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Note").font(.headline)
                            TextEditor(text: note).frame(width: 300, height: 150)
                            HStack { Spacer(); Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(workspace.settings.notes, forType: .string) }.disabled(workspace.settings.notes.isEmpty) }
                        }
                    }
            case .compact, .horizontal: preview(lines: 2)
            case .vertical: editor(showHeader: true)
            case .standard, .expanded, .dashboard, .hero: editor(showHeader: style.showTitle)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func preview(lines: Int) -> some View {
        let isMicro = context.family == .micro
        let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count
        return VStack(alignment: .leading, spacing: isMicro ? 4 : 4) {
            if isMicro {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(style.accentColor.color)
                    Text("NOTE")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    if context.settings.notesShowCounts {
                        Text("\(words)w")
                            .font(.system(size: 7, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if isMicro {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule().fill(index == 0 ? style.accentColor.color.opacity(0.55) : style.textColor.color.opacity(0.14))
                            .frame(width: index == 2 ? 28 : index == 1 ? 42 : 50, height: 3)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                Text(trimmed.isEmpty ? context.settings.notesPlaceholder : trimmed)
                    .font(style.font(scale: 0.86))
                    .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
                    .lineLimit(lines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(isMicro ? 7 : 0)
        .background {
            if isMicro {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(style.textColor.color.opacity(0.035))
            }
        }
        .overlay(alignment: .leading) {
            if isMicro {
                Capsule().fill(style.accentColor.color.opacity(0.72)).frame(width: 2.5).padding(.vertical, 8)
            }
        }
    }
    private func editor(showHeader: Bool) -> some View {
        VStack(alignment: .leading, spacing: context.spacing * 0.7) {
            if showHeader { HStack { Text("Quick Note").font(style.font(scale: 0.9)).fontWeight(.semibold); Spacer(); if context.settings.notesShowCounts { Text(noteStats).font(.caption2).foregroundStyle(.secondary) } } }
            ZStack(alignment: .topLeading) {
                if workspace.settings.notes.isEmpty { Text(context.settings.notesPlaceholder).foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 7).allowsHitTesting(false) }
                TextEditor(text: note).font(style.font()).lineSpacing(context.settings.notesLineSpacing).scrollContentBackground(.hidden)
            }.padding(context.settings.notesEditorPadding).frame(maxWidth: .infinity, maxHeight: .infinity)
            if context.settings.notesShowCounts && !showHeader { HStack { Spacer(); Text(noteStats).font(.caption2).foregroundStyle(.secondary) } }
        }
    }
    private var noteStats: String { let words = workspace.settings.notes.split { $0.isWhitespace || $0.isNewline }.count; return "\(words) words · \(workspace.settings.notes.count) chars" }
}

// MARK: - Capture

private struct VisualAdaptiveCaptureView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var service: CaptureService
    @ObservedObject var store: AppStore
    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .capture, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }

    var body: some View {
        Group {
            switch context.family {
            case .micro:
                primaryAction(iconOnly: true)
                    .haloMicroInteraction(accent: style.accentColor.color, help: "Capture · click region · hold for capture tools") {
                        service.capture { store.addFiles([$0]) }
                    } popover: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capture").font(.headline)
                            Button { service.capture { store.addFiles([$0]) } } label: { Label("Capture Region", systemImage: "viewfinder") }
                            Button { service.chooseImage() } label: { Label("OCR Image", systemImage: "text.viewfinder") }
                            if service.busy { ProgressView("Working…") }
                            if !service.recognizedText.isEmpty { Text(service.recognizedText).font(.caption).lineLimit(4).textSelection(.enabled) }
                        }.frame(width: 250)
                    }
            case .compact, .horizontal: compactActions
            case .vertical: vertical
            case .standard: standard
            case .expanded, .dashboard, .hero: large
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
    }
    private var compactActions: some View { HStack(spacing: context.spacing) { captureButton; ocrButton }.disabled(service.busy) }
    private var vertical: some View { VStack(spacing: context.spacing) { captureButton; ocrButton; if service.busy { ProgressView().controlSize(.small) }; if context.settings.captureShowOCR && !service.recognizedText.isEmpty && context.rows >= 3 { Text(service.recognizedText).font(.caption2).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading) } }.disabled(service.busy) }
    private var standard: some View { VStack(alignment: .leading, spacing: context.spacing) { compactActions; if service.busy { ProgressView("Working…") }; if context.settings.captureShowOCR && !service.recognizedText.isEmpty { Text(service.recognizedText).textSelection(.enabled).lineLimit(6) } } }
    private var large: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if style.showTitle { AdaptiveHeader(title: "CAPTURE", symbol: "viewfinder", style: style) }
            HStack(spacing: context.spacing) { captureButton; ocrButton }
            if service.busy { ProgressView("Working…") }
            if context.settings.captureShowRecent, let recent = service.recentCaptures.first {
                HStack(alignment: .top, spacing: context.spacing) {
                    CaptureThumbnail(url: recent).frame(width: context.settings.captureThumbnailSize, height: context.settings.captureThumbnailSize * 0.62).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) { Text("RECENT").font(.caption2).foregroundStyle(.secondary); Text(recent.lastPathComponent).font(.caption).lineLimit(2); HStack { Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([recent]) }; Button("Quick Look") { store.shelfPreview.show(recent) } }.buttonStyle(.borderless).controlSize(.small) }
                }
            }
            if context.settings.captureShowOCR && !service.recognizedText.isEmpty {
                Divider().opacity(0.18)
                Text("OCR RESULT").font(.caption2).foregroundStyle(.secondary)
                ScrollView { Text(service.recognizedText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack { Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(service.recognizedText, forType: .string) }; Button("Clear") { service.recognizedText = "" } }.buttonStyle(.bordered).controlSize(.small)
            }
            if let error = service.error { Text(error).font(.caption).foregroundStyle(.orange) }
        }
    }
    @ViewBuilder private func primaryAction(iconOnly: Bool) -> some View {
        let region = context.settings.capturePrimaryAction == .region
        Button { region ? capture() : service.chooseImage() } label: {
            if iconOnly {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(style.accentColor.color.opacity(0.055))
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(style.accentColor.color.opacity(0.42), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    VStack(spacing: 4) {
                        if service.busy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: region ? "viewfinder" : "text.viewfinder")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(style.accentColor.color)
                        }
                        Text(region ? "CAPTURE" : "OCR")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(3)
            } else {
                Label(region ? "Capture" : "OCR", systemImage: region ? "viewfinder" : "text.viewfinder")
            }
        }
        .buttonStyle(.plain)
        .disabled(service.busy)
    }
    private var captureButton: some View { Button { capture() } label: { Label("Capture", systemImage: "viewfinder").frame(maxWidth: .infinity) }.buttonStyle(.bordered) }
    private var ocrButton: some View { Button { service.chooseImage() } label: { Label("OCR", systemImage: "text.viewfinder").frame(maxWidth: .infinity) }.buttonStyle(.bordered) }
    private func capture() { service.capture { url in store.addFiles([url]) } }
}

private struct CaptureThumbnail: View {
    let url: URL
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { ZStack { Color.primary.opacity(0.04); Image(systemName: "photo").foregroundStyle(.secondary) } }
        }
        .onAppear { image = NSImage(contentsOf: url) }
        .onChange(of: url) { newURL in image = NSImage(contentsOf: newURL) }
    }
}

// MARK: - Stopwatch

private struct VisualAdaptiveStopwatchView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var workspace: WorkspaceStore
    private var context: AdaptiveResolvedContext { AdaptiveResolvedContext(module: .stopwatch, style: style, columns: gridColumnSpan, rows: gridRowSpan, width: availableWidth, height: availableHeight) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: context.settings.stopwatchPrecision.interval)) { timeline in
            let elapsed = workspace.stopwatchElapsed + (workspace.stopwatchStart.map { timeline.date.timeIntervalSince($0) } ?? 0)
            content(elapsed: elapsed)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
    }
    @ViewBuilder private func content(elapsed: TimeInterval) -> some View {
        switch context.family {
        case .micro: microStopwatch(elapsed: elapsed)
        case .compact: HStack { timeText(elapsed, scale: 0.9); Spacer(); primaryStopwatchControl }
        case .horizontal: HStack(spacing: context.spacing) { timeText(elapsed, scale: 1.0); Spacer(); stopwatchControls(compact: true) }
        case .vertical: VStack(spacing: context.spacing) { timeText(elapsed, scale: 1.05); if context.settings.stopwatchShowLaps { lapList(limit: min(context.settings.stopwatchLapCount, max(1, context.rows - 1))) }; stopwatchControls(compact: true); Spacer(minLength: 0) }
        case .standard: VStack(spacing: context.spacing) { timeText(elapsed, scale: 1.25); stopwatchControls(compact: false); if context.settings.stopwatchShowLaps { lapList(limit: min(3, context.settings.stopwatchLapCount)) } }
        case .expanded, .dashboard, .hero: hero(elapsed: elapsed)
        }
    }
    private func microStopwatch(elapsed: TimeInterval) -> some View {
        let sweep = min(1, max(0, elapsed.truncatingRemainder(dividingBy: 60) / 60))
        return AdaptiveMicroRing(progress: sweep, accent: style.accentColor.color) {
            VStack(spacing: 2) {
                Image(systemName: workspace.stopwatchStart == nil ? "pause.fill" : "stopwatch.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(style.accentColor.color)
                Text(microStopwatchTime(elapsed)).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.58).contentTransition(.numericText())
            }.padding(5)
        }
        .haloMicroInteraction(accent: style.accentColor.color, help: "Stopwatch · click start/pause · hold for laps") {
            workspace.toggleStopwatch()
        } popover: {
            VStack(alignment: .leading, spacing: 9) {
                Text("Stopwatch").font(.headline)
                Text(format(elapsed)).font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                HStack {
                    Button(workspace.stopwatchStart == nil ? "Start" : "Pause") { workspace.toggleStopwatch() }
                    if workspace.stopwatchStart != nil { Button("Lap") { workspace.lapStopwatch() } }
                    Button("Reset") { workspace.resetStopwatch() }.disabled(elapsed < 0.01)
                }
                ForEach(Array(workspace.stopwatchLaps.suffix(4).enumerated()), id: \.offset) { index, lap in
                    HStack { Text("Lap \(workspace.stopwatchLaps.count - 3 + index)"); Spacer(); Text(format(lap)).monospacedDigit() }.font(.caption)
                }
            }.frame(width: 250)
        }
    }

    private func microStopwatchTime(_ elapsed: TimeInterval) -> String {
        if elapsed < 60 { return String(format: "%.1f", elapsed) }
        let total = Int(elapsed)
        if total < 3600 { return String(format: "%d:%02d", total / 60, total % 60) }
        return String(format: "%d:%02d", total / 3600, (total / 60) % 60)
    }

    private func hero(elapsed: TimeInterval) -> some View { VStack(spacing: context.spacing) { if style.showTitle { AdaptiveHeader(title: "STOPWATCH", symbol: "stopwatch", style: style) }; Spacer(minLength: 0); timeText(elapsed, scale: context.family == .hero ? 1.9 : 1.55); stopwatchControls(compact: false); if context.settings.stopwatchShowLaps { Divider().opacity(0.16); HStack { Text("LAPS").font(.caption2).foregroundStyle(.secondary); Spacer() }; lapList(limit: context.settings.stopwatchLapCount) }; Spacer(minLength: 0) } }
    private func timeText(_ elapsed: TimeInterval, scale: Double) -> some View { Text(format(elapsed)).font(.system(size: max(18, style.fontSize * scale * context.settings.stopwatchTimeScale), weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.55).contentTransition(.numericText()) }
    @ViewBuilder private var primaryStopwatchControl: some View { if context.settings.showControls { Button { workspace.toggleStopwatch() } label: { Image(systemName: workspace.stopwatchStart == nil ? "play.fill" : "pause.fill") }.buttonStyle(.plain) } }
    @ViewBuilder private func stopwatchControls(compact: Bool) -> some View { if context.settings.showControls { HStack(spacing: context.spacing) { if workspace.stopwatchStart != nil && context.settings.stopwatchShowLaps { Button(compact ? "Lap" : "Lap") { workspace.lapStopwatch() } }; Button(workspace.stopwatchStart == nil ? (workspace.stopwatchElapsed > 0 ? "Resume" : "Start") : "Pause") { workspace.toggleStopwatch() }; if !compact || context.columns >= 4 { Button("Reset") { workspace.resetStopwatch() } } }.buttonStyle(.bordered).controlSize(compact ? .mini : .small) } }
    private func lapList(limit: Int) -> some View {
        let laps = Array(workspace.stopwatchLaps.suffix(limit).enumerated())
        let fastest = workspace.stopwatchLaps.min()
        let slowest = workspace.stopwatchLaps.max()
        return VStack(spacing: 4) {
            ForEach(Array(laps.reversed()), id: \.offset) { offset, lap in
                let number = workspace.stopwatchLaps.count - offset
                HStack { Text(String(format: "%02d", number)).font(.caption2).foregroundStyle(.secondary).frame(width: 28, alignment: .leading); Text(format(lap)).font(.system(size: 11, weight: .medium, design: .monospaced)); Spacer(); if context.settings.stopwatchShowLapExtremes && workspace.stopwatchLaps.count > 1 { if lap == fastest { Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green) } else if lap == slowest { Image(systemName: "arrow.up.circle.fill").foregroundStyle(.orange) } } }
            }
        }
    }
    private func format(_ value: TimeInterval) -> String {
        let clamped = max(0, value)
        let whole = Int(clamped)
        let minutes = whole / 60
        let seconds = whole % 60
        switch context.settings.stopwatchPrecision {
        case .seconds: return String(format: "%02d:%02d", minutes, seconds)
        case .tenths: return String(format: "%02d:%02d.%01d", minutes, seconds, Int((clamped * 10).truncatingRemainder(dividingBy: 10)))
        case .hundredths: return String(format: "%02d:%02d.%02d", minutes, seconds, Int((clamped * 100).truncatingRemainder(dividingBy: 100)))
        }
    }
}
