import Foundation
import Security

/// Keychain 安全存储封装
enum KeychainManager {
    private static let service = Bundle.main.bundleIdentifier ?? "com.hearthstoneTracker"
    
    /// 保存值到 Keychain
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // 删除旧记录
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        
        // 新增记录
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// 从 Keychain 读取值
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// 从 Keychain 删除值
    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    /// 迁移 UserDefaults 中的值到 Keychain
    static func migrateFromUserDefaults(userDefaultsKey: String, keychainKey: String) {
        guard read(key: keychainKey) == nil else { return } // 已迁移
        guard let value = UserDefaults.standard.string(forKey: userDefaultsKey), !value.isEmpty else { return }
        
        if save(key: keychainKey, value: value) {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            print("[Keychain] 已迁移 \(userDefaultsKey) → \(keychainKey)")
        }
    }
    
    // MARK: - HSReplay Token
    
    private static let hsreplayService = "com.hearthstonetracker.hsreplay"
    
    @discardableResult
    static func saveHSReplayToken(_ token: String) -> Bool {
        return save(key: "hsreplay_token", value: token, customService: hsreplayService)
    }
    
    static func getHSReplayToken() -> String? {
        return read(key: "hsreplay_token", customService: hsreplayService)
    }
    
    static func clearHSReplayToken() {
        delete(key: "hsreplay_token", customService: hsreplayService)
    }
    
    // MARK: - Custom Service Support
    
    private static func save(key: String, value: String, customService: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: customService
        ]
        SecItemDelete(query as CFDictionary)
        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(newQuery as CFDictionary, nil) == errSecSuccess
    }
    
    private static func read(key: String, customService: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: customService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private static func delete(key: String, customService: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: customService
        ]
        SecItemDelete(query as CFDictionary)
    }
}
