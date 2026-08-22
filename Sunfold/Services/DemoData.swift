import Foundation
import SwiftData

/// Demo state for App Store screenshots: a plausible month of history, and a
/// way to open any screen without a single tap.
///
/// Screenshots have to show the app doing its job — an empty history and a ring
/// at zero sell nothing — and a month of fasts cannot be tapped in by hand.
/// Both halves are driven by launch arguments, so they can never fire for a
/// real user, and the seeding is compiled out of release builds entirely:
///
///     xcrun simctl launch <udid> app.sunfold -SunfoldDemoData -SunfoldDemoScreen phases
///
/// Every date is relative to launch, so the screenshots stay current whenever
/// they are retaken. `Tools/screenshots.sh` drives the whole set.
enum DemoData {
    static let launchArgument = "-SunfoldDemoData"
    static let screenArgument = "-SunfoldDemoScreen"

    /// A screen the screenshot run can jump straight to. Two of these are
    /// sheets over the timer rather than tabs, which is why the views read this
    /// themselves instead of a single router doing it.
    enum Screen: String {
        case timer, phases, protocols, history, weight, settings
    }

    #if DEBUG
    static var isRequested: Bool {
        CommandLine.arguments.contains(launchArgument)
    }

    /// `nil` in release builds, so the views below fold to their normal
    /// defaults and no screenshot plumbing survives shipping.
    static var requestedScreen: Screen? {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: screenArgument) else { return nil }
        let value = arguments.index(after: flag)
        guard value < arguments.endIndex else { return nil }
        return Screen(rawValue: arguments[value])
    }

    /// Wipes whatever is there and seeds a fresh set. Wiping matters: running
    /// this twice must not double the history and skew every average on screen.
    static func seed(into context: ModelContext, settings: AppSettings = .shared) {
        try? context.delete(model: FastSession.self)
        try? context.delete(model: WeightEntry.self)

        let calendar = Calendar.current
        let now = Date.now

        // Every setting the screenshots can show is pinned, not left to
        // whatever the previous run wrote: the same command has to produce the
        // same frame in every locale, in any order.
        settings.hasCompletedOnboarding = true
        settings.selectedProtocol = .sixteenEight
        settings.appearance = .system
        settings.weightUnit = AppSettings.localeWeightUnit()
        // Keeps the system permission alert from landing on top of a shot.
        settings.hasRequestedNotificationPermission = true

        // A fast in progress, deep enough into the schedule that the ring is
        // clearly filled and the phase pill reads "Fat burning" rather than the
        // first, least interesting phase.
        let runningStart = now.addingTimeInterval(-(12 * 3600 + 47 * 60))
        context.insert(FastSession(
            startDate: runningStart,
            targetSeconds: 16 * 3600,
            fastingProtocol: .sixteenEight
        ))

        // Finished fasts. The last seven days are unbroken so the streak tile
        // reads 7; before that a realistic pattern with the odd missed day,
        // because a perfect month looks staged.
        let pattern: [(daysAgo: Int, hours: Double)] = [
            (1, 16.2), (2, 16.0), (3, 17.1), (4, 16.4), (5, 16.0), (6, 15.8), (7, 16.6),
            (9, 16.1), (10, 17.4), (11, 16.0), (12, 15.2), (13, 16.8),
            (15, 16.3), (16, 16.0), (17, 18.2), (18, 16.1),
            (20, 15.9), (21, 16.5), (22, 16.0), (23, 17.0), (24, 16.2),
            (26, 16.0), (27, 15.6), (28, 16.9), (29, 16.1), (30, 16.4),
            (32, 16.0), (33, 17.2)
        ]

        for entry in pattern {
            guard
                let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now),
                let end = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: day)
            else { continue }

            context.insert(FastSession(
                startDate: end.addingTimeInterval(-entry.hours * 3600),
                endDate: end,
                targetSeconds: 16 * 3600,
                fastingProtocol: .sixteenEight
            ))
        }

        // A gentle downward trend. Not dramatic — this is a timer, not a
        // weight-loss promise, and an implausible drop would be a claim the app
        // deliberately does not make.
        let weights: [(daysAgo: Int, kilograms: Double)] = [
            (33, 82.4), (26, 81.9), (19, 81.2), (12, 80.6), (5, 80.1), (0, 79.8)
        ]

        for entry in weights {
            guard let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: now) else { continue }
            context.insert(WeightEntry(date: day, kilograms: entry.kilograms))
        }

        try? context.save()
    }
    #else
    static var requestedScreen: Screen? { nil }
    #endif
}
