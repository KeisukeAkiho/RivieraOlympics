import SwiftUI

/// 公式オリンピックルール（PDF準拠・わかりやすい表示）
struct OlympicsRulesPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introBanner

                RuleSectionHeader(icon: "medal.fill", title: "まずはここから", color: RivieraTheme.fairway)
                RuleCard(title: "オリンピックってなに？", icon: "flag.circle.fill") {
                    RuleParagraph(text: "みんながカップに近づけた順番や、上手なプレーに点をつけ合うゲームです。")
                    RuleParagraph(text: "点が多いほどよいです。あとで掛け金率（20・50・100など）をかけて、おたがいの精算に使います。")
                    RuleTip(text: "お金を賭けるのはだめです。なかよしの点数ゲームとして楽しもう！")
                }

                RuleSectionHeader(icon: "crown.fill", title: "基本のメダル", color: .yellow)
                RuleCard(title: "カップから遠い人から点", icon: "target", accent: .yellow) {
                    RuleParagraph(text: "グリーンのまわりで、カップから遠いボールの人から順番にメダルがもらえます。")
                    PointBadge(label: "ダイヤ（グリーン外から入れた）", points: "+5")
                    PointBadge(label: "金（いちばん遠い）", points: "+4")
                    PointBadge(label: "銀", points: "+3")
                    PointBadge(label: "銅", points: "+2")
                    PointBadge(label: "鉄（いちばん近い）", points: "+1")
                    Divider()
                    RuleTip(text: "グリーンの外からボールを入れたら「ダイヤ」だよ！")
                }

                RuleSectionHeader(icon: "star.fill", title: "プラスの特別点", color: .blue)
                RuleCard(title: "竿（ピン）", icon: "ruler", accent: .blue) {
                    RuleBullet(text: "「竿！」と宣言する", icon: "1.circle.fill")
                    RuleBullet(text: "カップまでピン1本分より遠い", icon: "2.circle.fill")
                    PointBadge(label: "成功", points: "+2")
                    PointBadge(label: "宣言したのに3パット", points: "−2", positive: false)
                }
                RuleCard(title: "外竿", icon: "arrow.up.forward.circle.fill", accent: .blue) {
                    RuleParagraph(text: "グリーンの外から竿を宣言する特別ルールです。")
                    PointBadge(label: "チップイン成功", points: "+2")
                    PointBadge(label: "グリーンで2打目も入らず", points: "−2", positive: false)
                    RuleTip(text: "外竿を言ったら、ほかの人も竿を宣言したことになります。")
                }
                RuleCard(title: "砂（バンカー）", icon: "beach.umbrella.fill", accent: .orange) {
                    RuleParagraph(text: "砂場（バンカー）から打って、1パットで入れる（または直接入れる）。宣言はいりません。")
                    PointBadge(label: "砂", points: "+2")
                }
                RuleCard(title: "バーディー・イーグル・ホールインワン", icon: "bird.fill", accent: .mint) {
                    PointBadge(label: "バーディー（1打少ない）", points: "+3")
                    PointBadge(label: "イーグル（2打少ない）", points: "+10")
                    PointBadge(label: "ホールインワン", points: "+100")
                    RuleTip(text: "ホールインワンのときは、ほかの点もいっしょにもらえることがあります。")
                }
                RuleCard(title: "パーオン / バーディーオン", icon: "arrow.down.circle.fill", accent: .teal) {
                    PointBadge(label: "パーオン（バーディーパットになった）", points: "+1")
                    PointBadge(label: "バーディーオン（イーグルパット）", points: "+3")
                    RuleParagraph(text: "たとえばパー4で2オンならパーオン、1オンならバーディーオンです。")
                }

                RuleSectionHeader(icon: "flame.fill", title: "ニアピンと消防隊", color: .red)
                RuleCard(title: "ニアピン", icon: "scope", accent: RivieraTheme.flag) {
                    RuleParagraph(text: "ショートホールなどで、1打目がいちばんカップに近い人に権利がつきます。")
                    RuleParagraph(text: "パーかバーディーで上がると点がもらえます。回数（繰り越し）が多いほど点が大きくなります。")
                    PointBadge(label: "ニアピン（繰り越し×3）", points: "+3×回数")
                }
                RuleCard(title: "消防隊", icon: "flame.circle.fill", accent: .orange) {
                    RuleParagraph(text: "ほかの人のニアピン権利を「消す」ことができるルールです。消えた権利は次のホールへ持ち越し。")
                    RuleBullet(text: "グリーンに乗っていないのにパー／バーディー、相手はパー")
                    RuleBullet(text: "グリーンに乗ってバーディー、相手はパー")
                    RuleBullet(text: "グリーン外からバーディーで消す（2025年8月追加）")
                    PointBadge(label: "消防隊", points: "+1×回数")
                    RuleTip(text: "相手がバーディーのときは、消防隊は成功しません。")
                }

                RuleSectionHeader(icon: "exclamationmark.triangle.fill", title: "マイナスの点", color: RivieraTheme.flag)
                RuleCard(title: "気をつけよう", icon: "hand.raised.fill", accent: RivieraTheme.flag) {
                    PointBadge(label: "3パット", points: "−1", positive: false)
                    PointBadge(label: "4パット目から（1打ごと）", points: "−1", positive: false)
                    PointBadge(label: "舐め（カップの淵で曲がった）", points: "−1", positive: false)
                    PointBadge(label: "あわや（カラーに止まった）", points: "−1", positive: false)
                    Divider()
                    RuleParagraph(text: "舐めはグリーンの上だけ。あわやはグリーンのすぐ外の短い芝（だいたい40cm）です。")
                }

                RuleSectionHeader(icon: "bolt.fill", title: "リーチ", color: .purple)
                RuleCard(title: "リーチ宣言", icon: "sparkles", accent: .purple) {
                    RuleParagraph(text: "「リーチ！」と言うと、そのときの点が2倍になります。外すとマイナスも2倍です。")
                    PointBadge(label: "2点のパットをリーチして成功", points: "+4")
                    PointBadge(label: "同じパットを外す", points: "−4", positive: false)
                    PointBadge(label: "外して＋舐め", points: "−5", positive: false)
                    RuleTip(text: "ニアピン点・消防隊・あわやなどはリーチの2倍になりません。")
                }
                RuleCard(title: "リーチのやくそく", icon: "calendar", accent: .purple) {
                    RuleParagraph(text: "前半9ホールと後半9ホールで、それぞれ1回はリーチを宣言しましょう。")
                    RuleParagraph(text: "言わなかったら、最後のホールの1パット目が強制リーチになります（成功なら5×2=10）。")
                }

                RuleSectionHeader(icon: "fork.knife", title: "焼き鳥", color: .brown)
                RuleCard(title: "1パットがないと…", icon: "bird", accent: .brown) {
                    RuleParagraph(text: "前半・後半それぞれで、1パットを1回もしないと「焼き鳥」です。")
                    PointBadge(label: "焼き鳥", points: "−5", positive: false)
                    RuleTip(text: "昔あった「リセット焼き鳥」は今はありません（2016年ごろ廃止）。")
                }

                footerNote
            }
            .padding()
        }
        .background(pageBackground)
    }

    private var introBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("公式ルール", systemImage: "doc.richtext.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
            Text("リビエラ会オリンピック")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("最終更新 2025年8月26日\nPDFの内容を、わかりやすくまとめています。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [RivieraTheme.fairwayDeep, RivieraTheme.fairway], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footerNote: some View {
        Text("くわしい原文は「公式PDF」タブで見られます。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), RivieraTheme.sand.opacity(0.25)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
