import ActivityKit
import SwiftUI
import WidgetKit

// ウィジェットの設定(はじめの画面と置き方)。
// iOS の決まりで、アプリからウィジェットを勝手に置くこと・追加画面を直接ひらくことはできない。
// だから「置き方を教える」+「置けたか確認する」の2つで成り立つ。急かさない・ほめない。触覚はカードを選ぶときだけ。

enum WidgetSetupStorage {
    /// はじめの画面を見たか
    static let seenKey = "widgetSetupSeen"
    /// 「あとで」を選んだか
    static let skippedKey = "widgetSetupSkipped"
}

// MARK: - 場所と手順

enum WidgetPlace: CaseIterable, Identifiable {
    case home, lock, controls

    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "ホーム画面"
        case .lock: return "ロック画面"
        case .controls: return "下のボタン"
        }
    }

    var note: String {
        switch self {
        // 文の途中で折り返さないよう、文の切れ目で改行する
        case .home: return "小・中・大から選べます。\n景色のように見えます。"
        case .lock: return "時計の下や、日付のとなり。\n白だけで見えます。"
        case .controls: return "「撮る」「ひらく」。\n押すと、すぐ開きます。"
        }
    }

    var guideTitle: String { "\(title)に置く" }

    var icon: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .lock: return "lock"
        case .controls: return "button.horizontal"
        }
    }

    /// タイトルの横の小さなラベル(下のボタンだけ)
    var badge: String? { self == .controls ? "iOS 18〜" : nil }

    var steps: [WidgetGuideStep] {
        switch self {
        case .home:
            return [
                .init(title: "ホーム画面を、長押しする", body: "アイコンのない所を、1秒ほど押し続ける。", tip: "アイコンがゆれたら、できている。", scene: .homeGrid, target: CGPoint(x: 195, y: 560), label: "長押し(約1秒)", longPress: true),
                .init(title: "左上の「＋」を押す", body: "iOS 18 では「編集」と出る。そこから「ウィジェットを追加」を選ぶ。", tip: nil, scene: .homeEdit, target: CGPoint(x: 38, y: 72), label: "押す", longPress: false),
                .init(title: "「Later」を探す", body: "検索欄に「Later」と入れて、Later を押す。", tip: nil, scene: .homeSearch, target: CGPoint(x: 195, y: 262), label: "押す", longPress: false),
                .init(title: "大きさを選んで、追加する", body: "横にスワイプして、小・中・大から選ぶ。「ウィジェットを追加」を押す。", tip: nil, scene: .homeSizes, target: CGPoint(x: 195, y: 472), label: "押す", longPress: false, focusY: 372),
                .init(title: "置く場所を決めて、完了", body: "好きな場所へ動かし、右上の「完了」を押す。", tip: nil, scene: .homeDone, target: CGPoint(x: 346, y: 72), label: "押す", longPress: false),
            ]
        case .lock:
            return [
                .init(title: "ロック画面を、長押しする", body: "Face ID でロックを解いたあと、ホームへ進まずに画面を押し続ける。", tip: nil, scene: .lockScreen, target: CGPoint(x: 195, y: 410), label: "長押し(約1秒)", longPress: true, focusY: 300),
                .init(title: "「カスタマイズ」→「ロック画面」", body: "「ホーム画面」は壁紙の設定なので、まちがえない。", tip: nil, scene: .lockCustomize, target: CGPoint(x: 112, y: 420), label: "押す", longPress: false),
                .init(title: "時計の下の枠を押す", body: "日付のとなりの1行も、日付を押して置ける。", tip: nil, scene: .lockSlots, target: CGPoint(x: 195, y: 292), label: "押す", longPress: false),
                .init(title: "Later を選ぶ", body: "長方形・丸から選ぶ。枠は全部で4つ分。長方形は2つ分。", tip: "「長方形 + 丸 + 丸」がそろう。", scene: .lockPicker, target: CGPoint(x: 128, y: 640), label: "押す", longPress: false),
                .init(title: "完了を押す", body: "右上の「完了」。", tip: nil, scene: .lockDone, target: CGPoint(x: 346, y: 72), label: "押す", longPress: false),
            ]
        case .controls:
            return [
                .init(title: "下のボタンの「−」を押す", body: "入りかたは、ロック画面の 1・2 と同じ。", tip: nil, scene: .controlsMinus, target: CGPoint(x: 72, y: 742), label: "押す", longPress: false),
                .init(title: "あいた場所の「＋」を押す", body: "左のボタンの場所に「＋」が出る。", tip: nil, scene: .controlsPlus, target: CGPoint(x: 72, y: 762), label: "押す", longPress: false),
                .init(title: "「今日を撮る」を選ぶ", body: "検索欄に「Later」と入れる。", tip: "左に「今日を撮る」、右に「昨日をひらく」が使いやすい。", scene: .controlsPicker, target: CGPoint(x: 195, y: 560), label: "押す", longPress: false),
                .init(title: "完了を押す", body: "右上の「完了」。", tip: nil, scene: .controlsDone, target: CGPoint(x: 346, y: 72), label: "押す", longPress: false),
            ]
        }
    }
}

struct WidgetGuideStep {
    let title: String
    let body: String
    let tip: String?
    let scene: WidgetMockScene
    /// 押す場所(390×844 の画面の座標)
    let target: CGPoint
    let label: String
    let longPress: Bool
    /// 図の窓で見せる中心(nil なら押す場所)。押す場所のまわりの見本も、窓に入れたいとき
    var focusY: CGFloat? = nil
}

enum WidgetMockScene {
    case homeGrid, homeEdit, homeSearch, homeSizes, homeDone
    case lockScreen, lockCustomize, lockSlots, lockPicker, lockDone
    case controlsMinus, controlsPlus, controlsPicker, controlsDone
}

// MARK: - 流れ

/// 初回設定(オンボーディング v2)と同じ部品・寸法で組む:純黒+上の光+小さな玉(点はすべて灯す)、
/// 見出し 28pt 左揃え(top 196)、左右の余白 28pt、主ボタン 56pt / 文字だけのリンク。橙・紫は使わない。
struct WidgetSetupFlow: View {
    enum Start { case intro, chooser }

    let start: Start
    /// skipped = 「あとで」を選んだ
    let onFinish: (_ skipped: Bool) -> Void

    private enum Stage: Equatable { case intro, choose, guide(Int), check }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var stage: Stage = .intro
    @State private var phase: OnboardingFlowView.ContentPhase = .hidden
    @State private var place: WidgetPlace = .home
    @State private var haptics = ExposureHaptics()
    @State private var check: PlacementCheck?
    @State private var hasStarted = false
    @State private var isTransitioning = false

    private static let side: CGFloat = 28

    var body: some View {
        ZStack {
            OnboardingSmallOrbBackdrop(showsOrb: !isGuide)
            GeometryReader { proxy in
                let fullHeight = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                let metrics = OnboardingMetrics(size: CGSize(width: proxy.size.width, height: fullHeight))
                // 見出しは、画面の上端から 196pt(初回設定と同じ)。ここはセーフエリアの内側なので、その分を引く
                let headTop = max(0, metrics.y(OnboardingMetrics.historyTop) - proxy.safeAreaInsets.top)
                Group {
                    switch stage {
                    case .intro: intro(headTop: headTop)
                    case .choose: chooser(headTop: headTop)
                    case .guide(let index): guide(index, width: proxy.size.width, fullHeight: fullHeight)
                    case .check: checkView(headTop: headTop)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            FilmGrainOverlay(opacity: 0.05, blendMode: .normal)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            haptics.prepare()
            guard !hasStarted else { return }
            hasStarted = true
            stage = start == .intro ? .intro : .choose
            UserDefaults.standard.set(true, forKey: WidgetSetupStorage.seenKey)
            DispatchQueue.main.async { phase = .shown }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 前面にもどったとき:置けたかを、その場で確かめる
            if newPhase == .active, stage == .check || isLastGuideStep {
                if isLastGuideStep { go(to: .check) }
                Task { await runCheck() }
            }
        }
    }

    private var isGuide: Bool {
        if case .guide = stage { return true }
        return false
    }

    private var isLastGuideStep: Bool {
        if case .guide(let index) = stage { return index == place.steps.count - 1 }
        return false
    }

    /// 初回設定と同じ切り替え:出ていく中身 0.25秒 → 入ってくる中身 0.6秒(上から順に 0.11秒ずつ)
    private func go(to next: Stage) {
        guard next != stage, !isTransitioning else { return }
        isTransitioning = true
        withAnimation { phase = .leaving }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.25)) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                stage = next
                phase = .hidden
            }
            DispatchQueue.main.async {
                phase = .shown
                isTransitioning = false
            }
        }
    }

    // MARK: 画面の骨組み(中身はスクロールでき、ボタンは下に固定)

    private func screen<Content: View, Buttons: View>(
        headTop: CGFloat,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        VStack(spacing: 0) {
            GeometryReader { area in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: headTop)
                        content()
                    }
                    .padding(.horizontal, Self.side)
                    .padding(.bottom, 16)
                    .frame(minHeight: area.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            VStack(spacing: 4) { buttons() }
                .padding(.horizontal, Self.side)
                .padding(.bottom, 16)
                .floatIn(phase, index: 4, reduceMotion: reduceMotion)
                .allowsHitTesting(phase == .shown && !isTransitioning)
        }
    }

    // MARK: ① ウィジェットを置きますか

    private func intro(headTop: CGFloat) -> some View {
        screen(headTop: headTop) {
            OnboardingHeadline(
                title: "ウィジェットを\n置きますか",
                sub: "ホーム画面やロック画面に置くと、アプリを開かなくても、今日ののこり時間と、現像のようすが見えます。写真と、ほかの人の情報は、出ません。",
                phase: phase,
                reduceMotion: reduceMotion
            )
            Spacer(minLength: 32)
            WidgetIntroSample(reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity)
                .floatIn(phase, index: 2, reduceMotion: reduceMotion)
            Text("あとから「設定 → ウィジェットの置き方」で見られます")
                .font(.system(size: 11.5))
                .foregroundStyle(OnboardingPalette.note)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
                .floatIn(phase, index: 3, reduceMotion: reduceMotion)
            Spacer(minLength: 12)
        } buttons: {
            OnboardingPrimaryButton(title: "置き方を見る") { go(to: .choose) }
            OnboardingTextButton(title: "あとで") { skip() }
        }
    }

    // MARK: ② どこに置きますか

    private func chooser(headTop: CGFloat) -> some View {
        screen(headTop: headTop) {
            OnboardingHeadline(
                title: "どこに置きますか",
                sub: "ひとつ選んでください。あとから、ほかの場所にも置けます。",
                phase: phase,
                reduceMotion: reduceMotion
            )
            VStack(spacing: 10) {
                ForEach(WidgetPlace.allCases) { candidate in
                    WidgetPlaceCard(place: candidate, isSelected: place == candidate) {
                        guard place != candidate else { return }
                        // 触覚は、カードを選ぶときだけ
                        haptics.playTransient(intensity: 0.3, sharpness: 0.5)
                        place = candidate
                    }
                }
            }
            .padding(.top, 44)
            .floatIn(phase, index: 2, reduceMotion: reduceMotion)
        } buttons: {
            OnboardingPrimaryButton(title: "置き方を見る") { go(to: .guide(0)) }
            OnboardingTextButton(title: start == .intro ? "あとで" : "とじる") {
                if start == .intro { skip() } else { onFinish(false) }
            }
        }
    }

    // MARK: ③ 置き方(ステップごと)

    private func guide(_ index: Int, width: CGFloat, fullHeight: CGFloat) -> some View {
        let steps = place.steps
        let index = min(index, steps.count - 1)
        let step = steps[index]
        let isLast = index == steps.count - 1
        // 図の窓:幅 = 画面幅 − 56pt。画面の小さい端末では、高さを 344 → 300pt まで縮める
        let windowSize = CGSize(width: max(0, width - Self.side * 2), height: fullHeight < 760 ? 300 : 344)
        return VStack(spacing: 0) {
            guideTopRow(index: index, count: steps.count)
                .padding(.top, 4)
            WidgetGuideProgress(index: index, count: steps.count) { target in
                go(to: .guide(target))
            }
            .padding(.top, 6)
            WidgetGuideWindow(step: step, reduceMotion: reduceMotion, size: windowSize)
                .padding(.top, 16)
                .floatIn(phase, index: 0, reduceMotion: reduceMotion)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("STEP \(index + 1)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .tracking(0.14 * 11)
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .floatIn(phase, index: 1, reduceMotion: reduceMotion)
                    Text(step.title)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.04 * 24)
                        .lineSpacing(24 * 0.35 - 8)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                        .accessibilityAddTraits(.isHeader)
                        .floatIn(phase, index: 1, reduceMotion: reduceMotion)
                    Text(step.body)
                        .font(.system(size: 14.5))
                        .lineSpacing(14.5 * 0.65 - 4)
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .floatIn(phase, index: 2, reduceMotion: reduceMotion)
                    if let tip = step.tip {
                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundStyle(OnboardingPalette.note)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                            .floatIn(phase, index: 3, reduceMotion: reduceMotion)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            VStack(spacing: 4) {
                OnboardingPrimaryButton(title: isLast ? "置いたので、確認する" : "つぎへ") {
                    if isLast {
                        check = nil
                        go(to: .check)
                    } else {
                        go(to: .guide(index + 1))
                    }
                }
                OnboardingTextButton(title: index == 0 ? "場所をえらびなおす" : "もどる") {
                    go(to: index == 0 ? .choose : .guide(index - 1))
                }
            }
            .padding(.bottom, 16)
            .floatIn(phase, index: 4, reduceMotion: reduceMotion)
            .allowsHitTesting(phase == .shown && !isTransitioning)
        }
        .padding(.horizontal, Self.side)
    }

    /// 上の行:戻る(押せる範囲 44pt 角)/ 中央に「ホーム画面に置く」/ 右に「3 / 5」
    private func guideTopRow(index: Int, count: Int) -> some View {
        ZStack {
            Text(place.guideTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 56)
            HStack {
                Button {
                    go(to: index == 0 ? .choose : .guide(index - 1))
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("もどる")
                Spacer()
                Text("\(index + 1) / \(count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 44)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    // MARK: ④ 置けたか確認

    private func checkView(headTop: CGFloat) -> some View {
        screen(headTop: headTop) {
            if let check {
                if check.anyPlaced {
                    OnboardingHeadline(title: "ウィジェットが\n置かれました", phase: phase, reduceMotion: reduceMotion)
                    WidgetPlacementList(check: check, onOpenSettings: openSettings)
                        .padding(.top, 40)
                        .floatIn(phase, index: 2, reduceMotion: reduceMotion)
                } else {
                    OnboardingHeadline(
                        title: "まだ置かれて\nいないようです",
                        sub: "置いたあと、このアプリにもどると、ここで確認できます。",
                        phase: phase,
                        reduceMotion: reduceMotion
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text("一覧に Later が出ないとき")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Later を一度ひらいてから、もう一度、追加の画面を見てください。それでも出ないときは、iPhone を再起動すると出ることがあります。")
                            .font(.system(size: 14))
                            .lineSpacing(14 * 0.6 - 4)
                            .foregroundStyle(OnboardingPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WidgetSetupSurface(cornerRadius: 24))
                    .padding(.top, 28)
                    .floatIn(phase, index: 2, reduceMotion: reduceMotion)
                }
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                    .accessibilityLabel("置けたか、確かめています")
            }
        } buttons: {
            if let check, check.anyPlaced {
                OnboardingPrimaryButton(title: "ほかの場所にも置く") { go(to: .choose) }
                OnboardingTextButton(title: "おわる") { onFinish(false) }
            } else {
                OnboardingPrimaryButton(title: "もう一度、置き方を見る", isEnabled: check != nil) { go(to: .guide(0)) }
                OnboardingTextButton(title: "あとで") { skip() }
            }
        }
        .task { await runCheck() }
    }

    // MARK: 動き

    private func skip() {
        UserDefaults.standard.set(true, forKey: WidgetSetupStorage.skippedKey)
        onFinish(true)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private func runCheck() async {
        let result = await PlacementCheck.current()
        withAnimation(.easeInOut(duration: 0.25)) { check = result }
    }
}

// MARK: - 部品(この4画面だけのもの)

/// 面:白4%+縁(白7%)の内側線 1pt
struct WidgetSetupSurface: View {
    let cornerRadius: CGFloat
    var isSelected = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(.white.opacity(isSelected ? 0.09 : 0.04))
            .overlay(shape.strokeBorder(.white.opacity(isSelected ? 1 : 0.07), lineWidth: isSelected ? 1.5 : 1))
            .shadow(color: .white.opacity(isSelected ? 0.12 : 0), radius: 14)
    }
}

/// ② の場所カード:高さ 104pt・角丸 24pt・幅は画面いっぱい(左右 28pt)。絵の枠 96pt 角 → 文字 → チェック
struct WidgetPlaceCard: View {
    let place: WidgetPlace
    let isSelected: Bool
    /// iOS 18 より前は「下のボタン」を押せない(いまの対応OSは iOS 26 以降なので、ふだんは true)
    var isAvailable = true
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                WidgetPlaceThumbnail(place: place)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    // 入りきらない時は、ラベルを出さない(タイトルを切らない)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            title
                            if let badge = badgeText { badgeView(badge) }
                        }
                        title
                    }
                    Text(place.note)
                        .font(.system(size: 13))
                        .lineSpacing(13 * 0.55 - 3)
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                checkMark
                    .padding(.trailing, 16)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(WidgetSetupSurface(cornerRadius: 24, isSelected: isSelected))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(OnboardingPressStyle())
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.35)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var title: some View {
        Text(place.title)
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.025 * 17)
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
    }

    private var badgeText: String? {
        guard let badge = place.badge else { return nil }
        return isAvailable ? badge : "iOS 18 以降で使えます"
    }

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(OnboardingPalette.secondaryText)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white.opacity(0.08)))
    }

    /// 選択中:白い丸に黒の ✓ / 未選択:空の丸(線 #3A3A3E 1.5pt)
    private var checkMark: some View {
        ZStack {
            if isSelected {
                Circle().fill(.white)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
            } else {
                Circle().strokeBorder(Color(hex: "3A3A3E"), lineWidth: 1.5)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}

/// 絵の枠の中身:実物のウィジェットを縮めて入れる。縮めたあとの大きさに枠を合わせ、はみ出しは切る
struct WidgetPlaceThumbnail: View {
    let place: WidgetPlace

    var body: some View {
        ZStack {
            Color(hex: "1C1C1E")
            switch place {
            case .home:
                LaterSceneView(state: WidgetSamples.shoot, family: .systemSmall)
                    .frame(width: 170, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .scaleEffect(0.44)
                    .frame(width: 170 * 0.44, height: 170 * 0.44)
            case .lock:
                VStack(spacing: 4) {
                    Text("9:41")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    LaterRectangularView(state: WidgetSamples.developing)
                        .foregroundStyle(.white)
                        .frame(width: 158, height: 58)
                        .scaleEffect(0.48)
                        .frame(width: 158 * 0.48, height: 58 * 0.48)
                }
            case .controls:
                HStack(spacing: 14) {
                    controlButton("circle.circle")
                    controlButton("circle.dashed")
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func controlButton(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(.white.opacity(0.14)))
    }
}

/// ① の見本:本物の小ウィジェット(158×158)。6秒でゆっくり上下 6pt(動きを減らす設定では止める)
struct WidgetIntroSample: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            LaterSceneView(state: WidgetSamples.shoot, family: .systemSmall)
                .frame(width: 158, height: 158)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 20)
                .offset(y: CGFloat(sin(2 * .pi * t / 6)) * 6)
        }
        .frame(width: 158, height: 158 + 12)
        .accessibilityElement()
        .accessibilityLabel("ウィジェットの見本。今日を撮る")
    }
}

/// ③ の進み具合:5本(または4本)、間 6pt、太さ 4pt。済み=白、いま=白+にじみ、これから=#26262A
struct WidgetGuideProgress: View {
    let index: Int
    let count: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= index ? Color.white : Color(hex: "26262A"))
                    .frame(height: 4)
                    .shadow(color: .white.opacity(i == index ? 0.6 : 0), radius: 4)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { if i != index { onSelect(i) } }
            }
        }
        .padding(.vertical, -10)
        .accessibilityElement()
        .accessibilityLabel("\(count)ステップ中 \(index + 1)")
    }
}

/// ④ の一覧:4行(ホーム画面 / ロック画面 / 下のボタン / 撮ったあとの表示)
struct WidgetPlacementList: View {
    let check: PlacementCheck
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                row("ホーム画面", icon: "square.grid.2x2", status: check.home ? .placed : .notYet)
                divider
                row("ロック画面", icon: "lock", status: check.lock ? .placed : .notYet)
                divider
                row("下のボタン", icon: "button.horizontal", status: check.controls ? .placed : .notYet)
                divider
                row("撮ったあとの表示", icon: "dot.radiowaves.left.and.right", status: check.liveActivities ? .on : .off)
            }
            .background(WidgetSetupSurface(cornerRadius: 24))
            if !check.liveActivities {
                Button(action: onOpenSettings) {
                    Text("撮ったあとの表示を、設定でオンにする ›")
                        .font(.system(size: 11.5))
                        .underline()
                        .foregroundStyle(OnboardingPalette.subText)
                }
                .buttonStyle(.plain)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private enum Status { case placed, notYet, on, off }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.07)).frame(height: 1).padding(.leading, 60)
    }

    private func row(_ title: String, icon: String, status: Status) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.08)))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            statusView(status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func statusView(_ status: Status) -> some View {
        switch status {
        case .placed:
            HStack(spacing: 7) {
                Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white.opacity(0.9), radius: 4)
                Text("置かれています").foregroundStyle(.white)
            }
            .fixedSize()
            .font(.system(size: 13, weight: .medium))
        case .notYet:
            Text("まだ").font(.system(size: 13, weight: .medium)).foregroundStyle(OnboardingPalette.note)
        case .on:
            Text("オン").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
        case .off:
            Text("オフ").font(.system(size: 13, weight: .medium)).foregroundStyle(OnboardingPalette.note)
        }
    }
}

// MARK: - 置けたか(保存しない。毎回、その場で確かめる)

struct PlacementCheck: Equatable {
    var home: Bool
    var lock: Bool
    var controls: Bool
    var liveActivities: Bool

    var anyPlaced: Bool { home || lock || controls }

    static func current() async -> PlacementCheck {
        let configs = (try? await WidgetCenter.shared.currentConfigurations()) ?? []
        let homeFamilies: Set<WidgetFamily> = [.systemSmall, .systemMedium, .systemLarge]
        let lockFamilies: Set<WidgetFamily> = [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        let controls = (try? await ControlCenter.shared.currentControls()) ?? []
        return PlacementCheck(
            home: configs.contains { homeFamilies.contains($0.family) },
            lock: configs.contains { lockFamilies.contains($0.family) },
            controls: controls.contains { ["LaterShootControl", "LaterOpenControl"].contains($0.kind) },
            liveActivities: ActivityAuthorizationInfo().areActivitiesEnabled
        )
    }
}

// MARK: - 見本のウィジェット

/// 図に出すウィジェットは、デモ用の「今日を撮る」「現像中」だけ
enum WidgetSamples {
    static var shoot: LaterWidgetState {
        let now = Calendar.current.date(bySettingHour: 15, minute: 7, second: 0, of: Date()) ?? Date()
        var snapshot = LaterWidgetSnapshot.empty
        snapshot.dayKey = LaterWidgetDay.key(for: now)
        snapshot.history = [true, false, true, true, false, true]
        return .derive(snapshot, now: now)
    }

    static var developing: LaterWidgetState {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 22, minute: 40, second: 0, of: Date()) ?? Date()
        var snapshot = LaterWidgetSnapshot.empty
        snapshot.lastShotAt = calendar.date(bySettingHour: 18, minute: 11, second: 0, of: Date())
        snapshot.openedYesterday = true
        snapshot.dayKey = LaterWidgetDay.key(for: now)
        snapshot.history = [true, false, true, true, false, true]
        return .derive(snapshot, now: now)
    }
}

// MARK: - 図の窓(幅 = 画面幅 − 56pt、高さ 344pt)

/// 390×844 の画面を「窓の幅 ÷ 390」の倍率で縮め、押す場所のあたりだけを切り出す。
/// 動くのは3つだけ:指・押す場所の光の輪・ラベル
struct WidgetGuideWindow: View {
    let step: WidgetGuideStep
    let reduceMotion: Bool
    var size = CGSize(width: 334, height: 344)

    static let screenSize = CGSize(width: 390, height: 844)

    var scale: CGFloat { size.width / Self.screenSize.width }

    /// 窓の上端を、縮めた画面のどこに合わせるか(押す場所が窓の中におさまるように)
    static func offsetY(focus: CGFloat, scale: CGFloat, windowHeight: CGFloat) -> CGFloat {
        min(max(0, focus * scale - windowHeight / 2), max(0, screenSize.height * scale - windowHeight))
    }

    var body: some View {
        let offsetY = Self.offsetY(focus: step.focusY ?? step.target.y, scale: scale, windowHeight: size.height)
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        ZStack(alignment: .topLeading) {
            WidgetMockScreen(scene: step.scene)
                .frame(width: Self.screenSize.width, height: Self.screenSize.height)
                .overlay {
                    WidgetGuideFinger(step: step, reduceMotion: reduceMotion)
                }
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: Self.screenSize.width * scale, height: Self.screenSize.height * scale, alignment: .topLeading)
                .offset(y: -offsetY)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
        .accessibilityElement()
        .accessibilityLabel("図:\(step.title)")
    }
}

/// 白い丸(指):ゆっくり縮んで波紋を出す。押す場所:白い光の輪(呼吸のようにふくらむ)。ラベル:黒い丸薬+白文字
struct WidgetGuideFinger: View {
    let step: WidgetGuideStep
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let period = step.longPress ? 2.4 : 1.6
            let u = reduceMotion ? 0.5 : (context.date.timeIntervalSinceReferenceDate / period).truncatingRemainder(dividingBy: 1)
            let press = sin(.pi * min(1, u / 0.5))
            let ripple = max(0, (u - 0.25) / 0.75)
            let breathe = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 2.2)
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 2.5)
                    .frame(width: 64 + 10 * breathe, height: 64 + 10 * breathe)
                    .shadow(color: .white.opacity(0.7), radius: 10)
                    .opacity(0.45 + 0.4 * breathe)
                if !reduceMotion {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 36 + 70 * ripple, height: 36 + 70 * ripple)
                        .opacity((1 - ripple) * (step.longPress ? 0.85 : 0.6))
                }
                Circle()
                    .fill(.white.opacity(0.75))
                    .frame(width: 34, height: 34)
                    .scaleEffect(1 - 0.15 * press)
                    .shadow(color: .black.opacity(0.4), radius: 6)
                Text(step.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(.black))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                    .fixedSize()
                    .offset(y: step.target.y > 700 ? -58 : 58)
            }
            .position(step.target)
        }
        .allowsHitTesting(false)
    }
}

/// 図の画面:背景・ゴースト(薄い四角)のアイコン・シート・検索欄・ウィジェット実物で組む(画像は使わない)
struct WidgetMockScreen: View {
    let scene: WidgetMockScene

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "0E0E12")
            switch scene {
            case .homeGrid: ghostGrid(jiggle: false)
            case .homeEdit:
                ghostGrid(jiggle: true)
                topButton("＋", x: 38)
                topButton("完了", x: 346)
            case .homeSearch:
                ghostGrid(jiggle: true).opacity(0.4)
                sheet(top: 120) {
                    searchField("Later").padding(.top, 24)
                    pickerRow(title: "Later", y: 0).padding(.top, 30)
                    ghostRow().padding(.top, 14)
                    ghostRow().padding(.top, 14)
                }
            case .homeSizes:
                ghostGrid(jiggle: true).opacity(0.4)
                sheet(top: 120) {
                    Text("Later").font(.system(size: 22, weight: .bold)).foregroundStyle(.white).padding(.top, 28)
                    LaterSceneView(state: WidgetSamples.shoot, family: .systemSmall)
                        .frame(width: 170, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.top, 24)
                    HStack(spacing: 6) {
                        Circle().fill(.white).frame(width: 7)
                        Circle().fill(.white.opacity(0.3)).frame(width: 7)
                        Circle().fill(.white.opacity(0.3)).frame(width: 7)
                    }
                    .padding(.top, 20)
                    Text("ウィジェットを追加")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 320, height: 54)
                        .background(Capsule().fill(.white))
                        .padding(.top, 50)
                }
            case .homeDone:
                ghostGrid(jiggle: true, skipFirst: true)
                LaterSceneView(state: WidgetSamples.shoot, family: .systemSmall)
                    .frame(width: 170, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .position(x: 112, y: 214)
                topButton("完了", x: 346)
            case .lockScreen:
                lockClock()
            case .lockCustomize:
                HStack(spacing: 18) {
                    wallpaperCard("ロック画面")
                    wallpaperCard("ホーム画面")
                }
                .frame(width: 390)
                .position(x: 195, y: 420)
                Text("カスタマイズ")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 46)
                    .background(Capsule().fill(.white.opacity(0.15)))
                    .position(x: 195, y: 680)
            case .lockSlots:
                lockClock()
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .frame(width: 300, height: 70)
                    .position(x: 195, y: 292)
                topButton("完了", x: 346)
            case .lockPicker:
                lockClock().opacity(0.5)
                sheet(top: 470) {
                    Text("Later").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).padding(.top, 22)
                    HStack(spacing: 14) {
                        LaterRectangularView(state: WidgetSamples.developing)
                            .foregroundStyle(.white)
                            .frame(width: 150, height: 60)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.08)))
                        LaterTodayCircle(state: WidgetSamples.developing)
                            .foregroundStyle(.white)
                            .frame(width: 66, height: 66)
                            .background(Circle().fill(.white.opacity(0.08)))
                        LaterWeekCircle(state: WidgetSamples.developing)
                            .foregroundStyle(.white)
                            .frame(width: 66, height: 66)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .padding(.top, 40)
                }
            case .lockDone:
                lockClock()
                HStack(spacing: 10) {
                    LaterRectangularView(state: WidgetSamples.developing)
                        .foregroundStyle(.white)
                        .frame(width: 150, height: 56)
                    LaterYesterdayCircle(state: WidgetSamples.developing).foregroundStyle(.white).frame(width: 56, height: 56)
                    LaterWeekCircle(state: WidgetSamples.developing).foregroundStyle(.white).frame(width: 56, height: 56)
                }
                .position(x: 195, y: 292)
                topButton("完了", x: 346)
            case .controlsMinus:
                lockClock()
                bottomButtons(left: "flashlight.off.fill", right: "camera.fill", minus: true)
            case .controlsPlus:
                lockClock()
                bottomButtons(left: nil, right: "camera.fill", minus: false)
            case .controlsPicker:
                lockClock().opacity(0.4)
                sheet(top: 380) {
                    searchField("Later").padding(.top, 24)
                    pickerRow(title: "今日を撮る", y: 0, icon: "circle.circle").padding(.top, 40)
                    pickerRow(title: "昨日をひらく", y: 0, icon: "circle.dashed").padding(.top, 12)
                }
            case .controlsDone:
                lockClock()
                bottomButtons(left: "circle.circle", right: "circle.dashed", minus: false)
                topButton("完了", x: 346)
            }
        }
        .frame(width: 390, height: 844)
        .clipped()
        .accessibilityHidden(true)
    }

    private func ghostGrid(jiggle: Bool, skipFirst: Bool = false) -> some View {
        ForEach(0..<20, id: \.self) { i in
            let col = i % 4, row = i / 4
            if !(skipFirst && row < 2 && col < 2) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .frame(width: 62, height: 62)
                    .rotationEffect(.degrees(jiggle ? (i % 2 == 0 ? -3 : 3) : 0))
                    .position(x: 56 + CGFloat(col) * 93, y: 160 + CGFloat(row) * 104)
            }
        }
    }

    private func topButton(_ title: String, x: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(.white.opacity(0.18)))
            .position(x: x, y: 72)
    }

    private func sheet<Content: View>(top: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(width: 390, height: 844 - top, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color(white: 0.13)))
            .offset(y: top)
    }

    private func searchField(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            Text(text)
            Spacer()
        }
        .font(.system(size: 16))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .frame(width: 340, height: 42)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.1)))
    }

    private func pickerRow(title: String, y: CGFloat, icon: String = "moon.fill") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: "2A2A30")))
            Text(title).font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(width: 390)
    }

    private func ghostRow() -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11).fill(.white.opacity(0.08)).frame(width: 44, height: 44)
            Capsule().fill(.white.opacity(0.08)).frame(width: 140, height: 14)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(width: 390)
    }

    private func lockClock() -> some View {
        VStack(spacing: 2) {
            Text("10月16日 木曜日")
                .font(.system(size: 18, weight: .semibold))
            Text("9:41")
                .font(.system(size: 90, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.9))
        .frame(width: 390)
        .position(x: 195, y: 180)
    }

    private func wallpaperCard(_ title: String) -> some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "3A3A40"), Color(hex: "121216")], startPoint: .top, endPoint: .bottom))
                .frame(width: 150, height: 300)
                .overlay(Text("9:41").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8)).padding(.top, 30), alignment: .top)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
        }
    }

    private func bottomButtons(left: String?, right: String, minus: Bool) -> some View {
        ZStack {
            Group {
                if let left {
                    Image(systemName: left)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(.white.opacity(0.15)))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 52, height: 52)
                        .background(Circle().strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                }
            }
            .overlay(alignment: .topLeading) {
                if minus {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white))
                        .offset(x: -6, y: -6)
                }
            }
            .position(x: 72, y: 762)
            Image(systemName: right)
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(.white.opacity(0.15)))
                .position(x: 318, y: 762)
        }
    }
}
