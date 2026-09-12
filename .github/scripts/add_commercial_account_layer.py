from pathlib import Path
import plistlib

app = Path('Halo/Core/AppStore.swift')
settings = Path('Halo/Views/WorkspaceSettingsView.swift')
plist_path = Path('Halo/Info.plist')

s = app.read_text()
if 'import Security' not in s:
    s = s.replace('import QuartzCore\n', 'import QuartzCore\nimport Security\n')

startup_anchor = '''        // Environmental Interface is intentionally dormant for now. Keep the implementation\n        // and assets in the tree so development can resume later without shipping EI at runtime.\n'''
startup_insert = startup_anchor + '''        Task {\n            await HaloAccountManager.shared.restore()\n            await HaloLicenseManager.shared.restoreAndValidate()\n        }\n'''
if 'HaloAccountManager.shared.restore()' not in s:
    if startup_anchor not in s:
        raise SystemExit('AppStore startup anchor not found')
    s = s.replace(startup_anchor, startup_insert, 1)

marker = '// MARK: - Halo account + LicenseSeat commercial services'
if marker not in s:
    s += r'''

// MARK: - Halo account + LicenseSeat commercial services

struct HaloCommercialConfiguration {
    private static func value(_ key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    static var firebaseAPIKey: String { value("HaloFirebaseAPIKey") }
    static var licenseSeatPublishableKey: String { value("HaloLicenseSeatPublishableKey") }
    static var licenseSeatProductSlug: String { value("HaloLicenseSeatProductSlug") }
    static var firebaseConfigured: Bool { !firebaseAPIKey.isEmpty }
    static var licenseSeatConfigured: Bool {
        !licenseSeatPublishableKey.isEmpty && !licenseSeatProductSlug.isEmpty
    }
}

enum HaloKeychain {
    private static let service = "com.redstoneinvente.Halo.commercial"

    static func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            attributes.forEach { add[$0.key] = $0.value }
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct FirebaseAuthResponse: Decodable {
    let idToken: String
    let email: String?
    let refreshToken: String
    let expiresIn: String
    let localId: String
}

private struct FirebaseRefreshResponse: Decodable {
    let expiresIn: String
    let refreshToken: String
    let idToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case userId = "user_id"
    }
}

private struct FirebaseLookupResponse: Decodable {
    struct User: Decodable {
        let localId: String
        let email: String?
        let emailVerified: Bool?
        let displayName: String?
    }
    let users: [User]?
}

@MainActor
final class HaloAccountManager: ObservableObject {
    static let shared = HaloAccountManager()

    @Published private(set) var isSignedIn = false
    @Published private(set) var email = ""
    @Published private(set) var userID = ""
    @Published private(set) var emailVerified = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published var notice: String?

    private var idToken = ""
    private var tokenExpiry = Date.distantPast
    private let refreshKey = "firebase.refreshToken"
    private let defaults = UserDefaults.standard

    var isConfigured: Bool { HaloCommercialConfiguration.firebaseConfigured }

    func restore() async {
        guard isConfigured else {
            clearLocalSession()
            return
        }
        guard let refresh = HaloKeychain.string(for: refreshKey), !refresh.isEmpty else {
            clearLocalSession()
            return
        }
        do {
            try await refreshSession(using: refresh)
            try await loadProfile()
        } catch {
            clearLocalSession()
            errorMessage = readable(error)
        }
    }

    func signUp(email: String, password: String) async {
        await authenticate(endpoint: "accounts:signUp", email: email, password: password)
    }

    func signIn(email: String, password: String) async {
        await authenticate(endpoint: "accounts:signInWithPassword", email: email, password: password)
    }

    func resetPassword(email: String) async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { errorMessage = "Enter your email address first."; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            _ = try await firebaseRequest(
                endpoint: "accounts:sendOobCode",
                body: ["requestType": "PASSWORD_RESET", "email": cleaned]
            )
            notice = "Password reset email sent."
        } catch { errorMessage = readable(error) }
    }

    func signOut() {
        clearLocalSession()
        notice = "Signed out."
        errorMessage = nil
    }

    func validIDToken() async throws -> String {
        guard isSignedIn else { throw HaloCommercialError.message("Sign in to your Halo account first.") }
        if Date().addingTimeInterval(60) < tokenExpiry, !idToken.isEmpty { return idToken }
        guard let refresh = HaloKeychain.string(for: refreshKey) else {
            throw HaloCommercialError.message("Your Halo session has expired. Please sign in again.")
        }
        try await refreshSession(using: refresh)
        return idToken
    }

    private func authenticate(endpoint: String, email: String, password: String) async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.contains("@") else { errorMessage = "Enter a valid email address."; return }
        guard password.count >= 6 else { errorMessage = "Password must contain at least 6 characters."; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let data = try await firebaseRequest(
                endpoint: endpoint,
                body: ["email": cleaned, "password": password, "returnSecureToken": true]
            )
            let result = try JSONDecoder().decode(FirebaseAuthResponse.self, from: data)
            adopt(idToken: result.idToken, refreshToken: result.refreshToken,
                  userID: result.localId, email: result.email ?? cleaned,
                  expiresIn: result.expiresIn)
            try await loadProfile()
            notice = endpoint.contains("signUp") ? "Halo account created." : "Signed in."
        } catch { errorMessage = readable(error) }
    }

    private func refreshSession(using refreshToken: String) async throws {
        guard let encoded = "grant_type=refresh_token&refresh_token=\(formEncode(refreshToken))".data(using: .utf8),
              let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(HaloCommercialConfiguration.firebaseAPIKey)") else {
            throw HaloCommercialError.message("Firebase configuration is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = encoded
        let data = try await send(request)
        let result = try JSONDecoder().decode(FirebaseRefreshResponse.self, from: data)
        adopt(idToken: result.idToken, refreshToken: result.refreshToken,
              userID: result.userId, email: defaults.string(forKey: "HaloAccountEmail") ?? "",
              expiresIn: result.expiresIn)
    }

    private func loadProfile() async throws {
        guard !idToken.isEmpty else { return }
        let data = try await firebaseRequest(endpoint: "accounts:lookup", body: ["idToken": idToken])
        guard let user = try JSONDecoder().decode(FirebaseLookupResponse.self, from: data).users?.first else { return }
        userID = user.localId
        email = user.email ?? email
        emailVerified = user.emailVerified ?? false
        defaults.set(email, forKey: "HaloAccountEmail")
        isSignedIn = true
    }

    private func adopt(idToken: String, refreshToken: String, userID: String, email: String, expiresIn: String) {
        self.idToken = idToken
        self.userID = userID
        self.email = email
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn) ?? 3600)
        isSignedIn = true
        HaloKeychain.set(refreshToken, for: refreshKey)
        defaults.set(email, forKey: "HaloAccountEmail")
    }

    private func clearLocalSession() {
        HaloKeychain.remove(refreshKey)
        defaults.removeObject(forKey: "HaloAccountEmail")
        idToken = ""
        tokenExpiry = .distantPast
        isSignedIn = false
        email = ""
        userID = ""
        emailVerified = false
    }

    private func firebaseRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/\(endpoint)?key=\(HaloCommercialConfiguration.firebaseAPIKey)") else {
            throw HaloCommercialError.message("Firebase configuration is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HaloCommercialError.message("No response from Firebase.") }
        guard (200..<300).contains(http.statusCode) else {
            throw HaloCommercialError.message(firebaseErrorMessage(from: data) ?? "Firebase request failed (\(http.statusCode)).")
        }
        return data
    }

    private func firebaseErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let raw = error["message"] as? String else { return nil }
        switch raw {
        case "EMAIL_EXISTS": return "An account already exists with this email."
        case "EMAIL_NOT_FOUND": return "No Halo account exists with this email."
        case "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS": return "Incorrect email or password."
        case "USER_DISABLED": return "This account has been disabled."
        case "OPERATION_NOT_ALLOWED": return "Email/password sign-in is not enabled in Firebase."
        case "TOO_MANY_ATTEMPTS_TRY_LATER": return "Too many attempts. Please try again later."
        default: return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))) ?? value
    }

    private func readable(_ error: Error) -> String {
        (error as? HaloCommercialError)?.message ?? error.localizedDescription
    }
}

enum HaloLicenseState: Equatable {
    case unconfigured
    case inactive
    case checking
    case valid(plan: String?)
    case invalid(String)

    var title: String {
        switch self {
        case .unconfigured: return "Not configured"
        case .inactive: return "No license activated"
        case .checking: return "Checking license…"
        case .valid(let plan): return plan.map { "Licensed · \($0)" } ?? "Licensed"
        case .invalid: return "License needs attention"
        }
    }

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

@MainActor
final class HaloLicenseManager: ObservableObject {
    static let shared = HaloLicenseManager()

    @Published private(set) var state: HaloLicenseState = .inactive
    @Published private(set) var licenseHint = ""
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published var notice: String?

    private let licenseKeyKey = "licenseseat.licenseKey"
    private let fingerprintKey = "licenseseat.fingerprint"

    var isConfigured: Bool { HaloCommercialConfiguration.licenseSeatConfigured }

    func restoreAndValidate() async {
        guard isConfigured else { state = .unconfigured; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; return }
        licenseHint = Self.hint(key)
        await validate()
    }

    func activate(_ key: String) async {
        guard isConfigured else { state = .unconfigured; errorMessage = "LicenseSeat is not configured yet."; return }
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 6 else { errorMessage = "Enter your LicenseSeat key."; return }
        isBusy = true; state = .checking; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let payload: [String: Any] = [
                "license_key": cleaned,
                "fingerprint": fingerprint(),
                "device_name": Host.current().localizedName ?? "Mac"
            ]
            let json = try await request(endpoint: "activate", body: payload)
            let parsed = parseValidation(json)
            guard parsed.valid else { throw HaloCommercialError.message(parsed.message ?? "License activation was rejected.") }
            HaloKeychain.set(cleaned, for: licenseKeyKey)
            licenseHint = Self.hint(cleaned)
            state = .valid(plan: parsed.plan)
            notice = "License activated on this Mac."
        } catch {
            state = .invalid(readable(error))
            errorMessage = readable(error)
        }
    }

    func validate() async {
        guard isConfigured else { state = .unconfigured; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; return }
        isBusy = true; state = .checking; errorMessage = nil
        defer { isBusy = false }
        do {
            let json = try await request(endpoint: "validate", body: [
                "license_key": key,
                "fingerprint": fingerprint()
            ])
            let parsed = parseValidation(json)
            if parsed.valid {
                state = .valid(plan: parsed.plan)
                licenseHint = Self.hint(key)
            } else {
                state = .invalid(parsed.message ?? "This license is not valid for this Mac.")
            }
        } catch {
            state = .invalid(readable(error))
            errorMessage = readable(error)
        }
    }

    func deactivate() async {
        guard isConfigured else { return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            _ = try await request(endpoint: "deactivate", body: [
                "license_key": key,
                "fingerprint": fingerprint()
            ])
            HaloKeychain.remove(licenseKeyKey)
            licenseHint = ""
            state = .inactive
            notice = "This Mac has been deactivated."
        } catch { errorMessage = readable(error) }
    }

    func clearLocalLicense() {
        HaloKeychain.remove(licenseKeyKey)
        licenseHint = ""
        state = isConfigured ? .inactive : .unconfigured
        notice = "Local license data cleared."
    }

    private func fingerprint() -> String {
        if let existing = HaloKeychain.string(for: fingerprintKey), !existing.isEmpty { return existing }
        let value = "halo-\(UUID().uuidString.lowercased())"
        HaloKeychain.set(value, for: fingerprintKey)
        return value
    }

    private func request(endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        let slugAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard let slug = HaloCommercialConfiguration.licenseSeatProductSlug.addingPercentEncoding(withAllowedCharacters: slugAllowed),
              let url = URL(string: "https://licenseseat.com/api/v1/products/\(slug)/licenses/\(endpoint)") else {
            throw HaloCommercialError.message("LicenseSeat product configuration is invalid.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(HaloCommercialConfiguration.licenseSeatPublishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HaloCommercialError.message("No response from LicenseSeat.") }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw HaloCommercialError.message("LicenseSeat returned an unreadable response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = ((root["error"] as? [String: Any])?["message"] as? String)
                ?? (root["message"] as? String)
                ?? "LicenseSeat request failed (\(http.statusCode))."
            throw HaloCommercialError.message(message)
        }
        return root
    }

    private func parseValidation(_ root: [String: Any]) -> (valid: Bool, plan: String?, message: String?) {
        let valid = (root["valid"] as? Bool) ?? true
        let license = root["license"] as? [String: Any]
        let plan = (license?["plan_key"] as? String) ?? (license?["plan"] as? String)
        let message = (root["message"] as? String)
            ?? ((root["error"] as? [String: Any])?["message"] as? String)
        return (valid, plan, message)
    }

    private static func hint(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "••••" }
        return "••••-\(trimmed.suffix(4))"
    }

    private func readable(_ error: Error) -> String {
        (error as? HaloCommercialError)?.message ?? error.localizedDescription
    }
}

private enum HaloCommercialError: Error {
    case message(String)
    var message: String {
        switch self { case .message(let value): return value }
    }
}
'''
app.write_text(s)

s = settings.read_text()
old_sections = 'private let sections = ["General", "Appearance", "Modules", "Widgets", "Closed notch", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "About"]'
new_sections = 'private let sections = ["General", "Account & License", "Appearance", "Modules", "Widgets", "Closed notch", "Context Notch Interface", "HUD", "Media & Files", "Profiles", "Schedules", "Automation", "Displays", "Plugins", "Privacy", "About"]'
if old_sections in s:
    s = s.replace(old_sections, new_sections, 1)
elif '"Account & License"' not in s:
    raise SystemExit('Settings section list anchor not found')

icon_anchor = '        case "Appearance": return "paintpalette"\n'
if 'case "Account & License"' not in s:
    if icon_anchor not in s: raise SystemExit('settings icon anchor missing')
    s = s.replace(icon_anchor, '        case "Account & License": return "person.crop.circle.badge.checkmark"\n' + icon_anchor, 1)

content_anchor = '        case "Schedules": ScheduleSettingsView(workspace: workspace)\n'
if 'HaloAccountLicenseSettingsView()' not in s:
    if content_anchor not in s: raise SystemExit('settings content anchor missing')
    s = s.replace(content_anchor, '        case "Account & License": HaloAccountLicenseSettingsView()\n' + content_anchor, 1)

view_marker = '// MARK: - Halo Account & License settings'
if view_marker not in s:
    s += r'''

// MARK: - Halo Account & License settings

@MainActor
private struct HaloAccountLicenseSettingsView: View {
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var licenseKey = ""
    @State private var creatingAccount = false

    var body: some View {
        Section("Halo account") {
            if !account.isConfigured {
                Label("Firebase configuration needed", systemImage: "wrench.and.screwdriver")
                Text("Set HaloFirebaseAPIKey in Info.plist (or the HALO build environment) and enable Email/Password Authentication in Firebase. Halo will then restore sessions automatically from Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if account.isSignedIn {
                LabeledContent("Signed in as", value: account.email.isEmpty ? "Halo user" : account.email)
                if !account.userID.isEmpty {
                    LabeledContent("Account ID", value: String(account.userID.prefix(12)) + "…")
                }
                LabeledContent("Email", value: account.emailVerified ? "Verified" : "Not verified")
                HStack {
                    Button("Sign Out") { account.signOut() }
                    if account.isBusy { ProgressView().controlSize(.small) }
                }
            } else {
                Picker("Mode", selection: $creatingAccount) {
                    Text("Sign In").tag(false)
                    Text("Create Account").tag(true)
                }.pickerStyle(.segmented)
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                SecureField("Password", text: $password)
                    .textContentType(creatingAccount ? .newPassword : .password)
                HStack {
                    Button(creatingAccount ? "Create Halo Account" : "Sign In") {
                        Task {
                            if creatingAccount { await account.signUp(email: email, password: password) }
                            else { await account.signIn(email: email, password: password) }
                            if account.isSignedIn { password = "" }
                        }
                    }
                    .disabled(account.isBusy || email.isEmpty || password.isEmpty)
                    if !creatingAccount {
                        Button("Forgot Password?") { Task { await account.resetPassword(email: email) } }
                            .disabled(account.isBusy || email.isEmpty)
                    }
                    if account.isBusy { ProgressView().controlSize(.small) }
                }
            }
            if let notice = account.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if let error = account.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }

        Section("License") {
            if !license.isConfigured {
                Label("LicenseSeat configuration needed", systemImage: "key.horizontal")
                Text("Set HaloLicenseSeatPublishableKey and HaloLicenseSeatProductSlug. Use a LicenseSeat publishable client key (pk_), never a secret sk_ key in the Mac app.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    Label(license.state.title, systemImage: license.state.isValid ? "checkmark.seal.fill" : "key.horizontal")
                    Spacer()
                    if license.isBusy { ProgressView().controlSize(.small) }
                }
                if !license.licenseHint.isEmpty { LabeledContent("License", value: license.licenseHint) }

                if license.state.isValid {
                    HStack {
                        Button("Validate Now") { Task { await license.validate() } }.disabled(license.isBusy)
                        Button("Deactivate This Mac", role: .destructive) { Task { await license.deactivate() } }.disabled(license.isBusy)
                    }
                } else {
                    SecureField("License key", text: $licenseKey)
                    HStack {
                        Button("Activate License") {
                            Task {
                                await license.activate(licenseKey)
                                if license.state.isValid { licenseKey = "" }
                            }
                        }
                        .disabled(license.isBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !license.licenseHint.isEmpty {
                            Button("Clear Local License", role: .destructive) { license.clearLocalLicense() }
                                .disabled(license.isBusy)
                        }
                    }
                }
            }
            if let notice = license.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
            if let error = license.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }

        Section("How access works") {
            Text("Your Halo account and your software license are separate credentials. Firebase handles identity and session recovery; LicenseSeat handles the purchased license and device seat. Halo stores the Firebase refresh token, the activated license key, and its stable installation fingerprint in macOS Keychain.")
                .font(.caption).foregroundStyle(.secondary)
            Link("Manage LicenseSeat account", destination: URL(string: "https://licenseseat.com")!)
        }
    }
}
'''
settings.write_text(s)

with plist_path.open('rb') as f:
    plist = plistlib.load(f)
plist.setdefault('HaloFirebaseAPIKey', '')
plist.setdefault('HaloLicenseSeatPublishableKey', '')
plist.setdefault('HaloLicenseSeatProductSlug', 'halo')
with plist_path.open('wb') as f:
    plistlib.dump(plist, f, sort_keys=False)

print('Added Firebase account system and LicenseSeat client integration')
