import SwiftUI
import AppKit

/// Large catalogs are built only when opened; scrolling creates visible rows lazily.
struct SearchableStringPicker: View {
    let title: String
    @Binding var selection: String
    let values: [String]
    var emptyLabel = "System default"
    @State private var showing = false
    @State private var search = ""
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(selection.isEmpty ? emptyLabel : selection) { search = ""; showing = true }
                .lineLimit(1)
                .popover(isPresented: $showing) {
                    VStack(spacing: 10) {
                        TextField("Search \(title.lowercased())", text: $search).textFieldStyle(.roundedBorder)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(values.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { value in
                                    Button { selection = value; showing = false } label: {
                                        HStack {
                                            Text(value.isEmpty ? emptyLabel : value)
                                            Spacer()
                                            if selection == value { Image(systemName: "checkmark") }
                                        }.padding(6).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }.padding(12).frame(width: 340, height: 320)
                }
        }
    }
}

extension WidgetColor {
    var color: Color { Color(red: red, green: green, blue: blue) }
    init(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}
extension WidgetStyle {
    func font(scale: Double = 1) -> Font {
        let weight: Font.Weight
        switch self.weight {
        case .light: weight = .light
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        }
        if fontFamily == .custom { return .custom(customFont, size: fontSize * scale).weight(weight) }
        let design: Font.Design
        switch fontFamily {
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .monospaced: design = .monospaced
        default: design = .default
        }
        return .system(size: fontSize * scale, weight: weight, design: design)
    }
}
extension WidgetContentAlignment {
    var horizontal: HorizontalAlignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    var alignment: Alignment {
        switch self { case .leading: return .topLeading; case .center: return .top; case .trailing: return .topTrailing }
    }
}
extension WidgetControlSize {
    var swiftUI: ControlSize {
        switch self { case .mini: return .mini; case .small: return .small; case .regular: return .regular; case .large: return .large }
    }
}
private struct WidgetStyleKey: EnvironmentKey { static let defaultValue = WidgetStyle() }
extension EnvironmentValues {
    var widgetStyle: WidgetStyle {
        get { self[WidgetStyleKey.self] }
        set { self[WidgetStyleKey.self] = newValue }
    }
}


private struct OpenNotchPresentationEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchPresentation = .regular }
private struct OpenNotchCompressionEnvironmentKey: EnvironmentKey { static let defaultValue = 0 }
private struct OpenNotchAvailableWidthEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchBlockVerticalAlignmentEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchBlockVerticalAlignment = .top }
extension EnvironmentValues {
    var openNotchPresentation: OpenNotchPresentation {
        get { self[OpenNotchPresentationEnvironmentKey.self] }
        set { self[OpenNotchPresentationEnvironmentKey.self] = newValue }
    }
    var openNotchCompressionLevel: Int {
        get { self[OpenNotchCompressionEnvironmentKey.self] }
        set { self[OpenNotchCompressionEnvironmentKey.self] = newValue }
    }
    var openNotchAvailableWidth: CGFloat? {
        get { self[OpenNotchAvailableWidthEnvironmentKey.self] }
        set { self[OpenNotchAvailableWidthEnvironmentKey.self] = newValue }
    }
    var openNotchAvailableHeight: CGFloat? {
        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }
        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }
    }
    var openNotchBlockVerticalAlignment: OpenNotchBlockVerticalAlignment {
        get { self[OpenNotchBlockVerticalAlignmentEnvironmentKey.self] }
        set { self[OpenNotchBlockVerticalAlignmentEnvironmentKey.self] = newValue }
    }
}

/// Deliberate Visual Workspace compositions. These are not just density levels:
/// a wide 2×1 slot and a tall 1×2 slot intentionally receive different layouts.
enum VisualWorkspaceWidgetSize: Equatable {
    case glance
    case horizontal
    case vertical
    case standard
    case expanded

    static func resolve(width: CGFloat?, height: CGFloat?, presentation: OpenNotchPresentation) -> VisualWorkspaceWidgetSize? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        let aspect = width / max(1, height)
        let area = width * height

        // Roughly the footprint produced by a 1×1 cell. Keep the test area-aware so
        // resizing the workspace itself does not suddenly turn a wide cell into a square one.
        if (area < 20_000 && aspect > 0.72 && aspect < 1.38) || (width < 132 && height < 132) {
            return .glance
        }
        if aspect >= 1.38 && height < 178 { return .horizontal }
        if aspect <= 0.72 && width < 208 { return .vertical }
        if presentation == .expanded || (width >= 340 && height >= 195 && area >= 72_000) { return .expanded }
        return .standard
    }

    var isCompact: Bool {
        switch self {
        case .glance, .horizontal, .vertical: return true
        case .standard, .expanded: return false
        }
    }
}

extension OpenNotchPriority {
    func remainsVisible(at compression: Int) -> Bool {
        switch self {
        case .alwaysVisible, .high: return true
        case .normal: return compression < 5
        case .low: return compression < 3
        case .optional: return compression < 2
        }
    }
}

extension WidgetFontWeight {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension WidgetContentAlignment {
    var textAlignment: TextAlignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}

extension WidgetElementEmphasis {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

struct WidgetElementSurface<Content: View>: View {
    let element: WidgetElementStyle
    let widgetStyle: WidgetStyle
    var defaultPriority: OpenNotchPriority = .normal
    @ViewBuilder var content: Content
    @Environment(\.openNotchCompressionLevel) private var compression
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchPresentation) private var presentation

    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }
    private var adaptiveScale: Double {
        let widthScale = availableWidth.map { min(1, max(0.52, Double($0) / 250)) } ?? 1
        let heightScale = availableHeight.map { min(1, max(0.52, Double($0) / 145)) } ?? 1
        let pressure = max(0.68, 1 - Double(compression) * 0.055)
        let footprintScale: Double
        switch footprint {
        case .glance: footprintScale = 0.82
        case .horizontal, .vertical: footprintScale = 0.91
        case .standard, .expanded, .none: footprintScale = 1
        }
        return min(widthScale, heightScale) * pressure * footprintScale
    }
    private var priority: OpenNotchPriority { element.priority ?? defaultPriority }
    private var remainsVisibleForFootprint: Bool {
        guard let footprint else { return true }
        switch footprint {
        case .glance:
            return priority == .alwaysVisible || priority == .high
        case .horizontal, .vertical:
            return priority != .optional && priority != .low
        case .standard:
            return priority != .optional || compression < 1
        case .expanded:
            return true
        }
    }
    private var alignment: WidgetContentAlignment { element.alignment ?? widgetStyle.resolvedContent.alignment }
    private var textAlignment: WidgetContentAlignment { element.textAlignment ?? alignment }
    private var foreground: Color {
        switch element.foreground {
        case .inherit: return widgetStyle.textColor.color
        case .secondary: return widgetStyle.textColor.color.opacity(0.62)
        case .accent: return widgetStyle.accentColor.color
        case .custom: return element.customForeground.color
        }
    }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous) }
    private var font: Font {
        let family = element.fontFamily ?? widgetStyle.fontFamily
        let size = (element.fontSize ?? (widgetStyle.fontSize * element.fontScale)) * adaptiveScale
        let weight = element.fontWeight?.swiftUIFontWeight ?? element.emphasis.fontWeight
        if family == .custom { return .custom(element.customFont ?? widgetStyle.customFont, size: size).weight(weight) }
        let design: Font.Design
        switch family { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: size, weight: weight, design: design)
    }
    private var controlSize: ControlSize {
        let density = element.contentDensity ?? 1
        if footprint == .glance || compression >= 3 || density <= 0.7 { return .mini }
        if footprint?.isCompact == true || compression >= 1 || density <= 0.9 { return .small }
        if density >= 1.3 { return .large }
        return widgetStyle.resolvedContent.controlSize.swiftUI
    }

    @ViewBuilder private var elementBackground: some View {
        switch element.background {
        case .none: EmptyView()
        case .subtle: shape.fill(widgetStyle.textColor.color.opacity(element.backgroundOpacity * 0.16))
        case .accent: shape.fill(widgetStyle.accentColor.color.opacity(element.backgroundOpacity))
        case .glass: shape.fill(.ultraThinMaterial).opacity(max(0.15, element.backgroundOpacity))
        case .custom: shape.fill(element.backgroundColor.color.opacity(element.backgroundOpacity))
        }
    }

    var body: some View {
        if element.visible && priority.remainsVisible(at: compression) && remainsVisibleForFootprint {
            content
                .font(font)
                .foregroundStyle(foreground)
                .tint((element.tintColor ?? widgetStyle.accentColor).color.opacity(element.tintOpacity ?? 1))
                .multilineTextAlignment(textAlignment.textAlignment)
                .controlSize(controlSize)
                .opacity(element.opacity)
                .lineLimit(footprint == .glance || compression >= 4 ? 1 : compression >= 2 ? 2 : nil)
                .minimumScaleFactor(footprint == .glance ? 0.82 : compression >= 3 ? 0.72 : 0.86)
                .padding(element.padding * adaptiveScale)
                .background { elementBackground }
                .overlay {
                    if (element.borderWidth ?? 0) > 0 && (element.borderOpacity ?? 0) > 0 {
                        shape.stroke((element.borderColor ?? widgetStyle.textColor).color.opacity(element.borderOpacity ?? 0), lineWidth: element.borderWidth ?? 0)
                    }
                }
                .shadow(color: .black.opacity(element.shadowOpacity ?? 0), radius: element.shadowBlur ?? 0)
                .offset(x: element.xOffset ?? 0, y: element.yOffset ?? 0)
                .padding(.vertical, (element.externalSpacing ?? 0) * adaptiveScale * 0.5)
                .frame(maxWidth: .infinity, alignment: alignment.alignment)
        }
    }
}

struct WidgetElement<Content: View>: View {
    let key: String
    var defaultVisible = true
    var defaultPriority: OpenNotchPriority = .normal
    @ViewBuilder var content: Content
    @Environment(\.widgetStyle) private var style

    init(key: String, defaultVisible: Bool = true, defaultPriority: OpenNotchPriority = .normal,
         @ViewBuilder content: () -> Content) {
        self.key = key; self.defaultVisible = defaultVisible; self.defaultPriority = defaultPriority; self.content = content()
    }

    var body: some View {
        let element = style.elementStyle(for: key, defaultVisible: defaultVisible)
        if element.visible {
            VStack(alignment: (element.alignment ?? style.resolvedContent.alignment).horizontal, spacing: 4) {
                WidgetElementSurface(element: element, widgetStyle: style, defaultPriority: defaultPriority) { content }
                if element.dividerAfter { Divider().opacity(0.45) }
            }
            .frame(maxWidth: .infinity, alignment: (element.alignment ?? style.resolvedContent.alignment).alignment)
        }
    }
}

struct WidgetCard<Content: View>: View {
    let style: WidgetStyle
    var availableHeight: CGFloat? = nil
    var availableWidth: CGFloat? = nil
    @ViewBuilder var content: Content
    @Environment(\.openNotchCompressionLevel) private var compression
    @Environment(\.openNotchBlockVerticalAlignment) private var blockVerticalAlignment
    private var fittedStyle: WidgetStyle {
        var fitted = style
        switch style.resolvedLayoutMode {
        case .standard: break
        case .compact:
            fitted.padding *= 0.78
            fitted.fontSize *= 0.94
        case .hero:
            fitted.fontSize *= 1.10
            fitted.padding *= 1.08
        case .minimal:
            fitted.padding *= 0.72
        case .dense:
            fitted.padding *= 0.62
            fitted.fontSize *= 0.90
        }
        if let width = availableWidth {
            fitted.padding = min(fitted.padding, max(3, width * 0.055))
            fitted.fontSize = min(fitted.fontSize, max(9, width * 0.11))
        }
        if let height = availableHeight {
            fitted.padding = min(fitted.padding, max(2, height * 0.08))
            fitted.minimumHeight = 0
            fitted.fontSize = min(fitted.fontSize, max(9, height * 0.18))
        }
        return fitted
    }
    private var contentOptions: WidgetContentOptions { fittedStyle.resolvedContent }
    private var chrome: WidgetChromeOptions { fittedStyle.resolvedChrome }
    private var innerAvailableWidth: CGFloat? {
        availableWidth.map { max(1, $0 - CGFloat(fittedStyle.padding * 2)) }
    }
    private var innerAvailableHeight: CGFloat? {
        availableHeight.map { max(1, $0 - CGFloat(fittedStyle.padding * 2)) }
    }
    private var styledContent: some View {
        content.environment(\.widgetStyle, fittedStyle)
            .environment(\.openNotchAvailableWidth, innerAvailableWidth)
            .environment(\.openNotchAvailableHeight, innerAvailableHeight)
            .font(fittedStyle.font())
            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)
            .controlSize(contentOptions.controlSize.swiftUI)
            .opacity(chrome.contentOpacity)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fittedStyle.cornerRadius, style: .continuous)
    }
    private var contentFrameAlignment: Alignment {
        switch (blockVerticalAlignment, contentOptions.alignment) {
        case (.top, .leading): return .topLeading
        case (.top, .center): return .top
        case (.top, .trailing): return .topTrailing
        case (.center, .leading): return .leading
        case (.center, .center): return .center
        case (.center, .trailing): return .trailing
        case (.bottom, .leading): return .bottomLeading
        case (.bottom, .center): return .bottom
        case (.bottom, .trailing): return .bottomTrailing
        }
    }

    @ViewBuilder private var cardBackground: some View {
        switch fittedStyle.resolvedCardBackgroundStyle {
        case .none:
            Color.clear
        case .solid:
            shape.fill(fittedStyle.backgroundColor.color.opacity(fittedStyle.backgroundOpacity))
        case .gradient:
            shape.fill(
                LinearGradient(
                    colors: [
                        fittedStyle.backgroundColor.color.opacity(fittedStyle.backgroundOpacity),
                        fittedStyle.resolvedBackgroundSecondaryColor.color.opacity(fittedStyle.backgroundOpacity)
                    ],
                    startPoint: UnitPoint(x: 0.5 - 0.5 * cos(fittedStyle.resolvedGradientAngle * .pi / 180),
                                          y: 0.5 - 0.5 * sin(fittedStyle.resolvedGradientAngle * .pi / 180)),
                    endPoint: UnitPoint(x: 0.5 + 0.5 * cos(fittedStyle.resolvedGradientAngle * .pi / 180),
                                        y: 0.5 + 0.5 * sin(fittedStyle.resolvedGradientAngle * .pi / 180))
                )
            )
        case .glass:
            shape.fill(.ultraThinMaterial)
                .opacity(fittedStyle.backgroundOpacity)
                .overlay(shape.fill(fittedStyle.backgroundColor.color.opacity(fittedStyle.resolvedGlassTintOpacity * fittedStyle.backgroundOpacity)))
        case .accent:
            shape.fill(fittedStyle.accentColor.color.opacity(fittedStyle.backgroundOpacity))
        }
    }

    @ViewBuilder private var cardOutline: some View {
        let color = chrome.borderColor.color.opacity(chrome.borderOpacity)
        let width = max(0.5, chrome.borderWidth)
        switch fittedStyle.resolvedOutlineStyle {
        case .none:
            EmptyView()
        case .solid:
            shape.stroke(color, lineWidth: width)
        case .dashed:
            shape.stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [7, 5]))
        case .double:
            shape.stroke(color, lineWidth: width)
                .overlay(shape.inset(by: max(3, width + 2)).stroke(color.opacity(0.70), lineWidth: max(0.5, width * 0.65)))
        case .glow:
            shape.stroke(color, lineWidth: width)
                .shadow(color: chrome.borderColor.color.opacity(max(0.20, chrome.borderOpacity)), radius: max(5, width * 3))
        }
    }

    var body: some View {
        Group {
            if let height = availableHeight {
                let padding = CGFloat(fittedStyle.padding)
                let innerHeight = max(1, height - padding * 2)
                // Adaptation happens before this point. The scroll view is only a safety
                // net: when content fits it has no scroll range, and when it does not fit
                // the user can still reach every control instead of losing it to clipping.
                ScrollView(.vertical) {
                    styledContent
                        .frame(maxWidth: .infinity, minHeight: innerHeight, alignment: contentFrameAlignment)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, alignment: contentFrameAlignment)
                .frame(height: innerHeight, alignment: contentFrameAlignment)
                .padding(padding)
                .frame(height: max(0, height))
                .clipped()
            } else {
                styledContent
                    .frame(maxWidth: .infinity, minHeight: style.minimumHeight, alignment: contentOptions.alignment.alignment)
                    .padding(style.padding)
            }
        }
        .background { cardBackground }
        .overlay { cardOutline }
        .shadow(color: .black.opacity(chrome.shadowOpacity), radius: chrome.shadowRadius, y: chrome.shadowY)
        .frame(width: availableWidth)
        .frame(maxWidth: style.width > 0 ? style.width : .infinity)
        .frame(maxWidth: .infinity, alignment: contentOptions.alignment.alignment)
    }
}
struct WidgetClock: View {
    let style: WidgetStyle
    var compact = false
    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight

    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }
    private var formatter: DateFormatter {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: style.clock.timeZone) ?? .current
        value.dateFormat = (style.clock.twentyFourHour ? "HH:mm" : "h:mm") + (style.clock.showSeconds ? ":ss" : "") + (style.clock.twentyFourHour ? "" : " a")
        return value
    }
    private var glanceFormatter: DateFormatter {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: style.clock.timeZone) ?? .current
        value.dateFormat = style.clock.twentyFourHour ? "HH:mm" : "h:mm a"
        return value
    }
    private var dayFormatter: DateFormatter {
        let value = DateFormatter()
        value.locale = .autoupdatingCurrent
        value.timeZone = TimeZone(identifier: style.clock.timeZone) ?? .current
        switch style.resolvedContent.clockDateStyle {
        case .weekdayMonthDay: value.dateFormat = "EEE, MMM d"
        case .monthDay: value.dateFormat = "MMM d"
        case .full: value.dateFormat = "EEEE, MMMM d"
        case .numeric: value.dateStyle = .short; value.timeStyle = .none
        }
        return value
    }
    private var weekdayFormatter: DateFormatter {
        let value = DateFormatter()
        value.locale = .autoupdatingCurrent
        value.timeZone = TimeZone(identifier: style.clock.timeZone) ?? .current
        value.dateFormat = "EEEE"
        return value
    }
    private var timeZoneLabel: String { style.clock.timeZone.isEmpty ? TimeZone.current.identifier : style.clock.timeZone }

    var body: some View {
        let clockFormatter = formatter
        let smallClockFormatter = glanceFormatter
        let dateFormatter = dayFormatter
        let weekday = weekdayFormatter
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60)
        TimelineView(.periodic(from: start, by: style.clock.showSeconds && footprint != .glance ? 1 : 30)) { context in
            Group {
                if let footprint {
                    workspaceClock(footprint, date: context.date, clockFormatter: clockFormatter, glanceFormatter: smallClockFormatter, dateFormatter: dateFormatter, weekdayFormatter: weekday)
                } else {
                    legacyClock(date: context.date, clockFormatter: clockFormatter, dateFormatter: dateFormatter)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: footprint == .glance ? .center : style.resolvedContent.alignment.alignment)
            .animation(.easeInOut(duration: 0.18), value: footprint)
        }
    }

    @ViewBuilder private func workspaceClock(_ size: VisualWorkspaceWidgetSize, date: Date, clockFormatter: DateFormatter, glanceFormatter: DateFormatter, dateFormatter: DateFormatter, weekdayFormatter: DateFormatter) -> some View {
        let spacing = max(2, min(16, style.resolvedContent.spacing * 0.55))
        switch size {
        case .glance:
            VStack(spacing: 2) {
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) {
                    Text(glanceFormatter.string(from: date))
                        .font(style.font(scale: 1.34))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                if style.clock.showDate {
                    WidgetElement(key: "date", defaultPriority: .high) {
                        Text(date, format: .dateTime.weekday(.abbreviated).locale(.autoupdatingCurrent))
                            .font(style.font(scale: 0.62))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .horizontal:
            HStack(spacing: spacing) {
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) {
                    Text(glanceFormatter.string(from: date)).font(style.font(scale: 1.08)).monospacedDigit().lineLimit(1)
                }
                if style.clock.showDate {
                    Divider().opacity(0.35)
                    WidgetElement(key: "date", defaultPriority: .high) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(weekdayFormatter.string(from: date)).font(style.font(scale: 0.64)).lineLimit(1)
                            Text(dateFormatter.string(from: date)).font(style.font(scale: 0.58)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        case .vertical:
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) {
                    Text(glanceFormatter.string(from: date)).font(style.font(scale: 1.16)).monospacedDigit().lineLimit(1)
                }
                if style.clock.showDate {
                    WidgetElement(key: "date", defaultPriority: .high) {
                        VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: 2) {
                            Text(weekdayFormatter.string(from: date)).font(style.font(scale: 0.72)).lineLimit(1)
                            Text(dateFormatter.string(from: date)).font(style.font(scale: 0.64)).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }
        case .standard:
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                if style.showTitle && !compact { clockHeader(scale: 0.72) }
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) { Text(clockFormatter.string(from: date)).font(style.font(scale: 1.12)).monospacedDigit() }
                if style.clock.showDate && !compact { WidgetElement(key: "date", defaultPriority: .high) { Text(dateFormatter.string(from: date)) } }
                WidgetElement(key: "timezone", defaultVisible: false, defaultPriority: .normal) { Label(timeZoneLabel, systemImage: "globe") }
            }
        case .expanded:
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                if style.showTitle && !compact { clockHeader(scale: 0.78) }
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) { Text(clockFormatter.string(from: date)).font(style.font(scale: 1.35)).monospacedDigit() }
                extras(dateFormatter: dateFormatter, date: date)
            }
        }
    }

    @ViewBuilder private func legacyClock(date: Date, clockFormatter: DateFormatter, dateFormatter: DateFormatter) -> some View {
        let spacing = max(2, min(20, style.resolvedContent.spacing * 0.55))
        switch style.resolvedLayoutMode {
        case .compact:
            HStack(spacing: spacing) {
                if style.showTitle && !compact { clockHeader(scale: 0.68) }
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) { Text(clockFormatter.string(from: date)).monospacedDigit() }
                if style.clock.showDate && !compact {
                    WidgetElement(key: "date", defaultPriority: .high) { Text(dateFormatter.string(from: date)) }
                }
            }
        case .hero:
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                if style.showTitle && !compact { clockHeader(scale: 0.75) }
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) { Text(clockFormatter.string(from: date)).font(style.font(scale: 1.35)).monospacedDigit() }
                extras(dateFormatter: dateFormatter, date: date)
            }
        case .minimal:
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) { Text(clockFormatter.string(from: date)).monospacedDigit() }
                extras(dateFormatter: dateFormatter, date: date)
            }
        case .dense, .standard:
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: style.resolvedLayoutMode == .dense ? max(2, spacing * 0.55) : spacing) {
                if style.showTitle && !compact { clockHeader(scale: 0.75) }
                WidgetElement(key: "time", defaultPriority: .alwaysVisible) { Text(clockFormatter.string(from: date)).monospacedDigit() }
                extras(dateFormatter: dateFormatter, date: date)
            }
        }
    }

    @ViewBuilder private func extras(dateFormatter: DateFormatter, date: Date) -> some View {
        if style.clock.showDate && !compact {
            WidgetElement(key: "date", defaultPriority: .high) { Text(dateFormatter.string(from: date)) }
        }
        WidgetElement(key: "timezone", defaultVisible: false, defaultPriority: .normal) {
            Label(timeZoneLabel, systemImage: "globe")
        }
        WidgetElement(key: "dayProgress", defaultVisible: false, defaultPriority: .low) {
            let interval = Calendar.current.dateInterval(of: .day, for: date)
            let progress = interval.map { min(1, max(0, date.timeIntervalSince($0.start) / $0.duration)) } ?? 0
            VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: 4) {
                HStack { Text("Day progress"); Spacer(); Text("\(Int(progress * 100))%") }
                ProgressView(value: progress)
            }
        }
    }

    @ViewBuilder private func clockHeader(scale: Double) -> some View {
        HStack(spacing: max(4, style.resolvedContent.spacing * 0.55)) {
            if style.showsHeaderIcon {
                Image(systemName: "clock")
                    .font(.system(size: style.resolvedContent.iconSize, weight: .semibold))
                    .foregroundStyle(style.accentColor.color)
            }
            Text("Clock").font(style.font(scale: scale))
        }
    }
}
