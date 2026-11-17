# MockReference ── Later モック v52 の「正解データ」

この フォルダは **アプリを モックと 同じに するための 見本 一式**です。リポジトリの `Design/MockReference/` に 置いてください(アプリの ビルドには 含めない)。

| フォルダ | 中身 | 使い方 |
|---|---|---|
| `screens/` | モックの 画面 27枚(390 × 844pt を 2倍の 画像で) | **見た目の 正解**。実機の スクショと 並べて 比べる |
| `spec/SCREEN_MAP.md` | 画面ごとの 入口・中身・元コードの 場所・実機で ずれていた 所 | **最初に 読む** |
| `spec/TOKENS.md` | 色・書体・角丸 | 色と 書体は ここ以外の 値を 使わない |
| `spec/MEASURED_SPEC.md` | 全部品の 位置・大きさ・書体・色・角丸・影・ぼかし(自動計測) | **数字の 正解**。CSS より こちらを 優先 |
| `spec/ANIMATIONS.md` | すべての アニメーション(長さ・遅れ・カーブ・キーフレーム) | 動きは この 値で 作る |
| `spec/HAPTICS.md` | すべての バイブ(種類・強さ・タイミング・呼ばれる 場所) | バイブは この 表で 作る |
| `mock/later_v52.html` | モック 本体(Safari / Chrome で 開ける) | 動きを 自分の 目で 確かめる |
| `mock/src/` | モックの 元コード(CSS / HTML / JS) | 細かい 動き・条件を 調べる |
| `tools/compare.py` | モック画像と シミュレータの スクショを 並べて、差分を 赤で 出す | 直すたびに 実行する |

## 画像の 番号

- `A` = Home(today)・ライブパネル ・ 下スクロール
- `B` = Later yesterday(Groups / Mondo)
- `C` = Friend ・ ME ・ Recap
- `D` = Profile ・ Edit
- `N` = 夜(21:00〜9:00)の 色

## 比べ方

```bash
xcrun simctl io booted screenshot /tmp/sim_D01.png
python3 Design/MockReference/tools/compare.py \
  Design/MockReference/screens/D01_profile.png /tmp/sim_D01.png \
  Design/MockReference/compare_out/D01.png
```
左が モック、まんなかが 実機、右が 重ね合わせ(赤 = ずれ)。`score` は 0 に 近いほど 同じ。
