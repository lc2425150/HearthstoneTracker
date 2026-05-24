import SwiftUI
import AppKit

/// 悬浮窗控制器：管理透明悬浮窗口，贴合炉石传说窗口
final class OverlayWindowController: @unchecked Sendable {
    static let shared = OverlayWindowController()
    private var window: NSWindow?
    private var positionTimer: Timer?
    private var preferredSide: OverlaySide = .right

    enum OverlaySide {
        case left, right
    }

    func show(core: CardTrackerCore) {
        if window == nil {
            window = createOverlayWindow(core: core)
        } else {
            // 重新注入最新的 core（环境对象可能已变化）
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

    // MARK: - Window Creation

    private func createOverlayWindow(core: CardTrackerCore) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

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
            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                window?.setFrameOrigin(NSPoint(x: sf.maxX - 340, y: sf.maxY - 500))
            }
            return
        }

        let overlaySize = win.frame.size
        let gap: CGFloat = 0

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
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.positionNextToHearthstone()
        }
    }

    private func stopPositionTracking() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
}

// MARK: - Core 扩展：悬浮窗控制

extension CardTrackerCore {
    func toggleOverlay() {
        OverlayWindowController.shared.toggle(core: self)
        isOverlayVisible.toggle()
    }
}