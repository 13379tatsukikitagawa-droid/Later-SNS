# P19 ・ v75:Home を 写ルンです の 配色に ・ Lattag yesterday ・ ME(縦線)

> **注意**:**A(Home の 帯)は P21、B(Lattag yesterday)は P20 で 置きかえ**。この P19 では **C(ME)だけ** やる。
> **使い方**:Claude Code に「`Design/LattagKit/prompts/P19_v75_home_yesterday_me.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。量が 多いので **A → B → C の 3回** に 分けて よい(1回 終わる ごとに commit と `/clear`)。

## 読む もの
1. `prompts/reference/PROMPT_v75.md`(**ここが 正解**)
2. 元コード `mock/src/v71.css` `v71.js`(A)・ `v72.css` `v72.js`(B)・ `v73.css` `v73.js`(C)
3. 見本 `screens/H01 H03 H06 H07`(A)・ `Y01〜Y07`(B)・ `F09 F10`(C)と 同じ 名前の `spec/screens/*.json`

## すすめ方
- **A(Home の 帯)**:帯を レンズの 中心 基準で 置く → 3色の 線 → 帯の 中の 部品の 色。`H01` と 比べる。
- **B(Lattag yesterday)**:今の Lattag yesterday の 画面を 調べて 報告 → ヘッダー → 切りかえ → 24時間の 帯 → 大きな 写真 → 友だちの 列 + 上映 → あなたの きのう → ロック → Mondo タブ。`Y01` `Y04` `Y07` と 比べる。データは 今の 友だちの きのうの 写真(撮った 時刻を 使う)。
- **C(ME)**:Canvas で バーコード → なぞる → 選んだ 日 → 縦の フィルム。`F09` `F10` と 比べる。データは 自分の 写真の 記録(60日)。

## 終わったら
- `PROGRESS.md` の P19 に A / B / C ごとに ✓。git commit(A ・ B ・ C で 分ける)。報告は 短く。
