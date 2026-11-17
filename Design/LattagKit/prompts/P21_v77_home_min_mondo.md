# P21 ・ v77:Home を ミニマムに ・ Friends の 見出しと タグ ・ Mondo を 地球儀から

> **注意**:**A(ミニマムの Home)は P22 で 置きかえ**。この P21 では **B と C だけ** やる。
> **使い方**:Claude Code に「`Design/LattagKit/prompts/P21_v77_home_min_mondo.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。
> **P19 の A(写ルンです の 帯)は やらない**(この P21 の A が 置きかえ)。P19 の C(ME)・ P20(yesterday)の 上に 足す。

## 読む もの
1. `prompts/reference/PROMPT_v77.md`(**ここが 正解**)
2. `mock/src/v74.css` `v74.js`(Home)・ `mock/src/v72.css` `v72.js`(yesterday)
3. 見本 `screens/H01 H03 H06` ・ `Y02 Y03 Y08 Y10 Y12 Y13`、動き `motion/M23_mondo_globe_tap.png`

## すすめ方(3つに 分けて commit)
1. **A Home**:消す 物を 一覧に して 報告 → 消す → 1行の 情報 → レンズの 大きさ ・ 位置 → ひとこと。`H01` と 比べる。
2. **B Friends**:見出し → タグの ピル(押すと 入れかえ)。`Y02` `Y13` と 比べる。
3. **C Mondo**:地球儀 → タップの 動き(バイブ 3つ)→ ひらいた 後(ランキング ・ 図の カード)→ だれも いない 日。`Y10` `M23` `Y12` `Y08` と 比べる。DEBUG の 状態メニューに「Mondo:地球儀に もどす」を 足す。

## 終わったら
- `PROGRESS.md` の P21 に ✓(A / B / C)。報告は 短く。
