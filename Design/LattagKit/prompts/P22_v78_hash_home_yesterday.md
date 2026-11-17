# P22 ・ v78:Home を # で ・ yesterday の 上の 帯 ・ 通知 ・ あなたの きのう ・ Mondo の ランキング

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P22_v78_hash_home_yesterday.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。
> **P21 の A(ミニマムの Home)は やらない**(この P22 の A が 置きかえ)。P21 の B ・ C(Friends の タグ ・ Mondo の 地球儀)は やる。

## 読む もの
1. `prompts/reference/PROMPT_v78.md`(**ここが 正解**)
2. `mock/src/v75.css` `v75.js`(Home)・ `mock/src/v72.css` `v72.js`(yesterday)
3. 見本 `screens/H01 H03 H06` ・ `Y02 Y08 Y10 Y12 Y14 Y15 Y16 Y17`、動き `motion/M23_mondo_globe_tap.png`

## すすめ方(3つに 分けて commit)
1. **A Home**:# の 4本 + 黒い 円 → レンズの 大きさ ・ 位置 → ドームを 戻す → ロゴの 右上の TODAY(押すと 入れかわって yesterday へ)。`H01` と 比べる。
2. **B yesterday の 上**:Lattag を 消す → 左 通知 ・ まんなか タブ名 ・ 右 TODAY → 通知の パネル → あなたの きのう(いちばん 上 ・ 全画面)。`Y02` `Y14` `Y15` と 比べる。通知の データは 今 ある リアクション ・ コメント ・ 申請 から。
3. **C Mondo**:投稿 なし = 「今日の Mondo は ありません」→ ランキング(1位 ・ 2〜3位 ・ 4〜8位 ・ タグで しぼる)。`Y08` `Y12` `Y16` `Y17` と 比べる。

## 終わったら
- `PROGRESS.md` の P22 に ✓(A / B / C)。報告は 短く。
