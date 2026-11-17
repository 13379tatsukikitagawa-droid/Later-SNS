<!-- ========== v86 : ME = Recap が 主役 ・ 過去の 写真を 見やすく ・ 没入 ========== -->
# PROMPT v86 ・ ME と Recap(モック `lattag_v82.html`)

> **いちばん 新しい 指示**。ME の 画面は v75 C(縦線だけの ME)・ v54 / v56 の ME と Recap を **ぜんぶ おきかえる**。
> 正解:モック `mock/lattag_v82.html`(デモボタン `ME:Recap` `Recap:できた(新)` `Recap 再生`)、元コード `mock/src/v79.css` `v79.js`(関数 `meRender` `rcWeeks` `rcKB` `rcAlbum` `rcDay` `rcPlay`)、
> 見本 `screens/F09 F10 F13 F14 F15 F16 F17 F18`、動き `motion/M24_recap_develop` `M25_recap_play`。

---

## A. 画面(上から 順に)

### A-1. ヘッダー
- `‹`(44 丸 ・ ガラス)・ `ME`(Inter 900 40)・ 右に `106 SHOTS` + 年(v75 と 同じ)。

### A-2. Recap ヒーロー(いちばん 新しい 週)`F09` `F18`
- 左右 16 ・ 縦横比 **4:5** ・ 角丸 30。写真が 全面。上下に 黒の グラデ(上 55% → 0 / 下 0 → 82%)。
- 左上:`NEW`(黄緑 `#C8F25A` の 丸ラベル ・ 字 黒)+ `RECAP ・ NOV 9–15`(Space Mono 10 ・ 字間 .16em)。見た あとは `▶ 見た`(白 20%)。
- その 下:**7本の 線**(高さ 3 ・ すきま 4)= 月〜日。撮った 日は 白 90%、撮らない 日は 白 28%。
- 左下:`Your` / `week.`(Instrument Serif 52 ・ `week.` は 斜体 黄緑)+ チップ 3つ `19 SHOTS` `7 DAYS` `#夕焼け`(黒 42% + ふち 白 20%)。
- 右下:再生ボタン 58 丸(ガラス)+ 外に 黄緑の 輪が 広がって 消える(2.2秒 くり返し)。
- **動き(Ken Burns)**:その 週の 写真が **2.6秒 ごとに 入れかわる**。新しい 写真は 1.12倍 → 1.02倍 に ゆっくり 寄りながら フェードイン、前の 写真は 0.9秒で 消える。
- **できた ばかり(未再生)の 時だけ「現像」**(`M24`):写真が `ぼけ 16 ・ 白黒 ・ 暗い ・ セピア` → `くっきり` に 1.8秒(0.3秒 待って から)。おわりに `hap(.land)`。
- 押すと Recap の 再生(C 章)。押した 時 0.985倍。

### A-3. 次の Recap(作成中)
- 高さ 約 68 ・ 角丸 22 ・ 地 `#121315`。
- 左:**リング**(44 ・ 線 4 ・ 黄緑)= 今週 何日目か(`2/7`)。
- まんなか:`次の Recap を つくって います` + `あと 6日 ・ 月曜 9:00 に できる`(日曜は `あした 9:00 に できる`)。
- 右:**7マスの フィルム**(9 × 26)。撮った 日 = その日の 写真 + 黄緑の ふち、撮らない 日 = 白 16%、今日 = 黄緑の 内線、これから = 白 7%。

### A-4. Recaps(これまで)`F10`
- 見出し `Recaps`(Instrument Serif 30)+ `9 RECAPS`。横スクロール(スナップ)。
- 先頭:**月の Recap**(幅 150 ・ 9:14 ・ ふち 黄緑 1.5)`MONTH` / `OCT`(Serif 40)/ `2026`。
- つづいて **週の Recap**(幅 124 ・ 9:14 ・ 角丸 18)上に 7本の 線、下に `WEEK` / `NOV 9–15` / `19 shots`。新しい 順。
- 押すと その Recap を 再生。

### A-5. 60日の 縦線(v75 C の まま ・ 高さ 208)
- なぞると 日を えらぶ → 下に その日の 3枚。**3枚を 押すと 1日の 全画面**(A-7)。

### A-6. アルバム(月の カレンダー)`F13`
- 見出し `Album` + `‹ 2026 ・ NOV ›`(34 丸)。曜日 `日〜土`。
- 7列 ・ すきま 4 ・ 1マス 3:4 ・ 角丸 8。**撮った 日 = その日の 最後の 1枚**、左上に 日付、右上に 枚数(2枚 以上)、右下に `★`(のこした 写真が ある 日)。
- 撮らない 日 = 地 `#141517` + うすい 日付。これからの 日 = 枠だけ。
- 月を 変えると 横から 30 すべって 入る(0.38秒)。`hap(.sel)`。
- 押すと **1日の 全画面**。

### A-7. 1日の 全画面 `F14`
- 黒 ・ 1.04倍 → 1倍 + フェード(0.45秒)で ひらく。`hap(.pop)`。
- 上:`×` ・ `日 11/15` + `SUN ・ 3 SHOTS` ・ `★`(のこす。押すと 黄緑)。
- 写真(左右 16 ・ 3:4 ・ 角丸 22)を **横に ページング**。下に 時刻 と タグ の チップ、`★ KEPT`。点の インジケーター。ページが 変わると `hap(.tick)`。
- iOS:`TabView(.page)` か `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)`。

### A-8. 数字(いちばん 下)`106 SHOTS ・ 48 DAYS ・ 19 KEPT ★`

### A-9. 入る 時の 動き
- ヒーロー → 作成中 → Recaps → 縦線 → アルバム の 順に **下から 22 上がって フェードイン**(0.56秒 ・ 70ms ずつ ずらす)。

---

## B. Recap の 再生(ストーリーの 形)`F15` `F16` `F17` `M25`

| 場面 | 見た目 | 時間 | バイブ |
|---|---|---|---|
| ひらく | カードから 全画面へ(0.92倍 + 角丸 40 → 1倍 + 角丸 0)| 0.5秒 | `projector` |
| 題 `F15` | `LATTAG RECAP` / `Your` `week.`(Serif 84)/ `NOV 9–15 ・ 19 SHOTS`。1行ずつ ぼかし → くっきり で 上がる | 1.7秒 | — |
| 写真 `F16` | 1枚 **1.3秒**。新しい 写真は 1.14倍 → 1.02倍(左右に 少し ずらす)。左下に `MON 9`(Serif 64)・ 時刻(黄緑)・ タグ。 | 枚数 × 1.3秒 | 日が 変わる 時 `soft` |
| 上の 線 | **1日 = 1本**(その日の 枚数で 分けて 進む)+ おわりの 半分の 線 | | |
| おわり `F17` | `Your week.` ・ 4マス(`SHOTS` `DAYS` `KEPT ★` `よく 撮る 時間`)・ 黄緑の `いちばん 多い タグ` ・ `保存` `シェア`(白)`↻` | | `success` |

- **操作**:右 2/3 を タップ = 次、左 1/3 = 前、**長押し = 止める**(はなすと 続き)、`×` = とじる。
- Reduce Motion:題を 出さない ・ 寄る 動きなし(切りかえのみ)。

---

## C. Recap が **ちゃんと できる** しくみ(ここが 大事)

### C-1. 写真の のこし方(前提)
- Firebase の 写真は **7日で 消える ままで よい**(友だちの フィード用)。
- **自分の 写真は 撮った 時に 端末に 保存**(`SwiftData` + App の Documents。元の 画像 1枚 + 512px の サムネイル)。
- 同時に **iCloud(CloudKit の 自分用 DB ・ 今の コンテナ)に 同期**。機種変更 ・ 入れなおし でも ME と Recap が 戻る。
- ★(のこす)は 「ずっと のこす」 印。★ 以外も 消さない(ME は 1年 以上 見られる)。容量が 気に なる 人むけに 設定で「★ だけ のこす」を あとで 足せる 形に しておく(今は 作らない)。

### C-2. いつ できるか
| 種類 | できる 時 | 中身 | 条件 |
|---|---|---|---|
| **週の Recap** | **毎週 月曜 9:00**(端末の 時間)| 前の 月〜日 の 写真 ぜんぶ(撮った 順)| **3枚 以上**。2枚 以下の 週は 作らない(月の Recap に 入る)|
| **月の Recap** | **毎月 1日 9:00** | 前の 月から **最大 30枚**(1日 1枚:★ が あれば ★、なければ その日の 最後の 1枚)| 5枚 以上 |

- 9:00 に そろえる 理由:Lattag の「9:00 に ひらく」と 同じ 時間に できる 体験に する。

### C-3. 作り方(端末の 中で つくる)
1. **データだけ 先に 作る**(動画は 作らない):`RecapManifest`
   ```swift
   @Model final class Recap {
     var id: String          // "w-2026-11-09" / "m-2026-10"
     var kind: Kind          // .week / .month
     var start: Date; var end: Date
     var photoIDs: [String]  // 撮った 順
     var stats: Stats        // shots, days, kept, peakHour
     var topTag: String?     // いちばん 多い タグ
     var cover: String       // ヒーローに 使う 写真
     var state: State        // .building / .ready / .seen
     var createdAt: Date
   }
   ```
   - CloudKit に 同じ 形で 同期(`users/{uid}/recaps/{id}` を Firestore に 置く なら **写真の パスは 入れない**。数字 と ID だけ)。
2. **いつ 作るか(3重に して 取りこぼさない)**
   - ① アプリを ひらいた 時 / 前に 来た 時(`scenePhase == .active`):「作る べき なのに ない Recap」を さがして 作る(**これが 本命**。かならず 動く)。
   - ② `BGAppRefreshTask`(`app.lattag.recap`)を 月曜 9:00 / 1日 9:00 の 直後に 予約。動けば 先に 作る。
   - ③ **ローカル通知**を 月曜 9:00 に 予約:「先週の Recap が できました」。通知を 押すと ME → 再生。(①で 作るので 通知の 時に できて いなくても よい。ひらいた 瞬間に 作る 0.1秒)
   - 作るのは 重くない(写真の ID を 並べる だけ)。何度 呼ばれても 同じ `id` なら 作らない(**冪等**)。
3. **状態**
   - `.building`:今週(A-3 の リング)。
   - `.ready`:できた → ME の ヒーローに `NEW` + 現像の 動き(`M24`)。
   - `.seen`:さいごまで 見た(おわりの 画面が 出た)ら。`▶ 見た`。
4. **再生**は 動画ファイルを 使わず、`Recap` の 写真を **SwiftUI で その場で 動かす**(`TimelineView` + `keyframeAnimator`)。
5. **保存 ・ シェア の 時だけ 動画に する**:`AVAssetWriter` で 1080 × 1920 ・ 30fps ・ H.264(1枚 1.3秒 ・ 同じ 寄り と 題 と おわり)。作って いる 間は ボタンが リングに なる。保存は `PHPhotoLibrary`(追加 だけの 権限 `NSPhotoLibraryAddUsageDescription`)、シェアは `ShareLink`。**サーバーには 上げない**(v56 の きまり の まま)。

### C-4. 写真が 消えて いたら
- 端末にも iCloud にも ない 写真は とばす。のこりが 条件(3枚 / 5枚)より 少なく なったら その Recap は 出さない(リストから 消す)。

---

## D. iOS へ の おきかえ

| モック | iOS |
|---|---|
| ヒーローの Ken Burns(`rcKB`)| `TimelineView(.periodic(by: 2.6))` + 2枚の `Image` を 重ねて `opacity` と `scaleEffect` |
| 現像(filter blur/grayscale/brightness/sepia)| `.blur(radius:)` `.grayscale()` `.brightness()` `.colorMultiply` を `keyframeAnimator` で 1.8秒 |
| 再生ボタンの 広がる 輪 | `.phaseAnimator` + `repeatForever`(Reduce Motion で 止める)|
| 横の Recaps | `ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)` |
| カードから 全画面 | `.matchedTransitionSource` + `.navigationTransition(.zoom)`(iOS 18)|
| 上の 進む 線 | `GeometryReader` の 幅 × 進み(`withAnimation(.linear(duration: 1.3))`)|
| 長押しで 止める | `.onLongPressGesture(minimumDuration: 0.24, pressing:)` |
| アルバム | `LazyVGrid(columns: 7)` + 月を 変える 時 `.transition(.push(from:))` |
| バイブ | `land` `projector` `soft` `success` `pop` `tick` `sel`(`spec/HAPTICS.md`)|

## E. 確かめる こと
1. `F09 F10 F13 F14 F15 F16 F17 F18` と 比べる(DEBUG の 状態メニュー:`Recap:見た` `Recap:できた(新)` `Recap:再生`)。
2. DEBUG で **時間を 月曜 9:00 に 進める** → アプリを ひらく → 先週の Recap が `NEW` で 出る。もう1回 ひらいても 2つに ならない。
3. 2枚 だけの 週は 週の Recap が 出ない。月の Recap には 入る。
4. 機内モード でも 作れる ・ 見られる(端末の 写真 だけで)。
5. 保存した 動画が 写真アプリに 入る(縦 1080 × 1920)。
