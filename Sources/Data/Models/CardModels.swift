import Foundation
import SwiftData

// MARK: - Card Model

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
    public var id: Int { dbfId }
}

// MARK: - Deck Models

struct TrackedDeck {
    let deckCode: String
    let originalCards: [Card]
    var discoveredCards: [DiscoveredCard]
    let heroClass: HeroClass
    var remainingOriginal: [Card]
    var playedOriginal: [Card] = []
    var handOriginal: [Card] = []

    var remainingOriginalCount: Int { remainingOriginal.count }
    var totalOriginalCount: Int { originalCards.count }
    var playedOriginalCount: Int { playedOriginal.count }
    var handOriginalCount: Int { handOriginal.count }
}

struct DiscoveredCard: Identifiable {
    let id = UUID()
    let card: Card
    let source: DiscoverySource
    let timestamp: Date
    var isPlayed = false

    var sourceLabel: String {
        switch source {
        case .discover:  return "发现"
        case .random:    return "随机"
        case .generated(let by): return "来自 \(by)"
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
        case .druid:        return "德鲁伊"
        case .hunter:       return "猎人"
        case .mage:         return "法师"
        case .paladin:      return "圣骑士"
        case .priest:       return "牧师"
        case .rogue:        return "潜行者"
        case .shaman:       return "萨满"
        case .warlock:      return "术士"
        case .warrior:      return "战士"
        case .demonHunter:  return "恶魔猎手"
        case .deathKnight:  return "死亡骑士"
        case .unknown:      return "未知"
        }
    }
}

// MARK: - Event Models

enum CardEventType {
    case draw
    case play
    case discard
    case destroy
    case discover
    case create
    case secret
}

struct CardEvent {
    let type: CardEventType
    let card: Card
    let player: Player
    let timestamp: Date
    let confidence: Double
    let metadata: [String: Any]?
}

enum Player {
    case player, opponent
}

// MARK: - Database

@MainActor
class CardDatabase {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Card.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func card(for dbfId: Int) -> Card? {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.dbfId == dbfId })
        do {
            return try modelContainer.mainContext.fetch(descriptor).first
        } catch {
            print("[CardDatabase] Fetch error: \(error)")
            return nil
        }
    }

    func card(forCardId cardId: String) -> Card? {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.cardId == cardId })
        do {
            return try modelContainer.mainContext.fetch(descriptor).first
        } catch {
            print("[CardDatabase] Fetch error: \(error)")
            return nil
        }
    }

    func cards(for dbfIds: [Int]) -> [Card] {
        dbfIds.compactMap { card(for: $0) }
    }
}