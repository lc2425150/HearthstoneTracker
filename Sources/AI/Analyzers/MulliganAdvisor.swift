import Foundation

/// 留牌策略建议分析器
struct MulliganAdvisor {
    
    /// 留牌建议
    struct Advice {
        let cardName: String
        let action: String // 保留/换掉
        let reason: String
    }
    
    /// 构建留牌分析的 Prompt
    func buildPrompt(playerClass: String, opponentClass: String,
                     handCards: [String], gameState: String) -> String {
        let handList = handCards.joined(separator: "、")
        return """
你是一个炉石传说留牌策略专家。分析当前起手牌，给出最优留牌建议。

对局信息：
- 我方职业：\(playerClass)
- 对手职业：\(opponentClass)
- 起手手牌：\(handList)

分析要点：
1. 费用曲线：是否有1-3费的早期曲线
2. 对阵职业：对手的快攻/控制倾向
3. 卡牌协同：手牌之间是否有配合
4. 先手/后手：后手可多留一张

请逐张分析每张牌应该保留还是换掉。
格式：
卡牌名 | 保留/换掉 | 理由

当前游戏状态：
\(gameState)
"""
    }
    
    /// 解析 AI 返回的留牌建议
    func parseResponse(_ response: String) -> [Advice] {
        return response.components(separatedBy: "\n")
            .filter { $0.contains(" | ") && ($0.contains("保留") || $0.contains("换掉")) }
            .compactMap { line in
                let parts = line.components(separatedBy: " | ")
                guard parts.count >= 3 else { return nil }
                return Advice(
                    cardName: parts[0].trimmingCharacters(in: .whitespaces),
                    action: parts[1].trimmingCharacters(in: .whitespaces),
                    reason: parts[2].trimmingCharacters(in: .whitespaces)
                )
            }
    }
}
