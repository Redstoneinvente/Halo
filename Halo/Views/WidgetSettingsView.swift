import SwiftUI
import AppKit

struct WidgetSettingsView: View {
    @Binding var layout: WorkspaceLayout
    @State private var selected: ModuleID = .clock
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
                Picker("Installed font", selection: style.customFont) {
                    ForEach(Array(Set(installedFonts + [style.wrappedValue.customFont])).sorted(), id: \.self) { Text($0).tag($0) }
                }.onAppear { if installedFonts.isEmpty { installedFonts = NSFontManager.shared.availableFontFamilies } }
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
                Picker("Time zone", selection: style.clock.timeZone) {
                    Text("System time zone").tag("")
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                }
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
    private var expansion: Binding<ClosedExpansionOptions> {
        Binding(get: { options.wrappedValue.expansion ?? ClosedExpansionOptions() },
                set: { options.wrappedValue.expansion = $0 })
    }
    var body: some View {
        Section("Automatic width") {
            Toggle("Widen for music and live activity", isOn: expansion.enabled)
            Slider(value: expansion.width, in: 120...640, step: 1) { Text("Active width · \(Int(expansion.wrappedValue.width)) pt") }
            Text("Music playback, a running timer or stopwatch, and live activities widen the closed notch without opening the dashboard. Completed activities stay visible for eight seconds. Idle width and height remain as set in Appearance.").font(.caption)
        }
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
            Button("Connect selected music player") { media.perform("refresh", app: app) }.disabled(media.busy)
            Text(media.title)
            if let error = media.error { Text(error).foregroundStyle(.orange) }
            Text("Select Apple Music or Spotify in Media & Files. After connecting, Halo checks playback every two seconds. The visualizer is a playback animation, not an audio waveform. It stops when paused and respects Reduce Motion and Low Power Mode.").font(.caption)
        }
        Button("Reset closed content") { layout.closedNotch = ClosedNotchOptions() }
    }
    private func itemPicker(_ title: String, _ value: Binding<ClosedNotchItem>) -> some View {
        Picker(title, selection: value) {
            ForEach(ClosedNotchItem.allCases) { Text($0.rawValue.capitalized).tag($0) }
        }
    }
}
