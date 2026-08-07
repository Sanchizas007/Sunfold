// ActivityKit is not concurrency-audited: `Activity` is a plain class and its
// `update`/`end` are nonisolated async, so passing one out of the main actor
// trips Swift 6's sending check. The framework serialises these calls itself,
// and this controller is the only owner of the activity.
@preconcurrency import ActivityKit
import Foundation

/// Owns the Live Activity shown on the Lock Screen and in the Dynamic Island.
///
/// The activity is started once, when a fast begins, with the start and goal
/// dates baked into its state. Everything on screen after that is a self-ticking
/// `Text(timerInterval:)`, so Sunfold only pushes an update when the metabolic
/// phase changes — a handful of updates across a whole fast, no background
/// refresh, no push server.
@Observable
final class LiveActivityController {
    static let shared = LiveActivityController()

    private(set) var isRunning = false
    private var activity: Activity<FastingActivityAttributes>?
    /// The phase the activity is currently showing, so repeated ticks do not
    /// spend an update on state that has not changed.
    private var shownPhase: MetabolicPhase?

    private init() {
        adoptExistingActivity()
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Reattaches to an activity that survived a relaunch, so the app never
    /// leaves an orphaned card on the Lock Screen it can no longer end.
    private func adoptExistingActivity() {
        activity = Activity<FastingActivityAttributes>.activities.first
        isRunning = activity != nil
    }

    func start(
        protocolLabel: String,
        startDate: Date,
        endDate: Date,
        isEatingWindow: Bool,
        enabled: Bool
    ) {
        guard enabled, areActivitiesEnabled else { return }
        end()

        let phase = isEatingWindow ? nil : MetabolicPhase.phase(forElapsed: Date.now.timeIntervalSince(startDate))
        let state = FastingActivityAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            phaseRaw: phase?.rawValue ?? "",
            isEatingWindow: isEatingWindow
        )

        do {
            activity = try Activity.request(
                attributes: FastingActivityAttributes(protocolLabel: protocolLabel),
                content: ActivityContent(state: state, staleDate: endDate.addingTimeInterval(3600)),
                pushType: nil
            )
            shownPhase = phase
            isRunning = true
        } catch {
            // Most commonly the user has Live Activities switched off, or the
            // per-app limit is reached. Neither is worth interrupting them for.
            isRunning = false
        }
    }

    /// Pushes a new phase into the activity. No-op when nothing changed.
    func updatePhaseIfNeeded(startDate: Date, endDate: Date, at now: Date = .now) {
        guard let activity else { return }
        let phase = MetabolicPhase.phase(forElapsed: now.timeIntervalSince(startDate))
        guard phase != shownPhase else { return }
        shownPhase = phase

        let state = FastingActivityAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            phaseRaw: phase.rawValue,
            isEatingWindow: false
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: endDate.addingTimeInterval(3600)))
        }
    }

    func end() {
        guard let activity else {
            isRunning = false
            return
        }
        self.activity = nil
        shownPhase = nil
        isRunning = false
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Ends every activity this app owns, including ones adopted from a previous
    /// launch. Used when the user turns the feature off in settings.
    func endAll() {
        activity = nil
        shownPhase = nil
        isRunning = false
        Task {
            for activity in Activity<FastingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
