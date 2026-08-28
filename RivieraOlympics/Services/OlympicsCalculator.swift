import Foundation

/// Riviera Club Olympics point engine (rules dated 2025-08-26).
enum OlympicsCalculator {

    static func scoreHole(
        hole: HoleRecord,
        players: [Player],
        penaltiesEnabled: Bool,
        nearestPinCarryIn: Int,
        points: OlympicsPointRules = .rivieraDefault,
        customRules: [CustomPointRule] = []
    ) -> HoleOlympicsResult {
        var results: [PlayerHoleOlympicsResult] = []

        let npHolder = hole.entries.first(where: { $0.nearestPinContender })
        let firemanEntry = hole.entries.first(where: { $0.fireman })

        // Fireman may extinguish NP and push carry to next hole.
        var npAwardedThisHole = false
        var firemanSucceeded = false
        if let np = npHolder, let fire = firemanEntry, fire.playerId != np.playerId {
            firemanSucceeded = firemanQualifies(fire: fire, np: np, par: hole.par)
        }

        if let np = npHolder, !firemanSucceeded {
            let scoreToPar = np.strokes - hole.par
            if np.strokes > 0 && (scoreToPar == 0 || scoreToPar == -1) {
                npAwardedThisHole = true
            }
        }

        for entry in hole.entries {
            let result = scorePlayer(
                entry: entry,
                hole: hole,
                penaltiesEnabled: penaltiesEnabled,
                nearestPinCarryIn: nearestPinCarryIn,
                awardNearestPin: npAwardedThisHole && entry.playerId == npHolder?.playerId,
                awardFireman: firemanSucceeded && entry.playerId == firemanEntry?.playerId,
                points: points,
                customRules: customRules
            )
            results.append(result)
        }

        // If NP awarded, carry resets. Incomplete NP (no strokes yet) does not bump carry.
        let carryOut: Int
        if npAwardedThisHole {
            carryOut = 0
        } else if firemanSucceeded {
            // 消火成功 → 権利は次へ繰越（いまの階建て分を持ち越し）
            carryOut = max(1, nearestPinCarryIn + 1)
        } else if let np = npHolder, np.strokes > 0 {
            // 成立せず（ボギー以上など）→ 1階積み増しして繰越
            carryOut = max(1, nearestPinCarryIn + 1)
        } else {
            // 権利未確定（スコア未入力）→ キャリー据え置き
            carryOut = nearestPinCarryIn
        }

        return HoleOlympicsResult(
            holeNumber: hole.holeNumber,
            nearestPinCarryOut: carryOut,
            perPlayer: results
        )
    }

    static func scoreRound(_ round: GolfRound) -> [HoleOlympicsResult] {
        guard round.options.olympicsEnabled else { return [] }
        var carry = 0
        var out: [HoleOlympicsResult] = []
        for hole in round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            let result = scoreHole(
                hole: hole,
                players: round.players,
                penaltiesEnabled: round.options.penaltiesEnabled,
                nearestPinCarryIn: carry,
                points: round.options.olympicsPoints,
                customRules: round.options.customPointRules
            )
            carry = result.nearestPinCarryOut
            out.append(result)
        }

        // Yakitori / Reach obligation applied per nine
        return applyNineHoleObligations(round: round, holeResults: out)
    }

    // MARK: - Private

    // MARK: - Nearest pin / Fireman floors

    /// 階建て（1 = キャリーなし、2 = 2階建て…）
    static func nearestPinFloor(carryIn: Int) -> Int {
        max(1, carryIn + 1)
    }

    /// ニアピン: base × 階建て
    static func nearestPinPoints(carryIn: Int, base: Int = OlympicsPointRules.rivieraDefault.nearestPinBase) -> Int {
        base * nearestPinFloor(carryIn: carryIn)
    }

    /// 消防隊: base × 階建て
    static func firemanPoints(carryIn: Int, base: Int = OlympicsPointRules.rivieraDefault.firemanBase) -> Int {
        base * nearestPinFloor(carryIn: carryIn)
    }

    /// 指定ホール時点のキャリーイン（前ホールまでの繰越）
    static func carryIn(forHole holeNumber: Int, round: GolfRound) -> Int {
        var carry = 0
        for hole in round.holes.sorted(by: { $0.holeNumber < $1.holeNumber }) {
            if hole.holeNumber >= holeNumber { return carry }
            let result = scoreHole(
                hole: hole,
                players: round.players,
                penaltiesEnabled: round.options.penaltiesEnabled,
                nearestPinCarryIn: carry,
                points: round.options.olympicsPoints,
                customRules: round.options.customPointRules
            )
            carry = result.nearestPinCarryOut
        }
        return carry
    }

    private static func firemanQualifies(fire: PlayerHoleEntry, np: PlayerHoleEntry, par: Int) -> Bool {
        guard fire.strokes > 0, np.strokes > 0 else { return false }
        let fireToPar = fire.strokes - par
        let npToPar = np.strokes - par

        // NP holder birdie → fireman never succeeds
        if npToPar == -1 { return false }

        // Cond 1: fire off green, fire par/birdie, NP par
        if !fire.greenInRegulationTee && (fireToPar == 0 || fireToPar == -1) && npToPar == 0 {
            return true
        }
        // Cond 2: fire on green, fire birdie, NP par
        if fire.greenInRegulationTee && fireToPar == -1 && npToPar == 0 {
            return true
        }
        // Cond 3: fire off green birdie from off-green, NP would be birdie — but NP birdie blocks above.
        // Extra 2025-08-26: extinguish with birdie from off green when NP is par.
        if !fire.greenInRegulationTee && fireToPar == -1 && npToPar == 0 {
            return true
        }
        return false
    }

    private static func scorePlayer(
        entry: PlayerHoleEntry,
        hole: HoleRecord,
        penaltiesEnabled: Bool,
        nearestPinCarryIn: Int,
        awardNearestPin: Bool,
        awardFireman: Bool,
        points: OlympicsPointRules,
        customRules: [CustomPointRule]
    ) -> PlayerHoleOlympicsResult {
        var preReach: [PointLine] = []
        var always: [PointLine] = []

        let toPar = entry.strokes > 0 ? entry.strokes - hole.par : 0

        if let medal = entry.medal, medal == .diamond {
            preReach.append(PointLine(code: "diamond", label: "ダイヤ", points: points.diamond))
        } else if entry.chipInFromOffGreen {
            preReach.append(PointLine(code: "diamond", label: "ダイヤ", points: points.diamond))
        }

        if entry.declaredPin || entry.outerPinDeclared {
            let pts = entry.pinPointsOverride ?? points.pin
            preReach.append(PointLine(code: "pin", label: "竿", points: pts))
        }

        if entry.banker {
            let qualifies = entry.strokes == 0 || entry.chipInFromOffGreen || entry.putts == 1
            if qualifies {
                let pts = entry.bankerPointsOverride ?? points.banker
                preReach.append(PointLine(code: "banker", label: "砂", points: pts))
            }
        }

        if entry.strokes > 0 {
            if toPar == -1 {
                preReach.append(PointLine(code: "birdie", label: "バーディー", points: points.birdie))
            } else if toPar == -2 {
                preReach.append(PointLine(code: "eagle", label: "イーグル", points: points.eagle))
            } else if toPar <= -3 {
                preReach.append(PointLine(code: "albatross", label: "アルバトロス以上", points: points.albatross))
            }
            if entry.strokes == 1 {
                preReach.append(PointLine(code: "hio", label: "ホールインワン", points: points.holeInOne))
            }
        }

        if entry.parOn {
            let pts = entry.parOnPointsOverride ?? points.parOn
            preReach.append(PointLine(code: "par_on", label: "パーオン", points: pts))
        }
        if entry.birdieOn {
            let pts = entry.birdieOnPointsOverride ?? points.birdieOn
            preReach.append(PointLine(code: "birdie_on", label: "バーディーオン", points: pts))
        }

        for rule in customRules where rule.enabled && entry.customActiveRuleIds.contains(rule.id) {
            let line = PointLine(code: "custom_\(rule.id.uuidString.prefix(8))", label: rule.name, points: rule.points)
            if rule.appliesReach {
                preReach.append(line)
            } else {
                always.append(line)
            }
        }

        if penaltiesEnabled {
            let pinFailed = entry.pinFailed
                || ((entry.declaredPin || entry.outerPinDeclared) && entry.putts >= 3)
            if pinFailed {
                preReach.append(PointLine(code: "pin_fail", label: "竿失敗", points: points.pinThreePutt))
            }

            let threePuttMarked = entry.markedThreePutt || entry.putts >= 3
            if !pinFailed, threePuttMarked {
                if entry.putts > 3 {
                    let extra = entry.putts - 3
                    preReach.append(PointLine(code: "3putt", label: "3パット", points: points.threePutt))
                    preReach.append(PointLine(code: "over3putt", label: "オーバー3パット", points: points.overThreePuttPerExtra * extra))
                } else {
                    preReach.append(PointLine(code: "3putt", label: "3パット", points: points.threePutt))
                }
            }
            if entry.nameLick {
                preReach.append(PointLine(code: "name", label: "舐め", points: points.nameLick))
            }
        }

        if penaltiesEnabled, entry.awaya {
            always.append(PointLine(code: "awaya", label: "あわや", points: points.awaya))
        }

        if awardNearestPin {
            let floor = nearestPinFloor(carryIn: nearestPinCarryIn)
            let pts = nearestPinPoints(carryIn: nearestPinCarryIn, base: points.nearestPinBase)
            always.append(PointLine(
                code: "np",
                label: floor == 1 ? "ニアピン" : "ニアピン（\(floor)階建て）",
                points: pts
            ))
        }
        if awardFireman {
            let floor = nearestPinFloor(carryIn: nearestPinCarryIn)
            let pts = firemanPoints(carryIn: nearestPinCarryIn, base: points.firemanBase)
            always.append(PointLine(
                code: "fireman",
                label: floor == 1 ? "消防隊" : "消防隊（\(floor)階建て）",
                points: pts
            ))
        }

        var lines: [PointLine] = []
        var reachApplied = false
        let reachBase = preReach.reduce(0) { $0 + $1.points }
        let positiveBase = preReach.filter { $0.points > 0 }.reduce(0) { $0 + $1.points }
        let reachMade = resolveReachMade(entry)

        if entry.declaredReach {
            reachApplied = true
            if reachMade {
                for var line in preReach {
                    line.points *= 2
                    line.multipliedByReach = true
                    line.label += "（リーチ×2）"
                    lines.append(line)
                }
            } else if penaltiesEnabled {
                let baseForMiss = positiveBase > 0 ? positiveBase : points.reachMissDefaultBase
                let missPoints = -(abs(baseForMiss) * 2)
                lines.append(PointLine(
                    code: "reach_miss",
                    label: positiveBase > 0 ? "リーチ外れ（加点の−2倍）" : "リーチ外れ（既定\(points.reachMissDefaultBase)点×2）",
                    points: missPoints,
                    multipliedByReach: true
                ))
                for var line in preReach where line.points < 0 {
                    line.points *= 2
                    line.multipliedByReach = true
                    line.label += "（リーチ×2）"
                    lines.append(line)
                }
            } else {
                lines.append(contentsOf: preReach)
            }
        } else {
            lines.append(contentsOf: preReach)
        }

        lines.append(contentsOf: always)

        if entry.manualPointAdjust != 0 {
            lines.append(PointLine(code: "manual", label: "手動調整", points: entry.manualPointAdjust))
        }

        let total = lines.reduce(0) { $0 + $1.points }
        return PlayerHoleOlympicsResult(
            playerId: entry.playerId,
            lines: lines,
            rawPoints: reachBase,
            reachApplied: reachApplied,
            totalPoints: total
        )
    }

    /// リーチ成功: パット1／未入力(見込み)／外チップ。パット2以上のみ外れ。
    /// ※パット数そのものを点数には加えない
    private static func resolveReachMade(_ entry: PlayerHoleEntry) -> Bool {
        guard entry.declaredReach else { return false }
        if entry.chipInFromOffGreen { return true }
        if entry.putts <= 1 { return true }
        return false
    }

    private static func applyNineHoleObligations(
        round: GolfRound,
        holeResults: [HoleOlympicsResult]
    ) -> [HoleOlympicsResult] {
        var mutable = holeResults
        let penalties = round.options.penaltiesEnabled
        let pts = round.options.olympicsPoints

        for nine in 0..<2 {
            let range = (nine * 9 + 1)...(nine * 9 + 9)
            let lastHole = nine * 9 + 9

            for player in round.players {
                let playerHoles = round.holes.filter { range.contains($0.holeNumber) }
                let entries = playerHoles.compactMap { h in h.entries.first(where: { $0.playerId == player.id }) }

                let hasReach = entries.contains(where: { $0.declaredReach })
                let hasOnePutt = entries.contains(where: { $0.putts == 1 || ($0.putts == 0 && $0.strokes > 0 && $0.chipInFromOffGreen) || ($0.putts == 0 && $0.strokes == 1) })

                guard let idx = mutable.firstIndex(where: { $0.holeNumber == lastHole }) else { continue }
                guard var per = mutable[idx].perPlayer.first(where: { $0.playerId == player.id }) else { continue }

                if !hasReach {
                    if let e = entries.last, e.strokes > 0 {
                        let forcedMade = e.chipInFromOffGreen || e.putts == 1 || (e.putts == 0 && (e.chipInFromOffGreen || e.strokes == 1))
                        let value = forcedMade ? pts.forcedReachSuccess : (penalties ? pts.forcedReachFail : 0)
                        if value != 0 {
                            per.lines.append(PointLine(
                                code: "reach_obligation",
                                label: forcedMade ? "強制リーチ（成功）" : "強制リーチ（失敗）",
                                points: value,
                                multipliedByReach: true
                            ))
                            per.totalPoints += value
                            per.reachApplied = true
                        }
                    }
                }

                let played = entries.contains(where: { $0.strokes > 0 })
                if played && !hasOnePutt && penalties {
                    per.lines.append(PointLine(code: "yakitori", label: "焼き鳥（1パットなし）", points: pts.yakitori))
                    per.totalPoints += pts.yakitori
                }

                if let pidx = mutable[idx].perPlayer.firstIndex(where: { $0.playerId == player.id }) {
                    mutable[idx].perPlayer[pidx] = per
                }
            }
        }
        return mutable
    }

}
