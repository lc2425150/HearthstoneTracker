import Foundation
import SwiftData

/// 对手信息记忆管理器
@MainActor
final class OpponentMemoryManager {
    static let shared = OpponentMemoryManager()
    
    private var opponentHistory: [String: OpponentProfile] = [:]
    
    struct OpponentProfile {
        let name: String
        var matches: [(date: Date, playerClass: String, opponentClass: String, result: String)]
        var totalGames: Int { matches.count }
        var winRate: Double {
            guard !matches.isEmpty else { return 0 }
            let wins = matches.filter { $0.result == "win" }.count
            return Double(wins) / Double(matches.count)
        }
        var commonClasses: [String: Int] {
            Dictionary(grouping: matches, by: { $0.opponentClass })
                .mapValues { $0.count }
        }
    }
    
    /// 记录对局
    func recordMatch(opponentName: String, playerClass: String, opponentClass: String, result: String) {
        var profile = opponentHistory[opponentName] ?? OpponentProfile(name: opponentName, matches: [])
        profile.matches.append((Date(), playerClass, opponentClass, result))
        opponentHistory[opponentName] = profile
        print("[OpponentMemory] 记录对手: \(opponentName) (\(result))")
    }
    
    /// 获取对手信息
    func getProfile(name: String) -> OpponentProfile? {
        return opponentHistory[name]
    }
    
    /// 获取所有对手列表
    var allOpponents: [OpponentProfile] {
        opponentHistory.values.sorted { $0.totalGames > $1.totalGames }
    }
    
    /// 检查是否遇到过该对手
    func hasMet(name: String) -> Bool {
        opponentHistory.keys.contains(name)
    }
}
