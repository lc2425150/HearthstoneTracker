import AppKit
import Foundation

struct VersionChecker {
    static let current: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }()

    static let build: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }()

    static let repoOwner = "lc2425150"
    static let repoName = "HearthstoneTracker"
    
    static var displayVersion: String { "\(current) (\(build))" }
    
    /// 版本信息结构
    struct UpdateInfo {
        let latestVersion: String
        let downloadURL: URL
        let releaseNotes: String?
    }

    /// 检查 GitHub Releases 是否有新版本
    static func checkForUpdate() async -> UpdateInfo? {
        let repoURL = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: repoURL) else { return nil }

        let session = URLSession(configuration: .ephemeral)
        session.configuration.timeoutIntervalForRequest = 10

        do {
            let (data, _) = try await session.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                let latest = tag.replacingOccurrences(of: "v", with: "")
                if latest.compare(current, options: .numeric) == .orderedDescending {
                    // 查找 DMG 下载链接
                    var downloadURL: URL? = nil
                    let repoBase = "https://github.com/\(repoOwner)/\(repoName)/releases/download/\(tag)"
                    let dmgURL = URL(string: "\(repoBase)/HearthstoneTracker.dmg")
                    
                    // 检查 DMG 是否存在
                    if let dmg = dmgURL {
                        var headRequest = URLRequest(url: dmg)
                        headRequest.httpMethod = "HEAD"
                        if let (_, response) = try? await session.data(for: headRequest),
                           let httpResp = response as? HTTPURLResponse,
                           httpResp.statusCode == 200 {
                            downloadURL = dmg
                        }
                    }
                    
                    // 保底：打开 Releases 页面
                    let fallbackURL = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest")!
                    
                    return UpdateInfo(
                        latestVersion: latest,
                        downloadURL: downloadURL ?? fallbackURL,
                        releaseNotes: json["body"] as? String
                    )
                }
            }
        } catch {
            print("[VersionChecker] 更新检查失败: \(error)")
        }
        return nil
    }
    
    /// 打开下载页面
    static func openDownloadPage() {
        if let url = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }
}