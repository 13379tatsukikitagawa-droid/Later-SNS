# PROGRESS ・ 進み具合(Claude Code が 書きこむ)

| 段階 | 中身 | 画面 | 状態 | メモ |
|---|---|---|---|---|
| P00 | 準備 ・ 土台 ・ DEBUG メニュー ・ 名前 | — | ✓ | 2026-11-16。テスト 全部 成功 ・ シミュレータ(17e)で 起動 ・ lattag:// と later:// 両方 受けつけを 確認。3本指 メニューの 実機/シミュレータ 操作は 未確認 |
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

## P00 メモ(2026-11-16)

- 作った もの:`Theme/Brand.swift` ・ `DesignSystem/`(LGColor LGFont LGMotion LGGlass LGPressable)・ `Debug/`(DebugState DebugStateMenu SampleData DesignSystemPreview)・ `scripts/snap.sh` ・ `MIGRATION_MAP.md`
- `Haptics.play(.名前)` は 既に 15種類 そろって いた(`ExposureHaptics.swift`)ので 手を 入れて いない。強さの 数値は HAPTICS.md と 少し 違う(例 `tick` 0.45 vs 0.35)→ P01 で 実機に あわせて 調整。
- DEBUG 状態メニュー:3本指 長押し。撮った 枚数 / 昼夜 / オープニング / 設定やりなおし は 既存の しくみに つなぐ。友だち・申請・Trip・招待・初日・翌朝9:00・見本データ は 値を `DebugState`(UserDefaults `debug.*`)に 保存する だけで、**各 画面を 作る フェーズで 読む**。
- 見本データの 写真は 色の 面(画像は 後の フェーズ)。
- シミュレータ:幅 390pt は **iPhone 17e**。
- ロゴの 大きさ(v62 §3B:オープニング 104pt など)は まだ 直して いない(P01 / P02)。
