import SwiftUI
import AppKit
import EventKit


struct HaloTimerDurationComposer: View {
    let accent: Color
    let textColor: Color
    let quickPresets: [Int]
    let compact: Bool
    let onStart: (TimeInterval) -> Void

    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int

    init(
        accent: Color,
        textColor: Color,
        quickPresets: [Int] = [5, 15, 25, 45],
        initialMinutes: Int = 25,
        compact: Bool = false,
        onStart: @escaping (TimeInterval) -> Void
    ) {
        self.accent = accent
        self.textColor = textColor
        self.quickPresets = quickPresets
        self.compact = compact
        self.onStart = onStart

        let total = min(359_999, max(0, initialMinutes * 60))
        _hours = State(initialValue: total / 3600)
        _minutes = State(initialValue: total / 60 % 60)
        _seconds = State(initialValue: total % 60)
    }

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private var durationText: String {
        String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var startLabel: String {
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 { parts.append("\(seconds)s") }
        return parts.isEmpty ? "0s" : parts.joined(separator: " ")
    }

    private var uniqueQuickPresets: [Int] {
        var seen = Set<Int>()
        return quickPresets.filter { $0 > 0 && seen.insert($0).inserted }
    }

    var body: some View {
        VStack(spacing: compact ? 7 : 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CUSTOM DURATION")
                        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                        .tracking(1.25)
                        .foregroundStyle(textColor.opacity(0.48))
                    Text(durationText)
                        .font(.system(size: compact ? 17 : 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor.opacity(0.94))
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 12)

                Image(systemName: "dial.medium.fill")
                    .font(.system(size: compact ? 17 : 20, weight: .medium))
                    .foregroundStyle(accent)
                    .padding(compact ? 7 : 8)
                    .background(accent.opacity(0.10), in: Circle())
            }

            ViewThatFits(in: .horizontal) {
                timerWheelRow(compactMode: compact)
                timerWheelRow(compactMode: true)
            }

            if !quickPresets.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(uniqueQuickPresets.prefix(compact ? 3 : 5)), id: \.self) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            Text("\(preset)m")
                                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                                .padding(.horizontal, compact ? 8 : 10)
                                .padding(.vertical, compact ? 5 : 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(textColor.opacity(0.055))
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(textColor.opacity(0.08), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
            }

            Button {
                guard duration >= 1 else { return }
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                onStart(duration)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: compact ? 9 : 10, weight: .bold))
                    Text(duration >= 1 ? "Start \(startLabel)" : "Choose a duration")
                        .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(duration >= 1 ? Color.white : textColor.opacity(0.42))
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 7 : 9)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            duration >= 1
                                ? LinearGradient(
                                    colors: [accent.opacity(0.98), accent.opacity(0.70)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [textColor.opacity(0.06), textColor.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(duration >= 1 ? 0.12 : 0.04), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .disabled(duration < 1)
            .keyboardShortcut(.defaultAction)
        }
        .padding(compact ? 10 : 12)
        .background(
            RoundedRectangle(cornerRadius: compact ? 15 : 18, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 15 : 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.045),
                                    accent.opacity(0.025),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 15 : 18, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 0.8)
        )
    }

    private func timerWheelRow(compactMode: Bool) -> some View {
        HStack(spacing: compactMode ? 5 : 8) {
            HaloTimerWheelColumn(
                title: "HRS",
                value: $hours,
                range: 0...99,
                accent: accent,
                textColor: textColor,
                compact: compactMode
            )

            Text(":")
                .font(.system(size: compactMode ? 15 : 21, weight: .medium, design: .rounded))
                .foregroundStyle(textColor.opacity(0.34))
                .offset(y: compactMode ? -3 : -5)

            HaloTimerWheelColumn(
                title: "MIN",
                value: $minutes,
                range: 0...59,
                accent: accent,
                textColor: textColor,
                compact: compactMode
            )

            Text(":")
                .font(.system(size: compactMode ? 15 : 21, weight: .medium, design: .rounded))
                .foregroundStyle(textColor.opacity(0.34))
                .offset(y: compactMode ? -3 : -5)

            HaloTimerWheelColumn(
                title: "SEC",
                value: $seconds,
                range: 0...59,
                accent: accent,
                textColor: textColor,
                compact: compactMode
            )
        }
    }

    private var timerColon: some View {
        Text(":")
            .font(.system(size: compact ? 17 : 21, weight: .medium, design: .rounded))
            .foregroundStyle(textColor.opacity(0.34))
            .offset(y: compact ? -3 : -5)
    }

    private func applyPreset(_ preset: Int) {
        let total = min(359_999, max(1, preset * 60))
        hours = total / 3600
        minutes = total / 60 % 60
        seconds = total % 60
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}


private enum HaloTimerHorizontalUnit: String, CaseIterable, Identifiable {
    case hours = "HH"
    case minutes = "MM"
    case seconds = "SS"

    var id: String { rawValue }
}

struct HaloTimerHorizontalDurationComposer: View {
    let accent: Color
    let textColor: Color
    let quickPresets: [Int]
    let compact: Bool
    let onStart: (TimeInterval) -> Void

    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var selectedUnit: HaloTimerHorizontalUnit = .minutes
    @State private var dragAccumulator: CGFloat = 0
    @State private var lastDragTranslation: CGFloat = 0

    init(
        accent: Color,
        textColor: Color,
        quickPresets: [Int] = [5, 15, 25, 45],
        initialMinutes: Int = 25,
        compact: Bool = false,
        onStart: @escaping (TimeInterval) -> Void
    ) {
        self.accent = accent
        self.textColor = textColor
        self.quickPresets = quickPresets
        self.compact = compact
        self.onStart = onStart

        let total = min(359_999, max(0, initialMinutes * 60))
        _hours = State(initialValue: total / 3600)
        _minutes = State(initialValue: total / 60 % 60)
        _seconds = State(initialValue: total % 60)
    }

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    private var activeValue: Int {
        switch selectedUnit {
        case .hours: return hours
        case .minutes: return minutes
        case .seconds: return seconds
        }
    }

    private var activeUpperBound: Int {
        selectedUnit == .hours ? 99 : 59
    }

    private var uniqueQuickPresets: [Int] {
        var seen = Set<Int>()
        return quickPresets.filter { $0 > 0 && seen.insert($0).inserted }
    }

    private var durationLabel: String {
        String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var visibleQuickPresets: [Int] {
        Array(uniqueQuickPresets.prefix(compact ? 3 : 4))
    }

    private var panelCornerRadius: CGFloat {
        compact ? 13 : 16
    }

    var body: some View {
        VStack(spacing: compact ? 7 : 10) {
            unitSelector
            horizontalScrubber
            actionRow
        }
        .padding(compact ? 8 : 10)
        .background(panelBackground)
        .overlay(panelOutline)
        .accessibilityElement(children: .contain)
    }

    private var unitSelector: some View {
        HStack(spacing: compact ? 5 : 7) {
            ForEach(HaloTimerHorizontalUnit.allCases) { unit in
                unitButton(unit)
            }

            Text(durationLabel)
                .font(durationLabelFont)
                .foregroundStyle(textColor.opacity(0.52))
                .padding(.leading, compact ? 2 : 5)
                .lineLimit(1)
        }
    }

    private var durationLabelFont: Font {
        .system(
            size: compact ? 11 : 12,
            weight: .semibold,
            design: .monospaced
        )
    }

    private func unitButton(_ unit: HaloTimerHorizontalUnit) -> some View {
        let selected = unit == selectedUnit
        let foreground = selected ? Color.white : textColor.opacity(0.58)
        let fill = selected ? accent.opacity(0.72) : textColor.opacity(0.045)
        let stroke = selected ? accent.opacity(0.82) : textColor.opacity(0.06)
        let unitValue = value(for: unit)

        return Button {
            select(unit)
        } label: {
            VStack(spacing: 1) {
                Text(unit.rawValue)
                    .font(.system(
                        size: compact ? 8 : 9,
                        weight: .bold,
                        design: .rounded
                    ))
                    .tracking(0.8)

                Text(String(format: "%02d", unitValue))
                    .font(.system(
                        size: compact ? 13 : 15,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .monospacedDigit()
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(stroke, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            ForEach(visibleQuickPresets, id: \.self) { preset in
                presetButton(preset)
            }

            Spacer(minLength: 6)

            startButton
        }
    }

    private func presetButton(_ preset: Int) -> some View {
        Button {
            applyPreset(preset)
        } label: {
            Text("\(preset)m")
                .font(.system(
                    size: compact ? 8 : 9,
                    weight: .semibold,
                    design: .rounded
                ))
                .padding(.horizontal, compact ? 7 : 9)
                .padding(.vertical, compact ? 4 : 5)
                .background(
                    textColor.opacity(0.045),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        let enabled = duration >= 1
        let foreground = enabled ? Color.white : textColor.opacity(0.35)
        let fill = enabled ? accent.opacity(0.82) : textColor.opacity(0.045)

        return Button {
            guard enabled else { return }
            NSHapticFeedbackManager.defaultPerformer.perform(
                .generic,
                performanceTime: .now
            )
            onStart(duration)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "play.fill")
                    .font(.system(
                        size: compact ? 8 : 9,
                        weight: .bold
                    ))

                Text(enabled ? "Start" : "Set time")
                    .font(.system(
                        size: compact ? 9 : 10,
                        weight: .semibold,
                        design: .rounded
                    ))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, compact ? 5 : 6)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .keyboardShortcut(.defaultAction)
    }

    private var panelBackground: some View {
        let shape = RoundedRectangle(
            cornerRadius: panelCornerRadius,
            style: .continuous
        )

        return shape
            .fill(Color.black.opacity(0.10))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        accent.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            )
    }

    private var panelOutline: some View {
        RoundedRectangle(
            cornerRadius: panelCornerRadius,
            style: .continuous
        )
        .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
    }

    private var horizontalScrubber: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(textColor.opacity(0.075))
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(-4...4, id: \.self) { offset in
                    scrubberTick(offset: offset)
                }
            }

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 0.8)
                .frame(
                    width: compact ? 42 : 50,
                    height: compact ? 38 : 44
                )
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 44 : 50)
        .contentShape(Rectangle())
        .animation(
            .spring(response: 0.20, dampingFraction: 0.86),
            value: activeValue
        )
        .background(horizontalScrollCapture)
        .simultaneousGesture(horizontalDragGesture)
        .help("Scroll sideways or drag to change \(selectedUnit.rawValue)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(selectedUnit.rawValue) value")
        .accessibilityValue("\(activeValue)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustActive(by: 1)
            case .decrement:
                adjustActive(by: -1)
            @unknown default:
                break
            }
        }
    }

    private func scrubberTick(offset: Int) -> some View {
        let displayed = displayedValue(offset: offset)
        let isCenter = offset == 0
        let nearCenter = abs(offset) == 1
        let tickOpacity = isCenter ? 0.95 : (nearCenter ? 0.28 : 0.14)
        let textOpacity = isCenter ? 0.98 : (nearCenter ? 0.42 : 0.18)

        return VStack(spacing: 3) {
            Capsule(style: .continuous)
                .fill(
                    isCenter
                        ? accent.opacity(tickOpacity)
                        : textColor.opacity(tickOpacity)
                )
                .frame(
                    width: isCenter ? 2 : 1,
                    height: isCenter ? 12 : 7
                )

            Text(String(format: "%02d", displayed))
                .font(.system(
                    size: isCenter
                        ? (compact ? 14 : 17)
                        : (compact ? 8 : 9),
                    weight: isCenter ? .bold : .medium,
                    design: .rounded
                ))
                .monospacedDigit()
                .foregroundStyle(textColor.opacity(textOpacity))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isCenter else { return }
            setActiveValue(displayed)
        }
    }

    private var horizontalScrollCapture: some View {
        HaloTimerHorizontalScrollCapture { step in
            adjustActive(by: step)
        }
        .allowsHitTesting(true)
    }

    private var horizontalDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { gesture in
                updateDrag(with: gesture.translation.width)
            }
            .onEnded { _ in
                dragAccumulator = 0
                lastDragTranslation = 0
            }
    }

    private func updateDrag(with translation: CGFloat) {
        let delta = translation - lastDragTranslation
        lastDragTranslation = translation
        dragAccumulator += delta

        let threshold: CGFloat = compact ? 12 : 15
        while abs(dragAccumulator) >= threshold {
            adjustActive(by: dragAccumulator < 0 ? 1 : -1)
            dragAccumulator += dragAccumulator < 0 ? threshold : -threshold
        }
    }

    private func select(_ unit: HaloTimerHorizontalUnit) {
        guard selectedUnit != unit else { return }
        selectedUnit = unit
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func value(for unit: HaloTimerHorizontalUnit) -> Int {
        switch unit {
        case .hours: return hours
        case .minutes: return minutes
        case .seconds: return seconds
        }
    }

    private func displayedValue(offset: Int) -> Int {
        let count = activeUpperBound + 1
        let raw = activeValue + offset
        return ((raw % count) + count) % count
    }

    private func adjustActive(by step: Int) {
        guard step != 0 else { return }
        setActiveValue(displayedValue(offset: step > 0 ? 1 : -1))
    }

    private func setActiveValue(_ value: Int) {
        guard value != activeValue else { return }
        switch selectedUnit {
        case .hours: hours = value
        case .minutes: minutes = value
        case .seconds: seconds = value
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func applyPreset(_ preset: Int) {
        let total = min(359_999, max(1, preset * 60))
        hours = total / 3600
        minutes = total / 60 % 60
        seconds = total % 60
        selectedUnit = .minutes
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

private struct HaloTimerHorizontalScrollCapture: NSViewRepresentable {
    let onStep: (Int) -> Void

    final class View: NSView {
        var callback: ((Int) -> Void)?
        private var accumulator: CGFloat = 0

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            let horizontal = event.scrollingDeltaX
            let vertical = event.scrollingDeltaY
            let delta = abs(horizontal) >= abs(vertical) && horizontal != 0 ? horizontal : vertical
            guard delta != 0 else { return }

            if event.phase == .began {
                accumulator = 0
            }

            if event.hasPreciseScrollingDeltas {
                accumulator += delta
                let threshold: CGFloat = 10
                while abs(accumulator) >= threshold {
                    callback?(accumulator < 0 ? 1 : -1)
                    accumulator += accumulator < 0 ? threshold : -threshold
                }
            } else {
                callback?(delta < 0 ? 1 : -1)
            }

            if event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended {
                accumulator = 0
            }
        }
    }

    func makeNSView(context: Context) -> View {
        let view = View()
        view.callback = onStep
        return view
    }

    func updateNSView(_ nsView: View, context: Context) {
        nsView.callback = onStep
    }
}

struct HaloTimerDurationPopoverButton: View {
    @Environment(\.openNotchInteractionHold) private var holdOpen
    let accent: Color
    let textColor: Color
    let quickPresets: [Int]
    let initialMinutes: Int
    let label: String
    let onStart: (TimeInterval) -> Void

    @State private var showing = false

    init(
        accent: Color,
        textColor: Color,
        quickPresets: [Int] = [5, 15, 25, 45],
        initialMinutes: Int = 25,
        label: String = "Set timer",
        onStart: @escaping (TimeInterval) -> Void
    ) {
        self.accent = accent
        self.textColor = textColor
        self.quickPresets = quickPresets
        self.initialMinutes = initialMinutes
        self.label = label
        self.onStart = onStart
    }

    var body: some View {
        Button {
            showing = true
        } label: {
            Label(label, systemImage: "dial.medium")
        }
        .popover(isPresented: $showing, arrowEdge: .top) {
            GeometryReader { proxy in
                HaloTimerHorizontalDurationComposer(
                    accent: accent,
                    textColor: textColor,
                    quickPresets: quickPresets,
                    initialMinutes: initialMinutes,
                    compact: proxy.size.width < 360 || proxy.size.height < 210
                ) { duration in
                    showing = false
                    onStart(duration)
                }
                .padding(proxy.size.width < 360 ? 8 : 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(
                minWidth: 300,
                idealWidth: 430,
                maxWidth: 520,
                minHeight: 165,
                idealHeight: 205,
                maxHeight: 230
            )
        }
        .onChange(of: showing) { value in
            holdOpen(value)
        }
        .onDisappear {
            if showing {
                holdOpen(false)
            }
        }
    }
}

private struct HaloTimerWheelColumn: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let accent: Color
    let textColor: Color
    let compact: Bool

    @State private var dragAccumulator: CGFloat = 0
    @State private var lastDragTranslation: CGFloat = 0

    private var rowHeight: CGFloat { compact ? 24 : 29 }
    private var width: CGFloat { compact ? 50 : 62 }

    var body: some View {
        VStack(spacing: compact ? 4 : 5) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                    .fill(Color.black.opacity(0.16))

                RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.17), accent.opacity(0.075)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 8 : 9, style: .continuous)
                            .stroke(accent.opacity(0.28), lineWidth: 0.8)
                    )
                    .frame(height: rowHeight)

                VStack(spacing: 0) {
                    ForEach(-2...2, id: \.self) { offset in
                        let displayed = displayedValue(offset: offset)
                        Text(String(format: "%02d", displayed))
                            .font(.system(
                                size: offset == 0 ? (compact ? 15 : 17) : (compact ? 11 : 12),
                                weight: offset == 0 ? .semibold : .regular,
                                design: .rounded
                            ))
                            .monospacedDigit()
                            .foregroundStyle(
                                offset == 0
                                    ? textColor.opacity(0.98)
                                    : textColor.opacity(abs(offset) == 1 ? 0.38 : 0.16)
                            )
                            .scaleEffect(offset == 0 ? 1 : (abs(offset) == 1 ? 0.94 : 0.88))
                            .frame(height: rowHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard offset != 0 else { return }
                                set(displayed)
                            }
                    }
                }
                .animation(.spring(response: 0.20, dampingFraction: 0.86), value: value)

                VStack {
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: rowHeight * 1.1)
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: rowHeight * 1.1)
                }
                .allowsHitTesting(false)
            }
            .frame(width: width, height: rowHeight * 5)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 11 : 13, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
            )
            .background(
                HaloTimerWheelScrollCapture { step in
                    adjust(by: step)
                }
                .allowsHitTesting(true)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { gesture in
                        let delta = gesture.translation.height - lastDragTranslation
                        lastDragTranslation = gesture.translation.height
                        dragAccumulator += delta
                        let threshold: CGFloat = compact ? 13 : 16

                        while abs(dragAccumulator) >= threshold {
                            adjust(by: dragAccumulator < 0 ? 1 : -1)
                            dragAccumulator += dragAccumulator < 0 ? threshold : -threshold
                        }
                    }
                    .onEnded { _ in
                        dragAccumulator = 0
                        lastDragTranslation = 0
                    }
            )

            Text(title)
                .font(.system(size: compact ? 7 : 8, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(textColor.opacity(0.38))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: 1)
            case .decrement: adjust(by: -1)
            @unknown default: break
            }
        }
    }

    private func displayedValue(offset: Int) -> Int {
        let count = range.upperBound - range.lowerBound + 1
        guard count > 0 else { return value }
        let raw = value - range.lowerBound + offset
        let wrapped = ((raw % count) + count) % count
        return range.lowerBound + wrapped
    }

    private func adjust(by step: Int) {
        guard step != 0 else { return }
        set(displayedValue(offset: step > 0 ? 1 : -1))
    }

    private func set(_ newValue: Int) {
        guard newValue != value else { return }
        value = newValue
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

private struct HaloTimerWheelScrollCapture: NSViewRepresentable {
    let onStep: (Int) -> Void

    final class View: NSView {
        var callback: ((Int) -> Void)?
        private var accumulator: CGFloat = 0

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            let delta = event.scrollingDeltaY == 0 ? event.scrollingDeltaX : event.scrollingDeltaY
            guard delta != 0 else { return }

            if event.phase == .began {
                accumulator = 0
            }

            if event.hasPreciseScrollingDeltas {
                accumulator += delta
                let threshold: CGFloat = 10
                while abs(accumulator) >= threshold {
                    callback?(accumulator < 0 ? 1 : -1)
                    accumulator += accumulator < 0 ? threshold : -threshold
                }
            } else {
                callback?(delta < 0 ? 1 : -1)
            }

            if event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended {
                accumulator = 0
            }
        }
    }

    func makeNSView(context: Context) -> View {
        let view = View()
        view.callback = onStep
        return view
    }

    func updateNSView(_ nsView: View, context: Context) {
        nsView.callback = onStep
    }
}

/// Large catalogs are built only when opened; scrolling creates visible rows lazily.
struct SearchableStringPicker: View {
    let title: String
    @Binding var selection: String
    let values: [String]
    var emptyLabel = "System default"
    @State private var showing = false
    @State private var search = ""
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(selection.isEmpty ? emptyLabel : selection) { search = ""; showing = true }
                .lineLimit(1)
                .popover(isPresented: $showing) {
                    VStack(spacing: 10) {
                        TextField("Search \(title.lowercased())", text: $search).textFieldStyle(.roundedBorder)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(values.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { value in
                                    Button { selection = value; showing = false } label: {
                                        HStack {
                                            Text(value.isEmpty ? emptyLabel : value)
                                            Spacer()
                                            if selection == value { Image(systemName: "checkmark") }
                                        }.padding(6).contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }.padding(12).frame(width: 340, height: 320)
                }
        }
    }
}

extension WidgetColor {
    var color: Color { Color(red: red, green: green, blue: blue) }
    init(_ color: Color) {
        let rgb = NSColor(color).usingColorSpace(.deviceRGB) ?? .white
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}
extension WidgetStyle {
    func font(scale: Double = 1) -> Font {
        let weight: Font.Weight
        switch self.weight {
        case .light: weight = .light
        case .regular: weight = .regular
        case .medium: weight = .medium
        case .semibold: weight = .semibold
        case .bold: weight = .bold
        }
        if fontFamily == .custom { return .custom(customFont, size: fontSize * scale).weight(weight) }
        let design: Font.Design
        switch fontFamily {
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .monospaced: design = .monospaced
        default: design = .default
        }
        return .system(size: fontSize * scale, weight: weight, design: design)
    }
}
extension WidgetContentAlignment {
    var horizontal: HorizontalAlignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
    var alignment: Alignment {
        switch self { case .leading: return .topLeading; case .center: return .top; case .trailing: return .topTrailing }
    }
}
extension WidgetControlSize {
    var swiftUI: ControlSize {
        switch self { case .mini: return .mini; case .small: return .small; case .regular: return .regular; case .large: return .large }
    }
}
private struct WidgetStyleKey: EnvironmentKey { static let defaultValue = WidgetStyle() }
extension EnvironmentValues {
    var widgetStyle: WidgetStyle {
        get { self[WidgetStyleKey.self] }
        set { self[WidgetStyleKey.self] = newValue }
    }
}


private struct OpenNotchInteractionHoldEnvironmentKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}
extension EnvironmentValues {
    var openNotchInteractionHold: (Bool) -> Void {
        get { self[OpenNotchInteractionHoldEnvironmentKey.self] }
        set { self[OpenNotchInteractionHoldEnvironmentKey.self] = newValue }
    }
}

private struct OpenNotchPresentationEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchPresentation = .regular }
private struct OpenNotchCompressionEnvironmentKey: EnvironmentKey { static let defaultValue = 0 }
private struct OpenNotchAvailableWidthEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchAvailableHeightEnvironmentKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }
private struct OpenNotchGridColumnSpanEnvironmentKey: EnvironmentKey { static let defaultValue: Int? = nil }
private struct OpenNotchGridRowSpanEnvironmentKey: EnvironmentKey { static let defaultValue: Int? = nil }
private struct OpenNotchBlockVerticalAlignmentEnvironmentKey: EnvironmentKey { static let defaultValue: OpenNotchBlockVerticalAlignment = .top }
extension EnvironmentValues {
    var openNotchPresentation: OpenNotchPresentation {
        get { self[OpenNotchPresentationEnvironmentKey.self] }
        set { self[OpenNotchPresentationEnvironmentKey.self] = newValue }
    }
    var openNotchCompressionLevel: Int {
        get { self[OpenNotchCompressionEnvironmentKey.self] }
        set { self[OpenNotchCompressionEnvironmentKey.self] = newValue }
    }
    var openNotchAvailableWidth: CGFloat? {
        get { self[OpenNotchAvailableWidthEnvironmentKey.self] }
        set { self[OpenNotchAvailableWidthEnvironmentKey.self] = newValue }
    }
    var openNotchAvailableHeight: CGFloat? {
        get { self[OpenNotchAvailableHeightEnvironmentKey.self] }
        set { self[OpenNotchAvailableHeightEnvironmentKey.self] = newValue }
    }
    var openNotchGridColumnSpan: Int? {
        get { self[OpenNotchGridColumnSpanEnvironmentKey.self] }
        set { self[OpenNotchGridColumnSpanEnvironmentKey.self] = newValue }
    }
    var openNotchGridRowSpan: Int? {
        get { self[OpenNotchGridRowSpanEnvironmentKey.self] }
        set { self[OpenNotchGridRowSpanEnvironmentKey.self] = newValue }
    }
    var openNotchBlockVerticalAlignment: OpenNotchBlockVerticalAlignment {
        get { self[OpenNotchBlockVerticalAlignmentEnvironmentKey.self] }
        set { self[OpenNotchBlockVerticalAlignmentEnvironmentKey.self] = newValue }
    }
}

/// Deliberate Visual Workspace compositions. These are not just density levels:
/// a wide 2×1 slot and a tall 1×2 slot intentionally receive different layouts.
enum VisualWorkspaceWidgetSize: Equatable {
    case glance
    case horizontal
    case vertical
    case standard
    case expanded

    static func resolve(width: CGFloat?, height: CGFloat?, presentation: OpenNotchPresentation) -> VisualWorkspaceWidgetSize? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        let aspect = width / max(1, height)
        let area = width * height

        // Roughly the footprint produced by a 1×1 cell. Keep the test area-aware so
        // resizing the workspace itself does not suddenly turn a wide cell into a square one.
        if (area < 20_000 && aspect > 0.72 && aspect < 1.38) || (width < 132 && height < 132) {
            return .glance
        }
        if aspect >= 1.38 && height < 178 { return .horizontal }
        if aspect <= 0.72 && width < 208 { return .vertical }
        if presentation == .expanded || (width >= 340 && height >= 195 && area >= 72_000) { return .expanded }
        return .standard
    }

    var isCompact: Bool {
        switch self {
        case .glance, .horizontal, .vertical: return true
        case .standard, .expanded: return false
        }
    }
}

extension OpenNotchPriority {
    func remainsVisible(at compression: Int) -> Bool {
        switch self {
        case .alwaysVisible, .high: return true
        case .normal: return compression < 5
        case .low: return compression < 3
        case .optional: return compression < 2
        }
    }
}

extension WidgetFontWeight {
    var swiftUIFontWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

extension WidgetContentAlignment {
    var textAlignment: TextAlignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}

extension WidgetElementEmphasis {
    var fontWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

struct WidgetElementSurface<Content: View>: View {
    let element: WidgetElementStyle
    let widgetStyle: WidgetStyle
    var defaultPriority: OpenNotchPriority = .normal
    @ViewBuilder var content: Content
    @Environment(\.openNotchCompressionLevel) private var compression
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchPresentation) private var presentation

    private var footprint: VisualWorkspaceWidgetSize? {
        VisualWorkspaceWidgetSize.resolve(width: availableWidth, height: availableHeight, presentation: presentation)
    }
    private var adaptiveScale: Double {
        let widthScale = availableWidth.map { min(1, max(0.52, Double($0) / 250)) } ?? 1
        let heightScale = availableHeight.map { min(1, max(0.52, Double($0) / 145)) } ?? 1
        let pressure = max(0.68, 1 - Double(compression) * 0.055)
        let footprintScale: Double
        switch footprint {
        case .glance: footprintScale = 0.82
        case .horizontal, .vertical: footprintScale = 0.91
        case .standard, .expanded, .none: footprintScale = 1
        }
        return min(widthScale, heightScale) * pressure * footprintScale
    }
    private var priority: OpenNotchPriority { element.priority ?? defaultPriority }
    private var remainsVisibleForFootprint: Bool {
        guard let footprint else { return true }
        switch footprint {
        case .glance:
            return priority == .alwaysVisible || priority == .high
        case .horizontal, .vertical:
            return priority != .optional && priority != .low
        case .standard:
            return priority != .optional || compression < 1
        case .expanded:
            return true
        }
    }
    private var alignment: WidgetContentAlignment { element.alignment ?? widgetStyle.resolvedContent.alignment }
    private var textAlignment: WidgetContentAlignment { element.textAlignment ?? alignment }
    private var foreground: Color {
        switch element.foreground {
        case .inherit: return widgetStyle.textColor.color
        case .secondary: return widgetStyle.textColor.color.opacity(0.62)
        case .accent: return widgetStyle.accentColor.color
        case .custom: return element.customForeground.color
        }
    }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: element.cornerRadius, style: .continuous) }
    private var font: Font {
        let family = element.fontFamily ?? widgetStyle.fontFamily
        let size = (element.fontSize ?? (widgetStyle.fontSize * element.fontScale)) * adaptiveScale
        let weight = element.fontWeight?.swiftUIFontWeight ?? element.emphasis.fontWeight
        if family == .custom { return .custom(element.customFont ?? widgetStyle.customFont, size: size).weight(weight) }
        let design: Font.Design
        switch family { case .rounded: design = .rounded; case .serif: design = .serif; case .monospaced: design = .monospaced; default: design = .default }
        return .system(size: size, weight: weight, design: design)
    }
    private var controlSize: ControlSize {
        let density = element.contentDensity ?? 1
        if footprint == .glance || compression >= 3 || density <= 0.7 { return .mini }
        if footprint?.isCompact == true || compression >= 1 || density <= 0.9 { return .small }
        if density >= 1.3 { return .large }
        return widgetStyle.resolvedContent.controlSize.swiftUI
    }

    @ViewBuilder private var elementBackground: some View {
        switch element.background {
        case .none: EmptyView()
        case .subtle: shape.fill(widgetStyle.textColor.color.opacity(element.backgroundOpacity * 0.16))
        case .accent: shape.fill(widgetStyle.accentColor.color.opacity(element.backgroundOpacity))
        case .glass: shape.fill(.ultraThinMaterial).opacity(max(0.15, element.backgroundOpacity))
        case .custom: shape.fill(element.backgroundColor.color.opacity(element.backgroundOpacity))
        }
    }

    var body: some View {
        if element.visible && priority.remainsVisible(at: compression) && remainsVisibleForFootprint {
            content
                .font(font)
                .foregroundStyle(foreground)
                .tint((element.tintColor ?? widgetStyle.accentColor).color.opacity(element.tintOpacity ?? 1))
                .multilineTextAlignment(textAlignment.textAlignment)
                .controlSize(controlSize)
                .opacity(element.opacity)
                .lineLimit(footprint == .glance || compression >= 4 ? 1 : compression >= 2 ? 2 : nil)
                .minimumScaleFactor(footprint == .glance ? 0.82 : compression >= 3 ? 0.72 : 0.86)
                .padding(element.padding * adaptiveScale)
                .background { elementBackground }
                .overlay {
                    if (element.borderWidth ?? 0) > 0 && (element.borderOpacity ?? 0) > 0 {
                        shape.stroke((element.borderColor ?? widgetStyle.textColor).color.opacity(element.borderOpacity ?? 0), lineWidth: element.borderWidth ?? 0)
                    }
                }
                .shadow(color: .black.opacity(element.shadowOpacity ?? 0), radius: element.shadowBlur ?? 0)
                .offset(x: element.xOffset ?? 0, y: element.yOffset ?? 0)
                .padding(.vertical, (element.externalSpacing ?? 0) * adaptiveScale * 0.5)
                .frame(maxWidth: .infinity, alignment: alignment.alignment)
        }
    }
}

struct WidgetElement<Content: View>: View {
    let key: String
    var defaultVisible = true
    var defaultPriority: OpenNotchPriority = .normal
    @ViewBuilder var content: Content
    @Environment(\.widgetStyle) private var style

    init(key: String, defaultVisible: Bool = true, defaultPriority: OpenNotchPriority = .normal,
         @ViewBuilder content: () -> Content) {
        self.key = key; self.defaultVisible = defaultVisible; self.defaultPriority = defaultPriority; self.content = content()
    }

    var body: some View {
        let element = style.elementStyle(for: key, defaultVisible: defaultVisible)
        if element.visible {
            VStack(alignment: (element.alignment ?? style.resolvedContent.alignment).horizontal, spacing: 4) {
                WidgetElementSurface(element: element, widgetStyle: style, defaultPriority: defaultPriority) { content }
                if element.dividerAfter { Divider().opacity(0.45) }
            }
            .frame(maxWidth: .infinity, alignment: (element.alignment ?? style.resolvedContent.alignment).alignment)
        }
    }
}

struct WidgetCard<Content: View>: View {
    let style: WidgetStyle
    var availableHeight: CGFloat? = nil
    var availableWidth: CGFloat? = nil
    var fillsCell = false
    @ViewBuilder var content: Content
    @Environment(\.openNotchCompressionLevel) private var compression
    @Environment(\.openNotchBlockVerticalAlignment) private var blockVerticalAlignment
    private var fittedStyle: WidgetStyle {
        var fitted = style
        switch style.resolvedLayoutMode {
        case .standard: break
        case .compact:
            fitted.padding *= 0.78
            fitted.fontSize *= 0.94
        case .hero:
            fitted.fontSize *= 1.10
            fitted.padding *= 1.08
        case .minimal:
            fitted.padding *= 0.72
        case .dense:
            fitted.padding *= 0.62
            fitted.fontSize *= 0.90
        }
        if let width = availableWidth {
            fitted.padding = min(fitted.padding, max(3, width * 0.055))
            fitted.fontSize = min(fitted.fontSize, max(9, width * 0.11))
        }
        if let height = availableHeight {
            fitted.padding = min(fitted.padding, max(2, height * 0.08))
            fitted.minimumHeight = 0
            fitted.fontSize = min(fitted.fontSize, max(9, height * 0.18))
        }
        if fillsCell { fitted.padding = 0; fitted.showTitle = false }
        return fitted
    }
    private var contentOptions: WidgetContentOptions { fittedStyle.resolvedContent }
    private var chrome: WidgetChromeOptions { fittedStyle.resolvedChrome }
    private var innerAvailableWidth: CGFloat? {
        availableWidth.map { max(1, $0 - CGFloat(fittedStyle.padding * 2)) }
    }
    private var innerAvailableHeight: CGFloat? {
        availableHeight.map { max(1, $0 - CGFloat(fittedStyle.padding * 2)) }
    }
    private var styledContent: some View {
        content.environment(\.widgetStyle, fittedStyle)
            .environment(\.openNotchAvailableWidth, innerAvailableWidth)
            .environment(\.openNotchAvailableHeight, innerAvailableHeight)
            .font(fittedStyle.font())
            .foregroundStyle(style.textColor.color).tint(style.accentColor.color)
            .controlSize(contentOptions.controlSize.swiftUI)
            .opacity(chrome.contentOpacity)
    }

    private var shape: RoundedRectangle {
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

    @ViewBuilder private var cardBackground: some View {
        switch fittedStyle.resolvedCardBackgroundStyle {
        case .none:
            Color.clear
        case .solid:
            shape.fill(fittedStyle.backgroundColor.color.opacity(fittedStyle.backgroundOpacity))
        case .gradient:
            shape.fill(
                LinearGradient(
                    colors: [
                        fittedStyle.backgroundColor.color.opacity(fittedStyle.backgroundOpacity),
                        fittedStyle.resolvedBackgroundSecondaryColor.color.opacity(fittedStyle.backgroundOpacity)
                    ],
                    startPoint: UnitPoint(x: 0.5 - 0.5 * cos(fittedStyle.resolvedGradientAngle * .pi / 180),
                                          y: 0.5 - 0.5 * sin(fittedStyle.resolvedGradientAngle * .pi / 180)),
                    endPoint: UnitPoint(x: 0.5 + 0.5 * cos(fittedStyle.resolvedGradientAngle * .pi / 180),
                                        y: 0.5 + 0.5 * sin(fittedStyle.resolvedGradientAngle * .pi / 180))
                )
            )
        case .glass:
            shape.fill(.ultraThinMaterial)
                .opacity(fittedStyle.backgroundOpacity)
                .overlay(shape.fill(fittedStyle.backgroundColor.color.opacity(fittedStyle.resolvedGlassTintOpacity * fittedStyle.backgroundOpacity)))
        case .accent:
            shape.fill(fittedStyle.accentColor.color.opacity(fittedStyle.backgroundOpacity))
        }
    }

    @ViewBuilder private var cardOutline: some View {
        let color = chrome.borderColor.color.opacity(chrome.borderOpacity)
        let width = max(0.5, chrome.borderWidth)
        switch fittedStyle.resolvedOutlineStyle {
        case .none:
            EmptyView()
        case .solid:
            shape.stroke(color, lineWidth: width)
        case .dashed:
            shape.stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, dash: [7, 5]))
        case .double:
            shape.stroke(color, lineWidth: width)
                .overlay(shape.inset(by: max(3, width + 2)).stroke(color.opacity(0.70), lineWidth: max(0.5, width * 0.65)))
        case .glow:
            shape.stroke(color, lineWidth: width)
                .shadow(color: chrome.borderColor.color.opacity(max(0.20, chrome.borderOpacity)), radius: max(5, width * 3))
        }
    }

    var body: some View {
        Group {
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
                .frame(maxWidth: .infinity, alignment: contentFrameAlignment)
                .frame(height: innerHeight, alignment: contentFrameAlignment)
                .padding(padding)
                .frame(height: max(0, height))
                .clipped()
            } else {
                styledContent
                    .frame(maxWidth: .infinity, minHeight: style.minimumHeight, alignment: contentOptions.alignment.alignment)
                    .padding(style.padding)
            }
        }
        .background { cardBackground }
        .overlay { cardOutline }
        .shadow(color: .black.opacity(chrome.shadowOpacity), radius: chrome.shadowRadius, y: chrome.shadowY)
        .frame(width: availableWidth)
        .frame(maxWidth: style.width > 0 ? style.width : .infinity)
        .frame(maxWidth: .infinity, alignment: contentOptions.alignment.alignment)
    }
}
private enum ClockLayoutFamily: String, Equatable {
    case micro
    case horizontalCompact
    case verticalCompact
    case standard
    case wide
    case tall
    case large
    case hero

    static func exact(columns: Int, rows: Int) -> ClockLayoutFamily {
        let columns = max(1, columns)
        let rows = max(1, rows)
        if columns == 1 && rows == 1 { return .micro }
        if rows == 1 { return columns <= 3 ? .horizontalCompact : .wide }
        if columns == 1 { return rows <= 2 ? .verticalCompact : .tall }
        if columns >= 7 && rows >= 4 { return .hero }
        if (columns >= 5 && rows >= 3) || columns * rows >= 16 { return .large }
        if columns >= 4 && rows == 2 { return .wide }
        if rows >= 3 && columns <= 2 { return .tall }
        if columns >= 3 && rows >= 3 { return .large }
        return .standard
    }

    static func fallback(width: CGFloat, height: CGFloat, previous: ClockLayoutFamily?) -> ClockLayoutFamily {
        let width = max(1, width)
        let height = max(1, height)
        let aspect = width / height
        if previous == .micro, width < 158, height < 158 { return .micro }
        if previous == .horizontalCompact, aspect > 1.40, height < 188 { return .horizontalCompact }
        if previous == .wide, aspect > 1.48, width > 285 { return .wide }
        if previous == .verticalCompact, aspect < 0.82, width < 214, height < 280 { return .verticalCompact }
        if previous == .tall, aspect < 0.94, height > 220 { return .tall }
        if previous == .hero, width > 470, height > 270 { return .hero }
        if previous == .large, width > 320, height > 205 { return .large }

        if width < 138 && height < 138 { return .micro }
        if width >= 520 && height >= 310 { return .hero }
        if aspect >= 2.25 && height < 190 { return width >= 345 ? .wide : .horizontalCompact }
        if aspect <= 0.70 && width < 210 { return height >= 280 ? .tall : .verticalCompact }
        if width >= 355 && height >= 225 { return .large }
        if aspect >= 1.58 { return .wide }
        if aspect <= 0.84 { return .tall }
        return .standard
    }

    var complicationCapacity: Int {
        switch self {
        case .micro: return 0
        case .horizontalCompact, .verticalCompact: return 1
        case .standard: return 2
        case .wide, .tall: return 3
        case .large: return 4
        case .hero: return 6
        }
    }
}

private extension ClockFontWidth {
    var swiftUI: Font.Width {
        switch self {
        case .compressed: return .compressed
        case .condensed: return .condensed
        case .standard: return .standard
        case .expanded: return .expanded
        }
    }
}

private struct ClockTimeParts {
    let hour: String
    let minute: String
    let second: String
    let ampm: String
}

private struct AdaptiveAnalogClockFace: View {
    let date: Date
    let style: WidgetStyle
    let clock: ClockOptions
    let diameter: CGFloat
    let showSeconds: Bool

    private var options: ClockAnalogOptions { clock.resolvedAnalog }
    private var timeZone: TimeZone { TimeZone(identifier: clock.timeZone) ?? .current }

    var body: some View {
        let size = max(44, diameter)
        ZStack {
            Circle()
                .fill(options.faceColor.color.opacity(options.faceOpacity))
                .overlay(Circle().stroke((clock.secondaryColor ?? style.textColor).color.opacity(0.13), lineWidth: 1))
            Canvas { context, canvas in
                let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let radius = min(canvas.width, canvas.height) / 2
                if options.minuteTicks {
                    for tick in 0..<60 {
                        let major = tick.isMultiple(of: 5)
                        let outer = radius * 0.88
                        let inner = radius * (major ? 0.76 : 0.82)
                        let angle = Double(tick) / 60 * .pi * 2 - .pi / 2
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(path, with: .color(options.tickColor.color.opacity(major ? 0.66 : 0.28)), lineWidth: major ? options.tickThickness * 1.35 : options.tickThickness * 0.65)
                    }
                } else if options.hourTicks {
                    for tick in 0..<12 {
                        let outer = radius * 0.88
                        let inner = radius * 0.76
                        let angle = Double(tick) / 12 * .pi * 2 - .pi / 2
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(path, with: .color(options.tickColor.color.opacity(0.62)), lineWidth: options.tickThickness)
                    }
                }

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
                let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
                let minute = Double(components.minute ?? 0) + Double(components.second ?? 0) / 60
                let smoothSecond = Double(components.second ?? 0) + (options.smoothSecondHand ? Double(components.nanosecond ?? 0) / 1_000_000_000 : 0)

                func hand(angleDegrees: Double, length: Double, width: Double, color: Color) {
                    let angle = angleDegrees * .pi / 180 - .pi / 2
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + cos(angle) * radius * length, y: center.y + sin(angle) * radius * length))
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
                if options.showHourHand { hand(angleDegrees: hour / 12 * 360, length: options.hourHandLength, width: options.handThickness * 1.25, color: options.hourHandColor.color) }
                if options.showMinuteHand { hand(angleDegrees: minute / 60 * 360, length: options.minuteHandLength, width: options.handThickness, color: options.minuteHandColor.color) }
                if showSeconds && options.showSecondHand { hand(angleDegrees: smoothSecond / 60 * 360, length: options.secondHandLength, width: max(0.6, options.handThickness * 0.48), color: options.secondHandColor.color) }
            }
            if options.numerals != .none && size >= 82 {
                GeometryReader { proxy in
                    let radius = min(proxy.size.width, proxy.size.height) * 0.365
                    let roman = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
                    ForEach(0..<12, id: \.self) { index in
                        let angle = Double(index) / 12 * .pi * 2 - .pi / 2
                        let label = options.numerals == .roman ? roman[index] : String(index == 0 ? 12 : index)
                        Text(label)
                            .font(.system(size: max(7, size * 0.075), weight: .medium, design: .rounded))
                            .foregroundStyle((clock.secondaryColor ?? style.textColor).color.opacity(0.72))
                            .position(x: proxy.size.width / 2 + cos(angle) * radius,
                                      y: proxy.size.height / 2 + sin(angle) * radius)
                    }
                }
            }
            if options.centerCap {
                Circle().fill(options.secondHandColor.color).frame(width: max(4, size * 0.045), height: max(4, size * 0.045))
                    .overlay(Circle().stroke(Color.black.opacity(0.28), lineWidth: 0.5))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Analog clock")
    }
}

private struct ClockFlipDigit: View {
    let digit: Character
    let height: CGFloat
    let color: Color
    let accent: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(5, height * 0.10), style: .continuous)
                .fill(Color.black.opacity(0.32))
                .overlay(RoundedRectangle(cornerRadius: max(5, height * 0.10)).stroke(Color.white.opacity(0.08), lineWidth: 1))
            Rectangle().fill(Color.black.opacity(0.35)).frame(height: 1)
            Text(String(digit))
                .font(.system(size: height * 0.62, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .shadow(color: accent.opacity(0.10), radius: 8)
        }
        .frame(width: height * 0.54, height: height)
        .animation(.snappy(duration: 0.24), value: digit)
    }
}

private struct ClockDotMatrixBackdrop: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 8
            var x: CGFloat = 4
            while x < size.width {
                var y: CGFloat = 4
                while y < size.height {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)), with: .color(.white.opacity(0.055)))
                    y += spacing
                }
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

struct WidgetClock: View {
    let style: WidgetStyle
    var compact = false
    var workspace: WorkspaceStore? = nil
    var store: AppStore? = nil
    var weatherSummary: String? = nil
    var temperatureText: String? = nil
    var sunrise: Date? = nil
    var sunset: Date? = nil

    @Environment(\.openNotchPresentation) private var presentation
    @Environment(\.openNotchAvailableWidth) private var availableWidth
    @Environment(\.openNotchAvailableHeight) private var availableHeight
    @Environment(\.openNotchGridColumnSpan) private var gridColumns
    @Environment(\.openNotchGridRowSpan) private var gridRows
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var clockNamespace
    @State private var fallbackFamily: ClockLayoutFamily = .standard

    private var clock: ClockOptions { style.clock }
    private var width: CGFloat { max(72, availableWidth ?? (compact ? 220 : 320)) }
    private var height: CGFloat { max(44, availableHeight ?? (compact ? 58 : 180)) }
    private var sizeOverride: ClockSizeOverride? { clock.sizeOverride(columns: gridColumns, rows: gridRows) }
    private var visualStyle: ClockVisualStyle { sizeOverride?.style ?? clock.resolvedVisualStyle }
    private var family: ClockLayoutFamily {
        if compact { return .horizontalCompact }
        if let gridColumns, let gridRows { return .exact(columns: gridColumns, rows: gridRows) }
        return fallbackFamily
    }
    private var timeZone: TimeZone { TimeZone(identifier: clock.timeZone) ?? .current }
    private var primaryColor: Color { (clock.primaryColor ?? style.textColor).color }
    private var secondaryColor: Color { (clock.secondaryColor ?? style.textColor).color.opacity(0.62) }
    private var separatorColor: Color { (clock.separatorColor ?? style.accentColor).color }
    private var accentColor: Color { style.accentColor.color }
    private var geometrySignature: String { "\(Int(width.rounded()))x\(Int(height.rounded()))" }

    var body: some View {
        Group {
            if visualStyle == .analog && clock.showSeconds && clock.resolvedAnalog.smoothSecondHand && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in clockBody(date: context.date) }
            } else {
                TimelineView(.periodic(from: .now, by: clock.showSeconds || clock.resolvedBlinkingSeparator ? 1 : 15)) { context in clockBody(date: context.date) }
            }
        }
        .onAppear { updateFallbackFamily() }
        .onChange(of: geometrySignature) { _ in updateFallbackFamily() }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86), value: family)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: visualStyle)
    }

    private func updateFallbackFamily() {
        guard gridColumns == nil || gridRows == nil else { return }
        fallbackFamily = .fallback(width: width, height: height, previous: fallbackFamily)
    }

    @ViewBuilder private func clockBody(date: Date) -> some View {
        let complications = visibleComplications(date: date)
        switch family {
        case .micro:
            primaryClock(date: date, family: .micro)
                .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .horizontalCompact:
            if compact {
                primaryClock(date: date, family: .horizontalCompact)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.resolvedContent.alignment.alignment)
            } else {
                HStack(spacing: max(8, style.resolvedContent.spacing * 0.65)) {
                    primaryClock(date: date, family: .horizontalCompact)
                        .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                    if let complication = complications.first {
                        Spacer(minLength: 6)
                        compactComplication(complication, date: date, horizontal: true)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .verticalCompact:
            VStack(spacing: max(6, style.resolvedContent.spacing * 0.60)) {
                primaryClock(date: date, family: .verticalCompact)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                if let complication = complications.first {
                    compactComplication(complication, date: date, horizontal: false)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .standard:
            VStack(spacing: max(6, style.resolvedContent.spacing * 0.72)) {
                Spacer(minLength: 0)
                primaryClock(date: date, family: .standard)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                if let dateComp = complications.first(where: { $0 == .date || $0 == .day }) {
                    compactComplication(dateComp, date: date, horizontal: false)
                        .matchedGeometryEffect(id: "clock-date", in: clockNamespace)
                } else if let complication = complications.first {
                    compactComplication(complication, date: date, horizontal: false)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .wide:
            HStack(alignment: .center, spacing: max(14, style.resolvedContent.spacing)) {
                primaryClock(date: date, family: .wide)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !complications.isEmpty {
                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(Array(complications.prefix(3)), id: \.self) { complication in
                            compactComplication(complication, date: date, horizontal: true)
                        }
                    }
                    .frame(maxWidth: min(230, width * 0.40), alignment: .trailing)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .tall:
            VStack(spacing: max(10, style.resolvedContent.spacing)) {
                primaryClock(date: date, family: .tall)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                if !complications.isEmpty {
                    Divider().opacity(0.16)
                    VStack(spacing: 7) {
                        ForEach(Array(complications.prefix(3)), id: \.self) { complication in
                            compactComplication(complication, date: date, horizontal: false)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .large:
            VStack(spacing: max(10, style.resolvedContent.spacing * 0.9)) {
                largeHeader(date: date, complications: complications)
                Spacer(minLength: 0)
                primaryClock(date: date, family: .large)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                Spacer(minLength: 0)
                complicationRow(complications, date: date, limit: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .hero:
            heroClock(date: date, complications: complications)
        }
    }

    @ViewBuilder private func primaryClock(date: Date, family: ClockLayoutFamily) -> some View {
        let parts = timeParts(date)
        switch visualStyle {
        case .digital:
            if family == .verticalCompact || family == .tall {
                stackedTime(parts: parts, family: family, editorial: false)
            } else {
                digitalTime(parts: parts, date: date, family: family)
            }
        case .minimal:
            digitalTime(parts: parts, date: date, family: family, minimal: true)
        case .analog:
            let diameter = analogDiameter(for: family)
            AdaptiveAnalogClockFace(date: date, style: style, clock: clock, diameter: diameter, showSeconds: shouldShowSeconds(in: family))
        case .flip:
            flipTime(parts: parts, family: family)
        case .editorial:
            editorialTime(parts: parts, date: date, family: family)
        case .stacked:
            stackedTime(parts: parts, family: family, editorial: false)
        case .split:
            splitTime(parts: parts, family: family)
        case .terminal:
            terminalTime(parts: parts, family: family)
        case .lcd:
            lcdTime(parts: parts, date: date, family: family)
        case .dotMatrix:
            dotMatrixTime(parts: parts, date: date, family: family)
        case .outline:
            outlineTime(parts: parts, date: date, family: family)
        case .oversizedTypography:
            oversizedTime(parts: parts, date: date, family: family)
        }
    }

    private func timeParts(_ date: Date) -> ClockTimeParts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour24 = components.hour ?? 0
        let displayHour = clock.twentyFourHour ? hour24 : (hour24 % 12 == 0 ? 12 : hour24 % 12)
        let hour = clock.resolvedLeadingZero ? String(format: "%02d", displayHour) : String(displayHour)
        let minute = String(format: "%02d", components.minute ?? 0)
        let second = String(format: "%02d", components.second ?? 0)
        return ClockTimeParts(hour: hour, minute: minute, second: second, ampm: hour24 < 12 ? "AM" : "PM")
    }

    private func shouldShowSeconds(in family: ClockLayoutFamily) -> Bool {
        guard clock.showSeconds else { return false }
        switch family {
        case .micro: return false
        case .horizontalCompact: return width >= 300
        case .verticalCompact: return height >= 220
        default: return true
        }
    }

    private func timeFontSize(for family: ClockLayoutFamily) -> CGFloat {
        if !clock.usesAutomaticTypography {
            let multiplier: CGFloat
            switch family { case .micro: multiplier = 1.45; case .horizontalCompact, .verticalCompact: multiplier = 1.55; case .standard: multiplier = 2; case .wide, .tall: multiplier = 2.25; case .large: multiplier = 2.65; case .hero: multiplier = 3.1 }
            return CGFloat(style.fontSize * clock.resolvedTimeScale) * multiplier
        }
        let raw: CGFloat
        switch family {
        case .micro: raw = min(height * 0.40, width * 0.235)
        case .horizontalCompact: raw = min(height * 0.46, width * 0.17)
        case .verticalCompact: raw = min(height * 0.22, width * 0.42)
        case .standard: raw = min(height * 0.34, width * 0.18)
        case .wide: raw = min(height * 0.46, width * 0.14)
        case .tall: raw = min(height * 0.21, width * 0.42)
        case .large: raw = min(height * 0.31, width * 0.15)
        case .hero: raw = min(height * 0.28, width * 0.105)
        }
        return max(18, raw * CGFloat(clock.resolvedTimeScale))
    }

    private func dateFontSize(for family: ClockLayoutFamily) -> CGFloat {
        let time = timeFontSize(for: family)
        let base = time / CGFloat(clock.resolvedTimeDateRatio) * CGFloat(clock.resolvedDateScale)
        return min(24, max(9, base))
    }

    private func secondaryFontSize(for family: ClockLayoutFamily) -> CGFloat {
        min(18, max(8, dateFontSize(for: family) * 0.88 * CGFloat(clock.resolvedSecondaryScale)))
    }

    private func clockFont(size: CGFloat, weight: Font.Weight? = nil, forceDesign: Font.Design? = nil) -> Font {
        let resolvedWeight = weight ?? style.weight.swiftUIFontWeight
        let font: Font
        if style.fontFamily == .custom {
            font = .custom(style.customFont, size: size).weight(resolvedWeight)
        } else {
            let design: Font.Design
            if let forceDesign { design = forceDesign }
            else {
                switch style.fontFamily {
            case .rounded: design = .rounded
            case .serif: design = .serif
            case .monospaced: design = .monospaced
            case .system, .custom: design = .default
            }
            }
            font = .system(size: size, weight: resolvedWeight, design: design)
        }
        return font.width(clock.resolvedFontWidth.swiftUI)
    }

    @ViewBuilder private func digit(_ text: String, size: CGFloat, emphasis: Double = 1, color: Color? = nil, weight: Font.Weight? = nil, forceDesign: Font.Design? = nil) -> some View {
        let view = Text(text)
            .font(clockFont(size: size * CGFloat(emphasis), weight: weight, forceDesign: forceDesign))
            .tracking(clock.resolvedTracking)
            .foregroundStyle(color ?? primaryColor)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
        if clock.usesMonospacedDigits { view.monospacedDigit() } else { view }
    }

    @ViewBuilder private func digitalTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily, minimal: Bool = false) -> some View {
        let size = timeFontSize(for: family)
        let showSeconds = !minimal && shouldShowSeconds(in: family)
        let showAMPM = !clock.twentyFourHour && clock.resolvedShowAMPM && family != .micro && !minimal
        let separatorOpacity = clock.resolvedBlinkingSeparator && !reduceMotion && Int(date.timeIntervalSince1970) % 2 != 0 ? 0.18 : 1.0
        HStack(alignment: .firstTextBaseline, spacing: max(0, clock.resolvedDigitSpacing)) {
            digit(parts.hour, size: size, emphasis: clock.resolvedHourEmphasis)
            Text(clock.resolvedSeparator.glyph)
                .font(clockFont(size: size * 0.86, weight: .regular))
                .foregroundStyle(separatorColor)
                .opacity(separatorOpacity)
            digit(parts.minute, size: size, emphasis: clock.resolvedMinuteEmphasis)
            if showSeconds {
                Text(clock.resolvedSeparator.glyph)
                    .font(clockFont(size: size * 0.54, weight: .regular))
                    .foregroundStyle(separatorColor.opacity(0.78))
                    .opacity(separatorOpacity)
                digit(parts.second, size: size, emphasis: clock.resolvedSecondsEmphasis, color: secondaryColor)
            }
            if showAMPM {
                Text(parts.ampm)
                    .font(clockFont(size: max(8, size * 0.23), weight: .semibold))
                    .foregroundStyle(secondaryColor)
                    .padding(.leading, max(1, size * 0.02))
            }
        }
        .shadow(color: accentColor.opacity(clock.resolvedTextGlow * 0.32), radius: clock.resolvedTextGlow * 16)
        .shadow(color: .black.opacity(clock.resolvedTextShadow * 0.42), radius: clock.resolvedTextShadow * 10, y: clock.resolvedTextShadow * 2)
    }

    @ViewBuilder private func stackedTime(parts: ClockTimeParts, family: ClockLayoutFamily, editorial: Bool) -> some View {
        let size = max(24, min(width * 0.48, height * (family == .verticalCompact ? 0.26 : 0.22))) * CGFloat(clock.resolvedTimeScale)
        VStack(spacing: max(0, size * 0.02)) {
            digit(parts.hour, size: size, emphasis: clock.resolvedHourEmphasis, forceDesign: editorial ? .serif : nil)
            Rectangle().fill(separatorColor.opacity(0.42)).frame(width: min(width * 0.58, size * 1.3), height: 1)
            digit(parts.minute, size: size, emphasis: clock.resolvedMinuteEmphasis, forceDesign: editorial ? .serif : nil)
            if shouldShowSeconds(in: family) {
                digit(parts.second, size: size * 0.42, emphasis: clock.resolvedSecondsEmphasis, color: secondaryColor)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func splitTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family)
        let vertical = family == .verticalCompact || family == .tall
        if vertical {
            VStack(spacing: 7) { splitCell(parts.hour, size: size); splitCell(parts.minute, size: size) }
        } else {
            HStack(spacing: 8) { splitCell(parts.hour, size: size); splitCell(parts.minute, size: size) }
        }
    }

    private func splitCell(_ text: String, size: CGFloat) -> some View {
        digit(text, size: size * 0.86, weight: .semibold)
            .padding(.horizontal, max(8, size * 0.18)).padding(.vertical, max(6, size * 0.10))
            .background(primaryColor.opacity(0.055), in: RoundedRectangle(cornerRadius: max(8, size * 0.15), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: max(8, size * 0.15)).stroke(primaryColor.opacity(0.10), lineWidth: 1))
    }

    @ViewBuilder private func flipTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> some View {
        let vertical = family == .verticalCompact || family == .tall
        let cellHeight = max(30, min(vertical ? width * 0.34 : height * 0.56, vertical ? height * 0.22 : width * 0.11))
        let seconds = shouldShowSeconds(in: family)
        if vertical {
            VStack(spacing: 7) {
                flipPair(parts.hour, height: cellHeight)
                flipPair(parts.minute, height: cellHeight)
                if seconds { flipPair(parts.second, height: cellHeight * 0.72) }
            }
        } else {
            HStack(spacing: max(5, cellHeight * 0.10)) {
                flipPair(parts.hour, height: cellHeight)
                Text(clock.resolvedSeparator.glyph).font(.system(size: cellHeight * 0.48, weight: .medium, design: .rounded)).foregroundStyle(separatorColor)
                flipPair(parts.minute, height: cellHeight)
                if seconds {
                    Text(clock.resolvedSeparator.glyph).font(.system(size: cellHeight * 0.34, weight: .regular)).foregroundStyle(separatorColor.opacity(0.75))
                    flipPair(parts.second, height: cellHeight * 0.72)
                }
            }
        }
    }

    private func flipPair(_ text: String, height: CGFloat) -> some View {
        HStack(spacing: max(2, height * 0.035)) {
            ForEach(Array(text).indices, id: \.self) { index in
                ClockFlipDigit(digit: Array(text)[index], height: height, color: primaryColor, accent: accentColor)
            }
        }
    }

    @ViewBuilder private func editorialTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family)
        VStack(alignment: family == .wide ? .leading : .center, spacing: max(4, size * 0.08)) {
            Text(adaptiveDate(date, detail: family == .hero || family == .large ? .full : .short))
                .font(clockFont(size: max(9, dateFontSize(for: family) * 0.86), weight: .semibold, forceDesign: .serif))
                .tracking(max(1.5, clock.resolvedTracking + 1.5))
                .foregroundStyle(secondaryColor)
                .textCase(.uppercase)
                .lineLimit(1)
            Rectangle().fill(primaryColor.opacity(0.18)).frame(maxWidth: min(width * 0.72, 420), maxHeight: 1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                digit(parts.hour, size: size * 1.02, emphasis: clock.resolvedHourEmphasis, forceDesign: .serif)
                Text(clock.resolvedSeparator.glyph).font(clockFont(size: size * 0.72, weight: .light, forceDesign: .serif)).foregroundStyle(separatorColor)
                digit(parts.minute, size: size * 1.02, emphasis: clock.resolvedMinuteEmphasis, forceDesign: .serif)
            }
        }
    }

    @ViewBuilder private func terminalTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.86
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("›").font(.system(size: size * 0.68, weight: .bold, design: .monospaced)).foregroundStyle(accentColor)
            Text(rawTime(parts: parts, family: family))
                .font(.system(size: size, weight: .medium, design: .monospaced))
                .foregroundStyle(primaryColor)
                .tracking(max(0, clock.resolvedTracking))
                .monospacedDigit()
                .contentTransition(.numericText())
            if family == .wide || family == .large || family == .hero {
                Text(timeZone.abbreviation() ?? "LOCAL").font(.system(size: max(8, size * 0.23), weight: .medium, design: .monospaced)).foregroundStyle(secondaryColor)
            }
        }
    }

    @ViewBuilder private func lcdTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.88
        Text(rawTime(parts: parts, family: family))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(accentColor.opacity(0.95))
            .monospacedDigit()
            .tracking(max(1, clock.resolvedTracking))
            .padding(.horizontal, max(10, size * 0.18)).padding(.vertical, max(7, size * 0.10))
            .background(accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: max(8, size * 0.11), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: max(8, size * 0.11)).stroke(accentColor.opacity(0.16), lineWidth: 1))
            .shadow(color: accentColor.opacity(0.10), radius: 10)
            .contentTransition(.numericText())
    }

    @ViewBuilder private func dotMatrixTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.82
        Text(rawTime(parts: parts, family: family))
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .foregroundStyle(primaryColor)
            .monospacedDigit()
            .tracking(max(2, clock.resolvedTracking + 2))
            .padding(.horizontal, max(10, size * 0.16)).padding(.vertical, max(7, size * 0.10))
            .background { ClockDotMatrixBackdrop().clipShape(RoundedRectangle(cornerRadius: 10)) }
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(primaryColor.opacity(0.10), lineWidth: 1))
            .contentTransition(.numericText())
    }

    @ViewBuilder private func outlineTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = timeFontSize(for: family) * 0.90
        Text(rawTime(parts: parts, family: family))
            .font(clockFont(size: size, weight: .medium))
            .foregroundStyle(primaryColor.opacity(0.90))
            .monospacedDigit()
            .tracking(clock.resolvedTracking)
            .padding(.horizontal, max(12, size * 0.22)).padding(.vertical, max(7, size * 0.10))
            .overlay(RoundedRectangle(cornerRadius: max(10, size * 0.15), style: .continuous).stroke(primaryColor.opacity(0.28), lineWidth: 1.2))
            .contentTransition(.numericText())
    }

    @ViewBuilder private func oversizedTime(parts: ClockTimeParts, date: Date, family: ClockLayoutFamily) -> some View {
        let size = min(height * 0.58, width * (family == .hero ? 0.13 : family == .wide ? 0.16 : 0.23)) * CGFloat(clock.resolvedTimeScale)
        Text(rawTime(parts: parts, family: family))
            .font(clockFont(size: max(24, size), weight: .bold))
            .foregroundStyle(primaryColor)
            .tracking(min(-1, clock.resolvedTracking - 1))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .contentTransition(.numericText())
    }

    private func rawTime(parts: ClockTimeParts, family: ClockLayoutFamily) -> String {
        var result = parts.hour + clock.resolvedSeparator.glyph + parts.minute
        if shouldShowSeconds(in: family) { result += clock.resolvedSeparator.glyph + parts.second }
        if !clock.twentyFourHour && clock.resolvedShowAMPM && family != .micro { result += " " + parts.ampm }
        return result
    }

    private func analogDiameter(for family: ClockLayoutFamily) -> CGFloat {
        let multiplier: CGFloat
        switch family { case .micro: multiplier = 0.82; case .horizontalCompact: multiplier = 0.82; case .verticalCompact: multiplier = 0.86; case .standard: multiplier = 0.74; case .wide: multiplier = 0.80; case .tall: multiplier = 0.76; case .large: multiplier = 0.66; case .hero: multiplier = 0.62 }
        return max(44, min(width, height) * multiplier)
    }

    private enum DateDetail { case micro, short, medium, full }

    private func adaptiveDate(_ date: Date, detail: DateDetail) -> String {
        guard clock.showDate else { return "" }
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = timeZone
        let advanced = clock.showWeekday != nil || clock.showDay != nil || clock.showMonth != nil || clock.showYear != nil || clock.dateOrder != nil || clock.monthStyle != nil || clock.weekdayStyle != nil
        if !advanced {
            let formatter = DateFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.timeZone = timeZone
            switch detail {
            case .micro: formatter.dateFormat = "EEE d"
            case .short: formatter.dateFormat = "EEE, MMM d"
            case .medium:
                switch style.resolvedContent.clockDateStyle {
                case .weekdayMonthDay: formatter.dateFormat = "EEE, MMM d"
                case .monthDay: formatter.dateFormat = "MMM d"
                case .full: formatter.dateFormat = "EEEE, MMMM d"
                case .numeric: formatter.dateStyle = .short; formatter.timeStyle = .none
                }
            case .full:
                formatter.dateFormat = style.resolvedContent.clockDateStyle == .numeric ? "yyyy-MM-dd" : "EEEE, MMMM d"
            }
            return applyDateCase(formatter.string(from: date))
        }

        let weekdayFormatter = DateFormatter(); weekdayFormatter.locale = .autoupdatingCurrent; weekdayFormatter.timeZone = timeZone
        let monthFormatter = DateFormatter(); monthFormatter.locale = .autoupdatingCurrent; monthFormatter.timeZone = timeZone
        let forceShort = detail == .micro || detail == .short
        weekdayFormatter.dateFormat = forceShort || clock.resolvedWeekdayStyle == .short ? "EEE" : "EEEE"
        switch clock.resolvedMonthStyle {
        case .short: monthFormatter.dateFormat = "MMM"
        case .full: monthFormatter.dateFormat = forceShort ? "MMM" : "MMMM"
        case .numeric: monthFormatter.dateFormat = "MM"
        }
        let weekday = weekdayFormatter.string(from: date)
        let month = monthFormatter.string(from: date)
        let day = String(calendar.component(.day, from: date))
        let year = String(calendar.component(.year, from: date))
        var pieces: [String] = []
        let addWeekday = clock.resolvedShowWeekday
        let addDay = clock.resolvedShowDay
        let addMonth = clock.resolvedShowMonth
        let addYear = clock.resolvedShowYear && detail != .micro && detail != .short
        switch clock.resolvedDateOrder {
        case .weekdayMonthDay:
            if addWeekday { pieces.append(weekday) }; if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addYear { pieces.append(year) }
        case .monthDayYear:
            if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addYear { pieces.append(year) }; if addWeekday && detail == .full { pieces.append(weekday) }
        case .dayMonthYear:
            if addDay { pieces.append(day) }; if addMonth { pieces.append(month) }; if addYear { pieces.append(year) }; if addWeekday && detail == .full { pieces.append(weekday) }
        case .yearMonthDay:
            if addYear { pieces.append(year) }; if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addWeekday && detail == .full { pieces.append(weekday) }
        case .monthDayWeekday:
            if addMonth { pieces.append(month) }; if addDay { pieces.append(day) }; if addWeekday { pieces.append(weekday) }; if addYear { pieces.append(year) }
        }
        if detail == .micro { pieces = Array(pieces.prefix(2)) }
        return applyDateCase(pieces.joined(separator: detail == .full ? " · " : " "))
    }

    private func applyDateCase(_ value: String) -> String {
        switch clock.resolvedDateTextCase { case .natural: return value; case .uppercase: return value.uppercased(); case .lowercase: return value.lowercased() }
    }

    private func enabledComplications() -> [ClockComplication] {
        if let override = sizeOverride?.complications { return override }
        let enabled = Set(clock.resolvedEnabledComplications)
        return clock.resolvedComplicationPriority.filter { enabled.contains($0) }
    }

    private func visibleComplications(date: Date) -> [ClockComplication] {
        let source = enabledComplications().filter { complicationAvailable($0, date: date) }
        return Array(source.prefix(family.complicationCapacity))
    }

    private func complicationAvailable(_ complication: ClockComplication, date: Date) -> Bool {
        switch complication {
        case .date, .day: return clock.showDate
        case .seconds: return clock.showSeconds
        case .timezone, .location, .utcOffset, .weekNumber: return true
        case .nextEvent: return nextEvent(at: date) != nil
        case .timer: return store?.deadline != nil || (store?.pausedSeconds ?? 0) > 0
        case .weather: return weatherSummary?.isEmpty == false
        case .temperature: return temperatureText?.isEmpty == false
        case .battery: return workspace?.system.battery != nil
        case .sunrise: return sunrise != nil
        case .sunset: return sunset != nil
        case .worldClocks: return !clock.resolvedWorldTimeZones.isEmpty
        }
    }

    private func nextEvent(at date: Date) -> EKEvent? {
        workspace?.calendar.upcomingEvents.first { $0.endDate > date }
    }

    private func complicationValue(_ complication: ClockComplication, date: Date) -> String {
        switch complication {
        case .date: return adaptiveDate(date, detail: family == .hero || family == .large ? .full : .short)
        case .day:
            let formatter = DateFormatter(); formatter.locale = .autoupdatingCurrent; formatter.timeZone = timeZone; formatter.dateFormat = family == .micro ? "EEE" : "EEEE"; return applyDateCase(formatter.string(from: date))
        case .seconds:
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone; return String(format: "%02d", calendar.component(.second, from: date))
        case .timezone: return timeZone.abbreviation(for: date) ?? timeZone.identifier
        case .location:
            if let label = clock.locationLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty { return label }
            return timeZone.identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? timeZone.identifier
        case .utcOffset:
            let seconds = timeZone.secondsFromGMT(for: date); let sign = seconds < 0 ? "−" : "+"; let value = abs(seconds); return String(format: "UTC%@%02d:%02d", sign, value / 3600, value / 60 % 60)
        case .weekNumber:
            var calendar = Calendar.autoupdatingCurrent; calendar.timeZone = timeZone; return "Week \(calendar.component(.weekOfYear, from: date))"
        case .nextEvent:
            guard let event = nextEvent(at: date) else { return "" }
            let formatter = DateFormatter(); formatter.locale = .autoupdatingCurrent; formatter.timeZone = timeZone; formatter.timeStyle = .short
            return "\(event.title ?? "Event") · \(formatter.string(from: event.startDate))"
        case .timer:
            if let deadline = store?.deadline { return formatDuration(max(0, deadline.timeIntervalSince(date))) }
            if let paused = store?.pausedSeconds, paused > 0 { return "Paused · \(formatDuration(paused))" }
            return ""
        case .weather: return weatherSummary ?? ""
        case .temperature: return temperatureText ?? ""
        case .battery:
            guard let battery = workspace?.system.battery else { return "" }
            return workspace?.system.charging == true ? "\(battery)% · Charging" : "\(battery)%"
        case .sunrise: return solarTime(sunrise)
        case .sunset: return solarTime(sunset)
        case .worldClocks:
            return clock.resolvedWorldTimeZones.prefix(3).compactMap { identifier in
                guard let zone = TimeZone(identifier: identifier) else { return nil }
                let formatter = DateFormatter(); formatter.timeZone = zone; formatter.dateFormat = clock.twentyFourHour ? "HH:mm" : "h:mm a"
                let label = identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? identifier
                return "\(label) \(formatter.string(from: date))"
            }.joined(separator: "  ·  ")
        }
    }

    private func solarTime(_ value: Date?) -> String {
        guard let value else { return "" }
        let formatter = DateFormatter(); formatter.locale = .autoupdatingCurrent; formatter.timeZone = timeZone; formatter.timeStyle = .short
        return formatter.string(from: value)
    }

    private func complicationLabel(_ complication: ClockComplication) -> String {
        switch complication {
        case .nextEvent: return "NEXT"
        case .worldClocks: return "WORLD CLOCKS"
        case .utcOffset: return "OFFSET"
        case .weekNumber: return "WEEK"
        default: return complication.title.uppercased()
        }
    }

    @ViewBuilder private func compactComplication(_ complication: ClockComplication, date: Date, horizontal: Bool) -> some View {
        let value = complicationValue(complication, date: date)
        if !value.isEmpty {
            VStack(alignment: horizontal ? .trailing : .center, spacing: 2) {
                if family != .horizontalCompact && family != .verticalCompact {
                    Text(complicationLabel(complication))
                        .font(clockFont(size: max(7, secondaryFontSize(for: family) * 0.70), weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(secondaryColor.opacity(0.72))
                }
                Text(value)
                    .font(clockFont(size: secondaryFontSize(for: family), weight: complication == .date ? .medium : .regular))
                    .foregroundStyle(complication == .date ? secondaryColor.opacity(0.92) : secondaryColor)
                    .lineLimit(complication == .nextEvent ? 2 : 1)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(horizontal ? .trailing : .center)
            }
        }
    }

    @ViewBuilder private func complicationRow(_ complications: [ClockComplication], date: Date, limit: Int) -> some View {
        if !complications.isEmpty {
            HStack(alignment: .top, spacing: max(12, width * 0.035)) {
                ForEach(Array(complications.prefix(limit)), id: \.self) { complication in
                    let value = complicationValue(complication, date: date)
                    if !value.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(complicationLabel(complication), systemImage: complication.symbol)
                                .font(clockFont(size: max(7, secondaryFontSize(for: family) * 0.66), weight: .semibold))
                                .foregroundStyle(secondaryColor.opacity(0.68))
                                .labelStyle(.titleAndIcon)
                            Text(value)
                                .font(clockFont(size: secondaryFontSize(for: family), weight: .medium))
                                .foregroundStyle(secondaryColor)
                                .lineLimit(complication == .nextEvent ? 2 : 1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder private func largeHeader(date: Date, complications: [ClockComplication]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if clock.showDate {
                Text(adaptiveDate(date, detail: .full))
                    .font(clockFont(size: dateFontSize(for: family), weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            Spacer(minLength: 12)
            if complications.contains(.location) || complications.contains(.timezone) {
                Text(complicationValue(complications.contains(.location) ? .location : .timezone, date: date))
                    .font(clockFont(size: secondaryFontSize(for: family), weight: .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder private func heroClock(date: Date, complications: [ClockComplication]) -> some View {
        if visualStyle == .analog {
            HStack(spacing: max(28, width * 0.055)) {
                AdaptiveAnalogClockFace(date: date, style: style, clock: clock, diameter: min(height * 0.78, width * 0.42), showSeconds: shouldShowSeconds(in: .hero))
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                VStack(alignment: .leading, spacing: 14) {
                    largeHeader(date: date, complications: complications)
                    Spacer(minLength: 0)
                    complicationRow(complications, date: date, limit: 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(adaptiveDate(date, detail: .full))
                        .font(clockFont(size: max(11, dateFontSize(for: .hero) * 0.92), weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                    Spacer()
                    Text(complicationValue(.location, date: date))
                        .font(clockFont(size: max(10, secondaryFontSize(for: .hero)), weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(secondaryColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 14)
                primaryClock(date: date, family: .hero)
                    .matchedGeometryEffect(id: "clock-primary", in: clockNamespace)
                Spacer(minLength: 18)
                complicationRow(complications.filter { $0 != .date && $0 != .location }, date: date, limit: 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds.rounded()))
        if value >= 3600 { return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) }
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
