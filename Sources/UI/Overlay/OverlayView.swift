import SwiftUI
import AppKit

/// 悬浮窗视图：半透明悬浮层，展示牌库状态与对手信息
struct OverlayView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var opacity: Double = 0.85
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(opacity))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                // 标题栏（含侧边切换按钮）
                headerBar

                // 标签切换栏
                tabBar
                    .padding(.horizontal, 8)

                Divider()
                    .background(Color.white.opacity(0.3))

                // 内容区
                if let deck = core.playerDeck {
                    Group {
                        switch selectedTab {
                        case 0:
                            PlayerDeckSection(deck: deck)
                        case 1:
                            OpponentSection(tracker: core.opponentTracker)
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 10)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                        Text("粘贴卡组码后自动导入")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                // 底部状态条
                bottomStatusBar
            }
        }
        .frame(width: 320, height: 420)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // 侧边切换按钮
            Button(action: { core.switchOverlaySide() }) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10))
            }
            .help("切换左右侧")

            Text("炉石记牌器")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            HStack(spacing: 4) {
                Button(action: { opacity = max(0.3, opacity - 0.1) }) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 10))
                }
                .help("降低透明度")

                Button(action: { opacity = min(1.0, opacity + 0.1) }) {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                }
                .help("增加透明度")

                Button(action: { core.toggleOverlay() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .help("关闭悬浮窗")
            }
            .foregroundColor(.white.opacity(0.6))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(["我方牌库", "对手信息"], id: \.self) { title in
                let idx = (title == "我方牌库" ? 0 : 1)
                Button(title) { selectedTab = idx }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        selectedTab == idx
                            ? Color.white.opacity(0.15)
                            : Color.clear
                    )
                    .cornerRadius(4)
            }
            .foregroundColor(.white.opacity(0.8))
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Status

    private var bottomStatusBar: some View {
        HStack {
            Circle()
                .fill(core.isTracking ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(core.isTracking ? "追踪中" : "已暂停")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))

            if core.isTracking {
                Spacer()
                Text("对局 \(core.opponentTracker.totalPlayedCount > 0 ? "进行中" : "等待")")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
}

// MARK: - 我方牌库

struct PlayerDeckSection: View {
    let deck: TrackedDeck
    @EnvironmentObject var core: CardTrackerCore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("原卡组")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(deck.remainingOriginalCount) 张剩余")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // 已抽到（手牌中）
                    if !deck.handOriginal.isEmpty {
                        Text("手牌")
                            .font(.caption2)
                            .foregroundColor(.yellow.opacity(0.7))
                        ForEach(deck.handOriginal.sorted(by: { $0.cost < $1.cost })) { card in
                            OverlayCardRow(card: card, isInHand: true)
                        }
                    }

                    // 牌库剩余
                    if !deck.remainingOriginal.isEmpty {
                        Text("牌库")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        ForEach(deck.remainingOriginal.sorted(by: { $0.cost < $1.cost })) { card in
                            OverlayCardRow(card: card, isInHand: false)
                        }
                    }

                    // 已打出
                    if !deck.playedOriginal.isEmpty {
                        Text("已打出")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.5))
                        ForEach(deck.playedOriginal.sorted(by: { $0.cost < $1.cost })) { card in
                            OverlayCardRow(card: card, isInHand: false)
                                .opacity(0.5)
                        }
                    }

                    // 发现牌
                    if !deck.discoveredCards.isEmpty {
                        Text("发现牌")
                            .font(.caption2)
                            .foregroundColor(.blue.opacity(0.7))
                        let discCards = deck.discoveredCards
                        ForEach(Array(discCards.indices), id: \.self) { i in
                            let discovered = discCards[i]
                            HStack {
                                OverlayCardRow(card: discovered.card, isInHand: false)
                                Spacer()
                                Text(discovered.sourceLabel)
                                    .font(.system(size: 8))
                                    .foregroundColor(.blue.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 悬浮窗单张卡牌行

struct OverlayCardRow: View {
    let card: Card
    let isInHand: Bool
    @EnvironmentObject var core: CardTrackerCore

    var body: some View {
        HStack(spacing: 4) {
            // 稀有度颜色条
            RoundedRectangle(cornerRadius: 1)
                .fill(raritySwiftUIColor(card.rarityColor))
                .frame(width: 3, height: core.cardDisplaySize.rowHeight - 4)
            
            // 费用
            Text("\(card.cost)")
                .font(.system(size: core.cardDisplaySize.fontSize, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: core.cardDisplaySize.rowHeight - 4, height: core.cardDisplaySize.rowHeight - 4)
                .background(raritySwiftUIColor(card.rarityColor).opacity(0.8))
                .cornerRadius(3)
            
            // 名称
            Text(card.name)
                .font(.system(size: core.cardDisplaySize.fontSize))
                .foregroundColor(isInHand ? .yellow.opacity(0.9) : raritySwiftUIColor(card.rarityColor).opacity(0.9))
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
        .frame(height: core.cardDisplaySize.rowHeight + 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(raritySwiftUIColor(card.rarityColor).opacity(0.06))
        )
    }
}

// MARK: - 对手信息

struct OpponentSection: View {
    @ObservedObject var tracker: OpponentCardTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("对手已使用")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(tracker.totalPlayedCount) 张")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Text("剩余 \(max(30 - tracker.totalPlayedCount, 0))")
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.6))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let sortedOppCards = tracker.playedCards.sorted(by: { $0.cost < $1.cost })
                    ForEach(Array(sortedOppCards.indices), id: \.self) { i in
                        let record = sortedOppCards[i]
                        OverlayCardRow(card: record.card, isInHand: false)
                    }

                    if tracker.playedCards.isEmpty {
                        Text("暂无对手信息")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
    }
}

// MARK: - 对手信息预览（用于主窗口）

struct OpponentInfoPreview: View {
    @ObservedObject var tracker: OpponentCardTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("对手已使用 \(tracker.totalPlayedCount) 张")
                .font(.caption)
                .foregroundColor(.secondary)

            if !tracker.playedCards.isEmpty {
                HStack(spacing: -4) {
                    let recentCards = Array(tracker.playedCards.prefix(10))
                    ForEach(0..<recentCards.count, id: \.self) { idx in
                        let card = recentCards[idx].card
                        CardThumbnailMini(cardId: card.cardId, cardName: card.name)
                    }
                    if tracker.playedCards.count > 10 {
                        Text("+\(tracker.playedCards.count - 10)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("等待对手出牌...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
