# UI Layout Comparison - Before & After

## 📱 Gallery画面

### ❌ Before (回転ダイヤル)
```
┌─────────────────────────────────┐
│  [Personal] [Group]             │ ← Mode Selector
│                                 │
│                                 │
│        📷 Photo (3:2)           │
│                                 │
│       [Fullscreen]              │
│                                 │
│                                 │
│    ╭─────────────────╮          │
│   ╱  19  20  21  22   ╲         │ ← 回転ダイヤル（弧状）
│  │    ⚫  ⚪  ⚫  ⚪    │        │   魚眼エフェクト
│   ╲                   ╱         │   ドラッグで回転
│    ╰─────────────────╯          │
└─────────────────────────────────┘
      ↑ 15% of screen height
```

### ✅ After (水平タップバー)
```
┌─────────────────────────────────┐
│  [Personal] [Group]             │ ← Mode Selector
│                                 │
│                                 │
│        📷 Photo (3:2)           │
│                                 │
│       [Fullscreen]              │
│                                 │
│                                 │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ ← Gradient fade
│                                 │
│ 19  20  ┃21┃  22  23  24  25  →│ ← 水平タップバー
│MON TUE ┃WED┃THU FRI SAT SUN    │   シンプル・フラット
│ ⚫  ⚫  ┃⚫ ┃ ⚪  ⚫  ⚪  ⚫     │   タップ優先
└─────────────────────────────────┘
      ↑ 80px fixed height
```

**主な変更点：**
- ✂️ 弧状レイアウト削除 → フラットな横一列
- ✂️ 回転アニメーション削除 → タップ＆スクロール
- ✂️ 魚眼エフェクト削除 → 均一なサイズ（選択時のみ拡大）
- ✅ ネオングリーン枠で選択を強調
- ✅ グリーンドットで写真の有無を表示
- ✅ 画面高さを大幅削減（15% → 80px）

---

## 🏠 Home画面

### ❌ Before
```
┌─────────────────────────────────┐
│  ✨ Later           📅          │ ← Header
│   シークレット現像                │
│                                 │
│        📷 Card                  │
│       (現像中...)                │
│                                 │
│        ⚫⚫⚪⚫                   │ ← Page indicator
│                                 │
│   ┌─────────────────────┐       │
│   │  3  撮影済み | 5 目標 │       │ ← Footer stats
│   └─────────────────────┘       │
└─────────────────────────────────┘
```

### ✅ After
```
┌─────────────────────────────────┐
│  ✨ Later      ┌──────────┐     │ ← Header
│   シークレット   │ 📷 (blur)│     │   + Next Reveal
│   現像         │ REVEAL IN│     │
│                │ 12:34:56 │     │
│                └──────────┘     │
│        📷 Card                  │
│       (現像中...)                │
│                                 │
│        ⚫⚫⚪⚫                   │ ← Page indicator
│                                 │
│   ┌─────────────────────┐       │
│   │  3  撮影済み | 5 目標 │       │ ← Footer stats
│   └─────────────────────┘       │
└─────────────────────────────────┘
```

**主な変更点：**
- ✂️ カレンダーアイコン削除
- ✅ Next Revealウィジェット追加（右上）
- ✅ 100x100の小窓形式
- ✅ 強いブラー（radius: 30）
- ✅ リアルタイムカウントダウン
- ✅ ネオングリーン枠

---

## 🎨 カラーパレット

### ネオングリーン（ブランドカラー）
```
#00ff41  ████████  rgb(0, 255, 65)
         ↑ 選択状態、アクティブ要素
```

### グラデーション（タップバー）
```
Top:    rgba(0,0,0,0.0)    ░░░░░░░░
        rgba(0,0,0,0.7)    ▓▓▓▓▓▓▓▓
Bottom: rgba(0,0,0,0.95)   ████████
```

---

## 📐 サイズ仕様

### Gallery - HorizontalDateTapBar
```
全体高さ:     80px (固定)
アイテム幅:   70px
アイテム間隔: 16px
選択時拡大:   1.05倍
枠線:         2px (ネオングリーン)
ドット:       6px (選択時) / 4px (非選択時)
角丸:         12px
```

### Home - NextRevealWidget  
```
写真窓:       100x100px
ブラー:       radius 30
タイマー文字: 12pt (モノスペース・太字)
ラベル文字:   8pt (トラッキング1)
角丸:         12px (写真) / 6px (タイマー)
```

---

## ⚙️ アニメーション仕様

### タップバー
```swift
// タップ時
.animation(.snappy(duration: 0.2), value: selectedDate)

// スケール変化
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

// スクロール
.animation(.easeInOut(duration: 0.3)) { proxy.scrollTo(...) }
```

### Next Reveal
```swift
// タイマー更新間隔
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true)

// 出現アニメーション（将来的に追加可能）
.transition(.opacity.combined(with: .scale))
```

---

## 🎯 タップターゲット

### 推奨サイズ（Apple Human Interface Guidelines）
- 最小: 44x44 pt
- 推奨: 48x48 pt以上

### 実装サイズ
```
DateTapItem:
  - 幅: 70px ✅ (十分)
  - 高さ: 約60px (padding含む) ✅
  
NextRevealWidget:
  - 100x100px ✅ (十分)
```

---

## 📊 コード削減量

| ファイル         | Before  | After   | 削減量  |
|-----------------|---------|---------|---------|
| GalleryView     | ~1858行 | ~1350行 | -508行  |
| HomeView        | ~1291行 | ~1370行 | +79行   |
| **合計**        | ~3149行 | ~2720行 | **-429行** |

**削減内訳：**
- MechanicalScrollDial: ~200行
- TactileDialNavigation: ~250行  
- DialDateItem: ~80行
- その他（dateOverlay等）: ~58行

**追加内訳：**
- HorizontalDateTapBar: ~60行
- DateTapItem: ~40行
- NextRevealWidget: ~80行
- Color拡張（重複）: ~20行

---

## 🔄 ユーザーフロー

### Gallery（日付選択）
```
Before:
  指でドラッグ → 回転開始 → 慣性で回転継続 → 
  自動スナップ → ハプティクス → 日付確定
  (約2-3秒)

After:
  日付をタップ → 即座に切り替わる → ハプティクス
  (約0.3秒)
  
  または
  
  左右スワイプ → スクロール → 日付をタップ
```

### Home（Next Reveal確認）
```
Before:
  （機能なし）

After:
  画面表示 → 自動的に右上のウィジェットでカウントダウン表示
  → 00:00:00になったら自動解禁（別の機能で処理）
```

---

## 🐛 既知の制限事項

1. **Color拡張の重複**
   - GalleryView.swift と HomeView.swift 両方に定義
   - 今後は共通ファイル（例：ColorExtensions.swift）に統合推奨

2. **UIImage拡張**
   - GalleryView.swiftのみに定義
   - 他のファイルでも必要な場合は共通化必要

3. **タイマーのメモリ管理**
   - Next Revealは画面表示中のみタイマー動作
   - バックグラウンドでは停止（意図的な設計）

---

**ドキュメント作成日**: 2026年5月30日
