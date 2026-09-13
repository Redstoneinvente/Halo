from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {text.count(old)}')
    return text.replace(old, new, 1)

# 1) Theme width range
path = Path('Halo/Core/Models.swift')
text = path.read_text()
text = replace_once(
    text,
    '        result.width = min(640, max(340, width))\n',
    '        result.width = min(1200, max(340, width))\n',
    'theme width validation'
)
path.write_text(text)

# 2) Open notch layout model + compatibility
path = Path('Halo/Core/WorkspaceModels.swift')
text = path.read_text()
text = replace_once(
    text,
    'struct WorkspaceLayout: Codable, Equatable {\n',
    '''enum OpenNotchContentMode: String, Codable, CaseIterable, Identifiable {\n    case fixed = "Fixed Canvas"\n    case scroll = "Scroll"\n    case pages = "Pages"\n    var id: String { rawValue }\n}\n\nstruct WorkspaceLayout: Codable, Equatable {\n''',
    'open notch mode enum'
)
text = replace_once(
    text,
    '''    var horizontalWidgets: Bool?\n    var horizontalPages: Bool?\n    var horizontalHeight: Double?\n    var widgets: [String: WidgetStyle]?\n''',
    '''    var horizontalWidgets: Bool?\n    var horizontalPages: Bool?\n    var horizontalHeight: Double?\n    // Optional so existing workspaces and exported profiles decode unchanged.\n    var openNotchContentMode: OpenNotchContentMode?\n    var openHorizontalPadding: Double?\n    var openVerticalPadding: Double?\n    var openFixedColumns: Int?\n    var widgets: [String: WidgetStyle]?\n''',
    'workspace open notch fields'
)
text = replace_once(
    text,
    '''    var closedNotch: ClosedNotchOptions?\n    func widgetStyle(for id: ModuleID) -> WidgetStyle {\n''',
    '''    var closedNotch: ClosedNotchOptions?\n\n    var resolvedOpenNotchContentMode: OpenNotchContentMode {\n        if let openNotchContentMode { return openNotchContentMode }\n        return (horizontalPages ?? false) ? .pages : .scroll\n    }\n    var resolvedOpenHorizontalPadding: Double {\n        min(72, max(8, openHorizontalPadding ?? max(20, appearance.surface.shoulder + 12)))\n    }\n    var resolvedOpenVerticalPadding: Double {\n        min(72, max(8, openVerticalPadding ?? 20))\n    }\n    var resolvedOpenFixedColumns: Int {\n        min(4, max(1, openFixedColumns ?? 2))\n    }\n\n    func widgetStyle(for id: ModuleID) -> WidgetStyle {\n''',
    'workspace resolved open notch values'
)
text = replace_once(
    text,
    '        appearance.expandedHeight = min(800, max(280, appearance.expandedHeight))\n',
    '        appearance.expandedHeight = min(1100, max(280, appearance.expandedHeight))\n',
    'expanded height archive validation'
)
text = replace_once(
    text,
    '        appearance.spacing = min(28, max(4, appearance.spacing))\n',
    '        appearance.spacing = min(48, max(4, appearance.spacing))\n',
    'spacing archive validation'
)
text = replace_once(
    text,
    '''        if let height = layout.horizontalHeight {\n            guard height.isFinite else { throw CocoaError(.fileReadCorruptFile) }\n            archive.layout.horizontalHeight = min(500, max(200, height))\n        }\n        archive.layout.appearance = appearance\n''',
    '''        if let height = layout.horizontalHeight {\n            guard height.isFinite else { throw CocoaError(.fileReadCorruptFile) }\n            archive.layout.horizontalHeight = min(1100, max(200, height))\n        }\n        if let value = layout.openHorizontalPadding {\n            guard value.isFinite else { throw CocoaError(.fileReadCorruptFile) }\n            archive.layout.openHorizontalPadding = min(72, max(8, value))\n        }\n        if let value = layout.openVerticalPadding {\n            guard value.isFinite else { throw CocoaError(.fileReadCorruptFile) }\n            archive.layout.openVerticalPadding = min(72, max(8, value))\n        }\n        if let columns = layout.openFixedColumns {\n            archive.layout.openFixedColumns = min(4, max(1, columns))\n        }\n        archive.layout.appearance = appearance\n''',
    'open notch archive validation'
)
path.write_text(text)

# 3) Render configuration observes new open-notch settings
path = Path('Halo/Core/SurfaceModels.swift')
text = path.read_text()
text = replace_once(
    text,
    '''    var horizontalWidgets: Bool? = nil\n    var horizontalHeight: Double? = nil\n}\n''',
    '''    var horizontalWidgets: Bool? = nil\n    var horizontalPages: Bool? = nil\n    var horizontalHeight: Double? = nil\n    var openNotchContentMode: OpenNotchContentMode? = nil\n    var openHorizontalPadding: Double? = nil\n    var openVerticalPadding: Double? = nil\n    var openFixedColumns: Int? = nil\n}\n''',
    'surface render configuration fields'
)
path.write_text(text)

# 4) Geometry updates and legacy migration behavior
path = Path('Halo/NotchEngine/WindowManager.swift')
text = path.read_text()
text = replace_once(
    text,
    '''            return SurfaceRenderConfiguration(appearance: layout.appearance, displays: resolvedDisplays, closedNotch: layout.closedNotch, clock: layout.widgetStyle(for: .clock), horizontalWidgets: layout.horizontalWidgets, horizontalHeight: layout.horizontalHeight)\n''',
    '''            return SurfaceRenderConfiguration(\n                appearance: layout.appearance,\n                displays: resolvedDisplays,\n                closedNotch: layout.closedNotch,\n                clock: layout.widgetStyle(for: .clock),\n                horizontalWidgets: layout.horizontalWidgets,\n                horizontalPages: layout.horizontalPages,\n                horizontalHeight: layout.horizontalHeight,\n                openNotchContentMode: layout.openNotchContentMode,\n                openHorizontalPadding: layout.openHorizontalPadding,\n                openVerticalPadding: layout.openVerticalPadding,\n                openFixedColumns: layout.openFixedColumns\n            )\n''',
    'surface render configuration creation'
)
text = replace_once(
    text,
    '''            if effectiveLayout.horizontalWidgets ?? false {\n                let requested = effectiveLayout.horizontalHeight ?? 260\n                appearance.expandedHeight = requested.isFinite ? min(500, max(200, requested)) : 260\n            }\n''',
    '''            // Preserve the old horizontal-height behavior only for layouts saved before\n            // the explicit opened-notch content mode existed. New modes always use the main\n            // expanded-height control, so Fixed Canvas, Scroll and Pages get the same roomy space.\n            if effectiveLayout.openNotchContentMode == nil, effectiveLayout.horizontalWidgets ?? false {\n                let requested = effectiveLayout.horizontalHeight ?? 260\n                appearance.expandedHeight = requested.isFinite ? min(1100, max(200, requested)) : 260\n            }\n''',
    'legacy horizontal height behavior'
)
path.write_text(text)

# 5) Open notch runtime layout
path = Path('Halo/Views/SurfaceView.swift')
text = path.read_text()
pattern = re.compile(
    r'''                            if layout\.horizontalWidgets \?\? false \{\n.*?\n                            \}\n(?=                            HStack \{\n                                Spacer\(\)\n                                Button\("Settings"\))''',
    re.S,
)
text, count = pattern.subn('                            openDashboardContent\n', text, count=1)
if count != 1:
    raise SystemExit(f'open dashboard runtime branch: expected one match, found {count}')
text = replace_once(
    text,
    '''                        }.padding(.horizontal, max(20, layout.appearance.surface.shoulder + 12)).padding(.vertical, 20).frame(width: state.dashboardWidth).transition(.opacity)\n''',
    '''                        }\n                        .padding(.horizontal, CGFloat(layout.resolvedOpenHorizontalPadding))\n                        .padding(.vertical, CGFloat(layout.resolvedOpenVerticalPadding))\n                        .frame(width: state.dashboardWidth)\n                        .transition(.opacity)\n''',
    'open dashboard padding'
)
helper_marker = '''    @ViewBuilder private func widgetCards(horizontal: Bool) -> some View {\n'''
helper = '''    @ViewBuilder private var openDashboardContent: some View {\n        switch layout.resolvedOpenNotchContentMode {\n        case .fixed:\n            GeometryReader { proxy in\n                if modules.isEmpty {\n                    Text("Enable widgets in Settings → Modules.")\n                        .foregroundStyle(.secondary)\n                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)\n                } else {\n                    let columns = max(1, min(layout.resolvedOpenFixedColumns, modules.count))\n                    let rows = max(1, Int(ceil(Double(modules.count) / Double(columns))))\n                    let gap = CGFloat(layout.appearance.spacing)\n                    let cellHeight = max(1, (proxy.size.height - gap * CGFloat(max(0, rows - 1))) / CGFloat(rows))\n                    LazyVGrid(\n                        columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: columns),\n                        spacing: gap\n                    ) {\n                        ForEach(modules) { module in\n                            horizontalWidget(module)\n                                .frame(height: cellHeight)\n                        }\n                    }\n                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                }\n            }\n        case .scroll:\n            if layout.horizontalWidgets ?? false {\n                ScrollView(.horizontal) {\n                    LazyHStack(alignment: .top, spacing: layout.appearance.spacing) {\n                        widgetCards(horizontal: true)\n                    }\n                }\n            } else {\n                ScrollView {\n                    LazyVStack(spacing: layout.appearance.spacing) {\n                        widgetCards(horizontal: false)\n                    }\n                }\n            }\n        case .pages:\n            VStack(spacing: 8) {\n                if !modules.isEmpty {\n                    let index = min(page, modules.count - 1)\n                    horizontalWidget(modules[index])\n                    HStack {\n                        Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }\n                            .disabled(index == 0).accessibilityLabel("Previous widget")\n                        Spacer()\n                        Text("\\(modules[index].title) · \\(index + 1) / \\(modules.count)").font(.caption)\n                        Spacer()\n                        Button { page = min(modules.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }\n                            .disabled(index == modules.count - 1).accessibilityLabel("Next widget")\n                    }\n                } else {\n                    Text("Enable widgets in Settings → Modules.").foregroundStyle(.secondary)\n                }\n            }\n        }\n    }\n\n'''
text = replace_once(text, helper_marker, helper + helper_marker, 'open dashboard helper insertion')
path.write_text(text)

# 6) Open-notch settings and profile editor
path = Path('Halo/Views/WorkspaceSettingsView.swift')
text = path.read_text()
section_pattern = re.compile(
    r'''        Section\("Expanded dashboard"\) \{.*?\n        \}\n        Section\("Surface basics"\) \{''',
    re.S,
)
section_replacement = '''        Section("Opened notch workspace") {\n            Toggle("Keep closed-notch contents visible when opened", isOn: $keepClosedContentsWhenOpen)\n            Text("Keeps the normal Closed Notch widgets and media visible in the top strip. Context Interfaces keep their own layout rules.")\n                .font(.caption).foregroundStyle(.secondary)\n\n            Picker("Content behavior", selection: Binding(\n                get: { workspace.settings.layout.resolvedOpenNotchContentMode },\n                set: { mode in\n                    workspace.settings.layout.openNotchContentMode = mode\n                    workspace.settings.layout.horizontalPages = mode == .pages\n                    if mode == .pages { workspace.settings.layout.horizontalWidgets = true }\n                }\n            )) {\n                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }\n            }\n            .pickerStyle(.segmented)\n\n            switch workspace.settings.layout.resolvedOpenNotchContentMode {\n            case .fixed:\n                Picker("Fixed canvas columns", selection: Binding(\n                    get: { workspace.settings.layout.resolvedOpenFixedColumns },\n                    set: { workspace.settings.layout.openFixedColumns = $0 }\n                )) {\n                    ForEach(1...4, id: \\.self) { Text("\\($0)").tag($0) }\n                }\n                Text("All enabled widgets stay inside one fixed canvas. Halo divides the available height between rows instead of scrolling.")\n                    .font(.caption).foregroundStyle(.secondary)\n            case .scroll:\n                Picker("Scroll direction", selection: Binding(\n                    get: { workspace.settings.layout.horizontalWidgets ?? false },\n                    set: { workspace.settings.layout.horizontalWidgets = $0; workspace.settings.layout.horizontalPages = false }\n                )) {\n                    Text("Vertical").tag(false)\n                    Text("Horizontal").tag(true)\n                }\n                .pickerStyle(.segmented)\n                Text("Scroll keeps the notch size fixed while letting content move inside it.")\n                    .font(.caption).foregroundStyle(.secondary)\n            case .pages:\n                Text("Pages keeps one widget in focus at a time with previous/next navigation, using the full opened-notch workspace.")\n                    .font(.caption).foregroundStyle(.secondary)\n            }\n\n            Divider()\n            Slider(value: $store.configuration.theme.width, in: 340...1200, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Opened width") }\n            Slider(value: $workspace.settings.layout.appearance.expandedHeight, in: 280...1100, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Opened height") }\n            Slider(value: Binding(\n                get: { workspace.settings.layout.resolvedOpenHorizontalPadding },\n                set: { workspace.settings.layout.openHorizontalPadding = $0 }\n            ), in: 8...72) { Text("Side padding") }\n            Slider(value: Binding(\n                get: { workspace.settings.layout.resolvedOpenVerticalPadding },\n                set: { workspace.settings.layout.openVerticalPadding = $0 }\n            ), in: 8...72) { Text("Top & bottom padding") }\n            Slider(value: $workspace.settings.layout.appearance.spacing, in: 4...40) { Text("Module spacing") }\n            Text("Width is still limited by the display. Lower padding gives widgets more breathing room without changing the outer notch shape.")\n                .font(.caption).foregroundStyle(.secondary)\n        }\n        Section("Surface basics") {'''
text, count = section_pattern.subn(section_replacement, text, count=1)
if count != 1:
    raise SystemExit(f'opened notch settings section: expected one match, found {count}')
for old in [
    '            Slider(value: $store.configuration.theme.width, in: 340...640, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Expanded width") }\n',
    '            Slider(value: $workspace.settings.layout.appearance.expandedHeight, in: 280...800, onEditingChanged: { GeometryPreview.update(expanded: true, editing: $0) }) { Text("Expanded height") }\n',
    '            Slider(value: $workspace.settings.layout.appearance.spacing, in: 4...28) { Text("Module spacing") }\n',
]:
    text = replace_once(text, old, '', 'remove duplicate surface basics control')

profile_old = '''                    Picker("Surface", selection: $profile.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }\n                    Slider(value: $profile.theme.width, in: 340...640) { Text("Expanded width") }\n                    Toggle("Horizontal widgets", isOn: Binding(get: { profile.layout.horizontalWidgets ?? false }, set: { profile.layout.horizontalWidgets = $0 }))\n                    Toggle("Page navigation", isOn: Binding(get: { profile.layout.horizontalPages ?? false }, set: { profile.layout.horizontalPages = $0 }))\n                    Slider(value: Binding(get: { profile.layout.horizontalHeight ?? 260 }, set: { profile.layout.horizontalHeight = $0 }), in: 200...500) { Text("Horizontal height") }\n'''
profile_new = '''                    Picker("Surface", selection: $profile.theme.style) { ForEach(SurfaceStyle.allCases) { Text($0.rawValue).tag($0) } }\n                    Slider(value: $profile.theme.width, in: 340...1200) { Text("Opened width") }\n                    Picker("Opened content", selection: Binding(\n                        get: { profile.layout.resolvedOpenNotchContentMode },\n                        set: { mode in\n                            profile.layout.openNotchContentMode = mode\n                            profile.layout.horizontalPages = mode == .pages\n                            if mode == .pages { profile.layout.horizontalWidgets = true }\n                        }\n                    )) {\n                        ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }\n                    }\n                    .pickerStyle(.segmented)\n                    if profile.layout.resolvedOpenNotchContentMode == .fixed {\n                        Picker("Fixed canvas columns", selection: Binding(\n                            get: { profile.layout.resolvedOpenFixedColumns },\n                            set: { profile.layout.openFixedColumns = $0 }\n                        )) {\n                            ForEach(1...4, id: \\.self) { Text("\\($0)").tag($0) }\n                        }\n                    } else if profile.layout.resolvedOpenNotchContentMode == .scroll {\n                        Picker("Scroll direction", selection: Binding(\n                            get: { profile.layout.horizontalWidgets ?? false },\n                            set: { profile.layout.horizontalWidgets = $0; profile.layout.horizontalPages = false }\n                        )) {\n                            Text("Vertical").tag(false)\n                            Text("Horizontal").tag(true)\n                        }\n                        .pickerStyle(.segmented)\n                    }\n                    Slider(value: Binding(\n                        get: { profile.layout.resolvedOpenHorizontalPadding },\n                        set: { profile.layout.openHorizontalPadding = $0 }\n                    ), in: 8...72) { Text("Side padding") }\n                    Slider(value: Binding(\n                        get: { profile.layout.resolvedOpenVerticalPadding },\n                        set: { profile.layout.openVerticalPadding = $0 }\n                    ), in: 8...72) { Text("Top & bottom padding") }\n'''
text = replace_once(text, profile_old, profile_new, 'profile opened notch layout controls')
text = replace_once(
    text,
    '                        Slider(value: $profile.layout.appearance.expandedHeight, in: 280...800) { Text("Vertical dashboard height") }\n',
    '                        Slider(value: $profile.layout.appearance.expandedHeight, in: 280...1100) { Text("Opened height") }\n',
    'profile expanded height range'
)
path.write_text(text)

print('Opened notch workspace patch applied successfully.')
