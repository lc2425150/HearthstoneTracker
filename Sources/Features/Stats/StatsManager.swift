import Foundation
import SwiftData

/// 胜率统计管理器
@MainActor
final class StatsManager {
    static let shared = StatsManager()
    static var sharedDatabase: CardDatabase?
    
    private var context: ModelContext?
    
    /// 使用共享的数据库实例（优先使用 CardTrackerCore 的）
    static func configure(database: CardDatabase) {
        sharedDatabase = database
        shared.context = database.modelContainer.mainContext
    }
    
    private init() {
        if let db = StatsManager.sharedDatabase {
            self.context = db.modelContainer.mainContext
        } else {
            // 降级：创建临时内存数据库用于统计
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: MatchRecord.self, configurations: config) {
                self.context = container.mainContext
            } else {
                self.context = nil
            }
        }
    }
    
    /// 获取总对局数
    var totalMatches: Int {
        guard let context else { return 0 }
        return (try? context.fetch(FetchDescriptor<MatchRecord>()).count) ?? 0
    }
    
    /// 获取总胜率
    var overallWinRate: Double {
        calculateWinRate()
    }
    
    /// 按职业计算胜率
    func winRateByClass(_ playerClass: String) -> Double {
        calculateWinRate(playerClass: playerClass)
    }
    
    /// 按对阵计算胜率
    func winRateVsOpponent(opponentClass: String) -> (wins: Int, losses: Int, rate: Double) {
        guard let context else { return (0, 0, 0) }
        let desc = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.opponentClass == opponentClass }
        )
        guard let matches = try? context.fetch(desc) else { return (0, 0, 0) }
        let wins = matches.filter { $0.result == .win }.count
        let total = matches.count
        return (wins, total - wins, total > 0 ? Double(wins) / Double(total) : 0)
    }
    
    /// 近期胜率趋势（最近 N 场）
    func recentTrend(lastGames: Int = 20) -> [(index: Int, result: MatchResult)] {
        guard let context else { return [] }
        let desc = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
        guard let matches = try? context.fetch(desc) else { return [] }
        return Array(matches.prefix(lastGames)).reversed().enumerated().map { ($0, $1.result) }
    }
    
    // MARK: - Private
    
    private func calculateWinRate(playerClass: String? = nil) -> Double {
        guard let context else { return 0 }
        let desc: FetchDescriptor<MatchRecord>
        if let playerClass = playerClass {
            desc = FetchDescriptor(predicate: #Predicate { $0.playerClass == playerClass })
        } else {
            desc = FetchDescriptor<MatchRecord>()
        }
        guard let matches = try? context.fetch(desc), !matches.isEmpty else { return 0 }
        let wins = matches.filter { $0.result == .win }.count
        return Double(wins) / Double(matches.count)
    }
}
