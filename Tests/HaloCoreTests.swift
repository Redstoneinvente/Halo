import XCTest
#if SWIFT_PACKAGE
@testable import HaloCore
#endif

final class HaloCoreTests: XCTestCase {
    private func geometry(style: SurfaceStyle = .notch, safeArea: Double = 32, requested: Double = 400) -> SurfaceGeometry {
        var appearance = Appearance(); appearance.compactWidth = requested
        return SurfaceGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), visible: CGRect(x: 0, y: 40, width: 1512, height: 910),
                               safeAreaTop: safeArea, physicalNotchWidth: 180, style: style, appearance: appearance, expandedWidth: 420)
    }
    func testPhysicalNotchHonorsRequestedClosedWidth() {
        XCTAssertEqual(geometry(requested: 400).frame(expanded: false).width, 400)
        XCTAssertEqual(geometry(requested: 500).frame(expanded: false).width, 500)
    }
    func testPhysicalNotchOnlyEnforcesHardwareMinimum() {
        XCTAssertEqual(geometry(requested: 120).frame(expanded: false).width, 212)
        XCTAssertEqual(geometry(style: .pill, requested: 120).frame(expanded: false).width, 120)
    }
    func testSimulatedNotchHasNoHardcodedWidth() {
        XCTAssertEqual(geometry(style: .simulated, requested: 370).frame(expanded: false).width, 370)
    }
    func testMenuBarOnlyUsesFullWidthWhenOpen() {
        let model = geometry(style: .menuBar, requested: 280)
        XCTAssertEqual(model.frame(expanded: false).width, 280)
        XCTAssertEqual(model.frame(expanded: true).width, 1488)
    }
    func testClosedHeightAndOpenWidthNeverShrinkUnexpectedly() {
        var model = geometry(requested: 600); model.appearance.surface.compactHeight = 72
        XCTAssertEqual(model.frame(expanded: false).height, 72)
        XCTAssertGreaterThanOrEqual(model.frame(expanded: true).width, model.frame(expanded: false).width)
    }
    func testFramesRespectNegativeScreenOriginsAndEdgeAnchors() {
        var model = geometry(style: .bottom)
        model.screen.origin.x = -1512; model.visible.origin.x = -1512
        for expanded in [false, true] {
            XCTAssertEqual(model.frame(expanded: expanded).minY, 48)
            XCTAssertTrue(model.visible.contains(model.frame(expanded: expanded)))
        }
        model.style = .right
        XCTAssertEqual(model.frame(expanded: false).maxX, model.visible.maxX - 8)
    }
    func testLegacyAppearanceDecodesWithoutResettingSettings() throws {
        let legacy = Data(#"{"compactWidth":301,"background":"solid","animation":"elastic"}"#.utf8)
        let appearance = try JSONDecoder().decode(Appearance.self, from: legacy)
        XCTAssertEqual(appearance.compactWidth, 301)
        XCTAssertEqual(appearance.background, .solid)
        XCTAssertEqual(appearance.surface, SurfaceOptions())
    }
    func testSurfaceOptionsRoundTripAndValidation() throws {
        var appearance = Appearance(); appearance.surface.shape = .scoop; appearance.surface.closing = .slide
        let decoded = try JSONDecoder().decode(Appearance.self, from: JSONEncoder().encode(appearance))
        XCTAssertEqual(decoded, appearance)
        var options = SurfaceOptions(); options.duration = 9; options.compactHeight = 0
        XCTAssertEqual(try options.validated().duration, 1.2)
        XCTAssertEqual(try options.validated().compactHeight, 24)
        options.damping = .infinity
        XCTAssertThrowsError(try options.validated())
    }
    func testTransitionEndpointsAndFiniteSamples() {
        for transition in SurfaceTransition.allCases {
            XCTAssertEqual(SurfaceMotion.progress(0, transition: transition, preset: .smooth, damping: 0.8), 0)
            XCTAssertEqual(SurfaceMotion.progress(1, transition: transition, preset: .smooth, damping: 0.8), 1)
            for step in 0...100 {
                let progress = SurfaceMotion.progress(Double(step) / 100, transition: transition, preset: .smooth, damping: 0.4)
                XCTAssertTrue(progress.isFinite); XCTAssertGreaterThanOrEqual(progress, 0); XCTAssertLessThan(progress, 1.4)
            }
        }
        XCTAssertGreaterThan(SurfaceMotion.progress(0.3, transition: .spring, preset: .smooth, damping: 0.4), 1)
    }
    func testModuleDragPreservesEveryModuleOnce() {
        var layout = WorkspaceLayout(); layout.move(.notes, before: .clock)
        XCTAssertEqual(layout.order.first, .notes)
        XCTAssertEqual(Set(layout.order), Set(ModuleID.allCases))
        XCTAssertEqual(layout.order.count, ModuleID.allCases.count)
        layout.move(.notes, before: .notes)
        XCTAssertEqual(layout.order.first, .notes)
    }
    func testThemeRoundTrip() throws {
        let theme = Theme()
        XCTAssertEqual(theme, try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(theme)))
    }
    func testThemeClampsDimensions() throws {
        var theme = Theme()
        theme.width = 5000
        theme.opacity = -1
        let validated = try theme.validated()
        XCTAssertEqual(validated.width, 640)
        XCTAssertEqual(validated.opacity, 0.5)
    }
    func testRejectUnknownVersion() {
        var theme = Theme()
        theme.version = 99
        XCTAssertThrowsError(try theme.validated())
    }
    func testRejectNonFiniteValues() {
        var theme = Theme()
        theme.width = .infinity
        XCTAssertThrowsError(try theme.validated())
    }
    func testGeometryClampsToScreen() {
        XCTAssertEqual(Geometry.width(screenWidth: 360, requested: 640), 336)
        XCTAssertEqual(Geometry.width(screenWidth: 1440, requested: 420), 420)
    }
    func testConfigurationRoundTrip() throws {
        var configuration = Configuration()
        configuration.allDisplays = true
        configuration.showShelf = false
        let decoded = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration))
        XCTAssertTrue(decoded.allDisplays)
        XCTAssertFalse(decoded.showShelf)
    }
    func testModuleOrderDeduplicatesAndRestoresMissingModules() {
        var layout = WorkspaceLayout(); layout.order = [.timer, .timer, .clock]
        let result = layout.normalizedOrder()
        XCTAssertEqual(Array(result.prefix(2)), [.timer, .clock])
        XCTAssertEqual(Set(result), Set(ModuleID.allCases))
        XCTAssertEqual(result.count, ModuleID.allCases.count)
    }
    func testWorkspaceRoundTrip() throws {
        var settings = WorkspaceSettings(); settings.clipboardEnabled = true
        settings.layout.enabled = [.media, .calendar]
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(WorkspaceSettings.self, from: data)
        XCTAssertTrue(decoded.clipboardEnabled)
        XCTAssertEqual(decoded.layout.enabled, [.media, .calendar])
        XCTAssertEqual(decoded.profiles.count, 8)
    }
    func testClipboardIsOptIn() { XCTAssertFalse(WorkspaceSettings().clipboardEnabled) }
    func testAutomationBatteryRequiresRealReading() {
        let rule = AutomationRule(trigger: .batteryBelow, value: "20", profileID: UUID())
        XCTAssertFalse(rule.matches(app: "", battery: nil, charging: false, displays: 1, hour: 12))
        XCTAssertTrue(rule.matches(app: "", battery: 19, charging: false, displays: 1, hour: 12))
        XCTAssertFalse(rule.matches(app: "", battery: 20, charging: false, displays: 1, hour: 12))
    }
    func testDisabledAutomationDoesNotMatch() {
        let rule = AutomationRule(enabled: false, trigger: .activeApp, value: "Xcode", profileID: UUID())
        XCTAssertFalse(rule.matches(app: "Xcode", battery: nil, charging: false, displays: 1, hour: 1))
    }
    func testFuzzyCommandMatching() {
        XCTAssertTrue(CommandSearch.matches("stm25", in: "Start timer 25"))
        XCTAssertFalse(CommandSearch.matches("stop", in: "Start timer 25"))
        XCTAssertTrue(CommandSearch.matches("", in: "Safari"))
    }
    func testPluginRejectsExecutableAndFileURLs() {
        for url in ["file:///etc/passwd", "javascript:alert(1)", "http://example.com"] {
            let plugin = PluginManifest(version: 1, id: "test", name: "Test", permissions: ["openURL"], commands: [PluginCommand(id: "open", title: "Open", url: url)])
            XCTAssertThrowsError(try plugin.validated())
        }
    }
    func testPluginRejectsUndeclaredPermissionAndDuplicateCommands() {
        let command = PluginCommand(id: "one", title: "One", url: "https://example.com")
        XCTAssertThrowsError(try PluginManifest(version: 1, id: "test", name: "Test", permissions: [], commands: [command]).validated())
        XCTAssertThrowsError(try PluginManifest(version: 1, id: "test", name: "Test", permissions: ["openURL"], commands: [command, command]).validated())
    }
    func testPluginAcceptsHTTPS() throws {
        let plugin = PluginManifest(version: 1, id: "test", name: "Test", permissions: ["openURL"], commands: [PluginCommand(id: "open", title: "Open", url: "https://swift.org")])
        XCTAssertEqual(try plugin.validated().id, "test")
    }
    func testThemeArchiveRemovesForeignFilePaths() throws {
        var layout = WorkspaceLayout(); layout.appearance.assetPath = "/private/foreign.png"; layout.appearance.background = .image
        let archive = try ThemeArchive(theme: Theme(), layout: layout).validated()
        XCTAssertEqual(archive.layout.appearance.assetPath, "")
        XCTAssertEqual(archive.layout.appearance.background, .gradient)
    }
    func testThemeArchiveClampsEffects() throws {
        var layout = WorkspaceLayout(); layout.appearance.blur = 900; layout.appearance.expandedHeight = -1
        let archive = try ThemeArchive(theme: Theme(), layout: layout).validated()
        XCTAssertEqual(archive.layout.appearance.blur, 20)
        XCTAssertEqual(archive.layout.appearance.expandedHeight, 280)
    }
}
