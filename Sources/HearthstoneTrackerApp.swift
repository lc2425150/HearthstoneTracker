import SwiftUI
import Combine

@main
struct HearthstoneTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var core = CardTrackerCore()
    @State private var isLoadingData = false

    var body: some Scene {
        WindowGroup {
            ContentView(isLoadingData: $isLoadingData)
                .environmentObject(core)
                .frame(minWidth: 420, minHeight: 520)
                .onAppear {
                    isLoadingData = true
                    Task.detached(priority: .background) {
                        await core.initializeData()
                        await MainActor.run { isLoadingData = false }
                    }
                }
                .onReceive(core.$isDataReady) { ready in
                    if ready { isLoadingData = false }
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            deckCommands
            AppMenuCommands()
        }
    }

    @CommandsBuilder
    private var deckCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("导入卡组码") { core.requestDeckImport() }
            Divider()
            Button("切换悬浮窗") { core.toggleOverlay() }
            Divider()
            Button("检查卡牌更新") { Task { await core.checkCardDataUpdate() } }
            Divider()
            Button("开始/暂停追踪") { core.toggleTracking() }
            Divider()
            Button("OCR扫描") { core.triggerOCRScan() }
            Button("对手追踪") { core.startOpponentTracking() }
            Divider()
            Button("调试面板") { core.showDebugPanel() }
            Divider()
            Button("测试工具") { core.showTestHarness() }
            Divider()
            Button("重置对局") { core.resetMatch() }
        }
    }
}

struct AppMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(before: .help) {
            Button("关于炉石记牌器") {
                NSApplication.shared.orderFrontStandardAboutPanel(
                    options: [:]
                )
            }
            Divider()
            Button("打开日志目录") {
                let logDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                NSWorkspace.shared.open(logDir)
            }
            Button("打开卡牌数据目录") {
                let appDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("HearthstoneTracker")
                NSWorkspace.shared.open(appDir)
            }
            Divider()
            Button("HearthstoneJSON API") {
                if let url = URL(string: "https://hearthstonejson.com") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
