import SwiftUI
import AppKit

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
            Slider(value: style.fontSize, in: 10...48, step: 1) { Text("Text size · \(Int(style.wrappedValue.fontSize)) pt") }
            colorPicker("Text", style.textColor)
            colorPicker("Accent", style.accentColor)
            Toggle("Show title", isOn: style.showTitle)
        }
        Section("Card") {
            colorPicker("Background", style.backgroundColor)
            Slider(value: style.backgroundOpacity, in: 0...1) { Text("Background opacity") }
            Slider(value: style.padding, in: 0...32) { Text("Padding") }
            Slider(value: style.cornerRadius, in: 0...40) { Text("Corner radius") }
            Toggle("Fill available width", isOn: Binding(get: { style.wrappedValue.width == 0 }, set: { style.wrappedValue.width = $0 ? 0 : 280 }))
            if style.wrappedValue.width > 0 {
                Slider(value: style.width, in: 120...640, step: 1) { Text("Maximum width · \(Int(style.wrappedValue.width)) pt") }
            }
            Slider(value: style.minimumHeight, in: 0...400, step: 1) { Text("Minimum height · \(Int(style.wrappedValue.minimumHeight)) pt") }
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
            Slider(value: Binding(get: { options.wrappedValue.contentPaddingX }, set: { options.wrappedValue.horizontalPadding = $0 }), in: 0...24) { Text("Horizontal padding") }
            Slider(value: Binding(get: { options.wrappedValue.contentPaddingY }, set: { options.wrappedValue.verticalPadding = $0 }), in: 0...12) { Text("Vertical padding") }
            Text("Auto-size treats your configured closed width as a minimum and reserves camera space, up to 640 pt or the display width. Text and artwork fit the closed height; long text truncates when space runs out.").font(.caption)
        }
        Section("Automatic width") {
            Toggle("Widen for music and live activity", isOn: expansion.enabled)
            Slider(value: expansion.width, in: 120...640, step: 1) { Text("Active width · \(Int(expansion.wrappedValue.width)) pt") }
            Text("Music playback, pinned files, screen capture/OCR, a running timer or stopwatch, and live activities widen the closed notch without opening the dashboard. Completed activities stay visible for eight seconds. Idle width and height remain as set in Appearance.").font(.caption)
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
            Slider(value: options.fontSize, in: 8...24, step: 1) { Text("Text size · \(Int(options.wrappedValue.fontSize)) pt") }
            ColorPicker("Color", selection: Binding(get: { options.wrappedValue.color.color }, set: { options.wrappedValue.color = WidgetColor($0) }), supportsOpacity: false)
            Text("Increase closed width in Appearance to fit both slots. Space behind the camera is reserved. A tiny notch shows a status dot instead.").font(.caption)
        }
        Section("Music animation") {
            // Binding.animation(_:) shadows the model's animation property.
            Picker("Style", selection: Binding<PlaybackAnimation>(
                get: { options.wrappedValue.animation },
                set: { options.wrappedValue.animation = $0 }
            )) {
                ForEach(PlaybackAnimation.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Animate while music plays", isOn: options.animate)
            Toggle("Use colors from music artwork", isOn: visualizer.dynamicColors)
            Slider(value: visualizer.speed, in: 0.25...2) { Text("Animation speed") }
            Slider(value: visualizer.intensity, in: 0.1...1) { Text("Motion intensity") }
            Slider(value: visualizer.width, in: 32...160) { Text("Visualizer width") }
            Slider(value: visualizer.height, in: 8...48) { Text("Visualizer height") }
            PlaybackVisualizer(kind: options.wrappedValue.animation, playing: true, enabled: options.wrappedValue.animate,
                               options: visualizer.wrappedValue, palette: media.artworkColors, fallback: options.wrappedValue.color.color)
                .padding(12).background(.black, in: RoundedRectangle(cornerRadius: 12))
            Text("Artwork colors apply to the visualizer. Spotify artwork is downloaded from its artwork URL when enabled; Apple Music artwork comes from the player. Missing artwork uses your selected color. Increase closed height in Appearance for taller visualizers.").font(.caption)
            Button("Retry player detection") { media.retryDetection(preferred: app) }.disabled(media.busy)
            Text(media.title)
            if let error = media.error { Text(error).foregroundStyle(.orange) }
            Text("Halo automatically detects Apple Music and Spotify. Playback notifications are backed by a two-second check. The visualizer is a playback animation, not an audio waveform. It stops when paused and respects Reduce Motion and Low Power Mode.").font(.caption)
        }
        Button("Reset closed content") { layout.closedNotch = ClosedNotchOptions() }
    }
    private func itemPicker(_ title: String, _ value: Binding<ClosedNotchItem>) -> some View {
        Picker(title, selection: value) {
            ForEach(ClosedNotchItem.allCases) { Text($0.rawValue.capitalized).tag($0) }
        }
    }
}
