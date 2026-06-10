import Foundation
import SwiftData

@Model
final class Card {
    var dbfId: Int
    var cardId: String
    var name: String
    var cost: Int
    var cardClass: String
    var rarity: String
    var type: String
    var set: String
    
    var enName: String = ""
    var attack: Int = 0
    var health: Int = 0
    var race: String = ""
    var races: [String] = []
    var spellSchool: String = ""
    var mechanics: [String] = []
    var isStandard: Bool = false
    var collectible: Bool = true
    var artist: String = ""
    var flavor: String = ""
    var techLevel: Int = 0
    var overload: Int = 0
    var multiClassGroup: String = ""
    var hideStats: Bool = false
    
    init(dbfId: Int, cardId: String = "", name: String, cost: Int, cardClass: String, rarity: String, type: String, set: String, 
         enName: String = "", attack: Int = 0, health: Int = 0) {
        self.dbfId = dbfId
        self.cardId = cardId
        self.name = name
        self.cost = cost
        self.cardClass = cardClass
        self.rarity = rarity
        self.type = type
        self.set = set
        self.enName = enName
        self.attack = attack
        self.health = health
    }
}

extension Card: Identifiable {
    var id: Int { dbfId }
}

struct TrackedDeck {
    let deckCode: String
    let heroClass: HeroClass
    var discoveredCards: [DiscoveredCard]
    
    // 卡牌数量追踪（dbfId → 剩余张数）
    var cardCounts: [Int: Int] = [:]  // dbfId → count
    var cardPool: [Int: Card] = [:]   // dbfId → Card 对象
    
    // 完整卡牌列表（含复制）
    var allCards: [Card] {
        cardPool.values.sorted(by: { $0.cost < $1.cost })
    }
    
    var remainingOriginal: [Card] {
        cardCounts.filter { $0.value > 0 }.compactMap { cardPool[$0.key] }.sorted(by: { $0.cost < $1.cost })
    }
    
    /// 所有原始卡牌（唯一卡牌 + 完整数量）
    var allOriginalCards: [(card: Card, count: Int)] {
        cardPool.values.map { card in
            (card: card, count: cardCounts[card.dbfId] ?? 1)
        }.sorted(by: { $0.card.cost < $1.card.cost })
    }
    var remainingOriginalCount: Int { cardCounts.values.reduce(0, +) }
    var totalOriginalCount: Int { originalTotal }
    
    private let originalTotal: Int
    
    // 手牌/已打出追踪（实体ID列表）
    var handOriginal: [Card] = []
    var playedOriginal: [Card] = []
    
    init(deckCode: String, cards: [(card: Card, count: Int)], discoveredCards: [DiscoveredCard] = [], heroClass: HeroClass) {
        self.deckCode = deckCode
        self.heroClass = heroClass
        self.discoveredCards = discoveredCards
        var counts: [Int: Int] = [:]
        var pool: [Int: Card] = [:]
        var total = 0
        for (card, count) in cards {
            counts[card.dbfId] = count
            pool[card.dbfId] = card
            total += count
        }
        self.cardCounts = counts
        self.cardPool = pool
        self.originalTotal = total
    }
    
    /// 获取卡牌剩余张数
    func countOf(card dbfId: Int) -> Int { cardCounts[dbfId] ?? 0 }
    
    /// 获取卡牌原始总张数
    func originalCountOf(card dbfId: Int) -> Int { 2 } // 默认2张，传奇1张
}

struct DiscoveredCard: Identifiable {
    let id = UUID()
    let card: Card
    let source: DiscoverySource
    let timestamp: Date
    var isPlayed = false
}


extension DiscoveredCard {
    var sourceLabel: String {
        switch source {
        case .discover: return "发现"
        case .random: return "随机"
        case .generated(let by): return by
        }
    }
}

enum DiscoverySource: Equatable {
    case discover(pool: [Card])
    case random(from: Card)
    case generated(by: String)
}

enum HeroClass: String, CaseIterable {
    case druid, hunter, mage, paladin, priest, rogue, shaman, warlock, warrior, demonHunter, deathKnight, unknown
    var displayName: String {
        switch self {
        case .druid: return "德鲁伊"
        case .hunter: return "猎人"
        case .mage: return "法师"
        case .paladin: return "圣骑士"
        case .priest: return "牧师"
        case .rogue: return "潜行者"
        case .shaman: return "萨满"
        case .warlock: return "术士"
        case .warrior: return "战士"
        case .demonHunter: return "恶魔猎手"
        case .deathKnight: return "死亡骑士"
        case .unknown: return "未知"
        }
    }
}

enum CardEventType { case draw, play, discard, destroy, discover, create, secret }

struct CardEvent {
    let type: CardEventType
    let card: Card
    let player: Player
    let timestamp: Date
    let confidence: Double
    let metadata: [String: Any]?
}

enum Player { case player, opponent }

// 注册所有模型的容器
@MainActor
class CardDatabase {
    private var _container: ModelContainer?
    var modelContainer: ModelContainer {
        if let c = _container { return c }
        do {
            let c = try ModelContainer(for: Card.self, MatchRecord.self, SavedDeck.self)
            _container = c
            return c
        } catch {
            print("[CardDatabase] Failed to create ModelContainer: \(error)")
            // 如果默认配置失败，尝试内存配置（仅用于本次运行）
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let c = try ModelContainer(for: Card.self, MatchRecord.self, SavedDeck.self, configurations: config)
                _container = c
                return c
            } catch {
                fatalError("[CardDatabase] Cannot create any ModelContainer: \(error)")
            }
        }
    }
    let allModels: [any PersistentModel.Type] = [Card.self, MatchRecord.self, SavedDeck.self]
    
    init() {
        // ModelContainer 改为懒加载，启动不阻塞主线程
    }
    
    func card(for dbfId: Int) -> Card? {
        let desc = FetchDescriptor<Card>(predicate: #Predicate { $0.dbfId == dbfId })
        return try? modelContainer.mainContext.fetch(desc).first
    }
    
    func card(forCardId cardId: String) -> Card? {
        let desc = FetchDescriptor<Card>(predicate: #Predicate { $0.cardId == cardId })
        return try? modelContainer.mainContext.fetch(desc).first
    }
    
    func cards(for dbfIds: [Int]) -> [Card] { dbfIds.compactMap { card(for: $0) } }
    
    // MARK: - 增强搜索
    
    /// 获取所有卡牌
    var allStoredCards: [Card] {
        let desc = FetchDescriptor<Card>()
        return (try? modelContainer.mainContext.fetch(desc)) ?? []
    }
    
    func cardByEnglishName(_ name: String) -> Card? {
        return allStoredCards.first { $0.enName == name || $0.name == name }
    }
    
    func cardsByClass(_ cardClass: String) -> [Card] {
        return allStoredCards.filter { $0.cardClass == cardClass }
    }
    
    func cardsByCostRange(min: Int, max: Int) -> [Card] {
        return allStoredCards.filter { $0.cost >= min && $0.cost <= max }
    }
    
    func cardsByMechanic(_ mechanic: String) -> [Card] {
        return allStoredCards.filter { $0.mechanics.contains(mechanic) }
    }
    
    func search(query: String?, cardClass: String?, 
                costRange: ClosedRange<Int>?, mechanic: String?, 
                rarity: String?) -> [Card] {
        var results = allStoredCards
        if let query = query, !query.isEmpty {
            let lower = query.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(lower) ||
                $0.enName.lowercased().contains(lower) ||
                $0.cardId.lowercased().contains(lower)
            }
        }
        if let cardClass = cardClass, cardClass != "all" {
            results = results.filter { $0.cardClass == cardClass }
        }
        if let costRange = costRange {
            results = results.filter { costRange.contains($0.cost) }
        }
        if let mechanic = mechanic, !mechanic.isEmpty {
            results = results.filter { $0.mechanics.contains(mechanic) }
        }
        if let rarity = rarity, !rarity.isEmpty, rarity != "all" {
            results = results.filter { $0.rarity == rarity }
        }
        return results
    }
}


// MARK: - 稀有度颜色

extension Card {
    var rarityColor: String {
        switch rarity {
        case "COMMON":    return "gray"
        case "RARE":      return "blue"
        case "EPIC":      return "purple"
        case "LEGENDARY": return "orange"
        default:          return "gray"
        }
    }
}

// MARK: - 卡牌尺寸

enum CardDisplaySize: String, CaseIterable, Codable {
    case small = "小"
    case medium = "中"
    case large = "大"
    
    var displayName: String { rawValue }
    
    var rowHeight: CGFloat {
        switch self {
        case .small:  return 22
        case .medium: return 28
        case .large:  return 36
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small:  return 10
        case .medium: return 12
        case .large:  return 14
        }
    }
    
    var overlayWidth: CGFloat {
        switch self {
        case .small:  return 260
        case .medium: return 320
        case .large:  return 380
        }
    }

}
