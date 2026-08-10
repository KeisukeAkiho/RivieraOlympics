import SwiftUI

struct PlayersView: View {
    @EnvironmentObject private var store: RoundStore
    @State private var showEditor = false
    @State private var editingPlayer: RegisteredPlayer?
    @State private var playerSearch = ""
    @State private var showHidden = false
    @State private var playerPendingDelete: RegisteredPlayer?
    @State private var showPlayerDeleteConfirm = false

    private var filteredPlayers: [RegisteredPlayer] {
        let base = showHidden ? store.players : store.activePlayers
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

    var body: some View {
        List {
            Section {
                Button {
                    editingPlayer = nil
                    showEditor = true
                } label: {
                    Label("プレイヤーを登録", systemImage: "person.badge.plus")
                        .font(.headline)
                }
            }

            Section {
                Toggle("非表示も表示", isOn: $showHidden)
            }

            Section(showHidden ? "登録プレイヤー（非表示含む）" : "登録プレイヤー") {
                if store.players.isEmpty {
                    Text("まだ登録がありません。上のボタンから名前・ホームコースなどを登録してください。")
                        .foregroundStyle(.secondary)
                } else if filteredPlayers.isEmpty {
                    Text(playerSearch.isEmpty
                         ? "表示できるプレイヤーがいません。"
                         : "「\(playerSearch)」に一致するプレイヤーがいません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredPlayers) { p in
                    HStack(spacing: 8) {
                        Image(systemName: p.isFavorite ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(p.isFavorite ? Color.orange : Color.secondary)
                            .symbolRenderingMode(.monochrome)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.toggleFavoritePlayer(id: p.id)
                            }

                        NavigationLink {
                            PlayerDetailView(playerId: p.id)
                        } label: {
                            let career = store.career(for: p.id)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if p.isFavorite {
                                        Text("★")
                                            .font(.headline)
                                            .foregroundStyle(Color.orange)
                                    }
                                    Text(p.name).font(.headline)
                                    if p.isHidden {
                                        Text("非表示")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.2))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Text(yen(career.totalNetYen))
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                        .foregroundStyle(career.totalNetYen >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                                }
                                if !p.homeCourse.isEmpty {
                                    Label(p.homeCourse, systemImage: "flag.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(career.roundsPlayed)戦 \(career.wins)勝\(career.losses)敗")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .opacity(p.isHidden ? 0.65 : 1)
                        }

                        Menu {
                            Button {
                                store.toggleFavoritePlayer(id: p.id)
                            } label: {
                                Label(
                                    p.isFavorite ? "お気に入り解除" : "お気に入り",
                                    systemImage: p.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }
                            Button {
                                store.toggleHiddenPlayer(id: p.id)
                            } label: {
                                Label(
                                    p.isHidden ? "再表示" : "非表示",
                                    systemImage: p.isHidden ? "eye.fill" : "eye.slash.fill"
                                )
                            }
                            Button(role: .destructive) {
                                playerPendingDelete = p
                                showPlayerDeleteConfirm = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            playerPendingDelete = p
                            showPlayerDeleteConfirm = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        Button {
                            store.toggleHiddenPlayer(id: p.id)
                        } label: {
                            Label(
                                p.isHidden ? "再表示" : "非表示",
                                systemImage: p.isHidden ? "eye.fill" : "eye.slash.fill"
                            )
                        }
                        .tint(.indigo)
                    }
                }
            }
        }
        .navigationTitle("プレイヤー")
        .searchable(
            text: $playerSearch,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "名前・ホームコースで検索"
        )
        .sheet(isPresented: $showEditor) {
            PlayerEditorSheet(player: editingPlayer)
        }
        .alert("プレイヤーを削除しますか？", isPresented: $showPlayerDeleteConfirm) {
            Button("削除", role: .destructive) {
                if let id = playerPendingDelete?.id {
                    store.deletePlayer(id: id)
                }
                playerPendingDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                playerPendingDelete = nil
            }
        } message: {
            Text("「\(playerPendingDelete?.name ?? "")」を完全に削除します。過去ラウンドの記録は残りますが、マスター一覧からは消えます。")
        }
    }

    private func yen(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.positivePrefix = "+"
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}

struct PlayerEditorSheet: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss
    var player: RegisteredPlayer?

    @State private var name = ""
    @State private var homeCourse = ""
    @State private var homeTee = ""
    @State private var handicap = ""
    @State private var note = ""
    @State private var honestJohn = 90

    private var isNew: Bool { player == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("名前（必須）", text: $name)
                    if store.courses.isEmpty {
                        TextField("ホームコース", text: $homeCourse)
                            .textInputAutocapitalization(.words)
                    } else {
                        Picker("登録コースから選ぶ", selection: homeCoursePickBinding) {
                            Text("手入力／未選択").tag(Optional<UUID>.none)
                            ForEach(store.courses) { c in
                                Text("\(c.isFavorite ? "★ " : "")\(c.name)").tag(Optional(c.id))
                            }
                        }
                        TextField("ホームコース", text: $homeCourse)
                            .textInputAutocapitalization(.words)
                    }
                    TextField("ティー（例: 白・青・金）", text: $homeTee)
                    TextField("ハンディキャップ", text: $handicap)
                        .keyboardType(.decimalPad)
                }
                Section("その他") {
                    Stepper("オネストジョン申告: \(honestJohn)", value: $honestJohn, in: 60...140)
                    TextField("メモ", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    Text("ホームコースは一覧と詳細に表示されます。生涯戦績はこのプレイヤーに紐づきます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isNew ? "プレイヤー登録" : "プレイヤー編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "登録" : "保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let player {
                    name = player.name
                    homeCourse = player.homeCourse
                    homeTee = player.homeTee
                    handicap = player.handicap
                    note = player.note
                    honestJohn = player.defaultHonestJohn
                }
            }
        }
    }

    private var homeCoursePickBinding: Binding<UUID?> {
        Binding(
            get: {
                store.courses.first(where: { $0.name == homeCourse })?.id
            },
            set: { id in
                if let id, let course = store.course(id: id) {
                    homeCourse = course.name
                }
            }
        )
    }

    private func save() {
        if var existing = player {
            existing.name = name
            existing.homeCourse = homeCourse
            existing.homeTee = homeTee
            existing.handicap = handicap
            existing.note = note
            existing.defaultHonestJohn = honestJohn
            store.updatePlayer(existing)
        } else {
            store.addPlayer(
                name: name,
                homeCourse: homeCourse,
                homeTee: homeTee,
                handicap: handicap,
                note: note,
                honestJohn: honestJohn
            )
        }
        dismiss()
    }
}

struct PlayerDetailView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss
    let playerId: UUID
    @State private var showEditor = false
    @State private var confirmDelete = false

    private var career: CareerStats { store.career(for: playerId) }
    private var player: RegisteredPlayer? { store.players.first(where: { $0.id == playerId }) }

    var body: some View {
        List {
            if let p = player {
                Section("プロフィール") {
                    if !p.homeCourse.isEmpty {
                        Label(p.homeCourse, systemImage: "flag.fill")
                    }
                    if !p.homeTee.isEmpty {
                        Label("ティー: \(p.homeTee)", systemImage: "mappin.and.ellipse")
                    }
                    if !p.handicap.isEmpty {
                        Label("HCP \(p.handicap)", systemImage: "number")
                    }
                    if !p.note.isEmpty {
                        Text(p.note).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button {
                        store.toggleFavoritePlayer(id: p.id)
                    } label: {
                        Label(
                            p.isFavorite ? "お気に入り解除" : "お気に入りに追加",
                            systemImage: p.isFavorite ? "star.slash.fill" : "star.fill"
                        )
                        .foregroundStyle(Color.orange)
                    }
                    Button {
                        store.toggleHiddenPlayer(id: p.id)
                    } label: {
                        Label(
                            p.isHidden ? "一覧に再表示" : "一覧から非表示",
                            systemImage: p.isHidden ? "eye.fill" : "eye.slash.fill"
                        )
                    }
                    if p.homeCourse.isEmpty && p.homeTee.isEmpty && p.handicap.isEmpty && p.note.isEmpty {
                        Text("ホームコース未登録")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("プレイヤーを削除", role: .destructive) {
                        confirmDelete = true
                    }
                } footer: {
                    Text("削除するとマスター一覧から消えます。過去ラウンドのスコア記録は残ります。")
                }
            }

            Section("生涯握り戦績") {
                statRow("対戦数", "\(career.roundsPlayed)")
                statRow("勝ち", "\(career.wins)")
                statRow("負け", "\(career.losses)")
                statRow("引き分け", "\(career.draws)")
                HStack {
                    Text("累計収支")
                    Spacer()
                    Text(yen(career.totalNetYen))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(career.totalNetYen >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                }
                HStack {
                    Text("オリンピック収支")
                    Spacer()
                    Text(yen(career.totalOlympicYen))
                        .foregroundStyle(career.totalOlympicYen >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                }
                statRow("オリンピック累計点", "\(career.totalOlympicPoints)")
            }

            Section("オリンピック／握り履歴") {
                if career.history.isEmpty {
                    Text("精算確定したラウンドがまだありません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(career.history) { h in
                    NavigationLink {
                        if store.rounds.contains(where: { $0.id == h.roundId }) {
                            RoundDetailView(roundId: h.roundId)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(h.title).font(.headline)
                                Spacer()
                                Text(yen(h.netYen))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(h.netYen >= 0 ? RivieraTheme.fairway : RivieraTheme.flag)
                            }
                            Text(h.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("グロス \(h.grossScore) · 五輪 \(h.olympicPoints)点 · 五輪精算 \(yen(h.olympicYen))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button("プロフィールを編集") { showEditor = true }
            }
        }
        .navigationTitle(career.name)
        .sheet(isPresented: $showEditor) {
            PlayerEditorSheet(player: player)
        }
        .alert("プレイヤーを削除しますか？", isPresented: $confirmDelete) {
            Button("削除", role: .destructive) {
                store.deletePlayer(id: playerId)
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("マスター一覧から完全に削除します。過去ラウンドのスコア記録は残ります。")
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func yen(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.positivePrefix = "+"
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
}
