import Foundation
import SwiftData

/// A single weight reading.
///
/// Always stored in kilograms regardless of what the user is shown, so that
/// switching units never rewrites or rounds the history. Conversion happens at
/// the edge, in the formatter.
@Model
final class WeightEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var kilograms: Double = 0
    var note: String = ""

    init(id: UUID = UUID(), date: Date = .now, kilograms: Double, note: String = "") {
        self.id = id
        self.date = date
        self.kilograms = kilograms
        self.note = note
    }
}

nonisolated enum WeightUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case kilograms = "kg"
    case pounds = "lb"

    var id: String { rawValue }

    /// The Foundation unit, so `MeasurementFormatter` can render "kg" / "кг" /
    /// "фнт" itself instead of the app splicing in an English abbreviation.
    var unit: UnitMass {
        switch self {
        case .kilograms: .kilograms
        case .pounds: .pounds
        }
    }

    static let poundsPerKilogram = 2.2046226218

    func value(fromKilograms kg: Double) -> Double {
        switch self {
        case .kilograms: kg
        case .pounds: kg * Self.poundsPerKilogram
        }
    }

    func kilograms(fromValue value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value / Self.poundsPerKilogram
        }
    }

    /// Plausible human range, used to bound the picker and reject typos.
    var range: ClosedRange<Double> {
        switch self {
        case .kilograms: 25...350
        case .pounds: 55...770
        }
    }

    var titleKey: String.LocalizationValue {
        switch self {
        case .kilograms: "unit.kilograms"
        case .pounds: "unit.pounds"
        }
    }
}
