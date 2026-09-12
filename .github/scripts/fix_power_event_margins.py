from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing pattern: {label}")
    return text.replace(old, new, 1)

# Model: add power-specific notch margin + optional extra breathing room.
p = Path("Halo/Core/WidgetModels.swift")
s = p.read_text()
s = replace_once(s,
'''    var expandForEvent = true
    var eventWidth = 96.0
    var color = WidgetColor.accent
''',
'''    var expandForEvent = true
    // Legacy field retained so older saved profiles continue to decode. Power events are now
    // content-sized instead of forcing this value as a minimum wing width.
    var eventWidth = 96.0
    var notchMargin: Double?
    var extraEventSpace: Double?
    var resolvedNotchMargin: Double { min(48, max(0, notchMargin ?? 4)) }
    var resolvedExtraEventSpace: Double { min(120, max(0, extraEventSpace ?? 0)) }
    var color = WidgetColor.accent
''', 'power fields')
s = replace_once(s,
'''    func validated() throws -> PowerReactionOptions {
        guard eventWidth.isFinite else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lowThreshold = min(50, max(5, lowThreshold))
        v.eventWidth = min(240, max(48, eventWidth))
        v.color = try color.validated()
''',
'''    func validated() throws -> PowerReactionOptions {
        guard [eventWidth, notchMargin ?? 4, extraEventSpace ?? 0].allSatisfy(\\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var v = self
        v.lowThreshold = min(50, max(5, lowThreshold))
        v.eventWidth = min(240, max(48, eventWidth))
        if notchMargin != nil { v.notchMargin = resolvedNotchMargin }
        if extraEventSpace != nil { v.extraEventSpace = resolvedExtraEventSpace }
        v.color = try color.validated()
''', 'power validation')
p.write_text(s)

# Settings: expose the actual margin, and replace the old forced width with optional extra space.
p = Path("Halo/Views/WidgetSettingsView.swift")
s = p.read_text()
s = replace_once(s,
'''                Toggle("Expand for power events", isOn: power.expandForEvent)
                if power.wrappedValue.expandForEvent { PreciseSlider(title: "Power event width", value: power.eventWidth, range: 48...240, step: 1, suffix: "pt") }
                Toggle("Dynamic color by battery level", isOn: Binding(get: { power.wrappedValue.usesDynamicColor }, set: { power.wrappedValue.dynamicColor = $0 }))
''',
'''                PreciseSlider(title: "Margin from notch", value: Binding(
                    get: { power.wrappedValue.resolvedNotchMargin },
                    set: { power.wrappedValue.notchMargin = $0 }
                ), range: 0...48, step: 1, suffix: "pt")
                Toggle("Expand for power events", isOn: power.expandForEvent)
                if power.wrappedValue.expandForEvent {
                    PreciseSlider(title: "Extra event space", value: Binding(
                        get: { power.wrappedValue.resolvedExtraEventSpace },
                        set: { power.wrappedValue.extraEventSpace = $0 }
                    ), range: 0...120, step: 1, suffix: "pt")
                    Text("Power events size to their visible content. Extra event space is optional breathing room and no longer forces a large default wing.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Dynamic color by battery level", isOn: Binding(get: { power.wrappedValue.usesDynamicColor }, set: { power.wrappedValue.dynamicColor = $0 }))
''', 'power settings UI')
p.write_text(s)

# Renderer: replace the generic camera margin with the power-specific one and keep content camera-aligned.
p = Path("Halo/Views/ClosedNotchView.swift")
s = p.read_text()
s = replace_once(s,
'''    private var innerHeight: Double { max(1, availableHeight - 2 * options.contentPaddingY) }
    private var innerWidth: Double { max(1, availableWidth - 2 * options.contentPaddingX - options.contentSideMargin - options.contentOuterMargin) }
''',
'''    private var innerHeight: Double { max(1, availableHeight - 2 * options.contentPaddingY) }
    private var innerWidth: Double { max(1, availableWidth - 2 * options.contentPaddingX - slotCameraMargin - options.contentOuterMargin) }
''', 'inner width camera margin')
s = replace_once(s,
'''    private var showPowerEvent: Bool { powerTargetSide == side }
    private var decorationSize: Double {
''',
'''    private var showPowerEvent: Bool { powerTargetSide == side }
    private var powerSettings: PowerReactionOptions { options.powerReaction ?? PowerReactionOptions() }
    private var powerNotchMargin: Double { powerSettings.resolvedNotchMargin }
    // Power is always the element nearest the physical camera. When it is visible, its own
    // notch margin replaces the generic closed-notch side margin instead of stacking on top.
    private var slotCameraMargin: Double { showPowerEvent ? 0 : options.contentSideMargin }
    private var decorationSize: Double {
''', 'power margin helpers')
s = replace_once(s,
'''    private var powerSlotMargins: Double {
        2 * options.contentPaddingX + options.contentSideMargin + options.contentOuterMargin
    }
''', '', 'remove old power slot margins')
s = replace_once(s,
'''        let settings = options.powerReaction ?? PowerReactionOptions()
        return settings.expandForEvent && !itemIsVisible && decorationSize <= 0 && artworkFootprint <= 0 && hudReservedWidth <= 0
''',
'''        return powerSettings.expandForEvent && !itemIsVisible && decorationSize <= 0 && artworkFootprint <= 0 && hudReservedWidth <= 0
''', 'power container settings')
s = replace_once(s,
'''        let natural = max(16, naturalPowerWidth)
        guard powerUsesEventContainer else { return min(innerWidth, natural) }
        let settings = options.powerReaction ?? PowerReactionOptions()
        let targetContentWidth = max(natural, settings.eventWidth - powerSlotMargins)
        return min(innerWidth, targetContentWidth)
''',
'''        let natural = max(16, naturalPowerWidth)
        let extra = powerUsesEventContainer ? powerSettings.resolvedExtraEventSpace : 0
        // The footprint is content-driven. The old eventWidth no longer creates a large empty
        // container that centers a tiny icon far away from the camera cutout.
        return min(innerWidth, natural + powerNotchMargin + extra)
''', 'power footprint')
s = replace_once(s,
'''        .padding(.horizontal, options.contentPaddingX)
        .padding(.vertical, options.contentPaddingY)
        .padding(side == .left ? .trailing : .leading, options.contentSideMargin)
        .padding(side == .left ? .leading : .trailing, options.contentOuterMargin)
''',
'''        .padding(.horizontal, options.contentPaddingX)
        .padding(.vertical, options.contentPaddingY)
        .padding(side == .left ? .trailing : .leading, slotCameraMargin)
        .padding(side == .left ? .leading : .trailing, options.contentOuterMargin)
''', 'slot camera padding')
s = replace_once(s,
'''                side: side,
                textSize: powerTextSize,
                centered: powerUsesEventContainer
            )
            .frame(width: powerFootprint, height: innerHeight,
                   alignment: powerUsesEventContainer ? .center : (side == .left ? .trailing : .leading))
''',
'''                side: side,
                textSize: powerTextSize,
                notchMargin: powerNotchMargin
            )
            .frame(width: powerFootprint, height: innerHeight,
                   alignment: side == .left ? .trailing : .leading)
''', 'power badge call')
s = replace_once(s,
'''    let side: ClosedNotchSide
    let textSize: Double
    let centered: Bool

    private var contentAlignment: Alignment {
        centered ? .center : (side == .left ? .trailing : .leading)
    }
''',
'''    let side: ClosedNotchSide
    let textSize: Double
    let notchMargin: Double

    private var contentAlignment: Alignment { side == .left ? .trailing : .leading }
''', 'power badge properties')
s = replace_once(s,
'''        .font(.system(size: textSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .padding(.horizontal, 1)
''',
'''        .font(.system(size: textSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .padding(side == .left ? .trailing : .leading, notchMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .padding(side == .left ? .leading : .trailing, 1)
''', 'power badge padding')
p.write_text(s)

# Window sizing: size the power wing from visible content + explicit notch margin, not legacy eventWidth.
p = Path("Halo/NotchEngine/WindowManager.swift")
s = p.read_text()
s = replace_once(s,
'''        -> (side: DynamicSide, badgeWidth: Double, minimumSideWidth: Double)? {
''',
'''        -> (side: DynamicSide, badgeWidth: Double, notchMargin: Double, extraSpace: Double)? {
''', 'power tuple type')
s = replace_once(s,
'''        let minimumSideWidth = settings.expandForEvent && !hasSibling
            ? max(badgeWidth, settings.eventWidth)
            : badgeWidth

        return (side, badgeWidth, minimumSideWidth)
''',
'''        let extraSpace = settings.expandForEvent && !hasSibling ? settings.resolvedExtraEventSpace : 0
        return (side, badgeWidth, settings.resolvedNotchMargin, extraSpace)
''', 'power tuple values')
s = replace_once(s,
'''                                   power: (side: DynamicSide, badgeWidth: Double, minimumSideWidth: Double)?) ->
''',
'''                                   power: (side: DynamicSide, badgeWidth: Double, notchMargin: Double, extraSpace: Double)?) ->
''', 'fitted tuple signature')
s = replace_once(s,
'''        if let power {
            switch power.side {
            case .left:
                let withBadge = leftFull > 0 ? leftFull + elementGap + power.badgeWidth : slotMargins + power.badgeWidth
                leftFull = max(withBadge, power.minimumSideWidth)
            case .right:
                let withBadge = rightFull > 0 ? rightFull + elementGap + power.badgeWidth : slotMargins + power.badgeWidth
                rightFull = max(withBadge, power.minimumSideWidth)
            }
        }
''',
'''        if let power {
            // A power event sits nearest the camera. Replace the generic camera margin with the
            // power-specific margin, then add only the badge's measured width. This keeps tiny
            // icon-only events tight to the notch instead of reserving the old 96 pt container.
            func withPower(_ existing: Double) -> Double {
                let base: Double
                if existing > 0 {
                    base = max(0, existing - options.contentSideMargin) + elementGap
                } else {
                    base = 2 * options.contentPaddingX + options.contentOuterMargin
                }
                return base + power.notchMargin + power.badgeWidth + power.extraSpace
            }
            switch power.side {
            case .left: leftFull = withPower(leftFull)
            case .right: rightFull = withPower(rightFull)
            }
        }
''', 'fitted power sizing')
p.write_text(s)

print("Updated power event margin controls, alignment, and content-driven sizing")
