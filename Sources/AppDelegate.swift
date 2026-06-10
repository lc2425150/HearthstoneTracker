import Cocoa
import SwiftUI

/// 应用代理（非 @main，由 HearthstoneTrackerApp 委托）
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    static var _instance: AppDelegate?
    
    @MainActor static func instance() -> AppDelegate {
        guard let instance = _instance else {
            fatalError("AppDelegate 尚未初始化")
        }
        return instance
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate._instance = self
        
        // 设置全局异常处理
        NSSetUncaughtExceptionHandler { exception in
            print("[Crash] Uncaught exception: \(exception)")
            print("[Crash] Reason: \(exception.reason ?? "unknown")")
            print("[Crash] Stack: \(exception.callStackSymbols.joined(separator: "\n"))")
        }
        
        // 为所有窗口设置代理，使红色关闭按钮变为最小化
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for window in NSApplication.shared.windows {
                window.delegate = self
                // 防止窗口被释放 - IMK Bug 可能错误关闭窗口
                window.isReleasedWhenClosed = false
            }
        }
        
        // 监控窗口被错误关闭（macOS 输入法框架bug导致）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        
        // 监控窗口关闭后自动恢复（IMK Bug 防护）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResignMain),
            name: NSWindow.didResignMainNotification,
            object: nil
        )
        
        // 定期检查主窗口状态（IMK Bug 可能导致窗口消失）
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.startWindowHealthCheck()
        }
        
        // 数据安全迁移
        performDataMigration()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // 确保主窗口可见
        DispatchQueue.main.async {
            let mainWindow = NSApplication.shared.windows.first { $0.isVisible || $0.canBecomeKey }
            if mainWindow == nil || !(mainWindow?.isVisible ?? false) {
                // 尝试恢复主窗口
                for window in NSApplication.shared.windows {
                    if window.isReleasedWhenClosed == false {
                        window.makeKeyAndOrderFront(nil)
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - NSWindowDelegate: 关闭按钮 → 最小化到 Dock
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.hide(nil)
        return false
    }
    
    @objc func handleWindowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        // 检测是否被输入法框架错误关闭
        let stack = Thread.callStackSymbols.joined(separator: " ")
        let isIMKBug = stack.contains("TUINS") || stack.contains("TextInput") || stack.contains("IMK")
        
        if isIMKBug {
            print("[AppDelegate] 检测到输入法框架错误关闭窗口，阻止关闭")
            // 阻止关闭：立即恢复窗口并置前
            window.isReleasedWhenClosed = false
            DispatchQueue.main.async {
                window.makeKeyAndOrderFront(nil)
                window.level = .normal
                print("[AppDelegate] 窗口已恢复")
            }
        }
    }
    
    @objc func handleWindowDidResignMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        let stack = Thread.callStackSymbols.joined(separator: " ")
        if stack.contains("TUINS") || stack.contains("TextInput") || stack.contains("IMK") {
            print("[AppDelegate] IMK 导致窗口失去焦点，尝试恢复")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if !window.isKeyWindow && window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
    
    /// 定期检查主窗口健康状态，防止 IMK Bug 导致窗口消失
    private func startWindowHealthCheck() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard self != nil else { return }
            let windows = NSApplication.shared.windows
            _ = windows.first { $0.isVisible }
            
            // 检查是否所有窗口都消失了（IMK Bug 症状）
            let visibleWindows = windows.filter { $0.isVisible }
            if windows.count > 0 && visibleWindows.isEmpty {
                print("[AppDelegate] 检测到所有窗口不可见，尝试恢复")
                // 可能是 IMK Bug 导致窗口被隐藏
                for window in windows {
                    if !window.isReleasedWhenClosed {
                        DispatchQueue.main.async {
                            window.makeKeyAndOrderFront(nil)
                            print("[AppDelegate] 窗口健康检查恢复")
                        }
                        break
                    }
                }
            }
        }
    }
    
    private func performDataMigration() {
        KeychainManager.migrateFromUserDefaults(
            userDefaultsKey: "aiApiKey",
            keychainKey: Constants.keychainAIKey
        )
    }
}
