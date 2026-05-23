import Foundation
import SwiftData

/// 卡牌数据更新器：从 HearthstoneJSON API 获取最新卡牌数据，写入本地数据库
@MainActor
final class CardDataUpdater {
    private let database: CardDatabase
    private let session: URLSession

    init(database: CardDatabase) {
        self.database = database
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Public

    /// 检查并下载最新卡牌数据
    func checkForUpdates() async throws -> UpdateResult {
        let url = URL(string: Constants.cardDataUpdateURL)!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }

        let cards = try parseCardJSON(data)
        try await database.seedCards(cards)

        return UpdateResult(
            totalCards: cards.count,
            timestamp: Date()
        )
    }

    // MARK: - Private Parsing

    private func parseCardJSON(_ data: Data) throws -> [CardSeedData] {
        let decoder = JSONDecoder()

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

        let rawCards = try decoder.decode([RawCard].self, from: data)

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

// MARK: - Database Seeding Extension

extension CardDatabase {
    func seedCards(_ seedData: [CardSeedData]) async throws {
        let context = modelContainer.mainContext

        // 批量插入：先获取已有 DBF ID 集合，避免重复
        let existingIds = try Set(
            context.fetch(FetchDescriptor<Card>()).map { $0.dbfId }
        )

        for data in seedData where !existingIds.contains(data.dbfId) {
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
}