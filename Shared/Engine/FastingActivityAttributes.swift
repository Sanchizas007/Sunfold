import ActivityKit
import Foundation

/// The Live Activity contract, shared by the app (which starts and updates it)
/// and the widget extension (which draws it).
///
/// The state carries dates rather than a countdown, so the Lock Screen and the
/// Dynamic Island can render a self-ticking `Text(timerInterval:)`. That means
/// no push updates, no background refresh, and no battery cost: the activity
/// only needs a real update when the metabolic phase changes.
nonisolated struct FastingActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// When the fast (or eating window) began.
        var startDate: Date
        /// When it is due to end.
        var endDate: Date
        /// `MetabolicPhase.rawValue`; empty during an eating window.
        var phaseRaw: String
        /// True while the eating window is counting down instead of a fast.
        var isEatingWindow: Bool

        var phase: MetabolicPhase? {
            MetabolicPhase(rawValue: phaseRaw)
        }

        func progress(at now: Date) -> Double {
            let total = endDate.timeIntervalSince(startDate)
            guard total > 0 else { return 0 }
            return min(1, max(0, now.timeIntervalSince(startDate) / total))
        }
    }

    /// "16:8", "20:4", "14h" — fixed for the life of the activity.
    var protocolLabel: String
}
