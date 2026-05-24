import SwiftUI
import SwiftData

@main
struct HearthstoneTrackerApp: App {
    let modelContainer: ModelContainer

    @StateObject private var cardService: CardDataService
    @StateObject private var trackingService: TrackingService
    @State private var isLoadingData = true
    @State private var loadError: String?

    init() {
        do {
            let schema = Schema([
                Card.self,
                SavedDeck.self,
                MatchRecord.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: config)
            self.modelContainer = container

            let cardSvc = CardDataService(modelContext: container.mainContext)
            let trackSvc = TrackingService(
                modelContext: container.mainContext,
                cardService: cardSvc
            )
            _cardService = StateObject(wrappedValue: cardSvc)
            _trackingService = StateObject(wrappedValue: trackSvc)
        } catch {
            fatalError("数据库初始化失败: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if isLoadingData {
                LoadingView()
                    .task {
                        await initializeData()
                    }
            } else if let error = loadError {
                ErrorView(error: error) {
                    Task { await initializeData() }
                }
            } else {
                ContentView()
                    .environmentObject(cardService)
                    .environmentObject(trackingService)
                    .modelContainer(modelContainer)
            }
        }
    }

    private func initializeData() async {
        isLoadingData = true
        loadError = nil

        // 检查是否有卡牌数据
        if cardService.cardCount() == 0 || cardService.needsUpdate() {
            do {
                let _ = try await cardService.updateCardData()
            } catch {
                loadError = "卡牌数据加载失败: \(error.localizedDescription)"
                isLoadingData = false
                return
            }
        }

        isLoadingData = false
    }
}

// MARK: - 加载视图

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)

            Text("炉边记牌器")
                .font(.largeTitle)
                .bold()

            ProgressView()
                .scaleEffect(1.2)

            Text("正在加载卡牌数据...")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 错误视图

struct ErrorView: View {
    let error: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("加载失败")
                .font(.title2)
                .bold()

            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("重试") {
                Task { await retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
