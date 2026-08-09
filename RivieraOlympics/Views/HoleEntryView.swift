import SwiftUI

struct HoleEntryView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID
    let holeNumber: Int

    @State private var selectedPlayerId: UUID?

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
                        Text("選手をタップして打数・オリンピック・リーチ・舐め・あわやなどを入力します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("ホール \(holeNumber) · パー \(hole.par)")
                    }

                    Section("スコア") {
                        ForEach(hole.entries) { entry in
                            let name = round.players.first(where: { $0.id == entry.playerId })?.name ?? "?"
                            Button {
                                selectedPlayerId = entry.playerId
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).foregroundStyle(.primary)
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
                            ForEach(result.perPlayer, id: \.playerId) { p in
                                let name = round.players.first(where: { $0.id == p.playerId })?.name ?? "?"
                                HStack {
                                    Text(name)
                                    Spacer()
                                    Text("\(p.totalPoints) 点")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("ホール \(holeNumber)")
                .sheet(item: selectedEntryBinding(ri: ri, hi: hi)) { entry in
                    PlayerHoleEditor(
                        playerName: round.players.first(where: { $0.id == entry.playerId })?.name ?? "選手",
                        entry: entry,
                        par: hole.par,
                        onSave: { updated in
                            var r = store.rounds[ri]
                            if let ei = r.holes[hi].entries.firstIndex(where: { $0.id == updated.id }) {
                                r.holes[hi].entries[ei] = updated
                            }
                            if updated.nearestPinContender {
                                for i in r.holes[hi].entries.indices where r.holes[hi].entries[i].id != updated.id {
                                    r.holes[hi].entries[i].nearestPinContender = false
                                }
                            }
                            store.updateRound(r)
                            recomputeCarry(from: r)
                            selectedPlayerId = nil
                        }
                    )
                }
            } else {
                ContentUnavailableView("ホールが見つかりません", systemImage: "flag.slash")
            }
        }
    }

    private func selectedEntryBinding(ri: Int, hi: Int) -> Binding<PlayerHoleEntry?> {
        Binding(
            get: {
                guard let id = selectedPlayerId else { return nil }
                return store.rounds[ri].holes[hi].entries.first(where: { $0.playerId == id })
            },
            set: { newVal in
                if newVal == nil { selectedPlayerId = nil }
            }
        )
    }

    private func summary(_ e: PlayerHoleEntry) -> String {
        var bits: [String] = []
        if e.putts > 0 { bits.append("\(e.putts)パット") }
        if e.declaredReach { bits.append("リーチ") }
        if e.nameLick { bits.append("舐め") }
        if e.awaya { bits.append("あわや") }
        if e.banker { bits.append("砂") }
        if e.nearestPinContender { bits.append("ニアピン") }
        if e.fireman { bits.append("消防隊") }
        if let m = e.medal { bits.append(m.label) }
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

private struct PlayerHoleEditor: View {
    let playerName: String
    @State var entry: PlayerHoleEntry
    let par: Int
    let onSave: (PlayerHoleEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("スコア") {
                    Stepper("打数: \(entry.strokes)", value: $entry.strokes, in: 0...15)
                    Stepper("パット: \(entry.putts)", value: $entry.putts, in: 0...8)
                    Text("対パー: \(entry.strokes == 0 ? "—" : "\(entry.strokes - par)")")
                        .foregroundStyle(.secondary)
                }

                Section("基本メダル") {
                    Picker("メダル", selection: $entry.medal) {
                        Text("なし").tag(Optional<OlympicMedal>.none)
                        ForEach(OlympicMedal.allCases) { m in
                            Text("\(m.label)（\(m.points)）").tag(Optional(m))
                        }
                    }
                    Toggle("グリーン外チップイン（ダイヤ）", isOn: $entry.chipInFromOffGreen)
                }

                Section("付加価値") {
                    Toggle("竿を宣言", isOn: $entry.declaredPin)
                    Toggle("竿距離1ピン以上", isOn: $entry.pinDistanceQualified)
                    Toggle("外竿を宣言", isOn: $entry.outerPinDeclared)
                    Stepper("アプローチ後のグリーン上打数: \(entry.strokesOnGreenAfterApproach)", value: $entry.strokesOnGreenAfterApproach, in: 0...5)
                    Toggle("砂（バンカー）", isOn: $entry.banker)
                    Toggle("パーオン", isOn: $entry.parOn)
                    Toggle("バーディーオン", isOn: $entry.birdieOn)
                    Toggle("ニアピン権利", isOn: $entry.nearestPinContender)
                    Toggle("消防隊", isOn: $entry.fireman)
                    Toggle("1打目グリーンオン", isOn: $entry.greenInRegulationTee)
                }

                Section("リーチ・ペナルティ") {
                    Toggle("リーチ宣言", isOn: $entry.declaredReach)
                    Toggle("舐め（カップエッジ）", isOn: $entry.nameLick)
                    Toggle("あわや（フリンジ）", isOn: $entry.awaya)
                }

                Section("メモ") {
                    TextField("任意メモ", text: $entry.notes, axis: .vertical)
                }
            }
            .navigationTitle(playerName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(entry)
                        dismiss()
                    }
                }
            }
        }
    }
}
