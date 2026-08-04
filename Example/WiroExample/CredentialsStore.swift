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
    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
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
}
