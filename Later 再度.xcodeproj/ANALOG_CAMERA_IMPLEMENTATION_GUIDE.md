# 📸 Later アナログカメラ & 暗室モード実装ガイド

## 🎯 概要

「later」のコア体験である「時間差の現像」を視覚化するため、以下の機能を実装しました:

1. **アナログカメラUI** - 3:2ビューファインダー、フィルムカウンター、ライムグリーンアクセント
2. **暗室待機モード** - 撮影完了後、次に現像される写真をプレビュー
3. **強化されたギャラリー** - 複数グループ管理 + 弧状日付ダイヤル
4. **Circle管理機能** - グループ作成、招待共有の一元管理

---

## 📂 新規作成ファイル

### 1. `AnalogCameraView.swift`
- **アナログカメラUI**: 3:2アスペクト比、フィルムカウンター(05→00)、レティクル表示
- **暗室待機モード**: 撮影完了後、次に現像される写真のぼかしプレビュー + リアルタイムタイマー

**主な機能:**
- フィルムカウンター: 右上に物理ホイール風の窓を配置
- レティクル: L字フレームでビューファインダー感を演出
- ライムグリーン (#00ff41): 全UIアクセントカラー
- 暗室モード: 強いガウスぼかし + 粒子ノイズ + 秒単位タイマー

### 2. `EnhancedGalleryView.swift`
- **複数グループ対応**: Personal / Group モード切り替え
- **グループセレクター**: 水平チップで複数グループを選択可能
- **弧状日付ダイヤル**: ドラッグで直感的な日付変更
- **3:2全画面表示**: 余白なし（Zero Yohaku）写真表示

**主な機能:**
- Personal Mode: 選択日の自分の写真（最大5枚）を横スワイプ
- Group Mode: 選択日のWinner写真（1枚）を表示
- 日付選択の永続化: タブ切り替え後も選択日を維持
- ダイヤル操作中: 写真を軽くぼかして操作性向上

### 3. `CircleManagementView.swift`
- **Circle一覧**: ユーザーが所属する全グループを表示
- **Circle詳細**: メンバーリスト、統計情報、招待機能
- **シェア機能**: 合言葉 + QRコードをLINE等でシェア

**主な機能:**
- グループカード: メンバー数、写真数、活動日数を表示
- 招待セクション: 合言葉のコピー + シェアシート起動
- Done ボタン: DB保存後に正常終了

### 4. `QRCodeScannerWithMyCode.swift`
- **QRコードスキャナー**: カメラでQRコードを読み取り
- **My QR Code ボタン**: スキャン画面から自分のQRコードを表示

---

## 🔧 統合手順

### Step 1: カメラUIの置き換え

既存の `CameraView` を `AnalogCameraView` に置き換えます。

**HomeView.swift の変更:**

```swift
// 既存
.sheet(isPresented: $showCamera) {
    CameraView()
}

// ↓ 新しいカメラUI
.sheet(isPresented: $showCamera) {
    AnalogCameraView()
}
```

### Step 2: ギャラリーの置き換え

既存の `GalleryView` を `EnhancedGalleryView` に置き換えます。

**TabView または NavigationStack の変更:**

```swift
// 既存
TabView {
    GalleryView()
        .tabItem {
            Label("Gallery", systemImage: "photo.stack")
        }
}

// ↓ 強化版
TabView {
    EnhancedGalleryView()
        .tabItem {
            Label("Gallery", systemImage: "photo.stack")
        }
}
```

### Step 3: Connection画面の統合

既存の `ConnectionView_Fixed.swift` に `CircleManagementView` を統合します。

**既に実装済み** - `ConnectionView_Fixed.swift` の右上にCirclesボタンがあります:

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button {
        showCircleManagement = true
    } label: {
        // Circles アイコン
    }
}

.fullScreenCover(isPresented: $showCircleManagement) {
    CircleManagementView()
}
```

### Step 4: QRスキャナーの更新

`ConnectionView_Fixed.swift` の QRスキャナーを更新します。

**変更箇所:**

```swift
// 既存
.fullScreenCover(isPresented: $showQRScanner) {
    QRCodeScannerView(onScanSuccess: { code in
        handleScannedCode(code)
    })
}

// ↓ My QR Code ボタン付き
.fullScreenCover(isPresented: $showQRScanner) {
    QRCodeScannerWithMyCode(
        onScanSuccess: { scannedCode in
            handleScannedCode(scannedCode)
        },
        onShowMyQRCode: {
            showMyQRCode = true
        }
    )
}
```

---

## 🎨 デザイン仕様

### カラーパレット

```swift
// ライムグリーン（アクセントカラー）
Color(red: 0, green: 1, blue: 0.255)  // #00ff41

// 背景
Color.brandBlack  // 漆黒 (#0c0c0d)

// テクスチャ
.fill(.black)  // マット仕上げ
.shadow(color: limeGreen.opacity(0.8), radius: 8)  // 光彩効果
```

### フォント

```swift
// フィルムカウンター
.font(.system(size: 32, weight: .bold, design: .monospaced))

// タイマー表示
.font(.system(size: 28, weight: .bold, design: .monospaced))

// ステータスメッセージ
.font(.system(size: 14, weight: .bold, design: .monospaced))
.tracking(2)  // 文字間隔を広げる
```

### アスペクト比

全ての写真表示は **3:2** に統一:

```swift
.aspectRatio(3/2, contentMode: .fit)
```

---

## 📝 主要ロジック

### 1. Next-to-Reveal写真の抽出

**AnalogCameraView.swift - `DarkroomWaitingView`**

```swift
private func findNextToRevealPhoto() {
    let now = Date()
    let calendar = Calendar.current
    
    // 前日以前に撮影され、まだ現像されていない写真
    let undevelopedPhotos = allPhotos.filter { photo in
        !photo.isDeveloped && photo.captureDate < calendar.startOfDay(for: now)
    }
    
    // 現像時刻が最も近い1枚を選択
    nextToRevealPhoto = undevelopedPhotos.min(by: { photo1, photo2 in
        let reveal1 = photo1.revealTime ?? Date.distantFuture
        let reveal2 = photo2.revealTime ?? Date.distantFuture
        return reveal1 < reveal2
    })
    
    // 残り時間を計算
    if let photo = nextToRevealPhoto, let revealTime = photo.revealTime {
        remainingTime = max(0, revealTime.timeIntervalSince(now))
    }
}
```

**検索条件:**
- ✅ 前日以前に撮影
- ✅ `isDeveloped == false`
- ✅ 全グループ + Personal を横断
- ✅ 現像時刻が最も近い1枚のみ

### 2. 弧状ダイヤルの角度計算

**EnhancedGalleryView.swift - `ArcDateDial`**

```swift
private func calculateAngle(for index: Int, total: Int) -> CGFloat {
    let totalAngle: CGFloat = .pi  // 180度
    let startAngle: CGFloat = .pi  // 左端
    let step = totalAngle / CGFloat(total - 1)
    return startAngle - CGFloat(index) * step
}
```

7日間を半円状に配置:

```
π (180°)               π/2 (90°)               0° (0°)
  ●────────●────────●────────●────────●────────●────────●
  7日前    6日前    5日前    今日    明日    ...
```

### 3. グループ切り替え時の日付維持

**EnhancedGalleryView.swift**

```swift
// displayMode が変わっても selectedDayIndex は維持
.onChange(of: displayMode) { _, _ in
    currentPhotoIndex = 0  // 写真インデックスのみリセット
}

// グループ切り替え
.onChange(of: selectedGroupID) { _, _ in
    currentPhotoIndex = 0  // 写真インデックスのみリセット
}
```

**動作例:**
1. Personal Mode で「5日前」を選択
2. Group Mode に切り替え
3. **「5日前」のまま**、そのグループのWinner写真を表示

---

## 🧪 動作確認

### カメラUI

1. **撮影開始**
   - ✅ 3:2ビューファインダーが表示される
   - ✅ 右上にフィルムカウンター（05→04→...）
   - ✅ レティクル（L字フレーム）が表示される

2. **撮影完了（00到達）**
   - ✅ 自動的に暗室モードへ切り替わる
   - ✅ 次に現像される写真がぼかし表示される
   - ✅ タイマーが秒単位で更新される

3. **次に現像される写真がない場合**
   - ✅ "NO PHOTOS DEVELOPING" メッセージが表示される

### ギャラリーUI

1. **Personal Mode**
   - ✅ 選択日の自分の写真（最大5枚）が表示される
   - ✅ 横スワイプで写真を切り替え
   - ✅ 写真がない日は空状態メッセージ

2. **Group Mode**
   - ✅ グループセレクターが表示される
   - ✅ グループ切り替え時、選択日は維持される
   - ✅ Winner写真（1枚）が表示される

3. **弧状ダイヤル**
   - ✅ ドラッグで日付変更
   - ✅ 操作中は写真が軽くぼかされる
   - ✅ 選択日がハイライト表示される

### Circle管理

1. **Circle一覧**
   - ✅ Connection画面右上のボタンでアクセス
   - ✅ 所属グループがカード形式で表示される
   - ✅ 空状態の場合、作成を促すメッセージ

2. **Circle詳細**
   - ✅ グループ名、メンバー数、写真数が表示される
   - ✅ 合言葉をコピー可能
   - ✅ シェアボタンでLINE等へ招待可能

3. **Done ボタン**
   - ✅ グループ作成完了後、DB保存が完了する
   - ✅ シェアシートが正常に起動する

---

## 🔥 ハプティクフィードバック

全ての主要操作にハプティクスを実装:

```swift
// シャッター
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()

// 日付変更
haptics.selectionChanged()

// ボタンタップ
HapticsManager.swipeFeedback()

// 成功
HapticsManager.unlockSuccess()
```

---

## 🚨 既存コードとの依存関係

### 必要なモデル

```swift
@Model class LaterPhoto {
    var imageData: Data?
    var captureDate: Date
    var isDeveloped: Bool
    var revealTime: Date?  // 現像予定時刻
    var isGroupBestShot: Bool
    var owner: UserProfile?
    var caption: String
}

@Model class LaterGroup {
    var id: UUID
    var name: String
    var inviteCode: String
    var isPrivate: Bool
    var missionText: String
    var members: [UserProfile]
    var photos: [LaterPhoto]
    var createdAt: Date
}

@Model class UserProfile {
    var id: String
    var name: String
}
```

### 必要なマネージャー

```swift
// PhotoManager (既存)
class PhotoManager {
    static let shared = PhotoManager()
    var dailyLimit: Int = 5
    func todayPhotoCount() -> Int { ... }
}

// HapticsManager (既存)
class HapticsManager {
    static func swipeFeedback() { ... }
    static func cardChange() { ... }
    static func unlockSuccess() { ... }
}

// QRCodeGenerator (既存)
class QRCodeGenerator {
    static func createGroupQRData(groupID: String, groupName: String) -> String { ... }
    static func generateStyledQRCode(from data: String, size: CGFloat) -> UIImage? { ... }
}
```

### 必要なカラー定義

```swift
extension Color {
    static let brandGreen = Color(red: 0, green: 1, blue: 0.255)  // #00ff41
    static let brandBlack = Color(red: 0.05, green: 0.05, blue: 0.08)  // #0c0c0d
    static let brandDarkGray = Color(white: 0.15)
}
```

---

## 🎯 次のステップ

### 短期（1-2週間）

1. **リアルタイム同期** - Firebase Firestore で次に現像される写真を全ユーザーで同期
2. **プッシュ通知** - 写真が現像された瞬間に通知
3. **アニメーション強化** - 暗室モードの現像エフェクト

### 中期（1ヶ月）

1. **カメラ設定** - 露出、フォーカス、フラッシュの手動調整
2. **フィルムシミュレーション** - Kodak、Fujifilm風のカラープロファイル
3. **ギャラリーフィルター** - お気に入り、タグ、場所による絞り込み

### 長期（3ヶ月）

1. **ソーシャル機能** - 写真へのコメント、リアクション
2. **印刷サービス** - Printfulと連携してフォトブックを作成
3. **Apple Watch対応** - 現像カウントダウン表示

---

## 📚 参考資料

### SwiftUI カメラ実装
- [AVFoundation - Apple Developer](https://developer.apple.com/av-foundation/)
- [Building a Camera App](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture)

### 日付処理
- [Working with Dates and Times](https://developer.apple.com/documentation/foundation/dates_and_times)

### SwiftData
- [SwiftData Overview](https://developer.apple.com/documentation/swiftdata)
- [Modeling Data with SwiftData](https://developer.apple.com/documentation/swiftdata/modeling-data)

---

## 🤝 サポート

質問や問題がある場合は、以下の情報を含めてIssueを作成してください:

- Xcodeバージョン
- iOS/iPadOSバージョン
- 再現手順
- エラーメッセージ（あれば）

---

## 📝 変更履歴

### v1.0.0 (2026-05-28)
- ✅ アナログカメラUI実装（3:2ビューファインダー + フィルムカウンター）
- ✅ 暗室待機モード実装（Next-to-Reveal写真プレビュー + タイマー）
- ✅ 強化されたギャラリーUI（複数グループ管理 + 弧状ダイヤル）
- ✅ Circle管理画面実装（招待共有 + Doneボタン正常化）
- ✅ QRスキャナー強化（My QR Code ボタン追加）

---

## 📄 ライセンス

MIT License - 自由に使用、変更、配布が可能です。

---

🎉 **実装完了！**

これで「later」のコア体験である「時間差の現像」が視覚的に表現され、ユーザーは次に現像される写真を待機する暗室モードで、期待感を高めることができます。

Enjoy developing! 📸✨
