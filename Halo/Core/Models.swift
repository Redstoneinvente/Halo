import Foundation
import SwiftUI
import AppKit

enum SurfaceStyle: String, Codable, CaseIterable, Identifiable {
    case notch = "Notch", pill = "Floating pill", island = "Dynamic island", shelf = "Wide shelf"
    case menuBar = "Menu-bar surface", left = "Left edge", right = "Right edge", bottom = "Bottom island", simulated = "Simulated notch", detached = "Detached panel"
    var id: String { rawValue }
}

struct Theme: Codable, Equatable {
    var version = 1
    var name = "Midnight"
    var width = 420.0
    var cornerRadius = 24.0
    var tint = 0.58
    var opacity = 0.95
    var animations = true
    var style: SurfaceStyle = .notch
    func validated() throws -> Theme {
        guard version == 1, width.isFinite, cornerRadius.isFinite, tint.isFinite, opacity.isFinite else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var result = self
        result.width = min(640, max(340, width))
        result.cornerRadius = min(48, max(0, cornerRadius))
        result.tint = min(1, max(0, tint))
        result.opacity = min(1, max(0.5, opacity))
        return result
    }
}

struct Configuration: Codable {
    var theme = Theme()
    var hoverToExpand = true
    var allDisplays = false
    var simulateNotch = false
    var showClock = true
    var showTimer = true
    var showShelf = true
}

enum Geometry {
    static func width(screenWidth: Double, requested: Double) -> Double {
        min(max(1, screenWidth - 24), max(1, requested))
    }
}

/// Built-in modules use this metadata contract; executable third-party loading is not implemented.
protocol NotchModule {
    var id: String { get }
    var title: String { get }
    var symbol: String { get }
}

struct BuiltinModule: NotchModule, Identifiable {
    let id: String
    let title: String
    let symbol: String
    static let available = [
        BuiltinModule(id: "clock", title: "Clock", symbol: "clock"),
        BuiltinModule(id: "timer", title: "Focus timer", symbol: "timer"),
        BuiltinModule(id: "shelf", title: "File shelf", symbol: "tray")
    ]
}

/// `Binding` already has an `animation(_:)` method, which shadows dynamic-member lookup for a
/// model property also named `animation`. Expose the HUD model's animation binding explicitly so
/// expressions such as `configuration.animation.entrance` resolve to the model instead of the
/// SwiftUI method reference.
extension Binding where Value == HaloHUDConfiguration {
    var animation: Binding<HaloHUDAnimationConfiguration> {
        self[dynamicMember: \.animation]
    }
}

// MARK: - Settings slider behavior

private struct HaloEnhancedSettingsSlidersKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var haloEnhancedSettingsSliders: Bool {
        get { self[HaloEnhancedSettingsSlidersKey.self] }
        set { self[HaloEnhancedSettingsSlidersKey.self] = newValue }
    }
}

extension View {
    func haloEnhancedSettingsSliders(_ enabled: Bool = true) -> some View {
        environment(\.haloEnhancedSettingsSliders, enabled)
    }
}

/// A drop-in replacement for SwiftUI's common Double slider initializers.
/// Settings windows opt into the richer presentation; normal runtime controls remain native sliders.
struct Slider<Label: View>: View {
    @Binding private var value: Double
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: (Bool) -> Void
    private let label: () -> Label
    private let bypassSettingsEnhancement: Bool

    @Environment(\.haloEnhancedSettingsSliders) private var enhancedInSettings
    @State private var text = ""
    @State private var dragging = false
    @State private var lastTick: Int?
    @FocusState private var fieldFocused: Bool

    init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._value = value
        self.bounds = bounds
        self.step = nil
        self.onEditingChanged = onEditingChanged
        self.label = label
        self.bypassSettingsEnhancement = false
    }

    init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._value = value
        self.bounds = bounds
        self.step = step
        self.onEditingChanged = { _ in }
        self.label = label
        self.bypassSettingsEnhancement = false
    }

    /// `PreciseSlider` already owns its text field and haptic behavior. Its internal slider uses this
    /// explicit step + editing callback signature, so keep that nested slider native to avoid doubles.
    init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double,
        onEditingChanged: @escaping (Bool) -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self._value = value
        self.bounds = bounds
        self.step = step
        self.onEditingChanged = onEditingChanged
        self.label = label
        self.bypassSettingsEnhancement = true
    }

    private var shouldEnhance: Bool { enhancedInSettings && !bypassSettingsEnhancement }

    var body: some View {
        Group {
            if shouldEnhance {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        label()
                        Spacer()
                        TextField("", text: $text)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .focused($fieldFocused)
                            .onSubmit { commitText() }
                            .onChange(of: fieldFocused) { focused in
                                if !focused { commitText() }
                            }
                    }
                    enhancedNativeSlider
                }
            } else {
                nativeSlider
            }
        }
        .onAppear { syncText() }
        .onChange(of: value) { newValue in
            if shouldEnhance && !fieldFocused { text = formatted(newValue) }
        }
    }

    @ViewBuilder private var nativeSlider: some View {
        if let step {
            SwiftUI.Slider(value: $value, in: bounds, step: step, onEditingChanged: onEditingChanged) { label() }
        } else {
            SwiftUI.Slider(value: $value, in: bounds, onEditingChanged: onEditingChanged) { label() }
        }
    }

    @ViewBuilder private var enhancedNativeSlider: some View {
        if let step {
            SwiftUI.Slider(value: enhancedBinding, in: bounds, step: step, onEditingChanged: editingChanged) { EmptyView() }
        } else {
            SwiftUI.Slider(value: enhancedBinding, in: bounds, onEditingChanged: editingChanged) { EmptyView() }
        }
    }

    private var enhancedBinding: Binding<Double> {
        Binding(
            get: { value },
            set: { raw in
                let next = clamped(raw)
                value = next
                if !fieldFocused { text = formatted(next) }
                if dragging { tickIfNeeded(next) }
            }
        )
    }

    private func editingChanged(_ editing: Bool) {
        dragging = editing
        lastTick = editing ? tickIndex(value) : nil
        onEditingChanged(editing)
        if !editing { syncText() }
    }

    private func clamped(_ raw: Double) -> Double {
        min(bounds.upperBound, max(bounds.lowerBound, raw))
    }

    private func quantized(_ raw: Double) -> Double {
        let value = clamped(raw)
        guard let step, step > 0 else { return value }
        return clamped(((value - bounds.lowerBound) / step).rounded() * step + bounds.lowerBound)
    }

    private func tickIndex(_ value: Double) -> Int {
        if let step, step > 0 {
            return Int(((value - bounds.lowerBound) / step).rounded())
        }
        let span = max(0.000_001, bounds.upperBound - bounds.lowerBound)
        return Int((((value - bounds.lowerBound) / span) * 40).rounded(.towardZero))
    }

    private func tickIfNeeded(_ value: Double) {
        let tick = tickIndex(value)
        guard tick != lastTick else { return }
        lastTick = tick
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private var decimals: Int {
        if let step, step > 0 {
            if step >= 1 { return 0 }
            if step >= 0.1 { return 1 }
            if step >= 0.01 { return 2 }
            if step >= 0.001 { return 3 }
            return 4
        }
        let span = abs(bounds.upperBound - bounds.lowerBound)
        if span <= 2 { return 2 }
        if span <= 20 { return 1 }
        return 0
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.*f", decimals, value)
    }

    private func syncText() {
        text = formatted(value)
    }

    private func commitText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Double(trimmed) else {
            syncText()
            return
        }
        let next = quantized(parsed)
        if next != value {
            value = next
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        syncText()
    }
}

extension Slider where Label == EmptyView {
    init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.init(value: value, in: bounds, onEditingChanged: onEditingChanged) { EmptyView() }
    }

    init(
        value: Binding<Double>,
        in bounds: ClosedRange<Double> = 0...1,
        step: Double
    ) {
        self.init(value: value, in: bounds, step: step) { EmptyView() }
    }
}
