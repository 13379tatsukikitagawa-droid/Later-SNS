import SwiftUI
import SwiftData

@main
struct LaterApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // 🌟 ここで3つのデータを全て登録します
        .modelContainer(for: [LaterPhoto.self, LaterGroup.self, UserProfile.self])
    } // ← Scene を閉じるカッコ
} // ← App を閉じるカッコ


struct RootView: View {
    @State private var isSplashActive = true
    @State private var showGreenTransition = false

    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("photosTakenLastResetDate") private var lastResetDate: String = ""
    @Environment(\.scenePhase) private var scenePhase

    // 🎯 メインのセットアップ完了フラグ（初期値：false）
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false

    private func resetIfNeeded() {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        if lastResetDate != todayKey {
            photosTaken = 0
            lastResetDate = todayKey
        }
    }

    var body: some View {
        ZStack {
            if isSplashActive {
                // 新しいミニマル・スプラッシュ
                MinimalSplashView()
                    .transition(.opacity)
                    .onAppear {
                        // 3.5秒後に緑の光の遷移を開始
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                showGreenTransition = true
                            }
                            
                            // 緑の光が広がった後、メイン画面へ遷移
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    isSplashActive = false
                                }
                            }
                        }
                    }
            } else {
                // メインコンテンツ
                Group {
                    if !isSetupCompleted {
                        OnboardingView()
                    } else {
                        MainTabView()
                    }
                }
                .transition(.opacity)
            }
            
            // 緑の光の遷移エフェクト
            if showGreenTransition {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.4),
                                Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 600
                        )
                    )
                    .scaleEffect(showGreenTransition ? 3.0 : 0.1)
                    .opacity(showGreenTransition ? 0 : 1)
                    .animation(.easeOut(duration: 0.8), value: showGreenTransition)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { resetIfNeeded() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active { resetIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            resetIfNeeded()
        }
    }
}
// MARK: - 🎬 プレビュー

#Preview("メインアプリ") {
    RootView()
        .modelContainer(for: [LaterPhoto.self, LaterGroup.self, UserProfile.self])
}

#Preview("ギャラリー画面") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: LaterPhoto.self, UserProfile.self, LaterGroup.self,
        configurations: config
    )
    
    GalleryView()
        .modelContainer(container)
}


