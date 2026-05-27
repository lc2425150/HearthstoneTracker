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
    private let minInterval: TimeInterval = 10 // 最小分析间隔：10秒
    
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
    
    /// 截取 Hearthstone 窗口
    private func captureGameScreen() -> Data? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
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
                return nil
            }
            
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            return bitmap.representation(using: .png, properties: [:])
        }
        return nil
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
