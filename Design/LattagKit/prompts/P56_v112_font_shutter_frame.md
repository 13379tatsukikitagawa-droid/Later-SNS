# P56 ・ Home の 作りなおし(v131 + v122 + v121 + v119 + v118 + v114 + v112)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P56_v112_font_shutter_frame.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜F の 6回に 分けて commit。
> P55 と 同じ フォルダで 同時に 動かさない。P55 の 区切りが ついて から。

## 読む もの(上ほど 新しく、ぶつかったら 上が 勝つ)
| 順 | ファイル | 使う 所 | 使わない 所 |
|---|---|---|---|
| 00 | `prompts/reference/PROMPT_v133.md` | **1章 Today の 撮る / のこりの 枠 ・ 2章 Friends の マイカード ・ 3章 上の バー(`TopBar` を ここで 作る)・ 4章 Mondo の たしかめ** | 5章(作らない もの)を 守る |
| 0 | `prompts/reference/PROMPT_v132.md` | **3章 だけ**:Today の カード = 暗室の ひも(D で 作る) | 1章 ・ 2章(Trip の 一覧 ・ プロフィール = P58) |
| 1 | `prompts/reference/PROMPT_v131.md` | **ぜんぶ**:# の レンズ = 撮る ・ NEXT の 下の **写真の カード 3枚**(Friends ・ Trip ・ Yesterday)・ スクロール 中の 小さな 列 | — |
| 2 | `prompts/reference/PROMPT_v122.md` | ぜんぶ:横スライドの Friends ページ | — |
| 3 | `prompts/reference/PROMPT_v121.md` | 4章 New trip(**3章 マイカード = v133 2章 が 勝つ**)| 1章(丸の 見た目)= v131 が 勝つ ・ **2章 Today の 3枠 = v132 3章 が 勝つ** |
| 4 | `prompts/reference/PROMPT_v120.md` | 2章 スクロールで 小さな 列(形は v131 3章) | 1章 |
| 5 | `prompts/reference/PROMPT_v119.md` | 6つの きまり ・ 5章 きのう / アルバム / この日(2章 Today は v132 3章 が 勝つ) | 3章 ・ 4章の 大きさ = v121 が 勝つ |
| 6 | `prompts/reference/PROMPT_v118.md` | 1章 撮る 近道(地球 ・ ドーム)を 消す ・ 2章 字の 形(明朝 + セリフ) | 1章の 丸 = v131 が 勝つ ・ 3〜4章 = v119 |
| 7 | `prompts/reference/PROMPT_v114.md` | 2章 NEXT の 紙の カード | 1章(丸ゴシック) ・ 下の 3つ |
| 8 | `prompts/reference/PROMPT_v112.md` | 3章 画面の フレーム(ふち) | 1 ・ 2章 |
- **作らない**:v113 2章 ・ v115 〜 v117 ・ v123 〜 v128 ・ v130(ドーム ・ タイル ・ オーラ ・ ニュース ・ コンパクト などの 案)。
- モック `mock/lattag_v120.html`(開くと v131 の Home + v133 の Today ・ Friends ・ 上の バー)・ 元コード `mock/src/v116.*`(v131)・ `v117_today.*`(v132 Today ・ `.x9t.c` だけ)・ `v119_polish.*`(v133 ・ `.t9-2` `.w9-1` `hd9` だけ)・ `v104.*` 〜 `v109.*` ・ `v99.*` ・ `v100.*`
- 見本 `screens/v133_today.png` `screens/v133_friends.png` `screens/v133_header.png` `screens/v132_today.png` `screens/v131_home_row.png` `screens/v122_friends_page.png` `screens/v121_home_a.png` `screens/v121_home_b.png` `screens/v119_home.png` `screens/v118_font.png` `screens/v112_home_frame.png`

## すすめ方
- **0 しらべて 報告**:Home の 上(レンズ ・ NEXT ・ 下の ボタン)・ 地球 / ドームの View が のこって いるか ・ `Typo` の 中身 ・ 入って いる フォント。
- **A 字の 形**(v118 2章):Noto Serif JP Black を 切って 入れる(`Later Mincho`)・ `Typo.title` ・ 見出しの 置きかえ ・ あふれ チェック。
- **B Home の 上**(v131 1〜3章 + v118 1章 + v114 2章 + **v133 3章 の `TopBar`**):地球 ・ ドーム ・ 古い ボタンを 消す → **# の レンズを 押すと 撮る** ・「タップで 撮る」・ NEXT ・ **写真の カード 3枚** ・ スクロール 中の 小さな 列。
- **C 横スライドの Friends ページ**(v122)。
- **D Today ・ Friends ・ Trip の かたまり**:**Today = v132 3章 + v133 1章(次の 1枚 だけ)**・ **Friends = v133 2章(マイカード 1枚)**・ Trip = v121 4章 + v119 4章。
- **E きのう ・ アルバム ・ この日**(v119 5章:日本語 ・ ライム ・ Mondo の とりこぼしを 消す)。
- **F フレーム**(v112 3章)。
- 毎回:390pt の シミュレータで モックと 見くらべる。**9:00 まえに 友だちの 本物の 写真を はっきり 出さない**(Yesterday の カードは ぼかし + 鍵)ことを 確かめる。

## 終わったら
- `PROGRESS.md` の P56 に ✓(A〜F)。報告:Home の スクショ(上 ・ 9:00 まえ / あと ・ スクロール 中 ・ Today ・ Friends ・ Trip 0件 ・ きのう)・ フォントで ふえた 大きさ(MB)。
