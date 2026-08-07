import Foundation
import SwiftData

/// One fast, from the moment it was started to the moment it was ended.
///
/// A session with `endDate == nil` is the one in progress; Solura keeps at most
/// one of those. Elapsed time is always derived from `startDate` against the
/// clock — never accumulated by a running timer — so backgrounding the app,
/// rebooting the phone, or killing the process cannot drift the count.
@Model
final class FastSession {
    /// Stable identity for CSV export and for matching a Live Activity to its
    /// session. `@Attribute(.unique)` would be wrong here: a restored backup
    /// could legitimately collide, and losing history is worse than a dupe.
    var id: UUID = UUID()

    var startDate: Date = Date()

    /// `nil` while the fast is running.
    var endDate: Date?

    /// The length the user was aiming for when they started, in seconds.
    /// Stored per session so that changing protocols later never rewrites
    /// history.
    var targetSeconds: Double = 16 * 3600

    /// `FastingProtocol.rawValue` at the time of the fast.
    var protocolRaw: String = FastingProtocol.sixteenEight.rawValue

    var note: String = ""

    /// How the fast felt, 1–5, or `nil` if the user did not say.
    var feeling: Int?

    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        endDate: Date? = nil,
        targetSeconds: Double,
        fastingProtocol: FastingProtocol,
        note: String = "",
        feeling: Int? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.targetSeconds = targetSeconds
        self.protocolRaw = fastingProtocol.rawValue
        self.note = note
        self.feeling = feeling
        self.createdAt = .now
    }
}

extension FastSession {
    var fastingProtocol: FastingProtocol {
        FastingProtocol(rawValue: protocolRaw) ?? .custom
    }

    var isRunning: Bool { endDate == nil }

    /// Seconds fasted. For a running fast this is measured against `now`, which
    /// callers pass in so a `TimelineView` can drive redraws deterministically.
    func elapsed(at now: Date = .now) -> TimeInterval {
        max(0, (endDate ?? now).timeIntervalSince(startDate))
    }

    /// Final duration of a finished fast; `nil` while it is still running.
    var duration: TimeInterval? {
        endDate.map { max(0, $0.timeIntervalSince(startDate)) }
    }

    /// 0…1, clamped. A fast that ran long stays at 1 rather than overflowing
    /// the ring.
    func progress(at now: Date = .now) -> Double {
        guard targetSeconds > 0 else { return 0 }
        return min(1, max(0, elapsed(at: now) / targetSeconds))
    }

    /// When the fast is due to finish.
    var targetEndDate: Date {
        startDate.addingTimeInterval(targetSeconds)
    }

    /// True once the goal has been met, whether or not the user has stopped.
    func hasReachedGoal(at now: Date = .now) -> Bool {
        elapsed(at: now) >= targetSeconds
    }

    /// A finished fast that stopped short of its goal. Shown neutrally in
    /// history — a short fast is data, not a failure, and the UI never scolds.
    var endedEarly: Bool {
        guard let duration else { return false }
        return duration < targetSeconds
    }

    func phase(at now: Date = .now) -> MetabolicPhase {
        MetabolicPhase.phase(forElapsed: elapsed(at: now))
    }

    /// The day a fast is credited to for streaks and the calendar: the day it
    /// *ended*, since that is when the user completed the work. A 16:8 fast
    /// started at 8pm belongs to the next day.
    func creditedDay(in calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: endDate ?? startDate)
    }
}
