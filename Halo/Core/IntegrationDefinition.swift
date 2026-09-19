import Foundation

struct IntegrationAppIdentity: Codable, Hashable, Sendable {
    var name: String
    var bundleIdentifier: String
}

struct IntegrationDeliveryDefinition: Codable, Hashable, Sendable {
    var type: String
}

struct IntegrationCardPresentationDefinition: Codable, Hashable, Sendable {
    var bannerImage: String?
    var category: String?
    var description: String?
    var accentColor: String?
}

struct IntegrationPresentationDefinition: Codable, Hashable, Sendable {
    var card: IntegrationCardPresentationDefinition?
}

/// Immutable, normalized representation of a partner manifest.
/// Protocol-specific fields are erased here so the runtime never branches on v1/v2 semantics.
struct IntegrationDefinition: Codable, Hashable, Identifiable, Sendable {
    var protocolVersion: Int
    var app: IntegrationAppIdentity
    var presentation: IntegrationPresentationDefinition? = nil
    var dismissBehavior: CIDismissBehavior? = nil
    var actions: [CIActionDefinition]
    var triggers: [CITriggerDefinition]
    var delivery: IntegrationDeliveryDefinition

    var id: String { app.bundleIdentifier }
}

enum IntegrationManifestError: LocalizedError, Equatable {
    case manifestTooLarge(Int)
    case malformed(String)
    case unsupportedProtocol(Int)
    case missingAppName
    case missingBundleIdentifier
    case bundleIdentifierMismatch(manifest: String, actual: String)
    case missingActions
    case tooManyActions(Int)
    case duplicateActionID(String)
    case invalidActionID(String)
    case invalidInput(String)
    case invalidExtension(String)
    case tooManyOptions(actionID: String, count: Int)
    case duplicateOptionKey(actionID: String, key: String)
    case unsupportedOptionType(actionID: String, type: String)
    case invalidDefault(actionID: String, key: String)
    case tooManyTriggers(Int)
    case duplicateTriggerID(String)
    case unsupportedTriggerType(String)
    case unknownActionReference(triggerID: String, actionID: String)
    case incompatibleTriggerAction(triggerID: String, actionID: String)
    case invalidEventName(String)
    case invalidPresentation(String)
    case unsupportedDelivery(String)

    var errorDescription: String? {
        switch self {
        case .manifestTooLarge(let bytes): return "HaloIntegration.json is too large (\(bytes) bytes)."
        case .malformed(let detail): return "HaloIntegration.json is malformed: \(detail)"
        case .unsupportedProtocol(let value): return "unsupported Halo integration protocol v\(value)."
        case .missingAppName: return "manifest is missing its app name."
        case .missingBundleIdentifier: return "manifest is missing its bundle identifier."
        case .bundleIdentifierMismatch(let manifest, let actual): return "manifest bundle identifier \(manifest) does not match \(actual)."
        case .missingActions: return "manifest must expose at least one action."
        case .tooManyActions(let count): return "manifest exposes \(count) actions; maximum is 64."
        case .duplicateActionID(let id): return "action ID \(id) is declared more than once."
        case .invalidActionID(let id): return "action ID \(id) is invalid."
        case .invalidInput(let id): return "action \(id) has an invalid input declaration."
        case .invalidExtension(let ext): return "invalid file extension \(ext)."
        case .tooManyOptions(let id, let count): return "action \(id) exposes \(count) options; maximum is 32."
        case .duplicateOptionKey(let id, let key): return "action \(id) declares option key \(key) more than once."
        case .unsupportedOptionType(let id, let type): return "action \(id) declares unsupported option type \(type)."
        case .invalidDefault(let id, let key): return "action \(id) option \(key) has a default value with the wrong type."
        case .tooManyTriggers(let count): return "manifest exposes \(count) triggers; maximum is 32."
        case .duplicateTriggerID(let id): return "trigger ID \(id) is declared more than once."
        case .unsupportedTriggerType(let type): return "unsupported integration trigger type \(type)."
        case .unknownActionReference(let trigger, let action): return "trigger \(trigger) references unknown action \(action)."
        case .incompatibleTriggerAction(let trigger, let action): return "trigger \(trigger) cannot supply the input required by action \(action)."
        case .invalidEventName(let name): return "partner event name \(name) is invalid."
        case .invalidPresentation(let detail): return "integration presentation is invalid: \(detail)"
        case .unsupportedDelivery(let value): return "unsupported integration delivery type \(value)."
        }
    }
}

enum IntegrationManifestCodec {
    static let maximumManifestBytes = 256_000
    static let supportedProtocolVersions: Set<Int> = [1, 2]
    static let supportedOptionTypes: Set<String> = [
        "string", "integer", "double", "boolean", "stringArray", "integerArray", "doubleArray"
    ]

    private struct Probe: Decodable { var protocolVersion: Int }

    private struct V1Option: Decodable {
        var key: String
        var name: String
        var type: String
        var required: Bool
        var description: String?
    }
    private struct V1Action: Decodable {
        var id: String
        var name: String
        var supportedExtensions: [String]
        var options: [V1Option]
    }
    private struct V1Trigger: Decodable {
        var type: String
        var supportedExtensions: [String]?
    }
    private struct V1Manifest: Decodable {
        var protocolVersion: Int
        var name: String
        var bundleIdentifier: String
        var actions: [V1Action]
        var triggers: [V1Trigger]?
    }

    private struct V2Manifest: Decodable {
        struct App: Decodable { var name: String; var bundleIdentifier: String }
        struct Input: Decodable { var type: String; var extensions: [String]?; var multiple: Bool? }
        struct Option: Decodable {
            var key: String
            var name: String
            var type: String
            var required: Bool?
            var `default`: CIValue?
            var description: String?
        }
        struct Action: Decodable {
            var id: String
            var name: String
            var input: Input?
            var options: [Option]?
        }
        struct Trigger: Decodable {
            var id: String
            var type: String
            var actions: [String]?
            var eventName: String?
        }
        struct Delivery: Decodable { var type: String }
        struct Presentation: Decodable {
            struct Card: Decodable {
                var bannerImage: String?
                var category: String?
                var description: String?
                var accentColor: String?
            }
            var card: Card?
        }

        var protocolVersion: Int
        var app: App
        var presentation: Presentation?
        var dismissBehavior: String?
        var actions: [Action]
        var triggers: [Trigger]?
        var delivery: Delivery?
    }

    static func decodeAndNormalize(_ data: Data, actualBundleIdentifier: String? = nil) throws -> IntegrationDefinition {
        guard data.count <= maximumManifestBytes else { throw IntegrationManifestError.manifestTooLarge(data.count) }
        let decoder = JSONDecoder()
        let probe: Probe
        do { probe = try decoder.decode(Probe.self, from: data) }
        catch { throw IntegrationManifestError.malformed(error.localizedDescription) }
        guard supportedProtocolVersions.contains(probe.protocolVersion) else {
            throw IntegrationManifestError.unsupportedProtocol(probe.protocolVersion)
        }
        do {
            let definition: IntegrationDefinition
            switch probe.protocolVersion {
            case 1: definition = try normalizeV1(decoder.decode(V1Manifest.self, from: data))
            case 2: definition = try normalizeV2(decoder.decode(V2Manifest.self, from: data))
            default: throw IntegrationManifestError.unsupportedProtocol(probe.protocolVersion)
            }
            try validate(definition, actualBundleIdentifier: actualBundleIdentifier)
            return definition
        } catch let error as IntegrationManifestError {
            throw error
        } catch {
            throw IntegrationManifestError.malformed(error.localizedDescription)
        }
    }

    static func validate(_ definition: IntegrationDefinition, actualBundleIdentifier: String? = nil) throws {
        let name = definition.app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleID = definition.app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw IntegrationManifestError.missingAppName }
        guard !bundleID.isEmpty else { throw IntegrationManifestError.missingBundleIdentifier }
        if let actualBundleIdentifier, actualBundleIdentifier != bundleID {
            throw IntegrationManifestError.bundleIdentifierMismatch(manifest: bundleID, actual: actualBundleIdentifier)
        }
        guard !definition.actions.isEmpty else { throw IntegrationManifestError.missingActions }
        guard definition.actions.count <= 64 else { throw IntegrationManifestError.tooManyActions(definition.actions.count) }
        guard definition.triggers.count <= 32 else { throw IntegrationManifestError.tooManyTriggers(definition.triggers.count) }
        guard definition.delivery.type == "openRequest" else { throw IntegrationManifestError.unsupportedDelivery(definition.delivery.type) }
        try validate(presentation: definition.presentation)
        if let dismissBehavior = definition.dismissBehavior,
           !CIDismissBehavior.allCases.contains(dismissBehavior) {
            throw IntegrationManifestError.invalidPresentation("dismissBehavior is invalid.")
        }

        var actionIDs = Set<String>()
        for action in definition.actions {
            let id = action.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard validIdentifier(id) else { throw IntegrationManifestError.invalidActionID(action.id) }
            guard actionIDs.insert(id).inserted else { throw IntegrationManifestError.duplicateActionID(id) }
            guard !action.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw IntegrationManifestError.invalidActionID(id)
            }
            try validate(input: action.input, actionID: id)
            guard action.options.count <= 32 else { throw IntegrationManifestError.tooManyOptions(actionID: id, count: action.options.count) }
            var optionKeys = Set<String>()
            for option in action.options {
                guard validIdentifier(option.key) else { throw IntegrationManifestError.invalidActionID("\(id).\(option.key)") }
                guard optionKeys.insert(option.key).inserted else {
                    throw IntegrationManifestError.duplicateOptionKey(actionID: id, key: option.key)
                }
                guard supportedOptionTypes.contains(option.type) else {
                    throw IntegrationManifestError.unsupportedOptionType(actionID: id, type: option.type)
                }
                if let value = option.defaultValue, !valueMatches(type: option.type, value: value) {
                    throw IntegrationManifestError.invalidDefault(actionID: id, key: option.key)
                }
            }
        }

        let actionsByID = Dictionary(uniqueKeysWithValues: definition.actions.map { ($0.id, $0) })
        var triggerIDs = Set<String>()
        for trigger in definition.triggers {
            guard validIdentifier(trigger.id) else { throw IntegrationManifestError.duplicateTriggerID(trigger.id) }
            guard triggerIDs.insert(trigger.id).inserted else { throw IntegrationManifestError.duplicateTriggerID(trigger.id) }
            switch trigger.type {
            case .fileDrag, .keyboardShortcut, .partnerEvent, .manual:
                break
            default:
                throw IntegrationManifestError.unsupportedTriggerType(trigger.type.rawValue)
            }
            if trigger.type == .partnerEvent {
                guard let eventName = trigger.eventName, validIdentifier(eventName) else {
                    throw IntegrationManifestError.invalidEventName(trigger.eventName ?? "")
                }
            }
            for actionID in trigger.actionIDs {
                guard let action = actionsByID[actionID] else {
                    throw IntegrationManifestError.unknownActionReference(triggerID: trigger.id, actionID: actionID)
                }
                if trigger.type == .fileDrag, action.input.type != .files {
                    throw IntegrationManifestError.incompatibleTriggerAction(triggerID: trigger.id, actionID: actionID)
                }
            }
        }
    }

    static func optionValueIsValid(_ value: CIValue, for option: CIActionOptionDefinition) -> Bool {
        valueMatches(type: option.type, value: value)
    }

    private static func normalizeV1(_ manifest: V1Manifest) throws -> IntegrationDefinition {
        let actions = try manifest.actions.map { raw -> CIActionDefinition in
            let extensions = try normalizeExtensions(raw.supportedExtensions)
            let input: CIActionInputDefinition = extensions.isEmpty
                ? .none
                : CIActionInputDefinition(type: .files, extensions: extensions, multiple: true)
            return CIActionDefinition(
                id: raw.id,
                name: raw.name,
                input: input,
                options: raw.options.map {
                    CIActionOptionDefinition(
                        key: $0.key,
                        name: $0.name,
                        type: $0.type,
                        required: $0.required,
                        defaultValue: nil,
                        description: $0.description
                    )
                },
                requiredPermissions: input.type == .files ? ["Files.ReadSelected"] : []
            )
        }

        let fileActions = actions.filter { $0.input.type == .files }
        let triggers: [CITriggerDefinition] = try (manifest.triggers ?? []).enumerated().map { index, raw in
            guard raw.type == "fileDrag" else { throw IntegrationManifestError.unsupportedTriggerType(raw.type) }
            let triggerExtensions = try normalizeExtensions(raw.supportedExtensions ?? [])
            let actionIDs = fileActions.filter { action in
                guard !triggerExtensions.isEmpty else { return true }
                return extensionSetsOverlap(triggerExtensions, action.input.extensions)
            }.map(\.id)
            return CITriggerDefinition(
                id: "v1.fileDrag.\(index)",
                type: .fileDrag,
                actionIDs: actionIDs,
                eventName: nil,
                requiredPermissions: ["Files.ReadSelected"]
            )
        }

        return IntegrationDefinition(
            protocolVersion: 1,
            app: IntegrationAppIdentity(name: manifest.name, bundleIdentifier: manifest.bundleIdentifier),
            actions: actions,
            triggers: triggers,
            delivery: IntegrationDeliveryDefinition(type: "openRequest")
        )
    }

    private static func normalizeV2(_ manifest: V2Manifest) throws -> IntegrationDefinition {
        let actions = try manifest.actions.map { raw -> CIActionDefinition in
            let input: CIActionInputDefinition
            if let rawInput = raw.input {
                switch rawInput.type {
                case "none": input = .none
                case "files":
                    input = CIActionInputDefinition(
                        type: .files,
                        extensions: try normalizeExtensions(rawInput.extensions ?? []),
                        multiple: rawInput.multiple ?? true
                    )
                default: throw IntegrationManifestError.invalidInput(raw.id)
                }
            } else {
                input = .none
            }
            return CIActionDefinition(
                id: raw.id,
                name: raw.name,
                input: input,
                options: (raw.options ?? []).map {
                    CIActionOptionDefinition(
                        key: $0.key,
                        name: $0.name,
                        type: $0.type,
                        required: $0.required ?? false,
                        defaultValue: $0.default,
                        description: $0.description
                    )
                },
                requiredPermissions: input.type == .files ? ["Files.ReadSelected"] : []
            )
        }
        let triggers = try (manifest.triggers ?? []).map { raw -> CITriggerDefinition in
            guard let kind = CITriggerKind(rawValue: raw.type),
                  [.fileDrag, .keyboardShortcut, .partnerEvent, .manual].contains(kind) else {
                throw IntegrationManifestError.unsupportedTriggerType(raw.type)
            }
            let permissions: Set<String> = kind == .fileDrag ? ["Files.ReadSelected"] : []
            return CITriggerDefinition(
                id: raw.id,
                type: kind,
                actionIDs: raw.actions ?? actions.map(\.id),
                eventName: raw.eventName,
                requiredPermissions: permissions
            )
        }
        let presentation = manifest.presentation.map {
            IntegrationPresentationDefinition(
                card: $0.card.map {
                    IntegrationCardPresentationDefinition(
                        bannerImage: $0.bannerImage,
                        category: $0.category,
                        description: $0.description,
                        accentColor: $0.accentColor
                    )
                }
            )
        }
        let dismissBehavior: CIDismissBehavior?
        if let rawDismissBehavior = manifest.dismissBehavior {
            guard let parsed = CIDismissBehavior(rawValue: rawDismissBehavior) else {
                throw IntegrationManifestError.invalidPresentation("dismissBehavior must be transient, standard, interactive, or persistent.")
            }
            dismissBehavior = parsed
        } else {
            dismissBehavior = nil
        }
        return IntegrationDefinition(
            protocolVersion: 2,
            app: IntegrationAppIdentity(name: manifest.app.name, bundleIdentifier: manifest.app.bundleIdentifier),
            presentation: presentation,
            dismissBehavior: dismissBehavior,
            actions: actions,
            triggers: triggers,
            delivery: IntegrationDeliveryDefinition(type: manifest.delivery?.type ?? "openRequest")
        )
    }

    private static func validate(presentation: IntegrationPresentationDefinition?) throws {
        guard let card = presentation?.card else { return }

        if let category = card.category?.trimmingCharacters(in: .whitespacesAndNewlines),
           category.count > 40 {
            throw IntegrationManifestError.invalidPresentation("card category exceeds 40 characters.")
        }

        if let description = card.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           description.count > 160 {
            throw IntegrationManifestError.invalidPresentation("card description exceeds 160 characters.")
        }

        if let accentColor = card.accentColor?.trimmingCharacters(in: .whitespacesAndNewlines),
           !accentColor.isEmpty,
           accentColor.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) == nil {
            throw IntegrationManifestError.invalidPresentation("card accentColor must use #RRGGBB.")
        }

        if let bannerImage = card.bannerImage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bannerImage.isEmpty {
            guard bannerImage == URL(fileURLWithPath: bannerImage).lastPathComponent,
                  !bannerImage.contains("/"),
                  !bannerImage.contains("\\") else {
                throw IntegrationManifestError.invalidPresentation("card bannerImage must be a bundle-resource filename.")
            }
            let ext = URL(fileURLWithPath: bannerImage).pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "webp"].contains(ext) else {
                throw IntegrationManifestError.invalidPresentation("card bannerImage must be PNG, JPG, JPEG, or WebP.")
            }
        }
    }

    private static func validate(input: CIActionInputDefinition, actionID: String) throws {
        switch input.type {
        case .none:
            guard input.extensions.isEmpty else { throw IntegrationManifestError.invalidInput(actionID) }
        case .files:
            for ext in input.extensions { _ = try normalizeExtension(ext) }
        }
    }

    private static func normalizeExtensions(_ values: [String]) throws -> [String] {
        var result = Set<String>()
        for value in values { result.insert(try normalizeExtension(value)) }
        return result.sorted()
    }

    private static func normalizeExtension(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !value.isEmpty, value.count <= 32,
              value == "*" || value.range(of: #"^[a-z0-9][a-z0-9+_-]*$"#, options: .regularExpression) != nil else {
            throw IntegrationManifestError.invalidExtension(raw)
        }
        return value
    }

    private static func extensionSetsOverlap(_ lhs: [String], _ rhs: [String]) -> Bool {
        let l = Set(lhs), r = Set(rhs)
        return l.contains("*") || r.contains("*") || !l.isDisjoint(with: r)
    }

    private static func validIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 160 && value.range(of: #"^[A-Za-z0-9][A-Za-z0-9._:-]*$"#, options: .regularExpression) != nil
    }

    private static func valueMatches(type: String, value: CIValue) -> Bool {
        switch (type, value) {
        case ("string", .string), ("integer", .integer), ("double", .double), ("boolean", .boolean),
             ("stringArray", .stringArray), ("integerArray", .integerArray), ("doubleArray", .doubleArray):
            return true
        default:
            return false
        }
    }
}
