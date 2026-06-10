import Foundation

/// 卡组优化建议分析器
struct DeckOptimizer {
    
    struct Optimization {
        let suggestion: String
        let detail: String
    }
    
    /// 构建卡组分析的 Prompt
    func buildPrompt(heroClass: String, cards: [(name: String, count: Int)]) -> String {
        let cardList = cards.map { "  \($0.name) x\($0.count)" }.joined(separator: "\n")
        return """
你是一个炉石传说卡组分析专家。分析以下\(heroClass)卡组，给出优化建议。

卡组列表：
\(cardList)

分析要点：
1. 费用曲线是否合理（是否有足够的1-3费早期牌）
2. 卡牌协同效应（各卡牌之间是否有配合）
3. 对阵主流卡组的优劣势
4. 建议替换的卡牌及理由

格式：
建议类型 | 具体建议 | 理由
"""
    }
}
