import Foundation
import Testing

/// The in-app language switch.
///
/// These matter more than they look: everything a SwiftUI `Text("key")` renders
/// follows the environment locale on its own, so a broken `String.sunfold`
/// stays invisible on most of a screen and surfaces only in the few places that
/// build strings by hand — which is exactly how it shipped the first time.
struct LocalizationTests {

    /// Runs `body` with the app language forced, then puts the setting back.
    private func withLanguage(_ code: String?, _ body: () -> Void) {
        let defaults = AppGroup.defaults
        let original = defaults.string(forKey: Localization.defaultsKey)
        defer {
            if let original {
                defaults.set(original, forKey: Localization.defaultsKey)
            } else {
                defaults.removeObject(forKey: Localization.defaultsKey)
            }
        }
        if let code {
            defaults.set(code, forKey: Localization.defaultsKey)
        } else {
            defaults.removeObject(forKey: Localization.defaultsKey)
        }
        body()
    }

    @Test("A chosen language moves hand-built strings, not just SwiftUI text")
    func stringsFollowChosenLanguage() {
        withLanguage("uk") {
            #expect(String.sunfold("tab.settings") == "Налаштування")
        }
        withLanguage("ru") {
            #expect(String.sunfold("tab.settings") == "Настройки")
        }
        withLanguage("en") {
            #expect(String.sunfold("tab.settings") == "Settings")
        }
    }

    @Test("The bundle resolves to the chosen language, not the device's")
    func bundleFollowsChosenLanguage() {
        withLanguage("uk") {
            #expect(Localization.bundle.bundlePath.hasSuffix("uk.lproj"))
        }
        withLanguage(nil) {
            #expect(Localization.current == .system)
            #expect(Localization.bundle == .sunfold)
        }
    }

    @Test("Dates follow the chosen language too")
    func datesFollowChosenLanguage() {
        // 2026-08-22 is a Saturday.
        let date = Date(timeIntervalSince1970: 1_787_356_800)
        withLanguage("en") {
            #expect(date.sunfoldFormatted(.dateTime.weekday(.wide)).lowercased() == "saturday")
        }
        withLanguage("uk") {
            #expect(date.sunfoldFormatted(.dateTime.weekday(.wide)).lowercased() == "субота")
        }
    }
}
