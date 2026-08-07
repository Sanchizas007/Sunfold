import Foundation
import Testing

/// The metabolic phase ladder.
struct MetabolicPhaseTests {

    @Test("Each phase starts exactly on its boundary hour", arguments: [
        (0.0, MetabolicPhase.fed),
        (3.99, .fed),
        (4.0, .earlyFasting),
        (11.99, .earlyFasting),
        (12.0, .fatBurning),
        (15.99, .fatBurning),
        (16.0, .ketosis),
        (23.99, .ketosis),
        (24.0, .autophagy),
        (47.0, .autophagy)
    ])
    func phaseBoundaries(hours: Double, expected: MetabolicPhase) {
        #expect(MetabolicPhase.phase(atHours: hours) == expected)
    }

    @Test("A negative elapsed time cannot produce a phase past the first")
    func negativeElapsed() {
        // Can happen for a fast whose start was edited forward, or on a device
        // whose clock moved backwards.
        #expect(MetabolicPhase.phase(forElapsed: -3600) == .fed)
    }

    @Test("Phases chain in order and the last one is open-ended")
    func phaseChain() {
        #expect(MetabolicPhase.fed.next == .earlyFasting)
        #expect(MetabolicPhase.ketosis.next == .autophagy)
        #expect(MetabolicPhase.autophagy.next == nil)
    }

    @Test("Each phase ends where the next one begins, with no gaps")
    func phasesAreContiguous() {
        for phase in MetabolicPhase.allCases {
            guard let next = phase.next else { continue }
            #expect(phase.endHour == next.startHour)
        }
    }

    @Test("Ring ticks fall inside the ring and drop the ones past the goal")
    func tickFractions() {
        // A 16-hour goal passes fed→early (4h), early→fat (12h) and lands
        // exactly on ketosis at 16h, which is the end of the ring and so is
        // excluded.
        let ticks = MetabolicPhase.tickFractions(targetSeconds: 16 * 3600)
        #expect(ticks.count == 2)
        #expect(ticks.allSatisfy { $0 > 0 && $0 < 1 })
        #expect(abs(ticks[0] - 0.25) < 0.0001)
        #expect(abs(ticks[1] - 0.75) < 0.0001)
    }

    @Test("A zero-length goal produces no ticks instead of dividing by zero")
    func tickFractionsZeroTarget() {
        #expect(MetabolicPhase.tickFractions(targetSeconds: 0).isEmpty)
    }
}

/// Session arithmetic: elapsed, progress and which day a fast belongs to.
struct FastSessionTests {

    static let start = Date(timeIntervalSince1970: 1_786_400_000)

    static func session(
        hours: Double? = nil,
        target: Double = 16
    ) -> FastSession {
        FastSession(
            startDate: start,
            endDate: hours.map { start.addingTimeInterval($0 * 3600) },
            targetSeconds: target * 3600,
            fastingProtocol: .sixteenEight
        )
    }

    @Test("A running fast measures against the clock it is given")
    func elapsedRunning() {
        let session = Self.session()
        #expect(session.isRunning)
        #expect(session.elapsed(at: Self.start.addingTimeInterval(7200)) == 7200)
        #expect(session.duration == nil)
    }

    @Test("A finished fast ignores the clock and uses its end date")
    func elapsedFinished() throws {
        let session = Self.session(hours: 10)
        #expect(!session.isRunning)

        let duration = try #require(session.duration)
        #expect(duration == 36_000.0)
        // Passing a much later "now" must not stretch a finished fast.
        #expect(session.elapsed(at: Self.start.addingTimeInterval(100 * 3600)) == 36_000.0)
    }

    @Test("Progress is clamped so an overrun fast fills the ring exactly once")
    func progressClamped() {
        let session = Self.session(hours: 30, target: 16)
        #expect(session.progress() == 1)
    }

    @Test("Progress before the start is zero, never negative")
    func progressBeforeStart() {
        let session = Self.session()
        #expect(session.progress(at: Self.start.addingTimeInterval(-5000)) == 0)
    }

    @Test("A zero target cannot divide by zero")
    func progressZeroTarget() {
        let session = Self.session(hours: 5, target: 0)
        #expect(session.progress() == 0)
    }

    @Test("Reaching the goal is judged on elapsed time, not on stopping")
    func goalReached() {
        #expect(Self.session(hours: 16, target: 16).hasReachedGoal())
        #expect(Self.session(hours: 17, target: 16).hasReachedGoal())
        #expect(!Self.session(hours: 15, target: 16).hasReachedGoal())
    }

    @Test("Stopping short is flagged, and a running fast never is")
    func endedEarly() {
        #expect(Self.session(hours: 12, target: 16).endedEarly)
        #expect(!Self.session(hours: 16, target: 16).endedEarly)
        #expect(!Self.session().endedEarly)
    }

    @Test("A fast is credited to the day it ended, not the day it began")
    func creditedDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Starts 20:00, ends 12:00 the next day — the work was finished on the
        // second day and the streak calendar must mark that day.
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 6, hour: 20))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7, hour: 12))!
        let session = FastSession(
            startDate: start,
            endDate: end,
            targetSeconds: 16 * 3600,
            fastingProtocol: .sixteenEight
        )

        let expected = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!
        #expect(session.creditedDay(in: calendar) == expected)
    }

    @Test("The goal end date is the start plus the target")
    func targetEndDate() {
        #expect(Self.session(target: 18).targetEndDate == Self.start.addingTimeInterval(18 * 3600))
    }
}

/// Protocol definitions and the free-tier gate.
struct FastingProtocolTests {

    @Test("Only 16:8 is free — the free tier has to be genuinely usable")
    func freeTier() {
        #expect(FastingProtocol.sixteenEight.isFree)
        for locked in [FastingProtocol.eighteenSix, .twentyFour, .fiveTwo, .custom] {
            #expect(!locked.isFree)
        }
    }

    @Test("Fasting and eating windows add up to a day for the fixed protocols")
    func windowsAddUp() throws {
        for item in [FastingProtocol.sixteenEight, .eighteenSix, .twentyFour] {
            let eating = try #require(item.eatingWindowSeconds)
            #expect(item.defaultFastSeconds + eating == 24 * 3600)
        }
    }

    @Test("5:2 is a weekly pattern and reports no fixed eating window")
    func fiveTwoHasNoWindow() {
        #expect(FastingProtocol.fiveTwo.eatingWindowSeconds == nil)
        #expect(FastingProtocol.fiveTwo.defaultFastSeconds == 24 * 3600)
    }

    @Test("A custom fast takes its length from settings")
    func customLength() {
        #expect(FastingProtocol.custom.fastSeconds(customMinutes: 14 * 60) == 14 * 3600)
        // Fixed protocols ignore the custom value entirely.
        #expect(FastingProtocol.sixteenEight.fastSeconds(customMinutes: 999) == 16 * 3600)
    }

    @Test("A custom fast of a day or more has no eating window left to report")
    func customWindow() throws {
        let window = try #require(FastingProtocol.custom.eatingSeconds(customMinutes: 14 * 60))
        #expect(window == 36_000.0)
        #expect(FastingProtocol.custom.eatingSeconds(customMinutes: 24 * 60) == nil)
        #expect(FastingProtocol.custom.eatingSeconds(customMinutes: 36 * 60) == nil)
    }

    @Test("Short labels stay short")
    func shortLabels() {
        #expect(FastingProtocol.sixteenEight.shortLabel(customMinutes: 0) == "16:8")
        #expect(FastingProtocol.custom.shortLabel(customMinutes: 14 * 60) == "14h")
        #expect(FastingProtocol.custom.shortLabel(customMinutes: 14 * 60 + 30) == "14h 30m")
    }

    @Test("Raw values round-trip so stored history survives an update")
    func rawValuesAreStable() {
        for item in FastingProtocol.allCases {
            #expect(FastingProtocol(rawValue: item.rawValue) == item)
        }
        // These strings are written into SwiftData and exported CSV; changing
        // one silently reclassifies every past fast.
        #expect(FastingProtocol.sixteenEight.rawValue == "16:8")
        #expect(FastingProtocol.fiveTwo.rawValue == "5:2")
        #expect(FastingProtocol.custom.rawValue == "custom")
    }

    @Test("The custom range is bounded on both ends")
    func customLimits() {
        #expect(CustomFastLimits.minimumMinutes == 4 * 60)
        #expect(CustomFastLimits.maximumMinutes == 48 * 60)
        #expect(CustomFastLimits.advisorySeconds == 24 * 3600)
        #expect(CustomFastLimits.advisorySeconds < Double(CustomFastLimits.maximumMinutes) * 60)
    }
}
