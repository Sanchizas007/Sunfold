import Foundation

nonisolated enum DurationFormat {
    /// "14:23:07" — the big number on the timer. Monospaced digits in the view
    /// keep it from jittering as the seconds tick.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded(.down)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// "16h 30m" — compact, for history rows and stat tiles.
    ///
    /// The unit suffixes come from the string catalog rather than being spliced
    /// in: "16h" is fine in English but reads as an error in Russian, which
    /// wants "16 ч", and the spacing differs per language too.
    static func compact(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 {
            return String(format: String(localized: "duration.minutes"), minutes)
        }
        if minutes == 0 {
            return String(format: String(localized: "duration.hours"), hours)
        }
        return String(format: String(localized: "duration.hoursMinutes"), hours, minutes)
    }

    /// "16h" — used where space is tightest (widget, ring caption).
    static func hoursOnly(_ seconds: TimeInterval) -> String {
        String(
            format: String(localized: "duration.hours"),
            Int((max(0, seconds) / 3600).rounded())
        )
    }
}

nonisolated enum WeightFormat {
    /// "72,4 кг" — one decimal, with the unit name and the decimal separator
    /// both coming from the user's locale.
    static func string(kilograms: Double, unit: WeightUnit) -> String {
        formatter.string(from: Measurement(value: unit.value(fromKilograms: kilograms), unit: unit.unit))
    }

    /// Signed delta, for "since you started" rows: "−0,8 кг".
    ///
    /// The sign is applied to the formatted magnitude rather than to the value,
    /// because `MeasurementFormatter` has no signed style and a bare minus from
    /// the number formatter would land in the wrong place in some locales.
    static func delta(kilograms: Double, unit: WeightUnit) -> String {
        let value = unit.value(fromKilograms: kilograms)
        let magnitude = formatter.string(from: Measurement(value: abs(value), unit: unit.unit))
        // U+2212 MINUS SIGN, not a hyphen — it aligns with digits.
        return (value < 0 ? "\u{2212}" : "+") + magnitude
    }

    private static var formatter: MeasurementFormatter {
        let formatter = MeasurementFormatter()
        // Show the unit the user picked, never the locale's preferred one: a
        // user in a metric country who chose pounds means it.
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .medium
        formatter.numberFormatter.numberStyle = .decimal
        formatter.numberFormatter.minimumFractionDigits = 1
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }
}
