# P54 ・ v110:Mondo を なくす ・ タブは Friends | Trip ・ ステッカー × チェキ で ポップに

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P54_v110_trip_tab_pop.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜E の 5回に 分けて commit。
> P53(リンク)と 同じ フォルダで 同時に 動かさない。P53 の 区切りが ついて から 始める。

## 読む もの
1. `prompts/reference/PROMPT_v110.md`(**ここが 正解**)
2. モック `mock/lattag_v97.html`(デモ `★ v97 Friends` `★ v97 Trip` `Friends:1枚 撮った` `Trip:次の 週` `Trip:まだ 0件`)・ 元コード `mock/src/v97.js` `v97.css`
3. 見本 `screens/v110_friends.png` `screens/v110_trip.png`

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 5つ)。コードは 変えない。
- **A Mondo を なくす + 外がわ**(1 ・ 2章):タブ 2つ ・ ライムの つまみ ・ 使いかた / ウィジェット / 通知 から 消す。データは 消さない。
- **B ポップの 部品**(3章):色 4つ ・ `Pop/`(Sticker ・ Tag ・ Tape ・ ChekiFrame ・ PopButton ・ 押すと ぷにっ の ButtonStyle)。プレビュー 1画面で 全部 ならべて スクショ。
- **C Friends**(4章)。
- **D Trip**(5章)。一覧は サムネ だけ 読む。
- **E ほかの 画面を そろえる**(6章)+ 確かめる(8章)。
- 毎回:390pt の シミュレータで モックと 見くらべる(`tools/compare.py`)。Reduce Motion も。

## 終わったら
- `PROGRESS.md` の P54 に ✓(A〜E)。報告:Friends と Trip の スクショ(0枚 / 撮った / Trip 0件)・ 消した Mondo の ファイル一覧 ・ のこした データの 一覧。
