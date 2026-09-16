from pathlib import Path

settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
widgets_path = Path("Halo/Views/WidgetSettingsView.swift")
settings = settings_path.read_text()
widgets = widgets_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        print(f"{label}: already applied")
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    print(f"{label}: patched")
    return text.replace(old, new, 1)


settings = replace_once(
    settings,
    '''    private func sectionHelp(_ name: String) -> String {
        guard isSectionUnavailable(name) else { return name }
        return "Available in the Default layout only. Use Visual Workspace Editor while Visual Workspace is active."
    }
''',
    '''    private func sectionHelp(_ name: String) -> String {
        guard isSectionUnavailable(name) else { return name }
        return "\\(name) is locked while Visual Workspace is active. Configure these controls in Visual Workspace Editor, or switch Appearance → Opened Space → Layout System to Default."
    }

    private var sidebarSelection: Binding<String?> {
        Binding(
            get: { section },
            set: { candidate in
                guard let candidate else {
                    section = nil
                    return
                }
                guard !isSectionUnavailable(candidate) else { return }
                section = candidate
            }
        )
    }
''',
    "locked-section explanation and guarded selection",
)

settings = replace_once(
    settings,
    '                    Text("Default")\n',
    '                    Text("Default only")\n',
    "locked badge copy",
)

settings = replace_once(
    settings,
    '                List(selection: $section) {\n',
    '                List(selection: sidebarSelection) {\n',
    "guard sidebar selection",
)

settings = replace_once(
    settings,
    '''                        sidebarRow(name)
                            .tag(name)
                            .disabled(isSectionUnavailable(name))
''',
    '''                        sidebarRow(name)
                            .tag(name)
                            .selectionDisabled(isSectionUnavailable(name))
''',
    "disable list selection without killing hover help",
)

settings = replace_once(
    settings,
    '''                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout)
                        .frame(minWidth: 920, minHeight: 620)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
''',
    '''                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout, showsCloseButton: false)
                        .frame(minWidth: 980, idealWidth: 1080, minHeight: 660)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
''',
    "embedded editor sizing",
)

widgets = replace_once(
    widgets,
    '''struct OpenedNotchWorkspaceEditor: View {
    @Binding var layout: WorkspaceLayout
    @Environment(\\.dismiss) private var dismiss
''',
    '''struct OpenedNotchWorkspaceEditor: View {
    @Binding var layout: WorkspaceLayout
    var showsCloseButton = true
    @Environment(\\.dismiss) private var dismiss
''',
    "editor embedding option",
)

widgets = replace_once(
    widgets,
    '''            HSplitView {
                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    ScrollView([.horizontal, .vertical]) { preview.padding(26).frame(minWidth: 640, minHeight: 560) }
                }.frame(minWidth: 650)
                inspector.frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
            }
''',
    '''            HSplitView {
                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    GeometryReader { proxy in
                        ScrollView([.horizontal, .vertical]) {
                            preview(canvasSize: previewCanvasSize(for: proxy.size))
                                .padding(22)
                                .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .top)
                        }
                    }
                }
                .frame(minWidth: 680, idealWidth: 760)
                inspector
                    .frame(minWidth: 340, idealWidth: 390, maxWidth: 460)
                    .frame(maxHeight: .infinity)
            }
            .frame(minWidth: 1020, minHeight: 640)
''',
    "responsive editor split layout",
)

widgets = replace_once(
    widgets,
    '''            Spacer(minLength: 16)
            Button { dismiss() } label: {
                Label("Close", systemImage: "xmark")
            }
            .keyboardShortcut(.cancelAction)
            .help("Close Visual Workspace")
''',
    '''            Spacer(minLength: 16)
            if showsCloseButton {
                Button { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
                .help("Close Visual Workspace")
            }
''',
    "hide redundant embedded close button",
)

widgets = replace_once(
    widgets,
    '''    private var preview: some View {
        VStack(spacing: 10) {
''',
    '''    private func previewCanvasSize(for available: CGSize) -> CGSize {
        let width = min(760, max(610, available.width - 44))
        let height = min(580, max(470, available.height - 96))
        return CGSize(width: width, height: height)
    }

    private func preview(canvasSize: CGSize) -> some View {
        VStack(spacing: 10) {
''',
    "responsive preview helper",
)

widgets = replace_once(
    widgets,
    '''                Text("Drag a widget onto a grid cell · choose its standard size in the inspector")
                    .font(.caption).foregroundStyle(.secondary)
''',
    '''                Text("Drag a widget onto a grid cell · choose its standard size in the inspector")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 300, alignment: .trailing)
''',
    "preview instruction layout",
)

widgets = replace_once(
    widgets,
    '''                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                .frame(width: 610, height: 470)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)
''',
    '''                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                .frame(width: canvasSize.width, height: canvasSize.height)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)
''',
    "responsive preview canvas",
)

settings_path.write_text(settings)
widgets_path.write_text(widgets)
print("Visual Workspace navigation and editor layout polish applied.")
