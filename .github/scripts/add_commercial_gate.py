from pathlib import Path

root = Path('.')
appstore_path = root / 'Halo/Core/AppStore.swift'
settings_path = root / 'Halo/Views/WorkspaceSettingsView.swift'
haloapp_path = root / 'Halo/App/HaloApp.swift'

# ---------- AppStore.swift ----------
s = appstore_path.read_text()
old = '''        // Environmental Interface is intentionally dormant for now. Keep the implementation
        // and assets in the tree so development can resume later without shipping EI at runtime.
        Task {
            await HaloAccountManager.shared.restore()
            await HaloLicenseManager.shared.restoreAndValidate()
        }
'''
new = '''        // Environmental Interface is intentionally dormant for now. Keep the implementation
        // and assets in the tree so development can resume later without shipping EI at runtime.
        // Commercial account/license restoration is owned by AppDelegate so Halo's runtime
        // cannot start before access has been validated.
'''
if old not in s:
    raise SystemExit('AppStore commercial startup block not found')
s = s.replace(old, new, 1)

old = '''    func signOut() {
        clearLocalSession()
        notice = "Signed out."
        errorMessage = nil
    }
'''
new = '''    func sendVerificationEmail() async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        guard isSignedIn else { errorMessage = "Sign in to your Halo account first."; return }
        if emailVerified { notice = "Your email is already verified."; errorMessage = nil; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            let token = try await validIDToken()
            _ = try await firebaseRequest(
                endpoint: "accounts:sendOobCode",
                body: ["requestType": "VERIFY_EMAIL", "idToken": token]
            )
            notice = email.isEmpty ? "Verification email sent." : "Verification email sent to \\(email)."
        } catch { errorMessage = readable(error) }
    }

    func refreshVerificationStatus() async {
        guard isConfigured else { errorMessage = "Firebase is not configured yet."; return }
        guard isSignedIn else { errorMessage = "Sign in to your Halo account first."; return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            _ = try await validIDToken()
            try await loadProfile()
            notice = emailVerified ? "Email verified." : "Email is still awaiting verification."
        } catch { errorMessage = readable(error) }
    }

    func signOut() {
        clearLocalSession()
        notice = "Signed out."
        errorMessage = nil
    }
'''
if old not in s:
    raise SystemExit('HaloAccountManager signOut block not found')
s = s.replace(old, new, 1)

old = '''@MainActor
final class HaloLicenseManager: ObservableObject {
'''
new = '''struct HaloLicenseDetails: Equatable {
    var status: String = ""
    var plan: String = ""
    var expiresAt: Date?
    var activeSeats: Int?
    var seatLimit: Int?

    static let empty = HaloLicenseDetails()

    var statusTitle: String {
        guard !status.isEmpty else { return "Unknown" }
        return status.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var daysRemaining: Int? {
        guard let expiresAt else { return nil }
        return max(0, Int(ceil(expiresAt.timeIntervalSinceNow / 86_400)))
    }

    var activatedMacsTitle: String {
        guard let activeSeats else { return "Unavailable" }
        if let seatLimit { return "\\(activeSeats) of \\(seatLimit)" }
        return "\\(activeSeats)"
    }
}

@MainActor
final class HaloLicenseManager: ObservableObject {
'''
if old not in s:
    raise SystemExit('HaloLicenseManager marker not found')
s = s.replace(old, new, 1)

old = '''    @Published private(set) var licenseHint = ""
    @Published private(set) var isBusy = false
'''
new = '''    @Published private(set) var licenseHint = ""
    @Published private(set) var details: HaloLicenseDetails = .empty
    @Published private(set) var isBusy = false
'''
if old not in s:
    raise SystemExit('license published properties not found')
s = s.replace(old, new, 1)

old = '''        guard isConfigured else { state = .unconfigured; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; return }
'''
new = '''        guard isConfigured else { state = .unconfigured; details = .empty; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; details = .empty; return }
'''
if s.count(old) < 1:
    raise SystemExit('restore guard not found')
s = s.replace(old, new, 1)

old = '''            let parsed = parseValidation(json)
            guard parsed.valid else { throw HaloCommercialError.message(parsed.message ?? "License activation was rejected.") }
            HaloKeychain.set(cleaned, for: licenseKeyKey)
            licenseHint = Self.hint(cleaned)
            state = .valid(plan: parsed.plan)
            notice = "License activated on this Mac."
'''
new = '''            let parsed = parseValidation(json)
            guard parsed.valid else { throw HaloCommercialError.message(parsed.message ?? "License activation was rejected.") }
            HaloKeychain.set(cleaned, for: licenseKeyKey)
            licenseHint = Self.hint(cleaned)
            details = parsed.details
            state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
            notice = "License activated on this Mac."
'''
if old not in s:
    raise SystemExit('activation parse block not found')
s = s.replace(old, new, 1)

old = '''            let parsed = parseValidation(json)
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
'''
new = '''            let parsed = parseValidation(json)
            details = parsed.details
            if parsed.valid {
                state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
                licenseHint = Self.hint(key)
            } else {
                state = .invalid(parsed.message ?? "This license is not valid for this Mac.")
            }
        } catch {
            details = .empty
            state = .invalid(readable(error))
            errorMessage = readable(error)
        }
'''
if old not in s:
    raise SystemExit('validation parse block not found')
s = s.replace(old, new, 1)

old = '''            HaloKeychain.remove(licenseKeyKey)
            licenseHint = ""
            state = .inactive
            notice = "This Mac has been deactivated."
'''
new = '''            HaloKeychain.remove(licenseKeyKey)
            licenseHint = ""
            details = .empty
            state = .inactive
            notice = "This Mac has been deactivated."
'''
if old not in s:
    raise SystemExit('deactivate cleanup not found')
s = s.replace(old, new, 1)

old = '''        HaloKeychain.remove(licenseKeyKey)
        licenseHint = ""
        state = isConfigured ? .inactive : .unconfigured
        notice = "Local license data cleared."
'''
new = '''        HaloKeychain.remove(licenseKeyKey)
        licenseHint = ""
        details = .empty
        state = isConfigured ? .inactive : .unconfigured
        notice = "Local license data cleared."
'''
if old not in s:
    raise SystemExit('clear license cleanup not found')
s = s.replace(old, new, 1)

old = '''    private func parseValidation(_ root: [String: Any]) -> (valid: Bool, plan: String?, message: String?) {
        let valid = (root["valid"] as? Bool) ?? true
        let license = root["license"] as? [String: Any]
        let plan = (license?["plan_key"] as? String) ?? (license?["plan"] as? String)
        let message = (root["message"] as? String)
            ?? ((root["error"] as? [String: Any])?["message"] as? String)
        return (valid, plan, message)
    }
'''
new = '''    private func parseValidation(_ root: [String: Any]) -> (valid: Bool, details: HaloLicenseDetails, message: String?) {
        let license = (root["license"] as? [String: Any])
            ?? ((root["activation"] as? [String: Any])?["license"] as? [String: Any])
        let status = (license?["status"] as? String) ?? ""
        let plan = (license?["plan_key"] as? String) ?? (license?["plan"] as? String) ?? ""
        let activeSeats = intValue(license?["active_seats"])
        let seatLimit = intValue(license?["seat_limit"])

        var expiresAt = dateValue(license?["expires_at"])
        if expiresAt == nil, let entitlements = license?["active_entitlements"] as? [[String: Any]] {
            let expirations = entitlements.compactMap { dateValue($0["expires_at"]) }
            expiresAt = expirations.min()
        }

        let explicitValid = root["valid"] as? Bool
        let object = root["object"] as? String
        let inferredValid = status.lowercased() == "active" || object == "activation"
        let valid = explicitValid ?? inferredValid
        let message = (root["message"] as? String)
            ?? ((root["error"] as? [String: Any])?["message"] as? String)
        let details = HaloLicenseDetails(
            status: status.isEmpty ? (valid ? "active" : "invalid") : status,
            plan: plan,
            expiresAt: expiresAt,
            activeSeats: activeSeats,
            seatLimit: seatLimit
        )
        return (valid, details, message)
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private func dateValue(_ value: Any?) -> Date? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        return ISO8601DateFormatter().date(from: raw)
    }
'''
if old not in s:
    raise SystemExit('old parseValidation not found')
s = s.replace(old, new, 1)
appstore_path.write_text(s)

# ---------- WorkspaceSettingsView.swift ----------
s = settings_path.read_text()
s = s.replace('''    static let support = URL(string: "https://buymeacoffee.com/redstoneinvente")!\n''', '''    static let support = URL(string: "mailto:r.support@redstoneinvente.com")!\n''', 1)
s = s.replace('''            Link(destination: HaloAboutContent.support) { Label("Buy me a coffee", systemImage: "cup.and.saucer.fill") }\n''', '''            Link(destination: HaloAboutContent.support) { Label("Email support · r.support@redstoneinvente.com", systemImage: "envelope.fill") }\n''', 1)

old = '''                LabeledContent("Email", value: account.emailVerified ? "Verified" : "Not verified")
                HStack {
                    Button("Sign Out") { account.signOut() }
                    if account.isBusy { ProgressView().controlSize(.small) }
                }
'''
new = '''                LabeledContent("Email", value: account.emailVerified ? "Verified" : "Not verified")
                HStack {
                    if !account.emailVerified {
                        Button("Send Verification Email") { Task { await account.sendVerificationEmail() } }
                        Button("Refresh Verification Status") { Task { await account.refreshVerificationStatus() } }
                    }
                    Button("Sign Out") { account.signOut() }
                    if account.isBusy { ProgressView().controlSize(.small) }
                }
'''
if old not in s:
    raise SystemExit('account signed-in controls not found')
s = s.replace(old, new, 1)

old = '''                if !license.licenseHint.isEmpty { LabeledContent("License", value: license.licenseHint) }

                if license.state.isValid {
'''
new = '''                if !license.licenseHint.isEmpty { LabeledContent("License", value: license.licenseHint) }
                if license.state.isValid {
                    LabeledContent("Status", value: license.details.statusTitle)
                    if !license.details.plan.isEmpty { LabeledContent("Plan", value: license.details.plan) }
                    LabeledContent("Activated Macs", value: license.details.activatedMacsTitle)
                    if let days = license.details.daysRemaining, let expiresAt = license.details.expiresAt {
                        LabeledContent("Subscription remaining", value: "\\(days) day\\(days == 1 ? "" : "s")")
                        LabeledContent("Expires", value: expiresAt.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        LabeledContent("License term", value: "Lifetime / no expiry reported")
                    }
                }

                if license.state.isValid {
'''
if old not in s:
    raise SystemExit('license detail insertion point not found')
s = s.replace(old, new, 1)

old = '''            Link("Manage LicenseSeat account", destination: URL(string: "https://licenseseat.com")!)
'''
new = '''            Link("Manage LicenseSeat account", destination: URL(string: "https://licenseseat.com")!)
            Link("Contact Halo support · r.support@redstoneinvente.com", destination: URL(string: "mailto:r.support@redstoneinvente.com")!)
'''
if old not in s:
    raise SystemExit('support section insertion point not found')
s = s.replace(old, new, 1)
settings_path.write_text(s)

# ---------- HaloApp.swift ----------
s = haloapp_path.read_text()
old = '''    private var settings: NSWindow?
    private var hudSettings: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
'''
new = '''    private var settings: NSWindow?
    private var hudSettings: NSWindow?
    private var welcome: NSWindow?
    private var commercialBag = Set<AnyCancellable>()
    private var runtimeStarted = false
    private let welcomeCompletedKey = "HaloCommercialWelcomeCompleted"

    private var commercialCredentialsValid: Bool {
        HaloAccountManager.shared.isSignedIn && HaloLicenseManager.shared.state.isValid
    }

    private var commercialAccessGranted: Bool {
        commercialCredentialsValid && UserDefaults.standard.bool(forKey: welcomeCompletedKey)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
'''
if old not in s:
    raise SystemExit('AppDelegate property insertion point not found')
s = s.replace(old, new, 1)

old = '''        store.workspace.start()
        engine = WindowManager(store: store)
        engine?.start()
        hudController = HaloHUDController(audio: store.workspace.audio)
        hudController?.start()


        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
'''
new = '''        configureCommercialAccessGate()

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
'''
if old not in s:
    raise SystemExit('unconditional runtime startup not found')
s = s.replace(old, new, 1)

old = '''        if !UserDefaults.standard.bool(forKey: "onboarded") { openSettings() }
    }

    @objc private func toggle() { engine?.toggleAll() }
'''
new = '''    }

    private func configureCommercialAccessGate() {
        Publishers.CombineLatest(
            HaloAccountManager.shared.$isSignedIn.removeDuplicates(),
            HaloLicenseManager.shared.$state.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in self?.refreshCommercialAccess() }
        .store(in: &commercialBag)

        // Keep the runtime completely dormant until both services have restored and validated.
        showWelcome()
        Task { @MainActor [weak self] in
            await HaloAccountManager.shared.restore()
            await HaloLicenseManager.shared.restoreAndValidate()
            self?.refreshCommercialAccess()
        }
    }

    private func refreshCommercialAccess() {
        if commercialAccessGranted {
            welcome?.orderOut(nil)
            startLicensedRuntime()
        } else {
            stopLicensedRuntime()
            showWelcome()
        }
    }

    private func startLicensedRuntime() {
        guard !runtimeStarted else { return }
        runtimeStarted = true
        store.workspace.start()
        let manager = WindowManager(store: store)
        engine = manager
        manager.start()
        let hud = HaloHUDController(audio: store.workspace.audio)
        hudController = hud
        hud.start()
    }

    private func stopLicensedRuntime() {
        guard runtimeStarted else { return }
        runtimeStarted = false
        hudController?.stop()
        hudController = nil
        engine?.stop()
        engine = nil
        store.workspace.stop()
    }

    private func completeWelcome() {
        guard commercialCredentialsValid else { return }
        UserDefaults.standard.set(true, forKey: welcomeCompletedKey)
        refreshCommercialAccess()
    }

    private func showWelcome() {
        if welcome == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to Halo"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: HaloCommercialWelcomeView(
                firstRun: !UserDefaults.standard.bool(forKey: welcomeCompletedKey),
                onContinue: { [weak self] in self?.completeWelcome() },
                openSettings: { [weak self] in self?.openSettings() },
                quit: { NSApp.terminate(nil) }
            ))
            window.center()
            welcome = window
        }
        NSApp.activate(ignoringOtherApps: true)
        welcome?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggle() {
        guard commercialAccessGranted else { showWelcome(); return }
        engine?.toggleAll()
    }
'''
if old not in s:
    raise SystemExit('toggle/onboarded block not found')
s = s.replace(old, new, 1)

old = '''    func applicationWillTerminate(_ notification: Notification) {
        hudController?.stop()
        engine?.stop(); store.flushConfiguration(); store.workspace.stop()
    }
}

enum HaloHUDKeys {
'''
new = '''    func applicationWillTerminate(_ notification: Notification) {
        stopLicensedRuntime()
        store.flushConfiguration()
    }
}

@MainActor
private struct HaloCommercialWelcomeView: View {
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var licenseKey = ""
    @State private var creatingAccount = false

    let firstRun: Bool
    let onContinue: () -> Void
    let openSettings: () -> Void
    let quit: () -> Void

    private var canContinue: Bool { account.isSignedIn && license.state.isValid }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable().scaledToFit().frame(width: 92, height: 92)
                        Text(firstRun ? "Welcome to Halo" : "Halo needs your attention")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Sign in to your Halo account and activate a valid license before the notch starts.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 480)
                    }

                    GroupBox("Halo Account") {
                        VStack(alignment: .leading, spacing: 12) {
                            if account.isSignedIn {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text(account.email.isEmpty ? "Signed in" : account.email).fontWeight(.semibold)
                                    Spacer()
                                    Text(account.emailVerified ? "Verified" : "Email not verified")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if !account.emailVerified {
                                    HStack {
                                        Button("Send Verification Email") { Task { await account.sendVerificationEmail() } }
                                        Button("Refresh Status") { Task { await account.refreshVerificationStatus() } }
                                    }
                                }
                                Button("Sign Out") { account.signOut() }
                            } else {
                                Picker("Account", selection: $creatingAccount) {
                                    Text("Sign In").tag(false)
                                    Text("Create Account").tag(true)
                                }
                                .pickerStyle(.segmented)
                                TextField("Email", text: $email)
                                SecureField("Password", text: $password)
                                HStack {
                                    Button(creatingAccount ? "Create Account" : "Sign In") {
                                        Task {
                                            if creatingAccount { await account.signUp(email: email, password: password) }
                                            else { await account.signIn(email: email, password: password) }
                                            if account.isSignedIn { password = "" }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(account.isBusy || email.isEmpty || password.isEmpty)
                                    if !creatingAccount {
                                        Button("Forgot Password?") { Task { await account.resetPassword(email: email) } }
                                            .disabled(account.isBusy || email.isEmpty)
                                    }
                                }
                            }
                            if account.isBusy { ProgressView().controlSize(.small) }
                            if let notice = account.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
                            if let error = account.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                        }
                        .padding(6)
                    }

                    GroupBox("Halo License") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: license.state.isValid ? "checkmark.seal.fill" : "key.horizontal")
                                    .foregroundStyle(license.state.isValid ? .green : .secondary)
                                Text(license.state.title).fontWeight(.semibold)
                                Spacer()
                                if license.isBusy { ProgressView().controlSize(.small) }
                            }
                            if license.state.isValid {
                                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 7) {
                                    GridRow { Text("Status").foregroundStyle(.secondary); Text(license.details.statusTitle) }
                                    if !license.details.plan.isEmpty {
                                        GridRow { Text("Plan").foregroundStyle(.secondary); Text(license.details.plan) }
                                    }
                                    GridRow { Text("Activated Macs").foregroundStyle(.secondary); Text(license.details.activatedMacsTitle) }
                                    if let days = license.details.daysRemaining {
                                        GridRow { Text("Remaining").foregroundStyle(.secondary); Text("\\(days) day\\(days == 1 ? "" : "s")") }
                                    }
                                }
                                HStack {
                                    Button("Validate Now") { Task { await license.validate() } }.disabled(license.isBusy)
                                    Button("Deactivate This Mac", role: .destructive) { Task { await license.deactivate() } }.disabled(license.isBusy)
                                }
                            } else {
                                SecureField("License key", text: $licenseKey)
                                Button("Activate License") {
                                    Task {
                                        await license.activate(licenseKey)
                                        if license.state.isValid { licenseKey = "" }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(license.isBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            if let notice = license.notice { Text(notice).font(.caption).foregroundStyle(.secondary) }
                            if let error = license.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
                        }
                        .padding(6)
                    }

                    HStack(spacing: 14) {
                        Link("r.support@redstoneinvente.com", destination: URL(string: "mailto:r.support@redstoneinvente.com")!)
                        Button("Open Settings") { openSettings() }
                            .buttonStyle(.link)
                    }
                    .font(.caption)
                }
                .padding(28)
            }

            Divider()
            HStack {
                Button("Quit Halo") { quit() }
                Spacer()
                if !canContinue {
                    Text("A signed-in account and valid license are required.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Continue to Halo") { onContinue() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
            }
            .padding(18)
        }
        .frame(width: 640, height: 720)
    }
}

enum HaloHUDKeys {
'''
if old not in s:
    raise SystemExit('AppDelegate termination marker not found')
s = s.replace(old, new, 1)

# Combine is used by the commercial gate.
if 'import Combine\n' not in s.split('@main', 1)[0]:
    s = s.replace('import IOKit\n', 'import IOKit\nimport Combine\n', 1)

haloapp_path.write_text(s)
print('Commercial access gate, email verification, license details, and support contact added')
