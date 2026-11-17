# P23 ・ v79:ダブルタップで 切りかえ ・ あなたの きのう ・ Mondo の 大きな 地球 ・ ない 日 ・ Home の 時間と ピル

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P23_v79_switch_mondo_home.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。P22 の 上に 足す。

## 読む もの
1. `prompts/reference/PROMPT_v79.md`(**ここが 正解**)
2. `mock/src/v75.css` `v75.js`(Home)・ `mock/src/v72.css` `v72.js`(yesterday ・ Mondo)
3. 見本 `screens/H01 H11 Y02 Y08 Y09 Y10 Y11 Y12`、動き `motion/M23_mondo_globe_tap.png`
4. モックを Safari で 開いて、上の デモボタン(`きのう を ひらく` ・ `Mondo:投稿 あり / なし` ・ `地球に もどす`)で 動きを 確かめる

## すすめ方(2つに 分けて commit)
1. **Home**:時間の カプセル → ピルから Camera を 外す(ほかの ページでは 小さな 丸)→ TODAY を ダブルタップに。
2. **yesterday**:右上の アイコン(ダブルタップ)→ あなたの きのう(大きめ 1枚 + 2 more + ボタン 3つ)→ Mondo の 大きな 地球(指で 回す ・ タップで ひらく)→ ない 日(カウントダウン ・ 知らせる)。DEBUG の 状態メニューに「Mondo:投稿 あり / なし / 地球に もどす」。

## 終わったら
- `PROGRESS.md` の P23 に ✓。報告は 短く。
