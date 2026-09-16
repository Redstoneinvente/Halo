from pathlib import Path

path = Path("Halo/Views/WorkspaceSettingsView.swift")
s = path.read_text()


def once(old: str, new: str, label: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    s = s.replace(old, new, 1)


once(
    '    private let sections = ["General", "Account & License", "Appearance", "Activation Sequence", "Modules", "Widgets", "Closed notch", "Notch Ambient", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "Update Animation", "About"]',
    '''    private var visualWorkspaceActive: Bool {
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

    private func isSectionUnavailable(_ name: String) -> Bool {
        visualWorkspaceActive && (name == "Modules" || name == "Widgets")
    }

    private func sectionHelp(_ name: String) -> String {
        guard isSectionUnavailable(name) else { return name }
        return "Available in the Default layout only. Use Visual Workspace Editor while Visual Workspace is active."
    }

    @ViewBuilder
    private func sidebarRow(_ name: String) -> some View {
        HStack(spacing: 8) {
            Label(name, systemImage: sectionIcon(name))
            Spacer(minLength: 4)
            if isSectionUnavailable(name) {
                HStack(spacing: 3) {
                    Text("Default")
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
    }''',
    "dynamic settings sections",
)

once(
    '                    ForEach(sections.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \\.self) { Label($0, systemImage: sectionIcon($0)).padding(.vertical, 5).tag($0) }',
    '''                    ForEach(sections.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \\.self) { name in
                        sidebarRow(name)
                            .tag(name)
                            .disabled(isSectionUnavailable(name))
                    }''',
    "settings sidebar rows",
)

once(
    '                        Text("Changes are saved automatically").font(.caption).foregroundStyle(.secondary)',
    '                        Text(section == "Visual Workspace Editor" ? "Design the active Visual Workspace" : "Changes are saved automatically").font(.caption).foregroundStyle(.secondary)',
    "detail subtitle",
)

once(
    '                Form { content }.formStyle(.grouped).frame(maxWidth: .infinity, maxHeight: .infinity)',
    '''                if section == "Visual Workspace Editor", visualWorkspaceActive {
                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout)
                        .frame(minWidth: 920, minHeight: 620)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Form { content }
                        .formStyle(.grouped)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }''',
    "visual workspace editor detail",
)

once(
    '        }.frame(minWidth: 700, minHeight: 560)\n        .onDisappear { GeometryPreview.update(expanded: false, editing: false) }',
    '''        }.frame(minWidth: 700, minHeight: 560)
        .onChange(of: visualWorkspaceActive) { active in
            if active && (section == "Modules" || section == "Widgets") {
                section = "Visual Workspace Editor"
            } else if !active && section == "Visual Workspace Editor" {
                section = "Appearance"
            }
        }
        .onDisappear { GeometryPreview.update(expanded: false, editing: false) }''',
    "layout mode rerouting",
)

once(
    '        case "Activation Sequence": return "power.circle"\n        case "Modules": return "square.grid.2x2"',
    '        case "Activation Sequence": return "power.circle"\n        case "Visual Workspace Editor": return "rectangle.3.group"\n        case "Modules": return "square.grid.2x2"',
    "visual workspace editor icon",
)

path.write_text(s)
print("Visual Workspace settings navigation patched.")
