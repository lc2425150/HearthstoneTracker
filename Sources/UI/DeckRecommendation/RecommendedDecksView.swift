import SwiftUI
import AppKit

// MARK: - 推荐卡组主视图

struct RecommendedDecksView: View {
    @StateObject private var service = DeckRecommendationService.shared
    @EnvironmentObject var core: CardTrackerCore
    @State private var selectedClass: String? = nil
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var showCopyToast = false
    @State private var copiedDeckName = ""
    
    private let classIcons: [String: String] = [
        "DEATHKNIGHT": "skull",
        "DEMONHUNTER": "flame",
        "DRUID": "leaf",
        "HUNTER": "bow",
        "MAGE": "sparkles",
        "PALADIN": "shield",
        "PRIEST": "cross.case",
        "ROGUE": "syringe",
        "SHAMAN": "bolt",
        "WARLOCK": "circle.hexagongrid",
        "WARRIOR": "figure.fencing",
    ]
    
    private let classColors: [String: Color] = [
        "DEATHKNIGHT": Color(red: 0.2, green: 0.5, blue: 0.4),
        "DEMONHUNTER": Color(red: 0.5, green: 0.3, blue: 0.8),
        "DRUID": Color(red: 1.0, green: 0.5, blue: 0.1),
        "HUNTER": Color(red: 0.4, green: 0.8, blue: 0.3),
        "MAGE": Color(red: 0.2, green: 0.6, blue: 1.0),
        "PALADIN": Color(red: 1.0, green: 0.7, blue: 0.2),
        "PRIEST": Color(red: 0.8, green: 0.8, blue: 0.8),
        "ROGUE": Color(red: 0.6, green: 0.6, blue: 0.2),
        "SHAMAN": Color(red: 0.1, green: 0.4, blue: 0.9),
        "WARLOCK": Color(red: 0.5, green: 0.3, blue: 0.6),
        "WARRIOR": Color(red: 0.7, green: 0.3, blue: 0.2),
    ]
    
    private let classNameCN: [String: String] = [
        "DEATHKNIGHT": "死亡骑士",
        "DEMONHUNTER": "恶魔猎手",
        "DRUID": "德鲁伊",
        "HUNTER": "猎人",
        "MAGE": "法师",
        "PALADIN": "圣骑士",
        "PRIEST": "牧师",
        "ROGUE": "潜行者",
        "SHAMAN": "萨满",
        "WARLOCK": "术士",
        "WARRIOR": "战士",
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbarView
            
            if service.isLoading {
                Spacer()
                loadingView
                Spacer()
            } else if service.recommendedDecks.isEmpty {
                Spacer()
                emptyView
                Spacer()
            } else {
                // 职业筛选器
                classFilterView
                
                // 卡组列表
                deckListView
            }
        }
        .overlay(alignment: .bottom) {
            copyToastOverlay
        }
        .task {
            // 启动时尝试刷新
            if service.recommendedDecks.isEmpty || BuiltinDeckDatabase.standardDecks.containsSame(as: service.recommendedDecks) {
                await service.refresh()
            }
        }
    }
    
    // MARK: - 工具栏
    
    private var toolbarView: some View {
        HStack {
            Label("推荐卡组", systemImage: "star.fill")
                .font(.headline)
                .foregroundColor(.orange)
            
            Spacer()
            
            if let error = service.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .help(error)
            }
            
            if let lastRefresh = service.lastRefreshDate {
                Text(formatRefreshDate(lastRefresh))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { Task { await service.refresh() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(service.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
    
    // MARK: - Loading
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("正在获取热门卡组数据...")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("首次加载可能需要几秒钟")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("暂无推荐卡组")
                .font(.headline)
                .foregroundColor(.secondary)
            Button("加载卡组数据") {
                Task { await service.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - 职业筛选
    
    private var classFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button("全部") {
                    withAnimation { selectedClass = nil }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(selectedClass == nil ? .blue : nil)
                
                ForEach(service.allClasses, id: \.self) { cls in
                    Button(action: {
                        withAnimation { selectedClass = cls == selectedClass ? nil : cls }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: classIcons[cls] ?? "questionmark")
                                .font(.caption2)
                            Text(classNameCN[cls] ?? cls)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(selectedClass == cls ? classColors[cls] ?? .blue : nil)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - 卡组列表
    
    private var deckListView: some View {
        let filtered = filteredDecks
        let grouped = Dictionary(grouping: filtered, by: { $0.playerClass })
        let sortedClasses = grouped.keys.sorted()
        
        return ScrollView {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedClasses, id: \.self) { cls in
                    if let decks = grouped[cls] {
                        Section {
                            ForEach(decks) { deck in
                                DeckRecommendationRow(
                                    deck: deck,
                                    classColor: classColors[cls] ?? .gray,
                                    classIcon: classIcons[cls] ?? "questionmark",
                                    onCopy: { copyDeck(deck) }
                                )
                                .padding(.horizontal, 8)
                            }
                        } header: {
                            classHeaderView(cls: cls)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    private func classHeaderView(cls: String) -> some View {
        HStack {
            Image(systemName: classIcons[cls] ?? "questionmark")
                .foregroundColor(classColors[cls] ?? .gray)
            Text(classNameCN[cls] ?? cls)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(filteredDecks.filter { $0.playerClass == cls }.count) 套")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }
    
    // MARK: - 过滤
    
    private var filteredDecks: [RecommendedDeck] {
        var decks = service.recommendedDecks
        if let selectedClass = selectedClass {
            decks = decks.filter { $0.playerClass == selectedClass }
        }
        if !searchText.isEmpty {
            decks = decks.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.nameCN.localizedCaseInsensitiveContains(searchText)
            }
        }
        return decks.sorted { $0.winRate > $1.winRate }
    }
    
    // MARK: - Copy Toast
    
    private var copyToastOverlay: some View {
        Group {
            if showCopyToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已复制「\(copiedDeckName)」卡组代码")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showCopyToast = false }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func copyDeck(_ deck: RecommendedDeck) {
        let success = DeckRecommendationService.copyDeckCode(deck.deckCode)
        if success {
            copiedDeckName = deck.displayName
            withAnimation { showCopyToast = true }
            
            // 也设置到核心追踪器
            core.importDeckIfNeeded(from: deck.deckCode)
        }
    }
    
    private func formatRefreshDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        return "\(Int(interval / 86400))天前"
    }
}

// MARK: - 卡组推荐行

struct DeckRecommendationRow: View {
    let deck: RecommendedDeck
    let classColor: Color
    let classIcon: String
    let onCopy: () -> Void
    
    @State private var showDetail = false
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 胜率圆环
            ZStack {
                Circle()
                    .stroke(classColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: CGFloat(min(deck.winRate / 100, 1.0)))
                    .stroke(classColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                Text(deck.displayWinRate)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(classColor)
            }
            
            // 卡组信息
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // 职业标签
                    Label("", systemImage: classIcon)
                        .font(.caption2)
                        .foregroundColor(classColor)
                    
                    // 对局数
                    Label(deck.displayGames, systemImage: "play.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // 尘消耗
                    if deck.cost > 0 {
                        Label("\(deck.cost)", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 复制按钮
            HStack(spacing: 2) {
                Button(action: onCopy) {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
                
                Button(action: { showDetail.toggle() }) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .rotationEffect(.degrees(showDetail ? 180 : 0))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? classColor.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(classColor.opacity(0.15), lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
        .popover(isPresented: $showDetail, arrowEdge: .trailing) {
            DeckDetailPopover(deck: deck, classColor: classColor)
        }
    }
}

// MARK: - 卡组详情弹出

struct DeckDetailPopover: View {
    let deck: RecommendedDeck
    let classColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题
            HStack {
                Text(deck.displayName)
                    .font(.headline)
                Spacer()
                Text(deck.displayWinRate)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(classColor)
            }
            
            Divider()
            
            // 详情
            VStack(alignment: .leading, spacing: 6) {
                detailRow(label: "卡组代码", value: deck.deckCode)
                detailRow(label: "职业", value: deck.playerClass)
                detailRow(label: "总对局", value: deck.displayGames)
                if deck.cost > 0 {
                    detailRow(label: "合成尘数", value: "\(deck.cost)")
                }
                detailRow(label: "数据来源", value: deck.lastUpdated.formatted(date: .abbreviated, time: .omitted))
            }
            
            Divider()
            
            // 复制按钮
            Button(action: {
                _ = DeckRecommendationService.copyDeckCode(deck.deckCode)
            }) {
                Label("一键复制卡组代码", systemImage: "doc.on.doc")
                    .font(.body)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(classColor)
            .controlSize(.large)
        }
        .padding()
        .frame(width: 280)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            Spacer()
        }
    }
}

// MARK: - Array 扩展

extension Array where Element == RecommendedDeck {
    /// 检查两个数组是否包含相同的元素（忽略顺序，只比较 id）
    func containsSame(as other: [RecommendedDeck]) -> Bool {
        let ids = Set(self.map { $0.id })
        let otherIds = Set(other.map { $0.id })
        return ids == otherIds
    }
}
