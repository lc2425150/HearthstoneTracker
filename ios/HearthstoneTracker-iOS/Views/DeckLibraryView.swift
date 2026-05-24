import SwiftUI
import SwiftData

// MARK: - 卡组库

struct DeckLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var cardService: CardDataService
    @Query(sort: \SavedDeck.updatedAt, order: .reverse) private var decks: [SavedDeck]

    @State private var showImport = false
    @State private var showCreate = false
    @State private var searchText = ""

    var body: some View {
        Group {
            if decks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredDecks) { deck in
                        NavigationLink(destination: DeckDetailView(deck: deck)) {
                            DeckRowView(deck: deck)
                        }
                    }
                    .onDelete(perform: deleteDecks)
                }
                .searchable(text: $searchText, prompt: "搜索卡组...")
            }
        }
        .navigationTitle("卡组库")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showImport = true }) {
                        Label("导入卡组码", systemImage: "doc.text")
                    }
                    Button(action: { showCreate = true }) {
                        Label("新建空卡组", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showImport) {
            DeckCodeImportView()
        }
        .sheet(isPresented: $showCreate) {
            CreateDeckView()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            label: {
                Label("暂无卡组", systemImage: "rectangle.stack")
            },
            description: {
                Text("导入卡组码或手动创建卡组开始使用")
            },
            actions: {
                Button("导入卡组码") { showImport = true }
                    .buttonStyle(.borderedProminent)
                Button("新建空卡组") { showCreate = true }
                    .buttonStyle(.bordered)
            }
        )
    }

    private var filteredDecks: [SavedDeck] {
        if searchText.isEmpty { return decks }
        return decks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func deleteDecks(_ indexSet: IndexSet) {
        for index in indexSet {
            let deck = decks[index]
            modelContext.delete(deck)
        }
        try? modelContext.save()
    }
}

// MARK: - 卡组行

struct DeckRowView: View {
    let deck: SavedDeck

    var body: some View {
        HStack(spacing: 12) {
            // 职业图标
            ZStack {
                Circle()
                    .fill(classColor)
                    .frame(width: 40, height: 40)
                Image(systemName: classIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(deck.name)
                    .font(.headline)
                Text("\(deck.cardDbfIds.count) 张卡牌 · \(className)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(deck.updatedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
}

// MARK: - 导入卡组码

struct DeckCodeImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var cardService: CardDataService

    @State private var deckCode = ""
    @State private var deckName = ""
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var parsedCards: [Card] = []
    @State private var parsedClass: String = ""
    @State private var parsedSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("卡组码") {
                    TextEditor(text: $deckCode)
                        .font(.body.monospaced())
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                if parsedSuccess {
                    Section("卡组信息") {
                        TextField("卡组名称", text: $deckName)
                        Text("职业: \(className)")
                            .foregroundColor(.secondary)
                        Text("卡牌数量: \(parsedCards.count) 张")
                            .foregroundColor(.secondary)
                    }

                    Section("卡牌列表") {
                        ForEach(groupCards(parsedCards).sorted(by: { $0.key.cost < $1.key.cost }),
                                id: \.key.id) { card, count in
                            HStack {
                                Text("\(card.cost)⚡")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text(card.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("×\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("导入卡组码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveDeck()
                    }
                    .disabled(!parsedSuccess || deckName.isEmpty)
                }
            }
            .onChange(of: deckCode) { _, _ in
                parseCode()
            }
        }
    }

    private var className: String {
        HearthstoneClass(rawValue: parsedClass)?.displayName ?? parsedClass
    }

    private func parseCode() {
        guard !deckCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            parsedSuccess = false
            parsedCards = []
            errorMessage = nil
            return
        }

        isImporting = true
        errorMessage = nil

        do {
            let result = try DeckCodeParser.parse(deckCode)
            let cards = cardService.cards(by: result.cardDbfIds)

            guard !cards.isEmpty else {
                errorMessage = "未找到对应卡牌数据，请先更新卡牌数据库"
                parsedSuccess = false
                return
            }

            // 验证职业
            if result.heroClass != "NEUTRAL" {
                parsedClass = result.heroClass
            } else if let firstNonNeutral = cards.first(where: { $0.cardClass != "NEUTRAL" }) {
                parsedClass = firstNonNeutral.cardClass
            }

            parsedCards = cards
            parsedSuccess = true

            // 自动生成名称
            if deckName.isEmpty {
                let cls = HearthstoneClass(rawValue: parsedClass)?.displayName ?? parsedClass
                deckName = "\(cls) 卡组"
            }
        } catch {
            errorMessage = error.localizedDescription
            parsedSuccess = false
            parsedCards = []
        }

        isImporting = false
    }

    private func groupCards(_ cards: [Card]) -> [(key: Card, value: Int)] {
        var grouped: [Int: (card: Card, count: Int)] = [:]
        for card in cards {
            var entry = grouped[card.dbfId] ?? (card: card, count: 0)
            entry.count += 1
            grouped[card.dbfId] = entry
        }
        return grouped.values.map { (key: $0.card, value: $0.count) }
    }

    private func saveDeck() {
        guard parsedSuccess else { return }

        let deck = SavedDeck(
            name: deckName,
            deckCode: deckCode.trimmingCharacters(in: .whitespacesAndNewlines),
            playerClass: parsedClass,
            cardDbfIds: parsedCards.map { $0.dbfId }
        )
        modelContext.insert(deck)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 创建卡组

struct CreateDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var deckName = ""
    @State private var selectedClass = "MAGE"

    private let classes = HearthstoneClass.allCases.filter { $0 != .neutral }

    var body: some View {
        NavigationStack {
            Form {
                TextField("卡组名称", text: $deckName)

                Picker("职业", selection: $selectedClass) {
                    ForEach(classes, id: \.rawValue) { cls in
                        Text(cls.displayName).tag(cls.rawValue)
                    }
                }
            }
            .navigationTitle("新建卡组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        let deck = SavedDeck(
                            name: deckName.isEmpty ? "新卡组" : deckName,
                            deckCode: "",
                            playerClass: selectedClass,
                            cardDbfIds: []
                        )
                        modelContext.insert(deck)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(deckName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
