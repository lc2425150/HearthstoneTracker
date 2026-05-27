import Foundation
import AppKit

/// 卡牌图片加载器：内存缓存 + 磁盘缓存，从 HearthstoneJSON CDN 获取卡图
actor CardImageLoader {
    static let shared = CardImageLoader()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let cacheDir: URL
    private let baseURL = "https://art.hearthstonejson.com/v1/render/latest/zhCN/256x"
    private var pendingTasks: [String: Task<NSImage?, Never>] = [:]

    private init() {
        memoryCache.countLimit = 200

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("HearthstoneTracker/CardImages")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// 异步加载卡图，失败或卡图不可用时返回 nil
    func image(for cardId: String) async -> NSImage? {
        guard !cardId.isEmpty else { return nil }

        // 内存缓存命中
        if let cached = memoryCache.object(forKey: cardId as NSString) {
            return cached
        }

        // 合并同 cardId 的并发请求
        if let existing = pendingTasks[cardId] {
            return await existing.value
        }

        let task = Task<NSImage?, Never> { [weak self] in
            guard let self else { return nil }
            // 磁盘缓存（actor 上下文内，可直接调用 actor 方法）
            let fileURL = await self.diskCacheURL(for: cardId)
            if FileManager.default.fileExists(atPath: fileURL.path),
               let diskImage = NSImage(contentsOf: fileURL) {
                await self.cacheMemory(image: diskImage, for: cardId)
                return diskImage
            }

            // 网络下载
            guard let url = URL(string: "\(self.baseURL)/\(cardId).png") else {
                return nil
            }

            let req = URLRequest(url: url, timeoutInterval: 8)
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                if let image = NSImage(data: data) {
                    try? data.write(to: fileURL, options: .atomic)
                    await self.cacheMemory(image: image, for: cardId)
                    return image
                }
            } catch {
                // 静默失败 —— 卡图属于辅助信息，不影响核心功能
            }
            return nil
        }

        pendingTasks[cardId] = task
        let result = await task.value
        pendingTasks[cardId] = nil
        return result
    }

    // MARK: - Private

    /// 缓存到内存
    private func cacheMemory(image: NSImage, for cardId: String) {
        memoryCache.setObject(image, forKey: cardId as NSString)
    }

    /// 磁盘缓存路径
    private func diskCacheURL(for cardId: String) -> URL {
        cacheDir.appendingPathComponent("\(cardId).png")
    }

    /// 清除所有缓存文件
    func clearDiskCache() throws {
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            try FileManager.default.removeItem(at: cacheDir)
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        memoryCache.removeAllObjects()
    }
}
