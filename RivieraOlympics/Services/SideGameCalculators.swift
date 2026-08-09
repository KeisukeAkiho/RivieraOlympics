import Foundation

enum LasVegasCalculator {
    struct HoleTeams: Equatable {
        var teamA: [UUID]
        var teamB: [UUID]

        func side(of playerId: UUID) -> TeamSide? {
            if teamA.contains(playerId) { return .a }
            if teamB.contains(playerId) { return .b }
            return nil
        }
    }

    enum TeamSide {
        case a, b
    }

    /// Classic Las Vegas concat scores. Diff is from Team A perspective (positive = A collects).
    /// Teams change each hole from prior-hole ranking: 1st+4th vs 2nd+3rd (hole 1 uses option teams).
    static func holeDiffs(round: GolfRound) -> [Int] {
        guard round.options.lasVegasEnabled else { return [] }
        return round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }).map { hole in
            let teams = teams(forHole: hole.holeNumber, round: round)
            return holeDiff(hole: hole, teams: teams, rules: round.options.lasVegasRules)
        }
    }

    /// Per-hole team assignment for display / settlement.
    static func teamsByHole(round: GolfRound) -> [HoleTeams] {
        guard round.options.lasVegasEnabled else { return [] }
        return round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }).map {
            teams(forHole: $0.holeNumber, round: round)
        }
    }

    static func teams(forHole holeNumber: Int, round: GolfRound) -> HoleTeams {
        let rules = round.options.lasVegasRules
        if holeNumber <= 1 || !rules.rotatePairsByPreviousHoleScore {
            return startingTeams(round: round)
        }
        guard let prev = round.holes.first(where: { $0.holeNumber == holeNumber - 1 }) else {
            return startingTeams(round: round)
        }
        let ranked = rankedPlayerIds(hole: prev, players: round.players)
        guard ranked.count >= 4 else {
            return startingTeams(round: round)
        }
        // スコア順（良い→悪い）: 1位+4位 vs 2位+3位
        return HoleTeams(
            teamA: [ranked[0], ranked[3]],
            teamB: [ranked[1], ranked[2]]
        )
    }

    static func yenByPlayer(round: GolfRound) -> [UUID: Int] {
        guard round.options.lasVegasEnabled else { return [:] }
        let stake = round.options.stakeRate
        var map: [UUID: Int] = Dictionary(uniqueKeysWithValues: round.players.map { ($0.id, 0) })
        for hole in round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            let teams = teams(forHole: hole.holeNumber, round: round)
            let diff = holeDiff(hole: hole, teams: teams, rules: round.options.lasVegasRules)
            guard diff != 0, teams.teamA.count >= 1, teams.teamB.count >= 1 else { continue }
            let aShare = diff * stake / teams.teamA.count
            let bShare = diff * stake / teams.teamB.count
            for id in teams.teamA { map[id, default: 0] += aShare }
            for id in teams.teamB { map[id, default: 0] -= bShare }
        }
        return map
    }

    private static func startingTeams(round: GolfRound) -> HoleTeams {
        let a = round.options.lasVegasTeamA
        let b = round.options.lasVegasTeamB
        if a.count >= 2, b.count >= 2 {
            return HoleTeams(teamA: Array(a.prefix(2)), teamB: Array(b.prefix(2)))
        }
        let ids = round.players.map(\.id)
        guard ids.count >= 4 else {
            return HoleTeams(teamA: Array(ids.prefix(2)), teamB: Array(ids.dropFirst(2).prefix(2)))
        }
        return HoleTeams(teamA: [ids[0], ids[1]], teamB: [ids[2], ids[3]])
    }

    /// Lower strokes first; ties broken by roster order.
    private static func rankedPlayerIds(hole: HoleRecord, players: [Player]) -> [UUID] {
        let order = Dictionary(uniqueKeysWithValues: players.enumerated().map { ($0.element.id, $0.offset) })
        return hole.entries
            .filter { $0.strokes > 0 }
            .sorted { lhs, rhs in
                if lhs.strokes != rhs.strokes { return lhs.strokes < rhs.strokes }
                return (order[lhs.playerId] ?? 0) < (order[rhs.playerId] ?? 0)
            }
            .map(\.playerId)
    }

    private static func holeDiff(hole: HoleRecord, teams: HoleTeams, rules: LasVegasRules) -> Int {
        let a = Set(teams.teamA)
        let b = Set(teams.teamB)
        let aEntries = hole.entries.filter { a.contains($0.playerId) && $0.strokes > 0 }
        let bEntries = hole.entries.filter { b.contains($0.playerId) && $0.strokes > 0 }
        let aScores = aEntries.map(\.strokes).sorted()
        let bScores = bEntries.map(\.strokes).sorted()
        guard aScores.count >= 2, bScores.count >= 2 else { return 0 }

        var aCombo = combine(aScores[0], aScores[1])
        var bCombo = combine(bScores[0], bScores[1])
        var multiplier = 1

        let aBirdies = aEntries.filter { $0.strokes - hole.par <= -1 }.count
        let bBirdies = bEntries.filter { $0.strokes - hole.par <= -1 }.count
        let aEagles = aEntries.contains { $0.strokes - hole.par <= -2 }
        let bEagles = bEntries.contains { $0.strokes - hole.par <= -2 }

        // Priority: eagle → two birdies → birdie. Flip once per side; ×2 at most once.
        enum Special: Int { case none = 0, birdie = 1, twoBirdies = 2, eagle = 3 }
        var aSpecial: Special = .none
        var bSpecial: Special = .none

        if rules.eagleFlipAndDouble {
            if aEagles && !bEagles { aSpecial = .eagle }
            else if bEagles && !aEagles { bSpecial = .eagle }
        }
        if rules.twoBirdiesFlipAndDouble {
            if aSpecial == .none, aBirdies >= 2, bBirdies < 2 { aSpecial = .twoBirdies }
            if bSpecial == .none, bBirdies >= 2, aBirdies < 2 { bSpecial = .twoBirdies }
        }
        if rules.birdieFlip {
            if aSpecial == .none, aBirdies >= 1, bBirdies == 0 { aSpecial = .birdie }
            if bSpecial == .none, bBirdies >= 1, aBirdies == 0 { bSpecial = .birdie }
        }

        if aSpecial != .none {
            bCombo = flipDigits(bCombo)
            if aSpecial == .eagle || aSpecial == .twoBirdies { multiplier = 2 }
        } else if bSpecial != .none {
            aCombo = flipDigits(aCombo)
            if bSpecial == .eagle || bSpecial == .twoBirdies { multiplier = 2 }
        }

        return (aCombo - bCombo) * multiplier
    }

    private static func combine(_ low: Int, _ high: Int) -> Int {
        if high >= 10 { return low * 100 + high }
        return low * 10 + high
    }

    private static func flipDigits(_ n: Int) -> Int {
        let s = String(n)
        return Int(String(s.reversed())) ?? n
    }
}

enum HoleMatchCalculator {
    static func winnersByHole(round: GolfRound) -> [UUID?] {
        guard round.options.holeMatchEnabled else { return [] }
        return round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }).map { hole in
            let scored = hole.entries.filter { $0.strokes > 0 }
            guard let best = scored.map(\.strokes).min() else { return nil }
            let winners = scored.filter { $0.strokes == best }
            return winners.count == 1 ? winners[0].playerId : nil
        }
    }

    static func winsByPlayer(round: GolfRound) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        for w in winnersByHole(round: round) {
            guard let w else { continue }
            map[w, default: 0] += 1
        }
        return map
    }

    static func yenByPlayer(round: GolfRound) -> [UUID: Int] {
        let winners = winnersByHole(round: round)
        let stake = round.options.stakeRate
        var map: [UUID: Int] = Dictionary(uniqueKeysWithValues: round.players.map { ($0.id, 0) })
        let othersCount = max(0, round.players.count - 1)
        for w in winners {
            guard let winner = w else { continue }
            for p in round.players {
                if p.id == winner {
                    map[p.id, default: 0] += stake * othersCount
                } else {
                    map[p.id, default: 0] -= stake
                }
            }
        }
        return map
    }
}

/// 村長: each player ante `stakeRate`; worst (highest) gross takes the pot.
enum SonchoCalculator {
    static func grossByPlayer(round: GolfRound) -> [UUID: Int] {
        var map: [UUID: Int] = Dictionary(uniqueKeysWithValues: round.players.map { ($0.id, 0) })
        for hole in round.holes {
            for e in hole.entries where e.strokes > 0 {
                map[e.playerId, default: 0] += e.strokes
            }
        }
        return map
    }

    static func winnerIds(round: GolfRound) -> [UUID] {
        guard round.options.sonchoEnabled else { return [] }
        let gross = grossByPlayer(round: round)
        let completed = gross.filter { $0.value > 0 }
        guard let worst = completed.values.max() else { return [] }
        return completed.filter { $0.value == worst }.map(\.key)
    }

    static func yenByPlayer(round: GolfRound) -> [UUID: Int] {
        guard round.options.sonchoEnabled else { return [:] }
        let winners = winnerIds(round: round)
        guard !winners.isEmpty else { return [:] }
        let stake = round.options.stakeRate
        let n = round.players.count
        let pot = stake * n
        var map: [UUID: Int] = Dictionary(uniqueKeysWithValues: round.players.map { ($0.id, -stake) })
        let share = pot / winners.count
        var remainder = pot - share * winners.count
        for id in winners {
            map[id, default: 0] += share + (remainder > 0 ? 1 : 0)
            if remainder > 0 { remainder -= 1 }
        }
        return map
    }
}

/// 蛇: 3-putt transfers the snake; each transfer grows the pot by stake.
/// Settled at hole 9 & 18 (or 18 only). Holder pays; others split the pot.
enum SnakeCalculator {
    struct Run {
        var segments: [SnakeSegmentResult]
        var yen: [UUID: Int]
    }

    static func run(round: GolfRound) -> Run {
        guard round.options.snakeEnabled else {
            return Run(segments: [], yen: [:])
        }
        let stake = round.options.stakeRate
        var yen: [UUID: Int] = Dictionary(uniqueKeysWithValues: round.players.map { ($0.id, 0) })
        var segments: [SnakeSegmentResult] = []

        let settleHoles: [Int] = round.options.snakeSettlePerNine ? [9, 18] : [18]
        var holder: UUID? = nil
        var pot = 0
        var transfers = 0
        var segmentStart = 1

        let holes = round.holes.sorted(by: { $0.holeNumber < $1.holeNumber })
        for hole in holes {
            for entry in hole.entries where entry.putts >= 3 {
                holder = entry.playerId
                pot += stake
                transfers += 1
            }
            if settleHoles.contains(hole.holeNumber) {
                let label = "H\(segmentStart)–\(hole.holeNumber)"
                segments.append(SnakeSegmentResult(label: label, holderId: holder, pot: pot, transfers: transfers))
                if let holder, pot > 0 {
                    let others = round.players.filter { $0.id != holder }
                    if others.isEmpty {
                        yen[holder, default: 0] -= pot
                    } else {
                        yen[holder, default: 0] -= pot
                        let share = pot / others.count
                        var rem = pot - share * others.count
                        for o in others {
                            yen[o.id, default: 0] += share + (rem > 0 ? 1 : 0)
                            if rem > 0 { rem -= 1 }
                        }
                    }
                }
                holder = nil
                pot = 0
                transfers = 0
                segmentStart = hole.holeNumber + 1
            }
        }
        return Run(segments: segments, yen: yen)
    }

    /// Per-hole snake holder after processing that hole (nil if no holder yet in the open segment).
    static func holderByHole(round: GolfRound) -> [UUID?] {
        guard round.options.snakeEnabled else { return Array(repeating: nil, count: 18) }
        var out: [UUID?] = Array(repeating: nil, count: 18)
        let settleHoles = Set(round.options.snakeSettlePerNine ? [9, 18] : [18])
        var holder: UUID? = nil
        let holes = round.holes.sorted(by: { $0.holeNumber < $1.holeNumber })
        for hole in holes {
            for entry in hole.entries where entry.putts >= 3 {
                holder = entry.playerId
            }
            if hole.holeNumber >= 1 && hole.holeNumber <= 18 {
                out[hole.holeNumber - 1] = holder
            }
            if settleHoles.contains(hole.holeNumber) {
                holder = nil
            }
        }
        return out
    }
}

/// オネストジョン: declare gross before play.
/// Under declaration: +1 / stroke. Over: +2 / stroke. Exact = 0. Lower points win.
enum HonestJohnCalculator {
    static func results(round: GolfRound) -> [HonestJohnPlayerResult] {
        guard round.options.honestJohnEnabled else { return [] }
        let gross = SonchoCalculator.grossByPlayer(round: round)
        return round.players.map { p in
            let actual = gross[p.id, default: 0]
            let declared = p.honestJohnDeclared
            let points: Int
            if actual <= 0 {
                points = 0
            } else if actual <= declared {
                points = (declared - actual) * 1
            } else {
                points = (actual - declared) * 2
            }
            return HonestJohnPlayerResult(
                playerId: p.id,
                declared: declared,
                actual: actual,
                points: points
            )
        }.sorted { $0.points < $1.points }
    }

    /// Zero-sum: (averagePoints − myPoints) × stake.
    static func yenByPlayer(round: GolfRound) -> [UUID: Int] {
        let rows = results(round: round).filter { $0.actual > 0 }
        guard !rows.isEmpty else { return [:] }
        let avg = Double(rows.reduce(0) { $0 + $1.points }) / Double(rows.count)
        let stake = Double(round.options.stakeRate)
        var map: [UUID: Int] = [:]
        for r in rows {
            map[r.playerId] = Int(((avg - Double(r.points)) * stake).rounded())
        }
        // Fix rounding drift so sum ≈ 0
        let drift = map.values.reduce(0, +)
        if drift != 0, let first = rows.first?.playerId {
            map[first, default: 0] -= drift
        }
        return map
    }
}

enum SettlementEngine {
    static func summarize(_ round: GolfRound) -> SettlementSummary {
        let olympicHoles = OlympicsCalculator.scoreRound(round)
        var olympicTotals: [UUID: Int] = [:]
        for hole in olympicHoles {
            for p in hole.perPlayer {
                olympicTotals[p.playerId, default: 0] += p.totalPoints
            }
        }

        let lv = LasVegasCalculator.yenByPlayer(round: round)
        let hm = HoleMatchCalculator.yenByPlayer(round: round)
        let hmWins = HoleMatchCalculator.winsByPlayer(round: round)
        let soncho = SonchoCalculator.yenByPlayer(round: round)
        let sonchoWinners = Set(SonchoCalculator.winnerIds(round: round))
        let snake = SnakeCalculator.run(round: round)
        let hj = HonestJohnCalculator.results(round: round)
        let hjYen = HonestJohnCalculator.yenByPlayer(round: round)
        let gross = SonchoCalculator.grossByPlayer(round: round)
        let stake = round.options.stakeRate

        var notes: [String] = []
        if !round.options.penaltiesEnabled {
            notes.append("このラウンドはペナルティ無効です。")
        }
        if round.options.sonchoEnabled, !sonchoWinners.isEmpty {
            let names = round.players.filter { sonchoWinners.contains($0.id) }.map(\.name).joined(separator: ", ")
            notes.append("村長: \(names)")
        }

        let n = max(1, round.players.count)
        let sumOlympic = olympicTotals.values.reduce(0, +)

        let totals: [PlayerTotals] = round.players.map { player in
            let op = olympicTotals[player.id, default: 0]
            // 検算: (自分点×人数) − 全員合計 → 合計すると必ず0
            let olympicUnits = round.options.olympicsEnabled ? (op * n - sumOlympic) : 0
            let olympicYen = olympicUnits * stake
            let holeYen = hm[player.id, default: 0]
            let lvYen = lv[player.id, default: 0]
            let sonchoYen = soncho[player.id, default: 0]
            let snakeYen = snake.yen[player.id, default: 0]
            let hjPoints = hj.first(where: { $0.playerId == player.id })?.points ?? 0
            let honestYen = hjYen[player.id, default: 0]
            var net = olympicYen + holeYen + lvYen + sonchoYen + snakeYen + honestYen

            if round.options.settlementCap > 0 {
                let cap = round.options.settlementCap
                if net > cap {
                    notes.append("\(player.name) に上限適用: \(net) → \(cap)")
                    net = cap
                } else if net < -cap {
                    notes.append("\(player.name) に上限適用: \(net) → \(-cap)")
                    net = -cap
                }
            }

            return PlayerTotals(
                playerId: player.id,
                name: player.name,
                grossScore: gross[player.id, default: 0],
                olympicPoints: op,
                olympicUnits: olympicUnits,
                holeMatchWins: hmWins[player.id, default: 0],
                holeMatchYen: holeYen,
                lasVegasYen: lvYen,
                olympicYen: olympicYen,
                sonchoYen: sonchoYen,
                snakeYen: snakeYen,
                honestJohnPoints: hjPoints,
                honestJohnYen: honestYen,
                isSoncho: sonchoWinners.contains(player.id),
                netYen: net
            )
        }.sorted { $0.netYen > $1.netYen }

        return SettlementSummary(
            olympicByHole: olympicHoles,
            playerTotals: totals,
            lasVegasHoleDiffs: LasVegasCalculator.holeDiffs(round: round),
            holeMatchWinnersByHole: HoleMatchCalculator.winnersByHole(round: round),
            snakeSegments: snake.segments,
            sonchoWinnerIds: Array(sonchoWinners),
            honestJohn: hj,
            notes: notes
        )
    }
}
