# リビエラオリンピック (RivieraOlympics)

リビエラ会のゴルフ・オリンピック採点アプリ（iPhone / iPad）。

## アプリ名

| 項目 | 値 |
|------|-----|
| 表示名 | **リビエラオリンピック** |
| プロジェクト名 | `RivieraOlympics` |
| Bundle ID | `org.shinkosha.pogi.rivieraolympics` |

## 主な機能

- スコア入力（◎○－□■ 記号）
- オリンピック点・竿・砂・リーチ・舐め・あわやなど
- プレイヤー登録（ホームコース等）と生涯握り戦績
- ホールマッチ / ラスベガス / 村長 / 蛇 / オネストジョン
- 公式ルールPDF同梱・ルールブック

## ビルド

1. Xcode をインストール
2. `project.yml` から生成（親リポジトリ `PogiApple` の `Config/Signing.xcconfig` を参照）
3. または既存の `RivieraOlympics.xcodeproj` を開く

USB デプロイ（PogiApple ルートから）:

```bash
./Scripts/deploy_usb.sh RivieraOlympics
```

## 注意

賭けゴルフは違法です。掛け金は親睦内の精算単位として扱ってください。
