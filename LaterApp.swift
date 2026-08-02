import SwiftUI
import SwiftData
import CloudKit

@main
struct LaterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // SwiftData自身のCloudKit自動同期は使わない(CloudKitManagerでCKRecord/CKShareを
    // 直接扱っているため)。entitlementsにiCloudコンテナがあると、指定しない限り
    // SwiftDataが自動でCloudKitミラーリングを有効化しようとし、起動時にクラッシュしうる。
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.sharedModelContainer)
    } // ← Scene を閉じるカッコ
} // ← App を閉じるカッコ


struct RootView: View {
    @State private var isSplashActive = true
    @State private var showGreenTransition = false
    @State private var cloudKitManager: CloudKitManager?

    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("photosTakenLastResetDate") private var lastResetDate: String = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    // 🎯 メインのセットアップ完了フラグ（初期値：false）
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    // Sign in with Apple 済みかどうか
    @AppStorage("appleUserID") private var appleUserID: String = ""

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
                    if appleUserID.isEmpty {
                        AppleSignInView()
                    } else if !isSetupCompleted {
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
            if newPhase == .active, !appleUserID.isEmpty {
                Task { await cloudKitManager?.handleRemoteNotification() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            resetIfNeeded()
        }
        .task(id: appleUserID) {
            // Sign in with Apple完了後に一度だけCloudKitManagerを起動する。
            guard !appleUserID.isEmpty else { return }
            if cloudKitManager == nil {
                cloudKitManager = CloudKitManager(modelContext: modelContext)
            }
            await cloudKitManager?.start()
        }
        .onReceive(ShareInviteInbox.shared.$pendingMetadata) { metadata in
            guard let metadata else { return }
            Task { await acceptSharedInvite(metadata: metadata) }
        }
    }

    /// 招待リンクをタップして起動した際にAppDelegateが受け取ったCKShare.Metadataを受け入れる。
    private func acceptSharedInvite(metadata: CKShare.Metadata) async {
        guard let cloudKitManager else { return }
        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            try await sharingService.acceptShare(metadata: metadata)
        } catch {
            print("RootView: failed to accept share: \(error)")
            ShareInviteInbox.shared.pendingMetadata = nil
            return
        }
        ShareInviteInbox.shared.pendingMetadata = nil

        guard let rootRecordName = metadata.hierarchicalRootRecordID?.recordName else { return }

        // 反映されたグループ(=このShareのルートレコード)に、自分のUserProfileをアップロードする。
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let user = UserProfile.current(from: profiles),
               let group = (try? modelContext.fetch(FetchDescriptor<LaterGroup>()))?.first(where: { $0.ckRecordName == rootRecordName }) {
                if !group.isMember(userID: user.id) {
                    _ = group.addMember(user)
                }
                sharingService.uploadOwnProfile(user, to: group)
                break
            }
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


