from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing block: {label}")
    return text.replace(old, new, 1)

closed_path = Path("Halo/Views/ClosedNotchView.swift")
closed = closed_path.read_text()

closed = replace_once(
    closed,
    '''    private var textSize: Double { min(options.fontSize, innerHeight / 1.25) }
    private var effectiveTextColor: Color {''',
    '''    private var textSize: Double { min(options.fontSize, innerHeight / 1.25) }
    private var powerTextSize: Double { min(textSize, max(9, innerHeight * 0.46)) }
    private var powerIconWidth: Double { max(12, powerTextSize + 2) }
    private var powerSlotMargins: Double {
        2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin
    }
    private func powerTextWidth(_ value: String, monospaced: Bool = false) -> Double {
        let font = monospaced
            ? NSFont.monospacedDigitSystemFont(ofSize: powerTextSize, weight: .semibold)
            : NSFont.systemFont(ofSize: powerTextSize, weight: .semibold)
        return ceil((value as NSString).size(withAttributes: [.font: font]).width)
    }
    private var effectiveTextColor: Color {''',
    "power typography"
)

closed = replace_once(
    closed,
    '''    private var naturalPowerWidth: Double {
        guard let event = powerEvent else { return 0 }
        switch event.style {
        case .off: return 0
        case .icon: return textSize + 4
        case .percent: return textSize * 2.7
        case .iconPercent: return textSize * 3.9
        case .label: return textSize * 6.2
        }
    }
    private var powerFootprint: Double {
        guard showPowerEvent else { return 0 }
        let settings = options.powerReaction ?? PowerReactionOptions()
        let comfortable = min(settings.eventWidth, naturalPowerWidth + 12)
        return min(max(18, naturalPowerWidth), max(18, min(innerWidth, comfortable)))
    }''',
    '''    private var naturalPowerWidth: Double {
        guard let event = powerEvent else { return 0 }
        let gap = 4.0
        let inset = 2.0
        switch event.style {
        case .off: return 0
        case .icon: return powerIconWidth + inset
        case .percent: return powerTextWidth("\\(event.battery)%", monospaced: true) + inset
        case .iconPercent:
            return powerIconWidth + gap + powerTextWidth("\\(event.battery)%", monospaced: true) + inset
        case .label:
            return powerIconWidth + gap + powerTextWidth(event.label) + inset
        }
    }
    private var powerUsesEventContainer: Bool {
        guard showPowerEvent else { return false }
        let settings = options.powerReaction ?? PowerReactionOptions()
        return settings.expandForEvent && !itemIsVisible && decorationSize <= 0 && artworkFootprint <= 0
    }
    private var powerFootprint: Double {
        guard showPowerEvent else { return 0 }
        let natural = max(16, naturalPowerWidth)
        guard powerUsesEventContainer else { return min(innerWidth, natural) }
        let settings = options.powerReaction ?? PowerReactionOptions()
        let targetContentWidth = max(natural, settings.eventWidth - powerSlotMargins)
        return min(innerWidth, targetContentWidth)
    }''',
    "power footprint"
)

closed = replace_once(
    closed,
    '''    @ViewBuilder private var powerElement: some View {
        if showPowerEvent, let powerEvent {
            PowerEventBadge(event: powerEvent, options: options.powerReaction ?? PowerReactionOptions())
                .frame(width: powerFootprint, height: innerHeight,
                       alignment: side == .left ? .trailing : .leading)
                .clipped()
                .layoutPriority(2)
        }
    }''',
    '''    @ViewBuilder private var powerElement: some View {
        if showPowerEvent, let powerEvent {
            PowerEventBadge(
                event: powerEvent,
                options: options.powerReaction ?? PowerReactionOptions(),
                side: side,
                textSize: powerTextSize,
                centered: powerUsesEventContainer
            )
            .frame(width: powerFootprint, height: innerHeight,
                   alignment: powerUsesEventContainer ? .center : (side == .left ? .trailing : .leading))
            .clipped()
            .layoutPriority(2)
        }
    }''',
    "power element"
)

closed = replace_once(
    closed,
    '''private struct PowerEventBadge: View {
    let event: PowerEventInfo
    let options: PowerReactionOptions
    var body: some View {
        Group {
            switch event.style {
            case .off: EmptyView()
            case .icon: Image(systemName: event.symbol)
            case .percent: Text("\\(event.battery)%").monospacedDigit()
            case .iconPercent: Label("\\(event.battery)%", systemImage: event.symbol).monospacedDigit()
            case .label: Label(event.label, systemImage: event.symbol)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 2)
        .foregroundStyle(powerColor)
    }
    private var powerColor: Color {''',
    '''private struct PowerEventBadge: View {
    let event: PowerEventInfo
    let options: PowerReactionOptions
    let side: ClosedNotchSide
    let textSize: Double
    let centered: Bool

    private var contentAlignment: Alignment {
        centered ? .center : (side == .left ? .trailing : .leading)
    }
    private var iconWidth: Double { max(12, textSize + 2) }

    var body: some View {
        Group {
            switch event.style {
            case .off:
                EmptyView()
            case .icon:
                powerIcon
            case .percent:
                percentage
            case .iconPercent:
                HStack(spacing: 4) {
                    if side == .left {
                        percentage
                        powerIcon
                    } else {
                        powerIcon
                        percentage
                    }
                }
            case .label:
                HStack(spacing: 4) {
                    if side == .left {
                        Text(event.label)
                        powerIcon
                    } else {
                        powerIcon
                        Text(event.label)
                    }
                }
            }
        }
        .font(.system(size: textSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .padding(.horizontal, 1)
        .foregroundStyle(powerColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\\(event.label), \\(event.battery) percent")
    }

    private var powerIcon: some View {
        Image(systemName: event.symbol)
            .font(.system(size: textSize, weight: .semibold))
            .frame(width: iconWidth, height: max(12, textSize + 2), alignment: .center)
    }

    private var percentage: some View {
        Text("\\(event.battery)%").monospacedDigit()
    }

    private var powerColor: Color {''',
    "power badge"
)

closed_path.write_text(closed)

wm_path = Path("Halo/NotchEngine/WindowManager.swift")
wm = wm_path.read_text()
old = '''    private func powerReaction(options: ClosedNotchOptions,
                               items: (left: ClosedNotchItem, right: ClosedNotchItem))
        -> (side: DynamicSide, badgeWidth: Double, minimumSideWidth: Double)? {
        let settings = options.powerReaction ?? PowerReactionOptions()
        guard settings.isEnabled, let battery = store.workspace.system.battery else { return nil }
        let style: PowerReactionStyle
        let eventLabel: String
        if battery >= 99 && !store.workspace.system.onBattery {
            style = settings.charged; eventLabel = "Charged"
        } else if store.workspace.system.charging {
            style = settings.charging; eventLabel = "Charging"
        } else if store.workspace.system.onBattery && battery <= settings.lowThreshold {
            style = settings.low; eventLabel = "Low battery"
        } else { return nil }
        guard style != .off else { return nil }

        let size = max(10, options.fontSize)
        let font = NSFont.systemFont(ofSize: size, weight: .regular)
        func textWidth(_ value: String) -> Double {
            ceil((value as NSString).size(withAttributes: [.font: font]).width)
        }
        let iconWidth = max(12, size * 1.05)
        let labelGap = 4.0
        let horizontalPadding = 4.0
        let naturalWidth: Double
        switch style {
        case .off: naturalWidth = 0
        case .icon: naturalWidth = iconWidth + horizontalPadding
        case .percent: naturalWidth = textWidth("100%") + horizontalPadding
        case .iconPercent: naturalWidth = iconWidth + labelGap + textWidth("100%") + horizontalPadding
        case .label: naturalWidth = iconWidth + labelGap + textWidth(eventLabel) + horizontalPadding
        }
        let badgeWidth = max(18, naturalWidth)
        let minimumSideWidth = settings.expandForEvent ? max(badgeWidth, settings.eventWidth) : badgeWidth

        let side: DynamicSide
        switch settings.side {
        case .left: side = .left
        case .right: side = .right
        case .automatic:
            let playing = store.workspace.media.isPlaying
            let rightFree = items.right == .none || ((items.right == .media || items.right == .visualizer) && !playing)
            let leftFree = items.left == .none || ((items.left == .media || items.left == .visualizer) && !playing)
            if rightFree { side = .right }
            else if leftFree { side = .left }
            else { side = .right }
        }
        return (side, badgeWidth, minimumSideWidth)
    }'''
new = '''    private func powerReaction(options: ClosedNotchOptions,
                               items: (left: ClosedNotchItem, right: ClosedNotchItem))
        -> (side: DynamicSide, badgeWidth: Double, minimumSideWidth: Double)? {
        let settings = options.powerReaction ?? PowerReactionOptions()
        guard settings.isEnabled, let battery = store.workspace.system.battery else { return nil }
        let style: PowerReactionStyle
        let eventLabel: String
        if battery >= 99 && !store.workspace.system.onBattery {
            style = settings.charged; eventLabel = "Charged"
        } else if store.workspace.system.charging {
            style = settings.charging; eventLabel = "Charging"
        } else if store.workspace.system.onBattery && battery <= settings.lowThreshold {
            style = settings.low; eventLabel = "Low battery"
        } else { return nil }
        guard style != .off else { return nil }

        let playing = store.workspace.media.isPlaying
        let side: DynamicSide
        switch settings.side {
        case .left: side = .left
        case .right: side = .right
        case .automatic:
            let rightFree = items.right == .none || ((items.right == .media || items.right == .visualizer) && !playing)
            let leftFree = items.left == .none || ((items.left == .media || items.left == .visualizer) && !playing)
            if rightFree { side = .right }
            else if leftFree { side = .left }
            else { side = .right }
        }

        let innerHeight = max(1, options.surface.compactHeight - 2 * options.contentPaddingY)
        let baseSize = min(options.fontSize, innerHeight / 1.25)
        let size = min(baseSize, max(9, innerHeight * 0.46))
        let normalFont = NSFont.systemFont(ofSize: size, weight: .semibold)
        let digitFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold)
        func textWidth(_ value: String, font: NSFont) -> Double {
            ceil((value as NSString).size(withAttributes: [.font: font]).width)
        }
        let iconWidth = max(12, size + 2)
        let labelGap = 4.0
        let horizontalInset = 2.0
        let naturalWidth: Double
        switch style {
        case .off: naturalWidth = 0
        case .icon: naturalWidth = iconWidth + horizontalInset
        case .percent: naturalWidth = textWidth("\\(battery)%", font: digitFont) + horizontalInset
        case .iconPercent:
            naturalWidth = iconWidth + labelGap + textWidth("\\(battery)%", font: digitFont) + horizontalInset
        case .label:
            naturalWidth = iconWidth + labelGap + textWidth(eventLabel, font: normalFont) + horizontalInset
        }
        let badgeWidth = max(16, naturalWidth)

        func itemIsVisible(_ item: ClosedNotchItem) -> Bool {
            switch item {
            case .none: return false
            case .media, .visualizer: return playing
            case .activity: return activeClosedActivity != nil
            default: return true
            }
        }
        let targetItem = side == .left ? items.left : items.right
        let targetDecoration = side == .left ? options.leftDecoration : options.rightDecoration
        let hasSibling = itemIsVisible(targetItem) || (targetDecoration?.isVisible(playing: playing) ?? false)
        let minimumSideWidth = settings.expandForEvent && !hasSibling
            ? max(badgeWidth, settings.eventWidth)
            : badgeWidth

        return (side, badgeWidth, minimumSideWidth)
    }'''
wm = replace_once(wm, old, new, "window manager power sizing")
wm_path.write_text(wm)

print("Updated power event alignment and sizing")
