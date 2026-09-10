import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var body: some View { WorkspaceSettingsView(store: store, workspace: store.workspace) }
}
@MainActor struct WorkspaceSettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @AppStorage("onboarded") private var onboarded = false
    @State private var section: String? = "General"
    @State private var search = ""
    @State private var profileName = "My profile"
    @State private var renamingProfile: UUID?
    @State private var renamedProfile = ""
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    private let sections = ["General", "Appearance", "Modules", "Widgets", "Closed notch", "Context notch interface", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "Advanced"]
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 44, height: 44).accessibilityLabel("Halo app icon")
                    VStack(alignment: .leading) {
                        Text("Halo").font(.headline)
                        Text("Make it yours").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(16)
                TextField("Find a section", text: $search).textFieldStyle(.roundedBorder).padding(12)
                List(selection: $section) {
                    ForEach(sections.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { Label($0, systemImage: sectionIcon($0)).padding(.vertical, 5).tag($0) }
                }.listStyle(.sidebar)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Link(destination: URL(string: "https://halo.redstoneinvente.com")!) {
                        Label("Halo website", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://buymeacoffee.com/redstoneinvente")!) {
                        Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                    }
                }.font(.callout).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(width: 220)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: sectionIcon(section ?? "General"))
                        .font(.title2).foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section ?? "General").font(.title2.bold())
                        Text("Changes are saved automatically").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
                Divider()
                Form { content }.formStyle(.grouped).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.frame(minWidth: 700, minHeight: 560)
        .onDisappear { GeometryPreview.update(expanded: false, editing: false) }
        .alert("Halo", isPresented: Binding(get: { store.error != nil || workspace.error != nil }, set: { if !$0 { store.error = nil; workspace.error = nil } })) {
            Button("OK") { store.error = nil; workspace.error = nil }
        } message: { Text(store.error ?? workspace.error ?? "") }
        .alert("Rename profile", isPresented: Binding(get: { renamingProfile != nil }, set: { if !$0 { renamingProfile = nil } })) {
            TextField("Name", text: $renamedProfile)
            Button("Save") { if let id = renamingProfile { workspace.renameProfile(id, to: renamedProfile) }; renamingProfile = nil }
            Button("Cancel", role: .cancel) { renamingProfile = nil }
        }
    }
    private func sectionIcon(_ name: String) -> String {
        switch name {
        case "General": return "gearshape"
        case "Appearance": return "paintpalette"
        case "Modules": return "square.grid.2x2"
        case "Widgets": return "slider.horizontal.3"
        case "Context notch interface": return "rectangle.stack"
        case "Closed notch": return "rectangle.topthird.inset.filled"
        case "Media & Files": return "play.rectangle"
        case "Profiles": return "person.crop.rectangle.stack"
        case "Schedules": return "calendar.badge.clock"
        case "Automation": return "bolt"
        case "Displays": return "display.2"
        case "Plugins": return "puzzlepiece.extension"
        case "Privacy": return "hand.raised"
        default: return "wrench.and.screwdriver"
        }
    }
    @ViewBuilder private var content: some View {
        switch section ?? "General" {
        case "General":
            Section("Welcome to Halo") {
                Text("Your workspace, within reach.").font(.title2.bold())
                Text("Hover to expand, click the top strip to toggle, right-click for profiles, and drag files onto the surface. Option–Command–Space toggles Halo by default.")
                Text("Detected \(NSScreen.screens.count) display(s); \(NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }.count) with a notch.")
                ForEach(NSScreen.screens, id: \.localizedName) { screen in
                    Text("\(screen.localizedName): animation target up to \(FrameRatePolicy.target(maximum: screen.maximumFramesPerSecond, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)) fps").font(.caption)
                }
                if !onboarded { Button("Finish setup and show Halo") { onboarded = true; NotificationCenter.default.post(name: .init("HaloToggle"), object: nil) } }
            }
            Toggle("Expand on hover", isOn: $store.configuration.hoverToExpand)
            Toggle("Show on all displays", isOn: $store.configuration.allDisplays)
            Toggle("Launch at login", isOn: $loginEnabled).onChange(of: loginEnabled) { value in
                do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                catch { store.error = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
            }
            Section("Global shortcut") {
                Toggle("Enable global shortcut", isOn: $workspace.settings.hotkeyEnabled)
                Picker("Key", selection: $workspace.settings.hotkeyCode) { Text("Space").tag(UInt32(49)); Text("H").tag(UInt32(4)); Text("D").tag(UInt32(2)) }
                Picker("Modifiers", selection: $workspace.settings.hotkeyModifiers) {
                    Text("Option + Command").tag(UInt32(2304)); Text("Control + Option").tag(UInt32(6144)); Text("Control + Shift").tag(UInt32(4608))
                }
            }
        case "Schedules":
            ScheduleSettingsView(workspace: workspace)
        case "Appearance":
            Section("Expanded dashboard") {
                Toggle("Horizontal widget layout", isOn: Binding(
                    get: { workspace.settings.layout.horizontalWidgets ?? false },
                    set: { workspace.settings.layout.horizontalWidgets = $0 }
                ))
                if workspace.settings.layout.horizontalWidgets ?? false {
                    Picker("Navigation", selection: Binding(get: { workspace.settings.layout.horizontalPages ?? false }, set: { workspace.settings.layout.horizontalPages = $0 })) {
                        Text("Scroll").tag(false); Text("Pages").tag(true)
                    }.pickerStyle(.segmented)
                    Slider(value: Binding(get: { workspace.settings.layout.horizontalHeight ?? 260 }, set: { workspace.settings.layout.horizontalHeight = $0 }), in: 200...500) { Text("Horizontal dashboard height") }
                }
                Text("Arrange widgets in a sideways-scrolling row. Turn off for the original vertical layout. Widget order and customizations apply to both.").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Surface", selection: $store.configuration.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
            Slider(value: $store.configuration.theme.width, in: 340...640, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Expanded width") }
            Slider(value: $workspace.settings.layout.appearance.expandedHeight, in: 280...800, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Expanded height") }
            SurfaceAppearanceControls(appearance: $workspace.settings.layout.appearance, theme: store.configuration.theme, screen: NSScreen.screens.first)
            Slider(value: $store.configuration.theme.cornerRadius, in: 0...48) { Text("Corner radius") }
            Slider(value: $workspace.settings.layout.appearance.spacing, in: 4...28) { Text("Module spacing") }
            Slider(value: $store.configuration.theme.tint, in: 0...1) { Text("Accent hue") }
            Slider(value: $store.configuration.theme.opacity, in: 0.5...1) { Text("Opacity") }
            Section("Background") {
                Picker("Type", selection: Binding(
                    get: { workspace.settings.layout.appearance.background.rawValue },
                    set: { if let v = BackgroundKind(rawValue: $0) { workspace.settings.layout.appearance.background = v } }
                )) {
                    ForEach(BackgroundKind.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0.rawValue)
                    }
                }
                Button("Choose image or video…") { workspace.chooseBackground() }
                Text(workspace.settings.layout.appearance.assetPath.isEmpty ? "No background file selected" : URL(fileURLWithPath: workspace.settings.layout.appearance.assetPath).lastPathComponent).font(.caption)
                if workspace.settings.layout.appearance.background == .glass {
                    Text("Glass blurs the desktop behind Halo. Opacity adjusts its tint; macOS controls the backdrop blur. Reduce Transparency replaces glass with a solid background.").font(.caption)
                } else {
                    Slider(value: $workspace.settings.layout.appearance.blur, in: 0...20) { Text("Blur") }
                    Slider(value: $workspace.settings.layout.appearance.saturation, in: 0...2) { Text("Saturation") }
                    Slider(value: $workspace.settings.layout.appearance.brightness, in: -0.5...0.5) { Text("Brightness") }
                }
                GrainSettingsView(options: Binding(
                    get: { workspace.settings.layout.appearance.grain ?? GrainOptions() },
                    set: { workspace.settings.layout.appearance.grain = $0 }
                ))
                Toggle("Pause video on battery", isOn: $workspace.settings.layout.appearance.pauseVideoOnBattery)
                Text("Video is muted, loops, and pauses when collapsed. Large videos and blur increase GPU use. Background files are referenced in place.").font(.caption)
            }
            Toggle("Animate expansion", isOn: $store.configuration.theme.animations)
            Picker("Animation timing", selection: Binding(
                get: { workspace.settings.layout.appearance.animation.rawValue },
                set: { if let v = AnimationPreset(rawValue: $0) { workspace.settings.layout.appearance.animation = v } }
            )) {
                ForEach(AnimationPreset.allCases, id: \.self) {
                    Text($0.rawValue.capitalized).tag($0.rawValue)
                }
            }
            HStack { Button("Import theme…") { store.importTheme() }; Button("Export theme…") { store.exportTheme() }; Button("Reset") { store.configuration.theme = Theme(); workspace.settings.layout.appearance = Appearance() } }
        case "Widgets":
            WidgetSettingsView(layout: $workspace.settings.layout)
        case "Closed notch":
            ClosedNotchSettingsView(layout: $workspace.settings.layout, media: workspace.media, app: workspace.settings.mediaApp)
        case "Modules":
            Text("Drag a module row to reorder it, or use the arrow buttons.")
            ForEach(workspace.settings.layout.normalizedOrder()) { module in
                HStack {
                    Toggle(isOn: Binding(get: { workspace.settings.layout.enabled.contains(module) }, set: { value in
                        if value { workspace.settings.layout.enabled.insert(module) } else { workspace.settings.layout.enabled.remove(module) }
                    })) { Label(module.title, systemImage: module.symbol) }
                    Button { workspace.moveModule(module, by: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Move \(module.title) up")
                    Button { workspace.moveModule(module, by: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel("Move \(module.title) down")
                }
                .onDrag {
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(forTypeIdentifier: "com.redstoneinvente.halo.module", visibility: .ownProcess) { completion in
                        completion(Data(module.rawValue.utf8), nil); return nil
                    }
                    return provider
                }
                .onDrop(of: ["com.redstoneinvente.halo.module"], isTargeted: nil) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadDataRepresentation(forTypeIdentifier: "com.redstoneinvente.halo.module") { data, _ in
                        guard let data, let value = String(data: data, encoding: .utf8), let source = ModuleID(rawValue: value) else { return }
                        Task { @MainActor in workspace.settings.layout.move(source, before: module) }
                    }
                    return true
                }
            }
        case "Context notch interface":
            ContextMusicSettings(layout: $workspace.settings.layout)
        case "Media & Files":
            Toggle("Automatically detect the playing music app", isOn: Binding(
                get: { workspace.settings.automaticMedia ?? true },
                set: { workspace.settings.automaticMedia = $0; workspace.media.disconnect(); workspace.media.poll(app: workspace.settings.mediaApp, automatic: $0) }
            ))
            Picker("Preferred player", selection: $workspace.settings.mediaApp) { Text("Apple Music").tag("com.apple.Music"); Text("Spotify").tag("com.spotify.client") }
            Text("Halo detects playing Apple Music and Spotify automatically, with the preferred player breaking ties when both start together. macOS may ask for Automation permission once per player. If denied, use Retry detection after allowing access in System Settings. Browser playback and other apps are not supported. Disabling automatic detection limits detection to the preferred player.")
            Toggle("Keep shelf references between launches", isOn: $workspace.settings.persistShelf).onChange(of: workspace.settings.persistShelf) { _ in store.persistFiles() }
            Picker("Remove shelf references after", selection: $workspace.settings.shelfRetentionMinutes) { Text("Manually").tag(0); Text("5 minutes").tag(5); Text("30 minutes").tag(30); Text("1 hour").tag(60) }
            Text("Up to 100 references. Pinned items do not expire. Saved references keep their original retention age after relaunch. Removing a shelf item never deletes its original.")
            Button("Clear shelf references") { store.clearShelf() }
        case "Profiles":
            ProfileLibraryView(store: store, workspace: workspace)
        case "Automation":
            Text("Rules apply a profile when a condition becomes true. The first newly matching rule wins. No scripts or shell commands run.")
            ForEach($workspace.settings.rules) { $rule in
                VStack(alignment: .leading) {
                    Toggle("Enabled", isOn: $rule.enabled)
                    Picker("When", selection: $rule.trigger) { ForEach(RuleTrigger.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    TextField("Value", text: $rule.value)
                    Picker("Apply profile", selection: $rule.profileID) { ForEach(workspace.settings.profiles) { Text($0.name).tag($0.id) } }
                    Button("Remove rule") { workspace.settings.rules.removeAll { $0.id == rule.id } }
                }
            }
            Button("Add rule") { if let profile = workspace.settings.profiles.first { workspace.settings.rules.append(AutomationRule(profileID: profile.id)) } }.disabled(workspace.settings.profiles.isEmpty)
            Text("Values: app bundle ID; battery percentage; charging true/false; display count; local hour 0–23. Rules do not restore the previous profile.").font(.caption)
        case "Displays":
            Toggle("Show on all displays", isOn: $store.configuration.allDisplays)
            ForEach(NSScreen.screens, id: \.localizedName) { screen in
                let id = WindowManager.displayID(screen)
                Section(screen.localizedName) {
                    if let index = workspace.settings.displays.firstIndex(where: { $0.id == id }) {
                        Toggle("Show Halo here", isOn: $workspace.settings.displays[index].enabled)
                        Picker("Style", selection: $workspace.settings.displays[index].theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
                        Slider(value: $workspace.settings.displays[index].theme.width, in: 340...640, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0, display: screen) }) { Text("Width") }
                        Slider(value: $workspace.settings.displays[index].theme.tint, in: 0...1) { Text("Accent") }
                        Menu("Use a profile on this display") {
                            ForEach(workspace.settings.profiles) { profile in
                                Button(profile.name) { workspace.settings.displays[index].theme = profile.theme; workspace.settings.displays[index].layout = profile.layout }
                            }
                        }
                        Button("Follow global modules and background") { workspace.settings.displays[index].layout = nil }
                        if workspace.settings.displays[index].layout != nil {
                            SurfaceAppearanceControls(appearance: Binding(
                                get: { workspace.settings.displays[index].layout?.appearance ?? workspace.settings.layout.appearance },
                                set: { workspace.settings.displays[index].layout?.appearance = $0 }
                            ), theme: workspace.settings.displays[index].theme, screen: screen)
                        } else {
                            Button("Customize closed size, shape and transitions here") { workspace.settings.displays[index].layout = workspace.settings.layout }
                        }
                        Button("Use global theme") { workspace.settings.displays.removeAll { $0.id == id } }
                    } else { Button("Customize this display") { workspace.settings.displays.append(DisplayOverride(id: id, theme: store.configuration.theme)) } }
                }
            }
        case "Plugins":
            Text("Declarative plugins add URL commands to the launcher. Each command requires confirmation. Native executable plugins are not loaded.")
            Button("Import plugin manifest…") { workspace.importPlugin() }
            ForEach(workspace.plugins) { plugin in HStack { Text(plugin.name); Spacer(); Text("\(plugin.commands.count) commands"); Button("Remove") { workspace.removePlugin(plugin.id) } } }
        case "Privacy":
            Section("Clipboard — optional") {
                Text("Halo samples text every two seconds when enabled. History stays in memory and clears on quit. Sensitive clipboard markers and listed apps are excluded; exclusions cannot guarantee detection of all secrets.")
                Toggle("Enable text clipboard history", isOn: $workspace.settings.clipboardEnabled).onChange(of: workspace.settings.clipboardEnabled) { _ in workspace.clipboard.reset() }
                TextField("Excluded app bundle IDs, comma-separated", text: $workspace.settings.clipboardExcludedApps)
                Button("Clear history now") { workspace.clipboard.reset() }
            }
            Section("Optional permissions") {
                Button("Allow Calendar (today's events)") { workspace.calendar.requestAccess() }
                Button("Allow Notifications (timer completion)") { workspace.enableNotifications() }
                Text("Automation is requested when detecting or controlling a running supported music player. Screen Recording is requested only when you capture a region. Microphone and Accessibility are not requested. No analytics. Enabling artwork colors downloads Spotify artwork; Apple Music artwork is read from the player. Plugin URLs open only after confirmation.")
                Text("This direct-distribution build is not sandboxed. Files and notes are stored locally.")
            }
        default:
            Text("Halo 0.2 · macOS 13+ · Native SwiftUI and AppKit")
            Button("Choose developer repository…") { workspace.chooseRepository() }
            Text(workspace.settings.repositoryPath).font(.caption)
            Text("Git status is read-only and runs only when requested. No build commands or executable plugins run.")
            Text("Compilation and hardware validation on macOS are required. See Docs/ImplementationStatus.md and Docs/ReleaseChecklist.md.")
        }
    }
}

@MainActor private struct ProfileLibraryView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @AppStorage("HaloProfileCards") private var cards = true
    @State private var editing: Profile?
    @State private var name = "My profile"
    var body: some View {
        HStack {
            TextField("New profile name", text: $name)
            Button("Save current") { workspace.saveProfile(name: name, theme: store.configuration.theme) }
        }
        Picker("View", selection: $cards) {
            Label("Cards", systemImage: "square.grid.2x2").tag(true)
            Label("List", systemImage: "list.bullet").tag(false)
        }.pickerStyle(.segmented)
        LazyVGrid(columns: cards ? [GridItem(.adaptive(minimum: 220), alignment: .top)] : [GridItem(.flexible())], alignment: .leading, spacing: 12) {
            ForEach(workspace.settings.profiles) { profile in
                VStack(alignment: .leading, spacing: 10) {
                    Label(profile.name, systemImage: profile.icon ?? "person.crop.rectangle")
                        .font(.headline).foregroundStyle(Color.accentColor)
                    if let detail = profile.description, !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    Text("\(profile.layout.enabled.count) widgets · \(profile.theme.style.rawValue)").font(.caption)
                    Text(activationSummary(profile)).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Apply") { workspace.apply(profile) }
                        Button("Customize") { editing = profile }
                        Menu {
                            Button("Duplicate") { var copy = profile; copy.id = UUID(); copy.name += " copy"; workspace.settings.profiles.append(copy) }
                            Button("Delete", role: .destructive) { workspace.deleteProfile(profile.id) }
                        } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24)
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
            }
        }
        Text("Apply switches now. Customize edits only that saved profile. Manage automatic times in Schedules and conditions in Automation.").font(.caption).foregroundStyle(.secondary)
        .sheet(item: $editing) { profile in
            ProfileEditor(profile: profile, media: workspace.media, app: workspace.settings.mediaApp) { updated in
                if let index = workspace.settings.profiles.firstIndex(where: { $0.id == updated.id }) { workspace.settings.profiles[index] = updated }
            }
        }
    }
    private func activationSummary(_ profile: Profile) -> String {
        var lines: [String] = []
        for entry in workspace.settings.profileSchedules ?? [] where entry.profileID == profile.id {
            let w = entry.window
            let days = w.weekdays.sorted().filter { (1...7).contains($0) }.map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
            let time = w.startMinute == w.endMinute ? "All day" : String(format: "%02d:%02d–%02d:%02d", w.startMinute / 60, w.startMinute % 60, w.endMinute / 60, w.endMinute % 60)
            lines.append("\(entry.enabled ? "Scheduled" : "Schedule paused"): \(days) · \(time)")
        }
        for rule in workspace.settings.rules where rule.profileID == profile.id {
            lines.append("\(rule.enabled ? "Automatic" : "Rule paused"): \(rule.trigger.rawValue) · \(rule.value)")
        }
        return lines.isEmpty ? "Manual · Apply whenever you like" : lines.joined(separator: "\n")
    }
}

@MainActor private struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: Profile
    let media: MediaService
    let app: String
    let save: (Profile) -> Void
    @State private var tab = "Details"
    private let icons = ["person.crop.rectangle", "briefcase", "house", "moon", "sun.max", "gamecontroller", "music.note", "hammer", "leaf", "heart", "bolt", "star"]
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Customize profile").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() }; Button("Save") { save(profile); dismiss() }.disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding()
            Picker("Section", selection: $tab) { ForEach(["Details", "Layout", "Widgets", "Closed notch", "Context"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented).padding(.horizontal)
            Form {
                switch tab {
                case "Details":
                    TextField("Name", text: $profile.name)
                    TextField("Description", text: Binding(get: { profile.description ?? "" }, set: { profile.description = $0 }), axis: .vertical)
                    Picker("Icon", selection: Binding(get: { profile.icon ?? icons[0] }, set: { profile.icon = $0 })) {
                        ForEach(icons, id: \.self) { Label($0, systemImage: $0).tag($0) }
                    }
                case "Layout":
                    Picker("Surface", selection: $profile.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
                    Slider(value: $profile.theme.width, in: 340...640) { Text("Expanded width") }
                    Toggle("Horizontal widgets", isOn: Binding(get: { profile.layout.horizontalWidgets ?? false }, set: { profile.layout.horizontalWidgets = $0 }))
                    Toggle("Page navigation", isOn: Binding(get: { profile.layout.horizontalPages ?? false }, set: { profile.layout.horizontalPages = $0 }))
                    Slider(value: Binding(get: { profile.layout.horizontalHeight ?? 260 }, set: { profile.layout.horizontalHeight = $0 }), in: 200...500) { Text("Horizontal height") }
                    Section("Modules and order") {
                        ForEach(profile.layout.normalizedOrder()) { module in
                            HStack {
                                Toggle(module.title, isOn: Binding(get: { profile.layout.enabled.contains(module) }, set: { if $0 { profile.layout.enabled.insert(module) } else { profile.layout.enabled.remove(module) } }))
                                Button { moveUp(module) } label: { Image(systemName: "arrow.up") }.disabled(profile.layout.normalizedOrder().first == module).help("Move earlier")
                            }
                        }
                    }
                    Section("Theme and background") {
                        Slider(value: $profile.theme.tint, in: 0...1) { Text("Accent hue") }
                        Slider(value: $profile.theme.opacity, in: 0.5...1) { Text("Opacity") }
                        Slider(value: $profile.layout.appearance.expandedHeight, in: 280...800) { Text("Vertical dashboard height") }
                        Picker("Background", selection: $profile.layout.appearance.background) {
                            ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        Button("Choose background image or video…") {
                            let panel = NSOpenPanel(); panel.allowedContentTypes = [.image, .movie]; panel.canChooseDirectories = false
                            if panel.runModal() == .OK, let url = panel.url { profile.layout.appearance.assetPath = url.path }
                        }
                    }
                    SurfaceAppearanceControls(appearance: $profile.layout.appearance, theme: profile.theme)
                case "Context": ContextMusicSettings(layout: $profile.layout)
                case "Widgets": WidgetSettingsView(layout: $profile.layout)
                default: ClosedNotchSettingsView(layout: $profile.layout, media: media, app: app)
                }
            }.formStyle(.grouped)
        }.frame(width: 620, height: 650)
    }
    private func moveUp(_ module: ModuleID) {
        let order = profile.layout.normalizedOrder()
        if let index = order.firstIndex(of: module), index > 0 { profile.layout.move(module, before: order[index - 1]) }
    }
}


private struct ContextMusicSettings: View {
    @Binding var layout: WorkspaceLayout
    private var options: Binding<ContextMusicOptions> {
        Binding(get: { layout.contextMusic ?? ContextMusicOptions() }, set: { layout.contextMusic = $0 })
    }
    var body: some View {
        Section("Music interface") {
            Toggle("Show music interface while playing", isOn: options.enabled)
            Text("The opened notch switches to music while playback is active. Show widgets lets you access your dashboard at any time.").font(.caption)
            Toggle("Album artwork", isOn: options.showArtwork)
            Toggle("Song title", isOn: options.showTitle)
            Toggle("Artist", isOn: options.showArtist)
            Toggle("Playback controls", isOn: options.showControls)
            Toggle("Visualizer", isOn: options.showVisualizer)
            Slider(value: options.artworkSize, in: 32...200) { Text("Artwork size") }
            Slider(value: options.fontSize, in: 12...40) { Text("Text size") }
            ColorPicker("Text color", selection: Binding(get: { options.wrappedValue.textColor.color }, set: { options.wrappedValue.textColor = WidgetColor($0) }))
            Picker("Music card background", selection: options.background) {
                Text("Glass").tag(BackgroundKind.glass); Text("Gradient").tag(BackgroundKind.gradient); Text("Solid").tag(BackgroundKind.solid)
            }
            Slider(value: options.backgroundOpacity, in: 0...1) { Text("Background opacity") }
        }
    }
}
