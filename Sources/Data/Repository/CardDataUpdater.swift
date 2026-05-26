import Foundation
import SwiftData

/// 卡牌数据更新器：从多个数据源获取最新卡牌数据，写入本地数据库
@MainActor
final class CardDataUpdater {
    private let database: CardDatabase
    private let session: URLSession

    init(database: CardDatabase) {
        self.database = database
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // 30 秒超时，防止卡死
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public

    /// 从指定数据源下载并更新卡牌数据
    func checkForUpdates(from source: CardDataSource) async throws -> UpdateResult {
        let url = URL(string: source.apiURL)!
        
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }

        let cards: [CardSeedData]
        switch source {
        case .hearthstoneJSON:
            cards = try parseHearthstoneJSON(data)
        case .hsReplay:
            cards = try parseHearthstoneJSON(data)
        case .hearthPwn:
            cards = try parseHearthstoneJSON(data)
        }

        // 清空旧数据并用新数据重填
        try await database.replaceAllCards(cards)

        return UpdateResult(
            totalCards: cards.count,
            timestamp: Date(),
            source: source
        )
    }

    // MARK: - HearthstoneJSON Parser

    private func parseHearthstoneJSON(_ data: Data) throws -> [CardSeedData] {
        struct RawCard: Codable {
            let dbfId: Int
            let id: String?
            let name: String?
            let cost: Int?
            let cardClass: String?
            let rarity: String?
            let type: String?
            let set: String?
        }

        let rawCards = try JSONDecoder().decode([RawCard].self, from: data)

        return rawCards.compactMap { raw in
            guard raw.type != "HERO", raw.type != "HERO_POWER" else { return nil }
            return CardSeedData(
                dbfId: raw.dbfId,
                cardId: raw.id ?? "",
                name: raw.name ?? "未知",
                cost: raw.cost ?? 0,
                cardClass: raw.cardClass ?? "NEUTRAL",
                rarity: raw.rarity ?? "FREE",
                type: raw.type ?? "MINION",
                set: raw.set ?? "UNKNOWN"
            )
        }
    }

    // MARK: - HSReplay.net Parser

    private func parseHSReplayJSON(_ data: Data) throws -> [CardSeedData] {
        struct HSReplayCard: Codable {
            let dbf_id: Int
            let id: String?
            let name: String?
            let cost: Int?
            let card_class: String?
            let rarity: String?
            let type: String?
            let card_set: String?
        }

        let rawCards = try JSONDecoder().decode([HSReplayCard].self, from: data)

        return rawCards.compactMap { raw in
            guard raw.type != "HERO", raw.type != "HERO_POWER" else { return nil }
            return CardSeedData(
                dbfId: raw.dbf_id,
                cardId: raw.id ?? "",
                name: raw.name ?? "未知",
                cost: raw.cost ?? 0,
                cardClass: raw.card_class ?? "NEUTRAL",
                rarity: raw.rarity ?? "FREE",
                type: raw.type ?? "MINION",
                set: raw.card_set ?? "UNKNOWN"
            )
        }
    }

    // MARK: - HearthPwn Parser

    private func parseHearthPwnHTML(_ data: Data) throws -> [CardSeedData] {
        // HearthPwn 不提供标准 JSON API，返回空列表并用其他源
        // 这里作为备用/扩展点，实际使用中 HearthPwn 需要网页抓取
        print("[CardDataUpdater] HearthPwn 使用备用数据源")
        return []
    }
}

// MARK: - Types

struct CardSeedData {
    let dbfId: Int
    let cardId: String
    let name: String
    let cost: Int
    let cardClass: String
    let rarity: String
    let type: String
    let set: String
}

struct UpdateResult {
    let totalCards: Int
    let timestamp: Date
    let source: CardDataSource
}

enum UpdateError: Error, LocalizedError {
    case networkError
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .networkError: return "网络请求失败"
        case .parseError(let msg): return "数据解析失败: \(msg)"
        }
    }
}

// MARK: - Database Extension

extension CardDatabase {
    /// 清空所有卡牌并批量插入新数据
    func replaceAllCards(_ seedData: [CardSeedData]) async throws {
        let context = modelContainer.mainContext

        // 删除所有旧卡牌
        let fetchDescriptor = FetchDescriptor<Card>()
        let oldCards = try context.fetch(fetchDescriptor)
        for card in oldCards {
            context.delete(card)
        }

        // 批量插入新卡牌
        for data in seedData {
            let card = Card(
                dbfId: data.dbfId,
                cardId: data.cardId,
                name: data.name,
                cost: data.cost,
                cardClass: data.cardClass,
                rarity: data.rarity,
                type: data.type,
                set: data.set
            )
            context.insert(card)
        }

        if context.hasChanges {
            try context.save()
        }
    }
    
    /// 获取本地卡牌总数（用于判断是否已下载）
    func countAllCards() -> Int {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Card>()
        return (try? context.fetchCount(descriptor)) ?? 0
    }
    
    /// 获取本地卡牌数据的最后更新时间
    func lastUpdateDate() -> Date? {
        let userDefaults = UserDefaults.standard
        if let date = userDefaults.object(forKey: "cardDataLastUpdate") as? Date {
            return date
        }
        return nil
    }
    
    /// 保存卡牌数据的最后更新时间
    func saveLastUpdateDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "cardDataLastUpdate")
    }
}
