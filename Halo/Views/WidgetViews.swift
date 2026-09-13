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
struct WidgetCard<Content: View>: View {
    let style: WidgetStyle
    var availableHeight: CGFloat? = nil
    @ViewBuilder var content: Content
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
        guard let height = availableHeight else { return fitted }
        fitted.padding = min(fitted.padding, max(0, height * 0.08))
        fitted.minimumHeight = 0
        fitted.fontSize = min(fitted.fontSize, max(10, height * 0.18))
        return fitted
    }
    private var contentOptions: WidgetContentOptions { fittedStyle.resolvedContent }
    private var chrome: WidgetChromeOptions { fittedStyle.resolvedChrome }
    private var styledContent: some View {
        content.environment(\.widgetStyle, fittedStyle).font(fittedStyle.font())
            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)
            .controlSize(contentOptions.controlSize.swiftUI)
            .opacity(chrome.contentOpacity)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fittedStyle.cornerRadius, style: .continuous)
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
                let padding = fittedStyle.padding
                // Keep the card within the viewport; only overflowing contents scroll.
                ScrollView(.vertical) {
                    styledContent
                        .frame(maxWidth: .infinity, minHeight: max(0, height - 2 * padding), alignment: contentOptions.alignment == .center ? .top : (contentOptions.alignment == .trailing ? .topTrailing : .topLeading))
                }
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
        .frame(maxWidth: style.width > 0 ? style.width : .infinity)
        .frame(maxWidth: .infinity, alignment: contentOptions.alignment.alignment)
    }
}
struct WidgetClock: View {
    let style: WidgetStyle
    var compact = false
    private var formatter: DateFormatter {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: style.clock.timeZone) ?? .current
        value.dateFormat = (style.clock.twentyFourHour ? "HH:mm" : "h:mm") + (style.clock.showSeconds ? ":ss" : "") + (style.clock.twentyFourHour ? "" : " a")
        return value
    }
    private var dayFormatter: DateFormatter {
        let value = formatter
        switch style.resolvedContent.clockDateStyle {
        case .weekdayMonthDay: value.dateFormat = "EEE, MMM d"
        case .monthDay: value.dateFormat = "MMM d"
        case .full: value.dateFormat = "EEEE, MMMM d"
        case .numeric: value.dateStyle = .short; value.timeStyle = .none
        }
        return value
    }
    var body: some View {
        let clockFormatter = formatter
        let dateFormatter = dayFormatter
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60)
        TimelineView(.periodic(from: start, by: style.clock.showSeconds ? 1 : 60)) { context in
            let spacing = max(2, min(20, style.resolvedContent.spacing * 0.55))
            Group {
                switch style.resolvedLayoutMode {
                case .compact:
                    HStack(spacing: spacing) {
                        if style.showTitle && !compact { clockHeader(scale: 0.68) }
                        Text(clockFormatter.string(from: context.date)).font(style.font()).monospacedDigit()
                        Spacer(minLength: 4)
                        if style.clock.showDate && !compact {
                            Text(dateFormatter.string(from: context.date)).font(style.font(scale: 0.68)).foregroundStyle(.secondary)
                        }
                    }
                case .hero:
                    VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                        if style.showTitle && !compact { clockHeader(scale: 0.75) }
                        Text(clockFormatter.string(from: context.date)).font(style.font(scale: 1.35)).monospacedDigit()
                        if style.clock.showDate && !compact { Text(dateFormatter.string(from: context.date)).font(style.font(scale: 0.80)) }
                    }
                case .minimal:
                    VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: spacing) {
                        Text(clockFormatter.string(from: context.date)).font(style.font()).monospacedDigit()
                        if style.clock.showDate && !compact { Text(dateFormatter.string(from: context.date)).font(style.font(scale: 0.68)).foregroundStyle(.secondary) }
                    }
                case .dense, .standard:
                    VStack(alignment: style.resolvedContent.alignment.horizontal, spacing: style.resolvedLayoutMode == .dense ? max(2, spacing * 0.55) : spacing) {
                        if style.showTitle && !compact { clockHeader(scale: 0.75) }
                        Text(clockFormatter.string(from: context.date)).font(style.font()).monospacedDigit()
                        if style.clock.showDate && !compact { Text(dateFormatter.string(from: context.date)).font(style.font(scale: 0.75)) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: style.resolvedContent.alignment.alignment)
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
