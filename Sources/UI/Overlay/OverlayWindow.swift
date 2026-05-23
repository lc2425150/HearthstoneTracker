import SwiftUI
import AppKit

/// 悬浮窗控制器：管理透明悬浮窗口的生命周期和属性
final class OverlayWindowController: @unchecked Sendable {
    static let shared = OverlayWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            window = createOverlayWindow()
        }
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func createOverlayWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 悬浮窗核心属性
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.isMovable = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        // 默认位置：屏幕右上角
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 340
            let y = screenFrame.maxY - 500
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // SwiftUI OverlayView 作为内容
        let overlayView = OverlayView()
        let hostingView = NSHostingView(rootView: overlayView)
        window.contentView = hostingView

        return window
    }
}

// MARK: - Core 扩展：悬浮窗控制

extension CardTrackerCore {
    func toggleOverlay() {
        OverlayWindowController.shared.toggle()
        isOverlayVisible.toggle()
    }
}