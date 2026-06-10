import SwiftUI
import AppKit

/// 悬浮窗控制器：管理透明悬浮窗口，贴合炉石传说窗口
final class OverlayWindowController: NSObject, @unchecked Sendable {
    
    func updateLockState(locked: Bool) {
        guard let win = window else { return }
        updateWindowLockState(window: win, locked: locked)
        // 锁定（自动吸附）后对齐到游戏窗口
        if locked {
            positionNextToHearthstone()
        }
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
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        if let panel = window as? NSPanel {
            panel.isFloatingPanel = true
        }
        
        let initialLocked = UserDefaults.standard.object(forKey: "windowsLocked") as? Bool ?? false
        updateWindowLockState(window: window, locked: initialLocked)
        
        // 使用 HSTracker 风格的窗口层级
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.delegate = self

        let overlayView = OverlayView().environmentObject(core)
        let hostingView = NSHostingView(rootView: overlayView)
        window.contentView = hostingView
        
        // 最小/最大内容尺寸
        window.contentMinSize = NSSize(width: 180, height: 200)
        window.contentMaxSize = NSSize(width: 600, height: NSScreen.main?.frame.height ?? 1200)

        return window
    }
    
    /// 根据锁定状态更新窗口样式
    /// - locked = true: 自动吸附模式（跟随游戏窗口）
    /// - locked = false: 手动模式（保持用户位置）
    /// 两种模式都可拖动、可点击、可调整大小
    private func updateWindowLockState(window: NSWindow, locked: Bool) {
        // 始终可点击、可拖动
        window.styleMask = [.titled, .miniaturizable, .resizable, .borderless, .nonactivatingPanel, .fullSizeContentView]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = true
        window.isMovable = true
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
        guard let win = window else { return }
        
        // 检测炉石窗口或全屏显示模式
        let locked = UserDefaults.standard.object(forKey: "windowsLocked") as? Bool ?? false
        guard !isDragging, locked else { return }
        
        if let hsFrame = findHearthstoneWindow() {
            // 检测到炉石窗口（窗口模式或全屏），提升到屏蔽级别
            win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            lastHearthstoneFrame = hsFrame
            
            let overlayWidth = UserDefaults.standard.object(forKey: "overlayWidth") as? Double ?? 280
            let insideGame = UserDefaults.standard.bool(forKey: "overlayInsideGame")
            
            // 匹配游戏窗口高度
            let overlayHeight = hsFrame.height * 0.92
            win.setContentSize(NSSize(width: overlayWidth, height: overlayHeight))

            let origin: NSPoint
            if insideGame {
                switch preferredSide {
                case .right:
                    origin = NSPoint(x: hsFrame.maxX - overlayWidth - 10, y: hsFrame.minY + hsFrame.height * 0.04)
                case .left:
                    origin = NSPoint(x: hsFrame.minX + 10, y: hsFrame.minY + hsFrame.height * 0.04)
                }
            } else {
                switch preferredSide {
                case .right:
                    origin = NSPoint(x: hsFrame.maxX, y: hsFrame.minY)
                case .left:
                    origin = NSPoint(x: hsFrame.minX - overlayWidth, y: hsFrame.minY)
                }
            }
            win.setFrameOrigin(origin)
        } else {
            // 未找到炉石窗口：检查是否在全屏显示模式
            // 使用 CGShieldingWindowLevel 保持覆盖全屏应用
            win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            
            // 放在屏幕左侧或右侧（全屏时贴合屏幕边缘）
            if let screen = NSScreen.main {
                let sf = screen.frame
                let overlayWidth = UserDefaults.standard.object(forKey: "overlayWidth") as? Double ?? 280
                let overlayHeight = sf.height * 0.92
                win.setContentSize(NSSize(width: overlayWidth, height: overlayHeight))
                
                let origin: NSPoint
                switch preferredSide {
                case .right:
                    origin = NSPoint(x: sf.maxX - overlayWidth, y: sf.minY)
                case .left:
                    origin = NSPoint(x: sf.minX, y: sf.minY)
                }
                win.setFrameOrigin(origin)
            }
        }
    }

    private var wasHearthstoneActive = false
    private var overlayHiddenBySwitch = false
    
    private func startPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isDragging else { return }
            
            // 自动隐藏：检查炉石是否是当前活跃应用
            let isActive = self.isHearthstoneFrontmost()
            let autoHide = UserDefaults.standard.bool(forKey: "overlayAutoHide")
            
            if autoHide {
                if !isActive && !self.overlayHiddenBySwitch {
                    // 用户切到其他应用 → 隐藏悬浮窗
                    self.overlayHiddenBySwitch = true
                    self.window?.orderOut(nil)
                } else if isActive && self.overlayHiddenBySwitch {
                    // 用户切回炉石 → 显示悬浮窗
                    self.overlayHiddenBySwitch = false
                    self.window?.orderFront(nil)
                    self.positionNextToHearthstone()
                }
            } else if self.overlayHiddenBySwitch {
                // 关闭自动隐藏时恢复显示
                self.overlayHiddenBySwitch = false
                self.window?.orderFront(nil)
            }
            
            self.positionNextToHearthstone()
        }
    }
    
    /// 检查炉石是否是当前最前端的应用
    private func isHearthstoneFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.blizzard.heartstone" ||
               frontApp.localizedName == "Hearthstone" ||
               frontApp.bundleIdentifier?.contains("heartstone") == true ||
               frontApp.bundleIdentifier?.contains("blizzard") == true
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
        isDragging = false
        
        // 解锁模式下不自动吸附，保持用户拖拽位置
        let locked = UserDefaults.standard.object(forKey: "windowsLocked") as? Bool ?? false
        if !locked { return }
        
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
