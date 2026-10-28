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
        // 入れなおした直後は Application Support がまだ無く、CoreData が作る前に
        // 「Failed to stat path ... default.store」などの長い診断ログ(約1000行)を出す。害はないが、
        // 調査のじゃまになるので、先にフォルダを作っておく。
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        }
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
    /// 以前の1秒スプラッシュ(MinimalSplashView)。起動アニメーション(LaunchAnimation)をHomeの上で
    /// 再生するようになったため、もう出さない。
    @State private var isSplashActive = false
    @State private var cloudKitManager: CloudKitManager?
    @State private var sharedProfile: UserProfile?
    @State private var showingSharedProfile = false
    @State private var groupJoinAlertTitle = ""
    @State private var groupJoinAlertMessage = ""
    @State private var showingGroupJoinAlert = false
    @State private var isProcessingGroupJoin = false
    @State private var lastJoinedGroupName = ""
    /// 入るための画面(招待リンク・QR・合言葉)。どれから来ても、同じ「招待を受ける」画面に着く
    @State private var joinFlow: JoinFlowRequest?
    /// ログイン・初回設定の前にひらいた招待。終わったら、同じ招待にもどる
    @AppStorage("pendingInviteLink") private var pendingInviteLink: String = ""
    /// 初回設定のあと、一度だけ「招待されて来ましたか?」(コピーしたリンクを貼りつけて続きから)
    @AppStorage("invitePastePromptShown") private var invitePastePromptShown = false
    @State private var showingInvitePaste = false

    @AppStorage("photosTaken") private var photosTaken: Int = 0
    @AppStorage("photosTakenLastResetDate") private var lastResetDate: String = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeClock = ThemeClock()
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]

    private var userGroups: [LaterGroup] {
        guard let user = UserProfile.current(from: profiles) else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    // 🎯 メインのセットアップ完了フラグ（初期値：false）
    @AppStorage("isSetupCompleted") private var isSetupCompleted: Bool = false
    @AppStorage(OnboardingStorage.completedKey) private var onboardingCompleted = false
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

    /// Galleryでは撮影から7日(DailyExposureRules.photoRetentionDays)を過ぎた写真は
    /// 表示されなくなる仕様のため、表示されなくなった写真をローカル(SwiftData)に残し
    /// 続ける必要はない。保持期間を過ぎた写真はCloudKit側にも削除を伝えた上でローカルから
    /// 削除し、端末のストレージ肥大化を防ぐ(実際の判定はPhotoExpiryMaintenance参照)。
    private func pruneExpiredPhotos() {
        backfillExposureDays()
        PhotoExpiryMaintenance.pruneExpired(context: modelContext, cloudKitManager: cloudKitManager)
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
                ZStack {
                    // 初回設定の最後(ようこそ)の間は、Home を裏で用意しておく。
                    // 最後に玉の位置から円がひらいて、本物の Home が見える(同じ位置なので作りなおされない)。
                    if isSetupCompleted || onboardingCompleted {
                        MainNavigationView()
                    }
                    if !isSetupCompleted {
                        // 新規ユーザーの初回設定 v2(開幕・はじめる・ニックネーム・Laterの一日・
                        // 仕組みの問題・最初の1枚・預けました)。既存ユーザー(isSetupCompleted済み)は通らない。
                        OnboardingFlowView()
                    }
                }
                .transition(.opacity)
            }

            if isProcessingGroupJoin {
                groupJoinProgressOverlay
            }
        }
        .onAppear {
            // 初回起動(初回設定がまだ)は、起動アニメーションではなくオンボーディング。
            if !isSetupCompleted { LaunchCoordinator.hasPlayedInProcess = true }
            resetIfNeeded()
            ensurePersonalSpaceForCurrentUser()
            ensureWelcomeSeenForExistingUser()
            ensureSurveyCompletedForExistingUser()
            ensureAboutLaterIntroSeenForExistingUser()
            developProfilePhotoIfDue()
            backfillExposureDays()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("[PermPerf] App scenePhase \(oldPhase) → \(newPhase) setup=\(isSetupCompleted) onboarded=\(onboardingCompleted) splash=\(isSplashActive)")
            if newPhase == .active {
                resetIfNeeded()
                developProfilePhotoIfDue()
            }
            if newPhase == .active, isSignedIn {
                Task { await cloudKitManager?.handleRemoteNotification() }
                Task { await cloudKitManager?.resendOwnUnlockedPhotosIfNeeded() }
                ensurePersonalSpaceForCurrentUser()
            }
            if newPhase == .background {
                // 次にアプリを開かなくても、iOSのバックグラウンド更新のタイミングで
                // 期限切れ写真の片付け(BackgroundMaintenance)が走るよう申請し直す。
                BackgroundMaintenance.schedule()
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
            // 抜けている最中に止まったグループを、続きから(二重には実行しない)
            await GroupLeaveService.resumePending(context: modelContext)
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
                // 初回設定の画面を「確認中」にする。同じ端末でリンクを開けた場合(pendingEmailが
                // 残っている)は、ここでそのままサインインを完了する。別の端末で開いた場合は、
                // 初回設定の画面で同じアドレスを入れ直してもらう(emailSignInLinkFailed)。
                NotificationCenter.default.post(name: .emailSignInLinkOpened, object: nil)
                guard let email = FirebaseAuthService.pendingEmail else {
                    NotificationCenter.default.post(name: .emailSignInLinkFailed, object: nil)
                    return
                }
                Task {
                    do {
                        let result = try await FirebaseAuthService.completeSignIn(withLink: url.absoluteString, email: email)
                        UserDefaults.standard.set(result.email ?? email, forKey: "firebaseEmail")
                        firebaseUID = result.uid
                    } catch {
                        print("[Firebase] onOpenURL経由のサインイン完了に失敗: \(error)")
                        NotificationCenter.default.post(name: .emailSignInLinkFailed, object: error)
                    }
                }
                return
            }
            // ウィジェット・コントロール・ライブアクティビティ:later://widget/<U|R|D|M>
            // U → 撮影へ(タグ選び)/ R → Home(月を長押しで昨日をひらく)/ D・M → Home
            if url.scheme == "later", url.host == "widget" {
                NotificationCenter.default.post(name: .photoNotificationTapped, object: nil)
                if url.lastPathComponent == LaterWidgetPhase.U.rawValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        CaptureRequestStore.shared.pendingRequestID = UUID()
                    }
                }
                return
            }
            // 招待リンク(later://join)・素の CKShare URL(LINE などから、OS の受け入れ経路が動かなかったとき)
            if let shareURL = InviteConfig.shareURL(from: url) {
                handleInviteLink(shareURL)
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
            if let shareURL = InviteConfig.shareURL(from: url) {
                handleInviteLink(shareURL)
            }
        }
        .sheet(isPresented: $showingSharedProfile) {
            if let sharedProfile {
                UserDetailView(user: sharedProfile)
            }
        }
        .fullScreenCover(item: $joinFlow) { request in
            JoinFlowView(start: request.start) { joinFlow = nil }
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingInvitePaste) {
            InvitePasteSheet { shareURL in
                showingInvitePaste = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { handleInviteLink(shareURL) }
            } onDismiss: {
                showingInvitePaste = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .joinFlowRequested)) { note in
            joinFlow = JoinFlowRequest(start: note.object as? JoinFlowStart ?? .scan)
        }
        .onChange(of: isSetupCompleted) { _, completed in
            guard completed else { return }
            if let shareURL = URL(string: pendingInviteLink) {
                pendingInviteLink = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { handleInviteLink(shareURL) }
            } else if !invitePastePromptShown {
                invitePastePromptShown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { showingInvitePaste = true }
            }
        }
        .alert(groupJoinAlertTitle, isPresented: $showingGroupJoinAlert) {
            Button("OK") {}
        } message: {
            Text(groupJoinAlertMessage)
        }
        // アプリ全体の外観は、時刻(昼/夜)で決める唯一の場所。他の画面では preferredColorScheme を使わない。
        .background(Palette.for(themeClock.mode).bg.ignoresSafeArea())
        .environment(themeClock)
        .environment(\.palette, Palette.for(themeClock.mode))
        .preferredColorScheme(themeClock.mode == .night ? .dark : .light)
        .onAppear { themeClock.start() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { themeClock.refresh() }
        }
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

    /// 招待リンク・QR・合言葉から来た CKShare の URL → 招待を受ける画面
    private func handleInviteLink(_ shareURL: URL) {
        guard isSignedIn, isSetupCompleted else {
            // ログイン・初回設定のあとで、同じ招待にもどる
            pendingInviteLink = shareURL.absoluteString
            return
        }
        invitePastePromptShown = true
        joinFlow = JoinFlowRequest(start: .link(shareURL))
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



