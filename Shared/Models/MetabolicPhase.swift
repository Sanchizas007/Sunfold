import Foundation
import SwiftUI

/// The metabolic phases Sunfold shows around the ring.
///
/// Everything here is presented as approximate and educational. The copy is
/// deliberately hedged ("typically", "in many people") and the phases screen
/// carries a standing disclaimer: real timings depend on the person, their last
/// meal, activity and health. Sunfold makes no diagnostic or treatment claim —
/// that is both honest and what keeps it clear of guideline 1.4.1.
nonisolated enum MetabolicPhase: String, CaseIterable, Identifiable, Sendable {
    case fed
    case earlyFasting
    case fatBurning
    case ketosis
    case autophagy

    var id: String { rawValue }

    /// Hours from the start of the fast at which the phase typically begins.
    var startHour: Double {
        switch self {
        case .fed: 0
        case .earlyFasting: 4
        case .fatBurning: 12
        case .ketosis: 16
        case .autophagy: 24
        }
    }

    /// Hours at which the phase typically gives way to the next one.
    /// `autophagy` is open-ended; Sunfold caps display at 48 hours.
    var endHour: Double {
        switch self {
        case .fed: 4
        case .earlyFasting: 12
        case .fatBurning: 16
        case .ketosis: 24
        case .autophagy: 48
        }
    }

    static func phase(atHours hours: Double) -> MetabolicPhase {
        allCases.last { hours >= $0.startHour } ?? .fed
    }

    static func phase(forElapsed seconds: TimeInterval) -> MetabolicPhase {
        phase(atHours: max(0, seconds) / 3600)
    }

    /// The next phase, or `nil` once the last one is reached.
    var next: MetabolicPhase? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    var titleKey: String.LocalizationValue {
        switch self {
        case .fed: "phase.fed.title"
        case .earlyFasting: "phase.early.title"
        case .fatBurning: "phase.fat.title"
        case .ketosis: "phase.ketosis.title"
        case .autophagy: "phase.autophagy.title"
        }
    }

    var summaryKey: String.LocalizationValue {
        switch self {
        case .fed: "phase.fed.summary"
        case .earlyFasting: "phase.early.summary"
        case .fatBurning: "phase.fat.summary"
        case .ketosis: "phase.ketosis.summary"
        case .autophagy: "phase.autophagy.summary"
        }
    }

    var detailKey: String.LocalizationValue {
        switch self {
        case .fed: "phase.fed.detail"
        case .earlyFasting: "phase.early.detail"
        case .fatBurning: "phase.fat.detail"
        case .ketosis: "phase.ketosis.detail"
        case .autophagy: "phase.autophagy.detail"
        }
    }

    var symbol: String {
        switch self {
        case .fed: "fork.knife"
        case .earlyFasting: "drop"
        case .fatBurning: "flame"
        case .ketosis: "sparkles"
        case .autophagy: "leaf"
        }
    }

    /// Each phase gets its own step along the warm ramp, honey → plum, so the
    /// ring reads as one continuous journey rather than five unrelated states.
    var color: Color {
        switch self {
        case .fed: Palette.dynamic(light: 0xE0A94F, dark: 0xF2C879)
        case .earlyFasting: Palette.dynamic(light: 0xD9873F, dark: 0xF0A96F)
        case .fatBurning: Palette.dynamic(light: 0xCE6A45, dark: 0xE88A66)
        case .ketosis: Palette.dynamic(light: 0xB55771, dark: 0xD2778C)
        case .autophagy: Palette.dynamic(light: 0x8A5B94, dark: 0xBF9BC7)
        }
    }
}
