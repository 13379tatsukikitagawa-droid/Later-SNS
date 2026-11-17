# 動きの コマ割り(motion/)

- 1つの 動きを 決まった 時刻で 撮って 並べた もの(左上 = 0ms、緑の 数字 = 撮った 時刻)。**時間 ・ カーブの 正確な 値は コード と `spec/ANIMATIONS.md` と 各 PROMPT を 見る**。コマ割りは「どんな 順番で 何が 動くか」を 見る ため。
- 撮影の 都合で 時刻は ±50ms ほど ずれる。

| ID | 動き | コマ |
|---|---|---|
| `M01_opening` | オープニング(起動〜Home) | 15 |
| `M02_onboarding_intro` | はじめての 設定の 入口(題字が 落ちる → サインイン) | 12 |
| `M03_home_enter` | Home に 入る(カード ・ ボタン ・ 四すみ ・ ピル) | 12 |
| `M04_shutter` | まんなかを 押す → はなす → 撮影へ | 12 |
| `M05_page_swipe` | 横スライド(Camera → Friends)と 目次の 印 | 12 |
| `M06_after_shot` | 撮った あと(チェキ → 預ける → Home) | 12 |
| `M07_return_after_shot` | 撮って もどった Home(弧が 抜ける ・ ピル) | 10 |
| `M08_morning_develop` | 翌朝 9:00 の 現像 | 12 |
| `M09_request_accept` | 申請を 承認(カードが 落ちて 壁に 貼られる) | 10 |
| `M10_trip_create` | Trip を つくる → パス | 10 |
| `M11_mondo_globe` | Mondo の 地球(回る ・ 9:00 の 線) | 8 |
| `M12_friends_card_in` | Home 下の Friends カード(チェキが 貼られる) | 9 |
| `M13_live_panel` | 「消灯まで」を 押した パネル | 8 |
| `M14_friend_card_sheet` | 友だちの カードを ひらく | 9 |
