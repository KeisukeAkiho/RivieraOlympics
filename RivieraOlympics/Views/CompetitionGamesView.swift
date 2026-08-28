import SwiftUI

/// Mid-round competition content editor (accessible from round detail).
struct CompetitionGamesView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss
    let roundId: UUID

    var body: some View {
        Group {
            if store.rounds.contains(where: { $0.id == roundId }) {
                form
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "flag.slash")
            }
        }
        .navigationTitle("競技内容")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") { dismiss() }
            }
        }
    }

    private var current: GolfRound {
        store.rounds.first(where: { $0.id == roundId })!
    }

    private var form: some View {
        Form {
            CompetitionGamesSection(
                options: optionsBinding,
                enabled: !current.isSettled,
                showFooter: true
            )

            HoleMatchSettingsSection(
                options: optionsBinding,
                players: current.players.map { (id: $0.id, name: $0.name) },
                enabled: !current.isSettled
            )

            if current.isSettled {
                Section {
                    Text("精算確定後は競技内容を変更できません。解除する場合は精算画面から行ってください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if current.options.honestJohnEnabled {
                Section("オネストジョン申告スコア") {
                    ForEach(current.players) { p in
                        Stepper(
                            "\(p.name): \(p.honestJohnDeclared)",
                            value: honestJohnBinding(playerId: p.id),
                            in: 60...140
                        )
                        .disabled(current.isSettled)
                    }
                    Text("プレー前に予想グロスを申告。アンダーは+1/打、オーバーは+2/打。途中ON時は申告を合わせて設定してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if current.options.lasVegasEnabled {
                Section("ラスベガス 1Hスタートペア") {
                    teamPicker(title: "チームA（藍）", team: \.lasVegasTeamA)
                    teamPicker(title: "チームB（橙）", team: \.lasVegasTeamB)
                    Text("組替・バーディーFlip等は「ルール」タブのパラメータでON/OFFできます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var optionsBinding: Binding<RoundOptions> {
        Binding(
            get: { current.options },
            set: { newValue in
                mutate { r in
                    var opts = newValue
                    if opts.lasVegasEnabled {
                        Self.ensureLasVegasTeams(&opts, players: r.players)
                    }
                    if opts.holeMatchEnabled {
                        HoleMatchCalculator.ensureSides(&opts, players: r.players)
                    }
                    r.options = opts
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
                        guard !current.isSettled else { return }
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
                .disabled(current.isSettled)
            }
        }
    }

    private func honestJohnBinding(playerId: UUID) -> Binding<Int> {
        Binding(
            get: { current.players.first(where: { $0.id == playerId })?.honestJohnDeclared ?? 90 },
            set: { v in
                guard !current.isSettled else { return }
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

    static func ensureLasVegasTeams(_ options: inout RoundOptions, players: [Player]) {
        guard players.count >= 4 else { return }
        if options.lasVegasTeamA.isEmpty && options.lasVegasTeamB.isEmpty {
            options.lasVegasTeamA = [players[0].id, players[1].id]
            options.lasVegasTeamB = [players[2].id, players[3].id]
        }
    }
}
