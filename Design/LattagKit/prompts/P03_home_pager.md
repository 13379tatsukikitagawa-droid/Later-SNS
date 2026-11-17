# P03 ・ Home の 横スライド(5ページ)と 目次

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P03_home_pager.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`H11_page_friends` `H12_page_friends_filled` `H13_page_trip` `H14_page_mondo_locked` `H15_page_mondo_open` `H16_page_yesterday` `H17_page_yesterday_open` `H18_page_yesterday_firstday`
- 動き:`M05_page_swipe` `M11_mondo_globe`

## 仕様

`Kit/prompts/reference/PROMPT_v57.md`(横スライドの しくみ)→ `PROMPT_v64.md` §(4ページの 背景)→ `PROMPT_v65.md` §5(目次 44pt と すべる 印)→ `PROMPT_v66.md` §4(はじめての 日の Yesterday ページ)→ `PROMPT_v67.md`(Mondo ページ)。Trip ページは `PROMPT_v58.md`。

## 読む コード

- `v55.js`:`hpBuild` `hpLayout`(3D の かたむき)`hpGo`(ばね)`hpBind`(横と 縦の 見分け ・ 端の ゴム)`hpRender` `hpEnter`
- `v56.js`:`tripPage`(Trip ページ)、`v61.js`:4ページの ぼかし背景、`v62.js`:`g62Dock`(すべる 印)、`v63.js`:はじめての 日の Yesterday ページ、`v64.js`:Mondo(`mnDraw` 点の 地球 ・ 9:00 の 線 ・ 浮かぶ チェキ、`mnHTML`)

## 作り方の 注意

- 横スライドは 縦スクロールの 邪魔を しない(横 8pt 以上 かつ 横 > 縦 × 1.2)。
- Mondo の 地球は `Canvas` + `TimelineView`、**見えて いない ときは 止める**。陸は 本物の 海岸線データ。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P03 home pager, dock and pages"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
