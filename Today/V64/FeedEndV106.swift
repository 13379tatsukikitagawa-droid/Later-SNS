import SwiftUI

/// v106 §3-2:Friends の いちばん 下「きょうの フィルムは ここまで」。
/// フィルムの 帯が 缶に 入る 絵(Shape で かく ・ 人 ・ 顔は 使わない)+ 9:00 までの カウント + ボタン 2つ。
struct FeedEndV106: View {
    var empty = false
    var shotToday = false
    var onAdd: () -> Void = {}
    var onShoot: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var next9: Date {
        Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 9, minute: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
    }

    var body: some View {
        VStack(spacing: 0) {
            FilmCanArt(animated: !reduceMotion).frame(width: 260, height: 120)
            Text("END OF TODAY'S ROLL").font(Typo.label(10)).tracking(2).foregroundStyle(HV.lime).padding(.top, 18)
            Text(empty ? "友だちを ふやすと、ここに ならびます" : "きょうの フィルムは ここまで").font(Typo.ui(900, 20)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.top, 8)
            Text("あしたの 9:00 に、みんなの 1枚が ひらきます").font(Typo.ui(600, 13)).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center).padding(.top, 6)
            Text(timerInterval: Date()...max(next9, Date().addingTimeInterval(1)), countsDown: true).font(Typo.label(20)).monospacedDigit().foregroundStyle(HV.lime).padding(.top, 12)
            HStack(spacing: 10) {
                Button { Haptics.play(.click); onAdd() } label: {
                    Text("友だちを ふやす").font(Typo.ui(800, 14)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
                        .background(.white.opacity(0.1), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                }.buttonStyle(HVPress(scale: 0.97))
                if !shotToday {
                    Button { Haptics.play(.click); onShoot() } label: {
                        Text("今日の 1枚を 撮る").font(Typo.ui(900, 14)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 48).background(HV.lime, in: Capsule())
                    }.buttonStyle(HVPress(scale: 0.97))
                }
            }.padding(.horizontal, 20).padding(.top, 20)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 24)
        .onAppear {
            if reduceMotion { shown = true; return }
            withAnimation(.easeOut(duration: 0.6)) { shown = true }
            Haptics.play(.soft)
        }
    }
}

/// フィルムの 帯 → 缶(6秒で ゆっくり 行き来 ・ 缶が すこし ゆれる ・ ライムの 点 3つ)
private struct FilmCanArt: View {
    var animated: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { ctx in
            let t = animated ? ctx.date.timeIntervalSinceReferenceDate : 0
            let slide = animated ? (sin(t * 2 * .pi / 6) * 0.5 + 0.5) : 0.5
            Canvas { g, size in
                let lime = HV.lime
                // 缶
                let can = CGRect(x: size.width - 112, y: 22, width: 92, height: 82)
                let wob = animated ? sin(t * 2.4) * 1.6 : 0
                g.translateBy(x: can.midX, y: can.maxY); g.rotate(by: .degrees(wob)); g.translateBy(x: -can.midX, y: -can.maxY)
                g.fill(Path(roundedRect: can, cornerRadius: 14), with: .color(Color(hex: "2A2A2C")))
                g.stroke(Path(roundedRect: can, cornerRadius: 14), with: .color(.white.opacity(0.18)), lineWidth: 1)
                g.fill(Path(roundedRect: CGRect(x: can.minX + 8, y: can.minY + 26, width: can.width - 16, height: 34), cornerRadius: 6), with: .color(lime))
                g.draw(Text("#").font(.system(size: 24, weight: .black)).foregroundColor(.black), at: CGPoint(x: can.midX, y: can.minY + 43))
                g.fill(Path(roundedRect: CGRect(x: can.minX + 14, y: can.minY - 5, width: can.width - 28, height: 9), cornerRadius: 4), with: .color(Color(hex: "3A3A3C")))
                g.transform = .identity
                // 帯
                let stripX = -140 + slide * 190
                let strip = CGRect(x: stripX, y: 46, width: 190, height: 40)
                g.fill(Path(roundedRect: strip, cornerRadius: 4), with: .color(Color(hex: "151517")))
                g.stroke(Path(roundedRect: strip, cornerRadius: 4), with: .color(.white.opacity(0.2)), lineWidth: 1)
                for i in 0..<5 {
                    let fx = strip.minX + 8 + CGFloat(i) * 36
                    let last = i == 4
                    g.fill(Path(roundedRect: CGRect(x: fx, y: strip.minY + 9, width: 30, height: 22), cornerRadius: 2), with: .color(last ? lime : .white.opacity(0.1)))
                    for k in 0..<2 {
                        let hy = k == 0 ? strip.minY + 2.5 : strip.maxY - 6.5
                        g.fill(Path(roundedRect: CGRect(x: fx + 4, y: hy, width: 5, height: 4), cornerRadius: 1), with: .color(.white.opacity(0.35)))
                        g.fill(Path(roundedRect: CGRect(x: fx + 20, y: hy, width: 5, height: 4), cornerRadius: 1), with: .color(.white.opacity(0.35)))
                    }
                }
                // 点 3つ
                for i in 0..<3 {
                    let ph = animated ? (sin(t * 2.0 + Double(i) * 1.3) * 0.5 + 0.5) : 0.6
                    g.fill(Path(ellipseIn: CGRect(x: size.width / 2 - 6 + CGFloat(i) * 12 - 12, y: 106, width: 5, height: 5)), with: .color(lime.opacity(0.25 + 0.75 * ph)))
                }
            }
        }.accessibilityHidden(true)
    }
}
