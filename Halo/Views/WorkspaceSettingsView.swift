import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var body: some View { WorkspaceSettingsView(store: store, workspace: store.workspace) }
}
struct WorkspaceSettingsView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @AppStorage("onboarded") private var onboarded = false
    @State private var section: String? = "General"
    @State private var search = ""
    @State private var profileName = "My profile"
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    private let sections = ["General", "Appearance", "Modules", "Media & Files", "Profiles", "Automation", "Displays", "Plugins", "Privacy", "Advanced"]
    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(sections.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { Text($0).tag($0) }
            }.searchable(text: $search, prompt: "Find a section").navigationSplitViewColumnWidth(170)
        } detail: {
            Form { content }.formStyle(.grouped).navigationTitle(section ?? "General")
        }.frame(minWidth: 700, minHeight: 560)
        .alert("Halo", isPresented: Binding(get: { store.error != nil || workspace.error != nil }, set: { if !$0 { store.error = nil; workspace.error = nil } })) {
            Button("OK") { store.error = nil; workspace.error = nil }
        } message: { Text(store.error ?? workspace.error ?? "") }
    }
    @ViewBuilder private var content: some View {
        switch section ?? "General" {
        case "General":
            Section("Welcome to Halo") {
                Text("Your workspace, within reach.").font(.title2.bold())
                Text("Hover to expand, click the top strip to toggle, right-click for profiles, and drag files onto the surface. Option–Command–Space toggles Halo by default.")
                Text("Detected \(NSScreen.screens.count) display(s); \(NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }.count) with a notch.")
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
        case "Appearance":
            Picker("Surface", selection: $store.configuration.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
            Slider(value: $store.configuration.theme.width, in: 340...640) { Text("Expanded width") }
            Slider(value: $workspace.settings.layout.appearance.expandedHeight, in: 280...800) { Text("Expanded height") }
            Slider(value: $workspace.settings.layout.appearance.compactWidth, in: 120...320) { Text("Compact width") }
            Slider(value: $store.configuration.theme.cornerRadius, in: 0...48) { Text("Corner radius") }
            Slider(value: $workspace.settings.layout.appearance.spacing, in: 4...28) { Text("Module spacing") }
            Slider(value: $store.configuration.theme.tint, in: 0...1) { Text("Accent hue") }
            Slider(value: $store.configuration.theme.opacity, in: 0.5...1) { Text("Opacity") }
            Section("Background") {
                Picker("Type", selection: $workspace.settings.layout.appearance.background) { ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Button("Choose image or video…") { workspace.chooseBackground() }
                Text(workspace.settings.layout.appearance.assetPath.isEmpty ? "No background file selected" : URL(fileURLWithPath: workspace.settings.layout.appearance.assetPath).lastPathComponent).font(.caption)
                Slider(value: $workspace.settings.layout.appearance.blur, in: 0...20) { Text("Blur") }
                Slider(value: $workspace.settings.layout.appearance.saturation, in: 0...2) { Text("Saturation") }
                Slider(value: $workspace.settings.layout.appearance.brightness, in: -0.5...0.5) { Text("Brightness") }
                Toggle("Pause video on battery", isOn: $workspace.settings.layout.appearance.pauseVideoOnBattery)
                Text("Video is muted, loops, and pauses when collapsed. Large videos and blur increase GPU use. Background files are referenced in place.").font(.caption)
            }
            Toggle("Animate expansion", isOn: $store.configuration.theme.animations)
            Picker("Animation timing", selection: $workspace.settings.layout.appearance.animation) { ForEach(AnimationPreset.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            HStack { Button("Import theme…") { store.importTheme() }; Button("Export theme…") { store.exportTheme() }; Button("Reset") { store.configuration.theme = Theme(); workspace.settings.layout.appearance = Appearance() } }
        case "Modules":
            Text("Enable modules and change their dashboard order.")
            ForEach(workspace.settings.layout.normalizedOrder()) { module in
                HStack {
                    Toggle(isOn: Binding(get: { workspace.settings.layout.enabled.contains(module) }, set: { value in
                        if value { workspace.settings.layout.enabled.insert(module) } else { workspace.settings.layout.enabled.remove(module) }
                    })) { Label(module.title, systemImage: module.symbol) }
                    Button { workspace.moveModule(module, by: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel("Move \(module.title) up")
                    Button { workspace.moveModule(module, by: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel("Move \(module.title) down")
                }
            }
        case "Media & Files":
            Picker("Music player", selection: $workspace.settings.mediaApp) { Text("Apple Music").tag("com.apple.Music"); Text("Spotify").tag("com.spotify.client") }
            Text("Press Connect in the media module to request Automation access. Halo controls only the selected running player. Browser playback is not supported.")
            Toggle("Keep shelf references between launches", isOn: $workspace.settings.persistShelf).onChange(of: workspace.settings.persistShelf) { _ in store.persistFiles() }
            Picker("Remove shelf references after", selection: $workspace.settings.shelfRetentionMinutes) { Text("Manually").tag(0); Text("5 minutes").tag(5); Text("30 minutes").tag(30); Text("1 hour").tag(60) }
            Text("Up to 100 references. Removing a shelf item never deletes its original. Retention age restarts at launch for restored references.")
            Button("Clear shelf references") { store.files = [] }
        case "Profiles":
            HStack { TextField("Profile name", text: $profileName); Button("Save current") { workspace.saveProfile(name: profileName, theme: store.configuration.theme) } }
            ForEach(workspace.settings.profiles) { profile in
                HStack {
                    Text(profile.name); Spacer(); Button("Apply") { workspace.apply(profile) }
                    Button("Duplicate") { var copy = profile; copy.id = UUID(); copy.name += " copy"; workspace.settings.profiles.append(copy) }
                    Button("Delete") { workspace.deleteProfile(profile.id) }
                }
            }
            Text("Profiles save modules, appearance, and theme. They never enable clipboard capture or grant permissions.").font(.caption)
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
                        Slider(value: $workspace.settings.displays[index].theme.width, in: 340...640) { Text("Width") }
                        Slider(value: $workspace.settings.displays[index].theme.tint, in: 0...1) { Text("Accent") }
                        Menu("Use a profile on this display") {
                            ForEach(workspace.settings.profiles) { profile in
                                Button(profile.name) { workspace.settings.displays[index].theme = profile.theme; workspace.settings.displays[index].layout = profile.layout }
                            }
                        }
                        Button("Follow global modules and background") { workspace.settings.displays[index].layout = nil }
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
                Text("Automation is requested only by media controls. Screen Recording is requested only when you capture a region. Microphone and Accessibility are not requested. OCR runs on-device. No analytics or background network services. Plugin URLs open only after confirmation.")
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
