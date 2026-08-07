import Foundation
import WidgetKit

/// What the user is allowed to do, and why.
///
/// Two independent sources combine here: a seven-day full-access period that
/// starts on first launch and is purely local, and a Pro entitlement that comes
/// from the store. Nothing else in the app asks about payment state.
///
/// A note on wording, which matters for review: the seven days are *not* a
/// StoreKit introductory offer, so nothing in the UI calls them a "free trial"
/// of a subscription. They are simply a period during which the app is fully
/// open. Guideline 3.1.2 language about trials only binds claims about the
/// subscription itself.
@Observable
final class Entitlements {
    /// Length of the opening full-access period.
    static let fullAccessDays = 7

    private let provider: any PurchaseProviding
    private let settings: AppSettings

    /// True when the store says the Pro entitlement is active.
    private(set) var isPro = false
    private(set) var products: [SunfoldProduct] = []
    private(set) var isWorking = false
    /// Set when a purchase or restore failed for a reason worth showing.
    var errorMessage: String?
    /// True when the build has no store key, so the paywall can say so instead
    /// of silently failing.
    let isStoreConfigured: Bool

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let key = Bundle.main.object(forInfoDictionaryKey: "RCPublicAPIKey") as? String ?? ""
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            provider = UnconfiguredPurchaseProvider()
            isStoreConfigured = false
        } else {
            provider = RevenueCatProvider(apiKey: trimmed)
            isStoreConfigured = true
        }
        provider.configure()
        AccessStore.hasFullAccess = hasFullAccess
    }

    // MARK: Access

    /// When the opening full-access period runs out.
    var fullAccessEndDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: Self.fullAccessDays,
            to: settings.firstLaunchDate
        ) ?? settings.firstLaunchDate
    }

    var isInFullAccessPeriod: Bool {
        Date.now < fullAccessEndDate
    }

    /// Whole days left in the opening period, rounded up so the last partial
    /// day still reads as "1 day left" rather than "0".
    var fullAccessDaysRemaining: Int {
        guard isInFullAccessPeriod else { return 0 }
        let seconds = fullAccessEndDate.timeIntervalSinceNow
        return max(1, Int((seconds / 86_400).rounded(.up)))
    }

    /// The one question the rest of the app asks.
    var hasFullAccess: Bool {
        isPro || isInFullAccessPeriod
    }

    func canUse(_ fastingProtocol: FastingProtocol) -> Bool {
        hasFullAccess || fastingProtocol.isFree
    }

    /// How far back history is visible. Free keeps the last week.
    var historyWindowDays: Int? {
        hasFullAccess ? nil : 7
    }

    // MARK: Store

    func refresh() async {
        isPro = await provider.isProActive()
        publishAccess()
        if products.isEmpty {
            products = await provider.loadProducts()
        }
    }

    func loadProducts() async {
        products = await provider.loadProducts()
    }

    @discardableResult
    func purchase(_ product: SunfoldProduct) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let entitled = try await provider.purchase(id: product.id)
            isPro = entitled
            publishAccess()
            return entitled
        } catch PurchaseError.cancelled {
            // The user changed their mind. That is not an error worth a dialog.
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            let entitled = try await provider.restore()
            isPro = entitled
            publishAccess()
            if !entitled {
                errorMessage = String(localized: "paywall.restore.nothing")
            }
            return entitled
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Mirrors access into the shared container and nudges the widget, which
    /// otherwise would not learn about a purchase until its next refresh.
    private func publishAccess() {
        let access = hasFullAccess
        guard AccessStore.hasFullAccess != access else { return }
        AccessStore.hasFullAccess = access
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Re-evaluates the local period, which can lapse while the app is open.
    func revalidate() {
        publishAccess()
    }
}
