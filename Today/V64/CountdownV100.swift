import SwiftUI

// v100 §6:9:00 と 24:00 の 10秒 前。Home を 見て いる 時 だけ。
// 10 → 4 は tick、3 → 1 は click。9:00 = heart → 0.26秒 後 success(ひらいた)。24:00 = thud(消灯)。

enum HapticCountdownTarget { case open, lights }

enum HapticCountdown {
    /// いちばん 近い 次の 9:00 / 24:00 と、そこまでの 秒
    static func nearest(after now: Date, calendar cal: Calendar = .current) -> (target: HapticCountdownTarget, seconds: Double) {
        let day = cal.startOfDay(for: now)
        let nine = cal.date(byAdding: .hour, value: 9, to: day)!
        let midnight = cal.date(byAdding: .day, value: 1, to: day)!
        let nextNine = cal.date(byAdding: .hour, value: 9, to: midnight)!
        if now < nine { return (.open, nine.timeIntervalSince(now)) }
        if now < midnight { return (.lights, midnight.timeIntervalSince(now)) }
        return (.open, nextNine.timeIntervalSince(now))
    }

    /// 数字の 丸に 出す 数(10〜1)。それ 以外は nil
    static func shownNumber(_ seconds: Double) -> Int? {
        let n = Int(ceil(seconds))
        return (1...10).contains(n) ? n : nil
    }

    /// その 数の バイブ(10 → 4 = tick ・ 3 → 1 = click)
    static func kind(for n: Int) -> Haptics.Kind { n <= 3 ? .click : .tick }
}

struct HVCountdownV100: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var n: Int?
    @State private var lastTarget: HapticCountdownTarget?
    @State private var lastRemain = 9999.0

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: Date(timeIntervalSince1970: ceil(Date().timeIntervalSince1970)), by: 1)) { ctx in
                Color.clear.onChange(of: ctx.date) { _, now in tick(now) }
            }.frame(width: 1, height: 1)
            ring
        }
        .allowsHitTesting(false)
    }

    private var ring: some View {
        ZStack {
            if let n {
                ZStack {
                    Circle().fill(.black.opacity(0.8)).background(.ultraThinMaterial, in: Circle())
                    Circle().strokeBorder(n <= 3 ? Color(hex: "C8F25A") : .white.opacity(0.12), lineWidth: n <= 3 ? 3 : 1)
                    Text("\(n)").font(Typo.ui(900, 92)).foregroundStyle(.white).monospacedDigit().contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 176, height: 176)
                .transition(reduceMotion ? .identity : .scale(scale: 0.85).combined(with: .opacity))
                .accessibilityLabel("あと \(n)秒")
            }
        }
        .animation(reduceMotion ? nil : .timingCurve(0.3, 1.2, 0.4, 1, duration: 0.25), value: n)
    }

    /// 別の 画面(撮影 ・ シート ・ 全画面)が 上に 重なって いない
    private static var homeVisible: Bool {
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        return root?.presentedViewController == nil
    }

    private func tick(_ now: Date) {
        guard active, scenePhase == .active, Self.homeVisible else { n = nil; lastTarget = nil; return }
        let (target, s) = HapticCountdown.nearest(after: now)
        // 目標を こえた(いちばん 近い 目標が 切りかわった)
        if let lt = lastTarget, (target != lt || s > lastRemain + 5), lastRemain < 3 {
            switch lt {
            case .open:
                Haptics.play(.heart)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { Haptics.play(.success) }
            case .lights: Haptics.play(.thud)
            }
        } else if let num = HapticCountdown.shownNumber(s), num != n {
            Haptics.play(HapticCountdown.kind(for: num))
        }
        n = HapticCountdown.shownNumber(s)
        lastTarget = target; lastRemain = s
    }
}

