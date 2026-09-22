import Foundation
import Combine
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
    case gracePeriod(productIDs: Set<String>, expiresAt: Date?)
    case billingRetry(productIDs: Set<String>)
    case revoked
    case failed(message: String)

    var grantsAccess: Bool {
        switch self {
        case .entitled, .gracePeriod:
            return true
        case .notConfigured, .loading, .notEntitled, .billingRetry, .revoked, .failed:
            return false
        }
    }

    var isEntitled: Bool { grantsAccess }
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
    var primaryProductID: String? { get }
    var isEntitled: Bool { get }
    var statePublisher: AnyPublisher<AppStoreEntitlementState, Never> { get }
    var productsPublisher: AnyPublisher<[AppStoreProductInfo], Never> { get }
    var primaryProductIDPublisher: AnyPublisher<String?, Never> { get }

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
/// StoreKit remains private to this file. Halo consumes only AppStoreLicensing state,
/// products and actions.
@MainActor
private final class StoreKitAppStoreLicensing: ObservableObject, AppStoreLicensing {
    static let shared = StoreKitAppStoreLicensing()

    @Published private(set) var state: AppStoreEntitlementState = .notConfigured
    @Published private(set) var products: [AppStoreProductInfo] = []
    @Published private(set) var primaryProductID: String?

    var isEntitled: Bool { state.grantsAccess }
    var statePublisher: AnyPublisher<AppStoreEntitlementState, Never> {
        $state.eraseToAnyPublisher()
    }
    var productsPublisher: AnyPublisher<[AppStoreProductInfo], Never> {
        $products.eraseToAnyPublisher()
    }
    var primaryProductIDPublisher: AnyPublisher<String?, Never> {
        $primaryProductID.eraseToAnyPublisher()
    }

    private struct TransactionEntitlements {
        let productIDs: Set<String>
        let primaryProductID: String?
        let primaryPurchaseDate: Date?
    }

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
                    await self.refresh()
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
            primaryProductID = nil
            storeProducts = [:]
            return
        }
        guard !configuredProductIDs.isEmpty else {
            state = .notConfigured
            products = []
            primaryProductID = nil
            storeProducts = [:]
            return
        }

        if !state.grantsAccess {
            state = .loading
        }

        // Transaction.currentEntitlements is available independently of product
        // merchandising. Use it first so a temporary product-loading/network failure
        // does not lock out an already entitled customer.
        let transactionEntitlements = await currentTransactionEntitlements()
        primaryProductID = transactionEntitlements.primaryProductID
        if !transactionEntitlements.productIDs.isEmpty {
            state = .entitled(productIDs: transactionEntitlements.productIDs)
        }

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

            await refreshEntitlements(
                using: loadedProducts,
                transactionEntitlements: transactionEntitlements
            )
        } catch {
            storeProducts = [:]
            products = []
            if transactionEntitlements.productIDs.isEmpty {
                primaryProductID = nil
                state = .failed(message: error.localizedDescription)
            } else {
                primaryProductID = transactionEntitlements.primaryProductID
                state = .entitled(productIDs: transactionEntitlements.productIDs)
            }
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
            primaryProductID = transaction.productID
            await refresh()
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

    private func currentTransactionEntitlements() async -> TransactionEntitlements {
        var entitledProductIDs = Set<String>()
        var primaryProductID: String?
        var primaryPurchaseDate: Date?
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  configuredProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }

            if let expirationDate = transaction.expirationDate, expirationDate <= now {
                continue
            }

            entitledProductIDs.insert(transaction.productID)

            if primaryPurchaseDate == nil || transaction.purchaseDate > primaryPurchaseDate! {
                primaryProductID = transaction.productID
                primaryPurchaseDate = transaction.purchaseDate
            }
        }

        return TransactionEntitlements(
            productIDs: entitledProductIDs,
            primaryProductID: primaryProductID,
            primaryPurchaseDate: primaryPurchaseDate
        )
    }

    private func refreshEntitlements(
        using loadedProducts: [Product],
        transactionEntitlements: TransactionEntitlements
    ) async {
        var entitledProductIDs = transactionEntitlements.productIDs
        var selectedPrimaryProductID = transactionEntitlements.primaryProductID
        var selectedPrimaryPurchaseDate = transactionEntitlements.primaryPurchaseDate
        var graceProductIDs = Set<String>()
        var billingRetryProductIDs = Set<String>()
        var latestGraceExpiration: Date?
        var sawRevokedSubscription = false

        for product in loadedProducts {
            guard let subscription = product.subscription else { continue }

            do {
                let statuses = try await subscription.status
                for status in statuses {
                    let transaction: Transaction?
                    switch status.transaction {
                    case .verified(let verified):
                        transaction = verified
                    case .unverified:
                        transaction = nil
                    }

                    guard let transaction,
                          configuredProductIDs.contains(transaction.productID) else { continue }

                    if status.state == .subscribed {
                        guard transaction.revocationDate == nil,
                              !transaction.isUpgraded else { continue }
                        if let expirationDate = transaction.expirationDate,
                           expirationDate <= Date() {
                            continue
                        }
                        entitledProductIDs.insert(transaction.productID)
                        if selectedPrimaryPurchaseDate == nil || transaction.purchaseDate > selectedPrimaryPurchaseDate! {
                            selectedPrimaryProductID = transaction.productID
                            selectedPrimaryPurchaseDate = transaction.purchaseDate
                        }
                    } else if status.state == .inGracePeriod {
                        guard transaction.revocationDate == nil,
                              !transaction.isUpgraded else { continue }
                        graceProductIDs.insert(transaction.productID)
                        if selectedPrimaryPurchaseDate == nil || transaction.purchaseDate > selectedPrimaryPurchaseDate! {
                            selectedPrimaryProductID = transaction.productID
                            selectedPrimaryPurchaseDate = transaction.purchaseDate
                        }
                        if case .verified(let renewalInfo) = status.renewalInfo,
                           let graceExpiration = renewalInfo.gracePeriodExpirationDate {
                            if latestGraceExpiration == nil || graceExpiration > latestGraceExpiration! {
                                latestGraceExpiration = graceExpiration
                            }
                        }
                    } else if status.state == .inBillingRetryPeriod {
                        billingRetryProductIDs.insert(transaction.productID)
                    } else if status.state == .revoked {
                        sawRevokedSubscription = true
                    }
                }
            } catch {
                // currentEntitlements above remains the authoritative fallback if
                // subscription-status merchandising temporarily fails.
                continue
            }
        }

        if !entitledProductIDs.isEmpty {
            primaryProductID = selectedPrimaryProductID
            state = .entitled(productIDs: entitledProductIDs)
        } else if !graceProductIDs.isEmpty {
            primaryProductID = selectedPrimaryProductID
            state = .gracePeriod(productIDs: graceProductIDs, expiresAt: latestGraceExpiration)
        } else if !billingRetryProductIDs.isEmpty {
            primaryProductID = nil
            state = .billingRetry(productIDs: billingRetryProductIDs)
        } else if sawRevokedSubscription {
            primaryProductID = nil
            state = .revoked
        } else {
            primaryProductID = nil
            state = .notEntitled
        }
    }
}
