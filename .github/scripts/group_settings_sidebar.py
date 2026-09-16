from pathlib import Path

path = Path("Halo/Views/WorkspaceSettingsView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        print(f"{label}: already applied")
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    text = text.replace(old, new, 1)
    print(f"{label}: patched")


replace_once(
    '''    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    private var visualWorkspaceActive: Bool {
        workspace.settings.layout.resolvedUsesCustomOpenNotchWorkspace
    }

    private var sections: [String] {
        var items = ["General", "Account & License", "Appearance", "Activation Sequence"]
        if visualWorkspaceActive {
            items.append("Visual Workspace Editor")
        }
        items.append(contentsOf: ["Modules", "Widgets", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "Update Animation", "About"])
        return items
    }
''',
    '''    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
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
                items: ["Appearance", "Activation Sequence", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD"]
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
        sidebarGroups.flatMap(\\.items)
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
''',
    "sidebar group model",
)

replace_once(
    '''                List(selection: sidebarSelection) {
                    ForEach(sections.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \\.self) { name in
                        sidebarRow(name)
                            .tag(name)
                            .disabled(isSectionUnavailable(name))
                    }
                }.listStyle(.sidebar)
''',
    '''                List(selection: sidebarSelection) {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ForEach(sidebarGroups) { group in
                            DisclosureGroup(isExpanded: sidebarGroupExpansion(group)) {
                                ForEach(group.items, id: \\.self) { name in
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
                                    ForEach(matches, id: \\.self) { name in
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
''',
    "grouped sidebar list",
)

replace_once(
    '''        .onChange(of: visualWorkspaceActive) { active in
            if active && (section == "Modules" || section == "Widgets") {
                section = "Visual Workspace Editor"
            } else if !active && section == "Visual Workspace Editor" {
                section = "Appearance"
            }
        }
''',
    '''        .onChange(of: visualWorkspaceActive) { active in
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
''',
    "auto expand selected group",
)

path.write_text(text)
print("Settings sidebar grouping applied.")
