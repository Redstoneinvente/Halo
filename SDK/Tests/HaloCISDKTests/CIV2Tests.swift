import XCTest
@testable import HaloCISDK

final class CIV2Tests: XCTestCase {
    private func starter() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".haloCI")
        _ = try HaloCIDeveloperTools.run(["init", url.path, "com.example.tests", "Test CI"])
        return url
    }
    private func edit(_ root: URL, _ file: String, _ body: (inout [String: Any]) -> Void) throws {
        let url = root.appendingPathComponent(file)
        var value = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        body(&value)
        try JSONSerialization.data(withJSONObject: value).write(to: url)
    }
    func testStarterUsesAppValidatorAndDoesNotOverwrite() throws {
        let root = try starter()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(try HaloCIDeveloperTools.run(["validate", root.path]).contains("SDK 0.2"))
        let before = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
        XCTAssertThrowsError(try HaloCIDeveloperTools.run(["init", root.path, "other.id", "Other"]))
        XCTAssertEqual(before, try Data(contentsOf: root.appendingPathComponent("manifest.json")))
    }
    func testInvalidStarterDoesNotLeaveDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".haloCI")
        XCTAssertThrowsError(try HaloCIDeveloperTools.run(["init", root.path, "invalid", "Test"]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
    func testCatalogIsUniqueAndExportable() throws {
        let fields = try JSONDecoder().decode([HaloCIContextField].self, from: Data(HaloCIDeveloperTools.run(["catalog"]).utf8))
        XCTAssertEqual(fields, HaloCIContextCatalog.fields)
        XCTAssertEqual(Set(fields.map(\.key)).count, fields.count)
        XCTAssertTrue(fields.allSatisfy { ["boolean", "number", "string"].contains($0.type) })
    }
    func testContextRequiresBothDeclaredAndGrantedPermission() {
        let values = ["audio.volume": "0.5", "media.title": "Private", "displays.count": "2", "private.key": "secret"]
        let declared: Set<String> = ["Media.ReadState", "Audio.ReadState"]
        XCTAssertEqual(HaloCIContextCatalog.filter(values, sdkVersion: "0.2", declaredPermissions: declared, grantedPermissions: []), ["displays.count": "2"])
        XCTAssertEqual(HaloCIContextCatalog.filter(values, sdkVersion: "0.2", declaredPermissions: [], grantedPermissions: declared), ["displays.count": "2"])
        XCTAssertEqual(HaloCIContextCatalog.filter(values, sdkVersion: "0.2", declaredPermissions: declared, grantedPermissions: declared).count, 3)
    }
    func testVersionAndTypeFilteringFailClosed() {
        let values = ["displays.count": "2", "system.cpu.usedPercent": "nan", "media.isPlaying": "yes", "media.title": "Song"]
        XCTAssertEqual(HaloCIContextCatalog.filter(values, sdkVersion: "0.1", declaredPermissions: ["Media.ReadState"], grantedPermissions: ["Media.ReadState"]), ["media.title": "Song"])
        XCTAssertTrue(HaloCIContextCatalog.filter(values, sdkVersion: "9.0", declaredPermissions: [], grantedPermissions: []).isEmpty)
    }
    func testMixedMalformedBindingIsRejected() throws {
        XCTAssertFalse(HaloCIBindingResolver.isWellFormed("{{ media.title }} {{ arbitrary() }}"))
        XCTAssertFalse(HaloCIBindingResolver.isWellFormed("hello }}"))
        XCTAssertTrue(HaloCIBindingResolver.isWellFormed("😀 {{ media.title }}"))
        let root = try starter()
        defer { try? FileManager.default.removeItem(at: root) }
        try edit(root, "interface.json") { $0["expanded"] = ["type": "Text", "text": "{{ ci.name }} {{ eval() }}"] }
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)
    }
    func testNewBindingsRequireNewSDKAndPermissions() throws {
        let root = try starter()
        defer { try? FileManager.default.removeItem(at: root) }
        try edit(root, "interface.json") { $0["expanded"] = ["type": "Text", "text": "{{ audio.output.name }}"] }
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)
        try edit(root, "manifest.json") { $0["permissions"] = ["Audio.ReadState"] }
        XCTAssertTrue(HaloCIPackageValidator.validatePackage(at: root).isValid)
        try edit(root, "manifest.json") { $0["sdkVersion"] = "0.1" }
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)
    }
    func testHiddenExecutableAndSymlinkRejected() throws {
        let root = try starter()
        defer { try? FileManager.default.removeItem(at: root) }
        let hidden = root.appendingPathComponent(".hidden.js")
        try Data("bad".utf8).write(to: hidden)
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)
        try FileManager.default.removeItem(at: hidden)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(".hidden"), withDestinationURL: root.appendingPathComponent("manifest.json"))
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)
    }
    func testNewTriggersAndVersionGate() throws {
        let root = try starter()
        defer { try? FileManager.default.removeItem(at: root) }
        let triggers = #"{"match":"all","triggers":[{"type":"lowPowerMode","bool":true},{"type":"displayCount","number":2}]}"#
        try Data(triggers.utf8).write(to: root.appendingPathComponent("triggers.json"))
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertTrue(report.isValid)
        let doc = try XCTUnwrap(report.package?.triggers)
        XCTAssertTrue(HaloCITriggerEvaluator.matches(doc, snapshot: .init(lowPowerMode: true, displayCount: 2), grantedPermissions: []))
        XCTAssertFalse(HaloCITriggerEvaluator.matches(doc, snapshot: .init(lowPowerMode: false, displayCount: 2), grantedPermissions: []))
        try edit(root, "manifest.json") { $0["sdkVersion"] = "0.1" }
        XCTAssertTrue(HaloCIPackageValidator.validatePackage(at: root).issues.contains { $0.message.contains("trigger requires SDK 0.2") })
        try edit(root, "manifest.json") { $0["sdkVersion"] = "0.2" }
        for invalid in ["2.5", "true", "0", "65"] {
            try Data(triggers.replacingOccurrences(of: "\"number\":2", with: "\"number\":\(invalid)").utf8).write(to: root.appendingPathComponent("triggers.json"))
            XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid, invalid)
        }
    }
    func testAppIntegrationActionRequiresSDKPermissionAndArguments() throws {
        let root = try starter()
        defer { try? FileManager.default.removeItem(at: root) }

        try edit(root, "manifest.json") {
            $0["permissions"] = ["AppIntegration.Execute"]
            $0["capabilities"] = ["AppIntegrations"]
        }
        try edit(root, "interface.json") {
            $0["expanded"] = [
                "type": "Button",
                "text": "Convert",
                "accessibilityLabel": "Convert with partner app",
                "action": [
                    "id": "app.integration.invoke",
                    "arguments": [
                        "bundleIdentifier": "com.example.partner",
                        "actionID": "convert.file"
                    ]
                ]
            ]
        }

        XCTAssertTrue(
            HaloCIPackageValidator.validatePackage(at: root).isValid,
            HaloCIPackageValidator.validatePackage(at: root).issues.map(\.message).joined(separator: "\n")
        )

        try edit(root, "manifest.json") { $0["sdkVersion"] = "0.1" }
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)

        try edit(root, "manifest.json") { $0["sdkVersion"] = "0.2" }
        try edit(root, "interface.json") {
            guard var expanded = $0["expanded"] as? [String: Any],
                  var action = expanded["action"] as? [String: Any],
                  var arguments = action["arguments"] as? [String: Any] else { return }
            arguments.removeValue(forKey: "actionID")
            action["arguments"] = arguments
            expanded["action"] = action
            $0["expanded"] = expanded
        }
        XCTAssertFalse(HaloCIPackageValidator.validatePackage(at: root).isValid)
    }

    func testAppIntegrationActionAuthorizationIsRevocable() {
        let permission: Set<String> = ["AppIntegration.Execute"]
        XCTAssertTrue(HaloCIActionAuthorization.allows(
            "app.integration.invoke",
            enabled: true,
            globallyDisabled: false,
            declaredPermissions: permission,
            grantedPermissions: permission
        ))
        XCTAssertFalse(HaloCIActionAuthorization.allows(
            "app.integration.invoke",
            enabled: true,
            globallyDisabled: false,
            declaredPermissions: permission,
            grantedPermissions: []
        ))
    }

    func testActionsFailClosedAfterDisableOrRevocation() {
        let permission: Set<String> = ["Clipboard.Write"]
        XCTAssertTrue(HaloCIActionAuthorization.allows("clipboard.copy", enabled: true, globallyDisabled: false, declaredPermissions: permission, grantedPermissions: permission))
        for (enabled, disabled, declared, granted) in [
            (false, false, permission, permission), (true, true, permission, permission),
            (true, false, Set<String>(), permission), (true, false, permission, Set<String>())
        ] {
            XCTAssertFalse(HaloCIActionAuthorization.allows("clipboard.copy", enabled: enabled, globallyDisabled: disabled, declaredPermissions: declared, grantedPermissions: granted))
        }
        XCTAssertFalse(HaloCIActionAuthorization.allows("shell.run", enabled: true, globallyDisabled: false, declaredPermissions: permission, grantedPermissions: permission))
    }
    func testLegacySampleStillValid() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = HaloCIPackageValidator.validatePackage(at: repository.appendingPathComponent("Examples/HelloWorld.haloCI"))
        XCTAssertTrue(report.isValid, report.issues.map(\.message).joined(separator: "\n"))
    }
}
