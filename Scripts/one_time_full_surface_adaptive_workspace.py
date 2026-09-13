from pathlib import Path


def read(path):
    return Path(path).read_text()


def write(path, text):
    Path(path).write_text(text)


def replace_once(path, old, new):
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}, found {count}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))

surface = 'Halo/Views/SurfaceView.swift'

# Visual Workspace owns the expanded surface instead of inheriting the legacy header slot.
replace_once(surface,
'''                if !contextOwnsFullSurface {''',
'''                if !contextOwnsFullSurface &&
                    !(state.expanded && activeContext == nil && layout.resolvedUsesCustomOpenNotchWorkspace) {''')

replace_once(surface,
'''                    } else if retroContextActive {
                        if !retroUsesFullNotchArea {
                            RetroGameContextView(surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {''',
'''                    } else if retroContextActive {
                        if !retroUsesFullNotchArea {
                            RetroGameContextView(surfaceState: state)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        }
                    } else if layout.resolvedUsesCustomOpenNotchWorkspace {
                        // Visual Workspace owns the entire expanded surface. Regions now map
                        // directly to the notch canvas instead of a padded legacy dashboard body.
                        OpenNotchWorkspaceView(layout: layout, store: store,
                                               mode: layout.resolvedOpenNotchLayout.resolvedContentMode,
                                               page: $page)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .overlay(alignment: .bottomTrailing) {
                                HStack(spacing: 5) {
                                    Button { state.pinned.toggle() } label: {
                                        Image(systemName: state.pinned ? "pin.fill" : "pin")
                                    }
                                    .help("Keep expanded")
                                    Button {
                                        NotificationCenter.default.post(name: Notification.Name("HaloOpenSettings"), object: nil)
                                    } label: {
                                        Image(systemName: "gearshape")
                                    }
                                    .help("Settings")
                                }
                                .controlSize(.small)
                                .padding(.horizontal, 7).padding(.vertical, 5)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                            }
                            .overlay(alignment: .top) {
                                if keepsClosedContentsWhileExpanded {
                                    // Preserve the existing option without stealing layout space:
                                    // closed-notch content floats over the full workspace instead.
                                    ClosedNotchView(store: store, workspace: workspace, layout: layout,
                                                    occlusion: state.closedOcclusion,
                                                    referenceWidth: state.compactWidth)
                                        .frame(height: max(40, state.compactHeight))
                                        .zIndex(3)
                                }
                            }
                            .transition(.opacity)
                    } else {
                        VStack(alignment: .leading, spacing: 16) {''')

# Compression must account for the cross-axis too; otherwise a short/tall slot can
# remain in Regular presentation and simply get clipped.
replace_once(surface,
'''            let candidates = group.items.filter(context.isVisible)
            let mainAvailable = group.axis == .horizontal ? innerWidth : innerHeight
            let wanted = preferredLength(of: candidates) + max(0, CGFloat(candidates.count - 1)) * CGFloat(group.spacing)
            let compression = compressionLevel(available: mainAvailable, wanted: wanted)
            let spacing = max(2, CGFloat(group.spacing) * (compression >= 1 ? 0.62 : 1))
            let visible = candidates.filter { $0.priority.remainsVisible(at: compression) }
            let crossAvailable = group.axis == .horizontal ? innerHeight : innerWidth
            let lengths = allocatedLengths(items: visible, available: mainAvailable, spacing: spacing, compression: compression)
            let minimumNeeded = minimumLength(of: visible) + max(0, CGFloat(visible.count - 1)) * spacing

            Group {
                if compression >= 5 && minimumNeeded > mainAvailable + 1 {''',
'''            let candidates = group.items.filter(context.isVisible)
            let mainAvailable = group.axis == .horizontal ? innerWidth : innerHeight
            let crossAvailable = group.axis == .horizontal ? innerHeight : innerWidth
            let wanted = preferredLength(of: candidates) + max(0, CGFloat(candidates.count - 1)) * CGFloat(group.spacing)
            let mainCompression = compressionLevel(available: mainAvailable, wanted: wanted)
            let crossCompression = compressionLevel(available: crossAvailable, wanted: preferredCrossLength(of: candidates))
            let compression = max(mainCompression, crossCompression)
            let spacing = max(2, CGFloat(group.spacing) * (compression >= 1 ? 0.62 : 1))
            // A module explicitly placed in a Visual Workspace region is structural content.
            // Never remove the whole widget just because its slot is small; its internals
            // collapse first. Priority-based removal still applies to lightweight elements.
            let visible = candidates.filter { item in
                if standardBlocks && item.kind == .module { return true }
                return item.priority.remainsVisible(at: compression)
            }
            let lengths = allocatedLengths(items: visible, available: mainAvailable, spacing: spacing, compression: compression)
            let minimumNeeded = minimumLength(of: visible) + max(0, CGFloat(visible.count - 1)) * spacing

            Group {
                if !standardBlocks && compression >= 5 && minimumNeeded > mainAvailable + 1 {''')

replace_once(surface,
'''    private func minimumLength(of items: [OpenNotchItem]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + CGFloat(group.axis == .horizontal ? item.sizing.minimumWidth : item.sizing.minimumHeight)
        }
    }
    private func bounds(for item: OpenNotchItem) -> (min: CGFloat, preferred: CGFloat, max: CGFloat) {''',
'''    private func minimumLength(of items: [OpenNotchItem]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + CGFloat(group.axis == .horizontal ? item.sizing.minimumWidth : item.sizing.minimumHeight)
        }
    }
    private func preferredCrossLength(of items: [OpenNotchItem]) -> CGFloat {
        items.map { item in
            CGFloat(group.axis == .horizontal ? item.sizing.preferredHeight : item.sizing.preferredWidth)
        }.max() ?? 0
    }
    private func bounds(for item: OpenNotchItem) -> (min: CGFloat, preferred: CGFloat, max: CGFloat) {''')

# More aggressive but bounded adaptation before the safety scroll is needed.
replace_once(surface,
'''        let widthScale = min(1, max(0.68, slotSize.width / 300))
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
        style.content = content''',
'''        let widthScale = min(1, max(0.52, slotSize.width / 320))
        let heightScale = min(1, max(0.50, slotSize.height / 190))
        let scale = min(widthScale, heightScale)
        style.padding = max(2, style.padding * scale)
        style.fontSize = max(8, style.fontSize * max(0.62, scale))
        var content = style.resolvedContent
        content.spacing = max(2, content.spacing * scale)
        content.iconSize = max(9, content.iconSize * scale)
        if compression >= 1 || slotSize.height < 155 || slotSize.width < 255 {
            content.showSecondaryText = false
            content.mediaShowArtist = slotSize.height >= 88 && slotSize.width >= 180
            content.mediaShowSource = false
            content.calendarShowTimes = slotSize.height >= 125 && slotSize.width >= 230
            content.shelfShowDetails = false
            content.activitiesShowDetail = false
        }
        if compression >= 2 || slotSize.height < 125 || slotSize.width < 215 {
            content.controlSize = .small
            content.showStatus = false
            content.maxItems = min(3, content.maxItems)
        }
        if compression >= 3 || slotSize.height < 100 || slotSize.width < 185 {
            content.controlSize = .mini
            content.maxItems = min(2, content.maxItems)
            content.showFooter = false
            content.showQuickActions = false
            content.showSearch = slotSize.height >= 92 && slotSize.width >= 175
        } else if slotSize.height < 180 {
            content.maxItems = min(3, content.maxItems)
        }
        if compression >= 4 || slotSize.width < 155 || slotSize.height < 78 {
            content.mediaTitleLines = 1
            content.maxItems = min(1, content.maxItems)
            content.calendarShowJoin = false
        }
        style.content = content''')

# Make compact System composition reflow instead of crushing three metrics horizontally.
replace_once(surface,
'''            if presentation == .compact {
                HStack(spacing: 7) {
                    WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                    WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                    if options.systemBattery, let battery = service.battery {
                        WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
                    }
                }
            } else {''',
'''            if presentation == .compact {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                        WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                        if options.systemBattery, let battery = service.battery {
                            WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 5)], spacing: 5) {
                        WidgetElement(key: "cpu", defaultPriority: .alwaysVisible) { CompactMetric(label: "CPU", value: service.cpuUsage, icon: "cpu", accent: style.accentColor.color) }
                        WidgetElement(key: "memoryUsage", defaultPriority: .high) { CompactMetric(label: "RAM", value: service.memoryUsage, icon: "memorychip", accent: style.accentColor.color) }
                        if options.systemBattery, let battery = service.battery {
                            WidgetElement(key: "battery", defaultPriority: .high) { CompactMetric(label: "BAT", value: Double(battery), icon: service.charging ? "battery.100.bolt" : "battery.100", accent: style.accentColor.color) }
                        }
                    }
                }
            } else {''')

# Timer presets reflow in narrow blocks.
replace_once(surface,
'''                    WidgetElement(key: "presets") {
                        HStack(spacing: options.spacing) {
                            ForEach([options.timerPresetA, options.timerPresetB, options.timerPresetC], id: \.self) { minutes in
                                Button("\\(minutes) min") { store.startTimer(minutes: minutes) }
                            }
                        }.buttonStyle(.bordered)
                    }''',
'''                    WidgetElement(key: "presets") {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: options.spacing) {
                                ForEach([options.timerPresetA, options.timerPresetB, options.timerPresetC], id: \.self) { minutes in
                                    Button("\\(minutes) min") { store.startTimer(minutes: minutes) }
                                }
                            }
                            HStack(spacing: max(4, options.spacing * 0.6)) {
                                ForEach([options.timerPresetA, options.timerPresetB, options.timerPresetC], id: \.self) { minutes in
                                    Button("\\(minutes)m") { store.startTimer(minutes: minutes) }
                                }
                            }
                        }.buttonStyle(.bordered)
                    }''')

# WidgetCard gets the *inner* slot size and a scroll safety net. Content still
# compresses/picks compact presentations first; scrolling only becomes possible
# when the adapted content is genuinely taller than the designed slot.
widgets = 'Halo/Views/WidgetViews.swift'
replace_once(widgets,
'''    private var contentOptions: WidgetContentOptions { fittedStyle.resolvedContent }
    private var chrome: WidgetChromeOptions { fittedStyle.resolvedChrome }
    private var styledContent: some View {
        content.environment(\\.widgetStyle, fittedStyle)
            .environment(\\.openNotchAvailableWidth, availableWidth)
            .environment(\\.openNotchAvailableHeight, availableHeight)''',
'''    private var contentOptions: WidgetContentOptions { fittedStyle.resolvedContent }
    private var chrome: WidgetChromeOptions { fittedStyle.resolvedChrome }
    private var innerAvailableWidth: CGFloat? {
        availableWidth.map { max(1, $0 - CGFloat(fittedStyle.padding * 2)) }
    }
    private var innerAvailableHeight: CGFloat? {
        availableHeight.map { max(1, $0 - CGFloat(fittedStyle.padding * 2)) }
    }
    private var styledContent: some View {
        content.environment(\\.widgetStyle, fittedStyle)
            .environment(\\.openNotchAvailableWidth, innerAvailableWidth)
            .environment(\\.openNotchAvailableHeight, innerAvailableHeight)''')

replace_once(widgets,
'''    private var adaptiveScale: Double {
        let widthScale = availableWidth.map { min(1, max(0.68, Double($0) / 220)) } ?? 1
        let heightScale = availableHeight.map { min(1, max(0.68, Double($0) / 110)) } ?? 1
        return min(widthScale, heightScale)
    }''',
'''    private var adaptiveScale: Double {
        let widthScale = availableWidth.map { min(1, max(0.52, Double($0) / 250)) } ?? 1
        let heightScale = availableHeight.map { min(1, max(0.52, Double($0) / 145)) } ?? 1
        let pressure = max(0.68, 1 - Double(compression) * 0.055)
        return min(widthScale, heightScale) * pressure
    }''')

replace_once(widgets,
'''    private var controlSize: ControlSize {
        let density = element.contentDensity ?? 1
        if density <= 0.7 { return .mini }
        if density <= 0.9 { return .small }
        if density >= 1.3 { return .large }
        return widgetStyle.resolvedContent.controlSize.swiftUI
    }''',
'''    private var controlSize: ControlSize {
        let density = element.contentDensity ?? 1
        if compression >= 3 || density <= 0.7 { return .mini }
        if compression >= 1 || density <= 0.9 { return .small }
        if density >= 1.3 { return .large }
        return widgetStyle.resolvedContent.controlSize.swiftUI
    }''')

replace_once(widgets,
'''                .lineLimit(compression >= 4 ? 1 : nil)
                .padding(element.padding * adaptiveScale)''',
'''                .lineLimit(compression >= 4 ? 1 : compression >= 2 ? 2 : nil)
                .minimumScaleFactor(compression >= 3 ? 0.72 : 0.86)
                .padding(element.padding * adaptiveScale)''')

replace_once(widgets,
'''        Group {
            if let height = availableHeight {
                let padding = fittedStyle.padding
                if compression >= 5 {
                    ScrollView(.vertical) {
                        styledContent.frame(maxWidth: .infinity, alignment: contentFrameAlignment)
                    }
                    .padding(padding).frame(height: max(0, height)).clipped()
                } else {
                    styledContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentFrameAlignment)
                        .padding(padding)
                        .frame(height: max(0, height))
                        .clipped()
                }
            } else {
                styledContent
                    .frame(maxWidth: .infinity, minHeight: style.minimumHeight, alignment: contentOptions.alignment.alignment)
                    .padding(style.padding)
            }
        }''',
'''        Group {
            if let height = availableHeight {
                let padding = CGFloat(fittedStyle.padding)
                let innerHeight = max(1, height - padding * 2)
                // Adaptation happens before this point. The scroll view is only a safety
                // net: when content fits it has no scroll range, and when it does not fit
                // the user can still reach every control instead of losing it to clipping.
                ScrollView(.vertical) {
                    styledContent
                        .frame(maxWidth: .infinity, minHeight: innerHeight, alignment: contentFrameAlignment)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, height: innerHeight, alignment: contentFrameAlignment)
                .padding(padding)
                .frame(height: max(0, height))
                .clipped()
            } else {
                styledContent
                    .frame(maxWidth: .infinity, minHeight: style.minimumHeight, alignment: contentOptions.alignment.alignment)
                    .padding(style.padding)
            }
        }''')

print('Applied full-surface Visual Workspace and adaptive widget sizing patch.')
