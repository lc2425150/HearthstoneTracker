import Foundation
import SwiftData

// MARK: - Live Match Tracking Service

@MainActor
final class TrackingService: ObservableObject {
    @Published var matchState = LiveMatchState.empty
    @Published var trackHistory: [TrackedCard] = []
    @Published var isTracking = false

    private let modelContext: ModelContext
    private let cardService: CardDataService
    private var currentMatchRecord: MatchRecord?

    init(modelContext: ModelContext, cardService: CardDataService) {
        self.modelContext = modelContext
        self.cardService = cardService
    }

    // MARK: - 开始对局

    func startMatch(deck: SavedDeck, playerClass: String, opponentClass: String,
                    coin: Bool = false, cards: [Card]) {
        // 保存对局记录
        let record = MatchRecord(
            playerClass: playerClass,
            opponentClass: opponentClass,
            deckCode: deck.deckCode,
            coin: coin
        )
        modelContext.insert(record)
        currentMatchRecord = record

        // 初始化追踪状态
        var remainingDeck = cards
        // 先手抽3张，后手抽4张
        let initialDraw = coin ? 4 : 3
        var handCards: [Card] = []
        for _ in 0..<min(initialDraw, remainingDeck.count) {
            handCards.append(remainingDeck.removeFirst())
        }

        matchState = LiveMatchState(
            playerClass: playerClass,
            opponentClass: opponentClass,
            deckCards: cards,
            remainingDeck: remainingDeck,
            handCards: handCards,
            playedCards: [],
            destroyedCards: [],
            discoveredCards: [],
            turnNumber: 1,
            coin: coin,
            isTracking: true,
            startTime: Date()
        )

        isTracking = true
        trackHistory = []

        // 记录换牌
        for card in handCards {
            trackHistory.append(TrackedCard(
                card: card, action: .mulligan, turn: 0, timestamp: Date()
            ))
        }

        NotificationCenter.default.post(name: Constants.matchStarted, object: nil)
    }

    // MARK: - 抽牌

    func drawCard() {
        guard isTracking, !matchState.remainingDeck.isEmpty else { return }
        let card = matchState.remainingDeck.removeFirst()
        matchState.handCards.append(card)
        trackHistory.append(TrackedCard(
            card: card, action: .draw, turn: matchState.turnNumber, timestamp: Date()
        ))
        objectWillChange.send()
    }

    // MARK: - 打出

    func playCard(_ card: Card) {
        guard isTracking else { return }
        matchState.handCards.removeAll { $0.dbfId == card.dbfId }
        matchState.playedCards.append(card)
        trackHistory.append(TrackedCard(
            card: card, action: .play, turn: matchState.turnNumber, timestamp: Date()
        ))
        objectWillChange.send()
    }

    // MARK: - 弃牌/消灭

    func discardCard(_ card: Card) {
        guard isTracking else { return }
        if let idx = matchState.handCards.firstIndex(where: { $0.dbfId == card.dbfId }) {
            matchState.handCards.remove(at: idx)
        }
        matchState.destroyedCards.append(card)
        trackHistory.append(TrackedCard(
            card: card, action: .discard, turn: matchState.turnNumber, timestamp: Date()
        ))
        objectWillChange.send()
    }

    func destroyCard(_ card: Card) {
        guard isTracking else { return }
        if let idx = matchState.handCards.firstIndex(where: { $0.dbfId == card.dbfId }) {
            matchState.handCards.remove(at: idx)
        }
        matchState.destroyedCards.append(card)
        trackHistory.append(TrackedCard(
            card: card, action: .destroy, turn: matchState.turnNumber, timestamp: Date()
        ))
        objectWillChange.send()
    }

    // MARK: - 发现

    func discoverCard(_ card: Card) {
        guard isTracking else { return }
        matchState.discoveredCards.append(card)
        trackHistory.append(TrackedCard(
            card: card, action: .discover, turn: matchState.turnNumber, timestamp: Date()
        ))
        objectWillChange.send()
    }

    // MARK: - 回合切换

    func nextTurn() {
        guard isTracking else { return }
        matchState.turnNumber += 1
        // 每回合抽一张牌
        drawCard()
        objectWillChange.send()
    }

    // MARK: - 结束对局

    func endMatch(result: String) {
        guard isTracking, let record = currentMatchRecord else { return }

        record.endTime = Date()
        record.result = result

        matchState.isTracking = false
        isTracking = false

        NotificationCenter.default.post(name: Constants.matchEnded, object: nil)

        // 保存到 SwiftData
        try? modelContext.save()
    }

    // MARK: - 重置

    func resetMatch() {
        matchState = LiveMatchState.empty
        trackHistory = []
        isTracking = false
        currentMatchRecord = nil
    }
}
