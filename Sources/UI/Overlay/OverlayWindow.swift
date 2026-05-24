import SwiftUI
import AppKit

/// 悬浮窗控制器：管理透明悬浮窗口，贴合炉石传说窗口
final class OverlayWindowController: NSObject, @unchecked Sendable {
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
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
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
            // 炉石未运行，放在屏幕右上角
            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                window?.setFrameOrigin(NSPoint(x: sf.maxX - 340, y: sf.maxY - 500))
            }
            return
        }

        lastHearthstoneFrame = hsFrame
        
        // 如果用户正在拖拽，不自动定位
        guard !isDragging else { return }

        let overlaySize = win.frame.size
        let gap: CGFloat = 0 // 紧密贴合，无间隙

        let origin: NSPoint
        switch preferredSide {
        case .right:
            origin = NSPoint(
                x: hsFrame.maxX + gap,
                y: hsFrame.maxY - overlaySize.height
            )
        case .left:
            origin = NSPoint(
                x: hsFrame.minX - overlaySize.width - gap,
                y: hsFrame.maxY - overlaySize.height
            )
        }

        win.setFrameOrigin(origin)
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
