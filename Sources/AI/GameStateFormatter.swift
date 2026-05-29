import Foundation

/// 游戏状态格式化器：将对局数据转为 AI 可读的结构化文本
enum GameStateFormatter {
    
    /// 生成完整的对局状态描述
    @MainActor
    static func format(core: CardTrackerCore) -> String {
        var lines: [String] = []
        let separator = "---"
        
        // 基本信息
        if let deck = core.playerDeck {
            lines.append("【我方信息】")
            lines.append("职业: \(deck.heroClass.displayName)")
            let totalRemaining = deck.remainingOriginalCount
            let totalOriginal = deck.totalOriginalCount
            let drawn = totalOriginal - totalRemaining
            lines.append("牌库剩余: \(totalRemaining) 张 (已抽 \(drawn) 张)")
            
            // 手牌
            let hand = deck.handOriginal
            if hand.isEmpty {
                lines.append("手牌: (无)")
            } else {
                let handDesc = hand.map { card in
                    let extra = card.type == "minion" ? "随从" : card.type == "spell" ? "法术" : card.type == "weapon" ? "武器" : card.type
                    return "\(card.name)(\(card.cost)费/\(extra))"
                }.joined(separator: ", ")
                lines.append("手牌(\(hand.count)张): \(handDesc)")
            }
            
            // 已打出
            let played = deck.playedOriginal
            if !played.isEmpty {
                // 按花费分组显示
                let byCost = Dictionary(grouping: played) { $0.cost }
                let playedDesc = byCost.sorted { $0.key < $1.key }.map { cost, cards in
                    "\(cost)费: \(cards.map { $0.name }.joined(separator: ", "))"
                }.joined(separator: "; ")
                lines.append("已打出: \(playedDesc)")
            }
            
            // 发现/生成牌
            if !deck.discoveredCards.isEmpty {
                let disc = deck.discoveredCards.filter { !$0.isPlayed }
                if !disc.isEmpty {
                    lines.append("发现/生成牌(未使用): \(disc.map { "\($0.card.name)(\($0.card.cost)费)" }.joined(separator: ", "))")
                }
            }
        } else {
            lines.append("【我方信息】未导入卡组")
        }
        
        lines.append(separator)
        
        // 对手信息
        let opponent = core.opponentTracker
        lines.append("【对手信息】")
        lines.append("职业: \(opponent.heroClass.displayName)")
        lines.append("手牌数量(估): \(opponent.handSize) 张")
        lines.append("牌库剩余(估): \(opponent.deckRemaining) 张")
        if opponent.manaUsed > 0 {
            lines.append("已用费用: \(opponent.manaUsed)")
        }
        if let archetype = opponent.inferredArchetype {
            lines.append("推测卡组类型: \(archetype)")
        }
        
        let oppPlayed = opponent.playedCards
        if oppPlayed.isEmpty {
            lines.append("对手已出牌: (尚无)")
        } else {
            let oppByCost = Dictionary(grouping: oppPlayed) { $0.cost }
            let oppDesc = oppByCost.sorted { $0.key < $1.key }.map { cost, cards in
                "\(cost)费: \(cards.map { "\($0.card.name)" }.joined(separator: ", "))"
            }.joined(separator: "; ")
            lines.append("对手已出牌: \(oppDesc)")
        }
        
        lines.append(separator)
        
        // 我方已打出的对手卡牌信息
        let myPlayed = core.playerDeck?.playedOriginal ?? []
        if !myPlayed.isEmpty {
            lines.append("【本局关键信息】")
            // 统计平均费用
            let avgCost = myPlayed.map { Double($0.cost) }.reduce(0, +) / Double(max(myPlayed.count, 1))
            lines.append(String(format: "我方已打出平均费用: %.1f", avgCost))
            
            let oppAvgCost = oppPlayed.map { Double($0.cost) }.reduce(0, +) / Double(max(oppPlayed.count, 1))
            if oppPlayed.count > 0 {
                lines.append(String(format: "对手已打出平均费用: %.1f", oppAvgCost))
            }
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// 快速状态摘要（用于定时刷新的简洁模式）
    @MainActor
    static func quickSummary(core: CardTrackerCore) -> String {
        guard let deck = core.playerDeck else { return "请先导入卡组" }
        
        let hand = deck.handOriginal
        let handSummary = hand.isEmpty ? "无手牌" : hand.map { "\($0.name)(\($0.cost)费)" }.joined(separator: "、")
        let opp = core.opponentTracker
        
        return """
我方: \(deck.heroClass.displayName) | 手牌\(hand.count)张: \(handSummary)
对手: \(opp.heroClass.displayName) | 手牌约\(opp.handSize)张 | 已出\(opp.playedCards.count)张
"""
    }
}

/// 实时 AI 分析请求参数
struct RealTimeAnalysisRequest {
    let playerHero: String
    let playerDeckRemaining: Int
    let handCards: [(name: String, cost: Int, type: String)]
    let playedCards: [(name: String, cost: Int)]
    let discoveredCards: [(name: String, cost: Int)]
    let opponentHero: String
    let opponentHandSize: Int
    let opponentDeckRemaining: Int
    let opponentPlayedCards: [(name: String, cost: Int)]
    let opponentManaUsed: Int
    let inferredArchetype: String?
    
    @MainActor
    static func from(core: CardTrackerCore) -> RealTimeAnalysisRequest {
        let deck = core.playerDeck
        let opp = core.opponentTracker
        
        return RealTimeAnalysisRequest(
            playerHero: deck?.heroClass.displayName ?? "未知",
            playerDeckRemaining: deck?.remainingOriginalCount ?? 0,
            handCards: deck?.handOriginal.map { ($0.name, $0.cost, $0.type) } ?? [],
            playedCards: deck?.playedOriginal.map { ($0.name, $0.cost) } ?? [],
            discoveredCards: (deck?.discoveredCards ?? []).filter { !$0.isPlayed }.map { ($0.card.name, $0.card.cost) },
            opponentHero: opp.heroClass.displayName,
            opponentHandSize: opp.handSize,
            opponentDeckRemaining: opp.deckRemaining,
            opponentPlayedCards: opp.playedCards.map { ($0.card.name, $0.cost) },
            opponentManaUsed: opp.manaUsed,
            inferredArchetype: opp.inferredArchetype
        )
    }
}
