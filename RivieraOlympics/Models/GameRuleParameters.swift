import Foundation

/// オリンピック各項目の点数（ラウンド設定で変更可）
struct OlympicsPointRules: Equatable, Codable {
    var gold: Int = 4
    var silver: Int = 3
    var bronze: Int = 2
    var iron: Int = 1
    var diamond: Int = 5
    var pin: Int = 2
    var pinThreePutt: Int = -2
    var banker: Int = 2
    var birdie: Int = 3
    var eagle: Int = 10
    var albatross: Int = 10
    var holeInOne: Int = 100
    var parOn: Int = 1
    var birdieOn: Int = 3
    var threePutt: Int = -1
    var overThreePuttPerExtra: Int = -1
    var nameLick: Int = -1
    var awaya: Int = -1
    var yakitori: Int = -5
    var reachMissDefaultBase: Int = 2
    var nearestPinBase: Int = 3
    var firemanBase: Int = 1
    var forcedReachSuccess: Int = 10
    var forcedReachFail: Int = -10

    func medalPoints(_ medal: OlympicMedal) -> Int {
        switch medal {
        case .gold: return gold
        case .silver: return silver
        case .bronze: return bronze
        case .iron: return iron
        case .diamond: return diamond
        }
    }

    static let rivieraDefault = OlympicsPointRules()
}

/// ユーザー定義の加点／減点ルール
struct CustomPointRule: Identifiable, Equatable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var points: Int
    /// true のときリーチ倍率対象
    var appliesReach: Bool = true
    var enabled: Bool = true

    var isPenalty: Bool { points < 0 }
}

/// ラスベガス拡張ルール（いずれもユーザーが ON/OFF 可能）
struct LasVegasRules: Equatable, Codable {
    /// 前ホール順位で 1位+4位 vs 2位+3位 に組替
    var rotatePairsByPreviousHoleScore: Bool = true
    /// 一方だけバーディー以上 → 相手チームの連結スコアを桁反転（flip）
    var birdieFlip: Bool = false
    /// 一方だけイーグル以上 → flip かつ差分×2
    var eagleFlipAndDouble: Bool = false
    /// 同一チームがバーディー以上を2つ → 相手 flip かつ差分×2
    var twoBirdiesFlipAndDouble: Bool = false

    static let `default` = LasVegasRules()
}

/// 名前付きルールパラメータセット（アプリ全体で保存・再利用）
struct NamedGameRulePreset: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var olympicsPoints: OlympicsPointRules
    var customPointRules: [CustomPointRule]
    var lasVegasRules: LasVegasRules
    var updatedAt: Date = Date()

    static func from(name: String, options: RoundOptions) -> NamedGameRulePreset {
        NamedGameRulePreset(
            name: name,
            olympicsPoints: options.olympicsPoints,
            customPointRules: options.customPointRules,
            lasVegasRules: options.lasVegasRules
        )
    }

    static let rivieraDefault = NamedGameRulePreset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "リビエラ既定",
        olympicsPoints: .rivieraDefault,
        customPointRules: [],
        lasVegasRules: .default
    )
}
