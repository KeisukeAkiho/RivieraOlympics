import SwiftUI

struct RoundDetailView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID

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

                    HStack(spacing: 12) {
                        NavigationLink("設定") {
                            OptionsView(roundId: roundId)
                        }
                        .buttonStyle(.bordered)

                        NavigationLink("精算") {
                            SettlementView(roundId: roundId)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RivieraTheme.fairway)

                        if round.isSettled {
                            Text("確定済")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                }
                .navigationTitle(round.title)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { store.activeRoundId = roundId }
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "flag.slash")
            }
        }
    }
}
