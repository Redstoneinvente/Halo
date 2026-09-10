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
private struct WidgetStyleKey: EnvironmentKey { static let defaultValue = WidgetStyle() }
extension EnvironmentValues {
    var widgetStyle: WidgetStyle {
        get { self[WidgetStyleKey.self] }
        set { self[WidgetStyleKey.self] = newValue }
    }
}
struct WidgetCard<Content: View>: View {
    let style: WidgetStyle
    @ViewBuilder var content: Content
    var body: some View {
        content.environment(\.widgetStyle, style).font(style.font())
            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)
            .frame(maxWidth: .infinity, minHeight: style.minimumHeight, alignment: .leading)
            .padding(style.padding)
            .background(style.backgroundColor.color.opacity(style.backgroundOpacity), in: RoundedRectangle(cornerRadius: style.cornerRadius))
            .frame(maxWidth: style.width > 0 ? style.width : .infinity)
            .frame(maxWidth: .infinity)
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
        value.dateFormat = "EEE, MMM d"
        return value
    }
    var body: some View {
        let clockFormatter = formatter
        let dateFormatter = dayFormatter
        let start = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970 / 60) * 60)
        TimelineView(.periodic(from: start, by: style.clock.showSeconds ? 1 : 60)) { context in
            VStack(alignment: .leading, spacing: 4) {
                if style.showTitle && !compact { Text("Clock").font(style.font(scale: 0.75)) }
                Text(clockFormatter.string(from: context.date)).font(style.font()).monospacedDigit()
                if style.clock.showDate && !compact {
                    Text(dateFormatter.string(from: context.date))
                        .font(style.font(scale: 0.75))
                }
            }
        }
    }
}
