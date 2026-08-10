import SwiftUI

struct NewRoundView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = Self.defaultRoundTitle()
    @State private var selected: Set<UUID> = []
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
        store.activePlayers.filter { selected.contains($0.id) }
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

                if !selectedPlayersInOrder.isEmpty {
                    Section("選択中") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedPlayersInOrder) { p in
                                    Button {
                                        selected.remove(p.id)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(p.name)
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                        .font(.subheadline)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RivieraTheme.fairway.opacity(0.18))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
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
                                if selected.contains(p.id) {
                                    selected.remove(p.id)
                                } else {
                                    selected.insert(p.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(p.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(p.id) ? RivieraTheme.fairway : .secondary)
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
                    Text("上の欄で絞り込んでタップ選択。選択中 \(selected.count) 人")
                        .foregroundStyle(selected.count >= 2 ? Color.secondary : RivieraTheme.flag)
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
                        let ids = store.activePlayers.map(\.id).filter { selected.contains($0) }
                        store.createRound(
                            title: title,
                            playerIds: ids,
                            options: options,
                            courseId: selectedCourseId,
                            teeName: selectedTeeName.isEmpty ? nil : selectedTeeName
                        )
                        dismiss()
                    }
                    .disabled(selected.count < 2)
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
