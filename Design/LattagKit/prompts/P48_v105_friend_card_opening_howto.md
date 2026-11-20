# P48 ・ v105:友だちの カード ・ オープニング(強い 版)・ 使いかた

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P48_v105_friend_card_opening_howto.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜C の 3回に 分けて commit。
> P47 と 同じ フォルダで 同時に 動かさない(P47 の あと で よい ・ A は 先に やって よい)。

## 読む もの
1. `prompts/reference/PROMPT_v105.md`(**ここが 正解**)
2. モック `mock/lattag_v96.html`(デモ `友だちの カード(撮った)` `友だちの カード(まだ)` `使いかた`)・ 元コード `mock/src/v94.js` `v94.css`
3. オープニング `mock/opening_v94.html` の **S**(「ゆっくり ×4」)・ コマ割り `motion/M32_opening_v94_strong.png`
4. v99 の 動く 説明(`PROMPT_v99.md`)・ v104 の ウィジェット(`PROMPT_v104.md` 6章)

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 4つ)。コードは 変えない。
- **A 友だちの カード**:バグ(切れる ・ すける ・ 灰色の 帯)を 直す → 新しい 中身と 動き(PROMPT 1章)。
- **B オープニング S**:表の とおり。光 ・ 輪は 画像。Instruments で ヒッチ 0(PROMPT 2章)。L は 消す。
- **C 設定 > サポート**:2行を 消す → 使いかた の シート(PROMPT 3章)。
- 毎回:実機 ・ 390pt の シミュレータで モックと 見くらべる。

## 終わったら
- `PROGRESS.md` の P48 に ✓(A〜C)。報告:0 の 結果 ・ 前と 後の 起動 → Home の ms ・ ヒッチの 数 ・ 消した View。
