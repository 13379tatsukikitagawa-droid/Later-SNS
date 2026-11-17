# P14 ・ v70 Home 下の Friends カード(Instagram / BeReal 型)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P14_v70_friends_card.md` を 読んで、その とおりに 進めて」と だけ 伝える。
> ルールは リポジトリの `CLAUDE.md`。**計画モードで 始める**。キットの 場所:`Design/LattagKit/`(以下 `Kit/`)。

## 読む もの
1. `Kit/prompts/reference/PROMPT_v70.md`(ぜんぶ)
2. `Kit/mock/src/v67.css` `Kit/mock/src/v67.js`
3. 見本:`Kit/screens/L08_friends_card_empty.jpg` `L12_friends_card_noreq.jpg` `L09_friends_card.jpg`(数値は `Kit/spec/screens/` の 同じ 名前)・ 動き `Kit/motion/M12_friends_card_in.png`

## やる こと
1. 今の Home 下の Friends カード(キャラクター「まだ ひとり。」・ Shake / QR・ID / Link の 3ボタン ・ チェキの 列)を **消して**、v70 の 形に 置きかえる。
2. 3つの 状態(友だち あり / だれも いない ・ 申請 あり / だれも いない ・ 申請 なし)を DEBUG の 状態メニューで 出し、見本と 比べる。
3. 承認 ・ × ・ つつく ・ 確認 ・ リンク ・ QR ・ ID の 行き先は 今の しくみを そのまま 使う(データの しくみは 変えない)。

## 終わったら
- `Kit/PROGRESS.md` に「P14 v70」を 足して ✓、**git commit**。報告は 短く。
