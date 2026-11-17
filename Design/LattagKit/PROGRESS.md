# PROGRESS ・ 進み具合(Claude Code が 書きこむ)

| 段階 | 中身 | 画面 | 状態 | メモ |
|---|---|---|---|---|
| P00 | 準備 ・ 土台 ・ DEBUG メニュー ・ 名前 | — | ✓ | 2026-11-16。テスト 全部 成功 ・ シミュレータ(17e)で 起動 ・ lattag:// と later:// 両方 受けつけを 確認。3本指 メニューの 実機/シミュレータ 操作は 未確認 |
| P01 | オープニング ・ はじめての 設定 | O01〜O11 | ✓ | 2026-11-16。テスト 457件 成功 ・ 全11画面 score 8 以下。Google サインインは コード だけ(Firebase 側の 設定が 必要)・ 実機の バイブ / 長押し〜Home入りは 未確認 |
| P02 | Home の 上 ・ カメラカード | H01〜H10 | ✓(見た目)| 2026-11-17。ぼかし写真 + ガラスの カード ・ レンズ ・ 四すみ ・ ピル ・ チップ ・ 目次 ・ 月 ・ ライブパネル ・ はじめの 合図。入場 / シャッターの 動きと 実機の バイブは 未仕上げ |
| P03 | 横スライド ・ 目次 ・ Mondo | H11〜H18 | ✓(見た目)| 2026-11-17。5ページの 横スライド(3D ・ ゴム ・ ±1ページ)・ Friends / Trip / Mondo(本物の 海岸線の 地球)/ Yesterday。ページ入場の ずらし動き ・ 浮かぶ チェキは 未 |
| P04 | Home の 下 | L01〜L11 | ✓(見た目)| 2026-11-17。Today ・ Active ・ Yesterday ・ Mondo(縦長カード)・ Albums(4列)・ On this day ・ Friends カード(空っぽの キャラ / ポラロイドの 壁)・ はじめての 日の 空カードを 作り、L01 / L04〜L10 を 位置あわせ(4.4〜16)。L02(11.0)/ L03(19.7)/ L11(11.1)も 計測。L11 は `DevelopV64View`(Home の ピル → 現像)|
| P05 | 撮る(タグ ・ 撮影 ・ 現像) | C01〜C11 | ◐ | 2026-11-17。C01(タグ画面)は 既存の 画面が ほぼ 見本どおり だったので 題字を Later Mincho 29pt に 直した(10.2)。C02〜C11(撮影 ・ 撮った あと ・ 現像 ・ レア ・ チェキ)は シミュレータに カメラが 無く 見くらべ 不能 → 既存の 実装の まま(未計測)|
| P06 | Lattag yesterday | Y01〜Y06 | ✓(見た目)| 2026-11-17。白い ページ + 大きな カード + 下の ガラスタブ(Friends が 先 / Mondo)を `YesterdayV64View` で 作成。Mondo タブの 地球の 文字 ・ 写真を ひらく画面(reply で 既存の ビューアへ)まで。Y05(ME ・ Friend ・ TRIPS)も 作成(13.2)。Mondo の 都市の 時計は 実際の 時刻 |
| P07 | Friends ・ Profile ・ ME | F01〜F10 | ◐ | 2026-11-17。**申請 → 承認**(`FriendRequests`:ConnectionRequest / ConnectionResponse)と **1対1 チャット**(`DirectMessages`:DirectMessage)を 実装し、Home の Friends ページ / 下の Friends カードの「Requests」と 友だちの 丸から ひらく。純粋な 決まりは テスト 済(463件)。CloudKit との 実際の やりとりは 未確認(本番スキーマに 3つの レコードタイプが 入って いる 必要)。連絡先から さがす ・ Friend 画面 / Profile / ME の 見た目の 作りなおしは 未 |
| P08 | Trip | T01〜T09 | ◐ | 2026-11-17。Home の Trip ページ(H13)と Active の「New trip」カードは 作成 済。T01〜T08(つくる ・ パス ・ 設定 ・ 部屋 ・ 招待)は 既存の `NewGroupFlowView` / `GroupSettings` / `GroupChatRoom` / `GroupInvite` が すでに v58(Trip パス ・ Cover ・ KEY ・ QR)の 作りで、このフェーズでは 触って いない(見くらべ 未)。23枚の 予約は 未 |
| P09 | データ ・ 仕上げ ・ 全画面の 確認 | 全76 | ◐ | 2026-11-17。DEBUG だけの コードは Release ビルドで 外れる ことを 確認(Release ビルド 成功)。Reduce Motion は 新しい 画面の くり返し動き ・ ページャーの 3D で 止める。全76画面の 再比較 ・ 動き14本の 画面収録 ・ Instruments ・ VoiceOver の 通し確認 ・ 「Cloud Functions」(サーバー側の 9:00 処理)は 未 |

## 画面ごとの ずれ(compare.py の score。0 = 同じ。目安 8 以下)

| ID | score | 日付 | メモ |
|---|---|---|---|
| O01_opening_print | 2.3 | 2026-11-16 | t=1.95s で 止めて 比較 |
| O02_opening_logo | 4.6 | 2026-11-16 | t=2.62s |
| O03_onboarding_intro | 7.6 | 2026-11-16 | t=4.1s。見本の 写真(PH)は 実機に 作らないので 色の 面 → ここが 差の ほとんど |
| O04_onboarding_signin | 5.6 | 2026-11-16 | 壁の 写真は 色の 面。Apple は 公式ボタン(文言が「Appleで続ける」) |
| O05_onboarding_mail | 3.1 | 2026-11-16 | |
| O06_onboarding_sent | 3.5 | 2026-11-16 | |
| O07_onboarding_name | 2.5 | 2026-11-16 | |
| O08_onboarding_tag | 3.5 | 2026-11-16 | |
| O09_onboarding_fr | 2.8 | 2026-11-16 | `-debugInvite あや` で 見本の 申請の 行 |
| O10_onboarding_nt | 4.0 | 2026-11-16 | |
| O11_onboarding_go | 2.7 | 2026-11-16 | |
| H01_home | 9.6 | 2026-11-17 | 見本写真は DEBUG の /tmp(モックから 取り出した)で 比較。本番は 友だちの モザイク |
| H02_home_hint | 17.2 | 2026-11-17 | 合図の ぼかし(うすさ)を 調整 余地 |
| H03_home_press | 10.9 | 2026-11-17 | |
| H04_home_1shot | 9.6 | 2026-11-17 | |
| H05_home_2shot | 9.7 | 2026-11-17 | |
| H06_home_3shot | 9.7 | 2026-11-17 | |
| H07_home_friends | 9.9 | 2026-11-17 | |
| H08_home_firstday | 10.9 | 2026-11-17 | |
| H09_home_night | 9.5 | 2026-11-17 | 夜も 見本どおり 同じ 見た目 |
| H10_live_panel | 12.1 | 2026-11-17 | |
| H11_page_friends | 12.7 | 2026-11-17 | |
| H12_page_friends_filled | 12.4 | 2026-11-17 | |
| H13_page_trip | 15.3 | 2026-11-17 | |
| H14_page_mondo_locked | 11.3 | 2026-11-17 | |
| H15_page_mondo_open | 11.0 | 2026-11-17 | |
| H16_page_yesterday | 14.0 | 2026-11-17 | |
| H17_page_yesterday_open | 13.7 | 2026-11-17 | |
| H18_page_yesterday_firstday | 12.3 | 2026-11-17 | |
| L02_active | 11.0 | 2026-11-17 | |
| L03_yesterday | 19.7 | 2026-11-17 | ぼかし写真の 色 差 |
| L11_develop_view | 11.1 | 2026-11-17 | |
| Y05_yesterday_scroll | 13.2 | 2026-11-17 | |
| L01_today | 7.4 | 2026-11-17 | スクロール 936 |
| C01_tag | 10.2 | 2026-11-17 | 既存の TagScreen + 題字だけ 直した |
| Y01_yesterday_locked | 13.4 | 2026-11-17 | |
| Y02_yesterday_open | 13.8 | 2026-11-17 | |
| Y03_yesterday_mondo_tab | 12.1 | 2026-11-17 | |
| Y04_yesterday_friends_tab | 13.5 | 2026-11-17 | |
| Y06_photo_viewer | 10.2 | 2026-11-17 | |
| L04_yesterday_open | 14.0 | 2026-11-17 | `-debugSection sec-yesterday:97` |
| L05_mondo_row | 11.5 | 2026-11-17 | `sec-mondo:157` |
| L06_albums | 13.2 | 2026-11-17 | `sec-albums:137` |
| L07_onthisday | 14.2 | 2026-11-17 | `sec-onthisday:157` |
| L08_friends_card_empty | 10.3 | 2026-11-17 | `sec-friends:151` |
| L09_friends_card | 16.1 | 2026-11-17 | `sec-friends:210` |
| L10_firstday_yesterday | 4.4 | 2026-11-17 | `sec-yesterday:200` |

## P00 メモ(2026-11-16)

- 作った もの:`Theme/Brand.swift` ・ `DesignSystem/`(LGColor LGFont LGMotion LGGlass LGPressable)・ `Debug/`(DebugState DebugStateMenu SampleData DesignSystemPreview)・ `scripts/snap.sh` ・ `MIGRATION_MAP.md`
- `Haptics.play(.名前)` は 既に 15種類 そろって いた(`ExposureHaptics.swift`)ので 手を 入れて いない。強さの 数値は HAPTICS.md と 少し 違う(例 `tick` 0.45 vs 0.35)→ P01 で 実機に あわせて 調整。
- DEBUG 状態メニュー:3本指 長押し。撮った 枚数 / 昼夜 / オープニング / 設定やりなおし は 既存の しくみに つなぐ。友だち・申請・Trip・招待・初日・翌朝9:00・見本データ は 値を `DebugState`(UserDefaults `debug.*`)に 保存する だけで、**各 画面を 作る フェーズで 読む**。
- 見本データの 写真は 色の 面(画像は 後の フェーズ)。
- シミュレータ:幅 390pt は **iPhone 17e**。
- ロゴの 大きさ(v62 §3B:オープニング 104pt など)は まだ 直して いない(P01 / P02)。

## P01 メモ(2026-11-16)

- 作った もの:`Onboarding/V64/`(OnboardingV64View ・ Parts ・ Intro)・ `Debug/DebugRouter.swift` ・ `scripts/snapto.sh` `scripts/snapob.sh`。`LaterApp` の 初回設定は `OnboardingV64View`(古い `OnboardingFlowView` は 未使用で 残している)。
- オープニング(`OpeningV21`)は v64 の 見た目(緑の 紙 ・ 白い チェキ ・ テープ ・ 窓に 空が のぼる ・ Lattag 44pt)に 作りなおし。短縮版は 全体を 半分の 長さ。
- 手順は モックの in → (mail → sent) → name → tag → fr → nt → go。day ・ quiet ・ photo は 外した(写真は タグ画面の カメラ丸ボタン → 写真えらび → 既存の プロフィール写真の 保存)。
- スクショの 撮り方:`scripts/snapob.sh <ID> <intro|in|mail|sent|name|tag|fr|nt|go> [t秒]`(DEBUG)/ `scripts/snapto.sh <ID> opening <t秒>`。状態メニューにも「はじめての 設定の 画面へ」。
- **Google サインイン**:Firebase Auth の OAuth(`google.com`)で 書いた。`GoogleService-Info.plist` に CLIENT_ID が 無い ので、Firebase コンソールで Google を 有効に → plist を 入れかえ → URL スキーム(REVERSED_CLIENT_ID)を 足す まで は 押すと「準備中」の 表示。
- 友だち(O09):連絡先検索 ・ 申請の 実データは 無い ので、行は「招待してくれた 人」が いる とき(いまは DEBUG の 見本のみ)だけ。「リンクを おくる」は 既存の 友だちリンク。「ふって つながる」は ひと言 出すだけ。
- 注意:シミュレータで 通知の 許可ダイアログが 残ると 以後の スクショが ぜんぶ 崩れる(`simctl shutdown` → `boot` で 消える)。

## P02〜P04 メモ(2026-11-17)

- 新しい Home は `Today/V64/`(Parts ・ View ・ Pages ・ Lower ・ Host ・ ViewSwitch)。`TodayView` の `HomeView(` を `HomeViewSwitch(` に 1か所 かえただけ(`usesV5Home` に `&& !UIFlag.v64`、古い 月は `UIFlag.v64` の とき 見えなく)。DEBUG の 状態メニューで 切りかえ(UserDefaults `ui.v64`、既定 ON)。
- 古い 昨日の Home(`HomeV5Container`)は V64 の あいだ 出ない。昨日の 画面は P06 で 作る(それまで「yesterday」「Yesterday の 四すみ」は 既存の ビューアへ)。
- DEBUG:`scripts/snapto.sh <ID> home -- -debugBackdrop 1 -debugShots 2 -debugFriends 3 -debugPage 1 -debugScroll 936 …`(`Debug/DebugRouter.swift` の HomeV64Preview)。見本写真は モックから 取り出して `/tmp/lattag_ph/`(リポジトリの 外)に 置く。
- 撮る:`CaptureRequestStore.shared.pendingRequestID = UUID()`(通知 / ウィジェットと 同じ 入口)。のこり 0 の ときは「今日は、ここまで」。

## 2026-11-17 再計測(`scripts/snapall.sh`・見本の端末わく(DEBUG のみ)を重ねて比較)

| ID | score |
|---|---|
| H01_home | 6.4 |
| H02_home_hint | 10.0 |
| H03_home_press | 7.9 |
| H04_home_1shot | 6.7 |
| H05_home_2shot | 6.7 |
| H06_home_3shot | 7.1 |
| H07_home_friends | 7.6 |
| H08_home_firstday | 6.7 |
| H09_home_night | 6.7 |
| H10_live_panel | 16.9 |
| H11_page_friends | 10.1 |
| H12_page_friends_filled | 9.7 |
| H13_page_trip | 12.5 |
| H14_page_mondo_locked | 8.0 |
| H15_page_mondo_open | 8.4 |
| H16_page_yesterday | 11.5 |
| H17_page_yesterday_open | 11.2 |
| H18_page_yesterday_firstday | 8.3 |
| L01_today | 8.5 |
| L02_active | 8.4 |
| L03_yesterday | 8.8 |
| L04_yesterday_open | 9.5 |
| L05_mondo_row | 8.1 |
| L06_albums | 7.1 |
| L07_onthisday | 11.6 |
| L08_friends_card_empty | 7.2 |
| L09_friends_card | 13.0 |
| L10_firstday_yesterday | 5.4 |
| L11_develop_view | 11.1 |
| Y01_yesterday_locked | 9.6 |
| Y02_yesterday_open | 10.3 |
| Y03_yesterday_mondo_tab | 6.9 |
| Y04_yesterday_friends_tab | 10.3 |
| Y05_yesterday_scroll | 8.4 |
| Y06_photo_viewer | 1.5 |
| C01_tag | 26.6 |

- 8 以下:H01 H03〜H06 H08 H09 L01〜L06 L08 L10 Y03 Y05 Y06。H10(ライブパネル)16.9 ・ H13 12.5 ・ L09 13.0 ・ L07 11.6 ・ H16/H17 11 台が 残り。C01 は 見本が HTML 描画の キーボードで 実機の キーボードと 別物 → 26 前後から 下がらない。
- 作業の道具:`scripts/snapall.sh`(全画面)・`anchor_search.sh`・`grid.py`・`bands.py`。
