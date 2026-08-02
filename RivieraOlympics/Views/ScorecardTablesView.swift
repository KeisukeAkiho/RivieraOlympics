import SwiftUI

/// スコア表（上）とオリンピック表（下）を横スクロール同期表示
struct ScorecardTablesView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID

    @State private var olympicsTarget: EditTarget?
    @State private var draftEntry: PlayerHoleEntry = PlayerHoleEntry(playerId: UUID())

    private let nameWidth: CGFloat = 76
    private let cellWidth: CGFloat = 44
    private let cellHeight: CGFloat = 36

    private var round: GolfRound? {
        store.rounds.first(where: { $0.id == roundId })
    }

    var body: some View {
        Group {
            if let round {
                VStack(alignment: .leading, spacing: 0) {
                    if round.isSettled {
                        Label("精算確定済み（編集は精算解除後）", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                    }

                    HStack(alignment: .top, spacing: 0) {
                        stickyColumn(round: round)
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                scoreBlock(round: round)
                                sectionDivider(title: "オリンピック点数（セルをタップしてアイコン入力）")
                                olympicsBlock(round: round)
                            }
                        }
                    }
                }
                .sheet(item: $olympicsTarget) { target in
                    CompactOlympicsEditor(
                        entry: $draftEntry,
                        round: round,
                        par: par(for: target.holeNumber),
                        playerName: playerName(target.playerId),
                        holeNumber: target.holeNumber,
                        onCommit: {
                            commitOlympics(target: target, entry: draftEntry)
                            olympicsTarget = nil
                        },
                        onCancel: { olympicsTarget = nil }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "flag.slash")
            }
        }
    }

    // MARK: - Sticky names

    private func stickyColumn(round: GolfRound) -> some View {
        VStack(spacing: 0) {
            cellText("選手", bold: true, width: nameWidth, height: cellHeight)
                .background(RivieraTheme.fairway.opacity(0.15))
            ForEach(round.players) { p in
                cellText(p.name, bold: true, width: nameWidth, height: cellHeight)
            }
            cellText("合計", bold: true, width: nameWidth, height: cellHeight)
                .background(Color(.tertiarySystemFill))

            sectionDivider(title: " ")
                .frame(width: nameWidth)

            cellText("選手", bold: true, width: nameWidth, height: cellHeight)
                .background(Color.orange.opacity(0.15))
            ForEach(round.players) { p in
                let focused = olympicsTarget?.playerId == p.id
                cellText(focused ? "▶ \(p.name)" : p.name, bold: true, width: nameWidth, height: cellHeight)
                    .background(focused ? Color.yellow.opacity(0.55) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(focused ? RivieraTheme.fairway : .clear, lineWidth: 2)
                    )
            }
            cellText("合計", bold: true, width: nameWidth, height: cellHeight)
                .background(Color(.tertiarySystemFill))
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1)
        }
    }

    // MARK: - Score (combo menu)

    private func scoreBlock(round: GolfRound) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(1...18, id: \.self) { h in
                    cellText("\(h)", bold: true, width: cellWidth, height: cellHeight)
                        .background(RivieraTheme.fairway.opacity(0.15))
                }
                // 合計列は打数合計（記号ではなく参考値）
                cellText("計", bold: true, width: cellWidth, height: cellHeight)
                    .background(RivieraTheme.fairway.opacity(0.25))
            }
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...18, id: \.self) { h in
                        let par = round.holes.first(where: { $0.holeNumber == h })?.par ?? 4
                        let strokes = strokes(round: round, playerId: p.id, hole: h)
                        ScoreToParMenu(
                            par: par,
                            strokes: strokes,
                            disabled: round.isSettled,
                            width: cellWidth,
                            height: cellHeight
                        ) { newStrokes in
                            setStrokes(playerId: p.id, hole: h, strokes: newStrokes)
                        }
                    }
                    let tot = (1...18).reduce(0) { $0 + strokes(round: round, playerId: p.id, hole: $1) }
                    cellText(tot > 0 ? "\(tot)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    // MARK: - Olympics (compact popover)

    private func olympicsBlock(round: GolfRound) -> some View {
        let byHole = OlympicsCalculator.scoreRound(round)
        let map: [Int: [UUID: Int]] = Dictionary(uniqueKeysWithValues: byHole.map { hole in
            (hole.holeNumber, Dictionary(uniqueKeysWithValues: hole.perPlayer.map { ($0.playerId, $0.totalPoints) }))
        })

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(1...18, id: \.self) { h in
                    cellText("\(h)", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color.orange.opacity(0.15))
                }
                cellText("計", bold: true, width: cellWidth, height: cellHeight)
                    .background(Color.orange.opacity(0.25))
            }
            ForEach(round.players) { p in
                let rowFocused = olympicsTarget?.playerId == p.id
                HStack(spacing: 0) {
                    ForEach(1...18, id: \.self) { h in
                        let pts = map[h]?[p.id] ?? 0
                        let entry = entry(round: round, playerId: p.id, hole: h)
                        let cellFocused = olympicsTarget?.playerId == p.id && olympicsTarget?.holeNumber == h
                        Button {
                            guard !round.isSettled, let entry else { return }
                            draftEntry = entry
                            olympicsTarget = EditTarget(playerId: p.id, holeNumber: h)
                        } label: {
                            olympicsCellLabel(entry: entry, points: pts, focused: cellFocused, rowFocused: rowFocused)
                        }
                        .buttonStyle(.plain)
                        .disabled(round.isSettled)
                    }
                    let tot = (1...18).reduce(0) { $0 + (map[$1]?[p.id] ?? 0) }
                    cellText("\(tot)", bold: true, width: cellWidth, height: cellHeight)
                        .background(rowFocused ? Color.yellow.opacity(0.35) : Color(.tertiarySystemFill))
                }
                .background(rowFocused ? Color.yellow.opacity(0.12) : Color.clear)
            }
        }
    }

    private func olympicsCellLabel(entry: PlayerHoleEntry?, points: Int, focused: Bool, rowFocused: Bool) -> some View {
        let icons = olympicsIcons(entry)
        return VStack(spacing: 1) {
            if icons.isEmpty {
                Text(entry?.strokes ?? 0 > 0 ? "\(points)" : "·")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(points < 0 ? RivieraTheme.flag : (points > 0 ? RivieraTheme.fairway : .primary))
            } else {
                HStack(spacing: 1) {
                    ForEach(icons.prefix(3), id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 8))
                            .foregroundStyle(RivieraTheme.fairway)
                    }
                }
                Text("\(points)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(points < 0 ? RivieraTheme.flag : RivieraTheme.fairway)
            }
        }
        .frame(width: cellWidth, height: cellHeight)
        .background(focused ? Color.yellow.opacity(0.65) : (rowFocused ? Color.yellow.opacity(0.18) : Color.clear))
        .contentShape(Rectangle())
        .overlay(
            Rectangle().stroke(
                focused ? RivieraTheme.fairway : Color.secondary.opacity(0.25),
                lineWidth: focused ? 2.5 : 0.5
            )
        )
    }

    private func olympicsIcons(_ entry: PlayerHoleEntry?) -> [String] {
        guard let e = entry else { return [] }
        var icons: [String] = []
        if e.medal != nil || e.chipInFromOffGreen { icons.append("medal.fill") }
        if e.declaredReach { icons.append("bolt.fill") }
        if e.declaredPin || e.outerPinDeclared { icons.append("ruler") }
        if e.banker { icons.append("beach.umbrella.fill") }
        if e.nameLick { icons.append("drop.fill") }
        if e.awaya { icons.append("leaf.fill") }
        if e.nearestPinContender { icons.append("scope") }
        if e.fireman { icons.append("flame.fill") }
        return icons
    }

    private func sectionDivider(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGroupedBackground))
    }

    private func cellText(_ text: String, bold: Bool, width: CGFloat, height: CGFloat) -> some View {
        Text(text)
            .font(bold ? .caption.weight(.bold) : .caption.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, height: height)
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Mutations

    private func setStrokes(playerId: UUID, hole: Int, strokes: Int) {
        guard var r = store.rounds.first(where: { $0.id == roundId }), !r.isSettled,
              let hi = r.holes.firstIndex(where: { $0.holeNumber == hole }),
              let ei = r.holes[hi].entries.firstIndex(where: { $0.playerId == playerId }) else { return }
        r.holes[hi].entries[ei].strokes = strokes
        // 対パー入力時、未設定パットは仮で2（パーオン想定）。0クリア時はパットもクリア
        if strokes == 0 {
            r.holes[hi].entries[ei].putts = 0
        } else if r.holes[hi].entries[ei].putts == 0 {
            r.holes[hi].entries[ei].putts = 2
        }
        store.updateRound(r)
        recomputeCarry()
    }

    private func commitOlympics(target: EditTarget, entry: PlayerHoleEntry) {
        guard var r = store.rounds.first(where: { $0.id == roundId }), !r.isSettled,
              let hi = r.holes.firstIndex(where: { $0.holeNumber == target.holeNumber }),
              let ei = r.holes[hi].entries.firstIndex(where: { $0.playerId == target.playerId }) else { return }
        r.holes[hi].entries[ei] = entry
        if entry.nearestPinContender {
            for i in r.holes[hi].entries.indices where r.holes[hi].entries[i].id != entry.id {
                r.holes[hi].entries[i].nearestPinContender = false
            }
        }
        store.updateRound(r)
        recomputeCarry()
    }

    private func entry(round: GolfRound, playerId: UUID, hole: Int) -> PlayerHoleEntry? {
        round.holes.first(where: { $0.holeNumber == hole })?
            .entries.first(where: { $0.playerId == playerId })
    }

    private func strokes(round: GolfRound, playerId: UUID, hole: Int) -> Int {
        entry(round: round, playerId: playerId, hole: hole)?.strokes ?? 0
    }

    private func par(for hole: Int) -> Int {
        store.rounds.first(where: { $0.id == roundId })?
            .holes.first(where: { $0.holeNumber == hole })?.par ?? 4
    }

    private func playerName(_ id: UUID) -> String {
        store.rounds.first(where: { $0.id == roundId })?
            .players.first(where: { $0.id == id })?.name ?? "選手"
    }

    private func recomputeCarry() {
        guard var r = store.rounds.first(where: { $0.id == roundId }) else { return }
        var carry = 0
        for i in r.holes.indices.sorted(by: { r.holes[$0].holeNumber < r.holes[$1].holeNumber }) {
            r.holes[i].nearestPinCarryIn = carry
            let scored = OlympicsCalculator.scoreHole(
                hole: r.holes[i],
                players: r.players,
                penaltiesEnabled: r.options.penaltiesEnabled,
                nearestPinCarryIn: carry
            )
            carry = scored.nearestPinCarryOut
        }
        store.updateRound(r)
    }
}

private struct EditTarget: Identifiable {
    var id: String { "\(playerId)-\(holeNumber)" }
    let playerId: UUID
    let holeNumber: Int
}
