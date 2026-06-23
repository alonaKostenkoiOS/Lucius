import Foundation
import UserNotifications

/// Keys for user preferences stored in UserDefaults.
enum AppSettingsKeys {
    static let notificationsEnabled = "notificationsEnabled"
    static let aiHordeAPIKey = "aiHordeAPIKey"
}

/// Schedules and cancels local review reminders.
/// One pending notification per word, identified by the word's UUID.
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Permission

    @discardableResult
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Replaces any pending notification for this word with one
    /// matching its current `nextReviewDate`.
    func scheduleReviewNotification(for word: VocabularyWord) {
        cancelNotification(for: word)

        guard defaults.bool(forKey: AppSettingsKeys.notificationsEnabled),
              let reviewDate = word.nextReviewDate,
              reviewDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to review: \(word.word)"
        content.body = "Open Lucius and remember the visual association."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: reviewDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: word.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func cancelNotification(for word: VocabularyWord) {
        center.removePendingNotificationRequests(withIdentifiers: [word.id.uuidString])
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// Re-creates notifications for every word with an upcoming review.
    /// Used when the user re-enables notifications in Settings.
    func rescheduleAll(for words: [VocabularyWord]) {
        cancelAllNotifications()
        words.forEach { scheduleReviewNotification(for: $0) }
    }
}
