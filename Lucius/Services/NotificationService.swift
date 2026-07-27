import Foundation
import UserNotifications

/// Keys for user preferences stored in UserDefaults.
enum AppSettingsKeys {
    static let notificationsEnabled = "notificationsEnabled"
    static let aiHordeAPIKey = "aiHordeAPIKey"
    static let learningLanguageCode = "learningLanguageCode"
    static let translationLanguageCode = "translationLanguageCode"
}

typealias LanguageOption = SupportedLanguage

/// The currently selected language pair, shared by OCR, speech and translation.
enum AppLanguageSettings {
    static var learningLanguageCode: String {
        get {
            learningLanguageCode(defaults: .standard)
        }
        set { UserDefaults.standard.set(SupportedLanguage(rawValue: newValue)?.rawValue ?? SupportedLanguage.english.rawValue, forKey: AppSettingsKeys.learningLanguageCode) }
    }

    static func learningLanguageCode(defaults: UserDefaults) -> String {
        let saved = defaults.string(forKey: AppSettingsKeys.learningLanguageCode) ?? SupportedLanguage.english.rawValue
        return SupportedLanguage(rawValue: saved)?.rawValue ?? SupportedLanguage.english.rawValue
    }

    static var translationLanguageCode: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: AppSettingsKeys.translationLanguageCode),
               let language = SupportedLanguage(rawValue: saved),
               language.rawValue != learningLanguageCode {
                return language.rawValue
            }
            let deviceLanguage = SupportedLanguage.systemLanguage.rawValue
            return deviceLanguage == learningLanguageCode
                ? (SupportedLanguage.allCases.first { $0.rawValue != learningLanguageCode }?.rawValue ?? SupportedLanguage.english.rawValue)
                : deviceLanguage
        }
        set {
            guard let language = SupportedLanguage(rawValue: newValue), language.rawValue != learningLanguageCode else { return }
            UserDefaults.standard.set(language.rawValue, forKey: AppSettingsKeys.translationLanguageCode)
        }
    }

    static let availableLanguages: [LanguageOption] = SupportedLanguage.allCases

    static func displayName(for code: String) -> String {
        availableLanguages.first(where: { $0.code == code })?.nativeName ?? SupportedLanguage.english.nativeName
    }
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
        content.title = String(format: String(localized: "notification.review_title"), word.word)
        content.body = String(localized: "notification.review_body")
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
