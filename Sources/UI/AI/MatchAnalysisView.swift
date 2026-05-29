import SwiftUI
import AppKit

/// 对局 AI 分析面板（赛后分析 + 历史趋势）
struct MatchAnalysisView: View {
    @EnvironmentObject var core: CardTrackerCore
    @StateObject private var aiManager = AIManager.shared
    
    @State private var selectedAnalysis: AnalysisType = .matchHistory
    @State private var analysisResult: AISuggestion?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var selectedMatchIndex: Int = 0
    
    enum AnalysisType: String, CaseIterable {
        case matchHistory = "历史分析"
        case deckAnalysis = "卡组分析"
        case lastMatch = "最近对局"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI 对局分析")
                    .font(.headline)
                Spacer()
                if core.aiApiKey.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("请先在设置中配置 API Key")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 分析类型选择
            Picker("分析类型", selection: $selectedAnalysis) {
                ForEach(AnalysisType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Divider()
            
            // 分析内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedAnalysis {
                    case .matchHistory:
                        matchHistoryContent
                    case .deckAnalysis:
                        deckAnalysisContent
                    case .lastMatch:
                        lastMatchContent
                    }
                    
                    // 分析结果
                    if let result = analysisResult {
                        analysisResultView(result)
                    } else if isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI 分析中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                    } else if let error = errorMessage {
                        HStack {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 24))
                                .foregroundColor(.purple.opacity(0.4))
                            Text("选择一个分析类型并点击分析按钮")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
                .padding()
            }
            
            // 底部操作
            HStack {
                if analysisResult != nil {
                    Button("清除结果") {
                        analysisResult = nil
                        errorMessage = nil
                        aiManager.clearSuggestion()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Button(action: performAnalysis) {
                    HStack(spacing: 4) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.5)
                        }
                        Image(systemName: "sparkle.magnifyingglass")
                        Text(isAnalyzing ? "分析中..." : "AI 分析")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(core.aiApiKey.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzing || core.aiApiKey.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Match History Content
    
    private var matchHistoryContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分析近 20 场对局趋势，发现模式和改进点")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !core.matchRecords.isEmpty {
                let wins = core.matchRecords.filter { $0.result == .win }.count
                let total = core.matchRecords.count
                HStack {
                    Text("共 \(total) 场 (\(wins) 胜 / \(total - wins) 负)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("胜率 \(total > 0 ? String(format: "%.0f", Double(wins) / Double(total) * 100) : "0")%")
                        .font(.caption)
                        .foregroundColor(wins > total / 2 ? .green : .orange)
                }
            }
        }
    }
    
    // MARK: - Deck Analysis Content
    
    private var deckAnalysisContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let deck = core.playerDeck {
                Text("分析当前卡组的策略与优化建议")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("当前卡组: \(deck.heroClass.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(deck.totalOriginalCount) 张")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !deck.playedOriginal.isEmpty {
                    Text("已打出: \(deck.playedOriginal.map { $0.name }.joined(separator: "、"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("请先导入卡组后再分析")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Last Match Content
    
    private var lastMatchContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let match = core.matchRecords.first {
                Text("分析最近一局对局的得失")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(match.playerClass) vs \(match.opponentClass)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(match.result.displayName)
                        .font(.caption)
                        .foregroundColor(match.result == .win ? .green : .red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((match.result == .win ? Color.green : Color.red).opacity(0.15))
                        .cornerRadius(4)
                }
                
                if !match.notes.isEmpty {
                    Text("备注: \(match.notes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("暂无对局记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Analysis Result View
    
    private func analysisResultView(_ result: AISuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI 分析结果")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Text(result.suggestion)
                .font(.body)
                .foregroundColor(.primary)
            
            if !result.reasoning.isEmpty {
                Text(result.reasoning)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Perform Analysis
    
    private func performAnalysis() {
        guard !isAnalyzing, !core.aiApiKey.isEmpty else { return }
        
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil
        
        Task {
            var result: AISuggestion?
            
            switch selectedAnalysis {
            case .matchHistory:
                let matches = core.matchRecords.prefix(20).map { record in
                    (playerClass: record.playerClass,
                     opponentClass: record.opponentClass,
                     result: record.result.displayName)
                }
                result = await aiManager.analyzeMatchHistory(recentMatches: Array(matches))
                
            case .deckAnalysis:
                if let deck = core.playerDeck {
                    let cards = deck.allOriginalCards.map { (name: $0.card.name, count: $0.count) }
                    result = await aiManager.analyzeDeck(heroClass: deck.heroClass.displayName, cards: cards)
                }
                
            case .lastMatch:
                if let match = core.matchRecords.first {
                    let playerCards = core.opponentPlayedCards.map { $0.name }
                    result = await aiManager.analyzeMatchRecord(
                        playerClass: match.playerClass,
                        opponentClass: match.opponentClass,
                        result: match.result.displayName,
                        duration: Int(match.duration),
                        playerCards: [],
                        opponentCards: playerCards,
                        notes: match.notes
                    )
                }
            }
            
            await MainActor.run {
                analysisResult = result
                errorMessage = aiManager.lastError
                isAnalyzing = false
            }
        }
    }
}
