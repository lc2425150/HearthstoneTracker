import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 关闭最后窗口后不退出应用，保留在 Dock 中
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 点击 Dock 图标时重新显示窗口
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
    
    /// 应用启动完成，设置窗口关闭按钮行为
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 为所有窗口设置代理，使红色关闭按钮变为最小化
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for window in NSApplication.shared.windows {
                window.delegate = self
            }
        }
    }
}

// MARK: - NSWindowDelegate: 关闭按钮 → 最小化到 Dock
extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 拦截关闭事件，改为最小化
        sender.orderOut(nil)    // 隐藏窗口
        NSApp.hide(nil)         // 隐藏应用到 Dock
        return false            // 阻止实际关闭
    }
}
