import SwiftUI
import AppKit

/// AI 建议悬浮窗控制器
final class AISuggestionWindowController: NSObject, NSWindowDelegate {
    static let shared = AISuggestionWindowController()
    private var window: NSWindow?
    private var isVisible = false
    
    func show(core: CardTrackerCore? = nil) {
        if window == nil {
            window = createWindow(core: core)
        }
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
    }
    
    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggle(core: CardTrackerCore? = nil) {
        if isVisible { hide() } else { show(core: core) }
    }
    
    private func createWindow(core: CardTrackerCore? = nil) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 280),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.delegate = self
        
        if let panel = window as? NSPanel {
            panel.isFloatingPanel = true
        }
        
        window.contentMinSize = NSSize(width: 280, height: 160)
        window.contentMaxSize = NSSize(width: 500, height: 500)
        
        // AIPanelView 不再需要 EnvironmentObject，改为可选 core 参数
        let contentView = AIPanelView(core: core)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hostingView
        
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: sf.maxX - 380, y: sf.midY - 140))
        }
        
        return window
    }
}

/// AI 建议面板视图
struct AIPanelView: View {
    @StateObject private var aiManager = AIManager.shared
    let core: CardTrackerCore?
    @State private var suggestion: AISuggestion?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var statusSummary: String = ""
    
    init(core: CardTrackerCore? = nil) {
        self.core = core
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.purple)
                    Text("AI 对战建议")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if let core = core {
                        Button(action: {
                            core.aiAnalysisMode = core.aiAnalysisMode == .auto ? .manual : .auto
                            if core.aiAnalysisMode == .auto { core.requestAIAnalysis() }
                        }) {
                            Image(systemName: core.aiAnalysisMode.iconName)
                                .foregroundColor(core.aiAnalysisMode == .auto ? .green : .orange)
                        }
                        .buttonStyle(.plain)
                        .help(core.aiAnalysisMode == .auto ? "手动模式" : "自动实时")
                    }
                    Button(action: { AISuggestionWindowController.shared.hide() }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                Spacer()
                
                if let suggestion = aiManager.lastSuggestion {
                    Text("💡 建议：")
                        .font(.caption).bold().foregroundColor(.purple.opacity(0.8))
                    Text(suggestion.suggestion)
                        .font(.body).foregroundColor(.white)
                    if !suggestion.reasoning.isEmpty {
                        Text(suggestion.reasoning)
                            .font(.caption).foregroundColor(.gray)
                    }
                } else if aiManager.isAnalyzing {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("AI 分析中...").font(.caption).foregroundColor(.gray)
                    }
                } else if let error = aiManager.lastError {
                    Text("⚠️ \(error)").font(.caption).foregroundColor(.orange)
                } else {
                    Text("点击「AI建议」按钮开始分析")
                        .font(.caption).foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .frame(width: 340, height: 280)
    }
}
