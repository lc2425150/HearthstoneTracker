import Foundation

enum Constants {

    // MARK: - App

    static let appName = "HearthstoneTracker"
    static let appVersion = "1.0.0"

    // MARK: - File Paths

    static let logFilePaths = [
        "\(NSHomeDirectory())/Library/Logs/Unity/Player.log",
        "/Applications/Hearthstone/Logs/Power.log"
    ]

    /// Power.log 路径（日志监控使用第一条匹配路径）
    static var powerLogPath: String {
        for path in logFilePaths {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return logFilePaths.first ?? ""
    }

    /// 卡牌JSON数据本地缓存路径
    static var cardDataPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("HearthstoneTracker/cards.json").path
    }

    // MARK: - UI

    static let overlayDefaultSize = NSSize(width: 320, height: 480)
    static let overlayMinOpacity = 0.3
    static let overlayMaxOpacity = 1.0
    static let overlayDefaultOpacity = 0.7

    // MARK: - Hotkeys

    static let toggleOverlayKey = "o"
    static let importDeckKey = "i"
    static let hotkeyModifiers = "cmd+shift"

    // MARK: - API

    static let cardDataUpdateURL = "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json"

    // MARK: - Card

    static let standardDeckSizes = [30, 40]
    static let maxDeckSize = 60
}