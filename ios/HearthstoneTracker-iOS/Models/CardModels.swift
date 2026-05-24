import Foundation
import SwiftData

// MARK: - Card Data Model

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
    var text: String
    var attack: Int?
    var health: Int?

    init(dbfId: Int, cardId: String = "", name: String, cost: Int,
         cardClass: String, rarity: String, type: String, set: String,
         text: String = "", attack: Int? = nil, health: Int? = nil) {
        self.dbfId = dbfId
        self.cardId = cardId
        self.name = name
        self.cost = cost
        self.cardClass = cardClass
        self.rarity = rarity
        self.type = type
        self.set = set
        self.text = text
        self.attack = attack
        self.health = health
    }
}

extension Card: Identifiable {
    var id: Int { dbfId }
}

// MARK: - Deck Model

@Model
final class SavedDeck {
    var id: UUID
    var name: String
    var deckCode: String
    var playerClass: String
    var cardDbfIds: [Int]
    var createdAt: Date
    var updatedAt: Date

    init(name: String, deckCode: String, playerClass: String,
         cardDbfIds: [Int], createdAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.deckCode = deckCode
        self.playerClass = playerClass
        self.cardDbfIds = cardDbfIds
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

// MARK: - Match Record

@Model
final class MatchRecord {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var playerClass: String
    var opponentClass: String
    var result: String  // win / loss / unknown
    var deckCode: String
    var notes: String
    var coin: Bool  // whether player went second

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    init(startTime: Date = Date(), playerClass: String, opponentClass: String,
         result: String = "unknown", deckCode: String, notes: String = "",
         coin: Bool = false) {
        self.id = UUID()
        self.startTime = startTime
        self.playerClass = playerClass
        self.opponentClass = opponentClass
        self.result = result
        self.deckCode = deckCode
        self.notes = notes
        self.coin = coin
    }
}

// MARK: - In-Memory Tracking Models

struct TrackedCard: Identifiable {
    let id = UUID()
    let card: Card
    let action: CardAction
    let turn: Int
    let timestamp: Date
}

enum CardAction: String, CaseIterable {
    case draw = "抽到"
    case play = "打出"
    case discard = "弃掉"
    case destroy = "消灭"
    case discover = "发现"
    case returnToHand = "回手"
    case mulligan = "换牌"
}

enum CardZone {
    case deck
    case hand
    case battlefield
    case graveyard
    case discovered
}

struct LiveMatchState {
    var playerClass: String
    var opponentClass: String
    var deckCards: [Card]           // original deck
    var remainingDeck: [Card]       // cards still in deck
    var handCards: [Card]           // cards in hand
    var playedCards: [Card]         // cards played this game
    var destroyedCards: [Card]
    var discoveredCards: [Card]     // discovered/generated cards
    var turnNumber: Int
    var coin: Bool
    var isTracking: Bool
    var startTime: Date

    static let empty = LiveMatchState(
        playerClass: "", opponentClass: "",
        deckCards: [], remainingDeck: [],
        handCards: [], playedCards: [],
        destroyedCards: [], discoveredCards: [],
        turnNumber: 0, coin: false,
        isTracking: false, startTime: Date()
    )
}

// MARK: - Card Class Helpers

enum HearthstoneClass: String, CaseIterable {
    case deathKnight = "DEATHKNIGHT"
    case demonHunter = "DEMONHUNTER"
    case druid = "DRUID"
    case hunter = "HUNTER"
    case mage = "MAGE"
    case paladin = "PALADIN"
    case priest = "PRIEST"
    case rogue = "ROGUE"
    case shaman = "SHAMAN"
    case warlock = "WARLOCK"
    case warrior = "WARRIOR"
    case neutral = "NEUTRAL"

    var displayName: String {
        switch self {
        case .deathKnight: return "死亡骑士"
        case .demonHunter: return "恶魔猎手"
        case .druid: return "德鲁伊"
        case .hunter: return "猎人"
        case .mage: return "法师"
        case .paladin: return "圣骑士"
        case .priest: return "牧师"
        case .rogue: return "潜行者"
        case .shaman: return "萨满"
        case .warlock: return "术士"
        case .warrior: return "战士"
        case .neutral: return "中立"
        }
    }

    var iconName: String {
        switch self {
        case .deathKnight: return "skewis"
        case .demonHunter: return "flame"
        case .druid: return "leaf"
        case .hunter: return "arrow"
        case .mage: return "sparkle"
        case .paladin: return "shield"
        case .priest: return "cross"
        case .rogue: return "dagger"
        case .shaman: return "drop"
        case .warlock: return "flame"
        case .warrior: return "shield"
        case .neutral: return "star"
        }
    }
}
