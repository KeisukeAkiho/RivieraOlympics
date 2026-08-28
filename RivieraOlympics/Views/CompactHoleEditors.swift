import SwiftUI

/// スコアカード記号（対パー。パー3/4/5いずれでも同じ）
enum ScorecardSymbol {
    static func mark(toPar: Int) -> String {
        switch toPar {
        case ...(-2): return "◎"
        case -1: return "○"
        case 0: return "－"
        case 1: return "□"
        default: return "■"
        }
    }

    static func name(toPar: Int) -> String {
        switch toPar {
        case ...(-3): return "アルバトロス以上"
        case -2: return "イーグル"
        case -1: return "バーディー"
        case 0: return "パー"
        case 1: return "ボギー"
        case 2: return "ダブルボギー"
        default: return "トリプル以上"
        }
    }

    static func color(toPar: Int) -> Color {
        switch toPar {
        case ...(-1): return RivieraTheme.fairway
        case 0: return .secondary
        default: return RivieraTheme.flag
        }
    }

    static func menuTitle(toPar: Int) -> String {
        let num = toPar == 0 ? "0" : (toPar > 0 ? "+\(toPar)" : "\(toPar)")
        return "\(mark(toPar: toPar))  \(num)  \(name(toPar: toPar))"
    }

    static let selectableDeltas: [Int] = Array(-5...10)
}

/// 対パー記号セル（タップで全員入力シートを開く）
struct ScoreToParCell: View {
    let par: Int
    let strokes: Int
    let width: CGFloat
    let height: CGFloat

    private var toPar: Int? {
        strokes > 0 ? strokes - par : nil
    }

    var body: some View {
        Text(toPar.map { ScorecardSymbol.mark(toPar: $0) } ?? "·")
            .font(.body.weight(.semibold))
            .foregroundStyle(toPar.map { ScorecardSymbol.color(toPar: $0) } ?? Color.secondary)
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
    }
}

/// 1ホール分・全員の打数とオリンピック点を ± で入力。宣言は履歴として残す。
struct CompactScoreEditor: View {
    @Binding var entriesByPlayer: [UUID: PlayerHoleEntry]
    let players: [Player]
    let holeNumber: Int
    let par: Int
    var yards: Int = 0
    var teeName: String = ""
    let round: GolfRound
    let onCommit: () -> Void
    let onCancel: () -> Void

    private var pts: OlympicsPointRules { round.options.olympicsPoints }
    private var olympicsEnabled: Bool { round.options.olympicsEnabled }
    private var carryIn: Int { OlympicsCalculator.carryIn(forHole: holeNumber, round: round) }

    private var holePreview: HoleOlympicsResult {
        OlympicsStatus.previewHole(round: round, holeNumber: holeNumber, drafts: entriesByPlayer)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if yards > 0 {
                        Text("パー \(par) · \(yards) yd\(teeName.isEmpty ? "" : "（\(teeName)）")。打数とオリンピック点を ± で入力します。リーチなどはボタンで履歴に残します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("パー \(par) を基準に打数を ±。オリンピック点も別に ± できます。リーチなどはボタンで履歴に残します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("全員の入力") {
                    ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                        playerCard(player, themeIndex: index)
                    }
                }

                Section {
                    Button("全員をパーで入力") {
                        for p in players {
                            mutate(p.id) { $0.strokes = par }
                        }
                    }
                    Button("全員の打数をクリア", role: .destructive) {
                        for p in players {
                            mutate(p.id) {
                                $0.strokes = 0
                                $0.putts = 0
                            }
                        }
                    }
                }
            }
            .navigationTitle("ホール \(holeNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onCommit).fontWeight(.bold)
                }
            }
        }
    }

    private func playerCard(_ player: Player, themeIndex: Int) -> some View {
        let entry = entriesByPlayer[player.id] ?? PlayerHoleEntry(playerId: player.id)
        let strokes = entry.strokes
        let toPar = strokes > 0 ? strokes - par : 0
        let entered = strokes > 0
        let theme = PlayerTheme.color(at: themeIndex)
        let olympicTotal = holePreview.perPlayer.first(where: { $0.playerId == player.id })?.totalPoints ?? 0
        let olympicLines = holePreview.perPlayer.first(where: { $0.playerId == player.id })?.lines ?? []
        let reachOn = holePreview.perPlayer.first(where: { $0.playerId == player.id })?.reachApplied ?? false

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(theme.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entered
                         ? "\(ScorecardSymbol.menuTitle(toPar: toPar))  ·  \(strokes)打"
                         : "打数クリア")
                        .font(.caption2)
                        .foregroundStyle(entered ? ScorecardSymbol.color(toPar: toPar) : .secondary)
                    if olympicsEnabled {
                        Text(reachOn ? "オリンピック \(signed(olympicTotal))  · リーチ中" : "オリンピック \(signed(olympicTotal))")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(olympicTotal < 0 ? RivieraTheme.flag : (olympicTotal > 0 ? RivieraTheme.fairway : .secondary))
                    }
                }
                Spacer(minLength: 4)
            }

            HStack(alignment: .center, spacing: 16) {
                labeledStepper(
                    title: "打数",
                    valueText: entered ? ScorecardSymbol.mark(toPar: toPar) : "－",
                    color: entered ? ScorecardSymbol.color(toPar: toPar) : .secondary
                ) {
                    guard entered else { return }
                    mutate(player.id) { $0.strokes = max(1, par + max(-5, toPar - 1)) }
                } onPlus: {
                    mutate(player.id) {
                        if $0.strokes <= 0 {
                            $0.strokes = par
                        } else {
                            $0.strokes = min(par + 10, $0.strokes + 1)
                        }
                    }
                }

                if olympicsEnabled {
                    labeledStepper(
                        title: "五輪点",
                        valueText: signed(olympicTotal),
                        color: olympicTotal < 0 ? RivieraTheme.flag : (olympicTotal > 0 ? RivieraTheme.fairway : .secondary)
                    ) {
                        adjustOlympicPoints(playerId: player.id, delta: -1)
                    } onPlus: {
                        adjustOlympicPoints(playerId: player.id, delta: 1)
                    }
                }
            }

            if olympicsEnabled {
                HStack {
                    Text("パット")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: Binding(
                        get: { entry.putts },
                        set: { newVal in mutate(player.id) { $0.putts = newVal } }
                    ), in: 0...8) {
                        Text(entry.putts == 0 ? "未" : "\(entry.putts)")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(minWidth: 28, alignment: .trailing)
                    }
                }
                Text("リーチ成否・焼き鳥判定用。3パットと竿失敗は下のボタンで入力します。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                chipGrid(playerId: player.id, entry: entry, actions: OlympicQuickAction.primary)

                DisclosureGroup("その他") {
                    chipGrid(playerId: player.id, entry: entry, actions: OlympicQuickAction.extra)
                    let customs = round.options.customPointRules.filter(\.enabled)
                    if !customs.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], spacing: 6) {
                            ForEach(customs) { rule in
                                customChip(playerId: player.id, entry: entry, rule: rule)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .font(.caption.weight(.semibold))

                if !entry.eventLog.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("宣言・履歴")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(entry.eventLog) { rec in
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(rec.label)
                                    .font(.caption.weight(.semibold))
                                Text(rec.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    removeEvent(playerId: player.id, id: rec.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if !olympicLines.isEmpty {
                    DisclosureGroup("このホールの点数内訳") {
                        ForEach(olympicLines) { line in
                            HStack {
                                Text(line.label).font(.caption2)
                                Spacer()
                                Text(signed(line.points))
                                    .font(.caption2.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(line.points < 0 ? RivieraTheme.flag : RivieraTheme.fairway)
                            }
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("打数クリア", role: .destructive) {
                mutate(player.id) {
                    $0.strokes = 0
                    $0.putts = 0
                }
            }
        }
    }

    private func chipGrid(playerId: UUID, entry: PlayerHoleEntry, actions: [OlympicQuickAction]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], spacing: 6) {
            ForEach(actions) { action in
                let on = action.isOn(entry)
                eventChip(
                    title: action.title(pts: pts, carryIn: carryIn),
                    icon: action.icon,
                    selected: on,
                    tint: action.tint(),
                    disabled: false
                ) {
                    toggleAction(action, playerId: playerId)
                }
            }
        }
    }

    private func customChip(playerId: UUID, entry: PlayerHoleEntry, rule: CustomPointRule) -> some View {
        let on = entry.customActiveRuleIds.contains(rule.id)
        let label = "\(rule.name) \(rule.points > 0 ? "+" : "")\(rule.points)"
        return eventChip(
            title: label,
            icon: rule.points < 0 ? "minus.circle" : "plus.circle",
            selected: on,
            tint: rule.points < 0 ? RivieraTheme.flag : RivieraTheme.fairway,
            disabled: false
        ) {
            toggleCustom(playerId: playerId, rule: rule)
        }
    }

    private func labeledStepper(
        title: String,
        valueText: String,
        color: Color,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Text(valueText)
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(color)
                    .frame(minWidth: 36)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(RivieraTheme.fairway)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func eventChip(
        title: String,
        icon: String,
        selected: Bool,
        tint: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(disabled ? Color.secondary : (selected ? Color.white : tint))
            .background(disabled ? Color.secondary.opacity(0.12) : (selected ? tint : tint.opacity(0.12)))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        disabled ? Color.secondary.opacity(0.25) : (selected ? tint : tint.opacity(0.35)),
                        lineWidth: selected && !disabled ? 2 : 1
                    )
            )
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Mutations

    private func mutate(_ playerId: UUID, _ body: (inout PlayerHoleEntry) -> Void) {
        var e = entriesByPlayer[playerId] ?? PlayerHoleEntry(playerId: playerId)
        e.playerId = playerId
        body(&e)
        entriesByPlayer[playerId] = e
    }

    private func adjustOlympicPoints(playerId: UUID, delta: Int) {
        let current = holePreview.perPlayer.first(where: { $0.playerId == playerId })?.totalPoints ?? 0
        let next = max(-40, min(80, current + delta))
        guard next != current else { return }
        mutate(playerId) { $0.manualPointAdjust += (next - current) }
    }

    private func toggleAction(_ action: OlympicQuickAction, playerId: UUID) {
        var e = entriesByPlayer[playerId] ?? PlayerHoleEntry(playerId: playerId)
        e.playerId = playerId
        let on = !action.isOn(e)
        action.apply(to: &e, on: on, points: pts)
        if on {
            e.eventLog.append(OlympicEventRecord(code: action.code, label: action.historyLabel))
        } else if let idx = e.eventLog.lastIndex(where: { $0.code == action.code }) {
            e.eventLog.remove(at: idx)
        }
        entriesByPlayer[playerId] = e

        if on && action == .nearestPin {
            for pid in entriesByPlayer.keys where pid != playerId {
                mutate(pid) {
                    if $0.nearestPinContender {
                        $0.nearestPinContender = false
                        if let idx = $0.eventLog.lastIndex(where: { $0.code == OlympicQuickAction.nearestPin.code }) {
                            $0.eventLog.remove(at: idx)
                        }
                    }
                }
            }
        }
    }

    private func toggleCustom(playerId: UUID, rule: CustomPointRule) {
        let code = "custom:\(rule.id.uuidString)"
        mutate(playerId) { e in
            let on = e.customActiveRuleIds.contains(rule.id)
            if on {
                e.customActiveRuleIds.removeAll { $0 == rule.id }
                if let idx = e.eventLog.lastIndex(where: { $0.code == code }) {
                    e.eventLog.remove(at: idx)
                }
            } else {
                e.customActiveRuleIds.append(rule.id)
                e.eventLog.append(OlympicEventRecord(code: code, label: rule.name))
            }
        }
    }

    private func removeEvent(playerId: UUID, id: UUID) {
        mutate(playerId) { e in
            guard let rec = e.eventLog.first(where: { $0.id == id }) else { return }
            e.eventLog.removeAll { $0.id == id }
            if e.eventLog.contains(where: { $0.code == rec.code }) { return }
            if rec.code.hasPrefix("custom:") {
                let raw = String(rec.code.dropFirst("custom:".count))
                if let uuid = UUID(uuidString: raw) {
                    e.customActiveRuleIds.removeAll { $0 == uuid }
                }
                return
            }
            if let action = OlympicQuickAction(rawValue: rec.code) {
                action.apply(to: &e, on: false, points: pts)
            }
        }
    }

    private func signed(_ value: Int) -> String {
        value == 0 ? "0" : String(format: "%+d", value)
    }
}
