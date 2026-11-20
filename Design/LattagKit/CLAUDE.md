# CLAUDE.md ・ Lattag(レイタグ)iOS アプリ

> この ファイルは **リポジトリの いちばん上** に 置く(すでに CLAUDE.md が ある なら、下に つけたす)。
> Claude Code は 毎回 これを 読む。ここに 書いた ルールは **すべての 作業で 守る**。

## 1. いま やって いる こと

- HTML の モック(`Design/LattagKit/mock/lattag_v97.html`)を、**見た目 ・ 動き ・ バイブまで そのまま** SwiftUI の 実機アプリに 移す。
- 範囲は **オープニング 〜 Trip を つくる まで ぜんぶ**。段階(フェーズ)ごとに 進める:`Design/LattagKit/prompts/P00〜P54`。
- 進み具合は `Design/LattagKit/PROGRESS.md` に 書く(フェーズ と 画面 ID に ✓)。

## 2. 正解の 順番(迷ったら 上が 勝つ)

1. **見本画像** `Design/LattagKit/screens/<ID>.jpg` と **数値** `Design/LattagKit/spec/screens/<ID>.json`
   - JSON は モックを 実際に 動かして 測った **最終値**(CSS の 上書きを 計算した あと)。位置 ・ 大きさ ・ 書体 ・ 色 ・ 角丸 ・ 影 ・ ぼかしは **ここを 最優先**。
2. **動いて いる モック** `mock/lattag_v97.html`(Safari で ひらける。上の デモボタンで 状態を 変えられる)
3. **モックの 元コード** `mock/src/`(読む 順番は `mock/src/LOAD_ORDER.md`。**後の ファイルほど 優先**:CSS は 後勝ち、JS は 関数を 上書き)
4. **詳しい 仕様** `prompts/reference/PROMPT_v54〜v108.md`(**番号が 大きい ほど 新しく、優先**)
5. ここに ない ことは **作らない ・ 推測しない**。わからない ときは コードを 読むか、手を 止めて 聞く。

## 3. 名前と 中身の 名前

- アプリの 名前は **Lattag**(`#` なし)。読みは レイタグ。画面の 字は `Brand.name` から 出す(`prompts/reference/PROMPT_v62.md`)。
- **変えない**:Bundle ID ・ Firebase の プロジェクト / コレクション名 ・ CloudKit の コンテナ ・ Swift の 型名 / ファイル名 ・ フォント名 `Later Mincho`。

## 4. モック だけの もの(実機に 作らない)

- 上の デモボタン の 列(`#ctl`)・ 画面の 外の 枠 ・ 時計 / 電波の 表示 ・ `window.__api` / `window.__kit`
- バイブを 見せる ための **波紋**(`.rip`)と **画面の ゆれ**(`.qk`)
- 「(モック)」「デモ」と 書いた トースト
- 見本の 写真(`PH`)・ 見本の 友だち(`FPOOL`)・ 見本の 文(本番は 実データ)

## 5. 単位 ・ 座標

- モックの **1px = iOS の 1pt**。モックは **幅 390pt**。
- 比べる ときは **幅 390pt の シミュレータ**(iPhone 16e / iPhone 14 / iPhone 13)。
- 幅が 違う 端末では:左右の 端に 合わせる 物は 端からの 距離、まんなかの 物は 中心からの 距離で 置く。大きさは 変えない(カードの 幅だけ のびる)。

## 6. デザインの きまり(Design System)

- 色 ・ 書体は `spec/TOKENS.md` と 各 PROMPT に ある 値だけ。**新しい 色を 作らない**。(v110 で ポップ 3色 ピンク #FF7AB6 ・ 空色 #6EC8FF ・ 黄色 #FFD84D を 足した。使う 所は ステッカー ・ タグ ・ Trip の 色 ・ 数の 丸 だけ)
- 書体:Inter / Instrument Serif / Space Mono / Caveat / Klee One / Noto Serif JP Bold(`Later Mincho`)。`Info.plist` の `UIAppFonts` に 登録。
- **重さ**:ぼかしは 小さな 画像を 1回だけ ぼかして 引きのばす(毎フレーム 計算しない)。ガラスは 1画面 8枚まで。画面の 外の 動きは 止める(`PROMPT_v68.md` 5章)。
- **キャラクター(にこちゃんの 顔 ・ 人の 絵)は 使わない**。
- **ME の 写真と Recap は 端末 + iCloud(CloudKit の 自分用 DB)に のこす**。Firebase の 写真は 7日で 消える ままで よい(`PROMPT_v86.md`)。
- **今日 / きのう の 切りかえは 右上の アイコンを 2回 タップ**(1回 = プロフィール)。Home でも yesterday でも 同じ 部品(v87 / v88)。ロゴの 横に `TODAY` の 字は 置かない。
- **アプリアイコンの 絵を アプリの 中で 出す 時は かならず 角丸**(`RoundedRectangle(cornerRadius: size * 0.224, style: .continuous)`)。影は 切った あと(v88)。
- **Home の 上の かたまりに スクロールを 止める ジェスチャーを 付けない**(押す 物だけ `Button` ・ # の 帯は `.allowsHitTesting(false)`)。UI テストで 確かめる(v88 / v89 ・ 見本 `prompts/reference/swift/HomeHeroScroll_example.swift`)。
- **動きは `scaleEffect` ・ `offset` ・ `opacity` ・ `rotationEffect` で**(大きさ ・ ぼかしの 半径を 毎コマ 変えない)。`Info.plist` に `CADisableMinimumFrameDurationOnPhone = YES`(120fps)。重い 読みこみは 動きの 間に しない(v89)。
- **画面に デバッグの 字(`auth=…` など)を 出さない**(DEBUG の 状態メニュー の 中 だけ)。
- **部品を 重ねて 置かない**(`offset` ・ 決めうちの 幅を 使わず、`VStack` / `HStack` で 並べる)。はみ出しそうな 字は `lineLimit(1)` + `minimumScaleFactor` + `ViewThatFits`(v87)。
- **UI の 緑(`#24A03C` `#3BD35A` `#239E3C` `#7EE08F`)は 使わない → ライム `#C8F25A`**(v93)。数字が 変わる 所は **オドメーター / `.contentTransition(.numericText())`** で 動かす。
- **現像画面は ぼかしを 1回 だけ 作り、不透明度 だけで 動かす**(半径を 毎コマ 変えない ・ 自動 再生 しない ・ バイブは `CHHapticEngine` の パターン 1つ)(v93)。
- **Home は 下の タブ 2つ:Friends | Trip**(v110)。**Mondo は なくした**(画面 ・ 入口 ・ ウィジェット ・ 通知 ・ 説明 ・ 文字列 も 作らない。データは 消さない)。Yesterday ページは 作らない(v93)。
- **撮影ボタンは Lattag の アイコン**(長押しで ライムが 下から たまり、完成で 撮れる)(v94)。
- **ID(@ユーザー名)**:英小文字 ・ 数字 ・ `_` `.` ・ 3〜20文字 ・ 14日に 1回。とる / かえる は Cloud Functions の トランザクション だけ(`usernames/{id}`)。検索は callable `searchUsers` だけ(`users` を 自由に 読ませない)・ 名前で 見つかるのは `discoverableByName` の 人だけ(v94)。
- **友だちを ふやす 入口は Friends の さがす 画面 1つ**(名前 か @ID)(v94)。
- **キーボードが 出る 画面は `safeAreaInset(.bottom)` + `@FocusState` で 上を 小さく**(決めうちの 位置で 置かない)(v95)。
- **ボタンは 書いて ある とおりの 画面へ**(リンク = 共有 ・ QR を 見せる = 自分の QR ・ QR を 読む = カメラ ・ @ID = さがす)。同じ 画面に まとめない(v95)。
- **Home の まんなかに NEXT(いま やる こと)**・ はじめての 説明は 5つの スポットライト(1回 だけ)(v95)。
- **ライブ アクティビティは v97**(夜 = フィルム → 最後の 10分 = ライム の ラストコール → 朝 8:30〜9:00 = 朝の 部 ・ 数字と 線は timerInterval で 自動)。
- **ウィジェットは v96**(`widgets/lattag_widgets_v96.html`)。黒 + ライム + # の 帯 + チェキ ・ 数字は 太字 ・ **9:00 まえは 本物の 友だちの 写真を App Group に 置かない**(v96)。
- **QR は かならず 読める こと**(誤り訂正 H ・ 角の 目の 角丸は 1マス まで ・ Vision の Unit テスト)。形は チェキ + # の 緑の 点(v92)。
- **Shake(ふって つながる)は 作らない**(v85 で なくした)。友だちとは QR ・ リンク ・ ID で つながる。人は 写真の 丸(無ければ 名前の 1文字 + 色)。
- ガラス:iOS 26 は `.glassEffect()`(押せる 物は `.interactive()`)、それ より 前は `.ultraThinMaterial` + 白 10〜14% + ふちの 白い 線。部品は `LGGlass` に まとめる。
- **利用規約 ・ プライバシー(v102)**:リンク先は `LegalLink` 1か所(`…github.io/APP-Later2/terms.html` ・ `privacy.html`)。**文章は アプリに 持たない**。`SFSafariViewController` の シートで ひらく(「完了」で もどる)。つなぐ 場所は サインイン画面(O04)の 下の 字 と 設定 > サポート。押せる 大きさ 44pt ・ 重ねない。
- **友だち ・ 申請 ・ 1対1チャット ・ 友だちの 写真(v103)**:置き場所は **Cloudflare(Worker + R2 + データベース)**、本人確認は **Firebase の ID トークン(`uid`)**。CloudKit の 公開DB には 置かない(`_world` で だれでも 読めて しまう ため)。友だちは **無制限**(数は どこにも 表示しない)。写真は **投稿した 1枚だけ**・ **7日で 消える**・ EXIF を 取る。グループ ・ Trip は CloudKit の 共有ゾーンの まま、ME ・ Recap は 個人DB の `me` ゾーン。ID(`UserHandle`)と `UserDirectory` は 公開DB の まま(写真は 入れない)。**本人と 相手だけ 読める ことを サーバーが 検証**する。 **グループの 共有リンクと 招待の KEY は 公開DB に 置かない**(Worker 経由 ・ 回数制限 ・ 期限)。
- **サインイン(v104 ・ v101 を 上書き)**:**Apple だけ**(Google ・ メールの リンクは 出さない ・ コードも のこさない)。Apple は **Firebase に のせて** `uid` で 見分ける。O04 は 白い 丸の Apple ボタン(丸の 中は かえない ・ 動きは 丸の 外だけ)+「メールは かくす」(初期 オン = メールを もらわない)。見出しは「昨日を / 共有する SNS」。前から いる 人は おかえり → Home。**Apple で 入って いる 人を 壊さない**。
- **はじめての 設定(v106)**:終わりの しるしは さいごの ながおしで だけ。進み具合を のこし、とちゅうで Home を 出さない。おかえり は `onboardedAt` が ある 人 だけ。
- **Trip(v106)**:右上は 字つき「招待」「設定」。チャットは Trip の 共有ゾーン(今 ある `GroupChatMessage`)。設定は 1枚の シート(パスの 見本が すぐ 変わる)。ぬける / おわる は 長押し → パスが やぶれる → Home から 消える。
- **写真と 動画の 質感(v107 ・ 必須)**:写真 = チェキ(1440px ・ LUT `cheki_v2` ・ にじみ ・ ビネット ・ 粒子)、動画 = iPhone 8 風(1080p30 ・ HDR オフ ・ sRGB ・ LUT `retro8` ・ うすい シャープ ・ 動く 粒子)。**撮った 時に 1回 だけ 焼き、焼いた ファイル だけ を 保存 ・ 送る**(友だちにも 同じ 質感)。表示時の フィルターは 0。数字は `tools/film/film_pipeline.py`。
- **相互フォロー ・ お知らせ(v108)**:申請 → 承認(= フォローバック)で 相互。おたがいに 申請 → すぐ 相互。片方 だけの フォローは 作らない。Home の 上は まんなかに Lattag ・ 左に お知らせ(ベル + 数)・ 右に アイコン。友だち申請と Trip の 招待は お知らせで 承認 / 参加。通知は Worker → APNs。
- **リンク(v108)**:`https://later-app-f2606.firebaseapp.com/u/<ID>` ・ `/t/<トークン>` + `?openExternalBrowser=1`(LINE の 中で 止まらない)。ページ ・ OGP ・ AASA は `hosting/`。`/g/*` は こわさない。ドメインは `AppLinks` 1か所。
- **ポップ(v110)**:ステッカー × チェキ。部品は `Pop/`(Sticker ・ Tag ・ Tape ・ ChekiFrame ・ PopButton)。押すと 0.93 → ばねで もどる。ステッカーは 形と 字 だけ(顔 なし)。Trip は 上に 週の 帯(Trip の 色の 線)+ いま / これから / おわった の カード。
- **重さ(v106)**:起動時は 今の Trip だけ ・ CloudKit は 変更トークンで 差分 だけ ・ 一覧は サムネ だけ。古い データの 片づけは DEBUG だけ(自分の もの だけ ・ 自動で 消さない)。
- **シートは 中身の 高さ(v104)**:`Spacer()` で のばさない ・ `.presentationDetents([.height(h)])` ・ キーボードの すぐ 上。Name では キーボード 中も アイコンの 写真を かくさない。
- **ウィジェット(v104)**:先に 1つ えらぶ → アプリの 中の 動く 案内(5場面)→ もどった 時に `WidgetCenter` で 自動で たしかめる(アプリから ホームへ 行く ・ 自動で 置く ことは できない)。
- バイブ:`spec/HAPTICS.md` の 15種類(`tick` `sel` `pop` `click` `soft` `thud` `warn` `success` `shutter` `land` `heart` `projector` `buzz` `rumble` `vui`)を `Haptics.play(.名前)` で。モックの `hap('名前', …)` と 1対1。
- 動き:
  - CSS / JS の `cubic-bezier(a,b,c,d)` → `.timingCurve(a, b, c, d, duration:)`
  - `element.animate([...keyframes], {duration, delay, easing})` → `keyframeAnimator` か `PhaseAnimator`(iOS 17〜)
  - CSS の `animation: … infinite` → `.repeatForever(autoreverses:)`。画面外では 止める
  - モックの ばね(硬さ k / 減衰 c の 自前の 計算)→ `.spring(response:dampingFraction:)` で 近い 値を 見つけ、コマ割り(`motion/`)と 見くらべる
  - **Reduce Motion** では くり返しの 動きを 止める(各 PROMPT に 書いて ある)
- 押せる 物は **44 × 44pt 以上**。写真の 上の 字は 9.5pt 以上。

## 7. 作業の すすめ方(毎回)

1. 最初に **計画モード**で、今の フェーズの PROMPT ・ 見本画像 ・ JSON ・ モックの コードを 読み、作る ファイルと 手順を 出す。
2. 1つの 画面ずつ 作る → **ビルド** → **シミュレータで 開く** → **スクショ** → **見本と 比べる**:
   ```bash
   xcrun simctl io booted screenshot /tmp/sim.png
   python3 Design/LattagKit/tools/compare.py Design/LattagKit/screens/H01_home.jpg /tmp/sim.png /tmp/cmp_H01.png
   ```
   出た `/tmp/cmp_H01.png` を **自分で 見て**、赤い 所(ずれ)を 直す。score が 下がる まで くり返す。
3. 画面の 状態(0〜3枚 ・ 友だち ・ 申請 ・ はじめての 日 ・ Trip ・ 夜)は **DEBUG ビルドだけの「状態メニュー」**(P00 で 作る)で 切りかえて 撮る。モックの デモボタンと 同じ 名前に する。
4. 終わったら `PROGRESS.md` に ✓、**git commit**(フェーズ ごと)。最後に「できた 画面 / のこり / 気になる 所」を 短く 報告。

## 8. やっては いけない こと

- 見本と 違う「それっぽい」デザイン ・ 勝手な 省略 ・ 新しい 機能
- 動いて いる Firebase ・ 認証 ・ 課金 ・ 通知の しくみを 壊す
- 1回で 全部 作ろうと する(フェーズを 守る)
- 大きな ファイルを ぜんぶ 読みこむ(`style.css` は 約 3,600行 ある。**クラス名 ・ 関数名で 検索**して 必要な 所だけ 読む)
