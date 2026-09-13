from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"Missing anchor in {path}: {old[:100]!r}")
    text = text.replace(old, new, 1)
    p.write_text(text)

# 1) Per-item Visual Workspace widget style + vertical content alignment.
path = "Halo/Core/WorkspaceModels.swift"
replace_once(path,
'''enum OpenNotchItemKind: String, Codable, CaseIterable, Identifiable {
    case module, element, spacer, divider
    var id: String { rawValue }
}
''',
'''enum OpenNotchItemKind: String, Codable, CaseIterable, Identifiable {
    case module, element, spacer, divider
    var id: String { rawValue }
}

enum OpenNotchBlockVerticalAlignment: String, Codable, CaseIterable, Identifiable {
    case top = "Top"
    case center = "Center"
    case bottom = "Bottom"
    var id: String { rawValue }
}
''')
replace_once(path,
'''    var visibilityRules: [OpenNotchVisibilityRule] = []
    var style: WidgetElementStyle?
    var interactions = OpenNotchInteractions()
''',
'''    var visibilityRules: [OpenNotchVisibilityRule] = []
    var style: WidgetElementStyle?
    // Visual Workspace module instances may override the shared module style without
    // affecting the legacy opened dashboard or another copy of the same module.
    var widgetStyle: WidgetStyle?
    var verticalAlignment: OpenNotchBlockVerticalAlignment?
    var resolvedVerticalAlignment: OpenNotchBlockVerticalAlignment { verticalAlignment ?? .center }
    var interactions = OpenNotchInteractions()
''')
replace_once(path,
'''        value.kind = .module; value.module = module; value.presentation = presentation; value.priority = priority
        value.sizing = OpenNotchSizing(mode: .flexible, minimumWidth: 150, preferredWidth: 300, maximumWidth: 900,
''',
'''        value.kind = .module; value.module = module; value.presentation = presentation; value.priority = priority
        value.verticalAlignment = .center
        value.sizing = OpenNotchSizing(mode: .fill, minimumWidth: 120, preferredWidth: 300, maximumWidth: 1200,
''')
replace_once(path,
'''        value.sizing = try sizing.validated()
        if let style { value.style = try style.validated() }
''',
'''        value.sizing = try sizing.validated()
        if let style { value.style = try style.validated() }
        if let widgetStyle { value.widgetStyle = try widgetStyle.validated() }
''')

# 2) Shared polished defaults used only when a Visual Workspace module has no per-block override.
path = "Halo/Core/WidgetModels.swift"
replace_once(path,
'''enum ClosedNotchItem: String, Codable, CaseIterable, Identifiable {
''',
'''extension WidgetStyle {
    /// A restrained, integrated default for module blocks inside the Visual Workspace.
    /// Explicit per-widget choices still win because this is only used to seed/resolve a
    /// Visual Workspace block that has no item-level override yet.
    func visualWorkspacePolished() -> WidgetStyle {
        var value = self
        value.width = 0
        value.minimumHeight = 0
        value.showTitle = false
        if value.cardBackgroundStyle == nil { value.cardBackgroundStyle = .none }
        if value.outlineStyle == nil { value.outlineStyle = .none }
        if value.showHeaderIcon == nil { value.showHeaderIcon = false }
        value.padding = min(16, max(8, value.padding))
        value.cornerRadius = min(28, max(14, value.cornerRadius))
        value.fontSize = min(32, max(12, value.fontSize))
        var content = value.resolvedContent
        content.spacing = min(10, max(4, content.spacing * 0.75))
        content.controlSize = .small
        content.iconSize = min(18, max(12, content.iconSize))
        value.content = content
        var chrome = value.resolvedChrome
        chrome.shadowOpacity = min(0.18, chrome.shadowOpacity)
        value.chrome = chrome
        return value
    }
}

enum ClosedNotchItem: String, Codable, CaseIterable, Identifiable {
''')

# 3) WidgetCard can center content vertically in Visual Workspace without changing legacy defaults.
path = "Halo/Views/WidgetViews.swift"
replace_once(path,
'''private struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
extension EnvironmentValues {
''',
'''private struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchBlockVerticalAlignmentEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchBlockVerticalAlignment = .top }
extension EnvironmentValues {
''')
replace_once(path,
'''    var openNotchAvailableHeight: CGFloat? {
        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }
        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }
    }
}
''',
'''    var openNotchAvailableHeight: CGFloat? {
        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }
        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }
    }
    var openNotchBlockVerticalAlignment: OpenNotchBlockVerticalAlignment {
        get { self[OpenNotchBlockVerticalAlignmentEnvironmentKey.self] }
        set { self[OpenNotchBlockVerticalAlignmentEnvironmentKey.self] = newValue }
    }
}
''')
replace_once(path,
'''    @Environment(\\.openNotchCompressionLevel) private var compression
    private var fittedStyle: WidgetStyle {
''',
'''    @Environment(\\.openNotchCompressionLevel) private var compression
    @Environment(\\.openNotchBlockVerticalAlignment) private var blockVerticalAlignment
    private var fittedStyle: WidgetStyle {
''')
replace_once(path,
'''    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fittedStyle.cornerRadius, style: .continuous)
    }
''',
'''    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: fittedStyle.cornerRadius, style: .continuous)
    }
    private var contentFrameAlignment: Alignment {
        switch (blockVerticalAlignment, contentOptions.alignment) {
        case (.top, .leading): return .topLeading
        case (.top, .center): return .top
        case (.top, .trailing): return .topTrailing
        case (.center, .leading): return .leading
        case (.center, .center): return .center
        case (.center, .trailing): return .trailing
        case (.bottom, .leading): return .bottomLeading
        case (.bottom, .center): return .bottom
        case (.bottom, .trailing): return .bottomTrailing
        }
    }
''')
replace_once(path,
'''                        styledContent.frame(maxWidth: .infinity, alignment: contentOptions.alignment.alignment)
''',
'''                        styledContent.frame(maxWidth: .infinity, alignment: contentFrameAlignment)
''')
replace_once(path,
'''                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentOptions.alignment.alignment)
''',
'''                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentFrameAlignment)
''')

# 4) Fixed Visual Workspace regions use standard equal blocks and subtle separators.
path = "Halo/Views/SurfaceView.swift"
replace_once(path,
'''                    OpenNotchGroupView(group: group, layout: layout, store: store, constrained: true)
                        .frame(width: innerWidth, height: groupHeight)
''',
'''                    OpenNotchGroupView(group: group, layout: layout, store: store, constrained: true, standardBlocks: true)
                        .frame(width: innerWidth, height: groupHeight)
''')
replace_once(path,
'''    @ObservedObject var store: AppStore
    var constrained = false
    private var context: OpenNotchRuntimeContext { OpenNotchRuntimeContext(store: store) }
''',
'''    @ObservedObject var store: AppStore
    var constrained = false
    var standardBlocks = false
    private var context: OpenNotchRuntimeContext { OpenNotchRuntimeContext(store: store) }
''')
old_stack = '''        if group.axis == .horizontal {
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
'''
new_stack = '''        if group.axis == .horizontal {
            HStack(alignment: group.alignment.verticalAlignment, spacing: standardBlocks ? 0 : spacing) {
                ForEach(Array(items.enumerated()), id: \\.element.id) { index, item in
                    let size = CGSize(width: max(1, lengths[item.id] ?? CGFloat(item.sizing.minimumWidth)), height: max(1, crossAvailable))
                    OpenNotchItemView(item: item, layout: layout, store: store, compression: compression, slotSize: size)
                    if standardBlocks && index < items.count - 1 { Divider().opacity(0.20).padding(.vertical, 8) }
                }
            }.frame(maxHeight: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        } else {
            VStack(alignment: group.alignment.horizontalAlignment, spacing: standardBlocks ? 0 : spacing) {
                ForEach(Array(items.enumerated()), id: \\.element.id) { index, item in
                    let size = CGSize(width: max(1, crossAvailable), height: max(1, lengths[item.id] ?? CGFloat(item.sizing.minimumHeight)))
                    OpenNotchItemView(item: item, layout: layout, store: store, compression: compression, slotSize: size)
                    if standardBlocks && index < items.count - 1 { Divider().opacity(0.20).padding(.horizontal, 8) }
                }
            }.frame(maxWidth: .infinity, alignment: group.alignment.horizontalFrameAlignment)
        }
'''
replace_once(path, old_stack, new_stack)
replace_once(path,
'''        guard !items.isEmpty else { return [:] }
        let usable = max(0, available - spacing * CGFloat(max(0, items.count - 1)))
        var values: [UUID: CGFloat] = [:]
''',
'''        guard !items.isEmpty else { return [:] }
        let effectiveSpacing: CGFloat = standardBlocks ? 0 : spacing
        let usable = max(0, available - effectiveSpacing * CGFloat(max(0, items.count - 1)))
        if standardBlocks {
            let share = max(1, usable / CGFloat(items.count))
            return Dictionary(uniqueKeysWithValues: items.map { ($0.id, share) })
        }
        var values: [UUID: CGFloat] = [:]
''')
replace_once(path,
'''                    .environment(\\.openNotchAvailableHeight, slotSize.height)
                }
''',
'''                    .environment(\\.openNotchAvailableHeight, slotSize.height)
                    .environment(\\.openNotchBlockVerticalAlignment, item.resolvedVerticalAlignment)
                }
''')
replace_once(path,
'''        var style = layout.widgetStyle(for: module)
''',
'''        var style = item.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished()
''')

# 5) Make the media block use the actual slot rather than tiny fixed artwork.
path = "Halo/Views/ModuleViews.swift"
replace_once(path,
'''    @Environment(\\.openNotchPresentation) private var presentation
    @ObservedObject var service: MediaService
''',
'''    @Environment(\\.openNotchPresentation) private var presentation
    @Environment(\\.openNotchAvailableWidth) private var availableWidth
    @Environment(\\.openNotchAvailableHeight) private var availableHeight
    @ObservedObject var service: MediaService
''')
replace_once(path,
'''    private var options: WidgetContentOptions { style.resolvedContent }

    var body: some View {
''',
'''    private var options: WidgetContentOptions { style.resolvedContent }
    private var artworkStyle: WidgetElementStyle { style.elementStyle(for: "artwork") }
    private var compactArtworkSize: CGFloat {
        let requested = CGFloat(artworkStyle.iconSize ?? 54)
        return min(max(38, requested), max(38, min(72, (availableHeight ?? 92) * 0.62)))
    }
    private var regularArtworkSize: CGFloat {
        let requested = CGFloat(artworkStyle.iconSize ?? 82)
        return min(max(52, requested), max(52, min(112, (availableHeight ?? 150) * 0.72)))
    }
    private var expandedArtworkHeight: CGFloat {
        min(240, max(110, (availableHeight ?? 260) * 0.48))
    }

    var body: some View {
''')
replace_once(path,
'''                WidgetElement(key: "artwork", defaultPriority: .normal) { Image(nsImage: image).resizable().scaledToFill().frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 7)) }
                    .frame(width: 44)
''',
'''                WidgetElement(key: "artwork", defaultPriority: .normal) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: compactArtworkSize, height: compactArtworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: min(14, compactArtworkSize * 0.18), style: .continuous))
                }
                .frame(width: compactArtworkSize + 6)
''')
replace_once(path,
'''                WidgetElement(key: "artwork", defaultPriority: .normal) { Image(nsImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 10)) }
                    .frame(width: 78)
''',
'''                WidgetElement(key: "artwork", defaultPriority: .normal) {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: regularArtworkSize, height: regularArtworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: min(18, regularArtworkSize * 0.16), style: .continuous))
                }
                .frame(width: regularArtworkSize + 6)
''')
replace_once(path,
'''                    Image(nsImage: image).resizable().scaledToFill().frame(maxWidth: 260, minHeight: 120, maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 16))
''',
'''                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(maxWidth: min(320, (availableWidth ?? 360) - 24), minHeight: expandedArtworkHeight, maxHeight: expandedArtworkHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
''')
# Calendar summary is now a visual date anchor even in compact mode.
replace_once(path,
'''        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            if presentation != .compact { WidgetElement(key: "summary") { HStack { Text(Date(), style: .date); Spacer(); Text("\\(service.events.count) remaining") } } }
            if let next = service.events.first {
''',
'''        VStack(alignment: options.alignment.horizontal, spacing: options.spacing) {
            WidgetElement(key: "summary") {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(Date.now, format: .dateTime.month(.abbreviated)).font(.system(size: 19, weight: .bold, design: .rounded))
                    Text(Date.now, format: .dateTime.day()).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                    Spacer()
                    Text(service.events.isEmpty ? "Clear" : "\\(service.events.count) upcoming").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let next = service.events.first {
''')

# 6) Visual Workspace editor: standard block preview + per-instance module customization.
path = "Halo/Views/WidgetSettingsView.swift"
replace_once(path,
'''        let stack = Group {
            if group.axis == .horizontal {
                HStack(spacing: min(6, group.spacing)) { itemList(group, region: region) }
            } else {
                VStack(alignment: .leading, spacing: min(6, group.spacing)) { itemList(group, region: region) }
            }
        }
''',
'''        let stack = Group {
            if group.axis == .horizontal {
                HStack(spacing: 0) { itemList(group, region: region) }
            } else {
                VStack(alignment: .leading, spacing: 0) { itemList(group, region: region) }
            }
        }
''')
replace_once(path,
'''        .frame(minWidth: max(42, min(150, item.sizing.preferredWidth * 0.28)), alignment: .leading)
        .background(selectedItem == item.id ? Color.accentColor.opacity(0.28) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
''',
'''        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            if selectedItem == item.id { RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.28)) }
            else { widgetPreviewBackground(item) }
        }
''')
replace_once(path,
'''        Section("Responsive sizing") {
            Picker("Behavior", selection: binding.sizing.mode) { ForEach(OpenNotchSizingMode.allCases) { Text($0.rawValue).tag($0) } }
            sizingSlider("Min width", binding.sizing.minimumWidth, 20...1200)
            sizingSlider("Preferred width", binding.sizing.preferredWidth, 20...1200)
            sizingSlider("Max width", binding.sizing.maximumWidth, 20...1600)
            sizingSlider("Min height", binding.sizing.minimumHeight, 18...900)
            sizingSlider("Preferred height", binding.sizing.preferredHeight, 18...1100)
            sizingSlider("Max height", binding.sizing.maximumHeight, 18...1400)
        }
        Section("Element styling") { styleInspector(binding.style) }
''',
'''        if let module = item.module {
            widgetBlockInspector(itemID: item.id, module: module)
        } else {
            Section("Responsive sizing") {
                Picker("Behavior", selection: binding.sizing.mode) { ForEach(OpenNotchSizingMode.allCases) { Text($0.rawValue).tag($0) } }
                sizingSlider("Min width", binding.sizing.minimumWidth, 20...1200)
                sizingSlider("Preferred width", binding.sizing.preferredWidth, 20...1200)
                sizingSlider("Max width", binding.sizing.maximumWidth, 20...1600)
                sizingSlider("Min height", binding.sizing.minimumHeight, 18...900)
                sizingSlider("Preferred height", binding.sizing.preferredHeight, 18...1100)
                sizingSlider("Max height", binding.sizing.maximumHeight, 18...1400)
            }
            Section("Element styling") { styleInspector(binding.style) }
        }
''')
# Add widget editor helpers before groupInspector.
replace_once(path,
'''    @ViewBuilder private func groupInspector(_ group: OpenNotchGroup) -> some View {
''',
'''    @ViewBuilder private func widgetBlockInspector(itemID: UUID, module: ModuleID) -> some View {
        let style = widgetStyleBinding(itemID, module: module)
        Section("Widget Block") {
            Picker("Vertical content", selection: itemBinding(itemID).verticalAlignment.withDefault(.center)) {
                ForEach(OpenNotchBlockVerticalAlignment.allCases) { Text($0.rawValue).tag($0) }
            }
            HStack(spacing: 6) {
                ForEach(WidgetVisualPreset.allCases) { preset in
                    Button(preset.rawValue) { applyWidgetPreset(preset, itemID: itemID, module: module) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Toggle("Show title", isOn: style.showTitle)
            Toggle("Show header icon", isOn: Binding(get: { style.wrappedValue.showsHeaderIcon }, set: { style.wrappedValue.showHeaderIcon = $0 }))
            Picker("Content alignment", selection: style.content.withDefault(WidgetContentOptions()).alignment) {
                ForEach(WidgetContentAlignment.allCases) { Text($0.title).tag($0) }
            }
        }
        Section("Block Styling") {
            Picker("Background", selection: Binding(get: { style.wrappedValue.resolvedCardBackgroundStyle }, set: { style.wrappedValue.cardBackgroundStyle = $0 })) {
                ForEach(WidgetCardBackgroundStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            let background = style.wrappedValue.resolvedCardBackgroundStyle
            if background == .solid || background == .gradient || background == .glass {
                ColorPicker("Background color", selection: Binding(get: { style.wrappedValue.backgroundColor.color }, set: { style.wrappedValue.backgroundColor = WidgetColor($0) }), supportsOpacity: false)
            }
            if background == .gradient {
                ColorPicker("Second color", selection: Binding(get: { style.wrappedValue.resolvedBackgroundSecondaryColor.color }, set: { style.wrappedValue.backgroundSecondaryColor = WidgetColor($0) }), supportsOpacity: false)
                PreciseSlider(title: "Gradient angle", value: style.gradientAngle.withDefault(135), range: -180...180, step: 5, suffix: "°")
            }
            if background != .none {
                PreciseSlider(title: "Background opacity", value: style.backgroundOpacity, range: 0...1, step: 0.02, decimals: 2)
            }
            Picker("Outline", selection: Binding(get: { style.wrappedValue.resolvedOutlineStyle }, set: { style.wrappedValue.outlineStyle = $0 })) {
                ForEach(WidgetOutlineStyle.allCases) { Text($0.rawValue).tag($0) }
            }
            if style.wrappedValue.resolvedOutlineStyle != .none {
                ColorPicker("Outline color", selection: Binding(get: { style.wrappedValue.resolvedChrome.borderColor.color }, set: { var chrome = style.wrappedValue.resolvedChrome; chrome.borderColor = WidgetColor($0); style.wrappedValue.chrome = chrome }), supportsOpacity: false)
                PreciseSlider(title: "Outline width", value: widgetChromeDouble(style, \\.borderWidth), range: 0.5...6, step: 0.25, suffix: "pt", decimals: 2)
                PreciseSlider(title: "Outline opacity", value: widgetChromeDouble(style, \\.borderOpacity), range: 0...1, step: 0.05, decimals: 2)
            }
            PreciseSlider(title: "Corner radius", value: style.cornerRadius, range: 0...40, step: 1, suffix: "pt")
            PreciseSlider(title: "Internal padding", value: style.padding, range: 0...32, step: 1, suffix: "pt")
        }
        Section("Typography") {
            Picker("Font", selection: style.fontFamily) { ForEach(WidgetFontFamily.allCases, id: \\.self) { Text($0.rawValue.capitalized).tag($0) } }
            Picker("Weight", selection: style.weight) { ForEach(WidgetFontWeight.allCases, id: \\.self) { Text($0.rawValue.capitalized).tag($0) } }
            PreciseSlider(title: "Base text size", value: style.fontSize, range: 10...40, step: 1, suffix: "pt")
            ColorPicker("Text", selection: Binding(get: { style.wrappedValue.textColor.color }, set: { style.wrappedValue.textColor = WidgetColor($0) }), supportsOpacity: false)
            ColorPicker("Accent", selection: Binding(get: { style.wrappedValue.accentColor.color }, set: { style.wrappedValue.accentColor = WidgetColor($0) }), supportsOpacity: false)
        }
        Section("Displayed Content") {
            ForEach(module.widgetElements) { descriptor in
                let element = widgetElementStyleBinding(itemID, module: module, descriptor: descriptor)
                DisclosureGroup {
                    styleInspector(element, defaultVisible: descriptor.defaultVisible)
                } label: {
                    Toggle(isOn: Binding(
                        get: { element.wrappedValue?.visible ?? descriptor.defaultVisible },
                        set: { visible in
                            var value = element.wrappedValue ?? WidgetElementStyle()
                            value.visible = visible
                            element.wrappedValue = value
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(descriptor.title)
                            Text(descriptor.detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        Section {
            Button("Reset Block to Visual Workspace Defaults") { mutateItem(itemID) { $0.widgetStyle = nil; $0.verticalAlignment = .center } }
        }
    }

    @ViewBuilder private func groupInspector(_ group: OpenNotchGroup) -> some View {
''')
# Update styleInspector signature to respect descriptor defaults.
replace_once(path,
'''    @ViewBuilder private func styleInspector(_ optional: Binding<WidgetElementStyle?>) -> some View {
        let b = Binding<WidgetElementStyle>(get: { optional.wrappedValue ?? WidgetElementStyle() }, set: { optional.wrappedValue = $0 })
''',
'''    @ViewBuilder private func styleInspector(_ optional: Binding<WidgetElementStyle?>, defaultVisible: Bool = true) -> some View {
        let b = Binding<WidgetElementStyle>(get: {
            if let value = optional.wrappedValue { return value }
            var value = WidgetElementStyle(); value.visible = defaultVisible; return value
        }, set: { optional.wrappedValue = $0 })
''')
# New groups/regions are horizontal standard blocks by default.
replace_once(path,
'''            region.groups = [OpenNotchGroup(name: "Region \\(open.regions.count + 1)")]
''',
'''            region.groups = [OpenNotchGroup(name: "Region \\(open.regions.count + 1)", axis: .horizontal)]
''')
replace_once(path,
'''    private func addGroup(regionID: UUID? = nil) { let rid = regionID ?? selectedRegion ?? { ensureRegion(.middleCenter); return opened.regions.first(where: { $0.placement == .middleCenter })?.id }()!; let group = OpenNotchGroup(name: "Group"); mutateOpen { open in if let ri = open.regions.firstIndex(where: { $0.id == rid }) { open.regions[ri].groups.append(group) } }; selectedGroup = group.id; selectedRegion = rid }
''',
'''    private func addGroup(regionID: UUID? = nil) { let rid = regionID ?? selectedRegion ?? { ensureRegion(.middleCenter); return opened.regions.first(where: { $0.placement == .middleCenter })?.id }()!; let group = OpenNotchGroup(name: "Group", axis: .horizontal); mutateOpen { open in if let ri = open.regions.firstIndex(where: { $0.id == rid }) { open.regions[ri].groups.append(group) } }; selectedGroup = group.id; selectedRegion = rid }
''')
# Helpers before materialize().
replace_once(path,
'''    private func materialize() { if layout.openNotch == nil { layout.materializeOpenNotchLayout() } }
''',
'''    @ViewBuilder private func widgetPreviewBackground(_ item: OpenNotchItem) -> some View {
        if let module = item.module {
            let style = item.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished()
            let shape = RoundedRectangle(cornerRadius: min(10, style.cornerRadius), style: .continuous)
            switch style.resolvedCardBackgroundStyle {
            case .none: shape.fill(Color.white.opacity(0.035))
            case .solid: shape.fill(style.backgroundColor.color.opacity(max(0.06, style.backgroundOpacity)))
            case .gradient: shape.fill(LinearGradient(colors: [style.backgroundColor.color.opacity(max(0.08, style.backgroundOpacity)), style.resolvedBackgroundSecondaryColor.color.opacity(max(0.08, style.backgroundOpacity))], startPoint: .leading, endPoint: .trailing))
            case .glass: shape.fill(.ultraThinMaterial).opacity(max(0.18, style.backgroundOpacity))
            case .accent: shape.fill(style.accentColor.color.opacity(max(0.08, style.backgroundOpacity)))
            }
        } else {
            RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.08))
        }
    }

    private func widgetStyleBinding(_ itemID: UUID, module: ModuleID) -> Binding<WidgetStyle> {
        Binding(
            get: { findItem(itemID)?.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished() },
            set: { replacement in mutateItem(itemID) { $0.widgetStyle = replacement } }
        )
    }

    private func widgetElementStyleBinding(_ itemID: UUID, module: ModuleID, descriptor: WidgetElementDescriptor) -> Binding<WidgetElementStyle?> {
        Binding(
            get: { findItem(itemID)?.widgetStyle?.elementStyles?[descriptor.key] },
            set: { replacement in
                var widget = findItem(itemID)?.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished()
                if widget.elementStyles == nil { widget.elementStyles = [:] }
                widget.elementStyles?[descriptor.key] = replacement
                mutateItem(itemID) { $0.widgetStyle = widget }
            }
        )
    }

    private func widgetChromeDouble(_ style: Binding<WidgetStyle>, _ keyPath: WritableKeyPath<WidgetChromeOptions, Double>) -> Binding<Double> {
        Binding(get: { style.wrappedValue.resolvedChrome[keyPath: keyPath] }, set: { value in
            var chrome = style.wrappedValue.resolvedChrome
            chrome[keyPath: keyPath] = value
            style.wrappedValue.chrome = chrome
        })
    }

    private func applyWidgetPreset(_ preset: WidgetVisualPreset, itemID: UUID, module: ModuleID) {
        var style = findItem(itemID)?.widgetStyle ?? layout.widgetStyle(for: module).visualWorkspacePolished()
        var chrome = style.resolvedChrome
        switch preset {
        case .clean:
            style.cardBackgroundStyle = .none; style.outlineStyle = .none; style.backgroundOpacity = 0; chrome.shadowOpacity = 0
        case .glass:
            style.cardBackgroundStyle = .glass; style.backgroundOpacity = 0.42; style.outlineStyle = .solid; chrome.borderOpacity = 0.13; chrome.borderWidth = 1; chrome.shadowOpacity = 0.10
        case .filled:
            style.cardBackgroundStyle = .gradient; style.backgroundOpacity = 0.18; style.backgroundSecondaryColor = style.accentColor; style.outlineStyle = .none; chrome.shadowOpacity = 0.08
        case .outline:
            style.cardBackgroundStyle = .none; style.outlineStyle = .solid; chrome.borderColor = style.textColor; chrome.borderOpacity = 0.18; chrome.borderWidth = 1; chrome.shadowOpacity = 0
        case .floating:
            style.cardBackgroundStyle = .glass; style.backgroundOpacity = 0.34; style.outlineStyle = .glow; chrome.borderColor = style.accentColor; chrome.borderOpacity = 0.22; chrome.borderWidth = 1; chrome.shadowOpacity = 0.18; chrome.shadowRadius = 14
        case .minimal:
            style.cardBackgroundStyle = .none; style.outlineStyle = .none; style.showTitle = false; style.showHeaderIcon = false; style.padding = 6; chrome.shadowOpacity = 0
        }
        style.chrome = chrome
        mutateItem(itemID) { $0.widgetStyle = style }
    }

    private func materialize() { if layout.openNotch == nil { layout.materializeOpenNotchLayout() } }
''')

# Add a local optional Binding convenience if the file does not already have one.
p = Path(path)
text = p.read_text()
if 'private extension Binding {' not in text or 'func withDefault' not in text:
    text += '''\n\nprivate extension Binding {\n    func withDefault<T>(_ fallback: T) -> Binding<T> where Value == T? {\n        Binding<T>(get: { wrappedValue ?? fallback }, set: { wrappedValue = $0 })\n    }\n}\n'''
    p.write_text(text)

print("Implemented polished, equal-size, per-instance Visual Workspace widget blocks and customization.")
