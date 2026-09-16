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
                guard let candidate else { return }
                guard !isSectionUnavailable(candidate) else { return }
                section = candidate
            }
        )
    }
''',
    "guard locked sidebar selection",
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
    "use guarded sidebar binding",
)

settings = replace_once(
    settings,
    '''                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout)
                        .frame(minWidth: 920, minHeight: 620)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
''',
    '''                    OpenedNotchWorkspaceEditor(layout: $workspace.settings.layout, showsCloseButton: false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
''',
    "remove embedded editor hard minimum",
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
    '''    var body: some View {
        VStack(spacing: 0) {
            visualWorkspaceHeader
            Divider()
            HSplitView {
                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    ScrollView([.horizontal, .vertical]) { preview.padding(26).frame(minWidth: 640, minHeight: 560) }
                }.frame(minWidth: 650)
                inspector.frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
            }
        }
        .onAppear { materialize(); calendarSources.refresh() }
    }
''',
    '''    var body: some View {
        VStack(spacing: 0) {
            visualWorkspaceHeader
            Divider()
            GeometryReader { proxy in
                editorLayout(availableSize: proxy.size)
            }
        }
        .onAppear { materialize(); calendarSources.refresh() }
    }

    @ViewBuilder
    private func editorLayout(availableSize: CGSize) -> some View {
        if !showsCloseButton && availableSize.width < 900 {
            VSplitView {
                editorCanvasPane
                    .frame(minHeight: 350)
                inspector
                    .frame(minHeight: 250, idealHeight: 320)
            }
        } else if !showsCloseButton {
            let inspectorWidth = min(380, max(310, availableSize.width * 0.31))
            HStack(spacing: 0) {
                editorCanvasPane
                    .frame(width: max(460, availableSize.width - inspectorWidth - 1))
                Divider()
                inspector
                    .frame(width: inspectorWidth)
                    .frame(maxHeight: .infinity)
            }
        } else {
            HSplitView {
                editorCanvasPane
                    .frame(minWidth: 620, idealWidth: 760)
                inspector
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 430)
            }
        }
    }

    private var editorCanvasPane: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    preview(canvasSize: previewCanvasSize(for: proxy.size))
                        .padding(18)
                        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
    }
''',
    "responsive editor container",
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
    '''    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("Workspace", selection: Binding(
                get: { opened.resolvedContentMode },
                set: { mode in var value = opened; value.contentMode = mode; layout.openNotch = value }
            )) {
                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 250)
            Picker("Preset", selection: Binding(get: { opened.preset }, set: { applyPreset($0) })) {
                ForEach(OpenNotchPreset.allCases) { Text($0.rawValue).tag($0) }
            }.frame(width: 190)
            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            Menu {
                Button("4 × 3") { setGrid(columns: 4, rows: 3) }
                Button("6 × 3") { setGrid(columns: 6, rows: 3) }
                Button("6 × 4") { setGrid(columns: 6, rows: 4) }
                Button("8 × 4") { setGrid(columns: 8, rows: 4) }
                Divider()
                Button("Auto Pack Widgets") { repackGrid() }
            } label: { Label("Grid", systemImage: "square.grid.3x3") }
            Button { duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.disabled(selectedItem == nil).help("Duplicate selected item")
            Button { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil } label: { Image(systemName: "paintbrush") }.help("Opened surface appearance")
            Spacer(minLength: 0)
        }.padding(12)
    }
''',
    '''    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                workspaceModePicker.frame(width: 210)
                presetPicker.frame(width: 155)
                Menu { addMenu } label: { Label("Add", systemImage: "plus") }
                gridMenu
                Button { duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }
                    .disabled(selectedItem == nil)
                    .help("Duplicate selected item")
                Button { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil } label: { Image(systemName: "paintbrush") }
                    .help("Opened surface appearance")
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                workspaceModePicker.frame(minWidth: 150, idealWidth: 180)
                presetPicker.frame(minWidth: 120, idealWidth: 145)
                Menu {
                    Menu("Add Widget") { addMenu }
                    Divider()
                    Menu("Grid") {
                        Button("4 × 3") { setGrid(columns: 4, rows: 3) }
                        Button("6 × 3") { setGrid(columns: 6, rows: 3) }
                        Button("6 × 4") { setGrid(columns: 6, rows: 4) }
                        Button("8 × 4") { setGrid(columns: 8, rows: 4) }
                        Divider()
                        Button("Auto Pack Widgets") { repackGrid() }
                    }
                    Button("Duplicate Selected") { duplicateSelected() }.disabled(selectedItem == nil)
                    Button("Surface Appearance") { backgroundMode = true; selectedItem = nil; selectedGroup = nil; selectedRegion = nil }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var workspaceModePicker: some View {
        Picker("Workspace", selection: Binding(
            get: { opened.resolvedContentMode },
            set: { mode in var value = opened; value.contentMode = mode; layout.openNotch = value }
        )) {
            ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }
        }
    }

    private var presetPicker: some View {
        Picker("Preset", selection: Binding(get: { opened.preset }, set: { applyPreset($0) })) {
            ForEach(OpenNotchPreset.allCases) { Text($0.rawValue).tag($0) }
        }
    }

    private var gridMenu: some View {
        Menu {
            Button("4 × 3") { setGrid(columns: 4, rows: 3) }
            Button("6 × 3") { setGrid(columns: 6, rows: 3) }
            Button("6 × 4") { setGrid(columns: 6, rows: 4) }
            Button("8 × 4") { setGrid(columns: 8, rows: 4) }
            Divider()
            Button("Auto Pack Widgets") { repackGrid() }
        } label: {
            Label("Grid", systemImage: "square.grid.3x3")
        }
    }
''',
    "responsive editor toolbar",
)

widgets = replace_once(
    widgets,
    '''    private var preview: some View {
        VStack(spacing: 10) {
''',
    '''    private func previewCanvasSize(for available: CGSize) -> CGSize {
        let aspect: CGFloat = 610.0 / 470.0
        let maximumWidth = min(760, max(420, available.width - 36))
        let maximumHeight = min(580, max(325, available.height - 84))
        var width = maximumWidth
        var height = width / aspect
        if height > maximumHeight {
            height = maximumHeight
            width = height * aspect
        }
        return CGSize(width: max(420, width), height: max(325, height))
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
print("Visual Workspace navigation and responsive editor polish applied.")
