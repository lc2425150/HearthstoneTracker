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
    private let minInterval: TimeInterval = 20 // 最小分析间隔：10秒
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "aiProviderType"),
           let provider = AIProviderType(rawValue: saved) {
            if let p = AIProviderType(rawValue: saved) { selectedProvider = p }
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
    
    /// 清空建议
    func clearSuggestion() {
        lastSuggestion = nil
        lastError = nil
    }
}

extension Notification.Name {
    static let newAISuggestion = Notification.Name("newAISuggestion")
}
