from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected 1 match in {path}, got {count}: {old[:140]!r}")
    p.write_text(text.replace(old, new, 1))


def insert_before(path, marker, addition):
    p = Path(path)
    text = p.read_text()
    if marker not in text:
        raise SystemExit(f"Marker not found in {path}: {marker[:120]!r}")
    p.write_text(text.replace(marker, addition + marker, 1))

models = 'Halo/Core/WorkspaceModels.swift'
surface = 'Halo/Views/SurfaceView.swift'
settings = 'Halo/Views/WidgetSettingsView.swift'
module = 'Halo/Views/ModuleViews.swift'

# ---------------------------------------------------------------------------
# Models: direct grid placement and standard widget footprints.
# ---------------------------------------------------------------------------
insert_before(models,
'''enum OpenNotchPresentation: String, Codable, CaseIterable, Identifiable {''',
'''enum OpenNotchGridSizePreset: String, Codable, CaseIterable, Identifiable {
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
}

struct OpenNotchGridPlacement: Codable, Equatable {
    var column = 0
    var row = 0
    var columnSpan = 2
    var rowSpan = 1

    func clamped(columns: Int) -> OpenNotchGridPlacement {
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
    }
}

''')

replace_once(models,
'''    var sizing = OpenNotchSizing()
    var presentation: OpenNotchPresentation = .automatic''',
'''    var sizing = OpenNotchSizing()
    // Visual Workspace v2 places items directly on a grid. Optional keeps every
    // region-based saved workspace decodable and migratable.
    var gridPlacement: OpenNotchGridPlacement?
    var presentation: OpenNotchPresentation = .automatic''')

replace_once(models,
'''        value.sizing = try sizing.validated()
        if let style { value.style = try style.validated() }''',
'''        value.sizing = try sizing.validated()
        value.gridPlacement = try gridPlacement?.validated()
        if let style { value.style = try style.validated() }''')

replace_once(models,
'''    var contentMode: OpenNotchContentMode?
    var regions: [OpenNotchRegion] = []
    // Relative track weights for left/center/right and top/middle/bottom.''',
'''    var contentMode: OpenNotchContentMode?
    var regions: [OpenNotchRegion] = []
    // Visual Workspace v2. Items live directly on a standard grid; regions/groups
    // remain only as a backwards-compatible migration source.
    var gridItems: [OpenNotchItem]?
    var gridColumns: Int?
    var gridRows: Int?
    var gridGap: Double?
    var gridCellHeight: Double?
    var gridPadding: OpenNotchInsets?
    // Relative track weights for left/center/right and top/middle/bottom.''')

replace_once(models,
'''    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }
    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }
    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }
    var usesFreeformRegions: Bool { regions.contains { $0.frame != nil } }
    var allItems: [OpenNotchItem] { regions.flatMap(\\.groups).flatMap(\\.items) }
''',
'''    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }
    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }
    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }
    var usesFreeformRegions: Bool { regions.contains { $0.frame != nil } }
    var resolvedGridColumns: Int { min(12, max(2, gridColumns ?? 4)) }
    var resolvedGridRows: Int { min(12, max(1, gridRows ?? 3)) }
    var resolvedGridGap: Double {
        let value = gridGap ?? 8
        return value.isFinite ? min(32, max(0, value)) : 8
    }
    var resolvedGridCellHeight: Double {
        let value = gridCellHeight ?? 104
        return value.isFinite ? min(320, max(56, value)) : 104
    }
    var resolvedGridPadding: OpenNotchInsets { gridPadding ?? OpenNotchInsets(top: 8, leading: 8, bottom: 8, trailing: 8) }
    var allItems: [OpenNotchItem] { gridItems ?? regions.flatMap(\\.groups).flatMap(\\.items) }
    var resolvedGridItems: [OpenNotchItem] {
        if let gridItems { return gridItems }
        return Self.packedGridItems(from: regions.flatMap(\\.groups).flatMap(\\.items), columns: resolvedGridColumns)
    }
    var requiredGridRows: Int {
        max(resolvedGridRows, resolvedGridItems.compactMap { item in
            item.gridPlacement.map { $0.row + $0.rowSpan }
        }.max() ?? 0)
    }

    mutating func materializeGridItems() {
        if gridItems == nil { gridItems = resolvedGridItems }
        normalizeGridItems()
    }

    mutating func normalizeGridItems(pinnedID: UUID? = nil) {
        guard var items = gridItems else { return }
        let columns = resolvedGridColumns
        var occupied = Set<Int>()
        let ordered: [Int]
        if let pinnedID, let pinned = items.firstIndex(where: { $0.id == pinnedID }) {
            ordered = [pinned] + items.indices.filter { $0 != pinned }
        } else {
            ordered = Array(items.indices)
        }
        for index in ordered {
            let fallback = Self.defaultGridSpan(for: items[index])
            var placement = (items[index].gridPlacement ?? OpenNotchGridPlacement(columnSpan: fallback.columns, rowSpan: fallback.rows)).clamped(columns: columns)
            if !Self.canPlace(placement, columns: columns, occupied: occupied) {
                placement = Self.firstAvailablePlacement(columnSpan: placement.columnSpan, rowSpan: placement.rowSpan,
                                                         columns: columns, occupied: occupied)
            }
            items[index].gridPlacement = placement
            Self.mark(placement, columns: columns, occupied: &occupied)
        }
        gridItems = items
    }

    private static func packedGridItems(from source: [OpenNotchItem], columns: Int) -> [OpenNotchItem] {
        var items = source
        var occupied = Set<Int>()
        for index in items.indices {
            let span = defaultGridSpan(for: items[index])
            let placement = firstAvailablePlacement(columnSpan: min(columns, span.columns), rowSpan: span.rows,
                                                    columns: columns, occupied: occupied)
            items[index].gridPlacement = placement
            mark(placement, columns: columns, occupied: &occupied)
        }
        return items
    }

    private static func defaultGridSpan(for item: OpenNotchItem) -> (columns: Int, rows: Int) {
        if let module = item.module {
            switch module {
            case .media, .calendar, .system: return (3, 2)
            case .shelf, .clipboard, .launcher, .activities, .notes: return (2, 2)
            case .clock, .timer, .audio, .capture, .stopwatch, .developer: return (2, 1)
            }
        }
        switch item.element {
        case .albumArt, .customImage, .customGIF: return (2, 2)
        case .playbackControls, .playbackProgress, .customText: return (2, 1)
        default: return (1, 1)
        }
    }

    private static func canPlace(_ placement: OpenNotchGridPlacement, columns: Int, occupied: Set<Int>) -> Bool {
        guard placement.column >= 0, placement.row >= 0,
              placement.column + placement.columnSpan <= columns else { return false }
        for row in placement.row..<(placement.row + placement.rowSpan) {
            for column in placement.column..<(placement.column + placement.columnSpan) {
                if occupied.contains(row * 64 + column) { return false }
            }
        }
        return true
    }

    private static func mark(_ placement: OpenNotchGridPlacement, columns: Int, occupied: inout Set<Int>) {
        for row in placement.row..<(placement.row + placement.rowSpan) {
            for column in placement.column..<min(columns, placement.column + placement.columnSpan) {
                occupied.insert(row * 64 + column)
            }
        }
    }

    private static func firstAvailablePlacement(columnSpan: Int, rowSpan: Int, columns: Int,
                                                occupied: Set<Int>) -> OpenNotchGridPlacement {
        let span = min(columns, max(1, columnSpan))
        for row in 0..<48 {
            for column in 0...max(0, columns - span) {
                let candidate = OpenNotchGridPlacement(column: column, row: row, columnSpan: span, rowSpan: max(1, rowSpan))
                if canPlace(candidate, columns: columns, occupied: occupied) { return candidate }
            }
        }
        return OpenNotchGridPlacement(column: 0, row: 48, columnSpan: span, rowSpan: max(1, rowSpan))
    }
''')

replace_once(models,
'''    mutating func materializeOpenNotchLayout() {
        if openNotch == nil { openNotch = resolvedOpenNotchLayout }
    }''',
'''    mutating func materializeOpenNotchLayout() {
        if openNotch == nil { openNotch = resolvedOpenNotchLayout }
        openNotch?.materializeGridItems()
    }''')

replace_once(models,
'''    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {
        openNotch = OpenNotchLayout.made(preset)
        let modules = openNotch?.allItems.compactMap(\\.module) ?? []
        enabled.formUnion(modules)
    }''',
'''    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {
        openNotch = OpenNotchLayout.made(preset)
        openNotch?.materializeGridItems()
        let modules = openNotch?.allItems.compactMap(\\.module) ?? []
        enabled.formUnion(modules)
    }''')

replace_once(models,
'''        value.regions = try regions.prefix(9).map { try $0.validated() }
        value.appearance = try appearance.validated()
        return value''',
'''        value.regions = try regions.prefix(9).map { try $0.validated() }
        value.gridItems = try gridItems.map { try $0.prefix(80).map { try $0.validated() } }
        if let gridColumns { value.gridColumns = min(12, max(2, gridColumns)) }
        if let gridRows { value.gridRows = min(12, max(1, gridRows)) }
        if let gridGap { guard gridGap.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.gridGap = min(32, max(0, gridGap)) }
        if let gridCellHeight { guard gridCellHeight.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.gridCellHeight = min(320, max(56, gridCellHeight)) }
        value.gridPadding = try gridPadding?.validated()
        value.appearance = try appearance.validated()
        if value.gridItems != nil { value.normalizeGridItems() }
        return value''')

# ---------------------------------------------------------------------------
# Runtime: render Visual Workspace directly from grid items. Legacy region code
# remains compiled solely for backwards decoding; it is no longer the active path.
# ---------------------------------------------------------------------------
replace_once(surface,
'''            switch mode {
            case .fixed: fixedCanvas
            case .scroll: scrollCanvas
            case .pages: pagesCanvas
            }''',
'''            switch mode {
            case .fixed: directFixedCanvas
            case .scroll: directScrollCanvas
            case .pages: directPagesCanvas
            }''')

insert_before(surface,
'''    @ViewBuilder private var fixedCanvas: some View {''',
'''    private var directItems: [OpenNotchItem] {
        let runtime = OpenNotchRuntimeContext(store: store)
        return opened.resolvedGridItems.filter(runtime.isVisible)
    }

    private var directColumns: Int { opened.resolvedGridColumns }
    private var directRows: Int { opened.requiredGridRows }
    private var directGap: CGFloat { CGFloat(opened.resolvedGridGap) }
    private var directPadding: OpenNotchInsets { opened.resolvedGridPadding }

    private var directFixedCanvas: some View {
        GeometryReader { proxy in
            let rows = max(1, directRows)
            directGrid(items: directItems, canvasSize: proxy.size, rows: rows, rowOffset: 0,
                       fixedCellHeight: nil)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var directScrollCanvas: some View {
        GeometryReader { proxy in
            let rows = max(1, directRows)
            let padding = directPadding
            let contentHeight = CGFloat(padding.top + padding.bottom)
                + CGFloat(rows) * CGFloat(opened.resolvedGridCellHeight)
                + CGFloat(max(0, rows - 1)) * directGap
            ScrollView(.vertical) {
                directGrid(items: directItems, canvasSize: CGSize(width: proxy.size.width, height: contentHeight),
                           rows: rows, rowOffset: 0, fixedCellHeight: CGFloat(opened.resolvedGridCellHeight))
                    .frame(width: proxy.size.width, height: contentHeight)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var directPagesCanvas: some View {
        let rowsPerPage = max(1, opened.resolvedGridRows)
        let pageCount = max(1, Int(ceil(Double(max(1, directRows)) / Double(rowsPerPage))))
        let safePage = min(max(0, page), pageCount - 1)
        return VStack(spacing: 5) {
            GeometryReader { proxy in
                let startRow = safePage * rowsPerPage
                let pageItems = directItems.filter { item in
                    guard let placement = item.gridPlacement else { return false }
                    return placement.row < startRow + rowsPerPage && placement.row + placement.rowSpan > startRow
                }
                directGrid(items: pageItems, canvasSize: proxy.size, rows: rowsPerPage,
                           rowOffset: startRow, fixedCellHeight: nil)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            if pageCount > 1 {
                HStack(spacing: 10) {
                    Button { page = max(0, safePage - 1) } label: { Image(systemName: "chevron.left") }.disabled(safePage == 0)
                    Text("Page \\(safePage + 1) of \\(pageCount)").font(.caption2).foregroundStyle(.secondary)
                    Button { page = min(pageCount - 1, safePage + 1) } label: { Image(systemName: "chevron.right") }.disabled(safePage == pageCount - 1)
                }
                .controlSize(.mini)
            }
        }
    }

    private func directGrid(items: [OpenNotchItem], canvasSize: CGSize, rows: Int,
                            rowOffset: Int, fixedCellHeight: CGFloat?) -> some View {
        let padding = directPadding
        let innerWidth = max(1, canvasSize.width - CGFloat(padding.leading + padding.trailing))
        let innerHeight = max(1, canvasSize.height - CGFloat(padding.top + padding.bottom))
        let columns = max(1, directColumns)
        let safeRows = max(1, rows)
        let cellWidth = max(1, (innerWidth - directGap * CGFloat(max(0, columns - 1))) / CGFloat(columns))
        let cellHeight = fixedCellHeight ?? max(1, (innerHeight - directGap * CGFloat(max(0, safeRows - 1))) / CGFloat(safeRows))
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                if let raw = item.gridPlacement {
                    let placement = raw.clamped(columns: columns)
                    let localRow = placement.row - rowOffset
                    let visibleStart = max(0, localRow)
                    let visibleEnd = min(safeRows, localRow + placement.rowSpan)
                    if visibleEnd > visibleStart {
                        let visibleRows = visibleEnd - visibleStart
                        let width = cellWidth * CGFloat(placement.columnSpan) + directGap * CGFloat(max(0, placement.columnSpan - 1))
                        let height = cellHeight * CGFloat(visibleRows) + directGap * CGFloat(max(0, visibleRows - 1))
                        let x = CGFloat(padding.leading) + CGFloat(placement.column) * (cellWidth + directGap)
                        let y = CGFloat(padding.top) + CGFloat(visibleStart) * (cellHeight + directGap)
                        let slot = CGSize(width: max(1, width), height: max(1, height))
                        OpenNotchItemView(item: item, layout: layout, store: store,
                                          compression: compressionForDirectSlot(slot), slotSize: slot)
                            .frame(width: slot.width, height: slot.height)
                            .position(x: x + slot.width / 2, y: y + slot.height / 2)
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }

    private func compressionForDirectSlot(_ size: CGSize) -> Int {
        let widthRatio = size.width / 300
        let heightRatio = size.height / 180
        let ratio = min(widthRatio, heightRatio)
        if ratio >= 1 { return 0 }
        if ratio >= 0.82 { return 1 }
        if ratio >= 0.66 { return 2 }
        if ratio >= 0.50 { return 3 }
        if ratio >= 0.36 { return 4 }
        return 5
    }

''')

# Stronger final-stage adaptation for small standard cells.
replace_once(surface,
'''        if compression >= 4 || slotSize.width < 155 || slotSize.height < 78 {
            content.mediaTitleLines = 1
            content.maxItems = min(1, content.maxItems)
            content.calendarShowJoin = false
        }
        style.content = content''',
'''        if compression >= 4 || slotSize.width < 155 || slotSize.height < 78 {
            content.mediaTitleLines = 1
            content.maxItems = min(1, content.maxItems)
            content.calendarShowJoin = false
        }
        if compression >= 5 || slotSize.width < 125 || slotSize.height < 68 {
            style.showTitle = false
            style.showHeaderIcon = false
            style.padding = min(style.padding, 2)
            style.fontSize = min(style.fontSize, 11)
            content.spacing = min(content.spacing, 2)
            content.controlSize = .mini
            content.maxItems = 1
            content.showSecondaryText = false
            content.showStatus = false
            content.showFooter = false
            content.showQuickActions = false
            content.showSearch = false
            content.mediaShowArtist = false
            content.mediaShowSource = false
            content.calendarShowTimes = false
            content.calendarShowJoin = false
            content.shelfShowDetails = false
            content.activitiesShowDetail = false
        }
        style.content = content''')

# Media needs a genuinely different micro composition in 1x1 cells.
replace_once(module,
'''            switch presentation {
            case .compact: compact
            case .expanded: expanded
            case .regular, .automatic: regular
            }''',
'''            switch presentation {
            case .compact:
                if (availableWidth ?? 200) < 150 || (availableHeight ?? 100) < 82 { microCompact }
                else { compact }
            case .expanded: expanded
            case .regular, .automatic: regular
            }''')

insert_before(module,
'''    private var compact: some View {''',
'''    private var microCompact: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                if let image = service.artworkImage {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: min(38, max(26, (availableHeight ?? 70) * 0.38)),
                               height: min(38, max(26, (availableHeight ?? 70) * 0.38)))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Text(service.title).font(.system(size: 10, weight: .semibold)).lineLimit(2).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            if options.showControls, service.connectedApp != nil {
                Button { service.perform("playpause", app: app) } label: {
                    Image(systemName: service.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

''')

# Notes editor should consume its allotted cell rather than keeping a configured fixed height.
replace_once(module,
'''struct IntegrationModuleView: View {
    @Environment(\\.widgetStyle) private var style
    @Environment(\\.openNotchPresentation) private var presentation''',
'''struct IntegrationModuleView: View {
    @Environment(\\.widgetStyle) private var style
    @Environment(\\.openNotchPresentation) private var presentation
    @Environment(\\.openNotchAvailableHeight) private var availableHeight''')

replace_once(module,
'''                TextEditor(text: $workspace.settings.notes)
                    .frame(height: presentation == .compact ? min(52, options.notesHeight) : presentation == .expanded ? max(140, options.notesHeight) : options.notesHeight)
                    .accessibilityLabel("Quick note")''',
'''                TextEditor(text: $workspace.settings.notes)
                    .frame(height: {
                        let available = max(34, (availableHeight ?? options.notesHeight) - (presentation == .compact ? 10 : 44))
                        switch presentation {
                        case .compact: return min(58, available)
                        case .expanded: return min(max(90, options.notesHeight), available)
                        case .regular, .automatic: return min(options.notesHeight, available)
                        }
                    }())
                    .accessibilityLabel("Quick note")''')

# ---------------------------------------------------------------------------
# Editor: direct grid controls and direct widget preview. Region code remains
# dormant for decoding old profiles but disappears from the user experience.
# ---------------------------------------------------------------------------
replace_once(settings,
'''            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            if opened.resolvedContentMode == .fixed {
                Menu { regionArrangementMenu } label: { Label("Regions", systemImage: "rectangle.3.group") }
            }
            Button { duplicateSelected() }''',
'''            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            Menu {
                Button("4 × 3") { setGrid(columns: 4, rows: 3) }
                Button("6 × 3") { setGrid(columns: 6, rows: 3) }
                Button("6 × 4") { setGrid(columns: 6, rows: 4) }
                Button("8 × 4") { setGrid(columns: 8, rows: 4) }
                Divider()
                Button("Auto Pack Widgets") { repackGrid() }
            } label: { Label("Grid", systemImage: "square.grid.3x3") }
            Button { duplicateSelected() }''')

replace_once(settings,
'''        Menu("Module") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }
        Menu("Lightweight element") { ForEach(OpenNotchElementKind.allCases) { element in Button(element.title) { addElement(element) } } }
        Divider()
        Button("Group") { addGroup() }
        Button("Region") { addRegion() }.disabled(opened.regions.count >= 9)''',
'''        Menu("Widget") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }
        Menu("Lightweight element") { ForEach(OpenNotchElementKind.allCases) { element in Button(element.title) { addElement(element) } }''')

# Replace only the preview implementation; old region helper views below remain unreachable.
preview_start = settings
p = Path(preview_start)
text = p.read_text()
start = text.index('    private var preview: some View {')
end = text.index('    private var editorRowWeights:', start)
new_preview = '''    private var preview: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opened Notch").font(.headline)
                    Text("\\(opened.resolvedGridColumns) columns · \\(max(opened.resolvedGridRows, opened.requiredGridRows)) rows")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("Drag a widget onto a grid cell · choose its standard size in the inspector")
                    .font(.caption).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay {
                    GeometryReader { proxy in
                        directGridPreview(canvasSize: proxy.size)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                .frame(width: 610, height: 470)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)
        }
    }

    private func directGridPreview(canvasSize: CGSize) -> some View {
        let padding: CGFloat = 14
        let columns = opened.resolvedGridColumns
        let rows = max(opened.resolvedGridRows, opened.requiredGridRows)
        let gap = max(2, CGFloat(opened.resolvedGridGap) * 0.65)
        let innerWidth = max(1, canvasSize.width - padding * 2)
        let innerHeight = max(1, canvasSize.height - padding * 2)
        let cellWidth = max(1, (innerWidth - gap * CGFloat(max(0, columns - 1))) / CGFloat(columns))
        let cellHeight = max(1, (innerHeight - gap * CGFloat(max(0, rows - 1))) / CGFloat(max(1, rows)))
        let items = opened.resolvedGridItems
        return ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for column in 0...columns {
                    let x = padding + CGFloat(column) * (cellWidth + gap) - (column == columns ? gap : 0)
                    var path = Path(); path.move(to: CGPoint(x: x, y: padding)); path.addLine(to: CGPoint(x: x, y: canvasSize.height - padding))
                    context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
                }
                for row in 0...rows {
                    let y = padding + CGFloat(row) * (cellHeight + gap) - (row == rows ? gap : 0)
                    var path = Path(); path.move(to: CGPoint(x: padding, y: y)); path.addLine(to: CGPoint(x: canvasSize.width - padding, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
                }
            }
            .allowsHitTesting(false)

            ForEach(0..<(columns * rows), id: \\.self) { index in
                let column = index % columns
                let row = index / columns
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: cellWidth, height: cellHeight)
                    .position(x: padding + CGFloat(column) * (cellWidth + gap) + cellWidth / 2,
                              y: padding + CGFloat(row) * (cellHeight + gap) + cellHeight / 2)
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        acceptGridDrop(providers, column: column, row: row)
                    }
            }

            ForEach(items) { item in
                if let raw = item.gridPlacement {
                    let placement = raw.clamped(columns: columns)
                    let width = cellWidth * CGFloat(placement.columnSpan) + gap * CGFloat(max(0, placement.columnSpan - 1))
                    let height = cellHeight * CGFloat(placement.rowSpan) + gap * CGFloat(max(0, placement.rowSpan - 1))
                    let x = padding + CGFloat(placement.column) * (cellWidth + gap)
                    let y = padding + CGFloat(placement.row) * (cellHeight + gap)
                    gridItemPreview(item, size: CGSize(width: width, height: height))
                        .frame(width: width, height: height)
                        .position(x: x + width / 2, y: y + height / 2)
                }
            }

            if items.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "square.grid.3x3").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
                    Text("Empty workspace").font(.headline)
                    Text("Add widgets directly to the grid.").font(.caption).foregroundStyle(.secondary)
                    Menu("Add Widget") { ForEach(ModuleID.allCases) { module in Button(module.title) { addModule(module) } } }
                        .buttonStyle(.borderedProminent)
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }

    private func gridItemPreview(_ item: OpenNotchItem, size: CGSize) -> some View {
        let label = item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized
        let selected = selectedItem == item.id
        let placement = item.gridPlacement ?? OpenNotchGridPlacement()
        let shape = RoundedRectangle(cornerRadius: min(14, max(7, min(size.width, size.height) * 0.10)), style: .continuous)
        return ZStack {
            widgetPreviewBackground(item)
            VStack(spacing: 5) {
                Image(systemName: item.module?.symbol ?? item.element?.symbol ?? "rectangle")
                    .font(.system(size: min(24, max(12, min(size.width, size.height) * 0.18)), weight: .semibold))
                Text(label).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Text("\\(placement.columnSpan)×\\(placement.rowSpan)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            .padding(5)
        }
        .clipShape(shape)
        .overlay(shape.stroke(selected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.10), lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { selectedItem = item.id; selectedGroup = nil; selectedRegion = nil; backgroundMode = false }
        .onDrag { NSItemProvider(object: item.id.uuidString as NSString) }
        .contextMenu {
            Menu("Size") {
                ForEach(OpenNotchGridSizePreset.allCases.filter { $0 != .custom }) { preset in
                    Button(preset.rawValue) { applyGridSize(preset, to: item.id) }
                }
            }
            Button("Duplicate") { duplicate(item.id) }
            Divider()
            Button("Remove", role: .destructive) { remove(item.id) }
        }
    }

'''
p.write_text(text[:start] + new_preview + text[end:])

# Default inspector now exposes grid rather than regions/groups.
replace_once(settings,
'''            else {
                Section("Opened workspace") {
                    Text("Select an item, group, or region in the preview. Drag modules between regions and use the resize handle on a selected item.").foregroundStyle(.secondary)
                    Button("Customize Surface Appearance") { backgroundMode = true }
                }
            }''',
'''            else {
                Section("Visual Workspace Grid") {
                    Stepper("Columns: \\(opened.resolvedGridColumns)", value: gridColumnsBinding, in: 2...12)
                    Stepper("Rows: \\(opened.resolvedGridRows)", value: gridRowsBinding, in: 1...12)
                    PreciseSlider(title: "Grid gap", value: gridGapBinding, range: 0...32, step: 1, suffix: "pt")
                    if opened.resolvedContentMode == .scroll {
                        PreciseSlider(title: "Scroll cell height", value: gridCellHeightBinding, range: 56...320, step: 2, suffix: "pt")
                    }
                    Button("Auto Pack Widgets") { repackGrid() }
                    Text("Widgets use standard grid footprints. Their contents automatically switch presentation, density and detail based on the actual pixel space produced by that footprint.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section { Button("Customize Surface Appearance") { backgroundMode = true } }
            }''')

# Every item, including modules, gets direct grid size/position controls.
replace_once(settings,
'''        Section("Item") {
            Text(item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized).font(.headline)
            Toggle("Visible", isOn: Binding(get: { !binding.wrappedValue.hidden }, set: { binding.wrappedValue.hidden = !$0 }))
            Picker("Presentation", selection: binding.presentation) { ForEach(OpenNotchPresentation.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Priority", selection: binding.priority) { ForEach(OpenNotchPriority.allCases) { Text($0.rawValue).tag($0) } }
        }
        if let module = item.module {''',
'''        Section("Item") {
            Text(item.module?.title ?? item.element?.title ?? item.kind.rawValue.capitalized).font(.headline)
            Toggle("Visible", isOn: Binding(get: { !binding.wrappedValue.hidden }, set: { binding.wrappedValue.hidden = !$0 }))
            Picker("Presentation", selection: binding.presentation) { ForEach(OpenNotchPresentation.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Priority", selection: binding.priority) { ForEach(OpenNotchPriority.allCases) { Text($0.rawValue).tag($0) } }
        }
        Section("Grid Size & Position") {
            Picker("Standard size", selection: gridSizePresetBinding(item.id)) {
                ForEach(OpenNotchGridSizePreset.allCases) { Text($0.rawValue).tag($0) }
            }
            let placement = gridPlacementBinding(item.id)
            Stepper("Width: \\(placement.wrappedValue.columnSpan) column\\(placement.wrappedValue.columnSpan == 1 ? "" : "s")",
                    value: placement.columnSpan, in: 1...opened.resolvedGridColumns)
            Stepper("Height: \\(placement.wrappedValue.rowSpan) row\\(placement.wrappedValue.rowSpan == 1 ? "" : "s")",
                    value: placement.rowSpan, in: 1...12)
            Divider()
            Stepper("Column: \\(placement.wrappedValue.column + 1)", value: placement.column,
                    in: 0...max(0, opened.resolvedGridColumns - placement.wrappedValue.columnSpan))
            Stepper("Row: \\(placement.wrappedValue.row + 1)", value: placement.row, in: 0...48)
        }
        if let module = item.module {''')

replace_once(settings,
'''        Section { HStack { Button("Duplicate") { duplicate(item.id) }; Button("New Group") { groupSelectedItem() }; Spacer(); Button("Remove", role: .destructive) { remove(item.id) } } }''',
'''        Section { HStack { Button("Duplicate") { duplicate(item.id) }; Spacer(); Button("Remove", role: .destructive) { remove(item.id) } } }''')

# Direct-grid bindings and mutation helpers.
replace_once(settings,
'''    private func materialize() { if layout.openNotch == nil { layout.materializeOpenNotchLayout() } }
    private func openBinding() -> Binding<OpenNotchLayout> { Binding(get: { layout.resolvedOpenNotchLayout }, set: { layout.openNotch = $0 }) }
    private func itemBinding(_ id: UUID) -> Binding<OpenNotchItem> { Binding(get: { findItem(id) ?? OpenNotchItem() }, set: { replacement in mutateItem(id) { $0 = replacement } }) }''',
'''    private func materialize() {
        if layout.openNotch == nil { layout.materializeOpenNotchLayout() }
        var value = layout.resolvedOpenNotchLayout
        value.materializeGridItems()
        layout.openNotch = value
    }
    private func openBinding() -> Binding<OpenNotchLayout> { Binding(get: { layout.resolvedOpenNotchLayout }, set: { layout.openNotch = $0 }) }
    private func itemBinding(_ id: UUID) -> Binding<OpenNotchItem> { Binding(get: { findItem(id) ?? OpenNotchItem() }, set: { replacement in mutateItem(id) { $0 = replacement } }) }''')

replace_once(settings,
'''    private func findItem(_ id: UUID) -> OpenNotchItem? { opened.allItems.first { $0.id == id } }
    private func findGroup(_ id: UUID) -> OpenNotchGroup? { opened.regions.flatMap(\\.groups).first { $0.id == id } }
    private func findRegion(_ id: UUID) -> OpenNotchRegion? { opened.regions.first { $0.id == id } }
    private func mutateOpen(_ body: (inout OpenNotchLayout) -> Void) { var value = opened; body(&value); value.preset = .custom; layout.openNotch = value }
    private func mutateItem(_ id: UUID, _ body: (inout OpenNotchItem) -> Void) { mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { if let ii = open.regions[ri].groups[gi].items.firstIndex(where: { $0.id == id }) { body(&open.regions[ri].groups[gi].items[ii]); return } } } } }''',
'''    private func findItem(_ id: UUID) -> OpenNotchItem? { opened.resolvedGridItems.first { $0.id == id } }
    private func findGroup(_ id: UUID) -> OpenNotchGroup? { opened.regions.flatMap(\\.groups).first { $0.id == id } }
    private func findRegion(_ id: UUID) -> OpenNotchRegion? { opened.regions.first { $0.id == id } }
    private func mutateOpen(_ body: (inout OpenNotchLayout) -> Void) { var value = opened; body(&value); value.preset = .custom; layout.openNotch = value }
    private func mutateItem(_ id: UUID, _ body: (inout OpenNotchItem) -> Void) {
        mutateOpen { open in
            open.materializeGridItems()
            guard let index = open.gridItems?.firstIndex(where: { $0.id == id }) else { return }
            body(&open.gridItems![index])
            open.normalizeGridItems(pinnedID: id)
        }
    }''')

# Replace add/remove/duplicate operations with direct item operations.
replace_once(settings,
'''    private func addModule(_ module: ModuleID) { var item = OpenNotchItem.moduleItem(module); let gid = defaultGroupID(); mutateOpen { open in append(item, to: gid, open: &open) }; layout.enabled.insert(module); selectedItem = item.id; selectedGroup = gid }
    private func addElement(_ element: OpenNotchElementKind) { let item = OpenNotchItem.elementItem(element); let gid = defaultGroupID(); mutateOpen { open in append(item, to: gid, open: &open) }; selectedItem = item.id; selectedGroup = gid }
    private func addGroup(regionID: UUID? = nil) {''',
'''    private func addModule(_ module: ModuleID) {
        var item = OpenNotchItem.moduleItem(module)
        mutateOpen { open in
            open.materializeGridItems()
            open.gridItems?.append(item)
            open.normalizeGridItems(pinnedID: item.id)
        }
        layout.enabled.insert(module)
        selectedItem = item.id; selectedGroup = nil; selectedRegion = nil
    }
    private func addElement(_ element: OpenNotchElementKind) {
        let item = OpenNotchItem.elementItem(element)
        mutateOpen { open in
            open.materializeGridItems()
            open.gridItems?.append(item)
            open.normalizeGridItems(pinnedID: item.id)
        }
        selectedItem = item.id; selectedGroup = nil; selectedRegion = nil
    }
    private func addGroup(regionID: UUID? = nil) {''')

replace_once(settings,
'''    private func remove(_ id: UUID) { mutateOpen { open in for ri in open.regions.indices { for gi in open.regions[ri].groups.indices { open.regions[ri].groups[gi].items.removeAll { $0.id == id } } } }; selectedItem = nil }
    private func duplicate(_ id: UUID) { guard var copy = findItem(id) else { return }; copy.id = UUID(); let gid = selectedGroup ?? defaultGroupID(); mutateOpen { open in append(copy, to: gid, open: &open) }; selectedItem = copy.id }
    private func duplicateSelected() { if let selectedItem { duplicate(selectedItem) } }''',
'''    private func remove(_ id: UUID) {
        mutateOpen { open in open.materializeGridItems(); open.gridItems?.removeAll { $0.id == id }; open.normalizeGridItems() }
        selectedItem = nil
    }
    private func duplicate(_ id: UUID) {
        guard var copy = findItem(id) else { return }
        copy.id = UUID(); copy.gridPlacement = nil
        mutateOpen { open in open.materializeGridItems(); open.gridItems?.append(copy); open.normalizeGridItems(pinnedID: copy.id) }
        selectedItem = copy.id
    }
    private func duplicateSelected() { if let selectedItem { duplicate(selectedItem) } }''')

replace_once(settings,
'''    private func applyPreset(_ preset: OpenNotchPreset) { guard preset != .custom else { mutateOpen { $0.preset = .custom }; return }; layout.applyOpenNotchPreset(preset); selectedItem = nil; selectedGroup = nil; selectedRegion = nil }

    private func acceptDrop(_ providers: [NSItemProvider], placement: OpenNotchRegionPlacement) -> Bool {''',
'''    private func applyPreset(_ preset: OpenNotchPreset) {
        guard preset != .custom else { mutateOpen { $0.preset = .custom }; return }
        layout.applyOpenNotchPreset(preset)
        selectedItem = nil; selectedGroup = nil; selectedRegion = nil
    }

    private var gridColumnsBinding: Binding<Int> {
        Binding(get: { opened.resolvedGridColumns }, set: { value in
            mutateOpen { open in open.gridColumns = value; open.materializeGridItems(); open.normalizeGridItems() }
        })
    }
    private var gridRowsBinding: Binding<Int> {
        Binding(get: { opened.resolvedGridRows }, set: { value in mutateOpen { $0.gridRows = value } })
    }
    private var gridGapBinding: Binding<Double> {
        Binding(get: { opened.resolvedGridGap }, set: { value in mutateOpen { $0.gridGap = value } })
    }
    private var gridCellHeightBinding: Binding<Double> {
        Binding(get: { opened.resolvedGridCellHeight }, set: { value in mutateOpen { $0.gridCellHeight = value } })
    }
    private func gridPlacementBinding(_ id: UUID) -> Binding<OpenNotchGridPlacement> {
        Binding(get: { findItem(id)?.gridPlacement ?? OpenNotchGridPlacement() }, set: { replacement in
            mutateItem(id) { $0.gridPlacement = replacement.clamped(columns: opened.resolvedGridColumns) }
        })
    }
    private func gridSizePresetBinding(_ id: UUID) -> Binding<OpenNotchGridSizePreset> {
        Binding(get: {
            let p = findItem(id)?.gridPlacement ?? OpenNotchGridPlacement()
            return .matching(columns: p.columnSpan, rows: p.rowSpan)
        }, set: { preset in applyGridSize(preset, to: id) })
    }
    private func applyGridSize(_ preset: OpenNotchGridSizePreset, to id: UUID) {
        guard let span = preset.span else { return }
        mutateItem(id) { item in
            var placement = item.gridPlacement ?? OpenNotchGridPlacement()
            placement.columnSpan = min(opened.resolvedGridColumns, span.columns)
            placement.rowSpan = span.rows
            item.gridPlacement = placement
        }
    }
    private func setGrid(columns: Int, rows: Int) {
        mutateOpen { open in
            open.gridColumns = columns; open.gridRows = rows
            open.materializeGridItems(); open.normalizeGridItems(pinnedID: selectedItem)
        }
    }
    private func repackGrid() {
        mutateOpen { open in
            open.materializeGridItems()
            if open.gridItems != nil {
                for index in open.gridItems!.indices { open.gridItems![index].gridPlacement = nil }
            }
            open.normalizeGridItems()
        }
    }
    private func acceptGridDrop(_ providers: [NSItemProvider], column: Int, row: Int) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String, let id = UUID(uuidString: text) else { return }
            DispatchQueue.main.async {
                mutateItem(id) { item in
                    var placement = item.gridPlacement ?? OpenNotchGridPlacement()
                    placement.column = column; placement.row = row
                    item.gridPlacement = placement
                }
                selectedItem = id; selectedGroup = nil; selectedRegion = nil
            }
        }
        return true
    }

    private func acceptDrop(_ providers: [NSItemProvider], placement: OpenNotchRegionPlacement) -> Bool {''')

print('Applied direct Visual Workspace widget-grid architecture.')
