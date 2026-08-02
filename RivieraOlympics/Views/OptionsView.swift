import SwiftUI

struct OptionsView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID

    var body: some View {
        Group {
            if store.rounds.contains(where: { $0.id == roundId }) {
                optionsForm
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "gearshape")
            }
        }
        .navigationTitle("設定")
    }

    private var optionsForm: some View {
        Form {
            Section("掛け金") {
                Picker("掛け金率", selection: stakeBinding) {
                    Text("20").tag(20)
                    Text("50").tag(50)
                    Text("100").tag(100)
                    Text("200").tag(200)
                    Text("500").tag(500)
                }
                .pickerStyle(.segmented)

                Stepper(
                    "上限: \(current.options.settlementCap == 0 ? "なし" : "\(current.options.settlementCap)")",
                    value: capBinding,
                    in: 0...1_000_000,
                    step: 500
                )
                Text("上限0は制限なし。ネット精算に適用されます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("ゲーム") {
                Toggle("オリンピック", isOn: boolBinding(\.olympicsEnabled))
                Toggle("ホールマッチ", isOn: boolBinding(\.holeMatchEnabled))
                Toggle("ラスベガス", isOn: boolBinding(\.lasVegasEnabled))
                Toggle("村長", isOn: boolBinding(\.sonchoEnabled))
                Toggle("蛇", isOn: boolBinding(\.snakeEnabled))
                Toggle("蛇を9ホール毎に精算", isOn: boolBinding(\.snakeSettlePerNine))
                Toggle("オネストジョン", isOn: boolBinding(\.honestJohnEnabled))
                Toggle("ペナルティ", isOn: boolBinding(\.penaltiesEnabled))
            }

            Section("オネストジョン申告スコア") {
                ForEach(current.players) { p in
                    Stepper(
                        "\(p.name): \(p.honestJohnDeclared)",
                        value: honestJohnBinding(playerId: p.id),
                        in: 60...140
                    )
                }
                Text("プレー前に予想グロスを申告。アンダーは+1/打、オーバーは+2/打。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("ラスベガス チーム") {
                teamPicker(title: "チームA", team: \.lasVegasTeamA)
                teamPicker(title: "チームB", team: \.lasVegasTeamB)
            }

            Section("コースパー") {
                ForEach(0..<18, id: \.self) { i in
                    Stepper(
                        "ホール \(i + 1): パー \(current.coursePars[i])",
                        value: parBinding(hole: i),
                        in: 3...5
                    )
                }
            }
        }
    }

    private var current: GolfRound {
        store.rounds.first(where: { $0.id == roundId })!
    }

    private var stakeBinding: Binding<Int> {
        Binding(
            get: { current.options.stakeRate },
            set: { v in mutate { $0.options.stakeRate = v } }
        )
    }

    private var capBinding: Binding<Int> {
        Binding(
            get: { current.options.settlementCap },
            set: { v in mutate { $0.options.settlementCap = v } }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<RoundOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { current.options[keyPath: keyPath] },
            set: { v in mutate { $0.options[keyPath: keyPath] = v } }
        )
    }

    private func parBinding(hole: Int) -> Binding<Int> {
        Binding(
            get: { current.coursePars[hole] },
            set: { v in
                mutate { r in
                    r.coursePars[hole] = v
                    if let h = r.holes.firstIndex(where: { $0.holeNumber == hole + 1 }) {
                        r.holes[h].par = v
                    }
                }
            }
        )
    }

    private func teamPicker(title: String, team: WritableKeyPath<RoundOptions, [UUID]>) -> some View {
        DisclosureGroup(title) {
            ForEach(current.players) { p in
                Toggle(p.name, isOn: Binding(
                    get: { current.options[keyPath: team].contains(p.id) },
                    set: { on in
                        mutate { r in
                            var ids = r.options[keyPath: team]
                            if on {
                                if !ids.contains(p.id) { ids.append(p.id) }
                            } else {
                                ids.removeAll { $0 == p.id }
                            }
                            r.options[keyPath: team] = ids
                        }
                    }
                ))
            }
        }
    }

    private func honestJohnBinding(playerId: UUID) -> Binding<Int> {
        Binding(
            get: { current.players.first(where: { $0.id == playerId })?.honestJohnDeclared ?? 90 },
            set: { v in
                mutate { r in
                    if let i = r.players.firstIndex(where: { $0.id == playerId }) {
                        r.players[i].honestJohnDeclared = v
                    }
                }
            }
        )
    }

    private func mutate(_ block: (inout GolfRound) -> Void) {
        guard var r = store.rounds.first(where: { $0.id == roundId }) else { return }
        block(&r)
        store.updateRound(r)
    }
}
