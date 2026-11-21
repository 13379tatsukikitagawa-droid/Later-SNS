import SwiftUI

/// グループの画面(Homeのグループの丸をタップ → 下から出るシート)。
/// 見出し → 招待カード → メンバー → 文章 → 主ボタン → 写真をかえる・グループの設定。
/// 「誰が投稿したか」は出さず、人数だけを出す。
struct GroupSheet: View {
    let group: LaterGroup
    let summary: GroupSummary
    let state: HomeState
    let haptics: ExposureHaptics
    let onClose: () -> Void
    /// ready:長押しでひらいた(呼び出し側で opened にして、グループの範囲で昨日を見る)
    let onOpen: () -> Void
    /// opened:グループの昨日を見る
    let onView: () -> Void
    /// 右上の「設定」
    let onSettings: () -> Void
    /// QRコードを画面いっぱいに出す(シートの外に重ねるため、呼び出し側が出す)
    let onShowQR: (URL) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var holdModel = HoldGaugeModel()
    @State private var appeared = false
    @State private var cardPulse = false
    /// まだ見ていない「〇〇さんが、抜けました。」(開いたときに読み、一度見たら既読)
    @State private var leftEvents: [MemberEventStore.Event] = []
    @State private var tripKey = ""
    @State private var shareItems: [Any]?

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 36, height: 5).padding(.top, 10)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(leftEvents) { event in
                        leftNotice(event)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                    header
                        .padding(.horizontal, 20)
                        .modifier(SheetStagger(index: 0, appeared: appeared, reduceMotion: reduceMotion))
                    TripSeatMap(people: seatPeople, small: true)
                        .padding(.horizontal, 16).padding(.top, 14)
                        .modifier(SheetStagger(index: 1, appeared: appeared, reduceMotion: reduceMotion))
                    VStack(spacing: 10) {
                        TripSendButton(sub: summary.isFull ? "満員です" : "あと \(summary.openSeats)席", action: sendInvite)
                        TripTwoButtons(key: tripKey, onQR: showPass)
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                    .modifier(SheetStagger(index: 2, appeared: appeared, reduceMotion: reduceMotion))
                    Text(note)
                        .font(Typo.ui(600, 11.5)).foregroundStyle(Color(hex: "6E6E75")).multilineTextAlignment(.center)
                        .padding(.top, 14).padding(.horizontal, 24)
                        .modifier(SheetStagger(index: 3, appeared: appeared, reduceMotion: reduceMotion))
                }
                .padding(.top, 18)
                .padding(.bottom, 16)
            }

            actionButton
                .padding(.horizontal, 24)
                .padding(.top, 8)
                // 下の行が無くなったので、下端からの余白は 64pt
                .padding(.bottom, 64)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: group.id) { if let k = try? await GroupInviteService.passphrase(for: group, context: modelContext) { tripKey = k } }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large])
        }
        .onAppear {
            appeared = true
            leftEvents = MemberEventStore.unseen(groupID: group.id)
            if let first = leftEvents.first {
                UIAccessibility.post(notification: .announcement, argument: "\(first.memberName)さんが、抜けました")
            }
            MemberEventStore.markSeen(leftEvents.map(\.id))
            Task { await GroupLeaveService.pruneMemberEvents(context: modelContext) }
        }
        .onChange(of: group.members.count) { _, _ in
            // 開いている最中に、ほかの人が抜けた
            let fresh = MemberEventStore.unseen(groupID: group.id)
            if !fresh.isEmpty {
                withAnimation(.easeOut(duration: 0.3)) { leftEvents = fresh + leftEvents.filter { e in !fresh.contains { $0.id == e.id } } }
                MemberEventStore.markSeen(fresh.map(\.id))
            }
        }
    }

    /// 「しずくさんが、抜けました。」+ 日時(一度見たら消える・7日で消える)
    private func leftNotice(_ event: MemberEventStore.Event) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: "C8F25A")).frame(width: 7, height: 7).shadow(color: Color(hex: "C8F25A").opacity(0.8), radius: 4)
            Text("\(event.memberName)さんが、抜けました。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(Self.eventDate.string(from: event.eventAt))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(hex: "8E8E93"))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
    }

    private static let eventDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM.dd HH:mm"
        return f
    }()

    // MARK: - 見出し(表紙 52 ・ 名前 Instrument Serif 28 ・ DAY / 人数 ・ 歯車)

    private var dayNumber: Int {
        let cal = Calendar.current
        return max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: group.creationDate), to: cal.startOfDay(for: Date())).day ?? 0) + 1)
    }

    private var seatPeople: [TripSeatPerson] {
        group.members.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            TripSeatPerson(id: $0.id.uuidString, name: $0.name, image: V64Images.image(key: "tm\($0.id)", data: $0.profileImageData, maxPixel: 120))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let img = V64Images.image(key: "tg\(group.id)", data: summary.iconData, maxPixel: 200) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Color(hex: "2A2A2E").overlay(HV72HashShape().fill(Color(hex: "C8F25A")).frame(width: 26, height: 26))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(2)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(hex: "C8F25A"), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name).font(Typo.title(28)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                Text("DAY \(dayNumber) ・ \(summary.memberCount) / \(summary.memberLimit)人")
                    .font(Typo.label(10)).tracking(1.2).foregroundStyle(Color(hex: "8C8C93"))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5), value: summary.memberCount)
            }
            Spacer(minLength: 0)
            Button(action: onSettings) {
                Image(systemName: "gearshape").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(Color(hex: "1C1C1F")))
            }
            .buttonStyle(PressScaleStyle(scale: 0.94))
            .accessibilityLabel("Trip を かえる")
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 招待(KEY は 1つ)

    private func sendInvite() {
        Haptics.play(.click)
        Task {
            guard let link = try? await GroupInviteService.link(for: group, context: modelContext) else { return }
            let shareURL = InviteConfig.shareURL(from: link) ?? link
            let join = GroupJoinLink.buildURL(shareURL: shareURL) ?? shareURL
            // v108 §5-2:LINE で 押せる https の 文(KEY)。KEY が とれない 時だけ 今までの 文
            if let key = try? await GroupInviteService.passphrase(for: group, context: modelContext) {
                shareItems = [LattagShareItem.trip(text: ShareTextV108.trip(host: ShareTextV108.me.name, name: group.name, dates: nil, members: nil, key: key), groupName: group.name)]
            } else {
                shareItems = [LattagShareItem.trip(text: InviteConfig.shareMessage(groupName: group.name, url: join), groupName: group.name)]
            }
        }
    }

    private func showPass() {
        Task {
            guard let link = try? await GroupInviteService.link(for: group, context: modelContext) else { return }
            onShowQR(InviteConfig.shareURL(from: link) ?? link)
        }
    }

    private var note: String {
        switch state {
        case .opened: return "きのうの Trip の 写真は ひらいて います"
        case .ready: return "長押しで、きのうの Trip を ひらけます"
        case .deciding: return "昨日の1枚を選ぶと、きのうの Trip が ひらく"
        default: return "今日 1枚 撮ると、きのうの Trip が ひらく"
        }
    }

    // MARK: - ボタン(下から116pt・高さ62pt・角丸31pt)

    @ViewBuilder
    private var actionButton: some View {
        let shape = RoundedRectangle(cornerRadius: 31, style: .continuous)
        switch state {
        case .ready:
            TimelineView(.animation(paused: !holdModel.isMoving)) { context in
                let p = holdModel.progress(at: context.date)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        shape.fill(.white.opacity(0.1))
                        Color(hex: "C8F25A")
                            .frame(width: proxy.size.width * p)
                            .clipShape(shape)
                        shape.strokeBorder(Color(hex: "C8F25A").opacity(0.6), lineWidth: 1)
                        Text(holdModel.isPressing ? "そのまま、持っていて…" : "長押しで、グループの昨日をひらく")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 62)
            .contentShape(shape)
            .gesture(holdGesture)
            .accessibilityElement()
            .accessibilityLabel("グループの昨日をひらく")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { holdModel.finish(haptics: haptics, onComplete: onOpen) }
        case .opened:
            Button(action: onView) {
                Text("グループの昨日を見る")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(shape.fill(.white))
            }
            .buttonStyle(.plain)
        default:
            Button(action: lockedTap) {
                Text(lockedTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(shape.fill(.white.opacity(0.08)))
                    .overlay(shape.strokeBorder(.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("まだ押せません")
        }
    }

    private var lockedTitle: String {
        if case .deciding = state { return "先に、昨日の1枚を選ぼう" }
        return "今日を撮ると、ひらけます"
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in holdModel.press(haptics: haptics, onComplete: onOpen) }
            .onEnded { _ in holdModel.lift(haptics: haptics) }
    }

    /// ロック中:やわらかく2回(強さ0.4・鋭さ0.2、間90ms)
    private func lockedTap() {
        haptics.playSoftDouble()
    }

}

/// シートの中身:見出し → 招待カード → メンバー → 文章の順に、80msずつずらしてぼかしながら浮かぶ(0.7秒)
private struct SheetStagger: ViewModifier {
    let index: Int
    let appeared: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        let shown = appeared || reduceMotion
        return content
            .blur(radius: shown || reduceMotion ? 0 : 10)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7).delay(0.12 + Double(index) * 0.08), value: appeared)
    }
}

/// 下から上がるシートの入れ物(上の角丸40pt・背景60%黒)。背景のタップ・下へのドラッグで閉じる(触覚なし)。
struct BottomSheetContainer<Content: View>: View {
    /// シートの上端(画面の上端から)
    let topInset: CGFloat
    /// シートの背景(省略時は #121214。現像シートは #1b1b1f → #0c0c0e のたてグラデ)
    var fill: AnyShapeStyle = AnyShapeStyle(Color(hex: "121214"))
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.black.opacity(isShown ? 0.6 : 0)
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)
                    .accessibilityLabel("閉じる")
                    .accessibilityAddTraits(.isButton)

                content()
                    .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom - topInset)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
                            .fill(fill)
                            .overlay(
                                UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .offset(y: (isShown ? topInset : proxy.size.height + proxy.safeAreaInsets.bottom) + max(0, dragOffset))
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = $0.translation.height }
                            .onEnded { value in
                                // 100pt 以上、または速く払うと閉じる。途中で離したら戻る
                                if value.translation.height > 100 || value.predictedEndTranslation.height > 260 {
                                    close()
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { dragOffset = 0 }
                                }
                            }
                    )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.22, 0.8, 0.24, 1, duration: 0.55)) { isShown = true }
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: reduceMotion ? 0.15 : 0.3)) {
            isShown = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.15 : 0.3)) { onClose() }
    }
}
