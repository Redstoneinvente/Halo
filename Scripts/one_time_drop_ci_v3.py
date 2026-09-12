from pathlib import Path


def replace_between(path: str, start: str, end: str, replacement: str, label: str):
    p = Path(path)
    text = p.read_text()
    a = text.find(start)
    if a < 0:
        raise SystemExit(f"{label}: start marker not found")
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f"{label}: end marker not found")
    p.write_text(text[:a] + replacement + text[b:])


def replace_once(path: str, old: str, new: str, label: str):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, got {count}")
    p.write_text(text.replace(old, new, 1))


runtime_board = r'''@MainActor
private struct HaloDropZoneBoardView: View {
    @ObservedObject var settings: HaloDropZoneSettingsStore
    @ObservedObject var model: HaloDropZoneRuntimeModel

    var body: some View {
        GeometryReader { proxy in
            let configuration = settings.configuration
            let frames = HaloDropZoneLayoutResolver.frames(size: proxy.size, configuration: configuration)
            let dense = configuration.zones.count >= 6 || proxy.size.height < 260

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(configuration.backgroundOpacity))

                LinearGradient(
                    colors: [Color.white.opacity(0.055), Color.clear, Color.accentColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)

                header(configuration: configuration)
                    .padding(.horizontal, max(14, configuration.boardPadding + 4))
                    .padding(.top, 11)

                ForEach(Array(configuration.zones.enumerated()), id: \.element.id) { index, zone in
                    if frames.indices.contains(index) {
                        let frame = frames[index]
                        zoneCard(
                            zone,
                            index: index,
                            active: model.hoveredZone == index,
                            configuration: configuration,
                            dense: dense
                        )
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: model.hoveredZone == nil ? "cursorarrow.motionlines" : "arrow.down.circle.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                    Text(model.hoveredZone == nil ? "Move over an action" : "Release to run this action")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                }
                .foregroundStyle(model.hoveredZone == nil ? Color.white.opacity(0.36) : Color.white.opacity(0.70))
                .position(x: proxy.size.width / 2, y: max(12, proxy.size.height - 11))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .foregroundStyle(.white)
        }
    }

    private func header(configuration: HaloDropZoneConfiguration) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(configuration.headerTitle.isEmpty ? "Drop into Halo" : configuration.headerTitle)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                Text(model.result ?? (configuration.headerSubtitle.isEmpty ? "Choose what happens next" : configuration.headerSubtitle))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(model.result == nil ? Color.white.opacity(0.45) : Color.green.opacity(0.90))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Image(systemName: model.itemCount == 1 ? "doc.fill" : "doc.on.doc.fill")
                Text(model.itemCount == 1 ? "1 item" : "\(model.itemCount) items")
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.065), in: Capsule())
        }
    }

    private func zoneCard(
        _ zone: HaloDropZone,
        index: Int,
        active: Bool,
        configuration: HaloDropZoneConfiguration,
        dense: Bool
    ) -> some View {
        GeometryReader { proxy in
            let compact = dense || proxy.size.width < 130 || proxy.size.height < 86
            let accent = zone.color.color

            ZStack {
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(active ? 0.105 : 0.050))

                LinearGradient(
                    colors: [accent.opacity(active ? 0.24 : 0.075), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                    HStack(spacing: compact ? 7 : 9) {
                        if configuration.showIcons {
                            ZStack {
                                RoundedRectangle(cornerRadius: compact ? 9 : 11, style: .continuous)
                                    .fill(accent.opacity(active ? 0.27 : 0.13))
                                Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                    .font(.system(size: compact ? 14 : 17, weight: .semibold))
                                    .foregroundStyle(active ? Color.white : accent)
                            }
                            .frame(width: compact ? 31 : 38, height: compact ? 31 : 38)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                                .font(.system(size: compact ? 10 : 12.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            if configuration.showSubtitles && !compact && !zone.subtitle.isEmpty {
                                Text(zone.subtitle)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.44))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if !compact {
                        Spacer(minLength: 0)
                        HStack(spacing: 6) {
                            if configuration.showActionBadges {
                                Label(zone.accepts.rawValue, systemImage: zone.accepts.symbol)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.42))
                            }
                            Spacer(minLength: 0)
                            if active {
                                Label("Release", systemImage: "arrow.down")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accent.opacity(0.90), in: Capsule())
                            } else if zone.action.isDestructive {
                                Label("Changes original", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 7.6, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange.opacity(0.80))
                            } else {
                                Text(zone.action.rawValue)
                                    .font(.system(size: 7.8, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.26))
                                    .lineLimit(1)
                            }
                        }
                    } else if active {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                }
                .padding(compact ? 8 : 11)
            }
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .stroke(active ? accent.opacity(configuration.highlightStrength) : Color.white.opacity(0.07), lineWidth: active ? 1.7 : 1)
            )
            .shadow(color: active ? accent.opacity(0.23) : Color.clear, radius: active ? 16 : 0, y: 5)
            .scaleEffect(active ? 1.018 : 1)
            .animation(.easeOut(duration: 0.13), value: active)
        }
    }
}

'''

replace_between(
    "Halo/NotchEngine/DisplayClock.swift",
    "@MainActor\nprivate struct HaloDropZoneBoardView: View {",
    "@MainActor\nprivate final class HaloDropZoneHostView: NSView {",
    runtime_board,
    "runtime board",
)

studio = r'''@MainActor
private struct HaloDropZoneStudioView: View {
    var body: some View {
        HaloDropZoneSettingsEditor()
            .frame(minWidth: 900, minHeight: 620)
    }
}

private enum HaloDropStudioTemplate: String, CaseIterable, Identifiable {
    case essentials = "Essentials"
    case everyday = "Everyday"
    case creator = "Creator"
    case power = "Power User"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .essentials: return "sparkles"
        case .everyday: return "square.grid.2x2"
        case .creator: return "wand.and.stars"
        case .power: return "bolt.fill"
        }
    }
    var subtitle: String {
        switch self {
        case .essentials: return "Shelf + preview"
        case .everyday: return "Four useful actions"
        case .creator: return "Images and exports"
        case .power: return "Six utility actions"
        }
    }
    var actions: [HaloDropZoneAction] {
        switch self {
        case .essentials: return [.shelf, .quickLook]
        case .everyday: return [.shelf, .quickLook, .copyDownloads, .copyPath]
        case .creator: return [.quickLook, .convertPNG, .convertJPEG, .copyDownloads, .shelf]
        case .power: return [.shelf, .quickLook, .compress, .extract, .copyPath, .duplicate]
        }
    }
}

private enum HaloDropStudioLook: String, CaseIterable, Identifiable {
    case halo = "Halo"
    case glass = "Soft Glass"
    case minimal = "Minimal"
    case compact = "Compact"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .halo: return "circle.hexagongrid.fill"
        case .glass: return "drop.fill"
        case .minimal: return "minus.rectangle"
        case .compact: return "rectangle.compress.vertical"
        }
    }
}

@MainActor
struct HaloDropZoneSettingsEditor: View {
    @ObservedObject private var store = HaloDropZoneSettingsStore.shared
    @State private var selectedZoneID: UUID?
    @State private var showAdvancedAppearance = false
    @State private var showAdvancedZone = false

    var body: some View {
        VStack(spacing: 0) {
            studioHeader
            Divider()

            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        quickSetup
                        livePreview
                        zoneStrip
                        layoutAndLook
                        if showAdvancedAppearance { advancedAppearance }
                    }
                    .padding(20)
                }
                .frame(minWidth: 540)

                Divider()

                ScrollView {
                    zoneInspector
                        .padding(18)
                }
                .frame(width: 330)
                .background(Color.primary.opacity(0.018))
            }
        }
        .onAppear { ensureSelection() }
        .onChange(of: store.configuration.zones) { _ in ensureSelection() }
    }

    private var studioHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Drop Zone Studio")
                    .font(.title2.bold())
                Text("Make dragging files feel instant, obvious and yours.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.configuration.zones.count) zone\(store.configuration.zones.count == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())

            Button("Reset") { store.reset(); selectedZoneID = store.configuration.zones.first?.id }
            Button { store.addZone(); selectedZoneID = store.configuration.zones.last?.id } label: {
                Label("Add Zone", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.configuration.zones.count >= 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var quickSetup: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Quick setup", subtitle: "Start from a useful layout, then change anything.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 9)], spacing: 9) {
                ForEach(HaloDropStudioTemplate.allCases) { preset in
                    Button { applyTemplate(preset) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: preset.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.rawValue).font(.callout.weight(.semibold))
                                Text(preset.subtitle).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionTitle("Live preview", subtitle: "Click a zone to edit it.")
                Spacer()
                Picker("Zones", selection: zoneCountBinding) {
                    ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .frame(width: 72)
            }

            HaloDropZoneInteractivePreview(
                configuration: store.configuration,
                selectedZoneID: selectedZoneID,
                onSelect: { selectedZoneID = $0 }
            )
            .frame(height: previewHeight)
        }
    }

    private var zoneStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Zones", subtitle: "Select one to edit. Order controls its position in the layout.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(store.configuration.zones.enumerated()), id: \.element.id) { index, zone in
                        Button { selectedZoneID = zone.id } label: {
                            HStack(spacing: 7) {
                                Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                    .foregroundStyle(zone.color.color)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                                        .font(.caption.weight(.semibold)).lineLimit(1)
                                    Text("Zone \(index + 1)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                (selectedZoneID == zone.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04)),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selectedZoneID == zone.id ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var layoutAndLook: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Layout & style", subtitle: "Visual choices first; precision controls stay out of the way.")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 8)], spacing: 8) {
                ForEach(HaloDropZoneLayout.allCases) { layout in
                    Button { setConfiguration(\.layout, layout) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: layout.symbol).font(.system(size: 17, weight: .semibold))
                            Text(layout.rawValue).font(.caption2.weight(.semibold)).lineLimit(1)
                        }
                        .foregroundStyle(store.configuration.layout == layout ? Color.accentColor : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            store.configuration.layout == layout ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(store.configuration.layout == layout ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(HaloDropStudioLook.allCases) { look in
                    Button { applyLook(look) } label: {
                        Label(look.rawValue, systemImage: look.symbol)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.16)) { showAdvancedAppearance.toggle() }
            } label: {
                Label(showAdvancedAppearance ? "Hide advanced appearance" : "Advanced appearance", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
        }
    }

    private var advancedAppearance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            sectionTitle("Advanced appearance", subtitle: "Fine-tune the board after choosing a look.")
            HStack { valueSlider("Padding", \.boardPadding, 0...28); valueSlider("Spacing", \.zoneSpacing, 2...24) }
            HStack { valueSlider("Corner radius", \.cornerRadius, 6...36); valueSlider("Background", \.backgroundOpacity, 0.45...1) }
            valueSlider("Hover emphasis", \.highlightStrength, 0.15...1)
            HStack(spacing: 16) {
                Toggle("Icons", isOn: configurationBinding(\.showIcons))
                Toggle("Subtitles", isOn: configurationBinding(\.showSubtitles))
                Toggle("Type badges", isOn: configurationBinding(\.showActionBadges))
            }
            TextField("Header title", text: configurationBinding(\.headerTitle))
            TextField("Header instruction", text: configurationBinding(\.headerSubtitle))
        }
    }

    @ViewBuilder private var zoneInspector: some View {
        if let index = selectedZoneIndex {
            let zone = zoneBinding(index)
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(zone.wrappedValue.color.color.opacity(0.14))
                        Image(systemName: zone.wrappedValue.symbol.isEmpty ? zone.wrappedValue.action.symbol : zone.wrappedValue.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(zone.wrappedValue.color.color)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Zone \(index + 1)").font(.caption).foregroundStyle(.secondary)
                        Text(zone.wrappedValue.title.isEmpty ? zone.wrappedValue.action.rawValue : zone.wrappedValue.title)
                            .font(.headline).lineLimit(1)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("What happens").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Action", selection: actionBinding(index)) {
                        ForEach(HaloDropZoneAction.allCases) { action in
                            Label(action.rawValue, systemImage: action.symbol).tag(action)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Picker("Accept", selection: zone.accepts) {
                        ForEach(HaloDropZoneAcceptance.allCases) { type in
                            Label(type.rawValue, systemImage: type.symbol).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Label").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("Title", text: zone.title)
                    TextField("Short description", text: zone.subtitle)
                    ColorPicker(
                        "Accent",
                        selection: Binding(
                            get: { zone.wrappedValue.color.color },
                            set: { color in var next = zone.wrappedValue; next.color = WidgetColor(color); zone.wrappedValue = next }
                        ),
                        supportsOpacity: false
                    )
                }

                if zone.wrappedValue.action == .rename {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Rename template").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("{name}-renamed", text: zone.parameter)
                        Text("Available: {name}, {ext}, {date}").font(.caption2).foregroundStyle(.secondary)
                    }
                } else if zone.wrappedValue.action == .copyFolder {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Destination").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        HStack {
                            Text(zone.wrappedValue.parameter.isEmpty ? "No folder chosen" : URL(fileURLWithPath: zone.wrappedValue.parameter).lastPathComponent)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Button("Choose…") { chooseFolder(for: index) }
                        }
                    }
                }

                if zone.wrappedValue.action != .shelf {
                    Toggle("Also keep in File Shelf", isOn: zone.alsoAddToShelf)
                }

                if zone.wrappedValue.action.isDestructive {
                    Label("This action changes the original item.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) { showAdvancedZone.toggle() }
                } label: {
                    Label(showAdvancedZone ? "Hide advanced" : "Advanced", systemImage: "gearshape")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)

                if showAdvancedZone {
                    TextField("SF Symbol", text: zone.symbol)
                }

                Divider()

                HStack(spacing: 7) {
                    Button { store.moveZone(from: index, by: -1) } label: { Image(systemName: "arrow.left") }
                        .disabled(index == 0)
                    Button { store.moveZone(from: index, by: 1) } label: { Image(systemName: "arrow.right") }
                        .disabled(index == store.configuration.zones.count - 1)
                    Button { duplicateZone(index) } label: { Image(systemName: "plus.square.on.square") }
                        .disabled(store.configuration.zones.count >= 8)
                    Spacer()
                    Button(role: .destructive) { removeSelectedZone(index) } label: { Image(systemName: "trash") }
                        .disabled(store.configuration.zones.count <= 1)
                }
                .buttonStyle(.bordered)
            }
        } else {
            ContentUnavailableView("Select a zone", systemImage: "square.dashed", description: Text("Choose a zone from the preview to edit it."))
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var selectedZoneIndex: Int? {
        guard let selectedZoneID else { return store.configuration.zones.indices.first }
        return store.configuration.zones.firstIndex(where: { $0.id == selectedZoneID }) ?? store.configuration.zones.indices.first
    }

    private var previewHeight: CGFloat {
        let count = store.configuration.zones.count
        let rows: Int
        switch store.configuration.layout {
        case .vertical: rows = min(count, 4)
        case .horizontal: rows = 1
        case .twoColumns: rows = Int(ceil(Double(count) / 2.0))
        case .threeColumns: rows = Int(ceil(Double(count) / 3.0))
        case .fourColumns: rows = Int(ceil(Double(count) / 4.0))
        case .spotlight: rows = count > 4 ? 2 : 1
        case .adaptive:
            let columns = count <= 2 ? count : count <= 4 ? 2 : count <= 6 ? 3 : 4
            rows = Int(ceil(Double(count) / Double(max(1, columns))))
        }
        return min(390, max(250, 170 + CGFloat(rows - 1) * 62))
    }

    private var zoneCountBinding: Binding<Int> {
        Binding(
            get: { store.configuration.zones.count },
            set: { requested in
                let count = min(8, max(1, requested))
                while store.configuration.zones.count < count { store.addZone() }
                while store.configuration.zones.count > count { store.removeZone(at: store.configuration.zones.count - 1) }
                ensureSelection()
            }
        )
    }

    private func applyTemplate(_ preset: HaloDropStudioTemplate) {
        var configuration = store.configuration
        configuration.zones = preset.actions.enumerated().map { HaloDropZone.preset($0.element, index: $0.offset) }
        configuration.layout = preset.actions.count <= 2 ? .horizontal : .adaptive
        configuration.normalize()
        store.configuration = configuration
        selectedZoneID = configuration.zones.first?.id
    }

    private func applyLook(_ look: HaloDropStudioLook) {
        var configuration = store.configuration
        switch look {
        case .halo:
            configuration.boardPadding = 10; configuration.zoneSpacing = 8; configuration.cornerRadius = 18
            configuration.backgroundOpacity = 0.94; configuration.highlightStrength = 0.88
            configuration.showIcons = true; configuration.showSubtitles = true; configuration.showActionBadges = true
        case .glass:
            configuration.boardPadding = 13; configuration.zoneSpacing = 10; configuration.cornerRadius = 22
            configuration.backgroundOpacity = 0.72; configuration.highlightStrength = 0.82
            configuration.showIcons = true; configuration.showSubtitles = true; configuration.showActionBadges = false
        case .minimal:
            configuration.boardPadding = 8; configuration.zoneSpacing = 6; configuration.cornerRadius = 14
            configuration.backgroundOpacity = 0.97; configuration.highlightStrength = 0.72
            configuration.showIcons = true; configuration.showSubtitles = false; configuration.showActionBadges = false
        case .compact:
            configuration.boardPadding = 5; configuration.zoneSpacing = 5; configuration.cornerRadius = 12
            configuration.backgroundOpacity = 0.95; configuration.highlightStrength = 1.0
            configuration.showIcons = true; configuration.showSubtitles = false; configuration.showActionBadges = true
        }
        configuration.normalize()
        store.configuration = configuration
    }

    private func actionBinding(_ index: Int) -> Binding<HaloDropZoneAction> {
        Binding(
            get: { store.configuration.zones[index].action },
            set: { action in
                guard store.configuration.zones.indices.contains(index) else { return }
                var configuration = store.configuration
                let old = configuration.zones[index]
                let preset = HaloDropZone.preset(action, index: index)
                configuration.zones[index].action = action
                if old.title.isEmpty || old.title == old.action.rawValue { configuration.zones[index].title = preset.title }
                if old.subtitle.isEmpty || old.subtitle == old.action.rawValue || old.subtitle == HaloDropZone.preset(old.action, index: index).subtitle {
                    configuration.zones[index].subtitle = preset.subtitle
                }
                if old.symbol.isEmpty || old.symbol == old.action.symbol { configuration.zones[index].symbol = action.symbol }
                if action == .rename && configuration.zones[index].parameter.isEmpty { configuration.zones[index].parameter = "{name}-renamed" }
                if action != .rename && action != .copyFolder { configuration.zones[index].parameter = "" }
                configuration.normalize()
                store.configuration = configuration
            }
        )
    }

    private func setConfiguration<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>, _ value: T) {
        var configuration = store.configuration
        configuration[keyPath: keyPath] = value
        configuration.normalize()
        store.configuration = configuration
    }

    private func configurationBinding<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>) -> Binding<T> {
        Binding(
            get: { store.configuration[keyPath: keyPath] },
            set: { setConfiguration(keyPath, $0) }
        )
    }

    private func zoneBinding(_ index: Int) -> Binding<HaloDropZone> {
        Binding(
            get: { store.configuration.zones[index] },
            set: { value in
                guard store.configuration.zones.indices.contains(index) else { return }
                var configuration = store.configuration
                configuration.zones[index] = value
                configuration.normalize()
                store.configuration = configuration
            }
        )
    }

    private func duplicateZone(_ index: Int) {
        guard store.configuration.zones.indices.contains(index), store.configuration.zones.count < 8 else { return }
        var configuration = store.configuration
        var copy = configuration.zones[index]
        copy.id = UUID()
        copy.title = copy.title.isEmpty ? copy.action.rawValue : copy.title + " Copy"
        configuration.zones.insert(copy, at: min(index + 1, configuration.zones.count))
        configuration.normalize()
        store.configuration = configuration
        selectedZoneID = copy.id
    }

    private func removeSelectedZone(_ index: Int) {
        guard store.configuration.zones.count > 1 else { return }
        store.removeZone(at: index)
        selectedZoneID = store.configuration.zones[min(index, store.configuration.zones.count - 1)].id
    }

    private func chooseFolder(for index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            var configuration = store.configuration
            configuration.zones[index].parameter = url.path
            store.configuration = configuration
        }
    }

    private func ensureSelection() {
        if let id = selectedZoneID, store.configuration.zones.contains(where: { $0.id == id }) { return }
        selectedZoneID = store.configuration.zones.first?.id
    }

    private func valueSlider(_ title: String, _ keyPath: WritableKeyPath<HaloDropZoneConfiguration, Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(String(format: "%.1f", store.configuration[keyPath: keyPath]))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: configurationBinding(keyPath), in: range)
        }
    }
}

@MainActor
private struct HaloDropZoneInteractivePreview: View {
    let configuration: HaloDropZoneConfiguration
    let selectedZoneID: UUID?
    let onSelect: (UUID) -> Void

    var body: some View {
        GeometryReader { proxy in
            let frames = HaloDropZoneLayoutResolver.frames(size: proxy.size, configuration: configuration)
            let dense = configuration.zones.count >= 6 || proxy.size.height < 270

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(configuration.backgroundOpacity))
                LinearGradient(colors: [Color.white.opacity(0.05), Color.clear, Color.accentColor.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor.opacity(0.15))
                        Image(systemName: "arrow.down.doc.fill").foregroundStyle(Color.accentColor)
                    }
                    .frame(width: 31, height: 31)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(configuration.headerTitle.isEmpty ? "Drop into Halo" : configuration.headerTitle)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        Text(configuration.headerSubtitle.isEmpty ? "Choose what happens next" : configuration.headerSubtitle)
                            .font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.42)).lineLimit(1)
                    }
                    Spacer()
                    Text("LIVE").font(.system(size: 7, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.30))
                }
                .padding(.horizontal, max(12, configuration.boardPadding + 2))
                .padding(.top, 11)

                ForEach(Array(configuration.zones.enumerated()), id: \.element.id) { index, zone in
                    if frames.indices.contains(index) {
                        let frame = frames[index]
                        Button { onSelect(zone.id) } label: {
                            previewCard(zone, selected: selectedZoneID == zone.id, dense: dense)
                        }
                        .buttonStyle(.plain)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08)))
            .foregroundStyle(.white)
        }
    }

    private func previewCard(_ zone: HaloDropZone, selected: Bool, dense: Bool) -> some View {
        GeometryReader { proxy in
            let compact = dense || proxy.size.width < 125 || proxy.size.height < 80
            let accent = zone.color.color
            VStack(alignment: .leading, spacing: compact ? 4 : 7) {
                HStack(spacing: 7) {
                    if configuration.showIcons {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(accent.opacity(selected ? 0.24 : 0.12))
                            Image(systemName: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                                .font(.system(size: compact ? 12 : 15, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(zone.title.isEmpty ? zone.action.rawValue : zone.title)
                            .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded)).lineLimit(1)
                        if configuration.showSubtitles && !compact && !zone.subtitle.isEmpty {
                            Text(zone.subtitle).font(.system(size: 8)).foregroundStyle(.white.opacity(0.40)).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if !compact {
                    Spacer(minLength: 0)
                    HStack {
                        if configuration.showActionBadges {
                            Label(zone.accepts.rawValue, systemImage: zone.accepts.symbol)
                                .font(.system(size: 7.5, weight: .semibold)).foregroundStyle(.white.opacity(0.38))
                        }
                        Spacer()
                        if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(accent) }
                    }
                }
            }
            .padding(compact ? 7 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(selected ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous).stroke(selected ? accent.opacity(0.78) : Color.white.opacity(0.07), lineWidth: selected ? 1.7 : 1))
            .shadow(color: selected ? accent.opacity(0.16) : Color.clear, radius: selected ? 12 : 0, y: 4)
        }
    }
}

'''

replace_between(
    "Halo/NotchEngine/DisplayClock.swift",
    "@MainActor\nprivate struct HaloDropZoneStudioView: View {",
    "// MARK: - Global file-drag monitor",
    studio,
    "studio",
)

replace_once(
    "Halo/NotchEngine/DisplayClock.swift",
    "contentRect: CGRect(x: 0, y: 0, width: 820, height: 760)",
    "contentRect: CGRect(x: 0, y: 0, width: 1040, height: 720)",
    "studio window size",
)
replace_once(
    "Halo/NotchEngine/DisplayClock.swift",
    "window.minSize = CGSize(width: 720, height: 620)",
    "window.minSize = CGSize(width: 900, height: 620)",
    "studio min size",
)

settings = r'''private struct ContextDropSettings: View {
    @ObservedObject private var zones = HaloDropZoneSettingsStore.shared
    @AppStorage("HaloContextDropEnabled") private var enabled = true
    @AppStorage("HaloContextDropUseFullNotchArea") private var usesFullNotchArea = true
    @AppStorage("HaloContextDropKeepClosedNotchContents") private var keepsClosedNotchContents = false
    @AppStorage("HaloContextDropPriority") private var priority = 100.0

    var body: some View {
        Section("Drag & Drop Context Interface") {
            Toggle("Enable Drop CI", isOn: $enabled)
            Text("Start dragging a real file or folder anywhere on your Mac and Halo can summon Drop CI immediately. The cursor does not need to reach the notch first.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Drop zones") {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.11))
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(zones.configuration.zones.count) custom zone\(zones.configuration.zones.count == 1 ? "" : "s")")
                        .font(.headline)
                    Text("\(zones.configuration.layout.rawValue) layout · click-to-edit live preview")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Customize Drop CI…") {
                    HaloDropZoneStudioWindowController.shared.show()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)

            HStack(spacing: 7) {
                ForEach(Array(zones.configuration.zones.prefix(5))) { zone in
                    Label(zone.title.isEmpty ? zone.action.rawValue : zone.title,
                          systemImage: zone.symbol.isEmpty ? zone.action.symbol : zone.symbol)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(zone.color.color.opacity(0.09), in: Capsule())
                        .foregroundStyle(zone.color.color)
                }
                if zones.configuration.zones.count > 5 {
                    Text("+\(zones.configuration.zones.count - 5)")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            Text("The studio gives you visual presets, a live clickable preview, per-zone actions and filters, custom labels/icons/colors, reorder controls, and advanced appearance only when you want it.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI priority") {
            Slider(value: $priority, in: 0...100, step: 1) { Text("Drop CI priority") }
            Text("Drop CI defaults to the highest priority because a drag is an immediate user action. Lower it if another Context Interface should keep ownership during file drags.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("CI surface") {
            Toggle("Use full notch area", isOn: $usesFullNotchArea)
            Toggle("Keep closed-notch contents visible", isOn: $keepsClosedNotchContents)
            Text("Halo automatically requests the space needed by your chosen zone layout.")
                .font(.caption).foregroundStyle(.secondary)
        }

        Section("Safety") {
            Label("Only genuine file/folder drag payloads can summon Drop CI.", systemImage: "checkmark.shield")
            Label("Destructive actions are clearly marked and never added by a preset unless you choose them.", systemImage: "lock.shield")
        }
    }
}

'''

replace_between(
    "Halo/Views/WorkspaceSettingsView.swift",
    "private struct ContextDropSettings: View {",
    "private struct ContextInterfaceCard: View {",
    settings,
    "context settings",
)

print("Drop CI v3 patch applied")
