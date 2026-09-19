import AppKit
import Combine
import Foundation

struct CISurfaceOwnershipDecision: Sendable {
    var shouldOpenSurface = false
    var shouldCollapseSurface = false
    var session: CIActivationSession?
}

/// Composition root for app-integration CI services. Each responsibility remains implemented by
/// its dedicated catalog/factory/config/router/eligibility/payload/activation/broker/transport type.
@MainActor
final class IntegrationCIRuntime: ObservableObject {
    static let shared = IntegrationCIRuntime()

    @Published private(set) var registrations: [CIRegistration] = []
    @Published private(set) var revision: UInt64 = 0
    @Published private(set) var lastError: String?

    let catalog: HaloIntegrationCatalog
    let configurationStore: CIConfigurationStore
    let payloadStore: TriggerPayloadStore
    let triggerRouter: TriggerRouter
    let activationCoordinator: CIActivationCoordinator

    private var eligibleByDisplay: [String: [CIEligibleCandidate]] = [:]
    private var eventsByDisplay: [String: TriggerEvent] = [:]
    private var winnerCIByDisplay: [String: String] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private var started = false

    private lazy var actionBroker = IntegrationActionBroker(
        configurationStore: configurationStore,
        payloadStore: payloadStore,
        activationCoordinator: activationCoordinator,
        registrationsProvider: { [weak self] in self?.registrations ?? [] },
        freshIntegrationProvider: { [weak self] bundleID in
            guard let self else { throw IntegrationDiscoveryError.unavailable(bundleID) }
            return try self.catalog.freshIntegration(bundleIdentifier: bundleID)
        }
    )

    init(
        catalog: HaloIntegrationCatalog = .shared,
        configurationStore: CIConfigurationStore = .shared,
        payloadStore: TriggerPayloadStore = TriggerPayloadStore(),
        triggerRouter: TriggerRouter = TriggerRouter(),
        activationCoordinator: CIActivationCoordinator = CIActivationCoordinator()
    ) {
        self.catalog = catalog
        self.configurationStore = configurationStore
        self.payloadStore = payloadStore
        self.triggerRouter = triggerRouter
        self.activationCoordinator = activationCoordinator
    }

    func start() {
        guard !started else { return }
        started = true
        catalog.$integrations
            .receive(on: RunLoop.main)
            .sink { [weak self] integrations in self?.rebuildRegistrations(integrations) }
            .store(in: &subscriptions)
        catalog.$diagnostics
            .receive(on: RunLoop.main)
            .sink { [weak self] diagnostics in
                guard let self, !diagnostics.isEmpty else { return }
                self.lastError = diagnostics.joined(separator: "\n")
            }
            .store(in: &subscriptions)
        configurationStore.onChange = { [weak self] in
            DispatchQueue.main.async { self?.configurationChanged() }
        }
        catalog.start()
        rebuildRegistrations(catalog.integrations)
    }

    func stop() {
        guard started else { return }
        started = false
        subscriptions.removeAll()
        configurationStore.onChange = nil
        catalog.stop()
        cleanupForSleepOrWake()
    }

    func refresh() { catalog.refresh() }

    func configuration(for registration: CIRegistration) -> CIConfiguration {
        configurationStore.configuration(for: registration)
    }

    func registration(ciID: String) -> CIRegistration? {
        registrations.first(where: { $0.id == ciID })
    }

    func eligibleCandidates(displayID: String) -> [CIEligibleCandidate] {
        eligibleByDisplay[displayID] ?? []
    }

    func candidate(ciID: String, displayID: String) -> CIEligibleCandidate? {
        eligibleByDisplay[displayID]?.first(where: { $0.registration.id == ciID })
    }

    func currentSession(displayID: String) -> CIActivationSession? {
        activationCoordinator.currentSession(displayID: displayID)
    }

    func isCurrent(sessionID: UUID, ciID: String, displayID: String) -> Bool {
        activationCoordinator.isCurrent(sessionID: sessionID, ciID: ciID, displayID: displayID)
    }

    func currentWinnerCIID(displayID: String) -> String? { winnerCIByDisplay[displayID] }

    @discardableResult
    func fileDragEntered(files: [URL], displayID: String) -> Bool {
        guard eventsByDisplay[displayID]?.kind != .fileDrag,
              let metadata = FileDragClassifier.classify(files) else {
            return !(eligibleByDisplay[displayID] ?? []).isEmpty
        }
        let eventID = UUID()
        guard let handle = payloadStore.storeFileDrag(eventID: eventID, displayID: displayID, files: files) else { return false }
        let event = TriggerEvent(
            id: eventID,
            kind: .fileDrag,
            displayID: displayID,
            payloadHandle: handle,
            fileDrag: metadata
        )
        eventsByDisplay[displayID] = event
        eligibleByDisplay[displayID] = route(event)
        bumpRevision()
        return !(eligibleByDisplay[displayID] ?? []).isEmpty
    }

    func manualActivate(ciID: String, displayID: String) {
        let event = TriggerEvent(kind: .manual, displayID: displayID, targetedCIID: ciID, targetedTriggerID: "manual")
        eventsByDisplay[displayID] = event
        eligibleByDisplay[displayID] = route(event)
        bumpRevision()
    }

    func keyboardShortcutActivate(ciID: String, triggerID: String, displayID: String) {
        let event = TriggerEvent(
            kind: .keyboardShortcut,
            displayID: displayID,
            targetedCIID: ciID,
            targetedTriggerID: triggerID
        )
        eventsByDisplay[displayID] = event
        eligibleByDisplay[displayID] = route(event)
        bumpRevision()
    }

    func fileDragExited(displayID: String, pinned: Bool) -> Bool {
        guard eventsByDisplay[displayID]?.kind == .fileDrag else { return false }
        if let session = activationCoordinator.currentSession(displayID: displayID), session.committed {
            return false
        }
        let cancelled = activationCoordinator.cancelUncommitted(displayID: displayID, pinned: pinned)
        if let handle = cancelled.session?.payloadHandle { payloadStore.remove(handle) }
        if let eventHandle = eventsByDisplay[displayID]?.payloadHandle { payloadStore.remove(eventHandle) }
        eventsByDisplay.removeValue(forKey: displayID)
        eligibleByDisplay.removeValue(forKey: displayID)
        winnerCIByDisplay.removeValue(forKey: displayID)
        bumpRevision()
        return cancelled.shouldCollapse
    }

    /// Called by the Halo-owned drag destination after the central SurfaceView arbiter has already
    /// established that an integration owns this display.
    func commitFileDrag(displayID: String) -> Bool {
        guard let winner = winnerCIByDisplay[displayID],
              let session = activationCoordinator.currentSession(displayID: displayID),
              session.ciID == winner,
              let handle = session.payloadHandle,
              payloadStore.commit(handle, sessionID: session.id, ciID: winner) else { return false }
        _ = activationCoordinator.markCommitted(sessionID: session.id)
        bumpRevision()
        return true
    }

    func surfaceWinnerDidChange(
        ciID: String?,
        displayID: String,
        surfaceExpanded: Bool,
        pinned: Bool
    ) -> CISurfaceOwnershipDecision {
        var decision = CISurfaceOwnershipDecision()
        let previousWinner = winnerCIByDisplay[displayID]
        if previousWinner == ciID,
           let session = activationCoordinator.currentSession(displayID: displayID) {
            decision.session = session
            return decision
        }

        if let previous = activationCoordinator.currentSession(displayID: displayID) {
            let finished = activationCoordinator.finish(sessionID: previous.id, pinned: pinned)
            if let handle = previous.payloadHandle, !previous.committed {
                payloadStore.releaseBinding(handle, sessionID: previous.id)
            }
            decision.shouldCollapseSurface = finished.shouldCollapse
        }
        winnerCIByDisplay.removeValue(forKey: displayID)

        guard let ciID,
              let candidate = candidate(ciID: ciID, displayID: displayID),
              let registration = registration(ciID: ciID) else {
            bumpRevision()
            return decision
        }

        let config = configurationStore.configuration(for: registration)
        let autoOpen = config.triggers[candidate.triggerID]?.autoOpen ?? true
        let activation = activationCoordinator.activate(
            candidate: candidate,
            surfaceWasExpanded: surfaceExpanded,
            pinned: pinned,
            autoOpen: autoOpen
        )
        if let handle = activation.session.payloadHandle,
           !payloadStore.bind(handle, to: activation.session.id, ciID: ciID, eventID: candidate.event.id) {
            _ = activationCoordinator.relinquish(displayID: displayID)
            lastError = "Integration payload ownership changed before activation."
            bumpRevision()
            return decision
        }
        winnerCIByDisplay[displayID] = ciID
        decision.session = activation.session
        decision.shouldOpenSurface = activation.shouldOpenSurface
        decision.shouldCollapseSurface = false
        bumpRevision()
        return decision
    }

    func noteUserSurfaceOverride(displayID: String) {
        activationCoordinator.noteUserSurfaceOverride(displayID: displayID)
    }

    func dismiss(displayID: String, pinned: Bool) -> Bool {
        guard let session = activationCoordinator.currentSession(displayID: displayID) else { return false }
        let result = activationCoordinator.finish(sessionID: session.id, pinned: pinned)
        if let handle = session.payloadHandle { payloadStore.remove(handle) }
        eventsByDisplay.removeValue(forKey: displayID)
        eligibleByDisplay.removeValue(forKey: displayID)
        winnerCIByDisplay.removeValue(forKey: displayID)
        bumpRevision()
        return result.shouldCollapse
    }

    func executeAction(
        ciID: String,
        actionID: String,
        activationSessionID: UUID,
        options: [String: CIValue],
        parentWindow: NSWindow?,
        pinned: Bool
    ) async throws -> Bool {
        do {
            _ = try await actionBroker.execute(
                ciID: ciID,
                actionID: actionID,
                activationSessionID: activationSessionID,
                optionOverrides: options,
                parentWindow: parentWindow
            )
            guard let session = activationCoordinator.session(id: activationSessionID) else { return false }
            let result = activationCoordinator.finish(sessionID: activationSessionID, pinned: pinned)
            if let handle = session.payloadHandle { payloadStore.remove(handle) }
            eventsByDisplay.removeValue(forKey: session.displayID)
            eligibleByDisplay.removeValue(forKey: session.displayID)
            winnerCIByDisplay.removeValue(forKey: session.displayID)
            bumpRevision()
            return result.shouldCollapse
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func clearError() { lastError = nil }

    func cleanupForSleepOrWake() {
        _ = activationCoordinator.cleanupForSleepOrWake()
        payloadStore.clear()
        eligibleByDisplay.removeAll()
        eventsByDisplay.removeAll()
        winnerCIByDisplay.removeAll()
        bumpRevision()
    }

    private func rebuildRegistrations(_ integrations: [DiscoveredIntegration]) {
        let next = integrations.map { IntegrationCIFactory.makeRegistration(from: $0.definition) }
            .sorted { $0.metadata.name.localizedCaseInsensitiveCompare($1.metadata.name) == .orderedAscending }
        registrations = next
        for registration in next { _ = configurationStore.configuration(for: registration) }
        rerouteActiveEvents()
        bumpRevision()
        NotificationCenter.default.post(name: .init("HaloIntegrationRegistrationsChanged"), object: nil)
    }

    private func configurationChanged() {
        rerouteActiveEvents()
        bumpRevision()
        NotificationCenter.default.post(name: .init("HaloIntegrationConfigurationChanged"), object: nil)
    }

    private func rerouteActiveEvents() {
        for (displayID, event) in eventsByDisplay {
            eligibleByDisplay[displayID] = route(event)
        }
        let validIDs = Set(registrations.map(\.id))
        for (displayID, winner) in winnerCIByDisplay where !validIDs.contains(winner) {
            winnerCIByDisplay.removeValue(forKey: displayID)
        }
    }

    private func route(_ event: TriggerEvent) -> [CIEligibleCandidate] {
        triggerRouter.route(event, registrations: registrations) { [configurationStore] registration in
            configurationStore.configuration(for: registration)
        }
    }

    private func bumpRevision() { revision &+= 1 }
}
