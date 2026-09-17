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
    @State private var expandedSidebarGroups: Set<String> = ["Halo"]

    private struct SidebarGroup: Identifiable {
        let title: String
        let icon: String
        let items: [String]
        var id: String { title }
    }

    private var visualWorkspaceActive: Bool {
        workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace
    }

    private var sidebarGroups: [SidebarGroup] {
        var workspaceItems = ["Modules", "Widgets", "Media & Files"]
        if visualWorkspaceActive {
            workspaceItems.insert("Visual Workspace Editor", at: 0)
        }
        return [
            SidebarGroup(
                title: "Halo",
                icon: "sparkles",
                items: ["General", "Account & License", "Privacy", "About"]
            ),
            SidebarGroup(
                title: "Interface",
                icon: "paintpalette",
                items: ["Appearance", "Notch Skins", "Activation Sequence", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD"]
            ),
            SidebarGroup(
                title: "Workspace",
                icon: "rectangle.3.group",
                items: workspaceItems
            ),
            SidebarGroup(
                title: "Profiles & Automation",
                icon: "person.2.badge.gearshape",
                items: ["Profiles", "Schedules", "Automation"]
            ),
            SidebarGroup(
                title: "System",
                icon: "gearshape.2",
                items: ["Displays", "Plugins", "Update Animation"]
            )
        ]
    }

    private var sections: [String] {
        sidebarGroups.flatMap(\.items)
    }

    private func sidebarGroupExpansion(_ group: SidebarGroup) -> Binding<Bool> {
        Binding(
            get: { expandedSidebarGroups.contains(group.id) },
            set: { expanded in
                if expanded {
                    expandedSidebarGroups.insert(group.id)
                } else {
                    expandedSidebarGroups.remove(group.id)
                }
            }
        )
    }

    private func sidebarMatches(in group: SidebarGroup) -> [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return group.items }
        if group.title.localizedCaseInsensitiveContains(query) {
            return group.items
        }
        return group.items.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func isSectionUnavailable(_ name: String) -> Bool {
        visualWorkspaceActive && (name == "Modules" || name == "Widgets")
    }

    private func sectionHelp(_ name: String) -> String {
        guard isSectionUnavailable(name) else { return name }
        return "\(name) is locked while Visual Workspace is active. Configure these controls in Visual Workspace Editor, or switch Appearance → Opened Space → Layout System to Default."
    }

    private var sidebarSelection: Binding<String?> {
        Binding(
            get: { section },
            set: { candidate in
                guard let candidate else { return }
                guard !isSectionUnavailable(candidate) else { return }
                section = candidate
            }
        )
    }

    @ViewBuilder
    private func sidebarRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Label(name, systemImage: sectionIcon(name))
            Spacer(minLength: 4)
            if isSectionUnavailable(name) {
                HStack(spacing: 3) {
                    Text("Default only")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.10), in: Capsule())
            }
        }
        .padding(.vertical, 5)
        .opacity(isSectionUnavailable(name) ? 0.5 : 1)
        .contentShape(Rectangle())
        .help(sectionHelp(name))
    }
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
                List(selection: sidebarSelection) {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ForEach(sidebarGroups) { group in
                            DisclosureGroup(isExpanded: sidebarGroupExpansion(group)) {
                                ForEach(group.items, id: \.self) { name in
                                    sidebarRow(name)
                                        .tag(name)
                                        .disabled(isSectionUnavailable(name))
                                }
                            } label: {
                                Label(group.title, systemImage: group.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(group.items.contains(section ?? "") ? Color.accentColor : Color.secondary)
                            }
                        }
                    } else {
                        ForEach(sidebarGroups) { group in
                            let matches = sidebarMatches(in: group)
                            if !matches.isEmpty {
                                Section {
                                    ForEach(matches, id: \.self) { name in
                                        sidebarRow(name)
                                            .tag(name)
                                            .disabled(isSectionUnavailable(name))
                                    }
                                } header: {
                                    Label(group.title, systemImage: group.icon)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
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
                        Text(section == "Visual Workspace Editor" ? "Design the active Visual Workspace" : "Changes are saved automatically").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
                Divider()
                if section == "Visual Workspace Editor", visualWorkspaceActive {
                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout, showsCloseButton: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                } else {
                    Form { content }
                        .formStyle(.grouped)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.frame(minWidth: 700, minHeight: 560)
        .onChange(of: visualWorkspaceActive) { active in
            if active && (section == "Modules" || section == "Widgets") {
                section = "Visual Workspace Editor"
            } else if !active && section == "Visual Workspace Editor" {
                section = "Appearance"
            }
        }
        .onChange(of: section) { selectedSection in
            guard let selectedSection,
                  let group = sidebarGroups.first(where: { $0.items.contains(selectedSection) }) else { return }
            expandedSidebarGroups.insert(group.id)
        }
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
        case "Notch Skins": return "square.3.layers.3d"
        case "Activation Sequence": return "power.circle"
        case "Visual Workspace Editor": return "rectangle.3.group"
        case "Modules": return "square.grid.2x2"
        case "Widgets": return "slider.horizontal.3"
        case "Context Notch Interface": return "rectangle.stack"
        case "HUD": return "rectangle.inset.filled.and.person.filled"
        case "Closed notch": return "rectangle.topthird.inset.filled"
        case "Notch Ambient": return "sparkles"
        case "Media & Files": return "play.rectangle"
        case "Profiles": return "person.crop.rectangle.stack"
        case "Schedules": return "calendar.badge.clock"
        case "Automation": return "bolt"
        case "Displays": return "display.2"
        case "Plugins": return "puzzlepiece.extension"
        case "Privacy": return "hand.raised"
        case "Update Animation": return "arrow.down.circle"
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
            if store.configuration.hoverToExpand {
                LabeledContent("Hover delay") {
                    HStack(spacing: 10) {
                        SwiftUI.Slider(
                            value: Binding(
                                get: { store.configuration.resolvedHoverOpenDelay },
                                set: { store.configuration.hoverOpenDelay = min(10, max(0, $0)) }
                            ),
                            in: 0...10,
                            step: 0.1
                        )
                        .frame(width: 220)
                        Group {
                            if store.configuration.resolvedHoverOpenDelay == 0 {
                                Text("Instant")
                            } else {
                                Text("\(store.configuration.resolvedHoverOpenDelay, specifier: "%.1f") s")
                            }
                        }
                        .monospacedDigit()
                        .frame(width: 58, alignment: .trailing)
                    }
                }
            }
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
        case "Notch Skins": NotchSkinSettingsPane(appearance: $workspace.settings.layout.appearance, theme: store.configuration.theme)
        case "Activation Sequence": ActivationSequenceSettingsPane()
        case "Widgets": WidgetSettingsView(layout: $workspace.settings.layout)
        case "Closed notch": ClosedNotchSettingsView(layout: $workspace.settings.layout, media: workspace.media, app: workspace.settings.mediaApp)
        case "Notch Ambient": NotchAmbientSettingsView(store: store, workspace: workspace)
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
            }
        case "Update Animation":
            UpdateAnimationSettingsView()
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


@MainActor private struct NotchSkinSettingsPane: View {
    @Binding var appearance: Appearance
    let theme: Theme

    private let columns = [GridItem(.adaptive(minimum: 132), spacing: 10)]

    var body: some View {
        Section("Notch skins") {
            Toggle("Enable notch skin", isOn: $appearance.skin.enabled)
            Text("Skins are rendered above Halo's background but below widgets, controls and Context Interface content. They decorate the surface without covering useful UI.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Skin library") {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(NotchSkinPreset.allCases) { preset in
                    skinCard(preset)
                }
            }
            Text("Texture skins stay subtle; themed skins bring their own visual identity while remaining below Halo's content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section("Preview") {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.03, blue: 0.055), Color(red: 0.07, green: 0.025, blue: 0.11)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                NotchSkinLayer(options: previewOptions, theme: theme, expanded: true)
                HStack(spacing: 18) {
                    Label("Halo", systemImage: "sparkles").font(.headline)
                    Spacer()
                    Image(systemName: "waveform")
                    Image(systemName: "timer")
                    Image(systemName: "battery.100percent")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
            }
            .frame(height: 116)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12)))
        }

        Section("Behavior") {
            Picker("Show skin", selection: $appearance.skin.visibility) {
                ForEach(NotchSkinVisibility.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Blend mode", selection: $appearance.skin.blend) {
                ForEach(NotchSkinBlend.allCases) { Text($0.rawValue).tag($0) }
            }
            PreciseSlider(title: "Intensity", value: $appearance.skin.opacity, range: 0...1, step: 0.05, decimals: 2)
            PreciseSlider(title: "Pattern scale", value: $appearance.skin.scale, range: 0.4...3, step: 0.05, decimals: 2)
        }

        Section("Procedural color") {
            Toggle("Use Halo accent", isOn: $appearance.skin.usesThemeTint)
            if !appearance.skin.usesThemeTint {
                ColorPicker("Skin tint", selection: tintBinding, supportsOpacity: false)
            }
            Text("Every skin is generated procedurally, stays sharp at any notch size, and can be recolored. The themed presets also use complementary palette colors where appropriate.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Section {
            Button("Reset skin settings") { appearance.skin = NotchSkinOptions() }
        }
    }

    private var previewOptions: NotchSkinOptions {
        var value = appearance.skin
        value.enabled = true
        return value
    }

    @ViewBuilder
    private func skinCard(_ preset: NotchSkinPreset) -> some View {
        let selected = appearance.skin.preset == preset
        Button { applyPreset(preset) } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: preset.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor) }
                }
                Text(preset.rawValue).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                Text(presetDescription(preset))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .background(selected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Color.accentColor.opacity(0.72) : Color.white.opacity(0.08), lineWidth: selected ? 1.4 : 1))
        }
        .buttonStyle(.plain)
    }

    private func setTint(_ red: Double, _ green: Double, _ blue: Double, useTheme: Bool = false) {
        appearance.skin.usesThemeTint = useTheme
        appearance.skin.tint = WidgetColor(red: red, green: green, blue: blue)
    }

    private func applyPreset(_ preset: NotchSkinPreset) {
        appearance.skin.enabled = true
        appearance.skin.preset = preset
        switch preset {
        case .haloGlow:
            appearance.skin.opacity = 0.34; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .carbonWeave:
            appearance.skin.opacity = 0.44; appearance.skin.blend = .normal; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .neonCircuit:
            appearance.skin.opacity = 0.30; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .retroScanlines:
            appearance.skin.opacity = 0.40; appearance.skin.blend = .normal; appearance.skin.scale = 1.0; setTint(0.28, 0.95, 0.62)
        case .pixelMatrix:
            appearance.skin.opacity = 0.28; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .constellation:
            appearance.skin.opacity = 0.32; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; appearance.skin.usesThemeTint = true
        case .aurora:
            appearance.skin.opacity = 0.52; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.25, 0.95, 0.83)
        case .synthwave:
            appearance.skin.opacity = 0.58; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(1.0, 0.18, 0.78)
        case .sakuraNight:
            appearance.skin.opacity = 0.52; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(1.0, 0.46, 0.72)
        case .oceanCurrent:
            appearance.skin.opacity = 0.48; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.16, 0.75, 1.0)
        case .emberCore:
            appearance.skin.opacity = 0.58; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(1.0, 0.34, 0.08)
        case .blueprint:
            appearance.skin.opacity = 0.44; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.12, 0.68, 1.0)
        case .matrixRain:
            appearance.skin.opacity = 0.52; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.18, 1.0, 0.32)
        case .nebula:
            appearance.skin.opacity = 0.54; appearance.skin.blend = .screen; appearance.skin.scale = 1.0; setTint(0.58, 0.32, 1.0)
        }
    }

    private func presetDescription(_ preset: NotchSkinPreset) -> String {
        switch preset {
        case .haloGlow: return "Soft accent bloom and edge light"
        case .carbonWeave: return "Visible layered carbon-fiber weave"
        case .neonCircuit: return "Futuristic traces and light nodes"
        case .retroScanlines: return "Bold CRT scan bars with phosphor tint"
        case .pixelMatrix: return "Sparse 8-bit LED-style pixels"
        case .constellation: return "Quiet stars with faint connections"
        case .aurora: return "Flowing northern-light ribbons"
        case .synthwave: return "Neon sunset and perspective grid"
        case .sakuraNight: return "Night branch with drifting blossom petals"
        case .oceanCurrent: return "Layered cyan wave currents"
        case .emberCore: return "Warm core glow with rising sparks"
        case .blueprint: return "Technical drafting grid and guides"
        case .matrixRain: return "Falling green digital-code columns"
        case .nebula: return "Purple-blue cosmic clouds and stars"
        }
    }

    private var tintBinding: Binding<Color> {
        Binding(
            get: { appearance.skin.tint.color },
            set: { color in appearance.skin.tint = widgetColor(from: color) }
        )
    }

    private func widgetColor(from color: Color) -> WidgetColor {
        let ns = NSColor(color)
        let rgb = ns.usingColorSpace(.deviceRGB) ?? ns
        return WidgetColor(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
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
                set: { value in
                    let useVisualWorkspace = value == "visual"
                    workspace.settings.layout.setCustomOpenNotchWorkspaceEnabled(useVisualWorkspace)
                    // These are alternate opened-surface systems. Visual Workspace
                    // must never inherit the Default layout top-strip overlay.
                    if useVisualWorkspace { keepClosedContentsWhenOpen = false }
                }
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

        if workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace {
            Section("Opened notch behavior") {
                Label("Visual Workspace owns the opened notch", systemImage: "rectangle.3.group")
                Text("Default-layout chrome and the closed-notch top strip are disabled while Visual Workspace is active. Switch back to Default to use those options.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Section("Opened notch behavior") {
                Toggle("Keep closed-notch contents visible when opened", isOn: $keepClosedContentsWhenOpen)
                Text("Keeps the normal Closed Notch widgets and media visible in the top strip. Context Interfaces keep their own layout rules.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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

    private var visualBackgroundKind: Binding<BackgroundKind> {
        Binding(
            get: { workspace.settings.layout.resolvedOpenNotchLayout.appearance.background ?? workspace.settings.layout.appearance.background },
            set: { value in updateVisualAppearance { $0.background = value } }
        )
    }

    private var visualAssetPath: Binding<String> {
        Binding(
            get: { workspace.settings.layout.resolvedOpenNotchLayout.appearance.assetPath },
            set: { value in updateVisualAppearance { $0.assetPath = value } }
        )
    }

    private func visualDouble(_ keyPath: WritableKeyPath<OpenNotchAppearance, Double?>, fallback: Double) -> Binding<Double> {
        Binding(
            get: { workspace.settings.layout.resolvedOpenNotchLayout.appearance[keyPath: keyPath] ?? fallback },
            set: { value in updateVisualAppearance { $0[keyPath: keyPath] = value } }
        )
    }

    private func visualColor(_ keyPath: WritableKeyPath<OpenNotchAppearance, WidgetColor?>, fallback: WidgetColor) -> Binding<Color> {
        Binding(
            get: { (workspace.settings.layout.resolvedOpenNotchLayout.appearance[keyPath: keyPath] ?? fallback).color },
            set: { value in updateVisualAppearance { $0[keyPath: keyPath] = WidgetColor(value) } }
        )
    }

    private func updateVisualAppearance(_ update: (inout OpenNotchAppearance) -> Void) {
        var current = workspace.settings.layout
        current.materializeOpenNotchLayout()
        var opened = current.resolvedOpenNotchLayout
        update(&opened.appearance)
        opened.preset = .custom
        current.openNotch = opened
        workspace.settings.layout = current
    }

    private func chooseVisualBackgroundAsset(_ kind: BackgroundKind) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = kind == .video ? [.movie] : [.image]
        if panel.runModal() == .OK, let url = panel.url { visualAssetPath.wrappedValue = url.path }
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
        Section("Surface background effects") {
            if workspace.settings.layout.appearance.background == .glass {
                Label("Glass uses Halo's native macOS material", systemImage: "square.on.square")
                    .foregroundStyle(.secondary)
                Text("Background Blur applies to Solid, Gradient, Image, and Video surfaces. Visual Workspace glass strength remains independently configurable in its Background page.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                PreciseSlider(
                    title: "Background blur",
                    value: $workspace.settings.layout.appearance.blur,
                    range: 0...20,
                    step: 0.5,
                    suffix: "pt",
                    decimals: 1
                )
                HStack {
                    Button("Reset blur") { workspace.settings.layout.appearance.blur = 0 }
                    Spacer()
                    Text("Affects the surface background only")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var background: some View {
        if workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace {
            visualWorkspaceBackground
        } else {
            defaultWorkspaceBackground
        }
    }

    @ViewBuilder private var defaultWorkspaceBackground: some View {
        let kind = workspace.settings.layout.appearance.background
        Section {
            Label("Default Workspace", systemImage: "rectangle.split.3x1")
                .font(.headline)
            Text("These controls affect Halo's standard opened-notch workspace. Switch to Visual Workspace in Opened Space to edit its independent background instead.")
                .font(.caption).foregroundStyle(.secondary)
        }
        SurfaceAppearanceControls(
            appearance: $workspace.settings.layout.appearance,
            theme: store.configuration.theme,
            screen: NSScreen.main ?? NSScreen.screens.first,
            scope: .background
        )
        Section("Background effects") {
            switch kind {
            case .glass:
                Text("Default glass uses Halo's system material. Visual Workspace has its own adjustable glass strength when that layout system is selected.")
                    .font(.caption).foregroundStyle(.secondary)
            case .image, .video:
                Slider(value: $workspace.settings.layout.appearance.blur, in: 0...20) { Text("Blur") }
                Slider(value: $workspace.settings.layout.appearance.saturation, in: 0...2) { Text("Saturation") }
                Slider(value: $workspace.settings.layout.appearance.brightness, in: -0.5...0.5) { Text("Brightness") }
            case .gradient:
                Slider(value: $workspace.settings.layout.appearance.saturation, in: 0...2) { Text("Saturation") }
                Slider(value: $workspace.settings.layout.appearance.brightness, in: -0.5...0.5) { Text("Brightness") }
            case .solid:
                EmptyView()
            }
            GrainSettingsView(options: Binding(get: { workspace.settings.layout.appearance.grain ?? GrainOptions() }, set: { workspace.settings.layout.appearance.grain = $0 }))
            if kind == .video {
                Toggle("Pause video on battery", isOn: $workspace.settings.layout.appearance.pauseVideoOnBattery)
                Text("Video is muted, loops, and pauses when collapsed. Large videos and blur increase GPU use. The file is referenced in place.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if kind == .image {
                Text("The image file is referenced in place. Blur and color adjustments apply only to this background type.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var visualWorkspaceBackground: some View {
        let kind = visualBackgroundKind.wrappedValue
        let fallback = workspace.settings.layout.appearance
        let openedAppearance = workspace.settings.layout.resolvedOpenNotchLayout.appearance
        Section {
            Label("Visual Workspace", systemImage: "rectangle.3.group")
                .font(.headline)
            Text("Background changes here are stored with the Visual Workspace and do not overwrite the Default workspace background.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Background") {
            Picker("Type", selection: visualBackgroundKind) {
                ForEach(BackgroundKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }

            switch kind {
            case .glass:
                Text("Glass uses a live macOS material. The Glass blur control below now changes the material strength instead of being a no-op.")
                    .font(.caption).foregroundStyle(.secondary)
            case .solid:
                ColorPicker("Color", selection: visualColor(\.solidColor, fallback: fallback.solidColor ?? .white), supportsOpacity: false)
            case .gradient:
                ColorPicker("Gradient start", selection: visualColor(\.gradientStartColor, fallback: fallback.gradientStartColor ?? WidgetColor(red: 0.07, green: 0.09, blue: 0.14)), supportsOpacity: false)
                ColorPicker("Gradient end", selection: visualColor(\.gradientEndColor, fallback: fallback.gradientEndColor ?? WidgetColor(red: 0.01, green: 0.02, blue: 0.04)), supportsOpacity: false)
            case .image, .video:
                TextField(kind == .video ? "Video path" : "Image path", text: visualAssetPath)
                Button(kind == .video ? "Choose Video…" : "Choose Image…") { chooseVisualBackgroundAsset(kind) }
                Text("Halo references the selected file in place; it is not copied into the app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        Section("Material") {
            if kind == .glass {
                Slider(value: visualDouble(\.blur, fallback: fallback.blur), in: 0...30) { Text("Glass blur") }
                Text("0 uses the base glass. Higher values progressively strengthen the live material and backdrop separation.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if kind == .image || kind == .video {
                Slider(value: visualDouble(\.blur, fallback: fallback.blur), in: 0...30) { Text("Blur") }
            }

            if kind != .solid {
                Slider(value: visualDouble(\.saturation, fallback: fallback.saturation), in: 0...2.5) { Text("Saturation") }
                Slider(value: visualDouble(\.brightness, fallback: fallback.brightness), in: -0.5...0.5) { Text("Brightness") }
                Slider(value: visualDouble(\.contrast, fallback: openedAppearance.contrast ?? 1), in: 0.5...2) { Text("Contrast") }
            }

            Slider(value: visualDouble(\.grain, fallback: openedAppearance.grain ?? 0), in: 0...0.35) { Text("Grain") }
            Slider(value: visualDouble(\.warmth, fallback: openedAppearance.warmth ?? 0), in: -1...1) { Text("Warmth") }
            ColorPicker("Tint", selection: visualColor(\.tintColor, fallback: openedAppearance.tintColor ?? WidgetColor(red: 0.35, green: 0.55, blue: 1)), supportsOpacity: false)
            Slider(value: visualDouble(\.tintOpacity, fallback: openedAppearance.tintOpacity ?? 0), in: 0...0.5) { Text("Tint opacity") }
        }

        Section("Edge & depth") {
            let borderWidth = visualDouble(\.borderWidth, fallback: openedAppearance.borderWidth ?? 0)
            Slider(value: borderWidth, in: 0...6) { Text("Border width") }
            if borderWidth.wrappedValue > 0.001 {
                ColorPicker("Border", selection: visualColor(\.borderColor, fallback: openedAppearance.borderColor ?? .white), supportsOpacity: false)
                Slider(value: visualDouble(\.borderOpacity, fallback: openedAppearance.borderOpacity ?? 0.2), in: 0...1) { Text("Border opacity") }
                Slider(value: visualDouble(\.innerHighlight, fallback: openedAppearance.innerHighlight ?? 0), in: 0...0.5) { Text("Inner highlight") }
            }

            let shadowOpacity = visualDouble(\.shadowOpacity, fallback: openedAppearance.shadowOpacity ?? 0)
            Slider(value: shadowOpacity, in: 0...0.7) { Text("Shadow opacity") }
            if shadowOpacity.wrappedValue > 0.001 {
                Slider(value: visualDouble(\.shadowBlur, fallback: openedAppearance.shadowBlur ?? 12), in: 0...50) { Text("Shadow blur") }
            }
            Slider(value: visualDouble(\.glow, fallback: openedAppearance.glow ?? 0), in: 0...0.5) { Text("Subtle glow") }
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
    case drop, music, teleprompter, transfer, clipboard, bluetooth, retro
    var id: String { rawValue }
}

private struct ContextInterfaceLibraryView: View {
    @Binding var layout: WorkspaceLayout
    @State private var selection: ContextInterfaceSelection?
    @AppStorage("HaloContextDropEnabled") private var dropEnabled = true
    @AppStorage("HaloContextTransferEnabled") private var transferEnabled = true
    @AppStorage("HaloContextClipboardEnabled") private var clipboardEnabled = true
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
        } else if selection == .teleprompter {
            Section {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = nil }
                    } label: {
                        Label("All CI", systemImage: "chevron.left")
                    }
                    Spacer()
                    Label("Teleprompter CI", systemImage: "text.bubble.fill")
                        .font(.headline)
                }
            }
            TeleprompterContextSettings()
        } else if selection == .clipboard {
            Section {
                HStack(spacing: 12) {
                    Button { withAnimation(.easeInOut(duration: 0.18)) { selection = nil } } label: { Label("All CI", systemImage: "chevron.left") }
                    Spacer()
                    Label("Clipboard CI", systemImage: "doc.on.clipboard.fill").font(.headline)
                }
            }
            ClipboardContextSettings()
        } else if selection == .transfer {
            Section {
                HStack(spacing: 12) {
                    Button { withAnimation(.easeInOut(duration: 0.18)) { selection = nil } } label: { Label("All CI", systemImage: "chevron.left") }
                    Spacer()
                    Label("Transfer CI", systemImage: "arrow.up.arrow.down.circle.fill").font(.headline)
                }
            }
            TransferContextSettings()
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
                    TeleprompterContextInterfaceCard {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .teleprompter }
                    }
                    TransferContextInterfaceCard(enabled: transferEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .transfer }
                    }
                    ClipboardContextInterfaceCard(enabled: clipboardEnabled) {
                        withAnimation(.easeInOut(duration: 0.18)) { selection = .clipboard }
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

            HaloCustomCISettingsSection()

            Section {
                Label("CI can react to live system context without turning the notch into one giant settings page.", systemImage: "rectangle.stack.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}



private struct ClipboardContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextClipboardPriority") private var priority = 68.0
    @AppStorage("HaloContextClipboardTriggerMode") private var triggerMode = "Hover to Open"
    @AppStorage("HaloContextClipboardTimeoutSeconds") private var timeout = 8.0
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.24), Color.black.opacity(0.96)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            Image(systemName: "doc.on.clipboard.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            Text("COPIED")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.72))
                            Spacer()
                            Text("JUST NOW")
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.38))
                        }

                        Text("https://halo.redstoneinvente.com")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 7) {
                            Label("Open", systemImage: "arrow.up.forward.app")
                            Label("Search", systemImage: "magnifyingglass")
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.07), in: Capsule())
                    }
                    .padding(14)
                }
                .frame(height: 112)

                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 38, height: 38)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clipboard CI").font(.headline)
                        Text("Copy Actions").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "ON COPY" : "OFF")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background((enabled ? Color.accentColor : Color.secondary).opacity(0.12), in: Capsule())
                }
                Text("Turns the notch into a contextual action bar after you copy text, links, images, videos, files and more — with optional in-memory history.")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(3)
                HStack(spacing: 7) {
                    Label(triggerMode, systemImage: triggerMode == "Pop Up" ? "rectangle.portrait.and.arrow.forward" : "cursorarrow.motionlines")
                    Text("•")
                    Text("\(Int(timeout))s")
                    Text("•")
                    Text("Priority \(Int(priority))")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
    }
}

private struct ClipboardContextSettings: View {
    @AppStorage("HaloContextClipboardEnabled") private var enabled = true
    @AppStorage("HaloContextClipboardPriority") private var priority = 68.0
    @AppStorage("HaloContextClipboardTriggerMode") private var triggerMode = "Hover to Open"
    @AppStorage("HaloContextClipboardTimeoutSeconds") private var timeout = 8.0
    @AppStorage("HaloContextClipboardCompact") private var compact = false
    @AppStorage("HaloContextClipboardShowClosedPreview") private var showClosedPreview = true
    @AppStorage("HaloContextClipboardShowType") private var showType = true
    @AppStorage("HaloContextClipboardShowSource") private var showSource = true
    @AppStorage("HaloContextClipboardShowCharacterCount") private var showCharacterCount = true
    @AppStorage("HaloContextClipboardPreviewLines") private var previewLines = 3
    @AppStorage("HaloContextClipboardMaxActions") private var maxActions = 5
    @AppStorage("HaloContextClipboardAutoCloseAfterAction") private var autoCloseAfterAction = true
    @AppStorage("HaloContextClipboardShowSearch") private var showSearch = true
    @AppStorage("HaloContextClipboardShowTransforms") private var showTransforms = true
    @AppStorage("HaloContextClipboardSearchEngine") private var searchEngine = "Google"
    @AppStorage("HaloContextClipboardBackgroundStyle") private var backgroundStyle = "Adaptive"
    @AppStorage("HaloContextClipboardExcludedApps") private var excludedApps = ""
    @AppStorage("HaloContextClipboardHistoryEnabled") private var historyEnabled = true
    @AppStorage("HaloContextClipboardShowHistory") private var showHistory = true
    @AppStorage("HaloContextClipboardHistoryLimit") private var historyLimit = 8
    @AppStorage("HaloContextClipboardShortcutEnabled") private var shortcutEnabled = true
    @AppStorage("HaloContextClipboardShortcutCode") private var shortcutCode = 9
    @AppStorage("HaloContextClipboardShortcutModifiers") private var shortcutModifiers = 6144
    @AppStorage("HaloContextClipboardShowTranslate") private var showTranslate = true
    @AppStorage("HaloContextClipboardTranslateProvider") private var translateProvider = "Google Translate"
    @AppStorage("HaloContextClipboardTranslateTarget") private var translateTarget = "en"

    var body: some View {
        Group {
            Section("Activation") {
                Toggle("Enable Clipboard CI", isOn: $enabled)
                Picker("After copying", selection: $triggerMode) {
                    Text("Pop Up").tag("Pop Up")
                    Text("Stay closed — hover to open").tag("Hover to Open")
                }
                LabeledContent("Timeout") {
                    Slider(value: $timeout, in: 1...120, step: 1)
                    Text("\(Int(timeout)) s").font(.caption.monospacedDigit()).frame(width: 52)
                }
                Text(triggerMode == "Pop Up"
                     ? "A copy immediately opens Clipboard CI. The countdown pauses only while your pointer is over the CI, then resumes when you leave."
                     : "A copy replaces the closed notch with Clipboard CI without opening it. Hovering opens it even if Halo's global hover-to-expand setting is off. The countdown pauses while your pointer is over the CI.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Manual access") {
                Toggle("Enable global Clipboard CI shortcut", isOn: $shortcutEnabled)
                Picker("Shortcut key", selection: $shortcutCode) {
                    Text("V").tag(9)
                    Text("C").tag(8)
                    Text("B").tag(11)
                    Text("H").tag(4)
                    Text("Space").tag(49)
                }.disabled(!shortcutEnabled)
                Picker("Shortcut modifiers", selection: $shortcutModifiers) {
                    Text("Control + Option").tag(6144)
                    Text("Option + Command").tag(2304)
                    Text("Control + Shift").tag(4608)
                }.disabled(!shortcutEnabled)
                Button("Open Clipboard CI now") {
                    NotificationCenter.default.post(name: .init("HaloClipboardCIToggle"), object: nil)
                }
                Text("The default shortcut is Control–Option–V. Manual invocation opens the most recent history item even when nothing was just copied; press the shortcut again while Clipboard CI is open to dismiss it.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Context priority") {
                LabeledContent("Priority") {
                    Slider(value: $priority, in: 0...100, step: 1)
                    Text("\(Int(priority))").font(.caption.monospacedDigit()).frame(width: 36)
                }
                Text("Higher-priority Context Interfaces win when several contexts are active at once. Clipboard defaults just below Teleprompter and above Transfer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Layout") {
                Toggle("Compact opened layout", isOn: $compact)
                Toggle("Show copied preview while closed", isOn: $showClosedPreview)
                Toggle("Show content type", isOn: $showType)
                Toggle("Show source app", isOn: $showSource)
                Toggle("Show content details", isOn: $showCharacterCount)
                LabeledContent("Text preview lines") {
                    Stepper("\(previewLines)", value: $previewLines, in: 1...6).labelsHidden()
                    Text("\(previewLines)").font(.caption.monospacedDigit()).frame(width: 24)
                }
                LabeledContent("Maximum actions") {
                    Stepper("\(maxActions)", value: $maxActions, in: 2...8).labelsHidden()
                    Text("\(maxActions)").font(.caption.monospacedDigit()).frame(width: 24)
                }
                Text("Clipboard CI resizes for the selected content. Images get a visual preview, videos get a media card, and text uses your chosen number of preview lines.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Clipboard history") {
                Toggle("Keep in-memory history", isOn: $historyEnabled)
                Toggle("Show history in Clipboard CI", isOn: $showHistory).disabled(!historyEnabled)
                LabeledContent("History items") {
                    Stepper("\(historyLimit)", value: $historyLimit, in: 2...20)
                        .labelsHidden()
                    Text("\(historyLimit)").font(.caption.monospacedDigit()).frame(width: 28)
                }
                .disabled(!historyEnabled)
                Text("History can contain text, links, file references, image previews and videos. It lives only in memory and is cleared when Halo quits; sensitive/transient clipboard types are never added.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Actions") {
                Toggle("Offer web search", isOn: $showSearch)
                Picker("Search engine", selection: $searchEngine) {
                    Text("Google").tag("Google")
                    Text("DuckDuckGo").tag("DuckDuckGo")
                    Text("Bing").tag("Bing")
                }.disabled(!showSearch)
                Toggle("Offer Translate action", isOn: $showTranslate)
                Picker("Translation provider", selection: $translateProvider) {
                    Text("Google Translate").tag("Google Translate")
                    Text("DeepL").tag("DeepL")
                }.disabled(!showTranslate)
                Picker("Translate to", selection: $translateTarget) {
                    Text("English").tag("en")
                    Text("French").tag("fr")
                    Text("Spanish").tag("es")
                    Text("German").tag("de")
                    Text("Italian").tag("it")
                    Text("Portuguese").tag("pt")
                    Text("Dutch").tag("nl")
                    Text("Japanese").tag("ja")
                    Text("Korean").tag("ko")
                    Text("Chinese (Simplified)").tag("zh-CN")
                    Text("Hindi").tag("hi")
                    Text("Arabic").tag("ar")
                    Text("Russian").tag("ru")
                }.disabled(!showTranslate)
                Toggle("Offer text transforms", isOn: $showTransforms)
                Toggle("Dismiss CI after an action", isOn: $autoCloseAfterAction)
                Text("Paste restores the selected text, image, video or file to the macOS pasteboard and sends Command–V to the app that was frontmost when Clipboard CI opened. macOS may request Accessibility/Post Event permission the first time you use it.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Actions adapt to the payload: open links, compose email, FaceTime numbers, reveal files, open videos, preview/save/copy images, pretty-print JSON, open addresses in Maps, search or translate text, transform text, paste the selected payload into the previous app, or restore an earlier history item.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Background", selection: $backgroundStyle) {
                    Text("Adaptive tint").tag("Adaptive")
                    Text("Glass").tag("Glass")
                    Text("Black").tag("Black")
                }
                Text("Adaptive tint changes subtly with the copied content type while keeping the notch dark and readable.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Privacy") {
                TextField("Excluded app bundle IDs, comma-separated", text: $excludedApps)
                Text("Clipboard CI only inspects a new pasteboard item while this CI is enabled. macOS concealed/transient clipboard types are ignored, excluded apps suppress the trigger, and Clipboard CI never persists clipboard contents or history to disk.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct TransferContextInterfaceCard: View {
    let enabled: Bool
    let action: () -> Void
    @AppStorage("HaloContextTransferPriority") private var priority = 65.0
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [Color.accentColor.opacity(0.30), Color.black.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    HStack(spacing: 18) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 30, weight: .semibold))
                        VStack(spacing: 5) { Capsule().fill(.white.opacity(0.85)).frame(width: 92, height: 6); Capsule().fill(.white.opacity(0.25)).frame(width: 68, height: 5) }
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 30, weight: .semibold))
                    }.foregroundStyle(.white)
                }.frame(height: 112)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) { Text("Transfer CI").font(.headline); Text("Downloads & Uploads").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available").font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4).background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule()).foregroundStyle(enabled ? Color.green : Color.secondary)
                }
                Text("Appears automatically during sustained network transfers with live speed, peaks, totals, elapsed time and throughput history.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                HStack { Label("Automatic", systemImage: "bolt.fill").font(.caption2).foregroundStyle(.secondary); Text("Priority \(Int(priority))").font(.caption2).foregroundStyle(.secondary); Spacer(); Label("Edit", systemImage: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor) }
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(hovered ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.08), lineWidth: 1)).contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }.buttonStyle(.plain).onHover { hovered = $0 }.animation(.easeOut(duration: 0.14), value: hovered)
    }
}

private struct TransferContextSettings: View {
    @AppStorage("HaloContextTransferEnabled") private var enabled = true
    @AppStorage("HaloContextTransferPriority") private var priority = 65.0
    @AppStorage("HaloContextTransferThresholdMBps") private var threshold = 0.35
    @AppStorage("HaloContextTransferLingerSeconds") private var linger = 2.5
    @AppStorage("HaloContextTransferReactDownloads") private var reactDownloads = true
    @AppStorage("HaloContextTransferReactUploads") private var reactUploads = true
    @AppStorage("HaloContextTransferClosedStyle") private var closedStyle = "Stats"
    @AppStorage("HaloContextTransferOpenStyle") private var openStyle = "Dashboard"
    @AppStorage("HaloContextTransferCompact") private var compact = false
    @AppStorage("HaloContextTransferShowDirection") private var showDirection = true
    @AppStorage("HaloContextTransferShowDownload") private var showDownload = true
    @AppStorage("HaloContextTransferShowUpload") private var showUpload = true
    @AppStorage("HaloContextTransferShowPeak") private var showPeak = true
    @AppStorage("HaloContextTransferShowSession") private var showSession = true
    @AppStorage("HaloContextTransferShowElapsed") private var showElapsed = true
    @AppStorage("HaloContextTransferShowGraph") private var showGraph = true
    @AppStorage("HaloContextTransferIndicatorStyle") private var indicatorStyle = "Edge Bar"
    @AppStorage("HaloContextTransferIndicatorShowSpeed") private var indicatorShowSpeed = true
    @AppStorage("HaloContextTransferIndicatorThickness") private var indicatorThickness = 3.0
    @AppStorage("HaloContextTransferIndicatorIntensity") private var indicatorIntensity = 1.0
    @AppStorage("HaloContextTransferBackgroundStyle") private var backgroundStyle = "Gradient"
    @AppStorage("HaloContextTransferBackgroundPrimaryHue") private var backgroundPrimaryHue = 0.58
    @AppStorage("HaloContextTransferBackgroundSecondaryHue") private var backgroundSecondaryHue = 0.72
    @AppStorage("HaloContextTransferBackgroundSaturation") private var backgroundSaturation = 0.72
    @AppStorage("HaloContextTransferBackgroundBrightness") private var backgroundBrightness = 0.30
    @AppStorage("HaloContextTransferBackgroundOpacity") private var backgroundOpacity = 1.0

    var body: some View {
        Section("Transfer Context Interface") {
            Toggle("Enable Transfer CI", isOn: $enabled)
            Text("Transfer CI replaces the contents and styling of the existing Halo notch while transfer activity is present. It still opens, closes, hovers, pins and animates exactly like your normal notch.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("React to downloads", isOn: $reactDownloads)
            Toggle("React to uploads", isOn: $reactUploads)
        }

        Section("Detection") {
            LabeledContent("Activation threshold") {
                Slider(value: $threshold, in: 0.05...10, step: 0.05)
                Text(String(format: "%.2f MB/s", threshold)).font(.caption.monospacedDigit()).frame(width: 78)
            }
            LabeledContent("Stay visible after activity") {
                Slider(value: $linger, in: 0...10, step: 0.5)
                Text(String(format: "%.1f s", linger)).font(.caption.monospacedDigit()).frame(width: 54)
            }
            Text("Two sustained samples prevent tiny background requests from constantly taking over the notch. Linger smooths chunked transfers.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Closed notch") {
            Picker("Presentation", selection: $closedStyle) {
                Text("Stats").tag("Stats")
                Text("Download indicator").tag("Indicator")
                Text("Minimal").tag("Minimal")
            }.pickerStyle(.segmented)
            Text(closedStyle == "Indicator" ? "Indicator mode turns the notch itself into a live transfer indicator, similar to Halo's update/download presentation. Because system-wide traffic does not expose universal file progress, the fill represents live transfer activity rather than a fake percentage." : "Choose how much transfer information should replace the normal closed-notch contents.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if closedStyle == "Indicator" || openStyle == "Indicator" {
            Section("Indicator") {
                Picker("Style", selection: $indicatorStyle) {
                    Text("Edge Bar").tag("Edge Bar")
                    Text("Center Pulse").tag("Center Pulse")
                    Text("Dual Rails").tag("Dual Rails")
                    Text("Minimal").tag("Minimal")
                }
                Toggle("Show live speed", isOn: $indicatorShowSpeed)
                LabeledContent("Thickness") {
                    Slider(value: $indicatorThickness, in: 1.5...10, step: 0.5)
                    Text(String(format: "%.1f pt", indicatorThickness)).font(.caption.monospacedDigit()).frame(width: 48)
                }
                LabeledContent("Intensity") {
                    Slider(value: $indicatorIntensity, in: 0.2...1, step: 0.05)
                    Text("\(Int((indicatorIntensity * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 42)
                }
            }
        }

        Section("Opened notch") {
            Picker("Presentation", selection: $openStyle) {
                Text("Dashboard").tag("Dashboard")
                Text("Indicator").tag("Indicator")
                Text("Minimal").tag("Minimal")
            }.pickerStyle(.segmented)
            if openStyle == "Dashboard" {
                Toggle("Compact presentation", isOn: $compact)
            }
            Toggle("Show transfer direction", isOn: $showDirection)
            Toggle("Show download speed", isOn: $showDownload).disabled(openStyle == "Indicator")
            Toggle("Show upload speed", isOn: $showUpload).disabled(openStyle == "Indicator")
            Toggle("Show peak speeds", isOn: $showPeak).disabled(compact || openStyle != "Dashboard")
            Toggle("Show transferred this session", isOn: $showSession).disabled(compact || openStyle != "Dashboard")
            Toggle("Show elapsed time", isOn: $showElapsed)
            Toggle("Show live throughput graph", isOn: $showGraph).disabled(compact || openStyle != "Dashboard")
            Text("Transfer CI now sizes itself from the content you enable. Removing graph, session totals, peaks or stat blocks shrinks the opened notch; enabling them grows it again.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Transfer CI priority") }
            Text("Transfer defaults to priority 65: above Music and Bluetooth, below Teleprompter, Retro and Drop.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Background") {
            Picker("Style", selection: $backgroundStyle) {
                Text("Gradient").tag("Gradient")
                Text("Dynamic").tag("Dynamic")
                Text("Accent").tag("Accent")
                Text("Glass").tag("Glass")
                Text("Black").tag("Black")
            }
            if backgroundStyle == "Gradient" || backgroundStyle == "Dynamic" || backgroundStyle == "Glass" {
                LabeledContent("Primary hue") { Slider(value: $backgroundPrimaryHue, in: 0...1) }
            }
            if backgroundStyle == "Gradient" {
                LabeledContent("Secondary hue") { Slider(value: $backgroundSecondaryHue, in: 0...1) }
            }
            if backgroundStyle == "Gradient" || backgroundStyle == "Dynamic" || backgroundStyle == "Glass" {
                LabeledContent("Saturation") { Slider(value: $backgroundSaturation, in: 0...1) }
                LabeledContent("Brightness") { Slider(value: $backgroundBrightness, in: 0.05...1) }
            }
            LabeledContent("Background opacity") {
                Slider(value: $backgroundOpacity, in: 0.15...1)
                Text("\(Int((backgroundOpacity * 100).rounded()))%").font(.caption.monospacedDigit()).frame(width: 42)
            }
            Text(backgroundStyle == "Dynamic" ? "Dynamic shifts toward download/accent or upload/orange colors based on the active direction." : "Transfer styling is isolated from your normal notch appearance.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("What Halo can detect") {
            Text("System-wide transfer detection can report real throughput, direction, totals and peaks, but macOS does not expose a universal file progress percentage for every browser and app. Indicator mode therefore represents live transfer activity unless a future app-specific provider can supply real progress.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct TeleprompterContextInterfaceCard: View {
    let action: () -> Void
    @AppStorage("HaloContextTeleprompterEnabled") private var ciEnabled = true
    @AppStorage("HaloContextTeleprompterPriority") private var priority = 70.0
    @ObservedObject private var teleprompter = TeleprompterStore.shared
    @State private var hovered = false

    private var enabled: Bool { ciEnabled && teleprompter.profiles.contains(where: { $0.enabled }) }
    private var triggerCount: Int { teleprompter.profiles.reduce(0) { $0 + $1.triggers.filter(\.enabled).count } }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color.indigo.opacity(0.34), Color.black.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("READ · RECORD · PRESENT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72))
                        HStack(spacing: 5) {
                            Capsule().fill(.white.opacity(0.24)).frame(width: 44, height: 4)
                            Capsule().fill(.white.opacity(0.85)).frame(width: 76, height: 5)
                            Capsule().fill(.white.opacity(0.24)).frame(width: 44, height: 4)
                        }
                    }
                }
                .frame(height: 112)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Teleprompter CI").font(.headline)
                        Text("Creator & Presentation").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(enabled ? "Enabled" : "Available")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((enabled ? Color.green : Color.secondary).opacity(0.12), in: Capsule())
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }

                Text("A camera-aligned prompting interface with scripts, profiles, auto-scroll, capture hiding, and context-aware launch triggers.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)

                HStack {
                    Label("\(teleprompter.profiles.count) profile\(teleprompter.profiles.count == 1 ? "" : "s")", systemImage: "doc.text")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("\(triggerCount) trigger\(triggerCount == 1 ? "" : "s")")
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

private struct TeleprompterContextSettings: View {
    @ObservedObject private var teleprompter = TeleprompterStore.shared
    @AppStorage("HaloContextTeleprompterEnabled") private var ciEnabled = true
    @AppStorage("HaloContextTeleprompterPriority") private var priority = 70.0

    var body: some View {
        Section("Teleprompter Context Interface") {
            Toggle("Enable Teleprompter CI", isOn: $ciEnabled)
                .onChange(of: ciEnabled) { enabled in
                    if !enabled { TeleprompterCoordinator.shared.hidePrompt() }
                }
            Text("Disabling Teleprompter CI keeps your scripts, profiles, triggers and contexts saved, but prevents the CI from opening.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Camera-aligned prompting").font(.headline)
                    Text("Scripts can launch from keyboard, mouse, trackpad, recording state, or app context.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open Teleprompter Studio…") { TeleprompterCoordinator.shared.showSettings() }
                    .buttonStyle(.borderedProminent)
            }
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Teleprompter CI priority") }
            Text("When multiple Context Interfaces are eligible, Halo gives notch ownership to the enabled CI with the highest priority. Teleprompter defaults to 70, between Retro and Music.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Profiles") {
            if teleprompter.profiles.isEmpty {
                Text("No teleprompter profiles yet.").foregroundStyle(.secondary)
            } else {
                ForEach(teleprompter.profiles) { profile in
                    HStack(spacing: 10) {
                        Image(systemName: profile.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(profile.enabled ? Color.green : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name).font(.callout.weight(.semibold))
                            Text("\(profile.triggers.filter(\.enabled).count) triggers · \(Int(profile.behavior.wordsPerMinute)) WPM · \(profile.behavior.displayMode.rawValue)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Preview") { TeleprompterCoordinator.shared.show(profile: profile) }
                            .controlSize(.small)
                    }
                }
            }
            HStack {
                Button("New Profile") { teleprompter.addProfile() }
                Button("Configure All…") { TeleprompterCoordinator.shared.showSettings() }
            }
        }

        Section("Trigger & context engine") {
            Label("Keyboard and mouse shortcuts", systemImage: "keyboard")
            Label("Trackpad swipe and pinch gestures", systemImage: "hand.draw")
            Label("App opened / app activated", systemImage: "app.badge")
            Label("Screen-recording start / stop", systemImage: "record.circle")
            Label("Frontmost app, running app, window title, display count and time contexts", systemImage: "switch.2")
            Text("Each profile can use multiple triggers and multiple context conditions with Any/All matching.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Capture privacy") {
            Label("Teleprompter windows can be excluded from screen capture while remaining visible to you.", systemImage: "eye.slash")
                .font(.caption)
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
    private let updates = HaloUpdateController.shared
    private var version: String { updates.currentVersion }
    private var build: String { updates.currentBuild }

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

        Section("Software Update") {
            LabeledContent("Installed version", value: "\(version) (\(build))")
            HStack {
                Button("Check for Updates…") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.isConfigured)

                Button("What's New") {
                    HaloWhatsNewCoordinator.shared.present()
                }
            }
            if !updates.isConfigured {
                Label("Update configuration is unavailable in this build.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

        Section("Support") {
            Link("Contact Halo support · r.support@redstoneinvente.com", destination: URL(string: "mailto:r.support@redstoneinvente.com")!)
        }
    }
}

private struct HaloCustomCISettingsSection: View {
    @ObservedObject private var runtime = HaloCustomCIRuntimeStore.shared
    @AppStorage("HaloDisableCustomCI") private var disableCustomCI = false

    var body: some View {
        Section("Custom CI") {
            Toggle("Disable custom CI", isOn: $disableCustomCI)
                .onChange(of: disableCustomCI) { disabled in
                    if disabled { runtime.clearManualActivation() }
                }
            Text(disableCustomCI
                 ? "Custom CI packages stay installed, but none can render, trigger, or run brokered actions while this switch is on. Built-in Halo CIs are unaffected."
                 : "Loaded .haloCI packages are enabled through Halo\'s declarative CI SDK. They render with Halo-owned components and cannot run Swift, JavaScript, shell commands, dylibs, or arbitrary native code.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Button("Import .haloCI…") { runtime.chooseAndImportPackage() }
                    .disabled(disableCustomCI)
                Button("Reload") { runtime.reload() }
                    .disabled(disableCustomCI)
                Spacer()
                Text("SDK 0.1 · declarative")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            if let notice = runtime.notice, !notice.isEmpty {
                Label(notice, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            }
            if let error = runtime.errorMessage, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
            }
        }

        if !disableCustomCI {
            Section("Loaded custom CI") {
                if runtime.packages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("No custom CIs loaded", systemImage: "rectangle.stack.badge.plus")
                            .font(.headline)
                        Text("Import an unpacked folder ending in .haloCI. Halo validates the manifest, declarative component tree, bindings, triggers, actions, assets, permissions, size limits and executable-content rules before installing it.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 12)], alignment: .leading, spacing: 12) {
                        ForEach(runtime.packages, id: \.manifest.id) { package in
                            HaloCustomCIPackageCard(package: package)
                        }
                    }.padding(.vertical, 5)
                }
            }

            if !runtime.invalidPackages.isEmpty {
                Section("Custom CI diagnostics") {
                    ForEach(runtime.invalidPackages) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(item.name, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            ForEach(Array(item.issues.filter { $0.severity == .error }.prefix(4))) { issue in
                                Text("\(issue.path): \(issue.message)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct HaloCustomCIPackageCard: View {
    let package: HaloCIParsedPackage
    @ObservedObject private var runtime = HaloCustomCIRuntimeStore.shared
    @State private var hovered = false

    private var id: String { package.manifest.id }
    private var requested: [String] { runtime.requestedPermissions(package) }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "rectangle.3.group.bubble.left.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.manifest.name).font(.headline).lineLimit(1)
                    Text("\(package.manifest.author) · v\(package.manifest.version)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { runtime.isEnabled(id) },
                    set: { runtime.setEnabled($0, packageID: id) }
                )).labelsHidden().toggleStyle(.switch)
            }

            if !package.manifest.description.isEmpty {
                Text(package.manifest.description).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }

            LabeledContent("Priority") {
                Slider(value: Binding(
                    get: { runtime.priority(id) },
                    set: { runtime.setPriority($0, packageID: id) }
                ), in: 0...100, step: 1)
                .frame(maxWidth: 120)
                Text("\(Int(runtime.priority(id)))").font(.caption.monospacedDigit()).frame(width: 28)
            }.font(.caption)

            if !requested.isEmpty {
                Divider()
                Text("Permissions").font(.caption.weight(.semibold))
                ForEach(requested, id: \.self) { permission in
                    Toggle(permission, isOn: Binding(
                        get: { runtime.hasPermission(id, permission) },
                        set: { runtime.setPermission(permission, granted: $0, packageID: id) }
                    )).font(.caption)
                }
                Text("Permissions are per CI and can be revoked here at any time.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if !package.issues.filter({ $0.severity == .warning }).isEmpty {
                Label("\(package.issues.filter { $0.severity == .warning }.count) validation warning(s)", systemImage: "exclamationmark.circle")
                    .font(.caption2).foregroundStyle(.orange)
            }

            HStack {
                Button("Open") { runtime.requestManualActivation(id) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!runtime.isEnabled(id))
                Spacer()
                Text("Priority \(Int(runtime.priority(id)))")
                    .font(.caption2).foregroundStyle(.secondary)
                Button("Remove", role: .destructive) { runtime.removePackage(id) }
                    .controlSize(.small)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(hovered ? 0.075 : 0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(hovered ? Color.accentColor.opacity(0.38) : Color.primary.opacity(0.08), lineWidth: 1))
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.14), value: hovered)
    }
}
