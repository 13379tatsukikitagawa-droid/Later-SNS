# 色 と 書体(モック v52 から そのまま)

## 1. 書体 ── 6つだけ。すべて 無料(SIL OFL)・Google Fonts から 入手できる

| 役目 | 書体(ファイル) | 太さ | どこで 使うか(例) |
|---|---|---|---|
| 本文・ボタン・ロゴ | **Inter** | 500 / 700 / 800 / 900 | `Lattag` ロゴ(900 ・ 字間 -0.065em)、ボタン文字、`ME` の 大きな 字(900)、ハッシュタグの シール(900) |
| 見出し(英語) | **Instrument Serif** | Regular / *Italic* | `Shoot` `Yesterday` `Yesterday, together.` `Friend` `Your week.` `Film/Cheki/Beat` `QR/Edit/Share/Scan` の 文字、統計の 数字(`0` `18h` `6d`) |
| 見出し(日本語) | **Noto Serif JP Bold**(モックでは `Later Mincho` という 名前で 埋め込み) | 700 | 大きな 名前「ゆい」、`放課後クラブ` など 英語見出しの 中に 入る 日本語 |
| 小さな ラベル・時刻 | **Space Mono** | Regular / Bold | `LIVE` `GROUPS · NOV 12` `9:00 OPEN` `DAY STREAK` `@yui_0612` `'26 11 13` |
| 手書き | **Caveat SemiBold** | 600 | チェキの 下の 名前(36pt / 34pt) |
| 手書き(日本語) | **Klee One SemiBold** | 600 | Caveat に 無い 日本語(「ゆい」)を 書くとき ※ モックは ブラウザ まかせ なので、ここだけは こちらの 指定 |

### 書体の 大事な ルール

- **英語用の 書体には 日本語の 字が 無い**。iOS は 足りない字を 勝手に ヒラギノ角ゴ に するので、モックと 見た目が 変わる。
  - Instrument Serif の 後ろには **Noto Serif JP Bold** を つなぐ(`UIFontDescriptor` の `.cascadeList`)。
  - Caveat の 後ろには **Klee One SemiBold** を つなぐ。
  - Inter と Space Mono の 後ろは iOS の 標準(ヒラギノ角ゴ)で よい。
- 大きさは **固定**(`Font.custom(名前, fixedSize: pt)`)。モックの pt を そのまま 使う。Dynamic Type で 大きく しない(画面ごと 崩れるため)。
- 字間: モックの `letter-spacing`(px)= SwiftUI の `.tracking(pt)`。`MEASURED_SPEC.md` の「字間」の 値を そのまま 入れる。
- `text-transform: uppercase` の 所は 文字を 大文字に して 表示(`textCase(.uppercase)`)。
- イタリック: Instrument Serif の Italic ファイルを 使う(SwiftUI の `.italic()` で 斜めに しない)。

## 2. 色

### 基本(写ルンです の 配色)

| 名前 | 色 | 使う 所 |
|---|---|---|
| `film` | **#24A03C** | カメラ本体の 緑、QR ボタン、Add ボタン、進行バー |
| `filmLight` | **#3BD35A** | 光る 緑(リング・ドット・数字の アクセント) |
| `filmPale` | #9ED6A5 | 薄い 緑(「のこり 3こま」の 文字・波紋) |
| `liveGreen` | #7EE08F | `LIVE` `9:00 OPEN` など 暗い 所の 緑の 文字 |
| `lime` | #C8F25A | テープ・`week.`・`Oct 2026` など アクセント(**黄緑**) |
| `body` | #121212 | カメラの 黒い 本体 |
| `red` | #D8262C | 24:00 の 線・赤い 点・帯の 赤 |
| `gold` | #C8A46A | 帯の 金・★(kept) |
| `stamp` | #FF9A3C / #FF8A3D | **写真の 日付の 印字だけ**(`'26 11 13` `17:42` `FRI` `ME · 7 DAYS`)。**ほかに オレンジは 使わない** |

### 昼(9:00〜21:00)

| 名前 | 色 |
|---|---|
| 背景 | #EFEFEA(Home)/ #FFFFFF(Lattag yesterday) |
| 文字 | #111111 |
| 薄い 文字 | #86868C / #8E8E93 / #6E6E73 |
| ガラスの ピル | 上 rgba(255,255,255,.80) → 下 rgba(244,244,246,.56) + ぼかし 16 + 彩度 1.8 |

### 夜(21:00〜9:00)・暗い 画面(Friend / ME / Profile / Recap / 暗室)

| 名前 | 色 |
|---|---|
| 背景 | #000000 / #050505 / #0A0A0B |
| カード | #161618 / #121214(55% + ぼかし 18) |
| 線 | rgba(255,255,255,.12〜.16) |
| 文字 | #FFFFFF |
| 薄い 文字 | #8C8C93 / #8E8E95 / #C9C9CF |

- 昼と 夜で 変わるのは **色だけ**。部品の 形・大きさ・書体・位置は **同じ**(見本: `B01` と `N01`、`B03` と `N02`)。
- 見本の 夜画面: `screens/N01_night_yesterday_groups.png` `screens/N02_night_yesterday_mondo.png`。

### ハッシュタグの シール 6色(Profile・Friend の チェキ)

| 背景 | 文字 |
|---|---|
| #C8F25A | #111111 |
| #EE5E9C | #FFFFFF |
| #9ED8FF | #111111 |
| #FFD60A | #111111 |
| #9B8CFF | #FFFFFF |
| #61D278 | #111111 |

影: `3pt 4pt 0` の 黒 50%(ずらした 平らな 影)・角丸 14。

## 3. 角丸・影 の よく出る 値

- ピル(消灯まで / ひらくまで): 高さ 36・角丸 18。
- 大きな カード: 角丸 30〜36(ライブパネル 36、Lattag yesterday の ヒーロー 32)。
- ボタン(Profile の QR/Edit/Share/Scan): 84 × 82・角丸 22。
- 丸ボタン(戻る・設定): 42 × 42・白 12% + ぼかし 14。
- 細かい 値は `MEASURED_SPEC.md` が 正。
