import Foundation

/// 回合摘要分析器
struct RoundSummarizer {
    
    struct RoundSummary {
        let turnNumber: Int
        let keyEvents: String
        let assessment: String // 优势/均势/劣势
        let suggestion: String
    }
    
    /// 构建回合摘要的 Prompt
    func buildPrompt(turnNumber: Int, gameState: String) -> String {
        return """
你是一个炉石传说对局分析师。总结第\(turnNumber)回合的局势。

格式：
回合概述 | [一句话总结]
场面评估 | [优势/均势/劣势]
关键决策 | [本回合的关键操作]
下回合计划 | [建议]

当前游戏状态：
\(gameState)
"""
    }
}
