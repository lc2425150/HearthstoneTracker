import SwiftUI
import SwiftData
import UIKit

// MARK: - 设置

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var cardService: CardDataService

    @AppStorage("enableOCR") private var enableOCR = false
    @AppStorage("autoTrack") private var autoTrack = true

    @State private var isUpdating = false
    @State private var updateMessage: String?
    @State private var cardCount = 0
    @State private var cacheSize: String = "计算中..."
    @State private var isClearingCache = false
    @State private var showClearAlert = false
    @State private var showResetAlert = false

    var body: some View {
        List {
            // 卡牌数据
            Section("卡牌数据") {
                HStack {
                    Text("数据源")
                    Spacer()
                    Text(Constants.DataSource.hearthstoneJSON.displayName)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("卡牌数量")
                    Spacer()
                    Text("\(cardCount) 张")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("最后更新")
                    Spacer()
                    if let date = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.lastDataUpdate) as? Date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    } else {
                        Text("从未更新")
                            .foregroundColor(.orange)
                    }
                }

                Button(action: { Task { await updateCardData() } }) {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("更新中...")
                        } else {
                            Text("更新卡牌数据")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .disabled(isUpdating)

                if let message = updateMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(message.contains("成功") ? .green : .red)
                }
            }

            // 追踪设置
            Section("追踪设置") {
                Toggle("选择卡组后自动开始追踪", isOn: $autoTrack)
            }

            // 缓存管理
            Section("缓存管理") {
                HStack {
                    Text("卡图缓存")
                    Spacer()
                    if isClearingCache {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(cacheSize).foregroundColor(.secondary)
                    }
                }

                Button("清除卡图缓存", role: .destructive) {
                    clearCache()
                }
                .disabled(isClearingCache)
            }

            // 数据管理
            Section("数据管理") {
                Button("清除所有对局记录", role: .destructive) {
                    showClearAlert = true
                }
                Button("重置所有数据", role: .destructive) {
                    showResetAlert = true
                }
            }

            // 关于
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(Constants.appVersion).foregroundColor(.secondary)
                }
                HStack {
                    Text("应用")
                    Spacer()
                    Text(Constants.appName).foregroundColor(.secondary)
                }
                Link("数据来源: HearthstoneJSON",
                     destination: URL(string: "https://hearthstonejson.com")!)
            }
        }
        .navigationTitle("设置")
        .alert("确认清除", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) { clearAllMatches() }
        } message: {
            Text("将删除所有对局记录，此操作不可撤销。")
        }
        .alert("确认重置", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("确认重置", role: .destructive) { resetAllData() }
        } message: {
            Text("将删除所有数据（卡牌、卡组、对局记录），需要重新下载卡牌数据。")
        }
        .task {
            loadStats()
            calculateCacheSize()
        }
    }

    private func loadStats() {
        cardCount = cardService.cardCount()
    }

    private func calculateCacheSize() {
        let size = CardImageLoader.shared.cacheSize()
        if size > 1024 * 1024 {
            cacheSize = String(format: "%.1f MB", Double(size) / 1024 / 1024)
        } else if size > 1024 {
            cacheSize = String(format: "%.1f KB", Double(size) / 1024)
        } else {
            cacheSize = "\(size) B"
        }
    }

    private func updateCardData() async {
        isUpdating = true
        updateMessage = nil
        do {
            let result = try await cardService.updateCardData()
            updateMessage = "更新成功: \(result.cardCount) 张卡牌"
            loadStats()
        } catch {
            updateMessage = "更新失败: \(error.localizedDescription)"
        }
        isUpdating = false
    }

    private func clearCache() {
        isClearingCache = true
        Task {
            try? CardImageLoader.shared.clearDiskCache()
            CardImageLoader.shared.clearMemoryCache()
            await MainActor.run {
                calculateCacheSize()
                isClearingCache = false
            }
        }
    }

    private func clearAllMatches() {
        let descriptor = FetchDescriptor<MatchRecord>()
        if let records = try? modelContext.fetch(descriptor) {
            for record in records {
                modelContext.delete(record)
            }
            try? modelContext.save()
            loadStats()
        }
    }

    private func resetAllData() {
        // 清除所有 SwiftData 数据
        let cardDescriptor = FetchDescriptor<Card>()
        if let cards = try? modelContext.fetch(cardDescriptor) {
            for obj in cards { modelContext.delete(obj) }
        }
        let deckDescriptor = FetchDescriptor<SavedDeck>()
        if let decks = try? modelContext.fetch(deckDescriptor) {
            for obj in decks { modelContext.delete(obj) }
        }
        let matchDescriptor = FetchDescriptor<MatchRecord>()
        if let matches = try? modelContext.fetch(matchDescriptor) {
            for obj in matches { modelContext.delete(obj) }
        }
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.lastDataUpdate)
        Task { _ = try? await cardService.updateCardData() }
        loadStats()
    }
}
