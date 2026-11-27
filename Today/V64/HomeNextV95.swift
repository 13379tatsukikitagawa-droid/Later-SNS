import SwiftUI

// v95-8:Home まんなか = NEXT(いま やる こと)。レンズの すぐ 下の カプセル。状況で 変わり、5.2秒ごとに つぎへ。
// 押す = その 場所へ(Button なので、上の かたまりの スクロールを 止めない)。

struct HVNextItem: Identifiable, Equatable {
    enum Go { case shoot, friends, live, develop }
    let id: String
    let title: String
    let sub: String
    let icon: String
    var alert = false
    var go: Go = .shoot
    static func == (a: HVNextItem, b: HVNextItem) -> Bool { a.id == b.id }
}

enum HVNextBuilder {
    /// 上から 優先(= 先に 出す)。条件に 合う ものを ぜんぶ 並べる
    static func items(_ i: HomeV64Input) -> [HVNextItem] {
        var out: [HVNextItem] = []
        let left: String = {
            let cal = Calendar.current
            let end = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: i.now) ?? i.now)
            let s = max(0, Int(end.timeIntervalSince(i.now)))
            return "24:00まで \(s / 3600):" + String(format: "%02d", (s % 3600) / 60)
        }()
        if i.shotsUsed == 0 { out.append(.init(id: "first", title: "最初の 1枚を 撮ろう", sub: left, icon: "camera.fill", go: .shoot)) }
        if let r = i.requests.first {
            out.append(.init(id: "req", title: "\(r.name) から 申請", sub: i.requests.count > 1 ? "ほか \(i.requests.count - 1)人" : "友だちに なりたい", icon: "person.fill.badge.plus", alert: true, go: .friends))
        } else if i.requestCount > 0 {
            out.append(.init(id: "req", title: "友だち申請が \(i.requestCount)件", sub: "ひらいて 確認", icon: "person.fill.badge.plus", alert: true, go: .friends))
        }
        if i.friendCount == 0 && i.friends.isEmpty { out.append(.init(id: "invite", title: "友だちを よぼう", sub: "QR ・ リンク ・ @ID", icon: "person.2.fill", go: .friends)) }
        if i.shotsUsed >= 1 && i.shotsUsed < i.limit { out.append(.init(id: "left", title: "のこり \(i.remaining)こま", sub: left, icon: "camera.fill", go: .shoot)) }
        if i.shotsUsed >= i.limit { out.append(.init(id: "done", title: "今日は ここまで", sub: "あしたの 9:00 に ひらく", icon: "checkmark", go: .live)) }
        if i.shotsUsed >= 1 { out.append(.init(id: "dev", title: "現像中 ・ のぞいて みる", sub: "ねかせて ひらく", icon: "film", go: .develop)) }
        return out
    }
}

struct HVNextCapsule: View {
    let input: HomeV64Input
    let actions: HomeV64Actions
    var onLive: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var index = 0
    @ObservedObject private var frameStore = ScreenFrameStore.shared
    @State private var forward = true
    @State private var tick = 0

    var body: some View {
        let items = HVNextBuilder.items(input)
        let n = items.count
        let cur = items.isEmpty ? nil : items[min(index, n - 1)]
        return Group {
            if let cur {
                VStack(spacing: 6) {
                    Button { tap(cur) } label: { capsule(cur, n: n) }
                        .buttonStyle(HVPress(scale: 0.96))
                        .id(cur.id)
                        .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                    // v114:いまの 点は 白で 横長 14pt
                    HStack(spacing: 4) {
                        ForEach(0..<n, id: \.self) { k in
                            let on = k == min(index, n - 1)
                            Capsule().fill(.white.opacity(on ? 1 : 0.3)).frame(width: on ? 14 : 4, height: 4)
                        }
                    }
                    .frame(height: 6).opacity(n > 1 ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: index)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { v in
                    guard n > 1, abs(v.translation.width) > abs(v.translation.height) * 1.4, abs(v.translation.width) > 30 else { return }
                    Haptics.play(.sel); step(v.translation.width < 0 ? 1 : -1, n: n)
                })
                .clipped()
                .task(id: scenePhase) {
                    guard !reduceMotion, scenePhase == .active else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 5_200_000_000)
                        if Task.isCancelled { return }
                        let c = HVNextBuilder.items(input).count
                        if c > 1 { step(1, n: c) }
                    }
                }
            }
        }
    }

    private func step(_ d: Int, n: Int) {
        forward = d > 0
        withAnimation(.timingCurve(0.3, 1.0, 0.4, 1, duration: 0.45)) { index = ((index + d) % n + n) % n }
    }

    /// v114 2-1:紙の カード(330 × 66 ・ 角丸 22 ・ #F7F5EF ・ -1.2° ・ 上に テープ = フレームの 色)
    private func capsule(_ it: HVNextItem, n: Int) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((it.alert ? Color(hex: "FF7AB6") : HV.lime).shadow(.inner(color: Color(hex: "111113").opacity(0.14), radius: 0, y: -2)))
                Image(systemName: it.icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "111113"))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT ・ \(min(index, n - 1) + 1)/\(n)").font(Typo.ui(700, 10)).foregroundStyle(Color(hex: "8C8778"))
                Text(it.title).font(Typo.ui(800, 16)).foregroundStyle(Color(hex: "111113")).lineLimit(1).minimumScaleFactor(0.75)
                Text(it.sub).font(Typo.ui(600, 11.5)).foregroundStyle(Color(hex: "6E6A60")).lineLimit(1)
            }
            Spacer(minLength: 4)
            ZStack {
                Circle().fill(Color(hex: "111113"))
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(HV.lime)
            }
            .frame(width: 38, height: 38)
        }
        .padding(.leading, 11).padding(.trailing, 14)
        .frame(width: 330, height: 66)
        .background(Color(hex: "F7F5EF"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle().fill(tapeColor.opacity(0.9)).frame(width: 58, height: 18).rotationEffect(.degrees(3)).offset(y: -9)
        }
        .rotationEffect(.degrees(-1.2))
        .shadow(color: .black.opacity(0.45), radius: 13, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// テープの 色 = 画面の フレームの 色(フレームが なし の 時は ライム)
    private var tapeColor: Color { frameStore.accent }

    private func tap(_ it: HVNextItem) {
        Haptics.play(.pop)
        switch it.go {
        case .shoot: actions.shoot()
        case .friends: actions.openFriends()
        case .live: onLive()
        case .develop: actions.openDevelop()
        }
    }
}

private struct HVNextPulse: ViewModifier {
    let color: Color
    @State private var on = false
    func body(content: Content) -> some View {
        content.background(Circle().stroke(color.opacity(on ? 0 : 0.6), lineWidth: 2).frame(width: 36, height: 36).scaleEffect(on ? 1.7 : 1))
            .loopWhileVisible(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: $on)   // v111
    }
}
