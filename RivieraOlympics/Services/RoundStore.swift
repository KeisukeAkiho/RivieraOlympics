import Combine
import Foundation

struct AppPersistence: Codable {
    var players: [RegisteredPlayer]
    var rounds: [GolfRound]
}

@MainActor
final class RoundStore: ObservableObject {
    @Published var players: [RegisteredPlayer] = []
    @Published var rounds: [GolfRound] = []
    @Published var activeRoundId: UUID?

    private let fileURL: URL
    private let legacyRoundsURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("riviera_olympics_app.json")
        legacyRoundsURL = dir.appendingPathComponent("riviera_olympics_rounds.json")
        load()
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

    // MARK: - Rounds

    func createRound(title: String, playerIds: [UUID]) {
        let selected = playerIds.compactMap { id in players.first(where: { $0.id == id }) }
        guard selected.count >= 2 else { return }
        let round = GolfRound.newRound(title: title, registered: selected)
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
            activeRoundId = decoded.rounds.first?.id
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
            save()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payload = AppPersistence(players: players, rounds: rounds)
        if let data = try? encoder.encode(payload) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
