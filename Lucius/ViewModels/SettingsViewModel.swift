import Foundation
import SwiftData
import UserNotifications

/// Notification preferences: the on/off toggle and system permission.
@Observable
@MainActor
final class SettingsViewModel {
    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: AppSettingsKeys.notificationsEnabled)
        }
    }

    var aiHordeAPIKey: String {
        didSet {
            APIKeyStore.aiHordeKey = aiHordeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var learningLanguageCode: String {
        didSet { AppLanguageSettings.learningLanguageCode = learningLanguageCode }
    }

    var translationLanguageCode: String {
        didSet { AppLanguageSettings.translationLanguageCode = translationLanguageCode }
    }

    let availableLanguages = AppLanguageSettings.availableLanguages

    private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined
    private(set) var apiKeyStatus: String?
    private(set) var isVerifyingAPIKey = false

    init() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: AppSettingsKeys.notificationsEnabled)
        aiHordeAPIKey = APIKeyStore.aiHordeKey
        learningLanguageCode = AppLanguageSettings.learningLanguageCode
        translationLanguageCode = AppLanguageSettings.translationLanguageCode
    }

    var permissionStatusDescription: String {
        switch permissionStatus {
        case .authorized, .provisional, .ephemeral: "Granted"
        case .denied: "Denied"
        case .notDetermined: "Not requested yet"
        @unknown default: "Unknown"
        }
    }

    func refreshPermissionStatus() async {
        permissionStatus = await NotificationService.shared.authorizationStatus()
    }

    func requestPermission() async {
        await NotificationService.shared.requestPermission()
        await refreshPermissionStatus()
    }

    /// Confirms the AI Horde key is recognized and shows its kudos —
    /// the balance that drives generation queue priority.
    func verifyAPIKey() async {
        let key = aiHordeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            apiKeyStatus = "Enter a key first."
            return
        }

        isVerifyingAPIKey = true
        defer { isVerifyingAPIKey = false }

        do {
            let user = try await ImageGenerationService.shared.validateAPIKey(key)
            apiKeyStatus = "Key OK — \(user.username), \(Int(user.kudos)) kudos"
        } catch {
            apiKeyStatus = "Key not recognized — check it for typos."
        }
    }

    /// Cancels everything when notifications are turned off,
    /// or re-creates reminders for all upcoming reviews when turned back on.
    func applyNotificationsSetting(context: ModelContext) {
        if notificationsEnabled {
            let allWords = (try? context.fetch(FetchDescriptor<VocabularyWord>())) ?? []
            NotificationService.shared.rescheduleAll(for: allWords)
        } else {
            NotificationService.shared.cancelAllNotifications()
        }
    }
}
