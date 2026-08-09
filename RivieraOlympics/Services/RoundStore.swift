import Combine
import Foundation

struct AppPersistence: Codable {
    var players: [RegisteredPlayer]
    var rounds: [GolfRound]
    var courses: [RegisteredCourse]
    var customStakeRates: [Int]
    var customSettlementCaps: [Int]
    var rulePresets: [NamedGameRulePreset]
    var activeRulePresetId: UUID?

    init(
        players: [RegisteredPlayer],
        rounds: [GolfRound],
        courses: [RegisteredCourse] = [],
        customStakeRates: [Int] = [],
        customSettlementCaps: [Int] = [],
        rulePresets: [NamedGameRulePreset] = [],
        activeRulePresetId: UUID? = nil
    ) {
        self.players = players
        self.rounds = rounds
        self.courses = courses
        self.customStakeRates = customStakeRates
        self.customSettlementCaps = customSettlementCaps
        self.rulePresets = rulePresets
        self.activeRulePresetId = activeRulePresetId
    }

    enum CodingKeys: String, CodingKey {
        case players, rounds, courses, customStakeRates, customSettlementCaps, rulePresets, activeRulePresetId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        players = try c.decode([RegisteredPlayer].self, forKey: .players)
        rounds = try c.decode([GolfRound].self, forKey: .rounds)
        courses = try c.decodeIfPresent([RegisteredCourse].self, forKey: .courses) ?? []
        customStakeRates = try c.decodeIfPresent([Int].self, forKey: .customStakeRates) ?? []
        customSettlementCaps = try c.decodeIfPresent([Int].self, forKey: .customSettlementCaps) ?? []
        rulePresets = try c.decodeIfPresent([NamedGameRulePreset].self, forKey: .rulePresets) ?? []
        activeRulePresetId = try c.decodeIfPresent(UUID.self, forKey: .activeRulePresetId)
    }
}

@MainActor
final class RoundStore: ObservableObject {
    @Published var players: [RegisteredPlayer] = []
    @Published var rounds: [GolfRound] = []
    @Published var courses: [RegisteredCourse] = []
    @Published var activeRoundId: UUID?
    /// プリセット以外にユーザーが登録した掛け金率
    @Published var customStakeRates: [Int] = []
    /// プリセット以外にユーザーが登録した精算上限（0=なしはプリセット）
    @Published var customSettlementCaps: [Int] = []
    /// 名前付きルールパラメータセット
    @Published var rulePresets: [NamedGameRulePreset] = []
    /// ルールブック表示・新規ラウンド既定に使うセット
    @Published var activeRulePresetId: UUID = NamedGameRulePreset.rivieraDefault.id

    static let presetStakeRates: [Int] = [20, 50, 100, 200, 500]
    /// 0 = 制限なし
    static let presetSettlementCaps: [Int] = [0, 500, 1_000, 2_000, 5_000, 10_000]

    private let fileURL: URL
    private let legacyRoundsURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("riviera_olympics_app.json")
        legacyRoundsURL = dir.appendingPathComponent("riviera_olympics_rounds.json")
        load()
    }

    /// プリセット＋ユーザー登録（昇順・重複なし）
    var availableStakeRates: [Int] {
        Array(Set(Self.presetStakeRates + customStakeRates)).sorted()
    }

    var availableSettlementCaps: [Int] {
        Array(Set(Self.presetSettlementCaps + customSettlementCaps)).sorted()
    }

    func isPresetStakeRate(_ rate: Int) -> Bool {
        Self.presetStakeRates.contains(rate)
    }

    func isPresetSettlementCap(_ cap: Int) -> Bool {
        Self.presetSettlementCaps.contains(cap)
    }

    /// 任意金額を候補に登録（プリセット・既存は無視）。正の整数のみ。
    func registerCustomStakeRate(_ rate: Int) {
        guard rate > 0, !Self.presetStakeRates.contains(rate) else { return }
        guard !customStakeRates.contains(rate) else { return }
        customStakeRates.append(rate)
        customStakeRates.sort()
        save()
    }

    func removeCustomStakeRate(_ rate: Int) {
        customStakeRates.removeAll { $0 == rate }
        save()
    }

    /// 任意上限を候補に登録（0・プリセット・既存は無視）。正の整数のみ。
    func registerCustomSettlementCap(_ cap: Int) {
        guard cap > 0, !Self.presetSettlementCaps.contains(cap) else { return }
        guard !customSettlementCaps.contains(cap) else { return }
        customSettlementCaps.append(cap)
        customSettlementCaps.sort()
        save()
    }

    func removeCustomSettlementCap(_ cap: Int) {
        customSettlementCaps.removeAll { $0 == cap }
        save()
    }

    // MARK: - Named rule presets

    var activeRulePreset: NamedGameRulePreset {
        rulePreset(id: activeRulePresetId) ?? .rivieraDefault
    }

    func rulePreset(id: UUID?) -> NamedGameRulePreset? {
        guard let id else { return nil }
        if id == NamedGameRulePreset.rivieraDefault.id {
            return .rivieraDefault
        }
        return rulePresets.first(where: { $0.id == id })
    }

    func setActiveRulePresetId(_ id: UUID) {
        guard rulePreset(id: id) != nil else { return }
        activeRulePresetId = id
        save()
    }

    /// ラウンド／下書きへアクティブセットを適用
    func applyActiveRules(to options: inout RoundOptions) {
        options.applyRulePreset(activeRulePreset)
    }

    func applyRulePreset(_ presetId: UUID, toRoundId roundId: UUID) {
        guard let preset = rulePreset(id: presetId),
              let idx = rounds.firstIndex(where: { $0.id == roundId }),
              !rounds[idx].isSettled else { return }
        rounds[idx].options.applyRulePreset(preset)
        save()
    }

    /// 現在のラウンド設定から新規保存。同名があれば末尾に番号を付ける。
    @discardableResult
    func saveRulePreset(name: String, from options: RoundOptions) -> NamedGameRulePreset? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var unique = trimmed
        if unique == NamedGameRulePreset.rivieraDefault.name
            || rulePresets.contains(where: { $0.name == unique }) {
            var n = 2
            while rulePresets.contains(where: { $0.name == "\(trimmed) (\(n))" })
                || "\(trimmed) (\(n))" == NamedGameRulePreset.rivieraDefault.name {
                n += 1
            }
            unique = "\(trimmed) (\(n))"
        }
        let preset = NamedGameRulePreset.from(name: unique, options: options)
        rulePresets.append(preset)
        rulePresets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
        return preset
    }

    /// 既存プリセットを現在値で上書き（名前は維持）。リビエラ既定は不可。
    @discardableResult
    func updateRulePreset(id: UUID, from options: RoundOptions) -> NamedGameRulePreset? {
        guard id != NamedGameRulePreset.rivieraDefault.id,
              let idx = rulePresets.firstIndex(where: { $0.id == id }) else { return nil }
        rulePresets[idx].olympicsPoints = options.olympicsPoints
        rulePresets[idx].customPointRules = options.customPointRules
        rulePresets[idx].lasVegasRules = options.lasVegasRules
        rulePresets[idx].updatedAt = Date()
        save()
        return rulePresets[idx]
    }

    /// プリセット全体を置換（改名含む）。リビエラ既定は不可。
    @discardableResult
    func replaceRulePreset(_ preset: NamedGameRulePreset) -> NamedGameRulePreset? {
        guard preset.id != NamedGameRulePreset.rivieraDefault.id else { return nil }
        var next = preset
        next.updatedAt = Date()
        let trimmed = next.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != NamedGameRulePreset.rivieraDefault.name else { return nil }
        next.name = trimmed
        if let idx = rulePresets.firstIndex(where: { $0.id == next.id }) {
            if rulePresets.contains(where: { $0.id != next.id && $0.name == trimmed }) { return nil }
            rulePresets[idx] = next
        } else {
            if rulePresets.contains(where: { $0.name == trimmed }) { return nil }
            rulePresets.append(next)
        }
        rulePresets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
        return next
    }

    func renameRulePreset(id: UUID, to name: String) {
        guard id != NamedGameRulePreset.rivieraDefault.id,
              let idx = rulePresets.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != NamedGameRulePreset.rivieraDefault.name else { return }
        if rulePresets.contains(where: { $0.id != id && $0.name == trimmed }) { return }
        rulePresets[idx].name = trimmed
        rulePresets[idx].updatedAt = Date()
        rulePresets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
    }

    func deleteRulePreset(id: UUID) {
        guard id != NamedGameRulePreset.rivieraDefault.id else { return }
        rulePresets.removeAll { $0.id == id }
        if activeRulePresetId == id {
            activeRulePresetId = NamedGameRulePreset.rivieraDefault.id
        }
        save()
    }

    var activeRound: GolfRound? {
        get { rounds.first(where: { $0.id == activeRoundId }) }
        set {
            guard let newValue else { return }
            if let idx = rounds.firstIndex(where: { $0.id == newValue.id }) {
                rounds[idx] = newValue
            } else {
                rounds.insert(newValue, at: 0)
            }
            activeRoundId = newValue.id
            save()
        }
    }

    // MARK: - Players

    func addPlayer(
        name: String,
        homeCourse: String = "",
        homeTee: String = "",
        handicap: String = "",
        note: String = "",
        honestJohn: Int = 90
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        players.append(RegisteredPlayer(
            name: trimmed,
            homeCourse: homeCourse.trimmingCharacters(in: .whitespacesAndNewlines),
            homeTee: homeTee.trimmingCharacters(in: .whitespacesAndNewlines),
            handicap: handicap.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultHonestJohn: honestJohn
        ))
        players.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
    }

    func updatePlayer(_ player: RegisteredPlayer) {
        guard let idx = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[idx] = player
        players.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // Keep names in open rounds in sync
        for rIdx in rounds.indices where !rounds[rIdx].isSettled {
            if let pIdx = rounds[rIdx].players.firstIndex(where: { $0.id == player.id }) {
                rounds[rIdx].players[pIdx].name = player.name
                rounds[rIdx].players[pIdx].honestJohnDeclared = player.defaultHonestJohn
            }
        }
        save()
    }

    func deletePlayer(id: UUID) {
        players.removeAll { $0.id == id }
        save()
    }

    // MARK: - Courses

    func addCourse(_ course: RegisteredCourse) {
        let trimmed = course.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = course
        next.name = trimmed
        next.pars = RegisteredCourse.normalizedPars(next.pars)
        courses.append(next)
        courses.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
    }

    func updateCourse(_ course: RegisteredCourse) {
        guard let idx = courses.firstIndex(where: { $0.id == course.id }) else { return }
        var next = course
        next.name = course.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.name.isEmpty else { return }
        next.pars = RegisteredCourse.normalizedPars(next.pars)
        courses[idx] = next
        courses.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // Keep open round names in sync when linked
        for rIdx in rounds.indices where !rounds[rIdx].isSettled && rounds[rIdx].courseId == course.id {
            rounds[rIdx].applyCourse(next)
        }
        save()
    }

    func deleteCourse(id: UUID) {
        courses.removeAll { $0.id == id }
        save()
    }

    func course(id: UUID?) -> RegisteredCourse? {
        guard let id else { return nil }
        return courses.first(where: { $0.id == id })
    }

    func applyCourse(_ courseId: UUID, toRoundId roundId: UUID, teeName: String? = nil) {
        guard let course = course(id: courseId),
              let idx = rounds.firstIndex(where: { $0.id == roundId }),
              !rounds[idx].isSettled else { return }
        rounds[idx].applyCourse(course, teeName: teeName)
        save()
    }

    func applyTee(_ teeName: String, toRoundId roundId: UUID) {
        guard let idx = rounds.firstIndex(where: { $0.id == roundId }),
              !rounds[idx].isSettled,
              let courseId = rounds[idx].courseId,
              let course = course(id: courseId) else { return }
        rounds[idx].applyTee(named: teeName, from: course)
        save()
    }

    /// フィリピン主要コースを不足分のみマージ登録（既存シードには Tee ヤードを補完／更新）
    @discardableResult
    func ensureBuiltInCourses() -> Int {
        let seeds = PhilippineCourseCatalog.defaultSeedCourses()
        var added = 0
        var changed = false
        for seed in seeds {
            guard let key = seed.seedKey else { continue }
            if let idx = courses.firstIndex(where: { $0.seedKey == key }) {
                if !seed.tees.isEmpty {
                    let oldTotal = courses[idx].tees.reduce(0) { $0 + $1.totalYards }
                    let newTotal = seed.tees.reduce(0) { $0 + $1.totalYards }
                    if courses[idx].tees.isEmpty || newTotal > oldTotal || courses[idx].tees.count < seed.tees.count {
                        courses[idx].tees = seed.tees
                        changed = true
                        added += 1
                    }
                }
                continue
            }
            courses.append(seed)
            added += 1
            changed = true
        }
        if changed {
            courses.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        let yardsFilled = backfillRoundYardsFromCourses()
        if changed || yardsFilled {
            save()
        }
        return added
    }

    /// 既存ラウンドにコースは付いているが Tee ヤードが空のとき補完
    @discardableResult
    func backfillRoundYardsFromCourses() -> Bool {
        var changed = false
        for idx in rounds.indices {
            guard let courseId = rounds[idx].courseId,
                  let course = course(id: courseId),
                  !course.tees.isEmpty else { continue }
            let needsYards = !rounds[idx].hasHoleYards
            let needsTeeName = rounds[idx].selectedTeeName.isEmpty
            guard needsYards || needsTeeName else { continue }
            rounds[idx].applyTee(named: rounds[idx].selectedTeeName, from: course)
            changed = true
        }
        return changed
    }

    /// ナイン組み合わせを登録（既存 seedKey なら更新）
    @discardableResult
    func registerComposedCourse(from club: GolfClubCatalogEntry, outId: String, inId: String) -> RegisteredCourse? {
        guard var course = club.makeCourse(outId: outId, inId: inId) else { return nil }
        if let key = course.seedKey,
           let idx = courses.firstIndex(where: { $0.seedKey == key }) {
            course.id = courses[idx].id
            courses[idx] = course
            save()
            return course
        }
        addCourse(course)
        return course
    }

    // MARK: - Rounds

    func createRound(
        title: String,
        playerIds: [UUID],
        options: RoundOptions = RoundOptions(),
        courseId: UUID? = nil,
        teeName: String? = nil
    ) {
        let selected = playerIds.compactMap { id in players.first(where: { $0.id == id }) }
        guard selected.count >= 2 else { return }
        let course = course(id: courseId)
        let round = GolfRound.newRound(
            title: title,
            registered: selected,
            options: options,
            course: course,
            teeName: teeName
        )
        rounds.insert(round, at: 0)
        activeRoundId = round.id
        save()
    }

    func updateRound(_ round: GolfRound) {
        guard let idx = rounds.firstIndex(where: { $0.id == round.id }) else { return }
        rounds[idx] = round
        save()
    }

    func deleteRound(id: UUID) {
        rounds.removeAll { $0.id == id }
        if activeRoundId == id { activeRoundId = rounds.first?.id }
        save()
    }

    /// オリンピック含む握りを確定し、生涯戦績に反映
    @discardableResult
    func settleRound(id: UUID) -> SettlementSummary? {
        guard let idx = rounds.firstIndex(where: { $0.id == id }) else { return nil }
        var round = rounds[idx]
        let summary = SettlementEngine.summarize(round)
        round.isSettled = true
        round.settledAt = Date()
        round.settledSummary = summary
        rounds[idx] = round
        save()
        return summary
    }

    func unsettleRound(id: UUID) {
        guard let idx = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[idx].isSettled = false
        rounds[idx].settledAt = nil
        rounds[idx].settledSummary = nil
        save()
    }

    // MARK: - Career

    func career(for playerId: UUID) -> CareerStats {
        let name = players.first(where: { $0.id == playerId })?.name
            ?? rounds.flatMap(\.players).first(where: { $0.id == playerId })?.name
            ?? "不明"

        var history: [PlayerRoundResult] = []
        for round in rounds where round.isSettled {
            let summary = round.settledSummary ?? SettlementEngine.summarize(round)
            guard let total = summary.playerTotals.first(where: { $0.playerId == playerId }) else { continue }
            history.append(PlayerRoundResult(
                roundId: round.id,
                title: round.title,
                date: round.settledAt ?? round.date,
                grossScore: total.grossScore,
                olympicPoints: total.olympicPoints,
                olympicYen: total.olympicYen,
                netYen: total.netYen
            ))
        }
        history.sort { $0.date > $1.date }

        let wins = history.filter(\.isWin).count
        let losses = history.filter(\.isLose).count
        let draws = history.count - wins - losses

        return CareerStats(
            playerId: playerId,
            name: name,
            roundsPlayed: history.count,
            wins: wins,
            losses: losses,
            draws: draws,
            totalNetYen: history.reduce(0) { $0 + $1.netYen },
            totalOlympicYen: history.reduce(0) { $0 + $1.olympicYen },
            totalOlympicPoints: history.reduce(0) { $0 + $1.olympicPoints },
            history: history
        )
    }

    // MARK: - Persistence

    func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(AppPersistence.self, from: data) {
            players = decoded.players
            rounds = decoded.rounds
            courses = decoded.courses.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            customStakeRates = decoded.customStakeRates.sorted()
            customSettlementCaps = decoded.customSettlementCaps.sorted()
            rulePresets = decoded.rulePresets.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            if let id = decoded.activeRulePresetId, rulePreset(id: id) != nil {
                activeRulePresetId = id
            } else {
                activeRulePresetId = NamedGameRulePreset.rivieraDefault.id
            }
            activeRoundId = decoded.rounds.first?.id
            ensureBuiltInCourses()
            return
        }

        // Migrate legacy rounds-only file
        if let data = try? Data(contentsOf: legacyRoundsURL),
           let decoded = try? decoder.decode([GolfRound].self, from: data) {
            rounds = decoded
            var map: [UUID: RegisteredPlayer] = [:]
            for r in decoded {
                for p in r.players {
                    if map[p.id] == nil {
                        map[p.id] = RegisteredPlayer(
                            id: p.id,
                            name: p.name,
                            defaultHonestJohn: p.honestJohnDeclared
                        )
                    }
                }
            }
            players = map.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            activeRoundId = decoded.first?.id
            ensureBuiltInCourses()
            save()
        } else {
            ensureBuiltInCourses()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = AppPersistence(
            players: players,
            rounds: rounds,
            courses: courses,
            customStakeRates: customStakeRates,
            customSettlementCaps: customSettlementCaps,
            rulePresets: rulePresets,
            activeRulePresetId: activeRulePresetId
        )
        if let data = try? encoder.encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
