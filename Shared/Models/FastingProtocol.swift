import Foundation

/// The fasting schedules Sunfold supports.
///
/// A protocol is stored by its `rawValue` so it survives in SwiftData, in the
/// shared app-group defaults the widget reads, and in exported CSV without a
/// migration. `custom` carries no duration of its own — the user's chosen
/// length lives in `AppSettings.customFastMinutes`, which keeps this a plain
/// string enum.
nonisolated enum FastingProtocol: String, CaseIterable, Codable, Identifiable, Sendable {
    case sixteenEight = "16:8"
    case eighteenSix = "18:6"
    case twentyFour = "20:4"
    case fiveTwo = "5:2"
    case custom = "custom"

    var id: String { rawValue }

    /// Protocols available without Pro. The free tier is deliberately usable:
    /// 16:8 is the schedule most people actually start with.
    static let freeTier: Set<FastingProtocol> = [.sixteenEight]

    var isFree: Bool { Self.freeTier.contains(self) }

    /// Planned fasting length, in seconds, for everything but `.custom`.
    /// `.custom` resolves through `duration(customMinutes:)`.
    var defaultFastSeconds: TimeInterval {
        switch self {
        case .sixteenEight: 16 * 3600
        case .eighteenSix: 18 * 3600
        case .twentyFour: 20 * 3600
        case .fiveTwo: 24 * 3600
        case .custom: 16 * 3600
        }
    }

    /// Planned eating-window length, in seconds. `.fiveTwo` has no fixed window
    /// — it is a weekly pattern — so it reports `nil` and the UI says so.
    var eatingWindowSeconds: TimeInterval? {
        switch self {
        case .sixteenEight: 8 * 3600
        case .eighteenSix: 6 * 3600
        case .twentyFour: 4 * 3600
        case .fiveTwo: nil
        case .custom: nil
        }
    }

    func fastSeconds(customMinutes: Int) -> TimeInterval {
        self == .custom ? TimeInterval(customMinutes) * 60 : defaultFastSeconds
    }

    func eatingSeconds(customMinutes: Int) -> TimeInterval? {
        guard self != .custom else {
            let fasting = TimeInterval(customMinutes) * 60
            return fasting < 24 * 3600 ? 24 * 3600 - fasting : nil
        }
        return eatingWindowSeconds
    }

    /// Short label for the ring and the widget: "16:8", "20:4", "18h".
    func shortLabel(customMinutes: Int) -> String {
        guard self == .custom else { return rawValue }
        let minutes = customMinutes % 60
        let hours = customMinutes / 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    var titleKey: String.LocalizationValue {
        switch self {
        case .sixteenEight: "protocol.16_8.title"
        case .eighteenSix: "protocol.18_6.title"
        case .twentyFour: "protocol.20_4.title"
        case .fiveTwo: "protocol.5_2.title"
        case .custom: "protocol.custom.title"
        }
    }

    var subtitleKey: String.LocalizationValue {
        switch self {
        case .sixteenEight: "protocol.16_8.subtitle"
        case .eighteenSix: "protocol.18_6.subtitle"
        case .twentyFour: "protocol.20_4.subtitle"
        case .fiveTwo: "protocol.5_2.subtitle"
        case .custom: "protocol.custom.subtitle"
        }
    }

    /// One line on who the schedule suits. Descriptive, never prescriptive —
    /// Sunfold does not tell anyone what to do with their body.
    var blurbKey: String.LocalizationValue {
        switch self {
        case .sixteenEight: "protocol.16_8.blurb"
        case .eighteenSix: "protocol.18_6.blurb"
        case .twentyFour: "protocol.20_4.blurb"
        case .fiveTwo: "protocol.5_2.blurb"
        case .custom: "protocol.custom.blurb"
        }
    }

    var symbol: String {
        switch self {
        case .sixteenEight: "circle.lefthalf.filled"
        case .eighteenSix: "circle.righthalf.filled"
        case .twentyFour: "circle.bottomhalf.filled"
        case .fiveTwo: "calendar"
        case .custom: "slider.horizontal.3"
        }
    }
}

/// Bounds on a custom fast, in minutes.
///
/// The 48-hour ceiling is a safety decision, not a technical one: it keeps the
/// app out of multi-day-fast territory it has no business coaching, and keeps
/// it clear of App Review guideline 1.4.1 (physical harm). Anything at or over
/// `advisoryThreshold` shows a "talk to a doctor" notice before it can start.
nonisolated enum CustomFastLimits {
    static let minimumMinutes = 4 * 60
    static let maximumMinutes = 48 * 60
    static let stepMinutes = 30
    /// Fasts at or beyond 24 hours surface a medical-advice notice.
    static let advisorySeconds: TimeInterval = 24 * 3600
}
