# 画面の 地図 ── どこから 開くか / モックの どこに 書いてあるか

`mock/src/` の 中を、下の **関数名** や **見出しコメント**(`/* ===== v36 ... ===== */` など)で 検索すると 元の コードが 見つかる。
CSS は `mock/src/style.css` の **後ろの 行ほど 優先**(古い版の 上に 新しい版を 上書きしている)。同じ 部品に 何回も ルールが あるので、**最後に 書かれた 値**か `MEASURED_SPEC.md` の 実測値を 使う。

---

## 1. Home(today)

| 項目 | 内容 |
|---|---|
| 見本 | `A01_home_today` / `A02_home_after_shot` / `A04〜A07_home_scroll*` |
| 実測 | `MEASURED_SPEC.md` の A01 / A02 / A05 |
| 上の 帯 | `#hhd`(高さ 150・背景 #EFEFEA 74% → 透明 + ぼかし 12)。`Later`(Inter 900 32pt 字間 -2.08)・`today / yesterday`(Instrument Serif Italic 16pt)・右上の 丸(52pt の 緑の 玉 + 赤い 点) |
| ピル | `#hst.lp` 235 × 36 ・ 角丸 18 ・ ガラス。左から 緑の リング → 「消灯まで」→ 時刻(数字が 縦に 回る)→ 3つの 緑の 棒 → 残り数 → ⌄ |
| まんなか | **写ルンです の カメラ本体** `#orb`(黒 #121212 の 本体 + 緑 #24A03C の 帯 + 左の 白/赤/金 の 3本線)。中央に レンズ `#lens`(193pt)・その中に `Shoot` / `Yesterday`(Instrument Serif 54 / 42pt)と `3 LEFT`(Space Mono 13pt)。外側に 回る 文字の 輪 `#ring`(`LATER — TODAY — YESTERDAY — 3 SHOTS A DAY — 11.13`) |
| 四すみの ボタン | `#osat .osb`(丸 65〜70pt ・ 下に Space Mono 7pt の ラベル札)。**撮る前**: YESTERDAY(左上・ロック)/ NEW GROUP(右上)/ MONDO(左下・ロック)/ FRIENDS(右下・白)。**撮った後**: SHOOT / DEVELOP / NEW GROUP / MONDO。中身は `v32 まんなかの 万能ボタン` |
| 飾り | 左上 ✦、右上 〰、右下 ✿(赤い 芯)、左下 ∴。`Later` ロゴ(Inter 900 Italic 20pt)と `FILM FOR TOMORROW` |
| いちばん下 | **「今日を撮る」= 地球** `#hmoon`(直径 600pt の 円を y=712 に 置き、上の 約 130pt だけ 見せる)。黒い 球に 点の 地図(`canvas#mgl`)・ふちに **白/赤 #D8262C/金 #C8A46A の 3本線**(`.mat`)。文字 `今日を撮る` / `もう1枚 撮る`(Inter 900 25pt 白)+ `●●● のこり 3こま`(#9ED6A5)。コード: `v40 今日を撮る = 地球` |
| 下へ スクロール | 緑 → 黒の グラデ(`#dusk`)で 暗室へ。`Today 1/3` カード → `ACTIVE` → `YESTERDAY`(大きな 写真カード)→ 写真の グリッド → `ALBUMS`(`7 DAYS · RECAP ›`)。コード: `v28 暗室` |

## 2. 「消灯まで」ピル → ライブパネル

| 項目 | 内容 |
|---|---|
| 見本 | `A03_live_panel` |
| 実測 | A03 |
| 開き方 | ピルを 押す → ピルが 下に 伸びて パネルに なる(`openLive` / `lpTick`、`v46.js`) |
| パネル | `#lpk` 366 × 305 ・ x12 y97 ・ 角丸 36 ・ 背景 **#050506**(茶色に しない) |
| 中身 | `● LIVE`(Space Mono 9.5pt #7EE08F の 枠付き)+ 時刻 → `ひらくまで`(Inter 600 12pt #8C8C93)→ **大きな 時刻 `18:40`(Inter 900、`:` は 灰色の 2つの 点)+ 秒 `56`(緑 #3BD35A)** → `消灯まで 9h 40m` → 進行バー(緑・高さ 8・`0:00 / 9:00 / 24:00(赤)/ 9:00 OPEN(緑)`)→ 下の 列: **小さな 正方形 3つ(DEV の 写真 / + / +)と、右の 大きな 白い `shoot  2 LEFT` ボタン(186 × 54)** |

## 3. Later yesterday(today / yesterday の yesterday 側)

| 項目 | 内容 |
|---|---|
| 見本 | `B01`(ロック)/ `B02` / `B08`(撮った後)/ `B10〜B15`(Mondo)/ 夜 `N01` `N02` |
| 実測 | B01 / B08 / B03 / B10 |
| Groups タブ | ① **ヒーロー** `.yoh`(354 × 470 ・ 角丸 32):背景に きのうの 写真 4枚(2×2)を **ぼかして**(ロック中は blur 18・saturate .45・brightness 1.1・1.12倍)、上に 黒の グラデ。`GROUPS · NOV 12`(Space Mono 10pt)・ロック中は `🔒 shoot today to open` の ガラスピル・**`Yesterday, together.`(Instrument Serif 46pt 白)**・グループが あれば その名前に かわる・統計 3つ(`0 Groups` `18h To open`/`6d Left` `0 Friends ›`)・**白い `+ Create`(262 × 56)と 丸い QR(56)**。② グループが あれば `ACTIVE` の 横カード(写真背景・名前・pending・チャット)。③ **ME カード**(`#yme`)。④ **Friend カード**(`yFriends` `v49.js`):`Friend 3/12`・`● 2 today`・`›`・緑の `+ Add` と 友だちの 丸。**ここまで**。古い「グループ」見出し・グループの 縦の 一覧・ピン・`1/1` の 輪・「昨日は、まだ届いていません」は **出さない**(モックの CSS で `#ytg #yglist ... {display:none}` に している) |
| Mondo タブ | `MONDO · NOV 12`(緑の 点)→ **`The w🌐rld,` / `yesterday.`**(Instrument Serif、o が 回る 地球、`yesterday.` は 緑 Italic + 黄緑の 下線)→ 世界時計の 流れる 帯 → `TODAY'S ONE` の 大きな 写真カード(`#夕焼け` シール・`鎌倉市`)→ `WORDS TOP 5` → `MORNING NOW`(時間の グラデ帯)→ `MAP 12 PLACES` → `EVERYONE`(2列の 写真・地名・時刻 印字)→ `Your one` カード。ロック中は 中身が ぼけて `shoot today to open`。コード: `v37 Mondo` と `moHead()`(`v49.js`)|
| タブバー | モックは ガラスの 2つボタン(Mondo / Groups)。**実機は Apple 純正の Liquid Glass の タブバー**に する(プロンプト本文 参照) |

## 4. Friend

| 見本 | `C01_friend` | 実測 | C01 |
|---|---|---|---|

コード: `v48.js`(`fRender` `fSeats` `fCore` `fMeCard` `bumpBurst`)と `v49.js`(`Friend` の F を 大文字)。

## 5. ME(7日の フィルム と Recap)

| 項目 | 内容 |
|---|---|
| 見本 | `C02_me` / `C03・C04_recap_play` |
| 実測 | C02 / C03 |
| 開き方 | Later yesterday の **ME カード**、Home 暗室の **ALBUMS 見出し**、Profile の **ME · 7 DAYS** と **SHOTS / KEPT**。**右上の 丸からは 開かない**(右上の 丸 = Profile) |
| 中身 | 上: 戻る丸 + `ME`(Inter 900 46pt)+ `NOV 6 — NOV 12`。**Recap カード**(362 × 430・写真 2×2・`RECAP`・`Your`(62pt)/`week.`(70pt Italic #C8F25A)・`20 shots 7 days 7 kept`・▶)→ `Film / Cheki / Beat` の 切りかえ → 横に 流れる フィルム → 日ごとの 写真(`Thu NOV 12 … 6D LEFT`)。コード: `v50.js` |

## 6. Profile(右上の 丸を 1回 押す)

| 項目 | 内容 |
|---|---|
| 見本 | `D01_profile` / `D02_profile_scroll` / `D03_profile_edit` |
| 実測 | D01 / D03 |
| 開き方 | 右上の 丸から **円が 広がって ひらく**(680ms)→ チェキが 上から 落ちてくる(820ms)→ シールが 1枚ずつ ポンと 貼られる(110ms ずつ・毎回 小さく バイブ)→ 下の 中身が 下から 出る。コード: `openPrf()`(`v51.js`) |
| 上 | 左に ⌄ の 丸(閉じる・42pt)・まんなかに `@yui_0612`(Space Mono 11pt)・右に ⚙ の 丸 |
| チェキ | 241 × 299 ・ 少し 傾く ・ 上に 黄緑の テープ ・ 写真 + 印字 `'26 11 13`(オレンジ)・下に 手書きの 名前。**まわりに ハッシュタグの シール 6枚**(色は TOKENS 参照)。押すと 裏返って QR(`SCAN TO ADD`)。長押しで シールが はじけて 戻る。シールは 指で 動かせる |
| 下 | 大きな 名前 `ゆい`(54pt)・`SINCE Oct 2026` → **統計 4つ**(DAY STREAK / SHOTS / KEPT / FRIEND 3/12)→ **4つの ボタン QR(緑)/ Edit / Share / Scan**(84 × 82・文字は 英語 Instrument Serif 17pt)→ `ME · 7 DAYS` の 写真列 + 白い `Recap ▸` → `1 YEAR · KEPT` の 点の 表 → 設定(通知・言語・ブロック・ヘルプ・ログアウト)|
| Edit | その場で 直す モード(v52):上に `キャンセル / Edit / 完了`、下に Photo / Name / Tags の 欄。コード: `v52.js` |
| 使わない もの | 「PERSONA ・ 夕凪のかげ #4053」、日本語の ボタン名(編集・共有・スキャン)、「カレンダー(日めくり)⌄」、オレンジの フィルム帯 |

---

## 実機で ずれていた ところ(スクリーンショット から)

| # | 実機 | モック(正) |
|---|---|---|
| 1 | Later yesterday の Mondo が **世界時計の 帯だけで 真っ黒** | 見出し `The world, yesterday.` から 下まで 全部(B10〜B15、夜 N02) |
| 2 | タブバーが ただの 灰色の 角丸と 文字(アイコン 無し)。中身と 重なる | Apple 純正の Liquid Glass タブバー(アイコン + 文字) |
| 3 | ライブパネルが **茶色・オレンジの バー・細い 数字・同じ 大きさの 3つの 箱 + 横長の shoot** | A03(黒 #050506・Inter 900 の 太い 数字・緑の バー・小さな 正方形 3つ + 右に shoot) |
| 4 | Later yesterday に **古い グループ一覧(ピン・1/1 の 輪・「グループ」見出し)**が 残る。ME カードが 上の 帯に 重なる。Friend が 薄い | B01 / B02 / B08(ヒーロー → ME → Friend だけ。上の 帯は 不透明 + ぼかし) |
| 5 | ヒーローが **ただの 黒い 箱**(写真の ぼかし 無し) | 写真 2×2 を ぼかした 背景 + `Yesterday, together.` |
| 6 | Home が **古い 輪の デザイン**(SHOOT/DEVELOP/CHAT/NEW GROUP の 丸)、下の 「もう1枚 撮る」が **オレンジ〜紫の 小さな 半円** | A01 / A02(写ルンです の 本体 + 地球の 半円) |
| 7 | 全体に **オレンジ**(リング・時刻・ME の 文字・フィルム) | 緑 / 黒 / 白。オレンジは 写真の 日付の 印字だけ |
| 8 | 右上の 丸 → **「ME きょうも いちまい。」の 画面**に 行く | 右上の 丸 → **Profile**(D01)。ME は 別の 入口 |
| 9 | Profile が 別物(写真が 大きい だけ・シール 無し・日本語の ボタン・カレンダー⌄・PERSONA) | D01 / D02 / D03 |
