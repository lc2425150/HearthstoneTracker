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
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 280),
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
        
        window.contentMinSize = NSSize(width: 280, height: 160)
        window.contentMaxSize = NSSize(width: 500, height: 500)
        
        let hostingView = NSHostingView(rootView: AIPanelView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hostingView
        
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: sf.maxX - 380, y: sf.midY - 140))
        }
        
        return window
    }
}

/// AI 建议面板视图（实时对局分析）
struct AIPanelView: View {
    @StateObject private var aiManager = AIManager.shared
    @EnvironmentObject var core: CardTrackerCore
    @State private var suggestion: AISuggestion?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var statusSummary: String = ""
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                // 标题栏
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("AI 实时分析")
                        .font(.caption).bold()
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    if !statusSummary.isEmpty {
                        Text(statusSummary)
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Text(aiManager.selectedProvider.displayName)
                        .font(.system(size: 7))
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
                
                // 状态概览
                if let deck = core.playerDeck {
                    HStack(spacing: 8) {
                        Label("\(deck.heroClass.displayName)", systemImage: "person.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                        Label("手牌\(deck.handOriginal.count)", systemImage: "hand.raised.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                        Label("牌库\(deck.remainingOriginalCount)", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        if aiManager.lastSuggestion != nil {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // 内容
                if isAnalyzing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("分析当前局面...")
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
                        VStack(alignment: .leading, spacing: 4) {
                            // 主要建议（一行）
                            Text(sug.suggestion)
                                .font(.subheadline).bold()
                                .foregroundColor(.green.opacity(0.9))
                            
                            if !sug.reasoning.isEmpty {
                                Text(sug.reasoning)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(8)
                            }
                        }
                    }
                    .frame(minHeight: 60)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.3))
                        Text("等待分析...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                        if !core.aiApiKey.isEmpty {
                            Text("抽牌或出牌时将自动分析")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                // 底部按钮
                HStack {
                    Button(action: {
                        errorMessage = nil
                        isAnalyzing = true
                        Task { @MainActor in
                            core.requestAIAnalysis()
                            suggestion = aiManager.lastSuggestion
                            errorMessage = aiManager.lastError
                            isAnalyzing = aiManager.isAnalyzing
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                            Text("刷新")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAnalyzing)
                    
                    if suggestion != nil {
                        Text("\(suggestion!.timestamp.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    Spacer()
                    
                    // 自动分析状态指示
                    HStack(spacing: 3) {
                        Circle()
                            .fill(aiManager.enableAutoAnalyze ? Color.green : Color.gray)
                            .frame(width: 5, height: 5)
                        Text(aiManager.enableAutoAnalyze ? "自动" : "手动")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(12)
        }
        .frame(minWidth: 280, minHeight: 160)
        .onReceive(NotificationCenter.default.publisher(for: .newAISuggestion)) { notification in
            if let sug = notification.object as? AISuggestion {
                suggestion = sug
                isAnalyzing = false
                errorMessage = nil
                AISuggestionWindowController.shared.show()
            }
        }
        .onReceive(core.$playerDeck) { deck in
            if let deck = deck {
                statusSummary = "\(deck.handOriginal.count)手 | \(deck.remainingOriginalCount)库"
            }
        }
        .onAppear {
            if let deck = core.playerDeck {
                statusSummary = "\(deck.handOriginal.count)手 | \(deck.remainingOriginalCount)库"
            }
        }
    }
}
