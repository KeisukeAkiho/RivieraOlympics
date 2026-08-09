import Foundation

/// 9ホール単位のループ（前半／後半の組み合わせ用）
struct CourseNineLoop: Identifiable, Hashable, Equatable, Codable {
    var id: String
    var name: String
    var pars: [Int]
    /// Tee名 → 9ホールのヤード
    var teeYards: [String: [Int]]

    var totalPar: Int { pars.reduce(0, +) }

    init(id: String, name: String, pars: [Int], teeYards: [String: [Int]] = [:]) {
        self.id = id
        self.name = name
        precondition(pars.count == 9, "Nine must have 9 holes")
        self.pars = pars.map { min(5, max(3, $0)) }
        self.teeYards = teeYards.reduce(into: [:]) { acc, kv in
            var yards = Array(repeating: 0, count: 9)
            for i in 0..<min(9, kv.value.count) {
                yards[i] = max(0, kv.value[i])
            }
            acc[kv.key] = yards
        }
    }
}

struct CourseLayoutSuggestion: Hashable, Equatable {
    var outId: String
    var inId: String
    var layoutName: String
}

/// ゴルフ場（複数の9ホール／固定18を持つ）
struct GolfClubCatalogEntry: Identifiable, Hashable {
    var id: String
    var name: String
    var location: String
    /// 表示用の広域区分（カタログ一覧のセクション見出し）
    var region: String
    var nines: [CourseNineLoop]
    /// よく使う18ホール組み合わせ
    var suggestedLayouts: [CourseLayoutSuggestion]

    func nine(id: String) -> CourseNineLoop? {
        nines.first(where: { $0.id == id })
    }

    func makeCourse(outId: String, inId: String, layoutName: String? = nil) -> RegisteredCourse? {
        guard let out = nine(id: outId), let inn = nine(id: inId) else { return nil }
        let layout = layoutName ?? "\(out.name) / \(inn.name)"
        let seed = "\(id)|\(outId)|\(inId)"
        let teeNames = Set(out.teeYards.keys).union(inn.teeYards.keys).sorted()
        let tees: [CourseTee] = teeNames.compactMap { teeName in
            let o = out.teeYards[teeName] ?? Array(repeating: 0, count: 9)
            let i = inn.teeYards[teeName] ?? Array(repeating: 0, count: 9)
            let yards = o + i
            guard yards.contains(where: { $0 > 0 }) else { return nil }
            return CourseTee(name: teeName, yards: yards)
        }
        return RegisteredCourse(
            name: "\(name) — \(layout)",
            pars: out.pars + inn.pars,
            note: "\(location)。公開スコアカード等に基づく事前登録（要確認）。",
            clubName: name,
            layoutName: layout,
            outNineName: out.name,
            inNineName: inn.name,
            seedKey: seed,
            isBuiltIn: true,
            tees: tees
        )
    }
}

/// Gold / Blue / White / Red の9ホールヤード辞書を作る（欠けた色は省略）
private func gbwr(
    gold: [Int]? = nil,
    blue: [Int]? = nil,
    white: [Int]? = nil,
    red: [Int]? = nil
) -> [String: [Int]] {
    var d: [String: [Int]] = [:]
    if let gold { d["Gold"] = gold }
    if let blue { d["Blue"] = blue }
    if let white { d["White"] = white }
    if let red { d["Red"] = red }
    return d
}

/// 18ホール配列を前半9 / 後半9に分割
private func split18(_ yards: [Int]) -> (out: [Int], inn: [Int]) {
    precondition(yards.count == 18, "Expected 18 yardages")
    return (Array(yards.prefix(9)), Array(yards.suffix(9)))
}

/// フィリピン全土の主要コース事前登録カタログ
enum PhilippineCourseCatalog {
    /// シード内容を広げたときに上げる（ドキュメント用。マージは seedKey 単位）
    static let version = 5

    static let clubs: [GolfClubCatalogEntry] = [
        // Cavite / Batangas / Metro / Laguna / Rizal
        riviera,
        eagleRidge,
        sherwoodHills,
        southwoods,
        orchard,
        tagaytayHighlands,
        tagaytayMidlands,
        splendido,
        calatagan,
        wackWack,
        manilaGolf,
        forestHills,
        valleyGolf,
        staElena,
        ayalaGreenfield,
        theCountryClub,
        canlubang,
        // Central / North Luzon
        anvayaCove,
        luisita,
        mimosa,
        campJohnHay,
        // Visayas
        fairwaysBluewater,
        altaVista,
        // Mindanao
        apoGolf,
        puebloDeOro,
        ranchoPalosVerdes
    ]

    static var regionOrder: [String] {
        [
            "Cavite",
            "Batangas",
            "Metro Manila",
            "Laguna",
            "Rizal",
            "Bataan",
            "Central Luzon",
            "Cordillera",
            "Visayas",
            "Mindanao"
        ]
    }

    static func clubsGroupedByRegion() -> [(region: String, clubs: [GolfClubCatalogEntry])] {
        let grouped = Dictionary(grouping: clubs, by: \.region)
        return regionOrder.compactMap { region in
            guard let list = grouped[region], !list.isEmpty else { return nil }
            return (region, list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }
    }

    /// 推奨レイアウトを平坦化して RegisteredCourse にする
    static func defaultSeedCourses() -> [RegisteredCourse] {
        var out: [RegisteredCourse] = []
        for club in clubs {
            for layout in club.suggestedLayouts {
                if let course = club.makeCourse(
                    outId: layout.outId,
                    inId: layout.inId,
                    layoutName: layout.layoutName
                ) {
                    out.append(course)
                }
            }
        }
        return out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Riviera (Silang, Cavite) — Couples / Langer

    private static let riviera = GolfClubCatalogEntry(
        id: "ph-riviera",
        name: "The Riviera Golf and Country Club",
        location: "Silang, Cavite",
        region: "Cavite",
        nines: [
            CourseNineLoop(
                id: "couples-out", name: "Couples Out",
                pars: [4, 5, 4, 4, 4, 3, 5, 3, 4],
                teeYards: gbwr(
                    gold: [390, 544, 373, 457, 459, 190, 567, 226, 427],
                    blue: [355, 507, 348, 406, 418, 172, 530, 206, 394],
                    white: [315, 471, 300, 375, 380, 146, 492, 186, 345],
                    red: [296, 433, 254, 319, 315, 99, 443, 115, 300]
                )
            ),
            CourseNineLoop(
                id: "couples-in", name: "Couples In",
                pars: [4, 5, 4, 4, 3, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [343, 528, 389, 441, 140, 459, 540, 173, 456],
                    blue: [331, 514, 346, 405, 117, 434, 518, 154, 367],
                    white: [295, 476, 290, 365, 94, 376, 488, 133, 331],
                    red: [252, 320, 274, 335, 63, 325, 432, 100, 270]
                )
            ),
            CourseNineLoop(
                id: "langer-out", name: "Langer Out",
                pars: [4, 4, 4, 3, 5, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [423, 443, 480, 182, 604, 416, 414, 175, 385],
                    blue: [411, 422, 414, 171, 598, 380, 383, 167, 359],
                    white: [367, 366, 396, 159, 590, 325, 357, 139, 333],
                    red: [330, 332, 367, 114, 509, 260, 288, 97, 285]
                )
            ),
            CourseNineLoop(
                id: "langer-in", name: "Langer In",
                pars: [5, 4, 3, 4, 4, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [553, 367, 234, 409, 456, 345, 577, 156, 438],
                    blue: [534, 347, 212, 376, 446, 310, 552, 142, 402],
                    white: [499, 327, 160, 279, 440, 288, 525, 140, 375],
                    red: [363, 288, 137, 234, 353, 266, 438, 137, 328]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "couples-out", inId: "couples-in", layoutName: "Couples"),
            CourseLayoutSuggestion(outId: "langer-out", inId: "langer-in", layoutName: "Langer"),
            CourseLayoutSuggestion(outId: "couples-out", inId: "langer-in", layoutName: "Couples Out / Langer In"),
            CourseLayoutSuggestion(outId: "langer-out", inId: "couples-in", layoutName: "Langer Out / Couples In")
        ]
    )

    // MARK: - Eagle Ridge — Faldo / Aoki / Dye / Norman（各18ホール）

    private static let eagleRidge = GolfClubCatalogEntry(
        id: "ph-eagle-ridge",
        name: "Eagle Ridge Golf & Country Club",
        location: "General Trias, Cavite",
        region: "Cavite",
        nines: [
            // Golfify（ホール別パー＋Gold/Blue/White/Red）
            CourseNineLoop(
                id: "faldo-out", name: "Faldo Out",
                pars: [4, 5, 3, 5, 4, 3, 4, 4, 4],
                teeYards: gbwr(
                    gold: [355, 556, 205, 603, 430, 249, 442, 423, 464],
                    blue: [333, 528, 175, 568, 408, 221, 410, 385, 444],
                    white: [303, 501, 144, 474, 373, 153, 372, 351, 419],
                    red: [273, 444, 119, 432, 328, 126, 322, 326, 377]
                )
            ),
            CourseNineLoop(
                id: "faldo-in", name: "Faldo In",
                pars: [4, 3, 5, 4, 5, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [446, 186, 591, 431, 566, 395, 448, 219, 434],
                    blue: [421, 164, 566, 391, 530, 370, 426, 202, 355],
                    white: [396, 143, 541, 360, 514, 323, 389, 140, 275],
                    red: [341, 96, 442, 319, 454, 278, 352, 99, 175]
                )
            ),
            CourseNineLoop(
                id: "aoki-out", name: "Aoki Out",
                pars: [4, 4, 5, 3, 4, 5, 3, 4, 4],
                teeYards: gbwr(
                    gold: [452, 448, 566, 157, 285, 523, 212, 427, 327],
                    blue: [436, 414, 525, 137, 262, 499, 190, 395, 304],
                    white: [415, 387, 500, 114, 233, 399, 163, 359, 281],
                    red: [379, 344, 436, 91, 190, 370, 132, 318, 249]
                )
            ),
            CourseNineLoop(
                id: "aoki-in", name: "Aoki In",
                pars: [4, 5, 4, 4, 4, 3, 5, 3, 4],
                teeYards: gbwr(
                    gold: [425, 602, 363, 431, 425, 216, 527, 144, 460],
                    blue: [403, 572, 339, 412, 385, 193, 443, 122, 435],
                    white: [381, 542, 308, 360, 355, 168, 375, 101, 410],
                    red: [349, 483, 253, 319, 300, 119, 338, 84, 381]
                )
            ),
            CourseNineLoop(
                id: "dye-out", name: "Dye Out",
                pars: [4, 4, 3, 5, 4, 4, 4, 3, 5],
                teeYards: gbwr(
                    gold: [477, 406, 242, 489, 383, 490, 336, 191, 512],
                    blue: [415, 346, 228, 471, 361, 465, 317, 171, 499],
                    white: [380, 311, 180, 442, 321, 435, 270, 161, 448],
                    red: [333, 254, 137, 349, 264, 363, 189, 89, 415]
                )
            ),
            CourseNineLoop(
                id: "dye-in", name: "Dye In",
                pars: [4, 5, 3, 4, 4, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [427, 641, 162, 353, 490, 471, 603, 117, 473],
                    blue: [396, 584, 136, 332, 445, 444, 551, 141, 439],
                    white: [379, 541, 116, 296, 386, 422, 520, 125, 405],
                    red: [346, 482, 100, 262, 292, 388, 505, 95, 327]
                )
            ),
            CourseNineLoop(
                id: "norman-out", name: "Norman Out",
                pars: [4, 4, 5, 3, 5, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [410, 428, 574, 195, 589, 377, 327, 158, 418],
                    blue: [380, 373, 517, 185, 562, 349, 291, 133, 364],
                    white: [325, 342, 482, 159, 516, 313, 230, 104, 332],
                    red: [306, 311, 427, 127, 482, 279, 217, 86, 311]
                )
            ),
            CourseNineLoop(
                id: "norman-in", name: "Norman In",
                pars: [4, 5, 4, 4, 3, 5, 4, 3, 4],
                teeYards: gbwr(
                    gold: [432, 539, 424, 438, 176, 569, 432, 189, 448],
                    blue: [406, 504, 399, 395, 156, 515, 394, 166, 366],
                    white: [390, 483, 367, 344, 138, 441, 366, 139, 342],
                    red: [362, 437, 305, 332, 89, 417, 316, 112, 252]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "faldo-out", inId: "faldo-in", layoutName: "Nick Faldo"),
            CourseLayoutSuggestion(outId: "aoki-out", inId: "aoki-in", layoutName: "Isao Aoki"),
            CourseLayoutSuggestion(outId: "dye-out", inId: "dye-in", layoutName: "Andy Dye"),
            CourseLayoutSuggestion(outId: "norman-out", inId: "norman-in", layoutName: "Greg Norman")
        ]
    )

    // MARK: - Sherwood Hills (必須)

    private static let sherwoodHills = GolfClubCatalogEntry(
        id: "ph-sherwood-hills",
        name: "Sherwood Hills Golf & Country Club",
        location: "Trece Martires, Cavite",
        region: "Cavite",
        nines: [
            // GolfPass / 18Birdies — Jack Nicklaus, Par 72
            CourseNineLoop(
                id: "sherwood-out", name: "Out",
                pars: [4, 3, 4, 5, 4, 3, 4, 5, 4],
                teeYards: gbwr(
                    gold: [405, 221, 432, 566, 441, 182, 388, 525, 468],
                    blue: [388, 202, 399, 545, 431, 167, 376, 501, 444],
                    white: [366, 154, 335, 486, 326, 119, 290, 450, 372],
                    red: [260, 135, 303, 479, 294, 92, 243, 368, 299]
                )
            ),
            CourseNineLoop(
                id: "sherwood-in", name: "In",
                pars: [4, 3, 5, 4, 4, 5, 3, 4, 4],
                teeYards: gbwr(
                    gold: [366, 196, 558, 454, 430, 532, 192, 447, 462],
                    blue: [342, 177, 545, 433, 404, 505, 176, 425, 423],
                    white: [286, 148, 482, 376, 341, 428, 143, 355, 311],
                    red: [234, 113, 444, 316, 293, 419, 131, 297, 299]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "sherwood-out", inId: "sherwood-in", layoutName: "Championship")
        ]
    )

    // MARK: - Manila Southwoods — Legends / Masters

    private static let southwoods = GolfClubCatalogEntry(
        id: "ph-southwoods",
        name: "Manila Southwoods Golf & Country Club",
        location: "Carmona, Cavite",
        region: "Cavite",
        nines: [
            CourseNineLoop(
                id: "legends-out", name: "Legends Out",
                pars: [4, 4, 3, 4, 4, 5, 3, 5, 4],
                teeYards: gbwr(
                    gold: [406, 383, 191, 407, 428, 605, 182, 566, 425],
                    blue: [372, 357, 176, 368, 398, 575, 154, 538, 376],
                    white: [334, 331, 168, 324, 363, 545, 138, 513, 333],
                    red: [293, 305, 137, 285, 311, 472, 102, 463, 292]
                )
            ),
            CourseNineLoop(
                id: "legends-in", name: "Legends In",
                pars: [4, 4, 3, 4, 5, 4, 3, 5, 4],
                teeYards: gbwr(
                    gold: [453, 368, 215, 364, 560, 400, 200, 565, 434],
                    blue: [423, 321, 202, 331, 496, 366, 161, 533, 388],
                    white: [393, 269, 178, 246, 462, 322, 121, 500, 355],
                    red: [323, 232, 141, 206, 416, 303, 102, 460, 289]
                )
            ),
            CourseNineLoop(
                id: "masters-out", name: "Masters Out",
                pars: [4, 4, 3, 5, 3, 4, 4, 5, 4],
                teeYards: gbwr(
                    gold: [408, 433, 194, 543, 197, 415, 455, 550, 397],
                    blue: [366, 369, 183, 511, 175, 396, 421, 507, 361],
                    white: [327, 354, 172, 474, 151, 373, 365, 444, 326],
                    red: [286, 337, 130, 439, 119, 306, 319, 400, 258]
                )
            ),
            CourseNineLoop(
                id: "masters-in", name: "Masters In",
                pars: [4, 4, 4, 3, 4, 5, 4, 3, 5],
                teeYards: gbwr(
                    gold: [429, 401, 402, 237, 432, 545, 453, 193, 541],
                    blue: [385, 376, 379, 190, 415, 512, 416, 181, 470],
                    white: [372, 346, 356, 181, 340, 482, 359, 156, 455],
                    red: [305, 277, 279, 149, 315, 383, 324, 118, 380]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "legends-out", inId: "legends-in", layoutName: "Legends"),
            CourseLayoutSuggestion(outId: "masters-out", inId: "masters-in", layoutName: "Masters"),
            CourseLayoutSuggestion(outId: "legends-out", inId: "masters-in", layoutName: "Legends Out / Masters In"),
            CourseLayoutSuggestion(outId: "masters-out", inId: "legends-in", layoutName: "Masters Out / Legends In")
        ]
    )

    // MARK: - Orchard — Palmer / Player

    private static let orchard = GolfClubCatalogEntry(
        id: "ph-orchard",
        name: "The Orchard Golf & Country Club",
        location: "Dasmariñas, Cavite",
        region: "Cavite",
        nines: [
            CourseNineLoop(
                id: "palmer-out", name: "Palmer Out",
                pars: [4, 5, 4, 4, 3, 5, 3, 4, 4],
                teeYards: gbwr(
                    gold: [440, 521, 455, 487, 191, 506, 199, 404, 413],
                    blue: [413, 490, 359, 456, 177, 470, 179, 382, 394],
                    white: [357, 406, 330, 363, 138, 389, 132, 303, 319],
                    red: [335, 381, 303, 337, 120, 359, 86, 270, 290]
                )
            ),
            CourseNineLoop(
                id: "palmer-in", name: "Palmer In",
                pars: [4, 4, 3, 4, 5, 4, 3, 4, 5],
                teeYards: gbwr(
                    gold: [403, 345, 152, 385, 535, 427, 206, 405, 574],
                    blue: [373, 324, 140, 360, 485, 403, 187, 384, 537],
                    white: [332, 283, 103, 320, 445, 317, 150, 318, 455],
                    red: [290, 266, 88, 265, 406, 286, 140, 280, 421]
                )
            ),
            CourseNineLoop(
                id: "player-out", name: "Player Out",
                pars: [4, 4, 3, 5, 3, 4, 4, 4, 5],
                teeYards: gbwr(
                    gold: [359, 381, 196, 513, 208, 396, 367, 372, 578],
                    blue: [329, 354, 169, 494, 195, 378, 360, 317, 538],
                    white: [312, 333, 156, 455, 177, 340, 324, 252, 500],
                    red: [293, 313, 124, 448, 172, 303, 318, 228, 462]
                )
            ),
            CourseNineLoop(
                id: "player-in", name: "Player In",
                pars: [4, 3, 5, 4, 3, 4, 4, 4, 5],
                teeYards: gbwr(
                    gold: [426, 163, 610, 357, 179, 465, 381, 449, 503],
                    blue: [391, 159, 562, 340, 160, 441, 319, 429, 481],
                    white: [367, 151, 509, 285, 140, 390, 275, 405, 418],
                    red: [324, 100, 480, 251, 128, 363, 244, 386, 407]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "palmer-out", inId: "palmer-in", layoutName: "Palmer"),
            CourseLayoutSuggestion(outId: "player-out", inId: "player-in", layoutName: "Player"),
            CourseLayoutSuggestion(outId: "palmer-out", inId: "player-in", layoutName: "Palmer Out / Player In"),
            CourseLayoutSuggestion(outId: "player-out", inId: "palmer-in", layoutName: "Player Out / Palmer In")
        ]
    )

    // MARK: - Tagaytay Highlands (Par 70)

    private static let tagaytayHighlands = GolfClubCatalogEntry(
        id: "ph-tagaytay-highlands",
        name: "Tagaytay Highlands International Golf Club",
        location: "Tagaytay, Cavite",
        region: "Cavite",
        nines: [
            CourseNineLoop(
                id: "th-out", name: "Out",
                pars: [4, 3, 4, 5, 4, 3, 4, 4, 3],
                teeYards: gbwr(
                    gold: [341, 197, 357, 533, 340, 118, 396, 366, 129],
                    blue: [326, 179, 341, 523, 330, 102, 388, 357, 120],
                    white: [309, 172, 336, 504, 319, 93, 340, 350, 114],
                    red: [270, 170, 301, 357, 302, 71, 330, 330, 111]
                )
            ),
            CourseNineLoop(
                id: "th-in", name: "In",
                pars: [4, 4, 3, 4, 5, 5, 4, 3, 4],
                teeYards: gbwr(
                    gold: [368, 348, 190, 439, 490, 541, 394, 161, 411],
                    blue: [362, 335, 168, 382, 466, 528, 362, 134, 372],
                    white: [351, 318, 150, 376, 442, 513, 360, 113, 334],
                    red: [330, 304, 112, 291, 359, 480, 329, 87, 254]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "th-out", inId: "th-in", layoutName: "Championship")
        ]
    )

    // MARK: - Tagaytay Midlands + Lucky 9

    private static let tagaytayMidlands = GolfClubCatalogEntry(
        id: "ph-tagaytay-midlands",
        name: "Tagaytay Midlands Golf Club",
        location: "Tagaytay, Cavite",
        region: "Cavite",
        nines: [
            CourseNineLoop(
                id: "midlands-out", name: "Championship Out",
                pars: [4, 5, 3, 4, 3, 5, 4, 4, 4],
                teeYards: gbwr(
                    gold: [433, 592, 161, 463, 183, 539, 349, 410, 411],
                    blue: [424, 577, 141, 445, 169, 499, 335, 388, 393],
                    white: [403, 505, 121, 411, 153, 478, 321, 366, 373],
                    red: [300, 491, 100, 388, 130, 427, 306, 343, 356]
                )
            ),
            CourseNineLoop(
                id: "midlands-in", name: "Championship In",
                pars: [4, 4, 3, 4, 4, 4, 5, 3, 5],
                teeYards: gbwr(
                    gold: [428, 423, 137, 426, 439, 460, 492, 167, 514],
                    blue: [401, 400, 127, 414, 423, 439, 472, 165, 496],
                    white: [376, 383, 115, 403, 382, 419, 459, 162, 481],
                    red: [352, 344, 105, 314, 359, 362, 444, 149, 462]
                )
            ),
            // GolfPass Lucky 9
            CourseNineLoop(
                id: "lucky9", name: "Lucky 9",
                pars: [4, 5, 3, 5, 3, 4, 5, 4, 3],
                teeYards: gbwr(
                    gold: [306, 645, 161, 544, 210, 426, 530, 389, 242],
                    blue: [278, 570, 136, 490, 164, 392, 466, 341, 192],
                    white: [222, 510, 93, 440, 149, 369, 445, 306, 144],
                    red: [206, 450, 87, 398, 116, 324, 311, 246, 103]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "midlands-out", inId: "midlands-in", layoutName: "Championship"),
            CourseLayoutSuggestion(outId: "lucky9", inId: "lucky9", layoutName: "Lucky 9 × 2"),
            CourseLayoutSuggestion(outId: "midlands-out", inId: "lucky9", layoutName: "Championship Out / Lucky 9"),
            CourseLayoutSuggestion(outId: "lucky9", inId: "midlands-in", layoutName: "Lucky 9 / Championship In")
        ]
    )

    // MARK: - Splendido Taal

    private static let splendido = GolfClubCatalogEntry(
        id: "ph-splendido",
        name: "Splendido Taal Golf & Country Club",
        location: "Laurel, Batangas",
        region: "Batangas",
        nines: [
            CourseNineLoop(
                id: "splendido-out", name: "Out",
                pars: [5, 5, 3, 4, 4, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [534, 559, 142, 357, 464, 356, 422, 234, 435],
                    blue: [512, 538, 130, 340, 443, 343, 412, 213, 418],
                    white: [488, 502, 100, 298, 416, 272, 364, 191, 383],
                    red: [364, 320, 89, 195, 377, 200, 285, 174, 308]
                )
            ),
            CourseNineLoop(
                id: "splendido-in", name: "In",
                pars: [4, 5, 4, 4, 4, 3, 4, 3, 5],
                teeYards: gbwr(
                    gold: [395, 538, 455, 425, 372, 166, 375, 180, 550],
                    blue: [379, 528, 428, 415, 349, 148, 361, 164, 533],
                    white: [324, 475, 399, 395, 326, 118, 334, 134, 501],
                    red: [243, 396, 332, 333, 220, 99, 376, 113, 434]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "splendido-out", inId: "splendido-in", layoutName: "Championship")
        ]
    )

    // MARK: - Calatagan

    private static let calatagan = GolfClubCatalogEntry(
        id: "ph-calatagan",
        name: "Calatagan Golf Club",
        location: "Calatagan, Batangas",
        region: "Batangas",
        nines: [
            CourseNineLoop(
                id: "calatagan-out", name: "Out",
                pars: [5, 3, 4, 5, 4, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [555, 145, 398, 540, 432, 370, 390, 222, 404],
                    blue: [555, 145, 398, 540, 432, 370, 390, 222, 404],
                    white: [515, 138, 375, 525, 411, 305, 375, 202, 380],
                    red: [498, 112, 318, 475, 371, 244, 335, 155, 355]
                )
            ),
            CourseNineLoop(
                id: "calatagan-in", name: "In",
                pars: [4, 3, 4, 5, 4, 4, 3, 4, 5],
                teeYards: gbwr(
                    gold: [410, 155, 385, 498, 355, 400, 197, 375, 568],
                    blue: [410, 155, 385, 498, 355, 400, 197, 375, 568],
                    white: [393, 137, 340, 488, 325, 385, 170, 360, 550],
                    red: [363, 105, 305, 454, 273, 333, 141, 300, 485]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "calatagan-out", inId: "calatagan-in", layoutName: "Championship")
        ]
    )

    // MARK: - Wack Wack East / West

    private static let wackWack = GolfClubCatalogEntry(
        id: "ph-wack-wack",
        name: "Wack Wack Golf & Country Club",
        location: "Mandaluyong, Metro Manila",
        region: "Metro Manila",
        nines: [
            CourseNineLoop(
                id: "east-out", name: "East Out",
                pars: [4, 4, 4, 4, 5, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [406, 375, 342, 339, 576, 430, 341, 170, 426],
                    blue: [388, 357, 313, 326, 567, 411, 332, 156, 415],
                    white: [343, 326, 300, 304, 538, 363, 332, 143, 401],
                    red: [325, 259, 369, 267, 480, 296, 254, 116, 353]
                )
            ),
            CourseNineLoop(
                id: "east-in", name: "East In",
                pars: [4, 4, 4, 5, 4, 4, 3, 4, 4],
                teeYards: gbwr(
                    gold: [386, 362, 440, 504, 433, 379, 198, 406, 435],
                    blue: [369, 345, 414, 490, 415, 368, 186, 400, 422],
                    white: [345, 332, 353, 445, 380, 337, 162, 383, 410],
                    red: [287, 278, 328, 391, 349, 328, 150, 321, 384]
                )
            ),
            CourseNineLoop(
                id: "west-out", name: "West Out",
                pars: [4, 4, 3, 5, 4, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [440, 370, 208, 509, 422, 354, 483, 139, 402],
                    blue: [416, 349, 175, 488, 399, 341, 451, 133, 382],
                    white: [392, 318, 147, 456, 376, 326, 393, 125, 302],
                    red: [368, 291, 114, 373, 339, 264, 378, 113, 267]
                )
            ),
            CourseNineLoop(
                id: "west-in", name: "West In",
                pars: [5, 3, 4, 5, 3, 4, 4, 4, 4],
                teeYards: gbwr(
                    gold: [498, 188, 386, 544, 153, 423, 361, 406, 371],
                    blue: [413, 170, 368, 520, 132, 401, 340, 374, 346],
                    white: [388, 151, 322, 485, 121, 382, 315, 347, 321],
                    red: [374, 130, 306, 425, 110, 353, 288, 302, 286]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "east-out", inId: "east-in", layoutName: "East"),
            CourseLayoutSuggestion(outId: "west-out", inId: "west-in", layoutName: "West"),
            CourseLayoutSuggestion(outId: "east-out", inId: "west-in", layoutName: "East Out / West In"),
            CourseLayoutSuggestion(outId: "west-out", inId: "east-in", layoutName: "West Out / East In")
        ]
    )

    // MARK: - Forest Hills — Palmer / Nicklaus

    private static let forestHills = GolfClubCatalogEntry(
        id: "ph-forest-hills",
        name: "Forest Hills Golf & Country Club",
        location: "Antipolo, Rizal",
        region: "Rizal",
        nines: [
            CourseNineLoop(
                id: "fh-palmer-out", name: "Palmer Out",
                pars: [4, 5, 4, 3, 4, 4, 4, 3, 5],
                teeYards: gbwr(
                    gold: [404, 516, 335, 194, 390, 417, 320, 195, 602],
                    blue: [368, 483, 298, 176, 330, 377, 275, 174, 562],
                    white: [309, 428, 257, 151, 271, 324, 221, 149, 518],
                    red: [278, 383, 224, 136, 248, 290, 212, 121, 457]
                )
            ),
            CourseNineLoop(
                id: "fh-palmer-in", name: "Palmer In",
                pars: [4, 4, 3, 4, 5, 3, 5, 4, 4],
                teeYards: gbwr(
                    gold: [352, 352, 160, 397, 610, 176, 565, 447, 376],
                    blue: [320, 319, 143, 356, 570, 160, 516, 443, 354],
                    white: [258, 290, 138, 321, 530, 135, 460, 399, 328],
                    red: [205, 265, 123, 315, 491, 113, 435, 355, 305]
                )
            ),
            CourseNineLoop(
                id: "fh-nicklaus-out", name: "Nicklaus Out",
                pars: [4, 4, 4, 3, 4, 5, 3, 4, 4],
                teeYards: gbwr(
                    gold: [428, 453, 356, 211, 434, 550, 202, 377, 398],
                    blue: [404, 439, 340, 178, 398, 541, 192, 349, 379],
                    white: [346, 407, 292, 174, 352, 474, 172, 293, 286],
                    red: [310, 356, 214, 147, 305, 428, 139, 247, 263]
                )
            ),
            CourseNineLoop(
                id: "fh-nicklaus-in", name: "Nicklaus In",
                pars: [5, 4, 4, 3, 4, 3, 5, 4, 4],
                teeYards: gbwr(
                    gold: [543, 455, 477, 181, 473, 211, 501, 425, 429],
                    blue: [505, 441, 459, 157, 424, 190, 483, 405, 400],
                    white: [460, 394, 391, 140, 376, 188, 445, 389, 345],
                    red: [422, 340, 331, 123, 354, 158, 421, 359, 318]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "fh-palmer-out", inId: "fh-palmer-in", layoutName: "Palmer"),
            CourseLayoutSuggestion(outId: "fh-nicklaus-out", inId: "fh-nicklaus-in", layoutName: "Nicklaus"),
            CourseLayoutSuggestion(outId: "fh-palmer-out", inId: "fh-nicklaus-in", layoutName: "Palmer Out / Nicklaus In"),
            CourseLayoutSuggestion(outId: "fh-nicklaus-out", inId: "fh-palmer-in", layoutName: "Nicklaus Out / Palmer In")
        ]
    )

    // MARK: - Sta. Elena — Banahaw / Makiling / Sierra Madre（3×9）

    private static let staElena = GolfClubCatalogEntry(
        id: "ph-sta-elena",
        name: "Sta. Elena Golf & Country Club",
        location: "Santa Rosa, Laguna",
        region: "Laguna",
        nines: [
            CourseNineLoop(
                id: "makiling", name: "Makiling",
                pars: [4, 3, 5, 4, 4, 4, 3, 5, 4],
                teeYards: gbwr(
                    gold: [404, 197, 570, 437, 420, 411, 191, 548, 439],
                    blue: [372, 159, 535, 409, 379, 376, 168, 487, 396],
                    white: [327, 140, 487, 377, 335, 340, 134, 468, 355],
                    red: [299, 109, 444, 316, 306, 317, 123, 436, 319]
                )
            ),
            CourseNineLoop(
                id: "banahaw", name: "Banahaw",
                pars: [5, 4, 4, 4, 3, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [566, 380, 463, 454, 177, 415, 539, 192, 420],
                    blue: [521, 334, 429, 434, 155, 365, 514, 186, 402],
                    white: [479, 291, 391, 387, 125, 336, 467, 161, 356],
                    red: [403, 278, 328, 337, 97, 306, 405, 133, 310]
                )
            ),
            CourseNineLoop(
                id: "sierra-madre", name: "Sierra Madre",
                pars: [4, 4, 3, 5, 4, 3, 4, 5, 4],
                teeYards: gbwr(
                    gold: [478, 420, 177, 517, 454, 211, 323, 583, 417],
                    blue: [440, 392, 154, 477, 423, 191, 289, 532, 385],
                    white: [403, 355, 135, 486, 394, 168, 258, 496, 356],
                    red: [362, 324, 105, 463, 368, 144, 228, 453, 327]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "makiling", inId: "banahaw", layoutName: "Makiling / Banahaw"),
            CourseLayoutSuggestion(outId: "banahaw", inId: "sierra-madre", layoutName: "Banahaw / Sierra Madre"),
            CourseLayoutSuggestion(outId: "sierra-madre", inId: "makiling", layoutName: "Sierra Madre / Makiling"),
            CourseLayoutSuggestion(outId: "banahaw", inId: "makiling", layoutName: "Banahaw / Makiling"),
            CourseLayoutSuggestion(outId: "sierra-madre", inId: "banahaw", layoutName: "Sierra Madre / Banahaw"),
            CourseLayoutSuggestion(outId: "makiling", inId: "sierra-madre", layoutName: "Makiling / Sierra Madre")
        ]
    )

    // MARK: - Ayala Greenfield

    private static let ayalaGreenfield = GolfClubCatalogEntry(
        id: "ph-ayala-greenfield",
        name: "Ayala Greenfield Golf & Leisure Club",
        location: "Calamba, Laguna",
        region: "Laguna",
        nines: [
            CourseNineLoop(
                id: "ag-out", name: "Out",
                pars: [4, 5, 3, 4, 4, 3, 4, 4, 5],
                teeYards: gbwr(
                    gold: [388, 553, 165, 421, 425, 145, 365, 399, 560],
                    blue: [368, 512, 147, 401, 402, 122, 342, 368, 536],
                    white: [353, 470, 122, 356, 370, 115, 306, 339, 501],
                    red: [331, 452, 102, 331, 347, 106, 278, 315, 384]
                )
            ),
            CourseNineLoop(
                id: "ag-in", name: "In",
                pars: [5, 3, 4, 5, 3, 4, 3, 5, 4],
                teeYards: gbwr(
                    gold: [482, 171, 404, 540, 210, 480, 175, 521, 391],
                    blue: [458, 137, 384, 515, 189, 456, 150, 480, 368],
                    white: [438, 124, 292, 425, 153, 430, 122, 455, 326],
                    red: [416, 113, 230, 406, 146, 304, 110, 414, 311]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "ag-out", inId: "ag-in", layoutName: "Championship")
        ]
    )

    // MARK: - The Country Club (Canlubang)

    private static let theCountryClub = GolfClubCatalogEntry(
        id: "ph-the-country-club",
        name: "The Country Club",
        location: "Canlubang, Calamba, Laguna",
        region: "Laguna",
        nines: [
            CourseNineLoop(
                id: "tcc-out", name: "Out",
                pars: [4, 5, 3, 4, 4, 3, 4, 5, 4],
                teeYards: gbwr(
                    gold: [467, 622, 171, 395, 460, 244, 452, 558, 482],
                    blue: [409, 562, 140, 344, 440, 200, 402, 502, 434],
                    red: [360, 495, 108, 273, 417, 140, 376, 440, 386]
                )
            ),
            CourseNineLoop(
                id: "tcc-in", name: "In",
                pars: [5, 3, 4, 4, 5, 4, 4, 3, 4],
                teeYards: gbwr(
                    gold: [550, 252, 387, 448, 598, 471, 458, 161, 476],
                    blue: [505, 221, 342, 405, 547, 434, 416, 148, 431],
                    red: [445, 191, 305, 365, 488, 408, 374, 118, 365]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "tcc-out", inId: "tcc-in", layoutName: "Championship")
        ]
    )

    // MARK: - Canlubang — North / South

    private static let canlubang = GolfClubCatalogEntry(
        id: "ph-canlubang",
        name: "Canlubang Golf & Country Club",
        location: "Calamba, Laguna",
        region: "Laguna",
        nines: [
            CourseNineLoop(
                id: "south-out", name: "South Out",
                pars: [4, 5, 4, 3, 4, 4, 4, 3, 5],
                teeYards: gbwr(
                    gold: [399, 493, 395, 164, 376, 397, 406, 200, 520],
                    blue: [399, 493, 395, 164, 376, 397, 406, 200, 520],
                    white: [344, 445, 335, 133, 352, 357, 376, 172, 482],
                    red: [315, 415, 321, 112, 333, 309, 348, 143, 472]
                )
            ),
            CourseNineLoop(
                id: "south-in", name: "South In",
                pars: [4, 5, 4, 3, 4, 4, 4, 3, 5],
                teeYards: gbwr(
                    gold: [462, 477, 405, 184, 409, 368, 426, 174, 540],
                    blue: [462, 477, 405, 184, 409, 368, 426, 174, 540],
                    white: [427, 451, 376, 153, 370, 302, 400, 150, 488],
                    red: [325, 423, 276, 95, 296, 236, 281, 121, 411]
                )
            ),
            CourseNineLoop(
                id: "north-out", name: "North Out",
                pars: [4, 5, 4, 3, 4, 3, 4, 4, 5],
                teeYards: gbwr(
                    gold: [424, 563, 400, 172, 370, 179, 382, 344, 552],
                    blue: [424, 563, 400, 172, 370, 179, 382, 344, 552],
                    white: [373, 525, 358, 168, 329, 164, 348, 326, 514],
                    red: [345, 477, 321, 111, 299, 141, 331, 308, 505]
                )
            ),
            CourseNineLoop(
                id: "north-in", name: "North In",
                pars: [4, 3, 4, 4, 5, 3, 4, 5, 4],
                teeYards: gbwr(
                    gold: [360, 192, 379, 455, 494, 187, 426, 564, 429],
                    blue: [360, 192, 379, 455, 494, 187, 426, 564, 429],
                    white: [357, 163, 359, 423, 451, 164, 388, 545, 394],
                    red: [283, 143, 332, 329, 421, 134, 373, 515, 330]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "south-out", inId: "south-in", layoutName: "South"),
            CourseLayoutSuggestion(outId: "north-out", inId: "north-in", layoutName: "North"),
            CourseLayoutSuggestion(outId: "south-out", inId: "north-in", layoutName: "South Out / North In"),
            CourseLayoutSuggestion(outId: "north-out", inId: "south-in", layoutName: "North Out / South In")
        ]
    )

    // MARK: - Manila Golf (Par 71)

    private static let manilaGolf = GolfClubCatalogEntry(
        id: "ph-manila-golf",
        name: "Manila Golf and Country Club",
        location: "Makati, Metro Manila",
        region: "Metro Manila",
        nines: [
            CourseNineLoop(
                id: "mg-out", name: "Out",
                pars: [4, 4, 3, 5, 4, 3, 5, 4, 4],
                teeYards: gbwr(
                    gold: [342, 463, 184, 509, 345, 151, 511, 443, 381],
                    blue: [342, 463, 184, 509, 345, 151, 511, 443, 381],
                    white: [306, 440, 165, 481, 323, 123, 483, 418, 355],
                    red: [285, 390, 148, 428, 268, 102, 440, 379, 332]
                )
            ),
            CourseNineLoop(
                id: "mg-in", name: "In",
                pars: [4, 3, 4, 4, 3, 5, 3, 4, 5],
                teeYards: gbwr(
                    gold: [371, 175, 383, 354, 176, 523, 200, 440, 534],
                    blue: [371, 175, 383, 354, 176, 523, 200, 440, 534],
                    white: [347, 147, 360, 318, 155, 500, 171, 434, 513],
                    red: [331, 133, 344, 290, 138, 435, 147, 334, 482]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "mg-out", inId: "mg-in", layoutName: "Championship")
        ]
    )

    // MARK: - Valley Golf — North / South

    private static let valleyGolf = GolfClubCatalogEntry(
        id: "ph-valley",
        name: "Valley Golf & Country Club",
        location: "Antipolo, Rizal",
        region: "Rizal",
        nines: [
            CourseNineLoop(
                id: "valley-south-out", name: "South Out",
                pars: [4, 4, 4, 3, 5, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [416, 453, 373, 202, 545, 412, 501, 223, 375],
                    blue: [402, 438, 361, 193, 525, 395, 486, 209, 365],
                    white: [375, 410, 338, 167, 505, 370, 458, 186, 345],
                    red: [352, 333, 323, 144, 480, 349, 421, 165, 324]
                )
            ),
            CourseNineLoop(
                id: "valley-south-in", name: "South In",
                pars: [4, 5, 3, 4, 4, 4, 4, 5, 3],
                teeYards: gbwr(
                    gold: [358, 504, 197, 433, 426, 401, 420, 538, 211],
                    blue: [318, 486, 183, 420, 413, 385, 404, 524, 195],
                    white: [287, 474, 166, 392, 391, 360, 378, 501, 170],
                    red: [263, 458, 135, 348, 356, 341, 322, 481, 154]
                )
            ),
            CourseNineLoop(
                id: "valley-north-out", name: "North Out",
                pars: [4, 4, 3, 4, 5, 3, 5, 3, 5],
                teeYards: gbwr(
                    gold: [360, 346, 192, 366, 521, 164, 476, 156, 469],
                    blue: [360, 346, 192, 366, 521, 164, 476, 156, 469],
                    white: [337, 321, 169, 315, 495, 139, 409, 125, 452],
                    red: [313, 268, 138, 290, 481, 114, 335, 112, 416]
                )
            ),
            CourseNineLoop(
                id: "valley-north-in", name: "North In",
                pars: [5, 3, 3, 5, 4, 3, 5, 4, 4],
                teeYards: gbwr(
                    gold: [418, 151, 145, 475, 288, 155, 427, 382, 348],
                    blue: [418, 151, 145, 475, 288, 155, 427, 382, 348],
                    white: [397, 137, 127, 465, 267, 137, 411, 327, 313],
                    red: [376, 122, 109, 390, 257, 126, 389, 299, 292]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "valley-south-out", inId: "valley-south-in", layoutName: "South"),
            CourseLayoutSuggestion(outId: "valley-north-out", inId: "valley-north-in", layoutName: "North"),
            CourseLayoutSuggestion(outId: "valley-south-out", inId: "valley-north-in", layoutName: "South Out / North In"),
            CourseLayoutSuggestion(outId: "valley-north-out", inId: "valley-south-in", layoutName: "North Out / South In")
        ]
    )

    // MARK: - Anvaya Cove — Mountain / Seaside

    private static let anvayaCove = GolfClubCatalogEntry(
        id: "ph-anvaya",
        name: "Anvaya Cove Golf & Sports Club",
        location: "Morong, Bataan",
        region: "Bataan",
        nines: [
            CourseNineLoop(
                id: "mountain", name: "Mountain",
                pars: [4, 5, 4, 4, 4, 3, 4, 3, 5],
                teeYards: gbwr(
                    gold: [383, 585, 332, 368, 438, 211, 423, 205, 598],
                    blue: [364, 569, 301, 342, 404, 180, 391, 150, 560],
                    white: [291, 516, 271, 279, 366, 163, 350, 118, 478],
                    red: [249, 424, 247, 246, 316, 141, 297, 95, 443]
                )
            ),
            CourseNineLoop(
                id: "seaside", name: "Seaside",
                pars: [5, 4, 4, 3, 4, 5, 3, 4, 4],
                teeYards: gbwr(
                    gold: [554, 332, 446, 155, 409, 613, 203, 385, 390],
                    blue: [554, 332, 446, 155, 409, 613, 203, 385, 390],
                    white: [554, 332, 446, 155, 409, 613, 203, 385, 390],
                    red: [554, 332, 446, 155, 409, 613, 203, 385, 390]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "mountain", inId: "seaside", layoutName: "Mountain / Seaside"),
            CourseLayoutSuggestion(outId: "seaside", inId: "mountain", layoutName: "Seaside / Mountain")
        ]
    )

    // MARK: - Luisita (Tarlac)

    private static let luisita = GolfClubCatalogEntry(
        id: "ph-luisita",
        name: "Luisita Golf & Country Club",
        location: "Tarlac City, Tarlac",
        region: "Central Luzon",
        nines: [
            CourseNineLoop(
                id: "luisita-out", name: "Out",
                pars: [4, 3, 4, 4, 5, 3, 4, 4, 5],
                teeYards: gbwr(
                    gold: [451, 192, 433, 402, 567, 220, 401, 366, 623],
                    blue: [420, 145, 356, 370, 505, 165, 370, 346, 508],
                    white: [400, 110, 340, 345, 475, 145, 350, 334, 480],
                    red: [370, 86, 327, 336, 455, 115, 335, 272, 440]
                )
            ),
            CourseNineLoop(
                id: "luisita-in", name: "In",
                pars: [4, 4, 5, 3, 4, 4, 5, 3, 4],
                teeYards: gbwr(
                    gold: [375, 429, 572, 160, 420, 395, 539, 214, 451],
                    blue: [350, 372, 496, 138, 382, 384, 512, 180, 383],
                    white: [330, 308, 480, 127, 333, 382, 496, 120, 367],
                    red: [305, 278, 450, 115, 320, 315, 470, 103, 327]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "luisita-out", inId: "luisita-in", layoutName: "Championship")
        ]
    )

    // MARK: - Mimosa Plus Clark — Mountainview / Acacia Lakeview

    private static let mimosa = GolfClubCatalogEntry(
        id: "ph-mimosa",
        name: "Mimosa Plus Golf Course",
        location: "Clark Freeport, Pampanga",
        region: "Central Luzon",
        nines: [
            CourseNineLoop(
                id: "mv-out", name: "Mountainview Out",
                pars: [5, 3, 4, 4, 5, 3, 4, 3, 4],
                teeYards: gbwr(
                    gold: [585, 171, 431, 320, 530, 171, 484, 195, 464],
                    blue: [552, 156, 392, 302, 500, 147, 459, 175, 436],
                    white: [530, 142, 370, 288, 469, 126, 433, 160, 398],
                    red: [441, 85, 338, 252, 412, 102, 350, 129, 334]
                )
            ),
            CourseNineLoop(
                id: "mv-in", name: "Mountainview In",
                pars: [5, 4, 4, 5, 3, 4, 3, 4, 5],
                teeYards: gbwr(
                    gold: [563, 418, 491, 562, 230, 477, 200, 374, 571],
                    blue: [531, 399, 465, 544, 212, 463, 151, 365, 548],
                    white: [510, 369, 443, 513, 196, 433, 126, 332, 513],
                    red: [445, 281, 351, 451, 178, 371, 83, 303, 465]
                )
            ),
            CourseNineLoop(
                id: "acacia-out", name: "Acacia Out",
                pars: [4, 4, 3, 4, 5, 3, 4, 4, 5],
                teeYards: gbwr(
                    gold: [445, 326, 133, 400, 494, 197, 416, 400, 493],
                    blue: [404, 284, 111, 382, 451, 167, 384, 367, 473],
                    white: [379, 265, 82, 371, 417, 146, 356, 334, 431],
                    red: [278, 231, 58, 290, 386, 122, 280, 270, 404]
                )
            ),
            CourseNineLoop(
                id: "acacia-in", name: "Acacia In",
                pars: [4, 3, 4, 3, 5, 4, 5, 4, 4],
                teeYards: gbwr(
                    gold: [388, 178, 349, 204, 558, 395, 489, 353, 328],
                    blue: [354, 136, 318, 165, 524, 366, 460, 318, 287],
                    white: [332, 107, 303, 128, 490, 348, 412, 270, 262],
                    red: [293, 90, 244, 95, 456, 279, 349, 238, 221]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "mv-out", inId: "mv-in", layoutName: "Mountainview"),
            CourseLayoutSuggestion(outId: "acacia-out", inId: "acacia-in", layoutName: "Acacia Lakeview"),
            CourseLayoutSuggestion(outId: "mv-out", inId: "acacia-in", layoutName: "Mountainview Out / Acacia In"),
            CourseLayoutSuggestion(outId: "acacia-out", inId: "mv-in", layoutName: "Acacia Out / Mountainview In")
        ]
    )

    // MARK: - Camp John Hay (Baguio) — Par 69

    private static let campJohnHay = GolfClubCatalogEntry(
        id: "ph-camp-john-hay",
        name: "Camp John Hay Golf Club",
        location: "Baguio, Benguet",
        region: "Cordillera",
        nines: [
            CourseNineLoop(
                id: "cjh-out", name: "Out",
                pars: [5, 4, 4, 3, 4, 3, 4, 4, 4],
                teeYards: gbwr(
                    gold: [530, 287, 369, 204, 285, 173, 325, 273, 326],
                    blue: [530, 287, 369, 204, 285, 173, 325, 273, 326],
                    white: [491, 258, 343, 178, 258, 132, 301, 252, 270],
                    red: [447, 218, 245, 132, 227, 104, 238, 209, 251]
                )
            ),
            CourseNineLoop(
                id: "cjh-in", name: "In",
                pars: [4, 3, 4, 3, 4, 3, 5, 5, 3],
                teeYards: gbwr(
                    gold: [302, 155, 285, 152, 368, 177, 549, 547, 178],
                    blue: [302, 155, 285, 152, 368, 177, 549, 547, 178],
                    white: [288, 142, 247, 121, 349, 155, 485, 483, 157],
                    red: [242, 118, 227, 83, 308, 121, 426, 454, 104]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "cjh-out", inId: "cjh-in", layoutName: "Championship")
        ]
    )

    // MARK: - Fairways & Bluewater (Boracay)

    private static let fairwaysBluewater = GolfClubCatalogEntry(
        id: "ph-fairways-bluewater",
        name: "Fairways & Bluewater Resort Golf Club",
        location: "Boracay, Aklan",
        region: "Visayas",
        nines: [
            CourseNineLoop(
                id: "fb-out", name: "Out",
                pars: [5, 4, 3, 4, 4, 5, 4, 3, 4],
                teeYards: gbwr(
                    gold: [531, 411, 171, 360, 386, 502, 392, 173, 363],
                    blue: [482, 389, 148, 326, 349, 468, 369, 142, 336],
                    white: [466, 371, 133, 291, 332, 450, 354, 123, 303],
                    red: [432, 350, 120, 264, 295, 415, 338, 103, 282]
                )
            ),
            CourseNineLoop(
                id: "fb-in", name: "In",
                pars: [5, 3, 4, 4, 5, 4, 3, 4, 4],
                teeYards: gbwr(
                    gold: [526, 152, 394, 322, 525, 369, 143, 422, 383],
                    blue: [511, 124, 363, 300, 502, 346, 131, 377, 371],
                    white: [490, 113, 348, 273, 479, 330, 117, 357, 348],
                    red: [462, 99, 326, 244, 455, 315, 100, 329, 313]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "fb-out", inId: "fb-in", layoutName: "Championship")
        ]
    )

    // MARK: - Alta Vista (Cebu)

    private static let altaVista = GolfClubCatalogEntry(
        id: "ph-alta-vista",
        name: "Alta Vista Golf & Country Club",
        location: "Cebu City, Cebu",
        region: "Visayas",
        nines: [
            CourseNineLoop(
                id: "av-out", name: "Out",
                pars: [4, 3, 4, 4, 4, 3, 5, 3, 5],
                teeYards: gbwr(
                    gold: [326, 159, 311, 336, 354, 150, 443, 180, 482],
                    blue: [326, 159, 311, 336, 354, 150, 443, 180, 482],
                    white: [317, 120, 286, 323, 332, 130, 421, 144, 461],
                    red: [308, 119, 257, 300, 306, 109, 376, 116, 432]
                )
            ),
            CourseNineLoop(
                id: "av-in", name: "In",
                pars: [5, 4, 4, 3, 4, 3, 5, 4, 5],
                teeYards: gbwr(
                    gold: [454, 403, 310, 148, 359, 215, 467, 396, 496],
                    blue: [454, 403, 310, 148, 359, 215, 467, 396, 496],
                    white: [424, 378, 290, 109, 314, 193, 425, 343, 467],
                    red: [396, 360, 263, 81, 281, 171, 401, 306, 437]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "av-out", inId: "av-in", layoutName: "Championship")
        ]
    )

    // MARK: - Apo Golf (Davao)

    private static let apoGolf = GolfClubCatalogEntry(
        id: "ph-apo",
        name: "Apo Golf & Country Club",
        location: "Davao City, Davao del Sur",
        region: "Mindanao",
        nines: [
            CourseNineLoop(
                id: "apo-out", name: "Out",
                pars: [4, 4, 5, 3, 4, 5, 3, 4, 4],
                teeYards: gbwr(
                    gold: [402, 450, 542, 245, 409, 582, 206, 383, 408],
                    blue: [389, 421, 536, 220, 400, 542, 195, 366, 398],
                    white: [375, 406, 530, 206, 390, 422, 170, 343, 389],
                    red: [335, 329, 479, 170, 342, 428, 134, 329, 340]
                )
            ),
            CourseNineLoop(
                id: "apo-in", name: "In",
                pars: [4, 3, 4, 5, 4, 4, 4, 3, 5],
                teeYards: gbwr(
                    gold: [410, 170, 470, 528, 434, 425, 346, 176, 493],
                    blue: [402, 150, 443, 511, 391, 404, 334, 165, 481],
                    white: [394, 137, 417, 502, 383, 396, 323, 153, 469],
                    red: [345, 126, 383, 421, 308, 322, 285, 139, 411]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "apo-out", inId: "apo-in", layoutName: "Championship")
        ]
    )

    // MARK: - Pueblo de Oro (Cagayan de Oro)

    private static let puebloDeOro = GolfClubCatalogEntry(
        id: "ph-pueblo-de-oro",
        name: "Pueblo de Oro Golf & Country Club",
        location: "Cagayan de Oro, Misamis Oriental",
        region: "Mindanao",
        nines: [
            CourseNineLoop(
                id: "pdo-out", name: "Out",
                pars: [4, 3, 5, 4, 4, 3, 5, 4, 4],
                teeYards: gbwr(
                    gold: [391, 199, 584, 405, 404, 213, 529, 415, 441],
                    blue: [357, 166, 549, 382, 347, 185, 502, 380, 405],
                    white: [324, 151, 518, 339, 310, 150, 447, 349, 361],
                    red: [262, 147, 465, 303, 266, 108, 401, 331, 328]
                )
            ),
            CourseNineLoop(
                id: "pdo-in", name: "In",
                pars: [4, 3, 4, 3, 4, 5, 4, 5, 4],
                teeYards: gbwr(
                    gold: [434, 177, 315, 180, 419, 547, 335, 568, 418],
                    blue: [403, 162, 299, 152, 390, 501, 291, 543, 371],
                    white: [379, 126, 271, 129, 371, 464, 262, 516, 336],
                    red: [316, 100, 243, 115, 335, 445, 233, 457, 310]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "pdo-out", inId: "pdo-in", layoutName: "Championship")
        ]
    )

    // MARK: - Rancho Palos Verdes (Davao)

    private static let ranchoPalosVerdes = GolfClubCatalogEntry(
        id: "ph-rancho-palos-verdes",
        name: "Rancho Palos Verdes Golf & Country Club",
        location: "Davao City, Davao del Sur",
        region: "Mindanao",
        nines: [
            CourseNineLoop(
                id: "rpv-out", name: "Out",
                pars: [5, 3, 4, 4, 4, 3, 4, 5, 4],
                teeYards: gbwr(
                    gold: [520, 251, 396, 375, 376, 212, 382, 509, 474],
                    blue: [452, 170, 363, 342, 353, 188, 354, 481, 437],
                    white: [403, 148, 336, 314, 322, 169, 324, 465, 396],
                    red: [371, 120, 283, 243, 300, 136, 286, 440, 360]
                )
            ),
            CourseNineLoop(
                id: "rpv-in", name: "In",
                pars: [4, 3, 5, 4, 4, 5, 4, 3, 4],
                teeYards: gbwr(
                    gold: [405, 196, 527, 408, 364, 576, 429, 196, 443],
                    blue: [391, 179, 496, 371, 342, 546, 403, 168, 414],
                    white: [363, 147, 457, 325, 312, 491, 369, 142, 376],
                    red: [315, 122, 317, 276, 303, 459, 340, 116, 311]
                )
            )
        ],
        suggestedLayouts: [
            CourseLayoutSuggestion(outId: "rpv-out", inId: "rpv-in", layoutName: "Championship")
        ]
    )
}
