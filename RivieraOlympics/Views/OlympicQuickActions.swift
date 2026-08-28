import SwiftUI

/// Score-sheet buttons that record Olympics history (separate from stroke score).
enum OlympicQuickAction: String, CaseIterable, Identifiable {
    case reach
    case nameLick
    case awaya
    case pin
    case pinFail
    case banker
    case nearestPin
    case fireman
    case parOn
    case birdieOn
    case gold
    case silver
    case bronze
    case iron
    case diamond
    case chipIn
    case threePutt

    var id: String { rawValue }

    var code: String { rawValue }

    var historyLabel: String {
        switch self {
        case .reach: return "リーチ宣言"
        case .nameLick: return "舐め"
        case .awaya: return "あわや"
        case .pin: return "竿"
        case .pinFail: return "竿失敗"
        case .threePutt: return "3パット"
        case .banker: return "砂"
        case .nearestPin: return "ニアピン権利"
        case .fireman: return "消防隊"
        case .parOn: return "パーオン"
        case .birdieOn: return "バーディーオン"
        case .gold: return "金メダル"
        case .silver: return "銀メダル"
        case .bronze: return "銅メダル"
        case .iron: return "鉄メダル"
        case .diamond: return "ダイヤ"
        case .chipIn: return "外チップ"
        }
    }

    var icon: String {
        switch self {
        case .reach: return "bolt.fill"
        case .nameLick: return "drop.fill"
        case .awaya: return "leaf.fill"
        case .pin: return "ruler"
        case .pinFail: return "ruler.fill"
        case .threePutt: return "3.circle.fill"
        case .banker: return "beach.umbrella.fill"
        case .nearestPin: return "scope"
        case .fireman: return "flame.fill"
        case .parOn: return "p.circle"
        case .birdieOn: return "b.circle"
        case .gold, .silver, .bronze: return "medal.fill"
        case .iron: return "circle.grid.cross"
        case .diamond: return "diamond.fill"
        case .chipIn: return "arrow.down.right.circle"
        }
    }

    var isPenalty: Bool {
        self == .nameLick || self == .awaya || self == .threePutt || self == .pinFail
    }

    var isExclusiveMedal: Bool {
        switch self {
        case .gold, .silver, .bronze, .iron: return true
        default: return false
        }
    }

    var medal: OlympicMedal? {
        switch self {
        case .gold: return .gold
        case .silver: return .silver
        case .bronze: return .bronze
        case .iron: return .iron
        case .diamond: return .diamond
        default: return nil
        }
    }

    static let primary: [OlympicQuickAction] = [
        .reach, .nameLick, .awaya, .threePutt, .pin, .pinFail, .banker, .nearestPin
    ]

    static let extra: [OlympicQuickAction] = [
        .diamond, .parOn, .birdieOn, .fireman, .chipIn
    ]

    func title(pts: OlympicsPointRules, carryIn: Int) -> String {
        switch self {
        case .reach: return "リーチ×2"
        case .nameLick: return "舐め \(pts.nameLick)"
        case .awaya: return "あわや \(pts.awaya)"
        case .pin: return "竿 +\(pts.pin)"
        case .pinFail: return "竿失敗 \(pts.pinThreePutt)"
        case .threePutt: return "3パット \(pts.threePutt)"
        case .banker: return "砂 +\(pts.banker)"
        case .nearestPin:
            let n = OlympicsCalculator.nearestPinPoints(carryIn: carryIn, base: pts.nearestPinBase)
            return "ニアピン +\(n)"
        case .fireman:
            let n = OlympicsCalculator.firemanPoints(carryIn: carryIn, base: pts.firemanBase)
            return "消防隊 +\(n)"
        case .parOn: return "パーオン +\(pts.parOn)"
        case .birdieOn: return "Bオン +\(pts.birdieOn)"
        case .gold: return "金 +\(pts.gold)"
        case .silver: return "銀 +\(pts.silver)"
        case .bronze: return "銅 +\(pts.bronze)"
        case .iron: return "鉄 +\(pts.iron)"
        case .diamond: return "◆ +\(pts.diamond)"
        case .chipIn: return "外チップ"
        }
    }

    func tint() -> Color {
        if self == .reach { return .purple }
        if self == .awaya { return .orange }
        if isPenalty { return RivieraTheme.flag }
        return RivieraTheme.fairway
    }

    func isOn(_ entry: PlayerHoleEntry) -> Bool {
        switch self {
        case .reach: return entry.declaredReach
        case .nameLick: return entry.nameLick
        case .awaya: return entry.awaya
        case .pin: return entry.declaredPin || entry.outerPinDeclared
        case .pinFail: return entry.pinFailed
        case .threePutt: return entry.markedThreePutt
        case .banker: return entry.banker
        case .nearestPin: return entry.nearestPinContender
        case .fireman: return entry.fireman
        case .parOn: return entry.parOn
        case .birdieOn: return entry.birdieOn
        case .gold: return entry.medal == .gold
        case .silver: return entry.medal == .silver
        case .bronze: return entry.medal == .bronze
        case .iron: return entry.medal == .iron
        case .diamond: return entry.medal == .diamond
        case .chipIn: return entry.chipInFromOffGreen
        }
    }

    func apply(to entry: inout PlayerHoleEntry, on: Bool, points: OlympicsPointRules) {
        switch self {
        case .reach:
            entry.declaredReach = on
        case .nameLick:
            entry.nameLick = on
        case .awaya:
            entry.awaya = on
        case .pin:
            entry.declaredPin = on
            entry.outerPinDeclared = false
            entry.pinDistanceQualified = on
            entry.pinPointsOverride = on ? (entry.pinPointsOverride ?? points.pin) : nil
        case .pinFail:
            entry.pinFailed = on
        case .threePutt:
            entry.markedThreePutt = on
        case .banker:
            entry.banker = on
            entry.bankerPointsOverride = on ? (entry.bankerPointsOverride ?? points.banker) : nil
        case .nearestPin:
            entry.nearestPinContender = on
        case .fireman:
            entry.fireman = on
        case .parOn:
            entry.parOn = on
            entry.parOnPointsOverride = on ? (entry.parOnPointsOverride ?? points.parOn) : nil
        case .birdieOn:
            entry.birdieOn = on
            entry.birdieOnPointsOverride = on ? (entry.birdieOnPointsOverride ?? points.birdieOn) : nil
        case .gold, .silver, .bronze, .iron, .diamond:
            if on, let medal {
                entry.medal = medal
                entry.chipInFromOffGreen = medal == .diamond
            } else if entry.medal == medal {
                entry.medal = nil
                if medal == .diamond { entry.chipInFromOffGreen = false }
            }
        case .chipIn:
            entry.chipInFromOffGreen = on
            if on { entry.medal = .diamond }
            if !on && entry.medal == .diamond { entry.medal = nil }
        }
    }
}
