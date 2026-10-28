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
                        .padding(.horizontal, 24)
                        .modifier(SheetStagger(index: 0, appeared: appeared, reduceMotion: reduceMotion))
                    InviteCard(group: group, summary: summary, haptics: haptics, onShowQR: onShowQR)
                        .scaleEffect(cardPulse ? 1.025 : 1)
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .modifier(SheetStagger(index: 1, appeared: appeared, reduceMotion: reduceMotion))
                    members
                        .padding(.top, 22)
                        .modifier(SheetStagger(index: 2, appeared: appeared, reduceMotion: reduceMotion))
                    VStack(spacing: 6) {
                        (Text("昨日は ") + Text("\(summary.postedYesterday)人").bold().foregroundColor(.white) + Text(" が預けました。"))
                            .foregroundStyle(HomePalette.subText)
                        Text(note)
                            .foregroundStyle(Color(hex: "8E8E93"))
                            .multilineTextAlignment(.center)
                    }
                    .font(.system(size: 12))
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
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
        .overlay(alignment: .topTrailing) { settingsPill.padding(.top, 36).padding(.trailing, 22) }
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

    /// 右上の「設定」(高さ34pt・角丸17pt)。触覚なし
    private var settingsPill: some View {
        Button(action: onSettings) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15))
                Text("設定").font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(Color(hex: "D0D0D4"))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle(scale: 0.94))
        .accessibilityLabel("グループの設定")
    }

    /// 「しずくさんが、抜けました。」+ 日時(一度見たら消える・7日で消える)
    private func leftNotice(_ event: MemberEventStore.Event) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color(hex: "FFB26E")).frame(width: 7, height: 7).shadow(color: Color(hex: "FFB26E").opacity(0.8), radius: 4)
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

    // MARK: - 見出し

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                GroupFace(iconData: summary.iconData, initial: summary.initial, auraIndex: summary.auraIndex, diameter: 56)
                // まわりに12個の点。メンバー数ぶんが白く光る
                GroupLightRing(memberCount: GroupRingMath.maxDots, posted: min(GroupRingMath.maxDots, summary.memberCount), diameter: 84)
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 6) {
                Text(group.name)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.03 * 26)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    Text("\(summary.memberCount) / \(summary.memberLimit)人")
                        .foregroundStyle(Color(hex: "BCBBC0"))
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5), value: summary.memberCount)
                    Text(summary.isFull ? "満員" : "あと\(summary.openSeats)人")
                        .foregroundStyle(summary.isFull ? Color(hex: "8E8E93") : Color(hex: "FFB078"))
                }
                .font(.system(size: 11.5))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - メンバー(1行)

    private var members: some View {
        let sorted = group.members.sorted { $0.id.uuidString < $1.id.uuidString }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(sorted) { member in
                    VStack(spacing: 6) {
                        PersonaIcon(seed: member.id)
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                        Text(member.name)
                            .font(.system(size: 10.5))
                            .foregroundStyle(HomePalette.subText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(width: 58)
                    .accessibilityElement(children: .combine)
                    // 抜けた人の顔は、縮みながら消える(0.7秒)。残りが左へ寄る
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
                if !summary.isFull {
                    Button(action: pulseInviteCard) {
                        VStack(spacing: 6) {
                            InviteBreathingCircle()
                            Text("招待")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Color(hex: "FFB078"))
                        }
                        .frame(width: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("なかまを招待する")
                }
            }
            .padding(.horizontal, 24)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: sorted.map(\.id))
        }
    }

    /// 「＋ 招待」:上の招待カードが 1.025倍にふくらんで戻る(0.42秒)。ごく軽く1回
    private func pulseInviteCard() {
        haptics.playTransient(intensity: 0.25, sharpness: 0.4)
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.21)) { cardPulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
            withAnimation(.easeIn(duration: 0.21)) { cardPulse = false }
        }
    }

    private var note: String {
        switch state {
        case .ready, .opened: return "このグループの昨日だけを、ひらいて見られます。"
        case .deciding: return "昨日の1枚を選ぶと、このグループの昨日がひらけます。"
        default: return "今日を撮ると、このグループの昨日がひらけます。"
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
                        LinearGradient(colors: [Color(hex: "FFC56B"), HomePalette.orange], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * p)
                            .clipShape(shape)
                        shape.strokeBorder(HomePalette.orange.opacity(0.6), lineWidth: 1)
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

/// 「＋ 招待」のオレンジの点線の丸。ゆっくり呼吸する(影 0 ↔ 5pt、2.8秒)
private struct InviteBreathingCircle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle().strokeBorder(Color(hex: "FFB078"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(hex: "FFB078"))
        }
        .frame(width: 48, height: 48)
        .shadow(color: Color(hex: "FFB078").opacity(0.6), radius: breathing ? 5 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathing = true }
        }
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
