from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing block: {label}")
    return text.replace(old, new, 1)

# -----------------------------------------------------------------------------
# Context music model: explicit safe margins and fully independent color toggles.
# -----------------------------------------------------------------------------
models_path = Path("Halo/Core/WorkspaceModels.swift")
models = models_path.read_text()
models = replace_once(
    models,
    '''    var songTextColors: Bool?\n    var songControlColors: Bool?\n    var songVisualizerColors: Bool?\n    var songBackgroundColors: Bool?\n    var resolvedLayoutMode: ContextMusicLayoutMode { layoutMode ?? .hero }''',
    '''    var songTextColors: Bool?\n    var songControlColors: Bool?\n    var songVisualizerColors: Bool?\n    var songBackgroundColors: Bool?\n    var horizontalMargin: Double?\n    var topMargin: Double?\n    var bottomMargin: Double?\n    var resolvedLayoutMode: ContextMusicLayoutMode { layoutMode ?? .hero }''',
    "context margin fields"
)
models = replace_once(
    models,
    '''    var usesSongTextColors: Bool { songTextColors ?? false }\n    var usesSongControlColors: Bool { songControlColors ?? false }\n    var usesSongVisualizerColors: Bool { songVisualizerColors ?? true }\n    var usesSongBackgroundColors: Bool { songBackgroundColors ?? false }\n    func validated() throws -> ContextMusicOptions {\n        guard [artworkSize, fontSize, backgroundOpacity, artworkBackgroundBlur ?? 12, artworkBackgroundDim ?? 0.38,\n               spacing ?? 12, cornerRadius ?? 18, controlSize ?? 24, vinylRPM ?? 8,\n               lyricSyncOffset ?? 0, lyricFontSize ?? 16].allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }''',
    '''    var usesSongTextColors: Bool { songTextColors ?? false }\n    var usesSongControlColors: Bool { songControlColors ?? false }\n    var usesSongVisualizerColors: Bool { songVisualizerColors ?? true }\n    var usesSongBackgroundColors: Bool { songBackgroundColors ?? false }\n    var resolvedHorizontalMargin: Double { min(120, max(0, horizontalMargin ?? max(18, resolvedSpacing * 1.25))) }\n    var resolvedTopMargin: Double { min(160, max(0, topMargin ?? 0)) }\n    var resolvedBottomMargin: Double { min(120, max(0, bottomMargin ?? max(10, resolvedSpacing * 0.55))) }\n    func validated() throws -> ContextMusicOptions {\n        guard [artworkSize, fontSize, backgroundOpacity, artworkBackgroundBlur ?? 12, artworkBackgroundDim ?? 0.38,\n               spacing ?? 12, cornerRadius ?? 18, controlSize ?? 24, vinylRPM ?? 8,\n               lyricSyncOffset ?? 0, lyricFontSize ?? 16, horizontalMargin ?? 18, topMargin ?? 0, bottomMargin ?? 10].allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }''',
    "context resolved margins"
)
models = replace_once(
    models,
    '''        if lyricSyncOffset != nil { result.lyricSyncOffset = resolvedLyricSyncOffset }\n        if lyricFontSize != nil { result.lyricFontSize = resolvedLyricFontSize }\n        return result''',
    '''        if lyricSyncOffset != nil { result.lyricSyncOffset = resolvedLyricSyncOffset }\n        if lyricFontSize != nil { result.lyricFontSize = resolvedLyricFontSize }\n        if horizontalMargin != nil { result.horizontalMargin = resolvedHorizontalMargin }\n        if topMargin != nil { result.topMargin = resolvedTopMargin }\n        if bottomMargin != nil { result.bottomMargin = resolvedBottomMargin }\n        return result''',
    "context margin validation"
)
models_path.write_text(models)

# -----------------------------------------------------------------------------
# Context settings UI: expose margin controls next to surface ownership controls.
# -----------------------------------------------------------------------------
settings_path = Path("Halo/Views/WorkspaceSettingsView.swift")
settings = settings_path.read_text()
settings = replace_once(
    settings,
    '''    private var onlineLyrics: Binding<Bool> { Binding(get: { options.wrappedValue.usesOnlineLyrics }, set: { options.wrappedValue.lyricsOnline = $0 }) }\n    private var visualizerStyle: Binding<PlaybackAnimation> { Binding(get: { options.wrappedValue.resolvedVisualizerStyle }, set: { options.wrappedValue.visualizerStyle = $0 }) }\n    private func boolBinding''',
    '''    private var onlineLyrics: Binding<Bool> { Binding(get: { options.wrappedValue.usesOnlineLyrics }, set: { options.wrappedValue.lyricsOnline = $0 }) }\n    private var visualizerStyle: Binding<PlaybackAnimation> { Binding(get: { options.wrappedValue.resolvedVisualizerStyle }, set: { options.wrappedValue.visualizerStyle = $0 }) }\n    private var horizontalMargin: Binding<Double> { Binding(get: { options.wrappedValue.resolvedHorizontalMargin }, set: { options.wrappedValue.horizontalMargin = $0 }) }\n    private var topMargin: Binding<Double> { Binding(get: { options.wrappedValue.resolvedTopMargin }, set: { options.wrappedValue.topMargin = $0 }) }\n    private var bottomMargin: Binding<Double> { Binding(get: { options.wrappedValue.resolvedBottomMargin }, set: { options.wrappedValue.bottomMargin = $0 }) }\n    private func boolBinding''',
    "context margin bindings"
)
settings = replace_once(
    settings,
    '''            Toggle("Keep closed-notch contents visible", isOn: $keepClosedNotchContents)\n            Text("Controls whether the Closed Notch contents remain visible while Music CI is active. This setting is independent from the normal opened-notch Appearance setting.")\n                .font(.caption).foregroundStyle(.secondary)\n        }''',
    '''            Toggle("Keep closed-notch contents visible", isOn: $keepClosedNotchContents)\n            Text("Controls whether the Closed Notch contents remain visible while Music CI is active. This setting is independent from the normal opened-notch Appearance setting.")\n                .font(.caption).foregroundStyle(.secondary)\n            Divider()\n            Text("Content safe margins").font(.headline)\n            PreciseSlider(title: "Horizontal margin", value: horizontalMargin, range: 0...120, step: 1, suffix: "pt")\n            PreciseSlider(title: "Extra top margin", value: topMargin, range: 0...160, step: 1, suffix: "pt")\n            PreciseSlider(title: "Bottom margin", value: bottomMargin, range: 0...120, step: 1, suffix: "pt")\n            Text("Margins are included in the CI's requested surface size, so increasing them moves content inward instead of clipping it outside the notch.")\n                .font(.caption).foregroundStyle(.secondary)\n        }''',
    "context surface margin UI"
)
settings_path.write_text(settings)

# -----------------------------------------------------------------------------
# Audio / Music CI rendering: make size account for real insets and isolate colors.
# -----------------------------------------------------------------------------
surface_path = Path("Halo/Views/SurfaceView.swift")
surface = surface_path.read_text()
surface = replace_once(
    surface,
    '''    @Environment(\\.accessibilityReduceMotion) private var reduceMotion\n    private var safeInset: Double { max(18, options.resolvedSpacing * 1.25) }\n    private var contentTopInset: Double {\n        guard usesFullNotchArea else { return max(16, safeInset * 0.75) }\n        if keepsClosedNotchContents { return max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5)) }\n        return max(16, surfaceState.compactHeight * 0.68)\n    }\n    private var controlsTopInset: Double {\n        if usesFullNotchArea && keepsClosedNotchContents { return max(12, surfaceState.compactHeight + 6) }\n        return max(12, safeInset * 0.65)\n    }''',
    '''    @Environment(\\.accessibilityReduceMotion) private var reduceMotion\n    private var safeInset: Double { options.resolvedHorizontalMargin }\n    private var contentTopInset: Double {\n        let base: Double\n        if !usesFullNotchArea {\n            base = max(16, max(18, options.resolvedSpacing * 1.25) * 0.75)\n        } else if keepsClosedNotchContents {\n            base = max(16, surfaceState.compactHeight + max(6, options.resolvedSpacing * 0.5))\n        } else {\n            base = max(16, surfaceState.compactHeight * 0.68)\n        }\n        return base + options.resolvedTopMargin\n    }\n    private var controlsTopInset: Double {\n        let base = usesFullNotchArea && keepsClosedNotchContents\n            ? max(12, surfaceState.compactHeight + 6)\n            : max(12, max(18, options.resolvedSpacing * 1.25) * 0.65)\n        return base + options.resolvedTopMargin\n    }''',
    "context safe insets"
)
surface = replace_once(
    surface,
    '''         String(options.resolvedLyricFontSize), options.resolvedVisualizerStyle.rawValue,\n         String(options.resolvedSpacing), String(options.resolvedControlSize), String(visualizerFullWidth),\n         String(usesFullNotchArea), String(keepsClosedNotchContents)].joined(separator: "|")\n    }\n    private var songColors: [Color] { media.artworkColors.map(\\.color) }\n    private var primarySongColor: Color { songColors.first ?? options.textColor.color }\n    private var effectiveTextColor: Color { options.usesSongTextColors && !songColors.isEmpty ? primarySongColor : options.textColor.color }\n    private var effectiveControlColor: Color { options.usesSongControlColors && !songColors.isEmpty ? primarySongColor : effectiveTextColor }''',
    '''         String(options.resolvedLyricFontSize), options.resolvedVisualizerStyle.rawValue,\n         String(options.resolvedSpacing), String(options.resolvedControlSize), String(visualizerFullWidth),\n         String(options.resolvedHorizontalMargin), String(options.resolvedTopMargin), String(options.resolvedBottomMargin),\n         String(usesFullNotchArea), String(keepsClosedNotchContents)].joined(separator: "|")\n    }\n    private var songColors: [Color] { media.artworkColors.map(\\.color) }\n    private var baseTextColor: Color { options.textColor.color }\n    private var primarySongColor: Color { songColors.first ?? baseTextColor }\n    private var effectiveTextColor: Color { options.usesSongTextColors && !songColors.isEmpty ? primarySongColor : baseTextColor }\n    private var effectiveControlColor: Color { options.usesSongControlColors && !songColors.isEmpty ? primarySongColor : baseTextColor }\n    private var effectiveVisualizerColor: Color { options.usesSongVisualizerColors && !songColors.isEmpty ? primarySongColor : baseTextColor }\n    private var visualizerPalette: [WidgetColor] { options.usesSongVisualizerColors ? media.artworkColors : [] }\n    private var backgroundGradientColors: [Color] {\n        options.usesSongBackgroundColors && !songColors.isEmpty ? Array(songColors.prefix(3)) : [.blue, .purple]\n    }''',
    "context color isolation"
)
surface = replace_once(
    surface,
    '''                .padding(.horizontal, safeInset)\n                .padding(.top, contentTopInset)\n                .padding(.bottom, max(10, safeInset * 0.55))''',
    '''                .padding(.horizontal, safeInset)\n                .padding(.top, contentTopInset)\n                .padding(.bottom, options.resolvedBottomMargin)''',
    "context content padding"
)
surface = replace_once(
    surface,
    '''        return CGSize(width: width, height: min(700, max(150, innerHeight + 18)))''',
    '''        let legacyHorizontalMargin = max(18, options.resolvedSpacing * 1.25)\n        let extraHorizontalSpace = max(0, options.resolvedHorizontalMargin - legacyHorizontalMargin) * 2\n        let requestedWidth = min(760, width + extraHorizontalSpace)\n        let requestedHeight = innerHeight + contentTopInset + options.resolvedBottomMargin\n        return CGSize(width: requestedWidth, height: min(700, max(150, requestedHeight)))''',
    "context preferred surface size"
)
surface = replace_once(
    surface,
    '''            case .gradient:\n                LinearGradient(colors: songColors.isEmpty ? [.blue, .purple] : Array(songColors.prefix(3)), startPoint: .topLeading, endPoint: .bottomTrailing)\n                    .opacity(options.backgroundOpacity)\n            default:\n                Color.black.opacity(options.backgroundOpacity)\n            }\n            if options.usesSongBackgroundColors, !songColors.isEmpty {\n                LinearGradient(colors: Array(songColors.prefix(2)), startPoint: .topLeading, endPoint: .bottomTrailing)\n                    .opacity(min(0.78, max(0.16, options.backgroundOpacity)))\n                    .blendMode(.plusLighter)\n            }''',
    '''            case .gradient:\n                LinearGradient(colors: backgroundGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)\n                    .opacity(options.backgroundOpacity)\n            default:\n                Color.black.opacity(options.backgroundOpacity)\n            }\n            if options.usesSongBackgroundColors, !songColors.isEmpty, options.background != .gradient {\n                LinearGradient(colors: Array(songColors.prefix(2)), startPoint: .topLeading, endPoint: .bottomTrailing)\n                    .opacity(min(0.62, max(0.12, options.backgroundOpacity * 0.82)))\n                    .blendMode(.plusLighter)\n            }''',
    "context background color isolation"
)
surface = replace_once(
    surface,
    '''                .foregroundColor(index == activeWord ? primarySongColor : effectiveTextColor.opacity(0.5))''',
    '''                .foregroundColor(index == activeWord ? effectiveTextColor : effectiveTextColor.opacity(0.5))''',
    "lyric text color isolation"
)
surface = replace_once(
    surface,
    '''            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.isPlaying, enabled: true,\n                               options: configured, palette: media.artworkColors, fallback: effectiveControlColor)''',
    '''            PlaybackVisualizer(kind: options.resolvedVisualizerStyle, playing: media.isPlaying, enabled: true,\n                               options: configured, palette: visualizerPalette, fallback: effectiveVisualizerColor)''',
    "visualizer color isolation"
)
surface_path.write_text(surface)

# -----------------------------------------------------------------------------
# Closed notch renderer: exact footprints and no standalone event sizing with HUD.
# -----------------------------------------------------------------------------
closed_path = Path("Halo/Views/ClosedNotchView.swift")
closed = closed_path.read_text()
closed = replace_once(
    closed,
    '''        return settings.expandForEvent && !itemIsVisible && decorationSize <= 0 && artworkFootprint <= 0''',
    '''        return settings.expandForEvent && !itemIsVisible && decorationSize <= 0 && artworkFootprint <= 0 && hudReservedWidth <= 0''',
    "power standalone HUD sibling"
)
closed = replace_once(
    closed,
    '''        if let decoration, decorationSize > 0 {\n            SideDecorationView(options: decoration, playing: media.isPlaying, lowPower: system.lowPower, maximumHeight: decorationSize)\n        }''',
    '''        if let decoration, decorationSize > 0 {\n            SideDecorationView(options: decoration, playing: media.isPlaying, lowPower: system.lowPower, maximumHeight: decorationSize)\n                .frame(width: decorationSize, height: decorationSize, alignment: .center)\n                .clipped()\n        }''',
    "decoration exact footprint"
)
closed_path.write_text(closed)

# -----------------------------------------------------------------------------
# Window manager: align auto-fit measurements with renderer and throttle expensive
# appearance reconciliation while sliders are being dragged.
# -----------------------------------------------------------------------------
wm_path = Path("Halo/NotchEngine/WindowManager.swift")
wm = wm_path.read_text()
wm = replace_once(
    wm,
    '''        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)\n            .receive(on: RunLoop.main).sink { [weak self] _ in\n                DispatchQueue.main.async { self?.reconcile() }\n            }.store(in: &subscriptions)''',
    '''        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)\n            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)\n            .sink { [weak self] _ in self?.reconcile() }\n            .store(in: &subscriptions)''',
    "defaults reconcile debounce"
)
wm = replace_once(
    wm,
    '''        }\n            .removeDuplicates().dropFirst().receive(on: DispatchQueue.main)\n            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)''',
    '''        }\n            .removeDuplicates().dropFirst()\n            .throttle(for: .milliseconds(33), scheduler: DispatchQueue.main, latest: true)\n            .sink { [weak self] _ in self?.reconcile() }.store(in: &subscriptions)''',
    "workspace appearance reconcile throttle"
)
wm = replace_once(
    wm,
    '''        let targetItem = side == .left ? items.left : items.right\n        let targetDecoration = side == .left ? options.leftDecoration : options.rightDecoration\n        let hasSibling = itemIsVisible(targetItem) || (targetDecoration?.isVisible(playing: playing) ?? false)\n        let minimumSideWidth''',
    '''        let targetItem = side == .left ? items.left : items.right\n        let targetDecoration = side == .left ? options.leftDecoration : options.rightDecoration\n        var artwork = options.artworkOptions ?? ClosedArtworkOptions()\n        if options.artworkOptions == nil, let legacy = options.mediaOptions, legacy.artwork != .none {\n            artwork.enabled = true; artwork.mode = legacy.artwork; artwork.size = legacy.artworkSize\n        }\n        let hasArtworkSibling: Bool = {\n            guard playing, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return false }\n            switch artwork.side {\n            case .left: return side == .left\n            case .right: return side == .right\n            case .automatic:\n                if options.left == .media || options.left == .visualizer { return side == .left }\n                if options.right == .media || options.right == .visualizer { return side == .right }\n                return side == .right\n            }\n        }()\n        let hasSibling = itemIsVisible(targetItem) ||\n            (targetDecoration?.isVisible(playing: playing) ?? false) || hasArtworkSibling\n        let minimumSideWidth''',
    "power artwork sibling"
)
wm = replace_once(
    wm,
    '''            var leftDemand = autoFit ? sides.left : sides.decorationLeft\n            var rightDemand = autoFit ? sides.right : sides.decorationRight\n\n            if let hud''',
    '''            var leftDemand = autoFit ? sides.left : sides.decorationLeft\n            var rightDemand = autoFit ? sides.right : sides.decorationRight\n            // Transient power events must remain readable even when global auto-fit is disabled.\n            if let power {\n                if power.side == .left { leftDemand = max(leftDemand, sides.left) }\n                else { rightDemand = max(rightDemand, sides.right) }\n            }\n\n            if let hud''',
    "power fit when auto-fit off"
)
wm = replace_once(
    wm,
    '''        let size = min(options.fontSize, max(1, baseCompactHeight - 2 * options.contentPaddingY) / 1.25)\n        let font = NSFont.systemFont(ofSize: size)\n        let slotMargins = 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin''',
    '''        let innerHeight = max(1, baseCompactHeight - 2 * options.contentPaddingY)\n        let size = min(options.fontSize, innerHeight / 1.25)\n        let font = NSFont.systemFont(ofSize: size)\n        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)\n        let slotMargins = 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin''',
    "closed notch shared height"
)
wm = replace_once(
    wm,
    '''                case .date: content = textWidth("Sep 28", font: font)\n                case .timer: content = textWidth("88:88:88", font: font) + size\n                case .battery: content = textWidth("100%", font: font) + size + 5\n                case .media: content = mediaWidth()\n                case .visualizer: content = playing ? (options.visualizer ?? VisualizerOptions()).width : 0\n                case .mirror: content = 112\n                case .files: content = textWidth(String(store.files.count), font: font) + size + 5\n                case .activity:\n                    content = activity.map {\n                        let title = textWidth(String($0.title.prefix(80)), font: font)\n                        let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))\n                        let detail = $0.detail.isEmpty ? 0 : textWidth(String($0.detail.prefix(80)), font: detailFont)\n                        let icon = max(12, size)\n                        let text = max(title, detail)\n                        let progress = $0.progress == nil ? 0 : elementGap + 38\n                        return icon + elementGap + text + progress + 2\n                    } ?? 0''',
    '''                case .date: content = textWidth("Sep 28", font: font)\n                case .timer:\n                    if store.deadline != nil {\n                        content = textWidth("88:88:88", font: digitFont)\n                    } else {\n                        let label = store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready"\n                        content = max(12, size) + elementGap + textWidth(label, font: font)\n                    }\n                case .battery:\n                    let value = store.workspace.system.battery.map { "\\($0)%" } ?? ""\n                    content = value.isEmpty ? max(12, size) : max(12, size) + 5 + textWidth(value, font: digitFont)\n                case .media: content = mediaWidth()\n                case .visualizer: content = playing ? (options.visualizer ?? VisualizerOptions()).width : 0\n                case .mirror: content = 112\n                case .files: content = max(12, size) + 5 + textWidth(String(store.files.count), font: digitFont)\n                case .activity:\n                    content = activity.map {\n                        let title = textWidth(String($0.title.prefix(80)), font: font)\n                        let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))\n                        let detail = $0.detail.isEmpty ? 0 : textWidth(String($0.detail.prefix(80)), font: detailFont)\n                        let icon = max(12, size)\n                        let text = max(title, detail)\n                        let progress = $0.progress == nil ? 0 : elementGap + 38\n                        return min(240, icon + elementGap + text + progress + 2)\n                    } ?? 0''',
    "closed item measurements"
)
wm = replace_once(
    wm,
    '''        if let artworkTarget {\n            let artworkWidth = artwork.size + 2 * artwork.padding + artwork.margin''',
    '''        if let artworkTarget {\n            let renderedArtworkSize = max(1, min(artwork.size, innerHeight - 2 * artwork.padding))\n            let artworkWidth = renderedArtworkSize + 2 * artwork.padding + artwork.margin''',
    "closed artwork measured render size"
)
wm_path.write_text(wm)

print("Refined closed-notch sizing, CI safe margins/colors, and surface update performance")
