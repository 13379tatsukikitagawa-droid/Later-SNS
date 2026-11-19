# P34 ・ v91:オープニングを 黒に ・ 軽く(L)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P34_v91_opening_black.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。1回で よい。

## 読む もの
1. `prompts/reference/PROMPT_v91.md`(**ここが 正解**)
2. 動く 見本 `mock/opening_v91.html`(**L** を 見る ・ ゆっくり ×4)
3. コマ割り `motion/M31_opening_black_light.png` ・ `screens/opening_v91/L_*.png`

## すすめ方
1. 今の オープニングの View と 起動画面の 設定を 報告(背景の 光の 層 ・ 1字ずつ ・ mask が どこに あるか)。
2. 背景を `#000` に ・ `LaunchInk` も `#000`。光の 層を 消す。
3. 動きを L の 表に おきかえる(1字ずつ ・ 切り抜き ・ シャッター ・ 丸い mask を 消す)。
4. Slow Animations で 見比べ → 実機で Instruments(ヒッチ 0)。commit。

## 終わったら
- `PROMPT_v91.md` 5章。`PROGRESS.md` の P34 に ✓。報告:前と 後の ヒッチの 数 ・ 消した コード。
