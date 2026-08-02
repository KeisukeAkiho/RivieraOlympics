import Foundation

enum LasVegasCalculator {
    /// Classic Las Vegas: each hole concatenate team scores (lower first). Diff × stake.
    /// Returns per-hole signed diffs from Team A perspective (positive = A collects).
    static func holeDiffs(round: GolfRound) -> [Int] {
        guard round.options.lasVegasEnabled else { return [] }
        let a = Set(round.options.lasVegasTeamA)
        let b = Set(round.options.lasVegasTeamB)
        guard a.count >= 1, b.count >= 1 else { return [] }

        return round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }).map { hole in
            let aScores = hole.entries.filter { a.contains($0.playerId) && $0.strokes > 0 }.map(\.strokes).sorted()
            let bScores = hole.entries.filter { b.contains($0.playerId) && $0.strokes > 0 }.map(\.strokes).sorted()
            guard aScores.count >= 2, bScores.count >= 2 else { return 0 }
            let aCombo = combine(aScores[0], aScores[1])
            let bCombo = combine(bScores[0], bScores[1])
            return aCombo - bCombo
        }
    }

    static func yenByPlayer(round: GolfRound) -> [UUID: Int] {
        let diffs = holeDiffs(round: round)
        let totalDiff = diffs.reduce(0, +)
        let stake = round.options.stakeRate
        var map: [UUID: Int] = [:]
        for id in round.options.lasVegasTeamA { map[id, default: 0] += totalDiff * stake / max(1, round.options.lasVegasTeamA.count) }
        for id in round.options.lasVegasTeamB { map[id, default: 0] -= totalDiff * stake / max(1, round.options.lasVegasTeamB.count) }
        return map
    }

    private static func combine(_ low: Int, _ high: Int) -> Int {
        if high >= 10 { return low * 100 + high }
        return low * 10 + high
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
