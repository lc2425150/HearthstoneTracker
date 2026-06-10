import SwiftUI
import Combine
import AppKit

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
            return "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json"
        case .hsReplay:
            // 备用: 使用 hearthstoneJSON 的英文数据
            return "https://api.hearthstonejson.com/v1/latest/enUS/cards.json"
        case .hearthPwn:
            // 备用: 同样使用 hearthstoneJSON
            return "https://api.hearthstonejson.com/v1/latest/zhCN/cards.json"
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
    @Published var overlayWidth: CGFloat = 280 {
        didSet { UserDefaults.standard.set(overlayWidth, forKey: "overlayWidth") }
    }
    @Published var overlayInsideGame = false {
        didSet { UserDefaults.standard.set(overlayInsideGame, forKey: "overlayInsideGame") }
    }
    @Published var overlayAutoHide = false {
        didSet { UserDefaults.standard.set(overlayAutoHide, forKey: "overlayAutoHide") }
    }
    @Published var ocrOpponentTracking = true {
        didSet { UserDefaults.standard.set(ocrOpponentTracking, forKey: "ocrOpponentTracking") }
    }
    @Published var cardDisplaySize: CardDisplaySize {
        didSet {
            UserDefaults.standard.set(cardDisplaySize.rawValue, forKey: "cardDisplaySize")
        }
    }
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
    let deckRecommendation = DeckRecommendationService.shared

    // MARK: - AI Assistant

    @Published var aiSuggestion: AISuggestion?
    @Published var aiIsAnalyzing = false
    @Published var aiError: String?
    
    @Published var aiProviderType: AIProviderType = .tongyi {
        didSet { AIManager.shared.selectedProvider = aiProviderType }
    }
    @Published var aiApiKey: String = "" {
        didSet {
            if aiApiKey.isEmpty {
                KeychainManager.delete(key: Constants.keychainAIKey)
            } else {
                KeychainManager.save(key: Constants.keychainAIKey, value: aiApiKey)
            }
            AIManager.shared.apiKey = aiApiKey
        }
    }
    @Published var aiAnalysisMode: AIAnalysisMode = .auto {
        didSet { AIManager.shared.analysisMode = aiAnalysisMode }
    }
    
    /// 自动模式下的定时器
    private var realTimeAnalysisTimer: Timer? 

    // MARK: - UI State

    @Published var isOverlayVisible = false
    @Published var windowsLocked = false {
        didSet {
            UserDefaults.standard.set(windowsLocked, forKey: "windowsLocked")
            // 立即更新悬浮窗状态
            if isOverlayVisible {
                OverlayWindowController.shared.updateLockState(locked: windowsLocked)
            }
        }
    }
    @Published var isTracking = false

    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false

    init() {
        // 先创建轻量级模块，不触发数据库查询
        ocrScanner = VisionOCRScanner(database: cardDatabase)
        opponentTracker = OpponentCardTracker(database: cardDatabase)
        eventPipeline = EventPipeline(database: cardDatabase)
        cardDataUpdater = CardDataUpdater(database: cardDatabase)
        
        // 共享数据库实例给子模块，避免多个 ModelContainer 冲突
        StatsManager.configure(database: cardDatabase)
        
        // 读取卡牌尺寸和数据库来源设置
        windowsLocked = UserDefaults.standard.object(forKey: "windowsLocked") as? Bool ?? false
        overlayWidth = UserDefaults.standard.object(forKey: "overlayWidth") != nil ? CGFloat(UserDefaults.standard.double(forKey: "overlayWidth")) : 280
        overlayInsideGame = UserDefaults.standard.bool(forKey: "overlayInsideGame")
        overlayAutoHide = UserDefaults.standard.bool(forKey: "overlayAutoHide")
        ocrOpponentTracking = UserDefaults.standard.bool(forKey: "ocrOpponentTracking")
        
        if let savedSize = UserDefaults.standard.string(forKey: "cardDisplaySize"),
           let size = CardDisplaySize(rawValue: savedSize) {
            cardDisplaySize = size
        } else {
            cardDisplaySize = .medium
        }
        
        if let saved = UserDefaults.standard.string(forKey: "selectedDataSource"),
           let source = CardDataSource(rawValue: saved) {
            selectedDataSource = source
        }
        
        // 延迟加载数据（在 initializeData 中完成）
        // 从 AIManager 同步 AI 设置
        aiProviderType = AIManager.shared.selectedProvider
        aiApiKey = AIManager.shared.apiKey
        aiAnalysisMode = AIManager.shared.analysisMode
        setupSubscriptions()
        
        // HSReplay.net 集成
        _ = HSReplayManager.shared
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
        // 启动 OCR 对手卡牌识别（如果开启）
        if ocrOpponentTracking {
            startOpponentTracking()
            startOCRScanLoop()
        }
        // 自动模式下启动实时分析定时器
        startRealTimeAnalysis()
        isTracking = true
    }

    func stopTracking() {
        eventPipeline.stop()
        stopOCRScanLoop()
        stopRealTimeAnalysis()
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
        // 后台延迟首次扫描，避免阻塞主线程
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
            guard self.isTracking else { return }
            self.ocrScanner.scanGameWindow()
        }
    }
    
    // OCR 定时扫描循环（每 3 秒一次）
    private var ocrScanTimer: Timer?
    
    private func startOCRScanLoop() {
        stopOCRScanLoop()
        ocrScanTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isTracking, self.ocrOpponentTracking else { return }
                self.ocrScanner.scanGameWindow()
            }
        }
    }
    
    private func stopOCRScanLoop() {
        ocrScanTimer?.invalidate()
        ocrScanTimer = nil
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

        // 先检查本地是否已有卡牌数据
        let localCardCount = cardDatabase.countAllCards()
        if localCardCount > 0 {
            print("[Core] 本地已有 \(localCardCount) 张卡牌，跳过下载")
            await MainActor.run {
                isDataReady = true
                isUpdatingData = false
                let lastUpdate = cardDatabase.lastUpdateDate()
                if let date = lastUpdate {
                    availableDataSources[selectedDataSource] = date
                }
            }
            return
        }
        
        print("[Core] 本地无卡牌数据，开始下载...")
        
        // 只从 hearthstoneJSON 下载（其他数据源已失效）
        let primarySource = CardDataSource.hearthstoneJSON
        do {
            let result = try await cardDataUpdater.checkForUpdates(from: primarySource)
            cardDatabase.saveLastUpdateDate(result.timestamp)
            await MainActor.run {
                lastUpdateResult = result
                availableDataSources[primarySource] = result.timestamp
                selectedDataSource = primarySource
                isDataReady = true
                isUpdatingData = false
            }
            print("[Core] 卡牌数据下载成功: \(result.totalCards) 张")
        } catch {
            print("[Core] 卡牌数据下载失败: \(error)")
            await MainActor.run {
                deckImportError = "卡牌数据下载失败，请检查网络后重试"
                isUpdatingData = false
                isDataReady = true // 仍标记为 ready 以免 UI 卡住
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
    /// 如有必要则导入卡组（推荐卡组一键复制时调用）
    func importDeckIfNeeded(from deckCode: String) {
        if playerDeck == nil {
            importDeck(from: deckCode)
        }
    }
    
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

            let cardTuples = result.cards.map { ($0.card, $0.count) }
            playerDeck = TrackedDeck(
                deckCode: cleaned,
                cards: cardTuples,
                discoveredCards: [],
                heroClass: result.heroClass
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
        }
        
        // 自动上传对局到 HSReplay.net
        Task { @MainActor in
            if HSReplayManager.shared.isAuthenticated {
                await HSReplayManager.shared.uploadMatch(m, playerDeckCode: m.deckCode)
            }
        }
        
        // 自动 AI 赛后分析（如果配置了 API Key）
        if !aiApiKey.isEmpty && aiAnalysisMode == .auto {
            let opponentCards = opponentPlayedCards.map { $0.name }
            Task { @MainActor in
                _ = await AIManager.shared.analyzeMatchRecord(
                    playerClass: m.playerClass,
                    opponentClass: m.opponentClass,
                    result: m.result.displayName,
                    duration: Int(m.duration),
                    playerCards: [],
                    opponentCards: opponentCards,
                    notes: m.notes
                )
                self.aiSuggestion = AIManager.shared.lastSuggestion
            }
        }
        
        currentMatch = nil
        resetMatch()
        // 重置后重启定时器
        if aiAnalysisMode == .auto {
            startRealTimeAnalysis()
        }
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

    @MainActor func editDeckName(_ deck: SavedDeck, newName: String) {
        deck.name = newName
        do {
            try cardDatabase.modelContainer.mainContext.save()
            loadSavedDecks()
        } catch {
            print("[Core] Failed to rename deck: \(error)")
        }
    }

    @MainActor func toggleFavorite(_ deck: SavedDeck) {
        deck.isFavorite.toggle()
        do {
            try cardDatabase.modelContainer.mainContext.save()
            loadSavedDecks()
        } catch {
            print("[Core] Failed to toggle favorite: \(error)")
        }
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
    
    @Published var updateAvailable: VersionChecker.UpdateInfo? = nil
    @Published var isCheckingUpdate = false
    
    /// 检查应用版本更新
    func checkAppUpdate() async {
        guard !isCheckingUpdate else { return }
        isCheckingUpdate = true
        defer { isCheckingUpdate = false }
        
        let info = await VersionChecker.checkForUpdate()
        await MainActor.run {
            self.updateAvailable = info
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

    /// 手动触发 AI 分析（两种模式下均可使用）
    func requestAIAnalysis() {
        guard !aiIsAnalyzing else { return }
        guard !aiApiKey.isEmpty else {
            aiError = "请先在设置中配置 API Key"
            return
        }
        aiIsAnalyzing = true
        aiError = nil
        
        Task { @MainActor in
            await AIManager.shared.analyzeRealTime(core: self)
            self.aiSuggestion = AIManager.shared.lastSuggestion
            self.aiError = AIManager.shared.lastError
            self.aiIsAnalyzing = false
        }
    }
    
    /// 启动自动实时分析定时器（仅自动模式）
    private func startRealTimeAnalysis() {
        stopRealTimeAnalysis()
        guard aiAnalysisMode == .auto, !aiApiKey.isEmpty else { return }
        realTimeAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await AIManager.shared.analyzeRealTime(core: self)
                self.aiSuggestion = AIManager.shared.lastSuggestion
                self.aiError = AIManager.shared.lastError
                self.aiIsAnalyzing = false
            }
        }
    }
    
    /// 停止自动实时分析定时器
    private func stopRealTimeAnalysis() {
        realTimeAnalysisTimer?.invalidate()
        realTimeAnalysisTimer = nil
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
        
        // 自动检测游戏开始-从剪贴板导入卡组
        eventPipeline.onGameStart
            .sink { [weak self] _ in
                guard let self else { return }
                // 游戏开始时自动 AI 分析（实时模式）
                if self.aiAnalysisMode == .auto {
                    Task { @MainActor in
                        await AIManager.shared.analyzeRealTime(core: self)
                        self.aiSuggestion = AIManager.shared.lastSuggestion
                        self.aiIsAnalyzing = false
                    }
                }
                // 游戏开始时自动检测剪贴板中的卡组码
                if self.playerDeck == nil {
                    let pasteboard = NSPasteboard.general
                    if let code = pasteboard.string(forType: .string), !code.isEmpty {
                        self.importDeck(from: code)
                        if self.playerDeck != nil {
                            print("[AutoDeck] 已自动从剪贴板导入卡组")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // 卡牌事件触发实时 AI 分析（每回合检测手牌变化）
        eventPipeline.cardEvents
            .debounce(for: .seconds(2.0), scheduler: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self, self.aiAnalysisMode == .auto, !self.aiApiKey.isEmpty else { return }
                // 玩家抽牌/出牌时触发分析
                if event.player == .player, 
                   (event.type == .draw || event.type == .play) {
                    Task { @MainActor in
                        await AIManager.shared.analyzeRealTime(core: self)
                        self.aiSuggestion = AIManager.shared.lastSuggestion
                        self.aiError = AIManager.shared.lastError
                        self.aiIsAnalyzing = false
                    }
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
        var newDeck = deck
        let dbfId = event.card.dbfId
        if let current = newDeck.cardCounts[dbfId], current > 0 {
            newDeck.cardCounts[dbfId] = current - 1
            newDeck.handOriginal.append(event.card)
        }
        playerDeck = newDeck
    }

    private func handlePlay(_ event: CardEvent, deck: TrackedDeck) {
        var newDeck = deck
        let dbfId = event.card.dbfId
        
        // 从手牌移除
        if let handIndex = newDeck.handOriginal.firstIndex(where: { $0.dbfId == dbfId }) {
            newDeck.handOriginal.remove(at: handIndex)
            newDeck.playedOriginal.append(event.card)
        } else if let current = newDeck.cardCounts[dbfId], current > 0 {
            // 直接从牌库打出
            newDeck.cardCounts[dbfId] = current - 1
            newDeck.playedOriginal.append(event.card)
        }

        if let discIndex = newDeck.discoveredCards.firstIndex(where: { $0.card.dbfId == dbfId && !$0.isPlayed }) {
            newDeck.discoveredCards[discIndex].isPlayed = true
        }

        playerDeck = newDeck
    }

    private func handleDestroy(_ event: CardEvent, deck: TrackedDeck) {
        var newDeck = deck
        let dbfId = event.card.dbfId
        
        if let handIndex = newDeck.handOriginal.firstIndex(where: { $0.dbfId == dbfId }) {
            newDeck.handOriginal.remove(at: handIndex)
        } else if let current = newDeck.cardCounts[dbfId], current > 0 {
            newDeck.cardCounts[dbfId] = current - 1
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
