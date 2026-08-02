import SwiftUI

struct RuleSectionHeader: View {
    let icon: String
    let title: String
    var color: Color = RivieraTheme.fairway

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct RuleCard<Content: View>: View {
    let title: String
    var icon: String = "checkmark.seal.fill"
    var accent: Color = RivieraTheme.fairway
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            Divider()
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RivieraTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct RuleParagraph: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(4)
    }
}

struct RuleTip: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct PointBadge: View {
    let label: String
    let points: String
    var positive: Bool = true

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(points)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(.white)
                .background(positive ? RivieraTheme.fairway : RivieraTheme.flag)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

struct RuleBullet: View {
    let text: String
    var icon: String = "circle.fill"

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(RivieraTheme.fairway)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
