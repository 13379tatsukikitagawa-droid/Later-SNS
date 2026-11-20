# P49 ・ v106:はじめての 設定の バグ ・ Friends の さいご ・ Trip(チャット ・ 設定 ・ ぬける)・ 重さ

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P49_v106_bugs_friends_trip.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜E の 5回に 分けて commit。
> **ほかの タブと 同じ フォルダで 同時に 動かさない**。

## 読む もの
1. `prompts/reference/PROMPT_v106.md`(**ここが 正解**)
2. モック `mock/lattag_v96.html`(デモ `Name(字数)` `Friends:フィードの さいご` `Trip の 中` `Trip の 設定` `Trip を ぬける` `Trip を おわる`)・ 元コード `mock/src/v95.js` `v95.css`
3. グループの チャット:モックの `openRoom`(base)・ `mock/src/v77.js` の `th77Draw`(チャットの 入口)

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 6つ ・ **数字つき**)。コードは 変えない。
- **A バグ 2つ**:はじめての 設定が とちゅうで Home(1章)・ Name の 字数(2章)。テストを 先に 書く。
- **B Friends**:灰色の 面を なくす ・ さいごの フィルムの 絵(3章)。
- **C Trip の 中**:右上の 2つ ・ チャットを もどす(4章)。`GroupMessage` を 使う 場合は **CloudKit の Development に 型を 作る ところまで**(Production の Deploy は たつきさんが 確認 して から)。
- **D Trip の 設定 ・ ぬける / おわる**(5 ・ 6章)。
- **E 重さ**(7章):先に 0 の 数字 → 7-1 → もう一度 はかる → 7-2(DEBUG だけ)。**消す ボタンは 自動で 動かさない**。
- 毎回:実機で ためす ・ 390pt の シミュレータで モックと 見くらべる。

## 終わったら
- `PROGRESS.md` の P49 に ✓(A〜E)。報告:バグの 原因 ・ 前と 後の 起動 ms ・ メモリ ・ 読んだ レコード数 ・ Deploy が 要る 型の 一覧。
