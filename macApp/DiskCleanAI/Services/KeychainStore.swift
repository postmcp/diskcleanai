import Foundation
import Security

/// Minimal generic-password wrapper. The OpenRouter key never touches UserDefaults,
/// and it survives the app being deleted and reinstalled.
enum KeychainStore {
    static let service = "ai.diskclean.app"
    static let openRouterAccount = "openrouter-api-key"

    /// Items written by the paid builds (license key, trial and license tokens, device id).
    /// The app is free and open source now, so they are deleted on launch.
    private static let legacyLicensingAccounts = ["license-key", "license-token", "trial-token", "trial-started", "device-id"]

    enum KeychainError: LocalizedError {
        case status(OSStatus)

        var errorDescription: String? {
            switch self {
            case .status(let s): return SecCopyErrorMessageString(s, nil) as String? ?? "Keychain error \(s)"
            }
        }
    }

    static func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrLabel as String] = account == openRouterAccount ? "Disk Clean AI — OpenRouter key" : "Disk Clean AI — \(account)"
            let added = SecItemAdd(insert as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError.status(added) }
        } else if status != errSecSuccess {
            throw KeychainError.status(status)
        }
    }

    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func removeLegacyLicensing() {
        legacyLicensingAccounts.forEach(delete(account:))
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
