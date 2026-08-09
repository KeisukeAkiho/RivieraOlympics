import SwiftUI

struct NewRoundView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = "リビエラ ラウンド"
    @State private var selected: Set<UUID> = []
    @State private var playerSearch = ""
    @State private var options = RoundOptions()
    @State private var selectedCourseId: UUID?

    private var filteredPlayers: [RegisteredPlayer] {
        let q = playerSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = store.players.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !q.isEmpty else { return sorted }
        return sorted.filter { player in
            player.name.localizedStandardContains(q)
                || player.homeCourse.localizedStandardContains(q)
                || player.homeTee.localizedStandardContains(q)
                || player.handicap.localizedStandardContains(q)
                || player.note.localizedStandardContains(q)
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
                                Text("\(c.displayTitle)（計\(c.totalPar)）").tag(Optional(c.id))
                            }
                        }
                        if let course = store.course(id: selectedCourseId) {
                            Text("前\(course.pars.prefix(9).reduce(0, +)) / 後\(course.pars.suffix(9).reduce(0, +))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                CompetitionGamesSection(options: $options)

                Section {
                    if store.players.isEmpty {
                        Text("先に「プレイヤー」タブで登録してください。")
                            .foregroundStyle(.secondary)
                    } else if filteredPlayers.isEmpty {
                        Text("「\(playerSearch)」に一致するプレイヤーがいません。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredPlayers) { p in
                            Toggle(isOn: Binding(
                                get: { selected.contains(p.id) },
                                set: { on in
                                    if on { selected.insert(p.id) } else { selected.remove(p.id) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name)
                                    if !p.homeCourse.isEmpty {
                                        Text(p.homeCourse)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("参加プレイヤー（2人以上）")
                } footer: {
                    Text("選択中 \(selected.count) 人")
                        .foregroundStyle(selected.count >= 2 ? Color.secondary : RivieraTheme.flag)
                }

                Section {
                    Text("作成後もラウンド画面の「競技内容」からいつでも変更できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新しいラウンド")
            .searchable(text: $playerSearch, prompt: "参加プレイヤーを検索")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        let ids = store.players.map(\.id).filter { selected.contains($0) }
                        store.createRound(
                            title: title,
                            playerIds: ids,
                            options: options,
                            courseId: selectedCourseId
                        )
                        dismiss()
                    }
                    .disabled(selected.count < 2)
                }
            }
            .onAppear {
                store.applyActiveRules(to: &options)
            }
        }
    }
}
