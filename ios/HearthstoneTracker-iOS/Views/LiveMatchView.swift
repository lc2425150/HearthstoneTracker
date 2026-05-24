import SwiftUI

// MARK: - 实时对战追踪

struct LiveMatchView: View {
    @EnvironmentObject var trackingService: TrackingService

    var body: some View {
        Group {
            if trackingService.isTracking {
                matchView
            } else {
                idleView
            }
        }
        .navigationTitle("对战追踪")
    }

    // MARK: - 空闲状态

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("未开始对战")
                .font(.title2)
                .bold()

            Text("从卡组库选择一个卡组开始追踪")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 追踪视图

    private var matchView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 对战信息头
                matchHeader

                // 手牌
                handSection

                // 牌库剩余
                deckSection

                // 已打出
                playedSection

                // 发现牌
                discoveredSection

                // 操作按钮
                actionButtons

                // 结束对局
                endMatchButton
            }
            .padding()
        }
    }

    // MARK: - 对战信息

    private var matchHeader: some View {
        VStack(spacing: 8) {
            HStack {
                playerClassIcon(trackingService.matchState.playerClass)
                Text("VS")
                    .font(.headline)
                    .foregroundColor(.secondary)
                opponentClassIcon(trackingService.matchState.opponentClass)
            }

            HStack(spacing: 20) {
                Label("第 \(trackingService.matchState.turnNumber) 回合", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if trackingService.matchState.coin {
                    Label("后手", systemImage: "circlebadge")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }

                Text(trackingService.matchState.startTime, style: .timer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 手牌

    private var handSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("手牌", systemImage: "hand.raised")
                    .font(.headline)
                Spacer()
                Text("\(trackingService.matchState.handCards.count) 张")
                    .foregroundColor(.secondary)
            }

            if trackingService.matchState.handCards.isEmpty {
                Text("空手牌")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(trackingService.matchState.handCards, id: \.dbfId) { card in
                        HandCardView(card: card)
                            .onTapGesture {
                                trackingService.playCard(card)
                            }
                            .contextMenu {
                                Button("打出") { trackingService.playCard(card) }
                                Button("弃掉", role: .destructive) { trackingService.discardCard(card) }
                                Button("消灭", role: .destructive) { trackingService.destroyCard(card) }
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 牌库

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("牌库", systemImage: "rectangle.stack")
                    .font(.headline)
                Spacer()
                Text("剩余 \(trackingService.matchState.remainingDeck.count) 张")
                    .foregroundColor(.secondary)
            }

            // 费用分布
            let costDistribution = Dictionary(
                grouping: trackingService.matchState.remainingDeck
            ) { $0.cost }
                .mapValues { $0.count }
                .sorted { $0.key < $1.key }

            if !costDistribution.isEmpty {
                HStack(spacing: 6) {
                    ForEach(costDistribution, id: \.key) { cost, count in
                        VStack(spacing: 2) {
                            Text("\(count)")
                                .font(.caption2)
                                .bold()
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 18, height: 40)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(costColor(cost))
                                    .frame(width: 18, height: max(4, CGFloat(count) * 6))
                            }
                            Text("\(cost)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 抽牌按钮
            if !trackingService.matchState.remainingDeck.isEmpty {
                Button(action: { trackingService.drawCard() }) {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("抽牌")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 已打出

    private var playedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("已打出", systemImage: "arrow.up.forward")
                    .font(.headline)
                Spacer()
                Text("\(trackingService.matchState.playedCards.count) 张")
                    .foregroundColor(.secondary)
            }

            if trackingService.matchState.playedCards.isEmpty {
                Text("暂无")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(trackingService.matchState.playedCards, id: \.dbfId) { card in
                            MiniCardView(card: card)
                        }
                    }
                }
            }

            // 已消灭
            if !trackingService.matchState.destroyedCards.isEmpty {
                HStack {
                    Label("已消灭", systemImage: "flame")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                    Text("\(trackingService.matchState.destroyedCards.count) 张")
                        .foregroundColor(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(trackingService.matchState.destroyedCards, id: \.dbfId) { card in
                            MiniCardView(card: card)
                                .opacity(0.6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 发现牌

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("发现/衍生", systemImage: "sparkle.magnifyingglass")
                    .font(.headline)
                Spacer()
                Text("\(trackingService.matchState.discoveredCards.count) 张")
                    .foregroundColor(.secondary)
            }

            if trackingService.matchState.discoveredCards.isEmpty {
                Text("暂无")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(trackingService.matchState.discoveredCards, id: \.dbfId) { card in
                            MiniCardView(card: card)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.yellow, lineWidth: 2)
                                )
                        }
                    }
                }
            }

            // 添加发现牌按钮
            Button(action: { showDiscoverPicker = true }) {
                HStack {
                    Image(systemName: "plus.magnifyingglass")
                    Text("添加发现牌")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .sheet(isPresented: $showDiscoverPicker) {
                DiscoverCardPicker()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @State private var showDiscoverPicker = false

    // MARK: - 操作按钮

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { trackingService.nextTurn() }) {
                Label("下一回合", systemImage: "forward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(action: { showDiscoverPicker = true }) {
                Label("发现", systemImage: "sparkle.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 结束对局

    private var endMatchButton: some View {
        VStack(spacing: 8) {
            Button("胜利！") {
                trackingService.endMatch(result: "win")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .font(.headline)

            Button("失败...") {
                trackingService.endMatch(result: "loss")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .font(.headline)
        }
    }

    // MARK: - Helpers

    private func playerClassIcon(_ cls: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(classColor(cls == "" ? "MAGE" : cls))
                    .frame(width: 36, height: 36)
                Image(systemName: HearthstoneClass(rawValue: cls)?.iconName ?? "person")
                    .foregroundColor(.white)
                    .font(.caption)
            }
            Text(HearthstoneClass(rawValue: cls)?.displayName ?? "未知")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func opponentClassIcon(_ cls: String) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(classColor(cls == "" ? "WARRIOR" : cls))
                    .frame(width: 36, height: 36)
                Image(systemName: HearthstoneClass(rawValue: cls)?.iconName ?? "person")
                    .foregroundColor(.white)
                    .font(.caption)
            }
            Text(HearthstoneClass(rawValue: cls)?.displayName ?? "未知")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func classColor(_ cls: String) -> Color {
        switch cls {
        case "MAGE": return .blue
        case "WARRIOR": return .red
        case "PRIEST": return .gray
        case "ROGUE": return .gray
        case "PALADIN": return .yellow
        case "HUNTER": return .green
        case "DRUID": return .orange
        case "WARLOCK": return .purple
        case "SHAMAN": return .cyan
        case "DEMONHUNTER": return .indigo
        case "DEATHKNIGHT": return .mint
        default: return .secondary
        }
    }

    private func costColor(_ cost: Int) -> Color {
        switch cost {
        case 0: return .gray
        case 1...3: return .blue
        case 4...6: return .purple
        default: return .orange
        }
    }
}

// MARK: - 手牌卡牌卡片

struct HandCardView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(costColor)
                    .frame(width: 60, height: 26)
                Text("\(card.cost)")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
            }

            Text(card.name)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60, height: 28)

            RarityIndicator(rarity: card.rarity)
        }
        .frame(width: 64)
        .padding(4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2)
    }

    private var costColor: Color {
        switch card.cost {
        case 0: return .gray
        case 1...3: return .blue
        case 4...6: return .purple
        default: return .orange
        }
    }
}

// MARK: - 迷你卡牌

struct MiniCardView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(costColor)
                    .frame(width: 32, height: 18)
                Text("\(card.cost)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(card.name)
                .font(.system(size: 8))
                .lineLimit(1)
                .frame(width: 40)
        }
        .frame(width: 44)
        .padding(4)
        .background(Color(.systemBackground))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.1), radius: 1)
    }

    private var costColor: Color {
        switch card.cost {
        case 0: return .gray
        case 1...3: return .blue
        case 4...6: return .purple
        default: return .orange
        }
    }
}

// MARK: - 发现牌选择器

struct DiscoverCardPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cardService: CardDataService
    @EnvironmentObject var trackingService: TrackingService
    @State private var searchText = ""
    @State private var searchResults: [Card] = []

    var body: some View {
        NavigationStack {
            List {
                if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(searchResults, id: \.dbfId) { card in
                        Button(action: {
                            trackingService.discoverCard(card)
                            dismiss()
                        }) {
                            HStack {
                                Text("\(card.cost)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(costColor(card.cost))
                                    .cornerRadius(4)

                                VStack(alignment: .leading) {
                                    Text(card.name)
                                        .foregroundColor(.primary)
                                    if !card.type.isEmpty && card.type != "MINION" {
                                        Text(card.type)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索卡牌名称...")
            .navigationTitle("选择发现的卡牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onChange(of: searchText) { _, newValue in
                guard !newValue.isEmpty else {
                    searchResults = []
                    return
                }
                searchResults = cardService.searchCards(query: newValue)
            }
        }
    }

    private func costColor(_ cost: Int) -> Color {
        switch cost {
        case 0: return .gray
        case 1...3: return .blue
        case 4...6: return .purple
        default: return .orange
        }
    }
}
