<!-- ========== v88 : yesterday の アイコン 1回 = プロフィール ・ 編集を 新しい 見た目に ・ オープニングの 角 ・ Home の # の 上で スクロール ========== -->
# PROMPT v88 ・ 実機を 見て 直す 4つ(モック `lattag_v84.html`)

> **いちばん 新しい 指示**。v87 の あと、実機で 見つかった 4つ。
> 正解:モック `mock/lattag_v84.html`、元コード `mock/src/v81.css` `v81.js`(+ v80)。見本 `screens/F23_profile_edit` `F24_profile_edit_fields` `O0y_opening_icon_corner.png`、動き `motion/M20_opening_icon_slide` `M28_avatar_double_tap`。

---

## A. Lattag yesterday(Friends ・ Mondo)の 右上の アイコン:1回 = プロフィール
- **Home と 同じ ルール**:**1回 タップ = プロフィール** ・ **2回 タップ = 今日(Home)へ**。
- いまの 実機は 1回 押しても 何も 起きない(2回 だけ 反応)→ 1回も 受ける。
- 1回目で すぐ `tick` + アイコンが 0.9倍 → 1倍(0.2秒)= 「押せた」が わかる。0.34秒 たっても 2回目が 来なければ プロフィールを ひらく(アイコンの 位置から 丸く 広がる ・ v54)。
- プロフィールを とじたら **もとの yesterday に もどる**(Home へ 行かない)。
- iOS:Home と 同じ 部品(`AvatarSwitchButton` など)を **1つ 作って 両方で 使う**。
  ```swift
  .onTapGesture(count: 2) { haptics(.sel); onDouble() }   // 先に 2回
  .onTapGesture(count: 1) { onSingle() }                    // あとに 1回
  .simultaneousGesture(TapGesture().onEnded { haptics(.tick); pressBounce() })  // すぐの 手ごたえ
  ```

## B. プロフィールの 編集 = 新しい 見た目(`F23` `F24`)
- いまの 実機は `Edit` を 押すと **古い 白い プロフィール画面**(`ME · 7 DAYS` が オレンジの 物)が 出る。**その 古い 画面(と 古い 編集の View)は 消す**。
- 編集は **いまの 黒い プロフィールの 上で その場で** する(別の 画面へ 行かない)。入口は 3つ:`Edit` ボタン ・ チェキの ペンの 印 ・ 設定シートの いちばん 上の `編集`。

| 部品 | 値 |
|---|---|
| 上の 帯(高さ 104)| 左 `キャンセル`(44 の 丸い ボタン ・ 白 10% + ふち)・ まんなか `編集`(Inter 900 17)・ 右 `完了`(変えて いない 時 = 白 8% ・ 字 35% / 変えたら **黄緑 ・ 字 黒** + 光)|
| 隠す 物 | 歯車 ・ `@id` ・ 数字 ・ 4つの ボタン ・ Recap ・ 1年(編集が 終わったら 戻す)|
| チェキ | そのまま。右上に **黄緑の カメラの 丸**(写真へ とぶ)・ 右下に 白い ペンの 丸(名前へ とぶ)。自分の シール 3つの 左上に `×`(押すと はずれる)。シールは ゆれる(編集中の 合図)|
| 名前の 字 | 手書きの 名前の まわりに 点線(黄緑 60%)|
| 写真(箱)| 地 `#121315` ・ 角丸 22。題 `写真`(800 15)。横に 並ぶ:**黄緑の カメラ**(54 × 68 ・ 押すと 写真えらび v81)→ 最近の 写真 → 色の 丸。えらんだ 物は **黄緑の 輪** |
| 名前(箱)| 題 `名前` + 右に `2 / 12`。入力(高さ 54 ・ 白 7% ・ 字 800 19)。えらんで いる 時は ふちが 黄緑。右に `×`(けす)|
| タグ(箱)| 題 `タグ` + `3 / 3`。いまの 3つ(色の チップ + `×`)。下に 候補(押すと 入る)+ `# じぶんで 書く`(点線 黄緑)。4つ目を 入れようと したら トースト `タグは 3つまで` + `warn` |
| 入る 動き | 帯が 上から(0.38秒)・ 箱が 下から 1つずつ(70ms ずらし)・ `pop` |

- `完了`:保存 → トースト `プロフィールを 保存しました` → 編集が とじて、チェキ ・ 名前 ・ シールが 新しい 中身に。`success`。
- `キャンセル`:変えた 所を 元に もどして とじる。変えて いたら「変更を すてますか?」の 確認(`すてる`(赤)/ `キャンセル` = 編集を つづける)。
- **保存先は 今の まま**(Firestore の ユーザーの ドキュメント ・ 名前 ・ タグ ・ 写真。**フィールド名を 変えない**)。写真は v81 の とおり Storage に 512 × 512。
- シールの 場所(自分の 3つ):左上 (-120, -112, -8°) ・ 右上 (118, -84, 7°) ・ 左下 (-128, 52, 5°)(チェキの 中心から)。**編集の あとも 同じ 場所**。

## C. オープニング:アイコンの **角** を 丸く(`O0y_opening_icon_corner.png`)
- いまの 実機は オープニングの アイコンが **四角い(角が ある)**。起動画面(`LaunchIcon` = 角丸 込みの 画像)から 切りかわる 瞬間に 形が 変わって 見える。
- **原因**:`AppIcon` の PNG(1024 の 正方形。角丸は iOS が 自動で つける ので 画像には 無い)を そのまま 表示して いる。
- **直し方**:
  1. オープニングの アイコンは 正方形の 絵を **必ず 角丸で 切る**:`.clipShape(RoundedRectangle(cornerRadius: size * 0.224, style: .continuous))`。`size` は その時の 大きさ(132 → 78 で 変わる)。
  2. 影(黄緑の 光)は **切った あと** に つける(`.clipShape` → `.shadow`)。逆だと 四角い 影が 出る。影も 角丸の 形。
  3. 大きさの 変化を `scaleEffect` で する 場合は、132pt で 切って から 縮める(角丸も いっしょに 縮む = 22.4% の まま)。`frame` を 変える 場合は `cornerRadius` も `size * 0.224` で 毎回 計算。
  4. 絵は `Assets` に **アイコン用の 別の 画像**(`OpeningIcon`:ベクター PDF / SVG ・ 角丸なし)を 入れ、`AppIcon` を 読まない(`AppIcon` は アプリの 中から 正しく 読めない ことが ある)。
  5. レンズの シャッターの 光 ・ まばたきも **アイコンの 角丸の 中** に 収める(はみ出さない)。
- 確かめ方:Slow Animations で 0ms の 絵が `screens/O0x_opening_v72_0000ms.png` と 同じ 角丸か。起動画面 → オープニングで 形が 変わらないか(スロー撮影)。

## D. Home:黄緑の # の 上でも たてに スクロール(v87 B-4 の つづき)
- いまの 実機は **アイコン(レンズ)より 下** を なぞらないと 下へ 行かない。**黄緑の # ・ レンズ ・ まわりの 黒い 所、どこを なぞっても Home が たてに 動く** こと。
- まず **原因を 見つける**(計画モードで 報告):上の 大きな かたまり(横スライドの 4ページ ・ # ・ レンズ)に 付いて いる ジェスチャーを ぜんぶ 一覧に する。1つずつ 外して、どれが スクロールを うばって いるか 確かめる。
- よく ある 原因 と 直し方:

| 原因 | 直し方 |
|---|---|
| 光の 向き(レンズの つや)を 指で 動かす `DragGesture(minimumDistance: 0)` | **ジェスチャーを やめる**。光は スクロールの 位置 か 端末の かたむき(CoreMotion 30Hz)で 動かす |
| 横スライドを 自前の `DragGesture` で 作って いる | `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` + `.scrollPosition(id:)` に おきかえる(たての ScrollView の 中に 入れれば、たて / よこ は iOS が 自動で 見分ける)|
| レンズの「押している 間」を `DragGesture` / `LongPressGesture` で 取って いる | `Button` + 自前の `ButtonStyle`(`configuration.isPressed`)に する |
| `.highPriorityGesture` / `.gesture` が かたまり 全体に 付いて いる | 押す 物(レンズ)だけ に 付ける。# の 帯 ・ かざりは `.allowsHitTesting(false)` |
| `.contentShape(Rectangle())` が かたまり 全体 | レンズの 丸 だけ に する(`.contentShape(Circle())`)|
| iOS 18 で `.simultaneousGesture(DragGesture())` が ScrollView を 止める | 使わない(どうしても 必要なら `UIGestureRecognizerRepresentable` で `shouldRecognizeSimultaneously = true`)|

- **かならず テスト**(UI テストを 1本 足す):
  ```swift
  func testScrollFromHashBar() {
    let app = XCUIApplication(); app.launchArguments += ["-debugState", "home0"]; app.launch()
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.32))   // 左の 黄緑の 帯の 上
    start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.05)))
    XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 2))            // 下の かたまりが 見える
  }
  ```
  同じ ことを **# の 右の 帯(dx 0.9)・ レンズの 上(dx 0.5, dy 0.45)** からも。3本 とも 通る こと。
- 横スライド(4ページ)と レンズを 押して 撮る は **今まで どおり 動く** こと(壊さない)。

## E. 確かめる こと
1. yesterday の アイコン:1回 → プロフィール(とじると yesterday)・ 2回 → Home。Home 側も 同じ。
2. `Edit` で 古い 白い 画面が 出ない。`F23` `F24` と 同じ。キャンセル / 完了 が 動く。シールが 同じ 場所。
3. オープニングの アイコンが 0ms 〜 最後まで 角丸。起動画面から 形が 変わらない。
4. Home:黄緑の 帯 ・ レンズ の 上から 下へ スクロール できる(UI テスト 3本)。横スライドと 撮影も 動く。
