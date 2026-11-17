# P17 ・ v73:レンズの まんなかを 黄緑の シャッターに ・ レンズを テーマカラーに

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P17_v73_shutter.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。P15(v71 の レンズ)が 終わって いる こと。

## 読む もの

1. `prompts/reference/PROMPT_v73.md`(**ここが 正解**)
2. `mock/src/v69.css` ・ `mock/src/v69.js`(数値は ここから)
3. 見本 `screens/H01_home.jpg` `H03_home_press.jpg` `H04_home_1shot.jpg` `H06_home_3shot.jpg` と 同じ 名前の `spec/screens/*.json`、動き `motion/M18_iris_shutter.png`

## すすめ方

1. 今の LensView の まんなかの カメラの 絵(SF Symbol)の 場所を 調べて 報告。
2. `HashShape`(アイコンの #)を 部品に して、シャッターボタンを 作る(撮れる とき だけ)。
3. 色の 変更(PROMPT_v73 2章の 表を 上から)。
4. 押す / はなす を `M18` と 比べる。
5. `H01` `H04` `H06` `H09` と compare.py で 比べる。

## 終わったら

- `PROGRESS.md` の P17 に ✓。git commit。報告は 短く。
