import Foundation
import Security

/// Persists demo credentials in the Keychain.
@Observable
@MainActor
final class CredentialsStore {
    private enum Keys {
        static let apiKey = "wiro.example.apiKey"
        static let apiSecret = "wiro.example.apiSecret"
        static let proxyURL = "wiro.example.proxyURL"
        static let useProxy = "wiro.example.useProxy"
    }

    var apiKey: String {
        didSet { Keychain.set(apiKey, for: Keys.apiKey) }
    }

    var apiSecret: String {
        didSet { Keychain.set(apiSecret, for: Keys.apiSecret) }
    }

    var proxyURLString: String {
        didSet { Keychain.set(proxyURLString, for: Keys.proxyURL) }
    }

    var useProxy: Bool {
        didSet {
            UserDefaults.standard.set(useProxy, forKey: Keys.useProxy)
        }
    }

    init() {
        self.apiKey = Keychain.get(Keys.apiKey) ?? ""
        self.apiSecret = Keychain.get(Keys.apiSecret) ?? ""
        self.proxyURLString = Keychain.get(Keys.proxyURL) ?? ""
        self.useProxy = UserDefaults.standard.bool(forKey: Keys.useProxy)
    }

    var hasCredentials: Bool {
        if useProxy {
            return URL(string: proxyURLString) != nil
        }
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum Keychain {
    private static let service =
        Bundle.main.bundleIdentifier ?? "ai.wiro.WiroExample"

    static func set(_ value: String, for key: String) {
        let query = baseQuery(for: key)
        guard !value.isEmpty else {
            SecItemDelete(query as CFDictionary)
            return
        }

        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        guard status == errSecItemNotFound else { return }

        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        SecItemAdd(item as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
