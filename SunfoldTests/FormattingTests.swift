import Foundation
import Testing

struct DurationFormatTests {

    @Test("The ring clock is zero-padded and never shows a negative time", arguments: [
        (0.0, "0:00:00"),
        (59.0, "0:00:59"),
        (60.0, "0:01:00"),
        (3661.0, "1:01:01"),
        (57_784.0, "16:03:04"),
        (-500.0, "0:00:00")
    ])
    func clock(seconds: TimeInterval, expected: String) {
        #expect(DurationFormat.clock(seconds) == expected)
    }

    @Test("The clock truncates rather than rounding, so it never shows a second early")
    func clockTruncates() {
        // At 59.9s elapsed the user has not yet been fasting a minute.
        #expect(DurationFormat.clock(59.9) == "0:00:59")
    }

    @Test("Hours past a day keep counting instead of wrapping")
    func clockPastADay() {
        #expect(DurationFormat.clock(36 * 3600 + 61) == "36:01:01")
    }

    @Test("Compact durations carry the number and drop empty units")
    func compact() {
        // The unit suffix comes from the string catalog and changes per
        // language, so the assertion is on the numbers, which do not.
        let hoursAndMinutes = DurationFormat.compact(16 * 3600 + 30 * 60)
        #expect(hoursAndMinutes.contains("16"))
        #expect(hoursAndMinutes.contains("30"))

        let wholeHours = DurationFormat.compact(16 * 3600)
        #expect(wholeHours.contains("16"))
        #expect(!wholeHours.contains("0 "))

        let minutesOnly = DurationFormat.compact(45 * 60)
        #expect(minutesOnly.contains("45"))
    }

    @Test("Localised units resolve — a raw key here means the catalog was lost")
    func compactIsLocalised() {
        // Guards the bundle lookup in Formatters: if `String(localized:)` ever
        // falls back to `Bundle.main` again this returns "duration.hours".
        #expect(!DurationFormat.compact(16 * 3600).contains("duration."))
        #expect(!DurationFormat.hoursOnly(16 * 3600).contains("duration."))
    }

    @Test("Hours-only rounds to the nearest hour")
    func hoursOnly() {
        #expect(DurationFormat.hoursOnly(16 * 3600).contains("16"))
        #expect(DurationFormat.hoursOnly(16 * 3600 + 31 * 60).contains("17"))
        #expect(DurationFormat.hoursOnly(-5).contains("0"))
    }
}

struct WeightTests {

    @Test("Kilograms and pounds round-trip without drifting")
    func roundTrip() {
        for kilograms in [45.0, 70.0, 88.6, 120.4] {
            let pounds = WeightUnit.pounds.value(fromKilograms: kilograms)
            let back = WeightUnit.pounds.kilograms(fromValue: pounds)
            #expect(abs(back - kilograms) < 0.000001)
        }
    }

    @Test("Kilograms pass through untouched")
    func kilogramsIdentity() {
        #expect(WeightUnit.kilograms.value(fromKilograms: 72.4) == 72.4)
        #expect(WeightUnit.kilograms.kilograms(fromValue: 72.4) == 72.4)
    }

    @Test("The conversion matches the international pound")
    func conversionFactor() {
        let pounds = WeightUnit.pounds.value(fromKilograms: 100)
        #expect(abs(pounds - 220.46226218) < 0.00001)
    }

    @Test("Both units can express the same real weights")
    func ranges() {
        let kg = WeightUnit.kilograms.range
        let lb = WeightUnit.pounds.range
        #expect(kg.contains(70))
        #expect(lb.contains(154))

        // Whatever a user can record in kilograms they must also be able to
        // record in pounds, or switching units would clip their weight.
        #expect(lb.lowerBound <= WeightUnit.pounds.value(fromKilograms: kg.lowerBound))
        #expect(lb.upperBound >= WeightUnit.pounds.value(fromKilograms: kg.upperBound))
    }

    @Test("Formatted weights carry the value and a localised unit")
    func formatting() {
        let text = WeightFormat.string(kilograms: 72.4, unit: .kilograms)
        #expect(text.contains("72"))
        // MeasurementFormatter localises the unit; it must not be the raw enum
        // value spliced in by hand.
        #expect(!text.isEmpty)
    }

    @Test("A loss is signed with a real minus, a gain with a plus")
    func deltaSigns() {
        #expect(WeightFormat.delta(kilograms: -0.8, unit: .kilograms).hasPrefix("\u{2212}"))
        #expect(WeightFormat.delta(kilograms: 0.8, unit: .kilograms).hasPrefix("+"))
        #expect(WeightFormat.delta(kilograms: 0, unit: .kilograms).hasPrefix("+"))
    }
}

struct SnapshotTests {

    static let start = Date(timeIntervalSince1970: 1_786_400_000)

    static var fasting: FastingSnapshot {
        FastingSnapshot(
            mode: .fasting,
            startDate: start,
            endDate: start.addingTimeInterval(16 * 3600),
            protocolLabel: "16:8",
            streakDays: 5,
            hasFullAccess: true,
            updatedAt: start
        )
    }

    @Test("Progress runs from nothing to full across the window")
    func progress() {
        let snapshot = Self.fasting
        #expect(snapshot.progress(at: Self.start) == 0)
        #expect(snapshot.progress(at: Self.start.addingTimeInterval(8 * 3600)) == 0.5)
        #expect(snapshot.progress(at: Self.start.addingTimeInterval(16 * 3600)) == 1)
    }

    @Test("Progress is clamped at both ends")
    func progressClamped() {
        let snapshot = Self.fasting
        #expect(snapshot.progress(at: Self.start.addingTimeInterval(-3600)) == 0)
        #expect(snapshot.progress(at: Self.start.addingTimeInterval(40 * 3600)) == 1)
    }

    @Test("An idle snapshot has no dates and reports no progress")
    func idle() {
        #expect(FastingSnapshot.idle.mode == .idle)
        #expect(FastingSnapshot.idle.progress(at: Self.start) == 0)
        #expect(FastingSnapshot.idle.elapsed(at: Self.start) == 0)
        #expect(FastingSnapshot.idle.phase == nil)
    }

    @Test("The snapshot survives the trip through JSON to the widget")
    func codingRoundTrip() throws {
        // This is the only contract between the app and the widget process; a
        // silent decode failure would leave the widget permanently idle.
        let data = try JSONEncoder.sunfold.encode(Self.fasting)
        let decoded = try JSONDecoder.sunfold.decode(FastingSnapshot.self, from: data)
        #expect(decoded == Self.fasting)
    }

    @Test("Only a running fast reports a metabolic phase")
    func phaseOnlyWhileFasting() {
        var eating = Self.fasting
        eating.mode = .eating
        #expect(eating.phase == nil)
    }
}
