# 見本画像の 一覧(screens/)

- すべて **モック `mock/lattag_v83.html` から 自動で 撮った もの**(390 × 844pt を 2倍 = 780 × 1688px の JPG)。**v85 に 更新済み**(Shake を なくした)。その 前は v83(Trip の 入力 ・ ホーム)。その 前は v82(Mondo の 地球 = 字なし)。その 前は v81(アイコン = プロフィール写真)。その 前は v80(スクロールで 上が 小さく ・ Mondo の 字 なし)。その 前は v79(時間の カプセル ・ あなたの きのう ・ Mondo の 大きな 地球 ・ ない 日)。その 前は v73(まんなかの シャッター)。その 前は v71(まんなかの レンズ ・ かぎ ・「Friends」の 表記)。その 前は v70(Home の ヘッダー ・ 四すみ ・ フルブリード、Friends ・ Shake)。
- 同じ ID の **数値データ** が `spec/screens/<ID>.json` に ある(位置 ・ 大きさ ・ 書体 ・ 色 ・ 角丸 ・ 影 ・ ぼかし。**CSS の 上書きを ぜんぶ 計算した あとの 最終値**)。
- どうやって その 状態に したかは `tools/capture_mock.js` の 同じ ID の 行を 見る。
- JSON の 座標は **画面の 左上 = (0, 0)、単位 = pt**。`el` は モックの 要素名(タグ#id.class)。


## P01 オープニング・はじめての設定

| ID | 画面 | 部品の 数 |
|---|---|---|
| `O01_opening_print` | オープニング:チェキが 出てくる | 149 |
| `O02_opening_logo` | オープニング:Lattag の 文字 | 128 |
| `O03_onboarding_intro` | はじめての 設定:入口(落ちてくる 題字) | 227 |
| `O04_onboarding_signin` | はじめての 設定:サインイン(Apple / Google / メール) | 233 |
| `O05_onboarding_mail` | はじめての 設定:メールアドレス | 230 |
| `O06_onboarding_sent` | はじめての 設定:メール送信済み | 229 |
| `O07_onboarding_name` | はじめての 設定:名前と 色 | 165 |
| `O08_onboarding_tag` | はじめての 設定:タグを 3つ | 186 |
| `O09_onboarding_fr` | はじめての 設定:友だち | 174 |
| `O10_onboarding_nt` | はじめての 設定:通知の 許可 | 173 |
| `O11_onboarding_go` | はじめての 設定:できた | 160 |

## P02/P03 Home 上・横スライド(v68 フルブリード)

| ID | 画面 | 部品の 数 |
|---|---|---|
| `H01_home` | Home:0枚(いつも) | 154 |
| `H02_home_hint` | Home:はじめの 合図(スポットライト) | 154 |
| `H03_home_press` | Home:まんなかを 押している 間 | 154 |
| `H04_home_1shot` | Home:1枚 撮った あと | 156 |
| `H05_home_2shot` | Home:2枚 撮った あと | 156 |
| `H06_home_3shot` | Home:3枚 撮りおわり(まんなか = Yesterday) | 154 |
| `H07_home_friends` | Home:友だち 3人 + 申請あり(上の チップ) | 156 |
| `H08_home_firstday` | Home:はじめての 日(上) | 156 |
| `H09_home_night` | Home:夜 | 155 |
| `H10_live_panel` | Home:「消灯まで」を 押した パネル | 218 |
| `H11_page_friends` | 横スライド 1:Friends | 135 |
| `H12_page_friends_filled` | 横スライド 1:Friends(3人 + 申請) | 150 |
| `H13_page_trip` | 横スライド 2:Trip(まだ ない) | 124 |
| `H14_page_mondo_locked` | 横スライド 3:Mondo(撮る まえ) | 146 |
| `H15_page_mondo_open` | 横スライド 3:Mondo(撮った あと) | 155 |
| `H16_page_yesterday` | 横スライド 4:Yesterday(撮る まえ) | 135 |
| `H17_page_yesterday_open` | 横スライド 4:Yesterday(撮った あと) | 133 |
| `H18_page_yesterday_firstday` | 横スライド 4:Yesterday(はじめての 日) | 123 |

## P04 Home 下

| ID | 画面 | 部品の 数 |
|---|---|---|
| `L01_today` | Home 下:Today(今日の フィルム) | 111 |
| `L02_active` | Home 下:Active(Trip) | 109 |
| `L03_yesterday` | Home 下:Yesterday(撮る まえ ・ ロック) | 113 |
| `L04_yesterday_open` | Home 下:Yesterday(撮った あと) | 112 |
| `L05_mondo_row` | Home 下:Mondo の 列 | 124 |
| `L06_albums` | Home 下:Albums(7日) | 117 |
| `L07_onthisday` | Home 下:On this day | 125 |
| `L08_friends_card_empty` | Home 下:Friends カード(だれも いない ・ 申請 あり) | 116 |
| `L09_friends_card` | Home 下:Friends カード(友だち あり) | 141 |
| `L10_firstday_yesterday` | Home 下:はじめての 日の Yesterday | 106 |
| `L11_develop_view` | Home:今日の フィルム(現像中)を ひらく | 186 |
| `L12_friends_card_noreq` | Home 下:Friends カード(だれも いない ・ 申請も ない)| 81 |

## P05 撮る(タグ・撮影・現像)

| ID | 画面 | 部品の 数 |
|---|---|---|
| `C01_tag` | タグ画面(撮る まえ) | 56 |
| `C02_camera_photo` | 撮影画面(写真) | 46 |
| `C03_camera_video` | 撮影画面(動画) | 46 |
| `C04_volume_button` | 音量ボタン 長押しの 合図 | 46 |
| `C05_after_shot_1` | 撮った 直後 0.6秒 | 152 |
| `C06_after_shot_2` | 撮った あと 1.6秒 | 152 |
| `C07_after_shot_3` | 撮った あと 3.2秒 | 153 |
| `C08_morning_develop_1` | 翌朝 9:00 の 現像 1秒 | 23 |
| `C09_morning_develop_2` | 翌朝 9:00 の 現像 3秒 | 22 |
| `C10_rare_film` | 現像(レアフィルム) | 167 |
| `C11_cheki_develop` | 現像(チェキ) | 167 |

## P06 Lattag yesterday

| ID | 画面 | 部品の 数 |
|---|---|---|
| `Y01_yesterday_locked` | Lattag yesterday(撮る まえ) | 242 |
| `Y02_yesterday_open` | Lattag yesterday(撮った あと) | 242 |
| `Y03_yesterday_mondo_tab` | Lattag yesterday:Mondo タブ | 257 |
| `Y04_yesterday_friends_tab` | Lattag yesterday:Friends タブ(友だち あり) | 247 |
| `Y05_yesterday_scroll` | Lattag yesterday:下へ | 244 |
| `Y06_photo_viewer` | 写真を ひらいた ところ | 161 |

## P07 / P12 Friends・Profile(Shake は v85 で なくした)

| ID | 画面 | 部品の 数 |
|---|---|---|
| `F01_friend_empty` | Friends(だれも いない ・ QR で 会って つながる) | 202 |
| `F02_friend_list` | Friends(一覧:さがす ・ QR ・ 友だち) | 237 |
| `F03_friend_requests` | Friends:申請が とどいた | 232 |
| `F04_friend_scroll` | Friends:下へ(ヘッダーが ぼける) | 245 |
| `F05_friend_card` | 友だちの カード(シート) | 272 |
| `F06_add_friends` | Add friends(ID ・ QR) | 178 |
| `F07_dm_chat` | 友だちと チャット | 202 |
| `F08_profile` | Profile | 156 |
| `F09_me_calendar` | ME:Recap が 主役(見た あと)| — |
| `F10_qr_scan` | QR を 読む | 162 |

## P08 Trip

| ID | 画面 | 部品の 数 |
|---|---|---|
| `T01_new_trip` | New trip(つくる 画面) | 212 |
| `T02_new_trip_filled` | New trip(入力 した あと) | 216 |
| `T03_trip_pass_new` | Trip パス(できた ・ QR + KEY) | 195 |
| `T04_trip_page_active` | 横スライド 2:進行中の Trip | 167 |
| `T05_trip_pass` | Trip パス(あとから ひらく) | 197 |
| `T06_trip_settings` | Trip の 設定 | 169 |
| `T07_trip_chat` | Trip の 部屋(チャット) | 215 |
| `T08_invite` | 招待が とどいた | 155 |
| `T09_active_card` | Home 下:Active に Trip | 144 |


## v75 で 足した 画面

| ID | 中身 |
|---|---|
| `Y07_yesterday_other_shot` | Lattag yesterday:小さな 写真を 押して 入れかえ |
| `Y08_mondo_empty` | Mondo:だれも 投稿して いない |
| `Y09_mondo_empty_scroll` | Mondo:だれも いない(下へ)|
| `F10_me_scrub` | ME:Recaps の 列 ・ 縦線で 日を えらぶ |
| `Y10_mondo_globe` | Mondo:地球儀(タップ する まえ)|
| `Y11_mondo_tap` | Mondo:地球儀を タップ(光る)|
| `Y12_mondo_ranking` | Mondo:きのうの タグ ランキング ・ 図の 説明 |
| `Y13_friends_tags` | Friends:ハッシュタグ(押すと 入れかわる)|
| `Y14_notifications` | yesterday:左上の 通知 |
| `Y15_my_yesterday` | yesterday:あなたの きのう(自分の 写真)|
| `Y16_mondo_ranking_more` | Mondo:タグ ランキング 4〜8位 |
| `Y17_mondo_tag_filter` | Mondo:タグで しぼった 写真 |
| `H19_home_scrolled` | Home:下へ スクロール(時間が 小さく まとまる)|
| `Y18_friends_scrolled` | yesterday:下へ スクロール(上の 帯が 小さく)|
| `F11_icon_picker` | アイコン:写真を えらぶ シート |
| `F12_profile_no_photo` | Profile:写真 なし(1文字 + 色)|
| `T10_new_trip_who` | New trip ③だれと |
| `T11_new_trip_cover` | New trip ④表紙 + 確認 |
| `T12_trip_home` | Trip の ホーム(メイン)|
| `T13_trip_home_days` | Trip の ホーム:日ごとの フィルム |
| `F13_me_album` | ME:アルバム(月の カレンダー ・ 1日 1枚)|
| `F14_me_day` | ME:1日の 全画面(横に スワイプ)|
| `F15_recap_intro` | Recap:はじまりの 題(Your week.)|
| `F16_recap_play` | Recap:再生中(上の 線 ・ 曜日 ・ 時刻 ・ タグ)|
| `F17_recap_end` | Recap:おわり(数字 ・ 保存 ・ シェア ・ もう1回)|
| `F18_me_recap_new` | ME:新しい Recap が できた(現像の 途中)|

> v86:ME は **Recap が 主役**。動きは `motion/M24_recap_develop` `M25_recap_play`。

> v87:実機を 見て 直した 画面(**ぜんぶの 見本を 撮りなおした**:上の アイコン ・ 帯 ・ 下の 地球儀が 変わった ため)。

|---|---|
| `C12_camera_front` | 撮影画面:インカメ |
| `Y19_friends_first` | Friends:はじめて(自分の きのう も 友だち も ない)|
| `Y20_friends_first_scroll` | Friends:はじめて(下 ・ 友だちを よぶ)|
| `Y21_friends_no_friends` | Friends:自分の きのうは ある ・ 友だち 0人 |
| `Y22_friends_no_own` | Friends:友だちは いる ・ 自分の きのう なし |
| `F19_profile_scrolled` | Profile:下へ(上の 帯に アイコン + 名前 ・ Recap ・ 1年)|
| `F20_settings` | 設定(歯車 → 下から シート)|
| `F21_settings_bottom` | 設定:下(ログアウト ・ アカウントを 消す)|
| `F22_settings_logout` | 設定:ログアウトの 確認 |

動き:`motion/M26_camera_flip` `M27_settings_open` `M28_avatar_double_tap`。

**v104**:O04 は Apple だけ。`O05` `O06` `O25`〜`O27` `O29`〜`O31`(メール ・ Google)の 見本は 使わない(作らない ・ あれば 消す)。
