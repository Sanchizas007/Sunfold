import Foundation

/// Decides when to ask for an App Store review.
///
/// Asking costs nothing but spending the ask badly does: iOS allows only a
/// handful of these prompts per year and silently swallows the rest, so the
/// moment matters more than the frequency. The one moment worth spending it on
/// is just after a fast the user chose to finish — not at launch, when they
/// have done nothing yet, and not mid-fast, when the alert lands on top of the
/// ring they were watching.
enum ReviewPrompt {
    /// Finished fasts before the question is fair to ask. Three is enough to
    /// mean the app is being used and not so many that the ask never happens.
    static let minimumFinishedFasts = 3

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Asks at most once per app version: a user who declined in 1.1 should not
    /// be asked again until there is something new to have an opinion about.
    static func shouldAsk(finishedFasts: Int, settings: AppSettings = .shared) -> Bool {
        #if DEBUG
        // A screenshot run must never catch the system alert mid-frame.
        if DemoData.isRequested { return false }
        #endif
        guard finishedFasts >= minimumFinishedFasts else { return false }
        return settings.lastReviewRequestVersion != currentVersion
    }

    static func record(settings: AppSettings = .shared) {
        settings.lastReviewRequestVersion = currentVersion
    }
}
