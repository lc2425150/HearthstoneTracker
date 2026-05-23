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