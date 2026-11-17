# 見本画像の 一覧(screens/)

- すべて **モック `mock/lattag_v64.html` から 自動で 撮った もの**(390 × 844pt を 2倍 = 780 × 1688px の JPG)。
- 同じ ID の **数値データ** が `spec/screens/<ID>.json` に ある(画面に 見えている 部品の 位置 ・ 大きさ ・ 書体 ・ 色 ・ 角丸 ・ 影 ・ ぼかし。**CSS の 上書きを ぜんぶ 計算した あとの 最終値**)。
- どうやって その 状態に したかは `tools/capture_mock.js` の 同じ ID の 行を 見る(モックの 関数 / デモの ボタン)。
- JSON の 座標は **画面の 左上 = (0, 0)、単位 = pt**。`el` は モックの 要素名(タグ#id.class)。


## P01 オープニング・はじめての設定

| ID | 画面 | 部品の 数 |
|---|---|---|
| `O01_opening_print` | オープニング:チェキが 出てくる | 154 |
| `O02_opening_logo` | オープニング:Lattag の 文字 | 121 |
| `O03_onboarding_intro` | はじめての 設定:入口(落ちてくる 題字) | 247 |
| `O04_onboarding_signin` | はじめての 設定:サインイン(Apple / Google / メール) | 237 |
| `O05_onboarding_mail` | はじめての 設定:メールアドレス | 235 |
| `O06_onboarding_sent` | はじめての 設定:メール送信済み | 234 |
| `O07_onboarding_name` | はじめての 設定:名前と 色 | 170 |
| `O08_onboarding_tag` | はじめての 設定:タグを 3つ | 190 |
| `O09_onboarding_fr` | はじめての 設定:友だち | 178 |
| `O10_onboarding_nt` | はじめての 設定:通知の 許可 | 177 |
| `O11_onboarding_go` | はじめての 設定:できた | 164 |

## P02/P03 Home 上・カメラカード・横スライド

| ID | 画面 | 部品の 数 |
|---|---|---|
| `H01_home` | Home:0枚(いつも) | 158 |
| `H02_home_hint` | Home:はじめの 合図(スポットライト) | 158 |
| `H03_home_press` | Home:まんなかを 押している 間 | 158 |
| `H04_home_1shot` | Home:1枚 撮った あと | 160 |
| `H05_home_2shot` | Home:2枚 撮った あと | 160 |
| `H06_home_3shot` | Home:3枚 撮りおわり(まんなか = Yesterday) | 158 |
| `H07_home_friends` | Home:友だち 3人 + 申請あり(上の チップ) | 161 |
| `H08_home_firstday` | Home:はじめての 日(上) | 159 |
| `H09_home_night` | Home:夜 | 158 |
| `H10_live_panel` | Home:「消灯まで」を 押した パネル | 239 |
| `H11_page_friends` | 横スライド 1:Friends | 135 |
| `H12_page_friends_filled` | 横スライド 1:Friends(3人 + 申請) | 151 |
| `H13_page_trip` | 横スライド 2:Trip(まだ ない) | 122 |
| `H14_page_mondo_locked` | 横スライド 3:Mondo(撮る まえ) | 142 |
| `H15_page_mondo_open` | 横スライド 3:Mondo(撮った あと) | 153 |
| `H16_page_yesterday` | 横スライド 4:Yesterday(撮る まえ) | 132 |
| `H17_page_yesterday_open` | 横スライド 4:Yesterday(撮った あと) | 131 |
| `H18_page_yesterday_firstday` | 横スライド 4:Yesterday(はじめての 日) | 120 |

## P04 Home 下

| ID | 画面 | 部品の 数 |
|---|---|---|
| `L01_today` | Home 下:Today(今日の フィルム) | 116 |
| `L02_active` | Home 下:Active(Trip) | 114 |
| `L03_yesterday` | Home 下:Yesterday(撮る まえ ・ ロック) | 116 |
| `L04_yesterday_open` | Home 下:Yesterday(撮った あと) | 115 |
| `L05_mondo_row` | Home 下:Mondo の 列 | 127 |
| `L06_albums` | Home 下:Albums(7日) | 120 |
| `L07_onthisday` | Home 下:On this day | 128 |
| `L08_friends_card_empty` | Home 下:Friends カード(だれも いない) | 119 |
| `L09_friends_card` | Home 下:Friends カード(友だち あり) | 144 |
| `L10_firstday_yesterday` | Home 下:はじめての 日の Yesterday | 109 |
| `L11_develop_view` | Home:今日の フィルム(現像中)を ひらく | 190 |

## P05 撮る(タグ・撮影・現像)

| ID | 画面 | 部品の 数 |
|---|---|---|
| `C01_tag` | タグ画面(撮る まえ) | 56 |
| `C02_camera_photo` | 撮影画面(写真) | 47 |
| `C03_camera_video` | 撮影画面(動画) | 46 |
| `C04_volume_button` | 音量ボタン 長押しの 合図 | 46 |
| `C05_after_shot_1` | 撮った 直後 0.6秒 | 194 |
| `C06_after_shot_2` | 撮った あと 1.6秒 | 156 |
| `C07_after_shot_3` | 撮った あと 3.2秒 | 157 |
| `C08_morning_develop_1` | 翌朝 9:00 の 現像 1秒 | 23 |
| `C09_morning_develop_2` | 翌朝 9:00 の 現像 3秒 | 22 |
| `C10_rare_film` | 現像(レアフィルム) | 171 |
| `C11_cheki_develop` | 現像(チェキ) | 171 |

## P06 Lattag yesterday

| ID | 画面 | 部品の 数 |
|---|---|---|
| `Y01_yesterday_locked` | Lattag yesterday(撮る まえ) | 256 |
| `Y02_yesterday_open` | Lattag yesterday(撮った あと) | 256 |
| `Y03_yesterday_mondo_tab` | Lattag yesterday:Mondo タブ | 271 |
| `Y04_yesterday_friends_tab` | Lattag yesterday:Friends タブ(友だち あり) | 261 |
| `Y05_yesterday_scroll` | Lattag yesterday:下へ | 258 |
| `Y06_photo_viewer` | 写真を ひらいた ところ | 164 |

## P07 Friends・Profile

| ID | 画面 | 部品の 数 |
|---|---|---|
| `F01_friend_empty` | Friend 画面(だれも いない) | 213 |
| `F02_friend_wall` | Friend 画面(チェキの 壁) | 242 |
| `F03_friend_requests` | Friend 画面:申請が とどいた | 251 |
| `F04_friend_scroll` | Friend 画面:下へ | 237 |
| `F05_friend_card` | 友だちの カード(シート) | 275 |
| `F06_add_friends` | Add friends(ID ・ QR) | 180 |
| `F07_dm_chat` | 友だちと チャット | 207 |
| `F08_profile` | Profile | 157 |
| `F09_me_calendar` | ME(1年 のこす) | 216 |
| `F10_qr_scan` | QR を 読む | 164 |

## P08 Trip

| ID | 画面 | 部品の 数 |
|---|---|---|
| `T01_new_trip` | New trip(つくる 画面) | 215 |
| `T02_new_trip_filled` | New trip(入力 した あと) | 221 |
| `T03_trip_pass_new` | Trip パス(できた ・ QR + KEY) | 200 |
| `T04_trip_page_active` | 横スライド 2:進行中の Trip | 164 |
| `T05_trip_pass` | Trip パス(あとから ひらく) | 201 |
| `T06_trip_settings` | Trip の 設定 | 174 |
| `T07_trip_chat` | Trip の 部屋(チャット) | 219 |
| `T08_invite` | 招待が とどいた | 158 |
| `T09_active_card` | Home 下:Active に Trip | 149 |
