import Foundation
import SwiftUI

/// User preferences, stored in the shared app group so the widget sees the same
/// values the app does.
///
/// Plain stored properties with `didSet` rather than `@AppStorage`: the widget
/// reads several of these from a non-SwiftUI context, and one storage layer for
/// both processes is worth more than the property-wrapper sugar.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = AppGroup.defaults

    // MARK: Fasting

    var selectedProtocol: FastingProtocol {
        didSet { defaults.set(selectedProtocol.rawValue, forKey: Key.selectedProtocol) }
    }

    /// Length of a `.custom` fast, in minutes.
    var customFastMinutes: Int {
        didSet {
            let clamped = min(
                CustomFastLimits.maximumMinutes,
                max(CustomFastLimits.minimumMinutes, customFastMinutes)
            )
            if clamped != customFastMinutes {
                customFastMinutes = clamped
                return
            }
            defaults.set(customFastMinutes, forKey: Key.customFastMinutes)
        }
    }

    // MARK: Presentation

    var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Key.weightUnit) }
    }

    var appearance: AppearanceSetting {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    // MARK: Notifications

    var notifyOnFastComplete: Bool {
        didSet { defaults.set(notifyOnFastComplete, forKey: Key.notifyOnFastComplete) }
    }

    var notifyBeforeFastEnds: Bool {
        didSet { defaults.set(notifyBeforeFastEnds, forKey: Key.notifyBeforeFastEnds) }
    }

    var notifyOnEatingWindowEnd: Bool {
        didSet { defaults.set(notifyOnEatingWindowEnd, forKey: Key.notifyOnEatingWindowEnd) }
    }

    /// Live Activity in the Dynamic Island and on the Lock Screen.
    var liveActivityEnabled: Bool {
        didSet { defaults.set(liveActivityEnabled, forKey: Key.liveActivityEnabled) }
    }

    // MARK: Lifecycle

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    /// First launch, which anchors the 7-day full-access period.
    var firstLaunchDate: Date {
        didSet { defaults.set(firstLaunchDate.timeIntervalSince1970, forKey: Key.firstLaunchDate) }
    }

    /// Set once the user has been asked for notification permission, so Solura
    /// never asks twice and never asks before the first fast is started.
    var hasRequestedNotificationPermission: Bool {
        didSet {
            defaults.set(
                hasRequestedNotificationPermission,
                forKey: Key.hasRequestedNotificationPermission
            )
        }
    }

    private init() {
        let defaults = AppGroup.defaults

        selectedProtocol = defaults.string(forKey: Key.selectedProtocol)
            .flatMap(FastingProtocol.init(rawValue:)) ?? .sixteenEight

        let storedCustom = defaults.integer(forKey: Key.customFastMinutes)
        customFastMinutes = storedCustom == 0 ? 14 * 60 : storedCustom

        weightUnit = defaults.string(forKey: Key.weightUnit)
            .flatMap(WeightUnit.init(rawValue:)) ?? AppSettings.localeWeightUnit()

        appearance = defaults.string(forKey: Key.appearance)
            .flatMap(AppearanceSetting.init(rawValue:)) ?? .system

        notifyOnFastComplete = defaults.object(forKey: Key.notifyOnFastComplete) as? Bool ?? true
        notifyBeforeFastEnds = defaults.object(forKey: Key.notifyBeforeFastEnds) as? Bool ?? true
        notifyOnEatingWindowEnd = defaults.object(forKey: Key.notifyOnEatingWindowEnd) as? Bool ?? true
        liveActivityEnabled = defaults.object(forKey: Key.liveActivityEnabled) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        hasRequestedNotificationPermission = defaults.bool(
            forKey: Key.hasRequestedNotificationPermission
        )

        let stored = defaults.double(forKey: Key.firstLaunchDate)
        if stored > 0 {
            firstLaunchDate = Date(timeIntervalSince1970: stored)
        } else {
            let now = Date.now
            firstLaunchDate = now
            defaults.set(now.timeIntervalSince1970, forKey: Key.firstLaunchDate)
        }
    }

    /// Seconds the currently selected protocol asks for.
    var targetFastSeconds: TimeInterval {
        selectedProtocol.fastSeconds(customMinutes: customFastMinutes)
    }

    var targetEatingSeconds: TimeInterval? {
        selectedProtocol.eatingSeconds(customMinutes: customFastMinutes)
    }

    var protocolLabel: String {
        selectedProtocol.shortLabel(customMinutes: customFastMinutes)
    }

    /// Resets everything a user would expect "delete my data" to reset.
    /// Purchases are intentionally untouched — they belong to the Apple ID.
    func resetToDefaults() {
        for key in Key.allResettable { defaults.removeObject(forKey: key) }
        selectedProtocol = .sixteenEight
        customFastMinutes = 14 * 60
        appearance = .system
        notifyOnFastComplete = true
        notifyBeforeFastEnds = true
        notifyOnEatingWindowEnd = true
        liveActivityEnabled = true
        hasCompletedOnboarding = true
    }

    /// Pounds for the handful of locales that actually use them.
    private static func localeWeightUnit() -> WeightUnit {
        switch Locale.current.region?.identifier {
        case "US", "LR", "MM": .pounds
        default: .kilograms
        }
    }

    private enum Key {
        static let selectedProtocol = "settings.protocol"
        static let customFastMinutes = "settings.customFastMinutes"
        static let weightUnit = "settings.weightUnit"
        static let appearance = "settings.appearance"
        static let notifyOnFastComplete = "settings.notify.complete"
        static let notifyBeforeFastEnds = "settings.notify.before"
        static let notifyOnEatingWindowEnd = "settings.notify.window"
        static let liveActivityEnabled = "settings.liveActivity"
        static let hasCompletedOnboarding = "settings.onboarded"
        static let firstLaunchDate = "settings.firstLaunch"
        static let hasRequestedNotificationPermission = "settings.notifyAsked"

        /// `firstLaunchDate` is deliberately absent: wiping it would hand the
        /// user a fresh 7-day access period every time they cleared data.
        static let allResettable = [
            selectedProtocol, customFastMinutes, weightUnit, appearance,
            notifyOnFastComplete, notifyBeforeFastEnds, notifyOnEatingWindowEnd,
            liveActivityEnabled
        ]
    }
}

nonisolated enum AppearanceSetting: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: String.LocalizationValue {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
}
