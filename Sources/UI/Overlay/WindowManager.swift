import Cocoa

/// HSTracker 风格窗口管理器
/// 管理所有悬浮窗的创建、显示、隐藏、销毁
@MainActor
final class WindowManager {
    
    unowned let core: CoreManager
    private var windows: [String: OverWindowController] = [:]
    
    init(core: CoreManager) {
        self.core = core
    }
    
    // MARK: - 窗口注册
    
    /// 注册并获取窗口
    func register(id: String, factory: () -> OverWindowController) -> OverWindowController {
        if let existing = windows[id] {
            return existing
        }
        let window = factory()
        windows[id] = window
        return window
    }
    
    /// 获取已注册窗口
    func get(id: String) -> OverWindowController? {
        return windows[id]
    }
    
    /// 注销窗口
    func unregister(id: String) {
        windows[id]?.window?.close()
        windows.removeValue(forKey: id)
    }
    
    // MARK: - 批量操作
    
    /// 显示所有窗口
    func showAll() {
        windows.values.forEach { $0.showWindow(nil) }
    }
    
    /// 隐藏所有窗口
    func hideAll() {
        windows.values.forEach { $0.window?.orderOut(nil) }
    }
    
    /// 切换所有窗口
    func toggleAll() {
        let anyVisible = windows.values.contains { $0.window?.isVisible == true }
        if anyVisible {
            hideAll()
        } else {
            showAll()
        }
    }
    
    /// 更新所有窗口透明度
    func setAllOpacity(_ alpha: CGFloat) {
        windows.values.forEach { $0.setOpacity(alpha) }
    }
    
    /// 所有窗口边缘吸附
    func snapAllToEdge() {
        windows.values.forEach { $0.snapToEdge() }
    }
    
    /// 释放所有窗口
    func destroyAll() {
        windows.values.forEach { $0.window?.close() }
        windows.removeAll()
    }
    
    // MARK: - 窗口计数
    
    var count: Int { windows.count }
    var allWindows: [OverWindowController] { Array(windows.values) }
}
