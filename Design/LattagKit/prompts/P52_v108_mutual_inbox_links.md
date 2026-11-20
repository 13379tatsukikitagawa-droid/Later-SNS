# P52 ・ v108:相互フォロー ・ お知らせ ・ 通知 ・ LINE から 入れる リンク

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P52_v108_mutual_inbox_links.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜D の 4回に 分けて commit。
> P51(Xcode 27)より 先。P46 の A(友だち ・ 申請 を Cloudflare へ)は **この P52 の A で やる**。

## 読む もの
1. `prompts/reference/PROMPT_v108.md`(**ここが 正解**)
2. `prompts/reference/PROMPT_v103.md`(Cloudflare の 置き場所 ・ 本人確認 ・ 8-2 招待の 穴)
3. モック `mock/lattag_v96.html`(デモ `お知らせ` `相手が 承認した(通知)` `送る 文(友だち)` `送る 文(Trip)`)・ 元コード `mock/src/v96.js` `v96.css`
4. `hosting/`(ページ ・ 画像 ・ AASA ・ firebase の 設定の 見本)

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 6つ)。コードは 変えない。
- **A 相互フォロー**:Worker + D1(`friend_requests` ・ `friendships` ・ `notifications` ・ 端末トークン)・ 申請 / 承認 / おたがい申請 / 消す ・ Friends と カードの 承認ボタン。**テストを 先に**(2人の 流れ)。
- **B Home の 上 + お知らせ**:まんなかの Lattag ・ 左の ベルと 数 ・ お知らせ 画面(友だち ・ Trip)・ 承認 / 参加の 動き。
- **C 通知(push)**:Worker → APNs。キーの 入れ方は たつきさんに 手順を 出す(チャットに 貼らせない)。
- **D リンク**:`AppLinks` ・ 送る 文 ・ `hosting/` を 今の Hosting に 合わせて 足す(`/g/*` を こわさない)・ アプリの 受け取り(`/u` `/t` `/g`)・ 貼りつけ。**Hosting の デプロイは たつきさんの 確認の あと**。
- 毎回:実機 2台で ためす(PROMPT 7章)。

## 終わったら
- `PROGRESS.md` の P52 に ✓(A〜D)・ P46 の A に ✓。報告:0 の 結果 ・ 2台で ためした 結果 ・ LINE で 送った 時の 見え方の スクショ。
