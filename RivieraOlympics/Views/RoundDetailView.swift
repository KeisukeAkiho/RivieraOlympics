import SwiftUI

struct RoundDetailView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID
    @State private var showGames = false

    private var round: GolfRound? {
        store.rounds.first(where: { $0.id == roundId })
    }

    var body: some View {
        Group {
            if let round {
                VStack(spacing: 0) {
                    ScorecardTablesView(roundId: roundId)
                        .frame(maxHeight: .infinity)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("競技: \(CompetitionGamesSection.summaryLabel(round.options))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Button("競技内容") {
                                showGames = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RivieraTheme.fairway)

                            NavigationLink("設定") {
                                OptionsView(roundId: roundId)
                            }
                            .buttonStyle(.bordered)

                            NavigationLink("精算") {
                                SettlementView(roundId: roundId)
                            }
                            .buttonStyle(.bordered)

                            if round.isSettled {
                                Text("確定済")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .navigationTitle(round.title)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { store.activeRoundId = roundId }
                .sheet(isPresented: $showGames) {
                    NavigationStack {
                        CompetitionGamesView(roundId: roundId)
                            .environmentObject(store)
                    }
                }
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "flag.slash")
            }
        }
    }
}
