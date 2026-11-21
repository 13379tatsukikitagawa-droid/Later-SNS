# Claude Code に 送る もの(v131 まで)

## 0. さきに やる こと(たつきさん)
1. `LattagKit_v131_update.zip` を ひらいて、中の `Design` フォルダを **リポジトリの いちばん上に 上書き**(`Design/LattagKit/` に 入る)。
2. 中の `CLAUDE.md` は `Design/LattagKit/CLAUDE.md`。リポジトリの いちばん上の `CLAUDE.md` にも 同じ 中身を 入れる(前と 同じ やり方)。
3. もし 前に `mock/lattag_v116.html` や `prompts/P58_v130_compact.md` を 入れて いたら **消す**(v130 は 不採用)。

## 1. いま P55 を 進めて いる ターミナルへ(すぐ 送る)
```
Design/LattagKit を 最新に 上書きしました(v131 まで)。
P55 の B 以降で、v111 の あとに 変わった 所が あります。
Design/LattagKit/prompts/P55_patch_after_v111.md を 読んで ください。
- C の 5章(Trip 画面)と 6章(チャット)は P55 では 作らない で ください。P57(v129)で 作ります。
  いま 作りかけ なら、そこで 止めて、作った ファイルの 名前だけ 報告して ください。
- D の 搭乗ゲートは v98 の モック どおり。最後に ひらく 画面だけ、P57 で 作る TripRoomView に つなぐ 予定です(今は 今の Trip 画面で OK)。
- それ 以外(B ・ C 4章 ・ E ・ F)は v111 の まま 進めて ください。
- CLAUDE.md も 新しく なって います。もう一度 読んで から 続けて ください。
```

## 2. P55 が 終わったら(新しい ターミナル で OK)
```
Design/LattagKit/prompts/P56_v112_font_shutter_frame.md を 読んで、その とおりに 進めて。
計画モードで 始めて、0 の しらべた 結果を 先に 報告して。
```
- 中身:字の 形(明朝 + セリフ)・ **# の レンズ = 撮る** ・ **写真の カード 3枚(Friends ・ Trip ・ Yesterday)** ・ 横スライドの Friends ページ ・ Today / Friends / Trip / きのう ・ フレーム。

## 3. P56 が 終わったら
```
Design/LattagKit/prompts/P57_v129_trip_room_chat.md を 読んで、その とおりに 進めて。
計画モードで 始めて、0 の しらべた 結果を 先に 報告して。
```
- 中身:Trip の 部屋の 作りなおし ・ 本当に 送れる チャット(字 ・ よく使う ことば ・ ステッカー ・ ひらいた 写真 ・ 既読 ・ 通知)。**iPhone 2台で ためす**。

## 守る こと(毎回)
- **1つの フォルダで 2つの フェーズを 同時に 動かさない**(P55 → P56 → P57 の 順)。
- `.p8` や トークンは チャットに 貼らない(ターミナルで `wrangler secret put … < ファイル`)。
- CloudKit の **Production に Deploy は 差分を 見て から**。
