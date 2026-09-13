from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected 1 match in {path}, got {count}: {old[:100]!r}")
    p.write_text(text.replace(old, new, 1))

surface = "Halo/Views/SurfaceView.swift"

# Give the custom workspace an explicit canvas equal to the entire available expanded surface.
replace_once(surface,
'''                    } else if layout.resolvedUsesCustomOpenNotchWorkspace {
                        // Visual Workspace owns the entire expanded surface. Regions now map
                        // directly to the notch canvas instead of a padded legacy dashboard body.
                        OpenNotchWorkspaceView(layout: layout, store: store,
                                               mode: layout.resolvedOpenNotchLayout.resolvedContentMode,
                                               page: $page)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .overlay(alignment: .bottomTrailing) {''',
'''                    } else if layout.resolvedUsesCustomOpenNotchWorkspace {
                        // The Visual Workspace receives one authoritative canvas: exactly the
                        // expanded surface proposed by the notch window. Region percentages are
                        // resolved only against this rectangle, never against intrinsic content.
                        GeometryReader { surfaceProxy in
                            OpenNotchWorkspaceView(layout: layout, store: store,
                                                   mode: layout.resolvedOpenNotchLayout.resolvedContentMode,
                                                   page: $page)
                                .frame(width: surfaceProxy.size.width,
                                       height: surfaceProxy.size.height,
                                       alignment: .topLeading)
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .overlay(alignment: .bottomTrailing) {''')

# Freeform regions use explicit absolute positions in the authoritative canvas.
replace_once(surface,
'''    private var freeformCanvas: some View {
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
    }''',
'''    private var freeformCanvas: some View {
        GeometryReader { proxy in
            let canvas = proxy.size
            ZStack(alignment: .topLeading) {
                ForEach(regions) { region in
                    let raw = region.frame ?? fallbackFrame(for: region.placement)
                    let x = min(1, max(0, raw.x))
                    let y = min(1, max(0, raw.y))
                    let width = min(1 - x, max(0.01, raw.width))
                    let height = min(1 - y, max(0.01, raw.height))
                    let regionWidth = max(1, canvas.width * CGFloat(width))
                    let regionHeight = max(1, canvas.height * CGFloat(height))
                    OpenNotchRegionView(region: region, layout: layout, store: store)
                        .frame(width: regionWidth, height: regionHeight)
                        .position(x: canvas.width * CGFloat(x) + regionWidth / 2,
                                  y: canvas.height * CGFloat(y) + regionHeight / 2)
                }
            }
            .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        }
    }''')

# Region/group/item content should adapt inside its slot. Do not repeatedly clip at each
# hierarchy level; the surface contour remains the authoritative final clip.
replace_once(surface,
'''                    OpenNotchGroupView(group: group, layout: layout, store: store, constrained: true, standardBlocks: true)
                        .frame(width: innerWidth, height: groupHeight)
                        .clipped()''',
'''                    OpenNotchGroupView(group: group, layout: layout, store: store, constrained: true, standardBlocks: true)
                        .frame(width: innerWidth, height: groupHeight)''')
replace_once(surface,
'''        }
        .clipped()
    }
}

private struct OpenNotchGroupView: View {''',
'''        }
    }
}

private struct OpenNotchGroupView: View {''')
replace_once(surface,
'''        .frame(minHeight: constrained ? 0 : estimatedHeight, maxHeight: constrained ? .infinity : nil)
        .clipped()
    }

    @ViewBuilder private func stack''',
'''        .frame(minHeight: constrained ? 0 : estimatedHeight, maxHeight: constrained ? .infinity : nil)
    }

    @ViewBuilder private func stack''')
replace_once(surface,
'''        .frame(width: slotSize.width, height: slotSize.height, alignment: itemStyle.alignment?.alignment ?? .center)
        .clipped()
        .contentShape(Rectangle())''',
'''        .frame(width: slotSize.width, height: slotSize.height, alignment: itemStyle.alignment?.alignment ?? .center)
        .contentShape(Rectangle())''')

# Presentation now responds to slot shape as well as raw dimensions.
replace_once(surface,
'''    private var resolvedPresentation: OpenNotchPresentation {
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
    }''',
'''    private var resolvedPresentation: OpenNotchPresentation {
        let width = max(1, slotSize.width)
        let height = max(1, slotSize.height)
        let aspect = width / height
        let area = width * height
        let hardCompact = width < 132 || height < 58
        let shapeCompact = (aspect > 2.35 && height < 158) || (aspect < 0.62 && width < 205)
        let compact = hardCompact || shapeCompact || width < 225 || height < 104 || compression >= 3
        let expandedPossible = width >= 330 && height >= 185 && area >= 68_000 && compression < 2
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
    }''')

# Stronger content adaptation for short/wide and narrow/tall slots.
replace_once(surface,
'''        let widthScale = min(1, max(0.68, slotSize.width / 300))
        let heightScale = min(1, max(0.68, slotSize.height / 170))
        let scale = min(widthScale, heightScale)
        style.padding *= scale
        style.fontSize *= max(0.76, scale)''',
'''        let widthScale = min(1, max(0.50, slotSize.width / 300))
        let heightScale = min(1, max(0.50, slotSize.height / 170))
        let shapePressure = min(1, max(0.68, min(slotSize.width / max(1, slotSize.height), slotSize.height / max(1, slotSize.width)) * 1.8))
        let scale = min(widthScale, heightScale) * shapePressure
        style.padding *= max(0.48, scale)
        style.fontSize *= max(0.62, scale)''')

# Calendar chooses compositions by actual region shape, not only a generic presentation label.
module = "Halo/Views/ModuleViews.swift"
replace_once(module,
'''    private var effectiveView: CalendarWidgetViewStyle {
        let width = availableWidth ?? 360
        let height = availableHeight ?? 220
        if presentation == .compact || width < 230 || height < 120 {
            return requestedView == .agenda ? .agenda : .weekStrip
        }
        if requestedView == .split && width < 390 { return .monthGrid }
        return requestedView
    }''',
'''    private var effectiveView: CalendarWidgetViewStyle {
        let width = availableWidth ?? 360
        let height = availableHeight ?? 220
        let aspect = width / max(1, height)
        if height < 92 || (aspect > 2.25 && height < 170) {
            return requestedView == .agenda ? .agenda : .weekStrip
        }
        if width < 205 || (aspect < 0.68 && width < 255) {
            return .agenda
        }
        if presentation == .compact || width < 245 || height < 128 {
            return requestedView == .agenda ? .agenda : .weekStrip
        }
        if requestedView == .split && (width < 410 || height < 185) {
            return height >= 175 && width >= 285 ? .monthGrid : .agenda
        }
        return requestedView
    }''')

# The editor must represent normalized freeform geometry exactly. Remove the 44pt minimum
# distortion and use the same position-based math as runtime.
settings = "Halo/Views/WidgetSettingsView.swift"
replace_once(settings,
'''    private func freeformPreview(canvasSize: CGSize) -> some View {
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
    }''',
'''    private func freeformPreview(canvasSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(opened.regions) { region in
                let raw = effectiveRegionFrame(region.id)
                let x = min(1, max(0, raw.x))
                let y = min(1, max(0, raw.y))
                let width = min(1 - x, max(0.01, raw.width))
                let height = min(1 - y, max(0.01, raw.height))
                let regionWidth = canvasSize.width * CGFloat(width)
                let regionHeight = canvasSize.height * CGFloat(height)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(regionTitle(region)).font(.system(size: 9, weight: .semibold))
                        Spacer()
                        Text("\\(Int((width * 100).rounded()))×\\(Int((height * 100).rounded()))%")
                            .font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    ForEach(region.groups) { group in groupPreview(group, region: region) }
                    Spacer(minLength: 0)
                }
                .padding(min(7, max(2, min(regionWidth, regionHeight) * 0.04)))
                .frame(width: max(1, regionWidth), height: max(1, regionHeight), alignment: .topLeading)
                .background((selectedRegion == region.id ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.045)), in: RoundedRectangle(cornerRadius: min(12, max(4, min(regionWidth, regionHeight) * 0.08))))
                .overlay(RoundedRectangle(cornerRadius: min(12, max(4, min(regionWidth, regionHeight) * 0.08))).stroke(selectedRegion == region.id ? Color.accentColor.opacity(0.75) : .white.opacity(0.08), lineWidth: selectedRegion == region.id ? 1.5 : 1))
                .contentShape(Rectangle())
                .position(x: canvasSize.width * CGFloat(x) + regionWidth / 2,
                          y: canvasSize.height * CGFloat(y) + regionHeight / 2)
                .onTapGesture { selectedRegion = region.id; selectedGroup = nil; selectedItem = nil; backgroundMode = false }
                .onDrop(of: [UTType.text], isTargeted: nil) { providers in acceptDrop(providers, regionID: region.id) }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    }''')

print("Applied Visual Workspace authoritative-canvas geometry fix.")
