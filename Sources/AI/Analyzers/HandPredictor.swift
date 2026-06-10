import Foundation

/// 对手手牌预测分析器
struct HandPredictor {
    
    /// 对手手牌预测结果
    struct Prediction {
        let cardName: String
        let confidence: String // 高/中/低
        let reason: String
    }
    
    /// 构建分析的 Prompt
    func buildPrompt(gameState: String) -> String {
        return """
你是一个炉石传说AI对手手牌分析专家。根据当前对局状态，推测对手手牌。

分析依据：
1. 对手已使用的总费用 vs 当前可用费用
2. 对手已打出的卡牌（推测卡组类型）
3. 当前回合数
4. 对手职业的常见卡组

请给出最可能的3-5张手牌推测。格式如下（每行一条）：
卡牌名 | 可能性(高/中/低) | 理由

当前对局：
\(gameState)
"""
    }
    
    /// 解析 AI 返回的手牌预测结果
    func parseResponse(_ response: String) -> [Prediction] {
        return response.components(separatedBy: "\n")
            .filter { $0.contains(" | ") }
            .compactMap { line in
                let parts = line.components(separatedBy: " | ")
                guard parts.count >= 3 else { return nil }
                return Prediction(
                    cardName: parts[0].trimmingCharacters(in: .whitespaces),
                    confidence: parts[1].trimmingCharacters(in: .whitespaces),
                    reason: parts[2].trimmingCharacters(in: .whitespaces)
                )
            }
    }
}
