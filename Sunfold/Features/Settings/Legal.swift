import Foundation

/// Everywhere Sunfold points the user at a legal or support destination.
///
/// The privacy policy is *also* rendered inside the app, so the paywall's
/// required links stay functional even if the website is down or not yet
/// published — App Review checks those links, and a 404 during review is an
/// avoidable rejection. Terms of Use point at Apple's standard EULA, which is
/// the licence Sunfold ships under.
nonisolated enum Legal {
    /// Hosted policy, submitted in App Store Connect metadata as well.
    static let privacyPolicyURL = URL(string: "https://sunfold.app/privacy")!

    /// Apple's Standard End User Licence Agreement — the default licence for
    /// apps that do not supply a custom EULA.
    static let termsURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    static let supportURL = URL(string: "https://sunfold.app/support")!
    static let supportEmail = "support@sunfold.app"

    /// Managing or cancelling a subscription always happens in the App Store,
    /// never inside the app. Guideline 3.1.2 requires this to be reachable.
    static let manageSubscriptionsURL = URL(
        string: "https://apps.apple.com/account/subscriptions"
    )!
}
