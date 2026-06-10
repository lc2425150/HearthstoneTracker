import Cocoa
import SwiftUI

/// 牌库追踪悬浮窗（基于 HSTracker OverWindowController）
final class TrackerWindowController: OverWindowController {
    
    private var hostingView: NSHostingView<AnyView>?
    private var cardBarListView: CardBarListView?
    
    // MARK: - SwiftUI 内容初始化
    
    init(contentView: some View, title: String) {
        let hosting = NSHostingView(rootView: AnyView(contentView))
        self.hostingView = hosting
        super.init(window: nil)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        self.window = window
        window.title = title
        windowDidLoad()
    }
    
    // MARK: - CardBar 原生内容初始化
    
    /// 使用 AppKit 原生 CardBar 创建牌库追踪窗（性能更优）
    init(cards: [CardBarView.Configuration], title: String, theme: CardBarTheme = .minimal) {
        let listView = CardBarListView(frame: NSRect(x: 0, y: 0, width: 280, height: 400))
        listView.setCards(cards)
        self.cardBarListView = listView
        super.init(window: nil)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: listView.frame.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = listView
        self.window = window
        window.title = title
        windowDidLoad()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        // 可添加 Tracker 特有配置
    }
    
    // MARK: - 更新卡牌列表（原生模式）
    
    /// 刷新显示的卡牌
    func updateCards(_ configs: [CardBarView.Configuration]) {
        cardBarListView?.setCards(configs)
        // 自适应窗口高度
        if let listView = cardBarListView {
            window?.setFrame(
                NSRect(x: window?.frame.origin.x ?? 0,
                       y: window?.frame.origin.y ?? 0,
                       width: window?.frame.width ?? 280,
                       height: listView.frame.height + 10),
                display: true
            )
        }
    }
}
