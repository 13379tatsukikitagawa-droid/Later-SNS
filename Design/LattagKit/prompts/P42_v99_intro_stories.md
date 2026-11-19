# P42 ・ v99:はじめて ひらいた 時の 説明(Friends ・ Trip ・ Mondo)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P42_v99_intro_stories.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜C の 3回に 分けて commit。
> **ほかの タブと 同じ フォルダで 同時に 動かさない**(project.pbxproj が ぶつかる)。P41 が 終わって から。

## 読む もの
1. `prompts/reference/PROMPT_v99.md`(**ここが 正解**)
2. `mock/src/v89.css` `v89.js`(`Z9S`(場面の データ)・ `z9Open` ・ `z9Go` ・ `z9Pause` ・ `z9Close` ・ `hpGo` の 包み)
3. 見本 `screens/G01〜G14` ・ 動き `motion/M40〜M42`
4. モックで `説明 Friends` `説明 Trip` `説明 Mondo` を 押して 実際に 見る(タップ ・ 長押し も)

## すすめ方
0. **先に 報告**:Home の 横スライドで ページが かわる 所 ・ Friends を ひらく / New trip の 入口(どこから 何本)・ はじめての スポットライト(v95)の 状態の 持ち方。
- **A 土台**:`IntroStoryView`(進み具合 ・ 上の 行 ・ 題字 ・ 1行 ・ タップ / 長押し / スワイプ ・ 最後の ボタン)+ `introSeen` + 出す きっかけ(ページ ・ 入口 ・ `?`)。場面は 仮の 色の 箱で よい。
- **B 場面 12こ**:Friends 4 ・ Trip 4 ・ Mondo 4 の 動きと バイブ(表の 時間 どおり)。見本の 写真 6枚を アセットに。
- **C 仕上げ**:Reduce Motion ・ VoiceOver ・ 幅 375 ・ 重さ(Instruments で 120fps)・ とじた あとの `?` の ぷくっ + トースト。
- 毎回:見本と 比べる(`compare.py`)・ 実機で 15秒 通して 見る ・ バイブを 手で 確かめる。

## 終わったら
- `PROMPT_v99.md` 5章。`PROGRESS.md` の P42 に ✓(A〜C)。報告:入口の 数 ・ 1回 だけ に する しくみ ・ 気に なった 動き。
