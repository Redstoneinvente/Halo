import Foundation

enum CISourceKind: String, Codable, Hashable, Sendable {
    case builtIn
    case customPackage
    case appIntegration
}

enum CISourcePayload: Codable, Hashable, Sendable {
    case builtIn(identifier: String)
    case customPackage(packageID: String)
    case appIntegration(bundleIdentifier: String, protocolVersion: Int)

    private enum CodingKeys: String, CodingKey { case kind, identifier, packageID, bundleIdentifier, protocolVersion }
    private enum Kind: String, Codable { case builtIn, customPackage, appIntegration }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .builtIn:
            self = .builtIn(identifier: try c.decode(String.self, forKey: .identifier))
        case .customPackage:
            self = .customPackage(packageID: try c.decode(String.self, forKey: .packageID))
        case .appIntegration:
            self = .appIntegration(
                bundleIdentifier: try c.decode(String.self, forKey: .bundleIdentifier),
                protocolVersion: try c.decode(Int.self, forKey: .protocolVersion)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .builtIn(let identifier):
            try c.encode(Kind.builtIn, forKey: .kind)
            try c.encode(identifier, forKey: .identifier)
        case .customPackage(let packageID):
            try c.encode(Kind.customPackage, forKey: .kind)
            try c.encode(packageID, forKey: .packageID)
        case .appIntegration(let bundleIdentifier, let protocolVersion):
            try c.encode(Kind.appIntegration, forKey: .kind)
            try c.encode(bundleIdentifier, forKey: .bundleIdentifier)
            try c.encode(protocolVersion, forKey: .protocolVersion)
        }
    }

    var kind: CISourceKind {
        switch self {
        case .builtIn: return .builtIn
        case .customPackage: return .customPackage
        case .appIntegration: return .appIntegration
        }
    }
}

enum CIValue: Hashable, Sendable, Codable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case stringArray([String])
    case integerArray([Int])
    case doubleArray([Double])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let value = try? c.decode(Bool.self) { self = .boolean(value); return }
        if let value = try? c.decode(Int.self) { self = .integer(value); return }
        if let value = try? c.decode(Double.self) { self = .double(value); return }
        if let value = try? c.decode(String.self) { self = .string(value); return }
        if let value = try? c.decode([Int].self) { self = .integerArray(value); return }
        if let value = try? c.decode([Double].self) { self = .doubleArray(value); return }
        if let value = try? c.decode([String].self) { self = .stringArray(value); return }
        throw DecodingError.typeMismatch(
            CIValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported CI value type")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let value): try c.encode(value)
        case .integer(let value): try c.encode(value)
        case .double(let value): try c.encode(value)
        case .boolean(let value): try c.encode(value)
        case .stringArray(let value): try c.encode(value)
        case .integerArray(let value): try c.encode(value)
        case .doubleArray(let value): try c.encode(value)
        }
    }

    var typeName: String {
        switch self {
        case .string: return "string"
        case .integer: return "integer"
        case .double: return "double"
        case .boolean: return "boolean"
        case .stringArray: return "stringArray"
        case .integerArray: return "integerArray"
        case .doubleArray: return "doubleArray"
        }
    }
}

enum CIActionInputKind: String, Codable, Hashable, Sendable {
    case none
    case files
}

struct CIActionInputDefinition: Codable, Hashable, Sendable {
    var type: CIActionInputKind
    var extensions: [String]
    var multiple: Bool

    static let none = CIActionInputDefinition(type: .none, extensions: [], multiple: false)
}

struct CIActionOptionDefinition: Codable, Hashable, Identifiable, Sendable {
    var key: String
    var name: String
    var type: String
    var required: Bool
    var defaultValue: CIValue?
    var description: String?

    var id: String { key }
}

struct CIActionDefinition: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var input: CIActionInputDefinition
    var options: [CIActionOptionDefinition]
    var requiredPermissions: Set<String>
}

enum CITriggerKind: String, Codable, Hashable, Sendable {
    case manual
    case fileDrag
    case keyboardShortcut
    case partnerEvent
    case mediaPlaying
    case activeApplication
    case batteryBelow
    case batteryAbove
    case charging
    case timeWindow
}

struct CITriggerDefinition: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var type: CITriggerKind
    var actionIDs: [String]
    var eventName: String?
    var requiredPermissions: Set<String>
}

struct CIMetadata: Codable, Hashable, Sendable {
    var name: String
    var author: String
    var version: String
    var description: String
}

struct CIPresentationDescriptor: Codable, Hashable, Sendable {
    var preferredExpandedWidth: Double
    var preferredExpandedHeight: Double
    var preferredCompactWidth: Double?
    var preferredCompactHeight: Double?
    var usesFullSurface: Bool
    var keepsClosedContents: Bool

    static let integrationDefault = CIPresentationDescriptor(
        preferredExpandedWidth: 560,
        preferredExpandedHeight: 300,
        preferredCompactWidth: nil,
        preferredCompactHeight: nil,
        usesFullSurface: false,
        keepsClosedContents: false
    )
}

/// Immutable runtime representation consumed by Halo's CI arbiter and renderer.
/// User choices never live here; they belong to CIConfigurationStore.
struct CIRegistration: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var source: CISourcePayload
    var metadata: CIMetadata
    var supportedTriggers: [CITriggerDefinition]
    var supportedActions: [CIActionDefinition]
    var requiredPermissions: Set<String>
    var presentation: CIPresentationDescriptor
}

struct CIArbitrationCandidate: Hashable, Sendable {
    enum Owner: Hashable, Sendable {
        case builtIn(String)
        case custom(String)
        case integration(String)
    }

    var owner: Owner
    var ciID: String
    var priority: Double
    var tieRank: Int
}

enum CIArbitrationEngine {
    static func winner(in candidates: [CIArbitrationCandidate]) -> CIArbitrationCandidate? {
        candidates.max { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            if lhs.tieRank != rhs.tieRank { return lhs.tieRank < rhs.tieRank }
            return lhs.ciID > rhs.ciID
        }
    }
}

enum IntegrationCIFactory {
    static func makeRegistration(from definition: IntegrationDefinition) -> CIRegistration {
        let ciID = "integration.\(definition.app.bundleIdentifier)"
        var triggers = definition.triggers
        if !triggers.contains(where: { $0.type == .manual }) {
            triggers.insert(
                CITriggerDefinition(
                    id: "manual",
                    type: .manual,
                    actionIDs: definition.actions.map(\.id),
                    eventName: nil,
                    requiredPermissions: []
                ),
                at: 0
            )
        }
        return CIRegistration(
            id: ciID,
            source: .appIntegration(
                bundleIdentifier: definition.app.bundleIdentifier,
                protocolVersion: definition.protocolVersion
            ),
            metadata: CIMetadata(
                name: definition.app.name,
                author: definition.app.bundleIdentifier,
                version: "Protocol v\(definition.protocolVersion)",
                description: "Actions provided by \(definition.app.name)."
            ),
            supportedTriggers: triggers,
            supportedActions: definition.actions,
            requiredPermissions: Set(definition.actions.flatMap(\.requiredPermissions)),
            presentation: .integrationDefault
        )
    }
}

enum CustomCIFactory {
    static func makeRegistration(from package: HaloCIParsedPackage) -> CIRegistration {
        let actions = collectActions(from: [package.interface.closed, package.interface.expanded].compactMap { $0 })
        let triggers = package.triggers.triggers.enumerated().compactMap { index, trigger -> CITriggerDefinition? in
            guard let kind = CITriggerKind(rawValue: trigger.type) else { return nil }
            let permission = HaloCISDK.permissionForTrigger(trigger.type).map { Set([$0]) } ?? []
            return CITriggerDefinition(
                id: "custom.\(index).\(trigger.type)",
                type: kind,
                actionIDs: actions.map(\.id),
                eventName: nil,
                requiredPermissions: permission
            )
        }
        let expanded = package.manifest.surface.sizing.expanded
        let closed = package.manifest.surface.sizing.closed
        return CIRegistration(
            id: package.manifest.id,
            source: .customPackage(packageID: package.manifest.id),
            metadata: CIMetadata(
                name: package.manifest.name,
                author: package.manifest.author,
                version: package.manifest.version,
                description: package.manifest.description
            ),
            supportedTriggers: triggers,
            supportedActions: actions,
            requiredPermissions: Set(package.manifest.permissions),
            presentation: CIPresentationDescriptor(
                preferredExpandedWidth: expanded.width ?? expanded.preferredWidth ?? 560,
                preferredExpandedHeight: expanded.height ?? expanded.preferredHeight ?? 260,
                preferredCompactWidth: closed?.width ?? closed?.preferredWidth,
                preferredCompactHeight: closed?.height ?? closed?.preferredHeight,
                usesFullSurface: true,
                keepsClosedContents: false
            )
        )
    }

    private static func collectActions(from roots: [HaloCIComponent]) -> [CIActionDefinition] {
        var seen = Set<String>()
        var result: [CIActionDefinition] = []
        func visit(_ component: HaloCIComponent) {
            if let action = component.action, seen.insert(action.id).inserted {
                let permission = HaloCISDK.permissionForAction(action.id).map { Set([$0]) } ?? []
                result.append(
                    CIActionDefinition(
                        id: action.id,
                        name: action.id,
                        input: .none,
                        options: [],
                        requiredPermissions: permission
                    )
                )
            }
            component.children?.forEach(visit)
        }
        roots.forEach(visit)
        return result.sorted { $0.id < $1.id }
    }
}
