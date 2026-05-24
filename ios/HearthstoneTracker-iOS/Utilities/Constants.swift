import Foundation

enum Constants {
    static let appName = "炉边记牌器"
    static let appVersion = "1.0.0"

    // HearthstoneJSON API
    static let hearthstoneJSONURL = "https://api.hearthstonejson.com/v1/"
    static let cardImageURL = "https://art.hearthstonejson.com/v1/render/latest/zhCN/256x/"

    // 卡牌数据源
    enum DataSource: String, CaseIterable {
        case hearthstoneJSON = "HearthstoneJSON"

        var displayName: String {
            switch self {
            case .hearthstoneJSON: return "HearthstoneJSON"
            }
        }

        var apiURL: String {
            switch self {
            case .hearthstoneJSON: return "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json"
            }
        }
    }

    // 用户默认值键
    enum UserDefaultsKeys {
        static let lastDataUpdate = "lastDataUpdate"
        static let savedDecks = "savedDecks"
        static let enableOCR = "enableOCR"
        static let autoTrack = "autoTrack"
        static let selectedClass = "selectedClass"
    }

    // 通知名称
    static let cardDataUpdated = Notification.Name("cardDataUpdated")
    static let matchStarted = Notification.Name("matchStarted")
    static let matchEnded = Notification.Name("matchEnded")
}
