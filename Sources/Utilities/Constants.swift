import Foundation

enum Constants {

    // MARK: - App

    static let appName = "HearthstoneTracker"
    static let appVersion = "1.4.0"
    static let appBuild = 2001 // v2.0 phase1
    
    // MARK: - Keychain
    
    static let keychainAIKey = "aiApiKey"
    static let keychainAIProvider = "aiProviderType"

    // MARK: - File Paths

    static let logFilePaths = [
        "\(NSHomeDirectory())/Library/Logs/Unity/Player.log",
        "/Applications/Hearthstone/Logs/Power.log"
    ]

    static var powerLogPath: String {
        return LogPathFinder.discoverPowerLog() ?? logFilePaths.first ?? ""
    }

    static var cardDataPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("HearthstoneTracker/cards.json").path
    }

    // MARK: - UI

    static let overlayDefaultSize = NSSize(width: 320, height: 480)
    static let overlayMinOpacity = 0.3
    static let overlayMaxOpacity = 1.0
    static let overlayDefaultOpacity = 0.7
}
