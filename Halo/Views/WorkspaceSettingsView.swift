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
    private let sections = ["General", "Appearance", "Modules", "Widgets", "Closed notch", "Context notch interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "About"]
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
                    Link(destination: URL(string: "https://halo.redstoneinvente.com")!) { Label("Halo website", systemImage: "globe") }
                    Link(destination: URL(string: "https://buymeacoffee.com/redstoneinvente")!) { Label("Buy me a coffee", systemImage: "cup.and.saucer.fill") }
                }.font(.callout).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(width: 220)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: sectionIcon(section ?? "General")).font(.title2).foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40).background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
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
        case "HUD": return "rectangle.inset.filled.and.person.filled"
        case "Closed notch": return "rectangle.topthird.inset.filled"
        case "Media & Files": return "play.rectangle"
        case "Profiles": return "person.crop.rectangle.stack"
        case "Schedules": return "calendar.badge.clock"
        case "Automation": return "bolt"
        case "Displays": return "display.2"
        case "Plugins": return "puzzlepiece.extension"
        case "Privacy": return "hand.raised"
        case "About": return "info.circle"
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
        case "Schedules": ScheduleSettingsView(workspace: workspace)
        case "Appearance":
            Section("Expanded dashboard") {
                Toggle("Horizontal widget layout", isOn: Binding(get: { workspace.settings.layout.horizontalWidgets ?? false }, set: { workspace.settings.layout.horizontalWidgets = $0 }))
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
                Picker("Type", selection: Binding(get: { workspace.settings.layout.appearance.background.rawValue }, set: { if let v = BackgroundKind(rawValue: $0) { workspace.settings.layout.appearance.background = v } })) {
                    ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) }
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
                GrainSettingsView(options: Binding(get: { workspace.settings.layout.appearance.grain ?? GrainOptions() }, set: { workspace.settings.layout.appearance.grain = $0 }))
                Toggle("Pause video on battery", isOn: $workspace.settings.layout.appearance.pauseVideoOnBattery)
                Text("Video is muted, loops, and pauses when collapsed. Large videos and blur increase GPU use. Background files are referenced in place.").font(.caption)
            }
            Toggle("Animate expansion", isOn: $store.configuration.theme.animations)
            Picker("Animation timing", selection: Binding(get: { workspace.settings.layout.appearance.animation.rawValue }, set: { if let v = AnimationPreset(rawValue: $0) { workspace.settings.layout.appearance.animation = v } })) {
                ForEach(AnimationPreset.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) }
            }
            HStack { Button("Import theme…") { store.importTheme() }; Button("Export theme…") { store.exportTheme() }; Button("Reset") { store.configuration.theme = Theme(); workspace.settings.layout.appearance = Appearance() } }
        case "Widgets": WidgetSettingsView(layout: $workspace.settings.layout)
        case "Closed notch": ClosedNotchSettingsView(layout: $workspace.settings.layout, media: workspace.media, app: workspace.settings.mediaApp)
        case "HUD": HaloHUDWorkspaceSettingsView(layout: $workspace.settings.layout, profileNames: workspace.settings.profiles.map(\.name))
        case "Modules":
            Text("Drag a module row to reorder it, or use the arrow buttons.")
            ForEach(workspace.settings.layout.normalizedOrder()) { module in
                HStack {
                    Toggle(isOn: Binding(get: { workspace.settings.layout.enabled.contains(module) }, set: { value in if value { workspace.settings.layout.enabled.insert(module) } else { workspace.settings.layout.enabled.remove(module) } })) { Label(module.title, systemImage: module.symbol) }
                    Button { workspace.moveModule(module, by: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Move \(module.title) up")
                    Button { workspace.moveModule(module, by: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel("Move \(module.title) down")
                }
                .onDrag {
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(forTypeIdentifier: "com.redstoneinvente.halo.module", visibility: .ownProcess) { completion in completion(Data(module.rawValue.utf8), nil); return nil }
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
        case "Context notch interface": ContextMusicSettings(layout: $workspace.settings.layout)
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
        case "Profiles": ProfileLibraryView(store: store, workspace: workspace)
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
                        Menu("Use a profile on this display") { ForEach(workspace.settings.profiles) { profile in Button(profile.name) { workspace.settings.displays[index].theme = profile.theme; workspace.settings.displays[index].layout = profile.layout } } }
                        Button("Follow global modules and background") { workspace.settings.displays[index].layout = nil }
                        if workspace.settings.displays[index].layout != nil {
                            SurfaceAppearanceControls(appearance: Binding(get: { workspace.settings.displays[index].layout?.appearance ?? workspace.settings.layout.appearance }, set: { workspace.settings.displays[index].layout?.appearance = $0 }), theme: workspace.settings.displays[index].theme, screen: screen)
                        } else { Button("Customize closed size, shape and transitions here") { workspace.settings.displays[index].layout = workspace.settings.layout } }
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
        default: HaloAboutView()
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
        HStack { TextField("New profile name", text: $name); Button("Save current") { workspace.saveProfile(name: name, theme: store.configuration.theme) } }
        Picker("View", selection: $cards) { Label("Cards", systemImage: "square.grid.2x2").tag(true); Label("List", systemImage: "list.bullet").tag(false) }.pickerStyle(.segmented)
        LazyVGrid(columns: cards ? [GridItem(.adaptive(minimum: 220), alignment: .top)] : [GridItem(.flexible())], alignment: .leading, spacing: 12) {
            ForEach(workspace.settings.profiles) { profile in
                VStack(alignment: .leading, spacing: 10) {
                    Label(profile.name, systemImage: profile.icon ?? "person.crop.rectangle").font(.headline).foregroundStyle(Color.accentColor)
                    if let detail = profile.description, !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    Text("\(profile.layout.enabled.intersection(Set(ModuleID.allCases)).count) widgets · \(profile.theme.style.rawValue)").font(.caption)
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
        for rule in workspace.settings.rules where rule.profileID == profile.id { lines.append("\(rule.enabled ? "Automatic" : "Rule paused"): \(rule.trigger.rawValue) · \(rule.value)") }
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
            Picker("Section", selection: $tab) { ForEach(["Details", "Layout", "Widgets", "Closed notch", "Context", "HUD"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented).padding(.horizontal)
            Form {
                switch tab {
                case "Details":
                    TextField("Name", text: $profile.name)
                    TextField("Description", text: Binding(get: { profile.description ?? "" }, set: { profile.description = $0 }), axis: .vertical)
                    Picker("Icon", selection: Binding(get: { profile.icon ?? icons[0] }, set: { profile.icon = $0 })) { ForEach(icons, id: \.self) { Label($0, systemImage: $0).tag($0) } }
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
                        Picker("Background", selection: $profile.layout.appearance.background) { ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                        Button("Choose background image or video…") {
                            let panel = NSOpenPanel(); panel.allowedContentTypes = [.image, .movie]; panel.canChooseDirectories = false
                            if panel.runModal() == .OK, let url = panel.url { profile.layout.appearance.assetPath = url.path }
                        }
                    }
                    SurfaceAppearanceControls(appearance: $profile.layout.appearance, theme: profile.theme)
                case "Context": ContextMusicSettings(layout: $profile.layout)
                case "HUD": HaloHUDWorkspaceSettingsView(layout: $profile.layout, profileNames: [])
                case "Widgets": WidgetSettingsView(layout: $profile.layout)
                default: ClosedNotchSettingsView(layout: $profile.layout, media: media, app: app)
                }
            }.formStyle(.grouped)
        }.frame(width: 720, height: 700)
    }
    private func moveUp(_ module: ModuleID) {
        let order = profile.layout.normalizedOrder()
        if let index = order.firstIndex(of: module), index > 0 { profile.layout.move(module, before: order[index - 1]) }
    }
}

private struct ContextMusicSettings: View {
    @Binding var layout: WorkspaceLayout
    private var options: Binding<ContextMusicOptions> { Binding(get: { layout.contextMusic ?? ContextMusicOptions() }, set: { layout.contextMusic = $0 }) }
    private var layoutMode: Binding<ContextMusicLayoutMode> { Binding(get: { options.wrappedValue.resolvedLayoutMode }, set: { options.wrappedValue.layoutMode = $0 }) }
    private var foregroundArtwork: Binding<ContextArtworkPresentation> {
        Binding(get: { options.wrappedValue.resolvedForegroundArtwork }, set: { options.wrappedValue.foregroundArtwork = $0; options.wrappedValue.showArtwork = $0 != .none })
    }
    private var artworkBackground: Binding<Bool> { Binding(get: { options.wrappedValue.usesArtworkBackground }, set: { options.wrappedValue.artworkBackground = $0 }) }
    private var contentAlignment: Binding<ContextContentAlignment> { Binding(get: { options.wrappedValue.resolvedContentAlignment }, set: { options.wrappedValue.contentAlignment = $0 }) }
    private var artworkBlur: Binding<Double> { Binding(get: { options.wrappedValue.resolvedArtworkBackgroundBlur }, set: { options.wrappedValue.artworkBackgroundBlur = $0 }) }
    private var artworkDim: Binding<Double> { Binding(get: { options.wrappedValue.resolvedArtworkBackgroundDim }, set: { options.wrappedValue.artworkBackgroundDim = $0 }) }
    private var spacing: Binding<Double> { Binding(get: { options.wrappedValue.resolvedSpacing }, set: { options.wrappedValue.spacing = $0 }) }
    private var cornerRadius: Binding<Double> { Binding(get: { options.wrappedValue.resolvedCornerRadius }, set: { options.wrappedValue.cornerRadius = $0 }) }
    private var controlSize: Binding<Double> { Binding(get: { options.wrappedValue.resolvedControlSize }, set: { options.wrappedValue.controlSize = $0 }) }
    private var vinylRPM: Binding<Double> { Binding(get: { options.wrappedValue.resolvedVinylRPM }, set: { options.wrappedValue.vinylRPM = $0 }) }
    private var showLyrics: Binding<Bool> { Binding(get: { options.wrappedValue.showsLyrics }, set: { options.wrappedValue.showLyrics = $0 }) }
    private var lyricDisplay: Binding<LyricDisplayMode> { Binding(get: { options.wrappedValue.resolvedLyricDisplay }, set: { options.wrappedValue.lyricDisplay = $0 }) }
    private var lyricOffset: Binding<Double> { Binding(get: { options.wrappedValue.resolvedLyricSyncOffset }, set: { options.wrappedValue.lyricSyncOffset = $0 }) }
    private var lyricFontSize: Binding<Double> { Binding(get: { options.wrappedValue.resolvedLyricFontSize }, set: { options.wrappedValue.lyricFontSize = $0 }) }
    private var onlineLyrics: Binding<Bool> { Binding(get: { options.wrappedValue.usesOnlineLyrics }, set: { options.wrappedValue.lyricsOnline = $0 }) }
    private var visualizerStyle: Binding<PlaybackAnimation> { Binding(get: { options.wrappedValue.resolvedVisualizerStyle }, set: { options.wrappedValue.visualizerStyle = $0 }) }
    private func boolBinding(_ keyPath: WritableKeyPath<ContextMusicOptions, Bool?>, resolved: @escaping (ContextMusicOptions) -> Bool) -> Binding<Bool> {
        Binding(get: { resolved(options.wrappedValue) }, set: { options.wrappedValue[keyPath: keyPath] = $0 })
    }
    var body: some View {
        Section("Context music interface") {
            Toggle("Replace the opened notch while music is playing", isOn: options.enabled)
            Text("When enabled, the music interface becomes the expanded Halo surface. The normal widget dashboard returns automatically when playback stops.").font(.caption).foregroundStyle(.secondary)
            Picker("Layout", selection: layoutMode) { ForEach(ContextMusicLayoutMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Picker("Content alignment", selection: contentAlignment) { ForEach(ContextContentAlignment.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Toggle("Song title", isOn: options.showTitle)
            Toggle("Artist", isOn: options.showArtist)
            Toggle("Playback controls", isOn: options.showControls)
            Toggle("Visualizer", isOn: options.showVisualizer)
        }

        Section("Lyrics") {
            Toggle("Show synced lyrics", isOn: showLyrics)
            if showLyrics.wrappedValue {
                Picker("Lyric display", selection: lyricDisplay) {
                    Text("Current line").tag(LyricDisplayMode.line)
                    Text("Focus phrase").tag(LyricDisplayMode.focus)
                    Text("Current word").tag(LyricDisplayMode.word)
                }.pickerStyle(.segmented)
                Slider(value: lyricFontSize, in: 10...44) { Text("Lyrics size") }
                Slider(value: lyricOffset, in: -5...5, step: 0.05) { Text("Lyrics sync offset") }
                Toggle("Use online lyrics fallback", isOn: onlineLyrics)
                Text("Uses the same synced LRC timing approach as the closed notch, including timestamp offsets and Apple Music embedded-lyrics fallback.").font(.caption).foregroundStyle(.secondary)
            }
        }

        if options.wrappedValue.showVisualizer {
            Section("Visualizer") {
                Picker("Style", selection: visualizerStyle) {
                    ForEach(PlaybackAnimation.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Text("Bars, Wave, Pulse, Waveform, Ribbon, Dots, Rings, Orbit and Spectrum are available in the context interface.").font(.caption).foregroundStyle(.secondary)
            }
        }

        Section("Artwork layers") {
            Picker("Foreground artwork", selection: foregroundArtwork) { ForEach(ContextArtworkPresentation.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Text("Foreground artwork is independent from the background. You can use the album cover as the background while still showing a square cover or spinning vinyl in front.").font(.caption).foregroundStyle(.secondary)
            if foregroundArtwork.wrappedValue != .none { Slider(value: options.artworkSize, in: 32...240) { Text("Foreground artwork size") } }
            if foregroundArtwork.wrappedValue == .vinyl { Slider(value: vinylRPM, in: 1...45) { Text("Vinyl rotation speed") } }
            Toggle("Use album cover as background", isOn: artworkBackground)
            if artworkBackground.wrappedValue {
                Slider(value: artworkBlur, in: 0...30) { Text("Artwork background blur") }
                Slider(value: artworkDim, in: 0...0.9) { Text("Artwork background dim") }
                Text("Album artwork is clipped to the context surface before blur/cropping, so enabling it cannot resize or overflow the notch.").font(.caption).foregroundStyle(.secondary)
            }
        }

        Section("Colors from current song") {
            Toggle("Color text from song", isOn: boolBinding(\.songTextColors, resolved: { $0.usesSongTextColors }))
            Toggle("Color controls and scrubber from song", isOn: boolBinding(\.songControlColors, resolved: { $0.usesSongControlColors }))
            Toggle("Color visualizer from song", isOn: boolBinding(\.songVisualizerColors, resolved: { $0.usesSongVisualizerColors }))
            Toggle("Tint background from song", isOn: boolBinding(\.songBackgroundColors, resolved: { $0.usesSongBackgroundColors }))
            Text("Halo extracts a small palette from each track's artwork and updates these elements automatically when the song changes.").font(.caption).foregroundStyle(.secondary)
        }

        Section("Appearance") {
            Slider(value: options.fontSize, in: 12...48) { Text("Title size") }
            Slider(value: controlSize, in: 14...42) { Text("Control size") }
            Slider(value: spacing, in: 4...32) { Text("Content spacing") }
            Slider(value: cornerRadius, in: 0...48) { Text("Inner corner radius") }
            ColorPicker("Text color", selection: Binding(get: { options.wrappedValue.textColor.color }, set: { options.wrappedValue.textColor = WidgetColor($0) }))
            Picker("Base background", selection: options.background) {
                Text("Glass").tag(BackgroundKind.glass); Text("Gradient").tag(BackgroundKind.gradient); Text("Solid").tag(BackgroundKind.solid)
            }
            Slider(value: options.backgroundOpacity, in: 0...1) { Text("Base background opacity") }
        }
    }
}

// MARK: - HUD Studio

@MainActor private struct HaloHUDWorkspaceSettingsView: View {
    @Binding var layout: WorkspaceLayout
    let profileNames: [String]
    @State private var page = "Overview"
    @State private var selectedEvent: HaloHUDEventKind = .volume
    @State private var previewValue = 0.72
    @State private var customPresetName = "My HUD"
    @AppStorage("HaloHUDKeepVisibleWhileEditing") private var keepHUDVisibleWhileEditing = false

    private var hud: Binding<HaloHUDSettings> {
        Binding(get: { layout.hud ?? HaloHUDSettings() }, set: { layout.hud = $0 })
    }
    private var eventOverride: Binding<HaloHUDEventOverride> {
        Binding(get: { hud.wrappedValue.override(for: selectedEvent) }, set: {
            var settings = hud.wrappedValue; settings.setOverride($0, for: selectedEvent); hud.wrappedValue = settings
        })
    }
    private var configuration: Binding<HaloHUDConfiguration> {
        Binding(get: {
            let settings = hud.wrappedValue, item = settings.override(for: selectedEvent)
            return item.useGlobalSettings ? settings.global : item.configuration
        }, set: { newValue in
            var settings = hud.wrappedValue
            var item = settings.override(for: selectedEvent)
            if item.useGlobalSettings { settings.global = newValue }
            else { item.configuration = newValue; settings.setOverride(item, for: selectedEvent) }
            hud.wrappedValue = settings
        })
    }

    var body: some View {
        Picker("HUD", selection: $page) {
            ForEach(["Overview", "HUD Studio", "Events", "Presets", "Profiles / Rules"], id: \.self) { Text($0).tag($0) }
        }.pickerStyle(.segmented)

        switch page {
        case "HUD Studio": studio
        case "Events": events
        case "Presets": presets
        case "Profiles / Rules": rules
        default: overview
        }
    }

    @ViewBuilder private var overview: some View {
        Section("HUD Replacement") {
            Toggle("Enable HUD Replacement", isOn: hud.enabled)
            Text("Halo translates supported system events into reusable HUD events, resolves the active profile and per-event override, then sends the result to a presentation renderer.").font(.caption).foregroundStyle(.secondary)
        }
        Section("System status") {
            Label("Volume, mute, display brightness and keyboard brightness are connected to Halo's existing safe key-observer/replacement path.", systemImage: "checkmark.seal.fill")
            Label("Other event types stay capability-gated until a reliable provider is connected; Halo will not use fragile private hooks just to make the list look complete.", systemImage: "shield.lefthalf.filled")
            if !AXIsProcessTrusted() {
                Text("Native key suppression needs Accessibility permission. Observer HUDs can still work without suppressing Apple's HUD.").font(.caption).foregroundStyle(.orange)
                Button("Open Accessibility Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                }
            }
        }
        Section("Quick actions") {
            HStack {
                Button("Preview Volume") { preview(.volume) }
                Button("Preview Brightness") { preview(.displayBrightness) }
                Button("Open HUD Studio") { page = "HUD Studio" }
            }
        }
    }

    @ViewBuilder private var studio: some View {
        Section("HUD Studio") {
            Picker("Event", selection: $selectedEvent) { ForEach(HaloHUDEventKind.allCases) { Text($0.title).tag($0) } }
            Toggle("Enable this HUD", isOn: Binding(get: { eventOverride.wrappedValue.enabled }, set: { var v = eventOverride.wrappedValue; v.enabled = $0; eventOverride.wrappedValue = v }))
            Toggle("Use Global Settings", isOn: Binding(get: { eventOverride.wrappedValue.useGlobalSettings }, set: { enabled in
                var v = eventOverride.wrappedValue
                if !enabled && v.useGlobalSettings { v.configuration = hud.wrappedValue.global }
                v.useGlobalSettings = enabled; eventOverride.wrappedValue = v
            }))
            Toggle("Always show HUD while editing", isOn: $keepHUDVisibleWhileEditing)
                .onChange(of: keepHUDVisibleWhileEditing) { enabled in
                    if enabled { refreshPersistentPreview() } else { stopPersistentPreview() }
                }
            Text("Keeps the real HUD visible at its selected target while HUD Studio is open. Changes to target, layout, colors, size and preview value update live.").font(.caption).foregroundStyle(.secondary)
            Text(eventOverride.wrappedValue.useGlobalSettings ? "This HUD inherits the global configuration. Editing below changes the global HUD style." : "This HUD has its own configuration override.").font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { refreshPersistentPreview() }
        .onDisappear { stopPersistentPreview() }
        .onChange(of: selectedEvent) { _ in refreshPersistentPreview() }
        .onChange(of: previewValue) { _ in refreshPersistentPreview() }
        .onChange(of: configuration.wrappedValue) { _ in refreshPersistentPreview() }

        Section("Preview") {
            HaloHUDStudioPreview(kind: selectedEvent, value: previewValue, configuration: configuration.wrappedValue)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            Slider(value: $previewValue, in: 0...1) { Text("Preview value") }
            HStack {
                Text("\(Int(previewValue * 100))%").monospacedDigit()
                Spacer()
                Button("Preview HUD") { preview(selectedEvent, persistent: keepHUDVisibleWhileEditing) }
                Button("Test Entrance") { preview(selectedEvent, persistent: keepHUDVisibleWhileEditing) }
                Button("Test Exit") { stopPersistentPreview() }
            }
        }

        Section("Presentation") {
            Picker("Target", selection: configuration.presentation.target) { ForEach(HaloHUDPresentationTarget.allCases) { Text($0.title).tag($0) } }
            Picker("Display", selection: configuration.presentation.displayTarget) { ForEach(HaloHUDDisplayTarget.allCases) { Text($0.title).tag($0) } }
            switch configuration.wrappedValue.presentation.target {
            case .notch:
                Picker("Notch side", selection: configuration.presentation.notchSide) { ForEach(HaloHUDNotchSide.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Picker("Collision", selection: configuration.behavior.collision) { ForEach(HaloHUDCollisionBehavior.allCases) { Text($0.title).tag($0) } }
                Text("The model preserves Left, Right, Automatic and Full Notch as distinct presentation intents. Unsupported collisions fall back externally instead of destabilizing the notch.").font(.caption).foregroundStyle(.secondary)
            case .floating:
                Picker("Position", selection: configuration.presentation.floatingPosition) { ForEach(HaloHUDFloatingPosition.allCases) { Text($0.title).tag($0) } }
            case .screenEdge:
                Picker("Edge", selection: configuration.presentation.screenEdge) { ForEach(HaloHUDScreenEdge.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Slider(value: configuration.presentation.screenEdgeLength, in: 40...800) { Text("Length") }
                Slider(value: configuration.presentation.screenEdgeThickness, in: 1...24) { Text("Thickness") }
            case .menuBar:
                Text("Menu Bar is intended for state-like events. Events that need richer content can fall back to the configured external HUD.").font(.caption).foregroundStyle(.secondary)
            case .nearCursor:
                Text("Near Cursor uses the configured offsets and edge margin while keeping the HUD inside the selected display.").font(.caption).foregroundStyle(.secondary)
            case .disabled:
                Text("This event will not be presented.").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Fallback target", selection: configuration.behavior.fallbackTarget) { ForEach(HaloHUDPresentationTarget.allCases.filter { $0 != .disabled }) { Text($0.title).tag($0) } }
        }

        Section("Layout") {
            Picker("Layout", selection: configuration.layout.style) { ForEach(HaloHUDLayoutStyle.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Slider(value: configuration.layout.width, in: 80...900) { Text("Width") }
            Slider(value: configuration.layout.height, in: 24...500) { Text("Height") }
            Slider(value: configuration.layout.minimumWidth, in: 40...600) { Text("Minimum width") }
            Slider(value: configuration.layout.maximumWidth, in: 80...1200) { Text("Maximum width") }
            Slider(value: configuration.layout.horizontalPadding, in: 0...80) { Text("Horizontal padding") }
            Slider(value: configuration.layout.verticalPadding, in: 0...80) { Text("Vertical padding") }
            Slider(value: configuration.layout.spacing, in: 0...60) { Text("Content spacing") }
            Slider(value: configuration.layout.cornerRadius, in: 0...120) { Text("Corner radius") }
            Slider(value: configuration.layout.offsetX, in: -500...500) { Text("X offset") }
            Slider(value: configuration.layout.offsetY, in: -500...500) { Text("Y offset") }
            Slider(value: configuration.layout.edgeMargin, in: 0...120) { Text("Screen / edge margin") }
            Toggle("Compact mode", isOn: configuration.layout.compact)
        }

        Section("Components") {
            Toggle("Icon", isOn: configuration.components.icon)
            Toggle("Label", isOn: configuration.components.label)
            Toggle("Numeric value", isOn: configuration.components.value)
            Toggle("Percentage", isOn: configuration.components.percentage)
            Toggle("Progress visualization", isOn: configuration.components.progress)
            Toggle("Device name", isOn: configuration.components.deviceName)
            if configuration.wrappedValue.components.progress {
                Picker("Progress style", selection: configuration.progressStyle) { ForEach(HaloHUDProgressStyle.allCases) { Text($0.title).tag($0) } }
                if configuration.wrappedValue.progressStyle == .segmentedBar || configuration.wrappedValue.progressStyle == .dots {
                    Stepper("Segments / dots: \(configuration.wrappedValue.segments)", value: configuration.segments, in: 2...64)
                }
            }
            Slider(value: configuration.iconSize, in: 8...96) { Text("Icon size") }
            Slider(value: configuration.textSize, in: 8...64) { Text("Text size") }
        }

        Section("Appearance") {
            Picker("Background", selection: configuration.appearance.background) { ForEach(HaloHUDBackgroundStyle.allCases) { Text($0.title).tag($0) } }
            Slider(value: configuration.appearance.backgroundOpacity, in: 0...1) { Text("Background opacity") }
            Slider(value: configuration.appearance.blur, in: 0...60) { Text("Blur") }
            if configuration.wrappedValue.appearance.background == .glass { Slider(value: configuration.appearance.glassIntensity, in: 0...1) { Text("Glass intensity") } }
            Toggle("Border", isOn: configuration.appearance.border)
            if configuration.wrappedValue.appearance.border { Slider(value: configuration.appearance.borderOpacity, in: 0...1) { Text("Border opacity") } }
            Toggle("Shadow", isOn: configuration.appearance.shadow)
            Toggle("Glow", isOn: configuration.appearance.glow)
            Toggle("Noise", isOn: configuration.appearance.noise)
        }

        Section("Dynamic Colors") {
            colorSource("Primary", binding: configuration.appearance.primary.source)
            colorSource("Secondary", binding: configuration.appearance.secondary.source)
            colorSource("Progress", binding: configuration.appearance.progress.source)
            colorSource("Border", binding: configuration.appearance.borderColor.source)
            colorSource("Glow", binding: configuration.appearance.glowColor.source)
            Text("Album Artwork is a reusable color provider, not a music-HUD special case. When its source is unavailable the renderer falls back to Halo's accent/contrast colors.").font(.caption).foregroundStyle(.secondary)
        }

        Section("Animation") {
            Picker("Entrance", selection: configuration.animation.entrance) { ForEach(HaloHUDEntranceAnimation.allCases) { Text($0.title).tag($0) } }
            Picker("Exit", selection: configuration.animation.exit) { ForEach(HaloHUDExitAnimation.allCases) { Text($0.title).tag($0) } }
            Slider(value: configuration.animation.entranceDuration, in: 0...1.5) { Text("Entrance duration") }
            Slider(value: configuration.animation.exitDuration, in: 0...1.5) { Text("Exit duration") }
            if configuration.wrappedValue.animation.entrance == .spring {
                Slider(value: configuration.animation.springDamping, in: 0.1...1) { Text("Spring damping") }
                Slider(value: configuration.animation.springStiffness, in: 20...600) { Text("Spring stiffness") }
            }
            Picker("Progress animation", selection: configuration.animation.progress) { ForEach(HaloHUDProgressAnimation.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Slider(value: configuration.animation.intensity, in: 0...1) { Text("Animation intensity") }
        }

        Section("Behaviour") {
            Slider(value: configuration.behavior.displayDuration, in: 0.2...6) { Text("Display duration") }
            Picker("Repeated events", selection: configuration.behavior.interrupt) { ForEach(HaloHUDInterruptBehavior.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Picker("Collision behaviour", selection: configuration.behavior.collision) { ForEach(HaloHUDCollisionBehavior.allCases) { Text($0.title).tag($0) } }
            Text("Rapid values are designed to update the currently visible HUD and reset its dismissal deadline instead of repeatedly destroying and recreating the presentation.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var events: some View {
        Section("HUD Events") {
            ForEach(HaloHUDEventKind.allCases) { kind in
                let item = hud.wrappedValue.override(for: kind)
                HStack(spacing: 10) {
                    Image(systemName: kind.symbol).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                        Text(kind.providerStatus.title).font(.caption2).foregroundStyle(kind.providerStatus == .available ? .green : .secondary)
                    }
                    Spacer()
                    Text(hud.wrappedValue.configuration(for: kind).presentation.target.title).font(.caption).foregroundStyle(.secondary)
                    Toggle("", isOn: Binding(get: { item.enabled }, set: { enabled in
                        var settings = hud.wrappedValue, changed = settings.override(for: kind); changed.enabled = enabled; settings.setOverride(changed, for: kind); hud.wrappedValue = settings
                    })).labelsHidden()
                }
            }
        }
        Section("Provider policy") {
            Text("Available means the event is connected to Halo's current provider path. Observer-capable events have safe data sources but are not yet replacing a native HUD. Provider not connected means the event identifier/configuration exists, but Halo deliberately does not fake support with brittle private APIs.").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var presets: some View {
        Section("Built-in Presets") {
            ForEach(HaloHUDPreset.builtIns) { preset in
                HStack {
                    VStack(alignment: .leading) { Text(preset.name).font(.headline); Text(preset.configuration.presentation.target.title).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Apply") { var settings = hud.wrappedValue; settings.global = preset.configuration; hud.wrappedValue = settings }
                    Button("Duplicate") {
                        var settings = hud.wrappedValue
                        settings.customPresets.append(HaloHUDPreset(id: UUID().uuidString, name: preset.name + " Copy", builtIn: false, configuration: preset.configuration))
                        hud.wrappedValue = settings
                    }
                }
            }
        }
        Section("Custom Presets") {
            HStack { TextField("Preset name", text: $customPresetName); Button("Save Current") { saveCustomPreset() } }
            ForEach(hud.wrappedValue.customPresets) { preset in
                HStack {
                    Text(preset.name)
                    Spacer()
                    Button("Apply") { var settings = hud.wrappedValue; settings.global = preset.configuration; hud.wrappedValue = settings }
                    Button("Duplicate") {
                        var settings = hud.wrappedValue; var copy = preset; copy.id = UUID().uuidString; copy.name += " Copy"; settings.customPresets.append(copy); hud.wrappedValue = settings
                    }
                    Button("Delete", role: .destructive) { var settings = hud.wrappedValue; settings.customPresets.removeAll { $0.id == preset.id }; hud.wrappedValue = settings }
                }
            }
            Button("Reset to Halo Default") { var settings = hud.wrappedValue; settings.global = .haloPreset(); hud.wrappedValue = settings }
        }
    }

    @ViewBuilder private var rules: some View {
        Section("Profiles") {
            Text("HUD settings are stored inside WorkspaceLayout, so saved Halo profiles carry their own HUD configuration and scheduled/profile switches resolve the matching HUD settings automatically.").font(.caption).foregroundStyle(.secondary)
            if profileNames.isEmpty { Text("This editor is already inside a profile. Save the profile to keep these HUD settings with it.").foregroundStyle(.secondary) }
            else { ForEach(profileNames, id: \.self) { Label($0, systemImage: "person.crop.rectangle") } }
        }
        Section("Application-specific behaviour") {
            ForEach(hud.wrappedValue.appRules) { rule in
                HStack {
                    TextField("Bundle identifier", text: appRuleBinding(rule.id, keyPath: \.bundleIdentifier))
                    Picker("Target", selection: appRuleBinding(rule.id, keyPath: \.target)) { ForEach(HaloHUDPresentationTarget.allCases) { Text($0.title).tag($0) } }.frame(width: 160)
                    Button(role: .destructive) { var settings = hud.wrappedValue; settings.appRules.removeAll { $0.id == rule.id }; hud.wrappedValue = settings } label: { Image(systemName: "trash") }
                }
            }
            Button("Add Application Rule") { var settings = hud.wrappedValue; settings.appRules.append(HaloHUDAppRule()); hud.wrappedValue = settings }
            Text("Rules are persisted now so the presentation router can evolve without changing the settings format. The current hardware-key compatibility renderer still uses the resolved global presentation.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func colorSource(_ title: String, binding: Binding<HaloHUDDynamicColorSource>) -> some View {
        Picker(title, selection: binding) { ForEach(HaloHUDDynamicColorSource.allCases) { Text($0.title).tag($0) } }
    }
    private func appRuleBinding<T>(_ id: UUID, keyPath: WritableKeyPath<HaloHUDAppRule, T>) -> Binding<T> {
        Binding(get: {
            hud.wrappedValue.appRules.first(where: { $0.id == id })![keyPath: keyPath]
        }, set: { value in
            var settings = hud.wrappedValue
            guard let index = settings.appRules.firstIndex(where: { $0.id == id }) else { return }
            settings.appRules[index][keyPath: keyPath] = value; hud.wrappedValue = settings
        })
    }
    private func saveCustomPreset() {
        let name = customPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var settings = hud.wrappedValue
        settings.customPresets.append(HaloHUDPreset(id: UUID().uuidString, name: String(name.prefix(80)), builtIn: false, configuration: settings.global))
        hud.wrappedValue = settings
    }
    private func preview(_ kind: HaloHUDEventKind, persistent: Bool = false) {
        let settings = hud.wrappedValue
        let previewConfiguration = settings.configuration(for: kind)
        NotificationCenter.default.post(
            name: .init("HaloHUDPreview"),
            object: nil,
            userInfo: [
                "kind": kind.rawValue,
                "value": previewValue,
                "configuration": previewConfiguration,
                "persistent": persistent
            ]
        )
    }
    private func refreshPersistentPreview() {
        guard keepHUDVisibleWhileEditing, page == "HUD Studio" else { return }
        preview(selectedEvent, persistent: true)
    }
    private func stopPersistentPreview() {
        NotificationCenter.default.post(name: .init("HaloHUDPreviewExit"), object: nil)
    }
}

private struct HaloHUDStudioPreview: View {
    let kind: HaloHUDEventKind
    let value: Double
    let configuration: HaloHUDConfiguration
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var accent: Color {
        let c = configuration.appearance.primary
        switch c.source {
        case .systemAccent: return .accentColor
        case .automaticContrast, .systemAppearance: return .primary
        case .albumArtwork, .wallpaper: return .accentColor
        case .fixed: return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness, opacity: c.alpha)
        }
    }
    var body: some View {
        Group {
            if configuration.layout.style == .vertical {
                VStack(spacing: configuration.layout.spacing) { previewIcon; previewHeader; previewProgress }
            } else {
                HStack(spacing: configuration.layout.spacing) {
                    previewIcon
                    VStack(alignment: .leading, spacing: max(3, configuration.layout.spacing * 0.45)) { previewHeader; previewProgress }
                }
            }
        }
        .padding(.horizontal, configuration.layout.horizontalPadding)
        .padding(.vertical, configuration.layout.verticalPadding)
        .frame(width: min(520, max(100, configuration.layout.width)), height: min(220, max(36, configuration.layout.height)))
        .background { previewBackground }
        .clipShape(RoundedRectangle(cornerRadius: configuration.layout.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: configuration.layout.cornerRadius, style: .continuous).stroke(.white.opacity(configuration.appearance.border ? configuration.appearance.borderOpacity : 0)))
        .shadow(color: configuration.appearance.shadow ? .black.opacity(0.28) : .clear, radius: 16, y: 7)
        .animation(configuration.animation.progress == .instant ? nil : .easeOut(duration: 0.16), value: value)
    }
    @ViewBuilder private var previewIcon: some View {
        if configuration.components.icon { Image(systemName: kind.symbol).font(.system(size: configuration.iconSize, weight: .semibold)).foregroundStyle(accent) }
    }
    @ViewBuilder private var previewHeader: some View {
        HStack {
            if configuration.components.label { Text(kind.title).font(.system(size: configuration.textSize, weight: .semibold)) }
            Spacer()
            if configuration.components.value || configuration.components.percentage { Text("\(Int((value * 100).rounded()))%").font(.system(size: configuration.textSize, weight: .bold, design: .rounded)).monospacedDigit() }
        }
    }
    @ViewBuilder private var previewProgress: some View {
        if configuration.components.progress {
            switch configuration.progressStyle {
            case .segmentedBar, .dots:
                HStack(spacing: 2) { ForEach(0..<max(2, configuration.segments), id: \.self) { index in Capsule().fill(Double(index + 1) / Double(max(2, configuration.segments)) <= value ? accent : Color.secondary.opacity(0.2)).frame(height: configuration.progressStyle == .dots ? 5 : 7) } }
            case .ring, .arc, .gauge, .iconFill:
                ZStack { Circle().stroke(.secondary.opacity(0.2), lineWidth: 5); Circle().trim(from: 0, to: value).stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90)) }.frame(width: 34, height: 34)
            case .numberOnly:
                Text("\(Int(value * 100))").font(.system(size: configuration.textSize * 1.2, weight: .bold, design: .rounded)).foregroundStyle(accent)
            case .glow:
                Capsule().fill(accent.opacity(0.22)).overlay(alignment: .leading) { GeometryReader { p in Capsule().fill(accent).frame(width: max(2, p.size.width * value)).shadow(color: accent, radius: 7) } }.frame(height: 7)
            case .minimalLine:
                GeometryReader { p in Rectangle().fill(.secondary.opacity(0.18)).overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: p.size.width * value) } }.frame(height: 2)
            case .wave:
                HStack(alignment: .center, spacing: 2) { ForEach(0..<18, id: \.self) { i in Capsule().fill(accent.opacity(Double(i) / 18 <= value ? 1 : 0.22)).frame(width: 3, height: 4 + 12 * abs(sin(Double(i) * 0.8))) } }.frame(height: 18)
            default:
                GeometryReader { p in Capsule().fill(.secondary.opacity(0.18)).overlay(alignment: .leading) { Capsule().fill(accent).frame(width: max(2, p.size.width * value)) } }.frame(height: 7)
            }
        }
    }
    @ViewBuilder private var previewBackground: some View {
        if reduceTransparency || configuration.appearance.background == .solid { Color.black.opacity(max(0.5, configuration.appearance.backgroundOpacity)) }
        else if configuration.appearance.background == .clear { Color.clear }
        else if configuration.appearance.background == .gradient { LinearGradient(colors: [accent.opacity(0.55), .black.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing) }
        else { Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(max(0, configuration.appearance.backgroundOpacity - 0.45))) }
    }
}

private enum HaloAboutContent {
    static let description = "A customizable workspace for your Mac’s notch. Keep music, widgets and everyday controls within reach."
    static let creator = "Redstoneinvente"
    static let website = URL(string: "https://halo.redstoneinvente.com")!
    static let support = URL(string: "https://buymeacoffee.com/redstoneinvente")!
}
private struct HaloAboutView: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2" }
    var body: some View {
        Section {
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit().frame(width: 100, height: 100).accessibilityLabel("Halo app icon")
                Text("Halo").font(.largeTitle.bold())
                Text("Version \(version) · Build \(build)").font(.caption).foregroundStyle(.secondary)
                Text(HaloAboutContent.description).multilineTextAlignment(.center)
                Text("Created by \(HaloAboutContent.creator)").font(.callout).foregroundStyle(.secondary)
            }.padding(.vertical, 16).frame(maxWidth: .infinity)
        }
        Section("Find out more") {
            Link(destination: HaloAboutContent.website) { Label("Visit Halo’s website", systemImage: "globe") }
            Link(destination: HaloAboutContent.support) { Label("Buy me a coffee", systemImage: "cup.and.saucer.fill") }
        }
    }
}
