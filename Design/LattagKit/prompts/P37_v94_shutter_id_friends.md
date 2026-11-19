# P37 ・ v94:撮影ボタン = アイコン ・ ID(@ユーザー名)・ 友だちを さがす ・ QR カメラ ・ Friends タブ はじめての 日

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P37_v94_shutter_id_friends.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。大きいので **A → B → C → D → E の 順に 1つずつ commit**。

## 読む もの
1. `prompts/reference/PROMPT_v94.md`(**ここが 正解**)
2. `mock/src/v86.css` `v86.js`(`k9IconSvg` `k9Loop` ・ `k9Chk` `k9IdField` `k9IdBind` ・ `k9Hub` `k9Res` ・ `k9Scan` `k9Hit` ・ `k9Own` `k9Sample` `k9Invite`)
3. 見本 `screens/C23 C24 O12 O13 F01〜F06 F10 F28〜F35 Y19〜Y23` ・ 動き `motion/M35 M36`

## すすめ方
0. **先に 調べて 報告**:今の ユーザーの データ(`users/{uid}` の 項目)・ ID に 近い 物が あるか ・ 友だち申請の しくみ ・ QR の 中身。
1. **A 撮影ボタン**:アイコンの 部品(`LattagShutterIcon`)+ 下から たまる マスク + 1周の 線 + 4回の `click`。今の 長押しの しくみ(時間 ・ 音量ボタン)は そのまま つなぐ。
2. **B ID**:Cloud Functions `claimHandle` `checkHandle`(トランザクション)・ Security Rules(`usernames` は 書きこみ 禁止)・ `HandleField` 部品 ・ はじめての 設定に ID の ページ ・ ID を かえる シート ・ **ID が 無い 今の 人へ の シート**。**Unit テスト**:きまり(`k9Chk` と 同じ 結果)・ 同時に 同じ ID → 片方 だけ 通る(Emulator)。
3. **C さがす 画面**:`searchUsers`(callable ・ 1分 30回)・ `discoverableByName` + 設定の 切りかえ ・ 画面(自分の ID ・ 3つの 道 ・ 申請 ・ おすすめ ・ 友だち ・ 結果)。Add friends の 入口を ぜんぶ ここへ。
4. **D QR カメラ**:わく ・ ビーム ・ 見つけた 時の 動き ・ プロフィールの カード ・ Lattag 以外の QR を 断る。
5. **E Friends タブ はじめての 日**:3こま ・ 1日の 流れ ・ 見本の 投稿(見本 画像は Asset)・ 友だちを よぶ + おすすめ。
6. 見本と 比べる(`tools/compare.py`)。実機で:長押しで 撮れる ・ ID が とれる ・ 名前 / ID で 見つかる ・ QR を 読んで 申請できる。

## 終わったら
- `PROMPT_v94.md` F章。`PROGRESS.md` の P37 に ✓(A〜E)。報告:データの 変更点(項目 ・ 関数 ・ Rules)・ 今の ユーザーへの 移行 ・ テスト結果。
