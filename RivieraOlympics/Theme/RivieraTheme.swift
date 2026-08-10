import SwiftUI

enum RivieraTheme {
    static let fairway = Color(red: 0.09, green: 0.47, blue: 0.30)
    static let fairwayDeep = Color(red: 0.05, green: 0.28, blue: 0.18)
    static let sand = Color(red: 0.93, green: 0.86, blue: 0.68)
    static let flag = Color(red: 0.86, green: 0.20, blue: 0.20)
    static let card = Color.white.opacity(0.94)
}

/// Auto-assigned theme colors by player order (1st, 2nd, …) to reduce mix-ups.
enum PlayerTheme {
    /// Distinct, readable tints (cycles if more players than palette size).
    static let palette: [Color] = [
        Color(red: 0.20, green: 0.55, blue: 0.92), // sky
        Color(red: 0.92, green: 0.42, blue: 0.28), // coral
        Color(red: 0.55, green: 0.38, blue: 0.88), // violet
        Color(red: 0.12, green: 0.68, blue: 0.58), // teal
        Color(red: 0.95, green: 0.62, blue: 0.18), // amber
        Color(red: 0.88, green: 0.28, blue: 0.52), // rose
        Color(red: 0.28, green: 0.42, blue: 0.78), // indigo
        Color(red: 0.42, green: 0.72, blue: 0.28), // lime
    ]

    static func color(at index: Int) -> Color {
        guard !palette.isEmpty else { return RivieraTheme.fairway }
        let i = ((index % palette.count) + palette.count) % palette.count
        return palette[i]
    }

    static func color(for playerId: UUID, in players: [Player]) -> Color {
        color(at: players.firstIndex(where: { $0.id == playerId }) ?? 0)
    }

    /// Soft row fill for score / olympics tables.
    static func rowFill(at index: Int, focused: Bool = false) -> Color {
        color(at: index).opacity(focused ? 0.42 : 0.16)
    }

    /// Stronger fill for the active olympics cell.
    static func cellFill(at index: Int, focused: Bool, rowFocused: Bool) -> Color {
        if focused { return color(at: index).opacity(0.55) }
        if rowFocused { return color(at: index).opacity(0.22) }
        return color(at: index).opacity(0.10)
    }

    /// Sheet / modal wash so input matches the player row.
    static func sheetBackground(at index: Int) -> Color {
        color(at: index).opacity(0.22)
    }

    static func bannerColors(at index: Int) -> [Color] {
        let base = color(at: index)
        return [base.opacity(0.95), base.opacity(0.72)]
    }
}
