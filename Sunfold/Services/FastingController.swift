import Foundation
import SwiftData
import WidgetKit

/// The single place a fast is started, stopped or edited.
///
/// Every mutation goes through here so the four things that must stay in step —
/// the store, the widget snapshot, the scheduled notifications and the Live
/// Activity — can never drift apart. Views read state from it; nothing else
/// writes `FastSession`.
@Observable
final class FastingController {
    private let context: ModelContext
    private let settings: AppSettings

    /// The fast in progress, or `nil`.
    private(set) var active: FastSession?
    /// The most recently finished fast, which defines the eating window.
    private(set) var lastFinished: FastSession?

    /// Bumped on every mutation so views driven by derived values refresh.
    private(set) var revision = 0

    init(context: ModelContext, settings: AppSettings = .shared) {
        self.context = context
        self.settings = settings
        reload()
    }

    // MARK: Derived state

    var mode: FastingSnapshot.Mode {
        if active != nil { return .fasting }
        if let end = eatingWindowEnd, end > .now { return .eating }
        return .idle
    }

    /// When the current eating window closes, or `nil` if there is no window
    /// (no previous fast, or a protocol with no fixed window).
    var eatingWindowEnd: Date? {
        guard
            active == nil,
            let finishedAt = lastFinished?.endDate,
            let windowSeconds = settings.targetEatingSeconds
        else { return nil }
        return finishedAt.addingTimeInterval(windowSeconds)
    }

    var eatingWindowStart: Date? {
        active == nil ? lastFinished?.endDate : nil
    }

    /// Progress through the fast or the eating window, 0…1.
    func progress(at now: Date = .now) -> Double {
        switch mode {
        case .fasting:
            active?.progress(at: now) ?? 0
        case .eating:
            eatingProgress(at: now)
        case .idle:
            0
        }
    }

    private func eatingProgress(at now: Date) -> Double {
        guard let start = eatingWindowStart, let end = eatingWindowEnd else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    // MARK: Loading

    func reload() {
        active = try? context.fetch(FastSession.runningDescriptor).first
        lastFinished = try? context.fetch(FastSession.lastFinishedDescriptor).first
        revision += 1
    }

    // MARK: Mutations

    /// Starts a fast against the currently selected protocol.
    /// A start date in the past is allowed — people remember late — but never
    /// one in the future, which would show a negative timer.
    func start(at date: Date = .now) {
        guard active == nil else { return }
        let start = min(date, .now)

        let session = FastSession(
            startDate: start,
            targetSeconds: settings.targetFastSeconds,
            fastingProtocol: settings.selectedProtocol
        )
        context.insert(session)
        save()
        reload()

        LiveActivityController.shared.start(
            protocolLabel: settings.protocolLabel,
            startDate: start,
            endDate: session.targetEndDate,
            isEatingWindow: false,
            enabled: settings.liveActivityEnabled
        )
        syncExternalState()
    }

    /// Ends the running fast. An end date before the start is clamped, so a
    /// mis-set clock cannot write a negative duration into history.
    func stop(at date: Date = .now) {
        guard let session = active else { return }
        session.endDate = max(session.startDate, min(date, .now))
        save()
        reload()

        LiveActivityController.shared.end()
        syncExternalState()
    }

    /// Moves the start of the running fast, e.g. "I actually started at 8pm".
    func adjustStart(to date: Date) {
        guard let session = active else { return }
        session.startDate = min(date, .now)
        save()
        reload()

        LiveActivityController.shared.start(
            protocolLabel: settings.protocolLabel,
            startDate: session.startDate,
            endDate: session.targetEndDate,
            isEatingWindow: false,
            enabled: settings.liveActivityEnabled
        )
        syncExternalState()
    }

    /// Applies a protocol change to the fast already running, so switching from
    /// 16:8 to 18:6 mid-fast moves the goal instead of forcing a restart.
    func retargetActiveFast() {
        guard let session = active else { return }
        session.targetSeconds = settings.targetFastSeconds
        session.protocolRaw = settings.selectedProtocol.rawValue
        save()
        reload()

        LiveActivityController.shared.start(
            protocolLabel: settings.protocolLabel,
            startDate: session.startDate,
            endDate: session.targetEndDate,
            isEatingWindow: false,
            enabled: settings.liveActivityEnabled
        )
        syncExternalState()
    }

    func delete(_ session: FastSession) {
        let wasActive = session.isRunning
        context.delete(session)
        save()
        reload()
        if wasActive { LiveActivityController.shared.end() }
        syncExternalState()
    }

    func update(_ session: FastSession, note: String, feeling: Int?) {
        session.note = note
        session.feeling = feeling
        save()
        revision += 1
    }

    /// Called when the app comes back to the foreground: re-derives state and
    /// re-pushes anything that may have gone stale while it was away.
    func refreshOnForeground() {
        reload()
        if let session = active {
            LiveActivityController.shared.updatePhaseIfNeeded(
                startDate: session.startDate,
                endDate: session.targetEndDate
            )
        }
        syncExternalState()
    }

    // MARK: Keeping the outside world in step

    /// Writes the widget snapshot, reloads timelines and rebuilds the pending
    /// notifications from scratch.
    func syncExternalState() {
        writeSnapshot()
        WidgetCenter.shared.reloadAllTimelines()

        let settings = self.settings
        if let session = active {
            let endDate = session.targetEndDate
            let windowSeconds = settings.targetEatingSeconds
            Task {
                await NotificationService.shared.scheduleForFast(
                    endingAt: endDate,
                    eatingWindowSeconds: windowSeconds,
                    settings: settings
                )
            }
        } else if let windowEnd = eatingWindowEnd, windowEnd > .now {
            Task {
                await NotificationService.shared.scheduleForEatingWindow(
                    endingAt: windowEnd,
                    settings: settings
                )
            }
        } else {
            NotificationService.shared.cancelAll()
        }
    }

    private func writeSnapshot() {
        var snapshot = FastingSnapshot()
        snapshot.protocolLabel = settings.protocolLabel
        snapshot.hasFullAccess = AccessStore.hasFullAccess
        snapshot.updatedAt = .now

        let sessions = (try? context.fetch(FastSession.allDescriptor)) ?? []
        snapshot.streakDays = Statistics.currentStreak(for: sessions)

        switch mode {
        case .fasting:
            snapshot.mode = .fasting
            snapshot.startDate = active?.startDate
            snapshot.endDate = active?.targetEndDate
        case .eating:
            snapshot.mode = .eating
            snapshot.startDate = eatingWindowStart
            snapshot.endDate = eatingWindowEnd
        case .idle:
            snapshot.mode = .idle
        }

        SnapshotStore.save(snapshot)
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // SwiftData autosaves too; a failed explicit save is not worth an
            // alert, but losing it silently in a debug build would hide a real
            // schema problem.
            assertionFailure("Failed to save: \(error)")
        }
    }

    // MARK: Bulk operations

    /// Wipes every fast and weight entry. Used by "Delete all data" in settings.
    func deleteAllData() {
        LiveActivityController.shared.endAll()
        NotificationService.shared.cancelAll()
        try? context.delete(model: FastSession.self)
        try? context.delete(model: WeightEntry.self)
        save()
        reload()
        SnapshotStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
