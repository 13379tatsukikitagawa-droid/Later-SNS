# P24 ・ v80:スクロールで 上の 帯を 小さく ・ Mondo の 大きな 字を 消す

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P24_v80_scroll_compact.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。P23 の 上に 足す。

## 読む もの
1. `prompts/reference/PROMPT_v80.md`(**ここが 正解**)
2. `mock/src/v75.css` の いちばん 下(v80)・ `mock/src/v72.css` `v72.js` の `y72Shrink`
3. 見本 `screens/H19_home_scrolled.jpg` `Y18_friends_scrolled.jpg` `Y03_yesterday_mondo_tab.jpg`、動き `motion/M19_header_compact.png`

## すすめ方
1. Home:スクロール 60pt で 時間の カプセルを まんなかの 小さな ピルに(アバターと 重ならない ことを 375 / 390 / 440 で 確かめる)。
2. yesterday:スクロール 24pt で 上の 帯を 小さく(字 24 → 17 ・ ボタン 0.8倍 ・ 黒 78% + ぼかし)。
3. Mondo:ひらいた 後の 大きな「Mondo」の 字を 消して、地球を 上へ。
4. `H19` `Y18` `Y03` と 比べる。

## 終わったら
- `PROGRESS.md` の P24 に ✓。報告は 短く。
