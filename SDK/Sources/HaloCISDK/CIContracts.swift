import Foundation
import CoreFoundation

// MARK: - Halo Custom CI SDK 0.1

enum HaloCISDK {
    static let schemaVersion = 1
    static let sdkVersion = "0.2"
    static let supportedSDKVersions: Set<String> = ["0.1", "0.2"]
    static let maximumPackageBytes: Int64 = 10_000_000
    static let maximumFileCount = 128
    static let maximumJSONBytes: Int64 = 512_000
    static let maximumComponentCount = 180
    static let maximumTreeDepth = 16
    static let maximumStringLength = 8_192

    static let supportedComponents: Set<String> = [
        "Text", "Image", "Icon", "Button", "Toggle", "Slider", "Progress", "ProgressRing",
        "Spacer", "Divider", "HStack", "VStack", "ZStack", "Grid", "ScrollView", "Badge",
        "NotchContainer", "MediaArtwork", "AppIcon", "DeviceBattery", "SystemMetric", "ActivityIndicator"
    ]
    static let supportedPermissions: Set<String> = [
        "Media.ReadState", "Media.Control", "Applications.Observe", "Clipboard.Write", "URL.Open", "Audio.ReadState"
    ]
    static let supportedCapabilities: Set<String> = ["LocalAssets", "LocalState", "AutomaticTriggers", "MediaControls"]
    static let supportedActions: Set<String> = [
        "halo.ci.close", "clipboard.copy", "url.open", "media.playPause", "media.next", "media.previous"
    ]
    static let supportedTriggers: Set<String> = [
        "manual", "mediaPlaying", "activeApplication", "batteryBelow", "batteryAbove", "charging", "timeWindow", "lowPowerMode", "displayCount"
    ]
    static let supportedDataKeys = Set(HaloCIContextCatalog.fields.map(\.key))

    static func permissionForDataKey(_ key: String) -> String? {
        HaloCIContextCatalog.fields.first { $0.key == key }?.permission
    }
    static func permissionForAction(_ id: String) -> String? {
        switch id {
        case "media.playPause", "media.next", "media.previous": return "Media.Control"
        case "clipboard.copy": return "Clipboard.Write"
        case "url.open": return "URL.Open"
        default: return nil
        }
    }
    static func permissionForTrigger(_ type: String) -> String? {
        switch type {
        case "mediaPlaying": return "Media.ReadState"
        case "activeApplication": return "Applications.Observe"
        default: return nil
        }
    }
}

struct HaloCISizeRule: Codable, Equatable {
    var width: Double?
    var height: Double?
    var minWidth: Double?
    var preferredWidth: Double?
    var maxWidth: Double?
    var minHeight: Double?
    var preferredHeight: Double?
    var maxHeight: Double?

    init(width: Double? = nil, height: Double? = nil,
         minWidth: Double? = nil, preferredWidth: Double? = nil, maxWidth: Double? = nil,
         minHeight: Double? = nil, preferredHeight: Double? = nil, maxHeight: Double? = nil) {
        self.width = width; self.height = height
        self.minWidth = minWidth; self.preferredWidth = preferredWidth; self.maxWidth = maxWidth
        self.minHeight = minHeight; self.preferredHeight = preferredHeight; self.maxHeight = maxHeight
    }
}

struct HaloCISurfaceSizing: Codable, Equatable {
    /// `static` means exact declared dimensions. `dynamic` means Halo measures the rendered
    /// declarative tree and clamps it to the declared min/preferred/max bounds.
    var mode: String
    var closed: HaloCISizeRule?
    var expanded: HaloCISizeRule
}

struct HaloCIBackgroundStyle: Codable, Equatable {
    /// solid, gradient, glass, or clear
    var type: String
    var color: String?
    var secondaryColor: String?
    var opacity: Double?
    var blur: Double?

    init(type: String = "solid", color: String? = "#101014", secondaryColor: String? = nil,
         opacity: Double? = 1, blur: Double? = 0) {
        self.type = type; self.color = color; self.secondaryColor = secondaryColor
        self.opacity = opacity; self.blur = blur
    }
}

struct HaloCIBackgroundContract: Codable, Equatable {
    var closed: HaloCIBackgroundStyle?
    var expanded: HaloCIBackgroundStyle
}

struct HaloCISurfaceContract: Codable, Equatable {
    var sizing: HaloCISurfaceSizing
    var background: HaloCIBackgroundContract

    static let safeDefault = HaloCISurfaceContract(
        sizing: HaloCISurfaceSizing(
            mode: "static",
            closed: HaloCISizeRule(width: 190, height: 40),
            expanded: HaloCISizeRule(width: 560, height: 260)
        ),
        background: HaloCIBackgroundContract(
            closed: HaloCIBackgroundStyle(type: "solid", color: "#101014"),
            expanded: HaloCIBackgroundStyle(type: "solid", color: "#101014")
        )
    )
}

struct HaloCIManifest: Codable, Equatable {
    var schemaVersion: Int
    var sdkVersion: String
    var id: String
    var name: String
    var author: String
    var version: String
    var minimumHaloVersion: String
    var entryInterface: String
    var description: String
    var permissions: [String]
    var capabilities: [String]
    var supportedSurfaces: [String]
    var supportedStates: [String]
    var surface: HaloCISurfaceContract

    init(schemaVersion: Int = 1, sdkVersion: String = "0.1", id: String, name: String,
         author: String, version: String, minimumHaloVersion: String = "1.0.0",
         entryInterface: String = "interface.json", description: String = "",
         permissions: [String] = [], capabilities: [String] = [],
         supportedSurfaces: [String] = ["notch"], supportedStates: [String] = ["closed", "expanded"],
         surface: HaloCISurfaceContract = .safeDefault) {
        self.schemaVersion = schemaVersion; self.sdkVersion = sdkVersion; self.id = id; self.name = name
        self.author = author; self.version = version; self.minimumHaloVersion = minimumHaloVersion
        self.entryInterface = entryInterface; self.description = description; self.permissions = permissions
        self.capabilities = capabilities; self.supportedSurfaces = supportedSurfaces; self.supportedStates = supportedStates
        self.surface = surface
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sdkVersion, id, name, author, version, minimumHaloVersion, entryInterface,
             description, permissions, capabilities, supportedSurfaces, supportedStates, surface
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        sdkVersion = try c.decode(String.self, forKey: .sdkVersion)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        author = try c.decode(String.self, forKey: .author)
        version = try c.decode(String.self, forKey: .version)
        minimumHaloVersion = try c.decodeIfPresent(String.self, forKey: .minimumHaloVersion) ?? "1.0.0"
        entryInterface = try c.decodeIfPresent(String.self, forKey: .entryInterface) ?? "interface.json"
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        permissions = try c.decodeIfPresent([String].self, forKey: .permissions) ?? []
        capabilities = try c.decodeIfPresent([String].self, forKey: .capabilities) ?? []
        supportedSurfaces = try c.decodeIfPresent([String].self, forKey: .supportedSurfaces) ?? ["notch"]
        supportedStates = try c.decodeIfPresent([String].self, forKey: .supportedStates) ?? ["expanded"]
        surface = try c.decodeIfPresent(HaloCISurfaceContract.self, forKey: .surface) ?? .safeDefault
    }
}

struct HaloCIActionDescriptor: Codable, Equatable {
    var id: String
    var value: String?
    var arguments: [String: String]?
}

struct HaloCIComponent: Codable, Equatable {
    var type: String
    var id: String?
    var text: String?
    var value: String?
    var source: String?
    var systemName: String?
    var metric: String?
    var children: [HaloCIComponent]?
    var action: HaloCIActionDescriptor?
    var spacing: Double?
    var padding: Double?
    var width: Double?
    var height: Double?
    var cornerRadius: Double?
    var lineLimit: Int?
    var foreground: String?
    var background: String?
    var alignment: String?
    var axis: String?
    var columns: Int?
    var accessibilityLabel: String?
    var stateKey: String?
    var defaultBool: Bool?
    var defaultNumber: Double?
    var minimum: Double?
    var maximum: Double?
    var step: Double?
    var style: String?
}

struct HaloCIInterfaceDocument: Codable, Equatable {
    var closed: HaloCIComponent?
    var expanded: HaloCIComponent
}

struct HaloCITrigger: Codable, Equatable {
    var type: String
    var value: String?
    var number: Double?
    var bool: Bool?
    var startMinute: Int?
    var endMinute: Int?
}

struct HaloCITriggerDocument: Codable, Equatable {
    var match: String = "any"
    var triggers: [HaloCITrigger] = []

    private enum CodingKeys: String, CodingKey { case match, triggers }
    init(match: String = "any", triggers: [HaloCITrigger] = []) { self.match = match; self.triggers = triggers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        match = try c.decodeIfPresent(String.self, forKey: .match) ?? "any"
        triggers = try c.decodeIfPresent([HaloCITrigger].self, forKey: .triggers) ?? []
    }
}

enum HaloCIValidationSeverity: String, Codable { case warning, error }
struct HaloCIValidationIssue: Identifiable, Codable, Equatable {
    var id = UUID()
    var severity: HaloCIValidationSeverity
    var path: String
    var message: String
    init(_ severity: HaloCIValidationSeverity, _ path: String, _ message: String) {
        self.severity = severity; self.path = path; self.message = message
    }
}

struct HaloCIParsedPackage {
    var rootURL: URL
    var manifest: HaloCIManifest
    var interface: HaloCIInterfaceDocument
    var triggers: HaloCITriggerDocument
    var issues: [HaloCIValidationIssue]
}

struct HaloCIValidationReport {
    var package: HaloCIParsedPackage?
    var issues: [HaloCIValidationIssue]
    var isValid: Bool { package != nil && !issues.contains { $0.severity == .error } }
}

struct HaloCITriggerSnapshot: Equatable {
    var mediaIsPlaying = false
    var activeApplicationBundleID = ""
    var batteryLevel: Double?
    var charging = false
    var minuteOfDay = 0
    var lowPowerMode = false
    var displayCount = 1
}

enum HaloCITriggerEvaluator {
    static func matches(_ document: HaloCITriggerDocument, snapshot: HaloCITriggerSnapshot,
                        grantedPermissions: Set<String>) -> Bool {
        let automatic = document.triggers.filter { $0.type != "manual" }
        guard !automatic.isEmpty else { return false }
        let values = automatic.map { trigger -> Bool in
            if let permission = HaloCISDK.permissionForTrigger(trigger.type), !grantedPermissions.contains(permission) { return false }
            switch trigger.type {
            case "lowPowerMode": return snapshot.lowPowerMode == (trigger.bool ?? true)
            case "displayCount": return Double(snapshot.displayCount) == trigger.number
            case "mediaPlaying": return snapshot.mediaIsPlaying == (trigger.bool ?? true)
            case "activeApplication": return snapshot.activeApplicationBundleID == (trigger.value ?? "")
            case "batteryBelow": guard let level = snapshot.batteryLevel, let threshold = trigger.number else { return false }; return level < threshold
            case "batteryAbove": guard let level = snapshot.batteryLevel, let threshold = trigger.number else { return false }; return level > threshold
            case "charging": return snapshot.charging == (trigger.bool ?? true)
            case "timeWindow":
                guard let start = trigger.startMinute, let end = trigger.endMinute else { return false }
                let minute = min(1439, max(0, snapshot.minuteOfDay))
                if start == end { return true }
                return start < end ? (minute >= start && minute < end) : (minute >= start || minute < end)
            default: return false
            }
        }
        return document.match == "all" ? values.allSatisfy { $0 } : values.contains(true)
    }
}

enum HaloCIBindingResolver {
    private static let regex = try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9._-]+)\s*\}\}"#)

    static func isWellFormed(_ template: String) -> Bool {
        let remainder = regex.stringByReplacingMatches(in: template,
            range: NSRange(template.startIndex..., in: template), withTemplate: "")
        return !remainder.contains("{{") && !remainder.contains("}}")
    }

    static func keys(in template: String) -> [String] {
        let ns = template as NSString
        return regex.matches(in: template, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges == 2 else { return nil }
            return ns.substring(with: match.range(at: 1))
        }
    }

    static func resolve(_ template: String, data: [String: String]) -> String {
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template)).reversed()
        var result = template
        for match in matches {
            guard let full = Range(match.range(at: 0), in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[keyRange])
            result.replaceSubrange(full, with: data[key] ?? "")
        }
        return result
    }
}

enum HaloCIPackageValidator {
    private static let manifestKeys: Set<String> = [
        "schemaVersion", "sdkVersion", "id", "name", "author", "version", "minimumHaloVersion",
        "entryInterface", "description", "permissions", "capabilities", "supportedSurfaces", "supportedStates", "surface"
    ]
    private static let surfaceKeys: Set<String> = ["sizing", "background"]
    private static let sizingKeys: Set<String> = ["mode", "closed", "expanded"]
    private static let sizeRuleKeys: Set<String> = [
        "width", "height", "minWidth", "preferredWidth", "maxWidth",
        "minHeight", "preferredHeight", "maxHeight"
    ]
    private static let backgroundKeys: Set<String> = ["closed", "expanded"]
    private static let backgroundStyleKeys: Set<String> = ["type", "color", "secondaryColor", "opacity", "blur"]
    private static let interfaceKeys: Set<String> = ["closed", "expanded"]
    private static let componentKeys: Set<String> = [
        "type", "id", "text", "value", "source", "systemName", "metric", "children", "action",
        "spacing", "padding", "width", "height", "cornerRadius", "lineLimit", "foreground", "background",
        "alignment", "axis", "columns", "accessibilityLabel", "stateKey", "defaultBool", "defaultNumber",
        "minimum", "maximum", "step", "style"
    ]
    private static let actionKeys: Set<String> = ["id", "value", "arguments"]
    private static let triggerDocumentKeys: Set<String> = ["match", "triggers"]
    private static let triggerKeys: Set<String> = ["type", "value", "number", "bool", "startMinute", "endMinute"]
    private static let executableExtensions: Set<String> = ["js", "mjs", "cjs", "swift", "dylib", "so", "sh", "command", "scpt", "py", "rb"]
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "gif", "heic", "tiff", "bmp"]

    static func validatePackage(at root: URL) -> HaloCIValidationReport {
        var issues: [HaloCIValidationIssue] = []
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return HaloCIValidationReport(package: nil, issues: [.init(.error, root.lastPathComponent, "Custom CI must currently be an unpacked .haloCI directory.")])
        }
        guard root.pathExtension.lowercased() == "haloci" else {
            return HaloCIValidationReport(package: nil, issues: [.init(.error, root.lastPathComponent, "Package directory must use the .haloCI extension.")])
        }

        if (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            return HaloCIValidationReport(package: nil, issues: [.init(.error, ".", "Package root may not be a symbolic link.")])
        }

        var fileCount = 0
        var totalBytes: Int64 = 0
        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey], options: []) {
            for case let url as URL in enumerator {
                let relative = String(url.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if relative.split(separator: "/").contains("..") || url.path.contains("/../") {
                    issues.append(.init(.error, relative, "Path traversal is not allowed.")); continue
                }
                do {
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey])
                    if values.isSymbolicLink == true {
                        issues.append(.init(.error, relative, "Symbolic links are not allowed in CI packages.")); continue
                    }
                    if values.isRegularFile == true {
                        fileCount += 1; totalBytes += Int64(values.fileSize ?? 0)
                        if executableExtensions.contains(url.pathExtension.lowercased()) || relative.lowercased().hasPrefix("scripts/") {
                            issues.append(.init(.error, relative, "Executable/script content is reserved until Halo has an isolated CI runtime host."))
                        }
                    }
                } catch {
                    issues.append(.init(.error, relative, "Could not inspect package entry: \(error.localizedDescription)"))
                }
            }
        }
        if fileCount > HaloCISDK.maximumFileCount { issues.append(.init(.error, ".", "Package contains \(fileCount) files; maximum is \(HaloCISDK.maximumFileCount).")) }
        if totalBytes > HaloCISDK.maximumPackageBytes { issues.append(.init(.error, ".", "Package exceeds the 10 MB SDK 0.1 limit.")) }

        if issues.contains(where: { $0.severity == .error }) {
            return HaloCIValidationReport(package: nil, issues: issues)
        }

        let manifestURL = root.appendingPathComponent("manifest.json")
        guard let manifestData = readJSON(manifestURL, issues: &issues, label: "manifest.json"),
              let manifestObject = jsonObject(manifestData, path: "manifest.json", issues: &issues) as? [String: Any] else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        rejectUnknownKeys(in: manifestObject, allowed: manifestKeys, path: "manifest.json", issues: &issues)
        guard let manifest = decode(HaloCIManifest.self, data: manifestData, path: "manifest.json", issues: &issues) else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        validateManifest(manifest, issues: &issues)
        if let surfaceObject = manifestObject["surface"] as? [String: Any] {
            validateSurfaceRaw(surfaceObject, manifest: manifest, issues: &issues)
        } else {
            issues.append(.init(.error, "manifest.json.surface", "Every Custom CI must declare its notch sizing and background contract."))
        }

        guard safeRelativePath(manifest.entryInterface) else {
            issues.append(.init(.error, "manifest.json.entryInterface", "entryInterface must be a relative path inside the package."))
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        let interfaceURL = root.appendingPathComponent(manifest.entryInterface)
        guard interfaceURL.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") else {
            issues.append(.init(.error, "manifest.json.entryInterface", "entryInterface escapes the package root."))
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        guard let interfaceData = readJSON(interfaceURL, issues: &issues, label: manifest.entryInterface),
              let interfaceObject = jsonObject(interfaceData, path: manifest.entryInterface, issues: &issues) as? [String: Any] else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }
        rejectUnknownKeys(in: interfaceObject, allowed: interfaceKeys, path: manifest.entryInterface, issues: &issues)
        validateInterfaceRaw(interfaceObject, packageRoot: root, manifest: manifest, path: manifest.entryInterface, issues: &issues)
        guard let interface = decode(HaloCIInterfaceDocument.self, data: interfaceData, path: manifest.entryInterface, issues: &issues) else {
            return HaloCIValidationReport(package: nil, issues: issues)
        }

        var triggers = HaloCITriggerDocument()
        let triggerURL = root.appendingPathComponent("triggers.json")
        if fm.fileExists(atPath: triggerURL.path), let data = readJSON(triggerURL, issues: &issues, label: "triggers.json") {
            if let object = jsonObject(data, path: "triggers.json", issues: &issues) as? [String: Any] {
                rejectUnknownKeys(in: object, allowed: triggerDocumentKeys, path: "triggers.json", issues: &issues)
                validateTriggersRaw(object, manifest: manifest, issues: &issues)
            }
            if let decoded = decode(HaloCITriggerDocument.self, data: data, path: "triggers.json", issues: &issues) { triggers = decoded }
        }

        let errors = issues.contains { $0.severity == .error }
        let package = errors ? nil : HaloCIParsedPackage(rootURL: root, manifest: manifest, interface: interface, triggers: triggers, issues: issues)
        return HaloCIValidationReport(package: package, issues: issues)
    }

    private static func readJSON(_ url: URL, issues: inout [HaloCIValidationIssue], label: String) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { issues.append(.init(.error, label, "Required file is missing.")); return nil }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { issues.append(.init(.error, label, "JSON files may not be symbolic links.")); return nil }
            if Int64(values.fileSize ?? 0) > HaloCISDK.maximumJSONBytes { issues.append(.init(.error, label, "JSON file exceeds 512 KB.")); return nil }
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch { issues.append(.init(.error, label, error.localizedDescription)); return nil }
    }

    private static func jsonObject(_ data: Data, path: String, issues: inout [HaloCIValidationIssue]) -> Any? {
        do { return try JSONSerialization.jsonObject(with: data) }
        catch { issues.append(.init(.error, path, "Invalid JSON: \(error.localizedDescription)")); return nil }
    }

    private static func decode<T: Decodable>(_ type: T.Type, data: Data, path: String, issues: inout [HaloCIValidationIssue]) -> T? {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { issues.append(.init(.error, path, "Schema decode failed: \(error.localizedDescription)")); return nil }
    }

    private static func rejectUnknownKeys(in object: [String: Any], allowed: Set<String>, path: String, issues: inout [HaloCIValidationIssue]) {
        for key in object.keys where !allowed.contains(key) { issues.append(.init(.error, path + "." + key, "Unknown SDK 0.1 field.")) }
    }

    private static func validateSurfaceRaw(_ object: [String: Any], manifest: HaloCIManifest,
                                           issues: inout [HaloCIValidationIssue]) {
        rejectUnknownKeys(in: object, allowed: surfaceKeys, path: "manifest.json.surface", issues: &issues)
        guard let sizing = object["sizing"] as? [String: Any] else {
            issues.append(.init(.error, "manifest.json.surface.sizing", "sizing is required.")); return
        }
        rejectUnknownKeys(in: sizing, allowed: sizingKeys, path: "manifest.json.surface.sizing", issues: &issues)
        let mode = sizing["mode"] as? String ?? ""
        guard ["static", "dynamic"].contains(mode) else {
            issues.append(.init(.error, "manifest.json.surface.sizing.mode", "Sizing mode must be static or dynamic.")); return
        }

        func validateRule(_ raw: Any?, state: String, required: Bool) {
            let path = "manifest.json.surface.sizing.\(state)"
            guard let rule = raw as? [String: Any] else {
                if required { issues.append(.init(.error, path, "A \(state) size contract is required.")) }
                return
            }
            rejectUnknownKeys(in: rule, allowed: sizeRuleKeys, path: path, issues: &issues)
            let closed = state == "closed"
            let widthRange: ClosedRange<Double> = closed ? 48...720 : 160...1100
            let heightRange: ClosedRange<Double> = closed ? 16...160 : 96...820
            func checked(_ key: String, range: ClosedRange<Double>) -> Double? {
                guard let value = number(rule[key]), value.isFinite, range.contains(value) else {
                    issues.append(.init(.error, path + "." + key, "Missing or outside the supported \(state) size range.")); return nil
                }
                return value
            }
            if mode == "static" {
                _ = checked("width", range: widthRange); _ = checked("height", range: heightRange)
                for key in ["minWidth", "preferredWidth", "maxWidth", "minHeight", "preferredHeight", "maxHeight"] where rule[key] != nil {
                    issues.append(.init(.error, path + "." + key, "Dynamic bounds are not allowed when sizing.mode is static."))
                }
            } else {
                if rule["width"] != nil || rule["height"] != nil {
                    issues.append(.init(.error, path, "Dynamic sizing uses min/preferred/max bounds instead of width/height."))
                }
                let minW = checked("minWidth", range: widthRange), prefW = checked("preferredWidth", range: widthRange), maxW = checked("maxWidth", range: widthRange)
                let minH = checked("minHeight", range: heightRange), prefH = checked("preferredHeight", range: heightRange), maxH = checked("maxHeight", range: heightRange)
                if let minW, let prefW, let maxW, !(minW <= prefW && prefW <= maxW) { issues.append(.init(.error, path, "Width bounds must satisfy minWidth <= preferredWidth <= maxWidth.")) }
                if let minH, let prefH, let maxH, !(minH <= prefH && prefH <= maxH) { issues.append(.init(.error, path, "Height bounds must satisfy minHeight <= preferredHeight <= maxHeight.")) }
            }
        }
        let states = Set(manifest.supportedStates)
        validateRule(sizing["expanded"], state: "expanded", required: true)
        validateRule(sizing["closed"], state: "closed", required: states.contains("closed"))

        guard let background = object["background"] as? [String: Any] else {
            issues.append(.init(.error, "manifest.json.surface.background", "Every Custom CI must own its background.")); return
        }
        rejectUnknownKeys(in: background, allowed: backgroundKeys, path: "manifest.json.surface.background", issues: &issues)
        func validateBackground(_ raw: Any?, state: String, required: Bool) {
            let path = "manifest.json.surface.background.\(state)"
            guard let style = raw as? [String: Any] else {
                if required { issues.append(.init(.error, path, "A \(state) background is required.")) }
                return
            }
            rejectUnknownKeys(in: style, allowed: backgroundStyleKeys, path: path, issues: &issues)
            guard let type = style["type"] as? String, ["solid", "gradient", "glass", "clear"].contains(type) else {
                issues.append(.init(.error, path + ".type", "Background type must be solid, gradient, glass, or clear.")); return
            }
            if let opacity = number(style["opacity"]), !(0...1).contains(opacity) { issues.append(.init(.error, path + ".opacity", "Opacity must be 0...1.")) }
            if let blur = number(style["blur"]), !(0...40).contains(blur) { issues.append(.init(.error, path + ".blur", "Blur must be 0...40.")) }
            func validColor(_ key: String, required: Bool) {
                guard let raw = style[key] as? String else { if required { issues.append(.init(.error, path + "." + key, "A color is required.")) }; return }
                let named = ["accent", "white", "black", "clear", "secondary", "green", "orange", "red", "blue"].contains(raw.lowercased())
                let hex = matches(raw, #"^#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$"#)
                if !named && !hex { issues.append(.init(.error, path + "." + key, "Use a supported named color or #RRGGBB/#RRGGBBAA.")) }
            }
            validColor("color", required: type == "solid" || type == "gradient" || type == "glass")
            validColor("secondaryColor", required: type == "gradient")
        }
        validateBackground(background["expanded"], state: "expanded", required: true)
        validateBackground(background["closed"], state: "closed", required: states.contains("closed"))
    }

    private static func validateManifest(_ manifest: HaloCIManifest, issues: inout [HaloCIValidationIssue]) {
        if manifest.schemaVersion != HaloCISDK.schemaVersion { issues.append(.init(.error, "manifest.json.schemaVersion", "Unsupported schema version \(manifest.schemaVersion). Halo supports schema 1.")) }
        if !HaloCISDK.supportedSDKVersions.contains(manifest.sdkVersion) { issues.append(.init(.error, "manifest.json.sdkVersion", "Unsupported SDK version \(manifest.sdkVersion). Halo supports 0.1 and 0.2.")) }
        if !matches(manifest.id, #"^[A-Za-z0-9]+(?:[.-][A-Za-z0-9_-]+)+$"#) || manifest.id.count > 160 { issues.append(.init(.error, "manifest.json.id", "Use a stable reverse-DNS style identifier, maximum 160 characters.")) }
        for (value, path) in [(manifest.name, "name"), (manifest.author, "author")] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.count > 120 {
            issues.append(.init(.error, "manifest.json." + path, "Must contain 1–120 characters."))
        }
        if manifest.description.count > 2_000 { issues.append(.init(.error, "manifest.json.description", "Description is limited to 2,000 characters.")) }
        if !matches(manifest.version, #"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$"#) { issues.append(.init(.error, "manifest.json.version", "Version must use semantic versioning.")) }
        if !matches(manifest.minimumHaloVersion, #"^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$"#) { issues.append(.init(.error, "manifest.json.minimumHaloVersion", "minimumHaloVersion must use semantic versioning.")) }
        if manifest.supportedSurfaces.isEmpty || manifest.supportedSurfaces.contains(where: { $0 != "notch" }) { issues.append(.init(.error, "manifest.json.supportedSurfaces", "SDK 0.1 supports only the notch surface.")) }
        let states = Set(manifest.supportedStates)
        if states.isEmpty || !states.isSubset(of: ["closed", "expanded"]) || !states.contains("expanded") { issues.append(.init(.error, "manifest.json.supportedStates", "Use closed and/or expanded; expanded is required in SDK 0.1.")) }
        for permission in Set(manifest.permissions) where !HaloCISDK.supportedPermissions.contains(permission) { issues.append(.init(.error, "manifest.json.permissions", "Unsupported permission \(permission).")) }
        if manifest.permissions.contains("Audio.ReadState"), manifest.sdkVersion != "0.2" {
            issues.append(.init(.error, "manifest.json.permissions", "Audio.ReadState requires SDK 0.2."))
        }
        for capability in Set(manifest.capabilities) where !HaloCISDK.supportedCapabilities.contains(capability) { issues.append(.init(.error, "manifest.json.capabilities", "Unsupported capability \(capability).")) }
        if Set(manifest.permissions).count != manifest.permissions.count { issues.append(.init(.warning, "manifest.json.permissions", "Duplicate permissions were declared.")) }
    }

    private static func validateInterfaceRaw(_ object: [String: Any], packageRoot: URL, manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        guard let expanded = object["expanded"] as? [String: Any] else { issues.append(.init(.error, path + ".expanded", "expanded root component is required.")); return }
        var count = 0
        validateComponentRaw(expanded, packageRoot: packageRoot, manifest: manifest, path: path + ".expanded", depth: 1, count: &count, issues: &issues)
        if let closed = object["closed"] as? [String: Any] {
            validateComponentRaw(closed, packageRoot: packageRoot, manifest: manifest, path: path + ".closed", depth: 1, count: &count, issues: &issues)
        } else if Set(manifest.supportedStates).contains("closed") {
            issues.append(.init(.warning, path + ".closed", "Manifest declares closed support but no closed component exists; Halo will use a safe package-name fallback."))
        }
    }

    private static func validateComponentRaw(_ object: [String: Any], packageRoot: URL, manifest: HaloCIManifest,
                                             path: String, depth: Int, count: inout Int, issues: inout [HaloCIValidationIssue]) {
        count += 1
        if count > HaloCISDK.maximumComponentCount { issues.append(.init(.error, path, "Component count exceeds \(HaloCISDK.maximumComponentCount).")); return }
        if depth > HaloCISDK.maximumTreeDepth { issues.append(.init(.error, path, "Component tree exceeds depth \(HaloCISDK.maximumTreeDepth).")); return }
        rejectUnknownKeys(in: object, allowed: componentKeys, path: path, issues: &issues)
        guard let type = object["type"] as? String, HaloCISDK.supportedComponents.contains(type) else { issues.append(.init(.error, path + ".type", "Unsupported component type.")); return }
        for (key, value) in object {
            if let string = value as? String, string.count > HaloCISDK.maximumStringLength { issues.append(.init(.error, path + "." + key, "String exceeds \(HaloCISDK.maximumStringLength) characters.")) }
            if let string = value as? String { validateBindings(in: string, manifest: manifest, path: path + "." + key, issues: &issues) }
        }
        if let source = object["source"] as? String, source.hasPrefix("asset:") {
            let relative = String(source.dropFirst("asset:".count))
            if !safeRelativePath(relative) { issues.append(.init(.error, path + ".source", "Asset path must remain inside the package.")) }
            else {
                let url = packageRoot.appendingPathComponent(relative).standardizedFileURL
                if !url.path.hasPrefix(packageRoot.standardizedFileURL.path + "/") { issues.append(.init(.error, path + ".source", "Asset path escapes the package root.")) }
                else if !imageExtensions.contains(url.pathExtension.lowercased()) { issues.append(.init(.error, path + ".source", "SDK 0.1 Image assets must use a supported image format.")) }
                else if !FileManager.default.fileExists(atPath: url.path) { issues.append(.init(.error, path + ".source", "Referenced asset does not exist.")) }
            }
        } else if type == "Image", object["source"] != nil {
            issues.append(.init(.error, path + ".source", "Image source must use asset:<relative-path>. Network image loading is not exposed in SDK 0.1."))
        }
        if type == "MediaArtwork" { requirePermission("Media.ReadState", manifest: manifest, path: path, issues: &issues) }
        if type == "AppIcon" { requirePermission("Applications.Observe", manifest: manifest, path: path, issues: &issues) }
        if type == "SystemMetric", let metric = object["metric"] as? String,
           !["battery", "cpu", "memory", "storage", "networkDown", "networkUp", "thermal"].contains(metric) {
            issues.append(.init(.error, path + ".metric", "Unsupported system metric."))
        }
        if ["Button", "Toggle", "Slider"].contains(type), (object["accessibilityLabel"] as? String)?.isEmpty != false {
            issues.append(.init(.warning, path + ".accessibilityLabel", "Interactive components should declare accessibilityLabel."))
        }
        if type == "Toggle", (object["stateKey"] as? String)?.isEmpty != false { issues.append(.init(.error, path + ".stateKey", "Toggle requires an isolated stateKey.")) }
        if type == "Slider" {
            if (object["stateKey"] as? String)?.isEmpty != false { issues.append(.init(.error, path + ".stateKey", "Slider requires an isolated stateKey.")) }
            if let min = number(object["minimum"]), let max = number(object["maximum"]), min >= max { issues.append(.init(.error, path, "Slider minimum must be below maximum.")) }
        }
        if let action = object["action"] as? [String: Any] { validateActionRaw(action, manifest: manifest, path: path + ".action", issues: &issues) }
        if let children = object["children"] as? [[String: Any]] {
            for (index, child) in children.enumerated() { validateComponentRaw(child, packageRoot: packageRoot, manifest: manifest, path: "\(path).children[\(index)]", depth: depth + 1, count: &count, issues: &issues) }
        }
        validateNumericBounds(object, path: path, issues: &issues)
    }

    private static func validateActionRaw(_ object: [String: Any], manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        rejectUnknownKeys(in: object, allowed: actionKeys, path: path, issues: &issues)
        guard let id = object["id"] as? String, HaloCISDK.supportedActions.contains(id) else { issues.append(.init(.error, path + ".id", "Unsupported action.")); return }
        if let permission = HaloCISDK.permissionForAction(id) { requirePermission(permission, manifest: manifest, path: path, issues: &issues) }
        if let value = object["value"] as? String { validateBindings(in: value, manifest: manifest, path: path + ".value", issues: &issues) }
        if let args = object["arguments"] as? [String: Any] {
            for (key, value) in args {
                guard let string = value as? String else { issues.append(.init(.error, path + ".arguments." + key, "Action arguments must be strings or bindings.")); continue }
                validateBindings(in: string, manifest: manifest, path: path + ".arguments." + key, issues: &issues)
            }
        }
    }

    private static func validateTriggersRaw(_ object: [String: Any], manifest: HaloCIManifest, issues: inout [HaloCIValidationIssue]) {
        let match = object["match"] as? String ?? "any"
        if !["any", "all"].contains(match) { issues.append(.init(.error, "triggers.json.match", "match must be any or all.")) }
        guard let triggers = object["triggers"] as? [[String: Any]] else { issues.append(.init(.error, "triggers.json.triggers", "triggers must be an array.")); return }
        if triggers.count > 32 { issues.append(.init(.error, "triggers.json.triggers", "A CI may define at most 32 triggers.")) }
        for (index, trigger) in triggers.enumerated() {
            let path = "triggers.json.triggers[\(index)]"
            rejectUnknownKeys(in: trigger, allowed: triggerKeys, path: path, issues: &issues)
            guard let type = trigger["type"] as? String, HaloCISDK.supportedTriggers.contains(type) else { issues.append(.init(.error, path + ".type", "Unsupported trigger.")); continue }
            if let permission = HaloCISDK.permissionForTrigger(type) { requirePermission(permission, manifest: manifest, path: path, issues: &issues) }
            if ["lowPowerMode", "displayCount"].contains(type), manifest.sdkVersion != "0.2" {
                issues.append(.init(.error, path + ".type", "This trigger requires SDK 0.2."))
            }
            switch type {
            case "displayCount":
                if let count = integer(trigger["number"]), (1...64).contains(count) {} else {
                    issues.append(.init(.error, path + ".number", "displayCount requires an integer in 1...64."))
                }
            case "activeApplication": if (trigger["value"] as? String)?.isEmpty != false { issues.append(.init(.error, path + ".value", "activeApplication requires a bundle identifier.")) }
            case "batteryBelow", "batteryAbove": if number(trigger["number"]) == nil { issues.append(.init(.error, path + ".number", "Battery trigger requires a numeric threshold.")) }
            case "timeWindow":
                guard let start = integer(trigger["startMinute"]), let end = integer(trigger["endMinute"]), (0...1439).contains(start), (0...1439).contains(end) else { issues.append(.init(.error, path, "timeWindow requires startMinute/endMinute in 0...1439.")); continue }
            default: break
            }
        }
    }

    private static func validateBindings(in value: String, manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        let keys = HaloCIBindingResolver.keys(in: value)
        if !HaloCIBindingResolver.isWellFormed(value) { issues.append(.init(.error, path, "Malformed binding. SDK 0.1 accepts only {{ namespace.key }} bindings.")); return }
        for key in keys {
            guard HaloCIContextCatalog.fields.contains(where: { $0.key == key && ($0.since == "0.1" || manifest.sdkVersion == "0.2") }) else { issues.append(.init(.error, path, "Unsupported binding key \(key).")); continue }
            if let permission = HaloCISDK.permissionForDataKey(key) { requirePermission(permission, manifest: manifest, path: path, issues: &issues) }
        }
    }

    private static func requirePermission(_ permission: String, manifest: HaloCIManifest, path: String, issues: inout [HaloCIValidationIssue]) {
        let declared = Set(manifest.permissions)
        if !declared.contains(permission) { issues.append(.init(.error, path, "Requires \(permission), but the manifest does not declare it.")) }
    }

    private static func validateNumericBounds(_ object: [String: Any], path: String, issues: inout [HaloCIValidationIssue]) {
        let bounds: [String: ClosedRange<Double>] = [
            "spacing": 0...80, "padding": 0...120, "width": 0...1600, "height": 0...1400,
            "cornerRadius": 0...160, "minimum": -100000...100000, "maximum": -100000...100000,
            "step": 0.000001...100000
        ]
        for (key, range) in bounds where object[key] != nil {
            guard let value = number(object[key]), value.isFinite, range.contains(value) else { issues.append(.init(.error, path + "." + key, "Value is outside the supported SDK 0.1 range.")); continue }
        }
        if let line = integer(object["lineLimit"]), !(1...20).contains(line) { issues.append(.init(.error, path + ".lineLimit", "lineLimit must be 1...20.")) }
        if let columns = integer(object["columns"]), !(1...8).contains(columns) { issues.append(.init(.error, path + ".columns", "columns must be 1...8.")) }
    }

    private static func safeRelativePath(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.hasPrefix("~") else { return false }
        let parts = value.replacingOccurrences(of: "\\", with: "/").split(separator: "/", omittingEmptySubsequences: false)
        return !parts.contains("..") && !parts.contains("")
    }
    private static func matches(_ value: String, _ pattern: String) -> Bool { value.range(of: pattern, options: .regularExpression) != nil }
    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            return number.doubleValue
        }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }
    private static func integer(_ value: Any?) -> Int? {
        guard let value = number(value), value.isFinite, value.rounded() == value,
              value >= Double(Int.min), value < Double(Int.max) else { return nil }
        return Int(value)
    }
}

// MARK: - Custom CI V2 context contract

/// The catalog is shared by validation, the runtime broker and authoring tools.
/// Additive context requires a descriptor, a real provider, documentation and tests.
struct HaloCIContextField: Codable, Equatable {
    let key: String
    let type: String
    let unit: String?
    let permission: String?
    let since: String
    let description: String
}

enum HaloCIContextCatalog {
    static let fields: [HaloCIContextField] = [
        field("halo.surface.state", "string", "Current surface: closed or expanded."),
        field("halo.surface.isExpanded", "boolean", "Whether this surface is expanded."),
        field("system.battery.level", "number", "Battery level; absent when unavailable.", unit: "percent"),
        field("system.battery.isCharging", "boolean", "System charging state."),
        field("system.lowPowerMode", "boolean", "macOS Low Power Mode."),
        field("system.cpu.usedPercent", "number", "Latest sampled CPU usage.", unit: "percent"),
        field("system.memory.usedPercent", "number", "Latest sampled memory usage.", unit: "percent"),
        field("system.storage.usedPercent", "number", "Latest sampled storage usage.", unit: "percent"),
        field("media.isPlaying", "boolean", "Playback state.", permission: "Media.ReadState"),
        field("media.title", "string", "Current media title.", permission: "Media.ReadState"),
        field("media.artist", "string", "Current media artist.", permission: "Media.ReadState"),
        field("media.album", "string", "Current media album.", permission: "Media.ReadState"),
        field("apps.active.bundleID", "string", "Frontmost app bundle identifier.", permission: "Applications.Observe"),
        field("apps.active.name", "string", "Frontmost app name.", permission: "Applications.Observe"),
        field("media.duration", "number", "Current media duration.", unit: "seconds", permission: "Media.ReadState", since: "0.2"),
        field("media.position", "number", "Latest sampled playback position.", unit: "seconds", permission: "Media.ReadState", since: "0.2"),
        field("audio.output.name", "string", "Selected output device; absent when unavailable.", permission: "Audio.ReadState", since: "0.2"),
        field("audio.volume", "number", "Output volume when device supports volume control.", unit: "fraction", permission: "Audio.ReadState", since: "0.2"),
        field("audio.canSetVolume", "boolean", "Whether the selected output supports volume control.", permission: "Audio.ReadState", since: "0.2"),
        field("system.thermalState", "string", "Latest macOS thermal state.", since: "0.2"),
        field("system.network.downBytesPerSecond", "number", "System aggregate received traffic rate, not connectivity.", unit: "bytes/second", since: "0.2"),
        field("system.network.upBytesPerSecond", "number", "System aggregate sent traffic rate, not connectivity.", unit: "bytes/second", since: "0.2"),
        field("displays.count", "number", "Number of connected screens.", unit: "count", since: "0.2"),
        field("time.minuteOfDay", "number", "Local minute of day, 0 through 1439.", unit: "minutes", since: "0.2"),
        field("ci.id", "string", "This package's stable identifier.", since: "0.2"),
        field("ci.name", "string", "This package's display name.", since: "0.2"),
        field("ci.activation.kind", "string", "Eligibility source: manual or automatic; not an ownership guarantee.", since: "0.2")
    ]

    private static func field(_ key: String, _ type: String, _ description: String,
                              unit: String? = nil, permission: String? = nil,
                              since: String = "0.1") -> HaloCIContextField {
        .init(key: key, type: type, unit: unit, permission: permission, since: since, description: description)
    }

    /// Unknown keys, wrong types, unavailable data and revoked/undeclared permissions
    /// never reach the renderer or action interpolation. No fabricated zero defaults.
    static func filter(_ values: [String: String], sdkVersion: String,
                       declaredPermissions: Set<String>, grantedPermissions: Set<String>) -> [String: String] {
        guard HaloCISDK.supportedSDKVersions.contains(sdkVersion) else { return [:] }
        var result: [String: String] = [:]
        for field in fields where field.since == "0.1" || sdkVersion == "0.2" {
            if let permission = field.permission,
               !declaredPermissions.contains(permission) || !grantedPermissions.contains(permission) { continue }
            guard let value = values[field.key] else { continue }
            if field.type == "number", Double(value)?.isFinite != true { continue }
            if field.type == "boolean", !["true", "false"].contains(value) { continue }
            result[field.key] = String(value.prefix(HaloCISDK.maximumStringLength))
        }
        return result
    }
}

/// Rechecked at the action boundary, independently of whether an old view is mounted.
enum HaloCIActionAuthorization {
    static func allows(_ action: String, enabled: Bool, globallyDisabled: Bool,
                       declaredPermissions: Set<String>, grantedPermissions: Set<String>) -> Bool {
        guard enabled, !globallyDisabled, HaloCISDK.supportedActions.contains(action) else { return false }
        guard let permission = HaloCISDK.permissionForAction(action) else { return true }
        return declaredPermissions.contains(permission) && grantedPermissions.contains(permission)
    }
}
