import Foundation
import AppKit

/// LRU 卡牌图片缓存（内存 + 磁盘 + 网络三级）
final class CardImageCache {
    static let shared = CardImageCache()
    
    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    
    private var diskCacheDir: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("HearthstoneTracker/CardImages")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024
    }
    
    /// 获取卡牌图片（内存 → 磁盘 → 网络三级缓存）
    func getImage(cardId: String, completion: @escaping (NSImage?) -> Void) {
        // 1. 内存缓存
        if let image = memoryCache.object(forKey: cardId as NSString) {
            completion(image)
            return
        }
        
        // 2. 磁盘缓存
        let diskPath = diskCacheDir.appendingPathComponent("\(cardId).png")
        if let image = NSImage(contentsOf: diskPath) {
            memoryCache.setObject(image, forKey: cardId as NSString)
            completion(image)
            return
        }
        
        // 3. 网络下载
        downloadImage(cardId: cardId) { [weak self] image in
            guard let self = self, let image = image else {
                completion(nil)
                return
            }
            self.memoryCache.setObject(image, forKey: cardId as NSString)
            self.saveToDisk(cardId: cardId, image: image)
            completion(image)
        }
    }
    
    /// 预加载一组卡牌
    func preload(cardIds: [String]) {
        for id in cardIds.prefix(20) { // 一次最多预加载20张
            getImage(cardId: id) { _ in }
        }
    }
    
    /// 清空所有缓存
    func clear() {
        memoryCache.removeAllObjects()
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
    
    // MARK: - Private
    
    private func downloadImage(cardId: String, completion: @escaping (NSImage?) -> Void) {
        let urlStr = "https://art.hearthstonejson.com/v1/render/latest/zhCN/256x/\(cardId).png"
        guard let url = URL(string: urlStr) else { completion(nil); return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil, let image = NSImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }
    
    private func saveToDisk(cardId: String, image: NSImage) {
        let diskPath = diskCacheDir.appendingPathComponent("\(cardId).png")
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: diskPath)
    }
}
