import SwiftUI
import AppKit

/// 悬浮窗控制器：管理透明悬浮窗口，贴合炉石传说窗口
final class OverlayWindowController: NSObject, @unchecked Sendable {
    
    func updateLockState(locked: Bool) {
        window?.ignoresMouseEvents = locked
        window?.isMovableByWindowBackground = !locked
    }
    static let shared = OverlayWindowController()
    private var window: NSWindow?
    private var positionTimer: Timer?
    private(set) var preferredSide: OverlaySide = .right
    private var lastHearthstoneFrame: CGRect?
    private var isDragging = false

    enum OverlaySide: String {
        case left, right
        
        mutating func toggle() {
            self = (self == .left) ? .right : .left
        }
    }

    func show(core: CardTrackerCore) {
        if window == nil {
            window = createOverlayWindow(core: core)
        } else {
            let view = OverlayView().environmentObject(core)
            window?.contentView = NSHostingView(rootView: view)
        }
        // 设置窗口级别（浮动，可在全屏应用上方）
        window?.level = .floating
        positionNextToHearthstone()
        window?.makeKeyAndOrderFront(nil)
        startPositionTracking()
    }

    func hide() {
        stopPositionTracking()
        window?.orderOut(nil)
    }

    func toggle(core: CardTrackerCore) {
        if window?.isVisible == true {
            hide()
        } else {
            show(core: core)
        }
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// 切换到另一侧
    func switchSide() {
        preferredSide.toggle()
        positionNextToHearthstone()
    }

    // MARK: - Window Creation

    private func createOverlayWindow(core: CardTrackerCore) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 600),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        let initialLocked = UserDefaults.standard.object(forKey: "windowsLocked") as? Bool ?? true
        window.ignoresMouseEvents = initialLocked
        window.isMovableByWindowBackground = !initialLocked
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.delegate = self

        let overlayView = OverlayView().environmentObject(core)
        let hostingView = NSHostingView(rootView: overlayView)
        window.contentView = hostingView

        return window
    }

    // MARK: - Hearthstone Window Tracking

    private func findHearthstoneWindow() -> CGRect? {
        let options = CGWindowListOption(arrayLiteral: [.optionOnScreenOnly, .excludeDesktopElements])
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for info in windowList {
            if let ownerName = info["kCGWindowOwnerName"] as? String,
               ownerName == "Hearthstone",
               let boundsDict = info["kCGWindowBounds"] as? [String: CGFloat],
               let x = boundsDict["X"],
               let y = boundsDict["Y"],
               let w = boundsDict["Width"],
               let h = boundsDict["Height"],
               w > 300, h > 300 {
                return CGRect(x: x, y: y, width: w, height: h)
            }
        }
        return nil
    }

    func positionNextToHearthstone() {
        guard let hsFrame = findHearthstoneWindow(), let win = window else {
            // 炉石未运行，恢复普通窗口级别并放在屏幕右上角
            window?.level = .floating
            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                window?.setFrameOrigin(NSPoint(x: sf.maxX - 340, y: sf.maxY - 500))
            }
            return
        }
        
        // 检测到炉石窗口，提升到屏蔽级别（覆盖全屏游戏）
        window?.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        lastHearthstoneFrame = hsFrame
        
        // 如果用户正在拖拽，不自动定位
        guard !isDragging else { return }

        let gap: CGFloat = 0
        let overlayWidth = UserDefaults.standard.object(forKey: "overlayWidth") as? Double ?? 280
        let insideGame = UserDefaults.standard.bool(forKey: "overlayInsideGame")
        
        // 匹配游戏窗口高度
        let overlayHeight = hsFrame.height * 0.92
        let newSize = NSSize(width: overlayWidth, height: overlayHeight)
        win.setContentSize(newSize)

        let origin: NSPoint
        if insideGame {
            // 游戏界面内部
            switch preferredSide {
            case .right:
                origin = NSPoint(
                    x: hsFrame.maxX - overlayWidth - 10,
                    y: hsFrame.minY + hsFrame.height * 0.04
                )
            case .left:
                origin = NSPoint(
                    x: hsFrame.minX + 10,
                    y: hsFrame.minY + hsFrame.height * 0.04
                )
            }
        } else {
            // 游戏窗口外侧
            switch preferredSide {
            case .right:
                origin = NSPoint(
                    x: hsFrame.maxX + gap,
                    y: hsFrame.minY
                )
            case .left:
                origin = NSPoint(
                    x: hsFrame.minX - overlayWidth - gap,
                    y: hsFrame.minY
                )
            }
        }

        win.setFrameOrigin(origin)
        win.setContentSize(newSize)
    }

    private func startPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, !self.isDragging else { return }
            self.positionNextToHearthstone()
        }
    }

    private func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
}

// MARK: - NSWindowDelegate
extension OverlayWindowController: NSWindowDelegate {
    func windowWillMove(_ notification: Notification) {
        isDragging = true
    }
    
    func windowDidMove(_ notification: Notification) {
        // 用户停止拖拽后，判断是否要切换侧边
        isDragging = false
        
        guard let win = window, let hsFrame = findHearthstoneWindow() else { return }
        
        let winCenter = win.frame.midX
        let hsCenter = hsFrame.midX
        
        // 如果悬浮窗在游戏窗口中心另一侧，切换侧边
        if winCenter < hsCenter {
            preferredSide = .left
        } else {
            preferredSide = .right
        }
        
        // 拖拽后重新吸附对齐
        positionNextToHearthstone()
    }
}
