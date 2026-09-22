import SwiftUI
import Combine
import AppKit

@MainActor
final class AppStoreSubscriptionGateModel: ObservableObject {
    @Published private(set) var state: AppStoreEntitlementState
    @Published private(set) var products: [AppStoreProductInfo]
    @Published private(set) var isBusy = false
    @Published var message: String?

    private let licensing: any AppStoreLicensing
    private var bag = Set<AnyCancellable>()

    init(licensing: any AppStoreLicensing = AppStoreLicensingProvider.shared) {
        self.licensing = licensing
        self.state = licensing.state
        self.products = licensing.products

        licensing.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &bag)

        licensing.productsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] products in
                self?.products = products
            }
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
                    message = "Purchase verified. Unlocking Halo…"
                case .pending:
                    message = "The purchase is pending approval. Halo will unlock automatically when Apple completes it."
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

struct AppStoreSubscriptionGateView: View {
    @StateObject private var model = AppStoreSubscriptionGateModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 4)

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 76, height: 76)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }

            content

            if let message = model.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            HStack(spacing: 12) {
                Button("Restore Purchases") {
                    model.restore()
                }
                .disabled(model.isBusy)

                Button("Check Again") {
                    model.refresh()
                }
                .disabled(model.isBusy)
            }

            Text("Purchases are handled by the App Store.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 4)
        }
        .padding(34)
        .frame(minWidth: 560, minHeight: 480)
    }

    private var title: String {
        switch model.state {
        case .billingRetry:
            return "Subscription Billing Issue"
        case .revoked:
            return "Subscription No Longer Active"
        case .failed:
            return "Unable to Check Subscription"
        case .notConfigured:
            return "App Store Purchase Unavailable"
        default:
            return "Unlock Halo"
        }
    }

    private var subtitle: String {
        switch model.state {
        case .billingRetry:
            return "Apple is retrying your subscription payment. Halo will unlock automatically when the subscription becomes active again."
        case .revoked:
            return "The App Store reports that access to this Halo subscription has been revoked."
        case .failed(let message):
            return message
        case .notConfigured:
            return "Halo could not find its App Store purchase options. Check the App Store build configuration."
        case .loading:
            return "Checking your App Store purchases…"
        case .notEntitled:
            return "A Halo subscription or lifetime purchase is required to use this App Store version."
        case .entitled, .gracePeriod:
            return entitlementSubtitle
        }
    }

    private var entitlementSubtitle: String {
        let productIDs: Set<String>
        switch model.state {
        case .entitled(let ids), .gracePeriod(let ids, _):
            productIDs = ids
        default:
            return "Your Halo purchase is active. Halo is unlocking…"
        }

        let names = productIDs.sorted().map { productID in
            if let product = model.products.first(where: { $0.id == productID }) {
                return product.displayName
            }

            switch productID {
            case "Halo_Lifetime":
                return "Halo Lifetime"
            case "halo_monthly":
                return "Halo Monthly"
            default:
                return productID
            }
        }

        if names.count == 1, let name = names.first {
            return "\(name) is active. Halo is unlocking…"
        } else if !names.isEmpty {
            return "\(names.joined(separator: " + ")) are active. Halo is unlocking…"
        }

        return "Your Halo purchase is active. Halo is unlocking…"
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(height: 78)

        case .entitled, .gracePeriod:
            ProgressView()
                .controlSize(.large)
                .frame(height: 78)

        default:
            if model.products.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No purchase options are currently available.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 96)
            } else {
                VStack(spacing: 10) {
                    ForEach(model.products) { product in
                        Button {
                            model.purchase(product)
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
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy)
                    }
                }
                .frame(maxWidth: 470)
            }
        }
    }
}
