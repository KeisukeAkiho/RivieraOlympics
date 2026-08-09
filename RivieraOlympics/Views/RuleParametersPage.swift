import SwiftUI

/// ルールタブ: 名前付きパラメータの管理・ルールブック同期・ラウンド適用
struct RuleParametersPage: View {
    @EnvironmentObject private var store: RoundStore

    @State private var showNewNameAlert = false
    @State private var newPresetName = "マイルール"
    @State private var appliedMessage: String?

    private var openRounds: [GolfRound] {
        store.rounds.filter { !$0.isSettled }
    }

    var body: some View {
        List {
            Section {
                Text("ここで編集した点がルールブック表示と新規ラウンドの既定になります。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("ルールブック／新規ラウンドの既定") {
                presetPickerRow(NamedGameRulePreset.rivieraDefault)
                ForEach(store.rulePresets) { preset in
                    presetPickerRow(preset)
                }
                Text("選択中: \(store.activeRulePreset.name)")
                    .font(.caption)
                    .foregroundStyle(RivieraTheme.fairway)
            }

            Section("セットの編集") {
                NavigationLink {
                    RulePresetEditorView(mode: .builtInReference)
                } label: {
                    Label("リビエラ既定を見る", systemImage: "eye")
                }

                ForEach(store.rulePresets) { preset in
                    NavigationLink {
                        RulePresetEditorView(mode: .edit(preset.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                            Text("独自 \(preset.customPointRules.count) 件")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deletePresets)

                Button {
                    newPresetName = "マイルール"
                    showNewNameAlert = true
                } label: {
                    Label("現在の既定から新規セットを作成", systemImage: "plus.circle.fill")
                }
            }

            if !openRounds.isEmpty {
                Section("オープン中のラウンドへ適用") {
                    ForEach(openRounds) { round in
                        Button {
                            store.applyRulePreset(store.activeRulePresetId, toRoundId: round.id)
                            appliedMessage = "「\(round.title)」に「\(store.activeRulePreset.name)」を適用しました"
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(round.title)
                                    if let name = store.rulePreset(id: round.options.activeRulePresetId)?.name {
                                        Text("現在: \(name)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("適用")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                    Text("精算済みラウンドには適用できません。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let appliedMessage {
                Section {
                    Text(appliedMessage)
                        .font(.footnote)
                        .foregroundStyle(RivieraTheme.fairway)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(pageBackground)
        .alert("新規セット名", isPresented: $showNewNameAlert) {
            TextField("名前", text: $newPresetName)
            Button("キャンセル", role: .cancel) {}
            Button("作成") {
                var opts = RoundOptions()
                opts.applyRulePreset(store.activeRulePreset)
                if let created = store.saveRulePreset(name: newPresetName, from: opts) {
                    store.setActiveRulePresetId(created.id)
                }
            }
        } message: {
            Text("いまルールブックに表示中の内容をコピーして新しいセットを作ります。")
        }
    }

    private func presetPickerRow(_ preset: NamedGameRulePreset) -> some View {
        Button {
            store.setActiveRulePresetId(preset.id)
        } label: {
            HStack {
                Text(preset.name)
                    .foregroundStyle(.primary)
                Spacer()
                if store.activeRulePresetId == preset.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(RivieraTheme.fairway)
                }
            }
        }
    }

    private func deletePresets(at offsets: IndexSet) {
        let ids = offsets.map { store.rulePresets[$0].id }
        for id in ids {
            store.deleteRulePreset(id: id)
        }
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), RivieraTheme.sand.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// プリセット編集（ルールタブ）
struct RulePresetEditorView: View {
    enum Mode: Equatable {
        case builtInReference
        case edit(UUID)
        case createNew(String)
    }

    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    @State private var name = ""
    @State private var draft = RoundOptions()
    @State private var presetId: UUID?

    private var isReadOnly: Bool {
        if case .builtInReference = mode { return true }
        return false
    }

    var body: some View {
        GameRulesSettingsView(options: $draft, isReadOnly: isReadOnly)
            .safeAreaInset(edge: .top) {
                if !isReadOnly {
                    Form {
                        Section("セット名") {
                            TextField("名前", text: $name)
                        }
                    }
                    .frame(maxHeight: 100)
                    .scrollDisabled(true)
                } else {
                    Text("リビエラ既定は参照のみです。「パラメータ」で複製して編集してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                }
            }
            .navigationTitle(isReadOnly ? "リビエラ既定" : "セット編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") { save() }
                    }
                }
            }
            .onAppear(perform: load)
    }

    private func load() {
        switch mode {
        case .builtInReference:
            draft.applyRulePreset(.rivieraDefault)
            name = NamedGameRulePreset.rivieraDefault.name
            presetId = NamedGameRulePreset.rivieraDefault.id
        case .edit(let id):
            guard let preset = store.rulePreset(id: id) else { return }
            name = preset.name
            presetId = preset.id
            draft.applyRulePreset(preset)
        case .createNew(let suggested):
            name = suggested
            draft.applyRulePreset(store.activeRulePreset)
            presetId = nil
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let id = presetId, id != NamedGameRulePreset.rivieraDefault.id {
            var preset = NamedGameRulePreset.from(name: trimmed, options: draft)
            preset.id = id
            if store.replaceRulePreset(preset) != nil {
                dismiss()
            }
        } else if case .createNew = mode {
            if let created = store.saveRulePreset(name: trimmed, from: draft) {
                store.setActiveRulePresetId(created.id)
                dismiss()
            }
        }
    }
}
