from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing pattern: {label}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# 1. Closed-notch per-widget model
# -----------------------------------------------------------------------------
p = Path("Halo/Core/WidgetModels.swift")
s = p.read_text()
old = '''enum ClosedNotchItem: String, Codable, CaseIterable, Identifiable {
    case none, clock, date, timer, battery, media, visualizer, mirror, files, activity
    var id: String { rawValue }
}
'''
new = '''enum ClosedNotchItem: String, Codable, CaseIterable, Identifiable {
    case none, clock, date, timer, battery, media, visualizer, mirror, files, activity
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .clock: return "Clock"
        case .date: return "Date"
        case .timer: return "Timer"
        case .battery: return "Battery"
        case .media: return "Media text"
        case .visualizer: return "Visualizer"
        case .mirror: return "Mirror"
        case .files: return "File count"
        case .activity: return "Live activity"
        }
    }
}

enum ClosedNotchWidgetAlignment: String, Codable, CaseIterable, Identifiable {
    case automatic, leading, center, trailing
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ClosedNotchDateStyle: String, Codable, CaseIterable, Identifiable {
    case monthDay, numeric, weekday, weekdayMonthDay
    var id: String { rawValue }
    var title: String {
        switch self {
        case .monthDay: return "Sep 28"
        case .numeric: return "09/28"
        case .weekday: return "Monday"
        case .weekdayMonthDay: return "Mon, Sep 28"
        }
    }
    var measurementTemplate: String {
        switch self {
        case .monthDay: return "Sep 28"
        case .numeric: return "09/28"
        case .weekday: return "Wednesday"
        case .weekdayMonthDay: return "Wed, Sep 28"
        }
    }
}

/// Styling for one Closed Notch content type. The dictionary containing these values is optional,
/// so profiles created before per-widget customization continue to use Halo's legacy/global look.
struct ClosedNotchWidgetStyle: Codable, Equatable {
    var fontFamily: WidgetFontFamily = .system
    var customFont = "Helvetica Neue"
    var weight: WidgetFontWeight = .medium
    var fontSize = 12.0
    var textColor = WidgetColor.white
    var accentColor = WidgetColor.white
    var backgroundColor = WidgetColor(red: 0.10, green: 0.10, blue: 0.12)
    var backgroundOpacity = 0.0
    var padding = 0.0
    var cornerRadius = 8.0
    var opacity = 1.0
    var iconSize = 14.0
    var spacing = 5.0
    /// 0 means natural/content-fit width. A positive value reserves exactly this much widget space.
    var width = 0.0
    var horizontalOffset = 0.0
    var verticalOffset = 0.0
    var alignment: ClosedNotchWidgetAlignment = .automatic
    var showIcon = true
    var showText = true
    var clock = ClockOptions()
    var dateStyle: ClosedNotchDateStyle = .monthDay
    var activityShowDetail = true
    var activityShowProgress = true

    func validated() throws -> ClosedNotchWidgetStyle {
        let numbers = [fontSize, backgroundOpacity, padding, cornerRadius, opacity, iconSize,
                       spacing, width, horizontalOffset, verticalOffset]
        guard numbers.allSatisfy(\\.isFinite),
              clock.timeZone.isEmpty || TimeZone(identifier: clock.timeZone) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var value = self
        value.fontSize = min(32, max(7, fontSize))
        value.backgroundOpacity = min(1, max(0, backgroundOpacity))
        value.padding = min(24, max(0, padding))
        value.cornerRadius = min(32, max(0, cornerRadius))
        value.opacity = min(1, max(0.1, opacity))
        value.iconSize = min(36, max(7, iconSize))
        value.spacing = min(24, max(0, spacing))
        value.width = width <= 0 ? 0 : min(420, max(24, width))
        value.horizontalOffset = min(160, max(-160, horizontalOffset))
        value.verticalOffset = min(80, max(-80, verticalOffset))
        value.textColor = try textColor.validated()
        value.accentColor = try accentColor.validated()
        value.backgroundColor = try backgroundColor.validated()
        value.customFont = String(customFont.prefix(120))
        return value
    }
}
'''
s = replace_once(s, old, new, "closed item model")
old = '''    var visualizer: VisualizerOptions?
    var expansion: ClosedExpansionOptions?
    var left: ClosedNotchItem = .clock
'''
new = '''    var visualizer: VisualizerOptions?
    var expansion: ClosedExpansionOptions?
    /// Optional per-item styles. Missing entries intentionally fall back to the legacy/global style.
    var widgetStyles: [String: ClosedNotchWidgetStyle]?
    var left: ClosedNotchItem = .clock
'''
s = replace_once(s, old, new, "widget style storage")
old = '''    var animation: PlaybackAnimation = .bars
    var animate = true
    func validated() throws -> ClosedNotchOptions {
'''
new = '''    var animation: PlaybackAnimation = .bars
    var animate = true

    func widgetStyle(for item: ClosedNotchItem) -> ClosedNotchWidgetStyle? {
        widgetStyles?[item.rawValue]
    }
    mutating func setWidgetStyle(_ style: ClosedNotchWidgetStyle, for item: ClosedNotchItem) {
        guard item != .none else { return }
        if widgetStyles == nil { widgetStyles = [:] }
        widgetStyles?[item.rawValue] = style
    }
    mutating func resetWidgetStyle(for item: ClosedNotchItem) {
        widgetStyles?.removeValue(forKey: item.rawValue)
        if widgetStyles?.isEmpty == true { widgetStyles = nil }
    }

    func validated() throws -> ClosedNotchOptions {
'''
s = replace_once(s, old, new, "widget style helpers")
old = '''        v.reactiveBackground = try reactiveBackground?.validated()
        v.powerReaction = try powerReaction?.validated()
        if var expansion {
'''
new = '''        v.reactiveBackground = try reactiveBackground?.validated()
        v.powerReaction = try powerReaction?.validated()
        if let widgetStyles {
            var cleaned: [String: ClosedNotchWidgetStyle] = [:]
            for (key, style) in widgetStyles.prefix(24) {
                guard let item = ClosedNotchItem(rawValue: key), item != .none else { continue }
                cleaned[key] = try style.validated()
            }
            v.widgetStyles = cleaned.isEmpty ? nil : cleaned
        }
        if var expansion {
'''
s = replace_once(s, old, new, "widget style validation")
p.write_text(s)

# -----------------------------------------------------------------------------
# 2. SurfaceState + Drop CI runtime
# -----------------------------------------------------------------------------
p = Path("Halo/NotchEngine/WindowManager.swift")
s = p.read_text()
old = '''    @Published var theme = Theme()
    @Published var layoutOverride: WorkspaceLayout?
    @Published var contextPreferredSize: CGSize?
    var collapseTask: Task<Void, Never>?
'''
new = '''    @Published var theme = Theme()
    @Published var layoutOverride: WorkspaceLayout?
    @Published var contextPreferredSize: CGSize?
    /// Per-surface drag state. Keeping this on SurfaceState means multi-display drag CIs only
    /// activate on the display currently underneath the dragged file/folder.
    @Published var dropTargeted = false
    @Published var dropItemCount = 0
    var collapseTask: Task<Void, Never>?
'''
s = replace_once(s, old, new, "surface drop state")
p.write_text(s)

# -----------------------------------------------------------------------------
# 3. SurfaceView Drop CI and drop delegate
# -----------------------------------------------------------------------------
p = Path("Halo/Views/SurfaceView.swift")
s = p.read_text()
s = replace_once(s,
'''private enum ActiveContextInterface: String {
    case music, bluetooth, retro
}
''',
'''private enum ActiveContextInterface: String {
    case drop, music, bluetooth, retro
}
''', "active context drop case")
old = '''    @AppStorage("HaloContextMusicPriority") private var contextMusicPriority = 60.0
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothCIEnabled = false
'''
new = '''    @AppStorage("HaloContextMusicPriority") private var contextMusicPriority = 60.0
    @AppStorage("HaloContextDropEnabled") private var dropCIEnabled = true
    @AppStorage("HaloContextDropUseFullNotchArea") private var dropUsesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var dropKeepsClosedContents = false
    @AppStorage("HaloContextDropPriority") private var dropPriority = 100.0
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothCIEnabled = false
'''
s = replace_once(s, old, new, "drop CI storage")
old = '''    private var activeContext: ActiveContextInterface? {
        var candidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] = []
        if retroCIEnabled && retroGameRequested {
'''
new = '''    private var activeContext: ActiveContextInterface? {
        var candidates: [(interface: ActiveContextInterface, priority: Double, tieRank: Int)] = []
        if dropCIEnabled && state.dropTargeted {
            candidates.append((.drop, dropPriority, 4))
        }
        if retroCIEnabled && retroGameRequested {
'''
s = replace_once(s, old, new, "drop priority candidate")
old = '''    private var contextMusicActive: Bool { activeContext == .music }
    private var bluetoothContextActive: Bool { activeContext == .bluetooth }
    private var retroContextActive: Bool { activeContext == .retro }
'''
new = '''    private var dropContextActive: Bool { activeContext == .drop }
    private var contextMusicActive: Bool { activeContext == .music }
    private var bluetoothContextActive: Bool { activeContext == .bluetooth }
    private var retroContextActive: Bool { activeContext == .retro }
'''
s = replace_once(s, old, new, "drop active helper")
old = '''        switch activeContext {
        case .music: return contextMusicUsesFullNotchArea
        case .bluetooth: return bluetoothUsesFullNotchArea
'''
new = '''        switch activeContext {
        case .drop: return dropUsesFullNotchArea
        case .music: return contextMusicUsesFullNotchArea
        case .bluetooth: return bluetoothUsesFullNotchArea
'''
s = replace_once(s, old, new, "drop full surface")
old = '''        switch activeContext {
        case .music: return contextMusicKeepsClosedContents
        case .bluetooth: return bluetoothKeepsClosedContents
'''
new = '''        switch activeContext {
        case .drop: return dropKeepsClosedContents
        case .music: return contextMusicKeepsClosedContents
        case .bluetooth: return bluetoothKeepsClosedContents
'''
s = replace_once(s, old, new, "drop keep closed")
s = replace_once(s, '''    @State private var targeted = false
''', '', "remove local targeted")
old = '''                if state.expanded {
                    if contextMusicActive {
'''
new = '''                if state.expanded {
                    if dropContextActive {
                        if !dropUsesFullNotchArea {
                            DropContextView(itemCount: state.dropItemCount, surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if contextMusicActive {
'''
s = replace_once(s, old, new, "drop normal expanded route")
old = '''                Group {
                    if contextMusicActive {
                        ContextMusicView(media: workspace.media, options: contextOptions,
'''
new = '''                Group {
                    if dropContextActive {
                        DropContextView(itemCount: state.dropItemCount, surfaceState: state)
                    } else if contextMusicActive {
                        ContextMusicView(media: workspace.media, options: contextOptions,
'''
s = replace_once(s, old, new, "drop full surface route")
s = replace_once(s,
'''        .overlay(contour.stroke(targeted ? accent : .white.opacity(0.12), lineWidth: 1))
''',
'''        .overlay(contour.stroke(state.dropTargeted ? accent : .white.opacity(0.12), lineWidth: state.dropTargeted ? 1.6 : 1))
''', "drop contour")
s = replace_once(s,
'''        .onChange(of: targeted) { active in
            if active { state.collapseTask?.cancel(); state.expanded = true }
        }
''',
'''        .onChange(of: state.dropTargeted) { active in
            if active {
                state.collapseTask?.cancel()
                state.expanded = true
            }
        }
''', "drop targeted change")
old = '''        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $targeted) { providers in
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
'''
new = '''        .onDrop(of: [UTType.fileURL.identifier], delegate: HaloFileDropDelegate(
            targeted: $state.dropTargeted,
            itemCount: $state.dropItemCount,
            perform: acceptFileDrop
        ))
    }

    private func acceptFileDrop(_ providers: [NSItemProvider]) {
        state.expanded = true
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in store.addFiles([url]) }
            }
        }
    }

    private func horizontalWidget(_ module: ModuleID) -> some View {
'''
s = replace_once(s, old, new, "drop delegate hook")

# Insert Drop CI + DropDelegate before BuiltinOrIntegrationWidget.
anchor = '''struct BuiltinOrIntegrationWidget: View {
'''
insert = '''private struct HaloFileDropDelegate: DropDelegate {
    @Binding var targeted: Bool
    @Binding var itemCount: Int
    let perform: ([NSItemProvider]) -> Void

    private func providers(_ info: DropInfo) -> [NSItemProvider] {
        info.itemProviders(for: [UTType.fileURL.identifier])
    }

    func validateDrop(info: DropInfo) -> Bool {
        !providers(info).isEmpty
    }

    func dropEntered(info: DropInfo) {
        let values = providers(info)
        targeted = !values.isEmpty
        itemCount = values.count
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let values = providers(info)
        targeted = !values.isEmpty
        itemCount = values.count
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        targeted = false
        itemCount = 0
    }

    func performDrop(info: DropInfo) -> Bool {
        let values = providers(info)
        guard !values.isEmpty else {
            targeted = false
            itemCount = 0
            return false
        }
        targeted = false
        itemCount = 0
        perform(values)
        return true
    }
}

private struct DropContextView: View {
    let itemCount: Int
    @ObservedObject var surfaceState: SurfaceState
    @AppStorage("HaloContextDropUseFullNotchArea") private var usesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextDropPriority") private var priority = 100.0
    @Environment(\\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var count: Int { max(1, itemCount) }
    private var topInset: Double {
        if usesFullNotchArea && keepsClosedNotchContents { return max(24, surfaceState.compactHeight + 14) }
        if usesFullNotchArea { return max(22, surfaceState.compactHeight * 0.72) }
        return 22
    }
    private var preferredSize: CGSize { CGSize(width: 520, height: 270 + max(0, topInset - 22)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.accentColor.opacity(0.24), Color.blue.opacity(0.10), Color.black.opacity(0.72)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 84, height: 84)
                        .scaleEffect(pulse && !reduceMotion ? 1.08 : 0.96)
                    Circle()
                        .stroke(Color.accentColor.opacity(0.42), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .frame(width: 84, height: 84)
                    Image(systemName: count == 1 ? "doc.fill.badge.plus" : "doc.on.doc.fill")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 5) {
                    Text("Drop into Halo")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text(count == 1 ? "Release to add this item to File Shelf" : "Release to add \\(count) items to File Shelf")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    dropCapability("Original stays untouched", symbol: "lock.shield")
                    dropCapability("Quick Look", symbol: "eye")
                    dropCapability("Pin later", symbol: "pin")
                }

                HStack(spacing: 5) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Ready to copy references · CI priority \\(Int(priority))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, topInset)
            .padding(.bottom, 22)
        }
        .clipShape(RoundedRectangle(cornerRadius: usesFullNotchArea ? 0 : 20, style: .continuous))
        .task { publishPreferredSize() }
        .onChange(of: itemCount) { _ in publishPreferredSize() }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onDisappear { surfaceState.contextPreferredSize = nil }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drop \\(count) item\\(count == 1 ? "" : "s") into Halo")
    }

    private func dropCapability(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.07), in: Capsule())
    }

    private func publishPreferredSize() {
        let next = preferredSize
        DispatchQueue.main.async { [surfaceState] in
            if let current = surfaceState.contextPreferredSize,
               abs(current.width - next.width) < 1, abs(current.height - next.height) < 1 { return }
            surfaceState.contextPreferredSize = next
        }
    }
}

'''
if anchor not in s:
    raise SystemExit("missing BuiltinOrIntegrationWidget anchor")
s = s.replace(anchor, insert + anchor, 1)
p.write_text(s)

# -----------------------------------------------------------------------------
# 4. EI/router awareness of Drop CI (does not enable EI)
# -----------------------------------------------------------------------------
p = Path("Halo/Core/ExtensionContracts.swift")
s = p.read_text()
s = replace_once(s,
'''private enum RoutedContextInterface: String { case music, bluetooth, retro }
''',
'''private enum RoutedContextInterface: String { case drop, music, bluetooth, retro }
''', "routed drop case")
old = '''    @AppStorage("HaloContextMusicPriority") private var musicPriority = 60.0
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false
'''
new = '''    @AppStorage("HaloContextMusicPriority") private var musicPriority = 60.0
    @AppStorage("HaloContextDropEnabled") private var dropEnabled = true
    @AppStorage("HaloContextDropPriority") private var dropPriority = 100.0
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false
'''
s = replace_once(s, old, new, "router drop storage")
old = '''    private var activeCI: RoutedContextInterface? {
        var candidates: [(RoutedContextInterface, Double, Int)] = []
        if retroEnabled && engine.retroGameRequested { candidates.append((.retro, retroPriority, 3)) }
'''
new = '''    private var activeCI: RoutedContextInterface? {
        var candidates: [(RoutedContextInterface, Double, Int)] = []
        if dropEnabled && state.dropTargeted { candidates.append((.drop, dropPriority, 4)) }
        if retroEnabled && engine.retroGameRequested { candidates.append((.retro, retroPriority, 3)) }
'''
s = replace_once(s, old, new, "router drop candidate")
p.write_text(s)

# -----------------------------------------------------------------------------
# 5. ClosedNotch renderer per-widget styling
# -----------------------------------------------------------------------------
p = Path("Halo/Views/ClosedNotchView.swift")
s = p.read_text()
old = '''    private var elementSpacing: Double { layoutMetrics.elementSpacing }
    private var activeActivity: LiveActivity? { activity }
    private var innerHeight: Double { layoutMetrics.contentHeight }
'''
new = '''    private var elementSpacing: Double { layoutMetrics.elementSpacing }
    private var activeActivity: LiveActivity? { activity }
    private var innerHeight: Double { layoutMetrics.contentHeight }
    private var widgetStyle: ClosedNotchWidgetStyle? { options.widgetStyle(for: item) }
    private var widgetElementSpacing: Double { widgetStyle?.spacing ?? elementSpacing }
    private var widgetTextSize: Double { min(widgetStyle?.fontSize ?? textSize, max(7, innerHeight)) }
    private var widgetShowsIcon: Bool { widgetStyle?.showIcon ?? true }
    private var widgetShowsText: Bool { widgetStyle?.showText ?? true }
    private var widgetIconSize: Double { min(widgetStyle?.iconSize ?? max(12, widgetTextSize + 2), innerHeight) }
    private var widgetTextColor: Color { widgetStyle?.textColor.color ?? effectiveTextColor }
    private var widgetAccentColor: Color { widgetStyle?.accentColor.color ?? widgetTextColor }
    private var widgetBodyWidthLimit: Double {
        guard let widgetStyle, widgetStyle.width > 0 else { return innerWidth }
        return max(12, min(innerWidth, widgetStyle.width) - 2 * widgetStyle.padding)
    }
'''
s = replace_once(s, old, new, "renderer widget style properties")
old = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        v.width = min(v.width, max(1, innerWidth - mediaSiblingFootprint))
        v.height = min(v.height, innerHeight)
        return v
    }
'''
new = '''    private var visualizerOptions: VisualizerOptions {
        var v = options.visualizer ?? VisualizerOptions()
        v.width = min(v.width, max(1, min(widgetBodyWidthLimit, innerWidth - mediaSiblingFootprint)))
        v.height = min(v.height, innerHeight)
        return v
    }
'''
s = replace_once(s, old, new, "visualizer styled width")
old = '''    private var closedMediaWidth: Double {
        let remaining = max(24, innerWidth - mediaSiblingFootprint)
        if closedMediaOptions.overflow == .truncate || closedMediaOptions.overflow == .marquee {
            return min(remaining, closedMediaOptions.resolvedHorizontalSpace)
        }
        return remaining
    }
    private var mirrorContentWidth: Double {
        max(1, min(112, innerWidth - mediaSiblingFootprint))
    }
'''
new = '''    private var closedMediaWidth: Double {
        let remaining = max(24, min(widgetBodyWidthLimit, innerWidth - mediaSiblingFootprint))
        if closedMediaOptions.overflow == .truncate || closedMediaOptions.overflow == .marquee {
            return min(remaining, closedMediaOptions.resolvedHorizontalSpace)
        }
        return remaining
    }
    private var mirrorContentWidth: Double {
        max(1, min(widgetBodyWidthLimit, min(112, innerWidth - mediaSiblingFootprint)))
    }
'''
s = replace_once(s, old, new, "media mirror styled width")
old = '''        return max(24, innerWidth - occupied)
    }
'''
new = '''        return max(24, min(widgetBodyWidthLimit, innerWidth - occupied))
    }
'''
s = replace_once(s, old, new, "activity styled width")
old = '''    @ViewBuilder private var contentElement: some View {
        if itemIsVisible && !hideMusicContentForArtworkOnly { content }
    }
'''
new = '''    @ViewBuilder private var contentElement: some View {
        if itemIsVisible && !hideMusicContentForArtworkOnly {
            if let widgetStyle {
                content
                    .font(closedWidgetFont(widgetStyle))
                    .foregroundStyle(widgetTextColor)
                    .tint(widgetAccentColor)
                    .padding(widgetStyle.padding)
                    .frame(width: widgetStyle.width > 0 ? min(widgetStyle.width, innerWidth) : nil,
                           maxHeight: innerHeight,
                           alignment: resolvedWidgetAlignment(widgetStyle.alignment))
                    .background(widgetStyle.backgroundColor.color.opacity(widgetStyle.backgroundOpacity),
                                in: RoundedRectangle(cornerRadius: widgetStyle.cornerRadius, style: .continuous))
                    .opacity(widgetStyle.opacity)
                    .offset(x: widgetStyle.horizontalOffset, y: widgetStyle.verticalOffset)
            } else {
                content
            }
        }
    }
'''
s = replace_once(s, old, new, "widget chrome")
# Replace content switch cases with customized variants.
s = replace_once(s,
'''        case .clock: WidgetClock(style: compactClock, compact: true)
        case .date: TimelineView(.periodic(from: .now, by: 60)) { context in Text(context.date, format: .dateTime.month().day()).lineLimit(1) }
        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit().lineLimit(1) }
            else { compactLabel(symbol: "timer", text: store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready") }
        case .battery:
            if let battery = system.battery { compactLabel(symbol: system.charging ? "battery.100.bolt" : "battery.100", text: "\\(battery)%") }
            else { Image(systemName: "powerplug").frame(width: max(12, textSize + 2), alignment: .center) }
''',
'''        case .clock:
            WidgetClock(style: compactClock, compact: true)
        case .date:
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(formattedClosedDate(context.date)).lineLimit(1)
            }
        case .timer:
            if let deadline = store.deadline {
                if widgetStyle != nil {
                    HStack(spacing: widgetElementSpacing) {
                        if widgetShowsIcon { Image(systemName: "timer").font(.system(size: widgetIconSize)).foregroundStyle(widgetAccentColor) }
                        if widgetShowsText { Text(deadline, style: .timer).monospacedDigit().lineLimit(1) }
                    }
                } else {
                    Text(deadline, style: .timer).monospacedDigit().lineLimit(1)
                }
            } else {
                compactLabel(symbol: "timer", text: store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready")
            }
        case .battery:
            if let battery = system.battery {
                compactLabel(symbol: system.charging ? "battery.100.bolt" : "battery.100", text: "\\(battery)%")
            } else if widgetShowsIcon {
                Image(systemName: "powerplug").font(.system(size: widgetIconSize)).foregroundStyle(widgetAccentColor)
            }
''', "custom clock date timer battery")
s = replace_once(s,
'''                ClosedMediaView(media: media, options: closedMediaOptions, fontSize: textSize, availableWidth: closedMediaWidth, lowPower: system.lowPower)
''',
'''                ClosedMediaView(media: media, options: closedMediaOptions, fontSize: widgetTextSize, availableWidth: closedMediaWidth, lowPower: system.lowPower)
''', "custom media text size")
s = replace_once(s,
'''            if media.isPlaying { PlaybackVisualizer(kind: options.animation, playing: true, enabled: options.animate && !system.lowPower, options: visualizerOptions, palette: media.artworkColors, fallback: effectiveTextColor) }
''',
'''            if media.isPlaying { PlaybackVisualizer(kind: options.animation, playing: true, enabled: options.animate && !system.lowPower, options: visualizerOptions, palette: media.artworkColors, fallback: widgetAccentColor) }
''', "custom visualizer color")
s = replace_once(s,
'''                    HStack(spacing: elementSpacing) {
                        Image(systemName: "waveform.path")
                            .frame(width: max(12, textSize), alignment: .center)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(activity.title)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if !activity.detail.isEmpty {
                                Text(activity.detail)
                                    .font(.system(size: max(8, textSize * 0.76)))
                                    .opacity(0.72)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .layoutPriority(1)
                        if let progress = activity.progress {
                            ProgressView(value: progress)
                                .controlSize(.mini)
                                .frame(width: min(38, max(24, activityContentWidth * 0.22)))
                        }
                    }
''',
'''                    HStack(spacing: widgetElementSpacing) {
                        if widgetShowsIcon {
                            Image(systemName: "waveform.path")
                                .font(.system(size: widgetIconSize))
                                .foregroundStyle(widgetAccentColor)
                                .frame(width: max(12, widgetIconSize + 2), alignment: .center)
                        }
                        if widgetShowsText {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(activity.title)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                if (widgetStyle?.activityShowDetail ?? true) && !activity.detail.isEmpty {
                                    Text(activity.detail)
                                        .font(.system(size: max(7, widgetTextSize * 0.76)))
                                        .opacity(0.72)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .layoutPriority(1)
                        }
                        if (widgetStyle?.activityShowProgress ?? true), let progress = activity.progress {
                            ProgressView(value: progress)
                                .controlSize(.mini)
                                .tint(widgetAccentColor)
                                .frame(width: min(38, max(24, activityContentWidth * 0.22)))
                        }
                    }
''', "custom activity content")
old = '''    private func compactLabel(symbol: String, text: String) -> some View {
        HStack(spacing: elementSpacing) {
            Image(systemName: symbol)
                .frame(width: max(12, textSize + 2), alignment: .center)
            Text(text).monospacedDigit().lineLimit(1)
        }
    }
    private var compactClock: WidgetStyle { var value = clock; value.fontSize = textSize; value.textColor = WidgetColor(effectiveTextColor); return value }
}
'''
new = '''    private func compactLabel(symbol: String, text: String) -> some View {
        HStack(spacing: widgetElementSpacing) {
            if widgetShowsIcon {
                Image(systemName: symbol)
                    .font(.system(size: widgetIconSize))
                    .foregroundStyle(widgetAccentColor)
                    .frame(width: max(12, widgetIconSize + 2), alignment: .center)
            }
            if widgetShowsText { Text(text).monospacedDigit().lineLimit(1) }
        }
    }

    private func closedWidgetFont(_ value: ClosedNotchWidgetStyle) -> Font {
        var style = WidgetStyle()
        style.fontFamily = value.fontFamily
        style.customFont = value.customFont
        style.weight = value.weight
        style.fontSize = widgetTextSize
        return style.font()
    }

    private func resolvedWidgetAlignment(_ value: ClosedNotchWidgetAlignment) -> Alignment {
        switch value {
        case .automatic: return side == .left ? .trailing : .leading
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func formattedClosedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        switch widgetStyle?.dateStyle ?? .monthDay {
        case .monthDay: formatter.setLocalizedDateFormatFromTemplate("MMM d")
        case .numeric: formatter.setLocalizedDateFormatFromTemplate("MM/dd")
        case .weekday: formatter.setLocalizedDateFormatFromTemplate("EEEE")
        case .weekdayMonthDay: formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        }
        return formatter.string(from: date)
    }

    private var compactClock: WidgetStyle {
        var value = clock
        if let widgetStyle {
            value.fontFamily = widgetStyle.fontFamily
            value.customFont = widgetStyle.customFont
            value.weight = widgetStyle.weight
            value.fontSize = widgetTextSize
            value.textColor = widgetStyle.textColor
            value.accentColor = widgetStyle.accentColor
            value.clock = widgetStyle.clock
            value.showTitle = false
        } else {
            value.fontSize = textSize
            value.textColor = WidgetColor(effectiveTextColor)
        }
        return value
    }
}
'''
s = replace_once(s, old, new, "widget helpers")
p.write_text(s)

# -----------------------------------------------------------------------------
# 6. WindowManager sizing mirrors custom widget configuration
# -----------------------------------------------------------------------------
p = Path("Halo/NotchEngine/WindowManager.swift")
s = p.read_text()
# Replace mediaWidth helper with style-aware helper.
start = s.index('        func mediaWidth() -> Double {')
end = s.index('\n\n        func bluetoothActivityWidth', start)
old = s[start:end]
new = '''        func nsWeight(_ weight: WidgetFontWeight) -> NSFont.Weight {
            switch weight {
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }

        func itemFont(_ style: ClosedNotchWidgetStyle?, digits: Bool = false) -> (NSFont, Double, Double) {
            let itemSize = min(style?.fontSize ?? size, max(7, innerHeight))
            let weight = nsWeight(style?.weight ?? .regular)
            let resolved: NSFont
            if let style, style.fontFamily == .custom, let custom = NSFont(name: style.customFont, size: itemSize) {
                resolved = custom
            } else if digits || style?.fontFamily == .monospaced {
                resolved = NSFont.monospacedDigitSystemFont(ofSize: itemSize, weight: weight)
            } else {
                resolved = NSFont.systemFont(ofSize: itemSize, weight: weight)
            }
            return (resolved, itemSize, style?.spacing ?? elementGap)
        }

        func mediaWidth(_ widget: ClosedNotchWidgetStyle?) -> Double {
            guard playing else { return 0 }
            let media = options.mediaOptions ?? ClosedMediaOptions()
            let (mediaFont, mediaSize, mediaGap) = itemFont(widget)
            let title = textWidth(String(store.workspace.media.title.prefix(120)), font: mediaFont)
            let artistValue = store.workspace.media.artist.isEmpty ? store.workspace.media.title : store.workspace.media.artist
            let artist = textWidth(String(artistValue.prefix(120)), font: mediaFont)
            let adaptive = media.textMode == .lyrics && media.usesDynamicLyricWidth && mediaWidthHint != nil

            let usesInlineIcon: Bool = {
                guard media.showPlaybackIcon else { return false }
                switch media.textMode {
                case .title, .artist: return true
                case .titleArtist: return media.lines == 1
                case .lyrics:
                    switch media.resolvedLyricDisplay {
                    case .word: return true
                    case .line: return media.lines == 1
                    case .focus: return false
                    }
                }
            }()
            let icon = usesInlineIcon ? max(12, mediaSize + 2) + mediaGap : 0

            let naturalText: Double
            switch media.textMode {
            case .title: naturalText = title
            case .artist: naturalText = artist
            case .titleArtist:
                naturalText = media.lines == 2
                    ? max(title, artist)
                    : title + (store.workspace.media.artist.isEmpty ? 0 : artist + textWidth(" · ", font: mediaFont))
            case .lyrics:
                naturalText = adaptive ? max(28, mediaWidthHint!) : max(90, min(220, title + artist * 0.35))
            }

            if adaptive { return min(320, max(28, naturalText)) }
            let naturalTotal = naturalText + icon
            switch media.overflow {
            case .marquee, .truncate:
                return min(max(24, naturalTotal), media.resolvedHorizontalSpace)
            case .scale:
                return min(max(24, naturalTotal), 260)
            }
        }'''
s = s[:start] + new + s[end:]
# Replace itemWidth function wholesale.
start = s.index('        func itemWidth(_ side: DynamicSide, _ item: ClosedNotchItem) -> Double {')
end = s.index('\n\n        func decorationWidth', start)
old = s[start:end]
new = '''        func itemWidth(_ side: DynamicSide, _ item: ClosedNotchItem) -> Double {
            if isArtworkOnly(side, item: item) { return 0 }
            let widget = options.widgetStyle(for: item)
            let (itemFont, itemSize, itemGap) = itemFont(widget)
            let digitItemFont = itemFont(widget, digits: true).0
            let showIcon = widget?.showIcon ?? true
            let showText = widget?.showText ?? true
            let iconWidth = showIcon ? max(12, min(widget?.iconSize ?? itemSize + 2, innerHeight) + 2) : 0

            func iconAndText(_ text: String, font: NSFont = itemFont) -> Double {
                let textPart = showText ? textWidth(text, font: font) : 0
                if iconWidth > 0 && textPart > 0 { return iconWidth + itemGap + textPart }
                return max(iconWidth, textPart)
            }

            let raw: Double
            switch item {
            case .none:
                raw = 0
            case .clock:
                let baseClock = layout.widgetStyle(for: .clock)
                let clock = widget?.clock ?? baseClock.clock
                let clockFont: NSFont
                if let widget {
                    clockFont = itemFont
                } else if baseClock.fontFamily == .custom {
                    clockFont = NSFont(name: baseClock.customFont, size: size) ?? font
                } else {
                    clockFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
                }
                let template = "88:88" + (clock.showSeconds ? ":88" : "") + (clock.twentyFourHour ? "" : " PM")
                raw = textWidth(template, font: clockFont) * 1.04
            case .date:
                raw = showText ? textWidth(widget?.dateStyle.measurementTemplate ?? "Sep 28", font: itemFont) : 0
            case .timer:
                if store.deadline != nil {
                    if widget == nil { raw = textWidth("88:88:88", font: digitFont) }
                    else { raw = iconAndText("88:88:88", font: digitItemFont) }
                } else {
                    let label = store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready"
                    raw = iconAndText(label)
                }
            case .battery:
                guard let battery = store.workspace.system.battery else { raw = iconWidth; break }
                raw = iconAndText("\\(battery)%", font: digitItemFont)
            case .media:
                raw = mediaWidth(widget)
            case .visualizer:
                raw = playing ? (options.visualizer ?? VisualizerOptions()).width : 0
            case .mirror:
                raw = 112
            case .files:
                raw = iconAndText(String(store.files.count), font: digitItemFont)
            case .activity:
                guard let activity else { raw = 0; break }
                if let bluetooth = bluetoothActivityWidth(activity) {
                    raw = min(240, max(0, bluetooth))
                } else {
                    let title = showText ? textWidth(String(activity.title.prefix(80)), font: itemFont) : 0
                    let detailFont = NSFont.systemFont(ofSize: max(7, itemSize * 0.76))
                    let detail = showText && (widget?.activityShowDetail ?? true) && !activity.detail.isEmpty
                        ? textWidth(String(activity.detail.prefix(80)), font: detailFont) : 0
                    let text = max(title, detail)
                    let progress = (widget?.activityShowProgress ?? true) && activity.progress != nil ? itemGap + 38 : 0
                    var total = max(iconWidth, text)
                    if iconWidth > 0 && text > 0 { total = iconWidth + itemGap + text }
                    raw = min(240, total + progress + 2)
                }
            }

            guard raw > 0 else { return 0 }
            guard let widget else { return raw }
            let chromed = widget.width > 0 ? widget.width : raw + 2 * widget.padding
            let outwardOffset = side == .left ? max(0, -widget.horizontalOffset) : max(0, widget.horizontalOffset)
            return min(440, max(0, chromed + outwardOffset))
        }'''
s = s[:start] + new + s[end:]
p.write_text(s)

# -----------------------------------------------------------------------------
# 7. Closed Notch settings: rich per-widget editor
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()
old = '''    @AppStorage("HaloBluetoothClosedNotchIconSize") private var bluetoothIconSize = 16.0
    private var options: Binding<ClosedNotchOptions> { Binding(get: { layout.closedNotch ?? ClosedNotchOptions() }, set: { layout.closedNotch = $0 }) }
'''
new = '''    @AppStorage("HaloBluetoothClosedNotchIconSize") private var bluetoothIconSize = 16.0
    @State private var selectedClosedWidget: ClosedNotchItem = .clock
    @State private var closedWidgetFonts: [String] = []
    private var options: Binding<ClosedNotchOptions> { Binding(get: { layout.closedNotch ?? ClosedNotchOptions() }, set: { layout.closedNotch = $0 }) }
'''
s = replace_once(s, old, new, "closed widget editor state")
# Add helper bindings before body.
old = '''    private var power: Binding<PowerReactionOptions> { Binding(get: { options.wrappedValue.powerReaction ?? PowerReactionOptions() }, set: { options.wrappedValue.powerReaction = $0 }) }
    var body: some View {
'''
new = '''    private var power: Binding<PowerReactionOptions> { Binding(get: { options.wrappedValue.powerReaction ?? PowerReactionOptions() }, set: { options.wrappedValue.powerReaction = $0 }) }
    private var closedWidgetStyle: Binding<ClosedNotchWidgetStyle> {
        Binding(get: {
            options.wrappedValue.widgetStyle(for: selectedClosedWidget) ?? inheritedClosedWidgetStyle(selectedClosedWidget)
        }, set: { newValue in
            var updated = options.wrappedValue
            updated.setWidgetStyle(newValue, for: selectedClosedWidget)
            options.wrappedValue = updated
        })
    }
    private func inheritedClosedWidgetStyle(_ item: ClosedNotchItem) -> ClosedNotchWidgetStyle {
        var value = ClosedNotchWidgetStyle()
        value.fontSize = options.wrappedValue.fontSize
        value.textColor = options.wrappedValue.color
        value.accentColor = options.wrappedValue.color
        if item == .clock {
            let source = layout.widgetStyle(for: .clock)
            value.fontFamily = source.fontFamily
            value.customFont = source.customFont
            value.weight = source.weight
            value.clock = source.clock
        }
        return value
    }
    var body: some View {
'''
s = replace_once(s, old, new, "closed widget style binding")
# Insert editor after Content section.
anchor = '''        Section("Bluetooth events") {
'''
editor = '''        Section("Widget customization") {
            Picker("Customize", selection: $selectedClosedWidget) {
                ForEach(ClosedNotchItem.allCases.filter { $0 != .none }) { item in
                    Text(item.title).tag(item)
                }
            }
            Text("Each Closed Notch widget can have its own typography, colors, chrome, spacing and placement. Media, Visualizer and Live Activity keep their specialised controls below as well.")
                .font(.caption).foregroundStyle(.secondary)

            Group {
                Picker("Font", selection: closedWidgetStyle.fontFamily) {
                    ForEach(WidgetFontFamily.allCases, id: \\.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                if closedWidgetStyle.wrappedValue.fontFamily == .custom {
                    SearchableStringPicker(title: "Installed font", selection: closedWidgetStyle.customFont,
                        values: closedWidgetFonts.contains(closedWidgetStyle.wrappedValue.customFont)
                            ? closedWidgetFonts : [closedWidgetStyle.wrappedValue.customFont] + closedWidgetFonts)
                        .onAppear { if closedWidgetFonts.isEmpty { closedWidgetFonts = NSFontManager.shared.availableFontFamilies.sorted() } }
                }
                Picker("Weight", selection: closedWidgetStyle.weight) {
                    ForEach(WidgetFontWeight.allCases, id: \\.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                PreciseSlider(title: "Text size", value: closedWidgetStyle.fontSize, range: 7...32, step: 1, suffix: "pt")
                ColorPicker("Text color", selection: Binding(get: { closedWidgetStyle.wrappedValue.textColor.color }, set: { closedWidgetStyle.wrappedValue.textColor = WidgetColor($0) }), supportsOpacity: false)
                ColorPicker("Accent / icon color", selection: Binding(get: { closedWidgetStyle.wrappedValue.accentColor.color }, set: { closedWidgetStyle.wrappedValue.accentColor = WidgetColor($0) }), supportsOpacity: false)
                PreciseSlider(title: "Opacity", value: closedWidgetStyle.opacity, range: 0.1...1, step: 0.05, decimals: 2)
            }

            if [.timer, .battery, .files, .activity].contains(selectedClosedWidget) {
                Divider()
                Toggle("Show icon", isOn: closedWidgetStyle.showIcon)
                Toggle("Show text", isOn: closedWidgetStyle.showText)
                if closedWidgetStyle.wrappedValue.showIcon {
                    PreciseSlider(title: "Icon size", value: closedWidgetStyle.iconSize, range: 7...36, step: 1, suffix: "pt")
                }
                PreciseSlider(title: "Icon / text spacing", value: closedWidgetStyle.spacing, range: 0...24, step: 1, suffix: "pt")
            }

            if selectedClosedWidget == .clock {
                Divider()
                Toggle("24-hour time", isOn: closedWidgetStyle.clock.twentyFourHour)
                Toggle("Show seconds", isOn: closedWidgetStyle.clock.showSeconds)
                SearchableStringPicker(title: "Time zone", selection: closedWidgetStyle.clock.timeZone,
                    values: [""] + TimeZone.knownTimeZoneIdentifiers, emptyLabel: "System time zone")
            }

            if selectedClosedWidget == .date {
                Divider()
                Picker("Date style", selection: closedWidgetStyle.dateStyle) {
                    ForEach(ClosedNotchDateStyle.allCases) { style in Text(style.title).tag(style) }
                }
            }

            if selectedClosedWidget == .activity {
                Divider()
                Toggle("Show activity detail", isOn: closedWidgetStyle.activityShowDetail)
                Toggle("Show progress", isOn: closedWidgetStyle.activityShowProgress)
                Text("Bluetooth event contents still use the dedicated Bluetooth controls below; this section styles their overall widget chrome and placement.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()
            Text("Widget chrome").font(.headline)
            ColorPicker("Background color", selection: Binding(get: { closedWidgetStyle.wrappedValue.backgroundColor.color }, set: { closedWidgetStyle.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false)
            PreciseSlider(title: "Background opacity", value: closedWidgetStyle.backgroundOpacity, range: 0...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Inner padding", value: closedWidgetStyle.padding, range: 0...24, step: 1, suffix: "pt")
            PreciseSlider(title: "Corner radius", value: closedWidgetStyle.cornerRadius, range: 0...32, step: 1, suffix: "pt")

            Divider()
            Text("Sizing & placement").font(.headline)
            PreciseSlider(title: "Reserved width (0 = automatic)", value: closedWidgetStyle.width, range: 0...420, step: 1, suffix: "pt")
            Picker("Alignment", selection: closedWidgetStyle.alignment) {
                ForEach(ClosedNotchWidgetAlignment.allCases) { alignment in Text(alignment.title).tag(alignment) }
            }
            PreciseSlider(title: "Horizontal offset", value: closedWidgetStyle.horizontalOffset, range: -160...160, step: 1, suffix: "pt")
            PreciseSlider(title: "Vertical offset", value: closedWidgetStyle.verticalOffset, range: -80...80, step: 1, suffix: "pt")
            Text("Positive X moves right; positive Y moves down. Halo's content-fit width accounts for outward offsets so a customized widget does not get clipped.")
                .font(.caption).foregroundStyle(.secondary)

            Button("Reset \\(selectedClosedWidget.title) customization") {
                var updated = options.wrappedValue
                updated.resetWidgetStyle(for: selectedClosedWidget)
                options.wrappedValue = updated
            }
            .disabled(options.wrappedValue.widgetStyle(for: selectedClosedWidget) == nil)
        }
'''
if anchor not in s:
    raise SystemExit("missing bluetooth section anchor")
s = s.replace(anchor, editor + anchor, 1)
# Better picker labels.
s = s.replace('ForEach(ClosedNotchItem.allCases) { Text($0.rawValue.capitalized).tag($0) }', 'ForEach(ClosedNotchItem.allCases) { Text($0.title).tag($0) }', 1)
p.write_text(s)

# -----------------------------------------------------------------------------
# 8. CI library/settings for Drop CI
# -----------------------------------------------------------------------------
p = Path("Halo/Views/WorkspaceSettingsView.swift")
s = p.read_text()
s = replace_once(s,
'''private enum ContextInterfaceSelection: String, Identifiable {
    case music, bluetooth, retro
''',
'''private enum ContextInterfaceSelection: String, Identifiable {
    case drop, music, bluetooth, retro
''', "CI selection drop")
old = '''    @State private var selection: ContextInterfaceSelection?
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false
'''
new = '''    @State private var selection: ContextInterfaceSelection?
    @AppStorage("HaloContextDropEnabled") private var dropEnabled = true
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false
'''
s = replace_once(s, old, new, "CI drop enabled")
old = '''    @ViewBuilder var body: some View {
        if selection == .music {
'''
new = '''    @ViewBuilder var body: some View {
        if selection == .drop {
            Section {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = nil }
                    } label: {
                        Label("All CI", systemImage: "chevron.left")
                    }
                    Spacer()
                    Label("Drop CI", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                }
            }
            ContextDropSettings()
        } else if selection == .music {
'''
s = replace_once(s, old, new, "CI drop settings branch")
old = '''                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], alignment: .leading, spacing: 14) {
                    ContextInterfaceCard(enabled: musicEnabled) {
'''
new = '''                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], alignment: .leading, spacing: 14) {
                    DropContextInterfaceCard(enabled: dropEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .drop }
                    }
                    ContextInterfaceCard(enabled: musicEnabled) {
'''
s = replace_once(s, old, new, "CI drop card insertion")
# Insert Drop card/settings before existing music card.
anchor = '''private struct ContextInterfaceCard: View {
'''
insert = '''private struct DropContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextDropPriority") private var priority = 100.0
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentColor.opacity(0.24), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .padding(15)
                    VStack(spacing: 7) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("DROP FILES HERE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .frame(height: 112)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Drop CI").font(.headline)
                        Text("Files & Folders").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }

                Text("Turns Halo into a focused drop target while a Finder item is hovering over the notch.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)

                HStack {
                    Label("File Shelf", systemImage: "tray")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("Priority \\(Int(priority))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Label("Edit", systemImage: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
    }
}

private struct ContextDropSettings: View {
    @AppStorage("HaloContextDropEnabled") private var enabled = true
    @AppStorage("HaloContextDropUseFullNotchArea") private var usesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextDropPriority") private var priority = 100.0

    var body: some View {
        Section("Drag & Drop Context Interface") {
            Toggle("Enable Drop CI", isOn: $enabled)
            Text("When a file or folder is dragged over Halo, the opened notch becomes a dedicated drop target. Release to add a reference to File Shelf; Halo never moves or deletes the original.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Drop CI priority") }
            Text("Drop CI defaults to the highest priority because the drag is an immediate user action. You can lower it if another Context Interface should remain visible during a drag.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("CI surface") {
            Toggle("Use full notch area", isOn: $usesFullNotchArea)
            Toggle("Keep closed-notch contents visible", isOn: $keepsClosedNotchContents)
            Text("Full area gives the drop target the clearest visual feedback. Keeping closed contents visible reserves the top strip while you drag.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("What happens after dropping") {
            Label("Files and folders are added to File Shelf as references.", systemImage: "tray.full")
            Label("Originals remain in their current location.", systemImage: "lock.shield")
            Label("Use Quick Look, pin, reveal, open or share from the Shelf widget.", systemImage: "eye")
        }
    }
}

'''
if anchor not in s:
    raise SystemExit("missing ContextInterfaceCard anchor")
s = s.replace(anchor, insert + anchor, 1)
p.write_text(s)

print("Closed Notch widget customization + Drop CI applied")
