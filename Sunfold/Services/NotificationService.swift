import Foundation
import UserNotifications

/// Local notifications only — Sunfold has no server, no push token and no APNs
/// entitlement. That keeps the privacy label honest and removes a whole class
/// of review questions about what the app sends where.
@Observable
final class NotificationService {
    static let shared = NotificationService()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let fastComplete = "sunfold.fast.complete"
        static let fastEndingSoon = "sunfold.fast.endingSoon"
        static let eatingWindowEnd = "sunfold.window.end"

        static let all = [fastComplete, fastEndingSoon, eatingWindowEnd]
    }

    /// How far ahead of the goal the heads-up fires.
    static let headsUpLead: TimeInterval = 30 * 60

    private init() {}

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Asked for the first time only when the user starts a fast — a permission
    /// prompt on first launch, before the app has shown its worth, is the
    /// fastest way to a permanent "Don't Allow".
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        await refreshStatus()
        guard authorizationStatus == .notDetermined else {
            return authorizationStatus == .authorized || authorizationStatus == .provisional
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        AppSettings.shared.hasRequestedNotificationPermission = true
        await refreshStatus()
        return granted
    }

    // MARK: Scheduling

    /// Replaces every pending Sunfold notification with the set implied by a
    /// running fast. Called on start, on edit and on relaunch, so a rescheduled
    /// start time can never leave a stale alert behind.
    func scheduleForFast(
        endingAt endDate: Date,
        eatingWindowSeconds: TimeInterval?,
        settings: AppSettings
    ) async {
        cancelAll()
        guard await isAuthorized() else { return }

        if settings.notifyBeforeFastEnds {
            let fireDate = endDate.addingTimeInterval(-Self.headsUpLead)
            await add(
                id: ID.fastEndingSoon,
                title: String(localized: "notification.endingSoon.title"),
                body: String(localized: "notification.endingSoon.body"),
                at: fireDate
            )
        }

        if settings.notifyOnFastComplete {
            await add(
                id: ID.fastComplete,
                title: String(localized: "notification.complete.title"),
                body: String(localized: "notification.complete.body"),
                at: endDate
            )
        }

        if settings.notifyOnEatingWindowEnd, let eatingWindowSeconds {
            await add(
                id: ID.eatingWindowEnd,
                title: String(localized: "notification.windowEnd.title"),
                body: String(localized: "notification.windowEnd.body"),
                at: endDate.addingTimeInterval(eatingWindowSeconds)
            )
        }
    }

    /// After a fast is stopped, only the end-of-eating-window reminder remains.
    func scheduleForEatingWindow(endingAt endDate: Date, settings: AppSettings) async {
        cancelAll()
        guard settings.notifyOnEatingWindowEnd, await isAuthorized() else { return }
        await add(
            id: ID.eatingWindowEnd,
            title: String(localized: "notification.windowEnd.title"),
            body: String(localized: "notification.windowEnd.body"),
            at: endDate
        )
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: ID.all)
        center.removeDeliveredNotifications(withIdentifiers: ID.all)
    }

    // MARK: Internals

    private func isAuthorized() async -> Bool {
        await refreshStatus()
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    private func add(id: String, title: String, body: String, at date: Date) async {
        // A fire date in the past would either deliver immediately or be
        // dropped; neither is useful, so it is simply skipped.
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await center.add(request)
    }
}
