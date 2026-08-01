import SwiftUI

// ⚠️ このファイルは重複しています。LaterApp.swift を使用してください。
// 無効化されています。

#if false

@main
struct LaterApp: App {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.preferredLanguages.first?.hasPrefix("ja") == true ? "ja" : "en"
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: selectedLanguage))
        }
    }
}

#Preview("App - Japanese") {
    RootView()
        .environment(\.locale, Locale(identifier: "ja"))
}

#Preview("App - English") {
    RootView()
        .environment(\.locale, Locale(identifier: "en"))
}
#endif // false - LaterApp.swiftを使用

