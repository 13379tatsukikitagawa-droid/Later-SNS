# P09 ・ つなぎ と 仕上げ(データ ・ 9:00 ・ 全画面の 確認)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P09_finish.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## やる こと

1. **データを 本物に**:9:00 に ひらく しくみ(Cloud Functions の スケジュール)、友だちの 今日の **48px サムネ**、Mondo の 人気タグ(数字なし)と 9:00 の 街、はじめての 日の 判定(`hasYesterday`)、通知(FCM)。DEBUG の 見本データが 無くても 正しく 動く ことを 確かめる。
2. **全76画面を もう一度 比べる**:`Kit/screens/INDEX.md` の 順に、DEBUG メニューで 状態を 作って `scripts/snap.sh` → score を `PROGRESS.md` に。大きく ずれる 画面を 直す。
3. **動きを 全部 見る**:`Kit/motion/` の 14本を、シミュレータの 画面収録(`xcrun simctl io booted recordVideo`)と 見くらべる。
4. **アクセシビリティ**:Reduce Motion / 透明度を 下げる / コントラストを 上げる / VoiceOver(各 PROMPT の 文)/ 押せる 範囲 44pt。
5. **重さ**:Instruments で Home を 30秒 ながめる(ぼかし ・ 地球 ・ 粒子)。画面外の アニメが 止まって いるか。
6. **DEBUG メニューを リリース ビルドから 外す**。App Store 用の スクリーンショットを 新しい 見た目で 撮る。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P09 data wiring and final pass"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
