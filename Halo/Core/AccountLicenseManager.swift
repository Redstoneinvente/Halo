import Foundation
import Combine
import AppKit
import FirebaseCore
import FirebaseAuth
import LicenseSeat

struct HaloAccountProfile: Equatable {
    let uid: String
    let email: String
    let displayName: String
    let emailVerified: Bool
}

enum HaloLicenseState: Equatable {
    case notConfigured(String)
    case inactive(String)
    case pending(String)
    case active(maskedKey: String, device: String, activatedAt: Date, lastValidated: Date, offline: Bool)
    case invalid(String)

    var isLicensed: Bool {
        if case .active = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .notConfigured: return "Not configured"
        case .inactive: return "Not activated"
        case .pending: return "Checking license…"
        case .active(_, _, _, _, let offline): return offline ? "Licensed · Offline" : "Licensed"
        case .invalid: return "License problem"
        }
    }
}

@MainActor
final class HaloAccountLicenseManager: ObservableObject {
    static let shared = HaloAccountLicenseManager()

    @Published private(set) var firebaseConfigured = false
    @Published private(set) var account: HaloAccountProfile?
    @Published private(set) var licenseConfigured = false
    @Published private(set) var licenseState: HaloLicenseState = .notConfigured("Add your LicenseSeat publishable key and product slug.")
    @Published private(set) var nextLicenseValidation: Date?
    @Published private(set) var isBusy = false
    @Published var notice: String?
    @Published var errorMessage: String?

    private var started = false
    private var authListener: AuthStateDidChangeListenerHandle?
    private var subscriptions = Set<AnyCancellable>()

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        configureFirebaseIfAvailable()
        configureLicenseSeatIfAvailable()
    }

    // MARK: - Firebase

    private func configureFirebaseIfAvailable() {
        if FirebaseApp.app() == nil {
            guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let options = FirebaseOptions(contentsOfFile: path) else {
                firebaseConfigured = false
                return
            }
            FirebaseApp.configure(options: options)
        }

        firebaseConfigured = FirebaseApp.app() != nil
        guard firebaseConfigured else { return }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.applyFirebaseUser(user) }
        }
        applyFirebaseUser(Auth.auth().currentUser)
    }

    private func applyFirebaseUser(_ user: User?) {
        guard let user else {
            account = nil
            return
        }
        account = HaloAccountProfile(
            uid: user.uid,
            email: user.email ?? "",
            displayName: user.displayName ?? "",
            emailVerified: user.isEmailVerified
        )
    }

    func signIn(email: String, password: String) async {
        guard firebaseConfigured else {
            errorMessage = "Firebase is not configured yet. Add GoogleService-Info.plist to the Halo target."
            return
        }
        await perform("Signed in") {
            _ = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            self.applyFirebaseUser(Auth.auth().currentUser)
        }
    }

    func createAccount(email: String, password: String, displayName: String) async {
        guard firebaseConfigured else {
            errorMessage = "Firebase is not configured yet. Add GoogleService-Info.plist to the Halo target."
            return
        }
        await perform("Account created. Check your inbox to verify your email.") {
            let result = try await Auth.auth().createUser(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty {
                let request = result.user.createProfileChangeRequest()
                request.displayName = cleanName
                try await request.commitChanges()
            }
            try await result.user.sendEmailVerification()
            self.applyFirebaseUser(result.user)
        }
    }

    func sendPasswordReset(email: String) async {
        guard firebaseConfigured else {
            errorMessage = "Firebase is not configured yet."
            return
        }
        await perform("Password reset email sent") {
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func resendVerificationEmail() async {
        guard let user = Auth.auth().currentUser else { return }
        await perform("Verification email sent") {
            try await user.sendEmailVerification()
        }
    }

    func reloadAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        await perform(nil) {
            try await user.reload()
            self.applyFirebaseUser(Auth.auth().currentUser)
        }
    }

    func updateDisplayName(_ displayName: String) async {
        guard let user = Auth.auth().currentUser else { return }
        await perform("Profile updated") {
            let request = user.createProfileChangeRequest()
            request.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            try await request.commitChanges()
            try await user.reload()
            self.applyFirebaseUser(Auth.auth().currentUser)
        }
    }

    func signOut() {
        guard firebaseConfigured else { return }
        do {
            try Auth.auth().signOut()
            account = nil
            notice = "Signed out"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        guard let user = Auth.auth().currentUser else { return }
        await perform("Account deleted") {
            try await user.delete()
            self.account = nil
        }
    }

    // MARK: - LicenseSeat

    private func configureLicenseSeatIfAvailable() {
        let apiKey = configurationValue(environment: "LICENSESEAT_API_KEY", infoKey: "HaloLicenseSeatAPIKey")
        let productSlug = configurationValue(environment: "LICENSESEAT_PRODUCT_SLUG", infoKey: "HaloLicenseSeatProductSlug")

        guard let apiKey, let productSlug else {
            licenseConfigured = false
            licenseState = .notConfigured("Set HALO_LICENSESEAT_API_KEY and HALO_LICENSESEAT_PRODUCT_SLUG in the build configuration.")
            return
        }
        guard apiKey.hasPrefix("pk_") else {
            licenseConfigured = false
            licenseState = .notConfigured("Halo requires a LicenseSeat publishable pk_* key. Never embed an sk_* secret key in the app.")
            return
        }

        LicenseSeatStore.shared.configure(apiKey: apiKey, productSlug: productSlug) { config in
            config.autoValidateInterval = 3600
            config.heartbeatInterval = 300
            config.maxOfflineDays = 7
            config.telemetryEnabled = false
            #if DEBUG
            config.debug = true
            #else
            config.debug = false
            #endif
        }
        licenseConfigured = true
        applyLicenseStatus(LicenseSeatStore.shared.status)

        LicenseSeatStore.shared.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in self?.applyLicenseStatus(status) }
            .store(in: &subscriptions)

        LicenseSeatStore.shared.$nextAutoValidationAt
            .receive(on: RunLoop.main)
            .sink { [weak self] date in self?.nextLicenseValidation = date }
            .store(in: &subscriptions)
    }

    private func configurationValue(environment: String, infoKey: String) -> String? {
        let env = ProcessInfo.processInfo.environment[environment]
        let plist = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String
        for candidate in [env, plist] {
            guard let raw = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  !raw.contains("$(") else { continue }
            return raw
        }
        return nil
    }

    private func applyLicenseStatus(_ status: LicenseStatus) {
        switch status {
        case .inactive(let message):
            licenseState = .inactive(message)
        case .pending(let message):
            licenseState = .pending(message)
        case .invalid(let message), .offlineInvalid(let message):
            licenseState = .invalid(message)
        case .active(let details):
            licenseState = .active(
                maskedKey: Self.mask(details.license),
                device: details.device,
                activatedAt: details.activatedAt,
                lastValidated: details.lastValidated,
                offline: false
            )
        case .offlineValid(let details):
            licenseState = .active(
                maskedKey: Self.mask(details.license),
                device: details.device,
                activatedAt: details.activatedAt,
                lastValidated: details.lastValidated,
                offline: true
            )
        }
    }

    func activateLicense(_ key: String) async {
        guard licenseConfigured else {
            errorMessage = "LicenseSeat is not configured yet."
            return
        }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a license key."
            return
        }

        await perform("Halo activated on this Mac") {
            _ = try await LicenseSeatStore.shared.activate(trimmed)
            self.applyLicenseStatus(LicenseSeatStore.shared.status)
        }
    }

    func validateLicenseNow() async {
        guard licenseConfigured,
              let current = LicenseSeatStore.shared.seat?.currentLicense() else { return }
        await perform("License checked") {
            _ = try await LicenseSeatStore.shared.validate(licenseKey: current.licenseKey)
            self.applyLicenseStatus(LicenseSeatStore.shared.status)
        }
    }

    func deactivateLicense() async {
        guard licenseConfigured else { return }
        await perform("License deactivated on this Mac") {
            try await LicenseSeatStore.shared.deactivate()
            self.applyLicenseStatus(LicenseSeatStore.shared.status)
        }
    }

    var isLicensed: Bool { licenseState.isLicensed }

    private static func mask(_ key: String) -> String {
        let suffix = String(key.suffix(4))
        return key.count > 4 ? "••••-\(suffix)" : "••••"
    }

    // MARK: - Shared operation state

    private func perform(_ success: String?, operation: @escaping @MainActor () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        notice = nil
        defer { isBusy = false }
        do {
            try await operation()
            if let success { notice = success }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
