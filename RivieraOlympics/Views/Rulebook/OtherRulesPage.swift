import SwiftUI

/// オリンピック以外のサイドゲーム・雑学
struct OtherRulesPage: View {
    @EnvironmentObject private var store: RoundStore
    var onEditParameters: (() -> Void)?

    private var lv: LasVegasRules { store.activeRulePreset.lasVegasRules }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introBanner
                activePresetBanner

                RuleSectionHeader(icon: "person.3.fill", title: "ホールマッチ", color: RivieraTheme.fairway)
                RuleCard(title: "全員対抗（個人戦）", icon: "flag.checkered") {
                    RuleParagraph(text: "そのホールで、いちばん少ない打数の人が1人だけなら、その人がホールをもらいます。")
                    RuleBullet(text: "同じ打数が2人以上 → 引き分け（だれももらえない）", icon: "equal.circle.fill")
                    RuleBullet(text: "もらったホールごとに、ほかの人から掛け金をもらう", icon: "yensign.circle.fill")
                    RuleTip(text: "例：4人・掛け金20 → 勝つと+60、ほかの人は一人ずつ−20")
                }
                RuleCard(title: "サイド対抗（1対3など）", icon: "person.2.fill", accent: .blue) {
                    RuleParagraph(text: "サイドAとサイドBに分けます。人数は自由です（1対1、1対3、2対2）。")
                    RuleParagraph(text: "各サイドの最少打数をくらべて、少ないほうがホール獲得。")
                    RuleBullet(text: "1対3で1人が勝つ → +掛け金×3、3人は各自−掛け金", icon: "1.circle.fill")
                    RuleBullet(text: "3人サイドが勝つ → 1人が−掛け金×3、3人は各自+掛け金", icon: "3.circle.fill")
                    RuleTip(text: "スコア表のホールマッチ欄をタップすると、勝ち・引き分けを手動で直せます。")
                }

                RuleSectionHeader(icon: "dice.fill", title: "ラスベガス", color: .indigo)
                RuleCard(title: "2対2のチーム戦", icon: "rectangle.split.2x1.fill", accent: .indigo) {
                    RuleParagraph(text: "チームの2人のスコアを、小さい順にならべてくっつけます。")
                    RuleBullet(text: "4と5 → 45", icon: "textformat.123")
                    RuleBullet(text: "3と10 → 310", icon: "textformat.123")
                    RuleParagraph(text: "チームの数字の差が大きいほど、そのホールの勝ちが大きくなります。")
                    Divider()
                    RuleParagraph(text: "いまのパラメータセット「\(store.activeRulePreset.name)」での拡張:")
                    lvToggleLine("前ホール順位でペア組替", lv.rotatePairsByPreviousHoleScore)
                    lvToggleLine("バーディーFlip", lv.birdieFlip)
                    lvToggleLine("イーグルFlip＋×2", lv.eagleFlipAndDouble)
                    lvToggleLine("チーム2バーディーFlip＋×2", lv.twoBirdiesFlipAndDouble)
                }

                RuleSectionHeader(icon: "building.columns.fill", title: "村長", color: .brown)
                RuleCard(title: "いちばん多い打数の人", icon: "crown.fill", accent: .brown) {
                    RuleParagraph(text: "みんなで掛け金を出し合います。")
                    RuleParagraph(text: "18ホール終わって、スコアがいちばん悪かった（打数が多かった）人が「村長」になって、お金のポットを全部もらいます。")
                    RuleTip(text: "同点のときは、ポットを分け合います。")
                }

                RuleSectionHeader(icon: "scribble.variable", title: "蛇", color: RivieraTheme.flag)
                RuleCard(title: "3パットに注意！", icon: "exclamationmark.triangle.fill", accent: RivieraTheme.flag) {
                    RuleParagraph(text: "パットを3回も打っちゃうと「蛇」がつきます。")
                    RuleBullet(text: "3パットするたびに、蛇の人がかわり、ポットが増える", icon: "arrow.left.arrow.right")
                    RuleBullet(text: "前半の終わり・後半の終わりで精算（アプリの設定で変更可）", icon: "clock.fill")
                    RuleBullet(text: "最後に蛇を持っている人が払う", icon: "yensign.circle")
                    RuleTip(text: "18ホールずっとためると大きくなりすぎるので、9ホールごとに払うのがおすすめです。")
                }

                RuleSectionHeader(icon: "person.fill.checkmark", title: "オネストジョン", color: .cyan)
                RuleCard(title: "正直に予想しよう", icon: "hand.raised.fill", accent: .cyan) {
                    RuleParagraph(text: "はじめる前に「今日は何打くらいで回れるかな？」と自分のスコアを言います。")
                    PointBadge(label: "予想どおり", points: "0（いちばん良い）")
                    PointBadge(label: "予想より良い（1打ごと）", points: "+1")
                    PointBadge(label: "予想より悪い（1打ごと）", points: "+2", positive: false)
                    RuleParagraph(text: "この点数は少ないほど勝ちです。正直に言うゲームなので「オネスト（正直）」ジョンといいます。")
                    RuleTip(text: "例：予想100で97 → 3点。予想100で105 → 10点。")
                }

                RuleSectionHeader(icon: "book.fill", title: "ゴルフの雑学", color: .gray)
                RuleCard(title: "ことばカード", icon: "text.book.closed.fill", accent: .gray) {
                    RuleBullet(text: "パー … そのホールのきまった打数", icon: "p.circle.fill")
                    RuleBullet(text: "バーディー … パーより1打少ない", icon: "bird.fill")
                    RuleBullet(text: "ボギー … パーより1打多い", icon: "arrow.up.circle")
                    RuleBullet(text: "Fore! … 危ない球のときのかけ声", icon: "megaphone.fill")
                }
                RuleCard(title: "やさしいマナー", icon: "heart.fill", accent: .pink) {
                    RuleBullet(text: "打っている人の近くで動かない・しゃべらない", icon: "ear")
                    RuleBullet(text: "芝をけったらなおす。砂場はならす", icon: "leaf.fill")
                    RuleBullet(text: "前の組がまだ近いときは打たない", icon: "figure.walk")
                }

                Text("このページはオリンピック公式PDF以外の遊び方です。LV拡張のON/OFFは「パラメータ」タブで変えられます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .padding()
        }
        .background(pageBackground)
    }

    private func lvToggleLine(_ title: String, _ on: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(on ? "ON" : "OFF")
                .font(.caption.weight(.bold))
                .foregroundStyle(on ? RivieraTheme.fairway : .secondary)
        }
    }

    private var activePresetBanner: some View {
        Button {
            onEditParameters?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                VStack(alignment: .leading, spacing: 2) {
                    Text("表示中のセット")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(store.activeRulePreset.name)
                        .font(.subheadline.weight(.bold))
                }
                Spacer()
                Text("編集")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RivieraTheme.fairway)
            }
            .padding(12)
            .background(Color.indigo.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var introBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("その他のルール", systemImage: "puzzlepiece.extension.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
            Text("ホールマッチ・村長・蛇など")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
            Text("オリンピックと一緒に楽しめる、別の遊び方をまとめました。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [.indigo, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color.blue.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
