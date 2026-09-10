import SwiftUI
import AppKit

struct PreciseSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var suffix = ""
    var decimals = 0
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var text = ""
    @State private var dragging = false
    @State private var lastTick: Int?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(title)
                Spacer()
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: decimals > 0 ? 72 : 62)
                    .focused($fieldFocused)
                    .onSubmit { commitText() }
                    .onChange(of: fieldFocused) { focused in if !focused { commitText() } }
                if !suffix.isEmpty { Text(suffix).foregroundStyle(.secondary) }
            }
            Slider(value: Binding(get: { value }, set: { newValue in
                value = quantized(newValue)
                if dragging { tickIfNeeded(value) }
            }), in: range, step: step, onEditingChanged: { editing in
                dragging = editing
                lastTick = editing ? tickIndex(value) : nil
                onEditingChanged?(editing)
                if !editing { syncText() }
            })
            .accessibilityLabel(title)
        }
        .onAppear { syncText() }
        .onChange(of: value) { _ in if !fieldFocused && !dragging { syncText() } }
    }

    private func quantized(_ raw: Double) -> Double {
        let clamped = min(range.upperBound, max(range.lowerBound, raw))
        guard step > 0 else { return clamped }
        return min(range.upperBound, max(range.lowerBound,
            ((clamped - range.lowerBound) / step).rounded() * step + range.lowerBound))
    }
    private func tickIndex(_ value: Double) -> Int { Int(((value - range.lowerBound) / max(step, 0.0001)).rounded()) }
    private func tickIfNeeded(_ value: Double) {
        let tick = tickIndex(value)
        guard tick != lastTick else { return }
        lastTick = tick
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    private func syncText() { text = String(format: "%.*f", decimals, value) }
    private func commitText() {
        guard let parsed = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { syncText(); return }
        let newValue = quantized(parsed)
        if newValue != value {
            value = newValue
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        syncText()
    }
}

struct WidgetSettingsView: View {
    @Binding var layout: WorkspaceLayout
    @State private var selected: ModuleID = .clock
    private static let timeZones = TimeZone.knownTimeZoneIdentifiers
    @State private var installedFonts: [String] = []
    private var style: Binding<WidgetStyle> {
        Binding(get: { layout.widgetStyle(for: selected) }, set: { layout.setWidgetStyle($0, for: selected) })
    }
    var body: some View {
        Picker("Widget", selection: $selected) {
            ForEach(ModuleID.allCases) { Text($0.title).tag($0) }
        }
        Section("Typography") {
            Picker("Font", selection: style.fontFamily) {
                ForEach(WidgetFontFamily.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            if style.wrappedValue.fontFamily == .custom {
                SearchableStringPicker(title: "Installed font", selection: style.customFont,
                    values: installedFonts.contains(style.wrappedValue.customFont) ? installedFonts : [style.wrappedValue.customFont] + installedFonts)
                    .onAppear { if installedFonts.isEmpty { installedFonts = NSFontManager.shared.availableFontFamilies.sorted() } }
                TextField("Font name", text: style.customFont)
                Button("Browse fonts in Font Book") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Font Book.app")) }
            }
            Picker("Weight", selection: style.weight) {
                ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            PreciseSlider(title: "Text size", value: style.fontSize, range: 10...48, step: 1, suffix: "pt")
            colorPicker("Text", style.textColor)
            colorPicker("Accent", style.accentColor)
            Toggle("Show title", isOn: style.showTitle)
        }
        Section("Card") {
            colorPicker("Background", style.backgroundColor)
            PreciseSlider(title: "Background opacity", value: style.backgroundOpacity, range: 0...1, step: 0.01, decimals: 2)
            PreciseSlider(title: "Padding", value: style.padding, range: 0...32, step: 1, suffix: "pt")
            PreciseSlider(title: "Corner radius", value: style.cornerRadius, range: 0...40, step: 1, suffix: "pt")
            Toggle("Fill available width", isOn: Binding(get: { style.wrappedValue.width == 0 }, set: { style.wrappedValue.width = $0 ? 0 : 280 }))
            if style.wrappedValue.width > 0 {
                PreciseSlider(title: "Maximum width", value: style.width, range: 120...640, step: 1, suffix: "pt")
            }
            PreciseSlider(title: "Minimum height", value: style.minimumHeight, range: 0...400, step: 1, suffix: "pt")
        }
        if selected == .clock {
            Section("Clock") {
                Toggle("24-hour time", isOn: style.clock.twentyFourHour)
                Toggle("Show seconds", isOn: style.clock.showSeconds)
                Toggle("Show date", isOn: style.clock.showDate)
                SearchableStringPicker(title: "Time zone", selection: style.clock.timeZone,
                                       values: [""] + Self.timeZones, emptyLabel: "System time zone")
                WidgetClock(style: style.wrappedValue).foregroundStyle(style.wrappedValue.textColor.color)
                    .padding().background(.black, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        Button("Reset this widget") { layout.widgets?.removeValue(forKey: selected.rawValue) }
        Text("Changes apply live. Save a profile to keep a preset. Display-specific layouts use their saved profile's widget settings.").font(.caption)
    }
    private func colorPicker(_ title: String, _ value: Binding<WidgetColor>) -> some View {
        ColorPicker(title, selection: Binding(get: { value.wrappedValue.color }, set: { value.wrappedValue = WidgetColor($0) }), supportsOpacity: false)
    }
}

struct ClosedNotchSettingsView: View {
    @Binding var layout: WorkspaceLayout
    @ObservedObject var media: MediaService
    let app: String
    private var options: Binding<ClosedNotchOptions> {
        Binding(get: { layout.closedNotch ?? ClosedNotchOptions() }, set: { layout.closedNotch = $0 })
    }
    private var visualizer: Binding<VisualizerOptions> {
        Binding(get: { options.wrappedValue.visualizer ?? VisualizerOptions() },
                set: { options.wrappedValue.visualizer = $0 })
    }
    private var expansion: Binding<ClosedExpansionOptions> {
        Binding(get: { options.wrappedValue.expansion ?? ClosedExpansionOptions() },
                set: { options.wrappedValue.expansion = $0 })
    }
    var body: some View {
        Section("Content fit") {
            Toggle("Auto-size to fit content", isOn: Binding(get: { options.wrappedValue.autoFitContent ?? true }, set: { options.wrappedValue.autoFitContent = $0 }))
            PreciseSlider(title: "Horizontal padding", value: Binding(get: { options.wrappedValue.contentPaddingX }, set: { options.wrappedValue.horizontalPadding = $0 }), range: 0...24, step: 1, suffix: "pt")
            PreciseSlider(title: "Vertical padding", value: Binding(get: { options.wrappedValue.contentPaddingY }, set: { options.wrappedValue.verticalPadding = $0 }), range: 0...12, step: 1, suffix: "pt")
            PreciseSlider(title: "Margin from camera", value: Binding(get: { options.wrappedValue.contentSideMargin }, set: { options.wrappedValue.sideMargin = $0 }), range: 0...48, step: 1, suffix: "pt")
            PreciseSlider(title: "Margin from outer edge", value: Binding(get: { options.wrappedValue.contentOuterMargin }, set: { options.wrappedValue.outerMargin = $0 }), range: 0...48, step: 1, suffix: "pt")
            Text("Camera and outer-edge margins are independent. Auto-size reserves only the space each active side actually needs.").font(.caption)
        }
        Section("Automatic width") {
            Toggle("Widen for music and live activity", isOn: expansion.enabled)
            PreciseSlider(title: "Active width", value: expansion.width, range: 120...640, step: 1, suffix: "pt")
            Text("Music, pinned files, timers and live activities can widen the closed notch. Extra width is assigned only to the side that triggered it; if both sides have active reasons, both grow.").font(.caption)
        }
        SideDecorationSettingsView(title: "Left icon / GIF", options: Binding(
            get: { options.wrappedValue.leftDecoration ?? SideDecoration() },
            set: { options.wrappedValue.leftDecoration = $0 }
        ))
        SideDecorationSettingsView(title: "Right icon / GIF", options: Binding(
            get: { options.wrappedValue.rightDecoration ?? SideDecoration() },
            set: { options.wrappedValue.rightDecoration = $0 }
        ))
        Section("Content") {
            itemPicker("Left slot", options.left)
            itemPicker("Right slot", options.right)
            PreciseSlider(title: "Text size", value: options.fontSize, range: 8...24, step: 1, suffix: "pt")
            ColorPicker("Color", selection: Binding(get: { options.wrappedValue.color.color }, set: { options.wrappedValue.color = WidgetColor($0) }), supportsOpacity: false)
            Text("Live activities temporarily use the Activity slot, or take over an available closed-notch side so they are not missed.").font(.caption)
        }
        Section("Album colors") {
            Toggle("Color notch background from album", isOn: Binding(
                get: { options.wrappedValue.albumBackgroundColor ?? false },
                set: { options.wrappedValue.albumBackgroundColor = $0 }
            ))
            Toggle("Apply frequency effect to album background", isOn: Binding(
                get: { options.wrappedValue.albumBackgroundFrequencyEffect ?? false },
                set: { options.wrappedValue.albumBackgroundFrequencyEffect = $0 }
            )).disabled(!(options.wrappedValue.albumBackgroundColor ?? false))
            Toggle("Color closed-notch text from album", isOn: Binding(
                get: { options.wrappedValue.albumTextColor ?? false },
                set: { options.wrappedValue.albumTextColor = $0 }
            ))
            Text("Album colors take precedence only while music is actively playing and artwork colors are available. Pausing or stopping music immediately restores your normal notch background and text color.").font(.caption)
        }
        Section("Music animation") {
            Picker("Style", selection: Binding<PlaybackAnimation>(
                get: { options.wrappedValue.animation },
                set: { options.wrappedValue.animation = $0 }
            )) {
                ForEach(PlaybackAnimation.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Animate while music plays", isOn: options.animate)
            Toggle("Use colors from music artwork", isOn: visualizer.dynamicColors)
            PreciseSlider(title: "Animation speed", value: visualizer.speed, range: 0.25...2, step: 0.05, decimals: 2)
            PreciseSlider(title: "Motion intensity", value: visualizer.intensity, range: 0.1...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Visualizer width", value: visualizer.width, range: 32...160, step: 1, suffix: "pt")
            PreciseSlider(title: "Visualizer height", value: visualizer.height, range: 8...48, step: 1, suffix: "pt")
            PlaybackVisualizer(kind: options.wrappedValue.animation, playing: true, enabled: options.wrappedValue.animate,
                               options: visualizer.wrappedValue, palette: media.artworkColors, fallback: options.wrappedValue.color.color)
                .padding(12).background(.black, in: RoundedRectangle(cornerRadius: 12))
            Button("Retry player detection") { media.retryDetection(preferred: app) }.disabled(media.busy)
            Text(media.title)
            if let error = media.error { Text(error).foregroundStyle(.orange) }
        }
        Button("Reset closed content") { layout.closedNotch = ClosedNotchOptions() }
    }
    private func itemPicker(_ title: String, _ value: Binding<ClosedNotchItem>) -> some View {
        Picker(title, selection: value) {
            ForEach(ClosedNotchItem.allCases) { Text($0.rawValue.capitalized).tag($0) }
        }
    }
}
