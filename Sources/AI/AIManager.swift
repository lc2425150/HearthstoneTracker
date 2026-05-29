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
        didSet { UserDefaults.standard.set(apiKey, forKey: "aiApiKey") }
    }
    @Published var isAnalyzing = false
    @Published var lastSuggestion: AISuggestion?
    @Published var lastError: String?
    @Published var enableAutoAnalyze = true {
        didSet { UserDefaults.standard.set(enableAutoAnalyze, forKey: "aiAutoAnalyze") }
    }
    
    private var lastAnalysisTime: Date?
    private let minInterval: TimeInterval = 8 // 最小分析间隔：8秒（实时模式）
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "aiProviderType"),
           let p = AIProviderType(rawValue: saved) {
            selectedProvider = p
        }
        apiKey = UserDefaults.standard.string(forKey: "aiApiKey") ?? ""
        enableAutoAnalyze = UserDefaults.standard.bool(forKey: "aiAutoAnalyze")
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
            guard let screenData = captureGameScreen() else {
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
    
    /// 截取 Hearthstone 窗口（后台线程 + 降低分辨率）
    private func captureGameScreen() -> Data? {
        // 在后台线程执行截图
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?
        
        DispatchQueue.global(qos: .userInitiated).async {
            let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
            guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
                semaphore.signal()
                return
            }
            
            for info in windowList {
                guard let ownerName = info["kCGWindowOwnerName"] as? String,
                      ownerName == "Hearthstone" || ownerName.contains("炉石"),
                      let boundsDict = info["kCGWindowBounds"] as? [String: CGFloat],
                      let x = boundsDict["X"], let y = boundsDict["Y"],
                      let w = boundsDict["Width"], let h = boundsDict["Height"],
                      w > 300, h > 300 else { continue }
                
                let region = CGRect(x: x, y: y, width: w, height: h)
                guard let cgImage = CGWindowListCreateImage(region, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
                    semaphore.signal()
                    return
                }
                
                // 缩小图片到50%以减少API传输时间
                let smallW = Int(w / 2)
                let smallH = Int(h / 2)
                if let context = CGContext(data: nil, width: smallW, height: smallH,
                                           bitsPerComponent: 8, bytesPerRow: 0,
                                           space: CGColorSpaceCreateDeviceRGB(),
                                           bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
                    context.interpolationQuality = .medium
                    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: smallW, height: smallH))
                    if let resized = context.makeImage() {
                        let bitmap = NSBitmapImageRep(cgImage: resized)
                        result = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
                    }
                }
                break
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 5)
        return result
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
        
        let gameState = await GameStateFormatter.format(core: core)
        let req = await RealTimeAnalysisRequest.from(core: core)
        
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
