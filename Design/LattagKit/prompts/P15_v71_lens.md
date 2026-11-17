# P15 ・ v71:まんなかを 本物の レンズに ・ 「Friends」の 表記 ・ 四すみの かぎ

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P15_v71_lens.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。
> ルールは リポジトリの `CLAUDE.md`。

## 読む もの

1. `prompts/reference/PROMPT_v71.md`(**ここが 正解**)
2. `mock/src/v68.css` ・ `mock/src/v68.js`(約 90行。数値は ここから)
3. 見本:`screens/H01_home.jpg` `H03_home_press.jpg` `H06_home_3shot.jpg` `L09_friends_card.jpg` `F02_friend_list.jpg` と 同じ 名前の `spec/screens/*.json`
4. 動き:`motion/M18_iris_shutter.png` ・ `M17_home_camera_boot.png`

## すすめ方(この 順番)

1. **「Friends」の 表記**(いちばん 小さい):頭の 1文字だけ 色 ・ 斜体を 変えて いる 所を ぜんぶ 探して(`Friends` `Requests` などの 見出し)、1つの `Text` に もどす。→ ビルド → `L09` `F02` と 比べる。
2. **四すみの かぎ**:今の かぎの 置き方を 調べて 報告(どの View の 座標で 置いて いるか)。→ ボタンの `.overlay` に 移し、`CornerBracket` Shape(PROMPT_v71 2章)で 描く。→ iPhone 16e と SE(375)で スクショ → `H01` と 比べる。
3. **シール**:レンズの 中心から の 位置に 直す。8pt 以上 はなれて いるか 確かめる。
4. **レンズ**:`LensView` を 外から 中へ 作る(4-2 の 表の 順)。しぼり(v69 で 作った もの)の 円を 109 に。反射 → 動き の 順。1つ 足す ごとに ビルドして `H01` と 比べる。
5. 押す / はなす の 動きを `M18` の コマと 比べる。
6. Instruments で Home 10秒 何も しない → CPU 15% 以下か。

## 終わったら

- `PROGRESS.md` の P15 に ✓ と ずれの 点数(H01 ・ H03 ・ H06 ・ L09 ・ F02)。
- git commit(1 → 2・3 → 4・5 の 3つに 分ける)。
- 報告:できた 所 / 気に なる 所(とくに 小さい 端末での シール)。
