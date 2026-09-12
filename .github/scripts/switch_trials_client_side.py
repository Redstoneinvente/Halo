from pathlib import Path

root = Path('.')


def replace_once(path, old, new, label):
    text = path.read_text()
    if old not in text:
        raise SystemExit(f'{label}: expected block not found in {path}')
    path.write_text(text.replace(old, new, 1))

# --- AppStore: remove endpoint config and make trial local --------------------
app = root / 'Halo/Core/AppStore.swift'
text = app.read_text()
text = text.replace('    static var trialEndpoint: String { value("HaloTrialEndpoint") }\n', '')
text = text.replace('    static var trialConfigured: Bool { !trialEndpoint.isEmpty }\n', '')

old = '''    private let licenseKeyKey = "licenseseat.licenseKey"
    private let fingerprintKey = "licenseseat.fingerprint"

    var isConfigured: Bool { HaloCommercialConfiguration.licenseSeatConfigured }
    var trialConfigured: Bool { HaloCommercialConfiguration.trialConfigured }

    func restoreAndValidate() async {
        guard isConfigured else { state = .unconfigured; details = .empty; return }
        guard let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty else { state = .inactive; details = .empty; return }
        licenseHint = Self.hint(key)
        await validate()
    }
'''
new = '''    private let licenseKeyKey = "licenseseat.licenseKey"
    private let fingerprintKey = "licenseseat.fingerprint"
    private let localTrialUsedKey = "trial.local.used"
    private let localTrialOwnerKey = "trial.local.owner"
    private let localTrialStartedKey = "trial.local.startedAt"
    private let localTrialExpiresKey = "trial.local.expiresAt"
    private let localTrialLastCheckKey = "trial.local.lastCheck"
    private var trialExpiryTask: Task<Void, Never>?

    var isConfigured: Bool { HaloCommercialConfiguration.licenseSeatConfigured }
    // Client-side trial mode is intentionally always available for now.
    var trialConfigured: Bool { true }

    func restoreAndValidate() async {
        // Prefer a paid LicenseSeat entitlement whenever one is stored and valid.
        if isConfigured, let key = HaloKeychain.string(for: licenseKeyKey), !key.isEmpty {
            licenseHint = Self.hint(key)
            await validate()
            if state.isValid { return }
        }

        if restoreLocalTrial() { return }
        state = isConfigured ? .inactive : .unconfigured
        details = .empty
    }
'''
if old not in text:
    raise SystemExit('manager storage/restore block not found')
text = text.replace(old, new, 1)

start = text.index('    func startTrial() async {')
end = text.index('    func activate(_ key: String) async {', start)
local_trial_method = '''    func startTrial() async {
        guard HaloAccountManager.shared.isSignedIn else {
            errorMessage = "Sign in to your Halo account before starting a trial."
            return
        }
        guard HaloAccountManager.shared.emailVerified else {
            errorMessage = "Verify your email before starting the free trial."
            return
        }
        let accountID = HaloAccountManager.shared.userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty else {
            errorMessage = "Halo could not identify this account. Sign out and sign in again."
            return
        }

        isStartingTrial = true
        errorMessage = nil
        notice = nil
        defer { isStartingTrial = false }

        // One local trial per Mac. The owner binding also prevents another signed-in account
        // from inheriting an active trial on this installation.
        if HaloKeychain.string(for: localTrialUsedKey) == "1" {
            if restoreLocalTrial() {
                if state.isValid {
                    notice = "Your Halo trial is already active on this Mac."
                } else if errorMessage == nil {
                    errorMessage = "The free trial has already been used on this Mac."
                }
                return
            }
            errorMessage = "The free trial has already been used on this Mac."
            return
        }

        let startedAt = Date()
        let expiresAt = startedAt.addingTimeInterval(14 * 86_400)
        guard HaloKeychain.set("1", for: localTrialUsedKey),
              HaloKeychain.set(accountID, for: localTrialOwnerKey),
              HaloKeychain.set(String(startedAt.timeIntervalSince1970), for: localTrialStartedKey),
              HaloKeychain.set(String(expiresAt.timeIntervalSince1970), for: localTrialExpiresKey),
              HaloKeychain.set(String(startedAt.timeIntervalSince1970), for: localTrialLastCheckKey) else {
            errorMessage = "Halo could not save the local trial securely in Keychain."
            return
        }

        applyLocalTrial(expiresAt: expiresAt)
        notice = "Your 14-day Halo trial is active on this Mac."
    }

'''
text = text[:start] + local_trial_method + text[end:]

# Paid activation should cancel a pending local expiry task.
text = text.replace('''            details = parsed.details
            state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
            notice = "License activated on this Mac."
''', '''            trialExpiryTask?.cancel()
            details = parsed.details
            state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
            notice = "License activated on this Mac."
''', 1)

# Paid validation: cancel local expiry when paid is valid; otherwise allow an active local trial fallback.
old = '''            if parsed.valid {
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
new = '''            if parsed.valid {
                trialExpiryTask?.cancel()
                state = .valid(plan: parsed.details.plan.isEmpty ? nil : parsed.details.plan)
                licenseHint = Self.hint(key)
            } else if !restoreLocalTrial() {
                state = .invalid(parsed.message ?? "This license is not valid for this Mac.")
            }
        } catch {
            if !restoreLocalTrial() {
                details = .empty
                state = .invalid(readable(error))
                errorMessage = readable(error)
            }
        }
'''
if old not in text:
    raise SystemExit('validate result block not found')
text = text.replace(old, new, 1)

# Deactivation and clear paid license should reveal any still-active local trial.
text = text.replace('''            licenseHint = ""
            details = .empty
            state = .inactive
            notice = "This Mac has been deactivated."
''', '''            licenseHint = ""
            details = .empty
            if !restoreLocalTrial() { state = .inactive }
            notice = state.isValid ? "Paid license deactivated. Your local trial is still active." : "This Mac has been deactivated."
''', 1)
text = text.replace('''        licenseHint = ""
        details = .empty
        state = isConfigured ? .inactive : .unconfigured
        notice = "Local license data cleared."
''', '''        licenseHint = ""
        details = .empty
        if !restoreLocalTrial() { state = isConfigured ? .inactive : .unconfigured }
        notice = state.isValid ? "Paid license cleared. Your local trial is still active." : "Local license data cleared."
''', 1)

# Add local-trial helpers before fingerprint().
marker = '    private func fingerprint() -> String {'
helpers = '''    func accessValid(for accountID: String) -> Bool {
        guard state.isValid else { return false }
        guard details.isTrial && details.plan == "Local Trial" else { return true }
        guard let owner = HaloKeychain.string(for: localTrialOwnerKey), owner == accountID,
              let expiresAt = localTrialDate(for: localTrialExpiresKey) else { return false }
        return Date() < expiresAt
    }

    @discardableResult
    private func restoreLocalTrial() -> Bool {
        guard HaloKeychain.string(for: localTrialUsedKey) == "1" else { return false }
        guard let expiresAt = localTrialDate(for: localTrialExpiresKey),
              let owner = HaloKeychain.string(for: localTrialOwnerKey), !owner.isEmpty else {
            state = .invalid("The local trial record is incomplete.")
            details = .empty
            return true
        }

        let account = HaloAccountManager.shared
        guard account.isSignedIn, !account.userID.isEmpty else { return false }
        guard owner == account.userID else {
            trialExpiryTask?.cancel()
            details = HaloLicenseDetails(status: "account_mismatch", plan: "Local Trial", expiresAt: expiresAt, activeSeats: 1, seatLimit: 1)
            state = .invalid("This Mac's free trial belongs to another Halo account.")
            return true
        }

        let now = Date()
        if let lastCheck = localTrialDate(for: localTrialLastCheckKey), now.timeIntervalSince(lastCheck) < -300 {
            trialExpiryTask?.cancel()
            details = HaloLicenseDetails(status: "clock_changed", plan: "Local Trial", expiresAt: expiresAt, activeSeats: 1, seatLimit: 1)
            state = .invalid("The system clock moved backwards. Restore the correct date and restart Halo.")
            return true
        }
        HaloKeychain.set(String(now.timeIntervalSince1970), for: localTrialLastCheckKey)

        if now >= expiresAt {
            trialExpiryTask?.cancel()
            details = HaloLicenseDetails(status: "expired", plan: "Local Trial", expiresAt: expiresAt, activeSeats: 1, seatLimit: 1)
            state = .invalid("Your 14-day Halo trial has ended.")
            return true
        }

        applyLocalTrial(expiresAt: expiresAt)
        return true
    }

    private func applyLocalTrial(expiresAt: Date) {
        licenseHint = ""
        details = HaloLicenseDetails(status: "active", plan: "Local Trial", expiresAt: expiresAt, activeSeats: 1, seatLimit: 1)
        state = .valid(plan: "Local Trial")
        scheduleLocalTrialExpiry(at: expiresAt)
    }

    private func scheduleLocalTrialExpiry(at expiresAt: Date) {
        trialExpiryTask?.cancel()
        let seconds = max(0, expiresAt.timeIntervalSinceNow)
        let nanoseconds = UInt64(min(seconds, Double(UInt64.max / 1_000_000_000)) * 1_000_000_000)
        trialExpiryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: nanoseconds) }
            catch { return }
            guard let self, !Task.isCancelled else { return }
            _ = self.restoreLocalTrial()
        }
    }

    private func localTrialDate(for key: String) -> Date? {
        guard let raw = HaloKeychain.string(for: key), let timestamp = TimeInterval(raw) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

'''
if marker not in text:
    raise SystemExit('fingerprint marker not found')
text = text.replace(marker, helpers + marker, 1)
app.write_text(text)

# --- HaloApp access gate: account-bound local trial ---------------------------
halo_app = root / 'Halo/App/HaloApp.swift'
text = halo_app.read_text()
text = text.replace('''    private var commercialAccessGranted: Bool {
        HaloAccountManager.shared.isSignedIn && HaloLicenseManager.shared.state.isValid
    }
''', '''    private var commercialAccessGranted: Bool {
        let account = HaloAccountManager.shared
        return account.isSignedIn && HaloLicenseManager.shared.accessValid(for: account.userID)
    }
''', 1)
halo_app.write_text(text)

# --- Surface router/locked notch ---------------------------------------------
router = root / 'Halo/Core/ExtensionContracts.swift'
text = router.read_text()
text = text.replace('''    private var accessLocked: Bool {
        !account.isSignedIn || !license.state.isValid
    }
''', '''    private var accessLocked: Bool {
        !account.isSignedIn || !license.accessValid(for: account.userID)
    }
''', 1)
text = text.replace('''            Text(account.isSignedIn
                 ? "Your account is ready. Activate a license to unlock the notch."
                 : "Sign in or create a Halo account to continue.")
''', '''            Text(account.isSignedIn
                 ? "Start your free trial or activate a license to unlock the notch."
                 : "Sign in or create a Halo account to continue.")
''', 1)
text = text.replace('''                    .disabled(!account.emailVerified || !license.trialConfigured || license.isBusy || license.isStartingTrial)
''', '''                    .disabled(!account.emailVerified || license.isBusy || license.isStartingTrial)
''', 1)
text = text.replace('''                } else if !license.trialConfigured {
                    Text("Trial service is not configured on this build yet.")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
''', '', 1)
router.write_text(text)

# --- Settings UI: remove backend-config wording -------------------------------
settings = root / 'Halo/Views/WorkspaceSettingsView.swift'
text = settings.read_text()
text = text.replace('''                            Button("Start 14-Day Free Trial") { Task { await license.startTrial() } }
                                .disabled(!account.emailVerified || !license.trialConfigured || license.isBusy || license.isStartingTrial)
''', '''                            Button("Start 14-Day Free Trial") { Task { await license.startTrial() } }
                                .disabled(!account.emailVerified || license.isBusy || license.isStartingTrial)
''', 1)
text = text.replace('''                            } else if !license.trialConfigured {
                                Text("Trial service not configured.")
                                    .font(.caption).foregroundStyle(.secondary)
''', '', 1)
settings.write_text(text)

# --- Remove endpoint build config --------------------------------------------
plist = root / 'Halo/Info.plist'
text = plist.read_text()
text = text.replace('\t<key>HaloTrialEndpoint</key>\n\t<string>$(HALO_TRIAL_ENDPOINT)</string>\n', '')
plist.write_text(text)

base = root / 'Halo/Config/Base.xcconfig'
text = base.read_text().replace('HALO_TRIAL_ENDPOINT =\n', '')
base.write_text(text)

example = root / 'Halo/Config/Secrets.xcconfig.example'
text = example.read_text()
text = '\n'.join(line for line in text.splitlines() if not line.startswith('HALO_TRIAL_ENDPOINT')) + '\n'
example.write_text(text)

# Backend is intentionally removed while trials are client-side.
for path in [root / 'firebase.json', root / 'firestore.rules', root / 'functions/index.js', root / 'functions/package.json', root / 'functions/README.md']:
    if path.exists():
        path.unlink()
functions_dir = root / 'functions'
if functions_dir.exists() and not any(functions_dir.iterdir()):
    functions_dir.rmdir()

ignore = root / '.gitignore'
text = ignore.read_text()
text = text.replace('\n# Firebase local/deploy state\nfunctions/node_modules/\n.firebase/\nfirebase-debug.log\nfirestore-debug.log\n', '\n')
ignore.write_text(text)

print('Switched Halo trials to local Keychain enforcement')
