import SwiftUI

struct ContentView: View {
    @EnvironmentObject var cardService: CardDataService
    @EnvironmentObject var trackingService: TrackingService
    @State private var selectedTab: Tab = .decks

    enum Tab: String, CaseIterable {
        case decks = "牌库"
        case match = "对战"
        case stats = "统计"
        case settings = "设置"

        var icon: String {
            switch self {
            case .decks: return "rectangle.stack"
            case .match: return "play.circle"
            case .stats: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DeckLibraryView()
            }
            .tabItem {
                Label(Tab.decks.rawValue, systemImage: Tab.decks.icon)
            }
            .tag(Tab.decks)

            NavigationStack {
                LiveMatchView()
            }
            .tabItem {
                Label(Tab.match.rawValue, systemImage: Tab.match.icon)
            }
            .tag(Tab.match)

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label(Tab.stats.rawValue, systemImage: Tab.stats.icon)
            }
            .tag(Tab.stats)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
            }
            .tag(Tab.settings)
        }
        .onChange(of: trackingService.isTracking) { _, isTracking in
            if isTracking {
                selectedTab = .match
            }
        }
    }
}
