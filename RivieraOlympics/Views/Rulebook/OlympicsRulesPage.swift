import SwiftUI

/// 公式オリンピックルール（有効パラメータセットの点数と同期）
struct OlympicsRulesPage: View {
    @EnvironmentObject private var store: RoundStore
    var onEditParameters: (() -> Void)?

    private var pts: OlympicsPointRules { store.activeRulePreset.olympicsPoints }
    private var customRules: [CustomPointRule] {
        store.activeRulePreset.customPointRules.filter(\.enabled)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introBanner
                activePresetBanner

                RuleSectionHeader(icon: "medal.fill", title: "まずはここから", color: RivieraTheme.fairway)
                RuleCard(title: "オリンピックってなに？", icon: "flag.circle.fill") {
                    RuleParagraph(text: "みんながカップに近づけた順番や、上手なプレーに点をつけ合うゲームです。")
                    RuleParagraph(text: "点が多いほどよいです。あとで掛け金率（20・50・100など）をかけて、おたがいの精算に使います。")
                    RuleTip(text: "お金を賭けるのはだめです。なかよしの点数ゲームとして楽しもう！")
                }

                RuleSectionHeader(icon: "crown.fill", title: "基本のメダル", color: .yellow)
                RuleCard(title: "ダイヤ（外チップ）", icon: "diamond.fill", accent: .yellow) {
                    RuleParagraph(text: "グリーンの外からカップに入れたらダイヤです。金銀銅鉄の入力はありません。五輪点はスコア画面の ± で入れます。")
                    PointBadge(label: "ダイヤ", points: signed(pts.diamond))
                }

                RuleSectionHeader(icon: "star.fill", title: "プラスの特別点", color: .blue)
                RuleCard(title: "竿（ピン）", icon: "ruler", accent: .blue) {
                    RuleBullet(text: "「竿！」と宣言する", icon: "1.circle.fill")
                    RuleBullet(text: "カップまでピン1本分より遠い", icon: "2.circle.fill")
                    PointBadge(label: "成功", points: signed(pts.pin))
                    PointBadge(label: "竿失敗（宣言して入らず）", points: signed(pts.pinThreePutt), positive: pts.pinThreePutt >= 0)
                }
                RuleCard(title: "外竿", icon: "arrow.up.forward.circle.fill", accent: .blue) {
                    RuleParagraph(text: "グリーンの外から竿を宣言する特別ルールです。")
                    PointBadge(label: "チップイン成功", points: signed(pts.pin))
                    PointBadge(label: "グリーンで2打目も入らず", points: signed(pts.pinThreePutt), positive: pts.pinThreePutt >= 0)
                    RuleTip(text: "外竿を言ったら、ほかの人も竿を宣言したことになります。")
                }
                RuleCard(title: "砂（バンカー）", icon: "beach.umbrella.fill", accent: .orange) {
                    RuleParagraph(text: "砂場（バンカー）から打って、1パットで入れる（または直接入れる）。宣言はいりません。")
                    PointBadge(label: "砂", points: signed(pts.banker))
                }
                RuleCard(title: "バーディー・イーグル・ホールインワン", icon: "bird.fill", accent: .mint) {
                    PointBadge(label: "バーディー（1打少ない）", points: signed(pts.birdie))
                    PointBadge(label: "イーグル（2打少ない）", points: signed(pts.eagle))
                    PointBadge(label: "アルバトロス以上", points: signed(pts.albatross))
                    PointBadge(label: "ホールインワン", points: signed(pts.holeInOne))
                    RuleTip(text: "ホールインワンのときは、ほかの点もいっしょにもらえることがあります。")
                }
                RuleCard(title: "パーオン / バーディーオン", icon: "arrow.down.circle.fill", accent: .teal) {
                    PointBadge(label: "パーオン（バーディーパットになった）", points: signed(pts.parOn))
                    PointBadge(label: "バーディーオン（イーグルパット）", points: signed(pts.birdieOn))
                    RuleParagraph(text: "たとえばパー4で2オンならパーオン、1オンならバーディーオンです。")
                }

                RuleSectionHeader(icon: "flame.fill", title: "ニアピンと消防隊", color: .red)
                RuleCard(title: "ニアピン", icon: "scope", accent: RivieraTheme.flag) {
                    RuleParagraph(text: "ショートホールなどで、1打目がいちばんカップに近い人に権利がつきます。")
                    RuleParagraph(text: "パーかバーディーで上がると点がもらえます。回数（繰り越し）が多いほど点が大きくなります。")
                    PointBadge(label: "ニアピン（基礎×階建て）", points: "\(signed(pts.nearestPinBase))×回数")
                }
                RuleCard(title: "消防隊", icon: "flame.circle.fill", accent: .orange) {
                    RuleParagraph(text: "ほかの人のニアピン権利を「消す」ことができるルールです。消えた権利は次のホールへ持ち越し。")
                    RuleBullet(text: "グリーンに乗っていないのにパー／バーディー、相手はパー")
                    RuleBullet(text: "グリーンに乗ってバーディー、相手はパー")
                    RuleBullet(text: "グリーン外からバーディーで消す（2025年8月追加）")
                    PointBadge(label: "消防隊", points: "\(signed(pts.firemanBase))×回数")
                    RuleTip(text: "相手がバーディーのときは、消防隊は成功しません。")
                }

                RuleSectionHeader(icon: "exclamationmark.triangle.fill", title: "マイナスの点", color: RivieraTheme.flag)
                RuleCard(title: "気をつけよう", icon: "hand.raised.fill", accent: RivieraTheme.flag) {
                    PointBadge(label: "3パット", points: signed(pts.threePutt), positive: pts.threePutt >= 0)
                    PointBadge(label: "竿失敗", points: signed(pts.pinThreePutt), positive: pts.pinThreePutt >= 0)
                    PointBadge(label: "4パット目から（1打ごと）", points: signed(pts.overThreePuttPerExtra), positive: pts.overThreePuttPerExtra >= 0)
                    PointBadge(label: "舐め（カップの淵で曲がった）", points: signed(pts.nameLick), positive: pts.nameLick >= 0)
                    PointBadge(label: "あわや（カラーに止まった）", points: signed(pts.awaya), positive: pts.awaya >= 0)
                    Divider()
                    RuleParagraph(text: "舐めはグリーンの上だけ。あわやはグリーンのすぐ外の短い芝（だいたい40cm）です。")
                }

                if !customRules.isEmpty {
                    RuleSectionHeader(icon: "plus.circle.fill", title: "独自ルール", color: .indigo)
                    RuleCard(title: "このセットの追加点", icon: "list.bullet", accent: .indigo) {
                        ForEach(customRules) { rule in
                            PointBadge(
                                label: rule.name + (rule.appliesReach ? "（リーチ対象）" : ""),
                                points: signed(rule.points),
                                positive: rule.points >= 0
                            )
                        }
                    }
                }

                RuleSectionHeader(icon: "bolt.fill", title: "リーチ", color: .purple)
                RuleCard(title: "リーチ宣言", icon: "sparkles", accent: .purple) {
                    RuleParagraph(text: "「リーチ！」と言うと、そのときの点が2倍になります。外すとマイナスも2倍です。")
                    PointBadge(label: "リーチ外れの基準点", points: "\(pts.reachMissDefaultBase)")
                    RuleTip(text: "ニアピン点・消防隊・あわやなどはリーチの2倍になりません。")
                }
                RuleCard(title: "リーチのやくそく", icon: "calendar", accent: .purple) {
                    RuleParagraph(text: "前半9ホールと後半9ホールで、それぞれ1回はリーチを宣言しましょう。")
                    RuleParagraph(text: "言わなかったら、最後のホールの1パット目が強制リーチになります。")
                    PointBadge(label: "強制リーチ成功", points: signed(pts.forcedReachSuccess))
                    PointBadge(label: "強制リーチ失敗", points: signed(pts.forcedReachFail), positive: pts.forcedReachFail >= 0)
                }

                RuleSectionHeader(icon: "fork.knife", title: "焼き鳥", color: .brown)
                RuleCard(title: "1パットがないと…", icon: "bird", accent: .brown) {
                    RuleParagraph(text: "前半・後半それぞれで、1パットを1回もしないと「焼き鳥」です。")
                    PointBadge(label: "焼き鳥", points: signed(pts.yakitori), positive: pts.yakitori >= 0)
                    RuleTip(text: "昔あった「リセット焼き鳥」は今はありません（2016年ごろ廃止）。")
                }

                footerNote
            }
            .padding()
        }
        .background(pageBackground)
    }

    private func signed(_ n: Int) -> String {
        n > 0 ? "+\(n)" : "\(n)"
    }

    private var activePresetBanner: some View {
        Button {
            onEditParameters?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 2) {
                    Text("表示中の点数セット")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(store.activeRulePreset.name)
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
                Text("編集")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RivieraTheme.fairway)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RivieraTheme.fairway.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var introBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("公式ルール", systemImage: "doc.richtext.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
            Text("リビエラ会オリンピック")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("点数は「パラメータ」タブの選択セットと同期しています。")
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
        Text("くわしい原文は「公式PDF」タブで見られます。点数の編集は「パラメータ」タブです。")
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
