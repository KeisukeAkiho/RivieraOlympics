import SwiftUI

/// オリンピック点数・独自ルール・ラスベガス拡張の編集フォーム
struct GameRulesSettingsView: View {
    @Binding var options: RoundOptions
    var isReadOnly: Bool = false

    @State private var newRuleName = ""
    @State private var newRulePoints = 1

    var body: some View {
        Form {
            Section {
                Text("この値で点数計算・ルールブック表示に反映されます（保存セットとして確定後）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("オリンピック点数") {
                pointStepper("金", value: $options.olympicsPoints.gold, range: 0...20)
                pointStepper("銀", value: $options.olympicsPoints.silver, range: 0...20)
                pointStepper("銅", value: $options.olympicsPoints.bronze, range: 0...20)
                pointStepper("鉄", value: $options.olympicsPoints.iron, range: 0...20)
                pointStepper("ダイヤ", value: $options.olympicsPoints.diamond, range: 0...20)
                pointStepper("竿", value: $options.olympicsPoints.pin, range: 0...20)
                pointStepper("竿後3パット", value: $options.olympicsPoints.pinThreePutt, range: -20...0)
                pointStepper("砂", value: $options.olympicsPoints.banker, range: 0...20)
                pointStepper("バーディー", value: $options.olympicsPoints.birdie, range: 0...50)
                pointStepper("イーグル", value: $options.olympicsPoints.eagle, range: 0...50)
                pointStepper("アルバトロス以上", value: $options.olympicsPoints.albatross, range: 0...50)
                pointStepper("ホールインワン", value: $options.olympicsPoints.holeInOne, range: 0...200)
                pointStepper("パーオン", value: $options.olympicsPoints.parOn, range: 0...20)
                pointStepper("Bオン", value: $options.olympicsPoints.birdieOn, range: 0...20)
                pointStepper("3パット", value: $options.olympicsPoints.threePutt, range: -20...0)
                pointStepper("オーバー3パット/打", value: $options.olympicsPoints.overThreePuttPerExtra, range: -10...0)
                pointStepper("舐め", value: $options.olympicsPoints.nameLick, range: -20...0)
                pointStepper("あわや", value: $options.olympicsPoints.awaya, range: -20...0)
                pointStepper("焼き鳥", value: $options.olympicsPoints.yakitori, range: -50...0)
                pointStepper("リーチ外れ基準", value: $options.olympicsPoints.reachMissDefaultBase, range: 1...20)
                pointStepper("ニアピン基礎", value: $options.olympicsPoints.nearestPinBase, range: 0...20)
                pointStepper("消防隊基礎", value: $options.olympicsPoints.firemanBase, range: 0...20)
                pointStepper("強制リーチ成功", value: $options.olympicsPoints.forcedReachSuccess, range: 0...50)
                pointStepper("強制リーチ失敗", value: $options.olympicsPoints.forcedReachFail, range: -50...0)
                Button("リビエラ既定値に戻す") {
                    options.olympicsPoints = .rivieraDefault
                }
                .disabled(isReadOnly)
            }

            Section("独自ルール") {
                ForEach($options.customPointRules) { $rule in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("名称", text: $rule.name)
                        Stepper("点数: \(rule.points > 0 ? "+" : "")\(rule.points)", value: $rule.points, in: -50...50)
                        Toggle("リーチ対象", isOn: $rule.appliesReach)
                        Toggle("有効", isOn: $rule.enabled)
                    }
                    .disabled(isReadOnly)
                }
                .onDelete { idx in
                    guard !isReadOnly else { return }
                    options.customPointRules.remove(atOffsets: idx)
                }

                if !isReadOnly {
                    HStack {
                        TextField("新ルール名", text: $newRuleName)
                        Stepper("\(newRulePoints > 0 ? "+" : "")\(newRulePoints)", value: $newRulePoints, in: -50...50)
                        Button("追加") {
                            let name = newRuleName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            options.customPointRules.append(
                                CustomPointRule(name: name, points: newRulePoints)
                            )
                            newRuleName = ""
                            newRulePoints = 1
                        }
                    }
                }
                Text("オリンピック入力でトグル表示されます。減点は負の点数にしてください。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("ラスベガス拡張ルール") {
                Toggle("前ホール順位でペア組替（1+4 vs 2+3）", isOn: $options.lasVegasRules.rotatePairsByPreviousHoleScore)
                Toggle("バーディーFlip（片方のみ→相手桁反転）", isOn: $options.lasVegasRules.birdieFlip)
                Toggle("イーグルFlip＋差分×2", isOn: $options.lasVegasRules.eagleFlipAndDouble)
                Toggle("チーム2バーディー→相手Flip＋×2", isOn: $options.lasVegasRules.twoBirdiesFlipAndDouble)
                Text("複数該当時は イーグル → 2バーディー → バーディー の優先度で一度だけ適用。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .disabled(isReadOnly)
        }
    }

    private func pointStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper("\(title): \(value.wrappedValue)", value: value, in: range)
            .disabled(isReadOnly)
    }
}
