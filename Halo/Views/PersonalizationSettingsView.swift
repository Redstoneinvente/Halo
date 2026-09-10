import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO

struct DailyWindowEditor: View {
    @Binding var window: DailyWindow
    var body: some View {
        timePicker("From", $window.startMinute)
        timePicker("Until", $window.endMinute)
        HStack {
            ForEach(1...7, id: \.self) { day in
                Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: Binding(
                    get: { window.weekdays.contains(day) },
                    set: { if $0 { window.weekdays.insert(day) } else { window.weekdays.remove(day) } }
                )).toggleStyle(.button)
            }
        }
    }
    private func timePicker(_ title: String, _ value: Binding<Int>) -> some View {
        HStack {
            Text(title).frame(width: 50, alignment: .leading)
            Picker("Hour", selection: Binding(get: { value.wrappedValue / 60 }, set: { value.wrappedValue = $0 * 60 + value.wrappedValue % 60 })) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            Picker("Minute", selection: Binding(get: { value.wrappedValue % 60 }, set: { value.wrappedValue = value.wrappedValue / 60 * 60 + $0 })) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
        }
    }
}
struct GrainSettingsView: View {
    @Binding var options: GrainOptions
    var body: some View {
        Toggle("Soft grain", isOn: $options.enabled)
        if options.enabled {
            Slider(value: $options.amount, in: 0...0.6) { Text("Grain amount") }
            Slider(value: $options.size, in: 0.5...3) { Text("Grain size") }
            Slider(value: $options.warmth, in: 0...1) { Text("Warmth") }
        }
    }
}
@MainActor struct ScheduleSettingsView: View {
    @ObservedObject var workspace: WorkspaceStore
    private var profiles: Binding<[ProfileSchedule]> {
        Binding(get: { workspace.settings.profileSchedules ?? [] }, set: { workspace.settings.profileSchedules = $0 })
    }
    private var backgrounds: Binding<[TimedBackground]> {
        Binding(get: { workspace.settings.layout.appearance.backgroundSchedule ?? [] }, set: { workspace.settings.layout.appearance.backgroundSchedule = $0 })
    }
    var body: some View {
        Text("Schedules use your Mac's local time and time zone. The first matching enabled row wins. Equal start/end means all day. Overnight ranges belong to the day they start.").font(.caption)
        Section("Timed profiles") {
            if let id = workspace.scheduledProfileID, let profile = workspace.settings.profiles.first(where: { $0.id == id }) {
                Text("Active scheduled profile: \(profile.name)")
            } else { Text("Using your normal layout or a manually selected profile.") }
            ForEach(profiles) { entry in
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enabled", isOn: entry.enabled)
                    Picker("Profile", selection: entry.profileID) {
                        ForEach(workspace.settings.profiles) { Text($0.name).tag($0.id) }
                    }
                    DailyWindowEditor(window: entry.window)
                    HStack {
                        Button("Move earlier") { moveProfile(entry.wrappedValue.id) }
                        Button("Remove") { profiles.wrappedValue.removeAll { $0.id == entry.wrappedValue.id } }
                    }
                }
            }
            Button("Add profile schedule") {
                if let first = workspace.settings.profiles.first { profiles.wrappedValue.append(ProfileSchedule(profileID: first.id)) }
            }.disabled(workspace.settings.profiles.isEmpty)
            Button("Resume scheduled profiles now") { workspace.resumeSchedules() }
            Text("Your normal layout returns when the scheduled range ends. Applying a profile manually pauses that scheduled occurrence until the next range/day, or until you press Resume. Display-specific profiles take precedence on their displays.").font(.caption)
        }
        Section("Timed backgrounds for the current base layout") {
            ForEach(backgrounds) { entry in
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enabled", isOn: entry.enabled)
                    DailyWindowEditor(window: entry.window)
                    Picker("Background", selection: entry.kind) {
                        ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    if entry.wrappedValue.kind == .image || entry.wrappedValue.kind == .video {
                        Button("Choose background file…") { chooseBackground(entry) }
                        Text(entry.wrappedValue.assetPath.isEmpty ? "No file selected" : URL(fileURLWithPath: entry.wrappedValue.assetPath).lastPathComponent).font(.caption)
                    }
                    if entry.wrappedValue.kind != .glass { Slider(value: entry.blur, in: 0...20) { Text("Diffusion / blur") } }
                    GrainSettingsView(options: entry.grain)
                    HStack {
                        Button("Move earlier") { moveBackground(entry.wrappedValue.id) }
                        Button("Remove") { backgrounds.wrappedValue.removeAll { $0.id == entry.wrappedValue.id } }
                    }
                }
            }
            Button("Add background schedule") { backgrounds.wrappedValue.append(TimedBackground()) }
            Text("Outside these ranges, your normal background returns. Save this layout as a profile to include its background schedules. Images and videos are referenced on this Mac.").font(.caption)
        }
    }
    private func moveProfile(_ id: UUID) {
        var items = profiles.wrappedValue
        if let index = items.firstIndex(where: { $0.id == id }), index > 0 { items.swapAt(index, index - 1); profiles.wrappedValue = items }
    }
    private func moveBackground(_ id: UUID) {
        var items = backgrounds.wrappedValue
        if let index = items.firstIndex(where: { $0.id == id }), index > 0 { items.swapAt(index, index - 1); backgrounds.wrappedValue = items }
    }
    private func chooseBackground(_ entry: Binding<TimedBackground>) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        entry.wrappedValue.assetPath = url.path
        entry.wrappedValue.kind = ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased()) ? .video : .image
    }
}

@MainActor struct SideDecorationSettingsView: View {
    let title: String
    @Binding var options: SideDecoration
    @State private var error: String?
    var body: some View {
        Section(title) {
            Picker("Display", selection: $options.visibility) {
                Text("Disabled").tag(DecorationVisibility.disabled)
                Text("Always").tag(DecorationVisibility.always)
                Text("Only while music plays").tag(DecorationVisibility.playing)
            }
            if options.visibility != .disabled {
                Picker("Content", selection: $options.kind) {
                    Text("Icon").tag(DecorationKind.symbol)
                    Text("Image / GIF").tag(DecorationKind.image)
                }
                if options.kind == .symbol {
                    Picker("Icon", selection: $options.symbol) {
                        ForEach(Array(Set([options.symbol, "sparkles", "heart.fill", "moon.stars.fill", "sun.max.fill", "music.note", "headphones", "bolt.fill", "flame.fill", "leaf.fill", "gamecontroller.fill"])).sorted(), id: \.self) {
                            Label($0, systemImage: $0).tag($0)
                        }
                    }
                    TextField("SF Symbol name", text: $options.symbol)
                    ColorPicker("Icon color", selection: Binding(get: { options.color.color }, set: { options.color = WidgetColor($0) }), supportsOpacity: false)
                } else {
                    Button("Choose image or GIF…") { chooseFile() }
                    Text(options.assetPath.isEmpty ? "No file selected" : URL(fileURLWithPath: options.assetPath).lastPathComponent).font(.caption)
                    if let error { Text(error).foregroundStyle(.orange) }
                }
                Slider(value: $options.size, in: 12...64) { Text("Size") }
                SideDecorationView(options: options, playing: true, lowPower: false)
                Text("Shown beside this side's content while the notch is closed. Images scale to fit the closed height. GIFs: up to 10 MB / 120 frames, cached at 128 px. Reduce Motion and Low Power Mode show a still frame.").font(.caption)
            }
        }
    }
    private func chooseFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 10_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) <= 120 else {
            error = "Choose an image under 10 MB, with at most 120 frames."; return
        }
        error = nil; options.assetPath = url.path
    }
}
