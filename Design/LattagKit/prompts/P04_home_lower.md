# P04 ・ Home の 下(スクロール した 所)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P04_home_lower.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`L01_today` `L02_active` `L03_yesterday` `L04_yesterday_open` `L05_mondo_row` `L06_albums` `L07_onthisday` `L08_friends_card_empty` `L09_friends_card` `L10_firstday_yesterday` `L11_develop_view`
- 動き:`M12_friends_card_in`

## 仕様

`Kit/prompts/reference/PROMPT_v63.md` §12(Home 下の Friends カード ・ PULL を 消す)、`PROMPT_v66.md` §4(はじめての 日:Mondo ・ Albums ・ On this day を 出さない、Yesterday は 空っぽの カード)、`PROMPT_v59.md`(Active に Trip)。古い 詳細は `ALL_PROMPTS_v47-v67.md` を 画面名で 検索。

## 読む コード

- `app.js`:`arcToday` `arcActive` `arcYesterday` `arcMondo` `arcAlbums` `arcFriends` `renderArc`、白 → 黒の つなぎ `#dusk`、現像中の 画面 `openDvx` `dxPlay` `dxScroll`
- 上書き:`v46.js`(On this day ・ Albums)`v54.js` `v57.js`(Active の Trip カード)`v61.js`(Friends カード `arcFriends` `afIn`)`v63.js`(はじめての 日 `g63New`)
- **PULL の ひも(`.hcord`)は 作らない**。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P04 home lower sections"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
