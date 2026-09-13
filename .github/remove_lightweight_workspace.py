from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)

# Workspace model: keep legacy element enums/cases decodable, but never expose them
# as active Workspace content. Workspace is widget/module-only from this point on.
models_path = Path("Halo/Core/WorkspaceModels.swift")
models = models_path.read_text()
models = replace_once(
    models,
    '''enum OpenNotchItemKind: String, Codable, CaseIterable, Identifiable {\n    case module, element, spacer, divider\n    var id: String { rawValue }\n}''',
    '''enum OpenNotchItemKind: String, Codable, CaseIterable, Identifiable {\n    // element/spacer/divider remain decodable for legacy saved layouts only.\n    case module, element, spacer, divider\n    static var allCases: [OpenNotchItemKind] { [.module] }\n    var id: String { rawValue }\n}''',
    "OpenNotchItemKind"
)
models = replace_once(
    models,
    '''enum OpenNotchElementKind: String, Codable, CaseIterable, Identifiable {\n    case clock, date, battery, batteryPercentage, chargingState''',
    '''enum OpenNotchElementKind: String, Codable, CaseIterable, Identifiable {\n    // Legacy decoding shim. Lightweight elements are no longer Workspace content.\n    case clock, date, battery, batteryPercentage, chargingState''',
    "OpenNotchElementKind header"
)
models = replace_once(
    models,
    '''    case customText, customIcon, customImage, customGIF, button, spacer, divider\n    var id: String { rawValue }''',
    '''    case customText, customIcon, customImage, customGIF, button, spacer, divider\n    static var allCases: [OpenNotchElementKind] { [] }\n    var id: String { rawValue }''',
    "OpenNotchElementKind allCases"
)
models = replace_once(
    models,
    '''        value.padding = try padding.validated(); value.items = try items.prefix(80).map { try $0.validated() }''',
    '''        value.padding = try padding.validated()\n        value.items = try items.prefix(80)\n            .filter { $0.kind == .module && $0.module != nil }\n            .map { try $0.validated() }''',
    "OpenNotchGroup validation"
)
models = replace_once(
    models,
    '''    var allItems: [OpenNotchItem] { gridItems ?? regions.flatMap(\\.groups).flatMap(\\.items) }\n    var resolvedGridItems: [OpenNotchItem] {\n        if let gridItems { return gridItems }\n        return Self.packedGridItems(from: regions.flatMap(\\.groups).flatMap(\\.items), columns: resolvedGridColumns)\n    }''',
    '''    var allItems: [OpenNotchItem] {\n        Self.workspaceWidgetItems(gridItems ?? regions.flatMap(\\.groups).flatMap(\\.items))\n    }\n    var resolvedGridItems: [OpenNotchItem] {\n        if let gridItems { return Self.workspaceWidgetItems(gridItems) }\n        return Self.packedGridItems(\n            from: Self.workspaceWidgetItems(regions.flatMap(\\.groups).flatMap(\\.items)),\n            columns: resolvedGridColumns\n        )\n    }''',
    "Workspace item filtering"
)
models = replace_once(
    models,
    '''    mutating func materializeGridItems() {\n        if gridItems == nil { gridItems = resolvedGridItems }\n        normalizeGridItems()\n    }\n\n    mutating func normalizeGridItems(pinnedID: UUID? = nil) {\n        guard var items = gridItems else { return }''',
    '''    mutating func materializeGridItems() {\n        if let gridItems {\n            self.gridItems = Self.workspaceWidgetItems(gridItems)\n        } else {\n            gridItems = resolvedGridItems\n        }\n        normalizeGridItems()\n    }\n\n    mutating func normalizeGridItems(pinnedID: UUID? = nil) {\n        guard var items = gridItems else { return }\n        items = Self.workspaceWidgetItems(items)''',
    "Grid materialization filtering"
)
models = replace_once(
    models,
    '''    private static func packedGridItems(from source: [OpenNotchItem], columns: Int) -> [OpenNotchItem] {\n        var items = source''',
    '''    private static func workspaceWidgetItems(_ source: [OpenNotchItem]) -> [OpenNotchItem] {\n        source.filter { $0.kind == .module && $0.module != nil }\n    }\n\n    private static func packedGridItems(from source: [OpenNotchItem], columns: Int) -> [OpenNotchItem] {\n        var items = workspaceWidgetItems(source)''',
    "packedGridItems filtering"
)
models = replace_once(
    models,
    '''        if modules.isEmpty { group.items = [.elementItem(.clock, priority: .high)] }''',
    '''        if modules.isEmpty { group.items = [.moduleItem(.clock, presentation: .expanded, priority: .high)] }''',
    "migrated empty workspace"
)

marker = "    static func made(_ preset: OpenNotchPreset) -> OpenNotchLayout {"
end_marker = "\n    func validated() throws -> OpenNotchLayout {"
start = models.index(marker)
end = models.index(end_marker, start)
prefix, made, suffix = models[:start], models[start:end], models[end:]

replacements = {
    "minimal": '''        case .minimal:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.middleCenter, [g("Essentials", .vertical, [.moduleItem(.clock, presentation: .expanded, priority: .alwaysVisible)])])\n            ])\n''',
    "media": '''        case .media:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.middleCenter, [g("Media", .vertical, [.moduleItem(.media, presentation: .expanded, priority: .alwaysVisible)])]),\n                r(.bottomCenter, [g("Audio", .horizontal, [.moduleItem(.audio, presentation: .compact, priority: .high)])])\n            ])\n''',
    "productivity": '''        case .productivity:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.topCenter, [g("Overview", .horizontal, [.moduleItem(.clock, priority: .high)])]),\n                r(.middleLeft, [g("Schedule", .vertical, [.moduleItem(.calendar, priority: .high), .moduleItem(.timer, priority: .high)])]),\n                r(.middleRight, [g("Work", .vertical, [.moduleItem(.notes, priority: .normal), .moduleItem(.shelf, priority: .low)])])\n            ])\n''',
    "systemMonitor": '''        case .systemMonitor:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.middleCenter, [g("System", .vertical, [.moduleItem(.system, presentation: .expanded, priority: .alwaysVisible)])])\n            ])\n''',
    "focus": '''        case .focus:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.topCenter, [g("Time", .horizontal, [.moduleItem(.clock, priority: .high)])]),\n                r(.middleCenter, [g("Focus", .vertical, [.moduleItem(.timer, presentation: .expanded, priority: .alwaysVisible), .moduleItem(.notes, presentation: .compact, priority: .low)])])\n            ])\n''',
    "developer": '''        case .developer:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.middleLeft, [g("Tools", .vertical, [.moduleItem(.launcher, priority: .high), .moduleItem(.capture, priority: .normal)])]),\n                r(.middleRight, [g("Context", .vertical, [.moduleItem(.system, priority: .normal), .moduleItem(.notes, priority: .low)])])\n            ])\n''',
    "informationDense": '''        case .informationDense:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.topLeft, [g("Time", .vertical, [.moduleItem(.clock, presentation: .compact, priority: .high)])]),\n                r(.topRight, [g("System", .vertical, [.moduleItem(.system, presentation: .compact, priority: .high)])]),\n                r(.middleLeft, [g("Agenda", .vertical, [.moduleItem(.calendar, presentation: .compact, priority: .high), .moduleItem(.timer, presentation: .compact, priority: .normal)])]),\n                r(.middleRight, [g("Utilities", .vertical, [.moduleItem(.clipboard, presentation: .compact, priority: .normal), .moduleItem(.shelf, presentation: .compact, priority: .low)])]),\n                r(.bottomCenter, [g("Media", .horizontal, [.moduleItem(.media, presentation: .compact, priority: .high), .moduleItem(.audio, presentation: .compact, priority: .normal)])])\n            ])\n''',
    "showcase": '''        case .showcase:\n            return OpenNotchLayout(preset: preset, regions: [\n                r(.topCenter, [g("Header", .horizontal, [.moduleItem(.clock, presentation: .compact, priority: .high)])]),\n                r(.middleCenter, [g("Hero", .vertical, [.moduleItem(.media, presentation: .expanded, priority: .alwaysVisible)])]),\n                r(.bottomCenter, [g("Controls", .horizontal, [.moduleItem(.audio, presentation: .compact, priority: .high)])])\n            ])\n''',
}
order = ["minimal", "media", "productivity", "systemMonitor", "focus", "developer", "informationDense", "showcase", "custom"]
for index, name in enumerate(order[:-1]):
    next_name = order[index + 1]
    pattern = rf"(?ms)^        case \.{re.escape(name)}:\n.*?(?=^        case \.{re.escape(next_name)}:)"
    made, count = re.subn(pattern, replacements[name], made, count=1)
    if count != 1:
        raise SystemExit(f"preset {name}: expected 1 match, found {count}")
models = prefix + made + suffix
models_path.write_text(models)

# Workspace editor: creation and legacy item-list presentation become widget-only.
settings_path = Path("Halo/Views/WidgetSettingsView.swift")
settings = settings_path.read_text()
settings = replace_once(
    settings,
    '''    @ViewBuilder private var addMenu: some View {\n        Menu("Widget") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }\n        Menu("Lightweight element") { ForEach(OpenNotchElementKind.allCases) { element in Button(element.title) { addElement(element) } } }\n    }''',
    '''    @ViewBuilder private var addMenu: some View {\n        Menu("Widget") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }\n    }''',
    "Workspace add menu"
)
settings, count = re.subn(
    r'(?ms)^    private func addElement\(_ element: OpenNotchElementKind\) \{.*?^    \}\n(?=    private func )',
    '', settings, count=1
)
if count != 1:
    raise SystemExit(f"addElement: expected 1 match, found {count}")
settings = settings.replace(
    'ForEach(group.items) { item in itemPreview(item, group: group, region: region) }',
    'ForEach(group.items.filter { $0.kind == .module && $0.module != nil }) { item in itemPreview(item, group: group, region: region) }'
)
settings_path.write_text(settings)

# Runtime: legacy region-based layouts must never render old lightweight elements.
surface_path = Path("Halo/Views/SurfaceView.swift")
surface = surface_path.read_text()
old = 'let candidates = group.items.filter(context.isVisible)'
new = 'let candidates = group.items.filter { $0.kind == .module && $0.module != nil }.filter(context.isVisible)'
if old not in surface:
    raise SystemExit("Surface candidates filter not found")
surface = surface.replace(old, new)
old_height = 'let h = group.items.reduce(0.0) { $0 + min($1.sizing.preferredHeight, 260) } + max(0, Double(group.items.count - 1)) * group.spacing'
new_height = '''let widgetItems = group.items.filter { $0.kind == .module && $0.module != nil }\n        let h = widgetItems.reduce(0.0) { $0 + min($1.sizing.preferredHeight, 260) } + max(0, Double(widgetItems.count - 1)) * group.spacing'''
if old_height not in surface:
    raise SystemExit("Surface estimatedHeight expression not found")
surface = surface.replace(old_height, new_height)
surface_path.write_text(surface)

print("Removed Lightweight elements from Visual Workspace while preserving legacy decoding compatibility.")
