# P06 ・ Lattag yesterday(きのうの ホーム)と 写真を ひらく

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P06_yesterday.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`Y01_yesterday_locked` `Y02_yesterday_open` `Y03_yesterday_mondo_tab` `Y04_yesterday_friends_tab` `Y05_yesterday_scroll` `Y06_photo_viewer`

## いまの 実機との ちがい

- 実機は 下の タブが「Mondo / Groups」で、Mondo が 空(投稿が ない)。モックは 下の タブが **Mondo / Friends**(ガラスの タブバー)、**Friends が 最初**。
- 撮る まえ は 写真が ぼかしで「shoot today to open」。撮った あとは 写真 ・ 6d Left ・ 人数 ・ Add friends。

## 仕様と コード

- `Kit/prompts/reference/PROMPT_v54.md`(Friends タブ)、`PROMPT_v56.md`、古い 詳細は `ALL_PROMPTS…` で「Lattag yesterday」検索
- `app.js`:`openY` `closeY` `ytab` `yMondo` `renderYGroups`、`v46.js` `v49.js` `v54.js`(Friends タブ ・ Trips)、写真を ひらく `openAv`
- Mondo タブに 投稿が 無い ときの 表示も 作る(空の 形)。DEBUG の 見本データで 埋まった 形も 確かめる。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P06 lattag yesterday"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
