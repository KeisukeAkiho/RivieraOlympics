import Foundation

enum OlympicsStatus {
    struct NineStatus: Equatable {
        var nineLabel: String
        var reachDeclared: Bool
        var reachForcedSoon: Bool
        var hasOnePutt: Bool
        var remainingHolesWithoutReach: Int

        var reachText: String {
            if reachDeclared { return "リーチ済" }
            if reachForcedSoon { return "最終ホールで強制リーチ" }
            return "リーチ未宣言（残り\(max(1, remainingHolesWithoutReach))H）"
        }

        var yakitoriText: String {
            hasOnePutt ? "焼き鳥解消（1パットあり）" : "焼き鳥危険（1パットなし）"
        }

        var reachOK: Bool { reachDeclared }
        var yakitoriOK: Bool { hasOnePutt }
    }

    static func nine(for holeNumber: Int) -> Range<Int> {
        holeNumber <= 9 ? 1..<10 : 10..<19
    }

    static func status(round: GolfRound, playerId: UUID, holeNumber: Int) -> NineStatus {
        let range = nine(for: holeNumber)
        let last = range.upperBound - 1
        let holes = round.holes.filter { range.contains($0.holeNumber) }
        let entries = holes.compactMap { $0.entries.first(where: { $0.playerId == playerId }) }

        let reachDeclared = entries.contains(where: \.declaredReach)
        let hasOnePutt = entries.contains { e in
            e.putts == 1 || (e.putts == 0 && e.strokes > 0 && (e.chipInFromOffGreen || e.strokes == 1))
        }
        let remaining = max(0, last - holeNumber + (reachDeclared ? 0 : 1))
        // holes left in nine including current if no reach yet
        let remainingWithoutReach: Int = {
            guard !reachDeclared else { return 0 }
            return holes.filter { $0.holeNumber >= holeNumber }.count
        }()

        return NineStatus(
            nineLabel: holeNumber <= 9 ? "前半9" : "後半9",
            reachDeclared: reachDeclared,
            reachForcedSoon: !reachDeclared && holeNumber == last,
            hasOnePutt: hasOnePutt,
            remainingHolesWithoutReach: remainingWithoutReach
        )
    }

    /// 下書きエントリを差し込んだホールの速報点
    static func previewPoints(round: GolfRound, holeNumber: Int, draft: PlayerHoleEntry) -> (total: Int, lines: [PointLine], reachApplied: Bool) {
        let result = previewHole(round: round, holeNumber: holeNumber, drafts: [draft.playerId: draft])
        guard let mine = result.perPlayer.first(where: { $0.playerId == draft.playerId }) else {
            return (0, [], false)
        }
        return (mine.totalPoints, mine.lines, mine.reachApplied)
    }

    static func previewHole(
        round: GolfRound,
        holeNumber: Int,
        drafts: [UUID: PlayerHoleEntry]
    ) -> HoleOlympicsResult {
        guard var hole = round.holes.first(where: { $0.holeNumber == holeNumber }) else {
            return HoleOlympicsResult(holeNumber: holeNumber, nearestPinCarryOut: 0, perPlayer: [])
        }
        for (playerId, draft) in drafts {
            var saved = draft
            saved.playerId = playerId
            if let idx = hole.entries.firstIndex(where: { $0.playerId == playerId }) {
                saved.id = hole.entries[idx].id
                hole.entries[idx] = saved
            } else {
                hole.entries.append(saved)
            }
        }
        return OlympicsCalculator.scoreHole(
            hole: hole,
            players: round.players,
            penaltiesEnabled: round.options.penaltiesEnabled,
            nearestPinCarryIn: OlympicsCalculator.carryIn(forHole: holeNumber, round: round),
            points: round.options.olympicsPoints,
            customRules: round.options.customPointRules
        )
    }
}
