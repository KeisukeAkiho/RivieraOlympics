import SwiftUI

struct CoursesView: View {
    @EnvironmentObject private var store: RoundStore
    @State private var showEditor = false
    @State private var editingCourse: RegisteredCourse?
    @State private var search = ""
    @State private var seedMessage: String?

    private var filtered: [RegisteredCourse] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.courses }
        return store.courses.filter {
            $0.name.localizedStandardContains(q)
                || $0.clubName.localizedStandardContains(q)
                || $0.layoutName.localizedStandardContains(q)
                || $0.note.localizedStandardContains(q)
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    editingCourse = nil
                    showEditor = true
                } label: {
                    Label("手動でコースを登録", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                Button {
                    let n = store.ensureBuiltInCourses()
                    seedMessage = n > 0
                        ? "フィリピン全土コースを \(n) 件追加しました"
                        : "事前登録コースはすべて入っています"
                } label: {
                    Label("フィリピン全土コースを再同期", systemImage: "arrow.triangle.2.circlepath")
                }
                if let seedMessage {
                    Text(seedMessage)
                        .font(.caption)
                        .foregroundStyle(RivieraTheme.fairway)
                }
            }

            ForEach(PhilippineCourseCatalog.clubsGroupedByRegion(), id: \.region) { group in
                Section {
                    ForEach(group.clubs) { club in
                        NavigationLink {
                            ClubNineComposerView(club: club)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(club.name)
                                    .font(.headline)
                                Text(club.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(club.nines.count) ナイン · 前半/後半を組み合わせ可")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("カタログ · \(group.region)")
                } footer: {
                    if group.region == PhilippineCourseCatalog.regionOrder.last {
                        Text("前半・後半で別ナインを選べるゴルフ場はここで組み合わせます。パーは公開スコアカードに基づく事前登録のため、現地スコアカードで確認してください。")
                    }
                }
            }

            Section("登録済みコース") {
                if store.courses.isEmpty {
                    Text("まだコースがありません。")
                        .foregroundStyle(.secondary)
                } else if filtered.isEmpty {
                    Text("「\(search)」に一致するコースがありません。")
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { course in
                    Button {
                        editingCourse = course
                        showEditor = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.displayTitle)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 8) {
                                Text("パー計 \(course.totalPar)")
                                Text("前\(course.outPar)")
                                Text("後\(course.inPar)")
                                if !course.tees.isEmpty {
                                    Text("Tee \(course.tees.count)")
                                }
                                if course.isBuiltIn {
                                    Text("事前登録")
                                        .foregroundStyle(RivieraTheme.fairway)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            if !course.outNineName.isEmpty || !course.inNineName.isEmpty {
                                Text("前半: \(course.outNineName.isEmpty ? "—" : course.outNineName) / 後半: \(course.inNineName.isEmpty ? "—" : course.inNineName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { idx in
                    let ids = idx.map { filtered[$0].id }
                    for id in ids { store.deleteCourse(id: id) }
                }
            }
        }
        .navigationTitle("コース")
        .searchable(text: $search, prompt: "コース名・ゴルフ場で検索")
        .sheet(isPresented: $showEditor) {
            CourseEditorSheet(course: editingCourse)
        }
        .onAppear {
            _ = store.ensureBuiltInCourses()
        }
    }
}

/// ゴルフ場カタログから前半・後半ナインを選んで登録
struct ClubNineComposerView: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss

    let club: GolfClubCatalogEntry
    @State private var outId: String
    @State private var inId: String
    @State private var message: String?

    init(club: GolfClubCatalogEntry) {
        self.club = club
        let first = club.suggestedLayouts.first
        _outId = State(initialValue: first?.outId ?? club.nines.first?.id ?? "")
        _inId = State(initialValue: first?.inId ?? club.nines.dropFirst().first?.id ?? club.nines.first?.id ?? "")
    }

    private var preview: RegisteredCourse? {
        club.makeCourse(outId: outId, inId: inId)
    }

    var body: some View {
        Form {
            Section {
                Text(club.location)
                    .foregroundStyle(.secondary)
            } header: {
                Text(club.name)
            }

            Section("推奨レイアウト") {
                ForEach(Array(club.suggestedLayouts.enumerated()), id: \.offset) { _, layout in
                    Button {
                        outId = layout.outId
                        inId = layout.inId
                    } label: {
                        HStack {
                            Text(layout.layoutName)
                            Spacer()
                            if outId == layout.outId && inId == layout.inId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(RivieraTheme.fairway)
                            }
                        }
                    }
                }
            }

            Section("前半ナイン") {
                Picker("前半", selection: $outId) {
                    ForEach(club.nines) { nine in
                        Text("\(nine.name)（パー\(nine.totalPar)）").tag(nine.id)
                    }
                }
                .labelsHidden()
            }

            Section("後半ナイン") {
                Picker("後半", selection: $inId) {
                    ForEach(club.nines) { nine in
                        Text("\(nine.name)（パー\(nine.totalPar)）").tag(nine.id)
                    }
                }
                .labelsHidden()
            }

            if let preview {
                Section("プレビュー") {
                    Text(preview.displayTitle)
                        .font(.subheadline.weight(.semibold))
                    Text("パー計 \(preview.totalPar)（前\(preview.outPar) / 後\(preview.inPar)）")
                    Text(preview.pars.map(String.init).joined(separator: " · "))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if !preview.tees.isEmpty {
                        Text(preview.tees.map { "\($0.name) \($0.totalYards) yd" }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(RivieraTheme.fairway)
                    }
                }
            }

            Section {
                Button("この組み合わせを登録") {
                    if store.registerComposedCourse(from: club, outId: outId, inId: inId) != nil {
                        message = "登録しました"
                        dismiss()
                    } else {
                        message = "登録に失敗しました"
                    }
                }
                .disabled(preview == nil)
                if let message {
                    Text(message).font(.caption)
                }
            } footer: {
                Text("公開スコアカード等を参考にした値です。クラブ公式と異なる場合は登録後に編集してください。")
            }
        }
        .navigationTitle("ナイン組み合わせ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CourseEditorSheet: View {
    @EnvironmentObject private var store: RoundStore
    @Environment(\.dismiss) private var dismiss
    var course: RegisteredCourse?

    @State private var name = ""
    @State private var clubName = ""
    @State private var layoutName = ""
    @State private var outNineName = ""
    @State private var inNineName = ""
    @State private var note = ""
    @State private var pars: [Int] = RegisteredCourse.defaultPars
    @State private var tees: [CourseTee] = []
    @State private var customTeeName = ""
    @State private var expandedTeeID: UUID?

    private var isNew: Bool { course == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("表示名（必須）", text: $name)
                    TextField("ゴルフ場名", text: $clubName)
                    TextField("レイアウト名", text: $layoutName)
                    TextField("前半ナイン名", text: $outNineName)
                    TextField("後半ナイン名", text: $inNineName)
                    TextField("メモ", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("パー（合計 \(pars.reduce(0, +)) · 前\(pars.prefix(9).reduce(0, +)) / 後\(pars.suffix(9).reduce(0, +))）") {
                    ForEach(0..<9, id: \.self) { i in
                        Stepper("前半 \(i + 1): パー \(pars[i])", value: $pars[i], in: 3...5)
                    }
                    ForEach(9..<18, id: \.self) { i in
                        Stepper("後半 \(i - 8): パー \(pars[i])", value: $pars[i], in: 3...5)
                    }
                    Button("すべてパー4に戻す") {
                        pars = RegisteredCourse.defaultPars
                    }
                }

                Section {
                    ForEach($tees) { $tee in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedTeeID == tee.id },
                                set: { expandedTeeID = $0 ? tee.id : nil }
                            )
                        ) {
                            ForEach(0..<9, id: \.self) { i in
                                HStack {
                                    Text("前半 \(i + 1)")
                                    Spacer()
                                    TextField("yd", value: $tee.yards[i], format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 72)
                                    Text("yd")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ForEach(9..<18, id: \.self) { i in
                                HStack {
                                    Text("後半 \(i - 8)")
                                    Spacer()
                                    TextField("yd", value: $tee.yards[i], format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 72)
                                    Text("yd")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button("このTeeを削除", role: .destructive) {
                                tees.removeAll { $0.id == tee.id }
                                if expandedTeeID == tee.id { expandedTeeID = nil }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("Tee名", text: $tee.name)
                                Text("合計 \(tee.totalYards) yd")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(CourseTee.presetNames.filter { name in !tees.contains(where: { $0.name == name }) }, id: \.self) { preset in
                        Button {
                            tees.append(CourseTee(name: preset))
                            expandedTeeID = tees.last?.id
                        } label: {
                            Label("\(preset) を追加", systemImage: "plus.circle")
                        }
                    }

                    HStack {
                        TextField("カスタムTee名", text: $customTeeName)
                        Button("追加") {
                            let trimmed = customTeeName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            guard !tees.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
                            tees.append(CourseTee(name: trimmed))
                            customTeeName = ""
                            expandedTeeID = tees.last?.id
                        }
                        .disabled(customTeeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Tee距離（ヤード）")
                } footer: {
                    Text("Gold / Blue / White / Red を追加し、各ホールのヤードを入力できます。事前登録コースにはスコアカードの距離が入っています。")
                }

                Section {
                    Text("新規ラウンドやラウンド設定から選択すると反映されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isNew ? "コース登録" : "コース編集")
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
                if let course {
                    name = course.name
                    clubName = course.clubName
                    layoutName = course.layoutName
                    outNineName = course.outNineName
                    inNineName = course.inNineName
                    note = course.note
                    pars = course.pars
                    tees = course.tees
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cleanedTees = tees
            .map { CourseTee(id: $0.id, name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), yards: $0.yards) }
            .filter { !$0.name.isEmpty }
        if var existing = course {
            existing.name = trimmed
            existing.clubName = clubName.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.layoutName = layoutName.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.outNineName = outNineName.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.inNineName = inNineName.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.pars = pars
            existing.tees = cleanedTees
            store.updateCourse(existing)
        } else {
            store.addCourse(RegisteredCourse(
                name: trimmed,
                pars: pars,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                clubName: clubName.trimmingCharacters(in: .whitespacesAndNewlines),
                layoutName: layoutName.trimmingCharacters(in: .whitespacesAndNewlines),
                outNineName: outNineName.trimmingCharacters(in: .whitespacesAndNewlines),
                inNineName: inNineName.trimmingCharacters(in: .whitespacesAndNewlines),
                tees: cleanedTees
            ))
        }
        dismiss()
    }
}
