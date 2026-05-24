import SwiftUI
import Combine

/// 卡牌数据库来源
enum CardDataSource: String, CaseIterable, Codable {
    case hearthstoneJSON = "HearthstoneJSON"
    case hsReplay = "HSReplay.net"
    case hearthPwn = "HearthPwn"
    
    var displayName: String {
        switch self {
        case .hearthstoneJSON: return "HearthstoneJSON"
        case .hsReplay: return "HSReplay.net"
        case .hearthPwn: return "HearthPwn"
        }
    }
    
    var apiURL: String {
        switch self {
        case .hearthstoneJSON:
            return "https://api.hearthstonejson.com/v1/latest/enUS/cards.json"
        case .hsReplay:
            return "https://static.hsreplay.net/static/carddb/cards.json"
        case .hearthPwn:
            return "https://www.hearthpwn.com/cards"
        }
    }
}

/// 追踪器核心协调器：管理所有子模块，作为 App 环境对象注入
@MainActor
final class CardTrackerCore: ObservableObject {

    // MARK: - Deck State

    @Published var playerDeck: TrackedDeck?
    @Published var opponentPlayedCards: [Card] = []
    @Published var deckImportError: String?

    // MARK: - Match State

    @Published var currentMatch: MatchRecord?
    @Published var matchRecords: [MatchRecord] = []
    @Published var matchStats = MatchStats(records: [])

    // MARK: - Deck Library State

    @Published var savedDecks: [SavedDeck] = []

    // MARK: - Data State

    @Published var isDataReady = false
    @Published var isUpdatingData = false
    @Published var lastUpdateResult: UpdateResult?
    @Published var selectedDataSource: CardDataSource = .hearthstoneJSON {
        didSet {
            UserDefaults.standard.set(selectedDataSource.rawValue, forKey: "selectedDataSource")
        }
    }
    @Published var availableDataSources: [CardDataSource: Date] = [:]

    // MARK: - Module References

    let cardDatabase = CardDatabase()
    let eventPipeline: EventPipeline
    let cardDataUpdater: CardDataUpdater
    let ocrScanner: VisionOCRScanner
    let opponentTracker: OpponentCardTracker
    let gameLauncher = GameLauncher.shared

    // MARK: - UI State

    @Published var isOverlayVisible = false
    @Published var isTracking = false

    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false

    init() {
        // 先创建轻量级模块，不触发数据库查询
        ocrScanner = VisionOCRScanner(database: cardDatabase)
        opponentTracker = OpponentCardTracker(database: cardDatabase)
        eventPipeline = EventPipeline(database: cardDatabase)
        cardDataUpdater = CardDataUpdater(database: cardDatabase)
        
        // 读取上次选择的数据库来源
        if let saved = UserDefaults.standard.string(forKey: "selectedDataSource"),
           let source = CardDataSource(rawValue: saved) {
            selectedDataSource = source
        }
        
        // 延迟加载数据（在 initializeData 中完成）
        setupSubscriptions()
    }
    
    /// 后台初始化数据（不阻塞 UI 线程）
    func initializeData() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // 在后台线程加载历史数据
        await Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // 加载本地持久化数据
            await self.loadMatchHistory()
            await self.loadSavedDecks()
            
            // 检查卡牌数据（带超时）
            await self.checkCardDataUpdate()
            
            await MainActor.run {
                self.isDataReady = true
            }
        }.value
    }

    // MARK: - Public Actions

    func startTracking() {
        guard !isTracking else { return }
        eventPipeline.start()
        isTracking = true
    }

    func stopTracking() {
        eventPipeline.stop()
        isTracking = false
    }

    func toggleTracking() {
        if isTracking {
            stopTracking()
        } else {
            startTracking()
        }
    }

    /// OCR 扫描触发（支持循环调度）
    func triggerOCRScan() {
        ocrScanner.scanGameWindow()
    }

    /// 开启对手追踪（含 OCR 定时扫描）
    func startOpponentTracking() {
        ocrScanner.onResult = { [weak self] results in
            guard let self else { return }
            for result in results {
                self.opponentTracker.handleOCRResult(result)
            }
        }
        ocrScanner.scanGameWindow()
    }

    /// 显示调试面板
    func showDebugPanel() {
        let debugWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        debugWindow.title = "炉石记牌器 - 调试面板"
        debugWindow.contentView = NSHostingView(rootView: DebugPanelView().environmentObject(self))
        debugWindow.center()
        debugWindow.makeKeyAndOrderFront(nil)
    }

    /// 新对局重置
    func resetMatch() {
        playerDeck = nil
        opponentTracker.reset()
    }

    /// 检查卡牌数据更新（支持多数据源，自动选最新的）
    func checkCardDataUpdate() async {
        guard !isUpdatingData else { return }
        await MainActor.run { isUpdatingData = true }

        // 检查所有数据源
        for source in CardDataSource.allCases {
            do {
                let result = try await cardDataUpdater.checkForUpdates(from: source)
                await MainActor.run {
                    availableDataSources[source] = result.timestamp
                }
            } catch {
                print("[Core] 数据源 \(source.displayName) 更新失败: \(error)")
            }
        }

        // 自动选择最新的数据源
        if let latest = availableDataSources.max(by: { $0.value < $1.value }) {
            await MainActor.run {
                selectedDataSource = latest.key
            }
        }

        // 用当前选中的数据源更新本地数据
        do {
            let result = try await cardDataUpdater.checkForUpdates(from: selectedDataSource)
            await MainActor.run {
                lastUpdateResult = result
                isDataReady = true
                isUpdatingData = false
            }
        } catch {
            await MainActor.run {
                deckImportError = error.localizedDescription
                isUpdatingData = false
                isDataReady = true
            }
        }
    }

    /// 切换卡牌数据库来源并更新
    func switchDataSource(_ source: CardDataSource) async {
        selectedDataSource = source
        guard !isUpdatingData else { return }
        await MainActor.run { isUpdatingData = true }

        do {
            let result = try await cardDataUpdater.checkForUpdates(from: source)
            await MainActor.run {
                lastUpdateResult = result
                isDataReady = true
                isUpdatingData = false
            }
        } catch {
            await MainActor.run {
                deckImportError = error.localizedDescription
                isUpdatingData = false
            }
        }
    }

    /// 从剪贴板导入卡组码
    func requestDeckImport() {
        let pasteboard = NSPasteboard.general
        guard let deckCode = pasteboard.string(forType: .string),
              !deckCode.isEmpty else {
            deckImportError = "剪贴板中没有卡组码"
            return
        }
        importDeck(from: deckCode)
    }

    /// 解析并导入卡组码（无字数限制）
    func importDeck(from deckCode: String) {
        deckImportError = nil

        // 清理输入：去除多余空白和换行
        let cleaned = deckCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            deckImportError = "卡组码为空"
            return
        }

        do {
            let result = try DeckCodeParser.parse(cleaned, database: cardDatabase)

            let originalCards: [Card] = result.cards.map { $0.card }
            playerDeck = TrackedDeck(
                deckCode: cleaned,
                originalCards: originalCards,
                discoveredCards: [],
                heroClass: result.heroClass,
                remainingOriginal: originalCards,
                playedOriginal: [],
                handOriginal: []
            )
        } catch {
            deckImportError = error.localizedDescription
        }
    }

    /// 清除当前牌库
    func clearDeck() {
        playerDeck = nil
        deckImportError = nil
    }

    // MARK: - Match Recording

    func startMatch(playerClass: HeroClass, opponentClass: HeroClass) {
        let pc = playerClass.displayName
        let oc = opponentClass.displayName
        let dc = playerDeck?.deckCode ?? ""
        currentMatch = MatchRecord(
            startTime: Date(),
            playerClass: pc,
            opponentClass: oc,
            deckCode: dc
        )
    }

    func endMatch(result: MatchResult) {
        guard let m = currentMatch else { return }
        m.endTime = Date()
        m.result = result
        cardDatabase.saveMatch(m)
        Task { @MainActor in
            loadMatchHistory()
            loadMatchHistory()
        }
        currentMatch = nil
        resetMatch()
    }

    func loadMatchHistory() {
        matchRecords = cardDatabase.fetchMatches()
        matchStats = MatchStats(records: matchRecords)
    }

    @MainActor func deleteMatch(_ match: MatchRecord) {
        cardDatabase.modelContainer.mainContext.delete(match)
        do {
            try cardDatabase.modelContainer.mainContext.save()
            loadMatchHistory()
        } catch {
            print("[Core] Failed to delete match: \(error)")
        }
    }

    // MARK: - Deck Library

    func saveCurrentDeck(name: String) {
        guard let deck = playerDeck else {
            deckImportError = "没有可保存的卡组"
            return
        }
        let saved = SavedDeck(
            name: name,
            deckCode: deck.deckCode,
            heroClass: deck.heroClass.displayName
        )
        cardDatabase.saveDeck(saved)
        loadSavedDecks()
    }

    func loadSavedDecks() {
        savedDecks = cardDatabase.fetchDecks()
    }

    func deleteSavedDeck(_ deck: SavedDeck) {
        cardDatabase.deleteDeck(deck)
        loadSavedDecks()
    }

    @MainActor func updateDeckLastUsed(_ deck: SavedDeck) {
        deck.lastUsed = Date()
        do {
            try cardDatabase.modelContainer.mainContext.save()
            loadSavedDecks()
        } catch {
            print("[Core] Failed to update deck: \(error)")
        }
    }

    // MARK: - Overlay Control

    func toggleOverlay() {
        OverlayWindowController.shared.toggle(core: self)
        isOverlayVisible = OverlayWindowController.shared.isVisible
    }
    
    func switchOverlaySide() {
        OverlayWindowController.shared.switchSide()
    }

    func showOverlay() {
        OverlayWindowController.shared.show(core: self)
        isOverlayVisible = true
    }

    func hideOverlay() {
        OverlayWindowController.shared.hide()
        isOverlayVisible = false
    }

    // MARK: - Private

    private func setupSubscriptions() {
        eventPipeline.cardEvents
            .sink { [weak self] event in
                self?.handleCardEvent(event)
                // 对手事件 → 对手追踪器
                if event.player == .opponent {
                    self?.opponentTracker.handleOpponentEvent(event)
                }
            }
            .store(in: &cancellables)
    }

    func handleCardEvent(_ event: CardEvent) {
        guard event.player == .player, let deck = playerDeck else { return }

        switch event.type {
        case .draw:
            handleDraw(event, deck: deck)
        case .play:
            handlePlay(event, deck: deck)
        case .destroy:
            handleDestroy(event, deck: deck)
        case .create:
            handleCreate(event, deck: deck)
        default:
            break
        }
    }

    private func handleDraw(_ event: CardEvent, deck: TrackedDeck) {
        guard let index = deck.remainingOriginal.firstIndex(where: { $0.id == event.card.id }) else {
            return
        }
        var newDeck = deck
        let drawn = newDeck.remainingOriginal.remove(at: index)
        newDeck.handOriginal.append(drawn)
        playerDeck = newDeck
    }

    private func handlePlay(_ event: CardEvent, deck: TrackedDeck) {
        var newDeck = deck

        if let handIndex = newDeck.handOriginal.firstIndex(where: { $0.id == event.card.id }) {
            let played = newDeck.handOriginal.remove(at: handIndex)
            newDeck.playedOriginal.append(played)
        } else if let remainingIndex = newDeck.remainingOriginal.firstIndex(where: { $0.id == event.card.id }) {
            let played = newDeck.remainingOriginal.remove(at: remainingIndex)
            newDeck.playedOriginal.append(played)
        }

        if let discIndex = newDeck.discoveredCards.firstIndex(where: { $0.card.id == event.card.id && !$0.isPlayed }) {
            newDeck.discoveredCards[discIndex].isPlayed = true
        }

        playerDeck = newDeck
    }

    private func handleDestroy(_ event: CardEvent, deck: TrackedDeck) {
        var newDeck = deck

        if let handIndex = newDeck.handOriginal.firstIndex(where: { $0.id == event.card.id }) {
            newDeck.handOriginal.remove(at: handIndex)
        } else if let remainingIndex = newDeck.remainingOriginal.firstIndex(where: { $0.id == event.card.id }) {
            newDeck.remainingOriginal.remove(at: remainingIndex)
        }

        playerDeck = newDeck
    }

    private func handleCreate(_ event: CardEvent, deck: TrackedDeck) {
        let discovered = DiscoveredCard(
            card: event.card,
            source: .generated(by: "游戏事件"),
            timestamp: event.timestamp
        )
        var newDeck = deck
        newDeck.discoveredCards.append(discovered)
        playerDeck = newDeck
    }
}
