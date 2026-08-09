import SwiftUI

/// Shared toggles for which competitions are active in a round.
struct CompetitionGamesSection: View {
    @Binding var options: RoundOptions
    var enabled: Bool = true
    var showFooter: Bool = true

    var body: some View {
        Section {
            Toggle("オリンピック", isOn: $options.olympicsEnabled)
            Toggle("ホールマッチ", isOn: $options.holeMatchEnabled)
            Toggle("ラスベガス", isOn: $options.lasVegasEnabled)
            Toggle("村長", isOn: $options.sonchoEnabled)
            Toggle("蛇", isOn: $options.snakeEnabled)
            if options.snakeEnabled {
                Toggle("蛇を9ホール毎に精算", isOn: $options.snakeSettlePerNine)
            }
            Toggle("オネストジョン", isOn: $options.honestJohnEnabled)
            Toggle("ペナルティ", isOn: $options.penaltiesEnabled)
        } header: {
            Text("競技内容")
        } footer: {
            if showFooter {
                Text(footerText)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!enabled)
    }

    private var footerText: String {
        let names = Self.enabledGameNames(options)
        if names.isEmpty {
            return "有効な競技がありません。スコア入力のみになります。"
        }
        return "有効: " + names.joined(separator: "・")
    }

    static func enabledGameNames(_ options: RoundOptions) -> [String] {
        var names: [String] = []
        if options.olympicsEnabled { names.append("オリンピック") }
        if options.holeMatchEnabled { names.append("ホールマッチ") }
        if options.lasVegasEnabled { names.append("ラスベガス") }
        if options.sonchoEnabled { names.append("村長") }
        if options.snakeEnabled { names.append("蛇") }
        if options.honestJohnEnabled { names.append("オネストジョン") }
        return names
    }

    static func summaryLabel(_ options: RoundOptions) -> String {
        let names = enabledGameNames(options)
        return names.isEmpty ? "なし" : names.joined(separator: "・")
    }
}
