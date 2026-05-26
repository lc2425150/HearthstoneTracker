import Foundation
import AppKit

/// 炉石传说游戏启动器与进程检测
final class GameLauncher: ObservableObject, @unchecked Sendable {
    static let shared = GameLauncher()
    
    /// 游戏是否正在运行
    @Published var isGameRunning = false
    
    /// 游戏进程名称（macOS 版）
    private let gameBundleId = "com.blizzard.heartstone"
    private let gameName = "Hearthstone"
    private let gamePaths = [
        "/Applications/Hearthstone/Hearthstone.app",
        "/Volumes/T7/Applications/Hearthstone/Hearthstone.app",
        "/Users/\(NSUserName())/Applications/Hearthstone/Hearthstone.app",
        "/Applications/Battle.net.app",
        "/Volumes/T7/Applications/Battle.net.app",
    ]
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 5.0
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public
    
    /// 启动炉石传说游戏
    func launchGame() -> Bool {
        // 搜索炉石传说安装路径
        guard let foundPath = gamePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("[GameLauncher] Hearthstone not found at any known path")
            return false
        }
        
        let url = URL(fileURLWithPath: foundPath)
        
        do {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.createsNewApplicationInstance = false
            
            NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
                if let error = error {
                    print("[GameLauncher] Failed to launch: \(error)")
                } else {
                    print("[GameLauncher] Launched successfully: \(app?.bundleIdentifier ?? "unknown")")
                }
            }
            return true
        }
    }
    
    /// 检查游戏是否正在运行
    func checkGameRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { app in
            app.bundleIdentifier == gameBundleId ||
            app.bundleIdentifier?.contains("heartstone") == true ||
            app.bundleIdentifier?.contains("blizzard") == true ||
            app.localizedName?.contains(gameName) == true ||
            app.localizedName?.contains("炉石") == true ||
            app.executableURL?.lastPathComponent.contains("Hearthstone") == true ||
            app.executableURL?.lastPathComponent.contains("Unity") == true
        }
        
        DispatchQueue.main.async {
            self.isGameRunning = isRunning
        }
        return isRunning
    }
    
    /// 获取游戏窗口（如果正在运行）
    func getGameWindow() -> NSWindow? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == gameBundleId }) else {
            return nil
        }
        
        // 获取应用的所有窗口
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        let pid = app.processIdentifier
        let gameWindows = windowList.filter { window in
            guard let windowPid = window[kCGWindowOwnerPID as String] as? Int32 else { return false }
            return windowPid == pid
        }
        
        // 返回主窗口（最大的窗口）
        return nil // 实际需要更复杂的窗口获取逻辑
    }
    
    /// 强制退出游戏
    func forceQuitGame() -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == gameBundleId }) else {
            return false
        }
        
        app.terminate()
        return true
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // 立即检查一次
        checkGameRunning()
        
        // 定时检查
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.checkGameRunning()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Core 扩展：游戏启动功能

extension CardTrackerCore {
    /// 检查并启动炉石游戏
    func launchHearthstoneIfNeeded() -> Bool {
        let launcher = GameLauncher.shared
        
        if launcher.checkGameRunning() {
            print("[Core] Hearthstone is already running")
            return true
        }
        
        print("[Core] Launching Hearthstone...")
        return launcher.launchGame()
    }
    
    /// 游戏运行状态
    var isHearthstoneRunning: Bool {
        GameLauncher.shared.isGameRunning
    }
}