import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部游戏状态栏
            gameStatusBar

            TabView(selection: $selectedTab) {
                DeckView()
                    .tabItem {
                        Label("牌库", systemImage: "rectangle.stack")
                    }
                    .tag(0)

                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar")
                    }
                    .tag(1)

                DeckLibraryView()
                    .tabItem {
                        Label("卡组库", systemImage: "books.vertical")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape")
                    }
                    .tag(3)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .task {
            await core.checkCardDataUpdate()
        }
    }

    // MARK: - Game Status Bar

    private var gameStatusBar: some View {
        HStack(spacing: 8) {
            // 游戏状态指示灯
            HStack(spacing: 4) {
                Circle()
                    .fill(core.gameLauncher.isGameRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(core.gameLauncher.isGameRunning ? "炉石运行中" : "炉石未启动")
                    .font(.caption)
                    .foregroundColor(core.gameLauncher.isGameRunning ? .green : .orange)
            }

            Spacer()

            // 启动/强制退出按钮
            if core.gameLauncher.isGameRunning {
                Button(action: { _ = core.gameLauncher.forceQuitGame() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle")
                        Text("退出游戏")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            } else {
                Button(action: { _ = core.launchHearthstoneIfNeeded() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                        Text("启动炉石")
                    }
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Divider()
                .frame(height: 16)

            // 追踪控制
            HStack(spacing: 4) {
                Circle()
                    .fill(core.isTracking ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(core.isTracking ? "追踪中" : "未追踪")
                    .font(.caption2)
                Button(core.isTracking ? "暂停" : "开始") {
                    core.toggleTracking()
                }
                .buttonStyle(.borderless)
                .font(.caption2)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
    }
}

// MARK: - Deck View

struct DeckView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var manualDeckCode = ""

    var body: some View {
        VStack(spacing: 20) {
            if let deck = core.playerDeck {
                loadedDeckView(deck)
            } else {
                emptyDeckView
            }

            // 手动输入卡组码
            VStack(spacing: 8) {
                Divider()
                HStack {
                    TextField("粘贴卡组码...", text: $manualDeckCode)
                        .textFieldStyle(.roundedBorder)
                    Button("导入") {
                        core.importDeck(from: manualDeckCode)
                        manualDeckCode = ""
                    }
                    .disabled(manualDeckCode.isEmpty)
                }
                .padding(.horizontal)
            }

            Spacer()

            // 数据状态栏
            dataStatusBar
        }
    }

    private var emptyDeckView: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("未加载牌库")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("使用 Cmd+I 从剪贴板导入，或粘贴卡组码到下方输入框")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    private func loadedDeckView(_ deck: TrackedDeck) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("我方牌库")
                    .font(.headline)
                Spacer()
                Button("清除") { core.clearDeck() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            HStack {
                Label("职业: \(deck.heroClass.displayName)", systemImage: "person.fill")
                    .font(.subheadline)
                Spacer()
                Text("共 \(deck.originalCards.count) 张")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !deck.originalCards.isEmpty {
                        SectionHeader(title: "原卡组 (\(deck.remainingOriginalCount) / \(deck.originalCards.count))")
                        ForEach(deck.remainingOriginal.sorted(by: { $0.cost < $1.cost })) { card in
                            cardRow(card, count: 1)
                        }
                    }
                    if !deck.discoveredCards.isEmpty {
                        SectionHeader(title: "发现牌 (\(deck.discoveredCards.count))")
                            .foregroundColor(.blue)
                        ForEach(deck.discoveredCards) { discovered in
                            HStack {
                                cardRow(discovered.card, count: 1)
                                Spacer()
                                Text(discovered.sourceLabel)
                                    .font(.caption2)
                                    .foregroundColor(.blue.opacity(0.7))
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func cardRow(_ card: Card, count: Int) -> some View {
        HStack(spacing: 8) {
            CardThumbnailMini(cardId: card.cardId, cardName: card.name)
            Text("(\(card.cost))")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
            Text(card.name)
                .font(.body)
                .lineLimit(1)
            if count > 1 {
                Text("×\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var dataStatusBar: some View {
        HStack {
            // 追踪状态
            HStack(spacing: 4) {
                Circle()
                    .fill(core.isTracking ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
                Text(core.isTracking ? "监控中" : "未启动")
                    .font(.caption2)
            }

            Spacer()

            if core.isUpdatingData {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text("正在更新卡牌数据…")
                    .font(.caption2)
            } else if core.isDataReady, let result = core.lastUpdateResult {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption2)
                Text("卡牌库 \(result.totalCards) 张, 更新于 \(formatDate(result.timestamp))")
                    .font(.caption2)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                Text("卡牌数据待更新")
                    .font(.caption2)
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
}

// MARK: - Stats View

struct StatsView: View {
    @EnvironmentObject var core: CardTrackerCore

    var body: some View {
        let stats = core.matchStats
        VStack(alignment: .leading, spacing: 0) {
            if stats.totalMatches == 0 {
                emptyView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        overviewSection(stats: stats)
                        matchHistorySection
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无对局记录")
                .font(.headline)
            Text("开始一场对战，数据将自动记录")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func overviewSection(stats: MatchStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "总览")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCard(title: "总场次", value: "\(stats.totalMatches)")
                StatCard(title: "胜率", value: String(format: "%.0f%%", stats.winRate * 100))
                StatCard(title: "胜 / 负 / 平", value: "\(stats.wins) / \(stats.losses) / \(stats.draws)")
                StatCard(title: "平均时长", value: formatDuration(stats.averageDuration))
            }
        }
    }

    private var matchHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "最近对局")
            ForEach(core.matchRecords.prefix(20)) { record in
                MatchRow(record: record) {
                    core.deleteMatch(record)
                }
            }
        }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return "\(m)分\(s)秒"
    }
}

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

struct MatchRow: View {
    let record: MatchRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            resultBadge
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.playerClass) vs \(record.opponentClass)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(formatDate(record.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let end = record.endTime {
                Text(formatDuration(record.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
    }

    private var resultBadge: some View {
        Text(record.result.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(badgeTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }

    private var badgeColor: Color {
        switch record.result {
        case .win:  return .green
        case .loss: return .red
        case .draw: return .gray
        case .unknown: return .secondary
        }
    }

    private var badgeTextColor: Color {
        switch record.result {
        case .win:  return .green
        case .loss: return .red
        case .draw: return .gray
        case .unknown: return .secondary
        }
    }

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }

    func formatDuration(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return "\(m)m \(s)s"
    }
}

// MARK: - Deck Library View

struct DeckLibraryView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var showSaveDialog = false
    @State private var deckNameInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionHeader(title: "我的卡组")
                Spacer()
                if core.playerDeck != nil {
                    Button("保存当前卡组") {
                        deckNameInput = core.playerDeck?.heroClass.displayName ?? "新卡组"
                        showSaveDialog = true
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if core.savedDecks.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(core.savedDecks) { deck in
                            DeckRow(deck: deck) {
                                core.importDeck(from: deck.deckCode)
                                core.updateDeckLastUsed(deck)
                            } onDelete: {
                                core.deleteSavedDeck(deck)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showSaveDialog) {
            VStack(spacing: 16) {
                Text("保存卡组")
                    .font(.headline)
                TextField("卡组名称", text: $deckNameInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                HStack(spacing: 12) {
                    Button("取消") { showSaveDialog = false }
                        .keyboardShortcut(.escape)
                    Button("保存") {
                        core.saveCurrentDeck(name: deckNameInput)
                        showSaveDialog = false
                    }
                    .keyboardShortcut(.return)
                }
            }
            .padding(24)
            .frame(width: 280, height: 150)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("暂无保存的卡组")
                .font(.headline)
            Text("导入卡组码后，可以保存到卡组库")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DeckRow: View {
    let deck: SavedDeck
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(deck.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if deck.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                Text(deck.heroClass)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let lastUsed = deck.lastUsed {
                    Text("上次使用: \(formatDate(lastUsed))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("使用", action: onSelect)
                .font(.caption)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
    }

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var autoCheckUpdates = true
    @State private var enableOCR = true
    @State private var overlayOpacity = 0.7
    @State private var autoStartTracking = false
    @State private var isCheckingVersion = false
    @State private var updateMessage: String?
    @State private var isClearingCache = false
    @State private var cacheMessage: String?

    var body: some View {
        Form {
            Section("数据更新") {
                Toggle("启动时自动检查卡牌更新", isOn: $autoCheckUpdates)
                HStack {
                    Button(core.isUpdatingData ? "更新中…" : "立即检查更新") {
                        Task { await core.checkCardDataUpdate() }
                    }
                    .disabled(core.isUpdatingData)
                }
            }

            Section("版本更新") {
                HStack {
                    Text("当前版本")
                    Spacer()
                    Text(VersionChecker.displayVersion)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Button(isCheckingVersion ? "检查中…" : "检查更新") {
                        isCheckingVersion = true
                        updateMessage = nil
                        Task {
                            defer { isCheckingVersion = false }
                            if let latest = await VersionChecker.checkForUpdate() {
                                updateMessage = "发现新版本 \(latest)"
                            } else {
                                updateMessage = "已是最新版本"
                            }
                        }
                    }
                    .disabled(isCheckingVersion)

                    if let msg = updateMessage {
                        Text(msg)
                            .foregroundColor(msg.contains("新版本") ? .orange : .green)
                            .font(.caption)
                    }
                }
            }

            Section("日志监控") {
                HStack {
                    Text("状态: \(core.isTracking ? "监控中" : "已停止")")
                    Spacer()
                    Button(core.isTracking ? "停止监控" : "开始监控") {
                        core.toggleTracking()
                    }
                }
                Toggle("启动时自动开始监控", isOn: $autoStartTracking)
            }

            Section("OCR 识别") {
                Toggle("启用 OCR 兜底识别", isOn: $enableOCR)
            }

            Section("悬浮窗") {
                Slider(value: $overlayOpacity, in: 0.3...1.0) {
                    Text("透明度")
                }
            }

            Section("缓存管理") {
                HStack {
                    Button(isClearingCache ? "清除中…" : "清除卡图缓存") {
                        isClearingCache = true
                        cacheMessage = nil
                        Task {
                            do {
                                try await CardImageLoader.shared.clearDiskCache()
                                await MainActor.run {
                                    cacheMessage = "卡图缓存已清除"
                                }
                            } catch {
                                await MainActor.run {
                                    cacheMessage = "清除失败"
                                }
                            }
                            await MainActor.run { isClearingCache = false }
                        }
                    }
                    .disabled(isClearingCache)

                    if let msg = cacheMessage {
                        Text(msg)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}