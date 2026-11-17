<!-- ========== v85 : Shake(ふって つながる)を なくす ・ QR で 会って つながる ========== -->
# PROMPT v85 ・ Shake を なくす(モック `lattag_v81.html`)

> **いちばん 新しい 指示**。**友だちと「ふって つながる」(Shake)は アプリから なくす**。PROMPT_v68 の Shake の 章 ・ P12 の C / D(Shake の 画面 ・ しくみ)・ v69 の Shake の 部分は **作らない / 消す**。
> 正解:モック `mock/lattag_v81.html`、元コード `mock/src/v78.css` `v78.js`、見本 `screens/F01_friend_empty` `F02_friend_list` `F06_add_friends` `O09_onboarding_fr`。

## 1. 消す もの
- Shake の 画面(ふる まえ ・ さがす ・ 見つけた ・ まつ ・ つながった)と その 動き ・ バイブ。
- **しくみ**:CoreMotion(ふった 判定)・ MultipeerConnectivity(`lattag-shake` ・ 古い `ShakeConnect` / `_later-bump`)・ 2人の OK の 処理 ・ 回数の 制限。
- **Info.plist**:`NSBonjourServices` の `_lattag-shake._tcp` `_lattag-shake._udp`(と `_later-bump`)。**ほかに ローカルネットワークを 使う 所が なければ** `NSLocalNetworkUsageDescription` も 消す(使う 所が あれば 残して 報告)。
- 入口:Friends の「ふって、つながる」の カード ・ Add friends の `Shake` ・ はじめての 設定の `ふって つながる` ・ DEBUG メニューの Shake。
- 見本:`screens/K01〜K06` ・ `motion/M15_shake_connect` は キットから 消した。

## 2. かわりに:QR で 会って つながる(Friends ・ `F01` `F02`)
- Shake の カードが あった 場所に **2枚の カード**(左右 16 ・ すきま 8 ・ 高さ 142 ・ 角丸 24):
  | カード | 見た目 | 押すと |
  |---|---|---|
  | **QR を 見せる** | 黄緑 `#C8F25A` ・ 字 黒(`QR を 見せる` 900 17 + `会った 友だちに`)・ 右下に 自分の QR(白っぽい 地 56 ・ 角丸 12)| プロフィールの チェキを 裏返して QR を 見せる |
  | **QR を 読む** | 白 8% + ふち 白 14% ・ `QR を 読む` + `カメラで 読む` ・ 右下に 読み取りの 枠(黄緑)+ 上下に 動く 線(1.8秒)| QR を 読む カメラ |
- 友だちが **0人の 時**(`F01`):2枚を **たてに 大きく**(高さ 150)。
- その 下の 小さな ボタンは **`Link` ・ `ID` の 2つ**(QR は カードに 入った ので 消す)。
- **Add friends**(`F06`):`QR ・ Link ・ Scan` の **3つを 同じ 幅で**。
- **はじめての 設定 ・ 友だち**(`O09`):`ふって つながる` を 消し、`リンクを おくる` だけ。

## 3. 確かめる こと
1. アプリの どこにも「ふる」「Shake」が 出ない(字 ・ アイコン ・ 通知 ・ DEBUG)。
2. `F01` `F02` `F06` `O09` と 比べる。
3. ビルドが 通る(消した しくみへの 参照が 残って いない)。権限の ダイアログに ローカルネットワークが 出ない(使って いなければ)。
