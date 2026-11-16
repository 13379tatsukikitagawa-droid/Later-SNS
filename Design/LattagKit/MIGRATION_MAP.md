# MIGRATION_MAP ・ いまの 実機 → モック v64(76 画面)

> P00 で 作成(2026-11-16)。**根拠**:ファイル名 ・ 参照の grep ・ 行数。画面を 実機で 開いて 確かめた 訳では ない ので、「要確認」は P01 以降の フェーズで 実際に 開いて 直す。
> 凡例:◎ ほぼ 同じ 役目の View が ある / ○ 部分的に ある / △ 古い 版が ある(作りなおし)/ ✕ 無い(新規)

## 0. いまの 構造(root)

- `App/Views/LaterApp.swift`(@main)→ 未ログインは `OnboardingFlowView`、ログイン後は `MainNavigationView`
- `MainNavigationView`:タブ 無し。**home(`TodayView`)/ profile(`ProfileShelfView`、右から)/ me(`MEScreenV19`、円形に ひらく)** の 3画面
- `TodayView`(状態 `HomeState.resolve` ・ 時刻を 決める)→ **`HomeView`(v3)** か **`HomeV5Container`**(L496 / L555 で 分岐)
- Trip:**コードが 1つも 無い**(`grep -i trip` で 該当 なし)→ P08 は 新規。
- 古い 版(v52 ごろ)の 特徴:名前 Later ・ 緑の 帯の カメラ ・ Yesterday の 下の タブが Mondo / Groups ・ Mondo が 空。

## 1. 画面 ID ごとの 対応

### P01 オープニング・はじめての 設定(O01〜O11)

| ID | いまの View | 判定 | メモ |
|---|---|---|---|
| O01 チェキが 出る | `Today/OpeningV21.swift`(`LaunchAnimation.swift`) | ○ | L-a-t-t-a-g 6文字・44pt に 変更(v62)。要確認 |
| O02 Lattag の 文字 | `OpeningV21` | ○ | `oplogo` 104pt |
| O03 入口(落ちてくる 題字) | `Onboarding/OnboardingFlowView.swift`(1,500行)/ `OnboardingV2Views` | ○ | `wclogo` 112pt |
| O04 サインイン | `OnboardingFlowView` + `AppleSignInView` `EmailSignInView` | ○ | Apple / Google / メール |
| O05 メール / O06 送信済み | `EmailSignInView` | ○ | |
| O07 名前と 色 | `OnboardingFlowView` | ○ | |
| O08 タグを 3つ | `OnboardingFlowView`(`SelfTagPicker` は 未使用) | △ | |
| O09 友だち | `OnboardingFlowView` | △ | |
| O10 通知の 許可 | `OnboardingFlowView`(`NotificationCardSample` は 内部 使用) | ○ | |
| O11 できた | `OnboardingFlowView` / `WidgetSetupFlow`(別) | △ | |

### P02/P03 Home 上・横スライド(H01〜H18)

| ID | いまの View | 判定 | メモ |
|---|---|---|---|
| H01〜H06 カメラカード(0〜3枚) | `HomeV5Container` / `HomeV22` / `HomeDarkroom` / `HomeV5Chrome` | △ | まんなかの ボタン(Join/Shoot/Chat/Yesterday)は 直近の v32 で 実装 済。見本と 比べて 直す |
| H02 はじめの 合図 | `Today/FirstHint.swift` `FirstGuideView.swift` | ○ | |
| H07 友だち + 申請 | `HomeV5Chrome` / `FriendsClockCard` | △ | |
| H08 はじめての 日 | `HomeV5Container`(`HomeState`) | ○ | |
| H09 夜 | `ThemeClock` + `ChicTheme` の 夜 | ○ | |
| H10 「消灯まで」パネル | `Today/HomeLightsPanel.swift` | ◎ | |
| H11/H12 Friends ページ | `Today/FriendsHub.swift` | ○ | |
| H13 Trip ページ | **無い** | ✕ | P03 / P08 |
| H14/H15 Mondo ページ | `HomeV5Mondo` / `MondoViews` / `MondoModel` | △ | 投稿が 空 → 見本データで 確認 |
| H16〜H18 Yesterday ページ | `HomeV5Group`(Yesterday) / `YesterdayGroupHero` / `EmptyYesterdayView` | △ | |

### P04 Home 下(L01〜L11)

| ID | いまの View | 判定 |
|---|---|---|
| L01 Today | `HomeDarkroom` の `TodayDevelopCard` / `HomeDevelopCard` | △ |
| L02 Active | `HomeDarkroom` の `ActiveInviteCard` / `HomeGroupStrip` | △ |
| L03/L04 Yesterday | `HomeDarkroom` / `YesterdayGroupHero` | △ |
| L05 Mondo の 列 | `HomeV5Mondo` | △ |
| L06 Albums | `HomeDarkroom`(ALBUMS)/ `LampCalendar` | △ |
| L07 On this day | 要確認(`HomeDarkroom` 内?) | △ |
| L08/L09 Friends カード | `FriendsClockCard` / `FriendsHub` | △ |
| L10 はじめての 日の Yesterday | `EmptyYesterdayView` | ○ |
| L11 現像を ひらく | `HomeDevelopViewer.swift` | ◎ |

### P05 撮る(C01〜C11)

| ID | いまの View | 判定 |
|---|---|---|
| C01 タグ画面 | `Camera/Views/TagScreen.swift`(899行) | ○ |
| C02/C03 撮影(写真/動画) | `Camera/Services/CaptureScreenV21.swift` `Camera/Views/CaptureScreen.swift` `ExposureCameraView` / `VideoModeLayer` | ○ |
| C04 音量ボタン | `CaptureScreenV21`(要確認) | △ |
| C05〜C07 撮った あと | `CaptureAfterShotView` `ShotDoneView` | ○ |
| C08/C09 翌朝の 現像 | `DevelopSheet` `HomeDarkroom`(v30 の 暗室) | ○ |
| C10/C11 レア / チェキ | `ChekiPhotoFrame`(`ChekiLightLeak` は 未使用) | △ |

### P06 Lattag yesterday(Y01〜Y06)

| ID | いまの View | 判定 |
|---|---|---|
| Y01〜Y05 | `HomeV5Group`(`YesterdayOnceHero`)/ `HomeV5Mondo` / `FriendsHub` / `GroupSummary` | △ |
| Y06 写真を ひらく | `Today/VerticalPhotoViewer.swift` / `HomeDevelopViewer` | ○ |

### P07 Friends・Profile・ME(F01〜F10)

| ID | いまの View | 判定 |
|---|---|---|
| F01〜F04 Friend 画面 | `Today/FriendScreenV48.swift` / `FriendsHub` | ○ |
| F05 友だちの カード | `FriendsHub`(シート)/ `Profile/Views/UserDetailView` | △ |
| F06 Add friends | `Today/FriendQRScanView.swift` `QRScanView` `ProfileShelfView`(`ProfileSelfQRSheet`)/ `FriendMascot` | ○ |
| F07 DM チャット | `Today/GroupChat*`(`GroupChatRoom` 887行)。**友だちとの 1対1 は 要確認** | △ |
| F08 Profile | `Profile/Views/ProfileShelfView.swift`(953行)/ `ProfileEditScreen` | ○ |
| F09 ME | `Today/MEScreenV19.swift`(1,249行) | ◎ |
| F10 QR を 読む | `FriendQRScanView` `QRScanView` | ◎ |

### P08 Trip(T01〜T09)

| ID | いまの View | 判定 |
|---|---|---|
| T01/T02 New trip | `Group/Views/NewGroupFlowView.swift`(2,137行、グループ 作成)を 土台に できるか 検討 | △/✕ |
| T03/T05 Trip パス | **無い** | ✕ |
| T04 Trip ページ / T09 Active カード | **無い**(`HomeGroupStrip` / `ActiveInviteCard` が 近い) | ✕ |
| T06 設定 | `Today/GroupSettings.swift`(`GroupLeave`) | ○ |
| T07 部屋 | `Today/GroupChatRoom.swift` / `GroupRoomView` | ○ |
| T08 招待が とどく | `Today/GroupInvite.swift` `GroupJoinFlow.swift`(`InvitationView`) | ○ |

## 2. 消す / 置きかえる もの(古い)

> どれも「どこからも 参照されて いない」ことを **grep で 確認 済**(宣言の 1回だけ)。実際に 消す のは 各 フェーズで 置きかえた とき。**P00 では 消さない**。

| 区分 | もの | 理由 |
|---|---|---|
| 参照 なし(死んだ コード) | `HomeDotRing` `HomeTodayCard`(HomeV22)`HomeLayerStack` `HomeV17Stack` `MondoGlobeStage(V19)` `MondoBand` `MondoBigPrint` `OutlineNumber` `GroupEmptyYouthView` `MEScreen`(MEAndCalendar)`ProfileFilmView` `ProfileImmersiveView` `ChicNightSphere` `ChicScribble` `ChicRingArt` `LampButton` `LampStatusDot` `LampBloom` `DoubleRipple` `AnnouncedWorldCard` `FilmTriplet` `ChekiLightLeak` `GroupConfetti` `GroupCreateBackdrop` `TypewriterText` `RetakeCountUp` `SelfTagPicker` `MondoPlaceChips` `MondoPlaceCard` `GroupDotRing` | 新しい 版に 置きかわって いる |
| 古い Home | `HomeView`(v3,`TodayView` L496)と `ChicHomeView`(447行)| `HomeV5Container` が 本命(L555)。分岐の 条件を P02 で 確認して 一本化 |
| 古い Home の 層 | `HomeLayerViews` / `HomeLayerSheets` / `HomeLayerSocial`、`HomeV17*`(Sections 以外は 使用中の 可能性。要確認) | v17 系の 古い 階層レイアウト |
| 古い タブ | Yesterday の 下の **Mondo / Groups** タブ(`HomeV5Mondo` / `HomeV5Group` の 該当 部分) | v64 で 再編(P03/P06) |
| 古い カード | 写ルンです風の 緑の 帯の カメラ・`HomeDevelopCard` / `ChekiFilmFrames` 系 | P02/P04 で 新カードに |
| 触らない | `ThemeClock` `LaterFont` `LaterColor`(名前を 変えない)・Firebase / CloudKit / 認証 / 課金 | CLAUDE.md §3, §8 |

## 3. P00 で 足す もの(土台)

| もの | 場所 | 状態 |
|---|---|---|
| `Brand` | `Theme/Brand.swift` | 新規 |
| `LGColor` `LGFont` `LGMotion` `LGGlass` `LGPressable` | `DesignSystem/` | 新規 |
| `Haptics.play(.名前)`(15種) | `Camera/Services/ExposureHaptics.swift` を 拡張(`warn` `buzz` `vui` を 追加、`gap`) | 拡張 |
| DEBUG 状態メニュー + 見本データ + プレビュー | `Debug/` | 新規(`#if DEBUG`) |
| `scripts/snap.sh` | リポジトリ 直下 | 新規 |

## 4. 気を つける 点

- アプリ ターゲットは **ファイルを 明示的に 参照**(`project.pbxproj`)。新しい .swift は 手で 追加が 必要。`LaterTests` だけ 自動。
- 作業ツリーに **別作業の 未コミット 変更が 多数**。P00 の コミットには 含めない(自分の ファイルだけ)。
- シミュレータの 幅 390pt は **iPhone 17e**(390×844)を 使う(16 / 17 は 393pt)。
