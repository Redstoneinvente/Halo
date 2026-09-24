import Foundation
import Combine

enum HaloAccessLevel: String, Equatable, Sendable {
    case lite
    case full
}

/// Product-level features that distinguish Halo Full from Halo Lite.
///
/// Feature code should ask HaloFeatureAccess for capabilities instead of
/// checking StoreKit, LicenseSeat, account state, or ad-hoc purchase flags.
enum HaloCapability: String, CaseIterable, Sendable {
    case visualWorkspace
    case profiles
    case profileAutomation
    case schedules

    case contextInterfaces
    case integrations
    case customCI
    case plugins

    case pixelPal

    case advancedBubbles
    case multipleBubbles
    case advancedBubbleGestures

    case notchSkins
    case notchAmbient

    case advancedAppearance
    case customBackgrounds
    case advancedClosedNotch
    case advancedTransitions

    case advancedHUD
    case advancedWidgetCustomization

    case multiDisplayCustomization
    case themeImportExport
    case activationSequenceCustomization

    case clipboardWidget
    case launcherWidget
    case liveActivitiesWidget
    case notesWidget
    case captureWidget
}

/// Authoritative runtime source of truth for Halo Lite vs Halo Full.
///
/// Entitlement providers decide whether Full is available. Feature code should
/// consult this object instead of querying StoreKit, LicenseSeat, or account state.
@MainActor
final class HaloFeatureAccess: ObservableObject {
    static let shared = HaloFeatureAccess()

    @Published private(set) var accessLevel: HaloAccessLevel = .lite
    @Published private(set) var liteBackgroundOverride: BackgroundKind?

    private enum Keys {
        static let choseLite = "HaloHasChosenLite"
        static let hadFullAccess = "HaloHasHadFullAccess"
        static let liteBackground = "HaloLiteBackground"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.liteBackground),
           let background = BackgroundKind(rawValue: raw),
           [.solid, .gradient, .glass].contains(background) {
            liteBackgroundOverride = background
        }
    }

    func setLiteBackground(_ background: BackgroundKind) {
        guard [.solid, .gradient, .glass].contains(background) else { return }
        defaults.set(background.rawValue, forKey: Keys.liteBackground)
        if liteBackgroundOverride != background {
            liteBackgroundOverride = background
        }
    }

    var isFull: Bool { accessLevel == .full }

    /// Full enables every product capability. Lite deliberately exposes only
    /// the core experience; the enum above therefore represents Full features.
    func allows(_ capability: HaloCapability) -> Bool {
        isFull
    }

    /// Runtime widget boundary. This is intentionally independent from the
    /// Settings UI so an old/imported Full layout cannot render paid widgets.
    func allows(module: ModuleID) -> Bool {
        if isFull { return module != .developer }
        switch module {
        case .clock, .media, .timer, .stopwatch, .shelf, .calendar, .system, .audio:
            return true
        case .clipboard, .launcher, .activities, .pet, .notes, .capture, .developer:
            return false
        }
    }

    /// Runtime Bubble provider boundary.
    func allows(bubble: NotchBubbleKind) -> Bool {
        if isFull { return true }
        switch bubble {
        case .music, .timer, .audio:
            return true
        case .pixelPal, .clock, .stopwatch, .system, .clipboard, .calendar, .vinyl, .files:
            return false
        }
    }

    func allows(hudEvent: HaloHUDEventKind) -> Bool {
        if isFull { return true }
        switch hudEvent {
        case .volume, .mute, .displayBrightness, .keyboardBrightness:
            return true
        default:
            return false
        }
    }

    func effectiveHUDSettings(_ saved: HaloHUDSettings) -> HaloHUDSettings {
        guard !isFull else { return saved }

        var value = HaloHUDSettings()
        value.enabled = saved.enabled
        for kind in HaloHUDEventKind.allCases {
            var item = HaloHUDEventOverride()
            item.enabled = allows(hudEvent: kind) && saved.override(for: kind).enabled
            value.setOverride(item, for: kind)
        }
        return value
    }

    /// Resolve a runtime-safe theme without changing the user's saved Full
    /// theme. Lite keeps its useful basic appearance controls while advanced
    /// surface styles remain dormant until Full returns.
    func effectiveTheme(_ saved: Theme) -> Theme {
        guard !isFull else { return saved }
        var value = Theme()
        value.width = saved.width
        value.cornerRadius = saved.cornerRadius
        value.tint = saved.tint
        value.opacity = saved.opacity
        value.animations = saved.animations
        value.style = .notch
        return value
    }

    /// Produce the layout Halo is allowed to render right now. This is a copy;
    /// premium values in WorkspaceSettings remain untouched on disk.
    func effectiveLayout(_ saved: WorkspaceLayout) -> WorkspaceLayout {
        guard !isFull else { return saved }

        var value = saved

        // Visual Workspace is preserved in the saved layout, but Lite always
        // renders the classic/default workspace.
        value.useCustomOpenNotchWorkspace = false
        value.openNotch = nil

        // Filter runtime modules without rewriting the saved enabled/order sets.
        value.enabled = Set(saved.enabled.filter { allows(module: $0) })
        value.order = saved.normalizedOrder().filter { allows(module: $0) }

        // Context Interfaces and advanced HUD customization are Full features.
        value.contextMusic = nil
        value.hud = effectiveHUDSettings(saved.hud ?? HaloHUDSettings())

        // Closed-notch deep customization is Full. Lite keeps Halo's polished
        // default closed surface while the saved Full configuration is dormant.
        value.closedNotch = ClosedNotchOptions()

        // Retain only intentionally basic widget styling. Deeper per-widget
        // chrome, adaptive footprints and element overrides stay saved but do
        // not affect Lite rendering.
        if let savedWidgets = saved.widgets {
            var basicWidgets: [String: WidgetStyle] = [:]
            for (rawID, style) in savedWidgets {
                guard let module = ModuleID(rawValue: rawID), allows(module: module) else { continue }
                var basic = WidgetStyle()

                // Clock intentionally keeps a small typography/date surface in
                // Lite. Every other supported widget resolves to Halo's useful
                // default presentation; advanced saved styling remains dormant.
                if module == .clock {
                    basic.fontFamily = style.fontFamily == .custom ? .rounded : style.fontFamily
                    basic.weight = style.weight
                    basic.clock.twentyFourHour = style.clock.twentyFourHour
                    basic.clock.showSeconds = style.clock.showSeconds
                    basic.clock.showDate = style.clock.showDate
                }
                basicWidgets[rawID] = basic
            }
            value.widgets = basicWidgets.isEmpty ? nil : basicWidgets
        }

        var appearance = saved.appearance
        if let liteBackgroundOverride {
            appearance.background = liteBackgroundOverride
        } else if appearance.background == .image || appearance.background == .video {
            appearance.background = .gradient
        }
        // Lite exposes Halo Black, the default Gradient and default Glass. Custom
        // color recipes remain saved for Full but do not leak into the Lite runtime.
        appearance.solidColor = .black
        appearance.gradientStartColor = nil
        appearance.gradientEndColor = nil
        appearance.assetPath = ""
        appearance.grain = nil
        appearance.backgroundSchedule = nil
        appearance.glass = GlassOptions()
        appearance.blur = 0
        appearance.saturation = 1
        appearance.brightness = 0
        appearance.skin = NotchSkinOptions()
        appearance.animation = .smooth
        appearance.surface = SurfaceOptions()
        value.appearance = appearance

        return value
    }
    var hasChosenLite: Bool { defaults.bool(forKey: Keys.choseLite) }
    var hasHadFullAccess: Bool { defaults.bool(forKey: Keys.hadFullAccess) }

    /// A returning Lite user, or a customer who previously had Full, should not
    /// be forced back through access selection when a Full entitlement is absent.
    var shouldAutomaticallyStartLite: Bool {
        hasChosenLite || hasHadFullAccess
    }

    func chooseLite() {
        defaults.set(true, forKey: Keys.choseLite)
        setFullAccess(false)
    }

    func setFullAccess(_ enabled: Bool) {
        let next: HaloAccessLevel = enabled ? .full : .lite
        if enabled {
            defaults.set(true, forKey: Keys.hadFullAccess)
        }
        guard accessLevel != next else { return }
        accessLevel = next
    }
}

extension Notification.Name {
    static let haloPresentUpgrade = Notification.Name("HaloPresentUpgrade")
}

/// Reusable entry point for premium controls that need to present Halo's upgrade UI.
///
/// Feature-specific buttons can call this later without knowing whether the running
/// binary uses StoreKit or Direct licensing.
@MainActor
final class HaloUpgradeCoordinator {
    static let shared = HaloUpgradeCoordinator()

    private init() {}

    func present() {
        NotificationCenter.default.post(name: .haloPresentUpgrade, object: nil)
    }
}

/// Describes how this Halo binary is distributed.
///
/// Keep compile-condition checks in this file. The rest of Halo should ask for
/// a capability instead of branching on `HALO_DIRECT` or `HALO_APPSTORE`.
enum HaloDistribution: String, CaseIterable, Sendable {
    case direct
    case appStore

    static let current: HaloDistribution = {
#if HALO_DIRECT && HALO_APPSTORE
#error("Halo cannot be built with both HALO_DIRECT and HALO_APPSTORE.")
#elseif HALO_DIRECT
        return .direct
#elseif HALO_APPSTORE
        return .appStore
#else
#error("Halo must be built with either HALO_DIRECT or HALO_APPSTORE.")
#endif
    }()

    var capabilities: HaloDistributionCapabilities {
        switch self {
        case .direct:
            return HaloDistributionCapabilities(
                supportsSparkle: true,
                supportsExternalLicensing: true,
                supportsAppStoreLicensing: false,
                supportsUnrestrictedFileAccess: true,
                supportsPartnerIntegrations: true,
                supportsSystemAudio: true
            )
        case .appStore:
            return HaloDistributionCapabilities(
                supportsSparkle: false,
                supportsExternalLicensing: false,
                supportsAppStoreLicensing: true,
                supportsUnrestrictedFileAccess: false,
                supportsPartnerIntegrations: true,
                supportsSystemAudio: false
            )
        }
    }

    var supportsSparkle: Bool { capabilities.supportsSparkle }
    var supportsExternalLicensing: Bool { capabilities.supportsExternalLicensing }
    var supportsAppStoreLicensing: Bool { capabilities.supportsAppStoreLicensing }
    var supportsUnrestrictedFileAccess: Bool { capabilities.supportsUnrestrictedFileAccess }
    var supportsPartnerIntegrations: Bool { capabilities.supportsPartnerIntegrations }
    var supportsSystemAudio: Bool { capabilities.supportsSystemAudio }
}

/// Distribution-sensitive capabilities exposed to the rest of Halo.
///
/// These are deliberately capability-oriented. If App Store policy or Halo's
/// implementation changes later, update the mapping above without rewriting
/// feature call sites.
struct HaloDistributionCapabilities: Equatable, Sendable {
    let supportsSparkle: Bool
    let supportsExternalLicensing: Bool
    let supportsAppStoreLicensing: Bool
    let supportsUnrestrictedFileAccess: Bool
    let supportsPartnerIntegrations: Bool
    let supportsSystemAudio: Bool
}
