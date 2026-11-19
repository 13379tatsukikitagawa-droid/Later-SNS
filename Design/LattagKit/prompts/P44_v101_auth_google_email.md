# P44 ・ v101:Google と メールで サインイン(Firebase)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P44_v101_auth_google_email.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜D の 4回に 分けて commit。
> **ほかの タブと 同じ フォルダで 同時に 動かさない**。

## 読む もの
1. `prompts/reference/PROMPT_v101.md`(**ここが 正解**)
2. `prompts/reference/FIREBASE_SETUP_v101.md`(たつきさんの 設定。**終わって いるか 最初に 聞く**)
3. `prompts/reference/swift/AuthService_v101_example.swift`(形の 見本)
4. 見本 `screens/O04 O05 O06 O25〜O31` ・ モックの デモ `サインイン:…`

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 6つ)。コードは 変えない。たつきさんに 設定の ☑ を 聞く。
- **0 の 答え(決まった)**:**案1**(PROMPT 4-2 章)。設定は たつきさんが `FIREBASE_SETUP_v101.md` で 終わらせて から A へ。
- **A 土台**:Firebase SDK を 11.8 以上(できれば 最新)に ・ 古い Dynamic Links の のこりを 消す ・ GoogleSignIn-iOS(SPM)・ `REVERSED_CLIENT_ID` ・ Associated Domains ・ URL の 受け取り(`.onOpenURL` + `.onContinueUserActivity`)・ `AuthService`。**Apple を Firebase に のせて 今の 人を 引きつぐ(4-2 章)**。Apple で 入れるか を すぐ 確かめる。
- **B Google**:`O04` の ボタン → 入れる / キャンセルは 静か / エラー。
- **C メールの リンク**:おくる(`O05` `O25` `O06` ・ 60秒) → おくれない(`O26`)→ もどって きた(`O27`)→ 別の 端末(`O29`)→ 古い(`O30`)。
- **D 入った あと**:はじめて = Name / 前から いる = おかえり(`O28`)→ Home ・ 登録 済み(`O31`)+ つなぐ ・ サインアウト ・ 消す 時の 入りなおし。
- 毎回:**実機で** ためす(PROMPT 7章)。見本と 比べる。

## 終わったら
- `PROGRESS.md` の P44 に ✓(A〜D)。報告:0 の 結果 ・ SDK の 版 ・ ためした 結果(7章の 6つ)・ のこった 問題。
- うまく いかない 時は、画面に 出た `DEBUG ・ auth/…` の 字を そのまま 報告する。
