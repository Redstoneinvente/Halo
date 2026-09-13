from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1))

models = 'Halo/Core/WorkspaceModels.swift'
widgets = 'Halo/Views/WidgetSettingsView.swift'
surface = 'Halo/Views/SurfaceView.swift'

old = '''struct OpenNotchRegion: Codable, Equatable, Identifiable {
    var id = UUID()
    var placement: OpenNotchRegionPlacement = .middleCenter
    var padding = OpenNotchInsets()
    // Fractions are relative to the region's grid track. Optional keeps layouts
    // created by the first workspace version fully decodable.
    var widthFraction: Double?
    var heightFraction: Double?
    var groups: [OpenNotchGroup] = []
    var resolvedWidthFraction: Double { min(1, max(0.15, widthFraction ?? 1)) }
    var resolvedHeightFraction: Double { min(1, max(0.15, heightFraction ?? 1)) }
    func validated() throws -> OpenNotchRegion {
        var value = self
        if let widthFraction { guard widthFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.widthFraction = min(1, max(0.15, widthFraction)) }
        if let heightFraction { guard heightFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.heightFraction = min(1, max(0.15, heightFraction)) }
        value.padding = try padding.validated(); value.groups = try groups.prefix(16).map { try $0.validated() }
        return value
    }
}
'''
new = '''struct OpenNotchRegionFrame: Codable, Equatable {
    // Normalized coordinates inside the opened Visual Workspace canvas.
    // Optional use on OpenNotchRegion keeps every pre-freeform layout decodable.
    var x = 0.0
    var y = 0.0
    var width = 1.0
    var height = 1.0

    static let full = OpenNotchRegionFrame()

    func clamped(minimumSize: Double = 0.10) -> OpenNotchRegionFrame {
        var value = self
        value.width = min(1, max(minimumSize, width))
        value.height = min(1, max(minimumSize, height))
        value.x = min(1 - value.width, max(0, x))
        value.y = min(1 - value.height, max(0, y))
        return value
    }

    func union(_ other: OpenNotchRegionFrame) -> OpenNotchRegionFrame {
        let left = min(x, other.x)
        let top = min(y, other.y)
        let right = max(x + width, other.x + other.width)
        let bottom = max(y + height, other.y + other.height)
        return OpenNotchRegionFrame(x: left, y: top, width: right - left, height: bottom - top).clamped()
    }

    func validated() throws -> OpenNotchRegionFrame {
        guard [x, y, width, height].allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        return clamped()
    }
}

struct OpenNotchRegion: Codable, Equatable, Identifiable {
    var id = UUID()
    var placement: OpenNotchRegionPlacement = .middleCenter
    var padding = OpenNotchInsets()
    // Fractions are relative to the legacy grid track. They remain for old layouts.
    var widthFraction: Double?
    var heightFraction: Double?
    // Once set, frame replaces the legacy 3x3 track geometry for Fixed Canvas.
    var frame: OpenNotchRegionFrame?
    var groups: [OpenNotchGroup] = []
    var resolvedWidthFraction: Double { min(1, max(0.15, widthFraction ?? 1)) }
    var resolvedHeightFraction: Double { min(1, max(0.15, heightFraction ?? 1)) }
    func validated() throws -> OpenNotchRegion {
        var value = self
        if let widthFraction { guard widthFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.widthFraction = min(1, max(0.15, widthFraction)) }
        if let heightFraction { guard heightFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.heightFraction = min(1, max(0.15, heightFraction)) }
        value.frame = try frame?.validated()
        value.padding = try padding.validated(); value.groups = try groups.prefix(16).map { try $0.validated() }
        return value
    }
}
'''
replace_once(models, old, new)

old = '''    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }
    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }
    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }
    var allItems: [OpenNotchItem] { regions.flatMap(\\.groups).flatMap(\\.items) }
'''
new = '''    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }
    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }
    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }
    var usesFreeformRegions: Bool { regions.contains { $0.frame != nil } }
    var allItems: [OpenNotchItem] { regions.flatMap(\\.groups).flatMap(\\.items) }
'''
replace_once(models, old, new)

old = '''    mutating func setRowWeight(_ value: Double, at index: Int) {
        guard (0..<3).contains(index) else { return }
        var values = resolvedRowWeights; values[index] = min(6, max(0.1, value)); rowWeights = values
    }

    static func migrated(modules: [ModuleID], horizontal: Bool) -> OpenNotchLayout {
'''
new = '''    mutating func setRowWeight(_ value: Double, at index: Int) {
        guard (0..<3).contains(index) else { return }
        var values = resolvedRowWeights; values[index] = min(6, max(0.1, value)); rowWeights = values
    }

    // Converts the legacy collapsed 3x3 tracks into normalized freeform frames.
    // This only happens when a user starts editing region geometry, so old profiles
    // keep their exact legacy behavior until then.
    mutating func materializeRegionFrames() {
        guard !regions.isEmpty else { return }
        let occupiedColumns = (0..<3).map { column in regions.contains { Self.columnIndex($0.placement) == column } }
        let occupiedRows = (0..<3).map { row in regions.contains { Self.rowIndex($0.placement) == row } }
        let columnTracks = Self.normalizedTracks(weights: resolvedColumnWeights, occupied: occupiedColumns)
        let rowTracks = Self.normalizedTracks(weights: resolvedRowWeights, occupied: occupiedRows)

        for index in regions.indices where regions[index].frame == nil {
            let region = regions[index]
            let column = columnTracks[Self.columnIndex(region.placement)]
            let row = rowTracks[Self.rowIndex(region.placement)]
            let width = column.length * region.resolvedWidthFraction
            let height = row.length * region.resolvedHeightFraction
            let x = column.start + (column.length - width) * Self.horizontalAnchor(region.placement)
            let y = row.start + (row.length - height) * Self.verticalAnchor(region.placement)
            regions[index].frame = OpenNotchRegionFrame(x: x, y: y, width: width, height: height).clamped()
        }
    }

    private static func normalizedTracks(weights: [Double], occupied: [Bool]) -> [(start: Double, length: Double)] {
        let active = zip(weights, occupied).map { max(0, $1 ? $0 : 0) }
        let total = active.reduce(0, +)
        guard total > 0 else { return [(0, 1.0 / 3), (1.0 / 3, 1.0 / 3), (2.0 / 3, 1.0 / 3)] }
        var cursor = 0.0
        return active.map { weight in
            let length = weight > 0 ? weight / total : 0
            defer { cursor += length }
            return (cursor, length)
        }
    }

    private static func rowIndex(_ placement: OpenNotchRegionPlacement) -> Int {
        switch placement { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 1; case .bottomLeft, .bottomCenter, .bottomRight: return 2 }
    }
    private static func columnIndex(_ placement: OpenNotchRegionPlacement) -> Int {
        switch placement { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 1; case .topRight, .middleRight, .bottomRight: return 2 }
    }
    private static func horizontalAnchor(_ placement: OpenNotchRegionPlacement) -> Double {
        switch placement { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 0.5; case .topRight, .middleRight, .bottomRight: return 1 }
    }
    private static func verticalAnchor(_ placement: OpenNotchRegionPlacement) -> Double {
        switch placement { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 0.5; case .bottomLeft, .bottomCenter, .bottomRight: return 1 }
    }

    static func migrated(modules: [ModuleID], horizontal: Bool) -> OpenNotchLayout {
'''
replace_once(models, old, new)

old = '''    private var fixedCanvas: some View {
        GeometryReader { proxy in
            let heights = trackSizes(total: proxy.size.height, weights: effectiveRowWeights, gaps: 2)
            VStack(spacing: gap) {
                regionRow([.topLeft, .topCenter, .topRight], height: heights[0])
                regionRow([.middleLeft, .middleCenter, .middleRight], height: heights[1])
                regionRow([.bottomLeft, .bottomCenter, .bottomRight], height: heights[2])
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
'''
new = '''    @ViewBuilder private var fixedCanvas: some View {
        if opened.usesFreeformRegions {
            freeformCanvas
        } else {
            legacyFixedCanvas
        }
    }

    private var freeformCanvas: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(regions) { region in
                    let frame = region.frame ?? fallbackFrame(for: region.placement)
                    OpenNotchRegionView(region: region, layout: layout, store: store)
                        .frame(width: max(1, proxy.size.width * CGFloat(frame.width)),
                               height: max(1, proxy.size.height * CGFloat(frame.height)))
                        .offset(x: proxy.size.width * CGFloat(frame.x),
                                y: proxy.size.height * CGFloat(frame.y))
                        .clipped()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    private var legacyFixedCanvas: some View {
        GeometryReader { proxy in
            let heights = trackSizes(total: proxy.size.height, weights: effectiveRowWeights, gaps: 2)
            VStack(spacing: gap) {
                regionRow([.topLeft, .topCenter, .topRight], height: heights[0])
                regionRow([.middleLeft, .middleCenter, .middleRight], height: heights[1])
                regionRow([.bottomLeft, .bottomCenter, .bottomRight], height: heights[2])
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func fallbackFrame(for placement: OpenNotchRegionPlacement) -> OpenNotchRegionFrame {
        let column: Double
        let row: Double
        switch placement {
        case .topLeft, .middleLeft, .bottomLeft: column = 0
        case .topCenter, .middleCenter, .bottomCenter: column = 1
        case .topRight, .middleRight, .bottomRight: column = 2
        }
        switch placement {
        case .topLeft, .topCenter, .topRight: row = 0
        case .middleLeft, .middleCenter, .middleRight: row = 1
        case .bottomLeft, .bottomCenter, .bottomRight: row = 2
        }
        return OpenNotchRegionFrame(x: column / 3, y: row / 3, width: 1.0 / 3, height: 1.0 / 3)
    }
'''
replace_once(surface, old, new)

old = '''            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            Button { duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.disabled(selectedItem == nil).help("Duplicate selected item")
'''
new = '''            Menu { addMenu } label: { Label("Add", systemImage: "plus") }
            if opened.resolvedContentMode == .fixed {
                Menu { regionArrangementMenu } label: { Label("Regions", systemImage: "rectangle.3.group") }
            }
            Button { duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.disabled(selectedItem == nil).help("Duplicate selected item")
'''
replace_once(widgets, old, new)

old = '''        Divider()
        Button("Group") { addGroup() }
        Menu("Region") { ForEach(OpenNotchRegionPlacement.allCases) { placement in Button(placement.title) { ensureRegion(placement, select: true) } } }
    }

    private var preview: some View {
'''
new = '''        Divider()
        Button("Group") { addGroup() }
        Button("Region") { addRegion() }.disabled(opened.regions.count >= 9)
    }

    @ViewBuilder private var regionArrangementMenu: some View {
        Button("Add Region") { addRegion() }.disabled(opened.regions.count >= 9)
        if !opened.regions.isEmpty {
            Divider()
            let count = opened.regions.count
            if count == 1 {
                Button("Full Canvas") { arrangeSingle(.full) }
                Button("Centered Large") { arrangeSingle(OpenNotchRegionFrame(x: 0.10, y: 0.10, width: 0.80, height: 0.80)) }
                Button("Compact Center") { arrangeSingle(OpenNotchRegionFrame(x: 0.25, y: 0.25, width: 0.50, height: 0.50)) }
                Divider()
                Button("Left Half") { arrangeSingle(OpenNotchRegionFrame(x: 0, y: 0, width: 0.50, height: 1)) }
                Button("Right Half") { arrangeSingle(OpenNotchRegionFrame(x: 0.50, y: 0, width: 0.50, height: 1)) }
                Button("Top Half") { arrangeSingle(OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.50)) }
                Button("Bottom Half") { arrangeSingle(OpenNotchRegionFrame(x: 0, y: 0.50, width: 1, height: 0.50)) }
            } else if count == 2 {
                Button("Side by Side") { arrangeSideBySide() }
                Button("Stacked") { arrangeStacked() }
                Divider()
                Button("Wide Left + Narrow Right") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 0.64, height: 1), OpenNotchRegionFrame(x: 0.66, y: 0, width: 0.34, height: 1)]) }
                Button("Narrow Left + Wide Right") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 0.34, height: 1), OpenNotchRegionFrame(x: 0.36, y: 0, width: 0.64, height: 1)]) }
                Button("Hero Top + Bottom Strip") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.66), OpenNotchRegionFrame(x: 0, y: 0.68, width: 1, height: 0.32)]) }
                Button("Top Strip + Hero Bottom") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.32), OpenNotchRegionFrame(x: 0, y: 0.34, width: 1, height: 0.66)]) }
            } else if count == 3 {
                Button("3 Columns") { arrangeColumns() }
                Button("3 Rows") { arrangeRows() }
                Divider()
                Button("Hero Left + Right Stack") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 0.58, height: 1), OpenNotchRegionFrame(x: 0.60, y: 0, width: 0.40, height: 0.49), OpenNotchRegionFrame(x: 0.60, y: 0.51, width: 0.40, height: 0.49)]) }
                Button("Hero Top + Bottom Split") { applyRegionFrames([OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.58), OpenNotchRegionFrame(x: 0, y: 0.60, width: 0.49, height: 0.40), OpenNotchRegionFrame(x: 0.51, y: 0.60, width: 0.49, height: 0.40)]) }
            } else if count == 4 {
                Button("2 × 2 Grid") { arrangeGrid() }
                Button("4 Columns") { arrangeColumns() }
                Button("4 Rows") { arrangeRows() }
            } else {
                Button("Automatic Grid") { arrangeGrid() }
                Button("Columns") { arrangeColumns() }
                Button("Rows") { arrangeRows() }
            }
        }
    }

    private var preview: some View {
'''
replace_once(widgets, old, new)

old = '''                    GeometryReader { proxy in
                        let inset: CGFloat = 14
                        let canvasWidth = max(1, proxy.size.width - inset * 2)
                        let canvasHeight = max(1, proxy.size.height - inset * 2)
                        let heights = editorTrackSizes(total: canvasHeight, weights: editorRowWeights, gap: 8)
                        VStack(spacing: 8) {
                            editorRow([.topLeft, .topCenter, .topRight], height: heights[0], totalWidth: canvasWidth)
                            editorRow([.middleLeft, .middleCenter, .middleRight], height: heights[1], totalWidth: canvasWidth)
                            editorRow([.bottomLeft, .bottomCenter, .bottomRight], height: heights[2], totalWidth: canvasWidth)
                        }
                        .padding(inset)
                    }
'''
new = '''                    GeometryReader { proxy in
                        let inset: CGFloat = 14
                        let canvasSize = CGSize(width: max(1, proxy.size.width - inset * 2), height: max(1, proxy.size.height - inset * 2))
                        if opened.resolvedContentMode == .fixed && opened.usesFreeformRegions {
                            freeformPreview(canvasSize: canvasSize)
                                .padding(inset)
                        } else {
                            let heights = editorTrackSizes(total: canvasSize.height, weights: editorRowWeights, gap: 8)
                            VStack(spacing: 8) {
                                editorRow([.topLeft, .topCenter, .topRight], height: heights[0], totalWidth: canvasSize.width)
                                editorRow([.middleLeft, .middleCenter, .middleRight], height: heights[1], totalWidth: canvasSize.width)
                                editorRow([.bottomLeft, .bottomCenter, .bottomRight], height: heights[2], totalWidth: canvasSize.width)
                            }
                            .padding(inset)
                        }
                    }
'''
replace_once(widgets, old, new)

insert_after = '''    private func regionCell(_ placement: OpenNotchRegionPlacement, cellSize: CGSize) -> some View {
        let region = opened.regions.first { $0.placement == placement }
        return ZStack(alignment: placement.editorAlignment) {
            if let region {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(placement.title).font(.system(size: 9, weight: .semibold)); Spacer(); Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.green) }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(width: max(34, cellSize.width * CGFloat(region.resolvedWidthFraction)),
                       height: max(34, cellSize.height * CGFloat(region.resolvedHeightFraction)), alignment: .topLeading)
                .background((selectedRegion == region.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.035)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedRegion == region.id ? Color.accentColor.opacity(0.6) : .white.opacity(0.06)))
                .contentShape(Rectangle())
                .clipped()
                .onTapGesture { selectedRegion = region.id; selectedGroup = nil; selectedItem = nil; backgroundMode = false }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, placement: placement) }
            } else if cellSize.width > 24 && cellSize.height > 24 {
                Text("Drop here").font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, placement: placement) }
            }
        }
        .frame(width: cellSize.width, height: cellSize.height, alignment: placement.editorAlignment)
        .clipped()
    }
'''
addition = insert_after + '''

    private func freeformPreview(canvasSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(opened.regions) { region in
                let frame = effectiveRegionFrame(region.id)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(regionTitle(region)).font(.system(size: 9, weight: .semibold))
                        Spacer()
                        Text("\\(Int((frame.width * 100).rounded()))×\\(Int((frame.height * 100).rounded()))%")
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(7)
                .frame(width: max(44, canvasSize.width * CGFloat(frame.width)),
                       height: max(44, canvasSize.height * CGFloat(frame.height)), alignment: .topLeading)
                .background((selectedRegion == region.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.045)), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedRegion == region.id ? Color.accentColor.opacity(0.75) : .white.opacity(0.08), lineWidth: selectedRegion == region.id ? 1.5 : 1))
                .contentShape(Rectangle())
                .clipped()
                .offset(x: canvasSize.width * CGFloat(frame.x), y: canvasSize.height * CGFloat(frame.y))
                .onTapGesture { selectedRegion = region.id; selectedGroup = nil; selectedItem = nil; backgroundMode = false }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, regionID: region.id) }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .clipped()
    }

    private func regionTitle(_ region: OpenNotchRegion) -> String {
        let index = (opened.regions.firstIndex(where: { $0.id == region.id }) ?? 0) + 1
        return "Region \\(index)"
    }
'''
replace_once(widgets, insert_after, addition)

old = '''    @ViewBuilder private func regionInspector(_ region: OpenNotchRegion) -> some View {
        let b = regionBinding(region.id)
        Section("Region") { Picker("Placement", selection: b.placement) { ForEach(OpenNotchRegionPlacement.allCases) { Text($0.title).tag($0) } } }
        Section("Region size") {
            PreciseSlider(title: "Width in column", value: Binding(
                get: { b.wrappedValue.resolvedWidthFraction * 100 },
                set: { b.wrappedValue.widthFraction = $0 / 100 }
            ), range: 15...100, step: 1, suffix: "%")
            PreciseSlider(title: "Height in row", value: Binding(
                get: { b.wrappedValue.resolvedHeightFraction * 100 },
                set: { b.wrappedValue.heightFraction = $0 / 100 }
            ), range: 15...100, step: 1, suffix: "%")
            PreciseSlider(title: "Column width share", value: columnWeightBinding(for: b.wrappedValue.placement), range: 0.1...6, step: 0.1, suffix: "×", decimals: 1)
            PreciseSlider(title: "Row height share", value: rowWeightBinding(for: b.wrappedValue.placement), range: 0.1...6, step: 0.1, suffix: "×", decimals: 1)
            Button("Reset Region Size") { b.wrappedValue.widthFraction = nil; b.wrappedValue.heightFraction = nil; resetTrackWeights(for: b.wrappedValue.placement) }
            Text("Track shares control the relative size of this row/column. Width and height percentages control how much of that designed slot this region occupies.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Region padding") { insetsEditor(b.padding) }
        Section { Button("Add Group") { addGroup(regionID: region.id) } }
    }
'''
new = '''    @ViewBuilder private func regionInspector(_ region: OpenNotchRegion) -> some View {
        let b = regionBinding(region.id)
        Section("Region") {
            Text(regionTitle(region)).font(.headline)
            Text("\\(region.groups.count) group\\(region.groups.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
            if opened.resolvedContentMode != .fixed {
                Picker("Order position", selection: b.placement) { ForEach(OpenNotchRegionPlacement.allCases) { Text($0.title).tag($0) } }
            }
        }
        if opened.resolvedContentMode == .fixed {
            Section("Frame") {
                Menu("Quick Size & Position") {
                    Button("Full Canvas") { setRegionFrame(region.id, .full) }
                    Button("Centered Large") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.10, y: 0.10, width: 0.80, height: 0.80)) }
                    Button("Compact Center") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.25, y: 0.25, width: 0.50, height: 0.50)) }
                    Divider()
                    Button("Left Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0, width: 0.50, height: 1)) }
                    Button("Right Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.50, y: 0, width: 0.50, height: 1)) }
                    Button("Top Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0, width: 1, height: 0.50)) }
                    Button("Bottom Half") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0.50, width: 1, height: 0.50)) }
                    Divider()
                    Button("Top Left Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0, width: 0.50, height: 0.50)) }
                    Button("Top Right Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.50, y: 0, width: 0.50, height: 0.50)) }
                    Button("Bottom Left Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0, y: 0.50, width: 0.50, height: 0.50)) }
                    Button("Bottom Right Quarter") { setRegionFrame(region.id, OpenNotchRegionFrame(x: 0.50, y: 0.50, width: 0.50, height: 0.50)) }
                }
                PreciseSlider(title: "X", value: regionFramePercentBinding(region.id, \\.x), range: 0...100, step: 1, suffix: "%")
                PreciseSlider(title: "Y", value: regionFramePercentBinding(region.id, \\.y), range: 0...100, step: 1, suffix: "%")
                PreciseSlider(title: "Width", value: regionFramePercentBinding(region.id, \\.width), range: 10...100, step: 1, suffix: "%")
                PreciseSlider(title: "Height", value: regionFramePercentBinding(region.id, \\.height), range: 10...100, step: 1, suffix: "%")
                Text("Regions use normalized canvas coordinates, so the same layout scales with the opened notch size. Regions may also overlap intentionally.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Section("Region padding") { insetsEditor(b.padding) }
        Section("Region actions") {
            Button("Add Group") { addGroup(regionID: region.id) }
            if opened.regions.count > 1 {
                Menu("Merge Into…") {
                    ForEach(opened.regions.filter { $0.id != region.id }) { target in
                        Button(regionTitle(target)) { mergeRegion(region.id, into: target.id) }
                    }
                }
            }
            Button("Remove Region", role: .destructive) { removeRegion(region.id) }
        }
    }
'''
replace_once(widgets, old, new)

old = '''    private func ensureRegion(_ placement: OpenNotchRegionPlacement, select: Bool = false) {
        mutateOpen { open in
            if !open.regions.contains(where: { $0.placement == placement }) { open.regions.append(OpenNotchRegion(placement: placement, padding: OpenNotchInsets(), groups: [OpenNotchGroup(name: placement.title)])) }
        }
        if select, let r = opened.regions.first(where: { $0.placement == placement }) { selectedRegion = r.id }
    }
    private func defaultGroupID() -> UUID {
'''
new = '''    private func ensureRegion(_ placement: OpenNotchRegionPlacement, select: Bool = false) {
        mutateOpen { open in
            if !open.regions.contains(where: { $0.placement == placement }) { open.regions.append(OpenNotchRegion(placement: placement, padding: OpenNotchInsets(), groups: [OpenNotchGroup(name: placement.title)])) }
        }
        if select, let r = opened.regions.first(where: { $0.placement == placement }) { selectedRegion = r.id }
    }

    private func addRegion() {
        guard opened.regions.count < 9 else { return }
        let id = UUID()
        mutateOpen { open in
            open.materializeRegionFrames()
            let used = Set(open.regions.map(\\.placement))
            let placement = OpenNotchRegionPlacement.allCases.first(where: { !used.contains($0) }) ?? .middleCenter
            var region = OpenNotchRegion()
            region.id = id
            region.placement = placement
            region.padding = OpenNotchInsets()
            region.frame = .full
            region.groups = [OpenNotchGroup(name: "Region \\(open.regions.count + 1)")]
            open.regions.append(region)
            applyDefaultArrangement(to: &open)
        }
        selectedRegion = id; selectedGroup = nil; selectedItem = nil; backgroundMode = false
    }

    private func effectiveRegionFrame(_ id: UUID) -> OpenNotchRegionFrame {
        var value = opened
        value.materializeRegionFrames()
        return value.regions.first(where: { $0.id == id })?.frame ?? .full
    }

    private func regionFramePercentBinding(_ id: UUID, _ keyPath: WritableKeyPath<OpenNotchRegionFrame, Double>) -> Binding<Double> {
        Binding(
            get: { effectiveRegionFrame(id)[keyPath: keyPath] * 100 },
            set: { percent in
                mutateOpen { open in
                    open.materializeRegionFrames()
                    guard let index = open.regions.firstIndex(where: { $0.id == id }) else { return }
                    var frame = open.regions[index].frame ?? .full
                    frame[keyPath: keyPath] = percent / 100
                    open.regions[index].frame = frame.clamped()
                }
            }
        )
    }

    private func setRegionFrame(_ id: UUID, _ frame: OpenNotchRegionFrame) {
        mutateOpen { open in
            open.materializeRegionFrames()
            if let index = open.regions.firstIndex(where: { $0.id == id }) { open.regions[index].frame = frame.clamped() }
        }
    }

    private func applyRegionFrames(_ frames: [OpenNotchRegionFrame]) {
        mutateOpen { open in
            open.materializeRegionFrames()
            for index in open.regions.indices where index < frames.count { open.regions[index].frame = frames[index].clamped() }
        }
    }

    private func arrangeSingle(_ frame: OpenNotchRegionFrame) { guard opened.regions.count == 1 else { return }; applyRegionFrames([frame]) }
    private func arrangeSideBySide() { arrangeColumns() }
    private func arrangeStacked() { arrangeRows() }

    private func arrangeColumns() {
        let count = opened.regions.count
        guard count > 0 else { return }
        let gap = count > 1 ? 0.02 : 0
        let width = (1 - gap * Double(count - 1)) / Double(count)
        applyRegionFrames((0..<count).map { OpenNotchRegionFrame(x: Double($0) * (width + gap), y: 0, width: width, height: 1) })
    }

    private func arrangeRows() {
        let count = opened.regions.count
        guard count > 0 else { return }
        let gap = count > 1 ? 0.02 : 0
        let height = (1 - gap * Double(count - 1)) / Double(count)
        applyRegionFrames((0..<count).map { OpenNotchRegionFrame(x: 0, y: Double($0) * (height + gap), width: 1, height: height) })
    }

    private func arrangeGrid() {
        let count = opened.regions.count
        guard count > 0 else { return }
        let columns = max(1, Int(ceil(sqrt(Double(count)))))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let gap = 0.02
        let width = (1 - gap * Double(columns - 1)) / Double(columns)
        let height = (1 - gap * Double(rows - 1)) / Double(rows)
        applyRegionFrames((0..<count).map { index in
            let column = index % columns
            let row = index / columns
            return OpenNotchRegionFrame(x: Double(column) * (width + gap), y: Double(row) * (height + gap), width: width, height: height)
        })
    }

    private func applyDefaultArrangement(to open: inout OpenNotchLayout) {
        let count = open.regions.count
        guard count > 0 else { return }
        let frames: [OpenNotchRegionFrame]
        if count == 1 {
            frames = [.full]
        } else if count == 2 {
            frames = [OpenNotchRegionFrame(x: 0, y: 0, width: 0.49, height: 1), OpenNotchRegionFrame(x: 0.51, y: 0, width: 0.49, height: 1)]
        } else if count == 3 {
            frames = [OpenNotchRegionFrame(x: 0, y: 0, width: 0.32, height: 1), OpenNotchRegionFrame(x: 0.34, y: 0, width: 0.32, height: 1), OpenNotchRegionFrame(x: 0.68, y: 0, width: 0.32, height: 1)]
        } else {
            let columns = max(1, Int(ceil(sqrt(Double(count)))))
            let rows = max(1, Int(ceil(Double(count) / Double(columns))))
            let gap = 0.02
            let width = (1 - gap * Double(columns - 1)) / Double(columns)
            let height = (1 - gap * Double(rows - 1)) / Double(rows)
            frames = (0..<count).map { index in
                let column = index % columns; let row = index / columns
                return OpenNotchRegionFrame(x: Double(column) * (width + gap), y: Double(row) * (height + gap), width: width, height: height)
            }
        }
        for index in open.regions.indices where index < frames.count { open.regions[index].frame = frames[index] }
    }

    private func mergeRegion(_ sourceID: UUID, into targetID: UUID) {
        guard sourceID != targetID else { return }
        mutateOpen { open in
            open.materializeRegionFrames()
            guard let sourceIndex = open.regions.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = open.regions.firstIndex(where: { $0.id == targetID }) else { return }
            let source = open.regions[sourceIndex]
            let sourceFrame = source.frame ?? .full
            let targetFrame = open.regions[targetIndex].frame ?? .full
            open.regions[targetIndex].groups.append(contentsOf: source.groups)
            open.regions[targetIndex].frame = targetFrame.union(sourceFrame)
            open.regions.remove(at: sourceIndex)
        }
        selectedRegion = targetID; selectedGroup = nil; selectedItem = nil
    }

    private func removeRegion(_ id: UUID) {
        mutateOpen { open in open.regions.removeAll { $0.id == id } }
        if selectedRegion == id { selectedRegion = nil; selectedGroup = nil; selectedItem = nil }
    }

    private func defaultGroupID() -> UUID {
'''
replace_once(widgets, old, new)

old = '''    private func acceptDrop(_ providers: [NSItemProvider], placement: OpenNotchRegionPlacement) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in guard let text = object as? String, let id = UUID(uuidString: text) else { return }; DispatchQueue.main.async { ensureRegion(placement); guard let gid = opened.regions.first(where: { $0.placement == placement })?.groups.first?.id else { return }; move(id, to: gid, before: nil) } }; return true
    }
'''
new = '''    private func acceptDrop(_ providers: [NSItemProvider], placement: OpenNotchRegionPlacement) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in guard let text = object as? String, let id = UUID(uuidString: text) else { return }; DispatchQueue.main.async { ensureRegion(placement); guard let gid = opened.regions.first(where: { $0.placement == placement })?.groups.first?.id else { return }; move(id, to: gid, before: nil) } }; return true
    }
    private func acceptDrop(_ providers: [NSItemProvider], regionID: UUID) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String, let id = UUID(uuidString: text) else { return }
            DispatchQueue.main.async {
                guard let region = opened.regions.first(where: { $0.id == regionID }) else { return }
                if let gid = region.groups.first?.id { move(id, to: gid, before: nil) }
                else { addGroup(regionID: regionID); if let gid = findRegion(regionID)?.groups.first?.id { move(id, to: gid, before: nil) } }
            }
        }
        return true
    }
'''
replace_once(widgets, old, new)

print('Added freeform region frames, add/remove/merge, layout presets, manual geometry, runtime support, and editor preview.')
