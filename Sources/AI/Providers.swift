import Foundation
import AppKit

// MARK: - 通义千问 (通义 DashScope - OpenAI 兼容接口)

struct TongyiProvider: AIModelProvider {
    let type: AIProviderType = .tongyi
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let messages = screenshotMessages(imageData: imageData, systemPrompt: systemPrompt)
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: "qwen-vl-plus", messages: messages)
    }
    
    private var systemPrompt: String {
        "你是一个炉石传说AI助手。分析截图中的对局情况，给出最佳出牌建议。用中文回答，简洁明了。格式：建议+理由。"
    }
}

// MARK: - 智谱 GLM

struct ZhiPuProvider: AIModelProvider {
    let type: AIProviderType = .zhipu
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let messages = screenshotMessages(imageData: imageData, systemPrompt: "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答，格式：建议+理由。考虑费用、场面、手牌。")
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: "glm-4v-plus", messages: messages)
    }
}

// MARK: - DeepSeek

struct DeepSeekProvider: AIModelProvider {
    let type: AIProviderType = .deepseek
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        // DeepSeek 不支持图片输入，回退到文本描述
        let text = gameState ?? "当前对局截图"
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI助手。分析对局情况，给出最佳出牌建议。用中文回答。"],
            ["role": "user", "content": [["type": "text", "text": "当前对局: " + text]]]
        ]
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - Kimi (月之暗面 Moonshot)

struct KimiProvider: AIModelProvider {
    let type: AIProviderType = .kimi
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        // Kimi 支持多模态，发送截图
        let messages = screenshotMessages(imageData: imageData, systemPrompt: "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答。")
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: "moonshot-v1-8k-vision-preview", messages: messages)
    }
}

// MARK: - 豆包 (字节跳动火山引擎)

struct DoubaoProvider: AIModelProvider {
    let type: AIProviderType = .doubao
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        // 豆包通过火山引擎 API，使用 OpenAI 兼容格式
        let messages = screenshotMessages(imageData: imageData, systemPrompt: "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答。")
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - 百度文心

struct BaiduProvider: AIModelProvider {
    let type: AIProviderType = .baidu
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let prompt = "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答，格式：建议+理由。"
        let body: [String: Any] = [
            "model": type.modelName,
            "messages": [["role": "user", "content": prompt]]
        ]
        
        var request = URLRequest(url: URL(string: type.apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await sendRequest(request)
    }
}

// MARK: - 腾讯混元

struct TencentProvider: AIModelProvider {
    let type: AIProviderType = .tencent
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let messages = screenshotMessages(imageData: imageData, systemPrompt: "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答。")
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: "hunyuan-vision", messages: messages)
    }
}

// MARK: - 讯飞星火

struct XunFeiProvider: AIModelProvider {
    let type: AIProviderType = .xunfei
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let body: [String: Any] = [
            "model": type.modelName,
            "messages": [["role": "user", "content": "你是一个炉石传说AI助手。分析对局，给出最佳出牌建议。用中文回答。"]]
        ]
        
        var request = URLRequest(url: URL(string: type.apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await sendRequest(request)
    }
}

// MARK: - 零一万物 (Yi)

struct YiProvider: AIModelProvider {
    let type: AIProviderType = .yi
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let text = gameState ?? "当前对局截图"
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI助手。分析对局，给出最佳出牌建议。用中文回答。"],
            ["role": "user", "content": [["type": "text", "text": text]]]
        ]
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - 百川智能

struct BaichuanProvider: AIModelProvider {
    let type: AIProviderType = .baichuan
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let text = gameState ?? "当前对局截图"
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI助手。分析对局，给出最佳出牌建议。用中文回答。"],
            ["role": "user", "content": [["type": "text", "text": text]]]
        ]
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - OpenAI (ChatGPT)

struct OpenAIProvider: AIModelProvider {
    let type: AIProviderType = .openai
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let messages = screenshotMessages(imageData: imageData, systemPrompt: "你是一个炉石传说AI助手。分析截图中的对局情况，给出最佳出牌建议。用中文回答，格式：建议+理由。")
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: "gpt-4o", messages: messages)
    }
    
    func analyzeMatchData(matchSummary: String) async throws -> AISuggestion {
        let userMsg = "分析这局炉石对局: " + matchSummary
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI分析助手。分析对局数据，给出技术总结和改进建议。用中文回答。"],
            ["role": "user", "content": [["type": "text", "text": userMsg]]]
        ]
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: "gpt-4o-mini", messages: messages)
    }
}

// MARK: - 通用 OpenAI 兼容接口

private func callOpenAICompatible(endpoint: String, apiKey: String, model: String, messages: [[String: Any]]) async throws -> AISuggestion {
    let body: [String: Any] = [
        "model": model,
        "messages": messages,
        "max_tokens": 800,
        "temperature": 0.7
    ]
    
    var request = URLRequest(url: URL(string: endpoint)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    request.timeoutInterval = 30
    
    return try await sendRequest(request)
}

/// 通用请求发送 + 响应解析
private func sendRequest(_ request: URLRequest) async throws -> AISuggestion {
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIError.networkError("无效响应")
    }
    
    guard httpResponse.statusCode == 200 else {
        let body = String(data: data, encoding: .utf8) ?? "unknown"
        throw AIError.providerError("HTTP \(httpResponse.statusCode): \(body.prefix(200))")
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

// MARK: - 截图消息构造辅助

/// 构造带截图的用户消息（OpenAI vision 格式）
private func screenshotMessages(imageData: Data, systemPrompt: String) -> [[String: Any]] {
    let base64 = imageData.base64EncodedString()
    return [
        ["role": "system", "content": systemPrompt],
        ["role": "user", "content": [
            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
            ["type": "text", "text": "分析当前对局，我应该怎么出牌？考虑费用、场面、手牌和对手情况。"]
        ]]
    ]
}
