import SwiftUI

struct RulebookView: View {
    enum RuleTab: String, CaseIterable, Identifiable {
        case olympics = "オリンピック"
        case other = "その他"
        case parameters = "パラメータ"
        case pdf = "公式PDF"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .olympics: return "medal.fill"
            case .other: return "puzzlepiece.extension.fill"
            case .parameters: return "slider.horizontal.3"
            case .pdf: return "doc.richtext.fill"
            }
        }
    }

    @State private var tab: RuleTab = .olympics

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("ルールブック")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    ForEach(RuleTab.allCases) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { tab = item }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.icon)
                                    .font(.body)
                                Text(item.rawValue)
                                    .font(.system(size: 10, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(tab == item ? Color.white : RivieraTheme.fairwayDeep)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(tab == item ? RivieraTheme.fairway : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(RivieraTheme.fairway.opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(RivieraTheme.sand.opacity(0.45))

            Divider()

            Group {
                switch tab {
                case .olympics:
                    OlympicsRulesPage(onEditParameters: { tab = .parameters })
                case .other:
                    OtherRulesPage(onEditParameters: { tab = .parameters })
                case .parameters:
                    RuleParametersPage()
                case .pdf:
                    OfficialPDFPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
