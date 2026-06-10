import Foundation
import AppKit

/// AI 助手管理器：管理多个模型提供商、截图分析、缓存
@MainActor
final class AIManager: ObservableObject {
    static let shared = AIManager()
    
    @Published var selectedProvider: AIProviderType = .tongyi {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "aiProviderType") }
    }
    @Published var apiKey: String = "" {
        didSet {
            // 同步到 Keychain
            if apiKey.isEmpty {
                KeychainManager.delete(key: Constants.keychainAIKey)
            } else {
                KeychainManager.save(key: Constants.keychainAIKey, value: apiKey)
            }
        }
    }
    @Published var isAnalyzing = false
    @Published var lastSuggestion: AISuggestion?
    @Published var lastError: String?
    @Published var analysisMode: AIAnalysisMode = .auto {
        didSet { UserDefaults.standard.set(analysisMode.rawValue, forKey: "aiAnalysisMode") }
    }

    // MARK: - 子分析器（Phase 3）
    
    private let handPredictor = HandPredictor()
    private let mulliganAdvisor = MulliganAdvisor()
    private let deckOptimizer = DeckOptimizer()
    private let roundSummarizer = RoundSummarizer()
    
    // MARK: - 手牌预测
    
    @discardableResult
    func analyzeHandPrediction(core: CardTrackerCore) async -> String? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        lastError = nil
        
        let gameState = GameStateFormatter.format(core: core)
        let prompt = handPredictor.buildPrompt(gameState: gameState)
        
        do {
            let provider = try currentProvider()
            let suggestion = try await provider.analyzeMatchData(matchSummary: prompt)
            self.lastSuggestion = suggestion
            isAnalyzing = false
            return suggestion.suggestion
        } catch {
            self.lastError = error.localizedDescription
            isAnalyzing = false
            return nil
        }
    }
    
    // MARK: - 留牌建议
    
    @discardableResult
    func analyzeMulligan(playerClass: String, opponentClass: String,
                         handCards: [String], core: CardTrackerCore) async -> String? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        lastError = nil
        
        let gameState = GameStateFormatter.format(core: core)
        let prompt = mulliganAdvisor.buildPrompt(
            playerClass: playerClass, opponentClass: opponentClass,
            handCards: handCards, gameState: gameState
        )
        
        do {
            let provider = try currentProvider()
            let suggestion = try await provider.analyzeMatchData(matchSummary: prompt)
            self.lastSuggestion = suggestion
            isAnalyzing = false
            return suggestion.suggestion
        } catch {
            self.lastError = error.localizedDescription
            isAnalyzing = false
            return nil
        }
    }
    

    
    private var lastAnalysisTime: Date?
    private let minInterval: TimeInterval = 8 // 最小分析间隔：8秒（实时模式）
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "aiProviderType"),
           let p = AIProviderType(rawValue: saved) {
            selectedProvider = p
        }
        apiKey = KeychainManager.read(key: Constants.keychainAIKey) ?? UserDefaults.standard.string(forKey: "aiApiKey") ?? ""
        if let saved = UserDefaults.standard.string(forKey: "aiAnalysisMode"),
           let mode = AIAnalysisMode(rawValue: saved) {
            analysisMode = mode
        }
    }
    
    /// 获取当前选中的提供商实例
    private func currentProvider() throws -> AIModelProvider {
        guard !apiKey.isEmpty else { throw AIError.noApiKey }
        
        switch selectedProvider {
        case .tongyi:  return TongyiProvider(apiKey: apiKey)
        case .zhipu:   return ZhiPuProvider(apiKey: apiKey)
        case .baidu:   return BaiduProvider(apiKey: apiKey)
        case .xunfei:  return XunFeiProvider(apiKey: apiKey)
        case .tencent: return TencentProvider(apiKey: apiKey)
        case .deepseek: return DeepSeekProvider(apiKey: apiKey)
        case .kimi:     return KimiProvider(apiKey: apiKey)
        case .doubao:   return DoubaoProvider(apiKey: apiKey)
        case .yi:       return YiProvider(apiKey: apiKey)
        case .baichuan: return BaichuanProvider(apiKey: apiKey)
        case .openai:  return OpenAIProvider(apiKey: apiKey)
        }
    }
    
    /// 分析当前游戏画面
    func analyzeGameScreen() async {
        // 频率限制
        if let last = lastAnalysisTime, Date().timeIntervalSince(last) < minInterval {
            return
        }
        
        guard !isAnalyzing else { return }
        isAnalyzing = true
        lastError = nil
        
        do {
            let provider = try currentProvider()
            
            // 截取游戏窗口
            guard let screenData = await captureGameScreen() else {
                throw AIError.networkError("无法截取游戏画面")
            }
            
            let suggestion = try await provider.analyzeScreenshot(imageData: screenData, gameState: nil)
            
            await MainActor.run {
                self.lastSuggestion = suggestion
                self.lastAnalysisTime = Date()
                self.isAnalyzing = false
                // 通知悬浮窗显示建议
                NotificationCenter.default.post(name: .newAISuggestion, object: suggestion)
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isAnalyzing = false
            }
        }
    }
    
    /// 截取 Hearthstone 窗口（使用 ScreenCaptureKit）
    @MainActor
    private func captureGameScreen() async -> Data? {
        // 查找 Hearthstone 窗口
        guard let windowRect = ScreenCapture.findHearthstoneWindow(),
              windowRect.width > 300, windowRect.height > 300 else {
            print("[AIManager] Hearthstone window not found or too small")
            return nil
        }
        
        // 截取窗口（优先 ScreenCaptureKit，降级到 CG）
        guard let cgImage = await ScreenCapture.capture(region: windowRect) ?? captureLegacy(region: windowRect) else {
            return nil
        }
        
        // 缩小图片到50%以减少API传输时间
        let smallW = Int(windowRect.width / 2)
        let smallH = Int(windowRect.height / 2)
        guard let context = CGContext(data: nil, width: smallW, height: smallH,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: smallW, height: smallH))
        guard let resized = context.makeImage() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: resized)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
    
    /// 降级截图方案
    private func captureLegacy(region: CGRect) -> CGImage? {
        CGWindowListCreateImage(region, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    }
    

    /// 实时分析对局状态（基于文本状态，无需截图）
    func analyzeRealTime(core: CardTrackerCore) async {
        guard !isAnalyzing else { return }
        
        // 频率限制：8秒内不重复分析
        if let last = lastAnalysisTime, Date().timeIntervalSince(last) < minInterval {
            return
        }
        
        isAnalyzing = true
        lastError = nil
        
        let gameState = GameStateFormatter.format(core: core)
        let req = RealTimeAnalysisRequest.from(core: core)
        
        let prompt = """
你是一个炉石传说实时对局AI助手。根据当前对局状态，给出最优打法建议。
分析时要考虑：费用曲线、场面交换、手牌管理、对手可能的手牌和卡组类型。
最多给出2条建议，每条一行，格式为"建议|[理由]"。

当前对局状态:
\(gameState)

对手手牌约\(req.opponentHandSize)张，推测使用\(req.opponentManaUsed)费。
"""
        
        do {
            let provider = try currentProvider()
            let suggestion = try await provider.analyzeMatchData(matchSummary: prompt)
            
            await MainActor.run {
                self.lastSuggestion = suggestion
                self.lastAnalysisTime = Date()
                self.isAnalyzing = false
                NotificationCenter.default.post(name: .newAISuggestion, object: suggestion)
            }
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isAnalyzing = false
            }
        }
    }
    
    /// 分析赛后数据
    func analyzeMatchRecord(playerClass: String, opponentClass: String,
                            result: String, duration: Int,
                            playerCards: [String], opponentCards: [String],
                            notes: String) async -> AISuggestion? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        lastError = nil
        
        let matchSummary = """
职业: \(playerClass) vs \(opponentClass)
结果: \(result)
时长: \(duration)秒
我方卡牌: \(playerCards.joined(separator: ", "))
对手卡牌: \(opponentCards.joined(separator: ", "))
备注: \(notes)
"""
        
        do {
            let provider = try currentProvider()
            let suggestion = try await provider.analyzeMatchData(matchSummary: matchSummary)
            
            await MainActor.run {
                self.lastSuggestion = suggestion
                self.isAnalyzing = false
            }
            return suggestion
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isAnalyzing = false
            }
            return nil
        }
    }
    
    /// 分析卡组
    func analyzeDeck(heroClass: String, cards: [(name: String, count: Int)]) async -> AISuggestion? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        lastError = nil
        
        let cardList = cards.map { "\($0.name) x\($0.count)" }.joined(separator: "\n")
        let deckSummary = "职业: \(heroClass)\n卡组:\n\(cardList)"
        
        do {
            let provider = try currentProvider()
            let suggestion = try await provider.analyzeMatchData(matchSummary: "分析这套卡组的策略、优势和劣势:\n\(deckSummary)")
            
            await MainActor.run {
                self.lastSuggestion = suggestion
                self.isAnalyzing = false
            }
            return suggestion
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isAnalyzing = false
            }
            return nil
        }
    }
    
    /// 分析对局历史趋势
    func analyzeMatchHistory(recentMatches: [(playerClass: String, opponentClass: String, result: String)]) async -> AISuggestion? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        lastError = nil
        
        let matchList = recentMatches.enumerated().map { i, m in
            "\(i+1). \(m.playerClass) vs \(m.opponentClass) - \(m.result)"
        }.joined(separator: "\n")
        let historySummary = "最近对局:\n\(matchList)"
        
        do {
            let provider = try currentProvider()
            let suggestion = try await provider.analyzeMatchData(matchSummary: "分析我的炉石对局趋势，给出改进建议:\n\(historySummary)")
            
            await MainActor.run {
                self.lastSuggestion = suggestion
                self.isAnalyzing = false
            }
            return suggestion
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.isAnalyzing = false
            }
            return nil
        }
    }
    
    /// 清空建议
    func clearSuggestion() {

        lastSuggestion = nil
        lastError = nil
    }
}

extension Notification.Name {
    static let newAISuggestion = Notification.Name("newAISuggestion")
}
