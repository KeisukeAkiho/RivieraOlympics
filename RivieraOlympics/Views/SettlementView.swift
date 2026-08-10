import SwiftUI

struct SettlementView: View {
    @EnvironmentObject private var store: RoundStore
    var roundId: UUID? = nil
    /// 互換: 直接 round を渡す場合
    var round: GolfRound? = nil
    @State private var showExport = false

    private var resolved: GolfRound? {
        if let roundId, let r = store.rounds.first(where: { $0.id == roundId }) { return r }
        return round ?? store.activeRound
    }

    private var summary: SettlementSummary {
        guard let r = resolved else {
            return SettlementSummary(
                olympicByHole: [], playerTotals: [], lasVegasHoleDiffs: [],
                holeMatchWinnersByHole: [], snakeSegments: [], sonchoWinnerIds: [],
                honestJohn: [], notes: []
            )
        }
        return r.settledSummary ?? SettlementEngine.summarize(r)
    }

    var body: some View {
        Group {
            if let r = resolved {
                List {
                    if r.isSettled {
                        Section {
                            Label("このラウンドは精算確定済みです", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(RivieraTheme.fairway)
                            if let at = r.settledAt {
                                Text(at.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("オリンピック精算（掛け金 \(r.options.stakeRate)）") {
                        Text("計算: (自分の点 × 人数) − 全員の合計点 × 掛け金")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(summary.playerTotals) { t in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(t.name).font(.headline)
                                    Spacer()
                                    Text(yen(t.olympicYen))
                                        .font(.title3.monospacedDigit().weight(.bold))
                                        .foregroundStyle(t.olympicYen >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                                }
                                Text("点 \(t.olympicPoints) · 検算単位 \(t.olympicUnits)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        let sumO = summary.playerTotals.reduce(0) { $0 + $1.olympicYen }
                        HStack {
                            Text("オリンピック合計（検算）")
                            Spacer()
                            Text(yen(sumO)).foregroundStyle(sumO == 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                        }
                        .font(.footnote.weight(.semibold))
                    }

                    Section("ネット精算（全ゲーム）") {
                        ForEach(summary.playerTotals) { t in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(t.name).font(.headline)
                                    if t.isSoncho {
                                        Text("村長")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(RivieraTheme.sand)
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Text(yen(t.netYen))
                                        .font(.title3.monospacedDigit().weight(.bold))
                                        .foregroundStyle(t.netYen >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                                }
                                Text("グロス \(t.grossScore)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                                    GridRow {
                                        Text("オリンピック").foregroundStyle(.secondary)
                                        Text("\(t.olympicPoints)点 → \(yen(t.olympicYen))")
                                    }
                                    GridRow {
                                        Text("ホールマッチ").foregroundStyle(.secondary)
                                        Text("\(t.holeMatchWins)勝 → \(yen(t.holeMatchYen))")
                                    }
                                    GridRow {
                                        Text("ラスベガス").foregroundStyle(.secondary)
                                        Text(yen(t.lasVegasYen))
                                    }
                                    GridRow {
                                        Text("村長").foregroundStyle(.secondary)
                                        Text(yen(t.sonchoYen))
                                    }
                                    GridRow {
                                        Text("蛇").foregroundStyle(.secondary)
                                        Text(yen(t.snakeYen))
                                    }
                                    GridRow {
                                        Text("オネストジョン").foregroundStyle(.secondary)
                                        Text("\(t.honestJohnPoints) → \(yen(t.honestJohnYen))")
                                    }
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        let sumN = summary.playerTotals.reduce(0) { $0 + $1.netYen }
                        HStack {
                            Text("ネット合計（検算）")
                            Spacer()
                            Text(yen(sumN))
                        }
                        .font(.footnote.weight(.semibold))
                    }

                    Section("操作") {
                        Button {
                            showExport = true
                        } label: {
                            Label("写真としてエクスポート", systemImage: "photo.on.rectangle.angled")
                        }

                        if r.isSettled {
                            Button("精算を解除（再編集）", role: .destructive) {
                                store.unsettleRound(id: r.id)
                            }
                        } else {
                            Button {
                                store.settleRound(id: r.id)
                            } label: {
                                Label("精算を確定する", systemImage: "yensign.circle.fill")
                            }
                            Text("確定すると生涯戦績に反映され、スコア編集がロックされます。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !summary.notes.isEmpty {
                        Section("メモ") {
                            ForEach(summary.notes, id: \.self) { note in
                                Text(note).font(.footnote)
                            }
                        }
                    }
                }
                .navigationTitle("精算")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showExport = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("写真としてエクスポート")
                    }
                }
                .sheet(isPresented: $showExport) {
                    SettlementExportSheet(round: r, summary: summary)
                }
            } else {
                ContentUnavailableView(
                    "アクティブなラウンドがありません",
                    systemImage: "chart.bar",
                    description: Text("ラウンドを作成すると精算が表示されます。")
                )
            }
        }
    }

    private func yen(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.positivePrefix = "+"
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}
