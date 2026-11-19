<!-- ========== v107 : 写真 = チェキ ・ 動画 = iPhone 8 の 質感(必須)========== -->
# PROMPT v107 ・ 写真は チェキ、動画は iPhone 8 の 質感(**必須**)

> **いちばん 新しい 指示**。**これは 必須**(どの 画面より 優先)。
> 正解の 数字:`tools/film/film_pipeline.py`(ここの 値を そのまま 使う)。
> 素材:`assets/film/`(`cheki_v2_lut33.bin` ・ `retro8_lut33.bin` ・ `grain_512.png` ・ テストの 色見本 `chart_in.png` と 答え `chart_*_lut_only.png`)。見本:`assets/film/samples/`(`_overview.jpg` に 全部)。
> Swift の 形:`prompts/reference/swift/FilmLook_v107_example.swift`。

---

## 0. まず しらべて 報告(コードは まだ 変えない)
1. 今の `FilmEmulation.swift`(5層)は **どこで 使われて いるか**:撮った 時 / 表示の 時 / 送る 時。**送る ファイルに 質感が 入って いるか**。
2. 撮った 写真の 流れ:撮る → 保存(ME ・ 端末)→ Trip(CloudKit)→ 友だち(Cloudflare R2)。それぞれ どの ファイルを 使って いるか。
3. 動画の 流れ:撮る 設定(解像度 ・ fps ・ HDR ・ 手ぶれ補正 ・ コーデック)と 保存 ・ 送り方。
4. 表示の 時に 毎回 かけて いる フィルター(`CIFilter` ・ `.blur` ・ `.colorMultiply` など)の 一覧。
5. 今の 写真 1枚 / 動画 10秒 の ファイルの 大きさ。

**ここで 止まって 報告**。

## 1. しらべた こと(なぜ この 作り か)
### チェキ(Instax mini)
- ISO 800 ・ 昼光(5500K)・ **彩度を 上げた 色** ・ **なめらかな 粒子**。コントラストは「少し 強め」。
- ラチチュード(明るさの 幅)は **約 9〜10段**(いまの スマホは ずっと 広い)→ **明るい 所は すぐ とぶ ・ 暗い 所は つぶれ ぎみ**。
- 解像は **約 12本/mm**。絵の 大きさ 46 × 62mm → **約 1500px 相当**。高い 解像度は 要らない(→ 小さく して 軽く できる)。
- 絵の 比率 46:62 ≒ **3:4**(今の アプリの 比率と ほぼ 同じ)。カードの 大きさ 54 × 86mm。
### iPhone 8(2017)の 動画
- 4K 24/30/60 ・ 1080p 30/60 ・ 光学手ぶれ補正 + 1080p の「シネマ」補正 ・ HEVC / H.264。
- **HDR 動画は 無い**(写真の Auto HDR だけ)→ 明るい 所は ストンと とぶ ・ 影は 締まる。今の スマホの「影を 持ち上げて 平らに する」処理が 無い ので、**コントラストが あり 自然に 見える**(今の 若い 人が 古い iPhone で 撮る 理由と 同じ)。
### 出典
- Fujifilm Instax film の 特性(ISO800 ・ 5500K ・ 約 9〜10段 ・ 12本/mm):fujirumors.com「Top Ten Things to Know about Fujifilm Instax Film」
- Instax mini の 見え方(はっきりした 色 ・ なめらかな 粒子):PetaPixel 2026/11/06
- iPhone 8 の 動画仕様:support.apple.com(SP767)
- 今の スマホが「処理しすぎ」に 見える 理由(HDR で 影を 持ち上げる ・ 古い 機種は 自然):MKBHD「Why New Smartphone Cameras Feel Worse」

## 2. いちばん 大事な きまり
1. **撮った 時に 1回 だけ 焼きこむ**。表示の 時には **何も かけない**(フィルター 0 ・ 軽い)。
2. **焼いた ファイル だけ を 保存 ・ 送る**。ME ・ Trip ・ 友だち ・ ウィジェット ・ 外への 共有、**ぜんぶ 同じ ファイル** → 友だちにも 同じ チェキの 質感で とどく。
3. 処理は **Core Image だけ**(GPU ・ 6回 ほど)。自前の 重い 処理 ・ 機械学習 ・ 毎コマの ぼかし計算は しない。
4. 撮影中の 画面(プレビュー)には かけない(Lattag は「あした ひらく」ので、撮った 直後に 見せる 必要が ない ・ いちばん 軽い)。
5. メタデータ(EXIF ・ 位置情報)は 焼く 時に 捨てる(v103 の きまり)。
6. **変な 加工は しない**:枠の 絵 ・ 光の もれ ・ ゴミ ・ キズ ・ 日付の 焼きこみ は 写真に 入れない(質感 だけ)。

## 3. 写真:チェキ(`FilmLook.chekiJPEG`)
| 順 | 処理 | 値 | Core Image |
|---|---|---|---|
| 0 | 向きを 直す ・ メタデータを 捨てる | — | `applyOrientationProperty` ・ `settingProperties([:])` |
| 1 | 切りぬき | 今の アプリの 比率(3:4) | `cropped` |
| 2 | **長い 辺 1440px** に 縮小 → 0.86倍 に 小さく して もどす(少し やわらかい)| 1440 ・ 0.86 | `CILanczosScaleTransform` × 2 |
| 3 | **色(LUT 33³)** | `cheki_v2_lut33.bin` | `CIColorCubeWithColorSpace`(sRGB)|
| 4 | にじみ(明るい 所 だけ)| σ 8px(1440 の 時)・ 強さ 0.22 ・ 0.55 から 上 | `GaussianBlur` → `ToneCurve` → `ColorMatrix` → `AdditionCompositing` |
| 5 | ビネット | 強さ 0.42 ・ 半径 1.15 | `CIVignette` |
| 6 | 粒子 | `grain_512.png` を ならべる ・ 写真ごとに ずらす ・ 強さ 0.55 | `CIAffineTile` → `ColorMatrix` → `CISoftLightBlendMode` |
| 7 | JPEG | 品質 0.85(1枚 約 0.3〜0.5MB)| `jpegRepresentation` |

- LUT の 中身(色の 変え方 ・ `film_pipeline.py` の `cheki_color`):少し 明るく ・ コントラスト 1.10 ・ **白は クリーム色(0.985 / 0.970 / 0.925)に やわらかく とぶ** ・ 黒は 少し 浮く(真っ黒に しない)・ 影は 青緑 ・ 明るい 所は 暖色 ・ 緑 → 黄緑 ・ 青 → 青緑 ・ 彩度 1.15(赤〜橙を 少し 濃く)。
- 処理の 場所:撮った あと **バックグラウンド(`.utility`)**。1枚 数十ms の 見こみ(実機で はかる)。
- `CIContext` は アプリで **1つ**(`workingFormat: .RGBAh` ・ `cacheIntermediates: false`)。LUT と 粒子は **はじめて 使う 時に 1回 だけ** 読む。
- 撮影の 設定:`photoQualityPrioritization = .balanced`(処理を 強く しすぎない)。

## 4. 動画:iPhone 8 風
### 4-1. 撮る 時の 設定(処理 0 で 半分 決まる ・ `Retro8Capture`)
- **1920 × 1080 ・ 30fps**(4K ・ 60fps に しない)。
- **HDR 動画 オフ**(`automaticallyAdjustsVideoHDREnabled = false` ・ `isVideoHDREnabled = false`)・ 色は **sRGB**(HLG / Dolby Vision に しない)。
- 手ぶれ補正は **`.standard`**(強い 補正に しない)。カメラは **広角 1つ**(超広角 ・ 望遠に 自動で 切りかえない)。
- コーデック **H.264**。
### 4-2. 撮った あと 1回 書き出す(`FilmLook.exportRetro8`)
| 順 | 処理 | 値 |
|---|---|---|
| 1 | **色(LUT 33³)** | `retro8_lut33.bin`(少し 暖かい ・ 黒は 締める ・ S字 ・ **0.9 から 上は 早く とぶ** ・ 彩度 1.08)|
| 2 | うすい シャープ(古い 処理の 少し かたい 輪郭)| `CISharpenLuminance` 0.35 ・ 半径 1.2 |
| 3 | 粒子(**こまごとに ずらす** = 動く ノイズ)| 強さ 0.30 |
| 4 | 書き出し | `AVAssetExportPreset1920x1080` ・ mp4 ・ 30fps ・ メタデータは `.forSharing()` |
- `AVVideoComposition` の Core Image の 関数で 1こま ずつ(GPU)。書き出しは バックグラウンド。**終わる まで 送らない**(送るのは 書き出した ファイル だけ)。
- 書き出し中に アプリを 閉じても:元の ファイルを のこし、次に 開いた 時に やりなおす。

## 5. 友だちに 共有 ・ 外に 共有
- 友だち(Cloudflare R2)・ Trip(CloudKit)・ ME:**焼いた ファイル**を そのまま。サーバーで 何も しない。
- アプリの 中の 表示:チェキの **枠は UI**(今の チェキの 部品 ・ 日付の 字も UI)。写真には 枠を 焼かない。
- **外に 共有**(共有シート ・ 写真に 保存)の 時 だけ:Instax mini の 比率(54 × 86 ・ 絵は 上 4mm ・ 左右 4mm)の **白い 枠を 1回 合成**して 出す(色 `#F6F3EA`)。日付の 字は 枠の 下に 小さく(Space Mono ・ オレンジ)。
- 動画は 枠なし(書き出した mp4 の まま)。

## 6. 軽さの きまり
- 表示時の フィルター 0 ・ 画面の 動きの 間に 書き出さない(v89)。
- 1440px に する ので、**今より ファイルが 小さく なる**(送る ・ 読む が 速い)。
- 素材の 合計 約 1.4MB(LUT 2つ 各 575KB ・ 粒子 250KB)。
- 古い `FilmEmulation`(5層)・ 表示時の フィルターは **消す**(質感は この 1つに まとめる)。
- 前に 撮った 写真は そのまま(焼きなおさない)。

## 7. 確かめる こと
1. **Unit テスト**:`chart_in.png` に LUT だけ かけた 結果が `chart_cheki_lut_only.png` / `chart_retro8_lut_only.png` と **1画素 ±3/255 以内**(LUT の 読み方 ・ 色空間の 確認)。
2. 実機で 同じ 場所を 撮って `assets/film/samples/_overview.jpg` と 見くらべる(写真の 中身は 違って よい ・ **色の 方向 ・ 明るい 所の とび方 ・ 粒子 ・ やわらかさ** を 見る)。
3. 写真 1枚の 処理時間(ms)・ メモリの 山 ・ ファイルの 大きさ を 報告。動画 10秒の 書き出し時間 ・ 大きさ。
4. 友だちの 端末で 見ても 同じ 質感(サーバーの ファイルを ダウンロードして 確かめる)。EXIF ・ 位置情報が 無い。
5. 外に 共有 → 白い 枠つき。アプリの 中 → 枠は UI。
6. Instruments:撮った 直後の Home の 動きに ヒッチ 0(処理が 重なって いない)。
