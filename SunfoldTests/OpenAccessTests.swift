import Foundation
import Testing

@testable import Sunfold

/// The rule that decides how many days of full access an install gets for free.
///
/// Worth its own tests because both ways of getting it wrong are expensive and
/// neither shows up in a build: too generous and the paywall is never reached,
/// which is the funnel 1.2 exists to fix; too mean and an existing user loses
/// days they were already promised, which is the kind of thing people write
/// one-star reviews about.
@Suite("Open access period")
struct OpenAccessTests {
    @Test("A fresh install gets no open days and meets the paywall")
    func freshInstall() {
        let days = AppSettings.openAccessDays(hasExistingLaunchDate: false, stored: nil)
        #expect(days == 0)
    }

    @Test("An install that predates 1.2 keeps the seven days it was given")
    func upgradeFromOlderVersion() {
        let days = AppSettings.openAccessDays(hasExistingLaunchDate: true, stored: nil)
        #expect(days == AppSettings.legacyOpenAccessDays)
        #expect(days == 7)
    }

    @Test("Once recorded the answer never changes", arguments: [0, 3, 7])
    func recordedAnswerWins(stored: Int) {
        // Both branches must honour the stored value: a later launch has a
        // launch date on disk either way, so without this an upgrade would
        // silently hand every new install the legacy seven days back.
        #expect(AppSettings.openAccessDays(hasExistingLaunchDate: true, stored: stored) == stored)
        #expect(AppSettings.openAccessDays(hasExistingLaunchDate: false, stored: stored) == stored)
    }
}
