# P07 ・ Friends(友だち)と Profile ・ ME

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P07_friends.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`F01_friend_empty` `F02_friend_wall` `F03_friend_requests` `F04_friend_scroll` `F05_friend_card` `F06_add_friends` `F07_dm_chat` `F08_profile` `F09_me_calendar` `F10_qr_scan`
- 動き:`M09_request_accept` `M14_friend_card_sheet`

## 仕様

`Kit/prompts/reference/PROMPT_v56.md`(友だちの しくみ:申請 ・ おたがい 承認 ・ 人数の 上限 なし ・ 数は 出さない ・ チャット ・ Firestore の ルール)、`PROMPT_v60.md`(チェキの 壁 ・ 友だちの カード)。

## 読む コード

- `v48.js` `fRender`(土台)→ `v54.js`(`reqIncoming` `reqAccept` `reqLater` `openAdd` `openDM`)→ `v58.js`(`fRender` の 上書き:NOW ・ Requests ・ Today ・ 壁 ・ もっと つながる ・ You、`openFC` `fPoke2`)
- Profile:`v51.js` `openPrf`。ME / 1年:`v50.js` `openMe` `meplay`。QR:`v46.js` `openScan` `openShare`

## 作り方の 注意

- 友だちの しくみ(Firebase)は PROMPT_v56 の とおり。Profile は 今の 実機(緑の チェキ)を モックの 形に 合わせる。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P07 friends and profile"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
