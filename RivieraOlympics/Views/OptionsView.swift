import SwiftUI

struct OptionsView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID

    @State private var customStakeDraft = 30
    @State private var customCapDraft = 3_000

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
                Text("現在の選択: \(current.options.stakeRate)")
                    .font(.headline)

                amountChoiceGrid(
                    values: stakeChoicesForDisplay,
                    selected: current.options.stakeRate,
                    isPreset: store.isPresetStakeRate,
                    label: { "\($0)" },
                    onSelect: selectStake
                )

                if !store.availableStakeRates.contains(current.options.stakeRate) {
                    Text("このラウンドだけ \(current.options.stakeRate) が使われています（候補外）。下から選ぶか登録してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("ユーザー指定")
                    Spacer()
                    TextField("金額", value: $customStakeDraft, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Button("登録して選択") {
                        registerAndSelectCustomStake()
                    }
                    .disabled(customStakeDraft <= 0 || current.isSettled)
                }

                if !store.customStakeRates.isEmpty {
                    ForEach(store.customStakeRates, id: \.self) { rate in
                        HStack {
                            Text("登録済み: \(rate)")
                            Spacer()
                            if current.options.stakeRate == rate {
                                Text("使用中")
                                    .font(.caption)
                                    .foregroundStyle(RivieraTheme.fairway)
                            }
                        }
                    }
                    .onDelete(perform: deleteCustomStakes)
                    Text("左にスワイプで登録を削除（このラウンドの掛け金自体は変わりません）")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("プリセット（20・50・100・200・500）に加え、任意金額を登録して再利用できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("精算上限") {
                Text("現在の選択: \(capLabel(current.options.settlementCap))")
                    .font(.headline)

                amountChoiceGrid(
                    values: capChoicesForDisplay,
                    selected: current.options.settlementCap,
                    isPreset: store.isPresetSettlementCap,
                    label: capLabel,
                    onSelect: selectCap
                )

                if !store.availableSettlementCaps.contains(current.options.settlementCap) {
                    Text("このラウンドだけ \(capLabel(current.options.settlementCap)) が使われています（候補外）。下から選ぶか登録してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("ユーザー指定")
                    Spacer()
                    TextField("金額", value: $customCapDraft, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Button("登録して選択") {
                        registerAndSelectCustomCap()
                    }
                    .disabled(customCapDraft <= 0 || current.isSettled)
                }

                if !store.customSettlementCaps.isEmpty {
                    ForEach(store.customSettlementCaps, id: \.self) { cap in
                        HStack {
                            Text("登録済み: \(cap)")
                            Spacer()
                            if current.options.settlementCap == cap {
                                Text("使用中")
                                    .font(.caption)
                                    .foregroundStyle(RivieraTheme.fairway)
                            }
                        }
                    }
                    .onDelete(perform: deleteCustomCaps)
                    Text("左にスワイプで登録を削除（このラウンドの上限自体は変わりません）")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("プリセット（なし・500・1000・2000・5000・10000）に加え、任意上限を登録して再利用できます。0は制限なし。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            CompetitionGamesSection(
                options: optionsBinding,
                enabled: !current.isSettled
            )

            Section("ルールパラメータ") {
                Text("既定セット: \(store.activeRulePreset.name)")
                    .font(.subheadline.weight(.semibold))
                Button("ルールタブの既定セットをこのラウンドに適用") {
                    mutate { r in
                        store.applyActiveRules(to: &r.options)
                    }
                }
                .disabled(current.isSettled)
                Text("点数・独自ルール・LV拡張の編集は「ルール」タブ →「パラメータ」で行います。ルールブックの表示も同じセットに同期します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                    Text("プレー前に予想グロスを申告。アンダーは+1/打、オーバーは+2/打。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if current.options.lasVegasEnabled {
                Section("ラスベガス 1Hスタートペア") {
                    teamPicker(title: "チームA（藍）", team: \.lasVegasTeamA)
                    teamPicker(title: "チームB（橙）", team: \.lasVegasTeamB)
                    Text("組替・Flip等は「ルール」タブのパラメータでON/OFFできます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("コース") {
                if !current.courseName.isEmpty {
                    Text("現在: \(current.courseName)")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text("現在: 未指定（手入力パー）")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if store.courses.isEmpty {
                    Text("「コース」タブでコースを登録してください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("登録コースを適用", selection: coursePickBinding) {
                        Text("選択…").tag(Optional<UUID>.none)
                        ForEach(store.courses) { c in
                            Text("\(c.displayTitle)（計\(c.totalPar)）").tag(Optional(c.id))
                        }
                    }
                    .disabled(current.isSettled)
                }

                ForEach(0..<18, id: \.self) { i in
                    Stepper(
                        "ホール \(i + 1): パー \(current.coursePars[i])",
                        value: parBinding(hole: i),
                        in: 3...5
                    )
                    .disabled(current.isSettled)
                }
                Text("ステッパーで個別変更すると、登録コースとの紐づけは外れます。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func amountChoiceGrid(
        values: [Int],
        selected: Int,
        isPreset: @escaping (Int) -> Bool,
        label: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isSelected = selected == value
                let preset = isPreset(value)
                Button {
                    onSelect(value)
                } label: {
                    VStack(spacing: 2) {
                        Text(label(value))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if !preset {
                            Text("登録")
                                .font(.system(size: 9))
                                .opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? RivieraTheme.fairway.opacity(0.22) : Color(.tertiarySystemFill))
                    .foregroundStyle(isSelected ? RivieraTheme.fairway : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? RivieraTheme.fairway : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(current.isSettled)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    /// 候補＋現在値（候補外でも表示）
    private var stakeChoicesForDisplay: [Int] {
        var set = Set(store.availableStakeRates)
        set.insert(current.options.stakeRate)
        return set.filter { $0 > 0 }.sorted()
    }

    private var capChoicesForDisplay: [Int] {
        var set = Set(store.availableSettlementCaps)
        set.insert(current.options.settlementCap)
        return set.filter { $0 >= 0 }.sorted()
    }

    private func capLabel(_ cap: Int) -> String {
        cap == 0 ? "なし" : "\(cap)"
    }

    private var current: GolfRound {
        store.rounds.first(where: { $0.id == roundId })!
    }

    private var optionsBinding: Binding<RoundOptions> {
        Binding(
            get: { current.options },
            set: { newValue in
                mutate { r in
                    var opts = newValue
                    if opts.lasVegasEnabled {
                        CompetitionGamesView.ensureLasVegasTeams(&opts, players: r.players)
                    }
                    r.options = opts
                }
            }
        )
    }

    private func selectStake(_ rate: Int) {
        guard rate > 0 else { return }
        mutate { $0.options.stakeRate = rate }
    }

    private func selectCap(_ cap: Int) {
        guard cap >= 0 else { return }
        mutate { $0.options.settlementCap = cap }
    }

    private func registerAndSelectCustomStake() {
        let rate = customStakeDraft
        guard rate > 0 else { return }
        if !store.isPresetStakeRate(rate) {
            store.registerCustomStakeRate(rate)
        }
        selectStake(rate)
    }

    private func registerAndSelectCustomCap() {
        let cap = customCapDraft
        guard cap > 0 else { return }
        if !store.isPresetSettlementCap(cap) {
            store.registerCustomSettlementCap(cap)
        }
        selectCap(cap)
    }

    private func deleteCustomStakes(at offsets: IndexSet) {
        let rates = offsets.map { store.customStakeRates[$0] }
        for rate in rates {
            store.removeCustomStakeRate(rate)
        }
    }

    private func deleteCustomCaps(at offsets: IndexSet) {
        let caps = offsets.map { store.customSettlementCaps[$0] }
        for cap in caps {
            store.removeCustomSettlementCap(cap)
        }
    }

    private var coursePickBinding: Binding<UUID?> {
        Binding(
            get: { current.courseId },
            set: { id in
                guard let id else { return }
                store.applyCourse(id, toRoundId: roundId)
            }
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
                    // 個別変更したら登録コースとの一致は保証できない
                    r.courseId = nil
                    r.courseName = ""
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
