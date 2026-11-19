# P32 ・ v89:Home の スクロール ・ オープニング ・ お題 ・ 音楽 ・ きのうの 写真が ひらく ・ アイコン

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P32_v89_fixes.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。**3回に 分ける**(A → B → C)。

## 読む もの
1. `prompts/reference/PROMPT_v89.md`(**ここが 正解**)
2. `prompts/reference/swift/HomeHeroScroll_example.swift`(Home の 形の 見本)
3. `mock/src/v82.css` `v82.js`
4. 見本 `screens/C01 C10 C11 C13〜C22 H01 Y02` ・ 動き `motion/M29_reveal`

## A(1回目):Home の スクロール と オープニング
1. **Home**(v89 A):# の 帯に 付いて いる 物を 報告 → `.allowsHitTesting(false)` → 見本の 形に そろえる → **UI テスト 3本 を 通す**。
2. **オープニング**(v89 B):`CADisableMinimumFrameDurationOnPhone` ・ 重い 仕事を あとへ ・ 1つの 時計 ・ `scaleEffect` だけで 動かす ・ `drawingGroup` → **Instruments で ヒッチ 0** を 確かめる。
3. アイコン 56(v89 F)。commit。

## B(2回目):タグ画面の お題 と 音楽
1. お題(31こ ・ 日付で えらぶ ・ 太い 字 ・ 2行まで)。
2. 音楽シートを 黒に 作りなおす(デバッグの 字を 消す ・ おすすめ / 最近 / ライブラリ / 検索 ・ 押すと プレビューが 流れる ・ 決めた あとも 流れる ・ チップで 止める / 流す)。
3. `C01` `C13〜C18` と 比べる。commit。

## C(3回目):きのうの 写真が ひらく
1. いまの モザイクの 現像を 消す(ファイル名を 報告)。
2. しぼり → 光 → 現像 → タグ → ボタン(v89 E の 時間割り)。とちゅうで タップ = さいごへ。
3. 1回 タップで 全画面(ズームで ひろがる ・ 2回 タップで 2.2倍 ・ 下へ ひっぱって とじる ・ 全画面でも えらべる)。
4. 2枚の 日は つづけて ひらく。レア。Reduce Motion。
5. `C10 C11 C19〜C22` ・ `M29` と 比べる。commit。

## 終わったら
- `PROMPT_v89.md` G章の 1〜7。`PROGRESS.md` の P32 に ✓。
- 報告:**# の スクロールを 止めて いた 物** ・ UI テストの 結果 ・ オープニングの ヒッチの 数(前 / 後)・ 消した ファイル。
