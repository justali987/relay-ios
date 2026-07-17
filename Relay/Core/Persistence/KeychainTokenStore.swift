import Foundation
import Security

/// Secure storage for per-device pairing tokens/keys (e.g. webOS client keys, Tizen tokens).
/// Device identity and capabilities live in `DeviceStore`; only the secret material lives here.
actor KeychainTokenStore {
    private let service = "com.relay.app.pairingTokens"

    enum KeychainError: Error {
        case unhandled(OSStatus)
    }

    func setToken(_ token: String, forDeviceID deviceID: UUID) throws {
        let data = Data(token.utf8)
        let account = deviceID.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        // Remove any existing item before writing — SecItemAdd fails on a duplicate account.
        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(newItem as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    func token(forDeviceID deviceID: UUID) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func removeToken(forDeviceID deviceID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
