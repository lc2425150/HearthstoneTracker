import Foundation

/// Power.log 日志解析器：逐行解析，维护实体状态机，检测卡牌事件
@MainActor
final class PowerLogParser {
    // MARK: - Entity State

    private struct EntityState {
        var zone: LogZone = .unknown
        var cardId: String?
        var controller: Int = 0
        var cost: Int = 0
        var entityName: String?
    }

    enum LogZone: String {
        case deck = "DECK"
        case hand = "HAND"
        case play = "PLAY"
        case graveyard = "GRAVEYARD"
        case setaside = "SETASIDE"
        case secret = "SECRET"
        case removed = "REMOVEDFROMGAME"
        case unknown
    }

    // MARK: - Properties

    private var entities: [Int: EntityState] = [:]
    private var playerControllerID: Int = 0
    private var gameInProgress = false
    private var playerDeckDBFIds: [Int] = []
    private var currentBlock: LogBlock?
    private let cardDatabase: CardDatabase

    // MARK: - Event Callback

    var onEvent: ((ParsedLogEvent) -> Void)?
    var onGameStart: (() -> Void)?
    var onDeckCards: (([Int]) -> Void)?

    // MARK: - Log Block Tracking

    private enum LogBlock {
        case fullEntity(entityId: Int, cardId: String?)
        case showEntity(entityId: Int, cardId: String?)
        case tagChange(entityId: Int)
        case hideEntity(entityId: Int)
    }

    init(database: CardDatabase) {
        self.cardDatabase = database
    }

    // MARK: - Public

    func feedLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasSuffix("CREATE_GAME") {
            reset()

        } else if trimmed.hasPrefix("FULL_ENTITY") {
            let (entityId, cardId) = parseEntityCreation(trimmed, pattern: "FULL_ENTITY")
            entities[entityId] = EntityState(cardId: cardId)
            currentBlock = .fullEntity(entityId: entityId, cardId: cardId)

        } else if trimmed.hasPrefix("SHOW_ENTITY") {
            let (entityId, cardId) = parseEntityCreation(trimmed, pattern: "SHOW_ENTITY")
            currentBlock = .showEntity(entityId: entityId, cardId: cardId)

        } else if trimmed.hasPrefix("TAG_CHANGE") {
            let entityId = parseEntityId(trimmed)
            currentBlock = .tagChange(entityId: entityId)

        } else if trimmed.hasPrefix("HIDE_ENTITY") {
            let entityId = parseEntityId(trimmed)
            currentBlock = .hideEntity(entityId: entityId)

        } else if trimmed.hasPrefix("tag=") {
            handleTagLine(trimmed)

        } else {
            currentBlock = nil
        }
    }

    func reset() {
        entities.removeAll()
        playerControllerID = 0
        currentBlock = nil
    }

    // MARK: - Parse Helpers

    private func parseEntityCreation(_ line: String, pattern: String) -> (Int, String?) {
        var entityId = 0
        var cardId: String?

        if let idRange = line.range(of: "ID=") {
            let idStr = String(line[idRange.upperBound...])
                .prefix(while: { $0.isNumber })
            entityId = Int(idStr) ?? 0
        }

        if let cardRange = line.range(of: "CardID=") {
            cardId = String(line[cardRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
        }

        return (entityId, cardId)
    }

    private func parseEntityId(_ line: String) -> Int {
        guard let entityRange = line.range(of: "Entity=") else { return 0 }

        // entityName=... 格式：找到下一个 tag= 之前或行尾
        let start = line[entityRange.upperBound...]
        // Entity 描述中可能嵌套数字，取第一个 ID 数字
        if let idRange = start.range(of: "id=") {
            let afterId = start[idRange.upperBound...]
            let idStr = String(afterId.prefix(while: { $0.isNumber }))
            return Int(idStr) ?? 0
        }
        return 0
    }

    private func handleTagLine(_ line: String) {
        guard let block = currentBlock else { return }

        let (tag, value) = parseTagValue(line)

        switch block {
        case .fullEntity(let entityId, _),
             .showEntity(let entityId, _),
             .tagChange(let entityId):
            handleEntityTag(entityId: entityId, tag: tag, value: value)

        case .hideEntity:
            // HIDE_ENTITY 在下一行触发
            handleEntityTag(entityId: blockEntityId(), tag: tag, value: value)
            break
        }

        currentBlock = nil
    }

    private func blockEntityId() -> Int {
        guard let block = currentBlock else { return 0 }
        switch block {
        case .fullEntity(let id, _): return id
        case .showEntity(let id, _): return id
        case .tagChange(let id):     return id
        case .hideEntity(let id):    return id
        }
    }

    private func parseTagValue(_ line: String) -> (tag: String, value: String) {
        var tag = ""
        var value = ""

        if let tagRange = line.range(of: "tag=") {
            let afterTag = line[tagRange.upperBound...]
            if let valueRange = afterTag.range(of: " value=") {
                tag = String(afterTag[..<valueRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                value = String(afterTag[valueRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        return (tag, value)
    }

    private func handleEntityTag(entityId: Int, tag: String, value: String) {
        guard entityId > 0 else { return }

        var state = entities[entityId] ?? EntityState()
        let previousZone = state.zone

        switch tag {
        case "ZONE":
            let newZone = LogZone(rawValue: value) ?? .unknown
            state.zone = newZone
            entities[entityId] = state

            // 检测区域转移事件
            if previousZone != newZone, previousZone != .unknown {
                emitZoneTransition(entityId: entityId, from: previousZone, to: newZone, state: state)

            } else if newZone != .unknown && previousZone == .unknown,
                      entityId > 4 { // 跳过游戏实体(1-4)
                // 首次出现的卡牌进入某区域
                emitCreated(entityId: entityId, zone: newZone, state: state)
            }

        case "CONTROLLER":
            let controller = Int(value) ?? 0
            state.controller = controller
            entities[entityId] = state

            // 检测玩家 ID
            if entityId == 1 { // GameEntity
                playerControllerID = controller
            }

        case "COST":
            state.cost = Int(value) ?? 0
            entities[entityId] = state

        case "CARD_ID":
            // TAG_CHANGE 中可能带 cardId
            state.cardId = value
            entities[entityId] = state

        case "PLAYER_ID":
            if entityId > 0 && entityId <= 4 {
                playerControllerID = Int(value) ?? 0
            }

        default:
            break
        }
    }

    // MARK: - Event Emission

    private func emitZoneTransition(entityId: Int, from: LogZone, to: LogZone, state: EntityState) {
        guard let card = resolveCard(from: state, entityId: entityId) else { return }
        let player = inferPlayer(controller: state.controller)

        let eventType: ParsedEventType = {
            switch (from, to) {
            case (.deck, .hand):
                return .draw
            case (.hand, .play):
                return .play
            case (_, .graveyard):
                return .destroy
            case (.hand, .deck):
                return .returnToDeck
            default:
                return .unknown
            }
        }()

        guard eventType != .unknown else { return }

        onEvent?(ParsedLogEvent(
            type: eventType,
            card: card,
            player: player,
            entityId: entityId,
            timestamp: Date()
        ))
    }

    private func emitCreated(entityId: Int, zone: LogZone, state: EntityState) {
        guard let card = resolveCard(from: state, entityId: entityId) else { return }
        let player = inferPlayer(controller: state.controller)

        onEvent?(ParsedLogEvent(
            type: .created,
            card: card,
            player: player,
            entityId: entityId,
            timestamp: Date()
        ))
    }

    // MARK: - Helpers

    private func resolveCard(from state: EntityState, entityId: Int) -> Card? {
        if let cardId = state.cardId, let card = cardDatabase.card(forCardId: cardId) {
            return card
        }
        // fallback: 返回占位卡牌
        return Card(
            dbfId: entityId,
            name: "未知 #\(entityId)",
            cost: state.cost,
            cardClass: "NEUTRAL",
            rarity: "FREE",
            type: "MINION",
            set: "UNKNOWN"
        )
    }

    private func inferPlayer(controller: Int) -> Player {
        if playerControllerID == 0 { return .player }
        return controller == playerControllerID ? .player : .opponent
    }
}

// MARK: - Parsed Event Types

enum ParsedEventType {
    case draw
    case play
    case destroy
    case returnToDeck
    case created
    case unknown
}

struct ParsedLogEvent {
    let type: ParsedEventType
    let card: Card
    let player: Player
    let entityId: Int
    let timestamp: Date
}