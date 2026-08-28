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
    var isFavorite: Bool = false
    /// Soft-hide from pickers / default lists (data kept).
    var isHidden: Bool = false
    /// New rounds start with this player omitted from Olympics money settlement.
    var excludeFromOlympicsSettlement: Bool = false
}

extension RegisteredPlayer: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, homeCourse, homeTee, handicap, note, defaultHonestJohn, createdAt, isFavorite, isHidden
        case excludeFromOlympicsSettlement
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
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        excludeFromOlympicsSettlement = try c.decodeIfPresent(Bool.self, forKey: .excludeFromOlympicsSettlement) ?? false
    }
}

/// ティーボックス（ホール別ヤード）
struct CourseTee: Identifiable, Hashable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    /// 18ホールのヤード（0 = 未入力）
    var yards: [Int]

    static let presetNames = ["Gold", "Blue", "White", "Red", "Black", "Championship", "Forward"]

    var totalYards: Int { yards.reduce(0, +) }
    var hasAnyYardage: Bool { yards.contains(where: { $0 > 0 }) }

    init(id: UUID = UUID(), name: String, yards: [Int] = Array(repeating: 0, count: 18)) {
        self.id = id
        self.name = name
        self.yards = Self.normalizedYards(yards)
    }

    static func normalizedYards(_ yards: [Int]) -> [Int] {
        var out = Array(repeating: 0, count: 18)
        for i in 0..<min(18, yards.count) {
            out[i] = max(0, yards[i])
        }
        return out
    }

    static func emptyPresets() -> [CourseTee] {
        ["Gold", "Blue", "White", "Red"].map { CourseTee(name: $0) }
    }
}

/// 登録コース（名前＋18ホールのパー＋ティー距離）
struct RegisteredCourse: Identifiable, Hashable, Equatable {
    var id: UUID = UUID()
    var name: String
    var pars: [Int]
    var note: String = ""
    var createdAt: Date = Date()
    /// ゴルフ場名（例: The Riviera Golf and Country Club）
    var clubName: String = ""
    /// レイアウト名（例: Couples / Langer Out＋Couples In）
    var layoutName: String = ""
    var outNineName: String = ""
    var inNineName: String = ""
    /// 事前登録の重複防止キー
    var seedKey: String? = nil
    var isBuiltIn: Bool = false
    /// ティー別ホール距離（ヤード）
    var tees: [CourseTee] = []
    var isFavorite: Bool = false

    static let defaultPars: [Int] = Array(repeating: 4, count: 18)

    var totalPar: Int { pars.reduce(0, +) }
    var outPar: Int { pars.prefix(9).reduce(0, +) }
    var inPar: Int { pars.suffix(9).reduce(0, +) }
    var displayTitle: String {
        if !clubName.isEmpty, !layoutName.isEmpty {
            return "\(clubName) — \(layoutName)"
        }
        return name
    }

    init(
        id: UUID = UUID(),
        name: String,
        pars: [Int] = RegisteredCourse.defaultPars,
        note: String = "",
        createdAt: Date = Date(),
        clubName: String = "",
        layoutName: String = "",
        outNineName: String = "",
        inNineName: String = "",
        seedKey: String? = nil,
        isBuiltIn: Bool = false,
        tees: [CourseTee] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pars = Self.normalizedPars(pars)
        self.note = note
        self.createdAt = createdAt
        self.clubName = clubName
        self.layoutName = layoutName
        self.outNineName = outNineName
        self.inNineName = inNineName
        self.seedKey = seedKey
        self.isBuiltIn = isBuiltIn
        self.tees = tees.map {
            CourseTee(id: $0.id, name: $0.name, yards: CourseTee.normalizedYards($0.yards))
        }
        self.isFavorite = isFavorite
    }

    static func normalizedPars(_ pars: [Int]) -> [Int] {
        var out = Array(repeating: 4, count: 18)
        for i in 0..<min(18, pars.count) {
            out[i] = min(5, max(3, pars[i]))
        }
        return out
    }
}

extension RegisteredCourse: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, pars, note, createdAt
        case clubName, layoutName, outNineName, inNineName, seedKey, isBuiltIn, tees, isFavorite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        pars = Self.normalizedPars(try c.decodeIfPresent([Int].self, forKey: .pars) ?? Self.defaultPars)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        clubName = try c.decodeIfPresent(String.self, forKey: .clubName) ?? ""
        layoutName = try c.decodeIfPresent(String.self, forKey: .layoutName) ?? ""
        outNineName = try c.decodeIfPresent(String.self, forKey: .outNineName) ?? ""
        inNineName = try c.decodeIfPresent(String.self, forKey: .inNineName) ?? ""
        seedKey = try c.decodeIfPresent(String.self, forKey: .seedKey)
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? (seedKey != nil)
        tees = try c.decodeIfPresent([CourseTee].self, forKey: .tees) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

extension GolfRound {
    /// Short course label for list rows (~10 characters).
    var shortCourseLabel: String {
        let raw = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        if raw.count <= 10 { return raw }
        let end = raw.index(raw.startIndex, offsetBy: 10)
        return String(raw[..<end])
    }

    var listTitleWithCourse: String {
        let course = shortCourseLabel
        return course.isEmpty ? title : "\(title) · \(course)"
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

enum HoleMatchMode: String, Codable, CaseIterable, Identifiable {
    case allPlayAll
    case sides

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allPlayAll: return "全員対抗"
        case .sides: return "サイド対抗"
        }
    }

    var detail: String {
        switch self {
        case .allPlayAll:
            return "最少打数が1人だけのとき、その人がホール獲得（個人戦）。"
        case .sides:
            return "サイドA対サイドB。人数は自由（1対1、1対3、2対2など）。各サイドの最少打数で勝敗。"
        }
    }
}

struct RoundOptions: Equatable {
    var stakeRate: Int = 20
    var settlementCap: Int = 0
    var penaltiesEnabled: Bool = true
    var olympicsEnabled: Bool = true
    var lasVegasEnabled: Bool = false
    var holeMatchEnabled: Bool = false
    var holeMatchMode: HoleMatchMode = .allPlayAll
    var holeMatchSideA: [UUID] = []
    var holeMatchSideB: [UUID] = []
    var sonchoEnabled: Bool = false
    var snakeEnabled: Bool = false
    var snakeSettlePerNine: Bool = true
    var honestJohnEnabled: Bool = false
    var lasVegasTeamA: [UUID] = []
    var lasVegasTeamB: [UUID] = []
    var olympicsPoints: OlympicsPointRules = .rivieraDefault
    var customPointRules: [CustomPointRule] = []
    var lasVegasRules: LasVegasRules = .default
    /// 最後に適用／上書きした名前付きプリセット（任意）
    var activeRulePresetId: UUID? = nil
    /// オリンピック精算の人数・合計点から外す選手（点数入力自体は可能）
    var olympicsExcludedPlayerIds: [UUID] = []

    func isExcludedFromOlympicsSettlement(_ playerId: UUID) -> Bool {
        olympicsExcludedPlayerIds.contains(playerId)
    }

    mutating func setExcludedFromOlympicsSettlement(_ playerId: UUID, excluded: Bool) {
        if excluded {
            if !olympicsExcludedPlayerIds.contains(playerId) {
                olympicsExcludedPlayerIds.append(playerId)
            }
        } else {
            olympicsExcludedPlayerIds.removeAll { $0 == playerId }
        }
    }

    mutating func applyRulePreset(_ preset: NamedGameRulePreset) {
        olympicsPoints = preset.olympicsPoints
        customPointRules = preset.customPointRules
        lasVegasRules = preset.lasVegasRules
        activeRulePresetId = preset.id
    }
}

extension RoundOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case stakeRate, settlementCap, penaltiesEnabled, olympicsEnabled
        case lasVegasEnabled, holeMatchEnabled
        case holeMatchMode, holeMatchSideA, holeMatchSideB
        case sonchoEnabled, snakeEnabled, snakeSettlePerNine, honestJohnEnabled
        case lasVegasTeamA, lasVegasTeamB
        case olympicsPoints, customPointRules, lasVegasRules, activeRulePresetId
        case olympicsExcludedPlayerIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stakeRate = try c.decodeIfPresent(Int.self, forKey: .stakeRate) ?? 20
        settlementCap = try c.decodeIfPresent(Int.self, forKey: .settlementCap) ?? 0
        penaltiesEnabled = try c.decodeIfPresent(Bool.self, forKey: .penaltiesEnabled) ?? true
        olympicsEnabled = try c.decodeIfPresent(Bool.self, forKey: .olympicsEnabled) ?? true
        lasVegasEnabled = try c.decodeIfPresent(Bool.self, forKey: .lasVegasEnabled) ?? false
        holeMatchEnabled = try c.decodeIfPresent(Bool.self, forKey: .holeMatchEnabled) ?? false
        holeMatchMode = try c.decodeIfPresent(HoleMatchMode.self, forKey: .holeMatchMode) ?? .allPlayAll
        holeMatchSideA = try c.decodeIfPresent([UUID].self, forKey: .holeMatchSideA) ?? []
        holeMatchSideB = try c.decodeIfPresent([UUID].self, forKey: .holeMatchSideB) ?? []
        sonchoEnabled = try c.decodeIfPresent(Bool.self, forKey: .sonchoEnabled) ?? false
        snakeEnabled = try c.decodeIfPresent(Bool.self, forKey: .snakeEnabled) ?? false
        snakeSettlePerNine = try c.decodeIfPresent(Bool.self, forKey: .snakeSettlePerNine) ?? true
        honestJohnEnabled = try c.decodeIfPresent(Bool.self, forKey: .honestJohnEnabled) ?? false
        lasVegasTeamA = try c.decodeIfPresent([UUID].self, forKey: .lasVegasTeamA) ?? []
        lasVegasTeamB = try c.decodeIfPresent([UUID].self, forKey: .lasVegasTeamB) ?? []
        olympicsPoints = try c.decodeIfPresent(OlympicsPointRules.self, forKey: .olympicsPoints) ?? .rivieraDefault
        customPointRules = try c.decodeIfPresent([CustomPointRule].self, forKey: .customPointRules) ?? []
        lasVegasRules = try c.decodeIfPresent(LasVegasRules.self, forKey: .lasVegasRules) ?? .default
        activeRulePresetId = try c.decodeIfPresent(UUID.self, forKey: .activeRulePresetId)
        olympicsExcludedPlayerIds = try c.decodeIfPresent([UUID].self, forKey: .olympicsExcludedPlayerIds) ?? []
    }
}

struct PlayerHoleEntry: Identifiable, Equatable {
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
    /// Explicit 3-putt penalty (default −1). Independent of the putt stepper.
    var markedThreePutt: Bool = false
    /// Explicit pin miss penalty (default −2).
    var pinFailed: Bool = false
    var parOn: Bool = false
    var birdieOn: Bool = false
    var nearestPinContender: Bool = false
    var fireman: Bool = false
    var declaredReach: Bool = false
    var outerPinDeclared: Bool = false
    var greenInRegulationTee: Bool = false
    var strokesOnGreenAfterApproach: Int = 0
    var notes: String = ""
    /// nil = use rule default when the flag is on
    var pinPointsOverride: Int? = nil
    var bankerPointsOverride: Int? = nil
    var parOnPointsOverride: Int? = nil
    var birdieOnPointsOverride: Int? = nil
    /// Applied after reach math (not doubled by reach)
    var manualPointAdjust: Int = 0
    /// 独自ルールON（CustomPointRule.id）
    var customActiveRuleIds: [UUID] = []
    /// Button-recorded history (reach, name lick, etc.). Independent of stroke score.
    var eventLog: [OlympicEventRecord] = []
}

/// Named Olympics event recorded from the score sheet (not a stroke).
struct OlympicEventRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var code: String
    var label: String
    var createdAt: Date = Date()
}

extension PlayerHoleEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, playerId, strokes, putts, medal, chipInFromOffGreen
        case declaredPin, pinDistanceQualified, banker, nameLick, awaya
        case markedThreePutt, pinFailed
        case parOn, birdieOn, nearestPinContender, fireman, declaredReach
        case outerPinDeclared, greenInRegulationTee, strokesOnGreenAfterApproach, notes
        case pinPointsOverride, bankerPointsOverride, parOnPointsOverride, birdieOnPointsOverride
        case manualPointAdjust, customActiveRuleIds, eventLog
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        playerId = try c.decode(UUID.self, forKey: .playerId)
        strokes = try c.decodeIfPresent(Int.self, forKey: .strokes) ?? 0
        putts = try c.decodeIfPresent(Int.self, forKey: .putts) ?? 0
        medal = try c.decodeIfPresent(OlympicMedal.self, forKey: .medal)
        chipInFromOffGreen = try c.decodeIfPresent(Bool.self, forKey: .chipInFromOffGreen) ?? false
        declaredPin = try c.decodeIfPresent(Bool.self, forKey: .declaredPin) ?? false
        pinDistanceQualified = try c.decodeIfPresent(Bool.self, forKey: .pinDistanceQualified) ?? false
        banker = try c.decodeIfPresent(Bool.self, forKey: .banker) ?? false
        nameLick = try c.decodeIfPresent(Bool.self, forKey: .nameLick) ?? false
        awaya = try c.decodeIfPresent(Bool.self, forKey: .awaya) ?? false
        markedThreePutt = try c.decodeIfPresent(Bool.self, forKey: .markedThreePutt) ?? false
        pinFailed = try c.decodeIfPresent(Bool.self, forKey: .pinFailed) ?? false
        parOn = try c.decodeIfPresent(Bool.self, forKey: .parOn) ?? false
        birdieOn = try c.decodeIfPresent(Bool.self, forKey: .birdieOn) ?? false
        nearestPinContender = try c.decodeIfPresent(Bool.self, forKey: .nearestPinContender) ?? false
        fireman = try c.decodeIfPresent(Bool.self, forKey: .fireman) ?? false
        declaredReach = try c.decodeIfPresent(Bool.self, forKey: .declaredReach) ?? false
        outerPinDeclared = try c.decodeIfPresent(Bool.self, forKey: .outerPinDeclared) ?? false
        greenInRegulationTee = try c.decodeIfPresent(Bool.self, forKey: .greenInRegulationTee) ?? false
        strokesOnGreenAfterApproach = try c.decodeIfPresent(Int.self, forKey: .strokesOnGreenAfterApproach) ?? 0
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        pinPointsOverride = try c.decodeIfPresent(Int.self, forKey: .pinPointsOverride)
        bankerPointsOverride = try c.decodeIfPresent(Int.self, forKey: .bankerPointsOverride)
        parOnPointsOverride = try c.decodeIfPresent(Int.self, forKey: .parOnPointsOverride)
        birdieOnPointsOverride = try c.decodeIfPresent(Int.self, forKey: .birdieOnPointsOverride)
        manualPointAdjust = try c.decodeIfPresent(Int.self, forKey: .manualPointAdjust) ?? 0
        customActiveRuleIds = try c.decodeIfPresent([UUID].self, forKey: .customActiveRuleIds) ?? []
        eventLog = try c.decodeIfPresent([OlympicEventRecord].self, forKey: .eventLog) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(playerId, forKey: .playerId)
        try c.encode(strokes, forKey: .strokes)
        try c.encode(putts, forKey: .putts)
        try c.encodeIfPresent(medal, forKey: .medal)
        try c.encode(chipInFromOffGreen, forKey: .chipInFromOffGreen)
        try c.encode(declaredPin, forKey: .declaredPin)
        try c.encode(pinDistanceQualified, forKey: .pinDistanceQualified)
        try c.encode(banker, forKey: .banker)
        try c.encode(nameLick, forKey: .nameLick)
        try c.encode(awaya, forKey: .awaya)
        try c.encode(markedThreePutt, forKey: .markedThreePutt)
        try c.encode(pinFailed, forKey: .pinFailed)
        try c.encode(parOn, forKey: .parOn)
        try c.encode(birdieOn, forKey: .birdieOn)
        try c.encode(nearestPinContender, forKey: .nearestPinContender)
        try c.encode(fireman, forKey: .fireman)
        try c.encode(declaredReach, forKey: .declaredReach)
        try c.encode(outerPinDeclared, forKey: .outerPinDeclared)
        try c.encode(greenInRegulationTee, forKey: .greenInRegulationTee)
        try c.encode(strokesOnGreenAfterApproach, forKey: .strokesOnGreenAfterApproach)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(pinPointsOverride, forKey: .pinPointsOverride)
        try c.encodeIfPresent(bankerPointsOverride, forKey: .bankerPointsOverride)
        try c.encodeIfPresent(parOnPointsOverride, forKey: .parOnPointsOverride)
        try c.encodeIfPresent(birdieOnPointsOverride, forKey: .birdieOnPointsOverride)
        try c.encode(manualPointAdjust, forKey: .manualPointAdjust)
        try c.encode(customActiveRuleIds, forKey: .customActiveRuleIds)
        try c.encode(eventLog, forKey: .eventLog)
    }
}

struct HoleRecord: Identifiable, Equatable {
    var id: UUID = UUID()
    var holeNumber: Int
    var par: Int
    var nearestPinCarryIn: Int = 0
    var entries: [PlayerHoleEntry] = []
    var notes: String = ""
    /// When true, hole match uses the manual fields instead of scores.
    var holeMatchManual: Bool = false
    var holeMatchManualDraw: Bool = false
    var holeMatchManualWinnerIds: [UUID] = []
}

extension HoleRecord: Codable {
    enum CodingKeys: String, CodingKey {
        case id, holeNumber, par, nearestPinCarryIn, entries, notes
        case holeMatchManual, holeMatchManualDraw, holeMatchManualWinnerIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        holeNumber = try c.decode(Int.self, forKey: .holeNumber)
        par = try c.decode(Int.self, forKey: .par)
        nearestPinCarryIn = try c.decodeIfPresent(Int.self, forKey: .nearestPinCarryIn) ?? 0
        entries = try c.decodeIfPresent([PlayerHoleEntry].self, forKey: .entries) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        holeMatchManual = try c.decodeIfPresent(Bool.self, forKey: .holeMatchManual) ?? false
        holeMatchManualDraw = try c.decodeIfPresent(Bool.self, forKey: .holeMatchManualDraw) ?? false
        holeMatchManualWinnerIds = try c.decodeIfPresent([UUID].self, forKey: .holeMatchManualWinnerIds) ?? []
    }
}

struct GolfRound: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var date: Date = Date()
    var players: [Player] = []
    var holes: [HoleRecord] = []
    var options: RoundOptions = RoundOptions()
    var coursePars: [Int] = Array(repeating: 4, count: 18)
    /// 選択中 Tee のホール別ヤード（0 = 未設定）
    var courseYards: [Int] = Array(repeating: 0, count: 18)
    var selectedTeeName: String = ""
    var courseId: UUID? = nil
    var courseName: String = ""
    /// 精算確定済み
    var isSettled: Bool = false
    var settledAt: Date? = nil
    /// 確定時のスナップショット（生涯戦績用）
    var settledSummary: SettlementSummary? = nil
    /// Soft-hide from home list (data kept for career / reopen).
    var isArchived: Bool = false

    var hasHoleYards: Bool { courseYards.contains(where: { $0 > 0 }) }

    func yards(forHole holeNumber: Int) -> Int {
        guard (1...18).contains(holeNumber), courseYards.count == 18 else { return 0 }
        return courseYards[holeNumber - 1]
    }

    mutating func applyCourse(_ course: RegisteredCourse, teeName: String? = nil) {
        courseId = course.id
        courseName = course.displayTitle
        coursePars = course.pars
        applyTee(named: teeName ?? selectedTeeName, from: course)
        for i in holes.indices {
            let n = holes[i].holeNumber
            if (1...18).contains(n) {
                holes[i].par = course.pars[n - 1]
            }
        }
    }

    mutating func applyTee(named teeName: String, from course: RegisteredCourse) {
        let resolved: String = {
            if course.tees.contains(where: { $0.name == teeName }) { return teeName }
            if let preferred = course.tees.first(where: { $0.name == "Blue" })?.name { return preferred }
            return course.tees.first?.name ?? ""
        }()
        selectedTeeName = resolved
        if let tee = course.tees.first(where: { $0.name == resolved }) {
            courseYards = CourseTee.normalizedYards(tee.yards)
        } else {
            courseYards = Array(repeating: 0, count: 18)
        }
    }

    static func newRound(
        title: String,
        registered: [RegisteredPlayer],
        pars: [Int] = Array(repeating: 4, count: 18),
        options: RoundOptions = RoundOptions(),
        course: RegisteredCourse? = nil,
        teeName: String? = nil
    ) -> GolfRound {
        var round = GolfRound(title: title)
        round.players = registered.map { Player(from: $0) }
        round.options = options
        let defaultExcluded = registered.filter(\.excludeFromOlympicsSettlement).map(\.id)
        if !defaultExcluded.isEmpty {
            var set = Set(round.options.olympicsExcludedPlayerIds)
            defaultExcluded.forEach { set.insert($0) }
            round.options.olympicsExcludedPlayerIds = registered.map(\.id).filter { set.contains($0) }
        }
        if let course {
            round.applyCourse(course, teeName: teeName)
        } else {
            round.coursePars = pars.count == 18 ? pars : Array(repeating: 4, count: 18)
            round.courseYards = Array(repeating: 0, count: 18)
            round.selectedTeeName = ""
        }
        round.holes = (1...18).map { n in
            HoleRecord(
                holeNumber: n,
                par: round.coursePars[n - 1],
                entries: round.players.map { PlayerHoleEntry(playerId: $0.id) }
            )
        }
        if round.options.lasVegasTeamA.isEmpty && round.options.lasVegasTeamB.isEmpty,
           round.players.count >= 4 {
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
        case id, title, date, players, holes, options, coursePars, courseYards, selectedTeeName
        case courseId, courseName
        case isSettled, settledAt, settledSummary, isArchived
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
        courseYards = CourseTee.normalizedYards(try c.decodeIfPresent([Int].self, forKey: .courseYards) ?? [])
        selectedTeeName = try c.decodeIfPresent(String.self, forKey: .selectedTeeName) ?? ""
        courseId = try c.decodeIfPresent(UUID.self, forKey: .courseId)
        courseName = try c.decodeIfPresent(String.self, forKey: .courseName) ?? ""
        isSettled = try c.decodeIfPresent(Bool.self, forKey: .isSettled) ?? false
        settledAt = try c.decodeIfPresent(Date.self, forKey: .settledAt)
        settledSummary = try c.decodeIfPresent(SettlementSummary.self, forKey: .settledSummary)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
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
    var olympicsSettlementExcluded: Bool = false
}

extension PlayerTotals: Codable {
    enum CodingKeys: String, CodingKey {
        case playerId, name, grossScore, olympicPoints, olympicUnits
        case holeMatchWins, holeMatchYen, lasVegasYen, olympicYen
        case sonchoYen, snakeYen, honestJohnPoints, honestJohnYen, isSoncho, netYen
        case olympicsSettlementExcluded
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
        olympicsSettlementExcluded = try c.decodeIfPresent(Bool.self, forKey: .olympicsSettlementExcluded) ?? false
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
