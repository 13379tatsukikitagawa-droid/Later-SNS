# Lattag v133 を Claude Code に渡すセット

## 送り方（3ステップ）

1. このフォルダ `design-v133` をまるごと、アプリのプロジェクトのいちばん上の階層に置き、名前を `design/v133` にする
   （例：`APP later/design/v133/`）。Xcode のターゲットには入れない
2. Claude Code に、これだけ送る

   > `design/v133/00_PROMPT_v133.md` を読んで、Phase 0（調査と報告）だけやって。コードはまだ変えないで。

3. 報告が来たら「6. 仕様が変わるところ」の質問に答えて、「Phase 1 をやって」と送る。以後 Phase ごとに同じくり返し

## 中身

| ファイル | なに |
|---|---|
| `00_PROMPT_v133.md` | Claude Code への指示書（これが本体） |
| `lattag_v133.html` | 正解のデザイン（動くモック・仕様書つき） |
| `screens/` | 全画面のスクショ 38枚（番号は指示書と対応） |
| `fonts/` | Barlow Condensed ExtraBold・Space Mono Bold（SIL OFL・同梱してよい）と許諾文 |
| `assets/` | ロゴ・#・#レンズの SVG |
| `reference/` | 色・字・触感・#レンズ・長押し・現像の Swift 参考コード |

## 気をつけること

- 12/10〜12/17 は実験期間。Phase 1〜3 を 12/7 までに TestFlight へ出せなければ、残りは実験のあとに回す
- 「仕様が変わるところ」は、Claude Code が勝手に決めず必ず聞いてくるように書いてある
