import Foundation
import Combine

/// 对手出牌追踪器：监听日志/OCR事件，追踪对手手牌和已打出卡牌
final class OpponentCardTracker: ObservableObject {
    // MARK: - Published State

    /// 对手已打出的卡牌（按打出顺序）
    @Published var playedCards: [OpponentCardRecord] = []

    /// 对手手牌数量估算
    @Published var handSize: Int = 0

    /// 对手牌库剩余数量估算
    @Published var deckRemaining: Int = 30

    /// 对手职业
    @Published var heroClass: HeroClass = .unknown

    /// 对手已使用的法力水晶
    @Published var manaUsed: Int = 0

    // MARK: - Tracking State

    private var cardDatabase: CardDatabase
    private var cancellables = Set<AnyCancellable>()

    // 用于去重的已打出卡牌 record
    private var seenEntityIds = Set<Int>()

    init(database: CardDatabase) {
        self.cardDatabase = database
    }

    // MARK: - Public

    /// 重置追踪状态（新对局）
    func reset() {
        playedCards = []
        handSize = 0
        deckRemaining = 30
        manaUsed = 0
        seenEntityIds.removeAll()
    }

    /// 处理来自日志的对手事件
    func handleOpponentEvent(_ event: CardEvent) {
        guard event.player == .opponent else { return }

        // 去重
        if let entityId = event.metadata?["entityId"] as? Int {
            guard !seenEntityIds.contains(entityId) else { return }
            seenEntityIds.insert(entityId)
        }

        switch event.type {
        case .play:
            let record = OpponentCardRecord(
                card: event.card,
                turn: estimateTurn(),
                timestamp: event.timestamp,
                cost: event.card.cost
            )
            playedCards.append(record)
            manaUsed += event.card.cost

        case .draw:
            handSize += 1
            deckRemaining = max(0, deckRemaining - 1)

        case .destroy:
            // 随从死亡
            break

        case .secret:
            // 奥秘挂载
            let record = OpponentCardRecord(
                card: event.card,
                turn: estimateTurn(),
                timestamp: event.timestamp,
                cost: event.card.cost
            )
            playedCards.append(record)

        default:
            break
        }
    }

    /// 处理来自 OCR 的对手出牌
    func handleOCRResult(_ result: OCRResult) {
        // 避免重复：检查是否已通过日志记录
        let alreadyRecorded = playedCards.contains {
            $0.card.dbfId == result.card.dbfId &&
            abs($0.timestamp.timeIntervalSinceNow) < 10
        }
        guard !alreadyRecorded else { return }

        let record = OpponentCardRecord(
            card: result.card,
            turn: estimateTurn(),
            timestamp: Date(),
            cost: result.card.cost
        )
        playedCards.append(record)
    }

    // MARK: - Computed

    var totalPlayedCount: Int { playedCards.count }

    /// 对手已打出的卡牌按费用分类
    var cardsByCost: [Int: [OpponentCardRecord]] {
        Dictionary(grouping: playedCards) { $0.cost }
    }

    /// 推断对手可能的卡组类型（基于已打出卡牌）
    var inferredArchetype: String? {
        let cardNames = playedCards.map { $0.card.name }
        // 简单启发式：根据关键牌判断
        let archetypeKeywords: [String: String] = [
            "奇利亚斯": "机械",
            "雷诺": "宇宙",
            "帕奇斯": "海盗",
            "任务": "任务",
            "王子": "王子",
            "青玉": "青玉",
            "克苏恩": "克苏恩"
        ]

        for (keyword, archetype) in archetypeKeywords {
            if cardNames.contains(where: { $0.contains(keyword) }) {
                return archetype
            }
        }
        return nil
    }

    // MARK: - Private

    private func estimateTurn() -> Int {
        // 粗略估算：双方牌库消耗量 / 每回合抽 1 张
        let cardsDrawn = 30 - deckRemaining
        return max(1, cardsDrawn / 2)
    }
}

// MARK: - Supporting Types

struct OpponentCardRecord: Identifiable {
    let id = UUID()
    let card: Card
    let turn: Int
    let timestamp: Date
    let cost: Int

    var isLegendary: Bool { card.rarity == "LEGENDARY" }
}