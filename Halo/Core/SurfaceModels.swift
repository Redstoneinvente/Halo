import Foundation

enum ClosedContentSizing {
    static func width(left: Double, right: Double, camera: Double = 0, cameraOffset: Double = 0) -> Double {
        let half = camera > 0 ? max(left - cameraOffset, right + cameraOffset) : max(left, right)
        return max(16, camera + 2 * max(0, half))
    }
}

/// Each wing has a stable minimum independent of the other wing's measured content.
enum ClosedWingSizing {
    static func extents(base: Double, camera: Double, left: Double, right: Double,
                        expansion: Double, leftLive: Bool, rightLive: Bool) -> (left: Double, right: Double) {
        let baseSide = max(0, (base - camera) / 2)
        let liveCount = (leftLive ? 1 : 0) + (rightLive ? 1 : 0)
        let extra = liveCount > 0 ? max(0, expansion - camera - 2 * baseSide) / Double(liveCount) : 0
        return (max(left, baseSide + (leftLive ? extra : 0)),
                max(right, baseSide + (rightLive ? extra : 0)))
    }
}

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

        // Horizontal/camera defaults compress gracefully at very small heights. The outer-edge
        // margin is intentionally different: it has a hard 17 pt safety floor so content never
        // sits close enough to the surface boundary to be clipped by the contour.
        let adaptiveHorizontal = max(1, min(8, contentHeight * 0.28))
        horizontalPadding = options.horizontalPadding == nil
            ? min(options.contentPaddingX, adaptiveHorizontal)
            : options.contentPaddingX

        let adaptiveMargin = max(0, min(4, contentHeight * 0.25))
        cameraMargin = options.sideMargin == nil
            ? min(options.contentSideMargin, adaptiveMargin)
            : options.contentSideMargin
        outerMargin = options.contentOuterMargin

        elementSpacing = min(6, max(2, contentHeight * 0.16))
    }

    var normalCameraInset: Double { horizontalPadding + cameraMargin }
    var outerInset: Double { horizontalPadding + outerMargin }
    var normalShell: Double { normalCameraInset + outerInset }

    /// Extra window extent reserved for glyph antialiasing, shadows and animated content.
    /// This is not user-visible padding: the renderer keeps the configured margin exactly,
    /// while the surface grows slightly beyond its measured body so zero-margin content is
    /// never cut off by an exact-fit frame.
    var renderingAllowance: Double {
        max(2, min(6, contentHeight * 0.12))
    }

    /// Power-event margin is defined as the total distance from the camera edge. When no
    /// power-specific override exists, inherit the exact same camera inset as every other
    /// closed-notch element instead of silently falling back to a different default.
    func cameraInset(power: PowerReactionOptions?) -> Double {
        guard let configured = power?.notchMargin else { return normalCameraInset }
        return min(48, max(0, configured))
    }

    func shell(power: PowerReactionOptions?) -> Double {
        cameraInset(power: power) + outerInset
    }
}

enum ClosedNotchResolvedSide: Equatable {
    case left, right
}

struct ClosedNotchActivityPreferences: Equatable {
    var autoPresent = true
    var bluetoothEvents = true
    var bluetoothConnected = true
    var bluetoothDisconnected = true
    var bluetoothPoweredOn = true
    var bluetoothPoweredOff = true
    var bluetoothPreferredSide = "automatic"

    func allows(_ activity: LiveActivity) -> Bool {
        guard activity.resolvedKind == .bluetooth else { return true }
        guard bluetoothEvents else { return false }

        switch activity.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "bluetooth connected": return bluetoothConnected
        case "bluetooth disconnected": return bluetoothDisconnected
        case "bluetooth on": return bluetoothPoweredOn
        case "bluetooth off": return bluetoothPoweredOff
        default: return true
        }
    }

    var explicitBluetoothSide: ClosedNotchResolvedSide? {
        let normalized = bluetoothPreferredSide.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("left") { return .left }
        if normalized.contains("right") { return .right }
        return nil
    }
}

struct ClosedNotchResolvedContent {
    var left: ClosedNotchItem
    var right: ClosedNotchItem
    var activity: LiveActivity?
}

enum ClosedNotchContentResolver {
    static func primaryActivity(
        in activities: [LiveActivity],
        preferences: ClosedNotchActivityPreferences,
        now: Date = Date()
    ) -> LiveActivity? {
        LiveActivitySelection.primary(
            in: activities.filter(preferences.allows),
            now: now
        )
    }

    static func resolve(
        options: ClosedNotchOptions,
        activities: [LiveActivity],
        mediaVisible: Bool,
        preferences: ClosedNotchActivityPreferences,
        now: Date = Date()
    ) -> ClosedNotchResolvedContent {
        let activity = primaryActivity(in: activities, preferences: preferences, now: now)
        var left = options.left
        var right = options.right

        guard preferences.autoPresent,
              let activity,
              left != .activity,
              right != .activity else {
            return ClosedNotchResolvedContent(left: left, right: right, activity: activity)
        }

        if activity.resolvedKind == .bluetooth, let preferred = preferences.explicitBluetoothSide {
            if preferred == .left { left = .activity }
            else { right = .activity }
            return ClosedNotchResolvedContent(left: left, right: right, activity: activity)
        }

        let rightAvailable = right == .none || ((right == .media || right == .visualizer) && !mediaVisible)
        let leftAvailable = left == .none || ((left == .media || left == .visualizer) && !mediaVisible)
        if rightAvailable { right = .activity }
        else if leftAvailable { left = .activity }
        else { right = .activity }

        return ClosedNotchResolvedContent(left: left, right: right, activity: activity)
    }

    static func nextExpiry(
        in activities: [LiveActivity],
        preferences: ClosedNotchActivityPreferences,
        now: Date = Date()
    ) -> Date? {
        activities
            .filter(preferences.allows)
            .compactMap { activity -> Date? in
                if activity.isPersistent {
                    guard activity.resolvedState == .ended else { return nil }
                    return activity.expiresAt
                }
                return activity.expiresAt ?? activity.created.addingTimeInterval(12)
            }
            .filter { $0 > now }
            .min()
    }
}

enum FrameRatePolicy {
    static func target(maximum: Int, lowPower: Bool) -> Int {
        min(lowPower ? 60 : 120, maximum > 0 ? maximum : 60)
    }
}

/// Compare only render-affecting preferences; no JSON work on the slider hot path.
struct SurfaceRenderConfiguration: Equatable {
    var appearance: Appearance
    var displays: [DisplayOverride]
    var closedNotch: ClosedNotchOptions? = nil
    var clock: WidgetStyle? = nil
    var horizontalWidgets: Bool? = nil
    var horizontalPages: Bool? = nil
    var horizontalHeight: Double? = nil
    var openNotchContentMode: OpenNotchContentMode? = nil
    var openHorizontalPadding: Double? = nil
    var openVerticalPadding: Double? = nil
    var openFixedColumns: Int? = nil
}
enum GlassRendering {
    /// Kept for profiles/themes created before GlassOptions existed.
    static func tintOpacity(themeOpacity: Double) -> Double {
        guard themeOpacity.isFinite else { return 0.1 }
        return min(0.18, max(0, (themeOpacity - 0.5) * 0.36))
    }

    /// Higher clarity means less of the native blur/treatment is composited over the desktop.
    static func materialOpacity(clarity: Double) -> Double {
        guard clarity.isFinite else { return 0.55 }
        let value = min(1, max(0, clarity))
        return 0.18 + (1 - value) * 0.82
    }

    static func absorptionOpacity(_ amount: Double) -> Double {
        guard amount.isFinite else { return 0.12 }
        return min(0.78, max(0, amount) * 0.78)
    }

    static func chromaticOpacity(_ amount: Double) -> Double {
        guard amount.isFinite else { return 0 }
        return min(0.16, max(0, amount) * 0.16)
    }

    static func highlightOpacity(_ amount: Double) -> Double {
        guard amount.isFinite else { return 0 }
        return min(0.30, max(0, amount) * 0.30)
    }

    static func edgeDepthOpacity(_ amount: Double) -> Double {
        guard amount.isFinite else { return 0 }
        return min(0.40, max(0, amount) * 0.40)
    }
}

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
    // Optional fields preserve compatibility with themes/preferences saved before
    // these surface controls existed.
    var useStyleContour: Bool?
    var outlineEnabled: Bool?
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
    var activeCompactWidth: Double? = nil
    var activeCompactHeight: Double? = nil
    /// Dynamic horizontal bias for closed mode. Negative grows toward the left, positive toward the right.
    var activeCompactCenterOffset: Double? = nil
    var attachedToNotch: Bool { (style == .notch && safeAreaTop > 0) || style == .simulated }
    var minimumWidth: Double { 16 }
    var compactWidth: Double {
        let base = style == .shelf ? max(320, appearance.compactWidth) : style == .menuBar ? visible.width - 24 : appearance.compactWidth
        let requested = max(base, activeCompactWidth ?? 0)
        return Geometry.width(screenWidth: visible.width, requested: max(minimumWidth, requested))
    }
    var compactHeight: Double {
        max(16, max(appearance.surface.compactHeight, activeCompactHeight ?? 0))
    }
    var closedCameraOcclusion: CGRect? {
        guard safeAreaTop > 0, physicalNotchWidth > 0 else { return nil }
        let camera = CGRect(x: screen.midX - physicalNotchWidth / 2, y: screen.maxY - safeAreaTop,
                            width: physicalNotchWidth, height: safeAreaTop)
        let surface = frame(expanded: false)
        let overlap = camera.intersection(surface)
        guard !overlap.isNull, !overlap.isEmpty else { return nil }
        return CGRect(x: overlap.minX - surface.minX, y: 0, width: overlap.width, height: overlap.height)
    }
    func offset(expanded: Bool) -> CGSize {
        let offsets = appearance.surface.offsets ?? SurfaceOffsets()
        // UI uses positive Y = down; AppKit screen coordinates use positive Y = up.
        return CGSize(width: expanded ? offsets.openedX : offsets.closedX, height: -(expanded ? offsets.openedY : offsets.closedY))
    }
    func frame(expanded: Bool) -> CGRect {
        var width = compactWidth
        if expanded {
            let requested = style == .menuBar ? visible.width - 24 : style == .shelf ? max(expandedWidth, 720) : expandedWidth
            width = Geometry.width(screenWidth: visible.width, requested: max(appearance.compactWidth, requested))
        }
        let height = max(1, min(visible.height - 16, expanded ? appearance.expandedHeight + max(40, compactHeight) : compactHeight))
        // A real notch belongs to the physical display, not to visibleFrame. Using screen.midX
        // keeps the camera cutout fixed even when the Dock changes visibleFrame asymmetrically.
        let horizontalCenter = attachedToNotch && physicalNotchWidth > 0 ? screen.midX : visible.midX
        var x = horizontalCenter - width / 2
        var y = (attachedToNotch ? screen.maxY : visible.maxY - 8) - height
        if !expanded { x += activeCompactCenterOffset ?? 0 }
        switch style {
        case .left: x = visible.minX + 8; y = visible.midY - height / 2
        case .right: x = visible.maxX - width - 8; y = visible.midY - height / 2
        case .bottom: y = visible.minY + 8
        case .detached: y = visible.midY - height / 2
        case .pill: y = visible.maxY - 24 - height
        case .island: y = visible.maxY - 12 - height
        case .menuBar: y = visible.maxY - height
        case .shelf: y = visible.maxY - 4 - height
        default: break
        }
        let delta = offset(expanded: expanded)
        return CGRect(x: x + delta.width, y: y + delta.height, width: width, height: height)
    }
}
enum SurfaceMotion {
    /// A C2-continuous easing curve. Compared with classic smoothstep it has softer
    /// acceleration and braking, which matters when the window is changing both width
    /// and height at the same time.
    private static func smootherstep(_ t: Double) -> Double {
        t * t * t * (t * (t * 6 - 15) + 10)
    }

    static func progress(_ fraction: Double, transition: SurfaceTransition, preset: AnimationPreset, damping: Double) -> Double {
        let t = min(1, max(0, fraction))
        if t == 0 || t == 1 { return t }
        if transition == .instant || preset == .none { return 1 }

        if transition == .spring {
            // The old under-damped curve could overshoot the final window size and then
            // visibly snap back on the last frame. For a notch, that reads as jitter rather
            // than a pleasant spring. Use a normalized critically-damped response instead:
            // it keeps the soft spring character but is monotonic and lands exactly at 1.
            let settledDamping = min(1, max(0.4, damping))
            let response = 7.0 + (1.0 - settledDamping) * 4.0
            let value = 1 - exp(-response * t) * (1 + response * t)
            let end = 1 - exp(-response) * (1 + response)
            return min(1, max(0, value / max(0.0001, end)))
        }

        // Closed-notch live resizing uses resize + snappy. Keep it responsive, but use
        // the same C2-continuous curve so power events, Live Activities and media width
        // changes settle without a visible step at either end.
        if transition == .resize && preset == .snappy {
            return smootherstep(t)
        }

        switch preset {
        case .snappy:
            // Preserve the fast feel without the abrupt quartic launch used previously.
            let eased = 1 - pow(1 - t, 3)
            return 0.30 * eased + 0.70 * smootherstep(t)
        case .minimal:
            return t
        case .dynamic, .elastic:
            // Keep these lively, while still smoothing the first and last frame.
            let eased = 1 - pow(1 - t, 3)
            return 0.45 * eased + 0.55 * smootherstep(t)
        default:
            return smootherstep(t)
        }
    }
}