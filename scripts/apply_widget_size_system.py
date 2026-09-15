from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Workspace geometry: Halo's Visual Workspace is exactly 8 columns x 4 rows.
# -----------------------------------------------------------------------------
p = Path("Halo/Core/WorkspaceModels.swift")
s = p.read_text()

old_presets = '''enum OpenNotchGridSizePreset: String, Codable, CaseIterable, Identifiable {
    case oneByOne = "1×1"
    case twoByOne = "2×1"
    case oneByTwo = "1×2"
    case twoByTwo = "2×2"
    case threeByOne = "3×1"
    case threeByTwo = "3×2"
    case twoByThree = "2×3"
    case threeByThree = "3×3"
    case fourByTwo = "4×2"
    case fourByThree = "4×3"
    case custom = "Custom"
    var id: String { rawValue }
    var span: (columns: Int, rows: Int)? {
        switch self {
        case .oneByOne: return (1, 1)
        case .twoByOne: return (2, 1)
        case .oneByTwo: return (1, 2)
        case .twoByTwo: return (2, 2)
        case .threeByOne: return (3, 1)
        case .threeByTwo: return (3, 2)
        case .twoByThree: return (2, 3)
        case .threeByThree: return (3, 3)
        case .fourByTwo: return (4, 2)
        case .fourByThree: return (4, 3)
        case .custom: return nil
        }
    }
    static func matching(columns: Int, rows: Int) -> OpenNotchGridSizePreset {
        allCases.first { $0.span?.columns == columns && $0.span?.rows == rows } ?? .custom
    }
}'''

new_presets = '''enum OpenNotchGridSizePreset: String, Codable, CaseIterable, Identifiable {
    // Every legal Halo widget footprint. Keep raw values stable: they are persisted in UI state.
    case oneByOne = "1×1", twoByOne = "2×1", threeByOne = "3×1", fourByOne = "4×1"
    case fiveByOne = "5×1", sixByOne = "6×1", sevenByOne = "7×1", eightByOne = "8×1"
    case oneByTwo = "1×2", twoByTwo = "2×2", threeByTwo = "3×2", fourByTwo = "4×2"
    case fiveByTwo = "5×2", sixByTwo = "6×2", sevenByTwo = "7×2", eightByTwo = "8×2"
    case oneByThree = "1×3", twoByThree = "2×3", threeByThree = "3×3", fourByThree = "4×3"
    case fiveByThree = "5×3", sixByThree = "6×3", sevenByThree = "7×3", eightByThree = "8×3"
    case oneByFour = "1×4", twoByFour = "2×4", threeByFour = "3×4", fourByFour = "4×4"
    case fiveByFour = "5×4", sixByFour = "6×4", sevenByFour = "7×4", eightByFour = "8×4"
    case custom = "Custom"

    var id: String { rawValue }
    var span: (columns: Int, rows: Int)? {
        switch self {
        case .oneByOne: return (1, 1); case .twoByOne: return (2, 1); case .threeByOne: return (3, 1); case .fourByOne: return (4, 1)
        case .fiveByOne: return (5, 1); case .sixByOne: return (6, 1); case .sevenByOne: return (7, 1); case .eightByOne: return (8, 1)
        case .oneByTwo: return (1, 2); case .twoByTwo: return (2, 2); case .threeByTwo: return (3, 2); case .fourByTwo: return (4, 2)
        case .fiveByTwo: return (5, 2); case .sixByTwo: return (6, 2); case .sevenByTwo: return (7, 2); case .eightByTwo: return (8, 2)
        case .oneByThree: return (1, 3); case .twoByThree: return (2, 3); case .threeByThree: return (3, 3); case .fourByThree: return (4, 3)
        case .fiveByThree: return (5, 3); case .sixByThree: return (6, 3); case .sevenByThree: return (7, 3); case .eightByThree: return (8, 3)
        case .oneByFour: return (1, 4); case .twoByFour: return (2, 4); case .threeByFour: return (3, 4); case .fourByFour: return (4, 4)
        case .fiveByFour: return (5, 4); case .sixByFour: return (6, 4); case .sevenByFour: return (7, 4); case .eightByFour: return (8, 4)
        case .custom: return nil
        }
    }
    static func matching(columns: Int, rows: Int) -> OpenNotchGridSizePreset {
        allCases.first { $0.span?.columns == columns && $0.span?.rows == rows } ?? .custom
    }
}'''
s = replace_once(s, old_presets, new_presets, "grid footprint presets")

old_placement = '''    func clamped(columns: Int) -> OpenNotchGridPlacement {
        let columnCount = max(1, columns)
        var value = self
        value.columnSpan = min(columnCount, max(1, columnSpan))
        value.rowSpan = min(12, max(1, rowSpan))
        value.column = min(max(0, columnCount - value.columnSpan), max(0, column))
        value.row = min(48, max(0, row))
        return value
    }
    func validated() throws -> OpenNotchGridPlacement {
        var value = self
        value.column = min(48, max(0, column))
        value.row = min(48, max(0, row))
        value.columnSpan = min(12, max(1, columnSpan))
        value.rowSpan = min(12, max(1, rowSpan))
        return value
    }'''
new_placement = '''    func clamped(columns: Int) -> OpenNotchGridPlacement {
        let columnCount = min(8, max(1, columns))
        var value = self
        value.columnSpan = min(columnCount, max(1, columnSpan))
        value.rowSpan = min(4, max(1, rowSpan))
        value.column = min(max(0, columnCount - value.columnSpan), max(0, column))
        value.row = min(max(0, 4 - value.rowSpan), max(0, row))
        return value
    }
    func validated() throws -> OpenNotchGridPlacement {
        var value = self
        value.columnSpan = min(8, max(1, columnSpan))
        value.rowSpan = min(4, max(1, rowSpan))
        value.column = min(max(0, 8 - value.columnSpan), max(0, column))
        value.row = min(max(0, 4 - value.rowSpan), max(0, row))
        return value
    }'''
s = replace_once(s, old_placement, new_placement, "grid placement clamp")

s = replace_once(s,
'''    var resolvedGridColumns: Int { min(12, max(2, gridColumns ?? 4)) }
    var resolvedGridRows: Int { min(12, max(1, gridRows ?? 3)) }''',
'''    var resolvedGridColumns: Int { min(8, max(2, gridColumns ?? 4)) }
    var resolvedGridRows: Int { min(4, max(1, gridRows ?? 3)) }''', "resolved 8x4 grid")

s = replace_once(s,
'''        if let gridColumns { value.gridColumns = min(12, max(2, gridColumns)) }
        if let gridRows { value.gridRows = min(12, max(1, gridRows)) }''',
'''        if let gridColumns { value.gridColumns = min(8, max(2, gridColumns)) }
        if let gridRows { value.gridRows = min(4, max(1, gridRows)) }''', "validated 8x4 grid")

s = replace_once(s,
'''        guard placement.column >= 0, placement.row >= 0,
              placement.column + placement.columnSpan <= columns else { return false }''',
'''        guard placement.column >= 0, placement.row >= 0,
              placement.column + placement.columnSpan <= columns,
              placement.row + placement.rowSpan <= 4 else { return false }''', "grid placement bounds")

s = replace_once(s, '        for row in 0..<48 {\n', '        for row in 0..<4 {\n', "first available row bound")
s = replace_once(s,
'''        return OpenNotchGridPlacement(column: 0, row: 48, columnSpan: span, rowSpan: max(1, rowSpan))''',
'''        let boundedRows = min(4, max(1, rowSpan))
        return OpenNotchGridPlacement(column: 0, row: max(0, 4 - boundedRows), columnSpan: span, rowSpan: boundedRows)''', "first available fallback")

old_dense = '''        case .informationDense:
            // A deliberate six-row mosaic rather than a vertical pile of compact cards.
            return grid(8, 6, cellHeight: 88, gap: 7, [
                item(.clock,      0, 0, 2, 1, .compact, .high),
                item(.timer,      2, 0, 2, 1, .compact, .high),
                item(.audio,      4, 0, 2, 1, .compact, .normal),
                item(.activities, 6, 0, 2, 1, .compact, .normal),
                item(.calendar,   0, 1, 4, 3, .expanded, .high),
                item(.system,     4, 1, 4, 3, .expanded, .high),
                item(.clipboard,  0, 4, 2, 2, .expanded, .normal),
                item(.shelf,      2, 4, 2, 2, .expanded, .normal),
                item(.launcher,   4, 4, 2, 2, .expanded, .normal),
                item(.notes,      6, 4, 2, 2, .expanded, .normal)
            ])'''
new_dense = '''        case .informationDense:
            // Maximum-density composition inside Halo's canonical 8×4 workspace.
            return grid(8, 4, cellHeight: 92, gap: 7, [
                item(.clock,      0, 0, 2, 1, .compact, .high),
                item(.timer,      2, 0, 2, 1, .compact, .high),
                item(.audio,      4, 0, 2, 1, .compact, .normal),
                item(.activities, 6, 0, 2, 1, .compact, .normal),
                item(.calendar,   0, 1, 4, 2, .expanded, .high),
                item(.system,     4, 1, 4, 2, .expanded, .high),
                item(.clipboard,  0, 3, 2, 1, .compact, .normal),
                item(.shelf,      2, 3, 2, 1, .compact, .normal),
                item(.launcher,   4, 3, 2, 1, .compact, .normal),
                item(.notes,      6, 3, 2, 1, .compact, .normal)
            ])'''
s = replace_once(s, old_dense, new_dense, "information dense 8x4 preset")
p.write_text(s)

# -----------------------------------------------------------------------------
# Shared footprint model and per-module recommendations.
# -----------------------------------------------------------------------------
p = Path("Halo/Core/WidgetModels.swift")
s = p.read_text()
marker = '// MARK: - Visual Workspace adaptive widget system\n'
footprint_model = '''// MARK: - Canonical widget footprint system\n\nenum VisualWidgetStage: String, Codable, CaseIterable, Identifiable {\n    case micro = "Micro", compact = "Compact", rich = "Rich", dashboard = "Dashboard"\n    var id: String { rawValue }\n}\n\nenum VisualWidgetOrientation: String, Codable { case square, horizontal, vertical }\n\nstruct VisualWidgetFootprint: Hashable, Codable {\n    let columns: Int\n    let rows: Int\n\n    init(columns: Int, rows: Int) {\n        self.columns = min(8, max(1, columns))\n        self.rows = min(4, max(1, rows))\n    }\n\n    var key: String { "\\(columns)x\\(rows)" }\n    var area: Int { columns * rows }\n    var orientation: VisualWidgetOrientation { columns == rows ? .square : (columns > rows ? .horizontal : .vertical) }\n    var stage: VisualWidgetStage {\n        if area <= 2 { return .micro }\n        if (rows <= 2 && columns <= 4) || (columns <= 2 && rows <= 4) { return .compact }\n        if columns >= 6 && rows >= 3 { return .dashboard }\n        return .rich\n    }\n    var informationCapacity: Int {\n        switch stage {\n        case .micro: return min(3, 1 + area)\n        case .compact: return min(7, 2 + area)\n        case .rich: return min(13, 3 + area / 2)\n        case .dashboard: return min(18, 6 + area / 2)\n        }\n    }\n    var itemCapacity: Int {\n        switch stage {\n        case .micro: return max(1, area)\n        case .compact: return min(8, max(2, area))\n        case .rich: return min(18, max(4, area))\n        case .dashboard: return min(32, area)\n        }\n    }\n    func contains(columns requiredColumns: Int, rows requiredRows: Int) -> Bool {\n        columns >= requiredColumns && rows >= requiredRows\n    }\n}\n\nstruct VisualWidgetSizeRecommendation: Equatable {\n    let minimum: VisualWidgetFootprint\n    let everyday: VisualWidgetFootprint\n    let rich: VisualWidgetFootprint\n}\n\nextension ModuleID {\n    var visualWidgetSizeRecommendation: VisualWidgetSizeRecommendation {\n        switch self {\n        case .timer: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))\n        case .shelf: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 3))\n        case .media, .audio: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 3))\n        case .calendar: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 4))\n        case .clipboard: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 5, rows: 3))\n        case .system: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 3))\n        case .launcher: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 5, rows: 4))\n        case .notes: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 2), rich: .init(columns: 4, rows: 4))\n        case .capture: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 1), rich: .init(columns: 4, rows: 3))\n        case .stopwatch: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))\n        case .clock: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 3, rows: 1), rich: .init(columns: 4, rows: 2))\n        case .activities, .developer: return .init(minimum: .init(columns: 1, rows: 1), everyday: .init(columns: 2, rows: 2), rich: .init(columns: 4, rows: 3))\n        }\n    }\n\n    func visualWidgetSizeHint(for footprint: VisualWidgetFootprint) -> String {\n        let recommendation = visualWidgetSizeRecommendation\n        if footprint.area == 1 && self == .notes { return "1×1 is Quick Note capture only · actual note content starts at 2×2." }\n        if footprint.contains(columns: recommendation.rich.columns, rows: recommendation.rich.rows) { return "Rich layout · secondary panels and deeper controls are available." }\n        if footprint.contains(columns: recommendation.everyday.columns, rows: recommendation.everyday.rows) { return "Recommended everyday layout." }\n        return "Compact layout · Halo prioritizes glanceable information and safe primary actions."\n    }\n}\n\n'''
if footprint_model.strip() not in s:
    if marker not in s: raise SystemExit("widget footprint marker missing")
    s = s.replace(marker, footprint_model + marker, 1)

s = replace_once(s,
'''        case .timer: value.maxItems = 5
        case .media: value.maxItems = 8''',
'''        case .timer: value.maxItems = 5
        case .shelf: value.maxItems = 12
        case .media: value.maxItems = 8''', "shelf adaptive defaults")

s = replace_once(s,
'''        case .timer, .media, .audio, .clipboard, .system, .launcher, .activities, .notes, .capture, .stopwatch: return true''',
'''        case .timer, .shelf, .media, .audio, .clipboard, .system, .launcher, .activities, .notes, .capture, .stopwatch: return true''', "shelf adaptive support")

s = replace_once(s,
'''        case .timer: return ["countdown"]
        case .media: return ["artwork", "track"]''',
'''        case .timer: return ["countdown"]
        case .shelf: return ["files"]
        case .media: return ["artwork", "track"]''', "shelf always info")

s = replace_once(s,
'''        case .timer: return ["countdown", "controls", "progress", "status", "endTime", "presets"]
        case .media: return ["artwork", "track", "controls", "artist", "progress", "timing", "album", "shuffle", "repeat", "visualizer", "source", "playback", "status", "detection", "palette", "lyrics"]''',
'''        case .timer: return ["countdown", "controls", "progress", "status", "endTime", "presets"]
        case .shelf: return ["files", "summary", "actions", "footer"]
        case .media: return ["artwork", "track", "controls", "artist", "progress", "timing", "album", "shuffle", "repeat", "visualizer", "source", "playback", "status", "detection", "palette", "lyrics"]''', "shelf info order")
p.write_text(s)

# -----------------------------------------------------------------------------
# Adaptive context now knows the exact footprint; shelf gets a real responsive renderer.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/VisualWorkspaceAdaptiveWidgets.swift")
s = p.read_text()
s = replace_once(s,
'''        case .media:
            VisualAdaptiveMediaView(service: workspace.media, app: workspace.settings.mediaApp)''',
'''        case .shelf:
            VisualAdaptiveShelfView(store: store)
        case .media:
            VisualAdaptiveMediaView(service: workspace.media, app: workspace.settings.mediaApp)''', "adaptive shelf routing")

s = replace_once(s,
'''    let settings: VisualAdaptiveWidgetOptions
    let family: VisualAdaptiveFamily''',
'''    let settings: VisualAdaptiveWidgetOptions
    let footprint: VisualWidgetFootprint
    let family: VisualAdaptiveFamily''', "adaptive footprint property")

s = replace_once(s,
'''        self.width = width
        self.height = height
        let base = style.resolvedVisualAdaptive(for: module)''',
'''        self.width = width
        self.height = height
        self.footprint = VisualWidgetFootprint(columns: self.columns, rows: self.rows)
        let base = style.resolvedVisualAdaptive(for: module)''', "adaptive footprint init")

s = replace_once(s,
'''    var information: Set<String> { settings.visibleInformation(for: module, capacity: family.informationCapacity) }
    func shows(_ key: String) -> Bool {''',
'''    var information: Set<String> { settings.visibleInformation(for: module, capacity: footprint.informationCapacity) }
    var itemLimit: Int { min(settings.maxItems, footprint.itemCapacity) }
    func shows(_ key: String) -> Bool {''', "footprint information capacity")

shelf_view = r'''
// MARK: - File Shelf

private struct VisualAdaptiveShelfView: View {
    @Environment(\.widgetStyle) private var style
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumnSpan
    @Environment(\.openNotchGridRowSpan) private var gridRowSpan
    @ObservedObject var store: AppStore
    @State private var selectedURL: URL?

    private var context: AdaptiveResolvedContext {
        AdaptiveResolvedContext(module: .shelf, style: style, columns: gridColumnSpan, rows: gridRowSpan,
                                width: availableWidth, height: availableHeight)
    }
    private var orderedFiles: [URL] {
        let pinned = store.files.filter { store.pinnedFiles.contains($0) }
        let regular = store.files.filter { !store.pinnedFiles.contains($0) }
        return pinned + regular
    }
    private var effectiveSelection: URL? { selectedURL.flatMap { store.files.contains($0) ? $0 : nil } ?? orderedFiles.first }

    var body: some View {
        Group {
            if context.footprint.area == 1 { microShelf }
            else if context.footprint.rows == 1 { horizontalShelf }
            else if context.footprint.columns == 1 { verticalShelf }
            else if context.footprint.stage == .dashboard || (context.columns >= 5 && context.rows >= 3) { dashboardShelf }
            else { gridShelf }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: context.contentAlignment)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: context.footprint)
    }

    private var microShelf: some View {
        let shown = Array(orderedFiles.prefix(3))
        return ZStack {
            if shown.isEmpty {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(style.accentColor.color)
            } else {
                ForEach(Array(shown.enumerated().reversed()), id: \.offset) { index, url in
                    shelfIcon(url, size: 34)
                        .offset(x: CGFloat(index) * 3 - 3, y: CGFloat(index) * -3 + 3)
                        .rotationEffect(.degrees(Double(index - 1) * 3.2))
                }
                if store.files.count > 1 {
                    Text("\(store.files.count)")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(4).background(style.accentColor.color, in: Circle())
                        .foregroundStyle(.white).offset(x: 21, y: -21)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .haloMicroInteraction(accent: style.accentColor.color,
                              help: shown.isEmpty ? "File Shelf · click to add files" : "File Shelf · click latest · hold for shelf") {
            if let first = orderedFiles.first { NSWorkspace.shared.open(first) } else { store.chooseFiles() }
        } popover: {
            VStack(alignment: .leading, spacing: 9) {
                HStack { Text("File Shelf").font(.headline); Spacer(); Button("Add…") { store.chooseFiles() } }
                if shown.isEmpty { Text("Drop files onto Halo or add them here.").foregroundStyle(.secondary) }
                ForEach(Array(orderedFiles.prefix(5).enumerated()), id: \.offset) { _, url in
                    shelfRow(url, compact: true)
                }
            }.frame(width: 280)
        }
    }

    private var horizontalShelf: some View {
        HStack(spacing: max(5, context.spacing * 0.72)) {
            let shown = Array(orderedFiles.prefix(max(1, min(context.itemLimit, context.columns))))
            if shown.isEmpty { emptyShelf }
            else {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, url in
                    Button { NSWorkspace.shared.open(url) } label: {
                        HStack(spacing: 5) {
                            shelfIcon(url, size: context.columns >= 5 ? 28 : 24)
                            if context.columns >= 4 { Text(url.deletingPathExtension().lastPathComponent).font(.caption).lineLimit(1) }
                        }
                    }.buttonStyle(.plain).contextMenu { fileMenu(url) }
                }
                Spacer(minLength: 0)
                if context.columns >= 6 { Button { store.chooseFiles() } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(.plain).help("Add files") }
            }
        }
    }

    private var verticalShelf: some View {
        VStack(spacing: max(5, context.spacing * 0.72)) {
            let shown = Array(orderedFiles.prefix(max(1, min(context.itemLimit, context.rows))))
            if shown.isEmpty { emptyShelf }
            else {
                ForEach(Array(shown.enumerated()), id: \.offset) { _, url in
                    Button { NSWorkspace.shared.open(url) } label: {
                        VStack(spacing: 3) {
                            shelfIcon(url, size: 28)
                            if context.rows >= 3 { Text(url.deletingPathExtension().lastPathComponent).font(.system(size: 8, weight: .medium)).lineLimit(1) }
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain).contextMenu { fileMenu(url) }
                }
                if context.rows >= 4 { Button { store.chooseFiles() } label: { Image(systemName: "plus") }.buttonStyle(.plain) }
            }
        }
    }

    private var gridShelf: some View {
        VStack(alignment: .leading, spacing: context.spacing) {
            if context.columns >= 3 {
                HStack {
                    Text("FILES").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(store.files.count)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Button { store.chooseFiles() } label: { Image(systemName: "plus") }.buttonStyle(.plain)
                }
            }
            if orderedFiles.isEmpty { emptyShelf }
            else {
                let gridColumns = max(1, min(context.columns, context.rows == 2 ? 4 : 5))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: gridColumns), spacing: context.spacing) {
                    ForEach(Array(orderedFiles.prefix(context.itemLimit).enumerated()), id: \.offset) { _, url in
                        fileTile(url, detailed: context.rows >= 3)
                    }
                }
            }
        }
    }

    private var dashboardShelf: some View {
        HStack(alignment: .top, spacing: context.spacing * 1.15) {
            VStack(alignment: .leading, spacing: context.spacing) {
                HStack {
                    Label("File Shelf", systemImage: "tray.full.fill").font(.headline)
                    Spacer()
                    Button("Add…") { store.chooseFiles() }.controlSize(.small)
                    if !store.files.isEmpty { Button("Clear") { store.clearShelf() }.controlSize(.small) }
                }
                if orderedFiles.isEmpty { emptyShelf }
                else {
                    let gridColumns = min(5, max(3, context.columns - 2))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: context.spacing), count: gridColumns), spacing: context.spacing) {
                        ForEach(Array(orderedFiles.prefix(context.itemLimit).enumerated()), id: \.offset) { _, url in
                            fileTile(url, detailed: true)
                        }
                    }
                }
            }.frame(maxWidth: .infinity)
            if context.columns >= 5 {
                Divider().opacity(0.18)
                VStack(alignment: .leading, spacing: 8) {
                    if let url = effectiveSelection {
                        shelfIcon(url, size: min(96, max(56, (availableHeight ?? 220) * 0.28)))
                        Text(url.lastPathComponent).font(.headline).lineLimit(2)
                        Text(fileDetail(url)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        HStack {
                            Button("Open") { NSWorkspace.shared.open(url) }
                            Button("Preview") { store.shelfPreview.show(url) }
                        }.controlSize(.small)
                        Button(store.pinnedFiles.contains(url) ? "Unpin" : "Pin") { store.toggleFilePin(url) }.controlSize(.small)
                    } else {
                        Text("Select a file").foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.frame(minWidth: 130, maxWidth: 190, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var emptyShelf: some View {
        Button { store.chooseFiles() } label: {
            VStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 24, weight: .semibold)).foregroundStyle(style.accentColor.color)
                if context.footprint.area > 2 { Text("Drop files here or Add…").font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.buttonStyle(.plain)
    }

    private func fileTile(_ url: URL, detailed: Bool) -> some View {
        Button { selectedURL = url } label: {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    shelfIcon(url, size: detailed ? 42 : 34)
                    if store.pinnedFiles.contains(url) { Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(style.accentColor.color) }
                }
                Text(url.deletingPathExtension().lastPathComponent).font(.system(size: detailed ? 10 : 9, weight: .medium)).lineLimit(detailed ? 2 : 1).multilineTextAlignment(.center)
                if detailed && context.rows >= 3 { Text(fileKind(url)).font(.system(size: 7, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).lineLimit(1) }
            }.frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded { NSWorkspace.shared.open(url) })
        .contextMenu { fileMenu(url) }
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
    }

    private func shelfRow(_ url: URL, compact: Bool) -> some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack(spacing: 8) {
                shelfIcon(url, size: compact ? 24 : 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(url.lastPathComponent).lineLimit(1)
                    Text(fileDetail(url)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
        }.buttonStyle(.plain).contextMenu { fileMenu(url) }
    }

    @ViewBuilder private func fileMenu(_ url: URL) -> some View {
        Button("Open") { NSWorkspace.shared.open(url) }
        Button("Quick Look") { store.shelfPreview.show(url) }
        Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Button(store.pinnedFiles.contains(url) ? "Unpin" : "Pin") { store.toggleFilePin(url) }
        Divider()
        Button("Remove from Shelf") { store.removeFile(url) }
    }

    private func shelfIcon(_ url: URL, size: CGFloat) -> some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit().frame(width: size, height: size)
    }
    private func fileKind(_ url: URL) -> String { url.hasDirectoryPath ? "FOLDER" : (url.pathExtension.isEmpty ? "FILE" : url.pathExtension.uppercased()) }
    private func fileDetail(_ url: URL) -> String {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]) else { return "Original unavailable" }
        if values.isDirectory == true { return "Folder" }
        let size = ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
        let kind = url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased()
        return "\(kind) · \(size)"
    }
}

'''
media_marker = '// MARK: - Media\n'
if shelf_view.strip() not in s:
    if media_marker not in s: raise SystemExit("media marker missing for shelf insertion")
    s = s.replace(media_marker, shelf_view + media_marker, 1)
p.write_text(s)

# -----------------------------------------------------------------------------
# Route every Visual Workspace Shelf footprint through the adaptive renderer.
# -----------------------------------------------------------------------------
p = Path("Halo/Views/SurfaceView.swift")
s = p.read_text()
s = replace_once(s,
'''        case .shelf:
            if gridColumnSpan == 1, gridRowSpan == 1 { microShelf } else { shelf }''',
'''        case .shelf:
            if gridColumnSpan != nil, gridRowSpan != nil { VisualWorkspaceAdaptiveModuleView(module: .shelf, store: store, workspace: store.workspace) }
            else { shelf }''', "surface adaptive shelf route")
p.write_text(s)

# -----------------------------------------------------------------------------
# Documentation contract. Keep the detailed implementation rules near the code.
# -----------------------------------------------------------------------------
p = Path("Docs/WidgetCustomization.md")
s = p.read_text()
doc = r'''

---

## Canonical 8×4 footprint system

Halo's Visual Workspace has one canonical sizing contract: **8 columns × 4 rows**. A widget can occupy any of the 32 footprints from **1×1 through 8×4**. `OpenNotchGridSizePreset` exposes every legal footprint and layout validation clamps imported/legacy geometry into this envelope.

The renderer treats footprint as semantic information, not merely pixels:

- **Micro** — roughly 1×1, 2×1, 1×2. One dominant datum/visual and one safe primary action.
- **Compact** — roughly 2×2 through 4×2 (and narrow vertical equivalents). Primary information plus a small number of controls.
- **Rich** — medium/large footprints. Lists, grids, previews, secondary metadata and deeper interaction become appropriate.
- **Dashboard** — 6×3 through 8×4. Multiple logical sections; 8×4 should feel like a miniature application rather than a stretched card.

`VisualWidgetFootprint` is the single source of truth for stage, orientation, information capacity and item capacity. Horizontal and vertical footprints must use intentional hierarchy; never implement a vertical widget by simply rotating a horizontal one. Resize transitions should preserve state and morph between the same widget's representations.

### Per-widget minimums

| Widget | Absolute minimum | Everyday | Rich |
| --- | --- | --- | --- |
| Timer | 1×1 | 2×2 | 4×3 |
| File Shelf | 1×1 portal | 3×2 | 5×3 |
| Audio / Media | 1×1 | 3×2 | 5×3 |
| Calendar | 1×1 | 3×2 | 5×4 |
| Clipboard | 1×1 portal | 2×2 | 5×3 |
| System | 1×1 | 3×2 | 5×3 |
| Launcher | 1×1 | 3×2 | 5×4 |
| Notes | 1×1 capture only | 3×2 | 4×4 |
| Capture | 1×1 | 3×1 | 4×3 |
| Stopwatch | 1×1 | 2×2 | 4×3 |

The 1×1 rule is strict: at most one primary datum and one dominant visual. Filenames, event names, note prose, lap lists, multi-metric dashboards and dense controls belong in larger footprints. When content does not fit, degrade to a deliberately simpler representation instead of shrinking it below legibility.

### Interaction language

Across adaptive widgets: hover may reveal secondary state without rearranging the tile; press is the safe primary action; ~450 ms hold reveals contextual controls; right-click remains the context/settings path; scroll is reserved for natural adjustment/navigation; content is draggable only where the content itself has drag semantics. Avoid destructive double-click actions.

### State-aware adaptation

A footprint may change presentation without changing size. Examples already supported by the adaptive renderers include Timer idle/running/completed state, Audio switching from volume to artwork while media plays, Calendar changing a date tile to an imminent-event countdown, System rotating/promoting metrics, Capture showing work-in-progress state, and File Shelf changing from a portal into a browsable grid/preview as space grows.
'''
if '## Canonical 8×4 footprint system' not in s:
    s += doc
p.write_text(s)

print("Applied Halo 8x4 widget size system")
