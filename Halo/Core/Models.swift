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
        result.width = min(1200, max(340, width))
        result.cornerRadius = min(48, max(0, cornerRadius))
        result.tint = min(1, max(0, tint))
        result.opacity = min(1, max(0.5, opacity))
        return result
    }
}

enum HaloHoverHapticPattern: String, Codable, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case single = "Single Tap"
    case doubleTap = "Double Tap"
    case tripleTap = "Triple Tap"
    case heartbeat = "Heartbeat"
    case rapidBurst = "Rapid Burst"
    case echo = "Echo"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .automatic: return "Uses Halo's strength-aware default rhythm."
        case .single: return "One clean tactile tap."
        case .doubleTap: return "Two evenly spaced taps."
        case .tripleTap: return "Three deliberate taps."
        case .heartbeat: return "A quick pair followed by a stronger delayed beat."
        case .rapidBurst: return "Four fast taps for a very obvious response."
        case .echo: return "A primary tap followed by two softer-feeling echoes."
        }
    }
}

struct Configuration: Codable {
    var theme = Theme()
    var hoverToExpand = true
    // Optional delay values keep existing saved Configuration payloads backward-compatible.
    var hoverOpenDelay: Double? = nil
    var hoverCloseDelay: Double? = nil
    // Optional so existing Configuration payloads continue decoding. 1 preserves
    // the original subtle hover tick for users upgrading from earlier builds.
    var hoverHapticStrength: Int? = nil
    var hoverHapticPattern: HaloHoverHapticPattern? = nil
    var allDisplays = false

    var resolvedHoverOpenDelay: Double {
        min(10, max(0, hoverOpenDelay ?? 0))
    }

    var resolvedHoverCloseDelay: Double {
        min(10, max(0, hoverCloseDelay ?? 0))
    }

    var resolvedHoverHapticStrength: Int {
        min(6, max(0, hoverHapticStrength ?? 1))
    }

    var resolvedHoverHapticPattern: HaloHoverHapticPattern {
        hoverHapticPattern ?? .automatic
    }
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

private struct HaloSliderWindowProbe: NSViewRepresentable {
    let resolve: (NSWindow?) -> Void

    final class Coordinator {
        weak var lastWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.lastWindow = view.window
            resolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let window = nsView.window
        guard context.coordinator.lastWindow !== window else { return }
        context.coordinator.lastWindow = window
        DispatchQueue.main.async { resolve(window) }
    }
}

/// A drop-in replacement for SwiftUI's common Double slider initializers.
/// Settings windows get a numeric field and tactile ticks; normal runtime controls stay native.
struct Slider<Label: View>: View {
    @Binding private var value: Double
    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let onEditingChanged: (Bool) -> Void
    private let label: () -> Label
    private let bypassSettingsEnhancement: Bool

    @Environment(\.haloEnhancedSettingsSliders) private var enhancedInSettings
    @State private var hostWindow: NSWindow?
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

    private var livesInSettingsWindow: Bool {
        var window = hostWindow
        while let current = window {
            let title = current.title.lowercased()
            if title.contains("settings") || title.contains("halo · hud") || title.contains("customize profile") {
                return true
            }
            window = current.sheetParent
        }
        return false
    }

    private var shouldEnhance: Bool {
        (enhancedInSettings || livesInSettingsWindow) && !bypassSettingsEnhancement
    }

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
        .background {
            HaloSliderWindowProbe { window in
                if hostWindow !== window { hostWindow = window }
            }
            .frame(width: 0, height: 0)
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

// AppKit's `getHue` writes through its pointer arguments and returns Void on macOS.
// This Bool-returning overload lets call sites use it as a guard condition without changing
// the underlying extraction behavior.
extension NSColor {
    func getHue(
        _ hue: UnsafeMutablePointer<CGFloat>?,
        saturation: UnsafeMutablePointer<CGFloat>?,
        brightness: UnsafeMutablePointer<CGFloat>?,
        alpha: UnsafeMutablePointer<CGFloat>?
    ) -> Bool {
        let _: Void = self.getHue(hue, saturation: saturation, brightness: brightness, alpha: alpha)
        return true
    }
}

// MARK: - Backwards-compatible persistence decoding

extension KeyedDecodingContainer {
    /// Persisted Halo settings live across app upgrades. A newly-added field, removed enum case,
    /// or malformed optional sub-object must not invalidate the entire saved workspace.
    func haloDecode<T: Decodable>(
        _ type: T.Type,
        forKey key: Key,
        default fallback: @autoclosure () -> T
    ) -> T {
        do {
            return try decodeIfPresent(type, forKey: key) ?? fallback()
        } catch {
            return fallback()
        }
    }

    func haloOptional<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            return nil
        }
    }
}

extension Theme {
    private enum HaloCodingKeys: String, CodingKey {
        case version, name, width, cornerRadius, tint, opacity, animations, style
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: HaloCodingKeys.self)
        let fallback = Theme()
        version = c.haloDecode(Int.self, forKey: .version, default: fallback.version)
        name = c.haloDecode(String.self, forKey: .name, default: fallback.name)
        width = c.haloDecode(Double.self, forKey: .width, default: fallback.width)
        cornerRadius = c.haloDecode(Double.self, forKey: .cornerRadius, default: fallback.cornerRadius)
        tint = c.haloDecode(Double.self, forKey: .tint, default: fallback.tint)
        opacity = c.haloDecode(Double.self, forKey: .opacity, default: fallback.opacity)
        animations = c.haloDecode(Bool.self, forKey: .animations, default: fallback.animations)
        style = c.haloDecode(SurfaceStyle.self, forKey: .style, default: fallback.style)
    }
}

extension Configuration {
    private enum HaloCodingKeys: String, CodingKey {
        case theme, hoverToExpand, hoverOpenDelay, hoverCloseDelay, hoverHapticStrength,
             hoverHapticPattern, allDisplays, simulateNotch, showClock, showTimer, showShelf
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: HaloCodingKeys.self)
        let fallback = Configuration()
        theme = c.haloDecode(Theme.self, forKey: .theme, default: fallback.theme)
        hoverToExpand = c.haloDecode(Bool.self, forKey: .hoverToExpand, default: fallback.hoverToExpand)
        hoverOpenDelay = c.haloOptional(Double.self, forKey: .hoverOpenDelay)
        hoverCloseDelay = c.haloOptional(Double.self, forKey: .hoverCloseDelay)
        hoverHapticStrength = c.haloOptional(Int.self, forKey: .hoverHapticStrength)
        hoverHapticPattern = c.haloOptional(HaloHoverHapticPattern.self, forKey: .hoverHapticPattern)
        allDisplays = c.haloDecode(Bool.self, forKey: .allDisplays, default: fallback.allDisplays)
        simulateNotch = c.haloDecode(Bool.self, forKey: .simulateNotch, default: fallback.simulateNotch)
        showClock = c.haloDecode(Bool.self, forKey: .showClock, default: fallback.showClock)
        showTimer = c.haloDecode(Bool.self, forKey: .showTimer, default: fallback.showTimer)
        showShelf = c.haloDecode(Bool.self, forKey: .showShelf, default: fallback.showShelf)
    }
}
