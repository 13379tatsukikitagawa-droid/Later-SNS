# P38 ・ v95:実機を 見て 直す 11こ(キーボード ・ タグ ・ 招待 ・ 説明 ・ QR ・ Trip 写真 ・ Home Friends / NEXT / カード ・ Mondo)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P38_v95_fixes11.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。**A〜D の 4回に 分けて commit**。

## 読む もの
1. `prompts/reference/PROMPT_v95.md`(**ここが 正解**)
2. `mock/src/v87.css` `v87.js`(`j9KbOn` ・ `j9InvOpen` ・ `j9Tour` ・ `k9Scan` の 上書き ・ `tw8StepHtml` ・ `j9FrPage` ・ `j9Sugg` `j9NxDraw` ・ `arcFriends` ・ `x8NoMondo`)
3. 見本 `screens/O14〜O24 H11 H12 H20 H21 H22 F10 T15 Y19 Y24 Y25` ・ 動き `motion/M37 M38`

## すすめ方
- **A はじめて**(1〜4):キーボード(`safeAreaInset` + `@FocusState`)・ タグの 席 ・ 招待の 3つの 道(`PasteButton` ・ Trip の コード `joinTripByCode` ・ @ID)・ 5つの 説明。
- **B 小さな 画面**(5 ・ 6):QR カメラの 配置 ・ Trip の 写真を 設定(`PHPicker` ・ 撮った 写真は 出さない)。
- **C Home**(7〜9):Friends ページ ・ NEXT の カプセル(状況の 表)・ 下の Friends カードを 上へ + 4つの ボタンを 別々に。
- **D Mondo ・ Friends タブ**(10 ・ 11):Explore を 直す ・ ない 日の 画面 ・ ストーリーの 列。
- 毎回:見本と 比べる(`tools/compare.py`)・ **実機で キーボード と ボタンの 行き先を 確かめる**。

## 終わったら
- `PROMPT_v95.md` 12章。`PROGRESS.md` の P38 に ✓(A〜D)。報告:かさなりの 原因 ・ 4つの ボタンが 同じ 画面に なって いた 原因 ・ Explore が 動かなかった 原因。
