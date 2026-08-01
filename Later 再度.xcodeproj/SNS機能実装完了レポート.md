# SNS機能実装完了レポート - ステップ3

## 📋 実装概要

このレポートは、Later アプリにおけるSNS機能（QRコード生成・スキャン、ユーザー検索、フォロー管理）の完全な実装について記述します。

---

## ✅ 実装された機能

### 1. QRコード生成機能
- **ファイル**: `QRCodeGenerator.swift`, `MyQRCodeView.swift`
- **技術**: CoreImage の `CIQRCodeGenerator`
- **機能概要**:
  - ユーザーID（UUID）を含むQRコードを生成
  - カスタムURLスキーム対応: `laterapp://user?id=xxx&name=xxx`
  - 高解像度QRコード生成（最大1000x1000px）
  - テーマカラーに応じた枠線デザイン
  - 写真アルバムへの保存機能
  - ユーザーIDのクリップボードコピー機能

**主な関数**:
```swift
QRCodeGenerator.generateQRCode(from: String, size: CGFloat) -> UIImage?
QRCodeGenerator.createQRData(userID: String, userName: String?) -> String
```

---

### 2. QRスキャナー機能
- **ファイル**: `QRScannerView.swift`
- **技術**: AVFoundation
- **機能概要**:
  - カメラを使用したリアルタイムQRコードスキャン
  - カメラ権限の適切な処理
  - スキャンエリアのビジュアルガイド表示
  - トーチ（フラッシュライト）切り替え機能
  - スキャン成功時のハプティクスフィードバック
  - スキャン後、即座にユーザープロフィール画面へ遷移

**重要な注意事項**:
```
⚠️ Info.plistへの追加が必要
Key: Privacy - Camera Usage Description (NSCameraUsageDescription)
Value: QRコードをスキャンして友達を追加するためにカメラを使用します
```

**エラーハンドリング**:
- カメラ権限が拒否された場合: 設定画面へのリンクを表示
- カメラデバイスが見つからない場合: エラーログを出力
- QRコードの形式が不正な場合: ログに警告を表示

**主なクラス**:
```swift
struct QRScannerView: View
class QRCodeCameraPreviewView: UIView
enum CameraPermission { authorized, denied, notDetermined }
```

---

### 3. ユーザー検索機能
- **ファイル**: `ConnectionsView.swift`, `UserMockData.swift`
- **技術**: SwiftUI の `.searchable()` モディファイア
- **機能概要**:
  - ナビゲーションバーに統合された検索バー
  - ユーザー名、@ID、バイオでの検索
  - リアルタイムフィルタリング
  - 検索結果の件数表示
  - 空の状態の適切な処理

**モックデータベース**:
```swift
class MockUserDatabase {
    static let shared = MockUserDatabase()
    let users: [MockUser] = [20人のユーザーデータ]
    
    func searchUsers(query: String) -> [MockUser]
    func getUserByID(_ id: String) -> MockUser?
    func getRecommendedUsers(excludingIDs: [String], count: Int) -> [MockUser]
}
```

---

### 4. フォロー管理機能
- **ファイル**: `FollowingManager.swift`
- **技術**: UserDefaults、@Observable、Swift Concurrency
- **機能概要**:
  - フォロー/フォロー解除のトグル機能
  - フォロー状態の永続化（UserDefaults）
  - フォロー中ユーザーのリスト管理
  - リアルタイムでのUI更新
  - フォロー数のカウント表示

**主なAPI**:
```swift
class FollowingManager {
    static let shared = FollowingManager()
    
    func isFollowing(userID: String) -> Bool
    func follow(userID: String) -> Bool
    func unfollow(userID: String) -> Bool
    func toggleFollow(userID: String) -> Bool
    
    var allFollowingIDs: [String]
    var followingCount: Int
}
```

**データ永続化**:
- UserDefaultsキー: `"followingUserIDs"`
- データ形式: JSON エンコードされた `[String]`
- 自動保存: フォロー状態変更時に即座に保存

---

### 5. ユーザープロフィール詳細画面
- **ファイル**: `UserProfileDetailView.swift`
- **機能概要**:
  - プロフィール画像、名前、@ID、バイオの表示
  - 統計情報（投稿数、フォロワー数、フォロー中の数）
  - フォロー/フォロー中ボタン
  - メッセージボタン（将来実装用）
  - スムーズなアニメーション効果

---

## 📁 ファイル構成

### 新規作成ファイル
1. `QRCodeGenerator.swift` - QRコード生成ロジック
2. `MyQRCodeView.swift` - マイQRコード表示画面
3. `QRScannerView.swift` - QRスキャナー画面
4. `UserProfileDetailView.swift` - ユーザープロフィール詳細画面

### 更新ファイル
1. `ConnectionsView.swift` - 検索機能とQRスキャン統合
2. `ProfileView.swift` - マイQRコードボタンの追加

### 既存の依存ファイル
1. `FollowingManager.swift` - フォロー管理
2. `UserMockData.swift` - モックユーザーデータベース
3. `ShareSheet.swift` - 共有機能
4. `AppTheme.swift` - テーマカラー定義

---

## 🎯 使用方法

### 1. QRコード生成
```swift
// ProfileViewから
1. プロフィール画面を開く
2. ヘッダーのQRコードアイコンボタンをタップ
   または
   設定リストの「マイQRコード」をタップ
3. QRコードが表示される
4. 「QRコードを保存」または「IDをコピー」
```

### 2. QRコードスキャン
```swift
// ConnectionsViewから
1. Connections画面を開く
2. 上部の「QRコードでフォロー」バナーをタップ
   または
   ナビゲーションバーのQRアイコンをタップ
3. カメラが起動し、QRコードをスキャン
4. 自動的にユーザープロフィール詳細画面へ遷移
5. フォローボタンをタップしてフォロー
```

### 3. ユーザー検索
```swift
// ConnectionsViewから
1. Connections画面を開く
2. 検索バーにユーザー名または@IDを入力
3. リアルタイムで検索結果が表示される
4. ユーザーカードをタップしてプロフィール詳細を表示
5. フォローボタンでフォロー/フォロー解除
```

---

## 🔧 技術的詳細

### AVFoundation カメラセットアップ
```swift
// QRCodeCameraPreviewView.swift
private func setupCamera() {
    let session = AVCaptureSession()
    
    // カメラデバイス取得
    guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
        print("❌ カメラデバイスが見つかりません")
        return
    }
    
    // 入力設定
    guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
        print("❌ カメラ入力の作成に失敗しました")
        return
    }
    
    if session.canAddInput(videoInput) {
        session.addInput(videoInput)
    }
    
    // メタデータ出力設定
    let metadataOutput = AVCaptureMetadataOutput()
    if session.canAddOutput(metadataOutput) {
        session.addOutput(metadataOutput)
        metadataOutput.metadataObjectTypes = [.qr]
        metadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
    }
    
    // プレビューレイヤー設定
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.frame = bounds
    previewLayer.videoGravity = .resizeAspectFill
    layer.addSublayer(previewLayer)
}
```

### CoreImage QRコード生成
```swift
// QRCodeGenerator.swift
static func generateQRCode(from userID: String, size: CGFloat = 200) -> UIImage? {
    // CIQRCodeGeneratorフィルタを作成
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
        return nil
    }
    
    // 入力データをセット
    let data = Data(userID.utf8)
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel") // 15%エラー訂正
    
    // 出力画像を取得
    guard let outputImage = filter.outputImage else {
        return nil
    }
    
    // スケールアップ
    let scaleX = size / outputImage.extent.size.width
    let scaleY = size / outputImage.extent.size.height
    let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    
    // CIImageからUIImageに変換
    let context = CIContext()
    guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
        return nil
    }
    
    return UIImage(cgImage: cgImage)
}
```

### フォロー状態の永続化
```swift
// FollowingManager.swift
private func saveFollowingIDs() {
    if let encoded = try? JSONEncoder().encode(followingIDs) {
        userDefaults.set(encoded, forKey: storageKey)
    }
}

private func loadFollowingIDs() {
    if let data = userDefaults.data(forKey: storageKey),
       let decoded = try? JSONDecoder().decode([String].self, from: data) {
        followingIDs = decoded
    } else {
        followingIDs = []
    }
}
```

---

## 🎨 デザインガイドライン

### テーマカラー対応
すべてのUI要素は、ユーザーが選択したテーマカラーに対応しています：
- QRコードの枠線
- フォローボタン
- スキャンエリアのインジケーター
- アクセントカラー

### アニメーション
- プロフィール表示時のフェードイン・スケールアップ
- フォローボタンのバウンスエフェクト
- QRスキャンラインのアニメーション
- 検索結果のスムーズな表示

### ハプティクスフィードバック
- QRスキャン成功: `.success`
- フォロー/フォロー解除: `.medium`
- QRコード保存: `.success`

---

## 🐛 エラーハンドリング

### カメラ権限
```swift
enum CameraPermission {
    case authorized   // 許可済み
    case denied       // 拒否済み
    case notDetermined // 未確認
}

// 権限チェック
private func checkCameraPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        cameraPermission = .authorized
        
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermission = granted ? .authorized : .denied
            }
        }
        
    case .denied, .restricted:
        cameraPermission = .denied
        
    @unknown default:
        cameraPermission = .denied
    }
}
```

### QRコード形式エラー
```swift
// QRコードからユーザーIDを抽出
if let url = URL(string: code),
   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
   let queryItems = components.queryItems,
   let userID = queryItems.first(where: { $0.name == "id" })?.value {
    
    // 成功
    if let user = mockDB.getUserByID(userID) {
        selectedUser = user
        showingUserProfile = true
    } else {
        print("❌ ユーザーが見つかりませんでした: \(userID)")
    }
} else {
    print("❌ QRコードの形式が不正です")
}
```

---

## 📊 データフロー

### QRスキャンからフォローまでのフロー
```
1. ConnectionsView
   ↓ (QRスキャンボタンタップ)
2. QRScannerView
   ↓ (QRコード検出)
3. QRコード解析 (laterapp://user?id=xxx)
   ↓ (ユーザーID抽出)
4. MockUserDatabase.getUserByID()
   ↓ (ユーザー情報取得)
5. UserProfileDetailView
   ↓ (フォローボタンタップ)
6. FollowingManager.toggleFollow()
   ↓ (フォロー状態更新)
7. UserDefaults保存
   ↓ (UI更新)
8. ProfileView (フォロー数更新)
```

### 検索からフォローまでのフロー
```
1. ConnectionsView
   ↓ (検索バーに入力)
2. MockUserDatabase.searchUsers()
   ↓ (検索結果取得)
3. UserSearchResultRow表示
   ↓ (ユーザーカードタップ)
4. UserProfileDetailView
   ↓ (フォローボタンタップ)
5. FollowingManager.toggleFollow()
   ↓ (フォロー状態更新)
6. UI更新
```

---

## 🚀 将来の拡張可能性

### 1. リアルタイムフォロー同期
- Firebase Realtime Databaseとの統合
- フォロー状態のクラウド同期
- プッシュ通知連携

### 2. QRコードカスタマイズ
- ロゴやアイコンの埋め込み
- カラーQRコード
- ダイナミックQRコード（短縮URL使用）

### 3. 検索機能の拡張
- ファジー検索
- タグ検索
- 位置情報ベースの検索

### 4. フォロー機能の拡張
- フォローリクエスト（プライベートアカウント）
- 相互フォロー通知
- フォロワー管理画面

---

## 📝 テスト項目

### QRコード生成
- [ ] 正常なQRコードが生成される
- [ ] テーマカラーが正しく反映される
- [ ] 写真アルバムへの保存が成功する
- [ ] クリップボードコピーが機能する

### QRスキャナー
- [ ] カメラ権限のリクエストが正しく動作する
- [ ] QRコードが正常にスキャンされる
- [ ] トーチの切り替えが機能する
- [ ] 不正なQRコードが適切にエラー処理される

### ユーザー検索
- [ ] 検索バーに入力すると結果がフィルタリングされる
- [ ] 空の検索クエリでおすすめユーザーが表示される
- [ ] 検索結果の件数が正しく表示される

### フォロー管理
- [ ] フォローボタンで状態が切り替わる
- [ ] フォロー状態がUserDefaultsに保存される
- [ ] アプリ再起動後もフォロー状態が保持される
- [ ] フォロー数が正しくカウントされる

---

## 🎓 学習ポイント

### AVFoundation
- カメラセットアップとプレビュー表示
- メタデータ出力の設定
- QRコード検出のリアルタイム処理

### CoreImage
- CIFilterの使用方法
- QRコード生成の仕組み
- 画像のスケーリングとトランスフォーム

### SwiftUI
- `.searchable()` モディファイアの使用
- `UIViewRepresentable` でUIKitとの統合
- `@Observable` マクロでのステート管理

### データ永続化
- UserDefaultsでのカスタムデータ保存
- JSONエンコード・デコード
- シングルトンパターンの実装

---

## 🏁 まとめ

本実装により、Later アプリに以下の機能が追加されました：

✅ **QRコード生成**: ユーザーIDを含むQRコードの生成と共有
✅ **QRスキャナー**: カメラを使用したリアルタイムスキャン
✅ **ユーザー検索**: 名前・@IDでの検索機能
✅ **フォロー管理**: フォロー/フォロー解除と状態の永続化
✅ **プロフィール詳細**: ユーザー情報の表示とフォロー操作

すべてのコードは**省略なし**で実装され、適切な**エラーハンドリング**が含まれています。

**カメラ使用許可**:
Info.plistに `NSCameraUsageDescription` キーを追加してください。

---

**実装完了日**: 2026年5月22日
**バージョン**: v1.0.0
