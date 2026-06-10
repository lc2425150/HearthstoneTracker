import Cocoa
import AppKit

/// HSTracker 风格的悬浮窗基类
/// 无边框、透明、置顶，所有悬浮窗继承此类
class OverWindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        configureWindow()
    }
    
    private func configureWindow() {
        guard let window = window else { return }
        
        // HSTracker 窗口配置
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.level = .floating
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.styleMask = [.borderless, .nonactivatingPanel, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.acceptsMouseMovedEvents = true
    }
    
    /// 设置窗口透明度
    func setOpacity(_ alpha: CGFloat) {
        window?.backgroundColor = NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: alpha)
    }
    
    /// 边缘吸附
    func snapToEdge() {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        var frame = window.frame
        let threshold: CGFloat = 20
        
        if abs(frame.minX - screenFrame.minX) < threshold {
            frame.origin.x = screenFrame.minX
        } else if abs(frame.maxX - screenFrame.maxX) < threshold {
            frame.origin.x = screenFrame.maxX - frame.width
        }
        if abs(frame.minY - screenFrame.minY) < threshold {
            frame.origin.y = screenFrame.minY
        } else if abs(frame.maxY - screenFrame.maxY) < threshold {
            frame.origin.y = screenFrame.maxY - frame.height
        }
        
        window.setFrame(frame, display: true, animate: true)
    }
    
    /// 显示/隐藏切换
    func toggle() {
        guard let window = window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showWindow(nil)
        }
    }
}
