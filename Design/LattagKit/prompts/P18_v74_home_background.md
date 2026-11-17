# P18 ・ v74:Home の 地を 単色(黒)に ・ ガラスは ボタン だけ

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P18_v74_home_background.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。

## 読む もの

1. `prompts/reference/PROMPT_v74.md`(**ここが 正解**)
2. `mock/src/v70.css`、比べ `screens/H00_background_options.png`
3. 見本 `screens/H01_home.jpg` `H11_page_friends.jpg` `H13_page_trip.jpg` `L09_friends_card.jpg`、動き `motion/M19_header_compact.png`

## すすめ方

1. 今の Home の 背景(ぼかし写真 ・ 入れかわり ・ vignette)と、ガラスを 使って いる 所を 全部 調べて 一覧で 報告(ボタン か ボタン でない か)。
2. 背景を `Theme.homeBackground`(`#0B0C0D`)の 単色に。写真の 背景の コードは 消す。
3. ボタン でない ガラスを 単色に(上の 帯 など)。
4. `H01` `H11` `H13` `L09` と compare.py で 比べる。
5. P11 の PERF.md に Home の 前 → 後(CPU ・ メモリ)を 書く。

## 終わったら

- `PROGRESS.md` の P18 に ✓。git commit。報告は 短く。
