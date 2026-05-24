import SwiftUI

// MARK: - ForEach Workaround Views

struct DiscoveredCardList: View {
    let cards: [DiscoveredCard]
    @EnvironmentObject var core: CardTrackerCore
    
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
    @EnvironmentObject var core: CardTrackerCore
    
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
    @EnvironmentObject var core: CardTrackerCore
    
    var body: some View {
        HStack(spacing: 6) {
            // 费用
            Text("\(card.cost)")
                .font(.system(size: core.cardDisplaySize.fontSize, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: core.cardDisplaySize.rowHeight - 4, height: core.cardDisplaySize.rowHeight - 4)
                .background(raritySwiftUIColor(card.rarityColor))
                .cornerRadius(4)
            
            // 卡牌名称
            Text(card.name)
                .font(.system(size: core.cardDisplaySize.fontSize))
                .foregroundColor(raritySwiftUIColor(card.rarityColor))
                .lineLimit(1)
            
            Spacer()
            
            if count > 1 {
                Text("×\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .frame(height: core.cardDisplaySize.rowHeight + 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(raritySwiftUIColor(card.rarityColor).opacity(0.08))
        )
    }
}

// MARK: - 稀有度颜色

func raritySwiftUIColor(_ name: String) -> Color {
    switch name {
    case "gray":   return Color(nsColor: .systemGray)
    case "blue":   return Color.blue
    case "purple": return Color.purple
    case "orange": return Color.orange
    default:       return Color(nsColor: .systemGray)
    }
}
