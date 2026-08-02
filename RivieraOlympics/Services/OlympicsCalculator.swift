import Foundation

/// Riviera Club Olympics point engine (rules dated 2025-08-26).
enum OlympicsCalculator {

    static func scoreHole(
        hole: HoleRecord,
        players: [Player],
        penaltiesEnabled: Bool,
        nearestPinCarryIn: Int
    ) -> HoleOlympicsResult {
        var carry = max(0, nearestPinCarryIn)
        var results: [PlayerHoleOlympicsResult] = []

        let npHolder = hole.entries.first(where: { $0.nearestPinContender })
        let firemanEntry = hole.entries.first(where: { $0.fireman })

        // Fireman may extinguish NP and push carry to next hole.
        var npAwardedThisHole = false
        var firemanSucceeded = false
        if let np = npHolder, let fire = firemanEntry, fire.playerId != np.playerId {
            firemanSucceeded = firemanQualifies(fire: fire, np: np, par: hole.par)
            if firemanSucceeded {
                carry += 1
            }
        }

        if let np = npHolder, !firemanSucceeded {
            let scoreToPar = np.strokes - hole.par
            if np.strokes > 0 && (scoreToPar == 0 || scoreToPar == -1) {
                npAwardedThisHole = true
            } else if np.strokes > 0 {
                // Missed NP conversion → carry forward for next hole
                carry += 1
            }
        } else if npHolder == nil, firemanEntry == nil {
            // no change
        }

        for entry in hole.entries {
            let result = scorePlayer(
                entry: entry,
                hole: hole,
                penaltiesEnabled: penaltiesEnabled,
                nearestPinCarryIn: nearestPinCarryIn,
                awardNearestPin: npAwardedThisHole && entry.playerId == npHolder?.playerId,
                awardFireman: firemanSucceeded && entry.playerId == firemanEntry?.playerId,
                outerPinForce: hole.entries.contains(where: { $0.outerPinDeclared })
            )
            results.append(result)
        }

        // If NP awarded, carry resets relative to award (carry used for multiplier, then may grow from fireman).
        let carryOut: Int
        if npAwardedThisHole {
            carryOut = firemanSucceeded ? max(1, carry) : 0
        } else if firemanSucceeded {
            carryOut = max(1, carry)
        } else if npHolder != nil {
            carryOut = max(1, nearestPinCarryIn + 1)
        } else {
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
                nearestPinCarryIn: carry
            )
            carry = result.nearestPinCarryOut
            out.append(result)
        }

        // Yakitori / Reach obligation applied per nine
        return applyNineHoleObligations(round: round, holeResults: out)
    }

    // MARK: - Private

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
        outerPinForce: Bool
    ) -> PlayerHoleOlympicsResult {
        var preReach: [PointLine] = []
        var always: [PointLine] = []

        let toPar = entry.strokes > 0 ? entry.strokes - hole.par : 0

        // Medal / diamond
        if let medal = entry.medal {
            preReach.append(PointLine(code: "medal", label: medal.label, points: medal.points))
        } else if entry.chipInFromOffGreen {
            preReach.append(PointLine(code: "diamond", label: "ダイヤ", points: OlympicMedal.diamond.points))
        }

        // Pin
        let pinActive = entry.declaredPin || (outerPinForce && !entry.outerPinDeclared)
        if pinActive || entry.outerPinDeclared {
            if entry.outerPinDeclared {
                if entry.chipInFromOffGreen || entry.strokesOnGreenAfterApproach == 0 && entry.strokes > 0 && entry.putts == 0 {
                    preReach.append(PointLine(code: "outer_pin", label: "外竿チップイン", points: 2))
                } else if entry.strokesOnGreenAfterApproach >= 2 {
                    if penaltiesEnabled {
                        always.append(PointLine(code: "outer_pin_miss", label: "外竿外れ（2打目）", points: -2))
                    }
                }
                // miss first putt/green stroke → 0 (no line)
            } else if entry.declaredPin || pinActive {
                if entry.pinDistanceQualified && entry.putts <= 1 && entry.strokes > 0 {
                    preReach.append(PointLine(code: "pin", label: "竿", points: 2))
                }
                if entry.declaredPin && entry.pinDistanceQualified && entry.putts >= 3, penaltiesEnabled {
                    always.append(PointLine(code: "pin_3putt", label: "竿後3パット", points: -2))
                }
            }
        }

        if entry.banker {
            preReach.append(PointLine(code: "banker", label: "砂", points: 2))
        }

        if entry.strokes > 0 {
            if toPar == -1 {
                preReach.append(PointLine(code: "birdie", label: "バーディー", points: 3))
            } else if toPar == -2 {
                preReach.append(PointLine(code: "eagle", label: "イーグル", points: 10))
            } else if toPar <= -3 {
                preReach.append(PointLine(code: "albatross", label: "アルバトロス以上", points: 10))
            }
            if entry.strokes == 1 {
                preReach.append(PointLine(code: "hio", label: "ホールインワン", points: 100))
            }
        }

        if entry.parOn {
            preReach.append(PointLine(code: "par_on", label: "パーオン", points: 1))
        }
        if entry.birdieOn {
            preReach.append(PointLine(code: "birdie_on", label: "バーディーオン", points: 3))
        }

        if penaltiesEnabled {
            if entry.putts == 3 {
                always.append(PointLine(code: "3putt", label: "3パット", points: -1))
            } else if entry.putts > 3 {
                // -1 for 3-putt, then -1 per additional putt
                let extra = entry.putts - 3
                always.append(PointLine(code: "3putt", label: "3パット", points: -1))
                always.append(PointLine(code: "over3putt", label: "オーバー3パット", points: -extra))
            }
            if entry.nameLick {
                always.append(PointLine(code: "name", label: "舐め", points: -1))
            }
            if entry.awaya {
                // Awaya is listed as reach-excluded negative in special rules
                always.append(PointLine(code: "awaya", label: "あわや", points: -1))
            }
        }

        // Nearest pin: 3 × carryover (carry-in + 1 if first), Reach excluded
        if awardNearestPin {
            let mult = max(1, nearestPinCarryIn + 1)
            always.append(PointLine(code: "np", label: "ニアピン ×\(mult)", points: 3 * mult))
        }
        // Fireman: 1 × carryover, Reach excluded
        if awardFireman {
            let mult = max(1, nearestPinCarryIn + 1)
            always.append(PointLine(code: "fireman", label: "消防隊 ×\(mult)", points: 1 * mult))
        }

        // Reach doubles eligible pre-reach lines; miss → −2× base (default 2pt putt → −4).
        // NP / Fireman / Awaya / outer-pin miss stay outside Reach (in `always`).
        var lines: [PointLine] = []
        var reachApplied = false
        let reachBase = preReach.reduce(0) { $0 + $1.points }
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
                let missPoints = reachBase == 0 ? -4 : -(abs(reachBase) * 2)
                lines.append(PointLine(
                    code: "reach_miss",
                    label: reachBase == 0 ? "リーチ外れ（既定2点×2）" : "リーチ外れ",
                    points: missPoints,
                    multipliedByReach: true
                ))
            } else {
                lines.append(contentsOf: preReach)
            }
        } else {
            lines.append(contentsOf: preReach)
        }

        lines.append(contentsOf: always)

        let total = lines.reduce(0) { $0 + $1.points }
        return PlayerHoleOlympicsResult(
            playerId: entry.playerId,
            lines: lines,
            rawPoints: reachBase,
            reachApplied: reachApplied,
            totalPoints: total
        )
    }

    /// Reach is considered made if the player holed out without an extra miss after declare.
    /// Convention: chip-in / 0 putts → made; otherwise made when putts == 1 and no name-only miss without holing.
    /// Miss when putts >= 2 after a reach declare on a putt, or strokes==0 (incomplete).
    private static func resolveReachMade(_ entry: PlayerHoleEntry) -> Bool {
        guard entry.declaredReach, entry.strokes > 0 else { return false }
        if entry.chipInFromOffGreen || entry.putts == 0 { return true }
        // Single putt that drops → made
        if entry.putts == 1 { return true }
        return false
    }

    private static func applyNineHoleObligations(
        round: GolfRound,
        holeResults: [HoleOlympicsResult]
    ) -> [HoleOlympicsResult] {
        var mutable = holeResults
        let penalties = round.options.penaltiesEnabled

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
                    // Forced reach on final hole first putt / chip-in: 5×2=10 if made, else −10
                    if let e = entries.last, e.strokes > 0 {
                        let forcedMade = e.chipInFromOffGreen || e.putts <= 1
                        let pts = forcedMade ? 10 : (penalties ? -10 : 0)
                        if pts != 0 {
                            per.lines.append(PointLine(
                                code: "reach_obligation",
                                label: forcedMade ? "強制リーチ（成功）5×2" : "強制リーチ（失敗）5×2",
                                points: pts,
                                multipliedByReach: true
                            ))
                            per.totalPoints += pts
                            per.reachApplied = true
                        }
                    }
                }

                if !hasOnePutt && penalties {
                    per.lines.append(PointLine(code: "yakitori", label: "焼き鳥（1パットなし）", points: -5))
                    per.totalPoints -= 5
                }

                if let pidx = mutable[idx].perPlayer.firstIndex(where: { $0.playerId == player.id }) {
                    mutable[idx].perPlayer[pidx] = per
                }
            }
        }
        return mutable
    }

}
