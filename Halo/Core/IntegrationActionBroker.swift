import AppKit
import Foundation

struct IntegrationActionExecutionResult: Hashable, Sendable {
    var ciID: String
    var actionID: String
    var activationSessionID: UUID
    var displayID: String
}

enum IntegrationActionBrokerError: LocalizedError, Equatable {
    case ciMissing(String)
    case ciDisabled(String)
    case invalidSource(String)
    case staleActivation
    case actionMissing(String)
    case actionDisabled(String)
    case actionNotEligible(String)
    case permissionDenied(String)
    case payloadUnavailable
    case incompatibleInput
    case missingRequiredOption(String)
    case invalidOption(String)
    case unexpectedOption(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .ciMissing(let value): return "The CI \(value) is no longer registered."
        case .ciDisabled: return "This integration CI is disabled."
        case .invalidSource: return "This CI is not backed by a partner application integration."
        case .staleActivation: return "This action belongs to a stale or dismissed CI activation."
        case .actionMissing(let value): return "The partner app no longer advertises action \(value)."
        case .actionDisabled: return "This partner action is disabled in Halo Settings."
        case .actionNotEligible: return "This action is not eligible for the current CI activation."
        case .permissionDenied(let value): return "Permission \(value) is not granted for this integration."
        case .payloadUnavailable: return "The drag payload is unavailable, stale, or not committed to this activation."
        case .incompatibleInput: return "The selected files are no longer compatible with this action."
        case .missingRequiredOption(let value): return "Required option \(value) is missing."
        case .invalidOption(let value): return "Option \(value) has an invalid value."
        case .unexpectedOption(let value): return "Option \(value) is not advertised by the current manifest."
        case .userCancelled: return "The action was cancelled."
        }
    }
}

@MainActor
protocol IntegrationFilePicking: AnyObject {
    func chooseFiles(for action: CIActionDefinition, appName: String, parentWindow: NSWindow?) -> [URL]?
}

@MainActor
final class IntegrationFilePicker: IntegrationFilePicking {
    static let shared = IntegrationFilePicker()

    func chooseFiles(for action: CIActionDefinition, appName: String, parentWindow: NSWindow?) -> [URL]? {
        guard action.input.type == .files else { return [] }
        let panel = NSOpenPanel()
        panel.title = action.name
        panel.message = "Choose supported files to send to \(appName)."
        panel.prompt = "Use Files"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = action.input.multiple
        panel.resolvesAliases = true
        NSApp.activate(ignoringOtherApps: true)
        parentWindow?.makeKeyAndOrderFront(nil)
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.filter(\.isFileURL)
    }
}

/// Security-sensitive execution boundary. Renderers request an action by stable IDs only;
/// this broker revalidates every mutable fact immediately before partner delivery.
@MainActor
final class IntegrationActionBroker {
    typealias RegistrationsProvider = @MainActor () -> [CIRegistration]
    typealias FreshIntegrationProvider = @MainActor (String) throws -> DiscoveredIntegration

    private let configurationStore: CIConfigurationStore
    private let payloadStore: TriggerPayloadStore
    private let activationCoordinator: CIActivationCoordinator
    private let registrationsProvider: RegistrationsProvider
    private let freshIntegrationProvider: FreshIntegrationProvider
    private let transport: IntegrationTransporting
    private let filePicker: IntegrationFilePicking

    init(
        configurationStore: CIConfigurationStore,
        payloadStore: TriggerPayloadStore,
        activationCoordinator: CIActivationCoordinator,
        registrationsProvider: @escaping RegistrationsProvider,
        freshIntegrationProvider: @escaping FreshIntegrationProvider,
        transport: IntegrationTransporting = IntegrationTransport.shared,
        filePicker: IntegrationFilePicking = IntegrationFilePicker.shared
    ) {
        self.configurationStore = configurationStore
        self.payloadStore = payloadStore
        self.activationCoordinator = activationCoordinator
        self.registrationsProvider = registrationsProvider
        self.freshIntegrationProvider = freshIntegrationProvider
        self.transport = transport
        self.filePicker = filePicker
    }

    func execute(
        ciID: String,
        actionID: String,
        activationSessionID: UUID,
        optionOverrides: [String: CIValue] = [:],
        parentWindow: NSWindow? = nil
    ) async throws -> IntegrationActionExecutionResult {
        var state = try validateCurrent(ciID: ciID, actionID: actionID, activationSessionID: activationSessionID)
        var files: [URL] = []

        if state.freshAction.input.type == .files {
            if let handle = state.session.payloadHandle {
                guard let resolved = payloadStore.resolve(
                    handle,
                    activationSessionID: activationSessionID,
                    ciID: ciID,
                    requireCommitted: true
                ) else { throw IntegrationActionBrokerError.payloadUnavailable }
                files = resolved
            } else {
                guard let selected = filePicker.chooseFiles(
                    for: state.freshAction,
                    appName: state.integration.name,
                    parentWindow: parentWindow
                ) else { throw IntegrationActionBrokerError.userCancelled }
                state = try validateCurrent(ciID: ciID, actionID: actionID, activationSessionID: activationSessionID)
                files = selected
            }
            guard CIEligibilityEngine.filesCompatible(files, with: state.freshAction.input) else {
                throw IntegrationActionBrokerError.incompatibleInput
            }
        }

        var options = state.configuration.actions[actionID]?.optionDefaults ?? [:]
        for (key, value) in optionOverrides { options[key] = value }
        try validateOptions(options, action: state.freshAction)

        state = try validateCurrent(ciID: ciID, actionID: actionID, activationSessionID: activationSessionID)
        if state.freshAction.input.type == .files {
            guard CIEligibilityEngine.filesCompatible(files, with: state.freshAction.input) else {
                throw IntegrationActionBrokerError.incompatibleInput
            }
        } else if !files.isEmpty {
            throw IntegrationActionBrokerError.incompatibleInput
        }
        try validateOptions(options, action: state.freshAction)

        let request = IntegrationDeliveryRequest(
            protocolVersion: state.integration.definition.protocolVersion,
            requestID: UUID(),
            sourceBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.redstoneinvente.Halo",
            actionID: actionID,
            options: options,
            files: files,
            delivery: state.integration.definition.delivery
        )
        try await transport.deliver(request, to: state.integration.appURL)
        return IntegrationActionExecutionResult(
            ciID: ciID,
            actionID: actionID,
            activationSessionID: activationSessionID,
            displayID: state.session.displayID
        )
    }

    private struct ValidatedState {
        var registration: CIRegistration
        var configuration: CIConfiguration
        var session: CIActivationSession
        var integration: DiscoveredIntegration
        var freshAction: CIActionDefinition
    }

    private func validateCurrent(ciID: String, actionID: String, activationSessionID: UUID) throws -> ValidatedState {
        guard let registration = registrationsProvider().first(where: { $0.id == ciID }) else {
            throw IntegrationActionBrokerError.ciMissing(ciID)
        }
        guard case .appIntegration(let bundleIdentifier, _) = registration.source else {
            throw IntegrationActionBrokerError.invalidSource(ciID)
        }
        let configuration = configurationStore.configuration(for: registration)
        guard configuration.enabled else { throw IntegrationActionBrokerError.ciDisabled(ciID) }
        guard configuration.actionEnabled(actionID) else { throw IntegrationActionBrokerError.actionDisabled(actionID) }
        guard let session = activationCoordinator.session(id: activationSessionID), session.ciID == ciID else {
            throw IntegrationActionBrokerError.staleActivation
        }
        guard session.eligibleActionIDs.contains(actionID) else {
            throw IntegrationActionBrokerError.actionNotEligible(actionID)
        }
        guard registration.supportedActions.contains(where: { $0.id == actionID }) else {
            throw IntegrationActionBrokerError.actionMissing(actionID)
        }

        let integration = try freshIntegrationProvider(bundleIdentifier)
        guard integration.bundleIdentifier == bundleIdentifier else {
            throw IntegrationActionBrokerError.invalidSource(ciID)
        }
        guard let action = integration.definition.actions.first(where: { $0.id == actionID }) else {
            throw IntegrationActionBrokerError.actionMissing(actionID)
        }
        for permission in action.requiredPermissions where !configuration.grantedPermissions.contains(permission) {
            throw IntegrationActionBrokerError.permissionDenied(permission)
        }
        return ValidatedState(
            registration: registration,
            configuration: configuration,
            session: session,
            integration: integration,
            freshAction: action
        )
    }

    private func validateOptions(_ values: [String: CIValue], action: CIActionDefinition) throws {
        let options = Dictionary(uniqueKeysWithValues: action.options.map { ($0.key, $0) })
        for key in values.keys where options[key] == nil { throw IntegrationActionBrokerError.unexpectedOption(key) }
        for option in action.options {
            guard let value = values[option.key] else {
                if option.required { throw IntegrationActionBrokerError.missingRequiredOption(option.key) }
                continue
            }
            guard IntegrationManifestCodec.optionValueIsValid(value, for: option) else {
                throw IntegrationActionBrokerError.invalidOption(option.key)
            }
        }
    }
}
