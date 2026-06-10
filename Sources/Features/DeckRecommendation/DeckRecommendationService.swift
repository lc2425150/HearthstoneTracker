import Foundation
import AppKit
import Combine

// MARK: - 卡组推荐服务

/// 从多个来源获取热门卡组数据，提供卡组推荐功能
@MainActor
final class DeckRecommendationService: ObservableObject {
    
    static let shared = DeckRecommendationService()
    
    // MARK: - Published State
    
    @Published private(set) var recommendedDecks: [RecommendedDeck] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastRefreshDate: Date?
    @Published var selectedFormat: DeckFormat = .standard
    
    // MARK: - Cache
    
    private let cacheKey = "cached_recommended_decks"
    private let cacheDateKey = "cached_recommended_decks_date"
    private let cacheFormatKey = "cached_recommended_decks_format"
    
    // MARK: - Init
    
    private init() {
        loadFromCache()
        // 如果缓存为空，立即加载默认数据
        if recommendedDecks.isEmpty {
            recommendedDecks = BuiltinDeckDatabase.standardDecks
            saveToCache()
        }
    }
    
    // MARK: - Public API
    
    /// 刷新卡组数据（先尝试在线，失败则用内置）
    func refresh() async {
        isLoading = true
        lastError = nil
        
        do {
            // 尝试从 HSReplay 获取
            if try await fetchFromHSReplay() {
                isLoading = false
                return
            }
        } catch {
            print("[DeckRecommendation] HSReplay fetch failed: \(error)")
        }
        
        // 在线获取失败，使用内置数据
        print("[DeckRecommendation] 使用内置卡组数据库")
        recommendedDecks = BuiltinDeckDatabase.standardDecks
        lastError = "使用内置卡组数据（无法连接到在线数据源）"
        saveToCache()
        isLoading = false
    }
    
    /// 按职业获取推荐卡组
    func decks(forClass playerClass: String) -> [RecommendedDeck] {
        recommendedDecks.filter { $0.playerClass.uppercased() == playerClass.uppercased() }
    }
    
    /// 按职业分组
    func groupedByClass() -> [String: [RecommendedDeck]] {
        Dictionary(grouping: recommendedDecks, by: { $0.playerClass })
    }
    
    /// 获取所有职业列表
    var allClasses: [String] {
        Array(Set(recommendedDecks.map { $0.playerClass })).sorted()
    }
    
    /// 复制卡组代码到剪贴板
    static func copyDeckCode(_ deckCode: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(deckCode, forType: .string)
    }
    
    /// 清除缓存并重置
    func resetToBuiltin() {
        recommendedDecks = BuiltinDeckDatabase.standardDecks
        lastError = nil
        saveToCache()
    }
    
    // MARK: - HSReplay API
    
    private func fetchFromHSReplay() async throws -> Bool {
        let headers = ["User-Agent": "HearthstoneTracker/1.4.0 (Mac OS X 14.0+)"]
        
        guard let url = URL(string: "https://hsreplay.net/api/v1/archetypes/") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = 8
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        let archetypes = try JSONDecoder().decode([HSReplayArchetype].self, from: data)
        
        // 将 HSReplay 数据与内置卡组代码合并
        var mergedDecks: [RecommendedDeck] = []
        let builtinLookup = Dictionary(uniqueKeysWithValues: 
            BuiltinDeckDatabase.standardDecks.map { ($0.id, $0) })
        
        for archetype in archetypes where builtinLookup[archetype.id] != nil {
            if var deck = builtinLookup[archetype.id] {
                deck = RecommendedDeck(
                    id: deck.id,
                    name: archetype.name,
                    nameCN: deck.nameCN,
                    playerClass: archetype.playerClassName,
                    deckCode: deck.deckCode,
                    winRate: deck.winRate,  // HSReplay 在线 API 没有胜率
                    totalGames: deck.totalGames,
                    cost: deck.cost,
                    isStandard: deck.isStandard,
                    lastUpdated: Date()
                )
                mergedDecks.append(deck)
            }
        }
        
        // 补充未在 HSReplay 返回中的内置卡组
        let hsReplayIds = Set(archetypes.map { $0.id })
        for deck in BuiltinDeckDatabase.standardDecks where !hsReplayIds.contains(deck.id) {
            mergedDecks.append(deck)
        }
        
        if !mergedDecks.isEmpty {
            recommendedDecks = mergedDecks
            saveToCache()
            return true
        }
        
        return false
    }
    
    // MARK: - Local Cache
    
    private func saveToCache() {
        if let encoded = try? JSONEncoder().encode(recommendedDecks) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
            UserDefaults.standard.set(selectedFormat.rawValue, forKey: cacheFormatKey)
        }
    }
    
    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decks = try? JSONDecoder().decode([RecommendedDeck].self, from: data) else {
            return
        }
        recommendedDecks = decks
        lastRefreshDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date
        if let formatRaw = UserDefaults.standard.string(forKey: cacheFormatKey),
           let format = DeckFormat(rawValue: formatRaw) {
            selectedFormat = format
        }
    }
}

// MARK: - HSReplay API Response

struct HSReplayArchetype: Codable {
    let id: Int
    let name: String
    let playerClass: Int
    let playerClassName: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, playerClass = "player_class", playerClassName = "player_class_name"
    }
}

// MARK: - Deck Format

enum DeckFormat: String, CaseIterable, Codable {
    case standard = "standard"
    case wild = "wild"
    
    var displayName: String {
        switch self {
        case .standard: return "标准模式"
        case .wild: return "狂野模式"
        }
    }
}
