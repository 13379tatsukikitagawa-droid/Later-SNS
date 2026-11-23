# P58 ・ Trip の 一覧 ・ プロフィール ・ Today の カード(v132)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P58_v132_trip_profile_today.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。0 〜 D の 5回に 分けて commit。
> **順番**:P55 → P56 → P57 → **P58**。同じ フォルダで 同時に 動かさない。
> Today の カードは P56 の D でも 作る(P56 に v132 3章 を 読む 行を 足した)。P56 で もう できて いれば、ここ(C)は たしかめる だけ。

## 読む もの(上ほど 新しく、ぶつかったら 上が 勝つ)
| 順 | ファイル | 使う 所 | 使わない 所 |
|---|---|---|---|
| 0 | `prompts/reference/PROMPT_v133.md` | **3章 上の バー**(Friends / Trip の 画面に P56 の `TopBar` を 使う)・ **1章 Today**(C で たしかめる)・ 4章 Mondo | 2章(Home の マイカード = P56) |
| 1 | `prompts/reference/PROMPT_v132.md` | **ぜんぶ**(1章 Trip の 一覧 ・ 2章 プロフィール ・ 3章 Today ・ 4章 作らない もの) | — |
| 2 | `prompts/reference/PROMPT_v129.md` | Trip の 部屋(パスを 押した 行き先 だけ) | 部屋の 中の 見た目(P57 で 作った まま) |
| 3 | `prompts/reference/PROMPT_v110.md` | Trip の データ(いま / これから / おわった ・ Trip の 色) | 週の 帯の 箱 ・ カードの 見た目 = v132 が 勝つ |
| 4 | `prompts/reference/PROMPT_v95.md` | ボタンの 行き先(リンク = 共有 ・ QR = 自分の QR ・ 読む = カメラ) | — |
| 5 | `prompts/reference/PROMPT_v86.md` | ME の 写真の 置き場所(`me` ゾーン)| — |
| 6 | `prompts/reference/PROMPT_v93.md` | 現像の ぼかし(1回 作って 不透明度 だけ) | — |
- モック `mock/lattag_v120.html`(ひらくと この 形)。元コード `mock/src/v117_trip.*` ・ `v117_prof.*` ・ `v117_today.*`(**決まった 案だけ**:`v8hC` `v8hPeek` / `.vpr-b` / `.x9t.c`)。
- 見本 `screens/v133_header.png` ・ `screens/v132_trip.png` ・ `screens/v132_profile.png` ・ `screens/v132_today.png` ・ `screens/v118_brushup.png`。

## すすめ方
- **0 しらべて 報告**(作る 前に):
  1. `TripHubView` の 今の 部品(週の 帯 ・ カード)と、Trip の 部屋へ 行く 道(P57 の `TripRoomView` に つながって いるか)。
  2. プロフィールの View 名 ・ P55 B 1章 で 作りかけた 物が あるか ・ 数字(連続 ・ 撮った ・ ひらいた)を 出す 関数が あるか。
  3. Today の カード が v121(3枠 + 線)か v132(ひも)か。
  4. QR ・ 読む ・ 共有の 画面を プロフィールの 上に 出す 方法(sheet / fullScreenCover / 重ねた `UIWindow`)。
- **A Trip の 一覧**(v132 1章):**まず 上の バーを P56 の `TopBar` に かえる**(v133 3章 ・ Friends と Trip で 高さ ・ 位置 ・ 書体 ・ 写真 ・ 通知の 数が Home と 同じ)→ 帯(箱 なし)→ パスの 束(並び ・ 入れかえ ・ 立ちあがり)→ ひらいた 写真の 行 → 新しい Trip / KEY → Album。古い カードの View と 数の 行は **消す**(v98「古い 画面は 消す」)。
- **B プロフィール**(v132 2章):上(小さな チェキ + 名前 ・ スクロールで バーが かわる)→ 数字 3つ → ボタン 4つ(行き先)→ くっつく タブ → 3列(きょう ・ 9:00 まえの 鍵 ・ はじめての 日)。
- **C Today の カード**(v132 3章 + v133 1章):まだ v121 なら ひもに 作りなおす。撮る は 白い チェキ + ライムの 丸、のこりは 番号の 丸 だけ。できて いれば 数字と 動きを モックと 見くらべる。
- **D たしかめ**:
  - 390pt の シミュレータで モックと 見くらべ(`tools/compare.py`)。状態メニューに 足す:Trip 0 / 1 / 3件 ・ プロフィール 0日 / 2週間 ・ Today 0 / 1 / 3枚 ・ 時刻(11:40 / 21:30 / 8:50)。
  - **9:00 まえに 友だちの 写真 ・ きょうの 写真を はっきり 出さない**(Trip の 写真の 行 ・ プロフィールの マス)。
  - ライムは 1かたまりに 1つ(Trip = 前の パスの → ・ プロフィール = 送る ・ Today = 撮る か ライムの 札)。
  - 押せる 所 44pt ・ 写真の 上の 字 9.5pt ・ Reduce Motion ・ 画面外で 動きを 止める ・ Instruments で ヒッチ 0。

## 終わったら
- `PROGRESS.md` の P58 に ✓(0 〜 D)。報告:3画面の スクショ(上の 状態 ぜんぶ)・ 消した View の 名前 ・ 気に なった 所。
