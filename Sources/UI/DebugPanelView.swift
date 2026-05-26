import SwiftUI
import AppKit

/// 调试面板：用于查看日志事件、卡牌数据、缓存状态等内部信息
struct DebugPanelView: View {
    @EnvironmentObject var core: CardTrackerCore
    @State private var selectedTab = 0
    @State private var logEvents: [String] = []
    @State private var cacheStats = ""

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                ForEach(["日志事件", "卡牌数据", "缓存状态", "系统信息"], id: \.self) { title in
                    let idx = ["日志事件": 0, "卡牌数据": 1, "缓存状态": 2, "系统信息": 3][title]!
                    Button(title) { selectedTab = idx }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == idx
                                ? Color.blue.opacity(0.2)
                                : Color.clear
                        )
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            Divider()

            // 内容区
            Group {
                switch selectedTab {
                case 0:
                    logEventsView
                case 1:
                    cardDataView
                case 2:
                    cacheStatsView
                case 3:
                    systemInfoView
                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadLogEvents()
            loadCacheStats()
        }
    }

    private var logEventsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("最近日志事件")
                    .font(.headline)
                Spacer()
                Button("刷新") { loadLogEvents() }
                    .font(.caption)
            }
            .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(logEvents, id: \.self) { event in
                        Text(event)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(2)
                    }
                }
                .padding()
            }
        }
    }

    private var cardDataView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卡牌数据状态")
                .font(.headline)
                .padding(.horizontal)

            if let result = core.lastUpdateResult {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("总卡牌数:")
                        Text("\(result.totalCards)")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("更新时间:")
                        Text("\(result.timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("数据状态:")
                        Text("已检查")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            } else {
                Text("未加载卡牌数据")
                    .foregroundColor(.orange)
                    .padding()
            }

            Divider()

            if let deck = core.playerDeck {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前牌库")
                        .font(.subheadline)
                    HStack {
                        Text("职业:")
                        Text(deck.heroClass.displayName)
                            .foregroundColor(.purple)
                    }
                    HStack {
                        Text("原卡组:")
                        Text("\(deck.totalOriginalCount) 张")
                    }
                    HStack {
                        Text("发现牌:")
                        Text("\(deck.discoveredCards.count) 张")
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("剩余:")
                        Text("\(deck.remainingOriginalCount) 张")
                            .foregroundColor(deck.remainingOriginalCount > 0 ? .green : .red)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
    }

    private var cacheStatsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("缓存状态")
                .font(.headline)
                .padding(.horizontal)

            Text(cacheStats)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)

            HStack {
                Button("刷新缓存统计") { loadCacheStats() }
                Button("清除卡图缓存") {
                    Task {
                        try? await CardImageLoader.shared.clearDiskCache()
                        loadCacheStats()
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var systemInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("系统信息")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("应用版本:")
                    Text(VersionChecker.displayVersion)
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("追踪状态:")
                    Text(core.isTracking ? "监控中" : "已停止")
                        .foregroundColor(core.isTracking ? .green : .gray)
                }
                HStack {
                    Text("悬浮窗:")
                    Text(core.isOverlayVisible ? "显示" : "隐藏")
                        .foregroundColor(core.isOverlayVisible ? .green : .gray)
                }
                HStack {
                    Text("炉石进程:")
                    Text(core.isHearthstoneRunning ? "运行中" : "未运行")
                        .foregroundColor(core.isHearthstoneRunning ? .green : .orange)
                }
            }
            .padding(.horizontal)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("日志文件路径:")
                    .font(.caption)
                Text(Constants.powerLogPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Text("卡牌数据路径:")
                    .font(.caption)
                Text(Constants.cardDataPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Text("卡图缓存路径:")
                    .font(.caption)
                Text(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("HearthstoneTracker/CardImages").path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func loadLogEvents() {
        // 模拟日志事件
        logEvents = [
            "[2025-05-23 20:15:32] ZONE_CHANGE: PLAYER_DECK -> HAND",
            "[2025-05-23 20:15:35] CARD_PLAYED: 玩家打出「火球术」",
            "[2025-05-23 20:15:40] OPPONENT_PLAYED: 对手打出「寒冰箭」",
            "[2025-05-23 20:15:45] DISCOVER_CARD: 发现「炎爆术」",
            "[2025-05-23 20:15:50] GAME_START: 对局开始",
            "[2025-05-23 20:15:55] TURN_CHANGE: 回合 3"
        ]
    }

    private func loadCacheStats() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HearthstoneTracker/CardImages")
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: cacheDir.path)
            let totalSize = try files.reduce(0) { sum, file in
                let attrs = try FileManager.default.attributesOfItem(atPath: cacheDir.appendingPathComponent(file).path)
                return sum + (attrs[.size] as? Int ?? 0)
            }
            let mb = Double(totalSize) / (1024 * 1024)
            cacheStats = """
            缓存目录: \(cacheDir.path)
            文件数量: \(files.count)
            总大小: \(String(format: "%.2f", mb)) MB
            内存缓存: 上限 200 张
            """
        } catch {
            cacheStats = "无法读取缓存状态: \(error.localizedDescription)"
        }
    }
}