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
    @AppStorage("HaloOpenKeepClosedNotchContents") private var keepClosedContentsWhenOpen = false
    @State private var section: String? = "General"
    @State private var search = ""
    @State private var profileName = "My profile"
    @State private var renamingProfile: UUID?
    @State private var renamedProfile = ""
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    private let sections = ["General", "Account & License", "Appearance", "Modules", "Widgets", "Closed notch", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "About"]
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
        case "Account & License": return "person.crop.circle.badge.checkmark"
        case "Appearance": return "paintpalette"
        case "Modules": return "square.grid.2x2"
        case "Widgets": return "slider.horizontal.3"
        case "Context Notch Interface": return "rectangle.stack"
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
        case "Account & License": HaloAccountLicenseSettingsView()
        case "Schedules": ScheduleSettingsView(workspace: workspace)
        case "Appearance": AppearanceSettingsPane(store: store, workspace: workspace)
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
        case "Context Notch Interface": ContextInterfaceLibraryView(layout: $workspace.settings.layout)
        case "Media & Files":
            Section("Media source") {
                Picker("Source", selection: Binding(
                    get: {
                        if workspace.settings.automaticMedia ?? true { return "__automatic__" }
                        return workspace.settings.mediaApp
                    },
                    set: { source in
                        if source == "__automatic__" {
                            workspace.settings.automaticMedia = true
                            if workspace.settings.mediaApp == WorkspaceStore.systemAudioSource {
                                workspace.settings.mediaApp = "com.apple.Music"
                            }
                        } else {
                            workspace.settings.automaticMedia = false
                            workspace.settings.mediaApp = source
                        }
                        workspace.refreshMediaSource()
                    }
                )) {
                    Text("Automatic").tag("__automatic__")
                    Text("Apple Music").tag("com.apple.Music")
                    Text("Spotify").tag("com.spotify.client")
                    Text("System Audio").tag(WorkspaceStore.systemAudioSource)
                }

                if !(workspace.settings.automaticMedia ?? true) && workspace.settings.mediaApp == WorkspaceStore.systemAudioSource {
                    Label(
                        workspace.media.isPlaying && workspace.media.connectedApp == nil ? "System Audio detected" : "Waiting for System Audio",
                        systemImage: workspace.media.isPlaying && workspace.media.connectedApp == nil ? "waveform.circle.fill" : "waveform.circle"
                    )
                    Text("System Audio listens to your Mac's output through Screen Recording permission. It works with browser video, VLC, games and other apps, and can drive Halo's visualizers, reactive backgrounds and Context Notch. Generic system audio does not provide universal song title, artist, artwork, lyrics, seeking or track controls.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if workspace.settings.automaticMedia ?? true {
                    Text("Automatic prefers rich Apple Music or Spotify metadata when either is playing, then falls back to System Audio for anything else playing on your Mac. The fallback can drive playback-aware Halo features even when track metadata is unavailable.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Apple Music and Spotify provide rich metadata, artwork, playback controls and lyrics when available. macOS may ask for Automation permission the first time Halo connects to a player.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle("Keep shelf references between launches", isOn: $workspace.settings.persistShelf).onChange(of: workspace.settings.persistShelf) { _ in store.persistFiles() }
            Picker("Remove shelf references after", selection: $workspace.settings.shelfRetentionMinutes) { Text("Manually").tag(0); Text("5 minutes").tag(5); Text("30 minutes").tag(30); Text("1 hour").tag(60) }
            Text("Up to 100 references. Pinned items do not expire. Saved references keep their original retention age after relaunch. Removing a shelf item never deletes its original.").font(.caption)
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
        case "Displays": DisplaySettingsPane(store: store, workspace: workspace)
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
                Text("Automation is requested when detecting or controlling Apple Music or Spotify. System Audio uses Screen Recording permission to analyse the Mac's output audio. Screen Recording is also requested when you capture a region. Microphone and Accessibility are not requested. Bluetooth state is read only when the Bluetooth CI/connection-state features are used. No analytics. Enabling artwork colors downloads Spotify artwork; Apple Music artwork is read from the player. Plugin URLs open only after confirmation.")
                Text("This direct-distribution build is not sandboxed. Files and notes are stored locally.")
            }
        default: HaloAboutView()
        }
    }
}

private enum HaloAppearancePage: String, CaseIterable, Identifiable {
    case openedSpace = "Opened Space"
    case basics = "Basics"
    case surface = "Surface"
    case background = "Background"
    case motion = "Motion"
    var id: String { rawValue }
}

@MainActor private struct AppearanceSettingsPane: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore
    @AppStorage("HaloOpenKeepClosedNotchContents") private var keepClosedContentsWhenOpen = false
    @State private var page: HaloAppearancePage = .openedSpace
    @State private var showingOpenWorkspaceEditor = false

    var body: some View {
        Picker("Appearance area", selection: $page) {
            ForEach(HaloAppearancePage.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)

        switch page {
        case .openedSpace: openedSpace
        case .basics: basics
        case .surface: surface
        case .background: background
        case .motion: motion
        }
    }

    @ViewBuilder private var openedSpace: some View {
        Section("Opened notch space") {
            Picker("Layout system", selection: Binding(
                get: { workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace ? "visual" : "default" },
                set: { workspace.settings.layout.setCustomOpenNotchWorkspaceEnabled($0 == "visual") }
            )) {
                Text("Default").tag("default")
                Text("Visual Workspace").tag("visual")
            }
            .pickerStyle(.segmented)

            Text(workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace
                 ? "Visual Workspace uses your designed regions, groups and responsive widget slots. Your Default layout stays saved separately and returns unchanged when you switch back."
                 : "Default keeps Halo's classic opened-notch layout. Switching to Visual Workspace does not erase these settings.")
                .font(.caption).foregroundStyle(.secondary)

            Picker("Space behavior", selection: openedSpaceModeBinding) {
                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace {
                switch workspace.settings.layout.resolvedOpenNotchLayout.resolvedContentMode {
                case .fixed:
                    Text("Fixed uses the region sizes and row/column proportions from the Visual Workspace Editor and keeps everything inside one designed canvas.")
                        .font(.caption).foregroundStyle(.secondary)
                case .scroll:
                    Text("Scroll keeps your visual workspace structure while allowing its content to move inside the opened notch when it needs more room.")
                        .font(.caption).foregroundStyle(.secondary)
                case .pages:
                    Text("Pages presents the designed workspace one group at a time with previous/next navigation.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button { showingOpenWorkspaceEditor = true } label: {
                    Label("Open Visual Workspace Editor…", systemImage: "rectangle.3.group")
                }
                .sheet(isPresented: $showingOpenWorkspaceEditor) {
                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout)
                        .frame(minWidth: 980, idealWidth: 1120, minHeight: 680, idealHeight: 760)
                }
            } else {
                switch workspace.settings.layout.resolvedOpenNotchContentMode {
                case .fixed:
                    Picker("Fixed canvas columns", selection: Binding(
                        get: { workspace.settings.layout.resolvedOpenFixedColumns },
                        set: { workspace.settings.layout.openFixedColumns = $0 }
                    )) {
                        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                    }
                    Text("All enabled widgets stay inside one fixed canvas. Halo divides the available height between rows instead of scrolling.")
                        .font(.caption).foregroundStyle(.secondary)
                case .scroll:
                    Picker("Scroll direction", selection: Binding(
                        get: { workspace.settings.layout.horizontalWidgets ?? false },
                        set: { workspace.settings.layout.horizontalWidgets = $0; workspace.settings.layout.horizontalPages = false }
                    )) {
                        Text("Vertical").tag(false)
                        Text("Horizontal").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text("Scroll keeps the notch size fixed while letting widgets move inside it.")
                        .font(.caption).foregroundStyle(.secondary)
                case .pages:
                    Text("Pages keeps one widget in focus at a time with previous/next navigation.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }

        Section("Opened notch behavior") {
            Toggle("Keep closed-notch contents visible when opened", isOn: $keepClosedContentsWhenOpen)
            Text("Keeps the normal Closed Notch widgets and media visible in the top strip. Context Interfaces keep their own layout rules.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var openedSpaceModeBinding: Binding<OpenNotchContentMode> {
        Binding(
            get: {
                if workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace {
                    return workspace.settings.layout.resolvedOpenNotchLayout.resolvedContentMode
                }
                return workspace.settings.layout.resolvedOpenNotchContentMode
            },
            set: { mode in
                if workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace {
                    workspace.settings.layout.materializeOpenNotchLayout()
                    var opened = workspace.settings.layout.resolvedOpenNotchLayout
                    opened.contentMode = mode
                    workspace.settings.layout.openNotch = opened
                } else {
                    workspace.settings.layout.openNotchContentMode = mode
                    workspace.settings.layout.horizontalPages = mode == .pages
                    if mode == .pages { workspace.settings.layout.horizontalWidgets = true }
                }
            }
        )
    }

    @ViewBuilder private var basics: some View {
        Section("Opened notch size & spacing") {
            Slider(value: $store.configuration.theme.width, in: 340...1200, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Opened width") }
            Slider(value: $workspace.settings.layout.appearance.expandedHeight, in: 280...1100, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Opened height") }
            Slider(value: Binding(
                get: { workspace.settings.layout.resolvedOpenHorizontalPadding },
                set: { workspace.settings.layout.openHorizontalPadding = $0 }
            ), in: 8...72) { Text("Side padding") }
            Slider(value: Binding(
                get: { workspace.settings.layout.resolvedOpenVerticalPadding },
                set: { workspace.settings.layout.openVerticalPadding = $0 }
            ), in: 8...72) { Text("Top & bottom padding") }
            Slider(value: $workspace.settings.layout.appearance.spacing, in: 4...40) { Text("Module spacing") }
            Text("Width is still limited by the display. Lower padding gives widgets more breathing room without changing the outer notch shape.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Surface basics") {
            Picker("Surface", selection: $store.configuration.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
            Slider(value: $store.configuration.theme.cornerRadius, in: 0...48) { Text("Corner radius") }
            Slider(value: $store.configuration.theme.tint, in: 0...1) { Text("Accent hue") }
            Slider(value: $store.configuration.theme.opacity, in: 0.5...1) { Text("Opacity") }
        }
    }

    @ViewBuilder private var surface: some View {
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .geometry
        )
    }

    @ViewBuilder private var background: some View {
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .background
        )
        Section("Background effects") {
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
    }

    @ViewBuilder private var motion: some View {
        Section("Animation") {
            Toggle("Animate expansion", isOn: $store.configuration.theme.animations)
            Picker("Animation timing", selection: Binding(get: { workspace.settings.layout.appearance.animation.rawValue }, set: { if let v = AnimationPreset(rawValue: $0) { workspace.settings.layout.appearance.animation = v } })) {
                ForEach(AnimationPreset.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0.rawValue) }
            }
        }
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .motion
        )
        Section("Theme tools") {
            HStack {
                Button("Import theme…") { store.importTheme() }
                Button("Export theme…") { store.exportTheme() }
                Button("Reset") { store.configuration.theme = Theme(); workspace.settings.layout.appearance = Appearance() }
            }
        }
    }
}

@MainActor private struct DisplaySettingsPane: View {
    @ObservedObject var store: AppStore
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Toggle("Show on all displays", isOn: $store.configuration.allDisplays)
        ForEach(NSScreen.screens, id: \.localizedName) { screen in
            let id = WindowManager.displayID(screen)
            Section(screen.localizedName) {
                if let index = workspace.settings.displays.firstIndex(where: { $0.id == id }) {
                    Toggle("Show Halo here", isOn: $workspace.settings.displays[index].enabled)
                    if let profileID = workspace.settings.displays[index].profileID,
                       let profile = workspace.settings.profiles.first(where: { $0.id == profileID }) {
                        Picker("Display profile", selection: Binding(
                            get: { workspace.settings.displays[index].profileID ?? profileID },
                            set: { workspace.settings.displays[index].profileID = $0 }
                        )) {
                            ForEach(workspace.settings.profiles) { Text($0.name).tag($0.id) }
                        }
                        Text("This display follows \(profile.name) live. Editing that profile updates this display too.").font(.caption).foregroundStyle(.secondary)
                        Button("Customize this display instead") {
                            workspace.settings.displays[index].theme = profile.theme
                            workspace.settings.displays[index].layout = profile.layout
                            workspace.settings.displays[index].profileID = nil
                        }
                        Button("Follow global profile") { workspace.settings.displays.removeAll { $0.id == id } }
                    } else {
                        Picker("Style", selection: $workspace.settings.displays[index].theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }
                        Slider(value: $workspace.settings.displays[index].theme.width, in: 340...640, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0, display: screen) }) { Text("Width") }
                        Slider(value: $workspace.settings.displays[index].theme.tint, in: 0...1) { Text("Accent") }
                        Menu("Use a profile on this display") {
                            ForEach(workspace.settings.profiles) { profile in
                                Button(profile.name) {
                                    workspace.settings.displays[index].profileID = profile.id
                                    workspace.settings.displays[index].theme = profile.theme
                                    workspace.settings.displays[index].layout = nil
                                }
                            }
                        }
                        Button("Follow global modules and background") {
                            workspace.settings.displays[index].profileID = nil
                            workspace.settings.displays[index].layout = nil
                        }
                        if workspace.settings.displays[index].layout != nil {
                            SurfaceAppearanceControls(
                                appearance: Binding(
                                    get: { workspace.settings.displays[index].layout?.appearance ?? workspace.settings.layout.appearance },
                                    set: { workspace.settings.displays[index].layout?.appearance = $0 }
                                ),
                                theme: workspace.settings.displays[index].theme,
                                screen: screen,
                                scope: .geometry
                            )
                        } else {
                            Button("Customize closed size, shape and position here") {
                                workspace.settings.displays[index].layout = workspace.settings.layout
                            }
                        }
                        Button("Use global theme") { workspace.settings.displays.removeAll { $0.id == id } }
                    }
                } else {
                    Button("Customize this display") { workspace.settings.displays.append(DisplayOverride(id: id, theme: store.configuration.theme)) }
                }
            }
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
                    Slider(value: $profile.theme.width, in: 340...1200) { Text("Opened width") }
                    Picker("Opened content", selection: Binding(
                        get: { profile.layout.resolvedOpenNotchContentMode },
                        set: { mode in
                            profile.layout.openNotchContentMode = mode
                            profile.layout.horizontalPages = mode == .pages
                            if mode == .pages { profile.layout.horizontalWidgets = true }
                        }
                    )) {
                        ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if profile.layout.resolvedOpenNotchContentMode == .fixed {
                        Picker("Fixed canvas columns", selection: Binding(
                            get: { profile.layout.resolvedOpenFixedColumns },
                            set: { profile.layout.openFixedColumns = $0 }
                        )) {
                            ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                        }
                    } else if profile.layout.resolvedOpenNotchContentMode == .scroll {
                        Picker("Scroll direction", selection: Binding(
                            get: { profile.layout.horizontalWidgets ?? false },
                            set: { profile.layout.horizontalWidgets = $0; profile.layout.horizontalPages = false }
                        )) {
                            Text("Vertical").tag(false)
                            Text("Horizontal").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    Slider(value: Binding(
                        get: { profile.layout.resolvedOpenHorizontalPadding },
                        set: { profile.layout.openHorizontalPadding = $0 }
                    ), in: 8...72) { Text("Side padding") }
                    Slider(value: Binding(
                        get: { profile.layout.resolvedOpenVerticalPadding },
                        set: { profile.layout.openVerticalPadding = $0 }
                    ), in: 8...72) { Text("Top & bottom padding") }
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
                        Slider(value: $profile.layout.appearance.expandedHeight, in: 280...1100) { Text("Opened height") }
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

private enum ContextInterfaceSelection: String, Identifiable {
    case drop, music, bluetooth, retro
    var id: String { rawValue }
}

private struct ContextInterfaceLibraryView: View {
    @Binding var layout: WorkspaceLayout
    @State private var selection: ContextInterfaceSelection?
    @AppStorage("HaloContextDropEnabled") private var dropEnabled = true
    @AppStorage("HaloContextBluetoothEnabled") private var bluetoothEnabled = false
    @AppStorage("HaloContextRetroEnabled") private var retroEnabled = false

    private var musicEnabled: Bool { layout.contextMusic?.enabled ?? false }

    @ViewBuilder var body: some View {
        if selection == .drop {
            Section {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = nil }
                    } label: {
                        Label("All CI", systemImage: "chevron.left")
                    }
                    Spacer()
                    Label("Drop CI", systemImage: "tray.and.arrow.down.fill")
                        .font(.headline)
                }
            }
            ContextDropSettings()
        } else if selection == .music {
            Section {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = nil }
                    } label: {
                        Label("All CI", systemImage: "chevron.left")
                    }
                    Spacer()
                    Label("Music CI", systemImage: "music.note")
                        .font(.headline)
                }
            }
            ContextMusicSettings(layout: $layout)
        } else if selection == .bluetooth {
            Section {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = nil }
                    } label: {
                        Label("All CI", systemImage: "chevron.left")
                    }
                    Spacer()
                    Label("Bluetooth CI", systemImage: "wave.3.right")
                        .font(.headline)
                }
            }
            ContextBluetoothSettings()
        } else if selection == .retro {
            Section {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = nil }
                    } label: {
                        Label("All CI", systemImage: "chevron.left")
                    }
                    Spacer()
                    Label("Retro Game CI", systemImage: "gamecontroller.fill")
                        .font(.headline)
                }
            }
            ContextRetroGameSettings()
        } else {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Context Notch Interfaces").font(.title2.bold())
                    Text("CI changes what Halo becomes when the notch opens. Choose an interface to configure its content, behaviour and visual style.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Available CI") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], alignment: .leading, spacing: 14) {
                    DropContextInterfaceCard(enabled: dropEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .drop }
                    }
                    ContextInterfaceCard(enabled: musicEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .music }
                    }
                    BluetoothContextInterfaceCard(enabled: bluetoothEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .bluetooth }
                    }
                    RetroGameContextInterfaceCard(enabled: retroEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .retro }
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Label("CI can react to live system context without turning the notch into one giant settings page.", systemImage: "rectangle.stack.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DropContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextDropPriority") private var priority = 100.0
    @ObservedObject private var zones = HaloDropZoneSettingsStore.shared
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentColor.opacity(0.24), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .padding(15)
                    VStack(spacing: 7) {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("DROP FILES HERE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
                .frame(height: 112)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Drop CI").font(.headline)
                        Text("Files & Folders").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }

                Text("A customizable action board that appears when you start dragging a real file or folder, with up to 8 live drop zones.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)

                HStack {
                    Label("\(zones.configuration.zones.count) zone\(zones.configuration.zones.count == 1 ? "" : "s")", systemImage: "square.grid.2x2")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("Priority \(Int(priority))")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Label("Edit", systemImage: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
    }
}

private struct ContextDropSettings: View {
    @ObservedObject private var zones = HaloDropZoneSettingsStore.shared
    @AppStorage("HaloContextDropEnabled") private var enabled = true
    @AppStorage("HaloContextDropUseFullNotchArea") private var usesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextDropPriority") private var priority = 100.0

    var body: some View {
        Section("Drag & Drop Context Interface") {
            Toggle("Enable Drop CI", isOn: $enabled)
            Text("Start dragging a real file or folder anywhere on your Mac and Halo can summon Drop CI immediately. The cursor does not need to reach the notch first.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Drop zones") {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(zones.configuration.zones.count) custom zone\(zones.configuration.zones.count == 1 ? "" : "s")")
                        .font(.headline)
                    Text("\(zones.configuration.layout.rawValue) layout · click-to-edit live preview")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Customize Drop CI…") {
                    HaloDropZoneStudioWindowController.shared.show()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)

            HStack(spacing: 7) {
                ForEach(Array(zones.configuration.zones.prefix(5))) { zone in
                    Label(zone.title.isEmpty ? zone.action.rawValue : zone.title,
                          systemImage: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(zone.color.color.opacity(0.09), in: Capsule())
                        .foregroundStyle(zone.color.color)
                }
                if zones.configuration.zones.count > 5 {
                    Text("+\(zones.configuration.zones.count - 5)")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            Text("The studio gives you visual presets, a live clickable preview, per-zone actions and filters, custom labels/icons/colors, reorder controls, and advanced appearance only when you want it.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Drop CI priority") }
            Text("Drop CI defaults to the highest priority because a drag is an immediate user action. Lower it if another Context Interface should keep ownership during file drags.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI surface") {
            Toggle("Use full notch area", isOn: $usesFullNotchArea)
            Toggle("Keep closed-notch contents visible", isOn: $keepsClosedNotchContents)
            Text("Halo automatically requests the space needed by your chosen zone layout.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Safety") {
            Label("Only genuine file/folder drag payloads can summon Drop CI.", systemImage: "checkmark.shield")
            Label("Destructive actions are clearly marked and never added by a preset unless you choose them.", systemImage: "lock.shield")
        }
    }
}

private struct ContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextMusicPriority") private var priority = 60.0
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.94))
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(colors: [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 62, height: 62)
                            .overlay(Image(systemName: "music.note").font(.title2.weight(.semibold)).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 7) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.9)).frame(width: 96, height: 7)
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.42)).frame(width: 68, height: 5)
                            HStack(spacing: 7) {
                                Image(systemName: "backward.fill")
                                Image(systemName: "play.fill")
                                Image(systemName: "forward.fill")
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.88))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                }
                .frame(height: 112)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Music CI").font(.headline)
                        Text("Now Playing").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }

                Text("A playback-aware interface for artwork, controls, lyrics, visualizers and song-reactive colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                HStack {
                    Label(layoutSummary, systemImage: "rectangle.3.group")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Priority \(Int(priority))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("Edit", systemImage: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
    }

    private var layoutSummary: String {
        let mode = ContextMusicOptions().resolvedLayoutMode
        return mode.title
    }
}

private struct ContextMusicSettings: View {
    @Binding var layout: WorkspaceLayout
    @AppStorage("HaloContextMusicUseFullNotchArea") private var useFullNotchArea = false
    @AppStorage("HaloContextMusicKeepClosedNotchContents") private var keepClosedNotchContents = false
    @AppStorage("HaloContextMusicPriority") private var priority = 60.0
    private var options: Binding<ContextMusicOptions> { Binding(get: { layout.contextMusic ?? ContextMusicOptions() }, set: { layout.contextMusic = $0 }) }
    private var layoutMode: Binding<ContextMusicLayoutMode> { Binding(get: { options.wrappedValue.resolvedLayoutMode }, set: { options.wrappedValue.layoutMode = $0 }) }
    private var foregroundArtwork: Binding<ContextArtworkPresentation> {
        Binding(get: { options.wrappedValue.resolvedForegroundArtwork }, set: { value in
            var updated = options.wrappedValue
            updated.foregroundArtwork = value
            updated.showArtwork = value != .none
            options.wrappedValue = updated
        })
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
    private var horizontalMargin: Binding<Double> { Binding(get: { options.wrappedValue.resolvedHorizontalMargin }, set: { options.wrappedValue.horizontalMargin = $0 }) }
    private var topMargin: Binding<Double> { Binding(get: { options.wrappedValue.resolvedTopMargin }, set: { options.wrappedValue.topMargin = $0 }) }
    private var bottomMargin: Binding<Double> { Binding(get: { options.wrappedValue.resolvedBottomMargin }, set: { options.wrappedValue.bottomMargin = $0 }) }
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

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Music CI priority") }
            Text("When multiple Context Interfaces are eligible, Halo gives the surface to the eligible CI with the highest priority.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI surface") {
            Toggle("Use full notch area", isOn: $useFullNotchArea)
            Text(useFullNotchArea ? "Music CI owns the entire expanded Halo surface, including the area normally reserved for the top notch strip." : "Music CI starts below the notch/top strip, preserving the current expanded layout.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Keep closed-notch contents visible", isOn: $keepClosedNotchContents)
            Text("Controls whether the Closed Notch contents remain visible while Music CI is active. This setting is independent from the normal opened-notch Appearance setting.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Content safe margins").font(.headline)
            PreciseSlider(title: "Horizontal margin", value: horizontalMargin, range: 0...120, step: 1, suffix: "pt")
            PreciseSlider(title: "Extra top margin", value: topMargin, range: 0...160, step: 1, suffix: "pt")
            PreciseSlider(title: "Bottom margin", value: bottomMargin, range: 0...120, step: 1, suffix: "pt")
            Text("Margins are included in the CI's requested surface size, so increasing them moves content inward instead of clipping it outside the notch.")
                .font(.caption).foregroundStyle(.secondary)
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
    private var notchConfiguration: Binding<HaloHUDNotchConfiguration> {
        Binding(get: { configuration.wrappedValue.presentation.resolvedNotch }, set: { value in
            var updated = configuration.wrappedValue
            updated.presentation.notch = value
            configuration.wrappedValue = updated
        })
    }
    private var verticalNotchExpansion: Binding<Bool> {
        Binding(get: { notchConfiguration.wrappedValue.usesVerticalExpansion }, set: { enabled in
            var value = notchConfiguration.wrappedValue
            value.expandVertically = enabled
            notchConfiguration.wrappedValue = value
        })
    }
    private var verticalNotchHeight: Binding<Double> {
        Binding(get: { notchConfiguration.wrappedValue.resolvedVerticalHeight }, set: { height in
            var value = notchConfiguration.wrappedValue
            value.verticalHeight = height
            notchConfiguration.wrappedValue = value
        })
    }
    private var isNotchTarget: Bool { configuration.wrappedValue.presentation.target == .notch }

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
            Label("Volume, mute, display brightness and keyboard brightness are connected to Halo's safe key-observer/replacement path.", systemImage: "checkmark.seal.fill")
            Label("Observer-capable events use public or stable data paths. Events marked Provider not connected are configuration-ready but do not generate real system events yet.", systemImage: "shield.lefthalf.filled")
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
            HStack {
                Text(selectedEvent.providerStatus.title).font(.caption).foregroundStyle(selectedEvent.providerStatus == .available ? .green : .secondary)
                Spacer()
                if selectedEvent.providerStatus == .architected { Text("Preview only until a provider is connected").font(.caption).foregroundStyle(.orange) }
            }
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
                Button("Test Entrance") { preview(selectedEvent, persistent: keepHUDVisibleWhileEditing, restart: true) }
                Button("Test Exit") { stopPersistentPreview() }
            }
        }

        Section("Presentation") {
            Picker("Target", selection: configuration.presentation.target) { ForEach(HaloHUDPresentationTarget.allCases) { Text($0.title).tag($0) } }
            Picker("Display", selection: configuration.presentation.displayTarget) { ForEach(HaloHUDDisplayTarget.allCases) { Text($0.title).tag($0) } }
            switch configuration.wrappedValue.presentation.target {
            case .notch:
                Picker("Notch side", selection: configuration.presentation.notchSide) { ForEach(HaloHUDNotchSide.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Toggle("Expand notch vertically", isOn: verticalNotchExpansion)
                if verticalNotchExpansion.wrappedValue {
                    Slider(value: verticalNotchHeight, in: 56...220) { Text("Vertical HUD height") }
                    Text("Vertical mode keeps the normal closed-notch width and grows the surface downward for the HUD instead of reserving extra left/right wing width.").font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("Collision", selection: configuration.behavior.collision) { ForEach(HaloHUDCollisionBehavior.allCases) { Text($0.title).tag($0) } }
                    Text("Horizontal mode expands the chosen notch side outward without changing the closed-notch height.").font(.caption).foregroundStyle(.secondary)
                }
                Divider()
                Text("Notch HUD customization").font(.headline)
                Slider(value: notchConfiguration.width, in: 48...600) { Text("HUD width") }
                Slider(value: notchConfiguration.horizontalPadding, in: 0...40) { Text("Horizontal padding") }
                Slider(value: notchConfiguration.spacing, in: 0...32) { Text("Content spacing") }
                Slider(value: notchConfiguration.horizontalOffset, in: -300...300) { Text("Horizontal offset") }
                Slider(value: notchConfiguration.iconSize, in: 8...32) { Text("Icon size") }
                Slider(value: notchConfiguration.textSize, in: 8...24) { Text("Text size") }
                Slider(value: notchConfiguration.progressWidth, in: 20...220) { Text("Progress width") }
                Text("These values are stored separately from the normal floating HUD layout and are used only when Target is Notch.").font(.caption).foregroundStyle(.secondary)
            case .floating:
                Picker("Position", selection: configuration.presentation.floatingPosition) { ForEach(HaloHUDFloatingPosition.allCases) { Text($0.title).tag($0) } }
            case .screenEdge:
                Picker("Edge", selection: configuration.presentation.screenEdge) { ForEach(HaloHUDScreenEdge.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Slider(value: configuration.presentation.screenEdgeLength, in: 40...800) { Text("Length") }
                Slider(value: configuration.presentation.screenEdgeThickness, in: 1...24) { Text("Thickness") }
            case .menuBar:
                Text("Menu Bar uses the system status-item renderer. Layout dimensions and panel background effects do not apply to a menu-bar item.").font(.caption).foregroundStyle(.secondary)
            case .nearCursor:
                Text("Near Cursor uses the configured offsets and edge margin while keeping the HUD inside the selected display.").font(.caption).foregroundStyle(.secondary)
            case .disabled:
                Text("This event will not be presented.").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Fallback target", selection: configuration.behavior.fallbackTarget) { ForEach(HaloHUDPresentationTarget.allCases.filter { $0 != .disabled }) { Text($0.title).tag($0) } }
        }

        Section("Layout") {
            if isNotchTarget {
                Text(verticalNotchExpansion.wrappedValue ? "The Notch target keeps its compact HUD styling while the closed surface grows to the Vertical HUD height. Generic floating height, vertical padding, Y offset and panel layout settings do not apply here." : "The Notch target uses a compact horizontal HUD inside the current Closed Notch height. Generic height, vertical padding, Y offset, corner radius and panel layout settings do not apply here.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
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
        }

        Section("Components") {
            Toggle("Icon", isOn: configuration.components.icon)
            Toggle("Label", isOn: configuration.components.label)
            Toggle("Numeric value", isOn: configuration.components.value)
            Toggle("Percentage", isOn: configuration.components.percentage)
            Toggle("Progress visualization", isOn: configuration.components.progress)
            Toggle("Device name / detail", isOn: configuration.components.deviceName)
            if configuration.wrappedValue.components.progress {
                Picker("Progress style", selection: configuration.progressStyle) { ForEach(HaloHUDProgressStyle.allCases) { Text($0.title).tag($0) } }
                if configuration.wrappedValue.progressStyle == .segmentedBar || configuration.wrappedValue.progressStyle == .dots {
                    Stepper("Segments / dots: \(configuration.wrappedValue.segments)", value: configuration.segments, in: 2...64)
                }
            }
            if !isNotchTarget {
                Slider(value: configuration.iconSize, in: 8...96) { Text("Icon size") }
                Slider(value: configuration.textSize, in: 8...64) { Text("Text size") }
            }
        }

        Section("Appearance") {
            if isNotchTarget {
                Text("Notch HUD reuses the existing Closed Notch surface. It does not draw its own background, border, shadow, glow or blur, so the HUD stays visually integrated with closed mode.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Background", selection: configuration.appearance.background) {
                    ForEach(HaloHUDBackgroundStyle.allCases) { style in
                        Text(style.title + ((style == .image || style == .video) ? " · unavailable" : ""))
                            .tag(style)
                            .disabled(style == .image || style == .video)
                    }
                }
                if configuration.wrappedValue.appearance.background == .image || configuration.wrappedValue.appearance.background == .video {
                    Text("This saved HUD uses an asset-backed background type from the model, but HUD asset-path persistence is not connected yet. Halo renders a styled fallback until that provider is implemented.").font(.caption).foregroundStyle(.orange)
                }
                Slider(value: configuration.appearance.backgroundOpacity, in: 0...1) { Text("Background opacity") }
                Slider(value: configuration.appearance.blur, in: 0...60) { Text("Blur") }
                if configuration.wrappedValue.appearance.background == .glass { Slider(value: configuration.appearance.glassIntensity, in: 0...1) { Text("Glass intensity") } }
                Toggle("Border", isOn: configuration.appearance.border)
                if configuration.wrappedValue.appearance.border { Slider(value: configuration.appearance.borderOpacity, in: 0...1) { Text("Border opacity") } }
                Toggle("Shadow", isOn: configuration.appearance.shadow)
                Toggle("Glow", isOn: configuration.appearance.glow)
                Toggle("Noise", isOn: configuration.appearance.noise)
            }
        }

        Section("Dynamic Colors") {
            colorSource("Primary", binding: configuration.appearance.primary)
            colorSource("Secondary", binding: configuration.appearance.secondary)
            colorSource("Progress", binding: configuration.appearance.progress)
            if !isNotchTarget {
                colorSource("Border", binding: configuration.appearance.borderColor)
                colorSource("Glow", binding: configuration.appearance.glowColor)
            }
            Text("Album Artwork uses the current media palette when available. Wallpaper sampling is reserved in the model but is not connected yet and therefore falls back to the system accent.").font(.caption).foregroundStyle(.secondary)
        }

        Section("Animation") {
            if isNotchTarget {
                Text(verticalNotchExpansion.wrappedValue ? "Vertical notch mode animates the closed surface height while keeping it anchored to the physical top edge." : "Horizontal notch mode resizes the chosen wing while staying inside the closed-notch strip.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Entrance", selection: configuration.animation.entrance) { ForEach(HaloHUDEntranceAnimation.allCases) { Text($0.title).tag($0) } }
                Picker("Exit", selection: configuration.animation.exit) { ForEach(HaloHUDExitAnimation.allCases) { Text($0.title).tag($0) } }
            }
            Slider(value: configuration.animation.entranceDuration, in: 0...1.5) { Text("Entrance duration") }
            Slider(value: configuration.animation.exitDuration, in: 0...1.5) { Text("Exit duration") }
            if !isNotchTarget && configuration.wrappedValue.animation.entrance == .spring {
                Slider(value: configuration.animation.springDamping, in: 0.1...1) { Text("Spring damping") }
                Slider(value: configuration.animation.springStiffness, in: 20...600) { Text("Spring stiffness") }
            }
            Picker("Progress animation", selection: configuration.animation.progress) { ForEach(HaloHUDProgressAnimation.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            if !isNotchTarget { Slider(value: configuration.animation.intensity, in: 0...1) { Text("Animation intensity") } }
        }

        Section("Behaviour") {
            Slider(value: configuration.behavior.displayDuration, in: 0.2...6) { Text("Display duration") }
            Picker("Repeated events", selection: configuration.behavior.interrupt) { ForEach(HaloHUDInterruptBehavior.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            if !isNotchTarget {
                Picker("Collision behaviour", selection: configuration.behavior.collision) { ForEach(HaloHUDCollisionBehavior.allCases) { Text($0.title).tag($0) } }
            }
            Text("Restart replays the entrance and restarts the dismissal timer. Continue updates the value without extending the current lifetime. Blend updates in place and extends the dismissal timer.").font(.caption).foregroundStyle(.secondary)
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
            Text("Available means Halo can safely observe and optionally replace the related native hardware-key HUD. Observer-capable means Halo has a stable data/event source but does not suppress a native HUD. Provider not connected means only the event configuration and preview exist today.").font(.caption).foregroundStyle(.secondary)
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
            Text("Application rules currently override presentation target only; all visual settings still resolve from the selected event/global HUD configuration.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func colorSource(_ title: String, binding: Binding<HaloHUDColorConfiguration>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(title, selection: binding.source) {
                ForEach(HaloHUDDynamicColorSource.allCases) { source in
                    Text(source.title + (source == .wallpaper ? " · unavailable" : ""))
                        .tag(source)
                        .disabled(source == .wallpaper)
                }
            }
            if binding.wrappedValue.source == .fixed {
                ColorPicker("\(title) color", selection: fixedColor(binding), supportsOpacity: true)
            }
        }
    }

    private func fixedColor(_ binding: Binding<HaloHUDColorConfiguration>) -> Binding<Color> {
        Binding(get: {
            let c = binding.wrappedValue
            return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness, opacity: c.alpha)
        }, set: { color in
            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            guard rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else { return }
            var value = binding.wrappedValue
            value.hue = Double(hue)
            value.saturation = Double(saturation)
            value.brightness = Double(brightness)
            value.alpha = Double(alpha)
            binding.wrappedValue = value
        })
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
    private func preview(_ kind: HaloHUDEventKind, persistent: Bool = false, restart: Bool = false) {
        let settings = hud.wrappedValue
        let previewConfiguration = settings.configuration(for: kind)
        NotificationCenter.default.post(
            name: .init("HaloHUDPreview"),
            object: nil,
            userInfo: [
                "kind": kind.rawValue,
                "value": previewValue,
                "configuration": previewConfiguration,
                "persistent": persistent,
                "restart": restart
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

    private var event: HaloHUDEvent { HaloHUDEvent.preview(kind: kind, value: value) }
    private var rawSize: CGSize {
        switch configuration.presentation.target {
        case .notch:
            let notch = configuration.presentation.resolvedNotch
            return CGSize(width: max(48, notch.width), height: notch.usesVerticalExpansion ? notch.resolvedVerticalHeight : 40)
        case .screenEdge:
            let length = max(40, configuration.presentation.screenEdgeLength)
            let thickness = max(1, configuration.presentation.screenEdgeThickness)
            if configuration.presentation.screenEdge == .left || configuration.presentation.screenEdge == .right {
                return CGSize(width: thickness, height: length)
            }
            return CGSize(width: length, height: thickness)
        default:
            let width = min(configuration.layout.maximumWidth, max(configuration.layout.minimumWidth, configuration.layout.width))
            return CGSize(width: max(80, width), height: max(24, configuration.layout.height))
        }
    }
    private var previewScale: CGFloat {
        min(1, 520 / max(1, rawSize.width), 220 / max(1, rawSize.height))
    }

    var body: some View {
        Group {
            switch configuration.presentation.target {
            case .disabled:
                Label("HUD disabled for this target", systemImage: "nosign")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
            case .menuBar:
                menuBarPreview
            case .notch:
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black)
                    HaloHUDRenderView(event: event, configuration: configuration, palette: [.accent], visible: true)
                }
                .frame(width: rawSize.width, height: rawSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .scaleEffect(previewScale)
                .frame(width: rawSize.width * previewScale, height: rawSize.height * previewScale)
            default:
                HaloHUDRenderView(event: event, configuration: configuration, palette: [.accent], visible: true)
                    .frame(width: rawSize.width, height: rawSize.height)
                    .scaleEffect(previewScale)
                    .frame(width: rawSize.width * previewScale, height: rawSize.height * previewScale)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
    }

    private var menuBarPreview: some View {
        HStack(spacing: 5) {
            if configuration.components.icon { Image(systemName: event.icon) }
            if configuration.components.label { Text(event.primaryText) }
            let valueText = HaloHUDRenderFormatting.valueText(event: event, configuration: configuration)
            if !valueText.isEmpty { Text(valueText).monospacedDigit() }
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private enum HaloAboutContent {
    static let description = "A customizable workspace for your Mac’s notch. Keep music, widgets and everyday controls within reach."
    static let creator = "Redstoneinvente"
    static let website = URL(string: "https://halo.redstoneinvente.com")!
    static let support = URL(string: "mailto:r.support@redstoneinvente.com")!
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
            Link(destination: HaloAboutContent.support) { Label("Email support · r.support@redstoneinvente.com", systemImage: "envelope.fill") }
        }
    }
}

// MARK: - Halo Account & License settings

@MainActor
private struct HaloAccountLicenseSettingsView: View {
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var licenseKey = ""
    @State private var creatingAccount = false

    var body: some View {
        Section("Halo account") {
            if !account.isConfigured {
                Label("Firebase configuration needed", systemImage: "wrench.and.screwdriver")
                Text("Set HaloFirebaseAPIKey in Info.plist (or the HALO build environment) and enable Email/Password Authentication in Firebase. Halo will then restore sessions automatically from Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if account.isSignedIn {
                LabeledContent("Signed in as", value: account.email.isEmpty ? "Halo user" : account.email)
                if !account.userID.isEmpty {
                    LabeledContent("Account ID", value: String(account.userID.prefix(12)) + "…")
                }
                LabeledContent("Email", value: account.emailVerified ? "Verified" : "Not verified")
                HStack {
                    if !account.emailVerified {
                        Button("Send Verification Email") { Task { await account.sendVerificationEmail() } }
                        Button("Refresh Verification Status") { Task { await account.refreshVerificationStatus() } }
                    }
                    Button("Sign Out") { account.signOut() }
                    if account.isBusy { ProgressView().controlSize(.small) }
                }
            } else {
                Picker("Mode", selection: $creatingAccount) {
                    Text("Sign In").tag(false)
                    Text("Create Account").tag(true)
                }.pickerStyle(.segmented)
                TextField("Email", text: $email)
                SecureField("Password", text: $password)
                HStack {
                    Button(creatingAccount ? "Create Halo Account" : "Sign In") {
                        Task {
                            if creatingAccount { await account.signUp(email: email, password: password) }
                            else { await account.signIn(email: email, password: password) }
                            if account.isSignedIn { password = "" }
                        }
                    }
                    .disabled(account.isBusy || email.isEmpty || password.isEmpty)
                    if !creatingAccount {
                        Button("Forgot Password?") { Task { await account.resetPassword(email: email) } }
                            .disabled(account.isBusy || email.isEmpty)
                    }
                    if account.isBusy { ProgressView().controlSize(.small) }
                }
            }
            if let notice = account.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if let error = account.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }

        Section("License") {
            if !license.isConfigured {
                Label("LicenseSeat configuration needed", systemImage: "key.horizontal")
                Text("Set HaloLicenseSeatPublishableKey and HaloLicenseSeatProductSlug. Use a LicenseSeat publishable client key (pk_), never a secret sk_ key in the Mac app.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    Label(license.state.title, systemImage: license.state.isValid ? "checkmark.seal.fill" : "key.horizontal")
                    Spacer()
                    if license.isBusy { ProgressView().controlSize(.small) }
                }
                if !license.licenseHint.isEmpty { LabeledContent("License", value: license.licenseHint) }
                if license.state.isValid {
                    LabeledContent("Status", value: license.details.statusTitle)
                    if !license.details.plan.isEmpty { LabeledContent("Plan", value: license.details.plan) }
                    LabeledContent("Activated Macs", value: license.details.activatedMacsTitle)
                    if let days = license.details.daysRemaining, let expiresAt = license.details.expiresAt {
                        LabeledContent(license.details.isTrial ? "Trial remaining" : "Subscription remaining",
                                       value: "\(days) day\(days == 1 ? "" : "s")")
                        LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        LabeledContent("License term", value: "Lifetime / no expiry reported")
                    }
                }

                if license.state.isValid {
                    HStack {
                        Button("Validate Now") { Task { await license.validate() } }.disabled(license.isBusy)
                        Button("Deactivate This Mac", role: .destructive) { Task { await license.deactivate() } }.disabled(license.isBusy)
                    }
                } else {
                    if account.isSignedIn {
                        HStack {
                            Button("Start 14-Day Free Trial") { Task { await license.startTrial() } }
                                .disabled(!account.emailVerified || license.isBusy || license.isStartingTrial)
                            if !account.emailVerified {
                                Text("Verify your email to start a trial.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if license.isStartingTrial { ProgressView().controlSize(.small) }
                        }
                    }
                    SecureField("License key", text: $licenseKey)
                    HStack {
                        Button("Activate License") {
                            Task {
                                await license.activate(licenseKey)
                                if license.state.isValid { licenseKey = "" }
                            }
                        }
                        .disabled(license.isBusy || license.isStartingTrial || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !license.licenseHint.isEmpty {
                            Button("Clear Local License", role: .destructive) { license.clearLocalLicense() }
                                .disabled(license.isBusy || license.isStartingTrial)
                        }
                    }
                }
            }
            if let notice = license.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if let error = license.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }

        Section("How access works") {
            Text("Your Halo account and your software license are separate credentials. Firebase handles identity and session recovery; LicenseSeat handles the purchased license and device seat. Halo stores the Firebase refresh token, the activated license key, and its stable installation fingerprint in macOS Keychain.")
                .font(.caption).foregroundStyle(.secondary)
            Link("Manage LicenseSeat account", destination: URL(string: "https://licenseseat.com")!)
            Link("Contact Halo support · r.support@redstoneinvente.com", destination: URL(string: "mailto:r.support@redstoneinvente.com")!)
        }
    }
}
