import SwiftUI
import SwiftData

/// Home。画面の中身はHomeView(Step 2 + v2)で、ここはデータの用意・CloudKitの定期同期と、
/// 画面の下の「月」による切り替え(Home → タグ → 撮影、Home → 昨日を見る)を受け持つ。
///
/// 月の拡大と次の画面の登場を同じ時間軸で動かすため、標準の画面遷移は使わず、
/// Home・タグ(撮影)・昨日を見るを同じZStackに置いて、状態(Screen)で切り替える。
struct TodayView: View {
    /// 右上のアバター・左スワイプでProfileへ(MainNavigationViewが切り替える)
    var onOpenProfile: () -> Void = {}

    private enum Screen {
        case home, shoot, yesterday
    }

    @Environment(\.modelContext) private var context
    @Environment(\.selectedMainTabIndex) private var selectedMainTabIndex
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let homeTabIndex = 0

    @State private var screen: Screen = .home
    @State private var screenSize: CGSize = .zero
    /// 月のふくらみ(1 → 画面を満たす倍率)と、各層の不透明度
    @State private var moonScale: CGFloat = 1
    @State private var moonOpacity = 1.0
    @State private var moonTextOpacity = 1.0
    @State private var homeOpacity = 1.0
    @State private var bottomFadeOpacity = 1.0
    /// 月が動いている間は操作を受けつけない(二重のタップを防ぐ)
    @State private var isMoonAnimating = false
    /// タグ画面の各要素をずらして入れる時の、開始までの遅れ(nilなら演出なし)
    @State private var shootEntranceDelay: Double?
    @State private var holdModel = HoldGaugeModel()
    @State private var haptics = ExposureHaptics()
    /// 撮影画面(暗転したまま閉じる)から戻った直後に、Homeの上に一瞬だけ残す黒い幕。
    @State private var isShowingExposureVeil = false
    /// グループ作成(4ステップ)
    @State private var showingNewGroup = false
    /// Homeの円を、そのグループの点だけに絞っている時のグループ
    @State private var selectedGroupID: UUID?
    /// 長押しで昨日をひらいた日(ExposureDayStore.dayKey)。長押しは、その日の最初の1回だけ。
    @AppStorage("yesterdayOpenedDay") private var yesterdayOpenedDay: String = ""
    @AppStorage(AvatarBadge.pendingKey) private var avatarBadgePending: String = ""
    @AppStorage(AvatarBadge.acknowledgedKey) private var avatarBadgeAcknowledged: String = ""

    @Query private var profiles: [UserProfile]
    @Query private var groups: [LaterGroup]
    @Query(sort: \ExposureDay.captureDate, order: .reverse) private var exposureDays: [ExposureDay]
    @Bindable private var captureRequest = CaptureRequestStore.shared

    private var currentUser: UserProfile? {
        UserProfile.current(from: profiles)
    }

    private var userGroups: [LaterGroup] {
        guard let user = currentUser else { return [] }
        return groups.filter { $0.members.contains(where: { $0.id == user.id }) }
    }

    private var hasShotToday: Bool {
        guard let user = currentUser else { return false }
        return DailyExposureRules.hasShot(on: Date(), by: user)
    }

    private var myCaptureDates: [Date] {
        currentUser?.photos.map(\.captureDate) ?? []
    }

    /// MEを除いた、参加中のグループ
    private var sharedGroups: [LaterGroup] {
        userGroups.filter { !$0.isPersonalSpace }.sorted { $0.creationDate < $1.creationDate }
    }

    /// 件数だけを数える(昨日の写真の画像はHomeで取得しない)。ユーザー未確定の間は「—」。
    /// グループの輪をタップしている間は、そのグループの分だけ。
    private var yesterdayCount: Int? {
        guard currentUser != nil else { return nil }
        let target = selectedGroupID.flatMap { id in userGroups.filter { $0.id == id } } ?? userGroups
        return HomeState.yesterdayPhotoCount(in: target, now: Date())
    }

    private var openedToday: Bool {
        yesterdayOpenedDay == ExposureDayStore.dayKey(for: Date())
    }

    /// 今日より前で、最後に預けた1枚(写真は7日で消えるため、1日の記録も見る)。
    private var lastDepositBeforeToday: Date? {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let fromPhotos = myCaptureDates.filter { $0 < startOfToday }.max()
        let fromDays = exposureDays.first { $0.captureDate < startOfToday }?.captureDate
        return [fromPhotos, fromDays].compactMap { $0 }.max()
    }

    /// 自分の写真の主要な3色(端末内だけ。他人の写真の色は取得しない)
    private var tonesByDay: [String: [Color]] {
        var result: [String: [Color]] = [:]
        for day in exposureDays where !day.toneHexes.isEmpty {
            result[day.dayKey] = day.toneHexes.map { Color(hex: $0) }
        }
        return result
    }

    private func homeState(at now: Date) -> HomeState {
        HomeState.resolve(
            now: now,
            myCaptureDates: myCaptureDates,
            hasDeposited: !exposureDays.isEmpty || !myCaptureDates.isEmpty,
            openedToday: openedToday
        )
    }

    var body: some View {
        ZStack {
                Color.black.ignoresSafeArea()

                HomeView(
                    myCaptureDates: myCaptureDates,
                    hasDeposited: !exposureDays.isEmpty || !myCaptureDates.isEmpty,
                    lastDepositBeforeToday: lastDepositBeforeToday,
                    openedToday: openedToday,
                    yesterdayCount: yesterdayCount,
                    tonesByDay: tonesByDay,
                    groups: sharedGroups,
                    selectedGroupID: selectedGroupID,
                    isCovered: screen != .home || showingNewGroup,
                    holdModel: holdModel,
                    avatarImage: currentUser?.profileImageData.flatMap(UIImage.init(data:)),
                    avatarSeed: currentUser?.id,
                    showsAvatarBadge: !avatarBadgePending.isEmpty,
                    onOpenProfile: onOpenProfile,
                    onDevelopFinished: { key in
                        guard key != avatarBadgeAcknowledged, key != avatarBadgePending else { return }
                        avatarBadgePending = key
                    },
                    onSelectGroup: { group in selectedGroupID = group?.id },
                    onCreateGroup: { showingNewGroup = true }
                )
                .opacity(homeOpacity)
                .allowsHitTesting(screen == .home && !isMoonAnimating)

                switch screen {
                case .home:
                    EmptyView()
                case .shoot:
                    ShootFlowView(
                        hasShotToday: hasShotToday,
                        entranceDelay: shootEntranceDelay,
                        onCaptured: saveExposure,
                        onFinished: finishExposure,
                        onClose: shrinkMoonBack
                    )
                case .yesterday:
                    YesterdayPlaceholderView(onClose: shrinkMoonBack)
                }

                // 月のうしろの、画面の下から黒へのフェード(グループの段と月が混ざらないように)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .opacity(screen == .home ? bottomFadeOpacity : 0)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                // 月は画面の下端からの距離で置くため、セーフエリアを含む全画面の座標で配置する。
                GeometryReader { proxy in
                    moonLayer(size: proxy.size)
                        .onAppear { screenSize = proxy.size }
                        .onChange(of: proxy.size) { _, size in screenSize = size }
                }
                .ignoresSafeArea()

                if isShowingExposureVeil {
                    Color.black
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
        }
        .onAppear {
            AppLaunchTiming.reportHomeDisplayedIfNeeded()
            haptics.prepare()
        }
        .task {
            // Homeが見えている間だけ同期する。
            while !Task.isCancelled {
                if selectedMainTabIndex == Self.homeTabIndex {
                    await refreshAllGroups()
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        .fullScreenCover(isPresented: $showingNewGroup) {
            NewGroupFlowView { showingNewGroup = false }
        }
        .onChange(of: captureRequest.pendingRequestID) { _, newValue in
            guard newValue != nil else { return }
            captureRequest.pendingRequestID = nil
            if screen == .home, homeState(at: Date()).canShoot { expandMoon(to: .shoot) }
        }
    }

    // MARK: - 月

    private func moonLayer(size: CGSize) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let state = homeState(at: context.date)
            HomeMoon(
                mode: moonMode(for: state),
                screenSize: size,
                holdModel: holdModel,
                haptics: haptics,
                textOpacity: moonTextOpacity,
                isInteractive: screen == .home && !isMoonAnimating,
                onTap: {
                    if case .opened = state {
                        expandMoon(to: .yesterday)
                    } else if state.canShoot {
                        expandMoon(to: .shoot)
                    }
                },
                onHoldComplete: {
                    yesterdayOpenedDay = ExposureDayStore.dayKey(for: Date())
                    expandMoon(to: .yesterday)
                }
            )
            .scaleEffect(moonScale, anchor: .center)
            .position(MoonLayout.center(in: size))
            .opacity(moonOpacity)
            .allowsHitTesting(screen == .home && !isMoonAnimating)
        }
    }

    private func moonMode(for state: HomeState) -> HomeMoon.Mode {
        switch state {
        case .beforeOpening: return .dim(title: "9:00 に、はじまる")
        case .lightsOut: return .dim(title: "明日 9:00 に、はじまる")
        case .canShoot, .returning, .firstDay: return .tap(title: "今日を撮る", subtitle: "タグをつけて、撮影へ")
        case .shot: return .hold
        case .opened: return .tap(title: "昨日をもう一度見る", subtitle: "タップ")
        }
    }

    /// 月がふくらんで、次の画面になる(0.76秒で画面の四隅まで)。700msで次の画面を月のうしろに出し、
    /// そこから月の層がフェードアウトする。Reduce Motionの時は0.25秒のクロスフェード。
    private func expandMoon(to target: Screen) {
        guard !isMoonAnimating, screen == .home else { return }
        isMoonAnimating = true

        if reduceMotion {
            shootEntranceDelay = nil
            withAnimation(.easeInOut(duration: 0.25)) {
                screen = target
                homeOpacity = 0
                moonOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isMoonAnimating = false }
            return
        }

        let fullScale = MoonLayout.fullScale(in: screenSize)
        withAnimation(.easeOut(duration: 0.42)) { homeOpacity = 0 }
        withAnimation(.easeOut(duration: 0.3)) { bottomFadeOpacity = 0 }
        withAnimation(.easeOut(duration: 0.2)) { moonTextOpacity = 0 }
        withAnimation(.easeInOut(duration: 0.076)) { moonScale = 0.96 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.076) {
            withAnimation(.timingCurve(0.62, 0, 0.28, 1, duration: 0.684)) { moonScale = fullScale }
        }
        // 月が満ちる直前(550ms)に次の画面を月のうしろに置く(キーボードが上がりはじめる)。
        // タグ画面の各要素は、月が画面を満たす700msから、ずらして入れる。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            shootEntranceDelay = 0.15
            screen = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.52)) { moonOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.22) { isMoonAnimating = false }
    }

    /// 「×」で、月が縮んでHomeに戻る(640ms)。Homeの中身は、はじめの約35%は透明のまま、
    /// そのあとフェードイン。月の文字は500msの時点から表示する。入力中のタグは下書きとして残る。
    private func shrinkMoonBack() {
        guard !isMoonAnimating, screen != .home else { return }
        isMoonAnimating = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                screen = .home
                homeOpacity = 1
                moonOpacity = 1
                moonScale = 1
                moonTextOpacity = 1
                bottomFadeOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { isMoonAnimating = false }
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            moonScale = MoonLayout.fullScale(in: screenSize)
            moonOpacity = 1
            moonTextOpacity = 0
            screen = .home
        }
        withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.64)) { moonScale = 1 }
        withAnimation(.easeOut(duration: 0.455).delay(0.245)) { homeOpacity = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(0.34)) { bottomFadeOpacity = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) { moonTextOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { isMoonAnimating = false }
    }

    /// 複数グループをまたぐ画面なので、Private/Shared両DBの変更をまとめて取り込む。
    private func refreshAllGroups() async {
        guard let cloudKitManager = CloudKitManager.current else { return }
        await cloudKitManager.fetchSharedChangesNow()
        await cloudKitManager.fetchPrivateChangesNow()
        await cloudKitManager.resendOwnUnlockedPhotosIfNeeded()
    }

    // MARK: - 撮影した1枚の保存

    private func saveExposure(imageData: Data, exposureStart: Date, tags: [String], locationName: String?) -> Bool {
        guard let user = currentUser else { return false }
        do {
            try DailyExposureStore.save(
                imageData: imageData,
                captureDate: exposureStart,
                tags: tags,
                locationName: locationName,
                user: user,
                groups: userGroups,
                context: context
            )
            return true
        } catch {
            print("[PhotoSave Error] 撮影した1枚の保存に失敗: \(error)")
            return false
        }
    }

    /// 暗転画面を見せ終えた。黒い幕を残したまま撮影画面をアニメーションなしで外してHomeに戻し、
    /// 幕をゆっくり(0.6秒)フェードさせる。
    private func finishExposure() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingExposureVeil = true
            screen = .home
            moonScale = 1
            moonOpacity = 1
            moonTextOpacity = 1
            homeOpacity = 1
            bottomFadeOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) {
            isShowingExposureVeil = false
        }
    }
}

/// 「昨日を見る」の仮の画面。本当の画面(昨日の写真を見る・Today's Later)は後のStepで作る。
private struct YesterdayPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 10) {
                Text("昨日を見る")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("ここから Step 4・Step 3 で作ります。")
                    .font(.system(size: 13))
                    .foregroundStyle(HomePalette.subText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomePalette.subText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("閉じる")
            .padding(.leading, 8)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 画面状態

/// 画面中央のアクション要素(撮影ボタンが置かれる場所)の状態。GroupStatusPresenter.state(for:)と
/// 「個人の撮影上限に達しているか」の組み合わせで決まる。実際の描画分岐は
/// TodayShootingView側で行うため、
/// ここでは概念を明示するためのenumとして定義するに留める。
enum CaptureActionState: Equatable {
    case capture              // 撮影中・撮影可能
    case captureLimitReached  // 撮影中・個人の上限(GroupUnlockPolicy.individualMaximumPhotoCount)に到達済み
    case vote                 // 投票中
    case result                // 終了後
}
