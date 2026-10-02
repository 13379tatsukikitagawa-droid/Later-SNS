import SwiftUI
import SwiftData
import CloudKit

@main
struct LaterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // 起動時刻をアプリコード内で可能な限り早く記録する(AppLaunchTiming.processStartは
        // static letなので、ここで最初にアクセスした瞬間の時刻が記録される)。
        _ = AppLaunchTiming.processStart
    }

    // SwiftData自身のCloudKit自動同期は使わない(CloudKitManagerでCKRecord/CKShareを
    // 直接扱っているため)。entitlementsにiCloudコンテナがあると、指定しない限り
    // SwiftDataが自動でCloudKitミラーリングを有効化しようとし、起動時にクラッシュしうる。
    static let sharedModelContainer: ModelContainer = {
        let token = PerformanceSignpost.begin("App.ModelContainerInit")
        let schema = Schema([LaterPhoto.self, LaterGroup.self, UserProfile.self, PhotoVote.self, BlockedUser.self, ExposureDay.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            // ここの所要時間がデータ蓄積量(端末内のLaterPhoto/LaterGroup件数)と共に
            // 伸びていないかを確認するための計測(要調査項目3)。
            PerformanceSignpost.end("App.ModelContainerInit", token)
            return container
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
    /// 既存のスプラッシュは、サインイン済みの起動でだけ出す。未サインイン(=新規)の起動では、
    /// 初回設定(OnboardingFlowView)の開幕がスプラッシュの代わりになる。
    @State private var isSplashActive = RootView.launchedSignedIn
    @State private var cloudKitManager: CloudKitManager?
    @State private var sharedProfile: UserProfile?
    @State private var showingSharedProfile = false
    @State private var groupJoinAlertTitle = ""
    @State private var groupJoinAlertMessage = ""
    @State private var showingGroupJoinAlert = false
    @State private var isProcessingGroupJoin = false
    @State private var lastJoinedGroupName = ""

    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("photosTakenLastResetDate") private var lastResetDate: String = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]

    private var userGroups: [LaterGroup] {
        guard let user = UserProfile.current(from: profiles) else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    // 🎯 メインのセットアップ完了フラグ（初期値：false）
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    // Sign in with Apple 済みかどうか
    @AppStorage("appleUserID") private var appleUserID: String = ""
    // メールのマジックリンク(Firebase Authentication)でサインイン済みかどうか。
    // Sign in with Appleとは独立した、もう一つのサインイン手段(EmailSignInView参照)。
    @AppStorage("firebaseUID") private var firebaseUID: String = ""
    // 初回起動・ウェルカムオンボーディング(WelcomeOnboardingView)を見たかどうか。
    // 事前アンケートゲート画面よりさらに前、アプリの一番最初に一度だけ表示する。
    @AppStorage("hasSeenWelcomeOnboarding") private var hasSeenWelcomeOnboarding: Bool = false
    // 事前アンケートゲート画面への回答有無(自己申告制)。プロフィール設定画面より前に表示する。
    @AppStorage("hasCompletedSurvey") private var hasCompletedSurvey: Bool = false
    // プロフィール設定完了(OnboardingViewの「Laterをはじめる」)直後、Later紹介サイトへの
    // 導線画面(LaterAboutIntroView)を見た/スキップしたかどうか。
    @AppStorage("hasSeenAboutLaterIntro") private var hasSeenAboutLaterIntro: Bool = false

    private static var launchedSignedIn: Bool {
        let defaults = UserDefaults.standard
        return !(defaults.string(forKey: "appleUserID") ?? "").isEmpty || !(defaults.string(forKey: "firebaseUID") ?? "").isEmpty
    }

    /// 初回設定で撮ったプロフィール画像は、次の9:00を過ぎたら現像(反映)する。
    private func developProfilePhotoIfDue() {
        guard let user = UserProfile.current(from: profiles) else { return }
        ProfilePhotoDevelopment.promoteIfDue(user, context: modelContext)
    }

    /// 写真は7日で削除されるため、削除される前に「預けた日々」の記録を作っておく。
    private func backfillExposureDays() {
        guard let user = UserProfile.current(from: profiles) else { return }
        ExposureDayStore.backfill(for: user, context: modelContext)
    }

    /// Sign in with Apple・メールのマジックリンクいずれかでサインイン済みかどうか。
    /// 以降のゲート判定(appleUserID.isEmptyだけを見ていた箇所)は全てこちらに揃える。
    private var isSignedIn: Bool {
        !appleUserID.isEmpty || !firebaseUID.isEmpty
    }

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

    /// この機能追加より前にオンボーディング済みだったユーザーにも、個人用スペース「ME」を
    /// 遡って付与する。ensurePersonalSpaceは冪等なので、何度呼んでも重複作成しない。
    private func ensurePersonalSpaceForCurrentUser() {
        guard isSignedIn, let user = UserProfile.current(from: profiles) else { return }
        LaterGroup.ensurePersonalSpace(for: user, context: modelContext)
        try? modelContext.save()
    }

    /// アンケートゲート画面の追加より前からプロフィール設定が完了していた既存ユーザーには
    /// ゲート画面を出さない。isSetupCompletedが既にtrueなら、そのままhasCompletedSurveyも
    /// trueとして扱う(表示分岐自体もisSetupCompleted済みならゲートを素通りするが、
    /// フラグの実態も合わせておくことで以降の判定が常に正しい状態になる)。
    private func ensureSurveyCompletedForExistingUser() {
        guard isSetupCompleted, !hasCompletedSurvey else { return }
        hasCompletedSurvey = true
    }

    /// WelcomeOnboardingViewの追加より前からプロフィール設定が完了していた既存ユーザーには、
    /// 次回起動時に突然この画面を出さない(ensureSurveyCompletedForExistingUserと同じ方針)。
    private func ensureWelcomeSeenForExistingUser() {
        guard isSetupCompleted, !hasSeenWelcomeOnboarding else { return }
        hasSeenWelcomeOnboarding = true
    }

    /// LaterAboutIntroViewの追加より前からプロフィール設定が完了していた既存ユーザーには、
    /// 次回起動時に突然この画面を出さない(ensureSurveyCompletedForExistingUserと同じ方針)。
    private func ensureAboutLaterIntroSeenForExistingUser() {
        guard isSetupCompleted, !hasSeenAboutLaterIntro else { return }
        hasSeenAboutLaterIntro = true
    }

    /// Galleryでは撮影から7日を過ぎた写真は表示されなくなる仕様のため、表示されなくなった
    /// 写真をローカル(SwiftData)に残し続ける必要はない。保持期間を過ぎた写真は
    /// CloudKit側にも削除を伝えた上でローカルから削除し、端末のストレージ肥大化を防ぐ。
    private static let photoRetentionDays = 7

    private func pruneExpiredPhotos() {
        backfillExposureDays()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -Self.photoRetentionDays, to: Date()) else { return }
        let descriptor = FetchDescriptor<LaterPhoto>(predicate: #Predicate<LaterPhoto> { $0.captureDate < cutoff })
        guard let expiredPhotos = try? modelContext.fetch(descriptor), !expiredPhotos.isEmpty else { return }
        for photo in expiredPhotos {
            cloudKitManager?.markForDelete(photo: photo)
            modelContext.delete(photo)
        }
        try? modelContext.save()
    }


    var body: some View {
        ZStack {
            if isSplashActive {
                // シャッター&ネオン露光の1秒スプラッシュ。内部で0.0-1.0秒のシーケンスを
                // 自走式に進行し、完了した瞬間にonFinishedを1回だけ呼ぶ。
                MinimalSplashView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isSplashActive = false
                    }
                }
                .transition(.opacity)
            } else {
                // メインコンテンツ
                Group {
                    if !isSetupCompleted {
                        // 新規ユーザーの初回設定(開幕・サインイン・名前・説明・タグ・約束・
                        // プロフィール撮影・通知)。既存ユーザー(isSetupCompleted済み)は通らない。
                        OnboardingFlowView()
                    } else {
                        MainNavigationView()
                    }
                }
                .transition(.opacity)
            }

            if isProcessingGroupJoin {
                groupJoinProgressOverlay
            }
        }
        .onAppear {
            resetIfNeeded()
            ensurePersonalSpaceForCurrentUser()
            ensureWelcomeSeenForExistingUser()
            ensureSurveyCompletedForExistingUser()
            ensureAboutLaterIntroSeenForExistingUser()
            developProfilePhotoIfDue()
            backfillExposureDays()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                resetIfNeeded()
                developProfilePhotoIfDue()
            }
            if newPhase == .active, isSignedIn {
                Task { await cloudKitManager?.handleRemoteNotification() }
                Task { await cloudKitManager?.resendOwnUnlockedPhotosIfNeeded() }
                ensurePersonalSpaceForCurrentUser()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            resetIfNeeded()
            pruneExpiredPhotos()
        }
        .task(id: appleUserID + firebaseUID) {
            // Sign in with Apple・メールのマジックリンクいずれかの完了後に
            // 一度だけCloudKitManagerを起動する。
            guard isSignedIn else { return }
            if cloudKitManager == nil {
                cloudKitManager = CloudKitManager(modelContext: modelContext)
            }
            await cloudKitManager?.start()
            await cloudKitManager?.resendOwnUnlockedPhotosIfNeeded()
            await ModerationService.refreshBlockedUsersIfNeeded(modelContext: modelContext)
            pruneExpiredPhotos()
        }
        .onReceive(ShareInviteInbox.shared.$pendingMetadata) { metadata in
            guard let metadata else { return }
            Task {
                // OSがCKShare招待を直接受け入れた場合(userDidAcceptCloudKitShareWith経由、
                // 招待リンクの本来の主経路)。これまでこの経路には成功/失敗どちらの
                // 画面フィードバックも無く、コンソールログのみだったため、他の経路
                // (later://join / 素のicloud.com URL)と同じアラートを表示するようにする。
                withAnimation { isProcessingGroupJoin = true }
                let failureReason = await acceptSharedInvite(metadata: metadata)
                withAnimation { isProcessingGroupJoin = false }
                if let failureReason {
                    presentGroupJoinAlert(title: "参加できませんでした", message: failureReason)
                } else {
                    presentGroupJoinAlert(title: "参加しました", message: "「\(lastJoinedGroupName)」に参加しました！")
                }
            }
        }
        .onOpenURL { url in
            if FirebaseAuthService.isSignInLink(url) {
                // 同じ端末でリンクを開けた場合(pendingEmailが残っている)は、ここで
                // そのままサインインを完了できる。別端末で開いた場合はEmailSignInView側の
                // 手動貼り付け欄で完了してもらう(pendingEmailが無いため、ここでは何もしない)。
                if let email = FirebaseAuthService.pendingEmail {
                    Task {
                        do {
                            let result = try await FirebaseAuthService.completeSignIn(withLink: url.absoluteString, email: email)
                            firebaseUID = result.uid
                        } catch {
                            print("[Firebase] onOpenURL経由のサインイン完了に失敗: \(error)")
                        }
                    }
                }
                return
            }
            if let shareURL = GroupJoinLink.extractShareURL(from: url) {
                handleGroupJoinLink(shareURL: shareURL)
            } else if GroupJoinLink.isCKShareURL(url) {
                // LINE/メールなどから、later://でラップされていない素のCKShare URLが
                // そのままonOpenURLに渡ってきたケース(OS標準のCKShare受け入れ経路が
                // 何らかの理由で発火しなかった場合のフォールバック)。
                print("[Group Join] onOpenURLで素のCKShare URLを受信: \(url.absoluteString)")
                handleGroupJoinLink(shareURL: url)
            } else {
                handleIncomingProfileLink(url)
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            // Universal Link経由でCKShare URLが渡ってきた場合の保険。CKShare URLは
            // Appleのicloud.comドメインのため通常この経路は使われないはずだが、
            // OSの挙動差異に備えて同じ処理へフォールバックできるようにしておく。
            guard let url = activity.webpageURL else { return }
            print("[Group Join] onContinueUserActivity(BrowsingWeb)受信: \(url.absoluteString)")
            if GroupJoinLink.isCKShareURL(url) {
                handleGroupJoinLink(shareURL: url)
            }
        }
        .sheet(isPresented: $showingSharedProfile) {
            if let sharedProfile {
                UserDetailView(user: sharedProfile)
            }
        }
        .alert(groupJoinAlertTitle, isPresented: $showingGroupJoinAlert) {
            Button("OK") {}
        } message: {
            Text(groupJoinAlertMessage)
        }
        // アプリ全体を常時ダークテーマに固定する。実機のシステム外観設定(ライト/ダーク)に
        // 関わらず、ネイティブのLiquid Glassタブバー等が明るい配色へ自動的に
        // 切り替わってしまうのを防ぐ。
        .preferredColorScheme(.dark)
    }

    /// laterapp://user?id=...&name=... 形式のリンク(ProfileViewのシェア/MyQRCodeViewの
    /// QRコードと共通のフォーマット)を受け取る。既知のUserProfileがあればそれを、
    /// 無ければ名前だけの仮プロフィールをその場で作成してプロフィール詳細画面を即座に開き、
    /// 裏でUserDirectoryService(Public DB)から本当のユーザー名・アイコンを取得できれば
    /// 上書きする(相手が一度もプロフィールを保存/編集していない場合は取得できないまま)。
    private func handleIncomingProfileLink(_ url: URL) {
        guard let parsed = QRCodeGenerator.parseUserQRData(url.absoluteString),
              let id = UUID(uuidString: parsed.id) else { return }

        let profile: UserProfile
        if let existing = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first(where: { $0.id == id }) {
            profile = existing
        } else {
            let placeholder = UserProfile(name: parsed.name, username: "")
            placeholder.id = id
            modelContext.insert(placeholder)
            try? modelContext.save()
            profile = placeholder
        }
        sharedProfile = profile
        showingSharedProfile = true

        Task {
            guard let directoryProfile = await UserDirectoryService.fetchProfile(id: id) else { return }
            if !directoryProfile.name.isEmpty { profile.name = directoryProfile.name }
            if !directoryProfile.username.isEmpty { profile.username = directoryProfile.username }
            if !directoryProfile.bio.isEmpty { profile.bio = directoryProfile.bio }
            if let avatarData = directoryProfile.avatarData { profile.profileImageData = avatarData }
            try? modelContext.save()
        }
    }

    /// 招待リンクをタップして起動した際にAppDelegate/SceneDelegateが受け取ったCKShare.Metadataを
    /// 受け入れる。GroupSharingService.acceptShare自体が、rootRecordのピンポイント直接フェッチ→
    /// ゾーン全体フェッチ→(それでも反映されない場合の)プレースホルダー作成、の3段構えで
    /// 「returnする時点で必ずローカルにグループが存在する」ことを保証しているため、
    /// ここではポーリング/リトライを一切行わず1回だけ確認する。
    /// 参加に成功した場合はGroupSelectionStore/lastJoinedGroupNameを更新し、呼び出し側が
    /// Home画面への反映とグループ名入りの成功メッセージを組み立てられるようにする。
    /// 戻り値はnilなら成功、文字列なら失敗理由(呼び出し側がそのままアラートに表示できる)。
    /// acceptShare自体が失敗した(iCloud未ログイン・期限切れ等)場合を除き、
    /// 「反映に時間がかかっています」のようなタイムアウト文言は返さない。
    @discardableResult
    private func acceptSharedInvite(metadata: CKShare.Metadata) async -> String? {
        guard let cloudKitManager else {
            print("[CKShare Accept] acceptSharedInvite中断: cloudKitManagerが未初期化")
            return "iCloudへの接続が完了していません。しばらくしてから再度お試しください。"
        }
        let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)
        do {
            try await sharingService.acceptShare(metadata: metadata)
        } catch {
            // GroupSharingError.acceptFailed(underlying:)はLocalizedErrorとして、
            // iCloud未ログイン・期限切れなど実際のCKErrorの説明を含んだ文言を返す。
            let reason = error.localizedDescription
            print("[CKShare Accept] RootView.acceptSharedInvite: 受諾失敗 \(reason)")
            ShareInviteInbox.shared.pendingMetadata = nil
            return reason
        }
        ShareInviteInbox.shared.pendingMetadata = nil

        let rootRecordName = metadata.hierarchicalRootRecordID?.recordName
        if let rootRecordName,
           let user = UserProfile.current(from: profiles),
           let group = (try? modelContext.fetch(FetchDescriptor<LaterGroup>()))?.first(where: { $0.ckRecordName == rootRecordName }) {
            if !group.isMember(user) {
                _ = group.addMember(user)
            }
            // uploadOwnProfile自体が内部でCKSyncEngineへの送信を強制するため、
            // ここで別途sendPendingChangesNow()を呼ぶ必要はない。
            await sharingService.uploadOwnProfile(user, to: group)
            print("[CKShare Accept] RootView.acceptSharedInvite: グループ「\(group.name)」への参加完了")
            GroupSelectionStore.shared.selectedGroupID = group.id
            lastJoinedGroupName = group.name
            return nil
        }

        // acceptShare自体は成功しているため、ここに来るのは極めて稀(rootRecordIDが
        // 取れなかった等)。それでもタイムアウトアラートは出さず、成功として扱う
        // (バックグラウンドの同期が追いつき次第、画面には自動的に反映される)。
        print("[CKShare Accept] RootView.acceptSharedInvite: ローカルへの反映を確認できなかったが、成功として扱う(rootRecordName=\(rootRecordName ?? "nil"))")
        lastJoinedGroupName = (metadata.share[CKShare.SystemFieldKey.title] as? String) ?? "グループ"
        return nil
    }

    /// later://join?shareUrl=... 形式のグループ招待リンクを受け取った際の処理。
    /// CKShare標準URLをGroupSharingService.resolveShareMetadata/acceptShareへそのまま渡すことで、
    /// CloudKit連携ロジック自体は既存のものを完全に再利用する。
    private func handleGroupJoinLink(shareURL: URL) {
        print("[Group Join] later://join受信: shareUrl=\(shareURL.absoluteString)")

        guard let cloudKitManager else {
            print("[Group Join] 中断: cloudKitManagerが未初期化")
            presentGroupJoinAlert(title: "iCloudへの接続が完了していません", message: "しばらくしてから、もう一度リンクを開いてください。")
            return
        }

        Task {
            withAnimation { isProcessingGroupJoin = true }
            defer { withAnimation { isProcessingGroupJoin = false } }

            let sharingService = GroupSharingService(container: cloudKitManager.container, modelContext: modelContext, cloudKitManager: cloudKitManager)

            let metadata: CKShare.Metadata
            do {
                metadata = try await sharingService.resolveShareMetadata(shareURLString: shareURL.absoluteString)
            } catch {
                print("[Group Join] shareMetadata解決失敗: \(error)")
                presentGroupJoinAlert(title: "グループが見つかりませんでした", message: "招待リンクが無効か、共有が取り消されている可能性があります。")
                return
            }

            // 既に参加済みのグループなら、受諾処理を再実行せず案内だけ出す。
            if let rootRecordName = metadata.hierarchicalRootRecordID?.recordName,
               let user = UserProfile.current(from: profiles),
               let existingGroup = (try? modelContext.fetch(FetchDescriptor<LaterGroup>()))?.first(where: { $0.ckRecordName == rootRecordName }),
               existingGroup.isMember(user) {
                print("[Group Join] 既に参加済み: group=\(existingGroup.name)")
                GroupSelectionStore.shared.selectedGroupID = existingGroup.id
                presentGroupJoinAlert(title: "すでに参加しています", message: "「\(existingGroup.name)」には既に参加済みです。")
                return
            }

            print("[Group Join] 未参加のため受諾処理を開始")
            if let failureReason = await acceptSharedInvite(metadata: metadata) {
                print("[Group Join] 参加処理失敗: \(failureReason)")
                presentGroupJoinAlert(title: "参加できませんでした", message: failureReason)
            } else {
                print("[Group Join] 参加処理成功")
                presentGroupJoinAlert(title: "参加しました", message: "「\(lastJoinedGroupName)」に参加しました！")
            }
        }
    }

    private func presentGroupJoinAlert(title: String, message: String) {
        groupJoinAlertTitle = title
        groupJoinAlertMessage = message
        showingGroupJoinAlert = true
    }

    /// 招待の受諾〜グループ反映の間、画面全体に薄く重ねるローディング表示。
    private var groupJoinProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("グループに参加しています…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.95))
            )
        }
        .transition(.opacity)
    }
}
// MARK: - 🎬 プレビュー

#Preview("メインアプリ") {
    RootView()
        .modelContainer(for: [LaterPhoto.self, LaterGroup.self, UserProfile.self])
}



