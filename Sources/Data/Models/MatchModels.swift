import Foundation
import SwiftData

// MARK: - Match Record

@Model
final class MatchRecord {
    var id = UUID()
    var startTime: Date
    var endTime: Date?
    var playerClass: String
    var opponentClass: String
    var result: MatchResult
    var deckCode: String
    var notes: String
    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    init(startTime: Date = Date(),
         playerClass: String,
         opponentClass: String,
         result: MatchResult = .unknown,
         deckCode: String,
         notes: String = "") {
        self.startTime = startTime
        self.playerClass = playerClass
        self.opponentClass = opponentClass
        self.result = result
        self.deckCode = deckCode
        self.notes = notes
    }
}

enum MatchResult: String, Codable, CaseIterable {
    case win, loss, draw, unknown

    var displayName: String {
        switch self {
        case .win:      return "胜利"
        case .loss:     return "失败"
        case .draw:     return "平局"
        case .unknown:  return "未知"
        }
    }

    var colorName: String {
        switch self {
        case .win:      return "green"
        case .loss:     return "red"
        case .draw:     return "gray"
        case .unknown:  return "secondary"
        }
    }
}

struct MatchStats {
    let totalMatches: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let winRate: Double
    let averageDuration: TimeInterval
    
    // 按职业统计
    struct ClassStats: Identifiable {
        let id = UUID()
        let className: String
        let wins: Int
        let losses: Int
        var total: Int { wins + losses }
        var winRate: Double { total > 0 ? Double(wins) / Double(total) : 0 }
    }
    
    let statsByPlayerClass: [ClassStats]
    let statsByOpponentClass: [ClassStats]
    
    // 最近胜负记录（最近 20 场）
    let recentResults: [MatchResult]
    var currentStreak: (result: MatchResult, count: Int) {
        guard !recentResults.isEmpty else { return (.unknown, 0) }
        var count = 0
        let first = recentResults[0]
        for result in recentResults {
            if result == first { count += 1 } else { break }
        }
        return (first, count)
    }

    init(records: [MatchRecord]) {
        totalMatches = records.count
        wins = records.filter { $0.result == .win }.count
        losses = records.filter { $0.result == .loss }.count
        draws = records.filter { $0.result == .draw }.count
        winRate = totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0.0

        let completed = records.filter { $0.endTime != nil }
        if completed.isEmpty {
            averageDuration = 0
        } else {
            averageDuration = completed.reduce(0) { $0 + $1.duration } / Double(completed.count)
        }
        
        // 按对手职业统计
        var oppClasses: [String: (wins: Int, losses: Int)] = [:]
        var playerClasses: [String: (wins: Int, losses: Int)] = [:]
        for record in records {
            let opp = oppClasses[record.opponentClass] ?? (0, 0)
            let player = playerClasses[record.playerClass] ?? (0, 0)
            if record.result == .win {
                oppClasses[record.opponentClass] = (opp.wins + 1, opp.losses)
                playerClasses[record.playerClass] = (player.wins + 1, player.losses)
            } else if record.result == .loss {
                oppClasses[record.opponentClass] = (opp.wins, opp.losses + 1)
                playerClasses[record.playerClass] = (player.wins, player.losses + 1)
            }
        }
        statsByOpponentClass = oppClasses.map { .init(className: $0.key, wins: $0.value.wins, losses: $0.value.losses) }
            .sorted { $0.winRate > $1.winRate }
        statsByPlayerClass = playerClasses.map { .init(className: $0.key, wins: $0.value.wins, losses: $0.value.losses) }
            .sorted { $0.winRate > $1.winRate }
        
        // 最近 20 场
        let sorted = records.sorted { $0.startTime > $1.startTime }
        recentResults = Array(sorted.prefix(20)).map { $0.result }
    }
}

// MARK: - Deck Library

@Model
final class SavedDeck {
    var id = UUID()
    var name: String
    var deckCode: String
    var heroClass: String
    var createdAt: Date
    var lastUsed: Date?
    var notes: String
    var isFavorite: Bool

    init(name: String,
         deckCode: String,
         heroClass: String,
         notes: String = "",
         isFavorite: Bool = false) {
        self.name = name
        self.deckCode = deckCode
        self.heroClass = heroClass
        self.createdAt = Date()
        self.notes = notes
        self.isFavorite = isFavorite
    }
}

struct DeckStats {
    let totalGames: Int
    let wins: Int
    let losses: Int
    let winRate: Double
    let lastPlayed: Date?

    init(deckCode: String, matches: [MatchRecord]) {
        let deckMatches = matches.filter { $0.deckCode == deckCode }
        totalGames = deckMatches.count
        wins = deckMatches.filter { $0.result == .win }.count
        losses = deckMatches.filter { $0.result == .loss }.count
        winRate = totalGames > 0 ? Double(wins) / Double(totalGames) : 0.0
        lastPlayed = deckMatches.max(by: { $0.startTime < $1.startTime })?.startTime
    }
}

// MARK: - Database Extensions

@MainActor
extension CardDatabase {
    func saveMatch(_ match: MatchRecord) {
        modelContainer.mainContext.insert(match)
        do {
            try modelContainer.mainContext.save()
        } catch {
            print("[CardDatabase] Failed to save match: \(error)")
        }
    }

    func fetchMatches(limit: Int = 100) -> [MatchRecord] {
        let descriptor = FetchDescriptor<MatchRecord>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        do {
            return try modelContainer.mainContext.fetch(descriptor)
        } catch {
            print("[CardDatabase] Failed to fetch matches: \(error)")
            return []
        }
    }

    func saveDeck(_ deck: SavedDeck) {
        modelContainer.mainContext.insert(deck)
        do {
            try modelContainer.mainContext.save()
        } catch {
            print("[CardDatabase] Failed to save deck: \(error)")
        }
    }

    func fetchDecks() -> [SavedDeck] {
        let descriptor = FetchDescriptor<SavedDeck>()
        do {
            let decks = try modelContainer.mainContext.fetch(descriptor)
            // Manual sorting since SortDescriptor requires NSObject
            return decks.sorted { deck1, deck2 in
                if deck1.isFavorite != deck2.isFavorite {
                    return deck1.isFavorite && !deck2.isFavorite
                }
                return (deck1.lastUsed ?? Date.distantPast) > (deck2.lastUsed ?? Date.distantPast)
            }
        } catch {
            print("[CardDatabase] Failed to fetch decks: \(error)")
            return []
        }
    }

    func deleteDeck(_ deck: SavedDeck) {
        modelContainer.mainContext.delete(deck)
        do {
            try modelContainer.mainContext.save()
        } catch {
            print("[CardDatabase] Failed to delete deck: \(error)")
        }
    }
}