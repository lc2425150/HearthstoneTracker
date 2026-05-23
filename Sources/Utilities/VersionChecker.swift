import Foundation

struct VersionChecker {
    static let current: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }()

    static let build: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }()

    static var displayVersion: String { "\(current) (\(build))" }

    /// 检查 GitHub Releases 是否有新版本。返回 nil 表示已是最新，否则返回最新版本号。
    static func checkForUpdate() async -> String? {
        let repoURL = "https://api.github.com/repos/achen/HearthstoneTracker/releases/latest"
        guard let url = URL(string: repoURL) else { return nil }

        let session = URLSession(configuration: .ephemeral)
        session.configuration.timeoutIntervalForRequest = 10

        do {
            let (data, _) = try await session.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                // tag 格式如 "v1.2.3"，去掉 v 前缀后与当前版本比较
                let latest = tag.replacingOccurrences(of: "v", with: "")
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    return latest
                }
            }
        } catch {
            print("[VersionChecker] 更新检查失败: \(error)")
        }
        return nil
    }
}