import Foundation
import Combine
import AppKit

// MARK: - 游戏事件类型

enum GameMode: String, CaseIterable {
    case none = "none"
    case constructed = "constructed"
    case arena = "arena"
    case battlegrounds = "battlegrounds"
    case practice = "practice"
    case adventure = "adventure"
    case duels = "duels"
}

struct GameStartInfo {
    let playerClass: String
    let opponentClass: String
    let isFirstPlayer: Bool
    let mode: GameMode
}

struct GameEndInfo {
    let result: String // win / loss / draw
    let duration: TimeInterval
    let playerClass: String
    let opponentClass: String
    let mode: GameMode
}

// MARK: - Watcher 协议

/// HSTracker 风格的 Watcher 协议
protocol GameWatcher: AnyObject {
    var isEnabled: Bool { get set }
    func start()
    func stop()
}

// MARK: - GameManager

/// 游戏管理器（HSTracker 风格）
/// 负责监控 Hearthstone 进程状态、管理 Watcher
@MainActor
final class GameManager: ObservableObject {
    
    unowned let core: CoreManager
    
    // MARK: - Published 状态
    
    @Published var isGameRunning = false
    @Published var currentMode: GameMode = .none
    @Published var isInGame = false  // 是否在对局中
    
    // MARK: - 窗口管理器
    
    lazy var windowManager: WindowManager = {
        WindowManager(core: core)
    }()
    
    // MARK: - Watchers
    
    private var watchers: [GameWatcher] = []
    private var cancellables = Set<AnyCancellable>()
    private var processCheckTimer: AnyCancellable?
    
    init(core: CoreManager) {
        self.core = core
    }
    
    func start() {
        startProcessMonitoring()
        print("[GameManager] 已启动")
    }
    
    func stop() {
        processCheckTimer?.cancel()
        stopAllWatchers()
        print("[GameManager] 已停止")
    }
    
    // MARK: - 进程监控
    
    private func startProcessMonitoring() {
        processCheckTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkHearthstoneProcess()
            }
    }
    
    private func checkHearthstoneProcess() {
        let running = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "blizzard.hearthstone" ||
            app.bundleIdentifier == "unity.hearthstone"
        }
        
        if running != isGameRunning {
            isGameRunning = running
            if running {
                print("[GameManager] 检测到炉石传说启动")
                startAllWatchers()
            } else {
                print("[GameManager] 炉石传说已关闭")
                stopAllWatchers()
                isInGame = false
            }
        }
    }
    
    // MARK: - Watcher 管理
    
    func registerWatcher(_ watcher: GameWatcher) {
        watchers.append(watcher)
        if isGameRunning { watcher.start() }
    }
    
    func startAllWatchers() {
        watchers.forEach { $0.start() }
    }
    
    func stopAllWatchers() {
        watchers.forEach { $0.stop() }
    }
}
