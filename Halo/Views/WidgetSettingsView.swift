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
        Binding(get: { options.wrappedValue.visualizer ?? VisualizerOptions() }, set: { options.wrappedValue.visualizer = $0 })
    }
    private var expansion: Binding<ClosedExpansionOptions> {
        Binding(get: { options.wrappedValue.expansion ?? ClosedExpansionOptions() }, set: { options.wrappedValue.expansion = $0 })
    }
    private var mediaOptions: Binding<ClosedMediaOptions> {
        Binding(get: { options.wrappedValue.mediaOptions ?? ClosedMediaOptions() }, set: { options.wrappedValue.mediaOptions = $0 })
    }
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
    private var reactive: Binding<ReactiveBackgroundOptions> {
        Binding(get: { options.wrappedValue.reactiveBackground ?? ReactiveBackgroundOptions() }, set: { options.wrappedValue.reactiveBackground = $0 })
    }
    private var power: Binding<PowerReactionOptions> {
        Binding(get: { options.wrappedValue.powerReaction ?? PowerReactionOptions() }, set: { options.wrappedValue.powerReaction = $0 })
    }
    var body: some View {
        Section("Content fit") {
            Toggle("Auto-size to fit content", isOn: Binding(get: { options.wrappedValue.autoFitContent ?? true }, set: { options.wrappedValue.autoFitContent = $0 }))
            PreciseSlider(title: "Horizontal padding", value: Binding(get: { options.wrappedValue.contentPaddingX }, set: { options.wrappedValue.horizontalPadding = $0 }), range: 0...24, step: 1, suffix: "pt")
            PreciseSlider(title: "Vertical padding", value: Binding(get: { options.wrappedValue.contentPaddingY }, set: { options.wrappedValue.verticalPadding = $0 }), range: 0...12, step: 1, suffix: "pt")
            PreciseSlider(title: "Margin from camera", value: Binding(get: { options.wrappedValue.contentSideMargin }, set: { options.wrappedValue.sideMargin = $0 }), range: 0...48, step: 1, suffix: "pt")
            PreciseSlider(title: "Margin from outer edge", value: Binding(get: { options.wrappedValue.contentOuterMargin }, set: { options.wrappedValue.outerMargin = $0 }), range: 0...48, step: 1, suffix: "pt")
            Text("The Appearance closed-width slider is the guaranteed idle/base width. Auto-size can grow beyond it, then returns to it when transient content disappears.").font(.caption)
        }
        Section("Automatic width") {
            Toggle("Widen for music and live activity", isOn: expansion.enabled)
            PreciseSlider(title: "Active width", value: expansion.width, range: 120...640, step: 1, suffix: "pt")
            Text("Music, pinned files, timers, power events and live activities can widen the closed notch. Extra width is assigned only to the side that needs it.").font(.caption)
        }
        SideDecorationSettingsView(title: "Left icon / GIF", options: Binding(
            get: { options.wrappedValue.leftDecoration ?? SideDecoration() }, set: { options.wrappedValue.leftDecoration = $0 }
        ))
        SideDecorationSettingsView(title: "Right icon / GIF", options: Binding(
            get: { options.wrappedValue.rightDecoration ?? SideDecoration() }, set: { options.wrappedValue.rightDecoration = $0 }
        ))
        Section("Content") {
            itemPicker("Left slot", options.left)
            itemPicker("Right slot", options.right)
            PreciseSlider(title: "Text size", value: options.fontSize, range: 8...24, step: 1, suffix: "pt")
            ColorPicker("Color", selection: Binding(get: { options.wrappedValue.color.color }, set: { options.wrappedValue.color = WidgetColor($0) }), supportsOpacity: false)
            Text("Active Halo activities have priority: they use an Activity slot, an inactive side, or temporarily replace the right slot if both sides are occupied.").font(.caption)
        }
        Section("Closed media text") {
            Picker("Text", selection: mediaOptions.textMode) {
                Text("Track title").tag(MediaTextMode.title)
                Text("Artist").tag(MediaTextMode.artist)
                Text("Title + artist").tag(MediaTextMode.titleArtist)
                Text("Lyrics").tag(MediaTextMode.lyrics)
            }
            Picker("Overflow", selection: mediaOptions.overflow) {
                Text("Truncate").tag(MediaOverflowMode.truncate)
                Text("Scale to fit").tag(MediaOverflowMode.scale)
                Text("Marquee").tag(MediaOverflowMode.marquee)
            }
            if mediaOptions.wrappedValue.textMode == .lyrics {
                Picker("Lyric display", selection: Binding(
                    get: { mediaOptions.wrappedValue.resolvedLyricDisplay },
                    set: { mediaOptions.wrappedValue.lyricDisplay = $0 }
                )) {
                    Text("Current line").tag(LyricDisplayMode.line)
                    Text("Focus phrase").tag(LyricDisplayMode.focus)
                    Text("Current word").tag(LyricDisplayMode.word)
                }
            }
            if mediaOptions.wrappedValue.textMode != .lyrics || mediaOptions.wrappedValue.resolvedLyricDisplay != .word {
                Picker("Lines", selection: mediaOptions.lines) {
                    Text("1 line").tag(1)
                    Text("2 lines").tag(2)
                }
            }
            if mediaOptions.wrappedValue.overflow == .marquee {
                PreciseSlider(title: "Marquee speed", value: mediaOptions.marqueeSpeed, range: 8...120, step: 1, suffix: "pt/s")
            }
            Toggle("Show playback icon", isOn: mediaOptions.showPlaybackIcon)
            if mediaOptions.wrappedValue.textMode == .lyrics {
                Toggle("Use online lyrics fallback", isOn: Binding(
                    get: { mediaOptions.wrappedValue.usesOnlineLyrics },
                    set: { mediaOptions.wrappedValue.onlineLyrics = $0 }
                ))
                Text("Halo prefers timestamped synced lyrics when online fallback is enabled, then follows the current player position. Current-word and Focus Phrase estimate word timing inside each timestamped line when word-level timing is unavailable.").font(.caption)
            }
        }
        Section("Artwork") {
            Toggle("Show artwork", isOn: artwork.enabled)
            if artwork.wrappedValue.enabled {
                Picker("Style", selection: artwork.mode) {
                    Text("Album cover").tag(MediaArtworkMode.cover)
                    Text("Notch background").tag(MediaArtworkMode.background)
                    Text("Rotating vinyl").tag(MediaArtworkMode.vinyl)
                }
                Picker("Side", selection: artwork.side) {
                    Text("Automatic").tag(ClosedNotchSideChoice.automatic)
                    Text("Left").tag(ClosedNotchSideChoice.left)
                    Text("Right").tag(ClosedNotchSideChoice.right)
                }.disabled(artwork.wrappedValue.mode == .background)
                if artwork.wrappedValue.mode != .background {
                    PreciseSlider(title: "Artwork size", value: artwork.size, range: 14...72, step: 1, suffix: "pt")
                    PreciseSlider(title: "Artwork padding", value: artwork.padding, range: 0...24, step: 1, suffix: "pt")
                    PreciseSlider(title: "Artwork margin", value: artwork.margin, range: 0...48, step: 1, suffix: "pt")
                }
                if artwork.wrappedValue.mode == .vinyl {
                    PreciseSlider(title: "Vinyl speed", value: artwork.vinylRPM, range: 1...45, step: 1, suffix: "rpm")
                }
                if artwork.wrappedValue.mode == .background {
                    PreciseSlider(title: "Artwork background opacity", value: artwork.backgroundOpacity, range: 0...1, step: 0.01, decimals: 2)
                }
                Text("Artwork is independent from the Media text slot. It can stay on either side while the text slot is elsewhere, or be used only as the closed-notch background.").font(.caption)
            }
        }
        Section("Album colors") {
            Toggle("Color notch background from album", isOn: Binding(
                get: { options.wrappedValue.albumBackgroundColor ?? false }, set: { options.wrappedValue.albumBackgroundColor = $0 }
            ))
            Toggle("Color closed-notch text from album", isOn: Binding(
                get: { options.wrappedValue.albumTextColor ?? false }, set: { options.wrappedValue.albumTextColor = $0 }
            ))
        }
        Section("Reactive background") {
            Toggle("React while music plays", isOn: reactive.enabled)
            Picker("Reaction profile", selection: reactive.driver) {
                Text("Pulse").tag(ReactiveDriver.pulse)
                Text("Bass-like").tag(ReactiveDriver.bass)
                Text("Mid-like").tag(ReactiveDriver.mids)
                Text("Treble-like").tag(ReactiveDriver.treble)
                Text("Spectrum-like").tag(ReactiveDriver.spectrum)
            }.disabled(!reactive.wrappedValue.enabled)
            if reactive.wrappedValue.enabled {
                PreciseSlider(title: "Reaction speed", value: reactive.speed, range: 0.2...3, step: 0.05, decimals: 2)
                PreciseSlider(title: "Master intensity", value: reactive.intensity, range: 0...1, step: 0.05, decimals: 2)
                PreciseSlider(title: "Affect brightness", value: reactive.brightness, range: 0...0.8, step: 0.01, decimals: 2)
                PreciseSlider(title: "Affect saturation", value: reactive.saturation, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Affect scale", value: reactive.scale, range: 0...0.12, step: 0.005, decimals: 3)
                PreciseSlider(title: "Affect hue", value: reactive.hueShift, range: 0...1, step: 0.01, decimals: 2)
                PreciseSlider(title: "Affect blur", value: reactive.blur, range: 0...12, step: 0.25, suffix: "pt", decimals: 2)
                PreciseSlider(title: "Affect grain", value: reactive.grain, range: 0...0.6, step: 0.01, decimals: 2)
            }
            Text("Reactive mode now remains visibly active even without album-color mode. These are still lightweight playback-driven profiles rather than true FFT frequency analysis.").font(.caption)
        }
        Section("Power events") {
            Toggle("Enable power events", isOn: Binding(
                get: { power.wrappedValue.isEnabled }, set: { power.wrappedValue.enabled = $0 }
            ))
            if power.wrappedValue.isEnabled {
                Picker("Side", selection: power.side) {
                    Text("Automatic").tag(ClosedNotchSideChoice.automatic)
                    Text("Left").tag(ClosedNotchSideChoice.left)
                    Text("Right").tag(ClosedNotchSideChoice.right)
                }
                Picker("Charging", selection: power.charging) { powerStyles() }
                Picker("Low battery", selection: power.low) { powerStyles() }
                Picker("Charged", selection: power.charged) { powerStyles() }
                PreciseSlider(title: "Low battery threshold", value: Binding(get: { Double(power.wrappedValue.lowThreshold) }, set: { power.wrappedValue.lowThreshold = Int($0) }), range: 5...50, step: 1, suffix: "%")
                Toggle("Expand for power events", isOn: power.expandForEvent)
                if power.wrappedValue.expandForEvent {
                    PreciseSlider(title: "Power event width", value: power.eventWidth, range: 48...240, step: 1, suffix: "pt")
                }
                Toggle("Dynamic color by battery level", isOn: Binding(
                    get: { power.wrappedValue.usesDynamicColor }, set: { power.wrappedValue.dynamicColor = $0 }
                ))
                if power.wrappedValue.usesDynamicColor {
                    ColorPicker("Low battery color", selection: Binding(get: { power.wrappedValue.resolvedLowColor.color }, set: { power.wrappedValue.lowColor = WidgetColor($0) }), supportsOpacity: false)
                    ColorPicker("Mid battery color", selection: Binding(get: { power.wrappedValue.resolvedMidColor.color }, set: { power.wrappedValue.midColor = WidgetColor($0) }), supportsOpacity: false)
                    ColorPicker("High battery color", selection: Binding(get: { power.wrappedValue.resolvedHighColor.color }, set: { power.wrappedValue.highColor = WidgetColor($0) }), supportsOpacity: false)
                } else {
                    ColorPicker("Power event color", selection: Binding(get: { power.wrappedValue.color.color }, set: { power.wrappedValue.color = WidgetColor($0) }), supportsOpacity: false)
                }
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
        Picker(title, selection: value) { ForEach(ClosedNotchItem.allCases) { Text($0.rawValue.capitalized).tag($0) } }
    }
    @ViewBuilder private func powerStyles() -> some View {
        Text("Off").tag(PowerReactionStyle.off)
        Text("Icon").tag(PowerReactionStyle.icon)
        Text("Percentage").tag(PowerReactionStyle.percent)
        Text("Icon + percentage").tag(PowerReactionStyle.iconPercent)
        Text("Label").tag(PowerReactionStyle.label)
    }
}
