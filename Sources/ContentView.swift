import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var core: CardTrackerCore
    @Binding var isLoadingData: Bool
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // 顶部游戏状态栏 + 悬浮窗按钮
            HStack {
                StatusView()
                Spacer()
                // 悬浮窗切换按钮（突出显示）
                Button(action: {
                    OverlayWindowController.shared.toggle(core: core)
                    core.isOverlayVisible = OverlayWindowController.shared.isVisible
                }) {
                    Label("悬浮窗", systemImage: core.isOverlayVisible ? "rectangle.on.rectangle" : "rectangle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(core.isOverlayVisible ? .blue : .gray)
                .controlSize(.small)
                .padding(.trailing, 8)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            // 加载指示器
            if isLoadingData {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("正在初始化卡牌数据...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 2)
            }

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
        .frame(minWidth: 420, minHeight: 520)
        .task {
            if !core.isDataReady {
                isLoadingData = true
                await core.initializeData()
                isLoadingData = false
            }
        }
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

            // 手动输入卡组码（无字数限制，使用 TextEditor）
            VStack(spacing: 8) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("粘贴卡组码:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $manualDeckCode)
                        .font(.body.monospaced())
                        .frame(minHeight: 40, maxHeight: 80)
                        .border(Color(nsColor: .separatorColor), width: 0.5)
                        .cornerRadius(4)
                    
                    HStack {
                        if !core.isDataReady {
                            ProgressView()
                                .scaleEffect(0.5)
                            Text("卡牌数据加载中...")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        Spacer()
                        Button("导入") {
                            core.importDeck(from: manualDeckCode)
                            manualDeckCode = ""
                        }
                        .disabled(manualDeckCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !core.isDataReady)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // 错误提示
            if let error = core.deckImportError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

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
            Text("粘贴卡组码到下方输入框导入")
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
                Text("共 \(deck.totalOriginalCount) 张")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if deck.totalOriginalCount > 0 {
                        SectionHeader(title: "原卡组 (剩余\(deck.remainingOriginalCount) / 共\(deck.totalOriginalCount))")
                        AllCardsSection(cards: deck.allOriginalCards)
                    }
                    if !deck.discoveredCards.isEmpty {
                        SectionHeader(title: "发现牌 (\(deck.discoveredCards.count))")
                            .foregroundColor(.blue)
                        DiscoveredCardList(cards: deck.discoveredCards)
                    }
                }
            }
        }
        .padding()
    }

    private func cardRow(_ card: Card, count: Int) -> some View {
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

    private var dataStatusBar: some View {
        HStack {
            if let result = core.lastUpdateResult {
                Text("卡牌数据: \(result.totalCards) 张 (\(result.source.displayName))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if core.isDataReady {
                Text("卡牌数据已就绪")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("等待卡牌数据...")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            Spacer()
            if core.isUpdatingData {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }
}

// MARK: - Stats View

struct StatsView: View {
    @EnvironmentObject var core: CardTrackerCore

    var body: some View {
        VStack(spacing: 16) {
            Text("对战统计")
                .font(.title2)
                .fontWeight(.medium)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "总场次", value: "\(core.matchStats.totalMatches)", color: .blue)
                StatCard(title: "胜场", value: "\(core.matchStats.wins)", color: .green)
                StatCard(title: "负场", value: "\(core.matchStats.losses)", color: .red)
                StatCard(title: "胜率", value: String(format: "%.1f%%", core.matchStats.winRate * 100), color: .orange)
                StatCard(title: "平局", value: "\(core.matchStats.draws)", color: .gray)
                if core.matchStats.averageDuration > 0 {
                    StatCard(title: "平均时长", value: formatDuration(core.matchStats.averageDuration), color: .purple)
                }
            }
            .padding(.horizontal)

            if core.matchRecords.isEmpty {
                Spacer()
                Text("暂无对战记录")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    let matches = core.matchRecords
                    ForEach(matches) { match in
                        MatchHistoryRow(match: match)
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let match = core.matchRecords[idx]
                            core.deleteMatch(match)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding()
    }

    func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

struct MatchHistoryRow: View {
    let match: MatchRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(match.playerClass) vs \(match.opponentClass)")
                    .font(.subheadline)
                Text(formatDate(match.startTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(match.result.displayName)
                .font(.subheadline.bold())
                .foregroundColor(resultColor(match.result))
        }
        .padding(.vertical, 4)
    }

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }

    func resultColor(_ result: MatchResult) -> Color {
        switch result {
        case .win: return .green
        case .loss: return .red
        case .draw: return .gray
        case .unknown: return .secondary
        }
    }
}

// MARK: - Deck Library View

struct DeckLibraryView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var showingSaveDialog = false
    @State private var newDeckName = ""

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("我的卡组库")
                    .font(.title3)
                Spacer()
                Button("保存当前卡组") {
                    if core.playerDeck != nil {
                        showingSaveDialog = true
                    } else {
                        core.deckImportError = "请先导入卡组"
                    }
                }
                .font(.caption)
            }
            .padding(.horizontal)

            if core.savedDecks.isEmpty {
                Spacer()
                Text("暂无保存的卡组")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List {
                    let savedDecks = core.savedDecks
                    ForEach(savedDecks) { deck in
                        DeckLibraryRow(deck: deck, onSelect: {
                            core.importDeck(from: deck.deckCode)
                            core.updateDeckLastUsed(deck)
                        }, onDelete: {
                            core.deleteSavedDeck(deck)
                        })
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.vertical)
        .alert("保存卡组", isPresented: $showingSaveDialog) {
            TextField("卡组名称", text: $newDeckName)
            Button("保存") {
                core.saveCurrentDeck(name: newDeckName)
                newDeckName = ""
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("为当前卡组输入一个名称")
        }
    }
}

struct DeckLibraryRow: View {
    @EnvironmentObject var core: CardTrackerCore
    let deck: SavedDeck
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var isEditing = false
    @State private var editName = ""

    var body: some View {
        HStack {
            // 收藏按钮
            Button(action: { core.toggleFavorite(deck) }) {
                Image(systemName: deck.isFavorite ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundColor(deck.isFavorite ? .yellow : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("卡组名称", text: $editName, onCommit: {
                        core.editDeckName(deck, newName: editName)
                        isEditing = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .frame(maxWidth: 200)
                } else {
                    Text(deck.name)
                        .font(.subheadline)
                        .onTapGesture(count: 2) {
                            editName = deck.name
                            isEditing = true
                        }
                }
                Text("职业: \(deck.heroClass)")
                    .font(.caption2)
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
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(deck.isFavorite ? Color.yellow.opacity(0.06) : Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
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
            Section("卡牌数据库") {
                Picker("数据来源", selection: $core.selectedDataSource) {
                    ForEach(CardDataSource.allCases, id: \.self) { source in
                        HStack {
                            Text(source.displayName)
                            if let date = core.availableDataSources[source] {
                                Text("(\(formatDate(date)))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(source)
                    }
                }
                .pickerStyle(.menu)
                
                HStack {
                    if core.isUpdatingData {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                    Text("当前: \(core.selectedDataSource.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("切换并更新") {
                        Task { await core.switchDataSource(core.selectedDataSource) }
                    }
                    .disabled(core.isUpdatingData)
                }
                
                ForEach(CardDataSource.allCases, id: \.self) { source in
                    HStack {
                        Text(source.displayName)
                            .font(.caption)
                        Spacer()
                        if let date = core.availableDataSources[source] {
                            Text("更新于 \(formatDate(date))")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("未更新")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }

            Section("数据更新") {
                Toggle("启动时自动检查卡牌更新", isOn: $autoCheckUpdates)
                HStack {
                    Button(core.isUpdatingData ? "更新中…" : "立即检查所有来源") {
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

            Section("HSReplay.net 集成") {
                HStack {
                    if HSReplayManager.shared.isAuthenticated {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("已登录")
                                .font(.subheadline)
                            if let name = HSReplayManager.shared.username {
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.gray)
                        Text("未登录")
                            .font(.subheadline)
                    }
                    Spacer()
                    if HSReplayManager.shared.isAuthenticated {
                        Button("登出") {
                            HSReplayManager.shared.logout()
                        }
                        .font(.caption)
                    } else {
                        Button("获取 Token") {
                            HSReplayManager.shared.authenticate()
                        }
                        .font(.caption)
                    }
                }
                
                HStack {
                    Text("上传状态:")
                        .font(.caption)
                    Spacer()
                    Text("等待上传")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                HStack {
                    Image(systemName: "arrow.clipboard")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("自动检测卡组: 游戏开始时扫描剪贴板")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("OCR 识别") {
                Toggle("启用 OCR 兜底识别", isOn: $enableOCR)
            }

            Section("悬浮窗") {
                Toggle("窗口锁定（鼠标穿透）", isOn: $core.windowsLocked)
                    .help("锁定后鼠标点击穿透到游戏，解锁后可拖拽悬浮窗")
                
                Slider(value: $overlayOpacity, in: 0.3...1.0) {
                    Text("透明度")
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("悬浮窗宽度: \(Int(core.overlayWidth))px")
                        .font(.caption)
                    Slider(value: $core.overlayWidth, in: 180...500, step: 10) {
                        Text("宽度")
                    }
                }
                
                Toggle("悬浮窗显示在游戏界面内部", isOn: $core.overlayInsideGame)
                    .help("开启后悬浮窗贴合在游戏窗口内侧，关闭后在外侧")
                
                Toggle("自动隐藏悬浮窗（切出游戏时）", isOn: $core.overlayAutoHide)
                    .help("切换到其他应用时自动隐藏悬浮窗，回到游戏时自动显示")
                
                Picker("卡牌尺寸", selection: $core.cardDisplaySize) {
                    ForEach(CardDisplaySize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("稀有度颜色")
                        .font(.caption)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color.gray).frame(width: 8, height: 8)
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Circle().fill(Color.purple).frame(width: 8, height: 8)
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                    }
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

    func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}
