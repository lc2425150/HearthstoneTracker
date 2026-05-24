import SwiftUI
import SwiftData

// MARK: - 卡组详情

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var cardService: CardDataService
    @EnvironmentObject var trackingService: TrackingService
    let deck: SavedDeck

    @State private var cards: [Card] = []
    @State private var showStartMatch = false
    @State private var opponentClass = "MAGE"
    @State private var coin = false

    var body: some View {
        List {
            // 卡组信息
            Section {
                HStack {
                    ZStack {
                        Circle()
                            .fill(classColor)
                            .frame(width: 50, height: 50)
                        Image(systemName: classIcon)
                            .foregroundColor(.white)
                            .font(.title2)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deck.name)
                            .font(.title2)
                            .bold()
                        Text("\(className) · \(cards.count) 张卡牌")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // 开始对局
            if !cards.isEmpty {
                Section {
                    Button(action: { showStartMatch = true }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("开始对局追踪")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 卡牌列表（按费用分组）
            Section("卡牌列表 (\(cards.count))") {
                ForEach(groupedCards.keys.sorted(), id: \.self) { cost in
                    if let groupCards = groupedCards[cost] {
                        ForEach(groupCards, id: \.dbfId) { card in
                            let count = cards.filter { $0.dbfId == card.dbfId }.count
                            HStack {
                                // 费用
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(costColor(cost))
                                        .frame(width: 28, height: 28)
                                    Text("\(cost)")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(card.name)
                                        .font(.subheadline)
                                    if !card.type.isEmpty && card.type != "MINION" {
                                        Text(card.type)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if count > 1 {
                                    Text("×\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.15))
                                        .cornerRadius(4)
                                }

                                // 稀有度颜色条
                                RarityIndicator(rarity: card.rarity)
                            }
                        }
                    }
                }
            }

            // 卡组操作
            Section {
                Button(role: .destructive) {
                    modelContext.delete(deck)
                    try? modelContext.save()
                } label: {
                    Label("删除卡组", systemImage: "trash")
                }
            }
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadCards()
        }
        .sheet(isPresented: $showStartMatch) {
            startMatchSheet
        }
    }

    // MARK: - 开始对局 Sheet

    private var startMatchSheet: some View {
        NavigationStack {
            Form {
                Section("对手信息") {
                    Picker("对手职业", selection: $opponentClass) {
                        ForEach(HearthstoneClass.allCases.filter { $0 != .neutral }, id: \.rawValue) { cls in
                            Text(cls.displayName).tag(cls.rawValue)
                        }
                    }

                    Toggle("后手 (有硬币)", isOn: $coin)
                }

                Section("卡组信息") {
                    HStack {
                        Text("卡组")
                        Spacer()
                        Text(deck.name)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("卡牌数量")
                        Spacer()
                        Text("\(cards.count) 张")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("开始对战") {
                        startMatch()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("新对局")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showStartMatch = false }
                }
            }
        }
    }

    // MARK: - Private

    private func loadCards() {
        cards = cardService.cards(by: deck.cardDbfIds)
    }

    private func startMatch() {
        trackingService.startMatch(
            deck: deck,
            playerClass: deck.playerClass,
            opponentClass: opponentClass,
            coin: coin,
            cards: cards
        )
        showStartMatch = false
    }

    private var groupedCards: [Int: [Card]] {
        Dictionary(grouping: cards.sorted { $0.cost < $1.cost }) { $0.cost }
    }

    private var classColor: Color {
        switch deck.playerClass {
        case "MAGE": return .blue
        case "WARRIOR": return .red
        case "PRIEST": return .white
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

    private var classIcon: String {
        HearthstoneClass(rawValue: deck.playerClass)?.iconName ?? "questionmark"
    }

    private var className: String {
        HearthstoneClass(rawValue: deck.playerClass)?.displayName ?? deck.playerClass
    }

    private func costColor(_ cost: Int) -> Color {
        switch cost {
        case 0: return .gray
        case 1...3: return .blue
        case 4...6: return .purple
        case 7...9: return .orange
        default: return .red
        }
    }
}

// MARK: - 稀有度指示器

struct RarityIndicator: View {
    let rarity: String

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 3, height: 20)
            .cornerRadius(1.5)
    }

    private var color: Color {
        switch rarity {
        case "FREE": return .gray
        case "COMMON": return .gray
        case "RARE": return .blue
        case "EPIC": return .purple
        case "LEGENDARY": return .orange
        default: return .gray
        }
    }
}
