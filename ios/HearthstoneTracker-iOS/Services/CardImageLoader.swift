import SwiftUI

// MARK: - Card Image Loader

@MainActor
final class CardImageLoader {
    static let shared = CardImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let fileManager = FileManager.default

    private var diskCacheURL: URL {
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachesDir.appendingPathComponent("CardImages", isDirectory: true)
    }

    init() {
        cache.countLimit = 200
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)

        // 创建磁盘缓存目录
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    /// 异步加载卡牌图片
    func loadImage(cardId: String) async -> UIImage? {
        // 1. 检查内存缓存
        let key = cardId as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // 2. 检查磁盘缓存
        let fileURL = diskCacheURL.appendingPathComponent("\(cardId).png")
        if let diskImage = UIImage(contentsOfFile: fileURL.path) {
            cache.setObject(diskImage, forKey: key)
            return diskImage
        }

        // 3. 网络下载
        guard let url = URL(string: "\(Constants.cardImageURL)\(cardId).png") else {
            return nil
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { return nil }

            // 写入缓存
            cache.setObject(image, forKey: key)
            try? data.write(to: fileURL)

            return image
        } catch {
            return nil
        }
    }

    /// 清除磁盘缓存
    func clearDiskCache() throws {
        let contents = try fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil)
        for url in contents {
            try fileManager.removeItem(at: url)
        }
    }

    /// 清除内存缓存
    func clearMemoryCache() {
        cache.removeAllObjects()
    }

    /// 获取缓存大小
    func cacheSize() -> UInt64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + UInt64(size)
        }
    }
}

// MARK: - SwiftUI AsyncImage Wrapper

struct CardImage: View {
    let cardId: String
    let size: CGSize?

    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if failed {
                placeholder
            } else {
                placeholder
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
            }
        }
        .frame(width: size?.width, height: size?.height)
        .task {
            await load()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
    }

    private func load() async {
        isLoading = true
        image = await CardImageLoader.shared.loadImage(cardId: cardId)
        isLoading = false
        failed = image == nil
    }
}
