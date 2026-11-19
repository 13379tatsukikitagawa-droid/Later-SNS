# P41 ・ v98:Trip パス(枠 ・ 動き ・ QR ・ 保存)/ Trip チャット(空)/ メンバー / 古い 友だち画面 / キャプションの リセット

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P41_v98_trip_pass_fixes.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜C の 3回に 分けて commit。
> **ほかの タブ(P39 / P40 など)と 同じ フォルダで 同時に 動かさない**(project.pbxproj が ぶつかる)。

## 読む もの
1. `prompts/reference/PROMPT_v98.md`(**ここが 正解**)
2. `mock/src/v88.css` `v88.js`(`p9Qr` ・ `p9Pass` ・ `openPass` ・ `p9Seats` ・ `rmRender` ・ `p9Members` ・ `p9Same`)
3. 見本 `screens/T16〜T20 C25` ・ 動き `motion/M39_trip_pass_print`

## すすめ方
0. **先に 報告**:パスの 上が はみ出す 原因 ・ Save が 動かない 原因 ・ 古い 「ともだち / 呼ぶ」画面に 行く 道(どこから 何本)・ タグ / 音楽が のこる 原因。
- **A Trip パス**:`TripPassView`(clip)・ オリジナル QR(v92 の 部品を 共通に して 表紙を まんなかに)+ Vision テスト ・ 印刷の 動き ・ 写真に 保存(addOnly)。
- **B Trip の 招待**:チャット(空)の 座席表 + プレビュー + 招待リンク ・ メンバーの シート ・ 合言葉を KEY に そろえる ・ `invite-web` の `/t/<key>` に OGP(パスの 画像)。
- **C 古い 画面 と キャプション**:古い 友だち画面を 消して さがす 画面へ ・ ID が 無い 人の シート ・ キャプションの リセット + 「さっきと 同じ」。
- 毎回:見本と 比べる ・ 実機で 保存 ・ LINE の プレビュー ・ 2枚目の キャプションを 確かめる。

## 終わったら
- `PROMPT_v98.md` 6章。`PROGRESS.md` の P41 に ✓(A〜C)。報告:0 の 原因 4つ ・ 消した 古い ファイル ・ OGP の 画像の 作り方。
