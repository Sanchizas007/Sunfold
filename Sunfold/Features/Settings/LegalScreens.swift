import SwiftUI

/// A plain, readable document screen: a lede, then titled sections.
private struct DocumentScreen<Footer: View>: View {
    @Environment(\.dismiss) private var dismiss

    let navigationTitle: LocalizedStringKey
    let title: LocalizedStringKey
    let lede: LocalizedStringKey
    let sections: [(LocalizedStringKey, LocalizedStringKey)]
    @ViewBuilder var footer: Footer

    var body: some View {
        NavigationStack {
            ZStack {
                SunfoldBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(Typography.screenTitle)
                                .foregroundStyle(Palette.ink)
                            Text(lede)
                                .font(Typography.body)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.0)
                                    .font(Typography.cardTitle)
                                    .foregroundStyle(Palette.ink)
                                Text(section.1)
                                    .font(Typography.body)
                                    .foregroundStyle(Palette.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        footer
                    }
                    .padding(Metrics.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}

/// The privacy policy, rendered from the app bundle.
///
/// Shipping it in the binary means the link required on the paywall is
/// guaranteed to work — during App Review, offline, and before the website is
/// live. The hosted copy at `Legal.privacyPolicyURL` carries the same text for
/// the App Store Connect metadata field.
struct PrivacyPolicyScreen: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        DocumentScreen(
            navigationTitle: "privacy.title",
            title: "privacy.heading",
            lede: "privacy.lede",
            sections: [
                ("privacy.stored.title", "privacy.stored.body"),
                ("privacy.notCollected.title", "privacy.notCollected.body"),
                ("privacy.purchases.title", "privacy.purchases.body"),
                ("privacy.notifications.title", "privacy.notifications.body"),
                ("privacy.health.title", "privacy.health.body"),
                ("privacy.deletion.title", "privacy.deletion.body"),
                ("privacy.children.title", "privacy.children.body"),
                ("privacy.changes.title", "privacy.changes.body")
            ]
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Button("privacy.contact") {
                    openURL(URL(string: "mailto:\(Legal.supportEmail)") ?? Legal.supportURL)
                }
                .buttonStyle(QuietButtonStyle())

                Text("privacy.updated")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

/// The health notice.
///
/// Shown during onboarding before the first fast can be started, and reachable
/// from settings for good. Fasting is not right for everyone, and an app that
/// counts hours has a duty to say who should talk to a doctor first.
struct HealthDisclaimerScreen: View {
    var body: some View {
        DocumentScreen(
            navigationTitle: "disclaimer.title",
            title: "disclaimer.heading",
            lede: "disclaimer.lede",
            sections: [
                ("disclaimer.notMedical.title", "disclaimer.notMedical.body"),
                ("disclaimer.askFirst.title", "disclaimer.askFirst.body"),
                ("disclaimer.stop.title", "disclaimer.stop.body"),
                ("disclaimer.eatingDisorders.title", "disclaimer.eatingDisorders.body"),
                ("disclaimer.phases.title", "disclaimer.phases.body")
            ]
        ) {
            EmptyView()
        }
    }
}
