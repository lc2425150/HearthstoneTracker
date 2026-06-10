import Foundation
import SwiftData
import AppKit

/// 数据导出管理器
@MainActor
struct DataExporter {
    
    /// 导出为 CSV
    static func exportMatchesToCSV(database: CardDatabase) -> URL? {
        let context = database.modelContainer.mainContext
        let desc = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
        guard let matches = try? context.fetch(desc) else { return nil }
        
        var csv = "时间,我方职业,对手职业,结果,时长(秒)\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        
        for match in matches {
            csv += "\(df.string(from: match.startTime)),\(match.playerClass),\(match.opponentClass),\(match.result),\(match.duration)\n"
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("matches_export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    /// 导出卡组码
    static func exportDeckCode(cards: [(name: String, count: Int)]) -> String {
        return cards.map { "\($0.name) x\($0.count)" }.joined(separator: "\n")
    }
    
    /// 显示分享面板
    static func showShareDialog(url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        guard let window = NSApplication.shared.keyWindow,
              let contentView = window.contentView else { return }
        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
    }
}
