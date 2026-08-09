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

/// 1ホール分・全員のスコアを対パー矢印で入力
struct CompactScoreEditor: View {
    @Binding var strokesByPlayer: [UUID: Int]
    let players: [Player]
    let holeNumber: Int
    let par: Int
    var yards: Int = 0
    var teeName: String = ""
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if yards > 0 {
                        Text("パー \(par) · \(yards) yd\(teeName.isEmpty ? "" : "（\(teeName)）") を基準に矢印で調整。記号はスコアカードと同じです。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("パー \(par) を基準に矢印で調整。記号はスコアカードと同じです。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("全員のスコア") {
                    ForEach(players) { player in
                        playerRow(player)
                    }
                }

                Section {
                    Button("全員をパーで入力") {
                        for p in players {
                            strokesByPlayer[p.id] = par
                        }
                    }
                    Button("全員クリア", role: .destructive) {
                        for p in players {
                            strokesByPlayer[p.id] = 0
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

    private func playerRow(_ player: Player) -> some View {
        let strokes = strokesByPlayer[player.id, default: 0]
        let toPar = strokes > 0 ? strokes - par : 0
        let entered = strokes > 0
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(entered
                     ? "\(ScorecardSymbol.menuTitle(toPar: toPar))  ·  \(strokes)打"
                     : "クリア済")
                    .font(.caption2)
                    .foregroundStyle(entered ? ScorecardSymbol.color(toPar: toPar) : .secondary)
            }
            Spacer(minLength: 4)
            Stepper(value: Binding(
                get: { toPar },
                set: { delta in
                    strokesByPlayer[player.id] = max(1, par + delta)
                }
            ), in: -5...10) {
                Text(entered ? ScorecardSymbol.mark(toPar: toPar) : "－")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(entered ? ScorecardSymbol.color(toPar: toPar) : .secondary)
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("クリア", role: .destructive) {
                strokesByPlayer[player.id] = 0
            }
        }
    }
}

/// オリンピック用（スクロール可能なシート）
struct CompactOlympicsEditor: View {
    @Binding var entry: PlayerHoleEntry
    let round: GolfRound
    let par: Int
    let playerName: String
    let holeNumber: Int
    let playerIndex: Int
    let playerCount: Int
    let nearestPinCarryIn: Int
    let onCommit: () -> Void
    let onCancel: () -> Void
    let onGoPrevious: () -> Void
    let onGoNext: () -> Void

    private var preview: (total: Int, lines: [PointLine], reachApplied: Bool) {
        OlympicsStatus.previewPoints(round: round, holeNumber: holeNumber, draft: entry)
    }

    private var canGoPrevious: Bool { playerIndex > 0 }
    private var canGoNext: Bool { playerIndex + 1 < playerCount }

    /// 金銀銅鉄は1ホールにつき各1人まで（◆は複数可）
    private static let exclusiveMedals: Set<OlympicMedal> = [.gold, .silver, .bronze, .iron]

    private var exclusiveMedalsTakenByOthers: Set<OlympicMedal> {
        guard let hole = round.holes.first(where: { $0.holeNumber == holeNumber }) else { return [] }
        var taken = Set<OlympicMedal>()
        for e in hole.entries where e.playerId != entry.playerId {
            if let m = e.medal, Self.exclusiveMedals.contains(m) {
                taken.insert(m)
            }
        }
        return taken
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    focusBanner
                    pointsPreview

                    sectionTitle("パット", icon: "circle.grid.2x2")
                    puttRow

                    sectionTitle("共通", icon: "bolt.fill")
                    reachToggle
                    Text(entry.declaredReach
                         ? "リーチON — 成功時は加点・減点とも×2／外れは加点の−2倍"
                         : "リーチは減点ではありません。宣言すると対象点が2倍になります。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("加点", icon: "plus.circle.fill")
                            bonusColumn
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: 8) {
                            sectionTitle("減点", icon: "minus.circle.fill")
                            deductionColumn
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    sectionTitle("手動調整", icon: "plusminus.circle")
                    HStack {
                        Text("合計への加減")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Stepper(value: $entry.manualPointAdjust, in: -20...20) {
                            Text(entry.manualPointAdjust == 0 ? "±0" : String(format: "%+d", entry.manualPointAdjust))
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(
                                    entry.manualPointAdjust < 0
                                        ? RivieraTheme.flag
                                        : (entry.manualPointAdjust > 0 ? RivieraTheme.fairway : .secondary)
                                )
                                .frame(minWidth: 44, alignment: .trailing)
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding()
            }
            .simultaneousGesture(playerSwipeGesture)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("オリンピック入力")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItemGroup(placement: .principal) {
                    HStack(spacing: 12) {
                        Button(action: onGoPrevious) {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(!canGoPrevious)

                        Text("\(playerIndex + 1)/\(playerCount)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)

                        Button(action: onGoNext) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(!canGoNext)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onCommit()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var playerSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) * 1.2, abs(dx) > 60 else { return }
                if dx < 0, canGoNext {
                    onGoNext()
                } else if dx > 0, canGoPrevious {
                    onGoPrevious()
                }
            }
    }

    // MARK: - Focus

    private var focusBanner: some View {
        HStack(spacing: 6) {
            Button(action: onGoPrevious) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canGoPrevious ? Color.white : Color.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canGoPrevious)

            Image(systemName: "person.crop.circle.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 1) {
                Text(playerName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("H\(holeNumber) · \(strokesCaption)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
            Text("スワイプで切替")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))

            Button(action: onGoNext) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canGoNext ? Color.white : Color.white.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [RivieraTheme.fairwayDeep, RivieraTheme.fairway], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.yellow.opacity(0.7), lineWidth: 1.5)
        )
    }

    private var pointsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("このホールの速報点")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(preview.total) 点")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(preview.total >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
            }
            if preview.reachApplied {
                Label("リーチ適用中", systemImage: "bolt.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.purple)
            }
            ForEach(preview.lines) { line in
                HStack {
                    Text(line.label).font(.caption2)
                    Spacer()
                    Text("\(line.points)")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(line.points < 0 ? RivieraTheme.flag : RivieraTheme.fairway)
                }
            }
            if preview.lines.isEmpty {
                Text("まだ加点・減点がありません")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Inputs

    private var puttRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("パット数")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Stepper(value: $entry.putts, in: 0...8) {
                    Text("\(entry.putts)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.blue)
                        .frame(minWidth: 28, alignment: .trailing)
                }
            }
            Text("点数には加算しません。3パット減点・リーチ成否・蛇・焼き鳥判定にのみ使用。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var bonusColumn: some View {
        VStack(spacing: 6) {
            medalChip(nil, "無", "circle")
            medalChip(.gold, "金 +\(pts.gold)", "medal.fill")
            medalChip(.silver, "銀 +\(pts.silver)", "medal")
            medalChip(.bronze, "銅 +\(pts.bronze)", "medal")
            medalChip(.iron, "鉄 +\(pts.iron)", "circle.grid.cross")
            medalChip(.diamond, "◆ +\(pts.diamond)", "diamond.fill")

            Divider().padding(.vertical, 2)

            pinChip
            flagChip("砂 +\(pts.banker)", "beach.umbrella.fill", flag: \.banker, defaultPoints: pts.banker, override: \.bankerPointsOverride)
            flagChip("パーオン +\(pts.parOn)", "p.circle", flag: \.parOn, defaultPoints: pts.parOn, override: \.parOnPointsOverride)
            flagChip("Bオン +\(pts.birdieOn)", "b.circle", flag: \.birdieOn, defaultPoints: pts.birdieOn, override: \.birdieOnPointsOverride)
            iconToggle(
                "ニアピン +\(OlympicsCalculator.nearestPinPoints(carryIn: nearestPinCarryIn, base: pts.nearestPinBase))",
                "scope",
                $entry.nearestPinContender
            )
            iconToggle(
                "消防隊 +\(OlympicsCalculator.firemanPoints(carryIn: nearestPinCarryIn, base: pts.firemanBase))",
                "flame.fill",
                $entry.fireman
            )
            Text("いま\(OlympicsCalculator.nearestPinFloor(carryIn: nearestPinCarryIn))階建て（CO\(nearestPinCarryIn)）。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            iconToggle("ティーGIR", "flag.fill", $entry.greenInRegulationTee)
            iconToggle("外チップ", "arrow.down.right.circle", $entry.chipInFromOffGreen)

            let customBonuses = round.options.customPointRules.filter { $0.enabled && $0.points >= 0 }
            ForEach(customBonuses) { rule in
                customRuleChip(rule)
            }
        }
    }

    private var pts: OlympicsPointRules { round.options.olympicsPoints }

    private var deductionColumn: some View {
        VStack(spacing: 6) {
            iconToggle("舐め \(pts.nameLick)", "drop.fill", $entry.nameLick, tint: RivieraTheme.flag)
            iconToggle("あわや \(pts.awaya)", "leaf.fill", $entry.awaya, tint: .orange)
            let customPens = round.options.customPointRules.filter { $0.enabled && $0.points < 0 }
            ForEach(customPens) { rule in
                customRuleChip(rule, tint: RivieraTheme.flag)
            }
            Text("3パットはパット数から自動（点数は設定で変更可）")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func customRuleChip(_ rule: CustomPointRule, tint: Color = RivieraTheme.fairway) -> some View {
        let on = entry.customActiveRuleIds.contains(rule.id)
        let label = "\(rule.name) \(rule.points > 0 ? "+" : "")\(rule.points)"
        return chip(title: label, icon: rule.points < 0 ? "minus.circle" : "plus.circle", selected: on, tint: tint) {
            if on {
                entry.customActiveRuleIds.removeAll { $0 == rule.id }
            } else {
                entry.customActiveRuleIds.append(rule.id)
            }
        }
    }

    private var reachToggle: some View {
        chip(title: "リーチ×2", icon: "bolt.fill", selected: entry.declaredReach, tint: .purple) {
            entry.declaredReach.toggle()
            // パット数は変更しない（点数計算にパット数が混ざらないようにする）
        }
    }

    private var pinChip: some View {
        let on = entry.declaredPin || entry.outerPinDeclared
        let pinPts = pts.pin
        return chip(title: "竿/外竿 +\(pinPts)", icon: "ruler", selected: on, tint: RivieraTheme.fairway) {
            let next = !on
            entry.declaredPin = next
            entry.outerPinDeclared = false
            entry.pinDistanceQualified = next
            if next {
                if entry.pinPointsOverride == nil { entry.pinPointsOverride = pinPts }
            } else {
                entry.pinPointsOverride = nil
            }
        }
    }

    private func flagChip(
        _ title: String,
        _ icon: String,
        flag: WritableKeyPath<PlayerHoleEntry, Bool>,
        defaultPoints: Int,
        override: WritableKeyPath<PlayerHoleEntry, Int?>
    ) -> some View {
        chip(title: title, icon: icon, selected: entry[keyPath: flag], tint: RivieraTheme.fairway) {
            let next = !entry[keyPath: flag]
            entry[keyPath: flag] = next
            if next {
                if entry[keyPath: override] == nil {
                    entry[keyPath: override] = defaultPoints
                }
            } else {
                entry[keyPath: override] = nil
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RivieraTheme.fairwayDeep)
    }

    private var strokesCaption: String {
        guard entry.strokes > 0 else { return "スコア未入力" }
        let d = entry.strokes - par
        return "\(ScorecardSymbol.mark(toPar: d)) \(ScorecardSymbol.name(toPar: d))"
    }

    private func medalChip(_ medal: OlympicMedal?, _ title: String, _ icon: String) -> some View {
        let on = (medal == nil && entry.medal == nil) || (medal != nil && entry.medal == medal)
        let takenByOther = medal.map { exclusiveMedalsTakenByOthers.contains($0) } ?? false
        let disabled = takenByOther && !on
        return chip(title: title, icon: icon, selected: on, tint: .yellow, disabled: disabled) {
            guard !disabled else { return }
            entry.medal = medal
            if medal == .diamond { entry.chipInFromOffGreen = true }
            if medal != .diamond && medal != nil { entry.chipInFromOffGreen = false }
        }
    }

    private func iconToggle(_ title: String, _ icon: String, _ binding: Binding<Bool>, tint: Color = RivieraTheme.fairway) -> some View {
        chip(title: title, icon: icon, selected: binding.wrappedValue, tint: tint) {
            binding.wrappedValue.toggle()
        }
    }

    private func chip(
        title: String,
        icon: String? = nil,
        selected: Bool,
        tint: Color,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11))
                }
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
}

