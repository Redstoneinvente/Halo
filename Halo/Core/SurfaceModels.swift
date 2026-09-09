import Foundation

enum SurfaceShapeKind: String, Codable, CaseIterable, Identifiable {
    case rounded = "Rounded rectangle", capsule = "Capsule", squircle = "Squircle"
    case notch = "Soft notch", scoop = "Shouldered notch", chamfer = "Cut corners"
    case tapered = "Tapered", asymmetric = "Asymmetric corners"
    var id: String { rawValue }
}
enum SurfaceTransition: String, Codable, CaseIterable, Identifiable {
    case resize = "Resize", spring = "Spring", fade = "Fade and resize"
    case scale = "Scale", slide = "Slide", instant = "Instant"
    var id: String { rawValue }
}
struct SurfaceOptions: Codable, Equatable {
    // Optional for compatibility with themes/preferences saved before offsets existed.
    var offsets: SurfaceOffsets?
    var shape: SurfaceShapeKind = .rounded
    var compactHeight = 40.0
    var opening: SurfaceTransition = .spring
    var closing: SurfaceTransition = .resize
    var duration = 0.3
    var damping = 0.8
    var topRadius = 6.0
    var bottomRadius = 24.0
    var shoulder = 18.0
    func validated() throws -> SurfaceOptions {
        guard [compactHeight, duration, damping, topRadius, bottomRadius, shoulder].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var result = self
        result.compactHeight = min(100, max(16, compactHeight))
        result.offsets = try offsets?.validated()
        result.duration = min(1.2, max(0.1, duration))
        result.damping = min(1, max(0.4, damping))
        result.topRadius = min(64, max(0, topRadius))
        result.bottomRadius = min(64, max(0, bottomRadius))
        result.shoulder = min(48, max(0, shoulder))
        return result
    }
}
struct SurfaceOffsets: Codable, Equatable {
    var openedX = 0.0
    var openedY = 0.0
    var closedX = 0.0
    var closedY = 0.0
    func validated() throws -> SurfaceOffsets {
        guard [openedX, openedY, closedX, closedY].allSatisfy(\.isFinite) else { throw CocoaError(.fileReadCorruptFile) }
        var result = self
        result.openedX = min(1000, max(-1000, openedX)); result.openedY = min(1000, max(-1000, openedY))
        result.closedX = min(1000, max(-1000, closedX)); result.closedY = min(1000, max(-1000, closedY))
        return result
    }
}

/// Coordinates use AppKit's bottom-left screen origin; no screen APIs needed for tests.
struct SurfaceGeometry {
    var screen: CGRect
    var visible: CGRect
    var safeAreaTop: Double
    var physicalNotchWidth: Double
    var style: SurfaceStyle
    var appearance: Appearance
    var expandedWidth: Double
    var attachedToNotch: Bool { style == .notch && safeAreaTop > 0 }
    var minimumWidth: Double { 16 }
    var compactWidth: Double {
        Geometry.width(screenWidth: visible.width, requested: max(minimumWidth, appearance.compactWidth))
    }
    var compactHeight: Double { max(16, appearance.surface.compactHeight) }
    func offset(expanded: Bool) -> CGSize {
        let offsets = appearance.surface.offsets ?? SurfaceOffsets()
        // UI uses positive Y = down; AppKit screen coordinates use positive Y = up.
        return CGSize(width: expanded ? offsets.openedX : offsets.closedX, height: -(expanded ? offsets.openedY : offsets.closedY))
    }
    func frame(expanded: Bool) -> CGRect {
        var width = compactWidth
        if expanded {
            let requested = style == .menuBar ? visible.width - 24 : style == .shelf ? max(expandedWidth, 720) : expandedWidth
            width = Geometry.width(screenWidth: visible.width, requested: max(compactWidth, requested))
        }
        let height = max(1, min(visible.height - 16, expanded ? appearance.expandedHeight + max(40, compactHeight) : compactHeight))
        var x = visible.midX - width / 2
        var y = (attachedToNotch ? screen.maxY : visible.maxY - 8) - height
        switch style {
        case .left: x = visible.minX + 8; y = visible.midY - height / 2
        case .right: x = visible.maxX - width - 8; y = visible.midY - height / 2
        case .bottom: y = visible.minY + 8
        case .detached: y = visible.midY - height / 2
        default: break
        }
        let delta = offset(expanded: expanded)
        return CGRect(x: x + delta.width, y: y + delta.height, width: width, height: height)
    }
}
enum SurfaceMotion {
    static func progress(_ fraction: Double, transition: SurfaceTransition, preset: AnimationPreset, damping: Double) -> Double {
        let t = min(1, max(0, fraction))
        if t == 0 || t == 1 { return t }
        if transition == .instant || preset == .none { return 1 }
        if transition == .spring {
            let zeta = min(0.99, max(0.4, damping))
            let omega = 12.0
            let frequency = omega * sqrt(1 - zeta * zeta)
            return 1 - exp(-zeta * omega * t) * (cos(frequency * t) + zeta / sqrt(1 - zeta * zeta) * sin(frequency * t))
        }
        switch preset {
        case .snappy: return 1 - pow(1 - t, 4)
        case .minimal: return t
        case .dynamic, .elastic: return 1 - pow(1 - t, 3)
        default: return t * t * (3 - 2 * t)
        }
    }
}
