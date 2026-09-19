import Foundation

/// File-based authoring tools intentionally share the app's parser and validator.
/// This facade exports no private Halo service objects.
public enum HaloCIDeveloperTools {
    public static func run(_ arguments: [String]) throws -> String {
        guard let command = arguments.first else { return usage }
        switch command {
        case "catalog":
            guard arguments.count == 1 else { throw ToolError(usage) }
            return String(decoding: try encoder.encode(HaloCIContextCatalog.fields), as: UTF8.self)
        case "validate":
            guard arguments.count == 2 else { throw ToolError(usage) }
            let report = HaloCIPackageValidator.validatePackage(at: URL(fileURLWithPath: arguments[1]))
            let diagnostics = report.issues.map { "\($0.severity.rawValue): \($0.path): \($0.message)" }.joined(separator: "\n")
            guard report.isValid else { throw ToolError(diagnostics) }
            return "Valid: \(report.package!.manifest.id) (SDK \(report.package!.manifest.sdkVersion))\n" + diagnostics
        case "init":
            guard arguments.count == 4 else { throw ToolError(usage) }
            let destination = URL(fileURLWithPath: arguments[1]).standardizedFileURL
            guard destination.pathExtension == "haloCI" else { throw ToolError("Destination must end in .haloCI.") }
            guard !FileManager.default.fileExists(atPath: destination.path) else { throw ToolError("Destination already exists; no files were changed.") }
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".haloCI")
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: staging) }
            let manifest = HaloCIManifest(sdkVersion: "0.2", id: arguments[2], name: arguments[3],
                                          author: "Your Name", version: "1.0.0")
            try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))
            let document: [String: Any] = [
                "closed": ["type": "Text", "text": "{{ ci.name }}", "padding": 8, "lineLimit": 1],
                "expanded": ["type": "NotchContainer", "spacing": 12, "padding": 18, "children": [
                    ["type": "Text", "text": "{{ ci.name }}", "style": "headline"],
                    ["type": "Text", "text": "Surface: {{ halo.surface.state }} · Displays: {{ displays.count }}"],
                    ["type": "Button", "text": "Close", "accessibilityLabel": "Close interface", "action": ["id": "halo.ci.close"]]
                ]]
            ]
            try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
                .write(to: staging.appendingPathComponent("interface.json"))
            let report = HaloCIPackageValidator.validatePackage(at: staging)
            guard report.isValid else { throw ToolError(report.issues.map { "\($0.path): \($0.message)" }.joined(separator: "\n")) }
            try FileManager.default.moveItem(at: staging, to: destination)
            return "Created \(destination.path). Import it through Halo Settings → Custom CI."
        default: throw ToolError(usage)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
    private static let usage = "Usage: halo-ci catalog | validate <package.haloCI> | init <package.haloCI> <reverse.dns.id> <name>"
    private struct ToolError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
