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

/// 支持的 AI 模型提供商（国内常用 + OpenAI）
enum AIProviderType: String, CaseIterable, Codable {
    case tongyi    = "通义千问"
    case zhipu     = "智谱GLM"
    case deepseek  = "DeepSeek"
    case kimi      = "Kimi(月之暗面)"
    case doubao    = "豆包(字节)"
    case baidu     = "百度文心"
    case tencent   = "腾讯混元"
    case xunfei    = "讯飞星火"
    case yi        = "零一万物"
    case baichuan  = "百川智能"
    case openai    = "OpenAI"
    
    var displayName: String { rawValue }
    
    /// 文本模型（实时分析用）
    var modelName: String {
        switch self {
        case .tongyi:    return "qwen-plus"
        case .zhipu:     return "glm-4-flash"
        case .deepseek:  return "deepseek-chat"
        case .kimi:      return "moonshot-v1-8k"
        case .doubao:    return "ep-20241212114248-2xpl8" // doubao-pro-32k
        case .baidu:     return "ERNIE-4.0-8K-latest"
        case .tencent:   return "hunyuan-lite"
        case .xunfei:    return "spark-4.0"
        case .yi:        return "yi-lightning"
        case .baichuan:  return "Baichuan4-Turbo"
        case .openai:    return "gpt-4o-mini"
        }
    }
    
    /// API 端点（统一为 OpenAI 兼容格式）
    var apiEndpoint: String {
        switch self {
        case .tongyi:    return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .zhipu:     return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .deepseek:  return "https://api.deepseek.com/v1/chat/completions"
        case .kimi:      return "https://api.moonshot.cn/v1/chat/completions"
        case .doubao:    return "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
        case .baidu:     return "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions_pro"
        case .tencent:   return "https://api.hunyuan.cloud.tencent.com/v1/chat/completions"
        case .xunfei:    return "https://spark-api.xf-yun.com/v4.0/chat"
        case .yi:        return "https://api.lingyiwanwu.com/v1/chat/completions"
        case .baichuan:  return "https://api.baichuan-ai.com/v1/chat/completions"
        case .openai:    return "https://api.openai.com/v1/chat/completions"
        }
    }
}

/// AI 提供商协议
protocol AIModelProvider {
    var type: AIProviderType { get }
    var apiKey: String { get }
    
    /// 分析游戏截图并返回出牌建议
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion
    
    /// 分析对局记录（文本分析）
    func analyzeMatchData(matchSummary: String) async throws -> AISuggestion
}

// MARK: - 通用文本分析默认实现（使用 OpenAI 兼容格式）
extension AIModelProvider {
    func analyzeMatchData(matchSummary: String) async throws -> AISuggestion {
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI分析助手。分析对局数据，给出技术总结和改进建议。用中文回答。"],
            ["role": "user", "content": [["type": "text", "text": matchSummary]]]
        ]
        
        let body: [String: Any] = [
            "model": type.modelName,
            "messages": messages,
            "max_tokens": 800,
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: URL(string: type.apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("无效响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.providerError("HTTP \(httpResponse.statusCode): " + bodyStr.prefix(200))
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError("无法解析 AI 响应")
        }
        
        let parts = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        let suggestion = parts.first ?? content
        let reasoning = parts.dropFirst().joined(separator: "\n")
        
        return AISuggestion(
            suggestion: suggestion,
            reasoning: reasoning,
            confidence: "中",
            timestamp: Date()
        )
    }
}

/// AI 分析模式
enum AIAnalysisMode: String, CaseIterable, Codable {
    case auto = "自动实时分析"
    case manual = "手动分析"
    
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .auto:   return "play.circle.fill"
        case .manual: return "hand.tap.fill"
        }
    }
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
