import XCTest
@testable import HaloCISDK

final class CIContractTests: XCTestCase {
    func testCustomCIBindingResolverIsDeterministic() {
        let template = "Now playing {{ media.title }} by {{ media.artist }}"
        XCTAssertEqual(HaloCIBindingResolver.keys(in: template), ["media.title", "media.artist"])
        XCTAssertEqual(HaloCIBindingResolver.resolve(template, data: ["media.title": "Halo", "media.artist": "Redstone"]), "Now playing Halo by Redstone")
        XCTAssertEqual(HaloCIBindingResolver.resolve("{{ media.album }}", data: [:]), "")
    }

    func testCustomCITriggerPermissionAndMatching() {
        let document = HaloCITriggerDocument(match: "all", triggers: [
            HaloCITrigger(type: "mediaPlaying", value: nil, number: nil, bool: true, startMinute: nil, endMinute: nil),
            HaloCITrigger(type: "batteryAbove", value: nil, number: 20, bool: nil, startMinute: nil, endMinute: nil)
        ])
        let snapshot = HaloCITriggerSnapshot(mediaIsPlaying: true, activeApplicationBundleID: "com.apple.Music", batteryLevel: 80, charging: false, minuteOfDay: 700)
        XCTAssertFalse(HaloCITriggerEvaluator.matches(document, snapshot: snapshot, grantedPermissions: []))
        XCTAssertTrue(HaloCITriggerEvaluator.matches(document, snapshot: snapshot, grantedPermissions: ["Media.ReadState"]))
    }

    func testCustomCIValidatorAcceptsMinimalPackage() throws {
        let root = try makeCustomCIPackage(
            manifest: customCIManifestJSON(),
            interface: #"{"expanded":{"type":"VStack","children":[{"type":"Text","text":"Hello Halo"}]}}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertTrue(report.isValid, report.issues.map(\.message).joined(separator: " | "))
        XCTAssertEqual(report.package?.manifest.id, "com.redstoneinvente.tests.hello")
    }

    func testCustomCIValidatorRejectsExecutableContent() throws {
        let root = try makeCustomCIPackage(manifest: customCIManifestJSON(), interface: #"{"expanded":{"type":"Text","text":"Safe"}}"#)
        defer { try? FileManager.default.removeItem(at: root) }
        let scripts = root.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        try "print(\'nope\')".write(to: scripts.appendingPathComponent("main.py"), atomically: true, encoding: .utf8)
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.message.contains("Executable/script") })
    }

    func testCustomCIValidatorRejectsUndeclaredProtectedBinding() throws {
        let root = try makeCustomCIPackage(
            manifest: customCIManifestJSON(),
            interface: #"{"expanded":{"type":"Text","text":"{{ media.title }}"}}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.message.contains("Media.ReadState") })
    }

    func testCustomCIValidatorAcceptsDeclaredPermissionActionAndTrigger() throws {
        let manifest = customCIManifestJSON(permissions: ["Media.ReadState", "Media.Control"])
        let root = try makeCustomCIPackage(
            manifest: manifest,
            interface: #"{"expanded":{"type":"VStack","children":[{"type":"Text","text":"{{ media.title }}"},{"type":"Button","text":"Play","accessibilityLabel":"Play or pause media","action":{"id":"media.playPause"}}]}}"#,
            triggers: #"{"match":"any","triggers":[{"type":"mediaPlaying","bool":true}]}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertTrue(report.isValid, report.issues.map(\.message).joined(separator: " | "))
    }

    func testCustomCIValidatorRejectsUnknownComponentsAndTraversal() throws {
        let root = try makeCustomCIPackage(
            manifest: customCIManifestJSON(),
            interface: #"{"expanded":{"type":"RawSwiftUIView","source":"asset:../secret.png"}}"#
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.message.contains("Unsupported component") })
    }

    func testCustomCIValidatorRejectsUnsupportedSchemaAndSDK() throws {
        let bad = #"{"schemaVersion":2,"sdkVersion":"9.9","id":"com.redstoneinvente.tests.hello","name":"Hello CI","author":"Tests","version":"1.0.0","minimumHaloVersion":"1.0.0","entryInterface":"interface.json","description":"","permissions":[],"capabilities":[],"supportedSurfaces":["notch"],"supportedStates":["expanded"]}"#
        let root = try makeCustomCIPackage(manifest: bad, interface: #"{"expanded":{"type":"Text","text":"Hello"}}"#)
        defer { try? FileManager.default.removeItem(at: root) }
        let report = HaloCIPackageValidator.validatePackage(at: root)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.path.contains("schemaVersion") })
        XCTAssertTrue(report.issues.contains { $0.path.contains("sdkVersion") })
    }

    private func customCIManifestJSON(permissions: [String] = []) -> String {
        let permissionJSON = permissions.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"schemaVersion":1,"sdkVersion":"0.1","id":"com.redstoneinvente.tests.hello","name":"Hello CI","author":"Tests","version":"1.0.0","minimumHaloVersion":"1.0.0","entryInterface":"interface.json","description":"Test package","permissions":[\(permissionJSON)],"capabilities":[],"supportedSurfaces":["notch"],"supportedStates":["closed","expanded"],"surface":{"sizing":{"mode":"static","closed":{"width":250,"height":40},"expanded":{"width":500,"height":220}},"background":{"closed":{"type":"solid","color":"#101010"},"expanded":{"type":"solid","color":"#101010"}}}}
        """
    }

    private func makeCustomCIPackage(manifest: String, interface: String, triggers: String? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("haloCI")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try manifest.write(to: root.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try interface.write(to: root.appendingPathComponent("interface.json"), atomically: true, encoding: .utf8)
        if let triggers { try triggers.write(to: root.appendingPathComponent("triggers.json"), atomically: true, encoding: .utf8) }
        return root
    }
}
