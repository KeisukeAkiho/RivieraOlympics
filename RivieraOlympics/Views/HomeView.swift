import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: RoundStore
    @State private var showNew = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RivieraTheme.fairwayDeep, RivieraTheme.fairway.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            List {
                Section {
                    Button {
                        showNew = true
                    } label: {
                        Label("新しいラウンド", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .disabled(store.players.count < 2)
                    if store.players.count < 2 {
                        Text("先にプレイヤーを2人以上登録してください。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("保存済みラウンド") {
                    if store.rounds.isEmpty {
                        Text("まだラウンドがありません。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.rounds) { round in
                        NavigationLink {
                            RoundDetailView(roundId: round.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(round.title).font(.headline)
                                    if round.isSettled {
                                        Text("精算済")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(RivieraTheme.sand)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(round.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(round.players.map(\.name).joined(separator: " · "))
                                    .font(.caption2)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteRound(id: round.id)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("リビエラオリンピック")
        .sheet(isPresented: $showNew) {
            NewRoundView()
        }
    }
}
