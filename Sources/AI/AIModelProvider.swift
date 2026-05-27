import Foundation
import AppKit

/// AI 出牌建议
struct AISuggestion: Identifiable {
    let id = UUID()
    let suggestion: String
    let reasoning: String
    let confidence: String
    let timestamp: Date
}

/// 支持的 AI 模型提供商
enum AIProviderType: String, CaseIterable, Codable {
    case tongyi = "通义千问"
    case zhipu = "智谱GLM"
    case baidu = "百度文心"
    case xunfei = "讯飞星火"
    case tencent = "腾讯混元"
    
    var displayName: String { rawValue }
    
    var modelName: String {
        switch self {
        case .tongyi:  return "qwen-vl-plus"
        case .zhipu:   return "glm-4v-plus"
        case .baidu:   return "ERNIE-4.0-8K-latest"
        case .xunfei:  return "spark-4.0"
        case .tencent: return "hunyuan-vision"
        }
    }
    
    var apiEndpoint: String {
        switch self {
        case .tongyi:  return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .zhipu:   return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .baidu:   return "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions_pro"
        case .xunfei:  return "https://spark-api.xf-yun.com/v4.0/chat"
        case .tencent: return "https://api.hunyuan.cloud.tencent.com/v1/chat/completions"
        }
    }
}

/// AI 提供商协议
protocol AIModelProvider {
    var type: AIProviderType { get }
    var apiKey: String { get }
    
    /// 分析游戏截图并返回出牌建议
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion
}

/// API 错误
enum AIError: LocalizedError {
    case noApiKey
    case networkError(String)
    case parseError(String)
    case providerError(String)
    
    var errorDescription: String? {
        switch self {
        case .noApiKey: return "请先在设置中输入 API Key"
        case .networkError(let e): return "网络错误: \(e)"
        case .parseError(let e): return "解析失败: \(e)"
        case .providerError(let e): return "模型返回错误: \(e)"
        }
    }
}
