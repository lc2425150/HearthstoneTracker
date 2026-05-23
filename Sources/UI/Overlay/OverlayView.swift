import SwiftUI
import AppKit

/// 悬浮窗视图：半透明悬浮层，展示牌库状态与对手信息
struct OverlayView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var opacity: Double = 0.7
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(opacity))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                // 标题栏
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
        .frame(width: 320, height: 480)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
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

                Button(action: { opacity = min(1.0, opacity + 0.1) }) {
                    Image(systemName: "eye")
                        .font(.system(size: 10))
                }

                Button(action: { core.toggleOverlay() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
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
    @EnvironmentObject var core: CardTrackerCore
    let deck: TrackedDeck

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("原卡组")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(deck.remainingOriginalCount) 张剩余")
                    .font(.caption2)
                    .foregroundColor(.green.opacity(0.8))
            }

            ProgressView(
                value: Double(deck.playedOriginalCount + deck.handOriginalCount),
                total: Double(deck.totalOriginalCount)
            )
            .progressViewStyle(.linear)
            .tint(.green)

            HStack {
                statItem(label: "手牌", value: "\(deck.handOriginalCount)", color: .yellow)
                Spacer()
                statItem(label: "已打", value: "\(deck.playedOriginalCount)", color: .white)
                Spacer()
                statItem(label: "发现", value: "\(deck.discoveredCards.filter { !$0.isPlayed }.count)", color: .blue)
            }

            // 剩余卡牌速览（按费用排序，带缩略图）
            if !deck.remainingOriginal.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("剩余牌 (\(deck.remainingOriginalCount))")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(deck.remainingOriginal.sorted(by: { $0.cost < $1.cost })) { card in
                                VStack(spacing: 2) {
                                    CardThumbnailMini(
                                        cardId: String(card.id),
                                        cardName: card.name
                                    )
                                    Text("(\(card.cost))")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
            }

            // 最近发现的卡牌（带缩略图）
            if !deck.discoveredCards.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("发现/随机牌")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.8))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(deck.discoveredCards.suffix(8)) { dCard in
                                VStack(spacing: 2) {
                                    CardThumbnailMini(
                                        cardId: String(dCard.card.id),
                                        cardName: dCard.card.name
                                    )
                                    .opacity(dCard.isPlayed ? 0.4 : 1.0)
                                    Text(dCard.isPlayed ? "已打" : "(\(dCard.card.cost))")
                                        .font(.system(size: 8))
                                        .foregroundColor(dCard.isPlayed ? .gray : .blue)
                                }
                            }
                        }
                    }
                }
            }

            // OCR 扫描按钮
            if core.isTracking {
                Divider()
                    .background(Color.white.opacity(0.2))
                HStack {
                    Button("OCR扫描") {
                        core.triggerOCRScan()
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(.white)

                    Spacer()

                    Button("对手追踪") {
                        core.startOpponentTracking()
                    }
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - 对手信息

struct OpponentSection: View {
    @ObservedObject var tracker: OpponentCardTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 卡组推测
            if let archetype = tracker.inferredArchetype {
                HStack {
                    Text("推测卡组")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(archetype)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(3)
                }
            }

            // 统计
            HStack {
                statItem(label: "已打出", value: "\(tracker.totalPlayedCount)")
                Spacer()
                statItem(label: "手牌", value: "\(tracker.handSize)")
                Spacer()
                statItem(label: "法力", value: "\(tracker.manaUsed)")

                if tracker.deckRemaining > 0 {
                    Spacer()
                    statItem(label: "牌库", value: "\(tracker.deckRemaining)")
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // 已打出卡牌列表（带缩略图）
            if !tracker.playedCards.isEmpty {
                Text("已打出卡牌")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(tracker.playedCards.reversed().prefix(20)) { record in
                            HStack(spacing: 6) {
                                CardThumbnailMini(
                                    cardId: String(record.card.id),
                                    cardName: record.card.name
                                )
                                Text(record.card.name)
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(record.cost)费")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                                Text("T\(record.turn)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(2)
                        }
                    }
                }
                .frame(maxHeight: 200)
            } else {
                Text("等待对手出牌…")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}