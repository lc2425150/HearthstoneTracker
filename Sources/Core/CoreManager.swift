import Foundation
import Combine

/// HSTracker 风格的核心协调器
/// 注意：实际业务由 CardTrackerCore 管理，CoreManager 作为备用扩展点
/// 使用 configure(database:) 初始化数据库，避免创建独立实例
@MainActor
final class CoreManager {
    
    static let shared = CoreManager()
    
    let settings = Settings.shared
    private(set) var cardDatabase: CardDatabase?
    private(set) var ocrScanner: VisionOCRScanner?
    private(set) var opponentTracker: OpponentCardTracker?
    private(set) var eventPipeline: EventPipeline?
    private(set) var cardDataUpdater: CardDataUpdater?
    
    lazy var game: GameManager = {
        GameManager(core: self)
    }()
    
    private init() {
        // 不创建 CardDatabase，使用 configure 注入
    }
    
    /// 配置数据库依赖（共享 CardTrackerCore 的实例）
    func configure(database: CardDatabase) {
        self.cardDatabase = database
        self.ocrScanner = VisionOCRScanner(database: database)
        self.opponentTracker = OpponentCardTracker(database: database)
        self.eventPipeline = EventPipeline(database: database)
        self.cardDataUpdater = CardDataUpdater(database: database)
    }
}
