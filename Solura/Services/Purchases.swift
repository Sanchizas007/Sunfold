import Foundation
import RevenueCat

/// A purchasable plan, flattened out of whatever the billing backend calls it.
///
/// Views only ever see this type, which is what makes the app runnable today
/// without a RevenueCat account: swap the provider, keep the UI.
nonisolated struct SoluraProduct: Identifiable, Equatable, Sendable {
    enum Term: String, Sendable {
        case monthly, yearly, lifetime
    }

    var id: String
    var term: Term
    /// Already localised and currency-formatted by StoreKit.
    var displayPrice: String
    /// "$2.08 / month" for the yearly plan — nil when there is nothing to
    /// compare against.
    var perMonthPrice: String?
    /// Percent saved against the monthly plan, for the yearly badge.
    var savingsPercent: Int?
}

nonisolated protocol PurchaseProviding: AnyObject, Sendable {
    func configure()
    func isProActive() async -> Bool
    func loadProducts() async -> [SoluraProduct]
    /// Returns true when the user ends up entitled.
    func purchase(id: String) async throws -> Bool
    func restore() async throws -> Bool
}

nonisolated enum PurchaseError: LocalizedError {
    case cancelled
    case productUnavailable
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .cancelled: nil
        case .productUnavailable: String(localized: "paywall.error.unavailable")
        case .notConfigured: String(localized: "paywall.error.notConfigured")
        }
    }
}

// MARK: - RevenueCat

/// Product identifiers as they must be created in App Store Connect, and the
/// entitlement identifier as it must be created in RevenueCat.
nonisolated enum StoreIDs {
    static let monthly = "app.solura.pro.monthly"
    static let yearly = "app.solura.pro.yearly"
    static let lifetime = "app.solura.pro.lifetime"
    static let entitlement = "pro"
}

final class RevenueCatProvider: PurchaseProviding, @unchecked Sendable {
    private let apiKey: String
    private var configured = false
    /// RevenueCat packages, kept so a purchase can be made from a product id.
    private var packages: [String: Package] = [:]

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func configure() {
        guard !configured, !apiKey.isEmpty else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        configured = true
    }

    func isProActive() async -> Bool {
        guard configured else { return false }
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return info.entitlements[StoreIDs.entitlement]?.isActive == true
    }

    func loadProducts() async -> [SoluraProduct] {
        guard configured else { return [] }
        guard
            let offerings = try? await Purchases.shared.offerings(),
            let current = offerings.current
        else { return [] }

        packages = Dictionary(
            uniqueKeysWithValues: current.availablePackages.map { ($0.storeProduct.productIdentifier, $0) }
        )

        let monthlyPrice = current.availablePackages
            .first { $0.storeProduct.productIdentifier == StoreIDs.monthly }?
            .storeProduct.price

        return current.availablePackages.compactMap { package in
            let store = package.storeProduct
            guard let term = Self.term(for: store.productIdentifier) else { return nil }

            var perMonth: String?
            var savings: Int?
            if term == .yearly {
                let monthlyEquivalent = store.price / 12
                perMonth = Self.priceString(monthlyEquivalent, like: store)
                if let monthlyPrice, monthlyPrice > 0 {
                    let ratio = 1 - (monthlyEquivalent as NSDecimalNumber).doubleValue
                        / (monthlyPrice as NSDecimalNumber).doubleValue
                    savings = max(0, Int((ratio * 100).rounded()))
                }
            }

            return SoluraProduct(
                id: store.productIdentifier,
                term: term,
                displayPrice: store.localizedPriceString,
                perMonthPrice: perMonth,
                savingsPercent: savings
            )
        }
        .sorted { lhs, rhs in Self.order(lhs.term) < Self.order(rhs.term) }
    }

    func purchase(id: String) async throws -> Bool {
        guard configured else { throw PurchaseError.notConfigured }
        guard let package = packages[id] else { throw PurchaseError.productUnavailable }
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled { throw PurchaseError.cancelled }
        return result.customerInfo.entitlements[StoreIDs.entitlement]?.isActive == true
    }

    func restore() async throws -> Bool {
        guard configured else { throw PurchaseError.notConfigured }
        let info = try await Purchases.shared.restorePurchases()
        return info.entitlements[StoreIDs.entitlement]?.isActive == true
    }

    private static func term(for productID: String) -> SoluraProduct.Term? {
        switch productID {
        case StoreIDs.monthly: .monthly
        case StoreIDs.yearly: .yearly
        case StoreIDs.lifetime: .lifetime
        default: nil
        }
    }

    private static func order(_ term: SoluraProduct.Term) -> Int {
        switch term {
        case .yearly: 0
        case .monthly: 1
        case .lifetime: 2
        }
    }

    private static func priceString(_ amount: Decimal, like product: StoreProduct) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = product.currencyCode
        formatter.locale = .current
        return formatter.string(from: amount as NSDecimalNumber)
    }
}

// MARK: - Offline / pre-account provider

/// Stands in for the store while there is no RevenueCat key in the build, and
/// in SwiftUI previews.
///
/// It shows the real prices from the pricing plan so the paywall can be designed
/// and reviewed, and refuses to "sell" anything — a purchase attempt fails with
/// a clear message rather than silently unlocking Pro.
final class UnconfiguredPurchaseProvider: PurchaseProviding, @unchecked Sendable {
    func configure() {}

    func isProActive() async -> Bool { false }

    func loadProducts() async -> [SoluraProduct] {
        [
            SoluraProduct(
                id: StoreIDs.yearly,
                term: .yearly,
                displayPrice: "$24.99",
                perMonthPrice: "$2.08",
                savingsPercent: 58
            ),
            SoluraProduct(id: StoreIDs.monthly, term: .monthly, displayPrice: "$4.99"),
            SoluraProduct(id: StoreIDs.lifetime, term: .lifetime, displayPrice: "$49.99")
        ]
    }

    func purchase(id: String) async throws -> Bool {
        throw PurchaseError.notConfigured
    }

    func restore() async throws -> Bool {
        throw PurchaseError.notConfigured
    }
}
