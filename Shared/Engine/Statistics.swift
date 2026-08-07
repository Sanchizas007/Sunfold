import Foundation

/// Aggregates over finished fasts.
///
/// Pure functions over a snapshot of sessions — no store access, no dates
/// pulled from the clock inside — so every number here is testable and the
/// history screen can recompute cheaply as filters change.
nonisolated enum Statistics {

    /// A finished fast is one with an end date. Running fasts never count
    /// toward totals; they would make every average drift while on screen.
    static func finished(_ sessions: [FastSession]) -> [FastSession] {
        sessions.filter { !$0.isRunning }
    }

    struct Summary: Equatable, Sendable {
        var totalFasts: Int = 0
        var totalSeconds: TimeInterval = 0
        var averageSeconds: TimeInterval = 0
        var longestSeconds: TimeInterval = 0
        /// Fasts that reached their goal, over all finished fasts, 0…1.
        var goalRate: Double = 0
        var currentStreak: Int = 0
        var longestStreak: Int = 0
    }

    static func summary(
        for sessions: [FastSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Summary {
        let done = finished(sessions)
        guard !done.isEmpty else { return Summary() }

        let durations = done.compactMap(\.duration)
        let total = durations.reduce(0, +)
        let reachedGoal = done.filter { !$0.endedEarly }.count

        return Summary(
            totalFasts: done.count,
            totalSeconds: total,
            averageSeconds: durations.isEmpty ? 0 : total / Double(durations.count),
            longestSeconds: durations.max() ?? 0,
            goalRate: Double(reachedGoal) / Double(done.count),
            currentStreak: currentStreak(for: done, now: now, calendar: calendar),
            longestStreak: longestStreak(for: done, calendar: calendar)
        )
    }

    /// Distinct days that carry at least one finished fast.
    static func activeDays(
        for sessions: [FastSession],
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(finished(sessions).map { $0.creditedDay(in: calendar) })
    }

    /// Consecutive days ending today.
    ///
    /// A streak survives a day that has not happened yet: if the user fasted
    /// yesterday and has not finished today's fast, the streak still stands.
    /// It only breaks once a full day passes with nothing completed.
    static func currentStreak(
        for sessions: [FastSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let days = activeDays(for: sessions, calendar: calendar)
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        // Start counting from today if it already has a fast, otherwise from
        // yesterday — today may simply be unfinished.
        var cursor = days.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        guard days.contains(cursor) else { return 0 }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func longestStreak(
        for sessions: [FastSession],
        calendar: Calendar = .current
    ) -> Int {
        let days = activeDays(for: sessions, calendar: calendar).sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for (previous, day) in zip(days, days.dropFirst()) {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if gap == 1 {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    /// One point per calendar day over the trailing window, zero-filled so the
    /// chart shows the gaps instead of silently closing them up.
    struct DailyTotal: Identifiable, Equatable, Sendable {
        var day: Date
        var seconds: TimeInterval
        var id: Date { day }
    }

    static func dailyTotals(
        for sessions: [FastSession],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let today = calendar.startOfDay(for: now)
        var totals: [Date: TimeInterval] = [:]
        for session in finished(sessions) {
            totals[session.creditedDay(in: calendar), default: 0] += session.duration ?? 0
        }
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DailyTotal(day: day, seconds: totals[day] ?? 0)
        }
    }

    /// Sessions trimmed to what the free tier may see. Free keeps the most
    /// recent week; Pro keeps everything.
    static func visible(
        _ sessions: [FastSession],
        hasFullAccess: Bool,
        freeWindowDays: Int = 7,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FastSession] {
        guard !hasFullAccess else { return sessions }
        let today = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(freeWindowDays - 1), to: today) else {
            return sessions
        }
        return sessions.filter { $0.creditedDay(in: calendar) >= cutoff }
    }
}
