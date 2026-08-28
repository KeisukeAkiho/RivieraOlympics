import SwiftUI

struct HoleEntryView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID
    let holeNumber: Int

    @State private var showEditor = false
    @State private var scoreDraft: [UUID: PlayerHoleEntry] = [:]

    private var roundIndex: Int? {
        store.rounds.firstIndex(where: { $0.id == roundId })
    }

    private var holeIndex: Int? {
        guard let ri = roundIndex else { return nil }
        return store.rounds[ri].holes.firstIndex(where: { $0.holeNumber == holeNumber })
    }

    var body: some View {
        Group {
            if let ri = roundIndex, let hi = holeIndex {
                let round = store.rounds[ri]
                let hole = round.holes[hi]
                List {
                    Section {
                        if round.yards(forHole: holeNumber) > 0 {
                            let y = round.yards(forHole: holeNumber)
                            let tee = round.selectedTeeName.isEmpty ? "" : " · \(round.selectedTeeName)"
                            Text("距離 \(y) yd\(tee)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        Text("打数とオリンピック点を同じ画面で ± 入力します。リーチなどは履歴ボタンで残します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("ホール \(holeNumber) · パー \(hole.par)")
                    }

                    Section("スコア") {
                        ForEach(round.players) { player in
                            let entry = hole.entries.first(where: { $0.playerId == player.id })
                                ?? PlayerHoleEntry(playerId: player.id)
                            Button {
                                openEditor(round: round, hole: hole)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.name).foregroundStyle(.primary)
                                        Text(summary(entry))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(entry.strokes > 0 ? "\(entry.strokes)" : "—")
                                        .font(.title2.monospacedDigit().weight(.bold))
                                        .foregroundStyle(RivieraTheme.fairway)
                                }
                            }
                        }
                    }

                    if round.options.olympicsEnabled {
                        Section("このホールのオリンピック（速報）") {
                            let result = OlympicsCalculator.scoreHole(
                                hole: hole,
                                players: round.players,
                                penaltiesEnabled: round.options.penaltiesEnabled,
                                nearestPinCarryIn: hole.nearestPinCarryIn,
                                points: round.options.olympicsPoints,
                                customRules: round.options.customPointRules
                            )
                            ForEach(round.players) { player in
                                let pts = result.perPlayer.first(where: { $0.playerId == player.id })?.totalPoints ?? 0
                                HStack {
                                    Text(player.name)
                                    Spacer()
                                    Text("\(pts) 点")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("ホール \(holeNumber)")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("入力") {
                            openEditor(round: round, hole: hole)
                        }
                    }
                }
                .sheet(isPresented: $showEditor) {
                    CompactScoreEditor(
                        entriesByPlayer: $scoreDraft,
                        players: round.players,
                        holeNumber: holeNumber,
                        par: hole.par,
                        yards: round.yards(forHole: holeNumber),
                        teeName: round.selectedTeeName,
                        round: round,
                        onCommit: {
                            commit(ri: ri, hi: hi)
                            showEditor = false
                        },
                        onCancel: { showEditor = false }
                    )
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
                }
            } else {
                ContentUnavailableView("ホールが見つかりません", systemImage: "flag.slash")
            }
        }
    }

    private func openEditor(round: GolfRound, hole: HoleRecord) {
        var draft: [UUID: PlayerHoleEntry] = [:]
        for p in round.players {
            var e = hole.entries.first(where: { $0.playerId == p.id }) ?? PlayerHoleEntry(playerId: p.id)
            e.playerId = p.id
            if e.strokes == 0 { e.strokes = hole.par }
            draft[p.id] = e
        }
        scoreDraft = draft
        showEditor = true
    }

    private func commit(ri: Int, hi: Int) {
        var r = store.rounds[ri]
        for player in r.players {
            guard var saved = scoreDraft[player.id] else { continue }
            saved.playerId = player.id
            if let ei = r.holes[hi].entries.firstIndex(where: { $0.playerId == player.id }) {
                saved.id = r.holes[hi].entries[ei].id
                r.holes[hi].entries[ei] = saved
            } else {
                r.holes[hi].entries.append(saved)
            }
        }
        store.updateRound(r)
        recomputeCarry(from: r)
    }

    private func summary(_ e: PlayerHoleEntry) -> String {
        var bits: [String] = []
        if e.putts > 0 { bits.append("\(e.putts)パット") }
        if e.manualPointAdjust != 0 {
            bits.append("調整\(e.manualPointAdjust > 0 ? "+" : "")\(e.manualPointAdjust)")
        }
        bits.append(contentsOf: e.eventLog.map(\.label))
        if bits.isEmpty {
            if e.declaredReach { bits.append("リーチ") }
            if e.nameLick { bits.append("舐め") }
            if e.awaya { bits.append("あわや") }
            if let m = e.medal { bits.append(m.label) }
        }
        return bits.isEmpty ? "タップして入力" : bits.joined(separator: " · ")
    }

    private func recomputeCarry(from round: GolfRound) {
        var r = round
        var carry = 0
        for i in r.holes.indices.sorted(by: { r.holes[$0].holeNumber < r.holes[$1].holeNumber }) {
            r.holes[i].nearestPinCarryIn = carry
            let scored = OlympicsCalculator.scoreHole(
                hole: r.holes[i],
                players: r.players,
                penaltiesEnabled: r.options.penaltiesEnabled,
                nearestPinCarryIn: carry,
                points: r.options.olympicsPoints,
                customRules: r.options.customPointRules
            )
            carry = scored.nearestPinCarryOut
        }
        store.updateRound(r)
    }
}
