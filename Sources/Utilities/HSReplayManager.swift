import Foundation
import AppKit

/// HSReplay.net 集成管理器
/// 负责 OAuth 认证、对局上传、数据统计查询
@MainActor
final class HSReplayManager {
    static let shared = HSReplayManager()
    
    private let baseURL = "https://hsreplay.net"
    private let apiURL = "https://hsreplay.net/api/v1"
    private let session: URLSession
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var uploadStatus: UploadStatus = .idle
    @Published private(set) var username: String?
    
    enum UploadStatus: Equatable {
        case idle
        case uploading
        case success
        case failed(String)
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        // Check stored token
        if let _ = KeychainManager.getHSReplayToken() {
            isAuthenticated = true
        }
    }
    
    /// 打开浏览器进行 OAuth 登录
    func authenticate() {
        guard let url = URL(string: "\(baseURL)/accounts/login/?next=/api/v1/oauth/") else { return }
        NSWorkspace.shared.open(url)
    }
    
    /// 设置 API Token（用户从 HSReplay.net 复制）
    func setToken(_ token: String) {
        KeychainManager.saveHSReplayToken(token)
        isAuthenticated = true
        fetchUsername()
    }
    
    /// 登出
    func logout() {
        KeychainManager.clearHSReplayToken()
        isAuthenticated = false
        username = nil
    }
    
    /// 获取用户信息
    private func fetchUsername() {
        guard let token = KeychainManager.getHSReplayToken(),
              let url = URL(string: "\(apiURL)/account/") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        Task {
            do {
                let (data, _) = try await session.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let user = json["username"] as? String {
                    username = user
                }
            } catch {
                print("[HSReplay] Failed to fetch username: \(error)")
            }
        }
    }
    
    /// 上传对局记录
    func uploadMatch(_ match: MatchRecord, playerDeckCode: String?) async {
        guard let token = KeychainManager.getHSReplayToken(),
              let url = URL(string: "\(apiURL)/game/replay/") else {
            uploadStatus = .failed("未登录 HSReplay.net")
            return
        }
        
        uploadStatus = .uploading
        
        // 构建上传数据
        var replayData: [String: Any] = [
            "player_class": match.playerClass,
            "opponent_class": match.opponentClass,
            "result": match.result.rawValue,
            "game_date": ISO8601DateFormatter().string(from: match.startTime),
            "duration": match.duration,
        ]
        
        if let code = playerDeckCode, !code.isEmpty {
            replayData["deck_code"] = code
        }
        if let endTime = match.endTime {
            replayData["end_date"] = ISO8601DateFormatter().string(from: endTime)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: replayData)
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                uploadStatus = .success
            } else {
                uploadStatus = .failed("上传失败")
            }
        } catch {
            uploadStatus = .failed(error.localizedDescription)
        }
    }
}

/// 简单的钥匙串管理器（存储 HSReplay Token）
