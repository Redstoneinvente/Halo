from pathlib import Path
import re

ROOT = Path('.')
def read(p): return (ROOT / p).read_text()
def write(p, s): (ROOT / p).write_text(s)

def replace_once(s, old, new, label):
    if new in s:
        return s
    if old not in s:
        raise SystemExit(f'anchor not found: {label}')
    return s.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Workspace model: keep legacy opened layouts independent and make the custom
# workspace explicitly optional. Add independent custom canvas mode and region
# track/fill sizing without breaking already-saved custom layouts.
# -----------------------------------------------------------------------------
p = 'Halo/Core/WorkspaceModels.swift'
s = read(p)
s = replace_once(s,
'''    var openVerticalPadding: Double?\n    var openFixedColumns: Int?\n    // New opened-notch workspace model. Optional for backwards compatibility.\n    var openNotch: OpenNotchLayout?\n''',
'''    var openVerticalPadding: Double?\n    var openFixedColumns: Int?\n    // The modular workspace is optional. nil preserves behavior for users who\n    // already customized it before this toggle existed; legacy profiles with no\n    // OpenNotchLayout stay on the original Fixed / Scroll / Pages renderer.\n    var useCustomOpenNotchWorkspace: Bool?\n    var openNotch: OpenNotchLayout?\n''', 'workspace toggle property')

s = replace_once(s,
'''    var resolvedOpenFixedColumns: Int {\n        min(4, max(1, openFixedColumns ?? 2))\n    }\n\n    var resolvedOpenNotchLayout: OpenNotchLayout {\n''',
'''    var resolvedOpenFixedColumns: Int {\n        min(4, max(1, openFixedColumns ?? 2))\n    }\n    var resolvedUsesCustomOpenNotchWorkspace: Bool {\n        if let useCustomOpenNotchWorkspace { return useCustomOpenNotchWorkspace }\n        return openNotch != nil\n    }\n\n    var resolvedOpenNotchLayout: OpenNotchLayout {\n''', 'workspace toggle resolver')

s = replace_once(s,
'''    mutating func materializeOpenNotchLayout() {\n        if openNotch == nil || openNotch?.regions.isEmpty == true { openNotch = resolvedOpenNotchLayout }\n    }\n\n    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {\n''',
'''    mutating func materializeOpenNotchLayout() {\n        if openNotch == nil || openNotch?.regions.isEmpty == true { openNotch = resolvedOpenNotchLayout }\n    }\n\n    mutating func setCustomOpenNotchWorkspaceEnabled(_ enabled: Bool) {\n        useCustomOpenNotchWorkspace = enabled\n        if enabled { materializeOpenNotchLayout() }\n    }\n\n    mutating func applyOpenNotchPreset(_ preset: OpenNotchPreset) {\n''', 'workspace toggle mutator')

s = replace_once(s,
'''struct OpenNotchRegion: Codable, Equatable, Identifiable {\n    var id = UUID()\n    var placement: OpenNotchRegionPlacement = .middleCenter\n    var padding = OpenNotchInsets()\n    var groups: [OpenNotchGroup] = []\n    func validated() throws -> OpenNotchRegion {\n        var value = self\n        value.padding = try padding.validated(); value.groups = try groups.prefix(16).map { try $0.validated() }\n        return value\n    }\n}\n''',
'''struct OpenNotchRegion: Codable, Equatable, Identifiable {\n    var id = UUID()\n    var placement: OpenNotchRegionPlacement = .middleCenter\n    var padding = OpenNotchInsets()\n    // Fractions are relative to the region's grid track. Optional keeps layouts\n    // created by the first workspace version fully decodable.\n    var widthFraction: Double?\n    var heightFraction: Double?\n    var groups: [OpenNotchGroup] = []\n    var resolvedWidthFraction: Double { min(1, max(0.15, widthFraction ?? 1)) }\n    var resolvedHeightFraction: Double { min(1, max(0.15, heightFraction ?? 1)) }\n    func validated() throws -> OpenNotchRegion {\n        var value = self\n        if let widthFraction { guard widthFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.widthFraction = min(1, max(0.15, widthFraction)) }\n        if let heightFraction { guard heightFraction.isFinite else { throw CocoaError(.fileReadCorruptFile) }; value.heightFraction = min(1, max(0.15, heightFraction)) }\n        value.padding = try padding.validated(); value.groups = try groups.prefix(16).map { try $0.validated() }\n        return value\n    }\n}\n''', 'region sizing model')

s = replace_once(s,
'''struct OpenNotchLayout: Codable, Equatable {\n    var version = 1\n    var preset: OpenNotchPreset = .custom\n    var regions: [OpenNotchRegion] = []\n    var appearance = OpenNotchAppearance()\n\n    var allItems: [OpenNotchItem] { regions.flatMap(\\.groups).flatMap(\\.items) }\n''',
'''struct OpenNotchLayout: Codable, Equatable {\n    var version = 1\n    var preset: OpenNotchPreset = .custom\n    // Custom-workspace mode is intentionally independent from the legacy\n    // opened-notch Fixed / Scroll / Pages setting.\n    var contentMode: OpenNotchContentMode?\n    var regions: [OpenNotchRegion] = []\n    // Relative track weights for left/center/right and top/middle/bottom.\n    // Optional fields preserve the first custom-workspace archive format.\n    var columnWeights: [Double]?\n    var rowWeights: [Double]?\n    var appearance = OpenNotchAppearance()\n\n    var resolvedContentMode: OpenNotchContentMode { contentMode ?? .fixed }\n    var resolvedColumnWeights: [Double] { Self.resolvedTrackWeights(columnWeights) }\n    var resolvedRowWeights: [Double] { Self.resolvedTrackWeights(rowWeights) }\n    var allItems: [OpenNotchItem] { regions.flatMap(\\.groups).flatMap(\\.items) }\n\n    private static func resolvedTrackWeights(_ saved: [Double]?) -> [Double] {\n        var values = Array((saved ?? []).prefix(3))\n        while values.count < 3 { values.append(1) }\n        return values.map { value in value.isFinite ? min(6, max(0.1, value)) : 1 }\n    }\n    mutating func setColumnWeight(_ value: Double, at index: Int) {\n        guard (0..<3).contains(index) else { return }\n        var values = resolvedColumnWeights; values[index] = min(6, max(0.1, value)); columnWeights = values\n    }\n    mutating func setRowWeight(_ value: Double, at index: Int) {\n        guard (0..<3).contains(index) else { return }\n        var values = resolvedRowWeights; values[index] = min(6, max(0.1, value)); rowWeights = values\n    }\n''', 'layout track model')

s = replace_once(s,
'''    func validated() throws -> OpenNotchLayout {\n        guard version == 1 else { throw CocoaError(.fileReadCorruptFile) }\n        var value = self\n        value.regions = try regions.prefix(9).map { try $0.validated() }\n        value.appearance = try appearance.validated()\n        return value\n    }\n}\n''',
'''    func validated() throws -> OpenNotchLayout {\n        guard version == 1 else { throw CocoaError(.fileReadCorruptFile) }\n        var value = self\n        if let columnWeights { guard columnWeights.allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }; value.columnWeights = Self.resolvedTrackWeights(columnWeights) }\n        if let rowWeights { guard rowWeights.allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }; value.rowWeights = Self.resolvedTrackWeights(rowWeights) }\n        value.regions = try regions.prefix(9).map { try $0.validated() }\n        value.appearance = try appearance.validated()\n        return value\n    }\n}\n''', 'layout track validation')
write(p, s)

# -----------------------------------------------------------------------------
# Runtime: legacy renderer stays intact behind the toggle. Custom workspace uses
# authoritative region bounds and explicit per-item slot allocation.
# -----------------------------------------------------------------------------
p = 'Halo/Views/SurfaceView.swift'
s = read(p)
s = s.replace('if state.expanded && activeContext == nil {\n                OpenNotchBackgroundView', 'if state.expanded && activeContext == nil && layout.resolvedUsesCustomOpenNotchWorkspace {\n                OpenNotchBackgroundView', 1)
s = s.replace('if state.expanded && activeContext == nil {\n            OpenNotchSurfaceChrome', 'if state.expanded && activeContext == nil && layout.resolvedUsesCustomOpenNotchWorkspace {\n            OpenNotchSurfaceChrome', 1)

old = '''    private var openDashboardContent: some View {\n        OpenNotchWorkspaceView(layout: layout, store: store, mode: layout.resolvedOpenNotchContentMode, page: $page)\n    }\n}\n'''
new = '''    private func legacyHorizontalWidget(_ module: ModuleID) -> some View {\n        GeometryReader { proxy in\n            WidgetCard(style: layout.widgetStyle(for: module), availableHeight: proxy.size.height, availableWidth: proxy.size.width) {\n                BuiltinOrIntegrationWidget(module: module, store: store)\n            }\n        }\n    }\n\n    @ViewBuilder private var openDashboardContent: some View {\n        if layout.resolvedUsesCustomOpenNotchWorkspace {\n            OpenNotchWorkspaceView(layout: layout, store: store, mode: layout.resolvedOpenNotchLayout.resolvedContentMode, page: $page)\n        } else {\n            legacyOpenDashboardContent\n        }\n    }\n\n    @ViewBuilder private var legacyOpenDashboardContent: some View {\n        switch layout.resolvedOpenNotchContentMode {\n        case .fixed:\n            GeometryReader { proxy in\n                if modules.isEmpty {\n                    Text("Enable widgets in Settings → Modules.")\n                        .foregroundStyle(.secondary)\n                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)\n                } else {\n                    let columns = max(1, min(layout.resolvedOpenFixedColumns, modules.count))\n                    let rows = max(1, Int(ceil(Double(modules.count) / Double(columns))))\n                    let gap = CGFloat(layout.appearance.spacing)\n                    let cellHeight = max(1, (proxy.size.height - gap * CGFloat(max(0, rows - 1))) / CGFloat(rows))\n                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gap), count: columns), spacing: gap) {\n                        ForEach(modules) { module in legacyHorizontalWidget(module).frame(height: cellHeight) }\n                    }\n                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)\n                }\n            }\n        case .scroll:\n            if layout.horizontalWidgets ?? false {\n                ScrollView(.horizontal) { LazyHStack(alignment: .top, spacing: layout.appearance.spacing) { legacyWidgetCards(horizontal: true) } }\n            } else {\n                ScrollView { LazyVStack(spacing: layout.appearance.spacing) { legacyWidgetCards(horizontal: false) } }\n            }\n        case .pages:\n            VStack(spacing: 8) {\n                if !modules.isEmpty {\n                    let index = min(max(0, page), modules.count - 1)\n                    legacyHorizontalWidget(modules[index])\n                    HStack {\n                        Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0).accessibilityLabel("Previous widget")\n                        Spacer(); Text("\\(modules[index].title) · \\(index + 1) / \\(modules.count)").font(.caption); Spacer()\n                        Button { page = min(modules.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }.disabled(index == modules.count - 1).accessibilityLabel("Next widget")\n                    }\n                } else { Text("Enable widgets in Settings → Modules.").foregroundStyle(.secondary) }\n            }\n        }\n    }\n\n    @ViewBuilder private func legacyWidgetCards(horizontal: Bool) -> some View {\n        ForEach(modules) { module in\n            if horizontal {\n                legacyHorizontalWidget(module).frame(width: max(240, state.dashboardWidth - 64))\n            } else {\n                WidgetCard(style: layout.widgetStyle(for: module)) { BuiltinOrIntegrationWidget(module: module, store: store) }\n            }\n        }\n    }\n}\n'''
if old not in s:
    raise SystemExit('openDashboardContent anchor not found')
s = s.replace(old, new, 1)

start = s.index('private struct OpenNotchWorkspaceView: View {')
end = s.index('\nprivate struct OpenNotchLightweightElement:', start)
responsive = r'''private struct OpenNotchWorkspaceView: View {
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    let mode: OpenNotchContentMode
    @Binding var page: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var opened: OpenNotchLayout { layout.resolvedOpenNotchLayout }
    private var regions: [OpenNotchRegion] { opened.regions.sorted { $0.placement.sortIndex < $1.placement.sortIndex } }
    private var groups: [OpenNotchGroup] { regions.flatMap(\.groups) }
    private var gap: CGFloat { max(4, CGFloat(layout.appearance.spacing)) }

    var body: some View {
        Group {
            switch mode {
            case .fixed: fixedCanvas
            case .scroll: scrollCanvas
            case .pages: pagesCanvas
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: opened)
        .clipped()
    }

    private var fixedCanvas: some View {
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

    private func regionRow(_ placements: [OpenNotchRegionPlacement], height: CGFloat) -> some View {
        GeometryReader { proxy in
            let widths = trackSizes(total: proxy.size.width, weights: effectiveColumnWeights, gaps: 2)
            HStack(spacing: gap) {
                ForEach(0..<3, id: \.self) { index in
                    let placement = placements[index]
                    let cellWidth = widths[index]
                    ZStack(alignment: placement.regionAlignment) {
                        if let value = region(placement) {
                            OpenNotchRegionView(region: value, layout: layout, store: store)
                                .frame(width: max(1, cellWidth * CGFloat(value.resolvedWidthFraction)),
                                       height: max(1, height * CGFloat(value.resolvedHeightFraction)),
                                       alignment: placement.regionAlignment)
                                .clipped()
                        }
                    }
                    .frame(width: cellWidth, height: max(0, height), alignment: placement.regionAlignment)
                    .clipped()
                }
            }
        }
        .frame(height: max(0, height))
    }

    private var scrollCanvas: some View {
        Group {
            if layout.horizontalWidgets ?? false {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: layout.appearance.spacing) {
                        ForEach(groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store).frame(minWidth: 220) }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: layout.appearance.spacing) {
                        ForEach(groups) { group in OpenNotchGroupView(group: group, layout: layout, store: store) }
                    }
                }
            }
        }
    }

    private var pagesCanvas: some View {
        VStack(spacing: 8) {
            if groups.isEmpty {
                Text("Enable widgets or add opened-notch elements in Settings.").foregroundStyle(.secondary)
            } else {
                let index = min(max(0, page), groups.count - 1)
                OpenNotchGroupView(group: groups[index], layout: layout, store: store, constrained: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Button { page = max(0, index - 1) } label: { Image(systemName: "chevron.left") }.disabled(index == 0)
                    Spacer(); Text("\(groups[index].name) · \(index + 1) / \(groups.count)").font(.caption); Spacer()
                    Button { page = min(groups.count - 1, index + 1) } label: { Image(systemName: "chevron.right") }.disabled(index == groups.count - 1)
                }
            }
        }
    }

    private var effectiveRowWeights: [Double] {
        let occupied = [0, 1, 2].map { row in regions.contains { $0.placement.rowIndex == row } }
        return zip(opened.resolvedRowWeights, occupied).map { $1 ? $0 : 0 }
    }
    private var effectiveColumnWeights: [Double] {
        let occupied = [0, 1, 2].map { column in regions.contains { $0.placement.columnIndex == column } }
        return zip(opened.resolvedColumnWeights, occupied).map { $1 ? $0 : 0 }
    }
    private func trackSizes(total: CGFloat, weights: [Double], gaps: Int) -> [CGFloat] {
        let usable = max(0, total - gap * CGFloat(gaps))
        let positive = weights.map { max(0, $0) }
        let sum = positive.reduce(0, +)
        guard sum > 0 else { return [usable / 3, usable / 3, usable / 3] }
        return positive.map { usable * CGFloat($0 / sum) }
    }
    private func region(_ placement: OpenNotchRegionPlacement) -> OpenNotchRegion? { regions.first { $0.placement == placement } }
}

private struct OpenNotchRegionView: View {
    let region: OpenNotchRegion
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    var body: some View {
        GeometryReader { proxy in
            let groupGap = max(4, CGFloat(layout.appearance.spacing))
            let innerWidth = max(0, proxy.size.width - CGFloat(region.padding.leading + region.padding.trailing))
            let innerHeight = max(0, proxy.size.height - CGFloat(region.padding.top + region.padding.bottom))
            let count = max(1, region.groups.count)
            let groupHeight = max(0, (innerHeight - groupGap * CGFloat(max(0, count - 1))) / CGFloat(count))
            VStack(spacing: groupGap) {
                ForEach(region.groups) { group in
                    OpenNotchGroupView(group: group, layout: layout, store: store, constrained: true)
                        .frame(width: innerWidth, height: groupHeight)
                        .clipped()
                }
            }
            .padding(.top, region.padding.top).padding(.leading, region.padding.leading)
            .padding(.bottom, region.padding.bottom).padding(.trailing, region.padding.trailing)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: region.placement.regionAlignment)
        }
        .clipped()
    }
}

private struct OpenNotchGroupView: View {
    let group: OpenNotchGroup
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    var constrained = false
    private var context: OpenNotchRuntimeContext { OpenNotchRuntimeContext(store: store) }

    var body: some View {
        GeometryReader { proxy in
            let innerWidth = max(0, proxy.size.width - CGFloat(group.padding.leading + group.padding.trailing))
            let innerHeight = max(0, proxy.size.height - CGFloat(group.padding.top + group.padding.bottom))
            let candidates = group.items.filter(context.isVisible)
            let mainAvailable = group.axis == .horizontal ? innerWidth : innerHeight
            let wanted = preferredLength(of: candidates) + max(0, CGFloat(candidates.count - 1)) * CGFloat(group.spacing)
            let compression = compressionLevel(available: mainAvailable, wanted: wanted)
            let spacing = max(2, CGFloat(group.spacing) * (compression >= 1 ? 0.62 : 1))
            let visible = candidates.filter { $0.priority.remainsVisible(at: compression) }
            let crossAvailable = group.axis == .horizontal ? innerHeight : innerWidth
            let lengths = allocatedLengths(items: visible, available: mainAvailable, spacing: spacing, compression: compression)
            let minimumNeeded = minimumLength(of: visible) + max(0, CGFloat(visible.count - 1)) * spacing

            Group {
                if compression >= 5 && minimumNeeded > mainAvailable + 1 {
                    ScrollView(group.axis == .horizontal ? .horizontal : .vertical) {
                        stack(items: visible, spacing: spacing, compression: compression, crossAvailable: crossAvailable, lengths: lengths)
                    }
                } else {
                    stack(items: visible, spacing: spacing, compression: compression, crossAvailable: crossAvailable, lengths: lengths)
                }
            }
            .frame(width: innerWidth, height: innerHeight, alignment: group.alignment.horizontalFrameAlignment)
            .padding(.top, group.padding.top).padding(.leading, group.padding.leading)
            .padding(.bottom, group.padding.bottom).padding(.trailing, group.padding.trailing)
        }
        .frame(minHeight: constrained ? 0 : estimatedHeight, maxHeight: constrained ? .infinity : nil)
        .clipped()
    }

    @ViewBuilder private func stack(items: [OpenNotchItem], spacing: CGFloat, compression: Int,
                                    crossAvailable: CGFloat, lengths: [UUID: CGFloat]) -> some View {
        if group.axis == .horizontal {
            HStack(alignment: group.alignment.verticalAlignment, spacing: spacing) {
                ForEach(items) { item in
                    let size = CGSize(width: max(1, lengths[item.id] ?? CGFloat(item.sizing.minimumWidth)), height: max(1, crossAvailable))
                    OpenNotchItemView(item: item, layout: layout, store: store, compression: compression, slotSize: size)
                }
            }.frame(maxHeight: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        } else {
            VStack(alignment: group.alignment.horizontalAlignment, spacing: spacing) {
                ForEach(items) { item in
                    let size = CGSize(width: max(1, crossAvailable), height: max(1, lengths[item.id] ?? CGFloat(item.sizing.minimumHeight)))
                    OpenNotchItemView(item: item, layout: layout, store: store, compression: compression, slotSize: size)
                }
            }.frame(maxWidth: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        }
    }

    private func preferredLength(of items: [OpenNotchItem]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + CGFloat(group.axis == .horizontal ? item.sizing.preferredWidth : item.sizing.preferredHeight)
        }
    }
    private func minimumLength(of items: [OpenNotchItem]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + CGFloat(group.axis == .horizontal ? item.sizing.minimumWidth : item.sizing.minimumHeight)
        }
    }
    private func bounds(for item: OpenNotchItem) -> (min: CGFloat, preferred: CGFloat, max: CGFloat) {
        if group.axis == .horizontal {
            return (CGFloat(item.sizing.minimumWidth), CGFloat(item.sizing.preferredWidth), CGFloat(item.sizing.maximumWidth))
        }
        return (CGFloat(item.sizing.minimumHeight), CGFloat(item.sizing.preferredHeight), CGFloat(item.sizing.maximumHeight))
    }
    private func allocatedLengths(items: [OpenNotchItem], available: CGFloat, spacing: CGFloat, compression: Int) -> [UUID: CGFloat] {
        guard !items.isEmpty else { return [:] }
        let usable = max(0, available - spacing * CGFloat(max(0, items.count - 1)))
        var values: [UUID: CGFloat] = [:]
        for item in items {
            let b = bounds(for: item)
            let start: CGFloat
            switch item.sizing.mode {
            case .fill: start = b.min
            case .fixed, .fitContent, .flexible: start = min(b.max, max(b.min, b.preferred))
            }
            values[item.id] = start
        }

        var total = values.values.reduce(0, +)
        if total > usable {
            var deficit = total - usable
            for _ in 0..<3 where deficit > 0.5 {
                let shrinkable = items.filter { (values[$0.id] ?? 0) > bounds(for: $0).min + 0.5 }
                guard !shrinkable.isEmpty else { break }
                let capacity = shrinkable.reduce(CGFloat(0)) { $0 + max(0, (values[$1.id] ?? 0) - bounds(for: $1).min) }
                guard capacity > 0 else { break }
                for item in shrinkable {
                    let current = values[item.id] ?? 0
                    let minValue = bounds(for: item).min
                    let share = (current - minValue) / capacity
                    let cut = min(current - minValue, deficit * share)
                    values[item.id] = current - cut
                }
                total = values.values.reduce(0, +); deficit = max(0, total - usable)
            }
            // Before the final scroll stage, the slot remains authoritative even
            // if a user's minimum sizes cannot all fit. This prevents overlap.
            if deficit > 0.5 && compression < 5 && total > 0 {
                let scale = max(0.1, usable / total)
                for item in items { values[item.id] = max(1, (values[item.id] ?? 1) * scale) }
            }
        } else if total < usable {
            var extra = usable - total
            let growers = items.filter { $0.sizing.mode == .fill || $0.sizing.mode == .flexible }
            for _ in 0..<3 where extra > 0.5 && !growers.isEmpty {
                let active = growers.filter { (values[$0.id] ?? 0) < bounds(for: $0).max - 0.5 }
                guard !active.isEmpty else { break }
                let weightTotal = active.reduce(CGFloat(0)) { $0 + ($1.sizing.mode == .fill ? 2 : 1) }
                for item in active {
                    let current = values[item.id] ?? 0
                    let maxValue = bounds(for: item).max
                    let weight: CGFloat = item.sizing.mode == .fill ? 2 : 1
                    let add = min(maxValue - current, extra * weight / weightTotal)
                    values[item.id] = current + add
                }
                total = values.values.reduce(0, +); extra = max(0, usable - total)
            }
        }
        return values
    }
    private var estimatedHeight: CGFloat {
        let h = group.items.reduce(0.0) { $0 + min($1.sizing.preferredHeight, 260) } + max(0, Double(group.items.count - 1)) * group.spacing
        return CGFloat(min(720, max(54, h + group.padding.top + group.padding.bottom)))
    }
    private func compressionLevel(available: CGFloat, wanted: CGFloat) -> Int {
        guard wanted > 0, available > 0 else { return 0 }
        let ratio = available / wanted
        if ratio >= 1 { return 0 }
        if ratio >= 0.86 { return 1 }
        if ratio >= 0.72 { return 2 }
        if ratio >= 0.58 { return 3 }
        if ratio >= 0.44 { return 4 }
        return 5
    }
}

private struct OpenNotchItemView: View {
    let item: OpenNotchItem
    let layout: WorkspaceLayout
    @ObservedObject var store: AppStore
    let compression: Int
    let slotSize: CGSize
    @State private var hover = false

    var body: some View {
        let presentation = resolvedPresentation
        let style = adaptedWidgetStyle(presentation: presentation)
        let itemStyle = item.style ?? WidgetElementStyle()
        Group {
            switch item.kind {
            case .module:
                if let module = item.module, layout.enabled.contains(module) {
                    WidgetCard(style: style, availableHeight: slotSize.height, availableWidth: slotSize.width) {
                        BuiltinOrIntegrationWidget(module: module, store: store)
                    }
                    .environment(\.openNotchPresentation, presentation)
                    .environment(\.openNotchCompressionLevel, compression)
                    .environment(\.openNotchAvailableWidth, slotSize.width)
                    .environment(\.openNotchAvailableHeight, slotSize.height)
                }
            case .element:
                if let element = item.element {
                    WidgetElementSurface(element: itemStyle, widgetStyle: style, defaultPriority: item.priority) {
                        OpenNotchLightweightElement(kind: element, item: item, store: store)
                    }
                    .environment(\.openNotchPresentation, presentation)
                    .environment(\.openNotchCompressionLevel, compression)
                    .environment(\.openNotchAvailableWidth, slotSize.width)
                    .environment(\.openNotchAvailableHeight, slotSize.height)
                }
            case .spacer:
                Color.clear
            case .divider:
                Divider().opacity(itemStyle.opacity)
            }
        }
        .frame(width: slotSize.width, height: slotSize.height, alignment: itemStyle.alignment?.alignment ?? .center)
        .clipped()
        .contentShape(Rectangle())
        .opacity(hover ? 1 : 0.985)
        .onHover { hover = $0 }
        .modifier(OpenNotchInteractionModifier(item: item, store: store))
        .transition(.opacity.combined(with: .scale(scale: 0.975)))
    }

    private var resolvedPresentation: OpenNotchPresentation {
        let hardCompact = slotSize.width < 175 || slotSize.height < 72
        let compact = slotSize.width < 250 || slotSize.height < 118 || compression >= 3
        let expandedPossible = slotSize.width >= 360 && slotSize.height >= 210 && compression < 2
        if hardCompact { return .compact }
        switch item.presentation {
        case .automatic:
            if compact { return .compact }
            return expandedPossible ? .expanded : .regular
        case .expanded:
            if compact { return .compact }
            return expandedPossible ? .expanded : .regular
        case .regular:
            return compact ? .compact : .regular
        case .compact:
            return .compact
        }
    }
    private func adaptedWidgetStyle(presentation: OpenNotchPresentation) -> WidgetStyle {
        guard let module = item.module else { return WidgetStyle() }
        var style = layout.widgetStyle(for: module)
        // The designed slot owns geometry in the custom workspace. A legacy
        // per-widget width must never push a card outside its region.
        style.width = 0
        style.minimumHeight = 0
        switch presentation {
        case .compact: style.layoutMode = .compact
        case .expanded: style.layoutMode = .hero
        case .regular, .automatic: style.layoutMode = .standard
        }
        let widthScale = min(1, max(0.68, slotSize.width / 300))
        let heightScale = min(1, max(0.68, slotSize.height / 170))
        let scale = min(widthScale, heightScale)
        style.padding *= scale
        style.fontSize *= max(0.76, scale)
        var content = style.resolvedContent
        content.spacing *= scale
        content.iconSize *= scale
        if compression >= 2 || slotSize.height < 130 || slotSize.width < 230 {
            content.showSecondaryText = false
            content.mediaShowArtist = slotSize.height >= 92 && slotSize.width >= 185
            content.mediaShowSource = false
            content.calendarShowTimes = false
            content.shelfShowDetails = false
            content.activitiesShowDetail = false
        }
        if compression >= 3 || slotSize.height < 105 {
            content.maxItems = min(2, content.maxItems)
            content.showFooter = false
            content.showQuickActions = false
        } else if slotSize.height < 180 {
            content.maxItems = min(3, content.maxItems)
        }
        if compression >= 4 || slotSize.width < 190 {
            content.mediaTitleLines = 1
            content.maxItems = min(1, content.maxItems)
        }
        style.content = content
        return style
    }
}
'''
s = s[:start] + responsive + s[end:]

# Placement helpers used by the responsive grid and editor.
s = s.replace('''private extension OpenNotchRegionPlacement {\n    var sortIndex: Int { OpenNotchRegionPlacement.allCases.firstIndex(of: self) ?? 0 }\n    var regionAlignment: Alignment {\n''', '''private extension OpenNotchRegionPlacement {\n    var sortIndex: Int { OpenNotchRegionPlacement.allCases.firstIndex(of: self) ?? 0 }\n    var rowIndex: Int {\n        switch self { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 1; case .bottomLeft, .bottomCenter, .bottomRight: return 2 }\n    }\n    var columnIndex: Int {\n        switch self { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 1; case .topRight, .middleRight, .bottomRight: return 2 }\n    }\n    var regionAlignment: Alignment {\n''', 1)

# Built-in timer/shelf participate in presentation fitting too.
s = s.replace('''struct BuiltinOrIntegrationWidget: View {\n    let module: ModuleID\n    @ObservedObject var store: AppStore\n    @Environment(\\.widgetStyle) private var style\n''', '''struct BuiltinOrIntegrationWidget: View {\n    let module: ModuleID\n    @ObservedObject var store: AppStore\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n    @Environment(\\.openNotchCompressionLevel) private var compression\n''', 1)
s = s.replace('''            WidgetElement(key: "progress") { ProgressView(value: progress) }\n            WidgetElement(key: "endTime", defaultVisible: false) {\n''', '''            if presentation != .compact { WidgetElement(key: "progress", defaultPriority: .normal) { ProgressView(value: progress) } }\n            WidgetElement(key: "endTime", defaultVisible: false, defaultPriority: .low) {\n''', 1)
s = s.replace('''            if options.showSecondaryText {\n                WidgetElement(key: "status") {\n''', '''            if options.showSecondaryText && presentation == .expanded && compression < 2 {\n                WidgetElement(key: "status", defaultPriority: .low) {\n''', 1)
s = s.replace('''                        ForEach(Array(store.files.prefix(options.maxItems)), id: \\.self) { url in\n''', '''                        ForEach(Array(store.files.prefix(presentation == .compact ? 1 : presentation == .expanded ? options.maxItems : min(3, options.maxItems))), id: \\.self) { url in\n''', 1)
s = s.replace('''                                ShelfFileInfo(url: url, iconSize: options.shelfIconSize, showDetail: options.shelfShowDetails)\n''', '''                                ShelfFileInfo(url: url, iconSize: options.shelfIconSize, showDetail: options.shelfShowDetails && presentation != .compact && compression < 2)\n''', 1)
write(p, s)

# -----------------------------------------------------------------------------
# Widget styling itself reacts to the real slot, not only the requested style.
# -----------------------------------------------------------------------------
p = 'Halo/Views/WidgetViews.swift'
s = read(p)
s = replace_once(s,
'''private struct OpenNotchPresentationEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchPresentation = .regular }\nprivate struct OpenNotchCompressionEnvironmentKey: EnvironmentKey { static let defaultValue = 0 }\nextension EnvironmentValues {\n''',
'''private struct OpenNotchPresentationEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchPresentation = .regular }\nprivate struct OpenNotchCompressionEnvironmentKey: EnvironmentKey { static let defaultValue = 0 }\nprivate struct OpenNotchAvailableWidthEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }\nprivate struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }\nextension EnvironmentValues {\n''', 'slot environment keys')
s = replace_once(s,
'''    var openNotchCompressionLevel: Int {\n        get { self[OpenNotchCompressionEnvironmentKey.self] }\n        set { self[OpenNotchCompressionEnvironmentKey.self] = newValue }\n    }\n}\n''',
'''    var openNotchCompressionLevel: Int {\n        get { self[OpenNotchCompressionEnvironmentKey.self] }\n        set { self[OpenNotchCompressionEnvironmentKey.self] = newValue }\n    }\n    var openNotchAvailableWidth: CGFloat? {\n        get { self[OpenNotchAvailableWidthEnvironmentKey.self] }\n        set { self[OpenNotchAvailableWidthEnvironmentKey.self] = newValue }\n    }\n    var openNotchAvailableHeight: CGFloat? {\n        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }\n        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }\n    }\n}\n''', 'slot environment values')

s = replace_once(s,
'''    @Environment(\\.openNotchCompressionLevel) private var compression\n\n    private var priority: OpenNotchPriority { element.priority ?? defaultPriority }\n''',
'''    @Environment(\\.openNotchCompressionLevel) private var compression\n    @Environment(\\.openNotchAvailableWidth) private var availableWidth\n    @Environment(\\.openNotchAvailableHeight) private var availableHeight\n\n    private var adaptiveScale: Double {\n        let widthScale = availableWidth.map { min(1, max(0.68, Double($0) / 220)) } ?? 1\n        let heightScale = availableHeight.map { min(1, max(0.68, Double($0) / 110)) } ?? 1\n        return min(widthScale, heightScale)\n    }\n    private var priority: OpenNotchPriority { element.priority ?? defaultPriority }\n''', 'element adaptive scale')
s = s.replace('''        let size = element.fontSize ?? (widgetStyle.fontSize * element.fontScale)\n''', '''        let size = (element.fontSize ?? (widgetStyle.fontSize * element.fontScale)) * adaptiveScale\n''', 1)
s = s.replace('''                .padding(element.padding)\n''', '''                .padding(element.padding * adaptiveScale)\n''', 1)
s = s.replace('''                .padding(.vertical, (element.externalSpacing ?? 0) * 0.5)\n''', '''                .padding(.vertical, (element.externalSpacing ?? 0) * adaptiveScale * 0.5)\n''', 1)

s = replace_once(s,
'''struct WidgetCard<Content: View>: View {\n    let style: WidgetStyle\n    var availableHeight: CGFloat? = nil\n    @ViewBuilder var content: Content\n''',
'''struct WidgetCard<Content: View>: View {\n    let style: WidgetStyle\n    var availableHeight: CGFloat? = nil\n    var availableWidth: CGFloat? = nil\n    @ViewBuilder var content: Content\n    @Environment(\\.openNotchCompressionLevel) private var compression\n''', 'widget card slot width')
s = s.replace('''        guard let height = availableHeight else { return fitted }\n        fitted.padding = min(fitted.padding, max(0, height * 0.08))\n        fitted.minimumHeight = 0\n        fitted.fontSize = min(fitted.fontSize, max(10, height * 0.18))\n        return fitted\n''', '''        if let width = availableWidth {\n            fitted.padding = min(fitted.padding, max(3, width * 0.055))\n            fitted.fontSize = min(fitted.fontSize, max(9, width * 0.11))\n        }\n        if let height = availableHeight {\n            fitted.padding = min(fitted.padding, max(2, height * 0.08))\n            fitted.minimumHeight = 0\n            fitted.fontSize = min(fitted.fontSize, max(9, height * 0.18))\n        }\n        return fitted\n''', 1)
s = s.replace('''        content.environment(\\.widgetStyle, fittedStyle).font(fittedStyle.font())\n            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)\n''', '''        content.environment(\\.widgetStyle, fittedStyle)\n            .environment(\\.openNotchAvailableWidth, availableWidth)\n            .environment(\\.openNotchAvailableHeight, availableHeight)\n            .font(fittedStyle.font())\n            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)\n''', 1)
old_body = '''            if let height = availableHeight {\n                let padding = fittedStyle.padding\n                // Keep the card within the viewport; only overflowing contents scroll.\n                ScrollView(.vertical) {\n                    styledContent\n                        .frame(maxWidth: .infinity, minHeight: max(0, height - 2 * padding), alignment: contentOptions.alignment == .center ? .top : (contentOptions.alignment == .trailing ? .topTrailing : .topLeading))\n                }\n                .padding(padding)\n                .frame(height: max(0, height))\n                .clipped()\n            } else {\n'''
new_body = '''            if let height = availableHeight {\n                let padding = fittedStyle.padding\n                if compression >= 5 {\n                    ScrollView(.vertical) {\n                        styledContent.frame(maxWidth: .infinity, alignment: contentOptions.alignment.alignment)\n                    }\n                    .padding(padding).frame(height: max(0, height)).clipped()\n                } else {\n                    styledContent\n                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentOptions.alignment.alignment)\n                        .padding(padding)\n                        .frame(height: max(0, height))\n                        .clipped()\n                }\n            } else {\n'''
s = replace_once(s, old_body, new_body, 'widget card scroll behavior')
s = s.replace('''        .frame(maxWidth: style.width > 0 ? style.width : .infinity)\n''', '''        .frame(width: availableWidth)\n        .frame(maxWidth: style.width > 0 ? style.width : .infinity)\n''', 1)
write(p, s)

# -----------------------------------------------------------------------------
# Remaining major integration modules use presentation variants under pressure.
# -----------------------------------------------------------------------------
p = 'Halo/Views/ModuleViews.swift'
s = read(p)
s = replace_once(s,
'''struct IntegrationModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n''',
'''struct IntegrationModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n''', 'integration presentation environment')
s = s.replace('''        case .activities:\n            WidgetElement(key: "summary") {\n''', '''        case .activities:\n            WidgetElement(key: "summary", defaultPriority: .high) {\n''', 1)
s = s.replace('''            if workspace.activities.isEmpty, options.showStatus {\n''', '''            if workspace.activities.isEmpty, options.showStatus, presentation != .compact {\n''', 1)
s = s.replace('''            WidgetElement(key: "items") {\n                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {\n                    ForEach(Array(workspace.activities.prefix(options.maxItems))) { activity in\n''', '''            if presentation != .compact { WidgetElement(key: "items") {\n                VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {\n                    ForEach(Array(workspace.activities.prefix(presentation == .expanded ? options.maxItems : min(3, options.maxItems)))) { activity in\n''', 1)
s = s.replace('''                                if options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }\n''', '''                                if presentation == .expanded && options.activitiesShowDetail && !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }\n''', 1)
s = s.replace('''                }\n            }\n        case .notes:\n''', '''                }\n            } }\n        case .notes:\n''', 1)
s = s.replace('''        case .notes:\n            WidgetElement(key: "stats") {\n''', '''        case .notes:\n            if presentation != .compact { WidgetElement(key: "stats", defaultPriority: .low) {\n''', 1)
s = s.replace('''                HStack { Label("\\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\\(workspace.settings.notes.count) chars") }\n            }\n            WidgetElement(key: "editor") {\n                TextEditor(text: $workspace.settings.notes).frame(height: options.notesHeight).accessibilityLabel("Quick note")\n            }\n''', '''                HStack { Label("\\(words) words", systemImage: "text.word.spacing"); Spacer(); Text("\\(workspace.settings.notes.count) chars") }\n            } }\n            WidgetElement(key: "editor", defaultPriority: .high) {\n                TextEditor(text: $workspace.settings.notes)\n                    .frame(height: presentation == .compact ? min(52, options.notesHeight) : presentation == .expanded ? max(140, options.notesHeight) : options.notesHeight)\n                    .accessibilityLabel("Quick note")\n            }\n''', 1)
s = s.replace('''            WidgetElement(key: "actions", defaultVisible: false) {\n''', '''            if presentation == .expanded { WidgetElement(key: "actions", defaultVisible: false, defaultPriority: .low) {\n''', 1)
s = s.replace('''                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)\n                }\n            }\n        case .capture:\n''', '''                    Button("Clear") { workspace.settings.notes = "" }.disabled(workspace.settings.notes.isEmpty)\n                }\n            } }\n        case .capture:\n''', 1)
s = s.replace('''        case .stopwatch:\n            WidgetElement(key: "state") {\n''', '''        case .stopwatch:\n            if presentation != .compact { WidgetElement(key: "state", defaultPriority: .low) {\n''', 1)
s = s.replace('''                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")\n            }\n            WidgetElement(key: "time") {\n''', '''                      systemImage: workspace.stopwatchStart == nil ? "pause.circle" : "play.circle.fill")\n            } }\n            WidgetElement(key: "time", defaultPriority: .alwaysVisible) {\n''', 1)
s = s.replace('''            if options.showControls {\n                WidgetElement(key: "controls") {\n''', '''            if options.showControls {\n                WidgetElement(key: "controls", defaultPriority: .high) {\n''', 1)
# Audio compacts to the essential level/volume controls.
s = s.replace('''struct AudioModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n''', '''struct AudioModuleView: View {\n    @Environment(\\.widgetStyle) private var style\n    @Environment(\\.openNotchPresentation) private var presentation\n''', 1)
s = s.replace('''            WidgetElement(key: "output") {\n                Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {\n                    ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }\n                }\n            }\n''', '''            if presentation != .compact { WidgetElement(key: "output") {\n                Picker("Output", selection: Binding(get: { service.selected }, set: { service.setOutput($0) })) {\n                    ForEach(service.devices.prefix(options.maxItems)) { Text($0.name).tag($0.id) }\n                }\n            } }\n''', 1)
s = s.replace('''                WidgetElement(key: "volumeValue") { Text("Volume \\(Int(service.volume * 100))%").monospacedDigit() }\n''', '''                if presentation != .compact { WidgetElement(key: "volumeValue", defaultPriority: .low) { Text("Volume \\(Int(service.volume * 100))%").monospacedDigit() } }\n''', 1)
s = s.replace('''            if options.showQuickActions { WidgetElement(key: "actions") { Button("Refresh devices") { service.refresh() } } }\n''', '''            if options.showQuickActions && presentation == .expanded { WidgetElement(key: "actions", defaultPriority: .low) { Button("Refresh devices") { service.refresh() } } }\n''', 1)
write(p, s)

# -----------------------------------------------------------------------------
# Editor: explicit enable toggle, independent custom mode, real region track/fill
# controls, and an unmistakable close control.
# -----------------------------------------------------------------------------
p = 'Halo/Views/WidgetSettingsView.swift'
s = read(p)
old = '''        Section("Opened notch workspace") {\n            Button { showingOpenWorkspaceEditor = true } label: { Label("Open Visual Workspace Editor…", systemImage: "rectangle.3.group") }\n            Text("Arrange regions, groups, modules and lightweight elements visually. Widget styling below remains available for deep per-module tuning.")\n                .font(.caption).foregroundStyle(.secondary)\n        }\n'''
new = '''        Section("Opened notch workspace") {\n            Toggle("Use Custom Workspace Layout", isOn: Binding(\n                get: { layout.resolvedUsesCustomOpenNotchWorkspace },\n                set: { layout.setCustomOpenNotchWorkspaceEnabled($0) }\n            ))\n            Button { showingOpenWorkspaceEditor = true } label: { Label("Open Visual Workspace Editor…", systemImage: "rectangle.3.group") }\n            Text(layout.resolvedUsesCustomOpenNotchWorkspace\n                 ? "Custom Workspace is active. Turning it off instantly restores your original Fixed / Scroll / Pages layout without deleting the custom design."\n                 : "Your original opened-notch layout is active. You can design a Custom Workspace without replacing or modifying that layout until you enable it.")\n                .font(.caption).foregroundStyle(.secondary)\n        }\n'''
s = replace_once(s, old, new, 'editor toggle section')

# Custom mode picker is independent from the legacy mode.
s = s.replace('''            Picker("Layout", selection: Binding(get: { layout.resolvedOpenNotchContentMode }, set: { layout.openNotchContentMode = $0 })) {\n                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }\n            }.frame(width: 250)\n''', '''            Picker("Workspace", selection: Binding(\n                get: { opened.resolvedContentMode },\n                set: { mode in var value = opened; value.contentMode = mode; layout.openNotch = value }\n            )) {\n                ForEach(OpenNotchContentMode.allCases) { Text($0.rawValue).tag($0) }\n            }.frame(width: 250)\n''', 1)
# Explicit close icon + text button.
s = s.replace('''            Spacer()\n            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)\n''', '''            Spacer()\n            Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3) }.buttonStyle(.plain).help("Close editor")\n            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)\n''', 1)

# Replace the preview grid with a track-aware structural canvas.
preview_start = s.index('    private var preview: some View {')
preview_end = s.index('\n    private func groupPreview(', preview_start)
preview = r'''    private var preview: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { Text("Opened Notch").font(.headline); Text(opened.preset.rawValue).font(.caption).foregroundStyle(.secondary) }
                Spacer(); Text("Drag items between regions · drag corner to resize").font(.caption).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .overlay {
                    GeometryReader { proxy in
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
                }
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
                .frame(width: 610, height: 470)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.84), value: opened)
        }
    }

    private var editorRowWeights: [Double] {
        let occupied = [0, 1, 2].map { row in opened.regions.contains { $0.placement.rowIndex == row } }
        return zip(opened.resolvedRowWeights, occupied).map { $1 ? $0 : 0 }
    }
    private var editorColumnWeights: [Double] {
        let occupied = [0, 1, 2].map { column in opened.regions.contains { $0.placement.columnIndex == column } }
        return zip(opened.resolvedColumnWeights, occupied).map { $1 ? $0 : 0 }
    }
    private func editorTrackSizes(total: CGFloat, weights: [Double], gap: CGFloat) -> [CGFloat] {
        let usable = max(0, total - gap * 2)
        let positive = weights.map { max(0, $0) }
        let sum = positive.reduce(0, +)
        guard sum > 0 else { return [usable / 3, usable / 3, usable / 3] }
        return positive.map { usable * CGFloat($0 / sum) }
    }

    private func editorRow(_ placements: [OpenNotchRegionPlacement], height: CGFloat, totalWidth: CGFloat) -> some View {
        let widths = editorTrackSizes(total: totalWidth, weights: editorColumnWeights, gap: 8)
        return HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                regionCell(placements[index], cellSize: CGSize(width: widths[index], height: height))
                    .frame(width: widths[index], height: max(0, height))
            }
        }
        .frame(width: totalWidth, height: max(0, height))
    }

    private func regionCell(_ placement: OpenNotchRegionPlacement, cellSize: CGSize) -> some View {
        let region = opened.regions.first { $0.placement == placement }
        return ZStack(alignment: placement.regionAlignment) {
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
        .frame(width: cellSize.width, height: cellSize.height, alignment: placement.regionAlignment)
        .clipped()
    }
'''
s = s[:preview_start] + preview + s[preview_end:]

# Region controls: fill within slot + row/column track weights.
old = '''        Section("Region") { Picker("Placement", selection: b.placement) { ForEach(OpenNotchRegionPlacement.allCases) { Text($0.title).tag($0) } } }\n        Section("Region padding") { insetsEditor(b.padding) }\n        Section { Button("Add Group") { addGroup(regionID: region.id) } }\n'''
new = '''        Section("Region") { Picker("Placement", selection: b.placement) { ForEach(OpenNotchRegionPlacement.allCases) { Text($0.title).tag($0) } } }\n        Section("Region size") {\n            PreciseSlider(title: "Width in column", value: Binding(\n                get: { b.wrappedValue.resolvedWidthFraction * 100 },\n                set: { b.wrappedValue.widthFraction = $0 / 100 }\n            ), range: 15...100, step: 1, suffix: "%")\n            PreciseSlider(title: "Height in row", value: Binding(\n                get: { b.wrappedValue.resolvedHeightFraction * 100 },\n                set: { b.wrappedValue.heightFraction = $0 / 100 }\n            ), range: 15...100, step: 1, suffix: "%")\n            PreciseSlider(title: "Column width share", value: columnWeightBinding(for: b.wrappedValue.placement), range: 0.1...6, step: 0.1, suffix: "×", decimals: 1)\n            PreciseSlider(title: "Row height share", value: rowWeightBinding(for: b.wrappedValue.placement), range: 0.1...6, step: 0.1, suffix: "×", decimals: 1)\n            Button("Reset Region Size") { b.wrappedValue.widthFraction = nil; b.wrappedValue.heightFraction = nil; resetTrackWeights(for: b.wrappedValue.placement) }\n            Text("Track shares control the relative size of this row/column. Width and height percentages control how much of that designed slot this region occupies.").font(.caption).foregroundStyle(.secondary)\n        }\n        Section("Region padding") { insetsEditor(b.padding) }\n        Section { Button("Add Group") { addGroup(regionID: region.id) } }\n'''
s = replace_once(s, old, new, 'region inspector sizing')

# Insert track binding helpers immediately before the existing insets editor helper.
anchor = '    @ViewBuilder private func insetsEditor(_ b: Binding<OpenNotchInsets>) -> some View {'
helpers = r'''    private func columnWeightBinding(for placement: OpenNotchRegionPlacement) -> Binding<Double> {
        Binding(get: { opened.resolvedColumnWeights[placement.columnIndex] }, set: { value in
            var next = opened; next.setColumnWeight(value, at: placement.columnIndex); layout.openNotch = next
        })
    }
    private func rowWeightBinding(for placement: OpenNotchRegionPlacement) -> Binding<Double> {
        Binding(get: { opened.resolvedRowWeights[placement.rowIndex] }, set: { value in
            var next = opened; next.setRowWeight(value, at: placement.rowIndex); layout.openNotch = next
        })
    }
    private func resetTrackWeights(for placement: OpenNotchRegionPlacement) {
        var next = opened
        var columns = next.resolvedColumnWeights; columns[placement.columnIndex] = 1; next.columnWeights = columns
        var rows = next.resolvedRowWeights; rows[placement.rowIndex] = 1; next.rowWeights = rows
        layout.openNotch = next
    }

'''
if helpers.strip() not in s:
    if anchor not in s: raise SystemExit('insets helper anchor not found')
    s = s.replace(anchor, helpers + anchor, 1)

# Editor needs row/column helpers visible in this file as well.
insert_anchor = '\nprivate struct OpenedNotchWorkspaceEditor: View {'
placement_ext = r'''
private extension OpenNotchRegionPlacement {
    var editorRowIndex: Int {
        switch self { case .topLeft, .topCenter, .topRight: return 0; case .middleLeft, .middleCenter, .middleRight: return 1; case .bottomLeft, .bottomCenter, .bottomRight: return 2 }
    }
    var editorColumnIndex: Int {
        switch self { case .topLeft, .middleLeft, .bottomLeft: return 0; case .topCenter, .middleCenter, .bottomCenter: return 1; case .topRight, .middleRight, .bottomRight: return 2 }
    }
    var editorAlignment: Alignment {
        switch self {
        case .topLeft: return .topLeading; case .topCenter: return .top; case .topRight: return .topTrailing
        case .middleLeft: return .leading; case .middleCenter: return .center; case .middleRight: return .trailing
        case .bottomLeft: return .bottomLeading; case .bottomCenter: return .bottom; case .bottomRight: return .bottomTrailing
        }
    }
}
'''
# Use local editor names to avoid relying on private SurfaceView extensions.
if 'var editorRowIndex:' not in s:
    s = s.replace(insert_anchor, placement_ext + insert_anchor, 1)
# Repoint editor-only code to local names.
s = s.replace('.placement.rowIndex', '.placement.editorRowIndex')
s = s.replace('.placement.columnIndex', '.placement.editorColumnIndex')
s = s.replace('placement.regionAlignment', 'placement.editorAlignment')
s = s.replace('placement.columnIndex', 'placement.editorColumnIndex')
s = s.replace('placement.rowIndex', 'placement.editorRowIndex')
write(p, s)

# -----------------------------------------------------------------------------
# Documentation limited to the opened-notch behavior changed here.
# -----------------------------------------------------------------------------
p = 'Docs/WidgetCustomization.md'
s = read(p)
marker = '## Opened notch workspace\n'
if marker in s and 'Custom Workspace Layout is optional' not in s:
    s = s.replace(marker, marker + '''\n**Custom Workspace Layout is optional.** Existing Fixed, Scroll, and Pages opened-notch layouts remain the default for older profiles and are stored independently. Turning Custom Workspace off restores the legacy layout immediately without deleting the custom design. The custom workspace has its own Fixed/Scroll/Pages mode.\n\nIn the custom Fixed workspace, occupied rows and columns form the canvas. Each row and column has a relative size share, and every region can use a percentage of its grid slot plus independent padding. Items are allocated concrete width/height slots before they render; Fixed/Fit/Flexible/Fill sizing is clamped to the region, so cards cannot overlap or escape their designed area. Widgets receive their actual slot dimensions and automatically reduce padding/spacing/secondary content, switch presentation, truncate, and finally scroll only when the slot is genuinely too small.\n\n''', 1)
write(p, s)

print('Opened-notch optional responsive workspace patch applied.')
