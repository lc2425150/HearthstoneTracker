import SwiftUI

/// 异步卡牌缩略图组件：加载期间展示占位符，失败时降级为文字首字符
struct CardThumbnail: View {
    let cardId: String
    let cardName: String
    let cost: Int?
    let size: CGFloat

    @State private var image: NSImage?
    @State private var loadingFailed = false

    var body: some View {
        ZStack {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size * 1.39)
                    .clipped()
            } else if loadingFailed {
                fallbackView
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(ProgressView().scaleEffect(0.5))
            }
        }
        .frame(width: size, height: size * 1.39)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onAppear {
            guard !loadingFailed, image == nil else { return }
            Task {
                if let img = await CardImageLoader.shared.image(for: cardId) {
                    await MainActor.run { image = img }
                } else {
                    await MainActor.run { loadingFailed = true }
                }
            }
        }
    }

    private var fallbackView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .overlay(
                VStack(spacing: 2) {
                    if let cost = cost {
                        Text("\(cost)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    Text(String(cardName.prefix(1)))
                        .font(.system(size: size * 0.35))
                        .foregroundColor(.gray)
                }
            )
    }
}

/// 迷你小图版
struct CardThumbnailMini: View {
    let cardId: String
    let cardName: String

    var body: some View {
        CardThumbnail(cardId: cardId, cardName: cardName, cost: nil, size: 28)
    }
}

/// 标准列表版
struct CardThumbnailStandard: View {
    let cardId: String
    let cardName: String
    let cost: Int?

    var body: some View {
        CardThumbnail(cardId: cardId, cardName: cardName, cost: cost, size: 44)
    }
}