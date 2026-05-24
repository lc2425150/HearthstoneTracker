import Foundation
import Combine

/// 事件管道：连接日志解析器与核心状态机，转换原始事件为应用事件
@MainActor
final class EventPipeline: ObservableObject {
    // MARK: - Properties

    private let logParser: PowerLogParser
    private let logWatcher: LogFileWatcher
    private let cardDatabase: CardDatabase

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published

    @Published var cardEvents = PassthroughSubject<CardEvent, Never>()
    let onGameStart = PassthroughSubject<Void, Never>()

    // MARK: - Init

    init(database: CardDatabase) {
        self.cardDatabase = database
        self.logParser = PowerLogParser(database: database)
        self.logWatcher = LogFileWatcher(parser: logParser)

        setupEventForwarding()
    }

    // MARK: - Public

    func start() {
        logWatcher.startWatching(paths: Constants.logFilePaths)
    }

    func stop() {
        logWatcher.stopWatching()
    }

    // MARK: - Private

    private func setupEventForwarding() {
        logParser.onEvent = { [weak self] parsed in
            self?.convertAndForward(parsed)
        }
        
        logParser.onGameStart = { [weak self] in
            guard let self else { return }
            // 检测到新游戏，触发自动导入
            self.onGameStart.send()
        }
    }

    private func convertAndForward(_ parsed: ParsedLogEvent) {
        let eventType = convertEventType(parsed.type)
        let confidence = calculateConfidence(for: parsed, eventType: eventType)

        let event = CardEvent(
            type: eventType,
            card: parsed.card,
            player: parsed.player,
            timestamp: parsed.timestamp,
            confidence: confidence,
            metadata: [
                "entityId": parsed.entityId,
                "parsedType": String(describing: parsed.type)
            ]
        )

        DispatchQueue.main.async {
            self.cardEvents.send(event)
        }
    }

    private func convertEventType(_ parsed: ParsedEventType) -> CardEventType {
        switch parsed {
        case .draw:
            return .draw
        case .play:
            return .play
        case .destroy:
            return .destroy
        case .returnToDeck:
            return .discard // 近似处理
        case .created:
            return .create
        case .unknown:
            return .play // fallback
        }
    }

    private func calculateConfidence(for parsed: ParsedLogEvent, eventType: CardEventType) -> Double {
        var base: Double = 0.8

        // 根据事件类型调整置信度
        switch parsed.type {
        case .draw, .play:
            base = 0.95
        case .destroy:
            base = 0.9
        case .created:
            base = 0.85
        case .returnToDeck:
            base = 0.7
        case .unknown:
            base = 0.5
        }

        // 卡牌识别度调整
        if parsed.card.name.contains("未知") {
            base *= 0.6
        }

        return min(max(base, 0.0), 1.0)
    }
}