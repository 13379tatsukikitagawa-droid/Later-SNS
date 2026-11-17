# P08 ・ Trip(旅行の グループ)を つくる まで

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P08_trip.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`T01_new_trip` `T02_new_trip_filled` `T03_trip_pass_new` `T04_trip_page_active` `T05_trip_pass` `T06_trip_settings` `T07_trip_chat` `T08_invite` `T09_active_card`
- 動き:`M10_trip_create`

## 仕様

`Kit/prompts/reference/PROMPT_v56.md`(1日 23枚を みんなで 分ける ・ 翌朝 9:00 に ひらく ・ 写真の 重さ対策 ・ `reserveGroupShot`)、`PROMPT_v58.md`(Once 風の Trip ・ パス ・ QR ・ KEY)、`PROMPT_v59.md`(グループを つくる 入口は すべて New trip)。

## 読む コード

- `v56.js`:`openTrip` `twDraw` `twBind` `tripCreate` `openPass` `tripSet` `tripPage` `tKey` `tQR` `tPass` `tFilm`
- `v54.js`:`tripSeed` `tripShot` `tripCards`、`v57.js`:`arcActive`(Active の カード)と `openGnw` → `openTrip`
- チャット:`app.js` `openRoom`、招待:`app.js` の `INV` と `renderGroups`

## 作り方の 注意

- QR は 本物(`CIQRCodeGenerator`)。KEY は 英単語 + 数字(例 `#maple24`)。
- 23枚の 予約は サーバーで(Cloud Functions の トランザクション)。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P08 trip"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
