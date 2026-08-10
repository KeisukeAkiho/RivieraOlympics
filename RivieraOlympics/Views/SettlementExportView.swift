import Photos
import SwiftUI
import UIKit

/// Options for photo export of a round summary.
struct SettlementPhotoExportOptions: Equatable {
    var includeScores = true
    var includeOlympicsPoints = true
    var includePutts = false
    var includeSettlement = true
    var includeGames = true
}

/// Sheet: choose sections → preview → save to Photos / share.
struct SettlementExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let round: GolfRound
    let summary: SettlementSummary

    @State private var options = SettlementPhotoExportOptions()
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShare = false
    @State private var errorMessage: String?
    @State private var showSettingsAlert = false
    @State private var bannerText: String?
    @State private var bannerIsError = false
    @State private var bannerHideTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("スコアの記録", isOn: $options.includeScores)
                    Toggle("オリンピックポイント", isOn: $options.includeOlympicsPoints)
                        .disabled(!round.options.olympicsEnabled)
                    Toggle("パット数", isOn: $options.includePutts)
                    Toggle("精算結果集計", isOn: $options.includeSettlement)
                    Toggle("選択された競技内容", isOn: $options.includeGames)
                } header: {
                    Text("出力内容")
                } footer: {
                    Text("オンにした項目だけを1枚の写真にまとめて出力します。")
                }

                Section("プレビュー") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        SettlementExportCardView(round: round, summary: summary, options: options)
                            .frame(width: SettlementExportCardView.canvasWidth)
                            .scaleEffect(SettlementExportCardView.previewScale, anchor: .topLeading)
                            .frame(
                                width: SettlementExportCardView.canvasWidth * SettlementExportCardView.previewScale,
                                height: nil,
                                alignment: .topLeading
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                Section {
                    Button {
                        Task { await saveToPhotoLibrary() }
                    } label: {
                        if isRendering {
                            HStack {
                                ProgressView()
                                Text("作成中…")
                            }
                        } else {
                            Label("iPhoneの写真に追加", systemImage: "photo.badge.plus")
                        }
                    }
                    .disabled(isRendering || !hasAnySection)

                    Button {
                        Task { await sharePhoto() }
                    } label: {
                        Label("ほかのアプリで共有", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isRendering || !hasAnySection)
                } header: {
                    Text("保存")
                } footer: {
                    Text("「写真に追加」でカメラロールへ直接保存できます。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(RivieraTheme.flag)
                    }
                }
            }
            .navigationTitle("写真エクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: options) { _, _ in
                errorMessage = nil
            }
            .sheet(isPresented: $showShare) {
                if let renderedImage {
                    ActivityShareSheet(items: [renderedImage]) { completed in
                        if completed {
                            presentBanner("エクスポートが完了しました", isError: false)
                        }
                    }
                }
            }
            .alert("写真へのアクセスが必要です", isPresented: $showSettingsAlert) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("設定 > リビエラオリンピック > 写真 で「写真を追加」を許可してください。")
            }
            .overlay(alignment: .top) {
                if let bannerText {
                    exportBanner(text: bannerText, isError: bannerIsError)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: bannerText)
        }
    }

    private func exportBanner(text: String, isError: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.title3)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            (isError ? RivieraTheme.flag : RivieraTheme.fairway)
                .opacity(0.95)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .accessibilityAddTraits(.isStaticText)
    }

    private func presentBanner(_ text: String, isError: Bool) {
        bannerHideTask?.cancel()
        bannerIsError = isError
        withAnimation {
            bannerText = text
        }
        bannerHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled else { return }
            withAnimation {
                bannerText = nil
            }
        }
    }

    private var hasAnySection: Bool {
        options.includeScores
            || (options.includeOlympicsPoints && round.options.olympicsEnabled)
            || options.includePutts
            || options.includeSettlement
            || options.includeGames
    }

    @MainActor
    private func renderExportImage() async -> UIImage? {
        guard hasAnySection else {
            errorMessage = "少なくとも1つの出力内容を選んでください。"
            return nil
        }
        let card = SettlementExportCardView(round: round, summary: summary, options: options)
            .frame(width: SettlementExportCardView.canvasWidth)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2.0
        await Task.yield()
        return renderer.uiImage
    }

    @MainActor
    private func sharePhoto() async {
        isRendering = true
        errorMessage = nil
        defer { isRendering = false }

        guard let image = await renderExportImage() else {
            let msg = errorMessage ?? "画像の生成に失敗しました。もう一度お試しください。"
            errorMessage = msg
            presentBanner(msg, isError: true)
            return
        }
        renderedImage = image
        showShare = true
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        isRendering = true
        errorMessage = nil
        defer { isRendering = false }

        guard let image = await renderExportImage() else {
            let msg = errorMessage ?? "画像の生成に失敗しました。もう一度お試しください。"
            errorMessage = msg
            presentBanner(msg, isError: true)
            return
        }
        renderedImage = image

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        switch status {
        case .authorized, .limited:
            break
        case .denied, .restricted:
            showSettingsAlert = true
            let msg = "写真への追加が許可されていません。"
            errorMessage = msg
            presentBanner(msg, isError: true)
            return
        case .notDetermined:
            let msg = "写真への追加許可を確認できませんでした。"
            errorMessage = msg
            presentBanner(msg, isError: true)
            return
        @unknown default:
            let msg = "写真への追加許可を確認できませんでした。"
            errorMessage = msg
            presentBanner(msg, isError: true)
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            presentBanner("写真に追加しました（エクスポート完了）", isError: false)
        } catch {
            let msg = "写真への保存に失敗しました"
            errorMessage = "\(msg): \(error.localizedDescription)"
            presentBanner(msg, isError: true)
        }
    }
}

// MARK: - Condensed export card

struct SettlementExportCardView: View {
    let round: GolfRound
    let summary: SettlementSummary
    let options: SettlementPhotoExportOptions

    static let canvasWidth: CGFloat = 1080
    static let previewScale: CGFloat = 0.32

    private let nameW: CGFloat = 78
    private let holeW: CGFloat = 36
    private let nineW: CGFloat = 44
    private let totalW: CGFloat = 48
    private let rowH: CGFloat = 24
    private let headerH: CGFloat = 22
    private let gridBorder = Color.black
    private let gridBorderWidth: CGFloat = 1

    private var showScore: Bool { options.includeScores }
    private var showPutt: Bool { options.includePutts }
    private var showOly: Bool { options.includeOlympicsPoints && round.options.olympicsEnabled }
    private var playerRowHeight: CGFloat {
        let sub: CGFloat = (showPutt || showOly) ? 12 : 0
        let main: CGFloat = (showScore || (!showPutt && !showOly)) ? 16 : 0
        let body = max(main + sub, (showPutt || showOly) ? 28 : 24)
        return body + 4
    }

    private var olympicsMap: [Int: [UUID: Int]] {
        guard options.includeOlympicsPoints, round.options.olympicsEnabled else { return [:] }
        var map: [Int: [UUID: Int]] = [:]
        for hole in OlympicsCalculator.scoreRound(round) {
            var per: [UUID: Int] = [:]
            for row in hole.perPlayer {
                per[row.playerId] = row.totalPoints
            }
            map[hole.holeNumber] = per
        }
        return map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if options.includeGames {
                gamesBlock
            }
            if options.includeScores || options.includePutts || options.includeOlympicsPoints {
                scoreTables
            }
            if options.includeSettlement {
                settlementBlock
            }
            footer
        }
        .padding(18)
        .frame(width: Self.canvasWidth, alignment: .leading)
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("リビエラオリンピック")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RivieraTheme.fairway)
                Spacer()
                Text(round.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(round.title)
                .font(.system(size: 22, weight: .bold))
            HStack(spacing: 10) {
                if !round.courseName.isEmpty {
                    Text(round.courseName)
                }
                if !round.selectedTeeName.isEmpty {
                    Text("Tee \(round.selectedTeeName)")
                }
                Text("掛金 \(round.options.stakeRate)")
                if round.options.settlementCap > 0 {
                    Text("上限 \(round.options.settlementCap)")
                }
                if round.isSettled {
                    Text("精算済")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RivieraTheme.sand)
                        .clipShape(Capsule())
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RivieraTheme.fairway.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var gamesBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("競技内容")
            let names = CompetitionGamesSection.enabledGameNames(round.options)
            if names.isEmpty {
                Text("なし（スコアのみ）")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RivieraTheme.fairway.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var scoreTables: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("スコアカード")
            if showPutt || showOly {
                HStack(spacing: 10) {
                    if showScore { Text("上段: スコア").font(.system(size: 9)) }
                    if showPutt { Text("下段左: パット").font(.system(size: 9)) }
                    if showOly { Text(showPutt ? "下段右: OLY" : "下段: OLY").font(.system(size: 9)) }
                }
                .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                holeHeaderRow
                parRow
                ForEach(Array(round.players.enumerated()), id: \.element.id) { index, player in
                    playerScoreRow(player: player, themeIndex: index)
                }
            }
        }
    }

    private var holeHeaderRow: some View {
        HStack(spacing: 0) {
            gridCell("Hole", width: nameW, height: headerH, bold: true, bg: RivieraTheme.fairway.opacity(0.18))
            ForEach(1...9, id: \.self) { h in
                gridCell("\(h)", width: holeW, height: headerH, bold: true, bg: RivieraTheme.fairway.opacity(0.12))
            }
            gridCell("前", width: nineW, height: headerH, bold: true, bg: RivieraTheme.fairway.opacity(0.18))
            ForEach(10...18, id: \.self) { h in
                gridCell("\(h)", width: holeW, height: headerH, bold: true, bg: RivieraTheme.fairway.opacity(0.12))
            }
            gridCell("後", width: nineW, height: headerH, bold: true, bg: RivieraTheme.fairway.opacity(0.18))
            gridCell("計", width: totalW, height: headerH, bold: true, bg: RivieraTheme.fairway.opacity(0.22))
        }
    }

    private var parRow: some View {
        HStack(spacing: 0) {
            gridCell("Par", width: nameW, height: rowH, bold: true, bg: Color.gray.opacity(0.08))
            ForEach(1...9, id: \.self) { h in
                gridCell("\(par(h))", width: holeW, height: rowH, bg: Color.gray.opacity(0.05))
            }
            gridCell("\(sumPars(1...9))", width: nineW, height: rowH, bold: true, bg: Color.gray.opacity(0.08))
            ForEach(10...18, id: \.self) { h in
                gridCell("\(par(h))", width: holeW, height: rowH, bg: Color.gray.opacity(0.05))
            }
            gridCell("\(sumPars(10...18))", width: nineW, height: rowH, bold: true, bg: Color.gray.opacity(0.08))
            gridCell("\(sumPars(1...18))", width: totalW, height: rowH, bold: true, bg: Color.gray.opacity(0.10))
        }
    }

    private func playerScoreRow(player: Player, themeIndex: Int) -> some View {
        let nameTint = PlayerTheme.color(at: themeIndex).opacity(0.22)
        let h = playerRowHeight
        return HStack(spacing: 0) {
            nameCell(player.name, width: nameW, height: h, bg: nameTint)
            ForEach(1...9, id: \.self) { hole in
                stackedHoleCell(playerId: player.id, hole: hole, width: holeW, height: h)
            }
            stackedSumCell(playerId: player.id, holes: 1...9, width: nineW, height: h, bg: Color.gray.opacity(0.06))
            ForEach(10...18, id: \.self) { hole in
                stackedHoleCell(playerId: player.id, hole: hole, width: holeW, height: h)
            }
            stackedSumCell(playerId: player.id, holes: 10...18, width: nineW, height: h, bg: Color.gray.opacity(0.06))
            stackedSumCell(playerId: player.id, holes: 1...18, width: totalW, height: h, bg: Color.gray.opacity(0.08))
        }
    }

    private func nameCell(_ text: String, width: CGFloat, height: CGFloat, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 3)
            .frame(width: width, height: height, alignment: .leading)
            .background(bg)
            .clipped()
            .overlay(Rectangle().stroke(gridBorder, lineWidth: gridBorderWidth))
    }

    /// Score on top; putts + OLY as a small column-span row underneath.
    private func stackedHoleCell(playerId: UUID, hole: Int, width: CGFloat, height: CGFloat) -> some View {
        let s = strokes(playerId: playerId, hole: hole)
        let p = putts(playerId: playerId, hole: hole)
        let o = olympicsMap[hole]?[playerId] ?? 0
        return VStack(spacing: 1) {
            if showScore {
                Text(s > 0 ? "\(s)" : "·")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if showPutt || showOly {
                subMetricsLine(putt: s > 0 ? p : nil, oly: o, played: s > 0)
            } else if !showScore {
                Text("·")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .overlay(Rectangle().stroke(gridBorder, lineWidth: gridBorderWidth))
    }

    private func stackedSumCell(
        playerId: UUID,
        holes: ClosedRange<Int>,
        width: CGFloat,
        height: CGFloat,
        bg: Color
    ) -> some View {
        let sSum = strokesSum(playerId: playerId, holes: holes)
        let pSum = puttsSum(playerId: playerId, holes: holes)
        let oSum = pointsSum(playerId: playerId, holes: holes)
        let played = holes.contains { strokes(playerId: playerId, hole: $0) > 0 }
        return VStack(spacing: 1) {
            if showScore {
                Text(sSum > 0 ? "\(sSum)" : "·")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            if showPutt || showOly {
                subMetricsLine(putt: played ? pSum : nil, oly: oSum, played: played)
            }
        }
        .frame(width: width, height: height)
        .background(bg)
        .clipped()
        .overlay(Rectangle().stroke(gridBorder, lineWidth: gridBorderWidth))
    }

    /// Putt and OLY under the score. Slash only when an OLY point exists.
    private func subMetricsLine(putt: Int?, oly: Int, played: Bool) -> some View {
        let hasOly = showOly && oly != 0
        return HStack(spacing: 1) {
            if showPutt {
                Text(played ? "\(putt ?? 0)" : "·")
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            if showPutt && hasOly {
                Text("/")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if hasOly {
                Text(olySignedText(oly))
                    .font(.system(size: 8, weight: .bold).monospacedDigit())
                    .foregroundStyle(olyColor(oly))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else if showOly && !showPutt {
                Text("·")
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func olySignedText(_ v: Int) -> String {
        if v > 0 { return "+\(v)" }
        return "\(v)"
    }

    private func olyColor(_ v: Int) -> Color {
        if v > 0 { return RivieraTheme.fairway }
        if v < 0 { return RivieraTheme.flag }
        return .secondary
    }

    private var settlementBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("精算結果")
            HStack(spacing: 0) {
                settleHead("選手", width: 96)
                settleHead("グロス", width: 58)
                if round.options.olympicsEnabled {
                    settleHead("OLY点", width: 58)
                    settleHead("OLY¥", width: 72)
                }
                if round.options.holeMatchEnabled { settleHead("HM¥", width: 66) }
                if round.options.lasVegasEnabled { settleHead("LV¥", width: 66) }
                if round.options.sonchoEnabled { settleHead("村長¥", width: 66) }
                if round.options.snakeEnabled { settleHead("蛇¥", width: 66) }
                if round.options.honestJohnEnabled { settleHead("OJ¥", width: 66) }
                settleHead("ネット", width: 84)
            }
            ForEach(Array(summary.playerTotals.enumerated()), id: \.element.id) { index, t in
                HStack(spacing: 0) {
                    settleCell(
                        t.isSoncho ? "\(t.name)★" : t.name,
                        width: 96,
                        bold: true,
                        bg: PlayerTheme.color(at: index).opacity(0.18)
                    )
                    settleCell("\(t.grossScore)", width: 58)
                    if round.options.olympicsEnabled {
                        settleCell(olySignedText(t.olympicPoints), width: 58, fg: olyColor(t.olympicPoints))
                        settleCell(yen(t.olympicYen), width: 72, fg: moneyColor(t.olympicYen))
                    }
                    if round.options.holeMatchEnabled {
                        settleCell(yen(t.holeMatchYen), width: 66, fg: moneyColor(t.holeMatchYen))
                    }
                    if round.options.lasVegasEnabled {
                        settleCell(yen(t.lasVegasYen), width: 66, fg: moneyColor(t.lasVegasYen))
                    }
                    if round.options.sonchoEnabled {
                        settleCell(yen(t.sonchoYen), width: 66, fg: moneyColor(t.sonchoYen))
                    }
                    if round.options.snakeEnabled {
                        settleCell(yen(t.snakeYen), width: 66, fg: moneyColor(t.snakeYen))
                    }
                    if round.options.honestJohnEnabled {
                        settleCell(yen(t.honestJohnYen), width: 66, fg: moneyColor(t.honestJohnYen))
                    }
                    settleCell(
                        yen(t.netYen),
                        width: 84,
                        bold: true,
                        fg: moneyColor(t.netYen),
                        bg: Color.gray.opacity(0.06)
                    )
                }
            }
            let sumN = summary.playerTotals.reduce(0) { $0 + $1.netYen }
            HStack {
                Text("ネット合計（検算）")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(yen(sumN))
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(sumN == 0 ? RivieraTheme.fairway : RivieraTheme.flag)
            }
            .padding(.top, 2)
        }
    }

    private var footer: some View {
        Text("Exported from Riviera Olympics")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(RivieraTheme.fairwayDeep)
    }

    private func gridCell(
        _ text: String,
        width: CGFloat,
        height: CGFloat,
        bold: Bool = false,
        bg: Color = .clear,
        fg: Color = .primary,
        align: Alignment = .center
    ) -> some View {
        Text(text)
            .font(.system(size: 11, weight: bold ? .bold : .regular).monospacedDigit())
            .foregroundStyle(fg)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, align == .leading ? 3 : 0)
            .frame(width: width, height: height, alignment: align)
            .background(bg)
            .clipped()
            .overlay(Rectangle().stroke(gridBorder, lineWidth: gridBorderWidth))
    }

    private func settleHead(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .frame(width: width, height: 22)
            .background(RivieraTheme.fairway.opacity(0.14))
            .clipped()
            .overlay(Rectangle().stroke(gridBorder, lineWidth: gridBorderWidth))
    }

    private func settleCell(
        _ text: String,
        width: CGFloat,
        bold: Bool = false,
        fg: Color = .primary,
        bg: Color = .clear
    ) -> some View {
        Text(text)
            .font(.system(size: 11, weight: bold ? .bold : .regular).monospacedDigit())
            .foregroundStyle(fg)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: width, height: 24)
            .background(bg)
            .clipped()
            .overlay(Rectangle().stroke(gridBorder, lineWidth: gridBorderWidth))
    }

    private func par(_ hole: Int) -> Int {
        round.holes.first(where: { $0.holeNumber == hole })?.par
            ?? (round.coursePars.indices.contains(hole - 1) ? round.coursePars[hole - 1] : 4)
    }

    private func sumPars(_ holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { $0 + par($1) }
    }

    private func strokes(playerId: UUID, hole: Int) -> Int {
        round.holes.first(where: { $0.holeNumber == hole })?
            .entries.first(where: { $0.playerId == playerId })?.strokes ?? 0
    }

    private func putts(playerId: UUID, hole: Int) -> Int {
        round.holes.first(where: { $0.holeNumber == hole })?
            .entries.first(where: { $0.playerId == playerId })?.putts ?? 0
    }

    private func strokesSum(playerId: UUID, holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { $0 + strokes(playerId: playerId, hole: $1) }
    }

    private func puttsSum(playerId: UUID, holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { $0 + putts(playerId: playerId, hole: $1) }
    }

    private func pointsSum(playerId: UUID, holes: ClosedRange<Int>) -> Int {
        holes.reduce(0) { $0 + (olympicsMap[$1]?[playerId] ?? 0) }
    }

    private func yen(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.positivePrefix = "+"
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private func moneyColor(_ v: Int) -> Color {
        if v > 0 { return RivieraTheme.fairway }
        if v < 0 { return RivieraTheme.flag }
        return .secondary
    }
}

// MARK: - UIKit share

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onFinished: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            onFinished?(completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
