# P47 ・ v104:Apple だけで はじめる ・ はじめての 設定の 見た目 ・ ウィジェット

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P47_v104_apple_only_onboarding.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜D の 4回に 分けて commit。
> **P44 の かわり**:P44 の うち **Google(B)と メールの リンク(C)は やらない**。P44 の A(土台)の **Apple の 部分**と D(入った あと)は この P47 の A で やる。
> **ほかの タブと 同じ フォルダで 同時に 動かさない**。

## 読む もの
1. `prompts/reference/PROMPT_v104.md`(**ここが 正解**)
2. `prompts/reference/PROMPT_v101.md` の **4-2 章**(Apple を Firebase に のせる ・ 今の 人の 引きつぎ)と v103 の **8-3**(おかえり = `UserDirectory.firebaseUID`)
3. モック `mock/lattag_v95.html`(デモ `サインイン(Apple だけ)` `Apple とじた` `Apple できない` `サインイン:おかえり` `ID シート` `招待シート` `ウィジェット(えらぶ)` `ウィジェット(ホームで 置く)`)・ 元コード `mock/src/v93.js` `v93.css`

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 5つ)。コードは 変えない。
- **A サインイン = Apple だけ**:
  - Firebase SDK 11.8 以上。Apple は nonce つきの `OAuthProvider.appleCredential` で Firebase へ。**今の Apple の 人を 引きつぐ**(v101 4-2 章)。Apple で 入る 所は **1か所に まとめる**。
  - メールを かくす スイッチ → `requestedScopes`(PROMPT 2-2)。
  - はじめて = Name / 前から いる = おかえり(`UserDirectory.firebaseUID`)。サインアウト ・ 消す 時の 入りなおし(P44 の D)。
  - Google ・ メールの コード ・ 画面が 入って いれば **消す**(PROMPT 2-4)。`/g/*` は のこす。
- **B 見た目:O04**:見出し「昨日を / 共有する SNS」・ Apple の 丸 + 動き ・ メールの スイッチ ・ 失敗の 1行(PROMPT 2-1 〜 2-3)。
- **C Name ・ ID シート ・ 招待シート**:PROMPT 3 〜 5章。シートは **中身の 高さ**(`Spacer()` を 消す)。
- **D ウィジェット**:えらぶ シート → 案内(5場面)→ もどった 時に `WidgetCenter` で たしかめる(PROMPT 6章)。設定 › ウィジェットの 古い 画面は 消す。
- 毎回:**実機で** ためす(PROMPT 8章)。モックと 見くらべる(390pt の シミュレータ)。

## 終わったら
- `PROGRESS.md` の P47 に ✓(A〜D)。P44 は「v104 で Apple だけに した(B ・ C は やめ)」と 書く。
- 報告:0 の 結果 ・ SDK の 版 ・ 引きつぎ できた 人の 数(テスト端末)・ 8章の 結果 ・ のこった 問題。
- うまく いかない 時は、画面に 出た `DEBUG ・ auth/…` の 字を そのまま 報告する。
