import SwiftData
import SwiftUI
import UIKit

/// 抜ける前の写し(抜けたあとはグループのデータが消えるので、画面に出すものを先に写しておく)
struct LeaveSnapshot: Identifiable {
    let id = UUID()
    let groupID: UUID
    let name: String
    let image: UIImage?
    let colorIndex: Int
    let memberLimit: Int
    let memberCount: Int
    let kind: GroupLeaveService.Kind

    @MainActor
    init(group: LaterGroup, user: UserProfile) {
        groupID = group.id
        name = group.name
        image = group.iconImageData.flatMap(UIImage.init(data:))
        colorIndex = GroupPalette.isValid(group.colorIndex) ? group.colorIndex : GroupPalette.index(forName: group.name)
        memberLimit = GroupPalette.clampLimit(group.memberLimit)
        memberCount = max(1, group.members.count)
        kind = GroupLeaveService.kind(for: group, user: user)
    }

    /// あなたの点(光っている点のうち、いちばん後ろ)
    var myIndex: Int { max(0, memberCount - 1) }
}

// MARK: - 確認 → 長押し → 抜ける動き(約3.3秒)

/// 画面いっぱいに重ねる。確認(長押し1.0秒)のあと、同じ場所で抜ける動きを流す。
/// 「抜けました。」は、抜ける処理が終わったのを確かめてから出す。触覚は、確認でやわらかく2回・抜けた瞬間にやわらかく1回。
struct GroupLeaveOverlay: View {
    let snapshot: LeaveSnapshot
    let haptics: ExposureHaptics
    /// 抜ける処理(失敗したら throw)
    let perform: () async throws -> Void
    let onCancel: () -> Void
    let onHome: () -> Void

    private static let holdDuration: TimeInterval = 1.0
    private static let circleDiameter: CGFloat = 220
    private static let red = Color(hex: "FF7A85")
    private static let orange = Color(hex: "FFB26E")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pressStart: Date?
    @State private var leaveStart: Date?
    @State private var successAt: Double?
    @State private var message: String?
    @State private var softFired = false
    @State private var confirmingVoiceOver = false

    private var isEnding: Bool { snapshot.kind == .lastOne }
    /// 「抜けました。」の時刻:1.5秒。処理がそれより遅ければ、終わるまで待つ
    private var textTime: Double { max(1.5, successAt ?? .infinity) }

    var body: some View {
        TimelineView(.animation(paused: pressStart == nil && leaveStart == nil)) { context in
            let t = leaveStart.map { context.date.timeIntervalSince($0) }
            ZStack {
                // 画面が暗くぼける(66%・ぼかし)
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                Color.black.opacity(t == nil ? 0.66 : 0.9).ignoresSafeArea()
                    .onTapGesture { if leaveStart == nil { onCancel() } }

                if let t {
                    animation(t: t)
                } else {
                    dialog(now: context.date)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .onChange(of: context.date) { _, date in tick(date) }
        }
        .onAppear { haptics.playSoftDouble() }
        .onChange(of: scenePhase) { _, phase in
            // 動きの途中で背面に行った:戻ったら、終わった状態を出す
            if phase == .active, successAt != nil, let leaveStart, Date().timeIntervalSince(leaveStart) < 3.3 {
                self.leaveStart = Date().addingTimeInterval(-(textTime + 1.8))
            }
        }
        .alert(isEnding ? "グループを消しますか?" : "グループから抜けますか?", isPresented: $confirmingVoiceOver) {
            Button(isEnding ? "消す" : "抜ける", role: .destructive) { startLeave() }
            Button("やめる", role: .cancel) {}
        }
    }

    // MARK: 確認ダイアログ

    private var texts: (title: String, bullets: [String]) {
        switch snapshot.kind {
        case .member:
            return ("『\(snapshot.name)』から、\n抜けますか?", [
                "あなたの写真は、このグループから消えます。",
                "メンバーには「抜けました」と、静かに伝わります。(通知は鳴りません)",
                "もう一度入るには、新しい招待が必要です。",
            ])
        case .lastOne:
            return ("最後の1人です。", [
                "抜けると、グループは消えます。",
                "招待リンクも、使えなくなります。",
                "消えたグループは、もどせません。",
            ])
        }
    }

    private func dialog(now: Date) -> some View {
        let progress = pressStart.map { min(1, now.timeIntervalSince($0) / Self.holdDuration) } ?? 0
        return VStack(spacing: 0) {
            ZStack {
                Circle().fill(Self.red.opacity(0.18))
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Self.red)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            Text(texts.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(texts.bullets, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(Self.red).frame(width: 5, height: 5).offset(y: -2)
                        Text(line).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Color(hex: "BCBBC0"))
            .padding(.top, 16)

            if let message {
                Text(message)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Self.orange)
                    .padding(.top, 14)
            }

            holdButton(progress: progress)
                .padding(.top, 20)

            Button(action: onCancel) {
                Text("やめる")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "8E8E93"))
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(22)
        .frame(width: 336)
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(Color(hex: "1A1A1E")))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .accessibilityAddTraits(.isModal)
    }

    private func holdButton(progress: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 29, style: .continuous)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                shape.fill(Self.red.opacity(0.1))
                LinearGradient(colors: [Self.red, Color(hex: "D94A5A")], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * progress)
                    .clipShape(shape)
                shape.strokeBorder(Self.red.opacity(0.4), lineWidth: 1)
                Text(pressStart == nil ? (isEnding ? "長押しで、消す" : "長押しで、抜ける") : "そのまま、押し続けて")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 58)
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard pressStart == nil, leaveStart == nil else { return }
                    guard ConnectivityMonitor.shared.isOnline else {
                        message = "つながったら、抜けられます"
                        return
                    }
                    message = nil
                    pressStart = Date()
                    haptics.beginHold(duration: Self.holdDuration)
                }
                .onEnded { _ in
                    guard leaveStart == nil else { return }
                    pressStart = nil
                    haptics.cancelHold()
                }
        )
        .accessibilityElement()
        .accessibilityLabel(isEnding ? "グループを消す。長押しします" : "グループから抜ける。長押しします")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { confirmingVoiceOver = true }
    }

    // MARK: 抜ける動き

    private func tick(_ date: Date) {
        if let pressStart, leaveStart == nil, date.timeIntervalSince(pressStart) >= Self.holdDuration {
            startLeave()
        }
        guard let leaveStart else { return }
        let t = date.timeIntervalSince(leaveStart)
        // 0.95:席が点線にもどる → やわらかく1回(処理の成功を確かめてから)
        if !softFired, successAt != nil, t >= max(0.95, (successAt ?? 0)) {
            softFired = true
            haptics.playTransient(intensity: 0.4, sharpness: 0.2)
        }
    }

    private func startLeave() {
        pressStart = nil
        haptics.cancelHold()
        guard ConnectivityMonitor.shared.isOnline else {
            message = "つながったら、抜けられます"
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { leaveStart = Date() }
        Task {
            do {
                try await perform()
                if let leaveStart { successAt = Date().timeIntervalSince(leaveStart) }
            } catch {
                // 動きを止めて、確認にもどる(中途半端な状態は、次の起動で続きから片づく)
                withAnimation(.easeOut(duration: 0.3)) { leaveStart = nil }
                message = "抜けられませんでした。もういちど"
            }
        }
    }

    private func animation(t: Double) -> some View {
        let seatOffset = GroupCircle.seatOffset(index: snapshot.myIndex, memberLimit: snapshot.memberLimit, diameter: Self.circleDiameter)
        let done = successAt != nil
        // 0.9〜1.9:円が少ししぼんで暗くなる
        let shrink = HomeMotion.ease(min(1, max(0, (t - 0.9) / 1.0)))
        let left = t >= 0.95 && done
        let litCount: Int = {
            if isEnding {
                // 時計まわりに、順番に暗くなる(0.09秒ずつ)
                let dark = reduceMotion ? (left ? snapshot.memberCount : 0) : Int(max(0, (t - 0.3) / 0.09))
                return max(0, snapshot.memberCount - dark)
            }
            return left ? snapshot.memberCount - 1 : snapshot.memberCount
        }()
        let local = t - textTime

        return VStack(spacing: 0) {
            Spacer()
            ZStack {
                GroupCircle(
                    image: snapshot.image,
                    initial: GroupNameRules.initial(of: snapshot.name),
                    colorIndex: snapshot.colorIndex,
                    memberLimit: snapshot.memberLimit,
                    litCount: isEnding ? litCount : (left ? litCount : snapshot.memberCount - 1),
                    diameter: Self.circleDiameter,
                    rotates: false,
                    seatIndex: !isEnding && left ? snapshot.myIndex : nil
                )
                .scaleEffect(1 - 0.03 * shrink)
                .brightness(-0.1 * shrink - (isEnding ? 0.15 * shrink : 0))

                if !isEnding && !reduceMotion {
                    // あなたの点(オレンジで強調 → 外へ)+ 4つの尾
                    ForEach(0..<5, id: \.self) { i in
                        let lagU = min(1, max(0, (t - 0.3 - Double(i) * 0.06) / 1.15))
                        let e = 1 - pow(1 - lagU, 3)
                        let scale = (1 + 0.9 * e) * (1 - Double(i) * 0.15)
                        let distance = 160 * e
                        let dir = CGSize(width: seatOffset.width / (Self.circleDiameter / 2 - 6), height: seatOffset.height / (Self.circleDiameter / 2 - 6))
                        Circle()
                            .fill(Self.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: Self.orange.opacity(0.8), radius: 6)
                            .scaleEffect(scale)
                            .opacity((1 - e) * (i == 0 ? 1 : 0.5 - Double(i) * 0.08))
                            .offset(x: seatOffset.width + dir.width * distance, y: seatOffset.height + dir.height * distance)
                    }
                } else if !isEnding && !left {
                    Circle().fill(Self.orange).frame(width: 8, height: 8).offset(seatOffset)
                }
            }
            .frame(height: Self.circleDiameter + 40)

            ZStack {
                // 1.2〜1.5:「〇〇 から、抜けます。」がうすれる
                Text(isEnding ? "\(snapshot.name) を、終わらせます。" : "\(snapshot.name) から、抜けます。")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .opacity(1 - min(1, max(0, (t - 1.2) / 0.3)))

                if done, local >= 0 {
                    let p = reduceMotion ? min(1, local / 0.3) : HomeMotion.ease(min(1, local / 0.7))
                    VStack(spacing: 8) {
                        Text(isEnding ? "終わりました。" : "抜けました。")
                            .font(.system(size: 32, weight: .bold))
                        Text(snapshot.name).font(.system(size: 15, weight: .semibold))
                        Text(isEnding ? "グループは、消えました。" : "あなたの一覧から消えました。メンバーには静かに伝わっています。")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color(hex: "BCBBC0"))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .entrance(p, blur: reduceMotion ? 0 : 12, dy: reduceMotion ? 0 : 12)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            if !isEnding {
                Text("\(litCount) / \(snapshot.memberLimit)人")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeOut(duration: 1.2), value: litCount)
                    .padding(.top, 10)
            }
            Spacer()

            // 2.6〜3.2:「ホームへ」が下から浮かぶ。押せるのは 3.2秒から
            let bp = done ? (reduceMotion ? min(1, max(0, (local - 1.1) / 0.3)) : HomeMotion.ease(min(1, max(0, (local - 1.1) / 0.6)))) : 0
            Button(action: onHome) {
                Text("ホームへ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .disabled(!(done && local >= 1.7))
            .entrance(bp, dy: reduceMotion ? 0 : 16)
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - 「このグループは、終わりました。」(参加者の端末で、その1回だけ)

struct GroupEndedView: View {
    let ended: EndedGroupsStore.Ended
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                GroupCircle(initial: GroupNameRules.initial(of: ended.name), colorIndex: GroupPalette.isValid(ended.colorIndex) ? ended.colorIndex : 0,
                            memberLimit: GroupMembershipPolicy.maxMembersPerGroup, litCount: 0, diameter: 200, rotates: false, faded: true)
                Text("このグループは、\n終わりました。")
                    .font(.system(size: 27, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.top, 26)
                Text(ended.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "BCBBC0"))
                    .padding(.top, 10)
                Spacer()
                Button(action: onHome) {
                    Text("Home にもどる")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}
