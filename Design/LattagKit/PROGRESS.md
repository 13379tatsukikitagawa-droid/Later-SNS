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
