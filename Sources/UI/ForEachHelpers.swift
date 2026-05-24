import SwiftUI

// MARK: - ForEach Workaround - 使用 Group + 手动生成视图避免 Swift 6.3 API 变更

struct DiscoveredCardList: View {
    let cards: [DiscoveredCard]
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(zip(cards.indices, cards)), id: \.0) { _, discovered in
                HStack {
                    CardMiniRow(card: discovered.card)
                    Spacer()
                    Text(discovered.sourceLabel)
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.7))
                }
            }
        }
    }
}

struct CardListSection: View {
    let cards: [Card]
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(zip(cards.indices, cards)), id: \.0) { _, card in
                CardMiniRow(card: card)
            }
        }
    }
}

struct CardMiniRow: View {
    let card: Card
    var count: Int = 1
    
    var body: some View {
        HStack(spacing: 8) {
            Text("(\(card.cost))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(card.name)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            if count > 1 {
                Text("×\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.3))
        )
    }
}
