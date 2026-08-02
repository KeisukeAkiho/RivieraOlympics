import SwiftUI

struct NewRoundView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = "リビエラ ラウンド"
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("ラウンド") {
                    TextField("タイトル", text: $title)
                }

                Section("参加プレイヤー（2人以上）") {
                    if store.players.isEmpty {
                        Text("先に「プレイヤー」タブで登録してください。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.players) { p in
                        Toggle(isOn: Binding(
                            get: { selected.contains(p.id) },
                            set: { on in
                                if on { selected.insert(p.id) } else { selected.remove(p.id) }
                            }
                        )) {
                            Text(p.name)
                        }
                    }
                }

                Section {
                    Text("作成後、スコア表（上）とオリンピック表（下）を横スクロールで入力できます。")
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
                        let ids = store.players.map(\.id).filter { selected.contains($0) }
                        store.createRound(title: title, playerIds: ids)
                        dismiss()
                    }
                    .disabled(selected.count < 2)
                }
            }
        }
    }
}
