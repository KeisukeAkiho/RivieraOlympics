import Foundation

enum OlympicMedal: String, Codable, CaseIterable, Identifiable {
    case gold, silver, bronze, iron, diamond

    var id: String { rawValue }

    var points: Int {
        switch self {
        case .gold: return 4
        case .silver: return 3
        case .bronze: return 2
        case .iron: return 1
        case .diamond: return 5
        }
    }

    var label: String {
        switch self {
        case .gold: return "金"
        case .silver: return "銀"
        case .bronze: return "銅"
        case .iron: return "鉄"
        case .diamond: return "ダイヤ"
        }
    }
}

/// マスター登録プレイヤー（生涯戦績のキー）
struct RegisteredPlayer: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var homeCourse: String = ""
    var homeTee: String = ""
    var handicap: String = ""
    var note: String = ""
    var defaultHonestJohn: Int = 90
    var createdAt: Date = Date()
}

extension RegisteredPlayer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, homeCourse, homeTee, handicap, note, defaultHonestJohn, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        homeCourse = try c.decodeIfPresent(String.self, forKey: .homeCourse) ?? ""
        homeTee = try c.decodeIfPresent(String.self, forKey: .homeTee) ?? ""
        handicap = try c.decodeIfPresent(String.self, forKey: .handicap) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        defaultHonestJohn = try c.decodeIfPresent(Int.self, forKey: .defaultHonestJohn) ?? 90
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// ラウンド内のプレイヤー（IDは RegisteredPlayer と一致させる）
struct Player: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String = "#2E914E"
    var honestJohnDeclared: Int = 90
}

extension Player: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, honestJohnDeclared
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#2E914E"
        honestJohnDeclared = try c.decodeIfPresent(Int.self, forKey: .honestJohnDeclared) ?? 90
    }

    init(from registered: RegisteredPlayer) {
        self.id = registered.id
        self.name = registered.name
        self.honestJohnDeclared = registered.defaultHonestJohn
    }
}

struct RoundOptions: Equatable {
    var stakeRate: Int = 50
    var settlementCap: Int = 0
    var penaltiesEnabled: Bool = true
    var olympicsEnabled: Bool = true
    var lasVegasEnabled: Bool = false
    var holeMatchEnabled: Bool = false
    var sonchoEnabled: Bool = false
    var snakeEnabled: Bool = false
    var snakeSettlePerNine: Bool = true
    var honestJohnEnabled: Bool = false
    var lasVegasTeamA: [UUID] = []
    var lasVegasTeamB: [UUID] = []
}

extension RoundOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case stakeRate, settlementCap, penaltiesEnabled, olympicsEnabled
        case lasVegasEnabled, holeMatchEnabled
        case sonchoEnabled, snakeEnabled, snakeSettlePerNine, honestJohnEnabled
        case lasVegasTeamA, lasVegasTeamB
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stakeRate = try c.decodeIfPresent(Int.self, forKey: .stakeRate) ?? 50
        settlementCap = try c.decodeIfPresent(Int.self, forKey: .settlementCap) ?? 0
        penaltiesEnabled = try c.decodeIfPresent(Bool.self, forKey: .penaltiesEnabled) ?? true
        olympicsEnabled = try c.decodeIfPresent(Bool.self, forKey: .olympicsEnabled) ?? true
        lasVegasEnabled = try c.decodeIfPresent(Bool.self, forKey: .lasVegasEnabled) ?? false
        holeMatchEnabled = try c.decodeIfPresent(Bool.self, forKey: .holeMatchEnabled) ?? false
        sonchoEnabled = try c.decodeIfPresent(Bool.self, forKey: .sonchoEnabled) ?? false
        snakeEnabled = try c.decodeIfPresent(Bool.self, forKey: .snakeEnabled) ?? false
        snakeSettlePerNine = try c.decodeIfPresent(Bool.self, forKey: .snakeSettlePerNine) ?? true
        honestJohnEnabled = try c.decodeIfPresent(Bool.self, forKey: .honestJohnEnabled) ?? false
        lasVegasTeamA = try c.decodeIfPresent([UUID].self, forKey: .lasVegasTeamA) ?? []
        lasVegasTeamB = try c.decodeIfPresent([UUID].self, forKey: .lasVegasTeamB) ?? []
    }
}

struct PlayerHoleEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var playerId: UUID
    var strokes: Int = 0
    var putts: Int = 0
    var medal: OlympicMedal? = nil
    var chipInFromOffGreen: Bool = false
    var declaredPin: Bool = false
    var pinDistanceQualified: Bool = false
    var banker: Bool = false
    var nameLick: Bool = false
    var awaya: Bool = false
    var parOn: Bool = false
    var birdieOn: Bool = false
    var nearestPinContender: Bool = false
    var fireman: Bool = false
    var declaredReach: Bool = false
    var outerPinDeclared: Bool = false
    var greenInRegulationTee: Bool = false
    var strokesOnGreenAfterApproach: Int = 0
    var notes: String = ""
}

struct HoleRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var holeNumber: Int
    var par: Int
    var nearestPinCarryIn: Int = 0
    var entries: [PlayerHoleEntry] = []
    var notes: String = ""
}

struct GolfRound: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var date: Date = Date()
    var players: [Player] = []
    var holes: [HoleRecord] = []
    var options: RoundOptions = RoundOptions()
    var coursePars: [Int] = Array(repeating: 4, count: 18)
    /// 精算確定済み
    var isSettled: Bool = false
    var settledAt: Date? = nil
    /// 確定時のスナップショット（生涯戦績用）
    var settledSummary: SettlementSummary? = nil

    static func newRound(title: String, registered: [RegisteredPlayer], pars: [Int] = Array(repeating: 4, count: 18)) -> GolfRound {
        var round = GolfRound(title: title)
        round.players = registered.map { Player(from: $0) }
        round.coursePars = pars.count == 18 ? pars : Array(repeating: 4, count: 18)
        round.holes = (1...18).map { n in
            HoleRecord(
                holeNumber: n,
                par: round.coursePars[n - 1],
                entries: round.players.map { PlayerHoleEntry(playerId: $0.id) }
            )
        }
        if round.players.count >= 4 {
            round.options.lasVegasTeamA = [round.players[0].id, round.players[1].id]
            round.options.lasVegasTeamB = [round.players[2].id, round.players[3].id]
        }
        return round
    }

    /// 後方互換（名前だけ）
    static func newRound(title: String, playerNames: [String], pars: [Int] = Array(repeating: 4, count: 18)) -> GolfRound {
        let regs = playerNames.map { RegisteredPlayer(name: $0) }
        return newRound(title: title, registered: regs, pars: pars)
    }
}

extension GolfRound: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, date, players, holes, options, coursePars
        case isSettled, settledAt, settledSummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        players = try c.decodeIfPresent([Player].self, forKey: .players) ?? []
        holes = try c.decodeIfPresent([HoleRecord].self, forKey: .holes) ?? []
        options = try c.decodeIfPresent(RoundOptions.self, forKey: .options) ?? RoundOptions()
        coursePars = try c.decodeIfPresent([Int].self, forKey: .coursePars) ?? Array(repeating: 4, count: 18)
        isSettled = try c.decodeIfPresent(Bool.self, forKey: .isSettled) ?? false
        settledAt = try c.decodeIfPresent(Date.self, forKey: .settledAt)
        settledSummary = try c.decodeIfPresent(SettlementSummary.self, forKey: .settledSummary)
    }
}

// MARK: - Settlement DTOs

struct PointLine: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var code: String
    var label: String
    var points: Int
    var multipliedByReach: Bool = false
}

struct PlayerHoleOlympicsResult: Codable, Equatable {
    var playerId: UUID
    var lines: [PointLine]
    var rawPoints: Int
    var reachApplied: Bool
    var totalPoints: Int
}

struct HoleOlympicsResult: Codable, Equatable {
    var holeNumber: Int
    var nearestPinCarryOut: Int
    var perPlayer: [PlayerHoleOlympicsResult]
}

struct PlayerTotals: Identifiable, Equatable {
    var id: UUID { playerId }
    var playerId: UUID
    var name: String
    var grossScore: Int
    var olympicPoints: Int
    /// 検算単位: (自分点×人数) − 全員合計
    var olympicUnits: Int
    var holeMatchWins: Int
    var holeMatchYen: Int
    var lasVegasYen: Int
    var olympicYen: Int
    var sonchoYen: Int
    var snakeYen: Int
    var honestJohnPoints: Int
    var honestJohnYen: Int
    var isSoncho: Bool
    var netYen: Int
}

extension PlayerTotals: Codable {
    enum CodingKeys: String, CodingKey {
        case playerId, name, grossScore, olympicPoints, olympicUnits
        case holeMatchWins, holeMatchYen, lasVegasYen, olympicYen
        case sonchoYen, snakeYen, honestJohnPoints, honestJohnYen, isSoncho, netYen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try c.decode(UUID.self, forKey: .playerId)
        name = try c.decode(String.self, forKey: .name)
        grossScore = try c.decodeIfPresent(Int.self, forKey: .grossScore) ?? 0
        olympicPoints = try c.decodeIfPresent(Int.self, forKey: .olympicPoints) ?? 0
        olympicUnits = try c.decodeIfPresent(Int.self, forKey: .olympicUnits) ?? 0
        holeMatchWins = try c.decodeIfPresent(Int.self, forKey: .holeMatchWins) ?? 0
        holeMatchYen = try c.decodeIfPresent(Int.self, forKey: .holeMatchYen) ?? 0
        lasVegasYen = try c.decodeIfPresent(Int.self, forKey: .lasVegasYen) ?? 0
        olympicYen = try c.decodeIfPresent(Int.self, forKey: .olympicYen) ?? 0
        sonchoYen = try c.decodeIfPresent(Int.self, forKey: .sonchoYen) ?? 0
        snakeYen = try c.decodeIfPresent(Int.self, forKey: .snakeYen) ?? 0
        honestJohnPoints = try c.decodeIfPresent(Int.self, forKey: .honestJohnPoints) ?? 0
        honestJohnYen = try c.decodeIfPresent(Int.self, forKey: .honestJohnYen) ?? 0
        isSoncho = try c.decodeIfPresent(Bool.self, forKey: .isSoncho) ?? false
        netYen = try c.decodeIfPresent(Int.self, forKey: .netYen) ?? 0
    }
}

struct SnakeSegmentResult: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: String
    var holderId: UUID?
    var pot: Int
    var transfers: Int
}

struct HonestJohnPlayerResult: Identifiable, Codable, Equatable {
    var id: UUID { playerId }
    var playerId: UUID
    var declared: Int
    var actual: Int
    var points: Int
}

struct SettlementSummary: Codable, Equatable {
    var olympicByHole: [HoleOlympicsResult]
    var playerTotals: [PlayerTotals]
    var lasVegasHoleDiffs: [Int]
    var holeMatchWinnersByHole: [UUID?]
    var snakeSegments: [SnakeSegmentResult]
    var sonchoWinnerIds: [UUID]
    var honestJohn: [HonestJohnPlayerResult]
    var notes: [String]
}

// MARK: - Career

struct PlayerRoundResult: Identifiable, Codable, Equatable {
    var id: UUID { roundId }
    var roundId: UUID
    var title: String
    var date: Date
    var grossScore: Int
    var olympicPoints: Int
    var olympicYen: Int
    var netYen: Int
    var isWin: Bool { netYen > 0 }
    var isLose: Bool { netYen < 0 }
}

struct CareerStats: Identifiable, Equatable {
    var id: UUID { playerId }
    var playerId: UUID
    var name: String
    var roundsPlayed: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var totalNetYen: Int
    var totalOlympicYen: Int
    var totalOlympicPoints: Int
    var history: [PlayerRoundResult]
}
