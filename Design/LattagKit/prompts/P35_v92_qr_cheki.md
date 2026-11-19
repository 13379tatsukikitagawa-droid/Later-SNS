# P35 ・ v92:自分の QR = チェキ + # の 形

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P35_v92_qr_cheki.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。1回で よい。

## 読む もの
1. `prompts/reference/PROMPT_v92.md`(**ここが 正解**)
2. `mock/src/v84.css` `v84.js`(QR の 描き方 = `q9Svg`)
3. 見本 `screens/F25_qr_cheki` `F26_qr_copied` `F27_qr_back` ・ 動き `motion/M32_qr_open`

## すすめ方
1. 今 QR を 出して いる 所(プロフィール ・ Friends ・ Add friends)と 招待の URL を 報告。
2. **QR の 部品**(`LattagQRView`):CoreImage で マトリクス → Canvas で 点 ・ # の 緑 ・ レンズの 目 ・ アイコン。**Vision で 読める Unit テスト を 先に**。
3. 画面(チェキ ・ アイコン ・ 名前 ・ 日付 ・ テープ ・ うらがえす ・ かたむく)。
4. 下の 5つ(コピー ・ LINE ・ メッセージ ・ 保存 ・ その他)。
5. 入口を この 画面に つなぐ。見本と 比べる。**実機の カメラで 読める ことを 確かめる**。commit。

## 終わったら
- `PROMPT_v92.md` 6章。`PROGRESS.md` の P35 に ✓。報告:Unit テストの 結果 ・ 実機で 読めたか。
