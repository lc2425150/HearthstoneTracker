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
    
    init(dbfId: Int, cardId: String = "", name: String, cost: Int, cardClass: String, rarity: String, type: String, set: String) {
        self.dbfId = dbfId
        self.cardId = cardId
        self.name = name
        self.cost = cost
        self.cardClass = cardClass
        self.rarity = rarity
        self.type = type
        self.set = set
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
        let c = try! ModelContainer(for: Card.self, MatchRecord.self, SavedDeck.self)
        _container = c
        return c
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
