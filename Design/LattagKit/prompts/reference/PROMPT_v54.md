# v54 ── 実機を モック v52 と「完全に 同じ」に する

> **この プロンプトは v53 を 置きかえます**(v53 には モックと 違う 指示が 入っていたため。v53 は 使わない)。
> 見本 一式 `MockReference/` を リポジトリの **`Design/MockReference/`** に 置いてから 始めてください。
> 目的は 1つ: **見た目・大きさ・書体・色・動き・バイブ・画面の つながりを モックと 同じに する**。新しい デザインは 足さない。

## 守ること(さわらない)

- CloudKit の 保存 ・ 招待リンクの 発行 ・ 招待文の 形式 ・ Firebase Auth の 処理は **変えない**。変えるのは 画面(View)・色・書体・動き・バイブ・画面の 行き先 だけ。
- 迷ったら、優先する 順番は 次の とおり。
  1. `Design/MockReference/screens/` の 画像
  2. `spec/MEASURED_SPEC.md` の 数字
  3. `spec/ANIMATIONS.md` と `spec/HAPTICS.md`
  4. `mock/src/` の コード
- **自分で デザインを 決めない**。モックに 無い 部品は 作らず、モックに ある 部品は 消さない。

---

## 0. 最初に やること(コードを 書く前)

1. `spec/SCREEN_MAP.md` → `spec/TOKENS.md` を 読み、`screens/` の 画像を **全部 見る**。
2. `mock/later_v52.html` を ブラウザで 開き、各画面を 実際に 押して **動きと 順番を 確かめる**(右下の 「触覚」の 波形で、いつ バイブが 鳴るかも 見える)。
3. 実機アプリを シミュレータ(**iPhone 16**)で 開き、下の 9画面の スクショを 撮って、`tools/compare.py` で モックと 並べた 画像を `Design/MockReference/compare_out/before_*.png` に 保存する。
4. 次の **差分表** を 作って 見せる。列は 画面 / 部品 / 実機 / モック / 直す ファイル / 消す 古いコード。

| 番号 | 画面 | 比べる モック画像 |
|---|---|---|
| 1 | Home(撮る前) | `A01_home_today` |
| 2 | Home(1枚 撮った後) | `A02_home_after_shot` |
| 3 | ライブパネル | `A03_live_panel` |
| 4 | Home 下スクロール | `A04`〜`A07` |
| 5 | Lattag yesterday ・ Groups | `B01` `B02` `B08` `B09` |
| 6 | Lattag yesterday ・ Mondo | `B10`〜`B15`(夜は `N02`) |
| 7 | Friend | `C01_friend` |
| 8 | ME ・ Recap | `C02` `C03` `C04` |
| 9 | Profile ・ Edit | `D01` `D02` `D03` |

5. **古い版の コードを 探して 消す**。今の 実機には 古い版と 新しい版が まざっている。
   - 同じ 役目の View が 2つ 以上 あったら、モックと 同じ方 1つだけを 残す。
   - 消すもの:
     - 古い 輪の Home(SHOOT / DEVELOP / CHAT / NEW GROUP の 丸と `OPEN` ピル)
     - オレンジ〜紫の 半円
     - 茶色の ライブパネル
     - Lattag yesterday の 古い グループ 一覧(「グループ」見出し・ピン・`1/1` の 輪・「昨日は、まだ届いていません」)
     - 古い ME(「きょうも いちまい。」の 画面)
     - 古い Profile(PERSONA・カレンダー(日めくり)・日本語の ボタン名)
   - 消す前に 一覧を 見せる。消したら ビルドが 通ることを 確かめる。

---

## 1. 共通の 土台(先に 作る)

### 1-1. 書体(`spec/TOKENS.md` の 1)

- 6書体を アプリに 入れ、`Info.plist` の `UIAppFonts` に 登録する。どれも Google Fonts から 入手でき、ライセンスは SIL OFL。
  - Inter: 500 / 700 / 800 / 900
  - Instrument Serif: Regular / Italic
  - Space Mono: Regular / Bold
  - Caveat: SemiBold
  - Noto Serif JP: Bold
  - Klee One: SemiBold
- `LaterFont.swift` に まとめる。
  ```swift
  enum LF {
    static func inter(_ w: Int, _ s: CGFloat) -> Font            // 500/700/800/900
    static func serif(_ s: CGFloat, italic: Bool = false) -> Font // Instrument Serif → 日本語は Noto Serif JP Bold
    static func mono(_ s: CGFloat, bold: Bool = true) -> Font     // Space Mono
    static func hand(_ s: CGFloat) -> Font                        // Caveat → 日本語は Klee One
  }
  ```
- Instrument Serif と Caveat は `UIFontDescriptor` の **`.cascadeList`** で 日本語用の 書体を つなぐ。これを しないと、日本語が ヒラギノ角ゴに なって モックと 違う 見た目に なる。
- 大きさは `fixedSize` で モックの pt を そのまま 使う。字間は `MEASURED_SPEC.md` の「字間」を `.tracking()` に そのまま 入れる。
- 確認: デバッグ用の 画面で 全書体の 見本(英語 + 日本語)を 表示し、`UIFont.familyNames` に 6つ 出ていることを 確かめる。

### 1-2. 色(`spec/TOKENS.md` の 2)

- `LaterColor.swift` に TOKENS の 名前の まま 定義する(`film` `filmLight` `lime` `body` `red` `gold` `stamp` …)。
- **画面の コードに 色の 数字を 直接 書かない**。必ず トークンを 使う。
- **オレンジ(`stamp`)は 写真の 日付の 印字だけ**に 使う(`'26 11 13` `17:42` `FRI` `ME · 7 DAYS`)。リング・時刻・ボタン・見出し・フィルムの 枠には 使わない。
- 昼と 夜の 切りかえ:
  - 21:00〜9:00 は 夜の 色。時刻だけで 決める 今の 仕組みは そのまま 使う。
  - **変えるのは 色だけ**。形・大きさ・書体・位置は 昼と 同じにする(見本: `B01` と `N01`、`B03`(ロック中の Mondo)と `N02`)。

### 1-3. 大きさ

- モックの 画面は **390 × 844pt**。`MEASURED_SPEC.md` の x・y・w・h は そのまま pt として 使う。
- 幅が 390 で ない 機種では、`s = 画面幅 / 390`(0.96〜1.10 の 範囲に おさめる)を すべての 寸法に かけ、中央に そろえる。`Metrics.swift` の 1か所に まとめる。
- `UIScreen.main.bounds` は 使わない。画面の 幅は `GeometryReader` で 1回だけ 取って 渡す。
- 上の 帯・下の ボタンは セーフエリアを 守る。

### 1-4. 動き(`spec/ANIMATIONS.md`)

- `duration` と `delay` は ミリ秒 → 秒に 直す。
- `cubic-bezier(a,b,c,d)` は `.timingCurve(a,b,c,d, duration:)` に そのまま 移す。1 を 超える 値(はねる 動き)も そのまま 使う。
- 途中の キーフレーム(`offset:.6` など)が ある ものは `keyframeAnimator` で 作り、各区間の 長さを 合わせる。
- 円が 広がって ひらく 動き(`clipPath: circle(...)`)は、`Circle()` の mask を 拡大して 作る。中心は 押した ボタンの 中心。
- 次の くり返しの 動きも CSS の `@keyframes` の 秒数どおりに 作る(`TimelineView` か `repeatForever`)。
  - 文字の 輪の 回転: 200秒で 1周
  - 光の 呼吸: 6秒
  - Mondo の 地球
  - 世界時計の 流れ
- 「視差効果を 減らす」が オンの ときは、くり返しの 動きを 止める(モックの `prefers-reduced-motion` と 同じ)。

### 1-5. バイブ(`spec/HAPTICS.md`)

- `Haptics.swift` を Core Haptics で 作り、`hap(.pop)` の ように モックと **同じ 名前**で 呼ぶ。
  - 名前は 15種類(tick / sel / pop / click / soft / thud / warn / success / shutter / land / heart / projector / buzz / rumble / vui)。
  - 強さと タイミングは 表の とおり。
- 「呼ばれる 場所」の 表を 見て、**モックで 鳴る 所では 全部 鳴らす。鳴らない 所では 鳴らさない**。
- 画面が 揺れる 表現と 波紋は モックだけの もの なので、入れない。

---

## 2. 画面ごとの 直し(実機の スクショで 見つかった ずれ)

### 2-1. Home ── 写ルンです の 本体(見本 `A01` `A02`、実測 A01 / A02)

- 古い 輪の デザインを **やめて**、まんなかを **写ルンです の カメラ本体**(`#orb`)に する。重なり方は 下から 順に 次の とおり。
  1. 背景の 緑の 光(`hbg .lk1/.lk2`、`.oau` は ぼかし 40)
  2. 黒い 本体(角丸 40 ・ 上 22% が 黒 → 緑 #24A03C の 帯 → 下が 黒)
  3. 左の 縦の 3本線(白 / 赤 #D8262C / 金 #C8A46A)
  4. 外の 文字の 輪(`#ring`・Space Mono 8pt・200秒で 1周)
  5. 白っぽい 玉(`#og` 261pt)と その 縁の 光
  6. レンズ(`#lens` 193pt・刻み・`LATTAG · 28mm 1:1.4 …` の 文字・ガラスの 反射)
  7. レンズ中央の 文字(撮る前 `Shoot` Instrument Serif 54pt + `3 LEFT` Space Mono 13pt 字間 3.12、撮った後 `Yesterday` 42pt + `1 OPENED`)
- 四すみの ボタン(丸 65〜70pt・黒い 縁 2pt・下に 3pt の 平らな 影・下に Space Mono 7pt の 札)。
  - 撮る前: YESTERDAY(左上・ロック色)/ NEW GROUP(右上・赤い 点)/ MONDO(左下・ロック色)/ FRIENDS(右下・白)
  - 撮った後: SHOOT(左上・白)/ DEVELOP(右上)/ NEW GROUP(左下・赤い 点)/ MONDO(右下)
  - どれが どこに 出るかは `mock/src/app.js` の `v32 まんなかの 万能ボタン` の 条件の とおりに する。
- 飾り: ✦(左上)・〰(右上)・✿(右下・赤い 芯)・∴(左下)・`Lattag`(Inter 900 Italic 20pt)・`FILM FOR TOMORROW`。
- **いちばん 下の「今日を撮る」**(`#hmoon`): 大きさが 違い、デザインも 違う ので 作り直す。
  - 直径 **600pt** の 黒い 球を **y = 712** に 置き、上の 約 130pt だけ 画面に 出す(幅 390 の 画面から 左右に はみ出る 大きな 弧)。
  - 球は 黒(#1C1C1C → #0D0D0D → #050505 の 放射グラデ)。点で 描いた 世界地図が ゆっくり 回る(`canvas#mgl`、`v40 今日を撮る = 地球` の コードを 移植)。
  - 縁には 内側に **白 / 赤 / 金 の 3本の 細い 線**(`.mat` の 影 3つ)と、緑の 細い 輪(`.r2`)。
  - 文字は `今日を撮る` または `もう1枚 撮る`(Inter 900 25pt 白 ・ 字間 -0.5)と、その下に `●●● のこり 3こま`(#9ED6A5)。
  - **オレンジ〜紫の グラデは 使わない**。
- 下へ スクロール: 緑 → 黒の グラデ(`#dusk`)で 暗室に つながる。中身は `A04`〜`A07` の とおり(Today 1/3 → ACTIVE → YESTERDAY → 写真 → ALBUMS)。
- 入場の 動き: `homeIn()`(ANIMATIONS.md)。

### 2-2. 「消灯まで」ピル と ライブパネル(見本 `A03`、実測 A03)

- 上の ピルは 235 × 36 ・ 角丸 18 ・ ガラス(白 80% → 56% + ぼかし 16 + 彩度 1.8)。
  - 中身は 左から: **緑の** リング → `消灯まで`(Inter 600 11.5pt #86868C)→ 時刻(Inter 700 13.5pt、数字が 縦に 回って 変わる)→ 緑の 棒 3本 → 残り数 → ⌄
  - Lattag yesterday 側では 文字が `ひらくまで` に なる。
- 押すと **ピルが そのまま 伸びて パネルに なる**(`matchedGeometryEffect`)。
  - 開く: 620ms `cubic-bezier(.3,.9,.3,1)`。途中 62% で 少し 大きく なってから 戻る。
  - 中身: 150ms 遅れて ぼかし 8 → 0 で 出る。
  - 閉じる: 440ms `cubic-bezier(.5,0,.2,1)`。
  - 後ろの 画面は 黒 30% で 暗くし、ぼかす。
- パネル: **366 × 305 ・ 角丸 36 ・ 背景 #050506**(茶色は 使わない)。
  - `● LIVE`: Space Mono 9.5pt #7EE08F、背景は 緑 16%、角丸 11。右に 時刻(Space Mono 10pt #5D5D63)。右上に ∧ の 丸(30pt #1A1A1D)。
  - `ひらくまで`: Inter 600 12pt #8C8C93。
  - **大きな 時刻 `18:40`**: Inter **800 64pt** 白。秒は 緑 #3BD35A で 小さく。
  - `消灯まで 9h 40m`: Inter 600 11.5pt #6C6C73。
  - 進行バー(330 × 8・角丸 4): 0:00〜24:00 は 濃い 緑、24:00〜9:00 は 斜線。進んだ 分は 緑の グラデ。今の 位置に 白い 丸(14pt)。目盛りは Space Mono 8.5pt で、`24:00` は 赤 #D8262C、`9:00 OPEN` は #7EE08F。
  - 下の 列: **小さな 縦長の 箱 3つ**。DEV の 写真は 48 × 62 で 少し 傾ける。+ の 2つは 40 × 52・角丸 9。右に **白い `shoot` ボタン**(186 × 54・角丸 27・カメラの アイコン + `shoot`(Inter 800 17pt)+ `2 LEFT`(Space Mono 9pt))。
  - 3つの 箱を 同じ 大きさで 並べたり、shoot を 横幅 いっぱいに したりは しない。

### 2-3. Lattag yesterday ・ Groups タブ(見本 `B01` `B02` `B08` `B09`、実測 B01 / B08)

- 上の 帯(`.yhd` 高さ 176): 昼は 白 72% → 透明、夜は #3A3A3D → 黒。どちらも 下に ぼかしを 入れる。
  - スクロールした 中身が **帯の 上に 重ならない**ように する。帯を 上に 重ね、中身は 帯の 下を くぐる。
- 並びは **① ヒーロー → ② (グループが あれば)ACTIVE の 横カード → ③ ME カード → ④ Friend カード で 終わり**。
  - 古い「グループ」見出し・グループの 縦の 一覧・ピンの ボタン・`1/1` の 輪・「昨日は、まだ届いていません」は **出さない**(モックでは CSS で 消している)。
- ① ヒーロー(354 × 470 ・ 角丸 32 ・ #161618):
  - 背景に きのうの 写真 4枚を 2 × 2 で 敷く(すき間 3)。上に 黒の グラデ(上 45% → 10% → 35% → 下 97%)を 重ねる。
  - **ロック中(今日 まだ 撮って いない)は 写真を ぼかす**: ぼかし 18 ・ 彩度 0.45 ・ 明るさ 1.1 ・ 1.12倍。0.6秒で 切りかえる。今の 実機は ただの 黒い 箱に なっているので 必ず 直す。
  - 文字と ボタン:
    - `GROUPS · NOV 12`(Space Mono 10pt 白 75%)
    - ロック中は ガラスの `🔒 shoot today to open`
    - **`Yesterday, together.`**(Instrument Serif 46pt 白・字間 -0.69)。グループが あれば 1つ目の グループ名に かわる。
    - 統計 3つ: 数字は Instrument Serif Italic、ラベルは Inter。`Friends ›` を 押すと Friend 画面へ。
    - **白い `+ Create`**(262 × 56・角丸 28・Inter 800 16pt)と **丸い QR**(56・白 14%)。
- ③ ME カード・④ Friend カードは `B02` `B09` と 同じ 形に する。
  - Friend カードの 中身: `Friend`(F だけ 緑 Italic)`3/12` ・ `● 2 today` ・ 黒い 丸の `›` ・ 緑の `+ Add` ・ 友だちの 丸(今日の 枚数バッジ 付き)。
  - 今の 実機は Friend が 薄く、Add が 巨大で、キャラが 画面から はみ出しているので、直す。
- 入場の 動き: `yHeroIn()` と `yOnce()`。

### 2-4. Lattag yesterday ・ Mondo タブ(見本 `B10`〜`B15`、夜 `N02`、実測 B03 / B10)

- 今の 実機は **世界時計の 帯しか 無く、ほかが 真っ黒**。下の 中身を 全部 作る(コード: `v37 Mondo`、見出しは `moHead()` `v49.js`)。
  1. `● MONDO · NOV 12`(Space Mono)
  2. **`The w🌐rld,`**(Instrument Serif、o の 位置で 地球が 回る)と **`yesterday.`**(緑 Italic + 黄緑の 手書きの 下線)。開くたびに 文字が 下から 出て、光が 走る。
  3. 世界時計の 流れる 帯
  4. `TODAY'S ONE · 9:00` の 大きな 写真カード(ハッシュタグの シール・地名・`picked by the world · no numbers`)
  5. `WORDS TOP 5`(横に 流れる 丸い ピル)
  6. `MORNING NOW`(時間の グラデの 帯 + `NY is opening yesterday`)
  7. `MAP 12 PLACES`(暗い 地図に 写真の 丸)
  8. `EVERYONE`(2列の 写真。地名は Instrument Serif Italic、時刻は オレンジの 印字。`TAP×2 LIGHT · HOLD ONE`)
  9. `Your one` カード
- ロック中は 4 以下を ぼかして、`shoot today to open` を 重ねる(`N02`)。

### 2-5. タブバー(Mondo / Groups)── Apple 純正の Liquid Glass

- 今の 自作の 灰色の 角丸は **やめる**。理由は 3つ: アイコンが 無い・ガラスに なっていない・中身と 重なって 読めない。
- **iOS 26 の 純正 `TabView`** を 使う(下の バーは 自動で Liquid Glass に なる)。
  ```swift
  TabView(selection: $yTab) {
    Tab("Mondo", systemImage: "globe", value: YTab.mondo) { MondoView() }
    Tab("Groups", systemImage: "person.2.fill", value: YTab.groups) { YGroupsView() }
  }
  .tabBarMinimizeBehavior(.onScrollDown)
  ```
  - バーの 後ろに 不透明な 背景を 置かない。中身が バーの 下を くぐって 透けて 見えるように する。
  - 最初に 開く タブは **Groups**。
  - 画面の ダブルタップで タブを 切りかえる 今の 動きは 残し、`hap(.sel)` を 鳴らす。
- iOS 26 より 前の 端末も 対象なら、同じ 位置(下から 30pt・幅 274・高さ 66・角丸 33)に `.ultraThinMaterial` の カプセルで 代わりを 作る。選んだ 方は 白 7% の 中に カプセル(127 × 56)、文字は Inter 600 11pt。

### 2-6. Friend(見本 `C01`、実測 C01)

- 前回の 指示どおり、`Friend` の **F は 大文字**、右上に 白い `Add`。
- 真ん中の ダイヤル(目盛り 340pt・席 52pt・半径 118)、中心(176pt)に キャラの 群れ。
- 自分の チェキ(テープ・ハッシュタグ 3枚・手書きの 名前)。
- 下に Shake / QR / Link の 3つ(同じ 幅)。
- 数字は `MEASURED_SPEC.md` の C01 を 正と する。

### 2-7. ME と Recap(見本 `C02` `C03` `C04`、実測 C02 / C03)

- **入口**は 次の 4つ だけ。**右上の 丸からは 開かない**。
  - Lattag yesterday の ME カード
  - Home 暗室の `ALBUMS`(`7 DAYS · RECAP ›`)
  - Profile の `ME · 7 DAYS`
  - Profile の 統計の `SHOTS` / `KEPT`
- 古い「ME きょうも いちまい。」の 画面(日付カードの 横スワイプ・オレンジの 棒)は **消す**。
- 中身:
  - 上: 戻る丸 + `ME`(Inter 900 46pt)+ `NOV 6 — NOV 12`(Space Mono)
  - **Recap カード**(362 × 430・写真 2 × 2・`RECAP`・`Your`(Instrument Serif 62pt)/ `week.`(Italic 70pt #C8F25A)・`20 shots 7 days 7 kept`・▶)
  - `Film / Cheki / Beat` の 切りかえ(Instrument Serif 17pt、選んだ 方は 白の カプセル)
  - 横に 流れる フィルム(曜日は オレンジの 印字)
  - 日ごとの 写真(`Thu NOV 12 … 6D LEFT`)
- Recap の 再生画面と 動き・バイブは `v50.js` の `meplay` `meGo` の とおり。
  - 1枚の 長さ: Film 1.15秒 / Cheki 1.5秒 / Beat 0.56秒
  - 日が 変わる とき: thud
  - 写真ごと: tick(Beat では pop)
  - 終わり: success

### 2-8. Profile(右上の 丸を 1回 押す)(見本 `D01` `D02` `D03`、実測 D01 / D03)

- **右上の 丸 → Profile**。今は ME に 行っているので 行き先を 直す。
- 開く 動きは `openPrf()` の とおりに **全部** 再現する(合計 約 1.4秒)。
  1. 右上の 丸の 中心から **円が 広がって 画面が ひらく**(680ms `cubic-bezier(.3,.85,.25,1)`)。丸の まわりに 輪が はじける。`hap(.pop)`
  2. チェキが 上から **-18° 回りながら 落ちてきて** 少し はねる(820ms・120ms 遅れ)。560ms で `hap(.land)`
  3. ハッシュタグの シールが **1枚ずつ ポンと 貼られる**(0 → 1.25 → 1 倍・700ms 後から 110ms ずつ・1枚ごとに `hap(.tick)`)
  4. 名前・統計・ボタン・下の カードが 下から 24pt 上がって 出る(50ms ずつ ずらす)
  5. 閉じる: 円が 丸に 戻って 消える(460ms)。`hap(.soft)`
- 画面の 中身(上から):
  - 背景: 緑 → ピンクの 大きな ぼかし(70)と、ぼかした チェキ 2枚、暗い ビネット。
  - 上の 帯: 左に **⌄ の 丸**(閉じる・42pt・白 12% + ぼかし 14)、まんなかに `@yui_0612`(Space Mono 11pt #C9C9CF 字間 1.54)、右に **⚙ の 丸**(設定へ スクロール)。
  - **チェキ**(241 × 299 ・ 角丸 6 ・ #F4F1EA ・ 少し 傾ける):
    - 上に 黄緑の テープ(93 × 38)
    - 写真(211 × 221)と 印字 `'26 11 13`(Space Mono 11pt **オレンジ**)
    - 下に 手書きの 名前(Caveat / Klee One 34pt)
    - 光の 筋が 指の 動きで 動く
  - **ハッシュタグの シール 6枚を チェキの まわりに 貼る**。
    - 自分の タグ 3枚: Inter 900 17pt・角丸 14・平らな 影 `3,4`。
    - おすすめ 3枚: 14pt・薄め。
    - 色と 位置は D01 の 実測値どおり。
    - シールは 指で はがして 動かせる(はがす 時 `soft`、貼る 時 `tick`)。
  - チェキを **押すと 裏返って QR**(`SCAN TO ADD`)。**長押し**で シールが 全部 はじけて 戻る(`rumble`)。
  - 大きな 名前 `ゆい`(Instrument Serif → Noto Serif JP Bold 54pt)と `SINCE Oct 2026`(`Oct 2026` は Instrument Serif Italic #C8F25A)。
  - **統計 4つ**(358 × 74 ・ 角丸 24 ・ #121214 55% + ぼかし 18): DAY STREAK / SHOTS / KEPT / FRIEND `3/12`。数字は Instrument Serif 30pt、ラベルは Space Mono 8.5pt 大文字。
  - **ボタン 4つ**(各 84 × 82 ・ 角丸 22):
    - QR(緑 #24A03C)/ Edit / Share / Scan
    - 文字は **英語** の Instrument Serif 17pt。
    - 押すと 0.88 → 1.05 → 1 倍に はねる。
  - `ME · 7 DAYS`(写真の 列 + 白い `Recap ▸`)→ `1 YEAR · KEPT`(点の 表、★の 日は 金)→ 設定の 一覧(通知 / 言語 / ブロックした人 / ヘルプ・利用規約 / ログアウト(赤))。
- **出さない もの**:
  - `PERSONA ・ 夕凪のかげ #4053`
  - 日本語の ボタン名(編集・共有・スキャン)
  - `カレンダー(日めくり)⌄`
  - オレンジの フィルム帯
  - 戻る `<`(⌄ に する)
- Edit は v52 の 指示(その場で 直す モード)の とおり(見本 `D03`)。

---

## 3. 確かめ方(直すたびに)

1. 画面ごとに シミュレータの スクショを 撮り、`tools/compare.py` で モックと 並べる。結果は `Design/MockReference/compare_out/after_*.png` に 保存する。
2. 並べた 画像を **自分の 目で 見て**、次の 点が モックと 同じか 確かめる。
   - 部品の 数・順番・位置
   - 書体(明朝 / ゴシック / 手書き / 等幅)
   - 太さ・大きさ
   - 色
   - 角丸
   - ぼかし
3. 動きは シミュレータの 画面録画(`xcrun simctl io booted recordVideo`)と モックを 見比べ、**順番 ・ 長さ ・ はね方**が 同じか 確かめる。
4. バイブは 実機で、HAPTICS.md の「呼ばれる 場所」の 表を 1行ずつ 押して 確かめる。
5. 確かめた 結果を 0 章の 差分表に ✓ で 書きこむ。

## 4. 完了の 条件

- 9画面すべてで、`compare_out/after_*.png` を 見て、**部品の 有無・位置・書体・色が モックと 一致**している(写真の 中身や 時刻の 数字が 違うのは よい)。
- 実機で 見つかった ずれ 9つ(`spec/SCREEN_MAP.md` の 最後の 表)が すべて 直っている。
- 書体は 6つだけ。日本語が ヒラギノ角ゴに 化けていない。
- オレンジは 写真の 日付の 印字だけ。
- 画面の つながりが 次の とおり。
  - 右上の 丸 → Profile
  - ME カード / ALBUMS / Profile の ME · 7 DAYS → ME
  - ピル → ライブパネル
  - `today / yesterday` → Lattag yesterday
- タブバーが 純正の Liquid Glass。
- 古い版の View・色・定数が 残っていない(消した ファイルの 一覧を 見せる)。
- CloudKit の 保存 ・ リンク発行 ・ 招待文 ・ ログインは **前と 同じに 動く**(グループを 1つ 作って、招待リンクを 出せることを 確かめる)。
