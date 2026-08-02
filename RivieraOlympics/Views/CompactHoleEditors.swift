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

/// 対パー選択のコンボ風メニュー（スコアセル用）
struct ScoreToParMenu: View {
    let par: Int
    let strokes: Int
    let disabled: Bool
    let width: CGFloat
    let height: CGFloat
    let onSelect: (Int) -> Void

    private var toPar: Int? {
        strokes > 0 ? strokes - par : nil
    }

    var body: some View {
        Menu {
            Button("未入力", role: .destructive) { onSelect(0) }
            Section("良いスコア") {
                ForEach([-5, -4, -3, -2, -1], id: \.self) { delta in deltaButton(delta) }
            }
            Section("パー") { deltaButton(0) }
            Section("悪いスコア") {
                ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], id: \.self) { delta in deltaButton(delta) }
            }
        } label: {
            Text(toPar.map { ScorecardSymbol.mark(toPar: $0) } ?? "·")
                .font(.body.weight(.semibold))
                .foregroundStyle(toPar.map { ScorecardSymbol.color(toPar: $0) } ?? Color.secondary)
                .frame(width: width, height: height)
                .contentShape(Rectangle())
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
        }
        .disabled(disabled)
    }

    @ViewBuilder
    private func deltaButton(_ delta: Int) -> some View {
        let s = max(1, par + delta)
        Button {
            onSelect(s)
        } label: {
            HStack {
                Text(ScorecardSymbol.menuTitle(toPar: delta))
                if strokes == s { Image(systemName: "checkmark") }
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
    let onCommit: () -> Void
    let onCancel: () -> Void

    private var nineStatus: OlympicsStatus.NineStatus {
        // 下書きのリーチ／パットを反映した仮ラウンドで判定
        var draftRound = round
        if let hi = draftRound.holes.firstIndex(where: { $0.holeNumber == holeNumber }),
           let ei = draftRound.holes[hi].entries.firstIndex(where: { $0.playerId == entry.playerId }) {
            draftRound.holes[hi].entries[ei] = entry
        }
        return OlympicsStatus.status(round: draftRound, playerId: entry.playerId, holeNumber: holeNumber)
    }

    private var preview: (total: Int, lines: [PointLine], reachApplied: Bool) {
        OlympicsStatus.previewPoints(round: round, holeNumber: holeNumber, draft: entry)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    focusBanner
                    statusCards
                    pointsPreview

                    sectionTitle("パット", icon: "circle.grid.2x2")
                    puttRow

                    sectionTitle("オリンピック点（メダル）", icon: "medal.fill")
                    medalRow

                    sectionTitle("その他の加点", icon: "plus.circle.fill")
                    bonusGrid

                    sectionTitle("リーチ・減点", icon: "bolt.fill")
                    penaltyRow

                    if entry.outerPinDeclared {
                        sectionTitle("外竿", icon: "arrow.up.forward")
                        HStack {
                            Text("グリーン上打数")
                            Spacer()
                            Stepper("\(entry.strokesOnGreenAfterApproach)", value: $entry.strokesOnGreenAfterApproach, in: 0...5)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("オリンピック入力")
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

    // MARK: - Focus / status

    private var focusBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("入力中のプレイヤー", systemImage: "person.crop.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
            Text(playerName)
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("ホール \(holeNumber)  ·  \(strokesCaption)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [RivieraTheme.fairwayDeep, RivieraTheme.fairway], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.yellow.opacity(0.8), lineWidth: 3)
        )
    }

    private var statusCards: some View {
        let s = nineStatus
        return VStack(spacing: 8) {
            statusRow(
                title: "\(s.nineLabel) リーチ",
                text: s.reachText,
                ok: s.reachOK,
                warn: s.reachForcedSoon,
                icon: "bolt.fill"
            )
            statusRow(
                title: "\(s.nineLabel) 焼き鳥",
                text: s.yakitoriText,
                ok: s.yakitoriOK,
                warn: !s.yakitoriOK,
                icon: "fork.knife"
            )
        }
    }

    private func statusRow(title: String, text: String, ok: Bool, warn: Bool, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(ok ? RivieraTheme.fairway : (warn ? RivieraTheme.flag : .orange))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(text).font(.subheadline.weight(.semibold))
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? RivieraTheme.fairway : RivieraTheme.flag)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((ok ? RivieraTheme.fairway : RivieraTheme.flag).opacity(0.35), lineWidth: 1)
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
        HStack(spacing: 6) {
            ForEach([0, 1, 2, 3, 4], id: \.self) { p in
                chip(title: p == 0 ? "0" : "\(p)", selected: entry.putts == p, tint: .blue) {
                    entry.putts = p
                }
            }
        }
    }

    private var medalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                medalChip(nil, "無", "circle")
                medalChip(.gold, "金+4", "medal.fill")
                medalChip(.silver, "銀+3", "medal")
                medalChip(.bronze, "銅+2", "medal")
                medalChip(.iron, "鉄+1", "circle.grid.cross")
                medalChip(.diamond, "◆+5", "diamond.fill")
            }
        }
    }

    private var bonusGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            iconToggle("竿 +2", "ruler", $entry.declaredPin)
            iconToggle("1ピン↑", "arrow.up.to.line", $entry.pinDistanceQualified)
            iconToggle("外竿", "arrow.up.forward", $entry.outerPinDeclared)
            iconToggle("砂 +2", "beach.umbrella.fill", $entry.banker)
            iconToggle("パーオン +1", "p.circle", $entry.parOn)
            iconToggle("Bオン +3", "b.circle", $entry.birdieOn)
            iconToggle("ニアピン", "scope", $entry.nearestPinContender)
            iconToggle("消防隊", "flame.fill", $entry.fireman)
            iconToggle("ティーGIR", "flag.fill", $entry.greenInRegulationTee)
            iconToggle("外チップ", "arrow.down.right.circle", $entry.chipInFromOffGreen)
        }
    }

    private var penaltyRow: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            iconToggle("リーチ×2", "bolt.fill", $entry.declaredReach, tint: .purple)
            iconToggle("舐め −1", "drop.fill", $entry.nameLick, tint: RivieraTheme.flag)
            iconToggle("あわや −1", "leaf.fill", $entry.awaya, tint: .orange)
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
        return chip(title: title, icon: icon, selected: on, tint: .yellow) {
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

    private func chip(title: String, icon: String? = nil, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11))
                }
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .foregroundStyle(selected ? Color.white : tint)
            .background(selected ? tint : tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? tint : tint.opacity(0.35), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
