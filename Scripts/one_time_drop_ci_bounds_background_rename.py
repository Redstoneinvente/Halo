from pathlib import Path


def replace_once(path, old, new, label):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, got {count}")
    p.write_text(text.replace(old, new, 1))


path = "Halo/NotchEngine/DisplayClock.swift"

replace_once(path,
'''enum HaloDropZoneAcceptance: String, Codable, CaseIterable, Identifiable {''',
'''enum HaloDropCIBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case halo = "Halo Glow"
    case solid = "Solid"
    case gradient = "Gradient"
    case glass = "Glass"
    case transparent = "Transparent"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .halo: return "sparkles.rectangle.stack"
        case .solid: return "rectangle.fill"
        case .gradient: return "circle.lefthalf.filled"
        case .glass: return "drop.fill"
        case .transparent: return "square.dashed"
        }
    }
}

enum HaloDropZoneAcceptance: String, Codable, CaseIterable, Identifiable {''',
"background enum")

replace_once(path,
'''    var backgroundOpacity = 0.94
    var highlightStrength = 0.85''',
'''    var backgroundOpacity = 0.94
    // Optional for backward compatibility with HaloDropZones.v2 payloads.
    var backgroundStyle: HaloDropCIBackgroundStyle? = .halo
    var backgroundPrimaryColor: WidgetColor? = WidgetColor(red: 0.025, green: 0.035, blue: 0.060)
    var backgroundSecondaryColor: WidgetColor? = WidgetColor(red: 0.045, green: 0.105, blue: 0.180)
    var backgroundAccentStrength: Double? = 0.16
    var highlightStrength = 0.85''',
"background config fields")

replace_once(path,
'''    var headerTitle = "Drop into Halo"
    var headerSubtitle = "Choose what should happen to the dragged item"

    mutating func normalize() {''',
'''    var headerTitle = "Drop into Halo"
    var headerSubtitle = "Choose what should happen to the dragged item"

    var resolvedBackgroundStyle: HaloDropCIBackgroundStyle { backgroundStyle ?? .halo }
    var resolvedBackgroundPrimaryColor: WidgetColor {
        backgroundPrimaryColor ?? WidgetColor(red: 0.025, green: 0.035, blue: 0.060)
    }
    var resolvedBackgroundSecondaryColor: WidgetColor {
        backgroundSecondaryColor ?? WidgetColor(red: 0.045, green: 0.105, blue: 0.180)
    }
    var resolvedBackgroundAccentStrength: Double { backgroundAccentStrength ?? 0.16 }

    mutating func normalize() {''',
"background resolved values")

replace_once(path,
'''        cornerRadius = min(36, max(6, cornerRadius))
        backgroundOpacity = min(1, max(0.45, backgroundOpacity))
        highlightStrength = min(1, max(0.15, highlightStrength))''',
'''        cornerRadius = min(36, max(6, cornerRadius))
        backgroundOpacity = min(1, max(0, backgroundOpacity))
        if backgroundStyle == nil { backgroundStyle = .halo }
        if backgroundPrimaryColor == nil { backgroundPrimaryColor = WidgetColor(red: 0.025, green: 0.035, blue: 0.060) }
        if backgroundSecondaryColor == nil { backgroundSecondaryColor = WidgetColor(red: 0.045, green: 0.105, blue: 0.180) }
        backgroundAccentStrength = min(0.8, max(0, backgroundAccentStrength ?? 0.16))
        highlightStrength = min(1, max(0.15, highlightStrength))''',
"background normalization")

# Make the layout use a hard safe inset and never create negative/oversized cells.
replace_once(path,
'''        let padding = CGFloat(configuration.boardPadding)
        let gap = CGFloat(configuration.zoneSpacing)
        let top = headerHeight + padding
        let availableHeight = max(20, size.height - top - footerHeight - padding)
        let rect = CGRect(
            x: padding,
            y: top,
            width: max(20, size.width - padding * 2),
            height: availableHeight
        )''',
'''        let padding = max(8, CGFloat(configuration.boardPadding))
        let gap = max(2, CGFloat(configuration.zoneSpacing))
        let top = headerHeight + padding
        let availableWidth = max(1, size.width - padding * 2)
        let availableHeight = max(1, size.height - top - footerHeight - padding)
        let rect = CGRect(
            x: padding,
            y: top,
            width: availableWidth,
            height: availableHeight
        ).intersection(CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4))''',
"safe layout rect")

# Replace rename with coordinated, security-scope-aware file move and filename sanitation.
old_rename = '''    private static func rename(_ url: URL, template: String) throws {
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var name = template
            .replacingOccurrences(of: "{name}", with: stem)
            .replacingOccurrences(of: "{ext}", with: ext)
            .replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = stem + "-renamed" }
        if !ext.isEmpty && !template.contains("{ext}") && URL(fileURLWithPath: name).pathExtension.isEmpty {
            name += "." + ext
        }
        let directory = url.deletingLastPathComponent()
        var destination = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = uniqueURL(
                in: directory,
                stem: destination.deletingPathExtension().lastPathComponent,
                extension: destination.pathExtension
            )
        }
        try FileManager.default.moveItem(at: url, to: destination)
    }
'''
new_rename = '''    private static func rename(_ url: URL, template: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var name = template
            .replacingOccurrences(of: "{name}", with: stem)
            .replacingOccurrences(of: "{ext}", with: ext)
            .replacingOccurrences(of: "{date}", with: formatter.string(from: Date()))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: "/", with: "-")
        if name.isEmpty { name = stem + "-renamed" }
        if !ext.isEmpty && !template.contains("{ext}") && URL(fileURLWithPath: name).pathExtension.isEmpty {
            name += "." + ext
        }

        let directory = url.deletingLastPathComponent()
        var destination = directory.appendingPathComponent(name)
        if destination.standardizedFileURL == url.standardizedFileURL || FileManager.default.fileExists(atPath: destination.path) {
            destination = uniqueURL(
                in: directory,
                stem: destination.deletingPathExtension().lastPathComponent,
                extension: destination.pathExtension
            )
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var moveError: Error?
        coordinator.coordinate(
            writingItemAt: url,
            options: .forMoving,
            writingItemAt: destination,
            options: [],
            error: &coordinationError
        ) { source, coordinatedDestination in
            do {
                try FileManager.default.moveItem(at: source, to: coordinatedDestination)
            } catch {
                moveError = error
            }
        }
        if let moveError { throw moveError }
        if let coordinationError { throw coordinationError }
    }
'''
replace_once(path, old_rename, new_rename, "rename implementation")

# Add reusable configurable background before the runtime board.
replace_once(path,
'''@MainActor
private struct HaloDropZoneBoardView: View {''',
'''@MainActor
private struct HaloDropCIBackgroundView: View {
    let configuration: HaloDropZoneConfiguration

    @ViewBuilder var body: some View {
        let primary = configuration.resolvedBackgroundPrimaryColor.color
        let secondary = configuration.resolvedBackgroundSecondaryColor.color
        let strength = configuration.resolvedBackgroundAccentStrength
        switch configuration.resolvedBackgroundStyle {
        case .halo:
            LinearGradient(
                colors: [primary, secondary.opacity(0.92), Color.accentColor.opacity(strength)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(configuration.backgroundOpacity)
        case .solid:
            primary.opacity(configuration.backgroundOpacity)
        case .gradient:
            LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(configuration.backgroundOpacity)
        case .glass:
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(primary.opacity(strength * 0.55))
                .opacity(configuration.backgroundOpacity)
        case .transparent:
            Color.clear
        }
    }
}

@MainActor
private struct HaloDropZoneBoardView: View {''',
"background view")

replace_once(path,
'''                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(configuration.backgroundOpacity))

                LinearGradient(
                    colors: [Color.white.opacity(0.055), Color.clear, Color.accentColor.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)''',
'''                HaloDropCIBackgroundView(configuration: configuration)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .allowsHitTesting(false)

                LinearGradient(
                    colors: [Color.white.opacity(0.045), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)''',
"runtime background")

replace_once(path,
'''            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .foregroundStyle(.white)''',
'''            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .foregroundStyle(.white)''',
"runtime root clipping")

replace_once(path,
'''            .shadow(color: active ? accent.opacity(0.23) : Color.clear, radius: active ? 16 : 0, y: 5)
            .scaleEffect(active ? 1.018 : 1)
            .animation(.easeOut(duration: 0.13), value: active)''',
'''            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .shadow(color: active ? accent.opacity(0.18) : Color.clear, radius: active ? 10 : 0, y: 3)
            .animation(.easeOut(duration: 0.13), value: active)''',
"runtime card clipping")

replace_once(path,
'''        registerForDraggedTypes([.fileURL])
        autoresizingMask = [.width, .height]
        hosting.sizingOptions = []''',
'''        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.masksToBounds = true
        autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = true
        hosting.sizingOptions = []''',
"host masks")

# Delay rename until Finder's drag session has concluded.
replace_once(path,
'''        let zone = settings.configuration.zones[index]
        let result = HaloDropZoneActionExecutor.perform(
            zone: zone,
            urls: urls,
            shelfHandler: originalDropHandler,
            closeHandler: { [weak target] in target?.dragStateHandler?(false, 0) }
        )
        completeDrop(result: result)''',
'''        let zone = settings.configuration.zones[index]
        if zone.action == .rename {
            dropHandled = true
            model.result = "Renaming…"
            let shelf = originalDropHandler
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self, weak target] in
                guard let self else { return }
                let result = HaloDropZoneActionExecutor.perform(
                    zone: zone,
                    urls: urls,
                    shelfHandler: shelf,
                    closeHandler: { target?.dragStateHandler?(false, 0) }
                )
                self.completeDrop(result: result)
            }
            return
        }

        let result = HaloDropZoneActionExecutor.perform(
            zone: zone,
            urls: urls,
            shelfHandler: originalDropHandler,
            closeHandler: { [weak target] in target?.dragStateHandler?(false, 0) }
        )
        completeDrop(result: result)''',
"deferred rename")

# Add a first-class background editor below visual looks.
replace_once(path,
'''            HStack(spacing: 8) {
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

            Button {''',
'''            HStack(spacing: 8) {
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

            VStack(alignment: .leading, spacing: 10) {
                Text("CI background").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), spacing: 7)], spacing: 7) {
                    ForEach(HaloDropCIBackgroundStyle.allCases) { style in
                        Button { backgroundStyleBinding.wrappedValue = style } label: {
                            Label(style.rawValue, systemImage: style.symbol)
                                .font(.caption2.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .foregroundStyle(store.configuration.resolvedBackgroundStyle == style ? Color.accentColor : Color.primary)
                                .background(
                                    store.configuration.resolvedBackgroundStyle == style ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if store.configuration.resolvedBackgroundStyle != .transparent {
                    HStack(spacing: 14) {
                        ColorPicker("Primary", selection: backgroundPrimaryBinding, supportsOpacity: false)
                        if store.configuration.resolvedBackgroundStyle == .gradient || store.configuration.resolvedBackgroundStyle == .halo {
                            ColorPicker("Secondary", selection: backgroundSecondaryBinding, supportsOpacity: false)
                        }
                    }
                    HStack(spacing: 10) {
                        Text("Opacity").font(.caption).foregroundStyle(.secondary)
                        Slider(value: configurationBinding(\\.backgroundOpacity), in: 0.15...1)
                        Text(String(format: "%.0f%%", store.configuration.backgroundOpacity * 100))
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34)
                    }
                    if store.configuration.resolvedBackgroundStyle == .halo || store.configuration.resolvedBackgroundStyle == .glass {
                        HStack(spacing: 10) {
                            Text("Tint").font(.caption).foregroundStyle(.secondary)
                            Slider(value: backgroundAccentBinding, in: 0...0.8)
                        }
                    }
                } else {
                    Text("Transparent uses the surface underneath the Drop CI.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(11)
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Button {''',
"background settings UI")

# Remove duplicate background slider from advanced appearance.
replace_once(path,
'''            HStack { valueSlider("Corner radius", \\.cornerRadius, 6...36); valueSlider("Background", \\.backgroundOpacity, 0.45...1) }''',
'''            valueSlider("Corner radius", \\.cornerRadius, 6...36)''',
"advanced background slider")

# Look presets now also choose a matching background mode.
replace_once(path,
'''        case .halo:
            configuration.boardPadding = 10; configuration.zoneSpacing = 8; configuration.cornerRadius = 18
            configuration.backgroundOpacity = 0.94; configuration.highlightStrength = 0.88''',
'''        case .halo:
            configuration.boardPadding = 10; configuration.zoneSpacing = 8; configuration.cornerRadius = 18
            configuration.backgroundStyle = .halo
            configuration.backgroundOpacity = 0.94; configuration.highlightStrength = 0.88''',
"halo look bg")
replace_once(path,
'''        case .glass:
            configuration.boardPadding = 13; configuration.zoneSpacing = 10; configuration.cornerRadius = 22
            configuration.backgroundOpacity = 0.72; configuration.highlightStrength = 0.82''',
'''        case .glass:
            configuration.boardPadding = 13; configuration.zoneSpacing = 10; configuration.cornerRadius = 22
            configuration.backgroundStyle = .glass
            configuration.backgroundOpacity = 0.78; configuration.highlightStrength = 0.82''',
"glass look bg")
replace_once(path,
'''        case .minimal:
            configuration.boardPadding = 8; configuration.zoneSpacing = 6; configuration.cornerRadius = 14
            configuration.backgroundOpacity = 0.97; configuration.highlightStrength = 0.72''',
'''        case .minimal:
            configuration.boardPadding = 8; configuration.zoneSpacing = 6; configuration.cornerRadius = 14
            configuration.backgroundStyle = .solid
            configuration.backgroundOpacity = 0.97; configuration.highlightStrength = 0.72''',
"minimal look bg")
replace_once(path,
'''        case .compact:
            configuration.boardPadding = 5; configuration.zoneSpacing = 5; configuration.cornerRadius = 12
            configuration.backgroundOpacity = 0.95; configuration.highlightStrength = 1.0''',
'''        case .compact:
            configuration.boardPadding = 5; configuration.zoneSpacing = 5; configuration.cornerRadius = 12
            configuration.backgroundStyle = .halo
            configuration.backgroundOpacity = 0.95; configuration.highlightStrength = 1.0''',
"compact look bg")

# Bind optional, backward-compatible background values cleanly.
replace_once(path,
'''    private func configurationBinding<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>) -> Binding<T> {
        Binding(
            get: { store.configuration[keyPath: keyPath] },
            set: { setConfiguration(keyPath, $0) }
        )
    }

    private func zoneBinding''',
'''    private func configurationBinding<T>(_ keyPath: WritableKeyPath<HaloDropZoneConfiguration, T>) -> Binding<T> {
        Binding(
            get: { store.configuration[keyPath: keyPath] },
            set: { setConfiguration(keyPath, $0) }
        )
    }

    private var backgroundStyleBinding: Binding<HaloDropCIBackgroundStyle> {
        Binding(
            get: { store.configuration.resolvedBackgroundStyle },
            set: { style in var next = store.configuration; next.backgroundStyle = style; next.normalize(); store.configuration = next }
        )
    }

    private var backgroundPrimaryBinding: Binding<Color> {
        Binding(
            get: { store.configuration.resolvedBackgroundPrimaryColor.color },
            set: { color in var next = store.configuration; next.backgroundPrimaryColor = WidgetColor(color); next.normalize(); store.configuration = next }
        )
    }

    private var backgroundSecondaryBinding: Binding<Color> {
        Binding(
            get: { store.configuration.resolvedBackgroundSecondaryColor.color },
            set: { color in var next = store.configuration; next.backgroundSecondaryColor = WidgetColor(color); next.normalize(); store.configuration = next }
        )
    }

    private var backgroundAccentBinding: Binding<Double> {
        Binding(
            get: { store.configuration.resolvedBackgroundAccentStrength },
            set: { value in var next = store.configuration; next.backgroundAccentStrength = value; next.normalize(); store.configuration = next }
        )
    }

    private func zoneBinding''',
"background bindings")

# Preview uses the same background and hard clipping as runtime.
replace_once(path,
'''                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(configuration.backgroundOpacity))
                LinearGradient(colors: [Color.white.opacity(0.05), Color.clear, Color.accentColor.opacity(0.055)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))''',
'''                HaloDropCIBackgroundView(configuration: configuration)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                LinearGradient(colors: [Color.white.opacity(0.04), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))''',
"preview background")

replace_once(path,
'''            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08)))
            .foregroundStyle(.white)''',
'''            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08)))
            .foregroundStyle(.white)''',
"preview root clipping")

replace_once(path,
'''            .background(Color.white.opacity(selected ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous).stroke(selected ? accent.opacity(0.78) : Color.white.opacity(0.07), lineWidth: selected ? 1.7 : 1))
            .shadow(color: selected ? accent.opacity(0.16) : Color.clear, radius: selected ? 12 : 0, y: 4)''',
'''            .background(Color.white.opacity(selected ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous).stroke(selected ? accent.opacity(0.78) : Color.white.opacity(0.07), lineWidth: selected ? 1.7 : 1))
            .shadow(color: selected ? accent.opacity(0.12) : Color.clear, radius: selected ? 8 : 0, y: 3)''',
"preview card clipping")

print("Drop CI bounds/background/rename patch applied")
