# P45 ・ v102:利用規約 と プライバシーポリシーを つなぐ

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P45_v102_legal_links.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。小さな 作業なので **1回で 終わらせて よい**(A + B を 1 commit)。
> **ほかの タブと 同じ フォルダで 同時に 動かさない**。**P44(サインイン)が 動いて いる 間は 同じ ファイルを さわらない**(サインイン画面は P44 の ほうが 先)。

## 読む もの
1. `prompts/reference/PROMPT_v102.md`(**ここが 正解**)
2. `prompts/reference/swift/LegalLinks_v102_example.swift`(形の 見本)
3. モック `mock/lattag_v92.html`:デモ `規約を ひらく` `プライバシーを ひらく`、`サインイン:…` の 下の 字、`設定を ひらく` → サポート。元コード `mock/src/v92.js`

## すすめ方
- **0 しらべて 報告**(PROMPT 2章の 4つ)。コードは 変えない。
- **A 土台**:`LegalLink`(URL を 1か所に)・ `SafariView`(`SFSafariViewController`)・ `legalSheet`。単体テスト(URL が https ・ 同じ 表)。
- **B つなぐ**:サインイン画面の 下の 字(押せる 2語 ・ 44pt ・ 重ねない)・ 設定 > サポート の 2行。古い「ヘルプ ・ 利用規約」の 行が のこって いれば 消す。
- 実機で ためす(PROMPT 6章)。

## 終わったら
- `PROGRESS.md` の P45 に ✓。報告:0 の 結果 ・ つないだ 場所 ・ ためした 結果 ・ **英語の 時の ページ(日本語のみ)を どうするか**の 質問。
