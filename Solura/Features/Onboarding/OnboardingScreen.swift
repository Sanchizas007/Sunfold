import SwiftUI

/// First run.
///
/// Four short pages: what the app is, the health notice, a schedule, and what
/// the opening week includes. The health notice must be acknowledged before the
/// app can be used — an app that counts fasting hours should say who ought to
/// speak to a doctor first, and say it before the first fast, not after.
struct OnboardingScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Entitlements.self) private var entitlements

    @State private var page = 0
    @State private var acknowledgedHealthNotice = false
    @State private var showingDisclaimer = false

    private let lastPage = 3

    var body: some View {
        ZStack {
            SoluraBackground()

            VStack(spacing: 0) {
                // Deliberately not a paged TabView. A swipeable pager lets the
                // reader flick straight past the health notice without ever
                // acknowledging it, which defeats the one gate this screen
                // exists to enforce. Paging is driven by the button only.
                Group {
                    switch page {
                    case 0: welcome
                    case 1: healthNotice
                    case 2: protocolChoice
                    default: ready
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                controls
            }
        }
        .sheet(isPresented: $showingDisclaimer) { HealthDisclaimerScreen() }
    }

    // MARK: Pages

    private var welcome: some View {
        page(
            symbol: "circle.dotted",
            title: "onboarding.welcome.title",
            body: "onboarding.welcome.body"
        ) {
            VStack(spacing: 12) {
                bullet("timer", "onboarding.welcome.point1")
                bullet("flame", "onboarding.welcome.point2")
                bullet("lock.shield", "onboarding.welcome.point3")
            }
            .card()
        }
    }

    private var healthNotice: some View {
        page(
            symbol: "heart.text.square",
            title: "onboarding.health.title",
            body: "onboarding.health.body"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("onboarding.health.list")
                    .font(Typography.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("onboarding.health.readMore") { showingDisclaimer = true }
                    .buttonStyle(QuietButtonStyle())

                Divider().overlay(Palette.hairline)

                // A checkbox rather than a switch: this is a one-time consent,
                // not a setting, and the whole row is the target so the
                // acknowledgement is never fiddly to give.
                Button {
                    acknowledgedHealthNotice.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: acknowledgedHealthNotice
                            ? "checkmark.circle.fill"
                            : "circle")
                            .font(.system(size: 21))
                            .foregroundStyle(acknowledgedHealthNotice
                                ? Palette.accentDeep
                                : Palette.hairline)
                        Text("onboarding.health.acknowledge")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(acknowledgedHealthNotice ? [.isSelected] : [])
            }
            .card()
        }
    }

    private var protocolChoice: some View {
        page(
            symbol: "slider.horizontal.3",
            title: "onboarding.protocol.title",
            body: "onboarding.protocol.body"
        ) {
            @Bindable var settings = settings

            return VStack(spacing: 10) {
                ForEach([FastingProtocol.sixteenEight, .eighteenSix, .twentyFour]) { item in
                    Button {
                        settings.selectedProtocol = item
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15))
                                .foregroundStyle(
                                    settings.selectedProtocol == item
                                        ? Palette.accentDeep
                                        : Palette.inkTertiary
                                )
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(String(localized: item.titleKey))
                                    .font(Typography.cardTitle)
                                    .foregroundStyle(Palette.ink)
                                Text(String(localized: item.subtitleKey))
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.inkSecondary)
                            }

                            Spacer()

                            Image(systemName: settings.selectedProtocol == item
                                ? "checkmark.circle.fill"
                                : "circle")
                                .foregroundStyle(
                                    settings.selectedProtocol == item
                                        ? Palette.accentDeep
                                        : Palette.hairline
                                )
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }

                Text("onboarding.protocol.note")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ready: some View {
        page(
            symbol: "sparkles",
            title: "onboarding.ready.title",
            body: "onboarding.ready.body"
        ) {
            VStack(spacing: 12) {
                bullet("checkmark.circle", "onboarding.ready.point1")
                bullet("bell", "onboarding.ready.point2")
                bullet("iphone", "onboarding.ready.point3")
            }
            .card()
        }
    }

    // MARK: Chrome

    private func page<Extra: View>(
        symbol: String,
        title: LocalizedStringKey,
        body: LocalizedStringKey,
        @ViewBuilder extra: () -> Extra
    ) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(LinearGradient.fasting)
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text(title)
                        .font(Typography.screenTitle)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(body)
                        .font(Typography.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                extra()
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.bottom, 20)
        }
    }

    private func bullet(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.accentDeep)
                .frame(width: 22)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ForEach(0...lastPage, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Palette.accentDeep : Palette.hairline)
                        .frame(width: index == page ? 20 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
            }

            Button(page == lastPage ? "onboarding.start" : "common.continue") {
                if page == lastPage {
                    settings.hasCompletedOnboarding = true
                } else {
                    withAnimation(.easeInOut(duration: 0.28)) { page += 1 }
                }
            }
            .buttonStyle(PrimaryButtonStyle(tint: .fasting))
            .disabled(page == 1 && !acknowledgedHealthNotice)
            .opacity(page == 1 && !acknowledgedHealthNotice ? 0.5 : 1)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.bottom, 20)
    }
}
