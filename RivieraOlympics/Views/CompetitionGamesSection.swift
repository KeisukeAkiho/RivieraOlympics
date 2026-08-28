import SwiftUI

/// Shared toggles for which competitions are active in a round.
struct CompetitionGamesSection: View {
    @Binding var options: RoundOptions
    var enabled: Bool = true
    var showFooter: Bool = true

    var body: some View {
        Section {
            Toggle("オリンピック", isOn: $options.olympicsEnabled)
            Toggle("ホールマッチ", isOn: $options.holeMatchEnabled)
            Toggle("ラスベガス", isOn: $options.lasVegasEnabled)
            Toggle("村長", isOn: $options.sonchoEnabled)
            Toggle("蛇", isOn: $options.snakeEnabled)
            if options.snakeEnabled {
                Toggle("蛇を9ホール毎に精算", isOn: $options.snakeSettlePerNine)
            }
            Toggle("オネストジョン", isOn: $options.honestJohnEnabled)
            Toggle("ペナルティ", isOn: $options.penaltiesEnabled)
        } header: {
            Text("競技内容")
        } footer: {
            if showFooter {
                Text(footerText)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!enabled)
    }

    private var footerText: String {
        let names = Self.enabledGameNames(options)
        if names.isEmpty {
            return "有効な競技がありません。スコア入力のみになります。"
        }
        return "有効: " + names.joined(separator: "・")
    }

    static func enabledGameNames(_ options: RoundOptions) -> [String] {
        var names: [String] = []
        if options.olympicsEnabled { names.append("オリンピック") }
        if options.holeMatchEnabled { names.append("ホールマッチ") }
        if options.lasVegasEnabled { names.append("ラスベガス") }
        if options.sonchoEnabled { names.append("村長") }
        if options.snakeEnabled { names.append("蛇") }
        if options.honestJohnEnabled { names.append("オネストジョン") }
        return names
    }

    static func summaryLabel(_ options: RoundOptions) -> String {
        let names = enabledGameNames(options)
        return names.isEmpty ? "なし" : names.joined(separator: "・")
    }
}

struct HoleMatchSettingsSection: View {
    @Binding var options: RoundOptions
    var players: [(id: UUID, name: String)]
    var enabled: Bool = true

    var body: some View {
        if options.holeMatchEnabled, !players.isEmpty {
            Section {
                Picker("形式", selection: $options.holeMatchMode) {
                    ForEach(HoleMatchMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!enabled)

                Text(options.holeMatchMode.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if options.holeMatchMode == .sides {
                    sidePicker(title: "サイドA", side: \.holeMatchSideA, other: \.holeMatchSideB)
                    sidePicker(title: "サイドB", side: \.holeMatchSideB, other: \.holeMatchSideA)
                    Text("例: Aが1人・Bが3人なら 1対3。各サイドの最少打数で勝敗。勝ちサイドは掛け金×相手人数。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("ホールマッチ")
            } footer: {
                Text("結果はスコア表のホールマッチ欄をタップして手動でも変えられます。")
            }
            .onAppear { ensureSides() }
            .onChange(of: options.holeMatchMode) { _, _ in ensureSides() }
        }
    }

    private func sidePicker(
        title: String,
        side: WritableKeyPath<RoundOptions, [UUID]>,
        other: WritableKeyPath<RoundOptions, [UUID]>
    ) -> some View {
        DisclosureGroup("\(title)（\(options[keyPath: side].count)人）") {
            ForEach(players, id: \.id) { player in
                Toggle(player.name, isOn: Binding(
                    get: { options[keyPath: side].contains(player.id) },
                    set: { on in
                        var ids = options[keyPath: side]
                        var others = options[keyPath: other]
                        if on {
                            if !ids.contains(player.id) { ids.append(player.id) }
                            others.removeAll { $0 == player.id }
                        } else {
                            ids.removeAll { $0 == player.id }
                        }
                        options[keyPath: side] = ids
                        options[keyPath: other] = others
                    }
                ))
                .disabled(!enabled)
            }
        }
    }

    private func ensureSides() {
        guard options.holeMatchMode == .sides else { return }
        let valid = Set(players.map(\.id))
        options.holeMatchSideA.removeAll { !valid.contains($0) }
        options.holeMatchSideB.removeAll { !valid.contains($0) }
        if options.holeMatchSideA.isEmpty && options.holeMatchSideB.isEmpty, let first = players.first {
            options.holeMatchSideA = [first.id]
            options.holeMatchSideB = players.dropFirst().map(\.id)
        }
    }
}

/// Numbered player list with up/down reorder (scorecard, score entry, Olympics).
struct PlayerOrderEditor: View {
    let players: [(id: UUID, name: String)]
    var canEdit: Bool = true
    var showsRemove: Bool = false
    var onReorder: ([UUID]) -> Void
    var onRemove: ((UUID) -> Void)? = nil

    var body: some View {
        ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .center)
                Text(player.name)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if canEdit {
                    Button {
                        shift(index, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(index == 0)
                    .accessibilityLabel("上へ")

                    Button {
                        shift(index, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(index >= players.count - 1)
                    .accessibilityLabel("下へ")
                }
                if showsRemove, let onRemove {
                    Button(role: .destructive) {
                        onRemove(player.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("選択を解除")
                }
            }
        }
        .onMove { source, destination in
            guard canEdit else { return }
            var ids = players.map(\.id)
            ids.move(fromOffsets: source, toOffset: destination)
            onReorder(ids)
        }
        .moveDisabled(!canEdit)
    }

    private func shift(_ index: Int, by delta: Int) {
        var ids = players.map(\.id)
        let to = index + delta
        guard ids.indices.contains(index), ids.indices.contains(to) else { return }
        ids.swapAt(index, to)
        onReorder(ids)
    }
}

/// Per-player opt-out from Olympics money settlement (scores can still be entered).
struct OlympicsSettlementExclusionSection: View {
    var players: [(id: UUID, name: String)]
    @Binding var options: RoundOptions
    var enabled: Bool = true

    var body: some View {
        if options.olympicsEnabled, !players.isEmpty {
            Section {
                ForEach(players, id: \.id) { player in
                    Toggle(isOn: excludedBinding(player.id)) {
                        Text(player.name)
                    }
                    .disabled(!enabled)
                }
            } header: {
                Text("オリンピック精算から除外")
            } footer: {
                Text("ON にした選手は点数入力はできますが、精算の人数と合計点には入りません。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func excludedBinding(_ playerId: UUID) -> Binding<Bool> {
        Binding(
            get: { options.isExcludedFromOlympicsSettlement(playerId) },
            set: { options.setExcludedFromOlympicsSettlement(playerId, excluded: $0) }
        )
    }
}

