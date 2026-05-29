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
    case deepseek = "DeepSeek"
    case openai = "OpenAI"
    
    var displayName: String { rawValue }
    
    var modelName: String {
        switch self {
        case .tongyi:  return "qwen-vl-plus"
        case .zhipu:   return "glm-4v-plus"
        case .baidu:   return "ERNIE-4.0-8K-latest"
        case .xunfei:  return "spark-4.0"
        case .tencent: return "hunyuan-vision"
        case .deepseek: return "deepseek-vl"
        case .openai:  return "gpt-4o"
        }
    }
    
    var apiEndpoint: String {
        switch self {
        case .tongyi:  return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .zhipu:   return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .baidu:   return "https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions_pro"
        case .xunfei:  return "https://spark-api.xf-yun.com/v4.0/chat"
        case .tencent: return "https://api.hunyuan.cloud.tencent.com/v1/chat/completions"
        case .deepseek: return "https://api.deepseek.com/v1/chat/completions"
        case .openai:  return "https://api.openai.com/v1/chat/completions"
        }
    }
}

/// AI 提供商协议
protocol AIModelProvider {
    var type: AIProviderType { get }
    var apiKey: String { get }
    
    /// 分析游戏截图并返回出牌建议
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion
    
    /// 分析对局记录（赛后分析）
    func analyzeMatchData(matchSummary: String) async throws -> AISuggestion
}

// MARK: - 默认赛后分析实现
extension AIModelProvider {
    /// 默认使用 callOpenAICompatible 风格调用（中文提供商需自行重写）
    func analyzeMatchData(matchSummary: String) async throws -> AISuggestion {
        // 发出 JSON 请求分析对局数据
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI分析助手。分析对局数据，给出技术总结和改进建议。用中文回答。"],
            ["role": "user", "content": [["type": "text", "text": "分析这局炉石对局:\n" + matchSummary]]]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 800,
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.providerError("HTTP error: " + bodyStr.prefix(200))
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
