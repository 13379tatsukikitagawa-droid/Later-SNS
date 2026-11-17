# P12 ・ v68 最終ブラッシュアップ(Home フルブリード ・ Friends ・ Shake)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P12_v68_home_friends_shake.md` を 読んで、その とおりに 進めて」と だけ 伝える。
> ルールは リポジトリの `CLAUDE.md`。**計画モードで 始めて、計画を 見せて から 作る**。キットの 場所:`Design/LattagKit/`(以下 `Kit/`)。

## 読む もの(この 順)

1. `Kit/prompts/reference/PROMPT_v68.md`(**いちばん 新しい 指示。ぜんぶ 読む**)
2. `Kit/mock/src/v65.css` `Kit/mock/src/v65.js`(約 300行。値は ここが 正解)
3. 見本:`Kit/screens/H01_home.jpg` `H04` `H06` `H09` `H11〜H17`、`F01_friend_empty` `F02_friend_list` `F03_friend_requests` `F04_friend_scroll`、`K01〜K06`、数値 `Kit/spec/screens/<ID>.json`
4. 動き:`Kit/motion/M15_shake_connect.png` `M16_home_focus.png`
5. 重さの 決まり:`Kit/prompts/P11_performance.md`(あれば)と PROMPT_v68 の 5章

## 作る 順番(1つ 終わる ごとに ビルド → スクショ → 見本と 比べる → commit)

### A. Home フルブリード(PROMPT_v68 の 1章)
- カードの 台を 消し、ぼかした 写真を 画面 いっぱいに。**ぼかしは 小さな 画像を 1回だけ ぼかして 引きのばす**。
- ページの カードを 透明に、うしろの 写真を ページ位置で 入れかえる。
- ヘッダーを 白い 字 + ガラスに。アバターを 自分の 写真に(にこちゃんを やめる)。スクロールで ぼかしの 帯。
- 下の つなぎ(深い 緑)と 月(緑の ガラス)。ピント合わせ ・ 視差。
- 実機の 左上で ロゴに 重なって いる ボタンを 直す。
- 比べる:`H01` `H04` `H06` `H09` `H11` `H13` `H15` `H17` `L01`。

### B. Friends 画面(2章)
- 今の Friend 画面(点線の 丸 ・ キャラクター ・ `0 / 12`)を **ぜんぶ 置きかえる**。データ ・ 申請 ・ つつく ・ チャットの 仕組みは 変えない。
- 比べる:`F01` `F02` `F03` `F04`。**友だちの 数が どこにも 出ない こと**。

### C. Shake モードの 画面と 動き(3章の 3-1 ・ 3-2)
- 5つの 状態を DEBUG の 状態メニューから 出せる ように(見本の 相手で)。
- 比べる:`K01〜K06` ・ `M15`。

### D. Shake の 本物の しくみ(3章の 3-3)
- **作る前に ユーザーに 聞く**(下)。OK なら CoreMotion → MultipeerConnectivity → Cloud Functions(`shakeMatch` `shakeConfirm`)。
- サーバーが まだ なら、C まで で 止めて 報告。

## 作る前に ユーザーに 聞く こと

1. Shake の 本物の しくみ(D)を 今 作るか。Cloud Functions を 2つ 足す 必要が ある。
2. アプリの 最低の iOS 版(Liquid Glass は iOS 26、波紋 ・ 視差は iOS 17、ズーム遷移 ・ MeshGradient は iOS 18。古い 版には 代わりを 出す)。

## 終わったら

- `Kit/PROGRESS.md` に「P12 v68」の 行を 足して ✓、A〜D ごとに **git commit**。
- `PERF.md` に Home ・ Friends ・ Shake の CPU と カクつきを 書く。
- 報告:できた もの / のこり / 気に なる 所。
