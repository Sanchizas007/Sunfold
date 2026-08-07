import Foundation
import Testing

// No `@testable import` anywhere in this target: the tests compile `Shared/`
// directly, so the engine is visible without a host app and the suite runs in
// a second.

/// Streaks and aggregates.
///
/// Every test pins its own UTC calendar and its own "now" instead of leaning on
/// the device clock: a streak test that passes in Kyiv and fails in Los Angeles
/// is worse than no test at all, and day-boundary arithmetic is exactly where
/// that happens.
struct StatisticsTests {

    // MARK: Fixtures

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }

    /// 2026-08-07 12:00 UTC — the reference "now" for every test here.
    static let now = Date(timeIntervalSince1970: 1_786_449_600)

    /// A finished fast that is credited to `daysAgo` days before `now`.
    static func fast(
        daysAgo: Int,
        hours: Double = 16,
        target: Double = 16,
        now: Date = StatisticsTests.now
    ) -> FastSession {
        let calendar = Self.calendar
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        // End the fast at 08:00 on that day so the credited day is unambiguous
        // regardless of how long the fast ran.
        let end = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let session = FastSession(
            startDate: end.addingTimeInterval(-hours * 3600),
            endDate: end,
            targetSeconds: target * 3600,
            fastingProtocol: .sixteenEight
        )
        return session
    }

    // MARK: Current streak

    @Test("A fast finished today makes the streak 1")
    func streakToday() {
        let sessions = [Self.fast(daysAgo: 0)]
        #expect(Statistics.currentStreak(for: sessions, now: Self.now, calendar: Self.calendar) == 1)
    }

    @Test("Consecutive days accumulate")
    func streakConsecutive() {
        let sessions = (0...4).map { Self.fast(daysAgo: $0) }
        #expect(Statistics.currentStreak(for: sessions, now: Self.now, calendar: Self.calendar) == 5)
    }

    @Test("Today being unfinished does not break yesterday's streak")
    func streakSurvivesUnfinishedToday() {
        // Nothing today; three days before it. The user still has all of today
        // to fast, so the streak must stand rather than reset to zero.
        let sessions = (1...3).map { Self.fast(daysAgo: $0) }
        #expect(Statistics.currentStreak(for: sessions, now: Self.now, calendar: Self.calendar) == 3)
    }

    @Test("A full missed day breaks the streak")
    func streakBreaksOnGap() {
        // Days 2, 3, 4 — day 1 and today are both empty, so the run has ended.
        let sessions = [2, 3, 4].map { Self.fast(daysAgo: $0) }
        #expect(Statistics.currentStreak(for: sessions, now: Self.now, calendar: Self.calendar) == 0)
    }

    @Test("Two fasts on one day count once")
    func streakCountsDaysNotFasts() {
        let sessions = [Self.fast(daysAgo: 0, hours: 16), Self.fast(daysAgo: 0, hours: 4)]
        #expect(Statistics.currentStreak(for: sessions, now: Self.now, calendar: Self.calendar) == 1)
    }

    @Test("A running fast never contributes to the streak")
    func streakIgnoresRunningFast() {
        let running = FastSession(
            startDate: Self.now.addingTimeInterval(-3600),
            targetSeconds: 16 * 3600,
            fastingProtocol: .sixteenEight
        )
        #expect(Statistics.currentStreak(for: [running], now: Self.now, calendar: Self.calendar) == 0)
    }

    @Test("No history means no streak")
    func streakEmpty() {
        #expect(Statistics.currentStreak(for: [], now: Self.now, calendar: Self.calendar) == 0)
    }

    // MARK: Longest streak

    @Test("The longest run is found even when it is not the current one")
    func longestStreak() {
        // A run of four a fortnight ago, a run of two now.
        let old = [10, 11, 12, 13].map { Self.fast(daysAgo: $0) }
        let recent = [0, 1].map { Self.fast(daysAgo: $0) }
        let longest = Statistics.longestStreak(for: old + recent, calendar: Self.calendar)
        #expect(longest == 4)
    }

    @Test("A single fast is a streak of one")
    func longestStreakSingle() {
        #expect(Statistics.longestStreak(for: [Self.fast(daysAgo: 3)], calendar: Self.calendar) == 1)
    }

    // MARK: Summary

    @Test("Totals, average and longest come from finished fasts only")
    func summaryAggregates() {
        let sessions = [
            Self.fast(daysAgo: 0, hours: 16),
            Self.fast(daysAgo: 1, hours: 18),
            Self.fast(daysAgo: 2, hours: 14),
            FastSession(
                startDate: Self.now.addingTimeInterval(-7200),
                targetSeconds: 16 * 3600,
                fastingProtocol: .sixteenEight
            )
        ]
        let summary = Statistics.summary(for: sessions, now: Self.now, calendar: Self.calendar)

        #expect(summary.totalFasts == 3)
        #expect(summary.totalSeconds == 48 * 3600)
        #expect(summary.averageSeconds == 16 * 3600)
        #expect(summary.longestSeconds == 18 * 3600)
    }

    @Test("Goal rate counts fasts that reached their target")
    func summaryGoalRate() {
        let sessions = [
            Self.fast(daysAgo: 0, hours: 16, target: 16),
            Self.fast(daysAgo: 1, hours: 18, target: 16),
            Self.fast(daysAgo: 2, hours: 10, target: 16)
        ]
        let summary = Statistics.summary(for: sessions, now: Self.now, calendar: Self.calendar)
        #expect(abs(summary.goalRate - 2.0 / 3.0) < 0.0001)
    }

    @Test("An empty history produces zeroes, not a crash")
    func summaryEmpty() {
        let summary = Statistics.summary(for: [], now: Self.now, calendar: Self.calendar)
        #expect(summary == Statistics.Summary())
    }

    // MARK: Daily totals

    @Test("Daily totals are zero-filled so gaps stay visible in the chart")
    func dailyTotalsZeroFill() throws {
        let sessions = [Self.fast(daysAgo: 0, hours: 16), Self.fast(daysAgo: 3, hours: 12)]
        let totals = Statistics.dailyTotals(
            for: sessions,
            days: 5,
            now: Self.now,
            calendar: Self.calendar
        )

        #expect(totals.count == 5)
        let today = try #require(totals.last)
        #expect(today.seconds == 57_600.0)
        #expect(totals[totals.count - 4].seconds == 43_200.0)  // three days back
        #expect(totals[totals.count - 2].seconds == 0)         // yesterday, nothing
    }

    @Test("Same-day fasts are summed into one bar")
    func dailyTotalsSumsSameDay() {
        let sessions = [Self.fast(daysAgo: 1, hours: 10), Self.fast(daysAgo: 1, hours: 6)]
        let totals = Statistics.dailyTotals(
            for: sessions,
            days: 3,
            now: Self.now,
            calendar: Self.calendar
        )
        #expect(totals[totals.count - 2].seconds == 16 * 3600)
    }

    // MARK: Free-tier window

    @Test("Free tier sees the last seven days, Pro sees everything")
    func visibleWindow() {
        let sessions = (0...20).map { Self.fast(daysAgo: $0) }

        let free = Statistics.visible(
            sessions,
            hasFullAccess: false,
            now: Self.now,
            calendar: Self.calendar
        )
        let pro = Statistics.visible(
            sessions,
            hasFullAccess: true,
            now: Self.now,
            calendar: Self.calendar
        )

        // Today plus the six days before it.
        #expect(free.count == 7)
        #expect(pro.count == 21)
    }
}
