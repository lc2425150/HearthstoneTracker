import Foundation

/// @propertyWrapper 用于 UserDefaults 存取
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    init(_ key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// HSTracker 风格的静态配置类
enum Settings {
    static let shared = Settings.self
    
    // AI 设置
    @UserDefault("aiProviderType", defaultValue: "tongyi")
    static var aiProviderType: String
    
    @UserDefault("aiAnalysisMode", defaultValue: "auto")
    static var aiAnalysisMode: String
    
    // 悬浮窗设置
    @UserDefault("windowsLocked", defaultValue: false)
    static var windowsLocked: Bool
    
    @UserDefault("overlayWidth", defaultValue: 280.0)
    static var overlayWidth: Double
    
    @UserDefault("overlayOpacity", defaultValue: 0.7)
    static var overlayOpacity: Double
    
    @UserDefault("overlayInsideGame", defaultValue: false)
    static var overlayInsideGame: Bool
    
    @UserDefault("overlayAutoHide", defaultValue: false)
    static var overlayAutoHide: Bool
    
    // 追踪设置
    @UserDefault("ocrOpponentTracking", defaultValue: true)
    static var ocrOpponentTracking: Bool
    
    @UserDefault("cardDisplaySize", defaultValue: "medium")
    static var cardDisplaySize: String
    
    // AI API Key - 从 Keychain 读取
    static var aiApiKey: String {
        get { KeychainManager.read(key: "aiApiKey") ?? "" }
        set {
            if newValue.isEmpty {
                KeychainManager.delete(key: "aiApiKey")
            } else {
                _ = KeychainManager.save(key: "aiApiKey", value: newValue)
            }
        }
    }
}
