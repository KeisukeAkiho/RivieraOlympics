import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: RoundStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("ラウンド", systemImage: "flag.fill") }

            NavigationStack {
                PlayersView()
            }
            .tabItem { Label("プレイヤー", systemImage: "person.3.fill") }

            NavigationStack {
                SettlementView()
            }
            .tabItem { Label("精算", systemImage: "yensign.circle") }

            NavigationStack {
                RulebookView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("ルール", systemImage: "book.fill") }
        }
        .tint(RivieraTheme.fairway)
    }
}
