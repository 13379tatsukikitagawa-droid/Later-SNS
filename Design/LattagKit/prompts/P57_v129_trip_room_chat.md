# P57 ・ v129:Trip の 部屋を 作りなおす + 本当に 使える チャット

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P57_v129_trip_room_chat.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜D の 4回に 分けて commit。
> P55 ・ P56 と 同じ フォルダで 同時に 動かさない(P56 の 区切りが ついて から)。

## 読む もの
1. `prompts/reference/PROMPT_v129.md`(**ここが 正解**)
2. `prompts/reference/PROMPT_v111.md` の 6章(チャットの 吹き出し)と 通知(`trip_members`)・ `PROMPT_v106.md`(ぬける ・ 重さ)
3. モック `mock/lattag_v115.html`(デモ「Trip の 中」)・ 元コード `mock/src/v114.js` `v114.css`
4. 見本 `screens/v129_trip_room.png` `screens/v129_trip_chat.png`

## すすめ方
- **0 しらべて 報告**:今の Trip の 部屋の View(何個 あるか ・ どこから ひらくか)・ `GroupChatMessage` の 項目 ・ 共有ゾーンの 購読の 有無 ・ Trip の プッシュが 今 届くか。
- **A 部屋**(1章):上の バー 2つ ・ 表紙 ・ よぶ ・ きょうの カード ・ Film ・ 下の チャットの バー。古い 部屋は 消す。
- **B チャットの 見た目と 送る**(2章 見た目 ・ 送れる 物):字 ・ よく使う ことば ・ ステッカー ・ ひらいた 写真。**きょうの 写真が 送れない ことを Unit テスト**。
- **C データ**(2章 データ):`GroupChatMessage` の 送受信 ・ 購読 ・ `TripReadState`(既読)・ 未読の 数。2台で ためす。
- **D 通知**:Trip の チャットの プッシュ(Worker)。ひらいて いる 部屋の メッセージは 通知 しない。
- 毎回:390pt の シミュレータで モックと 見くらべる。

## 終わったら
- `PROGRESS.md` に P57 ✓(A〜D)。報告:2台で 送った 結果(字 ・ ステッカー ・ 写真 ・ 既読 ・ 通知)・ のこり。
