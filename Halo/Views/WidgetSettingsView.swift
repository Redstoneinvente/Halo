import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
            SwiftUI.Slider(value: Binding(get: { value }, set: { newValue in
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
    private var content: Binding<WidgetContentOptions> {
        Binding(get: { style.wrappedValue.resolvedContent }, set: { value in
            var updated = style.wrappedValue; updated.content = value; style.wrappedValue = updated
        })
    }
    private var chrome: Binding<WidgetChromeOptions> {
        Binding(get: { style.wrappedValue.resolvedChrome }, set: { value in
            var updated = style.wrappedValue; updated.chrome = value; style.wrappedValue = updated
        })
    }
    var body: some View {
        Picker("Widget", selection: $selected) {
            ForEach(ModuleID.allCases) { Text($0.title).tag($0) }
        }
        Section("Opened notch widget") {
            Text("Customize \(selected.title) independently. These settings apply to the widget in Halo's opened dashboard and travel with profiles and display-specific layouts.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Quick looks") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(WidgetVisualPreset.allCases) { preset in
                    Button(preset.rawValue) { applyVisualPreset(preset) }
                        .buttonStyle(.bordered)
                }
            }
            Text("Presets are starting points. Every setting below remains editable per widget.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Layout") {
            Picker("Widget layout", selection: Binding(
                get: { style.wrappedValue.resolvedLayoutMode },
                set: { style.wrappedValue.layoutMode = $0 }
            )) {
                ForEach(WidgetLayoutMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Show header", isOn: style.showTitle)
            if style.wrappedValue.showTitle {
                Toggle("Show header icon", isOn: Binding(
                    get: { style.wrappedValue.showsHeaderIcon },
                    set: { style.wrappedValue.showHeaderIcon = $0 }
                ))
            }
            Text("Compact moves the header beside content, Hero gives the widget stronger emphasis, Minimal strips it back, and Dense reduces internal spacing.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Elements") {
            Text("Each functional piece can be shown or hidden and styled independently. This includes real controls such as sliders, progress bars, status rows, lists and actions — not just text.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(selected.widgetElements) { descriptor in
                let value = elementBinding(descriptor)
                DisclosureGroup {
                    Toggle("Visible", isOn: value.visible)
                    if value.wrappedValue.visible {
                        Picker("Text color", selection: value.foreground) {
                            ForEach(WidgetElementForegroundStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if value.wrappedValue.foreground == .custom {
                            ColorPicker("Custom text", selection: Binding(get: { value.wrappedValue.customForeground.color }, set: { value.wrappedValue.customForeground = WidgetColor($0) }), supportsOpacity: false)
                        }
                        Picker("Emphasis", selection: value.emphasis) {
                            ForEach(WidgetElementEmphasis.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Picker("Collapse priority", selection: Binding(
                            get: { value.wrappedValue.priority ?? .normal },
                            set: { value.wrappedValue.priority = $0 }
                        )) { ForEach(OpenNotchPriority.allCases) { Text($0.rawValue).tag($0) } }
                        PreciseSlider(title: "Text scale", value: value.fontScale, range: 0.55...2.5, step: 0.05, suffix: "×", decimals: 2)
                        PreciseSlider(title: "Opacity", value: value.opacity, range: 0.15...1, step: 0.05, decimals: 2)
                        Picker("Element background", selection: value.background) {
                            ForEach(WidgetElementBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        if value.wrappedValue.background == .custom {
                            ColorPicker("Background color", selection: Binding(get: { value.wrappedValue.backgroundColor.color }, set: { value.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false)
                        }
                        if value.wrappedValue.background != .none {
                            PreciseSlider(title: "Background opacity", value: value.backgroundOpacity, range: 0...1, step: 0.05, decimals: 2)
                            PreciseSlider(title: "Element padding", value: value.padding, range: 0...24, step: 1, suffix: "pt")
                            PreciseSlider(title: "Element radius", value: value.cornerRadius, range: 0...32, step: 1, suffix: "pt")
                        }
                        Toggle("Divider after element", isOn: value.dividerAfter)
                        Button("Reset element style") { resetElement(descriptor) }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(descriptor.title)
                            Text(descriptor.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(value.wrappedValue.visible ? "On" : "Off").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
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
            Picker("Weight", selection: style.weight) { ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            PreciseSlider(title: "Text size", value: style.fontSize, range: 10...48, step: 1, suffix: "pt")
            colorPicker("Text", style.textColor)
            colorPicker("Accent", style.accentColor)
        }
        Section("Content layout") {
            Picker("Alignment", selection: content.alignment) {
                ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            PreciseSlider(title: "Content spacing", value: content.spacing, range: 0...32, step: 1, suffix: "pt")
            Picker("Control size", selection: content.controlSize) {
                ForEach(WidgetControlSize.allCases) { Text($0.title).tag($0) }
            }
            PreciseSlider(title: "Header icon size", value: content.iconSize, range: 8...48, step: 1, suffix: "pt")
        }
        Section("Card") {
            Picker("Background", selection: Binding(
                get: { style.wrappedValue.resolvedCardBackgroundStyle },
                set: { style.wrappedValue.cardBackgroundStyle = $0 }
            )) {
                ForEach(WidgetCardBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            if style.wrappedValue.resolvedCardBackgroundStyle != .none {
                if style.wrappedValue.resolvedCardBackgroundStyle == .accent {
                    colorPicker("Tint color", style.accentColor)
                } else {
                    colorPicker("Background", style.backgroundColor)
                }
                if style.wrappedValue.resolvedCardBackgroundStyle == .gradient {
                    ColorPicker("Second color", selection: Binding(
                        get: { style.wrappedValue.resolvedBackgroundSecondaryColor.color },
                        set: { style.wrappedValue.backgroundSecondaryColor = WidgetColor($0) }
                    ), supportsOpacity: false)
                    PreciseSlider(title: "Gradient angle", value: Binding(
                        get: { style.wrappedValue.resolvedGradientAngle },
                        set: { style.wrappedValue.gradientAngle = $0 }
                    ), range: -180...180, step: 5, suffix: "°")
                }
                if style.wrappedValue.resolvedCardBackgroundStyle == .glass {
                    PreciseSlider(title: "Glass tint", value: Binding(
                        get: { style.wrappedValue.resolvedGlassTintOpacity },
                        set: { style.wrappedValue.glassTintOpacity = $0 }
                    ), range: 0...0.6, step: 0.02, decimals: 2)
                }
                PreciseSlider(title: "Background opacity", value: style.backgroundOpacity, range: 0...1, step: 0.01, decimals: 2)
            }
            PreciseSlider(title: "Padding", value: style.padding, range: 0...32, step: 1, suffix: "pt")
            PreciseSlider(title: "Corner radius", value: style.cornerRadius, range: 0...40, step: 1, suffix: "pt")
            Toggle("Fill available width", isOn: Binding(get: { style.wrappedValue.width == 0 }, set: { style.wrappedValue.width = $0 ? 0 : 280 }))
            if style.wrappedValue.width > 0 { PreciseSlider(title: "Maximum width", value: style.width, range: 120...640, step: 1, suffix: "pt") }
            if layout.horizontalWidgets ?? false {
                Text("Horizontal widgets use the dashboard's fixed horizontal height, so per-widget minimum height does not apply in this layout mode.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                PreciseSlider(title: "Minimum height", value: style.minimumHeight, range: 0...400, step: 1, suffix: "pt")
            }
            Divider()
            Picker("Outline", selection: Binding(
                get: { style.wrappedValue.resolvedOutlineStyle },
                set: { value in
                    style.wrappedValue.outlineStyle = value
                    if value != .none && chrome.wrappedValue.borderWidth <= 0 { chrome.wrappedValue.borderWidth = 1 }
                    if value != .none && chrome.wrappedValue.borderOpacity <= 0 { chrome.wrappedValue.borderOpacity = 0.35 }
                }
            )) {
                ForEach(WidgetOutlineStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            if style.wrappedValue.resolvedOutlineStyle != .none {
                ColorPicker("Outline color", selection: Binding(get: { chrome.wrappedValue.borderColor.color }, set: { chrome.wrappedValue.borderColor = WidgetColor($0) }), supportsOpacity: false)
                PreciseSlider(title: "Outline opacity", value: chrome.borderOpacity, range: 0...1, step: 0.05, decimals: 2)
                PreciseSlider(title: "Outline width", value: chrome.borderWidth, range: 0...6, step: 0.25, suffix: "pt", decimals: 2)
            }
            PreciseSlider(title: "Shadow opacity", value: chrome.shadowOpacity, range: 0...0.8, step: 0.05, decimals: 2)
            if chrome.wrappedValue.shadowOpacity > 0 {
                PreciseSlider(title: "Shadow radius", value: chrome.shadowRadius, range: 0...40, step: 1, suffix: "pt")
                PreciseSlider(title: "Shadow Y", value: chrome.shadowY, range: -30...30, step: 1, suffix: "pt")
            }
            PreciseSlider(title: "Content opacity", value: chrome.contentOpacity, range: 0.15...1, step: 0.05, decimals: 2)
        }
        moduleSpecificSettings
        if selected == .clock {
            Section("Clock") {
                Toggle("24-hour time", isOn: style.clock.twentyFourHour)
                Toggle("Show seconds", isOn: style.clock.showSeconds)
                Toggle("Show date", isOn: style.clock.showDate)
                if style.wrappedValue.clock.showDate {
                    Picker("Date style", selection: content.clockDateStyle) {
                        ForEach(WidgetClockDateStyle.allCases) { Text($0.title).tag($0) }
                    }
                }
                SearchableStringPicker(title: "Time zone", selection: style.clock.timeZone, values: [""] + Self.timeZones, emptyLabel: "System time zone")
                WidgetClock(style: style.wrappedValue).foregroundStyle(style.wrappedValue.textColor.color)
                    .padding().background(.black, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        Button("Reset this widget") { layout.widgets?.removeValue(forKey: selected.rawValue) }
        Text("Changes apply live. Save a profile to keep a preset. Display-specific layouts use their saved profile's widget settings.").font(.caption)
    }
    private func elementBinding(_ descriptor: WidgetElementDescriptor) -> Binding<WidgetElementStyle> {
        Binding(get: {
            style.wrappedValue.elementStyle(for: descriptor)
        }, set: { value in
            var updated = style.wrappedValue
            if updated.elementStyles == nil { updated.elementStyles = [:] }
            updated.elementStyles?[descriptor.key] = value
            style.wrappedValue = updated
        })
    }

    private func resetElement(_ descriptor: WidgetElementDescriptor) {
        var updated = style.wrappedValue
        updated.elementStyles?.removeValue(forKey: descriptor.key)
        style.wrappedValue = updated
    }

    @ViewBuilder private var moduleSpecificSettings: some View {
        switch selected {
        case .clock:
            EmptyView()
        case .timer:
            Section("Focus timer") {
                Toggle("Show status / helper text", isOn: content.showSecondaryText)
                Toggle("Show timer controls", isOn: content.showControls)
                PreciseSlider(title: "Preset 1", value: Binding(get: { Double(content.wrappedValue.timerPresetA) }, set: { content.wrappedValue.timerPresetA = Int($0) }), range: 1...180, step: 1, suffix: "min")
                PreciseSlider(title: "Preset 2", value: Binding(get: { Double(content.wrappedValue.timerPresetB) }, set: { content.wrappedValue.timerPresetB = Int($0) }), range: 1...180, step: 1, suffix: "min")
                PreciseSlider(title: "Preset 3", value: Binding(get: { Double(content.wrappedValue.timerPresetC) }, set: { content.wrappedValue.timerPresetC = Int($0) }), range: 1...180, step: 1, suffix: "min")
            }
        case .shelf:
            Section("File Shelf") {
                PreciseSlider(title: "Visible items", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show file details", isOn: content.shelfShowDetails)
                Toggle("Show file actions", isOn: content.shelfShowActions)
                Toggle("Show Add button", isOn: content.showQuickActions)
                Toggle("Show overflow count", isOn: content.showFooter)
                PreciseSlider(title: "File icon size", value: content.shelfIconSize, range: 14...64, step: 1, suffix: "pt")
            }
        case .media:
            Section("Media") {
                Toggle("Show source", isOn: content.mediaShowSource)
                Toggle("Show artist", isOn: content.mediaShowArtist)
                Toggle("Show playback controls", isOn: content.showControls)
                Toggle("Show Retry detection", isOn: content.showQuickActions)
                Toggle("Show errors / status", isOn: content.showStatus)
                PreciseSlider(title: "Title lines", value: Binding(get: { Double(content.wrappedValue.mediaTitleLines) }, set: { content.wrappedValue.mediaTitleLines = Int($0) }), range: 1...4, step: 1)
            }
        case .audio:
            Section("Audio") {
                PreciseSlider(title: "Maximum listed outputs", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show volume control", isOn: content.showControls)
                Toggle("Show refresh action", isOn: content.showQuickActions)
                Toggle("Show status / errors", isOn: content.showStatus)
            }
        case .calendar:
            Section("Calendar") {
                Picker("View", selection: content.calendarViewStyle.withDefault(.agenda)) {
                    ForEach(CalendarWidgetViewStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show weekday labels", isOn: content.calendarShowWeekdayHeader.withDefault(true))
                Toggle("Show adjacent-month days", isOn: content.calendarShowAdjacentDays.withDefault(true))
                Toggle("Show event dots", isOn: content.calendarShowEventDots.withDefault(true))
                if content.wrappedValue.resolvedCalendarViewStyle == .monthGrid {
                    Toggle("Show selected-day agenda", isOn: content.calendarShowAgendaBelowGrid.withDefault(true))
                }
                Toggle("Show calendar status", isOn: content.showStatus)
                Toggle("Show event times", isOn: content.calendarShowTimes)
                Toggle("Show Join buttons", isOn: content.calendarShowJoin)
                Toggle("Show refresh action", isOn: content.showQuickActions)
            }
        case .clipboard:
            Section("Clipboard") {
                PreciseSlider(title: "Visible entries", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show search", isOn: content.showSearch)
                Toggle("Show Copy / Remove", isOn: content.showControls)
                Toggle("Show Clear history", isOn: content.showQuickActions)
                Toggle("Show privacy footer", isOn: content.showFooter)
            }
        case .system:
            Section("System information") {
                Toggle("Battery", isOn: content.systemBattery)
                Toggle("Battery progress", isOn: content.showProgress)
                Toggle("Memory", isOn: content.systemMemory)
                Toggle("Storage", isOn: content.systemStorage)
                Toggle("Uptime / Low Power Mode", isOn: content.systemUptime)
            }
        case .launcher:
            Section("Launcher") {
                Toggle("Search field", isOn: content.showSearch)
                Toggle("Timer shortcuts", isOn: content.launcherTimers)
                Toggle("Running applications", isOn: content.launcherRunningApps)
                Toggle("Plugin commands", isOn: content.launcherPlugins)
                Toggle("Open App / Downloads shortcuts", isOn: content.showQuickActions)
                PreciseSlider(title: "Maximum apps / commands", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
            }
        case .activities:
            Section("Activities") {
                PreciseSlider(title: "Visible activities", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
                Toggle("Show detail", isOn: content.activitiesShowDetail)
                Toggle("Show progress", isOn: content.showProgress)
                Toggle("Show dismiss controls", isOn: content.showControls)
                Toggle("Show empty status", isOn: content.showStatus)
            }
        case .notes:
            Section("Notes") {
                PreciseSlider(title: "Editor height", value: content.notesHeight, range: 60...420, step: 5, suffix: "pt")
            }
        case .capture:
            Section("Capture & OCR") {
                Toggle("Show permission hint", isOn: content.captureShowHelp)
                Toggle("Show capture controls", isOn: content.showControls)
                Toggle("Show progress / errors", isOn: content.showStatus)
                PreciseSlider(title: "OCR text lines", value: Binding(get: { Double(content.wrappedValue.captureTextLines) }, set: { content.wrappedValue.captureTextLines = Int($0) }), range: 2...40, step: 1)
            }
        case .stopwatch:
            Section("Stopwatch") {
                PreciseSlider(title: "Time scale", value: content.stopwatchScale, range: 0.8...4, step: 0.1, decimals: 1)
                Toggle("Show controls", isOn: content.showControls)
            }
        case .developer:
            EmptyView()
        }
    }

    private func applyVisualPreset(_ preset: WidgetVisualPreset) {
        var value = style.wrappedValue
        var card = value.resolvedChrome
        switch preset {
        case .clean:
            value.layoutMode = .standard
            value.cardBackgroundStyle = .solid
            value.backgroundOpacity = 0.06
            value.outlineStyle = .none
            value.showHeaderIcon = true
            card.borderOpacity = 0
            card.borderWidth = 0
            card.shadowOpacity = 0
        case .glass:
            value.layoutMode = .standard
            value.cardBackgroundStyle = .glass
            value.glassTintOpacity = 0.10
            value.outlineStyle = .solid
            card.borderOpacity = 0.16
            card.borderWidth = 0.75
            card.shadowOpacity = 0.16
            card.shadowRadius = 12
        case .filled:
            value.layoutMode = .hero
            value.cardBackgroundStyle = .gradient
            value.backgroundOpacity = 0.28
            value.backgroundSecondaryColor = value.accentColor
            value.outlineStyle = .none
            card.borderOpacity = 0
            card.shadowOpacity = 0.12
        case .outline:
            value.layoutMode = .standard
            value.cardBackgroundStyle = .none
            value.outlineStyle = .solid
            card.borderOpacity = 0.45
            card.borderWidth = 1
            card.shadowOpacity = 0
        case .floating:
            value.layoutMode = .compact
            value.cardBackgroundStyle = .glass
            value.outlineStyle = .glow
            card.borderColor = value.accentColor
            card.borderOpacity = 0.45
            card.borderWidth = 1
            card.shadowOpacity = 0.28
            card.shadowRadius = 18
            card.shadowY = 5
        case .minimal:
            value.layoutMode = .minimal
            value.cardBackgroundStyle = .none
            value.outlineStyle = .none
            value.showHeaderIcon = false
            value.padding = max(4, value.padding * 0.65)
            card.borderOpacity = 0
            card.borderWidth = 0
            card.shadowOpacity = 0
        }
        value.chrome = card
        style.wrappedValue = value
    }

    private func colorPicker(_ title: String, _ value: Binding<WidgetColor>) -> some View {
        ColorPicker(title, selection: Binding(get: { value.wrappedValue.color }, set: { value.wrappedValue = WidgetColor($0) }), supportsOpacity: false)
    }
}

struct ClosedNotchSettingsView: View {
    @Binding var layout: WorkspaceLayout
    @ObservedObject var media: MediaService
    let app: String
    @AppStorage("HaloBluetoothClosedNotchEvents") private var bluetoothEvents = true
    @AppStorage("HaloBluetoothClosedNotchConnected") private var bluetoothConnected = true
    @AppStorage("HaloBluetoothClosedNotchDisconnected") private var bluetoothDisconnected = true
    @AppStorage("HaloBluetoothClosedNotchPoweredOn") private var bluetoothPoweredOn = true
    @AppStorage("HaloBluetoothClosedNotchPoweredOff") private var bluetoothPoweredOff = true
    @AppStorage("HaloBluetoothClosedNotchSide") private var bluetoothSide = BluetoothClosedNotchSide.automatic.rawValue
    @AppStorage("HaloBluetoothClosedNotchLayout") private var bluetoothLayout = BluetoothClosedNotchLayout.stacked.rawValue
    @AppStorage("HaloBluetoothClosedNotchAccent") private var bluetoothAccent = BluetoothClosedNotchAccent.blue.rawValue
    @AppStorage("HaloBluetoothClosedNotchShowIcon") private var bluetoothShowIcon = true
    @AppStorage("HaloBluetoothClosedNotchShowLabel") private var bluetoothShowLabel = true
    @AppStorage("HaloBluetoothClosedNotchShowDevice") private var bluetoothShowDevice = true
    @AppStorage("HaloBluetoothClosedNotchDuration") private var bluetoothDuration = 10.0
    @AppStorage("HaloBluetoothClosedNotchIconSize") private var bluetoothIconSize = 16.0
    private var options: Binding<ClosedNotchOptions> { Binding(get: { layout.closedNotch ?? ClosedNotchOptions() }, set: { layout.closedNotch = $0 }) }
    private var visualizer: Binding<VisualizerOptions> { Binding(get: { options.wrappedValue.visualizer ?? VisualizerOptions() }, set: { options.wrappedValue.visualizer = $0 }) }
    private var expansion: Binding<ClosedExpansionOptions> { Binding(get: { options.wrappedValue.expansion ?? ClosedExpansionOptions() }, set: { options.wrappedValue.expansion = $0 }) }
    private var mediaOptions: Binding<ClosedMediaOptions> { Binding(get: { options.wrappedValue.mediaOptions ?? ClosedMediaOptions() }, set: { options.wrappedValue.mediaOptions = $0 }) }
    private var artwork: Binding<ClosedArtworkOptions> {
        Binding(get: {
            if let saved = options.wrappedValue.artworkOptions { return saved }
            let legacy = options.wrappedValue.mediaOptions ?? ClosedMediaOptions()
            var value = ClosedArtworkOptions()
            if legacy.artwork != .none {
                value.enabled = true; value.mode = legacy.artwork; value.size = legacy.artworkSize
                value.vinylRPM = legacy.vinylRPM; value.backgroundOpacity = legacy.backgroundOpacity
            }
            return value
        }, set: { options.wrappedValue.artworkOptions = $0 })
    }
    private var reactive: Binding<ReactiveBackgroundOptions> { Binding(get: { options.wrappedValue.reactiveBackground ?? ReactiveBackgroundOptions() }, set: { options.wrappedValue.reactiveBackground = $0 }) }
    private var power: Binding<PowerReactionOptions> { Binding(get: { options.wrappedValue.powerReaction ?? PowerReactionOptions() }, set: { options.wrappedValue.powerReaction = $0 }) }
    var body: some View {
        Section("Opened background") {
            Toggle("Apply these background effects when opened", isOn: Binding(get: { options.wrappedValue.applyBackgroundWhenOpened ?? false }, set: { options.wrappedValue.applyBackgroundWhenOpened = $0 }))
            Text("Reuse album colors, artwork backgrounds and reactive effects in the opened notch.").font(.caption)
        }
        Section("Content fit") {
            Toggle("Auto-size to fit content", isOn: Binding(get: { options.wrappedValue.autoFitContent ?? true }, set: { options.wrappedValue.autoFitContent = $0 }))
            PreciseSlider(title: "Horizontal padding", value: Binding(get: { options.wrappedValue.contentPaddingX }, set: { options.wrappedValue.horizontalPadding = $0 }), range: 0...24, step: 1, suffix: "pt")
            PreciseSlider(title: "Vertical padding", value: Binding(get: { options.wrappedValue.contentPaddingY }, set: { options.wrappedValue.verticalPadding = $0 }), range: 0...12, step: 1, suffix: "pt")
            PreciseSlider(title: "Margin from camera", value: Binding(get: { options.wrappedValue.contentSideMargin }, set: { options.wrappedValue.sideMargin = $0 }), range: 0...48, step: 1, suffix: "pt")
            PreciseSlider(title: "Margin from outer edge", value: Binding(get: { options.wrappedValue.contentOuterMargin }, set: { options.wrappedValue.outerMargin = $0 }), range: 0...48, step: 1, suffix: "pt")
            Text("The Appearance closed-width slider is the idle/base width. Auto-size grows only as much as visible content needs. Default padding compresses automatically at very small closed heights; explicit padding and margin values stay exact.").font(.caption)
        }
        Section("Automatic width") {
            Toggle("Widen for music and live activity", isOn: expansion.enabled)
            PreciseSlider(title: "Active width", value: expansion.width, range: 120...640, step: 1, suffix: "pt")
            Text("Optional fixed-width expansion for music and other live content. Leave this off for exact content-fit sizing. Power events always use their own measured size and margin.").font(.caption)
        }
        SideDecorationSettingsView(title: "Left icon / GIF", options: Binding(get: { options.wrappedValue.leftDecoration ?? SideDecoration() }, set: { options.wrappedValue.leftDecoration = $0 }))
        SideDecorationSettingsView(title: "Right icon / GIF", options: Binding(get: { options.wrappedValue.rightDecoration ?? SideDecoration() }, set: { options.wrappedValue.rightDecoration = $0 }))
        Section("Content") {
            itemPicker("Left slot", options.left)
            itemPicker("Right slot", options.right)
            PreciseSlider(title: "Text size", value: options.fontSize, range: 8...24, step: 1, suffix: "pt")
            ColorPicker("Color", selection: Binding(get: { options.wrappedValue.color.color }, set: { options.wrappedValue.color = WidgetColor($0) }), supportsOpacity: false)
            Text("Active Halo activities have priority: they use an Activity slot, an inactive side, or temporarily replace the right slot if both sides are occupied.").font(.caption)
        }
        Section("Bluetooth events") {
            Toggle("Show Bluetooth connection states", isOn: $bluetoothEvents)
            Group {
                Toggle("Device connected", isOn: $bluetoothConnected)
                Toggle("Device disconnected", isOn: $bluetoothDisconnected)
                Toggle("Bluetooth turned on", isOn: $bluetoothPoweredOn)
                Toggle("Bluetooth turned off", isOn: $bluetoothPoweredOff)
                Picker("Preferred side", selection: $bluetoothSide) {
                    ForEach(BluetoothClosedNotchSide.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Layout", selection: $bluetoothLayout) {
                    ForEach(BluetoothClosedNotchLayout.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Accent", selection: $bluetoothAccent) {
                    ForEach(BluetoothClosedNotchAccent.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Show event icon", isOn: $bluetoothShowIcon)
                Toggle("Show event label", isOn: $bluetoothShowLabel)
                Toggle("Show device / detail", isOn: $bluetoothShowDevice)
                PreciseSlider(title: "Visible duration", value: $bluetoothDuration, range: 2...20, step: 1, suffix: "s")
                if bluetoothShowIcon {
                    PreciseSlider(title: "Event icon size", value: $bluetoothIconSize, range: 10...30, step: 1, suffix: "pt")
                }
            }
            .disabled(!bluetoothEvents)
            Text("Bluetooth events can temporarily take the left or right Closed Notch slot. Your normal content returns after the selected duration.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Closed media text") {
            Picker("Text", selection: mediaOptions.textMode) {
                Text("Track title").tag(MediaTextMode.title); Text("Artist").tag(MediaTextMode.artist); Text("Title + artist").tag(MediaTextMode.titleArtist); Text("Lyrics").tag(MediaTextMode.lyrics)
            }
            Picker("Overflow", selection: mediaOptions.overflow) {
                Text("Truncate").tag(MediaOverflowMode.truncate); Text("Scale to fit").tag(MediaOverflowMode.scale); Text("Marquee").tag(MediaOverflowMode.marquee)
            }
            if mediaOptions.wrappedValue.overflow == .truncate || mediaOptions.wrappedValue.overflow == .marquee {
                PreciseSlider(title: "Media horizontal space", value: Binding(get: { mediaOptions.wrappedValue.resolvedHorizontalSpace }, set: { mediaOptions.wrappedValue.horizontalSpace = $0 }), range: 48...360, step: 1, suffix: "pt")
                Text("This is the maximum horizontal space reserved for Truncate or Marquee media. Lyrics can still shrink below it when dynamic lyric width is enabled.").font(.caption)
            }
            if mediaOptions.wrappedValue.textMode == .lyrics {
                Picker("Lyric display", selection: Binding(get: { mediaOptions.wrappedValue.resolvedLyricDisplay }, set: { mediaOptions.wrappedValue.lyricDisplay = $0 })) {
                    Text("Current line").tag(LyricDisplayMode.line); Text("Focus phrase").tag(LyricDisplayMode.focus); Text("Current word").tag(LyricDisplayMode.word)
                }
                Toggle("Resize notch to current lyric", isOn: Binding(get: { mediaOptions.wrappedValue.usesDynamicLyricWidth }, set: { mediaOptions.wrappedValue.dynamicLyricWidth = $0 }))
                PreciseSlider(title: "Lyrics sync offset", value: Binding(get: { mediaOptions.wrappedValue.resolvedLyricSyncOffset }, set: { mediaOptions.wrappedValue.lyricSyncOffset = $0 }), range: -5...5, step: 0.05, suffix: "s", decimals: 2)
            }
            if mediaOptions.wrappedValue.textMode != .lyrics || mediaOptions.wrappedValue.resolvedLyricDisplay != .word {
                Picker("Lines", selection: mediaOptions.lines) { Text("1 line").tag(1); Text("2 lines").tag(2) }
            }
            if mediaOptions.wrappedValue.overflow == .marquee { PreciseSlider(title: "Marquee speed", value: mediaOptions.marqueeSpeed, range: 8...120, step: 1, suffix: "pt/s") }
            Toggle("Show playback icon", isOn: mediaOptions.showPlaybackIcon)
            if mediaOptions.wrappedValue.textMode == .lyrics {
                Toggle("Use online lyrics fallback", isOn: Binding(get: { mediaOptions.wrappedValue.usesOnlineLyrics }, set: { mediaOptions.wrappedValue.onlineLyrics = $0 }))
                Text("Halo re-samples the player clock and snaps meaningful drift automatically. The sync offset lets you correct a lyric source that is consistently early or late. Timestamped LRC offset metadata is also respected.").font(.caption)
            }
        }
        Section("Song changes") {
            Picker("Transition", selection: Binding(get: { mediaOptions.wrappedValue.resolvedChangeAnimation }, set: { mediaOptions.wrappedValue.changeAnimation = $0 })) {
                Text("None").tag(MediaChangeAnimation.none); Text("Fade").tag(MediaChangeAnimation.fade); Text("Slide").tag(MediaChangeAnimation.slide); Text("Scale").tag(MediaChangeAnimation.scale); Text("Blur + fade").tag(MediaChangeAnimation.blur)
            }
            if mediaOptions.wrappedValue.resolvedChangeAnimation != .none {
                PreciseSlider(title: "Transition duration", value: Binding(get: { mediaOptions.wrappedValue.resolvedChangeAnimationDuration }, set: { mediaOptions.wrappedValue.changeAnimationDuration = $0 }), range: 0.08...1.2, step: 0.02, suffix: "s", decimals: 2)
            }
            Text("The chosen transition applies to song text, synced lyrics and cover/vinyl changes.").font(.caption)
        }
        Section("Media gestures") {
            gesturePicker("Tap", Binding(get: { mediaOptions.wrappedValue.resolvedTapAction }, set: { mediaOptions.wrappedValue.tapAction = $0 }))
            gesturePicker("Double tap", Binding(get: { mediaOptions.wrappedValue.resolvedDoubleTapAction }, set: { mediaOptions.wrappedValue.doubleTapAction = $0 }))
            gesturePicker("Swipe left", Binding(get: { mediaOptions.wrappedValue.resolvedSwipeLeftAction }, set: { mediaOptions.wrappedValue.swipeLeftAction = $0 }))
            gesturePicker("Swipe right", Binding(get: { mediaOptions.wrappedValue.resolvedSwipeRightAction }, set: { mediaOptions.wrappedValue.swipeRightAction = $0 }))
            Text("Gestures work across the closed media region, including artwork-only layouts. Defaults: tap Play/Pause, swipe left Next, swipe right Previous.").font(.caption)
        }
        Section("Artwork layers") {
            Toggle("Show foreground artwork", isOn: artwork.enabled)
            if artwork.wrappedValue.enabled {
                Picker("Foreground style", selection: Binding(
                    get: { artwork.wrappedValue.mode == .vinyl ? MediaArtworkMode.vinyl : .cover },
                    set: { artwork.wrappedValue.mode = $0 }
                )) {
                    Text("Album cover").tag(MediaArtworkMode.cover)
                    Text("Rotating vinyl").tag(MediaArtworkMode.vinyl)
                }.pickerStyle(.segmented)
                Picker("Foreground side", selection: artwork.side) {
                    Text("Automatic").tag(ClosedNotchSideChoice.automatic); Text("Left").tag(ClosedNotchSideChoice.left); Text("Right").tag(ClosedNotchSideChoice.right)
                }
                Toggle("Artwork only", isOn: Binding(get: { artwork.wrappedValue.isArtworkOnly }, set: { artwork.wrappedValue.artworkOnly = $0 }))
                PreciseSlider(title: "Artwork size", value: artwork.size, range: 14...72, step: 1, suffix: "pt")
                PreciseSlider(title: "Artwork padding", value: artwork.padding, range: 0...24, step: 1, suffix: "pt")
                PreciseSlider(title: "Artwork margin", value: artwork.margin, range: 0...48, step: 1, suffix: "pt")
                if artwork.wrappedValue.mode == .vinyl { PreciseSlider(title: "Vinyl speed", value: artwork.vinylRPM, range: 1...45, step: 1, suffix: "rpm") }
            }
            Toggle("Use album art as notch background", isOn: Binding(
                get: { artwork.wrappedValue.usesBackgroundArtwork },
                set: { enabled in
                    artwork.wrappedValue.backgroundEnabled = enabled
                    if enabled && !artwork.wrappedValue.enabled { artwork.wrappedValue.enabled = true }
                    if artwork.wrappedValue.mode == .background { artwork.wrappedValue.mode = .cover }
                }
            ))
            if artwork.wrappedValue.usesBackgroundArtwork {
                PreciseSlider(title: "Artwork background opacity", value: artwork.backgroundOpacity, range: 0...1, step: 0.01, decimals: 2)
            }
            Text("Foreground and background artwork are independent. You can show a square cover or spinning vinyl inside the closed notch while the same album art fills the notch background behind it.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Album colors") {
            Toggle("Color notch background from album", isOn: Binding(get: { options.wrappedValue.albumBackgroundColor ?? false }, set: { options.wrappedValue.albumBackgroundColor = $0 }))
            Toggle("Color closed-notch text from album", isOn: Binding(get: { options.wrappedValue.albumTextColor ?? false }, set: { options.wrappedValue.albumTextColor = $0 }))
        }
        Section("Reactive background") {
            Toggle("React while music plays", isOn: reactive.enabled)
            Picker("Reaction profile", selection: reactive.driver) {
                Text("Pulse").tag(ReactiveDriver.pulse); Text("Bass").tag(ReactiveDriver.bass); Text("Mids").tag(ReactiveDriver.mids); Text("Treble").tag(ReactiveDriver.treble); Text("Spectrum").tag(ReactiveDriver.spectrum)
            }.disabled(!reactive.wrappedValue.enabled)
            if reactive.wrappedValue.enabled {
                PreciseSlider(title: "Reaction speed", value: reactive.speed, range: 0.2...3, step: 0.05, decimals: 2)
                if reactive.wrappedValue.driver != .pulse { PreciseSlider(title: "Audio sensitivity", value: Binding(get: { reactive.wrappedValue.resolvedAudioSensitivity }, set: { reactive.wrappedValue.audioSensitivity = $0 }), range: 0.25...4, step: 0.05, decimals: 2) }
                PreciseSlider(title: "Master intensity", value: reactive.intensity, range: 0...1, step: 0.05, decimals: 2)
                PreciseSlider(title: "Affect brightness", value: reactive.brightness, range: 0...0.8, step: 0.01, decimals: 2)
                PreciseSlider(title: "Affect saturation", value: reactive.saturation, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Affect scale", value: reactive.scale, range: 0...0.12, step: 0.005, decimals: 3)
                PreciseSlider(title: "Affect hue", value: reactive.hueShift, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Affect blur", value: reactive.blur, range: 0...12, step: 0.25, suffix: "pt", decimals: 2)
                PreciseSlider(title: "Affect grain", value: reactive.grain, range: 0...0.6, step: 0.01, decimals: 2)
            }
            Text("Bass, Mids, Treble and Spectrum analyse captured system-audio PCM. macOS may request Screen Recording/audio-capture permission the first time. Pulse remains permission-free.").font(.caption)
        }
        Section("Power events") {
            Toggle("Enable power events", isOn: Binding(get: { power.wrappedValue.isEnabled }, set: { power.wrappedValue.enabled = $0 }))
            if power.wrappedValue.isEnabled {
                Picker("Side", selection: power.side) { Text("Automatic").tag(ClosedNotchSideChoice.automatic); Text("Left").tag(ClosedNotchSideChoice.left); Text("Right").tag(ClosedNotchSideChoice.right) }
                Picker("Charging", selection: power.charging) { powerStyles() }
                Picker("Low battery", selection: power.low) { powerStyles() }
                Picker("Charged", selection: power.charged) { powerStyles() }
                PreciseSlider(title: "Low battery threshold", value: Binding(get: { Double(power.wrappedValue.lowThreshold) }, set: { power.wrappedValue.lowThreshold = Int($0) }), range: 5...50, step: 1, suffix: "%")
                PreciseSlider(title: "Margin from notch", value: Binding(
                    get: { power.wrappedValue.resolvedNotchMargin },
                    set: { power.wrappedValue.notchMargin = $0 }
                ), range: 0...48, step: 1, suffix: "pt")
                Toggle("Expand for power events", isOn: power.expandForEvent)
                if power.wrappedValue.expandForEvent {
                    PreciseSlider(title: "Extra event space", value: Binding(
                        get: { power.wrappedValue.resolvedExtraEventSpace },
                        set: { power.wrappedValue.extraEventSpace = $0 }
                    ), range: 0...120, step: 1, suffix: "pt")
                    Text("Power events size to their visible content. Extra event space is optional breathing room and no longer forces a large default wing.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Dynamic color by battery level", isOn: Binding(get: { power.wrappedValue.usesDynamicColor }, set: { power.wrappedValue.dynamicColor = $0 }))
                if power.wrappedValue.usesDynamicColor {
                    ColorPicker("Low battery color", selection: Binding(get: { power.wrappedValue.resolvedLowColor.color }, set: { power.wrappedValue.lowColor = WidgetColor($0) }), supportsOpacity: false)
                    ColorPicker("Mid battery color", selection: Binding(get: { power.wrappedValue.resolvedMidColor.color }, set: { power.wrappedValue.midColor = WidgetColor($0) }), supportsOpacity: false)
                    ColorPicker("High battery color", selection: Binding(get: { power.wrappedValue.resolvedHighColor.color }, set: { power.wrappedValue.highColor = WidgetColor($0) }), supportsOpacity: false)
                } else { ColorPicker("Power event color", selection: Binding(get: { power.wrappedValue.color.color }, set: { power.wrappedValue.color = WidgetColor($0) }), supportsOpacity: false) }
            }
        }
        Section("Music animation") {
            Picker("Visualizer style", selection: Binding<PlaybackAnimation>(get: { options.wrappedValue.animation }, set: { options.wrappedValue.animation = $0 })) {
                ForEach(PlaybackAnimation.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Animate while music plays", isOn: options.animate)
            Toggle("Use colors from music artwork", isOn: visualizer.dynamicColors)
            PreciseSlider(title: "Animation speed", value: visualizer.speed, range: 0.25...2, step: 0.05, decimals: 2)
            PreciseSlider(title: "Motion intensity", value: visualizer.intensity, range: 0.1...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Visualizer width", value: visualizer.width, range: 32...160, step: 1, suffix: "pt")
            PreciseSlider(title: "Visualizer height", value: visualizer.height, range: 8...48, step: 1, suffix: "pt")
            PlaybackVisualizer(kind: options.wrappedValue.animation, playing: true, enabled: options.wrappedValue.animate, options: visualizer.wrappedValue, palette: media.artworkColors, fallback: options.wrappedValue.color.color)
                .padding(12).background(.black, in: RoundedRectangle(cornerRadius: 12))
            Button("Retry player detection") { media.retryDetection(preferred: app) }.disabled(media.busy)
            Text(media.title)
            if let error = media.error { Text(error).foregroundStyle(.orange) }
        }
        Button("Reset closed content") { layout.closedNotch = ClosedNotchOptions() }
    }
    private func itemPicker(_ title: String, _ value: Binding<ClosedNotchItem>) -> some View { Picker(title, selection: value) { ForEach(ClosedNotchItem.allCases) { Text($0.rawValue.capitalized).tag($0) } } }
    private func gesturePicker(_ title: String, _ value: Binding<MediaGestureAction>) -> some View {
        Picker(title, selection: value) {
            Text("None").tag(MediaGestureAction.none); Text("Play / Pause").tag(MediaGestureAction.playPause); Text("Next track").tag(MediaGestureAction.next); Text("Previous track").tag(MediaGestureAction.previous); Text("Open player").tag(MediaGestureAction.openPlayer)
        }
    }
    @ViewBuilder private func powerStyles() -> some View {
        Text("Off").tag(PowerReactionStyle.off); Text("Icon").tag(PowerReactionStyle.icon); Text("Percentage").tag(PowerReactionStyle.percent); Text("Icon + percentage").tag(PowerReactionStyle.iconPercent); Text("Label").tag(PowerReactionStyle.label)
    }
}

private extension OpenNotchRegionPlacement {
    var editorRowIndex: Int {
        switch self { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 1; case .bottomLeft, .bottomCenter, .bottomRight: return 2 }
    }
    var editorColumnIndex: Int {
        switch self { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 1; case .topRight, .middleRight, .bottomRight: return 2 }
    }
    var editorAlignment: Alignment {
        switch self {
        case .topLeft: return .topLeading; case .topCenter: return .top; case .topRight: return .topTrailing
        case .middleLeft: return .leading; case .middleCenter: return .center; case .middleRight: return .trailing
        case .bottomLeft: return .bottomLeading; case .bottomCenter: return .bottom; case .bottomRight: return .bottomTrailing
        }
    }
}

struct OpenedNotchWorkspaceEditor: View {
    @Binding var layout: WorkspaceLayout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedItem: UUID?
    @State private var selectedGroup: UUID?
    @State private var selectedRegion: UUID?
    @State private var backgroundMode = false

    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                toolbar
                Divider()
                ScrollView([.horizontal, .vertical]) { preview.padding(26).frame(minWidth: 640, minHeight: 560) }
            }.frame(minWidth: 650)
            inspector.frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
        }
        .onAppear { materialize() }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("Workspace", selection: Binding(
                get: { opened.resolvedContentMode },
                set: { mode in var value = opened; value.contentMode = mode; layout.openNotch = value }
            )) {
                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 250)
            Picker("Preset", selection: Binding(get: { opened.preset }, set: { applyPreset($0) })) {
                ForEach(OpenNotchPreset.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 190)
            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            if opened.resolvedContentMode == .fixed {
                Menu { regionArrangementMenu } label: { Label("Regions", systemImage: "rectangle.3.group") }
            }
            Button { duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.disabled(selectedItem == nil).help("Duplicate selected item")
            Button { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil } label: { Image(systemName: "paintbrush") }.help("Opened surface appearance")
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }.buttonStyle(.plain).help("Close editor")
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
        }.padding(12)
    }

    @ViewBuilder private var addMenu: some View {
        Menu("Module") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }
        Menu("Lightweight element") { ForEach(OpenNotchElementKind.allCases) { element in Button(element.title) { addElement(element) } } }
        Divider()
        Button("Group") { addGroup() }
        Button("Region") { addRegion() }.disabled(opened.regions.count >= 9)
    }

    @ViewBuilder private var regionArrangementMenu: some View {
        Button("Add Region") { addRegion() }.disabled(opened.regions.count >= 9)
        if !opened.regions.isEmpty {
            Divider()
            let count = opened.regions.count
            if count == 1 {
                Button("Full Canvas") { arrangeSingle(.full) }
                Button("Centered Large") { arrangeSingle(OpenNotchRegionFrame(x: 0.10, y: 0.10, width: 0.80, height: 0.80)) }
                Button("Compact Center") { arrangeSingle(OpenNotchRegionFrame(x: 0.25, y: 0.25, width: 0.50, height: 0.50)) }
                Divider()
                Button("Left Half") { arrangeSingle(OpenNotchRegionFrame(x: 0, y: 0, width: 0.50, height: 1)) }
                Button("Right Half") { arrangeSingle(OpenNotchRegionFrame(x: 0.50, y: 0, width: 0.50, height: 1)) }
                Button("Top Half") { arrangeSingle(OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.50)) }
                Button("Bottom Half") { arrangeSingle(OpenNotchRegionFrame(x: 0, y: 0.50, width: 1, height: 0.50)) }
            } else if count == 2 {
                Button("Side by Side") { arrangeSideBySide() }
                Button("Stacked") { arrangeStacked() }
                Divider()
                Button("Wide Left + Narrow Right") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 0.64, height: 1), OpenNotchRegionFrame(x: 0.66, y: 0, width: 0.34, height: 1)]) }
                Button("Narrow Left + Wide Right") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 0.34, height: 1), OpenNotchRegionFrame(x: 0.36, y: 0, width: 0.64, height: 1)]) }
                Button("Hero Top + Bottom Strip") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.66), OpenNotchRegionFrame(x: 0, y: 0.68, width: 1, height: 0.32)]) }
                Button("Top Strip + Hero Bottom") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.32), OpenNotchRegionFrame(x: 0, y: 0.34, width: 1, height: 0.66)]) }
            } else if count == 3 {
                Button("3 Columns") { arrangeColumns() }
                Button("3 Rows") { arrangeRows() }
                Divider()
                Button("Hero Left + Right Stack") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 0.58, height: 1), OpenNotchRegionFrame(x: 0.60, y: 0, width: 0.40, height: 0.49), OpenNotchRegionFrame(x: 0.60, y: 0.51, width: 0.40, height: 0.49)]) }
                Button("Hero Top + Bottom Split") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.58), OpenNotchRegionFrame(x: 0, y: 0.60, width: 0.49, height: 0.40), OpenNotchRegionFrame(x: 0.51, y: 0.60, width: 0.49, height: 0.40)]) }
            } else if count == 4 {
                Button("2 × 2 Grid") { arrangeGrid() }
                Button("4 Columns") { arrangeColumns() }
                Button("4 Rows") { arrangeRows() }
            } else {
                Button("Automatic Grid") { arrangeGrid() }
                Button("Columns") { arrangeColumns() }
                Button("Rows") { arrangeRows() }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text("Opened Notch").font(.headline); Text(opened.preset.rawValue).font(.caption).foregroundStyle(.secondary) }
                Spacer(); Text("Drag items between regions · drag corner to resize").font(.caption).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay {
                    GeometryReader { proxy in
                        let inset: CGFloat = 14
                        let canvasSize = CGSize(width: max(1, proxy.size.width - inset * 2), height: max(1, proxy.size.height - inset * 2))
                        if opened.regions.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "rectangle.dashed").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
                                Text("No regions").font(.headline)
                                Text("This workspace is intentionally empty.").font(.caption).foregroundStyle(.secondary)
                                Button("Add Region") { addRegion() }.buttonStyle(.borderedProminent)
                            }
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .padding(inset)
                        } else if opened.resolvedContentMode == .fixed && opened.usesFreeformRegions {
                            freeformPreview(canvasSize: canvasSize)
                                .padding(inset)
                        } else {
                            let heights = editorTrackSizes(total: canvasSize.height, weights: editorRowWeights, gap: 8)
                            VStack(spacing: 8) {
                                editorRow([.topLeft, .topCenter, .topRight], height: heights[0], totalWidth: canvasSize.width)
                                editorRow([.middleLeft, .middleCenter, .middleRight], height: heights[1], totalWidth: canvasSize.width)
                                editorRow([.bottomLeft, .bottomCenter, .bottomRight], height: heights[2], totalWidth: canvasSize.width)
                            }
                            .padding(inset)
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                .frame(width: 610, height: 470)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)
        }
    }

    private var editorRowWeights: [Double] {
        let occupied = [0, 1, 2].map { row in opened.regions.contains { $0.placement.editorRowIndex == row } }
        return zip(opened.resolvedRowWeights, occupied).map { $1 ? $0 : 0 }
    }
    private var editorColumnWeights: [Double] {
        let occupied = [0, 1, 2].map { column in opened.regions.contains { $0.placement.editorColumnIndex == column } }
        return zip(opened.resolvedColumnWeights, occupied).map { $1 ? $0 : 0 }
    }
    private func editorTrackSizes(total: CGFloat, weights: [Double], gap: CGFloat) -> [CGFloat] {
        let usable = max(0, total - gap * 2)
        let positive = weights.map { max(0, $0) }
        let sum = positive.reduce(0, +)
        guard sum > 0 else { return [usable / 3, usable / 3, usable / 3] }
        return positive.map { usable * CGFloat($0 / sum) }
    }

    private func editorRow(_ placements: [OpenNotchRegionPlacement], height: CGFloat, totalWidth: CGFloat) -> some View {
        let widths = editorTrackSizes(total: totalWidth, weights: editorColumnWeights, gap: 8)
        return HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                regionCell(placements[index], cellSize: CGSize(width: widths[index], height: height))
                    .frame(width: widths[index], height: max(0, height))
            }
        }
        .frame(width: totalWidth, height: max(0, height))
    }

    private func regionCell(_ placement: OpenNotchRegionPlacement, cellSize: CGSize) -> some View {
        let region = opened.regions.first { $0.placement == placement }
        return ZStack(alignment: placement.editorAlignment) {
            if let region {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(placement.title).font(.system(size: 9, weight: .semibold)); Spacer(); Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.green) }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(width: max(34, cellSize.width * CGFloat(region.resolvedWidthFraction)),
                       height: max(34, cellSize.height * CGFloat(region.resolvedHeightFraction)), alignment: .topLeading)
                .background((selectedRegion == region.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.035)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedRegion == region.id ? Color.accentColor.opacity(0.6) : .white.opacity(0.06)))
                .contentShape(Rectangle())
                .clipped()
                .onTapGesture { selectedRegion = region.id; selectedGroup = nil; selectedItem = nil; backgroundMode = false }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, placement: placement) }
            } else if cellSize.width > 24 && cellSize.height > 24 {
                Text("Drop here").font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, placement: placement) }
            }
        }
        .frame(width: cellSize.width, height: cellSize.height, alignment: placement.editorAlignment)
        .clipped()
    }


    private func freeformPreview(canvasSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(opened.regions) { region in
                let frame = effectiveRegionFrame(region.id)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(regionTitle(region)).font(.system(size: 9, weight: .semibold))
                        Spacer()
                        Text("\(Int((frame.width * 100).rounded()))×\(Int((frame.height * 100).rounded()))%")
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(width: max(44, canvasSize.width * CGFloat(frame.width)),
                       height: max(44, canvasSize.height * CGFloat(frame.height)), alignment: .topLeading)
                .background((selectedRegion == region.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.045)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedRegion == region.id ? Color.accentColor.opacity(0.75) : .white.opacity(0.08), lineWidth: selectedRegion == region.id ? 1.5 : 1))
                .contentShape(Rectangle())
                .clipped()
                .offset(x: canvasSize.width * CGFloat(frame.x), y: canvasSize.height * CGFloat(frame.y))
                .onTapGesture { selectedRegion = region.id; selectedGroup = nil; selectedItem = nil; backgroundMode = false }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, regionID: region.id) }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .clipped()
    }

    private func regionTitle(_ region: OpenNotchRegion) -> String {
        let index = (opened.regions.firstIndex(where: { $0.id == region.id }) ?? 0) + 1
        return "Region \(index)"
    }

    private func groupPreview(_ group: OpenNotchGroup, region: OpenNotchRegion) -> some View {
        let stack = Group {
            if group.axis == .horizontal {
                HStack(spacing: 0) { itemList(group, region: region) }
            } else {
                VStack(alignment: .leading, spacing: 0) { itemList(group, region: region) }
            }
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack { Text(group.name).font(.system(size: 8, weight: .medium)).foregroundStyle(.secondary); Spacer(); Image(systemName: group.axis == .horizontal ? "arrow.left.and.right" : "arrow.up.and.down").font(.system(size: 8)) }
            stack
        }
        .padding(5)
        .background(selectedGroup == group.id ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { selectedGroup = group.id; selectedRegion = region.id; selectedItem = nil; backgroundMode = false }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, groupID: group.id) }
    }

    @ViewBuilder private func itemList(_ group: OpenNotchGroup, region: OpenNotchRegion) -> some View {
        ForEach(group.items) { item in itemPreview(item, group: group, region: region) }
    }

    private func itemPreview(_ item: OpenNotchItem, group: OpenNotchGroup, region: OpenNotchRegion) -> some View {
        let label = item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized
        return HStack(spacing: 4) {
            Image(systemName: item.module?.symbol ?? item.element?.symbol ?? (item.kind == .divider ? "minus" : "rectangle"))
            Text(label).lineLimit(1)
            if item.hidden { Image(systemName: "eye.slash").foregroundStyle(.secondary) }
        }
        .font(.system(size: 9, weight: item.priority == .alwaysVisible || item.priority == .high ? .semibold : .regular))
        .padding(.horizontal, 6).padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            if selectedItem == item.id { RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.28)) }
            else { widgetPreviewBackground(item) }
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedItem == item.id {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 7)).padding(3).background(.ultraThinMaterial, in: Circle()).offset(x: 4, y: 4)
                    .gesture(DragGesture().onChanged { value in resize(item.id, translation: value.translation) })
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedItem = item.id; selectedGroup = group.id; selectedRegion = region.id; backgroundMode = false }
        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
        .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, groupID: group.id, before: item.id) }
        .contextMenu {
            Button(item.hidden ? "Show" : "Hide") { mutateItem(item.id) { $0.hidden.toggle() } }
            Button("Duplicate") { duplicate(item.id) }
            Button("Move to New Group") { groupSelectedItem() }
            Divider(); Button("Remove", role: .destructive) { remove(item.id) }
        }
    }

    @ViewBuilder private var inspector: some View {
        Form {
            if backgroundMode { backgroundInspector }
            else if let item = selectedItem.flatMap(findItem) { itemInspector(item) }
            else if let group = selectedGroup.flatMap(findGroup) { groupInspector(group) }
            else if let region = selectedRegion.flatMap(findRegion) { regionInspector(region) }
            else {
                Section("Opened workspace") {
                    Text("Select an item, group, or region in the preview. Drag modules between regions and use the resize handle on a selected item.").foregroundStyle(.secondary)
                    Button("Customize Surface Appearance") { backgroundMode = true }
                }
            }
        }.formStyle(.grouped).scrollContentBackground(.hidden)
    }

    @ViewBuilder private func itemInspector(_ item: OpenNotchItem) -> some View {
        let binding = itemBinding(item.id)
        Section("Item") {
            Text(item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized).font(.headline)
            Toggle("Visible", isOn: Binding(get: { !binding.wrappedValue.hidden }, set: { binding.wrappedValue.hidden = !$0 }))
            Picker("Presentation", selection: binding.presentation) { ForEach(OpenNotchPresentation.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Priority", selection: binding.priority) { ForEach(OpenNotchPriority.allCases) { Text($0.rawValue).tag($0) } }
        }
        if let module = item.module {
            widgetBlockInspector(itemID: item.id, module: module)
        } else {
            Section("Responsive sizing") {
                Picker("Behavior", selection: binding.sizing.mode) { ForEach(OpenNotchSizingMode.allCases) { Text($0.rawValue).tag($0) } }
                sizingSlider("Min width", binding.sizing.minimumWidth, 20...1200)
                sizingSlider("Preferred width", binding.sizing.preferredWidth, 20...1200)
                sizingSlider("Max width", binding.sizing.maximumWidth, 20...1600)
                sizingSlider("Min height", binding.sizing.minimumHeight, 18...900)
                sizingSlider("Preferred height", binding.sizing.preferredHeight, 18...1100)
                sizingSlider("Max height", binding.sizing.maximumHeight, 18...1400)
            }
            Section("Element styling") { styleInspector(binding.style) }
        }
        Section("Visibility rules") {
            Picker("Match", selection: binding.visibilityLogic) { ForEach(OpenNotchVisibilityLogic.allCases) { Text($0.rawValue).tag($0) } }
            ForEach(Array(binding.wrappedValue.visibilityRules.enumerated()), id: \.element.id) { index, rule in
                let rb = ruleBinding(item.id, index: index)
                HStack { Picker("Metric", selection: rb.metric) { ForEach(OpenNotchVisibilityMetric.allCases) { Text($0.rawValue).tag($0) } }; Button { removeRule(item.id, index: index) } label: { Image(systemName: "minus.circle") } }
                Picker("Condition", selection: rb.comparison) { ForEach(OpenNotchVisibilityComparison.allCases) { Text($0.rawValue).tag($0) } }
                if rb.wrappedValue.metric.isBoolean { Toggle("Required state", isOn: Binding(get: { rb.wrappedValue.value >= 0.5 }, set: { rb.wrappedValue.value = $0 ? 1 : 0 })) }
                else { PreciseSlider(title: "Value", value: rb.value, range: 0...100, step: 1, suffix: "%") }
                if index < binding.wrappedValue.visibilityRules.count - 1 { Divider() }
            }
            Button("Add Rule") { binding.wrappedValue.visibilityRules.append(OpenNotchVisibilityRule()) }
        }
        Section("Interactions") {
            interactionPicker("Single click", binding.interactions.singleClick)
            interactionPicker("Double click", binding.interactions.doubleClick)
            interactionPicker("Right click", binding.interactions.rightClick)
            interactionPicker("Scroll", binding.interactions.scroll)
            interactionPicker("Drag", binding.interactions.drag)
            interactionPicker("Modifier click", binding.interactions.modifierClick)
        }
        if item.element == .customText { Section("Content") { TextField("Text", text: binding.customText) } }
        if item.element == .customIcon { Section("Content") { TextField("SF Symbol", text: binding.customIcon) } }
        if item.element == .customImage || item.element == .customGIF { Section("Content") { TextField("Image / GIF path", text: binding.customAssetPath) } }
        if item.element == .button { Section("Content") { TextField("Label", text: binding.buttonLabel); TextField("URL", text: binding.buttonURL) } }
        Section { HStack { Button("Duplicate") { duplicate(item.id) }; Button("New Group") { groupSelectedItem() }; Spacer(); Button("Remove", role: .destructive) { remove(item.id) } } }
    }

    @ViewBuilder private func widgetBlockInspector(itemID: UUID, module: ModuleID) -> some View {
        let style = widgetStyleBinding(itemID, module: module)
        Section("Widget Block") {
            Picker("Vertical content", selection: itemBinding(itemID).verticalAlignment.withDefault(.center)) {
                ForEach(OpenNotchBlockVerticalAlignment.allCases) { Text($0.rawValue).tag($0) }
            }
            HStack(spacing: 6) {
                ForEach(WidgetVisualPreset.allCases) { preset in
                    Button(preset.rawValue) { applyWidgetPreset(preset, itemID: itemID, module: module) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Toggle("Show title", isOn: style.showTitle)
            Toggle("Show header icon", isOn: Binding(get: { style.wrappedValue.showsHeaderIcon }, set: { style.wrappedValue.showHeaderIcon = $0 }))
            Picker("Content alignment", selection: style.content.withDefault(WidgetContentOptions()).alignment) {
                ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) }
            }
        }
        if module == .calendar {
            let content = style.content.withDefault(WidgetContentOptions())
            Section("Calendar Presentation") {
                Picker("View", selection: content.calendarViewStyle.withDefault(.split)) {
                    ForEach(CalendarWidgetViewStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Text("Agenda emphasizes upcoming events, Month Grid is a real navigable calendar, Week Strip is compact, and Split pairs the month with the selected day's agenda.")
                    .font(.caption).foregroundStyle(.secondary)
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...20, step: 1)
                Toggle("Weekday labels", isOn: content.calendarShowWeekdayHeader.withDefault(true))
                Toggle("Adjacent-month days", isOn: content.calendarShowAdjacentDays.withDefault(true))
                Toggle("Event dots", isOn: content.calendarShowEventDots.withDefault(true))
                if content.wrappedValue.resolvedCalendarViewStyle == .monthGrid {
                    Toggle("Agenda below month", isOn: content.calendarShowAgendaBelowGrid.withDefault(true))
                }
                Toggle("Event times", isOn: content.calendarShowTimes)
                Toggle("Join buttons", isOn: content.calendarShowJoin)
            }
        }
        Section("Block Styling") {
            Picker("Background", selection: Binding(get: { style.wrappedValue.resolvedCardBackgroundStyle }, set: { style.wrappedValue.cardBackgroundStyle = $0 })) {
                ForEach(WidgetCardBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            let background = style.wrappedValue.resolvedCardBackgroundStyle
            if background == .solid || background == .gradient || background == .glass {
                ColorPicker("Background color", selection: Binding(get: { style.wrappedValue.backgroundColor.color }, set: { style.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false)
            }
            if background == .gradient {
                ColorPicker("Second color", selection: Binding(get: { style.wrappedValue.resolvedBackgroundSecondaryColor.color }, set: { style.wrappedValue.backgroundSecondaryColor = WidgetColor($0) }), supportsOpacity: false)
                PreciseSlider(title: "Gradient angle", value: style.gradientAngle.withDefault(135), range: -180...180, step: 5, suffix: "°")
            }
            if background != .none {
                PreciseSlider(title: "Background opacity", value: style.backgroundOpacity, range: 0...1, step: 0.02, decimals: 2)
            }
            Picker("Outline", selection: Binding(get: { style.wrappedValue.resolvedOutlineStyle }, set: { style.wrappedValue.outlineStyle = $0 })) {
                ForEach(WidgetOutlineStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            if style.wrappedValue.resolvedOutlineStyle != .none {
                ColorPicker("Outline color", selection: Binding(get: { style.wrappedValue.resolvedChrome.borderColor.color }, set: { var chrome = style.wrappedValue.resolvedChrome; chrome.borderColor = WidgetColor($0); style.wrappedValue.chrome = chrome }), supportsOpacity: false)
                PreciseSlider(title: "Outline width", value: widgetChromeDouble(style, \.borderWidth), range: 0.5...6, step: 0.25, suffix: "pt", decimals: 2)
                PreciseSlider(title: "Outline opacity", value: widgetChromeDouble(style, \.borderOpacity), range: 0...1, step: 0.05, decimals: 2)
            }
            PreciseSlider(title: "Corner radius", value: style.cornerRadius, range: 0...40, step: 1, suffix: "pt")
            PreciseSlider(title: "Internal padding", value: style.padding, range: 0...32, step: 1, suffix: "pt")
        }
        Section("Typography") {
            Picker("Font", selection: style.fontFamily) { ForEach(WidgetFontFamily.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Weight", selection: style.weight) { ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            PreciseSlider(title: "Base text size", value: style.fontSize, range: 10...40, step: 1, suffix: "pt")
            ColorPicker("Text", selection: Binding(get: { style.wrappedValue.textColor.color }, set: { style.wrappedValue.textColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Accent", selection: Binding(get: { style.wrappedValue.accentColor.color }, set: { style.wrappedValue.accentColor = WidgetColor($0) }), supportsOpacity: false)
        }
        Section("Displayed Content") {
            ForEach(module.widgetElements) { descriptor in
                let element = widgetElementStyleBinding(itemID, module: module, descriptor: descriptor)
                DisclosureGroup {
                    styleInspector(element, defaultVisible: descriptor.defaultVisible)
                } label: {
                    Toggle(isOn: Binding(
                        get: { element.wrappedValue?.visible ?? descriptor.defaultVisible },
                        set: { visible in
                            var value = element.wrappedValue ?? WidgetElementStyle()
                            value.visible = visible
                            element.wrappedValue = value
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(descriptor.title)
                            Text(descriptor.detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Section {
            Button("Reset Block to Visual Workspace Defaults") { mutateItem(itemID) { $0.widgetStyle = nil; $0.verticalAlignment = .center } }
        }
    }

    @ViewBuilder private func groupInspector(_ group: OpenNotchGroup) -> some View {
        let b = groupBinding(group.id)
        Section("Group") {
            TextField("Name", text: b.name)
            Picker("Direction", selection: b.axis) { ForEach(OpenNotchAxis.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Alignment", selection: b.alignment) { ForEach(OpenNotchGroupAlignment.allCases) { Text($0.rawValue).tag($0) } }
            PreciseSlider(title: "Spacing", value: b.spacing, range: 0...48, step: 1, suffix: "pt")
        }
        Section("Group padding") { insetsEditor(b.padding) }
    }

    @ViewBuilder private func regionInspector(_ region: OpenNotchRegion) -> some View {
        let b = regionBinding(region.id)
        Section("Region") {
            Text(regionTitle(region)).font(.headline)
            Text("\(region.groups.count) group\(region.groups.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
            if opened.resolvedContentMode != .fixed {
                Picker("Order position", selection: b.placement) { ForEach(OpenNotchRegionPlacement.allCases) { Text($0.title).tag($0) } }
            }
        }
        if opened.resolvedContentMode == .fixed {
            Section("Frame") {
                Menu("Quick Size & Position") {
                    Button("Full Canvas") { setRegionFrame(region.id, .full) }
                    Button("Centered Large") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.10, y: 0.10, width: 0.80, height: 0.80)) }
                    Button("Compact Center") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.25, y: 0.25, width: 0.50, height: 0.50)) }
                    Divider()
                    Button("Left Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0, width: 0.50, height: 1)) }
                    Button("Right Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.50, y: 0, width: 0.50, height: 1)) }
                    Button("Top Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.50)) }
                    Button("Bottom Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0.50, width: 1, height: 0.50)) }
                    Divider()
                    Button("Top Left Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0, width: 0.50, height: 0.50)) }
                    Button("Top Right Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.50, y: 0, width: 0.50, height: 0.50)) }
                    Button("Bottom Left Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0.50, width: 0.50, height: 0.50)) }
                    Button("Bottom Right Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.50, y: 0.50, width: 0.50, height: 0.50)) }
                }
                PreciseSlider(title: "X", value: regionFramePercentBinding(region.id, \.x), range: 0...100, step: 1, suffix: "%")
                PreciseSlider(title: "Y", value: regionFramePercentBinding(region.id, \.y), range: 0...100, step: 1, suffix: "%")
                PreciseSlider(title: "Width", value: regionFramePercentBinding(region.id, \.width), range: 10...100, step: 1, suffix: "%")
                PreciseSlider(title: "Height", value: regionFramePercentBinding(region.id, \.height), range: 10...100, step: 1, suffix: "%")
                Text("Regions use normalized canvas coordinates, so the same layout scales with the opened notch size. Regions may also overlap intentionally.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("Region padding") { insetsEditor(b.padding) }
        Section("Region actions") {
            Button("Add Group") { addGroup(regionID: region.id) }
            if opened.regions.count > 1 {
                Menu("Merge Into…") {
                    ForEach(opened.regions.filter { $0.id != region.id }) { target in
                        Button(regionTitle(target)) { mergeRegion(region.id, into: target.id) }
                    }
                }
            }
            Button("Remove Region", role: .destructive) { removeRegion(region.id) }
        }
    }

    @ViewBuilder private var backgroundInspector: some View {
        let b = openBinding()
        let kind = b.wrappedValue.appearance.background ?? layout.appearance.background
        Section("Opened notch surface") {
            Picker("Background", selection: Binding(get: { kind }, set: { b.wrappedValue.appearance.background = $0 })) {
                ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            switch kind {
            case .glass:
                Text("Glass uses a live macOS material. Use Glass blur below to control how strongly it separates the workspace from the desktop.")
                    .font(.caption).foregroundStyle(.secondary)
            case .solid:
                ColorPicker("Color", selection: Binding(get: { (b.wrappedValue.appearance.solidColor ?? layout.appearance.solidColor ?? .white).color }, set: { b.wrappedValue.appearance.solidColor = WidgetColor($0) }), supportsOpacity: false)
            case .gradient:
                ColorPicker("Gradient start", selection: Binding(get: { (b.wrappedValue.appearance.gradientStartColor ?? layout.appearance.gradientStartColor ?? WidgetColor(red: 0.07, green: 0.09, blue: 0.14)).color }, set: { b.wrappedValue.appearance.gradientStartColor = WidgetColor($0) }), supportsOpacity: false)
                ColorPicker("Gradient end", selection: Binding(get: { (b.wrappedValue.appearance.gradientEndColor ?? layout.appearance.gradientEndColor ?? WidgetColor(red: 0.01, green: 0.02, blue: 0.04)).color }, set: { b.wrappedValue.appearance.gradientEndColor = WidgetColor($0) }), supportsOpacity: false)
            case .image, .video:
                TextField(kind == .video ? "Video path" : "Image path", text: b.appearance.assetPath)
            }
        }
        Section("Material") {
            if kind == .glass {
                optionalSlider("Glass blur", b.appearance.blur, fallback: layout.appearance.blur, range: 0...30, suffix: "pt")
            } else if kind == .image || kind == .video {
                optionalSlider("Blur", b.appearance.blur, fallback: layout.appearance.blur, range: 0...30, suffix: "pt")
            }
            if kind != .solid {
                optionalSlider("Saturation", b.appearance.saturation, fallback: layout.appearance.saturation, range: 0...2.5, step: 0.05, suffix: "×", decimals: 2)
                optionalSlider("Brightness", b.appearance.brightness, fallback: layout.appearance.brightness, range: -0.5...0.5, step: 0.02, decimals: 2)
                optionalSlider("Contrast", b.appearance.contrast, fallback: 1, range: 0.5...2, step: 0.05, suffix: "×", decimals: 2)
            }
            optionalSlider("Grain", b.appearance.grain, fallback: 0, range: 0...0.35, step: 0.01, decimals: 2)
            optionalSlider("Warmth", b.appearance.warmth, fallback: 0, range: -1...1, step: 0.05, decimals: 2)
            ColorPicker("Tint", selection: Binding(get: { (b.wrappedValue.appearance.tintColor ?? WidgetColor(red: 0.35, green: 0.55, blue: 1)).color }, set: { b.wrappedValue.appearance.tintColor = WidgetColor($0) }), supportsOpacity: false)
            optionalSlider("Tint opacity", b.appearance.tintOpacity, fallback: 0, range: 0...0.5, step: 0.01, decimals: 2)
        }
        Section("Edge & depth") {
            optionalSlider("Border width", b.appearance.borderWidth, fallback: 0, range: 0...6, step: 0.25, suffix: "pt", decimals: 2)
            if (b.wrappedValue.appearance.borderWidth ?? 0) > 0.001 {
                ColorPicker("Border", selection: Binding(get: { (b.wrappedValue.appearance.borderColor ?? .white).color }, set: { b.wrappedValue.appearance.borderColor = WidgetColor($0) }), supportsOpacity: false)
                optionalSlider("Border opacity", b.appearance.borderOpacity, fallback: 0.2, range: 0...1, step: 0.05, decimals: 2)
                optionalSlider("Inner highlight", b.appearance.innerHighlight, fallback: 0, range: 0...0.5, step: 0.02, decimals: 2)
            }
            optionalSlider("Shadow opacity", b.appearance.shadowOpacity, fallback: 0, range: 0...0.7, step: 0.02, decimals: 2)
            if (b.wrappedValue.appearance.shadowOpacity ?? 0) > 0.001 {
                optionalSlider("Shadow blur", b.appearance.shadowBlur, fallback: 12, range: 0...50, step: 1, suffix: "pt")
            }
            optionalSlider("Subtle glow", b.appearance.glow, fallback: 0, range: 0...0.5, step: 0.02, decimals: 2)
        }
    }

    @ViewBuilder private func styleInspector(_ optional: Binding<WidgetElementStyle?>, defaultVisible: Bool = true) -> some View {
        let b = Binding<WidgetElementStyle>(get: {
            if let value = optional.wrappedValue { return value }
            var value = WidgetElementStyle(); value.visible = defaultVisible; return value
        }, set: { optional.wrappedValue = $0 })
        Picker("Alignment", selection: Binding(get: { b.wrappedValue.alignment ?? .leading }, set: { b.wrappedValue.alignment = $0 })) { ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) } }
        Picker("Text alignment", selection: Binding(get: { b.wrappedValue.textAlignment ?? .leading }, set: { b.wrappedValue.textAlignment = $0 })) { ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) } }
        PreciseSlider(title: "Scale", value: b.fontScale, range: 0.55...2.5, step: 0.05, suffix: "×", decimals: 2)
        PreciseSlider(title: "Opacity", value: b.opacity, range: 0.15...1, step: 0.05, decimals: 2)
        PreciseSlider(title: "Internal padding", value: b.padding, range: 0...24, step: 1, suffix: "pt")
        optionalSlider("External spacing", b.externalSpacing, fallback: 0, range: 0...48, step: 1, suffix: "pt")
        optionalSlider("X offset", b.xOffset, fallback: 0, range: -100...100, step: 1, suffix: "pt")
        optionalSlider("Y offset", b.yOffset, fallback: 0, range: -100...100, step: 1, suffix: "pt")
        Picker("Font", selection: Binding(get: { b.wrappedValue.fontFamily ?? .system }, set: { b.wrappedValue.fontFamily = $0 })) { ForEach(WidgetFontFamily.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
        optionalSlider("Font size", b.fontSize, fallback: 14, range: 8...72, step: 1, suffix: "pt")
        Picker("Weight", selection: Binding(get: { b.wrappedValue.fontWeight ?? .regular }, set: { b.wrappedValue.fontWeight = $0 })) { ForEach(WidgetFontWeight.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
        Picker("Foreground", selection: b.foreground) { ForEach(WidgetElementForegroundStyle.allCases) { Text($0.rawValue).tag($0) } }
        if b.wrappedValue.foreground == .custom { ColorPicker("Foreground color", selection: Binding(get: { b.wrappedValue.customForeground.color }, set: { b.wrappedValue.customForeground = WidgetColor($0) }), supportsOpacity: false) }
        Picker("Background", selection: b.background) { ForEach(WidgetElementBackgroundStyle.allCases) { Text($0.rawValue).tag($0) } }
        if b.wrappedValue.background == .custom { ColorPicker("Background color", selection: Binding(get: { b.wrappedValue.backgroundColor.color }, set: { b.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false) }
        PreciseSlider(title: "Background opacity", value: b.backgroundOpacity, range: 0...1, step: 0.05, decimals: 2)
        PreciseSlider(title: "Corner radius", value: b.cornerRadius, range: 0...32, step: 1, suffix: "pt")
        optionalSlider("Border width", b.borderWidth, fallback: 0, range: 0...8, step: 0.25, suffix: "pt", decimals: 2)
        optionalSlider("Border opacity", b.borderOpacity, fallback: 0, range: 0...1, step: 0.05, decimals: 2)
        optionalSlider("Shadow blur", b.shadowBlur, fallback: 0, range: 0...48, step: 1, suffix: "pt")
        optionalSlider("Shadow opacity", b.shadowOpacity, fallback: 0, range: 0...0.8, step: 0.05, decimals: 2)
        optionalSlider("Tint opacity", b.tintOpacity, fallback: 1, range: 0...1, step: 0.05, decimals: 2)
        optionalSlider("Icon size", b.iconSize, fallback: 20, range: 6...96, step: 1, suffix: "pt")
        optionalSlider("Content density", b.contentDensity, fallback: 1, range: 0.5...1.5, step: 0.05, suffix: "×", decimals: 2)
    }

    private func columnWeightBinding(for placement: OpenNotchRegionPlacement) -> Binding<Double> {
        Binding(get: { opened.resolvedColumnWeights[placement.editorColumnIndex] }, set: { value in
            var next = opened; next.setColumnWeight(value, at: placement.editorColumnIndex); layout.openNotch = next
        })
    }
    private func rowWeightBinding(for placement: OpenNotchRegionPlacement) -> Binding<Double> {
        Binding(get: { opened.resolvedRowWeights[placement.editorRowIndex] }, set: { value in
            var next = opened; next.setRowWeight(value, at: placement.editorRowIndex); layout.openNotch = next
        })
    }
    private func resetTrackWeights(for placement: OpenNotchRegionPlacement) {
        var next = opened
        var columns = next.resolvedColumnWeights; columns[placement.editorColumnIndex] = 1; next.columnWeights = columns
        var rows = next.resolvedRowWeights; rows[placement.editorRowIndex] = 1; next.rowWeights = rows
        layout.openNotch = next
    }

    @ViewBuilder private func insetsEditor(_ b: Binding<OpenNotchInsets>) -> some View {
        PreciseSlider(title: "Top", value: b.top, range: 0...96, step: 1, suffix: "pt")
        PreciseSlider(title: "Leading", value: b.leading, range: 0...96, step: 1, suffix: "pt")
        PreciseSlider(title: "Bottom", value: b.bottom, range: 0...96, step: 1, suffix: "pt")
        PreciseSlider(title: "Trailing", value: b.trailing, range: 0...96, step: 1, suffix: "pt")
    }
    @ViewBuilder private func sizingSlider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View { PreciseSlider(title: title, value: value, range: range, step: 1, suffix: "pt") }
    @ViewBuilder private func optionalSlider(_ title: String, _ value: Binding<Double?>, fallback: Double, range: ClosedRange<Double>, step: Double = 1, suffix: String = "", decimals: Int = 0) -> some View {
        PreciseSlider(title: title, value: Binding(get: { value.wrappedValue ?? fallback }, set: { value.wrappedValue = $0 }), range: range, step: step, suffix: suffix, decimals: decimals)
    }
    @ViewBuilder private func interactionPicker(_ title: String, _ value: Binding<OpenNotchInteractionAction>) -> some View { Picker(title, selection: value) { ForEach(OpenNotchInteractionAction.allCases) { Text($0.rawValue).tag($0) } } }

    @ViewBuilder private func widgetPreviewBackground(_ item: OpenNotchItem) -> some View {
        if let module = item.module {
            let style = item.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished(for: module)
            let shape = RoundedRectangle(cornerRadius: min(10, style.cornerRadius), style: .continuous)
            switch style.resolvedCardBackgroundStyle {
            case .none: shape.fill(Color.white.opacity(0.035))
            case .solid: shape.fill(style.backgroundColor.color.opacity(max(0.06, style.backgroundOpacity)))
            case .gradient: shape.fill(LinearGradient(colors: [style.backgroundColor.color.opacity(max(0.08, style.backgroundOpacity)), style.resolvedBackgroundSecondaryColor.color.opacity(max(0.08, style.backgroundOpacity))], startPoint: .leading, endPoint: .trailing))
            case .glass: shape.fill(.ultraThinMaterial).opacity(max(0.18, style.backgroundOpacity))
            case .accent: shape.fill(style.accentColor.color.opacity(max(0.08, style.backgroundOpacity)))
            }
        } else {
            RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08))
        }
    }

    private func widgetStyleBinding(_ itemID: UUID, module: ModuleID) -> Binding<WidgetStyle> {
        Binding(
            get: { findItem(itemID)?.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished(for: module) },
            set: { replacement in mutateItem(itemID) { $0.widgetStyle = replacement } }
        )
    }

    private func widgetElementStyleBinding(_ itemID: UUID, module: ModuleID, descriptor: WidgetElementDescriptor) -> Binding<WidgetElementStyle?> {
        Binding(
            get: { findItem(itemID)?.widgetStyle?.elementStyles?[descriptor.key] },
            set: { replacement in
                var widget = findItem(itemID)?.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished(for: module)
                if widget.elementStyles == nil { widget.elementStyles = [:] }
                widget.elementStyles?[descriptor.key] = replacement
                mutateItem(itemID) { $0.widgetStyle = widget }
            }
        )
    }

    private func widgetChromeDouble(_ style: Binding<WidgetStyle>, _ keyPath: WritableKeyPath<WidgetChromeOptions, Double>) -> Binding<Double> {
        Binding(get: { style.wrappedValue.resolvedChrome[keyPath: keyPath] }, set: { value in
            var chrome = style.wrappedValue.resolvedChrome
            chrome[keyPath: keyPath] = value
            style.wrappedValue.chrome = chrome
        })
    }

    private func applyWidgetPreset(_ preset: WidgetVisualPreset, itemID: UUID, module: ModuleID) {
        var style = findItem(itemID)?.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished(for: module)
        var chrome = style.resolvedChrome
        switch preset {
        case .clean:
            style.cardBackgroundStyle = .none; style.outlineStyle = .none; style.backgroundOpacity = 0; chrome.shadowOpacity = 0
        case .glass:
            style.cardBackgroundStyle = .glass; style.backgroundOpacity = 0.42; style.outlineStyle = .solid; chrome.borderOpacity = 0.13; chrome.borderWidth = 1; chrome.shadowOpacity = 0.10
        case .filled:
            style.cardBackgroundStyle = .gradient; style.backgroundOpacity = 0.18; style.backgroundSecondaryColor = style.accentColor; style.outlineStyle = .none; chrome.shadowOpacity = 0.08
        case .outline:
            style.cardBackgroundStyle = .none; style.outlineStyle = .solid; chrome.borderColor = style.textColor; chrome.borderOpacity = 0.18; chrome.borderWidth = 1; chrome.shadowOpacity = 0
        case .floating:
            style.cardBackgroundStyle = .glass; style.backgroundOpacity = 0.34; style.outlineStyle = .glow; chrome.borderColor = style.accentColor; chrome.borderOpacity = 0.22; chrome.borderWidth = 1; chrome.shadowOpacity = 0.18; chrome.shadowRadius = 14
        case .minimal:
            style.cardBackgroundStyle = .none; style.outlineStyle = .none; style.showTitle = false; style.showHeaderIcon = false; style.padding = 6; chrome.shadowOpacity = 0
        }
        style.chrome = chrome
        mutateItem(itemID) { $0.widgetStyle = style }
    }

    private func materialize() { if layout.openNotch == nil { layout.materializeOpenNotchLayout() } }
    private func openBinding() -> Binding<OpenNotchLayout> { Binding(get: { layout.resolvedOpenNotchLayout }, set: { layout.openNotch = $0 }) }
    private func itemBinding(_ id: UUID) -> Binding<OpenNotchItem> { Binding(get: { findItem(id) ?? OpenNotchItem() }, set: { replacement in mutateItem(id) { $0 = replacement } }) }
    private func groupBinding(_ id: UUID) -> Binding<OpenNotchGroup> { Binding(get: { findGroup(id) ?? OpenNotchGroup() }, set: { replacement in mutateOpen { open in for ri in open.regions.indices { if let gi = open.regions[ri].groups.firstIndex(where: { $0.id == id }) { open.regions[ri].groups[gi] = replacement; return } } } }) }
    private func regionBinding(_ id: UUID) -> Binding<OpenNotchRegion> { Binding(get: { findRegion(id) ?? OpenNotchRegion() }, set: { replacement in mutateOpen { open in if let i = open.regions.firstIndex(where: { $0.id == id }) { open.regions[i] = replacement } } }) }
    private func ruleBinding(_ itemID: UUID, index: Int) -> Binding<OpenNotchVisibilityRule> { Binding(get: { findItem(itemID)?.visibilityRules.indices.contains(index) == true ? findItem(itemID)!.visibilityRules[index] : OpenNotchVisibilityRule() }, set: { replacement in mutateItem(itemID) { if $0.visibilityRules.indices.contains(index) { $0.visibilityRules[index] = replacement } } }) }
    private func findItem(_ id: UUID) -> OpenNotchItem? { opened.allItems.first { $0.id == id } }
    private func findGroup(_ id: UUID) -> OpenNotchGroup? { opened.regions.flatMap(\.groups).first { $0.id == id } }
    private func findRegion(_ id: UUID) -> OpenNotchRegion? { opened.regions.first { $0.id == id } }
    private func mutateOpen(_ body: (inout OpenNotchLayout) -> Void) { var value = opened; body(&value); value.preset = .custom; layout.openNotch = value }
    private func mutateItem(_ id: UUID, _ body: (inout OpenNotchItem) -> Void) { mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { if let ii = open.regions[ri].groups[gi].items.firstIndex(where: { $0.id == id }) { body(&open.regions[ri].groups[gi].items[ii]); return } } } } }
    private func removeRule(_ id: UUID, index: Int) { mutateItem(id) { if $0.visibilityRules.indices.contains(index) { $0.visibilityRules.remove(at: index) } } }

    private func ensureRegion(_ placement: OpenNotchRegionPlacement, select: Bool = false) {
        mutateOpen { open in
            if !open.regions.contains(where: { $0.placement == placement }) { open.regions.append(OpenNotchRegion(placement: placement, padding: OpenNotchInsets(), groups: [OpenNotchGroup(name: placement.title)])) }
        }
        if select, let r = opened.regions.first(where: { $0.placement == placement }) { selectedRegion = r.id }
    }

    private func addRegion() {
        guard opened.regions.count < 9 else { return }
        let id = UUID()
        mutateOpen { open in
            open.materializeRegionFrames()
            let used = Set(open.regions.map(\.placement))
            let placement = OpenNotchRegionPlacement.allCases.first(where: { !used.contains($0) }) ?? .middleCenter
            var region = OpenNotchRegion()
            region.id = id
            region.placement = placement
            region.padding = OpenNotchInsets()
            region.frame = .full
            region.groups = [OpenNotchGroup(name: "Region \(open.regions.count + 1)", axis: .horizontal)]
            open.regions.append(region)
            applyDefaultArrangement(to: &open)
        }
        selectedRegion = id; selectedGroup = nil; selectedItem = nil; backgroundMode = false
    }

    private func effectiveRegionFrame(_ id: UUID) -> OpenNotchRegionFrame {
        var value = opened
        value.materializeRegionFrames()
        return value.regions.first(where: { $0.id == id })?.frame ?? .full
    }

    private func regionFramePercentBinding(_ id: UUID, _ keyPath: WritableKeyPath<OpenNotchRegionFrame, Double>) -> Binding<Double> {
        Binding(
            get: { effectiveRegionFrame(id)[keyPath: keyPath] * 100 },
            set: { percent in
                mutateOpen { open in
                    open.materializeRegionFrames()
                    guard let index = open.regions.firstIndex(where: { $0.id == id }) else { return }
                    var frame = open.regions[index].frame ?? .full
                    frame[keyPath: keyPath] = percent / 100
                    open.regions[index].frame = frame.clamped()
                }
            }
        )
    }

    private func setRegionFrame(_ id: UUID, _ frame: OpenNotchRegionFrame) {
        mutateOpen { open in
            open.materializeRegionFrames()
            if let index = open.regions.firstIndex(where: { $0.id == id }) { open.regions[index].frame = frame.clamped() }
        }
    }

    private func applyRegionFrames(_ frames: [OpenNotchRegionFrame]) {
        mutateOpen { open in
            open.materializeRegionFrames()
            for index in open.regions.indices where index < frames.count { open.regions[index].frame = frames[index].clamped() }
        }
    }

    private func arrangeSingle(_ frame: OpenNotchRegionFrame) { guard opened.regions.count == 1 else { return }; applyRegionFrames([frame]) }
    private func arrangeSideBySide() { arrangeColumns() }
    private func arrangeStacked() { arrangeRows() }

    private func arrangeColumns() {
        let count = opened.regions.count
        guard count > 0 else { return }
        let gap = count > 1 ? 0.02 : 0
        let width = (1 - gap * Double(count - 1)) / Double(count)
        applyRegionFrames((0..<count).map { OpenNotchRegionFrame(x: Double($0) * (width + gap), y: 0, width: width, height: 1) })
    }

    private func arrangeRows() {
        let count = opened.regions.count
        guard count > 0 else { return }
        let gap = count > 1 ? 0.02 : 0
        let height = (1 - gap * Double(count - 1)) / Double(count)
        applyRegionFrames((0..<count).map { OpenNotchRegionFrame(x: 0, y: Double($0) * (height + gap), width: 1, height: height) })
    }

    private func arrangeGrid() {
        let count = opened.regions.count
        guard count > 0 else { return }
        let columns = max(1, Int(ceil(sqrt(Double(count)))))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let gap = 0.02
        let width = (1 - gap * Double(columns - 1)) / Double(columns)
        let height = (1 - gap * Double(rows - 1)) / Double(rows)
        applyRegionFrames((0..<count).map { index in
            let column = index % columns
            let row = index / columns
            return OpenNotchRegionFrame(x: Double(column) * (width + gap), y: Double(row) * (height + gap), width: width, height: height)
        })
    }

    private func applyDefaultArrangement(to open: inout OpenNotchLayout) {
        let count = open.regions.count
        guard count > 0 else { return }
        let frames: [OpenNotchRegionFrame]
        if count == 1 {
            frames = [.full]
        } else if count == 2 {
            frames = [OpenNotchRegionFrame(x: 0, y: 0, width: 0.49, height: 1), OpenNotchRegionFrame(x: 0.51, y: 0, width: 0.49, height: 1)]
        } else if count == 3 {
            frames = [OpenNotchRegionFrame(x: 0, y: 0, width: 0.32, height: 1), OpenNotchRegionFrame(x: 0.34, y: 0, width: 0.32, height: 1), OpenNotchRegionFrame(x: 0.68, y: 0, width: 0.32, height: 1)]
        } else {
            let columns = max(1, Int(ceil(sqrt(Double(count)))))
            let rows = max(1, Int(ceil(Double(count) / Double(columns))))
            let gap = 0.02
            let width = (1 - gap * Double(columns - 1)) / Double(columns)
            let height = (1 - gap * Double(rows - 1)) / Double(rows)
            frames = (0..<count).map { index in
                let column = index % columns; let row = index / columns
                return OpenNotchRegionFrame(x: Double(column) * (width + gap), y: Double(row) * (height + gap), width: width, height: height)
            }
        }
        for index in open.regions.indices where index < frames.count { open.regions[index].frame = frames[index] }
    }

    private func mergeRegion(_ sourceID: UUID, into targetID: UUID) {
        guard sourceID != targetID else { return }
        mutateOpen { open in
            open.materializeRegionFrames()
            guard let sourceIndex = open.regions.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = open.regions.firstIndex(where: { $0.id == targetID }) else { return }
            let source = open.regions[sourceIndex]
            let sourceFrame = source.frame ?? .full
            let targetFrame = open.regions[targetIndex].frame ?? .full
            open.regions[targetIndex].groups.append(contentsOf: source.groups)
            open.regions[targetIndex].frame = targetFrame.union(sourceFrame)
            open.regions.remove(at: sourceIndex)
        }
        selectedRegion = targetID; selectedGroup = nil; selectedItem = nil
    }

    private func removeRegion(_ id: UUID) {
        mutateOpen { open in open.regions.removeAll { $0.id == id } }
        if selectedRegion == id { selectedRegion = nil; selectedGroup = nil; selectedItem = nil }
    }

    private func defaultGroupID() -> UUID {
        if let selectedGroup, findGroup(selectedGroup) != nil { return selectedGroup }
        ensureRegion(.middleCenter)
        if let id = opened.regions.first(where: { $0.placement == .middleCenter })?.groups.first?.id { return id }
        let id = UUID(); mutateOpen { open in if let ri = open.regions.firstIndex(where: { $0.placement == .middleCenter }) { open.regions[ri].groups.append(OpenNotchGroup(id: id, name: "Main")) } }; return id
    }
    private func addModule(_ module: ModuleID) { var item = OpenNotchItem.moduleItem(module); let gid = defaultGroupID(); mutateOpen { open in append(item, to: gid, open: &open) }; layout.enabled.insert(module); selectedItem = item.id; selectedGroup = gid }
    private func addElement(_ element: OpenNotchElementKind) { let item = OpenNotchItem.elementItem(element); let gid = defaultGroupID(); mutateOpen { open in append(item, to: gid, open: &open) }; selectedItem = item.id; selectedGroup = gid }
    private func addGroup(regionID: UUID? = nil) { let rid = regionID ?? selectedRegion ?? { ensureRegion(.middleCenter); return opened.regions.first(where: { $0.placement == .middleCenter })?.id }()!; let group = OpenNotchGroup(name: "Group", axis: .horizontal); mutateOpen { open in if let ri = open.regions.firstIndex(where: { $0.id == rid }) { open.regions[ri].groups.append(group) } }; selectedGroup = group.id; selectedRegion = rid }
    private func append(_ item: OpenNotchItem, to groupID: UUID, open: inout OpenNotchLayout) { for ri in open.regions.indices { if let gi = open.regions[ri].groups.firstIndex(where: { $0.id == groupID }) { open.regions[ri].groups[gi].items.append(item); return } } }
    private func remove(_ id: UUID) { mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } } } }; selectedItem = nil }
    private func duplicate(_ id: UUID) { guard var copy = findItem(id) else { return }; copy.id = UUID(); let gid = selectedGroup ?? defaultGroupID(); mutateOpen { open in append(copy, to: gid, open: &open) }; selectedItem = copy.id }
    private func duplicateSelected() { if let selectedItem { duplicate(selectedItem) } }
    private func groupSelectedItem() { guard let id = selectedItem, let item = findItem(id) else { return }; let regionID = selectedRegion ?? opened.regions.first?.id; guard let regionID else { return }; let group = OpenNotchGroup(name: "Group", items: [item]); mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } }; if open.regions[ri].id == regionID { open.regions[ri].groups.append(group) } } }; selectedGroup = group.id }
    private func resize(_ id: UUID, translation: CGSize) { mutateItem(id) { item in item.sizing.mode = .flexible; item.sizing.preferredWidth = min(item.sizing.maximumWidth, max(item.sizing.minimumWidth, item.sizing.preferredWidth + translation.width * 0.08)); item.sizing.preferredHeight = min(item.sizing.maximumHeight, max(item.sizing.minimumHeight, item.sizing.preferredHeight + translation.height * 0.08)) } }
    private func applyPreset(_ preset: OpenNotchPreset) { guard preset != .custom else { mutateOpen { $0.preset = .custom }; return }; layout.applyOpenNotchPreset(preset); selectedItem = nil; selectedGroup = nil; selectedRegion = nil }

    private func acceptDrop(_ providers: [NSItemProvider], placement: OpenNotchRegionPlacement) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in guard let text = object as? String, let id = UUID(uuidString: text) else { return }; DispatchQueue.main.async { ensureRegion(placement); guard let gid = opened.regions.first(where: { $0.placement == placement })?.groups.first?.id else { return }; move(id, to: gid, before: nil) } }; return true
    }
    private func acceptDrop(_ providers: [NSItemProvider], regionID: UUID) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String, let id = UUID(uuidString: text) else { return }
            DispatchQueue.main.async {
                guard let region = opened.regions.first(where: { $0.id == regionID }) else { return }
                if let gid = region.groups.first?.id { move(id, to: gid, before: nil) }
                else { addGroup(regionID: regionID); if let gid = findRegion(regionID)?.groups.first?.id { move(id, to: gid, before: nil) } }
            }
        }
        return true
    }
    private func acceptDrop(_ providers: [NSItemProvider], groupID: UUID, before target: UUID? = nil) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in guard let text = object as? String, let id = UUID(uuidString: text) else { return }; DispatchQueue.main.async { move(id, to: groupID, before: target) } }; return true
    }
    private func move(_ id: UUID, to groupID: UUID, before target: UUID?) {
        guard let item = findItem(id) else { return }
        mutateOpen { open in
            for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } } }
            for ri in open.regions.indices { if let gi = open.regions[ri].groups.firstIndex(where: { $0.id == groupID }) { if let target, let index = open.regions[ri].groups[gi].items.firstIndex(where: { $0.id == target }) { open.regions[ri].groups[gi].items.insert(item, at: index) } else { open.regions[ri].groups[gi].items.append(item) }; return } }
        }
        selectedItem = id; selectedGroup = groupID
    }
}


private extension Binding {
    func withDefault<T>(_ fallback: T) -> Binding<T> where Value == T? {
        Binding<T>(get: { wrappedValue ?? fallback }, set: { wrappedValue = $0 })
    }
}
