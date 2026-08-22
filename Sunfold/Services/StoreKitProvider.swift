import Foundation
import StoreKit

/// Buys directly through StoreKit 2, with no billing backend in between.
///
/// This exists so the paywall, the purchase flow, restore and the feature gates
/// can all be exercised **before** an Apple Developer account exists: pointed at
/// `Config/Sunfold.storekit`, the whole thing runs in the simulator against fake
/// products, and nothing is charged.
///
/// It is used in debug builds only. Release builds go through RevenueCat, or —
/// if the key is missing — refuse to transact rather than quietly selling
/// outside the system that is supposed to be recording the sale.
final class StoreKitProvider: PurchaseProviding, @unchecked Sendable {
    private var products: [String: Product] = [:]

    /// Whether `restore` may fall back to `AppStore.sync()`.
    ///
    /// False while the build runs against `Config/Sunfold.storekit`. A
    /// configuration file cannot stand in for `sync`: the call leaves for the
    /// real App Store, demands the Apple ID password, and comes back knowing
    /// nothing about the fake products — a password prompt with no possible
    /// outcome.
    private let canSyncWithAppStore: Bool

    init(canSyncWithAppStore: Bool) {
        self.canSyncWithAppStore = canSyncWithAppStore
    }

    func configure() {}

    func isProActive() async -> Bool {
        // `currentEntitlements` already filters out expired subscriptions, but
        // not refunds, so revoked transactions are dropped explicitly.
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard StoreIDs.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            return true
        }
        return false
    }

    func loadProducts() async -> [SunfoldProduct] {
        guard let fetched = try? await Product.products(for: StoreIDs.all) else { return [] }
        products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })

        let monthlyPrice = fetched.first { $0.id == StoreIDs.monthly }?.price

        return fetched.compactMap { product -> SunfoldProduct? in
            guard let term = Self.term(for: product.id) else { return nil }

            var perMonth: String?
            var savings: Int?
            if term == .yearly {
                let monthlyEquivalent = product.price / 12
                perMonth = monthlyEquivalent.formatted(product.priceFormatStyle)
                if let monthlyPrice, monthlyPrice > 0 {
                    let ratio = 1 - NSDecimalNumber(decimal: monthlyEquivalent).doubleValue
                        / NSDecimalNumber(decimal: monthlyPrice).doubleValue
                    savings = max(0, Int((ratio * 100).rounded()))
                }
            }

            return SunfoldProduct(
                id: product.id,
                term: term,
                displayPrice: product.displayPrice,
                perMonthPrice: perMonth,
                savingsPercent: savings
            )
        }
        .sorted { Self.order($0.term) < Self.order($1.term) }
    }

    func purchase(id: String) async throws -> Bool {
        guard let product = products[id] else { throw PurchaseError.productUnavailable }

        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            // Finishing tells StoreKit the entitlement has been delivered; an
            // unfinished transaction is replayed on every launch forever.
            await transaction.finish()
            return true
        case .userCancelled:
            throw PurchaseError.cancelled
        case .pending:
            // Ask-to-Buy and similar: the entitlement may arrive later.
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws -> Bool {
        // `currentEntitlements` already carries every purchase this Apple ID
        // owns, and StoreKit keeps it up to date across reinstalls and devices
        // on its own — so the ordinary case needs no sync at all.
        //
        // `AppStore.sync()` is kept for the case where nothing was found,
        // because it is the only thing that can recover a genuinely missing
        // transaction. It is deliberately last: it always prompts for the
        // Apple ID password, and asking someone to retype their password to
        // be told what the device already knew is a bad trade.
        if await isProActive() { return true }
        guard canSyncWithAppStore else { return false }
        try await AppStore.sync()
        return await isProActive()
    }

    private static func term(for productID: String) -> SunfoldProduct.Term? {
        switch productID {
        case StoreIDs.monthly: .monthly
        case StoreIDs.yearly: .yearly
        case StoreIDs.lifetime: .lifetime
        default: nil
        }
    }

    private static func order(_ term: SunfoldProduct.Term) -> Int {
        switch term {
        case .yearly: 0
        case .monthly: 1
        case .lifetime: 2
        }
    }
}
