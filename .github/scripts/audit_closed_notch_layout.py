from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing pattern: {label}")
    return text.replace(old, new, 1)

# 1) Shared closed-notch layout metrics used by both rendering and window sizing.
p = Path("Halo/Core/SurfaceModels.swift")
s = p.read_text()
anchor = '''enum ClosedWingSizing {
    static func extents(base: Double, camera: Double, left: Double, right: Double,
                        expansion: Double, leftLive: Bool, rightLive: Bool) -> (left: Double, right: Double) {
        let baseSide = max(0, (base - camera) / 2)
        let liveCount = (leftLive ? 1 : 0) + (rightLive ? 1 : 0)
        let extra = liveCount > 0 ? max(0, expansion - camera - 2 * baseSide) / Double(liveCount) : 0
        return (max(left, baseSide + (leftLive ? extra : 0)),
                max(right, baseSide + (rightLive ? extra : 0)))
    }
}
'''
insert = anchor + '''
/// Canonical spacing model for the closed notch. Rendering and dynamic window sizing must use
/// the same insets/gaps or the surface grows by a different amount than the content it contains.
/// Default padding compresses gracefully at very small closed heights (16–24 pt), while explicit
/// user values remain exact.
struct ClosedNotchLayoutMetrics: Equatable {
    let verticalPadding: Double
    let horizontalPadding: Double
    let cameraMargin: Double
    let outerMargin: Double
    let elementSpacing: Double
    let contentHeight: Double

    init(options: ClosedNotchOptions, height: Double) {
        let safeHeight = max(1, height)
        verticalPadding = min(options.contentPaddingY, max(0, (safeHeight - 8) / 2))
        contentHeight = max(1, safeHeight - 2 * verticalPadding)

        // Defaults should not consume an entire 16–24 pt wing. If the user explicitly chose a
        // value, honour it exactly rather than silently clamping their customization.
        let adaptiveHorizontal = max(1, min(8, contentHeight * 0.28))
        horizontalPadding = options.horizontalPadding == nil
            ? min(options.contentPaddingX, adaptiveHorizontal)
            : options.contentPaddingX

        let adaptiveMargin = max(0, min(4, contentHeight * 0.25))
        cameraMargin = options.sideMargin == nil
            ? min(options.contentSideMargin, adaptiveMargin)
            : options.contentSideMargin
        outerMargin = options.outerMargin == nil
            ? min(options.contentOuterMargin, adaptiveMargin)
            : options.contentOuterMargin

        elementSpacing = min(6, max(2, contentHeight * 0.16))
    }

    var normalCameraInset: Double { horizontalPadding + cameraMargin }
    var outerInset: Double { horizontalPadding + outerMargin }
    var normalShell: Double { normalCameraInset + outerInset }

    /// Power-event margin is defined as the total distance from the camera edge. It intentionally
    /// replaces generic camera padding instead of stacking on top of it.
    func cameraInset(power: PowerReactionOptions?) -> Double {
        power?.resolvedNotchMargin ?? normalCameraInset
    }

    func shell(power: PowerReactionOptions?) -> Double {
        cameraInset(power: power) + outerInset
    }
}
'''
s = replace_once(s, anchor, insert, 'shared closed-notch metrics')
p.write_text(s)

# 2) Exact-content fit should be the default. Fixed active width is an opt-in style choice.
p = Path("Halo/Core/WidgetModels.swift")
s = p.read_text()
s = replace_once(s,
'''struct ClosedExpansionOptions: Codable, Equatable {
    var enabled = true
    var width = 400.0
}
''',
'''struct ClosedExpansionOptions: Codable, Equatable {
    // Content-fit is the stable default. Users can opt into a fixed active width for a more
    // dramatic music/live-activity expansion without making every transient event 400 pt wide.
    var enabled = false
    var width = 400.0
}
''', 'closed expansion default')
p.write_text(s)

# 3) Renderer: use canonical edge insets, exact power margin, adaptive spacing, and deterministic labels.
p = Path("Halo/Views/ClosedNotchView.swift")
s = p.read_text()
s = replace_once(s,
'''    private func slot(_ item: ClosedNotchItem, decoration: SideDecoration?, side: ClosedNotchSide, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if width >= 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin + 8 {
                ClosedNotchSlot(item: item, decoration: decoration, side: side, availableHeight: height, availableWidth: width,
                                options: options, clock: layout.widgetStyle(for: .clock), store: store, workspace: workspace,
                                media: workspace.media, system: workspace.system, activity: activeActivity, hud: hud(for: side))
            }
        }.frame(width: max(0, width)).clipped()
    }
''',
'''    private func slot(_ item: ClosedNotchItem, decoration: SideDecoration?, side: ClosedNotchSide, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if width > 1 {
                ClosedNotchSlot(item: item, decoration: decoration, side: side, availableHeight: height, availableWidth: width,
                                options: options, clock: layout.widgetStyle(for: .clock), store: store, workspace: workspace,
                                media: workspace.media, system: workspace.system, activity: activeActivity, hud: hud(for: side))
            }
        }.frame(width: max(0, width)).clipped()
    }
''', 'slot minimum width')
s = replace_once(s,
'''    let activity: LiveActivity?
    let hud: HaloHUDNotchPresentation?
    private let elementSpacing = 6.0
    private var activeActivity: LiveActivity? { activity }
    private var innerHeight: Double { max(1, availableHeight - 2 * options.contentPaddingY) }
    private var innerWidth: Double { max(1, availableWidth - 2 * options.contentPaddingX - slotCameraMargin - options.contentOuterMargin) }
''',
'''    let activity: LiveActivity?
    let hud: HaloHUDNotchPresentation?
    private var layoutMetrics: ClosedNotchLayoutMetrics { ClosedNotchLayoutMetrics(options: options, height: availableHeight) }
    private var elementSpacing: Double { layoutMetrics.elementSpacing }
    private var activeActivity: LiveActivity? { activity }
    private var innerHeight: Double { layoutMetrics.contentHeight }
    private var innerWidth: Double { max(1, availableWidth - slotCameraInset - slotOuterInset) }
''', 'slot metrics')
s = replace_once(s,
'''    private var powerNotchMargin: Double { powerSettings.resolvedNotchMargin }
    // Power is always the element nearest the physical camera. When it is visible, its own
    // notch margin replaces the generic closed-notch side margin instead of stacking on top.
    private var slotCameraMargin: Double { showPowerEvent ? 0 : options.contentSideMargin }
''',
'''    private var powerNotchMargin: Double { powerSettings.resolvedNotchMargin }
    // Power is always nearest the camera. Its margin is the complete camera-edge inset, not an
    // additional value layered on top of the normal horizontal padding.
    private var slotCameraInset: Double {
        layoutMetrics.cameraInset(power: showPowerEvent ? powerSettings : nil)
    }
    private var slotOuterInset: Double { layoutMetrics.outerInset }
''', 'power camera inset')
s = replace_once(s,
'''        let natural = max(16, naturalPowerWidth)
        let extra = powerUsesEventContainer ? powerSettings.resolvedExtraEventSpace : 0
        // The footprint is content-driven. The old eventWidth no longer creates a large empty
        // container that centers a tiny icon far away from the camera cutout.
        return min(innerWidth, natural + powerNotchMargin + extra)
''',
'''        let natural = max(16, naturalPowerWidth)
        let extra = powerUsesEventContainer ? powerSettings.resolvedExtraEventSpace : 0
        // Camera margin belongs to the slot edge inset, not to the element's own width.
        return min(innerWidth, natural + extra)
''', 'power footprint')
s = replace_once(s,
'''        .frame(maxWidth: .infinity, maxHeight: innerHeight, alignment: side == .left ? .trailing : .leading)
        .padding(.horizontal, options.contentPaddingX)
        .padding(.vertical, options.contentPaddingY)
        .padding(side == .left ? .trailing : .leading, slotCameraMargin)
        .padding(side == .left ? .leading : .trailing, options.contentOuterMargin)
        .frame(width: availableWidth, height: availableHeight, alignment: .center)
''',
'''        .frame(maxWidth: .infinity, maxHeight: innerHeight, alignment: side == .left ? .trailing : .leading)
        .padding(.vertical, layoutMetrics.verticalPadding)
        .padding(side == .left ? .trailing : .leading, slotCameraInset)
        .padding(side == .left ? .leading : .trailing, slotOuterInset)
        .frame(width: availableWidth, height: availableHeight, alignment: .center)
''', 'edge padding')
s = replace_once(s,
'''                side: side,
                textSize: powerTextSize,
                notchMargin: powerNotchMargin
            )
''',
'''                side: side,
                textSize: powerTextSize
            )
''', 'power badge call')
s = replace_once(s,
'''        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit().lineLimit(1) }
            else { Label(store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready", systemImage: "timer").lineLimit(1) }
        case .battery:
            if let battery = system.battery { Label("\\(battery)%", systemImage: system.charging ? "battery.100.bolt" : "battery.100").lineLimit(1) }
            else { Image(systemName: "powerplug") }
''',
'''        case .timer:
            if let deadline = store.deadline { Text(deadline, style: .timer).monospacedDigit().lineLimit(1) }
            else { compactLabel(symbol: "timer", text: store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready") }
        case .battery:
            if let battery = system.battery { compactLabel(symbol: system.charging ? "battery.100.bolt" : "battery.100", text: "\\(battery)%") }
            else { Image(systemName: "powerplug").frame(width: max(12, textSize + 2), alignment: .center) }
''', 'compact timer battery')
s = replace_once(s,
'''        case .files: Label("\\(store.files.count)", systemImage: "tray").lineLimit(1)
''',
'''        case .files: compactLabel(symbol: "tray", text: "\\(store.files.count)")
''', 'compact files')
s = replace_once(s,
'''                    HStack(spacing: 6) {
''',
'''                    HStack(spacing: elementSpacing) {
''', 'generic activity spacing')
s = replace_once(s,
'''                    BluetoothClosedActivityView(activity: activity, kind: kind, side: side,
                                                textSize: textSize, availableWidth: activityContentWidth,
                                                inheritedColor: effectiveTextColor)
''',
'''                    BluetoothClosedActivityView(activity: activity, kind: kind, side: side,
                                                textSize: textSize, availableWidth: activityContentWidth,
                                                inheritedColor: effectiveTextColor, spacing: elementSpacing)
''', 'bluetooth spacing call')
s = replace_once(s,
'''    private var compactClock: WidgetStyle { var value = clock; value.fontSize = textSize; value.textColor = WidgetColor(effectiveTextColor); return value }
}

private struct BluetoothClosedActivityView: View {
''',
'''    private func compactLabel(symbol: String, text: String) -> some View {
        HStack(spacing: elementSpacing) {
            Image(systemName: symbol)
                .frame(width: max(12, textSize + 2), alignment: .center)
            Text(text).monospacedDigit().lineLimit(1)
        }
    }
    private var compactClock: WidgetStyle { var value = clock; value.fontSize = textSize; value.textColor = WidgetColor(effectiveTextColor); return value }
}

private struct BluetoothClosedActivityView: View {
''', 'compact label helper')
s = replace_once(s,
'''    let availableWidth: Double
    let inheritedColor: Color
''',
'''    let availableWidth: Double
    let inheritedColor: Color
    let spacing: Double
''', 'bluetooth spacing property')
s = replace_once(s, 'HStack(spacing: 5) {', 'HStack(spacing: spacing) {', 'bluetooth inline spacing')
s = replace_once(s, 'HStack(spacing: 6) {', 'HStack(spacing: spacing) {', 'bluetooth stacked spacing')
s = replace_once(s,
'''    let side: ClosedNotchSide
    let textSize: Double
    let notchMargin: Double

    private var contentAlignment: Alignment { side == .left ? .trailing : .leading }
''',
'''    let side: ClosedNotchSide
    let textSize: Double

    private var contentAlignment: Alignment { side == .left ? .trailing : .leading }
''', 'power badge properties')
s = replace_once(s,
'''        .minimumScaleFactor(0.82)
        .padding(side == .left ? .trailing : .leading, notchMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .padding(side == .left ? .leading : .trailing, 1)
''',
'''        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .padding(.horizontal, 1)
''', 'power badge exact margin')
p.write_text(s)

# 4) Window sizing: rebuild the side measurement from body widths + one canonical shell.
p = Path("Halo/NotchEngine/WindowManager.swift")
s = p.read_text()
s = replace_once(s,
'''        let innerHeight = max(1, compactHeight - 2 * options.contentPaddingY)
        let baseSize = min(options.fontSize, innerHeight / 1.25)
''',
'''        let metrics = ClosedNotchLayoutMetrics(options: options, height: compactHeight)
        let innerHeight = metrics.contentHeight
        let baseSize = min(options.fontSize, innerHeight / 1.25)
''', 'power measurement metrics')
s = replace_once(s,
'''        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let expansion = options.expansion ?? ClosedExpansionOptions()
''',
'''        let layout = host.state.layoutOverride ?? store.workspace.effectiveLayout
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let expansion = options.expansion ?? ClosedExpansionOptions()
        let closedMetrics = ClosedNotchLayoutMetrics(options: options, height: geometry.appearance.surface.compactHeight)
''', 'configure metrics')
s = replace_once(s,
'''                let hudGap = 6.0
                let shell = 2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin + 8
                func merged(_ existing: Double, _ hudWidth: Double) -> Double {
                    switch hud.collision {
                    case .replace:
                        return hudWidth
                    case .push, .queue:
                        return existing > 0 ? existing + hudGap + hudWidth : hudWidth
                    case .overlay, .showExternally:
                        return max(existing, hudWidth)
                    }
                }
''',
'''                let hudGap = closedMetrics.elementSpacing
                let shell = closedMetrics.normalShell
                func merged(_ existing: Double, _ hudBodyWidth: Double) -> Double {
                    switch hud.collision {
                    case .replace:
                        return hudBodyWidth + shell
                    case .push, .queue, .showExternally:
                        return existing > 0 ? existing + hudGap + hudBodyWidth : hudBodyWidth + shell
                    case .overlay:
                        return max(existing, hudBodyWidth + shell)
                    }
                }
''', 'hud shell sizing')
s = replace_once(s, 'leftDemand = merged(leftDemand, hud.width + shell)', 'leftDemand = merged(leftDemand, hud.width)', 'hud left merge')
s = replace_once(s, 'rightDemand = merged(rightDemand, hud.width + shell)', 'rightDemand = merged(rightDemand, hud.width)', 'hud right merge')
s = replace_once(s,
'''                    let half = hud.width / 2 + shell
                    leftDemand = merged(leftDemand, half)
                    rightDemand = merged(rightDemand, half)
''',
'''                    let half = hud.width / 2
                    leftDemand = merged(leftDemand, half)
                    rightDemand = merged(rightDemand, half)
''', 'hud full merge')
s = replace_once(s, 'rightDemand = merged(rightDemand, hud.width + shell)', 'rightDemand = merged(rightDemand, hud.width)', 'hud automatic merge')
start = s.index('    private func fittedClosedSides(host: Host, layout: WorkspaceLayout,')
end = s.index('    private func refreshDynamicWidths()', start)
new_function = '''    private func fittedClosedSides(host: Host, layout: WorkspaceLayout,
                                   items: (left: ClosedNotchItem, right: ClosedNotchItem),
                                   power: (side: DynamicSide, badgeWidth: Double, notchMargin: Double, extraSpace: Double)?) ->
        (left: Double, right: Double, decorationLeft: Double, decorationRight: Double) {
        guard let geometry = host.geometry else { return (0, 0, 0, 0) }
        let options = layout.closedNotch ?? ClosedNotchOptions()
        let playing = store.workspace.media.isPlaying
        let activity = activeClosedActivity
        let baseCompactHeight = max(16, geometry.appearance.surface.compactHeight)
        let metrics = ClosedNotchLayoutMetrics(options: options, height: baseCompactHeight)
        let innerHeight = metrics.contentHeight
        let size = min(options.fontSize, innerHeight / 1.25)
        let font = NSFont.systemFont(ofSize: size)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        let elementGap = metrics.elementSpacing

        var artwork = options.artworkOptions ?? ClosedArtworkOptions()
        if options.artworkOptions == nil, let legacy = options.mediaOptions, legacy.artwork != .none {
            artwork.enabled = true; artwork.mode = legacy.artwork; artwork.size = legacy.artworkSize
            artwork.vinylRPM = legacy.vinylRPM; artwork.backgroundOpacity = legacy.backgroundOpacity
        }

        let artworkTarget: DynamicSide? = {
            guard playing, artwork.enabled, artwork.mode != .none, artwork.mode != .background else { return nil }
            switch artwork.side {
            case .left: return .left
            case .right: return .right
            case .automatic:
                if options.left == .media || options.left == .visualizer { return .left }
                if options.right == .media || options.right == .visualizer { return .right }
                return .right
            }
        }()

        func textWidth(_ text: String, font: NSFont) -> Double {
            ceil((text as NSString).size(withAttributes: [.font: font]).width) + 2
        }

        func mediaWidth() -> Double {
            guard playing else { return 0 }
            let media = options.mediaOptions ?? ClosedMediaOptions()
            let title = textWidth(String(store.workspace.media.title.prefix(120)), font: font)
            let artistValue = store.workspace.media.artist.isEmpty ? store.workspace.media.title : store.workspace.media.artist
            let artist = textWidth(String(artistValue.prefix(120)), font: font)
            let adaptive = media.textMode == .lyrics && media.usesDynamicLyricWidth && mediaWidthHint != nil

            let usesInlineIcon: Bool = {
                guard media.showPlaybackIcon else { return false }
                switch media.textMode {
                case .title, .artist: return true
                case .titleArtist: return media.lines == 1
                case .lyrics:
                    switch media.resolvedLyricDisplay {
                    case .word: return true
                    case .line: return media.lines == 1
                    case .focus: return false
                    }
                }
            }()
            let icon = usesInlineIcon ? max(12, size + 2) + elementGap : 0

            let naturalText: Double
            switch media.textMode {
            case .title: naturalText = title
            case .artist: naturalText = artist
            case .titleArtist:
                naturalText = media.lines == 2
                    ? max(title, artist)
                    : title + (store.workspace.media.artist.isEmpty ? 0 : artist + textWidth(" · ", font: font))
            case .lyrics:
                naturalText = adaptive ? max(28, mediaWidthHint!) : max(90, min(220, title + artist * 0.35))
            }

            if adaptive { return min(320, max(28, naturalText)) }
            let naturalTotal = naturalText + icon
            switch media.overflow {
            case .marquee, .truncate:
                return min(max(24, naturalTotal), media.resolvedHorizontalSpace)
            case .scale:
                return min(max(24, naturalTotal), 260)
            }
        }

        func bluetoothActivityWidth(_ activity: LiveActivity) -> Double? {
            let label: String
            switch activity.title {
            case "Bluetooth connected": label = "Connected"
            case "Bluetooth disconnected": label = "Disconnected"
            case "Bluetooth on": label = "Bluetooth On"
            case "Bluetooth off": label = "Bluetooth Off"
            default: return nil
            }

            let defaults = UserDefaults.standard
            func boolValue(_ key: String, fallback: Bool) -> Bool {
                defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
            }
            let showIcon = boolValue("HaloBluetoothClosedNotchShowIcon", fallback: true)
            let showLabel = boolValue("HaloBluetoothClosedNotchShowLabel", fallback: true)
            let showDevice = boolValue("HaloBluetoothClosedNotchShowDevice", fallback: true)
            let layoutRaw = defaults.string(forKey: "HaloBluetoothClosedNotchLayout") ?? BluetoothClosedNotchLayout.stacked.rawValue
            let layout = BluetoothClosedNotchLayout(rawValue: layoutRaw) ?? .stacked
            let configuredIcon = defaults.object(forKey: "HaloBluetoothClosedNotchIconSize") == nil
                ? 16.0 : defaults.double(forKey: "HaloBluetoothClosedNotchIconSize")
            let iconSize = min(max(8, configuredIcon), max(8, size * 1.8))
            let iconWidth = showIcon ? max(12, iconSize + 2) : 0
            let labelWidth = showLabel ? textWidth(label, font: font) : 0
            let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))
            let detailWidth = showDevice && !activity.detail.isEmpty
                ? textWidth(String(activity.detail.prefix(80)), font: detailFont) : 0

            func inlineTextWidth() -> Double {
                let parts = [labelWidth, detailWidth].filter { $0 > 0 }
                guard !parts.isEmpty else { return 0 }
                return parts.reduce(0, +) + Double(max(0, parts.count - 1)) * elementGap
            }
            let stackedText = max(labelWidth, detailWidth)

            switch layout {
            case .iconOnly:
                return iconWidth
            case .textOnly:
                return stackedText
            case .inline:
                let text = inlineTextWidth()
                if iconWidth > 0 && text > 0 { return iconWidth + elementGap + text }
                return max(iconWidth, text)
            case .stacked:
                if iconWidth > 0 && stackedText > 0 { return iconWidth + elementGap + stackedText }
                return max(iconWidth, stackedText)
            }
        }

        func isArtworkOnly(_ side: DynamicSide, item: ClosedNotchItem) -> Bool {
            guard artwork.isArtworkOnly, artworkTarget == side else { return false }
            return item == .media || item == .visualizer
        }

        func itemWidth(_ side: DynamicSide, _ item: ClosedNotchItem) -> Double {
            if isArtworkOnly(side, item: item) { return 0 }
            switch item {
            case .none: return 0
            case .clock:
                let style = layout.widgetStyle(for: .clock)
                let clockFont = style.fontFamily == .custom
                    ? NSFont(name: style.customFont, size: size) ?? font
                    : NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
                let template = "88:88" + (style.clock.showSeconds ? ":88" : "") + (style.clock.twentyFourHour ? "" : " PM")
                return textWidth(template, font: clockFont) * 1.04
            case .date:
                return textWidth("Sep 28", font: font)
            case .timer:
                if store.deadline != nil { return textWidth("88:88:88", font: digitFont) }
                let label = store.pausedSeconds > 0 ? "Paused" : store.finished ? "Done" : "Ready"
                return max(12, size + 2) + elementGap + textWidth(label, font: font)
            case .battery:
                guard let battery = store.workspace.system.battery else { return max(12, size + 2) }
                return max(12, size + 2) + elementGap + textWidth("\\(battery)%", font: digitFont)
            case .media:
                return mediaWidth()
            case .visualizer:
                return playing ? (options.visualizer ?? VisualizerOptions()).width : 0
            case .mirror:
                return 112
            case .files:
                return max(12, size + 2) + elementGap + textWidth(String(store.files.count), font: digitFont)
            case .activity:
                guard let activity else { return 0 }
                if let bluetooth = bluetoothActivityWidth(activity) { return min(240, max(0, bluetooth)) }
                let title = textWidth(String(activity.title.prefix(80)), font: font)
                let detailFont = NSFont.systemFont(ofSize: max(8, size * 0.76))
                let detail = activity.detail.isEmpty ? 0 : textWidth(String(activity.detail.prefix(80)), font: detailFont)
                let icon = max(12, size)
                let text = max(title, detail)
                let progress = activity.progress == nil ? 0 : elementGap + 38
                return min(240, icon + elementGap + text + progress + 2)
            }
        }

        func decorationWidth(_ decoration: SideDecoration?) -> Double {
            decoration.flatMap {
                $0.isVisible(playing: playing) ? min($0.size, innerHeight) : nil
            } ?? 0
        }

        func append(_ width: Double, to body: inout Double) {
            guard width > 0 else { return }
            if body > 0 { body += elementGap }
            body += width
        }

        var leftBody = itemWidth(.left, items.left)
        var rightBody = itemWidth(.right, items.right)
        let leftDecoration = decorationWidth(options.leftDecoration)
        let rightDecoration = decorationWidth(options.rightDecoration)
        append(leftDecoration, to: &leftBody)
        append(rightDecoration, to: &rightBody)

        if let artworkTarget {
            let renderedArtworkSize = max(1, min(artwork.size, innerHeight - 2 * artwork.padding))
            let artworkWidth = renderedArtworkSize + 2 * artwork.padding + artwork.margin
            if artworkTarget == .left { append(artworkWidth, to: &leftBody) }
            else { append(artworkWidth, to: &rightBody) }
        }

        if let power {
            let powerWidth = power.badgeWidth + power.extraSpace
            if power.side == .left { append(powerWidth, to: &leftBody) }
            else { append(powerWidth, to: &rightBody) }
        }

        func fullWidth(body: Double, powerOnSide: Bool) -> Double {
            guard body > 0 else { return 0 }
            let cameraInset = powerOnSide && power != nil ? power!.notchMargin : metrics.normalCameraInset
            return body + cameraInset + metrics.outerInset
        }

        let leftFull = fullWidth(body: leftBody, powerOnSide: power?.side == .left)
        let rightFull = fullWidth(body: rightBody, powerOnSide: power?.side == .right)
        let leftDecorationFull = leftDecoration > 0 ? leftDecoration + metrics.normalShell : 0
        let rightDecorationFull = rightDecoration > 0 ? rightDecoration + metrics.normalShell : 0
        return (leftFull, rightFull, leftDecorationFull, rightDecorationFull)
    }

'''
s = s[:start] + new_function + s[end:]
p.write_text(s)

# 5) Settings copy: make the sizing model understandable and stop implying fixed width is default.
p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()
s = replace_once(s,
'''            Text("The Appearance closed-width slider is the guaranteed idle/base width. Auto-size can grow beyond it, then returns to it when transient content disappears.").font(.caption)
''',
'''            Text("The Appearance closed-width slider is the idle/base width. Auto-size grows only as much as visible content needs. Default padding compresses automatically at very small closed heights; explicit padding and margin values stay exact.").font(.caption)
''', 'content fit caption')
s = replace_once(s,
'''            Text("Music, pinned files, timers, power events and live activities can widen the closed notch. Dynamic lyrics and constrained Truncate/Marquee media use their own content width instead of forcing the fixed music width.").font(.caption)
''',
'''            Text("Optional fixed-width expansion for music and other live content. Leave this off for exact content-fit sizing. Power events always use their own measured size and margin.").font(.caption)
''', 'active width caption')
p.write_text(s)

print("Closed notch spacing/sizing audit applied")
