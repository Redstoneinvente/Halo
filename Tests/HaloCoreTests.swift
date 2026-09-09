import XCTest
#if SWIFT_PACKAGE
@testable import HaloCore
#endif

final class HaloCoreTests: XCTestCase {
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
