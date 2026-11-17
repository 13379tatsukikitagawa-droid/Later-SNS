# P02 ・ Home の 上 と カメラカード

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P02_home_top_card.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`H01_home` `H02_home_hint` `H03_home_press` `H04_home_1shot` `H05_home_2shot` `H06_home_3shot` `H07_home_friends` `H08_home_firstday` `H09_home_night` `H10_live_panel`
- 動き:`M03_home_enter` `M04_shutter` `M07_return_after_shot` `M13_live_panel`

## 仕様の 順番

`Kit/prompts/reference/PROMPT_v64.md`(ぼかした 写真 + ガラス)→ `PROMPT_v65.md`(仕上げ)→ `PROMPT_v66.md`(カメラの 絵だけ ・ 上 ・ 下 ・ はじめての 日)。**後の 方が 優先**。v61 と v63 の Home カードの 見た目は 古い(使わない)。

## 読む コード

- ヘッダー:`body.html` の `#hhd` `#hst`(数字が 縦に 回る 時刻 `.rl` は `v46.js`)、ライブパネル `v46.js` `openLive` `lpBuild`、today / yesterday は `v62.css` の `.hh .dsw`、プロフィールの 輪 と ピルは `v63.css` `v63.js`
- カード:`v61.js`(`hxBuild` `hxRender`:ぼかした 写真 ・ 光の もれ ・ 粒子 ・ ガラスの ボタン ・ 下の ピル)、`v62.js`(上の チップ ・ ガラスの ふち ・ 光の 向き ・ 四すみの 位置)、`v63.js`(カメラの 絵)、四すみの ボタンは `v53.js`(`dlBuild` `dlDeal`)+ `v55.js`(`hpCorner`)+ `v62.js`(`dlLayout`)
- まんなかの 役わり:`app.js` `orbActs` → `v61.js` の 上書き(四すみは いつも Yesterday / Trip / Mondo / Friends、3枚 撮る まで Shoot)
- 月(今日を撮る):`v63.js` `g63Moon` と `v63.css`
- はじめの 合図:`app.js` の `CMD`(と `v63.js` の 書きかえ)

## 作り方の 注意

- ぼかした 写真は **48px の サムネを 1回だけ ぼかして キャッシュ**(毎フレーム ぼかさない)。ひらく 前の 友だちの 元の 写真は 端末に 送らない(PROMPT_v64 §3)。
- ガラスは `LGGlass`、ふちの 光は かたむきで 動く。押した ときの「ピントが よる」(ぼかし 15 → 5)と 白い 光 ・ 線は PROMPT_v64 §6。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P02 home header and camera card"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
