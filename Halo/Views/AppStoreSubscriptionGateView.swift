import SwiftUI
import Combine
import AppKit

@MainActor
final class AppStoreSubscriptionGateModel: ObservableObject {
    @Published private(set) var state: AppStoreEntitlementState
    @Published private(set) var products: [AppStoreProductInfo]
    @Published private(set) var primaryProductID: String?
    @Published private(set) var isBusy = false
    @Published var message: String?

    private let licensing: any AppStoreLicensing
    private var bag = Set<AnyCancellable>()

    init(licensing: any AppStoreLicensing = AppStoreLicensingProvider.shared) {
        self.licensing = licensing
        self.state = licensing.state
        self.products = licensing.products
        self.primaryProductID = licensing.primaryProductID

        licensing.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.state = state }
            .store(in: &bag)

        licensing.productsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] products in self?.products = products }
            .store(in: &bag)

        licensing.primaryProductIDPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] productID in self?.primaryProductID = productID }
            .store(in: &bag)
    }

    func refresh() {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            await licensing.refresh()
            isBusy = false
        }
    }

    func purchase(_ product: AppStoreProductInfo) {
        guard !isBusy else { return }
        isBusy = true
        message = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isBusy = false }

            do {
                switch try await licensing.purchase(productID: product.id) {
                case .purchased:
                    message = "Purchase verified. Unlocking Halo Full…"
                case .pending:
                    message = "The purchase is pending approval. Halo Full will unlock automatically when Apple completes it."
                case .cancelled:
                    message = nil
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func restore() {
        guard !isBusy else { return }
        isBusy = true
        message = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isBusy = false }

            do {
                try await licensing.restorePurchases()
                if !licensing.state.grantsAccess {
                    message = "No active Halo purchase was found for this Apple Account."
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }
}

/// Shared access / upgrade presentation for both Halo distributions.
///
/// StoreKit remains entirely inside the App Store path. Direct builds reuse the
/// existing Halo account + LicenseSeat managers instead of introducing a second
/// licensing implementation.
@MainActor
struct HaloAccessView: View {
    let allowsLiteEntry: Bool
    let onStartLite: () -> Void

    @StateObject private var appStoreModel = AppStoreSubscriptionGateModel()
    @ObservedObject private var account = HaloAccountManager.shared
    @ObservedObject private var license = HaloLicenseManager.shared

    @State private var directLicenseExpanded = false
    @State private var creatingAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var licenseKey = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 76, height: 76)

                VStack(spacing: 8) {
                    Text("Halo")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Use Halo Lite for free, or unlock Halo Full for the complete experience.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 470)
                }

                if allowsLiteEntry {
                    Button("Start Lite") {
                        onStartLite()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 320)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Rectangle().fill(Color.secondary.opacity(0.22)).frame(height: 1)
                        Text("UNLOCK HALO FULL")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.22)).frame(height: 1)
                    }

                    switch HaloDistribution.current {
                    case .appStore:
                        appStorePurchaseContent
                    case .direct:
                        directPurchaseContent
                    }
                }
                .frame(maxWidth: 500)

                Spacer(minLength: 4)
            }
            .padding(34)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 580, minHeight: 520)
        .task {
            if HaloDistribution.current == .appStore {
                appStoreModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var appStorePurchaseContent: some View {
        if appStoreModel.products.isEmpty {
            if case .loading = appStoreModel.state {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: 76)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cart")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No App Store purchase options are currently available.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Check Again") { appStoreModel.refresh() }
                        .disabled(appStoreModel.isBusy)
                }
                .frame(minHeight: 96)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(appStoreModel.products) { product in
                    Button {
                        appStoreModel.purchase(product)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(product.displayName)
                                    .font(.headline)
                                if !product.description.isEmpty {
                                    Text(product.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 12)
                            Text(product.displayPrice)
                                .font(.headline)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(appStoreModel.isBusy)
                }
            }
        }

        if let message = appStoreModel.message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }

        HStack(spacing: 12) {
            Button("Restore Purchases") {
                appStoreModel.restore()
            }
            .disabled(appStoreModel.isBusy)

            if appStoreModel.isBusy {
                ProgressView().controlSize(.small)
            }
        }

        Text("Purchases are handled securely by the App Store.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private var directPurchaseContent: some View {
        VStack(spacing: 12) {
            Button("Purchase Halo") {
                guard let url = URL(string: "https://halo.redstoneinvente.com") else { return }
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button(directLicenseExpanded ? "Hide License Entry" : "Enter License Key") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    directLicenseExpanded.toggle()
                }
            }
            .buttonStyle(.borderedProminent)

            if directLicenseExpanded {
                directActivationContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var directActivationContent: some View {
        VStack(spacing: 12) {
            if !account.isSignedIn {
                Picker("Halo Account", selection: $creatingAccount) {
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
                            if account.isSignedIn {
                                password = ""
                                await license.restoreAndValidate()
                            }
                        }
                    }
                    .disabled(account.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                    if !creatingAccount {
                        Button("Forgot Password?") {
                            Task { await account.resetPassword(email: email) }
                        }
                        .disabled(account.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if account.isBusy { ProgressView().controlSize(.small) }
                }

                commercialMessages(account.notice, account.errorMessage)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.email.isEmpty ? "Halo Account" : account.email)
                            .font(.callout.weight(.semibold))
                        Text(account.emailVerified ? "Signed in · Verified" : "Signed in")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign Out") { account.signOut() }
                        .controlSize(.small)
                }

                SecureField("License key", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Activate License") {
                        let key = licenseKey
                        Task {
                            await license.activate(key)
                            if license.state.isValid { licenseKey = "" }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(license.isBusy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !license.licenseHint.isEmpty {
                        Button("Validate Existing") {
                            Task { await license.restoreAndValidate() }
                        }
                        .disabled(license.isBusy)
                    }

                    if license.isBusy {
                        ProgressView().controlSize(.small)
                    }
                }

                if license.state.isValid {
                    Label("Halo Full entitlement verified. Unlocking…", systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                commercialMessages(license.notice, license.errorMessage)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func commercialMessages(_ notice: String?, _ error: String?) -> some View {
        if let notice {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
    }
}

/// Compatibility wrapper for call sites that still reference the historical App Store
/// gate by name. New startup and upgrade flows should present HaloAccessView directly.
struct AppStoreSubscriptionGateView: View {
    var body: some View {
        HaloAccessView(allowsLiteEntry: false, onStartLite: {})
    }
}
