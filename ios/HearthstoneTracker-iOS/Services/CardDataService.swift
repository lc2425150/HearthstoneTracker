import Foundation
import SwiftData

// MARK: - Card Data Service

@MainActor
final class CardDataService: ObservableObject {
    private let modelContext: ModelContext
    private let session: URLSession

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    /// 获取最新卡牌版本号
    func fetchLatestVersion() async throws -> String {
        let url = URL(string: "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json")!
        // 先获取版本信息
        let versionURL = URL(string: "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json")!
        _ = versionURL

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.networkError
        }
        // 从重定向URL提取版本
        if let finalURL = httpResponse.url {
            let pathComponents = finalURL.pathComponents
            if let versionIndex = pathComponents.firstIndex(where: { $0 == "v1" }),
               versionIndex + 1 < pathComponents.count {
                return pathComponents[versionIndex + 1]
            }
        }
        return "latest"
    }

    /// 下载并更新卡牌数据
    func updateCardData() async throws -> UpdateResult {
        let url = URL(string: "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ServiceError.networkError
        }

        // 解析 JSON
        let decoder = JSONDecoder()
        let rawCards = try decoder.decode([RawCard].self, from: data)

        // 批量导入到 SwiftData
        var importedCount = 0
        for rawCard in rawCards {
            guard !rawCard.name.isEmpty, rawCard.dbfId > 0 else { continue }

            let card = Card(
                dbfId: rawCard.dbfId,
                cardId: rawCard.id ?? "",
                name: rawCard.name,
                cost: rawCard.cost ?? 0,
                cardClass: rawCard.cardClass ?? "NEUTRAL",
                rarity: rawCard.rarity ?? "FREE",
                type: rawCard.type ?? "",
                set: rawCard.set ?? "",
                text: rawCard.text ?? "",
                attack: rawCard.attack,
                health: rawCard.health
            )
            modelContext.insert(card)
            importedCount += 1
        }

        // 保存
        try modelContext.save()

        // 记录更新时间
        UserDefaults.standard.set(Date(), forKey: Constants.UserDefaultsKeys.lastDataUpdate)

        return UpdateResult(
            version: "latest",
            cardCount: importedCount,
            date: Date()
        )
    }

    /// 检查是否需要更新
    func needsUpdate() -> Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lastDataUpdate) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastUpdate) > 86400 * 7  // 7天
    }

    /// 获取卡牌总数
    func cardCount() -> Int {
        let descriptor = FetchDescriptor<Card>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// 根据 DBF ID 查找卡牌
    func card(by dbfId: Int) -> Card? {
        let predicate = #Predicate<Card> { $0.dbfId == dbfId }
        let descriptor = FetchDescriptor<Card>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    /// 根据名称搜索卡牌
    func searchCards(query: String) -> [Card] {
        guard !query.isEmpty else { return [] }
        let predicate = #Predicate<Card> { $0.name.contains(query) }
        let descriptor = FetchDescriptor<Card>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 根据职业获取卡牌
    func cards(forClass: String) -> [Card] {
        let predicate = #Predicate<Card> {
            $0.cardClass == forClass || $0.cardClass == "NEUTRAL"
        }
        let descriptor = FetchDescriptor<Card>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 批量获取卡牌
    func cards(by dbfIds: [Int]) -> [Card] {
        let predicate = #Predicate<Card> { dbfIds.contains($0.dbfId) }
        let descriptor = FetchDescriptor<Card>(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Models

struct UpdateResult {
    let version: String
    let cardCount: Int
    let date: Date
}

enum ServiceError: Error, LocalizedError {
    case networkError
    case parseError
    case databaseError

    var errorDescription: String? {
        switch self {
        case .networkError: return "网络连接失败，请检查网络"
        case .parseError: return "数据解析失败"
        case .databaseError: return "数据库错误"
        }
    }
}

// MARK: - Raw Card JSON

private struct RawCard: Codable {
    let dbfId: Int
    let id: String?
    let name: String
    let cost: Int?
    let cardClass: String?
    let rarity: String?
    let type: String?
    let set: String?
    let text: String?
    let attack: Int?
    let health: Int?
}
