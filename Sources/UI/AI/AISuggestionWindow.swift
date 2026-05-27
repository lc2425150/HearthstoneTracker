import SwiftUI
import AppKit

/// AI 建议悬浮窗控制器
final class AISuggestionWindowController: NSObject, NSWindowDelegate {
    static let shared = AISuggestionWindowController()
    private var window: NSWindow?
    private var isVisible = false
    
    func show() {
        if window == nil {
            window = createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
    }
    
    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggle() {
        if isVisible { hide() } else { show() }
    }
    
    private func createWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.delegate = self
        
        if let panel = window as? NSPanel {
            panel.isFloatingPanel = true
        }
        
        window.contentMinSize = NSSize(width: 280, height: 120)
        window.contentMaxSize = NSSize(width: 500, height: 500)
        
        let hostingView = NSHostingView(rootView: AIPanelView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hostingView
        
        // 放在屏幕右中位置
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: sf.maxX - 360, y: sf.midY - 100))
        }
        
        return window
    }
}

/// AI 建议面板视图
struct AIPanelView: View {
    @StateObject private var aiManager = AIManager.shared
    @State private var suggestion: AISuggestion?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 8) {
                // 标题栏
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("AI 出牌建议")
                        .font(.caption).bold()
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(aiManager.selectedProvider.displayName)
                        .font(.system(size: 8))
                        .foregroundColor(.purple.opacity(0.6))
                        .padding(.horizontal, 4)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(3)
                    
                    Button(action: { AISuggestionWindowController.shared.hide() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // 内容
                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("分析中...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                } else if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else if let sug = suggestion {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sug.suggestion)
                                .font(.subheadline).bold()
                                .foregroundColor(.green.opacity(0.9))
                            if !sug.reasoning.isEmpty {
                                Text(sug.reasoning)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(6)
                            }
                        }
                    }
                    .frame(minHeight: 60)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
                        Text("点击分析获取出牌建议")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // 底部按钮
                HStack {
                    Button(action: {
                        errorMessage = nil
                        isAnalyzing = true
                        Task {
                            await aiManager.analyzeGameScreen()
                            await MainActor.run {
                                suggestion = aiManager.lastSuggestion
                                errorMessage = aiManager.lastError
                                isAnalyzing = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text("分析")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzing)
                    
                    Spacer()
                    
                    if suggestion != nil {
                        Text("\(suggestion!.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(12)
        }
        .frame(minWidth: 280, minHeight: 120)
        .onReceive(NotificationCenter.default.publisher(for: .newAISuggestion)) { notification in
            if let sug = notification.object as? AISuggestion {
                suggestion = sug
                isAnalyzing = false
                errorMessage = nil
                // 自动显示窗口
                AISuggestionWindowController.shared.show()
            }
        }
    }
}
