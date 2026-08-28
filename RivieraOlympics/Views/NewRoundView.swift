import SwiftUI

struct NewRoundView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = Self.defaultRoundTitle()
    @State private var selectedOrder: [UUID] = []
    @State private var playerSearch = ""
    @State private var options = RoundOptions()
    @State private var selectedCourseId: UUID?
    @State private var selectedTeeName: String = ""

    private var selectedCourse: RegisteredCourse? {
        store.course(id: selectedCourseId)
    }

    private var filteredPlayers: [RegisteredPlayer] {
        let base = store.activePlayers
        let q = playerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { player in
            Self.textMatches(player.name, q)
                || Self.textMatches(player.homeCourse, q)
                || Self.textMatches(player.homeTee, q)
                || Self.textMatches(player.handicap, q)
                || Self.textMatches(player.note, q)
        }
    }

    private static func textMatches(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(
            of: needle,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        ) != nil
    }

    private var selectedPlayersInOrder: [RegisteredPlayer] {
        selectedOrder.compactMap { id in
            store.players.first(where: { $0.id == id })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ラウンド") {
                    TextField("タイトル", text: $title)
                }

                Section("コース") {
                    if store.courses.isEmpty {
                        Text("「コース」タブで登録すると、ここから選択できます。未選択時はすべてパー4です。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("コース", selection: $selectedCourseId) {
                            Text("指定なし（すべてパー4）").tag(Optional<UUID>.none)
                            ForEach(store.courses) { c in
                                Text(coursePickerLabel(c)).tag(Optional(c.id))
                            }
                        }
                        .onChange(of: selectedCourseId) { _, newId in
                            guard let course = store.course(id: newId) else {
                                selectedTeeName = ""
                                return
                            }
                            selectedTeeName = course.tees.first(where: { $0.name == "Blue" })?.name
                                ?? course.tees.first?.name
                                ?? ""
                        }
                        if let course = selectedCourse {
                            Text("前\(course.pars.prefix(9).reduce(0, +)) / 後\(course.pars.suffix(9).reduce(0, +))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !course.tees.isEmpty {
                                Picker("Tee", selection: $selectedTeeName) {
                                    ForEach(course.tees) { tee in
                                        let total = tee.totalYards
                                        Text(total > 0 ? "\(tee.name)（\(total) yd）" : tee.name)
                                            .tag(tee.name)
                                    }
                                }
                                if let tee = course.tees.first(where: { $0.name == selectedTeeName }),
                                   tee.hasAnyYardage {
                                    Text("ホール毎ヤードあり（作成後スコア表に表示）")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                CompetitionGamesSection(options: $options)

                HoleMatchSettingsSection(
                    options: $options,
                    players: selectedPlayersInOrder.map { (id: $0.id, name: $0.name) }
                )

                OlympicsSettlementExclusionSection(
                    players: selectedPlayersInOrder.map { (id: $0.id, name: $0.name) },
                    options: $options
                )

                if !selectedPlayersInOrder.isEmpty {
                    Section {
                        PlayerOrderEditor(
                            players: selectedPlayersInOrder.map { (id: $0.id, name: $0.name) },
                            canEdit: true,
                            showsRemove: true,
                            onReorder: { ids in selectedOrder = ids },
                            onRemove: { id in
                                selectedOrder.removeAll { $0 == id }
                                options.setExcludedFromOlympicsSettlement(id, excluded: false)
                            }
                        )
                    } header: {
                        Text("選択中（表示・入力順）")
                    } footer: {
                        Text("上から順にスコアカード・打数入力・オリンピック点に並びます。矢印で並べ替え。")
                    }
                    .environment(\.editMode, .constant(.active))
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("名前・ホームコースで検索", text: $playerSearch)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !playerSearch.isEmpty {
                            Button {
                                playerSearch = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if store.activePlayers.isEmpty {
                        Text("先に「プレイヤー」タブで登録してください（非表示でない選手が2人以上必要）。")
                            .foregroundStyle(.secondary)
                    } else if filteredPlayers.isEmpty {
                        Text("「\(playerSearch)」に一致するプレイヤーがいません。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredPlayers) { p in
                            Button {
                                if let idx = selectedOrder.firstIndex(of: p.id) {
                                    selectedOrder.remove(at: idx)
                                    options.setExcludedFromOlympicsSettlement(p.id, excluded: false)
                                } else {
                                    selectedOrder.append(p.id)
                                    if p.excludeFromOlympicsSettlement {
                                        options.setExcludedFromOlympicsSettlement(p.id, excluded: true)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedOrder.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedOrder.contains(p.id) ? RivieraTheme.fairway : .secondary)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(p.name)
                                                .foregroundStyle(.primary)
                                            if p.isFavorite {
                                                Image(systemName: "star.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.orange)
                                            }
                                        }
                                        if !p.homeCourse.isEmpty {
                                            Text(p.homeCourse)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if p.excludeFromOlympicsSettlement {
                                            Text("五輪精算 既定除外")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("参加プレイヤー（2人以上）")
                } footer: {
                    Text("上の欄で絞り込んでタップ選択。選択順が初期の並びです。選択中 \(selectedOrder.count) 人")
                        .foregroundStyle(selectedOrder.count >= 2 ? Color.secondary : RivieraTheme.flag)
                }

                Section {
                    Text("作成後もラウンド画面の「競技内容」からいつでも変更できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新しいラウンド")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        store.createRound(
                            title: title,
                            playerIds: selectedOrder,
                            options: options,
                            courseId: selectedCourseId,
                            teeName: selectedTeeName.isEmpty ? nil : selectedTeeName
                        )
                        dismiss()
                    }
                    .disabled(selectedOrder.count < 2)
                }
            }
            .onAppear {
                store.applyActiveRules(to: &options)
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = Self.defaultRoundTitle()
                }
            }
        }
    }

    private func coursePickerLabel(_ c: RegisteredCourse) -> String {
        let star = c.isFavorite ? "★ " : ""
        return "\(star)\(c.displayTitle)（計\(c.totalPar)）"
    }

    private static func defaultRoundTitle(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
