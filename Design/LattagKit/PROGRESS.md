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
