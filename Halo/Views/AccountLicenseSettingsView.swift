import SwiftUI

@MainActor
struct AccountLicenseSettingsView: View {
    @ObservedObject private var manager = HaloAccountLicenseManager.shared
    private let updates = HaloUpdateController.shared

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var editedDisplayName = ""
    @State private var licenseKey = ""
    @State private var showingDeleteAccountConfirmation = false
    @State private var automaticallyChecksForUpdates = false
    @State private var automaticallyDownloadsUpdates = false

    private enum AuthMode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case create = "Create Account"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            accountSection
            licenseSection
            softwareUpdateSection
            statusSection
        }
        .task {
            manager.start()
            refreshUpdatePreferences()
        }
        .confirmationDialog(
            "Delete your Halo account?",
            isPresented: $showingDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task { await manager.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the Firebase account. It does not automatically cancel or delete a LicenseSeat purchase or license key.")
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Halo Account") {
            if !manager.firebaseConfigured {
                Label("Firebase setup required", systemImage: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                Text("Add your Firebase GoogleService-Info.plist to the Halo app target. Until then, account sign-in remains disabled and the rest of Halo keeps working normally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let account = manager.account {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(account.displayName.isEmpty ? "Halo Account" : account.displayName)
                            .font(.headline)
                        Text(account.email.isEmpty ? account.uid : account.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(account.emailVerified ? "Verified" : "Unverified",
                          systemImage: account.emailVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(account.emailVerified ? .green : .orange)
                        .font(.caption)
                }

                TextField("Display name", text: $editedDisplayName)
                    .onAppear { editedDisplayName = account.displayName }
                    .onChange(of: account.displayName) { editedDisplayName = $0 }

                HStack {
                    Button("Save Name") {
                        Task { await manager.updateDisplayName(editedDisplayName) }
                    }
                    .disabled(manager.isBusy || editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) == account.displayName)

                    if !account.emailVerified {
                        Button("Resend Verification") {
                            Task { await manager.resendVerificationEmail() }
                        }
                        Button("Refresh") {
                            Task { await manager.reloadAccount() }
                        }
                    }
                    Spacer()
                    Button("Sign Out") { manager.signOut() }
                }

                DisclosureGroup("Account details") {
                    LabeledContent("Firebase UID", value: account.uid)
                        .textSelection(.enabled)
                    Text("Your Halo login is provided by Firebase Authentication. Licensing is handled separately by LicenseSeat so a signed-in account and an activated device can be managed independently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Delete Firebase Account", role: .destructive) {
                        showingDeleteAccountConfirmation = true
                    }
                }
            } else {
                Picker("Account", selection: $mode) {
                    ForEach(AuthMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .disableAutocorrection(true)

                SecureField("Password", text: $password)
                    .textContentType(mode == .create ? .newPassword : .password)

                if mode == .create {
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                    SecureField("Confirm password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }

                HStack {
                    Button(mode == .signIn ? "Sign In" : "Create Account") {
                        Task {
                            if mode == .signIn {
                                await manager.signIn(email: email, password: password)
                            } else if password == confirmPassword {
                                await manager.createAccount(email: email, password: password, displayName: displayName)
                            } else {
                                manager.errorMessage = "Passwords do not match."
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manager.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || (mode == .create && password != confirmPassword))

                    if mode == .signIn {
                        Button("Forgot Password?") {
                            Task { await manager.sendPasswordReset(email: email) }
                        }
                        .disabled(manager.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var licenseSection: some View {
        Section("License") {
            HStack {
                Label(manager.licenseState.title,
                      systemImage: manager.isLicensed ? "checkmark.shield.fill" : "key.horizontal")
                    .foregroundStyle(manager.isLicensed ? .green : .primary)
                Spacer()
                Link("LicenseSeat", destination: URL(string: "https://licenseseat.com")!)
                    .font(.caption)
            }

            switch manager.licenseState {
            case .notConfigured(let message):
                Text(message)
                    .foregroundStyle(.secondary)
                Text("Use a LicenseSeat publishable pk_* key in the Mac app. Keep sk_* secret keys on a trusted backend only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .inactive(let message):
                Text(message).font(.caption).foregroundStyle(.secondary)
                activationControls

            case .pending(let message):
                HStack {
                    ProgressView().controlSize(.small)
                    Text(message)
                }

            case .invalid(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                activationControls

            case .active(let maskedKey, let offline):
                LabeledContent("License", value: maskedKey)
                LabeledContent("Mode", value: offline ? "Signed offline grant" : "Online validated")
                if let next = manager.nextLicenseValidation {
                    LabeledContent("Next check", value: next.formatted(date: .abbreviated, time: .shortened))
                }
                HStack {
                    Button("Check Now") { Task { await manager.validateLicenseNow() } }
                        .disabled(manager.isBusy)
                    Button("Deactivate This Mac", role: .destructive) {
                        Task { await manager.deactivateLicense() }
                    }
                    .disabled(manager.isBusy)
                }
                Text("Halo accepts LicenseSeat's signed offline grant for up to 7 days between successful online checks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var softwareUpdateSection: some View {
        Section("Software Update") {
            HStack(spacing: 12) {
                Image(systemName: updates.isConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(updates.isConfigured ? .green : .orange)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Halo \(updates.currentVersion)")
                        .font(.headline)
                    Text("Build \(updates.currentBuild)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Check for Updates") {
                    updates.checkForUpdates()
                    refreshUpdatePreferences()
                }
                .disabled(updates.isConfigured && !updates.canCheckForUpdates)
            }

            if updates.isConfigured {
                Label("Secure updates are handled by Sparkle 2.", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .onChange(of: automaticallyChecksForUpdates) { value in
                        updates.setAutomaticallyChecksForUpdates(value)
                    }

                Toggle("Automatically download updates", isOn: $automaticallyDownloadsUpdates)
                    .onChange(of: automaticallyDownloadsUpdates) { value in
                        updates.setAutomaticallyDownloadsUpdates(value)
                    }

                if let lastCheck = updates.lastUpdateCheckDate {
                    LabeledContent("Last checked", value: lastCheck.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
            } else {
                Text("Halo's update feed or signing key is not configured in this build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("What's New") {
                    HaloWhatsNewCoordinator.shared.present()
                }

                Spacer()

                Text("Release notes are also shown by Sparkle when a new version is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("License key", text: $licenseKey)
                .textContentType(.oneTimeCode)
            Button("Activate Halo") {
                let key = licenseKey
                licenseKey = ""
                Task { await manager.activateLicense(key) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.isBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func refreshUpdatePreferences() {
        guard updates.isConfigured else { return }
        automaticallyChecksForUpdates = updates.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updates.automaticallyDownloadsUpdates
    }

    @ViewBuilder
    private var statusSection: some View {
        if manager.isBusy || manager.notice != nil || manager.errorMessage != nil {
            Section {
                if manager.isBusy {
                    HStack { ProgressView().controlSize(.small); Text("Working…") }
                }
                if let notice = manager.notice {
                    Label(notice, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let error = manager.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
