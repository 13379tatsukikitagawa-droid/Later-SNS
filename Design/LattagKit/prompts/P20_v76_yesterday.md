# P20 ・ v76:Lattag yesterday(Friends = BeReal の 形 ・ Mondo = 壮大 ・ タブ = Apple 標準)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P20_v76_yesterday.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。
> **P19 の B は やらない**(この P20 が 置きかえ)。P19 の A(Home の 帯)と C(ME)は そのまま。

## 読む もの
1. `prompts/reference/PROMPT_v76.md`(**ここが 正解**)
2. `mock/src/v72.css` ・ `mock/src/v72.js`
3. 見本 `screens/Y01〜Y09`、動き `motion/M22_mondo_intro.png`

## すすめ方
1. 今の Lattag yesterday の 画面と タブの 作りを 調べて 報告(自作の タブバーが あれば 一覧に)。
2. **タブ**を 標準の `TabView`(Friends / Mondo)に。
3. **Friends**:あなたの きのう → ロックの 帯 → 投稿(大きな 1枚 + 小さな 2枚 ・ 入れかえ)→ まだ 公開して いない 友だち(キャプション + ぼかし)。`Y01` `Y02` `Y04` `Y07` と 比べる。
4. **Mondo**:大きな 場面(Mondo の 字 ・ 回る 地球 ・ 数字)→ 出て くる 動き → 説明 → 投稿 あり / だれも いない。`Y03` `Y05` `Y08` `Y09` ・ `M22` と 比べる。
5. DEBUG の 状態メニューに「Mondo:投稿 あり / だれも いない」「友だち:公開 / まだ」を 足す。

## 終わったら
- `PROGRESS.md` の P20 に ✓(Friends / Mondo / タブ)。git commit(3つに 分ける)。報告は 短く。
