import SwiftUI

// v95-8:Home まんなか = NEXT(いま やる こと)。レンズの すぐ 下の カプセル。状況で 変わり、5.2秒ごとに つぎへ。
// 押す = その 場所へ(Button なので、上の かたまりの スクロールを 止めない)。

struct HVNextItem: Identifiable, Equatable {
    enum Go { case shoot, friends, poke(String), live, develop }
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
            return "消灯まで \(s / 3600):" + String(format: "%02d", (s % 3600) / 60)
        }()
        if i.shotsUsed == 0 { out.append(.init(id: "first", title: "最初の 1枚を 撮ろう", sub: left, icon: "camera.fill", go: .shoot)) }
        if let r = i.requests.first {
            out.append(.init(id: "req", title: "\(r.name) から 申請", sub: i.requests.count > 1 ? "ほか \(i.requests.count - 1)人" : "友だちに なりたい", icon: "person.fill.badge.plus", alert: true, go: .friends))
        } else if i.requestCount > 0 {
            out.append(.init(id: "req", title: "友だち申請が \(i.requestCount)件", sub: "ひらいて 確認", icon: "person.fill.badge.plus", alert: true, go: .friends))
        }
        if i.friendCount == 0 && i.friends.isEmpty { out.append(.init(id: "invite", title: "友だちを よぼう", sub: "QR ・ リンク ・ @ID", icon: "person.2.fill", go: .friends)) }
        if i.shotsUsed >= 1 && i.shotsUsed < i.limit { out.append(.init(id: "left", title: "のこり \(i.remaining)こま", sub: left, icon: "camera.fill", go: .shoot)) }
        if let f = i.friends.first(where: { $0.shots == 0 }) {
            out.append(.init(id: "poke", title: "\(f.name) が まだ 撮って いない", sub: "つついて 知らせる", icon: "hand.point.up.left.fill", go: .poke(f.id)))
        }
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
                        .buttonStyle(HVPress(scale: 0.98))
                        .id(cur.id)
                        .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                    HStack(spacing: 4) {
                        ForEach(0..<n, id: \.self) { k in Circle().fill(.white.opacity(k == min(index, n - 1) ? 0.9 : 0.25)).frame(width: 4, height: 4) }
                    }.frame(height: 6).opacity(n > 1 ? 1 : 0)
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

    private func capsule(_ it: HVNextItem, n: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if it.alert { Circle().fill(Color(hex: "FF3B30")).frame(width: 36, height: 36).modifier(HVNextPulse(color: Color(hex: "FF3B30"))) }
                else { Circle().fill(HV.lime).frame(width: 36, height: 36) }
                Image(systemName: it.icon).font(.system(size: 15, weight: .bold)).foregroundStyle(it.alert ? .white : HV.ink)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("NEXT ・ \(min(index, n - 1) + 1)/\(n)").font(LF.mono(9)).tracking(1.2).foregroundStyle(it.alert ? Color(hex: "FF6A60") : HV.lime)
                Text(it.title).font(LF.inter(800, 14.5)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                Text(it.sub).font(LF.inter(600, 10.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 11).frame(width: 318, height: 58)
        .background(Color.black.opacity(0.86), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .contentShape(Capsule())
    }

    private func tap(_ it: HVNextItem) {
        Haptics.play(.pop)
        switch it.go {
        case .shoot: actions.shoot()
        case .friends: actions.openFriends()
        case .poke(let id): actions.poke(id)
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
            .onAppear { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true } }
    }
}
