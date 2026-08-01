# エラー修正ガイド

## 報告されているエラーの原因と解決方法

### 問題1: `@main` 属性の重複

**エラー:**
```
error: 'main' attribute can only apply to one type in a module
```

**原因:**
プロジェクト内に複数の `@main` エントリーポイントが存在しています。

**解決方法:**

1. 既存のAppファイル（例: `LaterApp.swift`）を探す
2. 以下のどちらかを選択:

#### オプションA: 新しいアプリを使用
```swift
// ModernPhotoAppMain.swift を使用する場合
// 既存の LaterApp.swift などから @main を削除

// 既存ファイルを修正:
// @main  ← この行を削除
struct LaterApp: App {
    // ...
}
```

#### オプションB: 既存アプリに統合
```swift
// 既存の @main App を残す場合
// ModernPhotoAppMain.swift の @main を削除

// ModernPhotoAppMain.swift を修正:
// @main  ← この行を削除
struct ModernPhotoApp: App {
    // ...
}

// そして既存の App で ModernMainContainerView を使用:
@main
struct LaterApp: App {
    var body: some Scene {
        WindowGroup {
            ModernMainContainerView()  // ← 新しいビューを使用
                .preferredColorScheme(.dark)
                .monitorGlobalRevealStatus()
                .monitorHeartbeat()
        }
    }
}
```

---

### 問題2: Combineのインポート

**エラー:**
```
error: Ambiguous implicit access level for import of 'Combine'
error: Instance method 'autoconnect()' is not available due to missing import
```

**原因:**
Combineのインポート方法が一貫していません。

**解決方法:**

すべてのファイルで統一:

```swift
// ✅ 推奨: 明示的にインポート
import Combine

// ❌ 避ける: import
import Combine
```

**該当ファイル:**
- `DevelopingPhotoView.swift`
- `GroupUnlockView.swift`
- `GlobalUnlockManager.swift`

**修正例:**
```swift
// Before
import SwiftUI
import Combine

// After
import SwiftUI
import Combine
```

---

### 問題3: GroupMember / GroupSessionManager の重複定義

**エラー:**
```
error: Invalid redeclaration of 'GroupMember'
error: 'GroupMember' is ambiguous for type lookup in this context
```

**原因:**
複数のファイルで同じ型が定義されています。

**解決方法:**

#### オプションA: 1つのファイルにまとめる
```swift
// GroupUnlockView.swift のみに定義を残し、他のファイルからは削除

// 他のファイルで使用する場合はインポート
// （同じモジュール内なら自動的に見える）
```

#### オプションB: 名前空間を使用
```swift
// 異なる名前空間に分ける
enum GroupUnlock {
    struct Member: Identifiable {
        // ...
    }
    
    class SessionManager: ObservableObject {
        // ...
    }
}

// 使用時
let member = GroupUnlock.Member(...)
```

#### オプションC: 新しいUIを使用（推奨）
```swift
// 古いGroupUnlockView.swift を削除または無効化し、
// 新しいModernHomeView.swift とグローバル解禁システムを使用
```

---

### 問題4: DevelopingPhotoView.swift のタイマー

**エラー:**
```
error: Instance method 'autoconnect()' is not available due to missing import
```

**解決方法:**

以下のように修正:

```swift
// Before
import SwiftUI
import Combine

// After
import SwiftUI
import Combine  // ← これを追加

struct DevelopingPhotoView: View {
    // ...
    
    var body: some View {
        // ...
        .task {
            // Swift Concurrency を使用
            for await _ in Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()  // ← これが動作する
                .values {
                currentTime = Date()
            }
        }
    }
}
```

---

## 🚀 推奨される修正手順

### ステップ1: Combineのインポートを統一

すべてのファイルで以下を確認:

```bash
# 検索して修正
# "import Combine" → "import Combine"
```

### ステップ2: @main の重複を解決

1つだけ `@main` を残す:

```swift
// 推奨: ModernPhotoAppMain.swift
@main
struct ModernPhotoApp: App {
    init() {
        setupApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ModernMainContainerView()
                .preferredColorScheme(.dark)
                .monitorGlobalRevealStatus()
                .monitorHeartbeat()
        }
    }
    
    private func setupApp() {
        _ = GlobalRevealNotificationHandler.shared
        GlobalRevealBackgroundSyncTask.shared.registerBackgroundTask()
        GlobalRevealBackgroundSyncTask.shared.scheduleNextBackgroundSync()
    }
}
```

### ステップ3: 重複定義を解決

古いファイルを削除または名前変更:

```swift
// オプション1: ファイル名を変更
GroupUnlockView.swift → GroupUnlockView_OLD.swift

// オプション2: ファイルを削除
// GroupUnlockView.swift を削除

// オプション3: コメントアウト
/*
struct GroupMember {
    // ...
}
*/
```

### ステップ4: ビルドして確認

```bash
# Xcodeでビルド
# Cmd + B

# エラーがなくなるまで繰り返し
```

---

## 📋 チェックリスト

- [ ] すべてのファイルで `import Combine` に統一
- [ ] `@main` は1つだけ
- [ ] `GroupMember` / `GroupSessionManager` の重複を解消
- [ ] ビルドが成功する
- [ ] プレビューが動作する
- [ ] 新しいUIが表示される

---

## 🔧 クイック修正スクリプト

以下のファイルを優先的に修正:

### 1. DevelopingPhotoView.swift
```swift
// Line 2-3
import SwiftUI
import Combine  // ← internal を削除
```

### 2. GroupUnlockView.swift
```swift
// ファイル全体をコメントアウトまたは削除
// （新しいModernHomeViewを使用するため）
```

### 3. GlobalUnlockManager.swift
```swift
// Line 2
import Foundation
import Combine  // ← internal を削除
```

### 4. ModernPhotoAppMain.swift
```swift
// @main を確認（これを残す）
@main
struct ModernPhotoApp: App {
    // ...
}
```

### 5. 他の @main を削除
```swift
// LaterApp.swift などから @main を削除
// @main  ← この行を削除
struct LaterApp: App {
    // ...
}
```

---

## ✅ 修正後の確認

### ビルド成功の確認
```
✅ Build Succeeded
✅ 0 errors
✅ 0 warnings (理想)
```

### プレビューの確認
```swift
#Preview {
    ModernMainContainerView()
}
```

### 実行の確認
- ホーム画面が表示される
- タブバーが表示される
- カメラボタンが機能する
- スワイプが動作する

---

## 📞 トラブルシューティング

### まだエラーが出る場合

1. **クリーンビルド**
   ```
   Shift + Cmd + K (Clean Build Folder)
   Cmd + B (Build)
   ```

2. **Derived Data を削除**
   ```
   Xcode > Preferences > Locations > Derived Data
   → フォルダを削除
   ```

3. **Xcode を再起動**
   ```
   Xcode を完全に終了して再起動
   ```

4. **ファイルの依存関係を確認**
   ```
   Project Navigator でファイルが正しくターゲットに含まれているか確認
   ```

---

**修正完了後、新しいモダンUIが完全に動作します！** 🎉
