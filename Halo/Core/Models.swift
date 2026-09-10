import Foundation
import SwiftUI

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
