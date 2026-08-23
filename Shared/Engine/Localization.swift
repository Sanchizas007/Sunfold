import Foundation

/// The language Sunfold renders in.
///
/// `.system` follows the device and is the default. The explicit choices exist
/// because this app's audience routinely reads one language and carries a phone
/// set to another — a Ukrainian speaker with a Russian-language phone should not
/// have to change the whole device to read a fasting timer.
nonisolated enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case ukrainian = "uk"
    case russian = "ru"

    var id: String { rawValue }

    /// The code to resolve strings against; `nil` means "follow the device".
    var code: String? { self == .system ? nil : rawValue }

    /// Drives dates, numbers and SwiftUI's own `Text("key")` lookups.
    ///
    /// Lives on the case rather than only on `Localization` so a view can read
    /// it through the observed settings object and redraw the moment the
    /// language changes, instead of waiting for a relaunch.
    var locale: Locale {
        guard let code else { return .autoupdatingCurrent }
        return Locale(identifier: code)
    }

    /// Written in the language itself — "Українська", not "Ukrainian".
    ///
    /// Whoever opens this list is quite likely there because they cannot read
    /// the language the app is currently in, so the options must not be
    /// translated into it.
    var displayName: String {
        guard let code else { return .sunfold("language.system") }
        return Locale(identifier: code)
            .localizedString(forLanguageCode: code)?
            .localizedCapitalized
            ?? code.uppercased()
    }
}

/// Resolves every user-facing string and date against the chosen language.
///
/// Reads the App Group directly instead of going through `AppSettings`, because
/// the widget and the Live Activity render in a different process where that
/// object does not exist. A language setting that stopped at the app's edge
/// would leave the screens in one language and the notifications and widget in
/// another, which is the whole failure this layer exists to prevent.
nonisolated enum Localization {
    static let defaultsKey = "settings.language"

    static var current: AppLanguage {
        AppGroup.defaults.string(forKey: defaultsKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// Drives date, number and measurement formatting outside SwiftUI.
    static var locale: Locale { current.locale }

    /// The `.lproj` carrying the chosen language, or the ordinary bundle when
    /// following the device.
    ///
    /// Resolved against `Bundle.sunfold` rather than `Bundle.main` so it is
    /// correct in the widget extension and in the test bundle too.
    static var bundle: Bundle {
        guard
            let code = current.code,
            let path = Bundle.sunfold.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return .sunfold }
        return bundle
    }
}

nonisolated extension String {
    /// Every user-facing string in Sunfold goes through here.
    ///
    /// `String(localized:)` on its own resolves against the device language, so
    /// a single call left behind is a sentence that stays in the wrong language
    /// while everything around it changes.
    static func sunfold(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: Localization.bundle, locale: Localization.locale)
    }

    /// The key is a `StaticString` here, not a `LocalizationValue`: Foundation
    /// only offers `defaultValue:` on that overload, and a default only makes
    /// sense for a key written out in the source anyway.
    static func sunfold(
        _ key: StaticString,
        defaultValue: String.LocalizationValue
    ) -> String {
        String(
            localized: key,
            defaultValue: defaultValue,
            bundle: Localization.bundle,
            locale: Localization.locale
        )
    }
}

nonisolated extension Date {
    /// Formatted in the app's language rather than the device's.
    ///
    /// Deliberately absent from CSV export, where dates are ISO 8601 and must
    /// not follow anything the user picked.
    func sunfoldFormatted(
        date: Date.FormatStyle.DateStyle,
        time: Date.FormatStyle.TimeStyle
    ) -> String {
        formatted(Date.FormatStyle(date: date, time: time, locale: Localization.locale))
    }

    func sunfoldFormatted(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(Localization.locale))
    }
}
