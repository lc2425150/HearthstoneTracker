import SwiftUI
import SwiftData

// MARK: - 统计

struct StatsView: View {
    @Query(sort: \MatchRecord.startTime, order: .reverse) private var matches: [MatchRecord]
    @Query(sort: \SavedDeck.updatedAt, order: .reverse) private var decks: [SavedDeck]

    @State private var selectedTimeRange: TimeRange = .all

    enum TimeRange: String, CaseIterable {
        case all = "全部"
        case week = "本周"
        case month = "本月"

        var filterDate: Date? {
            switch self {
            case .all: return nil
            case .week: return Calendar.current.date(byAdding: .day, value: -7, to: Date())
            case .month: return Calendar.current.date(byAdding: .month, value: -1, to: Date())
            }
        }
    }

    var body: some View {
        Group {
            if filteredMatches.isEmpty {
                ContentUnavailableView(
                    label: { Label("暂无对局记录", systemImage: "chart.bar") },
                    description: { Text("开始对局追踪后，对局记录将显示在这里") }
                )
            } else {
                List {
                    // 概览统计
                    Section {
                        overviewSection
                    }

                    // 按卡组统计
                    if !deckStats.isEmpty {
                        Section("按卡组") {
                            ForEach(deckStats.sorted(by: { $0.total > $1.total })) { stat in
                                DeckStatRow(stat: stat)
                            }
                        }
                    }

                    // 按职业统计
                    Section("按对手职业") {
                        ForEach(classStats.sorted(by: { $0.total > $1.total })) { stat in
                            ClassStatRow(stat: stat)
                        }
                    }

                    // 对局历史
                    Section("最近对局") {
                        ForEach(filteredMatches.prefix(20)) { match in
                            MatchHistoryRow(match: match)
                        }
                    }
                }
            }
        }
        .navigationTitle("统计")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - 概览

    private var overviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                StatCard(
                    title: "总场次",
                    value: "\(filteredMatches.count)",
                    icon: "gamecontroller",
                    color: .blue
                )
                StatCard(
                    title: "胜场",
                    value: "\(winCount)",
                    icon: "checkmark.circle",
                    color: .green
                )
                StatCard(
                    title: "胜率",
                    value: winRateString,
                    icon: "percent",
                    color: .orange
                )
            }

            if !filteredMatches.isEmpty {
                HStack {
                    StatCard(
                        title: "当前连胜",
                        value: "\(currentStreak)",
                        icon: "flame",
                        color: .red
                    )
                    StatCard(
                        title: "最长连胜",
                        value: "\(bestStreak)",
                        icon: "trophy",
                        color: .yellow
                    )
                    StatCard(
                        title: "卡组数",
                        value: "\(decks.count)",
                        icon: "rectangle.stack",
                        color: .purple
                    )
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: - 计算属性

    private var filteredMatches: [MatchRecord] {
        guard let filterDate = selectedTimeRange.filterDate else {
            return matches
        }
        return matches.filter { $0.startTime >= filterDate }
    }

    private var winCount: Int {
        filteredMatches.filter { $0.result == "win" }.count
    }

    private var lossCount: Int {
        filteredMatches.filter { $0.result == "loss" }.count
    }

    private var winRateString: String {
        let total = winCount + lossCount
        guard total > 0 else { return "-" }
        let rate = Double(winCount) / Double(total) * 100
        return String(format: "%.1f%%", rate)
    }

    private var currentStreak: Int {
        let recentMatches = Array(filteredMatches
            .filter { $0.result != "unknown" }
            .sorted { $0.startTime > $1.startTime }
            .prefix(20))

        guard !recentMatches.isEmpty else { return 0 }
        let firstResult = recentMatches[0].result
        var streak = 0
        for match in recentMatches {
            if match.result == firstResult {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private var bestStreak: Int {
        let relevant = filteredMatches.filter { $0.result != "unknown" }
            .sorted { $0.startTime < $1.startTime }
        guard !relevant.isEmpty else { return 0 }

        var maxStreak = 0
        var current = 0
        var lastResult = ""

        for match in relevant {
            if match.result == lastResult {
                current += 1
            } else {
                current = 1
                lastResult = match.result
            }
            maxStreak = max(maxStreak, current)
        }
        return maxStreak
    }

    // MARK: - 卡组统计

    private var deckStats: [DeckStat] {
        var stats: [String: (wins: Int, losses: Int, total: Int)] = [:]
        for match in filteredMatches where match.result != "unknown" {
            let key = match.deckCode
            var entry = stats[key] ?? (0, 0, 0)
            if match.result == "win" { entry.wins += 1 }
            else if match.result == "loss" { entry.losses += 1 }
            entry.total += 1
            stats[key] = entry
        }

        // 找卡组名称
        return stats.compactMap { code, counts in
            let deck = decks.first { $0.deckCode == code }
            return DeckStat(
                id: code,
                deckName: deck?.name ?? "未知卡组",
                playerClass: deck?.playerClass ?? "",
                wins: counts.wins,
                losses: counts.losses,
                total: counts.total
            )
        }
    }

    // MARK: - 职业统计

    private var classStats: [ClassStat] {
        var stats: [String: (wins: Int, losses: Int, total: Int)] = [:]
        for match in filteredMatches where match.result != "unknown" {
            let key = match.opponentClass
            var entry = stats[key] ?? (0, 0, 0)
            if match.result == "win" { entry.wins += 1 }
            else if match.result == "loss" { entry.losses += 1 }
            entry.total += 1
            stats[key] = entry
        }

        return stats.map { cls, counts in
            ClassStat(
                id: cls,
                className: HearthstoneClass(rawValue: cls)?.displayName ?? cls,
                wins: counts.wins,
                losses: counts.losses,
                total: counts.total
            )
        }
    }
}

// MARK: - 统计卡片

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .bold()

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - 卡组统计行

struct DeckStat: Identifiable {
    let id: String
    let deckName: String
    let playerClass: String
    let wins: Int
    let losses: Int
    let total: Int

    var winRate: Double {
        total > 0 ? Double(wins) / Double(total) * 100 : 0
    }
}

struct DeckStatRow: View {
    let stat: DeckStat

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(classColor)
                    .frame(width: 32, height: 32)
                Image(systemName: classIcon)
                    .foregroundColor(.white)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.deckName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(stat.total) 场 · \(stat.wins)胜 \(stat.losses)负")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f%%", stat.winRate))
                .font(.headline)
                .foregroundColor(stat.winRate >= 50 ? .green : .red)
        }
    }

    private var classColor: Color {
        switch stat.playerClass {
        case "MAGE": return .blue
        case "WARRIOR": return .red
        case "PRIEST": return .gray
        case "ROGUE": return .gray
        case "PALADIN": return .yellow
        case "HUNTER": return .green
        case "DRUID": return .orange
        case "WARLOCK": return .purple
        case "SHAMAN": return .cyan
        case "DEMONHUNTER": return .indigo
        case "DEATHKNIGHT": return .mint
        default: return .secondary
        }
    }

    private var classIcon: String {
        HearthstoneClass(rawValue: stat.playerClass)?.iconName ?? "questionmark"
    }
}

// MARK: - 职业统计行

struct ClassStat: Identifiable {
    let id: String
    let className: String
    let wins: Int
    let losses: Int
    let total: Int

    var winRate: Double {
        total > 0 ? Double(wins) / Double(total) * 100 : 0
    }
}

struct ClassStatRow: View {
    let stat: ClassStat

    var body: some View {
        HStack {
            Text(stat.className)
                .font(.subheadline)

            Spacer()

            Text("\(stat.total) 场")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(stat.wins)-\(stat.losses)")
                .font(.subheadline)
                .foregroundColor(stat.winRate >= 50 ? .green : .red)

            Text(String(format: "%.0f%%", stat.winRate))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - 对局历史行

struct MatchHistoryRow: View {
    let match: MatchRecord

    var body: some View {
        HStack {
            // 结果
            ZStack {
                Circle()
                    .fill(resultColor)
                    .frame(width: 32, height: 32)
                Image(systemName: resultIcon)
                    .foregroundColor(.white)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(HearthstoneClass(rawValue: match.playerClass)?.displayName ?? match.playerClass)
                        .font(.subheadline)
                    Text("vs")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(HearthstoneClass(rawValue: match.opponentClass)?.displayName ?? match.opponentClass)
                        .font(.subheadline)
                }
                Text(match.startTime, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if match.result != "unknown" {
                Text(match.result == "win" ? "胜" : "负")
                    .font(.caption)
                    .bold()
                    .foregroundColor(match.result == "win" ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background((match.result == "win" ? Color.green : Color.red).opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }

    private var resultColor: Color {
        switch match.result {
        case "win": return .green
        case "loss": return .red
        default: return .gray
        }
    }

    private var resultIcon: String {
        switch match.result {
        case "win": return "checkmark"
        case "loss": return "xmark"
        default: return "minus"
        }
    }
}
