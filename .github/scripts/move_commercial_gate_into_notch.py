from pathlib import Path

root = Path('.')
app_path = root / 'Halo/App/HaloApp.swift'
router_path = root / 'Halo/Core/ExtensionContracts.swift'

# ---- AppDelegate: keep the notch shell alive while locking the real runtime ----
s = app_path.read_text()
start = s.index('    private var welcome: NSWindow?')
end = s.index('    @objc private func quit()', start)
replacement = '''    private var commercialBag = Set<AnyCancellable>()
    private var licensedServicesStarted = false

    private var commercialAccessGranted: Bool {
        HaloAccountManager.shared.isSignedIn && HaloLicenseManager.shared.state.isValid
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings), name: Notification.Name("HaloOpenSettings"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(toggle), name: Notification.Name("HaloToggle"), object: nil)
        configureCommercialAccessGate()

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "capsule.tophalf.filled", accessibilityDescription: "Halo")
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Halo", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let hudRoot = NSMenuItem(title: "HUD", action: nil, keyEquivalent: "")
        let hudMenu = NSMenu(title: "HUD")
        let hudSettingsItem = NSMenuItem(title: "HUD Settings…", action: #selector(openHUDSettings), keyEquivalent: "")
        hudSettingsItem.target = self
        hudMenu.addItem(hudSettingsItem)
        hudMenu.addItem(.separator())
        let previewVolume = NSMenuItem(title: "Preview Volume HUD", action: #selector(previewVolumeHUD), keyEquivalent: "")
        previewVolume.target = self
        hudMenu.addItem(previewVolume)
        let previewBrightness = NSMenuItem(title: "Preview Screen Brightness HUD", action: #selector(previewBrightnessHUD), keyEquivalent: "")
        previewBrightness.target = self
        hudMenu.addItem(previewBrightness)
        let previewKeyboard = NSMenuItem(title: "Preview Keyboard Brightness HUD", action: #selector(previewKeyboardHUD), keyEquivalent: "")
        previewKeyboard.target = self
        hudMenu.addItem(previewKeyboard)
        hudRoot.submenu = hudMenu
        menu.addItem(hudRoot)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Halo", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        status?.menu = menu
    }

    private func configureCommercialAccessGate() {
        // The panel/geometry engine is always alive. When access is unavailable the router renders
        // only the black locked notch and the sign-in/license flow; normal Halo content never runs.
        let manager = WindowManager(store: store)
        engine = manager
        manager.start()

        Publishers.CombineLatest(
            HaloAccountManager.shared.$isSignedIn.removeDuplicates(),
            HaloLicenseManager.shared.$state.removeDuplicates()
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in self?.refreshCommercialAccess() }
        .store(in: &commercialBag)

        Task { @MainActor [weak self] in
            await HaloAccountManager.shared.restore()
            await HaloLicenseManager.shared.restoreAndValidate()
            self?.refreshCommercialAccess()
        }
    }

    private func refreshCommercialAccess() {
        if commercialAccessGranted {
            startLicensedServices()
        } else {
            stopLicensedServices()
        }
    }

    private func startLicensedServices() {
        guard !licensedServicesStarted else { return }
        licensedServicesStarted = true
        store.workspace.start()
        let hud = HaloHUDController(audio: store.workspace.audio)
        hudController = hud
        hud.start()
    }

    private func stopLicensedServices() {
        guard licensedServicesStarted else { return }
        licensedServicesStarted = false
        hudController?.stop()
        hudController = nil
        store.workspace.stop()
    }

    @objc private func toggle() { engine?.toggleAll() }
'''
s = s[:start] + replacement + s[end:]
s = s.replace('''    @objc func openHUDSettings() {
        if hudSettings == nil {
''', '''    @objc func openHUDSettings() {
        guard commercialAccessGranted else { engine?.toggleAll(); return }
        if hudSettings == nil {
''', 1)
s = s.replace('''    func applicationWillTerminate(_ notification: Notification) {
        stopLicensedRuntime()
        store.flushConfiguration()
    }
}

@MainActor
private struct HaloCommercialWelcomeView: View {
''', '''    func applicationWillTerminate(_ notification: Notification) {
        stopLicensedServices()
        engine?.stop()
        engine = nil
        store.flushConfiguration()
    }
}

#if false
@MainActor
private struct HaloCommercialWelcomeView: View {
''', 1)
# Keep the previous standalone welcome implementation compiled out for the moment so this migration
# stays small and easy to remove after QA. Close the conditional immediately before HaloHUDKeys.
marker = '\nenum HaloHUDKeys {'
if marker not in s:
    raise SystemExit('HaloHUDKeys marker not found')
s = s.replace(marker, '\n#endif\n\nenum HaloHUDKeys {', 1)
app_path.write_text(s)

# ---- Surface router: locked content is the notch itself ----
s = router_path.read_text()
s = s.replace('''    @ObservedObject private var bluetooth = BluetoothStateService.shared
''', '''    @ObservedObject private var bluetooth = BluetoothStateService.shared
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared
''', 1)
s = s.replace('''    private var eiOwnsSurface: Bool {
        state.expanded && ownership.isRequested && eiSettings.settings.mode != .off && activeCI == nil
    }
''', '''    private var accessLocked: Bool {
        !account.isSignedIn || !license.state.isValid
    }

    private var eiOwnsSurface: Bool {
        !accessLocked && state.expanded && ownership.isRequested && eiSettings.settings.mode != .off && activeCI == nil
    }
''', 1)
old_body = '''    var body: some View {
        ZStack(alignment: .top) {
            SurfaceView(store: store, state: state, workspace: workspace)
                .opacity(eiOwnsSurface ? 0 : 1)
                .allowsHitTesting(!eiOwnsSurface)
                .accessibilityHidden(eiOwnsSurface)

            if eiOwnsSurface {
                EIOpenSurface(surfaceState: state)
                    .background(EISurfaceBackdrop(mode: eiSettings.settings.mode,
                                                  preferences: EIOpenPreferencesStore.shared.value,
                                                  environment: engine.environment))
                    .clipShape(contour)
                    .overlay(contour.stroke(Color.white.opacity(0.11), lineWidth: 1))
                    .contentShape(contour)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(20)

            }
        }
        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
        .clipped()
        .onAppear { updateAmbientSuppression(eiOwnsSurface) }
        .onChange(of: eiOwnsSurface) { active in updateAmbientSuppression(active) }
        .onDisappear { updateAmbientSuppression(false) }
    }
'''
new_body = '''    var body: some View {
        ZStack(alignment: .top) {
            if accessLocked {
                HaloLockedAccessSurface(surfaceState: state)
                    .clipShape(contour)
                    .contentShape(contour)
                    .transition(.opacity)
                    .zIndex(100)
            } else {
                SurfaceView(store: store, state: state, workspace: workspace)
                    .opacity(eiOwnsSurface ? 0 : 1)
                    .allowsHitTesting(!eiOwnsSurface)
                    .accessibilityHidden(eiOwnsSurface)

                if eiOwnsSurface {
                    EIOpenSurface(surfaceState: state)
                        .background(EISurfaceBackdrop(mode: eiSettings.settings.mode,
                                                      preferences: EIOpenPreferencesStore.shared.value,
                                                      environment: engine.environment))
                        .clipShape(contour)
                        .overlay(contour.stroke(Color.white.opacity(0.11), lineWidth: 1))
                        .contentShape(contour)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                        .zIndex(20)
                }
            }
        }
        .frame(width: viewport.size.width, height: viewport.size.height, alignment: .top)
        .clipped()
        .onAppear { updateAmbientSuppression(eiOwnsSurface) }
        .onChange(of: eiOwnsSurface) { active in updateAmbientSuppression(active) }
        .onDisappear { updateAmbientSuppression(false) }
    }
'''
if old_body not in s:
    raise SystemExit('HaloSurfaceRouter body not found')
s = s.replace(old_body, new_body, 1)

insert_marker = '// MARK: - Owned Environmental Interface\n'
locked_view = r'''// MARK: - Commercial lock surface

@MainActor
private struct HaloLockedAccessSurface: View {
    @ObservedObject var surfaceState: SurfaceState
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var licenseKey = ""
    @State private var creatingAccount = false

    private var preferredSize: CGSize { CGSize(width: 520, height: account.isSignedIn ? 360 : 390) }

    var body: some View {
        ZStack {
            Color.black

            if surfaceState.expanded {
                setupContent
                    .padding(.horizontal, 30)
                    .padding(.top, 24)
                    .padding(.bottom, 22)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .foregroundStyle(.white)
        .onHover { inside in surfaceState.hover(inside, enabled: true) }
        .onTapGesture {
            if !surfaceState.expanded { surfaceState.expanded = true }
        }
        .onAppear { publishPreferredSize() }
        .onChange(of: surfaceState.expanded) { _ in publishPreferredSize() }
        .onChange(of: account.isSignedIn) { _ in publishPreferredSize() }
        .onDisappear {
            if !account.isSignedIn || !license.state.isValid { surfaceState.contextPreferredSize = nil }
        }
    }

    private var setupContent: some View {
        VStack(spacing: 18) {
            header

            if !account.isSignedIn {
                accountStep
            } else if !license.state.isValid {
                licenseStep
            } else {
                ProgressView().controlSize(.small)
                Text("Unlocking Halo…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 0)
            Link("Need help? r.support@redstoneinvente.com",
                 destination: URL(string: "mailto:r.support@redstoneinvente.com")!)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
            Text(account.isSignedIn ? "Activate Halo" : "Welcome to Halo")
                .font(.system(size: 21, weight: .bold, design: .rounded))
            Text(account.isSignedIn
                 ? "Your account is ready. Activate a license to unlock the notch."
                 : "Sign in or create a Halo account to continue.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
    }

    private var accountStep: some View {
        VStack(spacing: 12) {
            Picker("Account", selection: $creatingAccount) {
                Text("Sign In").tag(false)
                Text("Create Account").tag(true)
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(creatingAccount ? "Create Account" : "Sign In") {
                    Task {
                        if creatingAccount {
                            await account.signUp(email: email, password: password)
                        } else {
                            await account.signIn(email: email, password: password)
                        }
                        if account.isSignedIn { password = "" }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(account.isBusy || email.isEmpty || password.isEmpty)

                if !creatingAccount {
                    Button("Forgot Password?") { Task { await account.resetPassword(email: email) } }
                        .disabled(account.isBusy || email.isEmpty)
                }

                if account.isBusy { ProgressView().controlSize(.small) }
            }

            commercialMessages(account.notice, account.errorMessage)
        }
        .frame(maxWidth: 430)
    }

    private var licenseStep: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.email.isEmpty ? "Signed in" : account.email)
                        .font(.system(size: 11, weight: .semibold))
                    Text(account.emailVerified ? "Email verified" : "Email not verified")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Spacer()
                if !account.emailVerified {
                    Button("Verify Email") { Task { await account.sendVerificationEmail() } }
                        .controlSize(.small)
                    Button("Refresh") { Task { await account.refreshVerificationStatus() } }
                        .controlSize(.small)
                }
                Button("Sign Out") { account.signOut() }
                    .controlSize(.small)
            }

            Divider().overlay(Color.white.opacity(0.15))

            HStack {
                Image(systemName: "key.horizontal")
                    .foregroundStyle(.white.opacity(0.65))
                Text("License")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(license.state.title)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.52))
            }

            SecureField("License key", text: $licenseKey)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Activate License") {
                    Task {
                        await license.activate(licenseKey)
                        if license.state.isValid { licenseKey = "" }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(license.isBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !license.licenseHint.isEmpty {
                    Button("Validate Existing") { Task { await license.validate() } }
                        .disabled(license.isBusy)
                    Button("Clear", role: .destructive) { license.clearLocalLicense() }
                        .disabled(license.isBusy)
                }

                if license.isBusy { ProgressView().controlSize(.small) }
            }

            commercialMessages(license.notice, license.errorMessage)
        }
        .frame(maxWidth: 450)
    }

    @ViewBuilder
    private func commercialMessages(_ notice: String?, _ error: String?) -> some View {
        if let notice {
            Text(notice).font(.system(size: 9)).foregroundStyle(.white.opacity(0.58))
        }
        if let error {
            Text(error).font(.system(size: 9)).foregroundStyle(.red.opacity(0.92))
                .multilineTextAlignment(.center)
        }
    }

    private func publishPreferredSize() {
        surfaceState.contextPreferredSize = surfaceState.expanded ? preferredSize : nil
    }
}

'''
if insert_marker not in s:
    raise SystemExit('EI marker not found')
s = s.replace(insert_marker, locked_view + insert_marker, 1)
router_path.write_text(s)

print('Moved commercial access flow into black locked notch')
