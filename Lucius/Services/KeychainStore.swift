import Foundation
import Security

/// Minimal Keychain wrapper for small secrets like the AI Horde API key.
/// Stored items survive reinstalls-from-backup and never land in plain
/// `UserDefaults`. All operations are synchronous and best-effort.
enum KeychainStore {
    private static let service = "com.lucius.app.secrets"

    static func set(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Replace any existing value; a missing item is an acceptable outcome.
        SecItemDelete(query as CFDictionary)

        // An empty value means "clear" — we've already deleted, so we're done.
        guard !value.isEmpty else { return }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(attributes as CFDictionary, nil)
        assert(status == errSecSuccess, "Keychain write failed with status \(status)")
    }

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }

        return value
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// The one secret the app stores today: the optional AI Horde key.
/// Reads transparently migrate any value left over in `UserDefaults`
/// by older builds into the Keychain, then clear the old copy.
enum APIKeyStore {
    private static let account = "aiHordeAPIKey"

    static var aiHordeKey: String {
        get {
            if let key = KeychainStore.get(account) { return key }

            // One-time migration from the old UserDefaults location.
            let legacy = UserDefaults.standard.string(forKey: AppSettingsKeys.aiHordeAPIKey) ?? ""
            if !legacy.isEmpty {
                KeychainStore.set(legacy, for: account)
                UserDefaults.standard.removeObject(forKey: AppSettingsKeys.aiHordeAPIKey)
            }
            return legacy
        }
        set { KeychainStore.set(newValue, for: account) }
    }
}
