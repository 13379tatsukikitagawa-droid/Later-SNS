# P00 ・ 準備(いまの アプリを 調べる ・ 土台を 作る ・ 名前を Lattag に)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P00_setup.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## ねらい

いまの 実機は **古い 版(v52 ごろ)** の まま(名前が Later、緑の 帯の カメラ、Yesterday の 下の タブが Mondo / Groups の まま、Mondo が 空 など)。
いきなり 画面を 作らず、**全部の フェーズで 使う 土台** を 先に 作る。

## やる こと

1. **調べる**:いまの SwiftUI の 画面 ・ ビュー ・ データの 流れを 一覧に して `Kit/MIGRATION_MAP.md` に 書く。
   - `Kit/screens/INDEX.md` の 76画面 それぞれに、「いまの どの View が あたるか / 無い か」を 表に する。
   - 消す もの(古い 写ルンです風の カード ・ 古い タブ など)も 書く。
2. **Brand**(名前):`Kit/prompts/reference/PROMPT_v62.md` の とおり。画面 ・ 文 ・ 共有 ・ 通知の「Later」を `Brand` に。URL スキーム `lattag://` を 足し、`later://` も のこす。
3. **Design System** を 1か所に:
   - `LGColor`(`Kit/spec/TOKENS.md` と 各 PROMPT の 色)/ `LGFont`(6書体。`UIAppFonts` に 登録、名前で 呼べるか テスト)
   - `Haptics.play(.tick …)`(`Kit/spec/HAPTICS.md` の 15種類。Core Haptics。同じ 名前が 短い 間に 続いたら 鳴らさない `gap`)
   - `LGMotion`(よく 使う カーブ:`(.3,1.4,.5,1)` `(.2,.8,.3,1)` `(.3,1.2,.4,1)` `(.3,1.6,.4,1)` などを 名前つきで)
   - `LGGlass`(すりガラス:iOS 26 `.glassEffect(.regular.interactive())` / それ より 前 `.ultraThinMaterial` + 白 + ふちの 光。**ふちの 光は 端末の かたむきで 動く**:`Kit/prompts/reference/PROMPT_v65.md` §6、Core Motion)
   - `LGPressable`(押すと 沈む / ふくらむ。44pt 以上の 押せる 範囲)
4. **DEBUG の 状態メニュー**(DEBUG ビルドだけ。画面を 3本指で 長押し などで 開く):モックの デモボタンと 同じ 項目。
   - 今日 撮った 枚数 0 / 1 / 2 / 3 ・ はじめての 日 ⇄ いつも ・ 友だち 0人 / 3人 ・ 申請が とどく ・ Trip を つくる(見本の Trip)・ 招待が とどく ・ 昼 ⇄ 夜 ・ 翌朝 9:00 に する ・ オープニングを もう一度 ・ はじめての 設定を もう一度 ・ ぜんぶ 最初から
   - **見本データ**(写真 ・ 友だち ・ Mondo の 投稿)を 入れられる ように(本物の データが 無くても 全画面を 確かめる ため。いま Mondo が 空 なのは 投稿が 無い ため)。
5. **見本と 比べる しくみ**:`scripts/snap.sh <ID>`(シミュレータの スクショ → `compare.py` → `/tmp/cmp_<ID>.png`)。シミュレータは **幅 390pt**(iPhone 16e か 14)。
6. `Kit/PROGRESS.md` を 作る(P00〜P09 の 表 と、各 フェーズの 画面 ID)。

## 完了の 条件

- `MIGRATION_MAP.md` が ある。ビルドが 通る。アプリの 名前が Lattag。
- DEBUG メニューで 全部の 状態が 切りかえられる。`scripts/snap.sh H01_home` で 比べた 画像が 出る(この 時点では 違って いて よい)。
- 書体 6つ ・ バイブ 15種類 ・ ガラスの 部品が 動く(小さな プレビュー画面で 確かめる)。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P00 setup: design system, debug state menu, rename to Lattag"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
