import Foundation
import AppKit

// MARK: - 通义千问 (DashScope - OpenAI 兼容接口)

struct TongyiProvider: AIModelProvider {
    let type: AIProviderType = .tongyi
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let base64 = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是一个炉石传说AI助手。分析截图中的对局情况，给出最佳出牌建议。用中文回答，简洁明了。格式：建议+理由。"],
            ["role": "user", "content": [
                ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                ["type": "text", "text": "分析当前对局，我应该怎么出牌？考虑费用、场面、手牌和对手情况。"]
            ]]
        ]
        
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - 智谱 GLM-4V

struct ZhiPuProvider: AIModelProvider {
    let type: AIProviderType = .zhipu
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let base64 = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": [
                ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                ["type": "text", "text": "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答，格式：建议+理由。考虑费用、场面、手牌。"]
            ]]
        ]
        
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - 腾讯混元

struct TencentProvider: AIModelProvider {
    let type: AIProviderType = .tencent
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let base64 = imageData.base64EncodedString()
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": [
                ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                ["type": "text", "text": "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答，格式：建议+理由。考虑费用、场面、手牌。"]
            ]]
        ]
        
        return try await callOpenAICompatible(endpoint: type.apiEndpoint, apiKey: apiKey, model: type.modelName, messages: messages)
    }
}

// MARK: - 百度文心 (OAuth2 token)

struct BaiduProvider: AIModelProvider {
    let type: AIProviderType = .baidu
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        let base64 = imageData.base64EncodedString()
        
        let body: [String: Any] = [
            "model": type.modelName,
            "messages": [
                ["role": "user", "content": [
                    ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]],
                    ["type": "text", "text": "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答，格式：建议+理由。"]
                ]]
            ]
        ]
        
        var request = URLRequest(url: URL(string: type.apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await sendRequest(request)
    }
}

// MARK: - 讯飞星火

struct XunFeiProvider: AIModelProvider {
    let type: AIProviderType = .xunfei
    let apiKey: String
    
    func analyzeScreenshot(imageData: Data, gameState: String?) async throws -> AISuggestion {
        // 讯飞使用 WebSocket 协议，为简化先通过 HTTP 兼容接口
        let base64 = imageData.base64EncodedString()
        
        let body: [String: Any] = [
            "model": type.modelName,
            "messages": [
                ["role": "user", "content": "你是一个炉石传说AI助手。分析截图，给出最佳出牌建议。用中文回答。截图数据: [图片]"]
            ]
        ]
        
        var request = URLRequest(url: URL(string: type.apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await sendRequest(request)
    }
}

// MARK: - 通用 OpenAI 兼容接口

private func callOpenAICompatible(endpoint: String, apiKey: String, model: String, messages: [[String: Any]]) async throws -> AISuggestion {
    let body: [String: Any] = [
        "model": model,
        "messages": messages,
        "max_tokens": 500,
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
    
    // 分割建议和理由
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
