import SwiftUI

struct RoundDetailView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss
    let roundId: UUID
    @State private var showGames = false
    @State private var showDeleteConfirm = false

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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                store.toggleArchiveRound(id: roundId)
                            } label: {
                                Label(
                                    round.isArchived ? "アーカイブから復元" : "アーカイブ（非表示）",
                                    systemImage: round.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
                                )
                            }
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("ラウンドを削除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .onAppear { store.activeRoundId = roundId }
                .sheet(isPresented: $showGames) {
                    NavigationStack {
                        CompetitionGamesView(roundId: roundId)
                            .environmentObject(store)
                    }
                }
                .alert("ラウンドを削除しますか？", isPresented: $showDeleteConfirm) {
                    Button("削除", role: .destructive) {
                        store.deleteRound(id: roundId)
                        dismiss()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("「\(round.title)」を完全に削除します。この操作は元に戻せません。")
                }
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "flag.slash")
            }
        }
    }
}
