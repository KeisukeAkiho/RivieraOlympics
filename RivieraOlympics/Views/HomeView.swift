import SwiftUI

private enum RoundBrowseMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "一覧"
        case .calendar: return "カレンダー"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: RoundStore
    @State private var showNew = false
    @State private var roundSearch = ""
    @State private var showArchived = false
    @State private var showAllRounds = false
    @State private var browseMode: RoundBrowseMode = .list
    @State private var selectedCalendarDay: Date?
    @State private var deleteTargetId: UUID?
    @State private var deleteTargetTitle = ""
    @State private var showDeleteConfirm = false

    private static let defaultRoundLimit = 10

    private var filteredRounds: [GolfRound] {
        let base = showArchived ? store.rounds : store.activeRounds
        let q = roundSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { round in
            Self.textMatches(round.title, q)
                || Self.textMatches(round.courseName, q)
                || Self.textMatches(round.listTitleWithCourse, q)
                || Self.textMatches(round.selectedTeeName, q)
                || round.players.contains { Self.textMatches($0.name, q) }
                || Self.textMatches(round.date.formatted(date: .abbreviated, time: .omitted), q)
                || Self.textMatches(round.date.formatted(date: .numeric, time: .omitted), q)
        }
    }

    /// Default list shows ~10; search / “show all” reveals the rest.
    private var displayedRounds: [GolfRound] {
        let q = roundSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty || showAllRounds { return filteredRounds }
        return Array(filteredRounds.prefix(Self.defaultRoundLimit))
    }

    private var hiddenRoundCount: Int {
        max(0, filteredRounds.count - displayedRounds.count)
    }

    private var selectedCalendarDayRounds: [GolfRound] {
        guard let selectedCalendarDay else { return [] }
        let day = Calendar.current.startOfDay(for: selectedCalendarDay)
        return filteredRounds
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.date > $1.date }
    }

    private static func textMatches(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(
            of: needle,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        ) != nil
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RivieraTheme.fairwayDeep, RivieraTheme.fairway.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if browseMode == .calendar {
                calendarBrowseLayout
            } else {
                List {
                    homeControlSections
                    roundsListSection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("リビエラオリンピック")
        .searchable(
            text: $roundSearch,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "ラウンド・コース・選手で検索"
        )
        .onChange(of: roundSearch) { _, _ in
            if roundSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showAllRounds = false
            }
        }
        .onChange(of: browseMode) { _, mode in
            // Calendar always uses the full filtered set (no 10-item list cap).
            if mode == .calendar {
                showAllRounds = false
                if selectedCalendarDay == nil {
                    selectedCalendarDay = Calendar.current.startOfDay(for: Date())
                }
            }
        }
        .sheet(isPresented: $showNew) {
            NewRoundView()
        }
        .alert("ラウンドを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                if let id = deleteTargetId {
                    store.deleteRound(id: id)
                }
                deleteTargetId = nil
                deleteTargetTitle = ""
            }
            Button("キャンセル", role: .cancel) {
                deleteTargetId = nil
                deleteTargetTitle = ""
            }
        } message: {
            Text("「\(deleteTargetTitle)」を完全に削除します。この操作は元に戻せません。")
        }
    }

    @ViewBuilder
    private var homeControlSections: some View {
        Section {
            Button {
                showNew = true
            } label: {
                Label("新しいラウンド", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .disabled(store.activePlayers.count < 2)
            if store.activePlayers.count < 2 {
                Text("先にプレイヤーを2人以上登録（非表示でない）してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        Section {
            Picker("表示", selection: $browseMode) {
                ForEach(RoundBrowseMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("アーカイブも表示", isOn: $showArchived)
        }
    }

    /// Calendar mode uses ScrollView so day taps are not swallowed by List.
    private var calendarBrowseLayout: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    calendarControlsCard

                    if filteredRounds.isEmpty {
                        Text(store.rounds.isEmpty
                             ? "まだラウンドがありません。"
                             : (roundSearch.isEmpty
                                ? "表示できるラウンドがありません。"
                                : "「\(roundSearch)」に一致するラウンドがありません。"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemBackground).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("カレンダー")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            RoundsCalendarView(rounds: filteredRounds, selectedDay: $selectedCalendarDay)
                            Text("日付をタップすると、下にその日のラウンドが表示されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if let selectedCalendarDay {
                        calendarDayDetailCard(selectedCalendarDay)
                            .id("dayDetail")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: selectedCalendarDay) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo("dayDetail", anchor: .top)
                }
            }
        }
    }

    private var calendarControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showNew = true
            } label: {
                Label("新しいラウンド", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(store.activePlayers.count < 2)

            if store.activePlayers.count < 2 {
                Text("先にプレイヤーを2人以上登録（非表示でない）してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Picker("表示", selection: $browseMode) {
                ForEach(RoundBrowseMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("アーカイブも表示", isOn: $showArchived)
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func calendarDayDetailCard(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.formatted(date: .complete, time: .omitted))
                .font(.headline)

            if selectedCalendarDayRounds.isEmpty {
                Text("この日のラウンドはありません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(selectedCalendarDayRounds) { round in
                    NavigationLink {
                        RoundDetailView(roundId: round.id)
                    } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(RivieraTheme.fairway)
                                .frame(width: 4, height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(round.listTitleWithCourse)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(round.courseName.isEmpty ? "コース未設定" : round.courseName)
                                    .font(.subheadline)
                                    .foregroundStyle(RivieraTheme.fairwayDeep)
                                Text(round.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(round.players.map(\.name).joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var roundsListSection: some View {
        Section(showArchived ? "ラウンド（アーカイブ含む）" : "保存済みラウンド") {
            if store.rounds.isEmpty {
                Text("まだラウンドがありません。")
                    .foregroundStyle(.secondary)
            } else if filteredRounds.isEmpty {
                Text(roundSearch.isEmpty
                     ? "表示できるラウンドがありません。"
                     : "「\(roundSearch)」に一致するラウンドがありません。")
                    .foregroundStyle(.secondary)
            }
            ForEach(displayedRounds) { round in
                HStack(spacing: 8) {
                    NavigationLink {
                        RoundDetailView(roundId: round.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(round.listTitleWithCourse).font(.headline)
                                if round.isArchived {
                                    Text("アーカイブ")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                if round.isSettled {
                                    Text("精算済")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(RivieraTheme.sand)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(round.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(round.players.map(\.name).joined(separator: " · "))
                                .font(.caption2)
                        }
                        .opacity(round.isArchived ? 0.65 : 1)
                    }

                    Menu {
                        Button {
                            store.toggleArchiveRound(id: round.id)
                        } label: {
                            Label(
                                round.isArchived ? "アーカイブから復元" : "アーカイブ（非表示）",
                                systemImage: round.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
                            )
                        }
                        Button(role: .destructive) {
                            askDelete(round)
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
                        askDelete(round)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    Button {
                        store.toggleArchiveRound(id: round.id)
                    } label: {
                        Label(
                            round.isArchived ? "復元" : "アーカイブ",
                            systemImage: round.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
                        )
                    }
                    .tint(round.isArchived ? RivieraTheme.fairway : .indigo)
                }
                .contextMenu {
                    Button {
                        store.toggleArchiveRound(id: round.id)
                    } label: {
                        Label(
                            round.isArchived ? "アーカイブから復元" : "アーカイブ（非表示）",
                            systemImage: round.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
                        )
                    }
                    Button(role: .destructive) {
                        askDelete(round)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
            if hiddenRoundCount > 0 {
                Button {
                    showAllRounds = true
                } label: {
                    Label("さらに \(hiddenRoundCount) 件表示", systemImage: "chevron.down")
                }
            } else if showAllRounds, filteredRounds.count > Self.defaultRoundLimit,
                      roundSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    showAllRounds = false
                } label: {
                    Label("先頭 \(Self.defaultRoundLimit) 件に戻す", systemImage: "chevron.up")
                }
            }
        }
    }

    private func askDelete(_ round: GolfRound) {
        deleteTargetId = round.id
        deleteTargetTitle = round.title
        showDeleteConfirm = true
    }
}

