# PROGRESS ・ 進み具合(Claude Code が 書きこむ)

| 段階 | 中身 | 画面 | 状態 | メモ |
|---|---|---|---|---|
| P00 | 準備 ・ 土台 ・ DEBUG メニュー ・ 名前 | — | ☐ | |
| P01 | オープニング ・ はじめての 設定 | O01〜O11 | ☐ | |
| P02 | Home の 上 ・ カメラカード | H01〜H10 | ☐ | |
| P03 | 横スライド ・ 目次 ・ Mondo | H11〜H18 | ☐ | |
| P04 | Home の 下 | L01〜L11 | ☐ | |
| P05 | 撮る(タグ ・ 撮影 ・ 現像) | C01〜C11 | ☐ | |
| P06 | Lattag yesterday | Y01〜Y06 | ☐ | |
| P07 | Friends ・ Profile ・ ME | F01〜F10 | ☐ | |
| P08 | Trip | T01〜T09 | ☐ | |
| P09 | データ ・ 仕上げ ・ 全画面の 確認 | 全76 | ☐ | |

## 画面ごとの ずれ(compare.py の score。0 = 同じ。目安 8 以下)

| ID | score | 日付 | メモ |
|---|---|---|---|

| P15 | v71 レンズ ・ 表記 ・ かぎ | ☐ | H01 H03 H06 L09 F02 |

## 2026-11-17 土台(新しい 見本 v68〜v71 に 対する 今の v64 実装の 点数・M0)

最低 iOS 18 に 下げた あと(M0a/M0b)。H は うしろが 全面の 写真に 変わる ので 20〜46 に 戻る のは 予定どおり。Y01〜Y05 も 新しい 見本が 暗い 画面に なって いて 大きい(Y05 の 見本は まだ キャラクターが 残って いる:P12〜P15 の 対象外 → 要 確認)。

| ID | score |
|---|---|
| H01_home | 26.0 |
| H02_home_hint | 46.7 |
| H03_home_press | 26.1 |
| H04_home_1shot | 27.2 |
| H05_home_2shot | 26.5 |
| H06_home_3shot | 28.6 |
| H07_home_friends | 30.6 |
| H08_home_firstday | 30.6 |
| H09_home_night | 26.8 |
| H10_live_panel | 16.4 |
| H11_page_friends | 21.5 |
| H12_page_friends_filled | 21.1 |
| H13_page_trip | 21.4 |
| H14_page_mondo_locked | 26.4 |
| H15_page_mondo_open | 26.7 |
| H16_page_yesterday | 22.6 |
| H17_page_yesterday_open | 22.5 |
| H18_page_yesterday_firstday | 29.4 |
| L01_today | 7.2 |
| L02_active | 6.9 |
| L03_yesterday | 10.0 |
| L04_yesterday_open | 9.2 |
| L05_mondo_row | 9.4 |
| L06_albums | 7.5 |
| L07_onthisday | 16.9 |
| L08_friends_card_empty | 17.2 |
| L09_friends_card | 21.3 |
| L10_firstday_yesterday | 6.1 |
| L11_develop_view | 12.5 |
| Y01_yesterday_locked | 41.2 |
| Y02_yesterday_open | 41.4 |
| Y03_yesterday_mondo_tab | 53.1 |
| Y04_yesterday_friends_tab | 41.6 |
| Y05_yesterday_scroll | 76.5 |
| Y06_photo_viewer | 1.4 |
| C01_tag | 26.6 |

## 2026-11-17 P12(v68)〜P15(v71):M0〜M1 完了(Home)

- M0:最低 iOS 26 → 18(app / widget / tests)。iOS の 版の 分かれ目は `LGGlass`(`LGGlassMode` `lgScrollEdgeSoft` `lgTabBarMinimize` `LGGlassGroup`)に まとめた。DEBUG `-debugLegacyGlass 1`。Info.plist に `_lattag-shake`。widgets ブランチにも 取りこみ 済み(ビルド 確認)。
- M1a 背景 + ヘッダー(HUD ・ アバターの 輪 ・ まとまる 動き)/ M1b 四すみ 78pt + かぎ(ボタンの overlay)+ ファインダー / M1c 本物の レンズ + しぼり羽根 + シール。
- 点数(新しい 見本 ・ `-debugMock 1`):H01 9.4 / H03 11.9 / H04 10.4 / H06 8.1 / H10 6.9 / H11 6.1 / H12 5.9 / H13 6.8 / H14 7.7 / H15 7.9 / H16 9.5 / H17 9.4 / H18 8.9(土台は 26〜46)。
- のこり(M2 以降):H02 17.4 / H08 13.0 ・ L01〜L09 は うしろが 変わった ぶん 11〜24(M2 の Friends カード = P14 と 下の 区画の 位置あわせで 直す)・ Y01〜Y05。

## 2026-11-17 M2(P14:Home 下の Friends カード)完了

- 友だち あり(ストーリーの 丸 + 申請の 1行)/ だれも いない(横に すべる カード:申請して きた 人 + リンク / QR / ID)。キャラクター ・ Shake ・ 3ボタン ・ チェキの 列は なくした。申請の 承認は `FriendRequests.respond`、つつくは `layerActions.knock`。
- 点数(`-debugMock 1`):L01_today 7.4 | L02_active 7.1 | L03_yesterday 9.3 | L04_yesterday_open 8.9 | L05_mondo_row 7.0 | L06_albums 10.4 | L07_onthisday 10.0 | L08_friends_card_empty 9.9 | L09_friends_card 9.7 | L12_friends_card_noreq 11.1 | L10_firstday_yesterday 6.4 | L11_develop_view 12.5 | 
- 注意:並行して 2本 測定を 回すと 結果が くずれる(シミュレータが 1台)。`snapall.sh` は 1本ずつ。

## 2026-11-17 M3(P12-B:Friends 画面)

- `FriendsV68View`(黒い 一覧)に 置きかえ。`TodayView` の 呼び出し 1か所を `UIFlag.v64` で 切りかえ。今日の 一行 ・ さがす ・ ふる カード(いまは 今ある `ShakeConnectSheet` を ひらく。M4/M5 で 新しい Shake に)・ QR / Link / ID ・ Requests ・ Friends 一覧(撮った 人が 上)・ 下の 一行。人数は どこにも 出さない。
- 「ID で さがす」は 今ある `UserDirectoryService.search` + `FriendRequests.send` を 使う 小さな シート。
- 承認 = `FriendRequests.respond`、つつく = `KnockStore`、チャット = `DirectMessageView`、ブロック / 通報 = `ModerationService` / `ReportSheet`(行を 押す)。**ブロックの しくみは すでに ある**(`ModerationService.blockUser`)→ M5 の Shake 候補から ブロック済みの 人も 外す。
- 見本との ちがい(データが 無い):申請の 人の 写真(申請の レコードに 写真が 無い → 名前の 1文字)・「17:05 に 撮った」の 時刻(いまは「今日 撮った」)。

## 2026-11-17 M4(P12-C:Shake モードの 画面と 動き)

- `ShakeV68View`(状態 idle / seek / found / wait / done / none を うけとって 描く だけ)。輪 4本 + 黄緑の ひろがる 輪 + レーダー ・ 丸の 息 ・ ふるえ ・ 相手の 丸が 落ちて 重なる ・ 白い 光 + 波紋 ・ 黄緑の 線で 囲む。バイブは 状態が かわる とき(sel / buzz + tick×6 / success / click / success→heart / warn)。Reduce Motion ・ 見えない とき ・ 低電力で 止める。DEBUG:`-debugRoute shake -debugShake <状態>`。
- 点数:K01 8.1 / K02 9.4 / K03 6.5 / K04 10.9 / K05 5.1(K06 は Friends の 新しい 行 = F 系)。
- 26 の「2つの 丸が 近づくと ガラスが くっつく」は まだ(M6 で 検討)。実機の ふった 判定 ・ 通信は M5。

## 2026-11-17 M5(P12-D:Shake の 本物の しくみ ・ Cloud Functions なし)

- `ShakeSession`(センサー + 通信)・ `ShakeV68Rules`(純粋な 決まり ・ テスト 8本)・ `ShakeV68Host`(画面と つなぐ)。Friends 画面の「ふって、つながる」が 新しい Shake を ひらく。
- ふった 判定:加速度 50Hz ・ 2.2G を 0.65秒 以内に 2回(山が 下がって から 次を 数える)。
- ちかく:`MultipeerConnectivity`(`lattag-shake`)。広告に 出す のは **1回きりの 乱数 16バイト だけ**。合言葉が 小さい 方だけ 招待。暗号化 必須。ユーザー ID ・ 名前 ・ 小さな 写真は ふって 見つけた あとの 暗号化 通信で だけ。
- **2秒 判定は 端末の 時計を くらべない**:ふったら すぐ 送り、うけとった 側が「自分が ふった 時刻」と「うけとった 時刻」(どちらも 自分の 時計)で 判定。
- 「つながる」= `FriendRequests.send` + 通信で「OK」。両方 OK(60秒 以内)で 完了。**重なった 申請**(自分 → 相手 と 相手 → 自分)は `settleCrossed` で 承認ボタン なしで 成立(Home の 読みこみ時も)。
- 候補に 出さない:ブロック済み(`BlockedUser`)・ 申請を 断った 相手(`declinedByMe`)・ 自分が 取り消した 相手(`ShakeExclusions`)・ もう 友だち(「もう 友だち です」)。10分に 20回まで。ことわられたら「QR で つながる」を 目立たせる。とじたら `stop()` で ぜんぶ 止める。
- 注意:テスト関数名に 数字 + `_` を 入れると Xcode の ビルドシステムが 落ちた(`0_65秒` など)。名前は ひらがな / 漢字だけに した。
- **未確認(実機 2台が 必要)**:ふって つながる / 片方 だけ ふって 相手が 出ないか / とじた あと センサーと 通信が 止まるか / ローカルネットワークの 許可。
- 古い `ShakeConnect` と `_later-bump` は **まだ 消して いない**(実機で 新しい 方が 動いて から)。V64 の Friends 画面は 新しい 方だけ 使う ので 同時には さがさない。

## 2026-11-17 M6(仕上げ)・ P12〜P15 の まとめ

- 全 471 テスト 成功 ・ Release ビルド 成功 ・ Home アイドル CPU 約 13%(`PERF.md`)。
- 点数(新しい 見本・`-debugMock 1`):

| ID | score |
|---|---|
| H01_home | 9.3 |
| H02_home_hint | 16.4 |
| H03_home_press | 10.9 |
| H04_home_1shot | 9.5 |
| H05_home_2shot | 9.4 |
| H06_home_3shot | 7.3 |
| H07_home_friends | 9.1 |
| H08_home_firstday | 12.6 |
| H09_home_night | 9.2 |
| H10_live_panel | 6.2 |
| H11_page_friends | 5.0 |
| H12_page_friends_filled | 5.0 |
| H13_page_trip | 6.0 |
| H14_page_mondo_locked | 6.3 |
| H15_page_mondo_open | 6.0 |
| H16_page_yesterday | 8.6 |
| H17_page_yesterday_open | 8.4 |
| H18_page_yesterday_firstday | 8.0 |
| L01_today | 7.4 |
| L02_active | 7.1 |
| L03_yesterday | 9.3 |
| L04_yesterday_open | 8.8 |
| L05_mondo_row | 7.1 |
| L06_albums | 10.4 |
| L07_onthisday | 10.1 |
| L08_friends_card_empty | 9.9 |
| L09_friends_card | 9.7 |
| L12_friends_card_noreq | 11.1 |
| L10_firstday_yesterday | 6.4 |
| L11_develop_view | 12.5 |
| Y01_yesterday_locked | 41.2 |
| Y02_yesterday_open | 41.4 |
| Y03_yesterday_mondo_tab | 53.1 |
| Y04_yesterday_friends_tab | 41.6 |
| Y05_yesterday_scroll | 76.5 |
| Y06_photo_viewer | 1.4 |
| C01_tag | 26.7 |
| F01_friend_empty | 9.8 |
| F02_friend_list | 12.4 |
| F03_friend_requests | 13.0 |
| K01_shake_idle | 8.1 |
| K02_shake_seek | 7.1 |
| K03_shake_found | 6.5 |
| K04_shake_wait | 10.9 |
| K05_shake_done | 5.1 |

- 8 以下:H06 H10〜H15 H18 L01 L02 L05 L10 K02 K03 K05 Y06。
- **のこり(大きい)**:Y01〜Y05(Lattag yesterday)は 新しい 見本が 暗い 画面 + 新しい ヘッダーに 変わった ため 41〜76。`YesterdayV64View`(白い ページ)を 作りなおす 必要が ある(P12〜P15 の 対象外 → 決めて から)。Y05 の 見本に キャラクターが 残って いる。
- **のこり(小さい)**:H02 16.4 / H08 12.6 / L06〜L12 10〜12 / F02 12.4 / F03 13.0 / K04 10.9 / L11 12.5 / C01 26.7(見本の キーボードは HTML 描画)。
- **実機で 確認**:Shake(2台)・ ヘッダーが まとまる 動き ・ 四すみの 入場 ・ レンズの しぼり ・ SE(幅 375)。

## 2026-11-18 P28(v85)Shake を なくした ✓

- 消した:`ShakeV68View` `ShakeSession` `ShakeV68Rules` `ShakeV68Tests`、旧 `ShakeConnect` `ShakeRules` `ShakeConnectSheet`(`FriendsHub`)、旧 Home の `V17Bump`、Friends の ふる カード、Add / 旧 Friends の `Shake` タイル、はじめての 設定の `ふって つながる`、DEBUG の `shake` ルート、`snapall` の K01〜K05。
- Info.plist:`NSBonjourServices`(`_later-bump` `_lattag-shake`)と `NSLocalNetworkUsageDescription` を 消した(ほかに ローカルネットワークを 使う 所は ない。`InfoPlist.xcstrings` と `LocalizationTests` も そろえた)。
- Friends:`QR を 見せる`(黄緑)/ `QR を 読む` の 2枚(0人 = たてに 大きく 150、いる 時 = 横に 142)+ `Link` `ID` の 2つ。F01 11.5 ・ F02 8.5 ・ F03 9.7。背景の 写真が 画面より 広がって いた ずれも 直した。
- `QR を 見せる` は プロフィールの チェキを 裏返す 画面が できる まで、自分の QR の シートで 見せる(のこり:P25/P29 で つなぐ)。
- のこり:Add friends(F06)の `QR ・ Link ・ Scan` 3つ(F06 を 作る とき)。

## 2026-11-18 P16(v72)アイコン ・ 起動画面 ・ オープニング B ✓

- アイコン:`AppIcon` = 黄緑の # + レンズ(`7_lime_lens`)。起動画面:`LaunchInk`(#0B0C0D)+ `LaunchIcon`(光 込み 240pt)。
- オープニング B:`Today/V64/OpeningV72View.swift`(時間は モックの ミリ秒どおり)。アプリの いちばん 上(`RootView`)で 起動した とき だけ 流す。0.6秒 たったら タップで とばせる。はじめての 設定の 人は 丸い 開きの かわりに フェード。設定「短く」= 0.33秒 → すぐ ひらく。視差を 減らす = 最後の 組みを 見せて フェード。古い チェキの オープニング(`OpeningV21View`)は 消した(`OpeningEase` `OpeningStyle` は オンボーディングが 使う ので 残す)。
- 点数(`O0x_opening_v72_*`):0ms 2.2 ・ 700ms 2.7 ・ 1200ms 3.2 ・ 1650ms 3.1(2500ms は 下に Home が ない デバッグ画面 なので 比べない)。
- のこり:Home の 1.06倍 → 1 の 入りは 未(Home は 下で 作って ある)。実機の チラつきは ユーザーの 確認。


## 2026-11-18 v82 キット(P16〜P29)の 作業 まとめ

| 段階 | 中身 | 状態 | 点数(目安 8 以下)・メモ |
|---|---|---|---|
| P16 | アイコン ・ 起動画面 ・ オープニング B | ✓ | O0x 2.2〜3.2。実機の チラつきは ユーザー確認 |
| P17 | レンズの まんなか = 黄緑の シャッター ・ テーマ色 | ✓ | H01 3.8 H03 4.7 |
| P18 | Home の 地 = 単色(黒) | ✓ | H01〜H19 ≤ 6.4(H02 6.0 H10 6.3 H14 6.4) |
| P19 | ME の 縦線 | ✓(P29 に 含む) | F10 17.5 |
| P20 | yesterday(Friends = BeReal 型 ・ 標準 TabView) | ✓ | Y01 6.7 Y02 6.3 Y04 10.6 |
| P21 | Friends の タグ ・ Mondo の 地球儀 | ✓ | Y10 5.3 |
| P22 | Home = 大きな # ・ yesterday の 上の 帯 ・ 通知 ・ あなたの きのう ・ Mondo ランキング | ✓ | H01 3.8 Y14 8.3 Y15 3.9 Y12 8.4 |
| P23 | ダブルタップ ・ 時間の カプセル ・ 大きな 地球 ・ ない 日 | ✓ | Y08 6.7 Y03 6.1 |
| P24 | スクロールで 小さく | ✓ | H19 5.4 Y05 6.6 |
| P25 | アイコン(プロフィール写真)・ えらぶ シート | ○ | `IconPickerV81Sheet`(プロフィールの チェキの「写真」から)。はじめての 設定(O07)の 丸は 未 |
| P26 | Mondo の 地球 = 字なし | ✓ | Y10 |
| P27 | Trip = 1問ずつ ・ ホーム | ✓ | T01 4.2 T02 6.0 T10 5.3 T11 10.4 T03 10.1 T12 14.1 T13 13.3 |
| P28 | Shake を なくす ・ QR で つながる | ✓ | F01 11.4 F02 8.6 F03 9.7。Add friends(F06)は `QR / Link / Scan` の 3つ |
| P29 | ME = Recap | ○ | F14 4.6 F15 2.9 F09 14.6 F10 17.5 F13 19.5 F16 17 F17 12.9(見本の 写真と 並びが ちがう 分)。しくみ + テストは ✓。BG タスクは 未(前に 来た 時に 作るのが 本命) |

- のこり(作って いない):T04〜T09(Trip ページの 横カード ・ パス あとから ・ 設定 ・ 部屋 ・ 招待 ・ Active カード)の 新デザイン化 / O07 の アイコン丸 / F05・F07・F08・F11 の 見た目 あわせ / BGAppRefreshTask(Recap)。
- 要 ユーザー確認:実機の 重さ(Instruments) ・ オープニングの チラつき ・ Recap の 動画保存 ・ 月曜 9:00 の 通知。

## 2026-11-18 最終の 全画面 再測定(v82 キット ・ Debug ビルド ・ `-debugMock 1`)

| 区分 | score |
|---|---|
| H01〜H19 | 4.0 / 6.1 / 4.7 / 3.3 / 3.3 / 3.6 / 3.3 / 3.3 / 3.3 / 6.4 / 3.9 / 3.7 / 4.6 / 5.8 / 5.5 / 4.1 / 4.1 / 2.8 / 5.5 |
| L01〜L12 | 6.7 / 6.5 / 8.6 / 8.2 / 7.4 / 10.1 / 9.8 / 9.7 / 9.4 / 5.9(L10)/ 11.3(L11)/ 10.8(L12) |
| Y01〜Y15 | Y01 6.8 Y02 6.4 Y03 6.3 Y04 10.7 Y05 6.8 Y06 1.5 Y08 6.8 Y10 5.7 Y12 8.6 Y14 8.4 Y15 4.0 |
| T | T01 4.3 T02 6.1 T10 5.5 T11 10.5 T03 10.2 T12 14.0 T13 13.3 |
| F(ME) | F09 14.7 F18 14.2 F10 17.6 F13 12.7 F14 4.8 F15 3.0 F16 16.8 F17 13.0 |
| F(Friends) | F01 11.4 F02 8.6 F03 9.7 |
| O(はじめての 設定) | O03 13.8 O04 5.4 O07 17.5(キーボードが 出る 状態)O08 4.1 O09 5.5 O10 3.8 O11 3.1 |
| C01 | 23.2(見本の キーボードは HTML の 絵) |

- 8 より 大きい もの:L06〜L12 ・ Y04 ・ T11〜T13 ・ ME(F09 F10 F13 F16 F17 F18)・ F01 ・ F03 ・ O03 ・ O07 ・ C01。ME は 見本の 写真の 並びと 私の 見本データが ちがう 分が 大きい。
- 作った 追加:Recap の BGAppRefreshTask(`app.lattag.recap`)・ Home 下の Active に 本物の Trip(押すと Trip の ホーム)・ Trip の ホームの QR から パス・ はじめての 設定の アイコンの 丸(O07)。
- のこり:T04〜T09 の 横カード ・ 設定 ・ 部屋 ・ 招待 の 新デザイン化(今ある 画面の まま 動く)/ F05 F07 F08 F12 の 見た目あわせ / 実機の Instruments。
- Release の 待機 CPU は 今回 測り なおして いない(Release は ログイン まえの 画面に なる ため。DEBUG の Home は ぼかし写真の 背景を なくした 分 かなり 軽い はず)。実機の 数字は ユーザー確認。

## 2026-11-18 T04 ・ T09(Trip の ページ ・ Active の カード)✓

- Trip ページ(`HVTripPage`):表紙の 写真 + TRIP ・ DAY + QR / ··· + 名前 + 今日の こま数 + 23こまの フィルム + `Shoot for trip` + チャット。T04 6.9。
- Home 下の Active(`HVActiveRow`):表紙 + DAY + 赤い 数 + 名前 + フィルム + こま数。押すと Trip の ホーム。T09 10.3。
- のこり:T05(パス あとから)は Trip の ホームの QR から 開く 形で つないだ(見た目は T03 と 同じ パス)。T06 設定 ・ T07 部屋 ・ T08 招待 は 今ある 画面の まま 動く。F05 F07 F08 F12 の 見た目あわせは まだ。

## 2026-11-18 F05 ・ F07 ・ F08 ・ F12 ✓

- F08/F12 プロフィール:`ProfileV82View`(背景 = 写真を ぼかした 緑 → 紫 → 黒 ・ チェキ + タグの シール + 名前 + 数字 + QR / Edit / Share / Scan)。Profile の 枠(`MainNavigationView`)に つないだ。☀ と「ME ・ 7 DAYS」から 今までの `ProfileShelfView`(設定 ・ 編集 ・ 通報 ・ 削除)を ひらく。F08 12.9 ・ F12 13.4。
- F07 チャット:明るい ベージュの 地 ・ 2人の 丸 + 7日の 点 ・ きのうの カード ・ 吹き出し(`DirectMessageView`)。8.7。
- F05 友だちの カード:`FriendCardV82Sheet`(Friends の 行を 押す)。Chat / つつく / Trip / more。14.1。
- のこり:T06 設定 ・ T07 部屋 ・ T08 招待 の 新デザイン化(今ある 画面の まま 動く)。

## 2026-11-18 P30(v87)
- B ✓ Home/きのう(アバター 52 + 2回タップ切替・TODAY 字なし・Friends 初回状態 Y19–Y22)
- C ✓ プロフィール = 1本の ScrollView(F08 11.1 / F19 7.9)+ 設定シート(F20 7.8)。ログアウト・アカウント削除(既存 AccountDeletionService)・Recap 通知スイッチ
- A ◐ 撮影画面:黄緑テーマ・`today` 字を削除・右ボタン = 内/外カメラ切替(BACK/FRONT・0.44s・ダブルタップ・内カメ時は画面フラッシュ+鏡像保存)・「<」= タグ画面へ。ビルド/テスト(468)OK。
  ※ Camera/ の 5ファイルは 作業前から 未コミットの 変更が あったため、混ぜない よう **コミットして いない**。

## 2026-11-18 v89(D・E)
- D ✓ 音楽シート(黒・おすすめ/最近/ライブラリ・行を押すと流れる・決めたあと流れる・チップ 1回=止/流・長押し=えらびなおす・撮影画面で 45%・Home/撮影後でフェード停止)。MusicKit の実データは 実機のみ確認可。
- E ◐ 撮った あとの 現像:`ReleaseRevealV89View`(しぼり 7枚 → 光から 現像 → シール/時刻 → 2ボタン・全画面ズーム・公開/自分だけの飛び方)。モザイクは 使わない。RARE は データに 無いため 未対応。

## 2026-11-18 v90(Trip を つくる)
- パス(搭乗券 148・半券・切りとり線・No.・FROM/TO 曜日・DAYS・めくれる名前)、4本の線、題(黒 30)、流れる候補 2列(長押しで停止・タップで パスへ とぶ)、日数の つまみ、4列の丸、表紙の 横スナップ + まとめ。見本 T01/T14/T02/T10/T11 の 新しい 画像は まだ 取りこんで いない(古い 見本との 差は 参考値)。

## 2026-11-18 v91・v92
- v91 ✓ オープニング L(黒・1.47秒)。
- v92 ✓ 自分の QR = チェキ + # の 形(`SelfQRChekiV92View` / `StyledQR`)。点・緑の # ・目=レンズ・まんなかアイコン・誤り訂正 H。デコードは Unit テスト(シミュレータは Vision が 動かない ため CIDetector)。コピー/LINE/メッセージ/保存/その他。入口 = プロフィール QR ・ Friends の QR を 見せる。実機の カメラで 読めるかは ユーザー確認。

## 2026-11-18 v93
- 1 ✓ ライブ パネル:ライム化 + オドメーター(開く時 0 → 値・毎秒 ころがる・:点滅・今の丸ドクッ・1分で光・バー走る光)。`develop` ボタン/`DEV` は 今の パネルに 無い ため 未対応。
- 2 ✓ Yesterday ページ削除(4ページ ・ 目次 3つ + Camera ・ `/ 03`)。H16〜H18 を snapall から 外した。
- 3 ◐ 現像画面:`DevelopV64View` 作りなおし(VStack ・ 横めくり ・ 7層の 窓 ・ Animatable の d 1本 ・ CHHapticEngine 1パターン ・ 自動再生なし)。実機の Hangs / 120fps は 未計測。

## 2026-11-18 v94
- A ✓ 撮影ボタン = アイコン(`ShutterIconV94`)・ 長押しの 目盛り 24 → クリック 6ごと(4段)。CaptureScreenV21 の 変更は 未コミット(元から 未コミットの 変更あり)。
- B ◐ ID:`HandleRules`(テスト)・ `HandleService`(**CloudKit Public DB `UserHandle` で 予約**。仕様の Firebase / Cloud Functions は この アプリに 無い ため 置きかえ)・ はじめての 設定に ID 1ページ ・ ID を かえる シート(設定 / Friends)・ ID の 無い 人に 強制シート。CloudKit の 本番 スキーマ(`UserHandle` / `UserDirectory.nameSearch` `discoverableByName`)の デプロイは ユーザー作業。
- C ◐ Friends = さがす 画面(検索欄 ・ 自分の ID カード ・ 3つの 道 ・ 結果 ・ プライバシー設定)。おすすめ(共通の 友だち / 連絡先)と `searchUsers` の 回数制限は 未実装(サーバー必要)。
- D ✓ QR を 読む = Lattag カメラ(カード ・ 申請 ・ 写真から ・ Lattag 以外は 断る)。
- E ◐ Friends タブ はじめての日:見本の 投稿(SAMPLE)+ さがす 入口。おすすめの 横スクロールは 未実装。

## v95(実機を 見て 直す 11こ)
- ✓ 1 はじめての 設定:Name / ID を 打つ 間 チェキ 0.52倍(上 92)・ アイコン行 / 説明 / 文字数を かくす・ 入力欄は 題の すぐ 下・ つぎへは キーボードの 10pt 上(`editing`)
- ✓ 2 タグの シール:`#` つき ・ 3つの 席(左上 / 右 / 左下)
- ✓ 3 招待:3つの 道(リンク貼りつけ / Trip の 合言葉 / 友だちの @ID)。Trip コードは 既存の 合言葉(CloudKit)で。6マス入力 / `joinTripByCode` は 作って いない(Firebase 版では ないため)
- ✓ 4 はじめての 説明 5ステップ(`HomeTourV95.swift`)・ 設定 › 「はじめての 説明を もう1回」
- ✓ 5 QR カメラ:わく 上 206 / 282 ・ 下に ヒント + 3ボタン(写真から / 自分の QR / @ID)。※ シミュレータは カメラなしで 未確認
- ✓ 6 Trip ④「写真を 設定」:ライブラリ(PhotosPicker)・ 最近の 8枚(許可 ある 時)・ ドラッグ / ピンチ → 3:4 切りぬき
- ✓ 7 Home Friends ページ:0人 = 軌道 + おすすめ 3 ・ 4ボタン / あり = 3分割の 輪 + 数字 3つ + 申請
- ✓ 8 NEXT カプセル(`HomeNextV95.swift`)・ 5.2秒で つぎへ ・ 横に はらう
- ✓ 9 Home 下の Friends カード:今日の フィルムの 下へ ・ 4ボタンは 別々の 行き先(共有シート / 自分の QR / QR カメラ / さがす + フォーカス)
- ✓ 10 Mondo:Explore が Mondo タブを ひらく ・ ない 日を「次の 9:00 を 待つ 画面」に(`MondoWaitV95.swift`)
- ✓ 11 Friends タブ(はじめての 日)に ストーリーの 列

## P39 ・ v96 ウィジェット
- ✓ A 土台:App Group は 今の `group.com.tatsukikitagawa.laternew2`(ID は 変えない)に `WidgetSnapshot.json` + `w/`(サムネ 300px ・ ぼかし ・ アイコン 120px)。書く = `WidgetSnapshotWriter`(`TodayView.syncWidget` ・ 写真の 同期 ・ 撮影)/ 読む = `WidgetModel.make`(9:00 を またぐと 今日 → きのう、こまは FilmCounter の App Group 値が 先)。写真の ルール:きのうの 本物は 自分が 今日 撮った 時 だけ 書く ・ ロック中は mosaicTiny を もう1回 ぼかした 物 だけ(使わない 画像は 毎回 消す)。予約 = 今 ・ 21:00 ・ 24:00 ・ 9:00。書体:ラテン系 9本を 拡張に 同梱、和文 2本(8MB)は App Group へ コピーして 拡張で 登録。行き先 `lattag://shoot|develop|friends|yesterday?f=|mondo|trip/<id>`(`WidgetRouteStore` → `HomeV64Host`)。コントロール 2つは 新しい 行き先へ。サーバーは 使わない(CloudKit のみ ・ 9:00 は タイムラインで 切りかえ)。
- ✓ B 小 4種(S1 レンズ ・ S2 9:00 まで ・ S3 友だちの 1枚 ・ S4 Mondo)+ ロック 4種(`LattagWidgetsSmall/Lock/Parts.swift`)。見た目は アプリの DEBUG ルート `widgets`(`-debugWShots N -debugWHour H -debugWPart small|mid|lock`)で 同じ View を 並べて 確認(拡張は シミュレータで ホームに 置けないため)。S1 の 字の 輪は ウィジェットでは 回らない(静止)・ S2 の 残りは 秒まで 動く 時計(h:mm だけには できない)
- ✓ C 中 ・ 大(M1 Friends + `つつく` / M2 きのう / M3 Trip / L1 ボード)。`つつく` = `PokeFriendIntent` → `Shared/KnockSender.swift`(アプリの KnockStore と 同じ 書き方で CloudKit に ノック)。拡張に iCloud(CloudKit)の entitlement を 追加 → **実機は 署名の 更新が 必要**。失敗しても `lattag://friends` には 飛ばない(AppIntent の 型の 制約)
- ✓ D 設定 › ウィジェット(3ステップ + 見本)・ はじめての 説明の さいごに 1回(`WidgetGuideV96.swift`)

## P40 ・ v97 ライブ アクティビティ
- ✓ A 形:`Shared/LattagLiveAttributes.swift`(Attributes ・ Phase ・ `OpenCameraIntent` ・ `LattagLiveClock`)・ `LaterWidget/LattagLiveViews.swift`(フィルム / ラストコール / 朝の 部 + Dynamic Island 小 ・ 最小 ・ ひらく)。古い(P10)ライブ アクティビティは バンドルから 外し、既存の 物は 終了。見た目は DEBUG ルート `live` で 確認(島は シミュレータで 未確認)
- ✓ B 始め方 ・ 終わり方:`App/Services/LattagLiveManager.swift`(前面で 23:00 start → 23:50 ラストコール → 3枚 / 24:00 で end(+30分 / +1時間)・ 8:30 朝の 部)・ push-to-start トークンを 控える ・ 設定 › 通知に 夜 / 朝の オン オフ ・ 「撮る」ボタン = `OpenCameraIntent`(App Group の 旗 → 撮影)。`LattagLiveTests`(時間割)
- ✓ C サーバー:`server/live-activity/`(Cloud Functions + APNs の ひな形 と README)。**未配備**。アプリに Firestore が 無く トークンを 送る 部分は 未実装

## v98(実機を 見て 直す 5こ)
- ① Trip パス:`TripPassV98.swift`(表紙は clipped ・ 印刷の 動き M39 ・ ISSUED はんこ ・ 写真に 保存 = ImageRenderer + addOnly)。QR = `https://lattag.app/t/<key>` ・ まんなか = 表紙 ・ Unit テストで 読める ことを 確認。`/t/<key>` は アプリ側(onOpenURL ・ QR 読み取り)で KEY から 入る。サーバー(invite-web の OGP)は 未作成。
- ② Trip チャット(空)= `TripBoardingView`(座席表 ・ 送ると こう 見える ・ 招待リンク)。③ メンバーの シート = `GroupSheet` を シンプルに(合言葉 ・ 「預けました」 ・ オレンジ 削除)。
- ④ 古い `FriendsHubView` を 削除。チャットの 友だち招待 = v94 の さがす 画面。
- ⑤ キャプション:撮ったら タグ ・ 音楽を 空に(`LastShotCaption`)+ 「↺ さっきと 同じ」カプセル。

## P42 ・ v99(はじめての 説明:Friends ・ Trip ・ Mondo)
- A 土台:`IntroStoryV99.swift`(進み具合 ・ 題字 ・ 1行 ・ タップ / 長押し / 下スワイプ ・ 最後の ボタン ・ `introSeen.*`)。出す きっかけ = ① Home の ページ 1〜3 に 0.62秒 とどまる(`HomeV64View` onChange)② Friends / New trip の 入口(`TodayView.gateIntro`:5か所)③ ページの `?`(`IntroHelpButton`)。
- B 場面 12こ:`IntroScenesV99.swift`(時間 t の 関数。バイブは `IntroKind.scenes`)。DEBUG:`-debugRoute intro -debugIntroKind friends|trip|mondo -debugIntroAt 秒`。
- C 仕上げ:Reduce Motion(最後の 形で 止める ・ 題字なし)・ VoiceOver(場面ごとに 読み上げ + 「つぎへ」「スキップ」)・ 幅は 390 × 844 の 座標を 拡縮 ・ とじた あとの `?` ぷくっ + 初回 トースト ・ アカウント削除で 記録を もどす。
- 未:見本 G01〜G14 ・ M40〜M42 は キットに 無く 比べて いない。写真は 色の 絵(見本の 6枚は 未取りこみ)。Instruments の 120fps は 未計測。

## P43 ・ v100(アプリ ぜんたいに バイブ)
- A 土台:`Haptics.Kind` に notch / edge / stretch / knock / sig(計 21)・ 全体 40ms ・ 種類ごとの gap ・ ひかえめ = さわる段を 鳴らさない ・ 背面 / 録画中(`ShutterGesture` が `isMuted`)は 鳴らさない ・ 設定 › 表示 › バイブ(しっかり / ひかえめ / オフ ・ 選ぶと 見本)・ `LGButtonStyle` / `.lgTap()` ・ `HapticsV100Tests`。
- B スクロール:`DesignSystem/ScrollHapticsV100.swift`(`.scrollHaptics()` + `.hapticSection()`)。Home の 下(`HVAnchor`)・ yesterday ・ Friends 一覧 ・ 設定 に 接続。区切り = notch(かぎ付き = knock)・ はじ = edge ・ ひっぱる = stretch ×3 → soft ・ はやい(2400pt/秒 超)は 静か。
- C:横スライドの 半分で sel ・ 地球を 指で まわす(15° notch ・ 慣性 ×0.95 ・ 地球が 優先)・ 「ひらくまで」長押し(pop ・ 1秒 tick ・ 分 click ・ soft)・ 9:00 / 24:00 の 10秒前(`CountdownV100.swift`)・ Lattag の サイン(sig + はずむ)。
- 未:Trip チャット ・ 横の 列(Mondo)の notch ・ 9章(detent ・ 引いて 閉じる ・ ピンチ)・ 名前の ない ボタン 全部への tick ・ オープニングの sig ・ パターンの 使いまわし。


## v102 規約 ・ プライバシーの つなぎ
- ✓ `LegalLink`(URL 1か所)+ `SFSafariViewController`(ライム / `#1C1C1E`・soft / tick)。
- ✓ サインイン O04 の 2つ(別々に 開く ・ 44pt ・ isLink)/ 設定 > サポート の 2行。
- 未: 旧 `SettingsMenuView` / `OnboardingFlowView` / `PrivacyPolicyView` / `LaterPromiseView` は 残してある(Profile 側から 到達の 可能性)。実機: 機内モード ・ VoiceOver ・ UI テスト。


## 「つつく」を なくした
- 送る(`KnockStore`)・ ウィジェットの `PokeFriendIntent` / `KnockSender` ・ 全画面の ボタン(Friends / 友だちカード / チャット / Home / 旧 Home)・ NEXT の poke ・ 設定の「ノックを受けとる」を 削除。
- 古い版が 書いた knock レコードは `KnockInbox` が 黙って 捨てる(通知も 出さない)。
- のこした:`knockOff` フィールド(SwiftData / CloudKit の 形を 変えない)・ `Haptics.knock`(スクロールの かぎ用)・ ウィジェットの iCloud 権限 ・ `Localizable.xcstrings` の `notification.poke.*`(ユーザーの 未コミット変更の ため 触らず)。


## P44 ・ v101(Google ・ メールの サインイン / Apple を Firebase に)
- 0 しらべ ✓(報告 済み)。**→ v104 で 使わない(P47 へ)**

## P45 ・ v102(規約 ・ プライバシー)
- ✓ 0 ・ A ・ B(`LegalLink` ・ O04 ・ 設定)。

## P46 ・ v103(友だちまわりを Cloudflare + Firebase 認証へ)
- 0 ✓(決定 済み)。A ☐ A2 ☐ B ☐ C ☐ D ☐ E ☐(P44 の あと)

## P47 ・ v104(Apple だけ ・ Name / ID / 招待シート ・ ウィジェット)
- 0 しらべ ✓。A サインイン ☐(Firebase の Apple 設定 待ち)B O04 ☐ C Name ・ ID ・ 招待シート ✓(`SheetFitsContent` = 中身の 高さ ・ Name は キーボード中も 写真の 行)D ウィジェット ✓(えらぶ → 5場面の 案内 → `WidgetCenter` で 自動たしかめ)。
- 実機: 置けたかの 自動確認 ・ ID / 招待シートの 高さ ・ iPhone SE。旧 `WidgetSetupFlow` は 旧設定 / 旧初回設定 から のみ(のこし)

- v104 B(O04 見た目)✓:見出し「昨日を / 共有する SNS」・ 白い 丸の Apple ボタン(輪 ・ 波紋 ・ 待つ 間 ・ 入れた 光)・「メールは かくす」(`requestedScopes = [] / [.email]`)・ Google / メールの ボタンを O04 から 外した(コードは A で 消す)。

## P48? ・ v105(友だちの カード ・ オープニング S ・ 使いかた)
- ✓ 友だちの カード(うく カード ・ 背景 1枚 ・ チェキは 中 ・ 黒 62% ・ 動き)。**つつくは 作らない**(2026/11/19 に 機能ごと なくした ため。v105 の 表に ある「つつく」ボタンは 外した)。`@id` ・ since ・ 共通の 友だち は データが 無いので 出さない。
- ✓ 設定 > サポート:「はじめての 説明を もう1回」「ウィジェット」を 消し、使いかた(ぜんぶ 見る + 4行)に。
- ✓ オープニング S(約 2.1秒 ・ 時間割りは `OP72`)。v91 の L は 消した。光 ・ 輪 ・ うしろの 光は `OPImages`(起動時に 1回 作る 画像)。
- 実機: ヒッチ 0(Instruments)・ 120Hz ・ Slow Animations で `M32_opening_v94_strong.png` と 見くらべ ・ 通知から 開いた 時の 220ms ジャンプ。

## v106(はじめての設定 ・ Friends ・ Trip)
- ✓ §7-2 DEBUG「データの 量」(DebugDataVolume)/ ✓ §1 完了は ながおしの あと だけ(`onboardedAt`・おかえりは 公開DBの onboardedAt か 古い記録)/ ✓ §2 Name / ✓ §3 投稿カード 4状態 + フィルム缶 / ✓ §4-1 招待・設定 / ✓ §4-2 chatLine + 未読 / ✓ §5 設定 1枚
- 未: §6 ぬける/おわる の 長押し ・ やぶれる 演出 ・ Home の カード 消え(いまは 今までの 確認 + 演出)/ §5 の 日にち ・ メンバーの ✕(データが ない)/ §7-1 起動の 軽量化 ・ サムネ キャッシュ(数字を 見てから)
| P50 | v107 質感(A 写真 / B 送る ・ 見せる / C 動画 / D はかる)| ☐ ☐ ☐ ☐ | 手順 0 報告まで |
| P51 | Xcode 27 切りかえ(期限 2027年4月 ・ 目安 1〜2日)| ☐ | P50 の あと。Firebase 12 系 / AppDelegate の コメント直し / import SwiftData 2件 / UIScreen.main 置きかえ / 警告の 整理 |
| P52 | v108 相互フォロー ・ お知らせ ・ リンク | △ | 下の v108 を 見る |
| P54 | v110(A Mondo ・ タブ / B ポップの 部品 / C Friends / D Trip / E ほかの 画面)| ✓ ✓ ✓ ✓ ✓ | A 済み(Mondo 削除 ・ Friends｜Trip タブ ・ 入れ物の TripHubView)/ B 済み(Pop/:色 ・ Sticker ・ Tag ・ Tape ・ ChekiFrame ・ PopButton ・ PopPressStyle ・ DEBUG プレビュー `lattag://debug/pop`)/ C 済み(Friends:今日の あなた ・ 友だちの 列 ・ チェキ フィード ・ まだ の 人 ・ さいご)/ D 済み(Trip:LaterGroup に tripStart ・ tripEnd ・ tripColor / TripHubView 1つ / 週の 帯 ・ いま ・ これから ・ おわった ・ 0件)。CloudKit Production は 未 Deploy / E 済み(お知らせ ・ 友だちの カード ・ Trip の 設定に PopButton ・ ピンクの 数の 丸 ・ 色の 4つの 丸) |

## v107 P50
- ✓ A 写真:`FilmLook.chekiJPEG`(撮った 時に 1回 ・ 1440px ・ LUT ・ にじみ ・ ビネット ・ 粒子 ・ EXIF なし)・ `filmVersion = 2`(LaterPhoto ・ CKRecord `filmVersion` ・ PendingShot)・ 解禁の 直前に もう 焼かない(filmVersion が ない 写真だけ 旧 FilmEmulation を 1回 → `filmVersion = 1`)・ 古い 写真への 遡り 焼きこみは やめた。LUT の 色見本テスト(±3)。
- 移行の 処理(`ChekiColorGrade.bakeIntoImageData` の 旧 FilmEmulation 分)は 2026-11-27 以降に 消す(P50 B)。
- ✓ B(外共有の 白い 枠 `InstaxShareFrame` + テスト ・ 遡り 焼きこみを 削除。**表示時の フィルターは もともと 写真に かけて いない**ので 削る もの なし)
- △ C 動画(撮る 設定は 動画モードの 間だけ HDR オフ ・ sRGB ・ .standard を `setVideoLook` で 入れ、写真モードで もどす ・ 粒子 0.15 ・ 2こまに 1回 ・ 10秒 約 4.4MB)。以前の メモ:書き出しを `FilmLook.retro8Frame`(LUT + シャープ + 動く 粒子)に 置きかえ ・ `filmVersion = 2`。1080p 6Mbps は 10秒 約 9MB(前 1.45MB の 約 6倍)→ 規則どおり 720p30 3.5Mbps(約 4.7MB ・ 約 3.2倍)。撮る 設定(1080p30 ・ HDR オフ ・ sRGB ・ H.264)は **写真と 同じ セッション(.photo)の ため 未実施**(確認待ち)
- △ D はかる(シミュレータ ・ 12MP):写真 1枚 約 110ms ・ メモリの 山 +約 49MB(読む 時に 1440px へ 縮めて 234MB → 49MB)・ 大きさ 約 0.12〜0.36MB ・ 動画 10秒 書き出し 約 6.6秒 / 約 4.7MB(前 1.45MB)。**実機の ms ・ ヒッチ(Instruments)は 実機で**

## v108 P52(相互フォロー ・ お知らせ ・ リンク)
- ✓ つなぎ(Worker が できるまで・「v108 つなぎ」で 検索して 消す):おたがいの 申請は 承認 なしで 相互(`FriendRequests.acceptCrossed`)/ 公開DB の CKQuerySubscription 2つ(申請が とどいた ・ 承認された。文に 名前なし ・ `shouldSendContentAvailable`)→ 裏で `syncAccepted`(`FriendRequestBridgeV108`)。
- ✓ §2 Home の 上(まんなかに Lattag ・ 左に ベル + 数 ・ 右に アイコン)/ ✓ §3 お知らせ(`InboxV108View`:友だち申請 + Trip の 招待 ・ これまで 30日 ・ 承認の 動き)。データは 今の CloudKit。
- ✓ §5 `AppLinks`(ドメイン ・ ストア)・ `/u/<ID>` カード(`FriendLinkSheetV108`)・ `/t/<トークン>` は 今ある KEY 参加へ ・ 友だちの 送る 文 ・ `hosting/` を `server/invite-web` に 合わせた(deploy は あなた)。
- ☐ Worker(`server/social-worker` ・ D1)・ APNs ・ Trip の 送る 文(トークンは Worker 後)・ 貼りつけ画面の `/u` `/t` ・ Home の NEXT の 申請の 行の 見た目の 差。
- ✓ Worker `server/social-worker`(`later-social.later-social.workers.dev`・ D1 `later-social`)deploy 済み。申請 1日 50件 ・ CloudKit の 友だち 1回 移行(両方が 申し出た 組 だけ)。
- ✓ P47 A:Apple → Firebase(nonce)・ 「Apple で つなぎなおす」(出して から 24時間 は 出さない)・ Google / メールの リンクの コードを 消した。
- △ (2) つなぎかえ:`SocialClient` + `SocialFlag.useWorker`(**既定 オフ**・ DEBUG 状態メニューで 切りかえ)。実機確認の あと 有効に する。有効に したら「v108 つなぎ」(`FriendRequestBridgeV108`)を 消す。APNs の キー(.p8)は あなたの 作業。

## v111 P55(B・C4・D・E)
- ✓ B 1 プロフィール:チェキの 下の 大きな 名前を 消し、チェキを 大きく(余白 18 ・ 最大 340 ・ 写真 1:1 ・ 下 74 ・ 名前 46 ・ -2.5° ・ ライムの テープ 96×26 ・ タグは 白い ふちの ステッカー ・「写真」ボタン)。上の 小さな 名前(:104)は のこす。
- ✓ B 2 共有の アイコン:`LattagShareItem` + `AppIconShare`(Assets)。`ShareLinkItemSource` ・ `GroupInviteItemSource` ・ `ProfileShareItem` ・ 素の String の 道は 消した。
- ✓ B 3 リンクの 文:最後の 行を 消した(友だち ・ Trip)。
- ✓ C 4 Trip 0件:`TripEmptyV111`(案内板 + パタパタ ・ うすい パス ・ 見出し ・ ボタン 2つ)。
- ✓ D 搭乗ゲート:`BoardingGateV111`(約 3.0秒 ・ スキップ ・ Reduce Motion)。参加が 終わった 時点で 出す。ひらく 先は 今の Trip 画面(P57 で TripRoomView へ)。チャットの「乗りました」は P57。
- ✓ E お知らせ:AppDelegate の 起動ごとの 許可を やめた / `NotifAskSheetV111`(はじめて 友だち申請 ・ Trip の とき ・ あとで = 7日)/ 設定 › お知らせ(`NotifSettingsV111View`:3状態 ・ テスト通知 ・ スイッチ 6つ ・ Worker に 保存)/ 9:00 ・ ラストコールは ローカル通知。
- △ F 相互フォロー:アプリ側は 済み(リモート設定 ・ 部屋の 登録 ・ チャット通知)。Worker の 移行 ・ deploy ・ .p8 ・ 2台の 確認は たつきさん。確認後に v108 の つなぎを 消す。
- △ 10 ぬける:[Leave] ログを 待って います。

## P56(Home の 作りなおし ・ v131 + v122 + v121 + v119 + v118 + v114 + v112)
- ✓ A 字の 形(`f8670e0`):`Typo`(title = Instrument Serif + Later Mincho ・ mincho ・ ui = SF Pro + ヒラギノ の 太字 ・ label)。`Later Mincho` = Noto Serif JP Black を JIS 第1 ・ 第2水準 + かな + アプリで 使う 字 に 切った 物(`Fonts/LaterMincho-Black.otf` 3.0MB ・ 7,003字)。アプリから Inter 4本 ・ Space Mono 2本 ・ Noto Serif JP Bold(8.1MB)を 外した → **約 6.6MB 軽く**。ウィジェットは v96 の まま(Inter ・ Space Mono を 使う)。
- ✓ B Home の 上(`80b8122`):レンズ 1.06倍(331pt ・ 押す 間 1.09)= 撮る ・「タップで 撮る」・ NEXT = 紙の カード(-1.2° ・ テープ = フレームの 色)・ 写真の カード 3枚(9:00 まえ = きのうは 64px で 1回 だけ ぼかし + 鍵 ・ 友だちは アイコン写真 だけ)・ 150pt で 小さな 列。月 ・ 地球(ドーム)・ ドックを 消した。数値は モック v117(中身の 列)を 動かして 測った 値(PROMPT の 1.14 倍 / 454 では なく、動く モックの 1.06 倍 / 538 に 合わせた)。
- ✓ C 横スライドの Friends ページ(`5f40229`):0人 / 申請 あり / 友だち あり の 3つ。
- ✓ D Today ・ Friends ・ Trip の かたまり(`7f065fd`)。
- ✓ E きのう ・ アルバム ・ この日(`1449e9c`):日本語 ・ ライム ・「きのうを ひらく」。使って いない 緑の アバター(にこちゃん)を 消した。
- ✓ F フレーム(`4f439e3`):重ねた `UIWindow`(押せない)・ 7色 ・ 設定 › 表示 › フレームの色 ・ オープニングの あと 0.4秒で 出す。
- ✓ D' Today を v132 3章(暗室の ひも)に 作りなおし:`HVTodayPanel`(HomeV64Lower.swift)。ひも = 2次ベジェ(モック X9S を 幅に あわせて のばす)+ 白い 線 = 9:00 から いま(24時間 ・ % なし)・ チェキ → ライムの 撮る(のこり N)→ 点線 + 数字 を クリップで つるす ・ 9:00 の 札(-4° ・ 3枚で ライム)。撮れない 時間(0:00〜9:00)は 撮る を 出さない。写真は 自分の きょうの 写真を 64px で 1回 だけ ぼかし、9:00 に むけて 不透明度 だけで 浮きでる。動き:35% 見えたら 1回 着地(チェキ ゆれて 止まる ・ 撮る/枠 落ちる ・ 札 ・ 線 のびる)・ 指 = 3D ±12° + 光の すじ(`HVTouchTracker` = UIKit の 認識器。SwiftUI の DragGesture は スクロールを 止めたので 使わない)・ ジャイロ ±6°(見えて いる 間 だけ 30Hz)・ スクロールの ゆれ ±2.2°。Reduce Motion = フェード だけ。v121 の 3枠 ・ ライムの 進みの 線 ・ % は 消した。UI テスト `testScrollFromTodayCheki` 追加(ほかの 3つの 目じるしを YESTERDAY → Today に)。513 テスト 通過。
- 未:横スライドの Yesterday ページ(v131 では カード → きのうの 画面 なので 作って いない)・ iCloud の キー値の 権限(entitlement)が ない(フレームの 色 ・ Recap とも 端末 だけに のこる)・ 実機の ヒッチ ・ 120Hz。

## P57(Trip の 部屋 ・ v129)
- ✓ A 部屋:`TripRoomView`(Today/V64/TripRoomView.swift)= この 1つ だけ。上の バー(もどる ・ DAY の 札 ・ 設定 = 押せる 物 2つ)・ 表紙 330 ・ メンバー + 白い「よぶ」・ きょうの カード(ライム 1つ)・ Film(DAY ごと 4マス ・ きょうは ぼかし + 鍵)・ 下の チャットの バー 1本。200pt で バー 黒 + 名前。古い `TripHomeV83View`(右下の 丸 ・ 浮いた 吹き出し ・ 招待の カプセル)を 消した。チャットの バーは 今は 今の `GroupChatRoomView` を ひらく(B で 新しい チャットに)。
- ✓ B チャットの 見た目と 送る:`TripChatV129View`(Today/V64/TripChatV129.swift)+ きまり `TripChatRules`(TripChatRulesV129.swift)。吹き出し(相手 `#1F1F23` ・ 自分 ライム ・ かたまり ・ 名前は 最初 ・ 丸い 写真は 最後)・ 時間 ・ 既読 N(C で つなぐ)・ DAY の 札 ・ system の 札 ・ 入力(字 200まで ・ 空白だけは 送らない ・ 日本語の 変換中は 送らない)・ よく使う ことば 5つ(字を 打つ 間は かくす)・ ステッカー 8つ(`PopSticker` ・ 古い ハッシュタグ型は そのまま 読める)・ **ひらいた 写真 だけ**(`PhotoDevelop.isDeveloped` と 同じ 1つの 判定 ・ 一覧 + 送る 時の 2重 チェック)。`ChatMessage.Kind.photo` を 足した(CloudKit の kind は STRING なので スキーマ 変更 なし)。通報 / ブロックは 長押しメニュー(今まで どおり)。Trip の チャットは これに つなぎかえ(`GroupChatRoomView` は 個人スペース だけ)。テスト:きょうの 写真は 送れない(8:59 / 9:00 ・ 朝 7時の 写真 ・ 一覧)・ 並べ方(日 札 ・ かたまり ・ system)。DEBUG `-debugRoute tripchat -debugTray photos|stickers`。520 テスト 通過。
- ✓ C データ(アプリ側):`TripReadState`(新しい CloudKit レコード ・ groupRef / userId / lastReadAt ・ 名前 `read_<グループID>_<userId>` で 1人 1つ ・ 親 = グループの レコード)を `Later.ckdb` に 追加。`TripReadStore`(Today/V64/TripReadStore.swift)= 端末の JSON + 共有ゾーンへ 保存(ひらいて いる 間 + 閉じた 時 ・ 1秒に 1回 まで)・ 受信は `CloudKitManager.apply` に 1つ 足した(古い 値で 新しい 値を 上書きしない)。既読 N = 送った 人 以外で lastReadAt が 送った 時刻 以降の 人数。未読 = 自分の lastReadAt より 後の 相手の メッセージ(部屋の 下の バー + Home の Trip)。チャットは 新しい メッセージ ・ ひらいた 時 ・ 閉じた 時に 「ここまで 読んだ」を 進める。テスト 5つ(既読 N ・ 未読 ・ レコード名 ・ 古い 値)。525 テスト 通過。
  - ☐ **たつきさん**:Development で iPhone 2台 を ためす(字 ・ ステッカー ・ 写真 ・ 既読 N)→ CloudKit Console で `TripReadState` を 確かめて **差分を 見てから Production に Deploy**(前の 未 Deploy の 項目と いっしょに)。
- ✓ D 通知(アプリ側):Worker `/v1/push/trip-chat` は 前から ある(`trip_members` 照合 ・ 2分に 1回 ・ 本文「名前:ことば」・ ペイロードに `kind` + `tripId`)ので **Worker は 変えて いない**。アプリ:① ひらいて いる 部屋の 通知は バナーも 音も 出さない(`willPresent` ← `TripChatPushRules.shouldPresentInForeground`)② 通知を タップ → その 部屋を ひらく(`tripId` → `.chatNotificationTapped`)③ 通知が 来たら 裏で 同期 ④ Worker の プッシュが 有効(`useWorker` オン)の 間は 端末の ローカル通知を 出さない(二重に 鳴らさない ・ オフの 間は 今まで どおり ローカル通知)。写真は「写真」・ ステッカーは「ステッカー」と だけ。テスト 3つ。528 テスト 通過。
  - ☐ **実機 2台で 確かめる**:字 ・ よく使う ことば ・ ステッカー ・ ひらいた 写真(きょうの 写真が 一覧に 出ない)・ 既読 N ・ 未読の 数 ・ 通知(部屋を ひらいて いる 間は 鳴らない ・ 閉じたら 鳴る ・ タップで 部屋)。`useWorker` を オンに した 時の 二重通知の 有無。
  - ☐ 未:通知の「相手の 入力中」は 作らない(モック だけ)。`GroupChatRoomView` は 個人スペース 用に のこして いる。

## P58(Trip の 一覧 ・ プロフィール ・ Today の たしかめ ・ v132 + v133)
- ✓ 0 しらべ(v133 の zip も 取りこみ ・ `e12b777`)。
- ✓ A(`fed8869`)**TopBar**(v133 3章 ・ `TopBar.swift`):Home ・ Friends ・ Trip で 1つの 部品(通知 52 ・ 題 SF Pro Black 30 ・ プロフィール 56 ・ 数 = ライム ・ 通知の 数と 写真は 同じ データ)。Home の `HV68Header` の ベル / ロゴ / アバターと、きのうの 画面の 別の バーを 消した。**Trip の 一覧**(v132 1章):週の 帯(箱 なし)→ Boarding(`BoardingPass` ・ `BoardingStack` = 前へ タップ / 前を 押すと 部屋 ・ 立ちあがり ・ Reduce Motion = フェード)→ ひらいた 写真の 行(きょうの 1枚は ぼかし + 鍵 ・ `TripHubRules.openedSummary`)→ 新しい Trip(点線)+ KEY → Album。古い `weekCard` ・ `liveCard` ・ `upcomingRow` ・ 数の 行 ・ ライムの ボタンを 消した。
- ✓ B(`2aa3ed6`)**プロフィール = アーカイブ**(v132 2章):小さな チェキ(-4°)+ 名前(セリフ 40)+ 数字 3つ(日 れんぞく ・ 枚 撮った ・ 日 ひらいた)+ 編集 / 送る(ライム)/ QR / 読む + くっつく タブ(毎日 | Trip)+ ひらいた 日が 3列(きょうの マスは 写真なし ・ 9:00 まえは きのうも 鍵 ・ はじめての 日の 案内)。`ProfileArchiveRules`(ひらいた 日 ・ れんぞく ・ 年月)+ テスト 6つ。日を 押すと その 日の ひらいた 写真(`ProfileDayPhotosView`)・ Trip を 押すと その 部屋。消した:SINCE ・ 数字の 箱 ・ ボタン 4つの 大きな 形 ・ Recap カード ・ 1 YEAR カード(ME への 入口は プロフィールから なくなった)。
- ✓ C **Today v133 1章**:枠 96×124 ・ 高さ 172 ・ 撮る = 白い チェキ(-2°)+ ライムの 丸 48 ・ のこりは クリップ + 番号の 丸 だけ ・ 線 白 42% 2.2pt / 3pt。**Friends の マイカード 1枚**(v133 2章 ・ P56 D の 直し):チェキ 112(-4°)+ 自分 + 読む / さがす + ライムの「リンクを 送る」。カードの 外の「QR を 読む / ID で さがす」と「LINE ・ AirDrop ・ インスタ」を 消した。
- ✓ D たしかめ:390pt シミュレータ(Trip 0 / 3件 ・ プロフィール 0日 / 13日 / 9:00 まえの 鍵 / スクロール ・ Today 1 / 2枚 ・ 夜 8:54 ・ Home の Friends)。537 テスト + UI 4つ 通過。
  - Mondo の 検索:V64 の 画面には 出る 字 なし。のこり = 古い Home(`HomeV5*` ・ `HomeV17*`)・ `MondoModel` / `MondoService` / `EmptyYesterdayView` など データ層 + 古い 画面 → 消す かどうかは たつきさんに 確認。
  - ☐ 実機:ジャイロ ・ 立ちあがり / 前へ 出る 動きの 手ざわり ・ ヒッチ(Instruments)・ 120Hz。

## v134 Phase 1(ブランチ design-v134 ・ 土台)
- Design/v134 に zip を 置いた(文書の v133 は v134 と 読む)。タグ `experiment-p58` = 実験に 使う 状態。
- Barlow Condensed ExtraBold を 同梱(アプリ本体 ・ UIAppFonts)。SpaceMono-Bold も アプリ本体に 登録。
- ライムは `LattagPalette.lime`(Shared)1か所。LaterColor / PopColor / HV / WColor / LTColor は これを 指す。`Color(hex: "C8F25A")` の 直書き ~85か所も 置きかえ。
- 新部品(DesignSystem/):LTTheme(色 ・ 字 ・ 角丸 ・ 動き ・ DisplayTitle ・ DateStamp ・ TagChip ・ LimeButtonStyle)/ LTHaptics(既存 Haptics と HapticRamp の 上の 薄い 層。新しい エンジンは 作らない)/ LTHold(HoldToConfirm ・ FilmDevelop)/ LTHashLens(#レンズ)。ガラスは 既存の `lgGlass`。
- アセット:HashGlyph(Template ・ Preserve Vector)・ LattagWordmark。
- まだ どの画面にも つないで いない(Phase 2 以降)。

## v134 Phase 2(Home)
- 新 Home = `Today/V134/HomeV134View`(Friends | Trip)。Host(`HomeV64Host`)が `YesterdayV64Input` を 作って 渡す。
  - 上:ともだち追加(リクエスト数の ピンクの バッジ)・ ロゴ ・ アバター。
  - あなたのきのう(ぼかし 3枚 + 鍵 ・ ひらいた 写真は ライムの 輪)→ ともだちの丸 → きのう(投稿 ・ 待った時間 ・ 日付スタンプ ・ タグ ・ 返信 = 1対1チャットを ひらく)→ まだひらいていない → 「きのうは、ここまで。」
  - 下:ガラスの タブ + #レンズ + 今日の フィルム(スクロールで タブが 丸に なり、フィルムが 間に 入る)。自前の TabView は 使わない。
  - シート:今日のフィルム / ともだち(リクエスト | ともだち | さがす)。
- ルール(`HomeV134Rules` ・ テストずみ):フィルムの 文言 ・ 夜 ・ カードの 文言 ・ 待った時間(翌朝9:00 − 撮った 時刻)・ 日付。
- Home の Today ページは 使わない(`HomeV64View` は まだ ファイルに 残る = 未使用)。
- 返信:「写真つきで 飛ぶ」は まだ(チャットを ひらくだけ)。#で返す は しない。

## v134 Phase 3(撮る流れ)
- タグ:`Camera/Views/TagScreenV134`(白と黒だけ ・ 開くと キーボード ・ タグは 3つまで ・ 4つ目は warning + ゆれる ・ 候補 2列 ・ 曲 ・ 場所 ・ 白い「撮る」)。`CaptureFlow` は これを 使う(カードが ひろがる 演出は 使わない → 撮影へは フェード)。旧 `TagScreen` は テストと 計測用に 残る(未使用)。
- 撮影:`CaptureScreenV21` の 見た目だけ v134 に(ロゴ ・ ファインダー 左右8 ・ 3:4 ・ 上に もどる / フィルム / フラッシュ ・ 日付スタンプ ・ 場所 + タグ3つ ・ # と 切りかえ ・ 白い 輪 90 + ライムの 輪 ・「長押しで撮る / そのまま… / もう少し長く」・ 初回だけ 音量ボタンの 案内 4秒)。長押し 1.5秒と 音量ボタンの 長押しは **前から 同じ 状態機械**(`ShutterGesture`)で 動いて いる = 仕組みは 変えて いない。写真 / 動画の 切りかえは 残し、ファインダーの 左下に 小さく 置いた。
- 撮れた 瞬間:黒 → 白く 光る → ミルク色の 板が とぶ(既存 `ShotSequenceOverlay` / `ShotFlightOverlay`)。着地先は 新 Home の 今日の フィルムの 3枠(`FilmLanding.slotFrames`)。
- ひらく:`ReleaseRevealV89View` を v134 に(上から 光 ・「1 / 3」・ チェキ ・ `filmDevelop` ・ 9秒 / おさえて 1.4秒 ・ 触感 ・「のせる / 自分だけ」)。結果は 今までの `.posted` / `.skipped`。

## v134 Phase 4(9:00)
- GOOD MORNING:`Today/V134/MorningNightV134`(`GoodMorningV134`)。9:00 以降に はじめて ひらいた とき、きのう 撮った 写真が あれば 1日1回(`GoodMorningStore` = UserDefaults の 日付だけ)。上から 光 1.6秒 + 触感「あかり」+ フィルム 3枚が 順に 上がる + 「撮って、ひらく」→ 撮影 /「あとで」。通知から 開いても 同じ 条件。
- 消灯:0:00〜9:00 は Home の 中身を 強く ぼかして 暗く、スクロール 止め、まんなかに「消灯中」+ カウントダウン(Barlow 86)+ きのうの フィルム。#は 鍵。データの 読みこみは 変えない。
- 通知文:「あかりがつきました。今日の1枚を撮ると、きのうがひらきます。」(`notification.daily.body`・ ja / en)。毎日 9:00 の 1回だけ(今までの まま)。
- Live Activity:`.waiting` を 追加。1枚目を 撮った 瞬間から あした 9:00 まで 1つ(ロック画面:#レンズ +「あかりがつくまで あと H:MM:SS」+ フィルム 3枠 + ライムの 進み +「撮った / 9:00 ひらく」。島:左に #レンズ ・ 右に ライムの 残り時間)。9:00 を すぎて 古く なった 時は「あかりがつきました」。夜の 設定(`notify.liveNight`)が オフなら 出さない。**iOS は ライブ アクティビティを 8時間で 止める**(そのあと 最大4時間は 画面に のこる)ため、22時 以降の 撮影は 実機で 確認が 必要。

## v134 Phase 5(ストーリー ・ シェアカード ・ 招待 ・ プロフィール)
- ストーリー:`StoryV134View`。ともだちの 丸から 全画面。1枚 4.8秒 ・ 左 / 右タップ ・ 最後まで 行ったら 次の 人 ・ おさえている 間は 止まる ・ 下へ 払って とじる。まだの 人は 色の 板を ぼかして タグだけ。返信 = 1対1チャットを ひらく。
- シェアカード:`ShareCardScreenV134`(Film / Time / Clean ・ 9:16 ・ 4倍で 書き出し)。のせる(= `.posted`)の あと `TodayView` が 出す。「ストーリーにのせる」= 共有シート(画像)・ 保存 = 写真アプリ。待った 時間 = 翌朝9:00 − 撮った 時刻。
- 招待:`InviteV134View`(INVITE ・ 4枚から えらぶ ・ 見本の ふきだし ・ リンクを送る ・ コピー ・ QR)。リンクの 形は 今までの まま、文面だけ「◯◯の「きのう」が届いています。…」(`ShareTextV108.friend`)。ともだちシートの「リンクで呼ぶ」と「呼ぶ」の 丸も ここへ。リンクプレビューの ぼかし 画像は サーバー側が 必要なので 見本だけ。
- プロフィール:れんぞくの 数字を 画面から 消した(データは のこす)。「N月、見ないで待った Nh」+ 日ごとの 棒 + 自分だけに 見える 数字。名前は システム書体 heavy。カレンダーは 後回し。

## v134 Phase 6(はじめての設定 ・ オープニング ・ ウィジェット ・ Trip)
- はじめての設定:`OBStep` に `q`(質問「撮った写真、すぐに見返す?」A / B / C ・ 押して 0.5秒後に 次へ ・ 答えは 保存しない)と `why`(理由)を 追加。順番は サインイン → 質問 → 理由 → 名前 → ID → タグ → ともだち(既存の まま)→ 通知 → はじめる。`go` は 大きい #レンズ(176)+ 刻印の 輪 + 長押し 1.6秒(振動 だんだん 強く → 「ブイッ」)。上に 5つの 進みバー + もどる。部品:`Onboarding/V64/OnboardingV134Steps.swift`。サインイン ~ 通知の 既存の 画面は そのまま(チェキの 画面)。
- オープニング:すでに「アイコンが 横へ → ロゴ + 9:00」(v72)= v134 の 01 と 同じ 構成。変更なし。
- Trip:Home の Trip タブに 大見出し「TRIP」(Barlow)。ヘッダー ・ 下の バー ・ 搭乗パスは Phase 2 / P58 の まま。
- ウィジェット:小「ひらくまで」(#レンズ + フィルム 3枠 + Barlow の 残り時間 + ライムの 進み)・ 中「きのう」(ともだちの 写真 いっぱい +「◯◯の きのう」+「11H 03M 見ないで待った」+ #レンズ)を v134 に。Barlow を ウィジェットにも 同梱。ほかの ウィジェット(レンズ ・ Friends ・ Trip ・ ロック画面 など)は v96 の まま。
