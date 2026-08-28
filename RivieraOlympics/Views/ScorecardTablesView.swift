import SwiftUI

/// スコア表（上）とオリンピック表（下）を横スクロール同期表示
struct ScorecardTablesView: View {
    @EnvironmentObject private var store: RoundStore
    let roundId: UUID

    @State private var scoreHoleTarget: ScoreHoleTarget?
    @State private var scoreDraft: [UUID: PlayerHoleEntry] = [:]
    @State private var holeMatchEditHole: Int?

    private let nameWidth: CGFloat = 52
    private let cellWidth: CGFloat = 44
    private let cellHeight: CGFloat = 36
    private let yardsRowHeight: CGFloat = 26
    /// ラスベガス選手行: A/B + そのホールの得失点
    private let lvPlayerRowHeight: CGFloat = 46
    private let sectionBandHeight: CGFloat = 28

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

                    BlinkingObligationWarningBar(chips: obligationChips(round: round))

                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            stickyColumn(round: round)
                            ScrollView(.horizontal, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 0) {
                                    scoreBlock(round: round)

                                    if round.options.olympicsEnabled {
                                        sectionDivider(title: "オリンピック点数（スコア入力で ± ／履歴）")
                                        olympicsBlock(round: round)
                                    }

                                    if round.options.holeMatchEnabled {
                                        sectionDivider(title: holeMatchSectionTitle(round))
                                        holeMatchBlock(round: round)
                                    }

                                    if round.options.lasVegasEnabled {
                                        sectionDivider(title: "ラスベガス（毎ホール 1+4 vs 2+3／A藍・B橙）")
                                        lasVegasBlock(round: round)
                                    }

                                    if round.options.snakeEnabled {
                                        sectionDivider(title: "蛇（ホルダー／精算¥）")
                                        snakeBlock(round: round)
                                    }

                                    if round.options.sonchoEnabled {
                                        sectionDivider(title: "村長（グロス／精算¥）")
                                        sonchoBlock(round: round)
                                    }

                                    if round.options.honestJohnEnabled {
                                        sectionDivider(title: "オネストジョン（申告差／精算¥）")
                                        honestJohnBlock(round: round)
                                    }
                                }
                            }
                        }
                    }
                }
                .sheet(item: $scoreHoleTarget) { target in
                    let live = currentRound ?? round
                    CompactScoreEditor(
                        entriesByPlayer: $scoreDraft,
                        players: live.players,
                        holeNumber: target.holeNumber,
                        par: par(for: target.holeNumber),
                        yards: live.yards(forHole: target.holeNumber),
                        teeName: live.selectedTeeName,
                        round: live,
                        onCommit: {
                            commitHoleEntries(hole: target.holeNumber, entriesByPlayer: scoreDraft)
                            scoreHoleTarget = nil
                        },
                        onCancel: { scoreHoleTarget = nil }
                    )
                    .presentationDetents([.large, .medium])
                    .presentationDragIndicator(.visible)
                }
                .confirmationDialog(
                    holeMatchDialogTitle,
                    isPresented: Binding(
                        get: { holeMatchEditHole != nil },
                        set: { if !$0 { holeMatchEditHole = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    holeMatchDialogButtons
                    Button("キャンセル", role: .cancel) { holeMatchEditHole = nil }
                } message: {
                    Text("自動はスコアから判定。手動にすると打数が変わってもこのホールの勝ちは固定されます。")
                }
            } else {
                ContentUnavailableView("ラウンドが見つかりません", systemImage: "flag.slash")
            }
        }
    }

    private var currentRound: GolfRound? {
        store.rounds.first(where: { $0.id == roundId })
    }

    // MARK: - Compact warnings (reach / yakitori)

    private struct ObligationChip: Identifiable, Equatable {
        var id: String { "\(playerId.uuidString)-\(text)" }
        let playerId: UUID
        let text: String
    }

    private func obligationChips(round: GolfRound) -> [ObligationChip] {
        guard round.options.olympicsEnabled else { return [] }
        var chips: [ObligationChip] = []
        // 前半は8H、後半は17Hの入力完了後に警告（最終前ホールで対処催促）
        for player in round.players {
            for gateHole in [8, 17] {
                guard strokes(round: round, playerId: player.id, hole: gateHole) > 0 else { continue }
                let status = OlympicsStatus.status(round: round, playerId: player.id, holeNumber: gateHole)
                if !status.reachOK {
                    chips.append(ObligationChip(
                        playerId: player.id,
                        text: "\(player.name) · \(status.nineLabel)リーチ未"
                    ))
                }
                if !status.yakitoriOK {
                    chips.append(ObligationChip(
                        playerId: player.id,
                        text: "\(player.name) · \(status.nineLabel)焼き鳥"
                    ))
                }
            }
        }
        return chips
    }

    /// 警告バー（点滅）
    private struct BlinkingObligationWarningBar: View {
        let chips: [ObligationChip]
        @State private var blinkOn = false

        var body: some View {
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(RivieraTheme.flag)
                            .opacity(blinkOn ? 1 : 0.25)
                        ForEach(chips) { chip in
                            Text(chip.text)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RivieraTheme.flag)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RivieraTheme.flag.opacity(blinkOn ? 0.28 : 0.08))
                                .clipShape(Capsule())
                                .opacity(blinkOn ? 1 : 0.35)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .background(Color.orange.opacity(blinkOn ? 0.22 : 0.06))
                .onAppear {
                    blinkOn = false
                    withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                        blinkOn = true
                    }
                }
            }
        }
    }

    // MARK: - Sticky names
    // 右ペインと同じ行構成（ヘッダ + 選手行のみ）。「合計」行は右に無いため置かない（列ずれ防止）。

    private func stickyColumn(round: GolfRound) -> some View {
        VStack(spacing: 0) {
            stickyPlayerSection(
                title: "選手",
                tint: RivieraTheme.fairway.opacity(0.15),
                round: round,
                includeParsRow: true,
                includeYardsRow: round.hasHoleYards
            )

            if round.options.olympicsEnabled {
                sectionDivider(title: " ").frame(width: nameWidth)
                stickyPlayerSection(title: "選手", tint: Color.orange.opacity(0.15), round: round)
            }
            if round.options.holeMatchEnabled {
                sectionDivider(title: " ").frame(width: nameWidth)
                stickyPlayerSection(title: "HM", tint: Color.blue.opacity(0.12), round: round)
            }
            if round.options.lasVegasEnabled {
                sectionDivider(title: " ").frame(width: nameWidth)
                // 右ペイン: ホールヘッダ → 差(A)行 → 選手行 と行数を一致させる
                cellText("LV", bold: true, width: nameWidth, height: cellHeight)
                    .background(Color.indigo.opacity(0.12))
                cellText("差(A)", bold: true, width: nameWidth, height: cellHeight)
                    .background(Color.indigo.opacity(0.18))
                stickyPlayerSection(
                    title: "LV",
                    tint: Color.indigo.opacity(0.08),
                    round: round,
                    skipHeader: true,
                    rowHeight: lvPlayerRowHeight
                )
            }
            if round.options.snakeEnabled {
                sectionDivider(title: " ").frame(width: nameWidth)
                stickyPlayerSection(title: "蛇", tint: Color.purple.opacity(0.12), round: round)
            }
            if round.options.sonchoEnabled {
                sectionDivider(title: " ").frame(width: nameWidth)
                stickyPlayerSection(title: "村長", tint: RivieraTheme.sand.opacity(0.35), round: round)
            }
            if round.options.honestJohnEnabled {
                sectionDivider(title: " ").frame(width: nameWidth)
                stickyPlayerSection(title: "OJ", tint: Color.teal.opacity(0.12), round: round)
            }
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 1)
        }
    }

    private func stickyPlayerSection(
        title: String,
        tint: Color,
        round: GolfRound,
        skipHeader: Bool = false,
        rowHeight: CGFloat? = nil,
        includeParsRow: Bool = false,
        includeYardsRow: Bool = false
    ) -> some View {
        let h = rowHeight ?? cellHeight
        return VStack(spacing: 0) {
            if !skipHeader {
                cellText(title, bold: true, width: nameWidth, height: cellHeight)
                    .background(tint)
            }
            if includeParsRow {
                cellText("Par", bold: true, width: nameWidth, height: yardsRowHeight)
                    .background(RivieraTheme.fairway.opacity(0.14))
            }
            if includeYardsRow {
                let label = round.selectedTeeName.isEmpty ? "yd" : round.selectedTeeName
                cellText(label, bold: true, width: nameWidth, height: yardsRowHeight)
                    .background(RivieraTheme.fairway.opacity(0.10))
            }
            ForEach(Array(round.players.enumerated()), id: \.element.id) { index, p in
                let theme = PlayerTheme.color(at: index)
                Text(p.name)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(width: nameWidth, height: h)
                    .overlay(Rectangle().stroke(theme.opacity(0.45), lineWidth: 0.5))
                    .background(PlayerTheme.rowFill(at: index, focused: false))
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(.clear, lineWidth: 2)
                    )
            }
        }
    }

    // MARK: - Score (all players at once)

    private func scoreBlock(round: GolfRound) -> some View {
        VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: RivieraTheme.fairway.opacity(0.15),
                nineTint: RivieraTheme.fairway.opacity(0.22),
                totalTint: RivieraTheme.fairway.opacity(0.28)
            )
            nineSplitParsRow(round: round)
            if round.hasHoleYards {
                nineSplitYardsRow(round: round)
            }
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        scoreHoleButton(round: round, playerId: p.id, hole: h)
                    }
                    let out = strokesSum(round: round, playerId: p.id, holes: 1...9)
                    cellText(out > 0 ? "\(out)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(RivieraTheme.fairway.opacity(0.10))
                    ForEach(10...18, id: \.self) { h in
                        scoreHoleButton(round: round, playerId: p.id, hole: h)
                    }
                    let inn = strokesSum(round: round, playerId: p.id, holes: 10...18)
                    cellText(inn > 0 ? "\(inn)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(RivieraTheme.fairway.opacity(0.10))
                    let tot = out + inn
                    cellText(tot > 0 ? "\(tot)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func scoreHoleButton(round: GolfRound, playerId: UUID, hole: Int) -> some View {
        let par = round.holes.first(where: { $0.holeNumber == hole })?.par ?? 4
        let strokes = strokes(round: round, playerId: playerId, hole: hole)
        return Button {
            guard !round.isSettled else { return }
            openScoreEditor(round: round, hole: hole)
        } label: {
            ScoreToParCell(
                par: par,
                strokes: strokes,
                width: cellWidth,
                height: cellHeight
            )
        }
        .buttonStyle(.plain)
        .disabled(round.isSettled)
    }

    private func openScoreEditor(round: GolfRound, hole: Int) {
        let par = round.holes.first(where: { $0.holeNumber == hole })?.par ?? 4
        var draft: [UUID: PlayerHoleEntry] = [:]
        for p in round.players {
            var e = entry(round: round, playerId: p.id, hole: hole) ?? PlayerHoleEntry(playerId: p.id)
            e.playerId = p.id
            if e.strokes == 0 {
                e.strokes = par
            }
            draft[p.id] = e
        }
        scoreDraft = draft
        scoreHoleTarget = ScoreHoleTarget(holeNumber: hole)
    }

    // MARK: - Olympics

    private func olympicsBlock(round: GolfRound) -> some View {
        let byHole = OlympicsCalculator.scoreRound(round)
        var map: [Int: [UUID: Int]] = [:]
        for hole in byHole {
            var per: [UUID: Int] = [:]
            for row in hole.perPlayer {
                per[row.playerId] = row.totalPoints
            }
            map[hole.holeNumber] = per
        }

        return VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: Color.orange.opacity(0.15),
                nineTint: Color.orange.opacity(0.22),
                totalTint: Color.orange.opacity(0.28)
            )
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        olympicsHoleButton(round: round, playerId: p.id, hole: h, map: map)
                    }
                    let out = pointsSum(map: map, playerId: p.id, holes: 1...9)
                    cellText(out == 0 ? "—" : "\(out)", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color.orange.opacity(0.10))
                    ForEach(10...18, id: \.self) { h in
                        olympicsHoleButton(round: round, playerId: p.id, hole: h, map: map)
                    }
                    let inn = pointsSum(map: map, playerId: p.id, holes: 10...18)
                    cellText(inn == 0 ? "—" : "\(inn)", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color.orange.opacity(0.10))
                    let tot = out + inn
                    cellText(tot == 0 ? "—" : "\(tot)", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func olympicsHoleButton(
        round: GolfRound,
        playerId: UUID,
        hole: Int,
        map: [Int: [UUID: Int]]
    ) -> some View {
        let pts = map[hole]?[playerId] ?? 0
        let holeEntry = entry(round: round, playerId: playerId, hole: hole)
        return Button {
            guard !round.isSettled else { return }
            openScoreEditor(round: round, hole: hole)
        } label: {
            olympicsCellLabel(entry: holeEntry, points: pts, focused: false, rowFocused: false)
        }
        .buttonStyle(.plain)
        .disabled(round.isSettled)
    }

    /// 1–9 | 前 | 10–18 | 後 | 計
    private func nineSplitHeaderRow(holeTint: Color, nineTint: Color, totalTint: Color) -> some View {
        HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { h in
                cellText("\(h)", bold: true, width: cellWidth, height: cellHeight)
                    .background(holeTint)
            }
            cellText("前", bold: true, width: cellWidth, height: cellHeight)
                .background(nineTint)
            ForEach(10...18, id: \.self) { h in
                cellText("\(h)", bold: true, width: cellWidth, height: cellHeight)
                    .background(holeTint)
            }
            cellText("後", bold: true, width: cellWidth, height: cellHeight)
                .background(nineTint)
            cellText("計", bold: true, width: cellWidth, height: cellHeight)
                .background(totalTint)
        }
    }

    private func nineSplitParsRow(round: GolfRound) -> some View {
        let tint = RivieraTheme.fairway.opacity(0.12)
        let nineTint = RivieraTheme.fairway.opacity(0.18)
        let out = round.coursePars.prefix(9).reduce(0, +)
        let inn = round.coursePars.suffix(9).reduce(0, +)
        let tot = out + inn
        return HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { h in
                let par = round.holes.first(where: { $0.holeNumber == h })?.par
                    ?? (round.coursePars.indices.contains(h - 1) ? round.coursePars[h - 1] : 4)
                cellText("\(par)", bold: true, width: cellWidth, height: yardsRowHeight)
                    .background(tint)
            }
            cellText("\(out)", bold: true, width: cellWidth, height: yardsRowHeight)
                .background(nineTint)
            ForEach(10...18, id: \.self) { h in
                let par = round.holes.first(where: { $0.holeNumber == h })?.par
                    ?? (round.coursePars.indices.contains(h - 1) ? round.coursePars[h - 1] : 4)
                cellText("\(par)", bold: true, width: cellWidth, height: yardsRowHeight)
                    .background(tint)
            }
            cellText("\(inn)", bold: true, width: cellWidth, height: yardsRowHeight)
                .background(nineTint)
            cellText("\(tot)", bold: true, width: cellWidth, height: yardsRowHeight)
                .background(RivieraTheme.fairway.opacity(0.24))
        }
    }

    private func nineSplitYardsRow(round: GolfRound) -> some View {
        let tint = RivieraTheme.fairway.opacity(0.08)
        let nineTint = RivieraTheme.fairway.opacity(0.14)
        let out = round.courseYards.prefix(9).reduce(0, +)
        let inn = round.courseYards.suffix(9).reduce(0, +)
        let tot = out + inn
        return HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { h in
                let y = round.yards(forHole: h)
                cellText(y > 0 ? "\(y)" : "—", bold: false, width: cellWidth, height: yardsRowHeight)
                    .background(tint)
            }
            cellText(out > 0 ? "\(out)" : "—", bold: true, width: cellWidth, height: yardsRowHeight)
                .background(nineTint)
            ForEach(10...18, id: \.self) { h in
                let y = round.yards(forHole: h)
                cellText(y > 0 ? "\(y)" : "—", bold: false, width: cellWidth, height: yardsRowHeight)
                    .background(tint)
            }
            cellText(inn > 0 ? "\(inn)" : "—", bold: true, width: cellWidth, height: yardsRowHeight)
                .background(nineTint)
            cellText(tot > 0 ? "\(tot)" : "—", bold: true, width: cellWidth, height: yardsRowHeight)
                .background(RivieraTheme.fairway.opacity(0.18))
        }
    }

    private func strokesSum(round: GolfRound, playerId: UUID, holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { $0 + strokes(round: round, playerId: playerId, hole: $1) }
    }

    private func pointsSum(map: [Int: [UUID: Int]], playerId: UUID, holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { $0 + (map[$1]?[playerId] ?? 0) }
    }

    private func olympicsCellLabel(entry: PlayerHoleEntry?, points: Int, focused: Bool, rowFocused: Bool) -> some View {
        let icons = olympicsIcons(entry)
        let showValue = points != 0 || hasOlympicsMarks(entry)
        return VStack(spacing: 1) {
            if icons.isEmpty {
                Text(showValue ? "\(points)" : "·")
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
        .clipped()
        .background(focused ? Color.yellow.opacity(0.55) : (rowFocused ? Color.yellow.opacity(0.12) : Color.clear))
        .contentShape(Rectangle())
        .overlay(
            Rectangle().stroke(
                focused ? RivieraTheme.fairway : Color.secondary.opacity(0.25),
                lineWidth: focused ? 2.5 : 0.5
            )
        )
    }

    private func hasOlympicsMarks(_ entry: PlayerHoleEntry?) -> Bool {
        guard let e = entry else { return false }
        return e.medal != nil
            || e.chipInFromOffGreen
            || e.declaredPin
            || e.pinDistanceQualified
            || e.banker
            || e.nameLick
            || e.awaya
            || e.markedThreePutt
            || e.pinFailed
            || e.parOn
            || e.birdieOn
            || e.nearestPinContender
            || e.fireman
            || e.declaredReach
            || e.outerPinDeclared
            || e.manualPointAdjust != 0
            || e.pinPointsOverride != nil
            || e.bankerPointsOverride != nil
            || e.parOnPointsOverride != nil
            || e.birdieOnPointsOverride != nil
            || !e.eventLog.isEmpty
            || e.putts >= 3
    }

    private func olympicsIcons(_ entry: PlayerHoleEntry?) -> [String] {
        guard let e = entry else { return [] }
        var icons: [String] = []
        if e.medal != nil || e.chipInFromOffGreen { icons.append("medal.fill") }
        if e.declaredReach { icons.append("bolt.fill") }
        if e.declaredPin || e.outerPinDeclared { icons.append("ruler") }
        if e.pinFailed { icons.append("xmark.circle") }
        if e.markedThreePutt || e.putts >= 3 { icons.append("3.circle") }
        if e.banker { icons.append("beach.umbrella.fill") }
        if e.nameLick { icons.append("drop.fill") }
        if e.awaya { icons.append("leaf.fill") }
        if e.nearestPinContender { icons.append("scope") }
        if e.fireman { icons.append("flame.fill") }
        return icons
    }

    // MARK: - Side games

    private func holeMatchSectionTitle(_ round: GolfRound) -> String {
        switch round.options.holeMatchMode {
        case .allPlayAll:
            return "ホールマッチ（全員対抗・タップで手動）"
        case .sides:
            let a = round.options.holeMatchSideA.count
            let b = round.options.holeMatchSideB.count
            return "ホールマッチ（\(a)対\(b)・タップで手動）"
        }
    }

    private var holeMatchDialogTitle: String {
        if let h = holeMatchEditHole {
            return "ホール \(h) の勝ち"
        }
        return "ホールマッチ"
    }

    @ViewBuilder
    private var holeMatchDialogButtons: some View {
        if let hole = holeMatchEditHole, let round = currentRound {
            Button("自動（スコア）") {
                setHoleMatch(hole: hole, manual: false, draw: false, winners: [])
            }
            Button("引き分け") {
                setHoleMatch(hole: hole, manual: true, draw: true, winners: [])
            }
            if round.options.holeMatchMode == .sides {
                let aNames = round.players.filter { round.options.holeMatchSideA.contains($0.id) }.map(\.name).joined(separator: "・")
                let bNames = round.players.filter { round.options.holeMatchSideB.contains($0.id) }.map(\.name).joined(separator: "・")
                Button("サイドAの勝ち（\(aNames)）") {
                    setHoleMatch(hole: hole, manual: true, draw: false, winners: round.options.holeMatchSideA)
                }
                Button("サイドBの勝ち（\(bNames)）") {
                    setHoleMatch(hole: hole, manual: true, draw: false, winners: round.options.holeMatchSideB)
                }
            }
            ForEach(round.players) { p in
                Button("\(p.name) の勝ち") {
                    let winners: [UUID]
                    if round.options.holeMatchMode == .sides {
                        if round.options.holeMatchSideA.contains(p.id) {
                            winners = round.options.holeMatchSideA
                        } else if round.options.holeMatchSideB.contains(p.id) {
                            winners = round.options.holeMatchSideB
                        } else {
                            winners = [p.id]
                        }
                    } else {
                        winners = [p.id]
                    }
                    setHoleMatch(hole: hole, manual: true, draw: false, winners: winners)
                }
            }
        }
    }

    private func holeMatchBlock(round: GolfRound) -> some View {
        let outcomes = HoleMatchCalculator.outcomes(round: round)
        let yen = HoleMatchCalculator.yenByPlayer(round: round)
        let nineTint = Color.blue.opacity(0.18)
        return VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: Color.blue.opacity(0.12),
                nineTint: nineTint,
                totalTint: Color.blue.opacity(0.22)
            )
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        holeMatchMarkCell(outcomes: outcomes, playerId: p.id, hole: h, round: round)
                    }
                    let outW = winCount(outcomes: outcomes, playerId: p.id, holes: 1...9)
                    cellText(outW > 0 ? "\(outW)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    ForEach(10...18, id: \.self) { h in
                        holeMatchMarkCell(outcomes: outcomes, playerId: p.id, hole: h, round: round)
                    }
                    let inW = winCount(outcomes: outcomes, playerId: p.id, holes: 10...18)
                    cellText(inW > 0 ? "\(inW)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    let tot = outW + inW
                    let y = yen[p.id, default: 0]
                    cellText(tot > 0 || y != 0 ? "\(tot)/\(compactYen(y))" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func holeMatchMarkCell(
        outcomes: [HoleMatchCalculator.HoleOutcome],
        playerId: UUID,
        hole: Int,
        round: GolfRound
    ) -> some View {
        let outcome = (hole - 1 < outcomes.count) ? outcomes[hole - 1] : nil
        let won = outcome?.winnerIds.contains(playerId) == true
        let draw = outcome?.isDraw == true
        let manual = outcome?.isManual == true
        let mark: String = {
            if won { return "W" }
            if draw { return "=" }
            return "·"
        }()
        return Button {
            guard !round.isSettled else { return }
            holeMatchEditHole = hole
        } label: {
            cellText(mark, bold: won || draw, width: cellWidth, height: cellHeight)
                .foregroundStyle(won ? RivieraTheme.fairway : (draw ? Color.orange : .secondary))
                .background(manual ? Color.blue.opacity(0.12) : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(round.isSettled)
    }

    private func winCount(
        outcomes: [HoleMatchCalculator.HoleOutcome],
        playerId: UUID,
        holes: ClosedRange<Int>
    ) -> Int {
        holes.reduce(0) { sum, h in
            let idx = h - 1
            guard idx < outcomes.count, outcomes[idx].winnerIds.contains(playerId) else { return sum }
            return sum + 1
        }
    }

    private func setHoleMatch(hole: Int, manual: Bool, draw: Bool, winners: [UUID]) {
        guard var r = store.rounds.first(where: { $0.id == roundId }), !r.isSettled,
              let hi = r.holes.firstIndex(where: { $0.holeNumber == hole }) else { return }
        r.holes[hi].holeMatchManual = manual
        r.holes[hi].holeMatchManualDraw = draw
        r.holes[hi].holeMatchManualWinnerIds = draw || !manual ? [] : winners
        store.updateRound(r)
        holeMatchEditHole = nil
    }

    private func lasVegasBlock(round: GolfRound) -> some View {
        let diffs = LasVegasCalculator.holeDiffs(round: round)
        let teamsByHole = LasVegasCalculator.teamsByHole(round: round)
        let yen = LasVegasCalculator.yenByPlayer(round: round)
        let teamAColor = Color.indigo.opacity(0.22)
        let teamBColor = Color.orange.opacity(0.22)
        let nineTint = Color.indigo.opacity(0.18)
        let outDiff = rangeSum(diffs, holes: 1...9)
        let inDiff = rangeSum(diffs, holes: 10...18)
        let totalDiff = outDiff + inDiff
        return VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: Color.indigo.opacity(0.12),
                nineTint: nineTint,
                totalTint: Color.indigo.opacity(0.22)
            )
            // Diff row (Team A perspective)
            HStack(spacing: 0) {
                ForEach(1...9, id: \.self) { h in
                    lasVegasDiffCell(diffs: diffs, hole: h)
                }
                signedSummaryCell(outDiff, width: cellWidth, height: cellHeight)
                    .background(nineTint.opacity(0.55))
                ForEach(10...18, id: \.self) { h in
                    lasVegasDiffCell(diffs: diffs, hole: h)
                }
                signedSummaryCell(inDiff, width: cellWidth, height: cellHeight)
                    .background(nineTint.opacity(0.55))
                signedSummaryCell(totalDiff, width: cellWidth, height: cellHeight)
                    .background(Color(.tertiarySystemFill))
            }
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        lasVegasPlayerHoleCell(
                            playerId: p.id, hole: h,
                            diffs: diffs, teamsByHole: teamsByHole,
                            teamAColor: teamAColor, teamBColor: teamBColor
                        )
                    }
                    let outPts = lasVegasTeamPointsSum(
                        playerId: p.id, holes: 1...9, diffs: diffs, teamsByHole: teamsByHole
                    )
                    signedSummaryCell(outPts, width: cellWidth, height: lvPlayerRowHeight)
                        .background(nineTint.opacity(0.55))
                    ForEach(10...18, id: \.self) { h in
                        lasVegasPlayerHoleCell(
                            playerId: p.id, hole: h,
                            diffs: diffs, teamsByHole: teamsByHole,
                            teamAColor: teamAColor, teamBColor: teamBColor
                        )
                    }
                    let inPts = lasVegasTeamPointsSum(
                        playerId: p.id, holes: 10...18, diffs: diffs, teamsByHole: teamsByHole
                    )
                    signedSummaryCell(inPts, width: cellWidth, height: lvPlayerRowHeight)
                        .background(nineTint.opacity(0.55))
                    let y = yen[p.id, default: 0]
                    cellText(compactYen(y), bold: true, width: cellWidth, height: lvPlayerRowHeight)
                        .foregroundStyle(y >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func lasVegasDiffCell(diffs: [Int], hole: Int) -> some View {
        let d = (hole - 1 < diffs.count) ? diffs[hole - 1] : 0
        return cellText(d == 0 ? "·" : String(format: "%+d", d), bold: d != 0, width: cellWidth, height: cellHeight)
            .foregroundStyle(d > 0 ? RivieraTheme.fairway : (d < 0 ? RivieraTheme.flag : .secondary))
    }

    private func lasVegasPlayerHoleCell(
        playerId: UUID,
        hole: Int,
        diffs: [Int],
        teamsByHole: [LasVegasCalculator.HoleTeams],
        teamAColor: Color,
        teamBColor: Color
    ) -> some View {
        let side = (hole - 1 < teamsByHole.count) ? teamsByHole[hole - 1].side(of: playerId) : nil
        let d = (hole - 1 < diffs.count) ? diffs[hole - 1] : 0
        let teamPts: Int? = {
            switch side {
            case .a: return d
            case .b: return -d
            case nil: return nil
            }
        }()
        return lasVegasTeamCell(
            side: side,
            teamPts: teamPts,
            width: cellWidth,
            height: lvPlayerRowHeight,
            teamAColor: teamAColor,
            teamBColor: teamBColor
        )
    }

    private func lasVegasTeamPointsSum(
        playerId: UUID,
        holes: ClosedRange<Int>,
        diffs: [Int],
        teamsByHole: [LasVegasCalculator.HoleTeams]
    ) -> Int {
        holes.reduce(0) { sum, h in
            let side = (h - 1 < teamsByHole.count) ? teamsByHole[h - 1].side(of: playerId) : nil
            let d = (h - 1 < diffs.count) ? diffs[h - 1] : 0
            switch side {
            case .a: return sum + d
            case .b: return sum - d
            case nil: return sum
            }
        }
    }

    private func lasVegasTeamCell(
        side: LasVegasCalculator.TeamSide?,
        teamPts: Int?,
        width: CGFloat,
        height: CGFloat,
        teamAColor: Color,
        teamBColor: Color
    ) -> some View {
        let label: String = {
            switch side {
            case .a: return "A"
            case .b: return "B"
            case nil: return "·"
            }
        }()
        let ptsText: String = {
            guard let teamPts, teamPts != 0 else { return " " }
            return String(format: "%+d", teamPts)
        }()
        return VStack(spacing: 0) {
            Text(label)
                .font(.caption.weight(side != nil ? .bold : .regular))
                .foregroundStyle(side == .a ? Color.indigo : (side == .b ? Color.orange : .secondary))
            Text(ptsText)
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(
                    (teamPts ?? 0) > 0
                        ? RivieraTheme.fairway
                        : ((teamPts ?? 0) < 0 ? RivieraTheme.flag : .secondary)
                )
                .opacity((teamPts ?? 0) == 0 ? 0 : 1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: width, height: height)
        .background(side == .a ? teamAColor : (side == .b ? teamBColor : Color.clear))
        .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
    }

    private func snakeBlock(round: GolfRound) -> some View {
        let holders = SnakeCalculator.holderByHole(round: round)
        let yen = SnakeCalculator.run(round: round).yen
        let nineTint = Color.purple.opacity(0.18)
        return VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: Color.purple.opacity(0.12),
                nineTint: nineTint,
                totalTint: Color.purple.opacity(0.22)
            )
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        snakeMarkCell(holders: holders, playerId: p.id, hole: h)
                    }
                    let outC = snakeHoldCount(holders: holders, playerId: p.id, holes: 1...9)
                    cellText(outC > 0 ? "\(outC)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    ForEach(10...18, id: \.self) { h in
                        snakeMarkCell(holders: holders, playerId: p.id, hole: h)
                    }
                    let inC = snakeHoldCount(holders: holders, playerId: p.id, holes: 10...18)
                    cellText(inC > 0 ? "\(inC)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    let y = yen[p.id, default: 0]
                    cellText(compactYen(y), bold: true, width: cellWidth, height: cellHeight)
                        .foregroundStyle(y >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func snakeMarkCell(holders: [UUID?], playerId: UUID, hole: Int) -> some View {
        let hold = (hole - 1 < holders.count) ? holders[hole - 1] : nil
        let mark = hold == playerId ? "蛇" : "·"
        return cellText(mark, bold: mark == "蛇", width: cellWidth, height: cellHeight)
            .foregroundStyle(mark == "蛇" ? Color.purple : .secondary)
    }

    private func snakeHoldCount(holders: [UUID?], playerId: UUID, holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { sum, h in
            let idx = h - 1
            guard idx < holders.count, holders[idx] == playerId else { return sum }
            return sum + 1
        }
    }

    private func sonchoBlock(round: GolfRound) -> some View {
        let winners = Set(SonchoCalculator.winnerIds(round: round))
        let yen = SonchoCalculator.yenByPlayer(round: round)
        let nineTint = RivieraTheme.sand.opacity(0.45)
        return VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: RivieraTheme.sand.opacity(0.35),
                nineTint: nineTint,
                totalTint: RivieraTheme.sand.opacity(0.55)
            )
            ForEach(round.players) { p in
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        let s = strokes(round: round, playerId: p.id, hole: h)
                        cellText(s > 0 ? "\(s)" : "·", bold: false, width: cellWidth, height: cellHeight)
                    }
                    let out = strokesSum(round: round, playerId: p.id, holes: 1...9)
                    cellText(out > 0 ? "\(out)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    ForEach(10...18, id: \.self) { h in
                        let s = strokes(round: round, playerId: p.id, hole: h)
                        cellText(s > 0 ? "\(s)" : "·", bold: false, width: cellWidth, height: cellHeight)
                    }
                    let inn = strokesSum(round: round, playerId: p.id, holes: 10...18)
                    cellText(inn > 0 ? "\(inn)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    let g = out + inn
                    let y = yen[p.id, default: 0]
                    let label = winners.contains(p.id) ? "長\(g)/\(compactYen(y))" : "\(g)/\(compactYen(y))"
                    cellText(g > 0 || y != 0 ? label : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(winners.contains(p.id) ? RivieraTheme.sand.opacity(0.45) : Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func honestJohnBlock(round: GolfRound) -> some View {
        let rows = Dictionary(uniqueKeysWithValues: HonestJohnCalculator.results(round: round).map { ($0.playerId, $0) })
        let yen = HonestJohnCalculator.yenByPlayer(round: round)
        let nineTint = Color.teal.opacity(0.18)
        return VStack(spacing: 0) {
            nineSplitHeaderRow(
                holeTint: Color.teal.opacity(0.12),
                nineTint: nineTint,
                totalTint: Color.teal.opacity(0.22)
            )
            ForEach(round.players) { p in
                let row = rows[p.id]
                HStack(spacing: 0) {
                    ForEach(1...9, id: \.self) { h in
                        let s = strokes(round: round, playerId: p.id, hole: h)
                        cellText(s > 0 ? "\(s)" : "·", bold: false, width: cellWidth, height: cellHeight)
                            .foregroundStyle(.secondary)
                    }
                    let out = strokesSum(round: round, playerId: p.id, holes: 1...9)
                    cellText(out > 0 ? "\(out)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    ForEach(10...18, id: \.self) { h in
                        let s = strokes(round: round, playerId: p.id, hole: h)
                        cellText(s > 0 ? "\(s)" : "·", bold: false, width: cellWidth, height: cellHeight)
                            .foregroundStyle(.secondary)
                    }
                    let inn = strokesSum(round: round, playerId: p.id, holes: 10...18)
                    cellText(inn > 0 ? "\(inn)" : "—", bold: true, width: cellWidth, height: cellHeight)
                        .background(nineTint.opacity(0.55))
                    let declared = row?.declared ?? p.honestJohnDeclared
                    let actual = row?.actual ?? 0
                    let y = yen[p.id, default: 0]
                    let text = actual > 0 ? "\(declared)→\(actual)/\(compactYen(y))" : "—"
                    cellText(text, bold: true, width: cellWidth, height: cellHeight)
                        .background(Color(.tertiarySystemFill))
                }
            }
        }
    }

    private func rangeSum(_ values: [Int], holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { sum, h in
            let idx = h - 1
            guard idx >= 0, idx < values.count else { return sum }
            return sum + values[idx]
        }
    }

    private func signedSummaryCell(_ value: Int, width: CGFloat, height: CGFloat) -> some View {
        cellText(value == 0 ? "—" : String(format: "%+d", value), bold: value != 0, width: width, height: height)
            .foregroundStyle(value > 0 ? RivieraTheme.fairway : (value < 0 ? RivieraTheme.flag : .secondary))
    }

    private func compactYen(_ v: Int) -> String {
        if v > 0 { return "+\(v)" }
        if v < 0 { return "\(v)" }
        return "0"
    }

    private func sectionDivider(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: sectionBandHeight)
            .background(Color(.systemGroupedBackground))
    }

    private func cellText(_ text: String, bold: Bool, width: CGFloat, height: CGFloat) -> some View {
        Text(text)
            .font(bold ? .caption.weight(.bold) : .caption.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, height: height)
            .clipped()
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: - Mutations

    private func commitHoleEntries(hole: Int, entriesByPlayer: [UUID: PlayerHoleEntry]) {
        guard var r = store.rounds.first(where: { $0.id == roundId }), !r.isSettled,
              let hi = r.holes.firstIndex(where: { $0.holeNumber == hole }) else { return }

        let exclusiveMedals: Set<OlympicMedal> = [.gold, .silver, .bronze, .iron]
        var claimedMedals = Set<OlympicMedal>()
        var claimedNearestPin = false
        for player in r.players {
            guard var saved = entriesByPlayer[player.id] else { continue }
            saved.playerId = player.id
            if let m = saved.medal, exclusiveMedals.contains(m) {
                if claimedMedals.contains(m) {
                    saved.medal = nil
                } else {
                    claimedMedals.insert(m)
                }
            }
            if saved.nearestPinContender {
                if claimedNearestPin {
                    saved.nearestPinContender = false
                } else {
                    claimedNearestPin = true
                }
            }
            if let ei = r.holes[hi].entries.firstIndex(where: { $0.playerId == player.id }) {
                saved.id = r.holes[hi].entries[ei].id
                r.holes[hi].entries[ei] = saved
            } else {
                r.holes[hi].entries.append(saved)
            }
        }

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
}

private struct ScoreHoleTarget: Identifiable {
    var id: Int { holeNumber }
    let holeNumber: Int
}
