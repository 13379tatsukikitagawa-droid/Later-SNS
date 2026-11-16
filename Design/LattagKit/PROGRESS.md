# PROGRESS ・ 進み具合(Claude Code が 書きこむ)

| 段階 | 中身 | 画面 | 状態 | メモ |
|---|---|---|---|---|
| P00 | 準備 ・ 土台 ・ DEBUG メニュー ・ 名前 | — | ✓ | 2026-11-16。テスト 全部 成功 ・ シミュレータ(17e)で 起動 ・ lattag:// と later:// 両方 受けつけを 確認。3本指 メニューの 実機/シミュレータ 操作は 未確認 |
| P01 | オープニング ・ はじめての 設定 | O01〜O11 | ✓ | 2026-11-16。テスト 457件 成功 ・ 全11画面 score 8 以下。Google サインインは コード だけ(Firebase 側の 設定が 必要)・ 実機の バイブ / 長押し〜Home入りは 未確認 |
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
