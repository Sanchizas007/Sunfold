import SwiftUI

/// Sunfold Pro.
///
/// Laid out to satisfy App Review guideline 3.1.2 without looking like a
/// compliance checklist: every plan states its length and its price, the
/// auto-renewal terms sit directly above the buy button rather than buried in a
/// sheet, and Restore, Terms and Privacy are all one tap away. The lifetime
/// option is labelled as a one-time payment so it can never be mistaken for a
/// subscription.
struct PaywallScreen: View {
    @Environment(Entitlements.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedID: String?
    @State private var showingPrivacy = false

    var body: some View {
        NavigationStack {
            ZStack {
                SunfoldBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        header
                        benefits
                        plans
                        purchaseSection
                        legalFooter
                    }
                    .padding(Metrics.screenPadding)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.close") { dismiss() }
                        .foregroundStyle(Palette.inkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("paywall.restore") {
                        Task { await restore() }
                    }
                    .font(Typography.captionStrong)
                    .foregroundStyle(Palette.accentDeep)
                }
            }
            .task {
                await entitlements.loadProducts()
                selectedID = entitlements.products.first { $0.term == .yearly }?.id
                    ?? entitlements.products.first?.id
            }
            .sheet(isPresented: $showingPrivacy) { PrivacyPolicyScreen() }
            .alert(
                "paywall.error.title",
                isPresented: Binding(
                    get: { entitlements.errorMessage != nil },
                    set: { if !$0 { entitlements.errorMessage = nil } }
                )
            ) {
                Button("common.ok", role: .cancel) { entitlements.errorMessage = nil }
            } message: {
                Text(entitlements.errorMessage ?? "")
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 14) {
            ProgressRing(progress: 0.72, colors: Palette.fastingGradient, lineWidth: 13, showsHead: true) {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Palette.accent)
            }
            .frame(width: 116, height: 116)

            VStack(spacing: 6) {
                Text("paywall.title")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)

                Text(entitlements.isInFullAccessPeriod ? "paywall.subtitle.trial" : "paywall.subtitle")
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(spacing: 12) {
            benefit("circle.grid.2x2", "paywall.benefit.protocols", "paywall.benefit.protocols.body")
            benefit("clock.arrow.circlepath", "paywall.benefit.history", "paywall.benefit.history.body")
            benefit("chart.line.uptrend.xyaxis", "paywall.benefit.charts", "paywall.benefit.charts.body")
            benefit("flame", "paywall.benefit.phases", "paywall.benefit.phases.body")
            benefit("square.grid.2x2", "paywall.benefit.widgets", "paywall.benefit.widgets.body")
        }
        .card()
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accentDeep)
                .frame(width: 28, height: 28)
                .background(Palette.accent.opacity(0.14), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.ink)
                Text(body)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Plans

    @ViewBuilder
    private var plans: some View {
        if !entitlements.products.isEmpty {
            VStack(spacing: 10) {
                ForEach(entitlements.products) { product in
                    planCard(product)
                }
            }
        } else if entitlements.isLoadingProducts {
            ProgressView()
                .tint(Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if entitlements.productsUnavailable {
            // The store did not answer — almost always no connection. Spinning
            // forever here would look like a broken app rather than a broken
            // network, and leave the user with nothing to do about it.
            VStack(spacing: 12) {
                EmptyStateView(
                    symbol: "wifi.exclamationmark",
                    title: "paywall.unavailable.title",
                    message: "paywall.unavailable.body"
                )
                Button("common.retry") {
                    Task { await entitlements.loadProducts() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .card()
        }
    }

    private func planCard(_ product: SunfoldProduct) -> some View {
        let isSelected = selectedID == product.id

        return Button { selectedID = product.id } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Palette.accentDeep : Palette.hairline)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(title(for: product.term))
                            .font(Typography.cardTitle)
                            .foregroundStyle(Palette.ink)

                        if let savings = product.savingsPercent, savings > 0 {
                            Text(
                                String(
                                    localized: "paywall.save",
                                    defaultValue: "Save \(savings)%"
                                )
                            )
                            .font(Typography.overline)
                            .foregroundStyle(Palette.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(LinearGradient.fasting, in: .capsule)
                        }
                    }

                    Text(subtitle(for: product))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }

                Spacer(minLength: 6)

                Text(product.displayPrice)
                    .font(Typography.stat)
                    .foregroundStyle(Palette.ink)
            }
            .card()
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .strokeBorder(isSelected ? Palette.accent.opacity(0.6) : .clear, lineWidth: 1.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func title(for term: SunfoldProduct.Term) -> LocalizedStringKey {
        switch term {
        case .monthly: "paywall.plan.monthly"
        case .yearly: "paywall.plan.yearly"
        case .lifetime: "paywall.plan.lifetime"
        }
    }

    private func subtitle(for product: SunfoldProduct) -> String {
        switch product.term {
        case .monthly:
            String(localized: "paywall.plan.monthly.detail")
        case .yearly:
            if let perMonth = product.perMonthPrice {
                String(
                    localized: "paywall.plan.yearly.detailPerMonth",
                    defaultValue: "Billed yearly · \(perMonth) / month"
                )
            } else {
                String(localized: "paywall.plan.yearly.detail")
            }
        case .lifetime:
            String(localized: "paywall.plan.lifetime.detail")
        }
    }

    // MARK: Purchase

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            switch entitlements.storeKind {
            case .revenueCat:
                EmptyView()
            case .localTesting:
                DisclaimerNote(text: "paywall.localStore", symbol: "hammer")
            case .unconfigured:
                DisclaimerNote(text: "paywall.notConfigured", symbol: "wrench.and.screwdriver")
            }

            // The renewal terms sit immediately above the button, where they
            // are actually read, not folded into a link.
            Text(selectedIsLifetime ? "paywall.terms.lifetime" : "paywall.terms.subscription")
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await purchase() }
            } label: {
                if entitlements.isWorking {
                    ProgressView().tint(Palette.onAccent)
                } else {
                    Text(selectedIsLifetime ? "paywall.cta.buy" : "paywall.cta.subscribe")
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: .fasting))
            .disabled(selectedID == nil || entitlements.isWorking)
        }
    }

    private var selectedIsLifetime: Bool {
        entitlements.products.first { $0.id == selectedID }?.term == .lifetime
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            // Guideline 3.1.2 requires these three to be present and usable.
            // Side by side they collapse into one-syllable columns at the
            // accessibility text sizes, so past that point they stack.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 14) { legalLinks }
            } else {
                HStack(spacing: 18) { legalLinks }
            }

            Button("paywall.manage") { openURL(Legal.manageSubscriptionsURL) }
                .buttonStyle(QuietButtonStyle())
                .foregroundStyle(Palette.inkTertiary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 2)
    }

    @ViewBuilder
    private var legalLinks: some View {
        Button("paywall.restore") { Task { await restore() } }
            .buttonStyle(QuietButtonStyle())
        Button("settings.terms") { openURL(Legal.termsURL) }
            .buttonStyle(QuietButtonStyle())
        Button("settings.privacy") { showingPrivacy = true }
            .buttonStyle(QuietButtonStyle())
    }

    // MARK: Actions

    private func purchase() async {
        guard let product = entitlements.products.first(where: { $0.id == selectedID }) else { return }
        if await entitlements.purchase(product) { dismiss() }
    }

    private func restore() async {
        if await entitlements.restore() { dismiss() }
    }
}
