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
                colorPicker(style.wrappedValue.resolvedCardBackgroundStyle == .accent ? "Tint base" : "Background", style.backgroundColor)
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
                PreciseSlider(title: "Visible events", value: Binding(get: { Double(content.wrappedValue.maxItems) }, set: { content.wrappedValue.maxItems = Int($0) }), range: 1...30, step: 1)
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