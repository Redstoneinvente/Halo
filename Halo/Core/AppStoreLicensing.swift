import Foundation
import StoreKit

struct AppStoreProductInfo: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
}

enum AppStoreEntitlementState: Equatable, Sendable {
    case notConfigured
    case loading
    case notEntitled
    case entitled(productIDs: Set<String>)
    case failed(message: String)

    var isEntitled: Bool {
        if case .entitled = self { return true }
        return false
    }
}

enum AppStorePurchaseOutcome: Equatable, Sendable {
    case purchased(productID: String)
    case pending
    case cancelled
}

enum AppStoreLicensingError: LocalizedError, Equatable {
    case unavailableForDistribution
    case productNotConfigured(String)
    case unverifiedTransaction
    case unknownPurchaseResult

    var errorDescription: String? {
        switch self {
        case .unavailableForDistribution:
            return "StoreKit licensing is unavailable for this Halo distribution."
        case .productNotConfigured(let productID):
            return "The App Store product \(productID) is not configured."
        case .unverifiedTransaction:
            return "The App Store transaction could not be verified."
        case .unknownPurchaseResult:
            return "The App Store returned an unknown purchase result."
        }
    }
}

/// Boundary between Halo and StoreKit.
///
/// Callers should depend on this interface instead of importing StoreKit or inspecting
/// App Store transactions directly. Direct-distribution licensing remains independent.
@MainActor
protocol AppStoreLicensing: AnyObject {
    var state: AppStoreEntitlementState { get }
    var products: [AppStoreProductInfo] { get }
    var isEntitled: Bool { get }

    func start()
    func stop()
    func refresh() async
    func purchase(productID: String) async throws -> AppStorePurchaseOutcome
    func restorePurchases() async throws
}

@MainActor
enum AppStoreLicensingProvider {
    static let shared: any AppStoreLicensing = StoreKitAppStoreLicensing.shared
}

enum AppStoreLicensingConfiguration {
    static var productIDs: Set<String> {
        if let values = Bundle.main.object(forInfoDictionaryKey: "HaloAppStoreProductIDs") as? [String] {
            let normalized = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !normalized.isEmpty { return Set(normalized) }
        }

        if let raw = ProcessInfo.processInfo.environment["HALO_APPSTORE_PRODUCT_IDS"] {
            let normalized = raw
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !normalized.isEmpty { return Set(normalized) }
        }

        return []
    }
}

/// StoreKit 2 implementation of Halo's App Store licensing boundary.
///
/// This object intentionally does not decide whether Halo should block launch when no
/// entitlement exists. It only reports StoreKit state and performs StoreKit operations.
@MainActor
private final class StoreKitAppStoreLicensing: ObservableObject, AppStoreLicensing {
    static let shared = StoreKitAppStoreLicensing()

    @Published private(set) var state: AppStoreEntitlementState = .notConfigured
    @Published private(set) var products: [AppStoreProductInfo] = []

    var isEntitled: Bool { state.isEntitled }

    private let configuredProductIDs: Set<String>
    private var storeProducts: [String: Product] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?

    init(productIDs: Set<String> = AppStoreLicensingConfiguration.productIDs) {
        configuredProductIDs = productIDs
    }

    func start() {
        guard HaloDistribution.current.supportsAppStoreLicensing else {
            state = .notConfigured
            return
        }
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let self else { return }

                switch result {
                case .verified(let transaction):
                    guard self.configuredProductIDs.contains(transaction.productID) else { continue }
                    await transaction.finish()
                    await self.refreshEntitlements()
                case .unverified:
                    continue
                }
            }
        }

        Task { [weak self] in
            await self?.refresh()
        }
    }

    func stop() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = nil
    }

    func refresh() async {
        guard HaloDistribution.current.supportsAppStoreLicensing else {
            state = .notConfigured
            products = []
            storeProducts = [:]
            return
        }
        guard !configuredProductIDs.isEmpty else {
            state = .notConfigured
            products = []
            storeProducts = [:]
            return
        }

        state = .loading

        do {
            let loadedProducts = try await Product.products(for: Array(configuredProductIDs))
            storeProducts = Dictionary(uniqueKeysWithValues: loadedProducts.map { ($0.id, $0) })
            products = loadedProducts
                .map {
                    AppStoreProductInfo(
                        id: $0.id,
                        displayName: $0.displayName,
                        description: $0.description,
                        displayPrice: $0.displayPrice
                    )
                }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            await refreshEntitlements()
        } catch {
            storeProducts = [:]
            products = []
            state = .failed(message: error.localizedDescription)
        }
    }

    func purchase(productID: String) async throws -> AppStorePurchaseOutcome {
        guard HaloDistribution.current.supportsAppStoreLicensing else {
            throw AppStoreLicensingError.unavailableForDistribution
        }
        guard configuredProductIDs.contains(productID) else {
            throw AppStoreLicensingError.productNotConfigured(productID)
        }

        if storeProducts[productID] == nil {
            await refresh()
        }
        guard let product = storeProducts[productID] else {
            throw AppStoreLicensingError.productNotConfigured(productID)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw AppStoreLicensingError.unverifiedTransaction
            }
            await transaction.finish()
            await refreshEntitlements()
            return .purchased(productID: transaction.productID)

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            throw AppStoreLicensingError.unknownPurchaseResult
        }
    }

    func restorePurchases() async throws {
        guard HaloDistribution.current.supportsAppStoreLicensing else {
            throw AppStoreLicensingError.unavailableForDistribution
        }
        try await StoreKit.AppStore.sync()
        await refresh()
    }

    private func refreshEntitlements() async {
        var entitledProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  configuredProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }

            entitledProductIDs.insert(transaction.productID)
        }

        state = entitledProductIDs.isEmpty
            ? .notEntitled
            : .entitled(productIDs: entitledProductIDs)
    }
}
