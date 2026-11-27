import SwiftUI

// v134 Phase 4:GOOD MORNING(9:00)と 消灯(0:00〜9:00)。見本 screens/12 ・ 24。

/// ミルク色の フィルム(撮った 時刻つき)。光が 流れる
struct MilkFilmV134: View {
    var time: String
    var width: CGFloat = 96
    var sheen = false
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let photoW = width - 12
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [LTColor.milkTop, LTColor.milkBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: photoW, height: photoW * 4 / 3 - 4)
                .overlay {
                    if sheen && !reduceMotion {
                        LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: photoW * 0.5).rotationEffect(.degrees(18)).offset(x: sweep ? photoW : -photoW).blendMode(.plusLighter)
                    }
                }.clipped()
            Text(time).font(LTFont.stamp(11)).foregroundStyle(Color(hex6: 0x7A766D)).frame(height: 22)
        }
        .padding(.top, 6).padding(.horizontal, 6)
        .background(LTColor.chekiFrame, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear { if sheen && !reduceMotion { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false).delay(0.6)) { sweep = true } } }
        .accessibilityElement(children: .ignore).accessibilityLabel("\(time)に撮った1枚")
    }
}

/// 9:00 に はじめて ひらいた とき(1日1回)
struct GoodMorningV134: View {
    var times: [Date]
    var now: Date = Date()
    var onShoot: () -> Void
    var onLater: () -> Void
    @State private var lit = false
    @State private var rise = [false, false, false]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LTColor.bg.ignoresSafeArea()
            RadialGradient(colors: [Color(hex6: 0xC8D4A0).opacity(0.5), Color(hex6: 0x2A3318).opacity(0.25), .clear], center: UnitPoint(x: 0.5, y: 0.05), startRadius: 0, endRadius: 420)
                .ignoresSafeArea().opacity(lit ? 1 : 0).allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: -16) {
                    Text("GOOD").foregroundStyle(.white)
                    Text("MORNING").foregroundStyle(LinearGradient(colors: [Color(hex6: 0xDADADF), LTColor.tagGray], startPoint: .top, endPoint: .bottom))
                }
                .font(LTFont.display(84)).padding(.top, 70).accessibilityElement(children: .combine).accessibilityLabel("GOOD MORNING").accessibilityAddTraits(.isHeader)
                HStack(spacing: 8) {
                    Text(HomeV134Rules.dayLabel(now).replacingOccurrences(of: " ", with: " · ")).font(LTFont.display(24)).foregroundStyle(LTColor.ink3)
                }.padding(.top, 4)
                Spacer(minLength: 16)
                HStack(spacing: 14) {
                    ForEach(Array(times.prefix(3).enumerated()), id: \.offset) { i, t in
                        MilkFilmV134(time: HomeV134Rules.clock(t), width: 96, sheen: i == 0)
                            .frame(maxWidth: .infinity)
                            .offset(y: rise[i] ? 0 : 60).opacity(rise[i] ? 1 : 0)
                    }
                }
                VStack(spacing: 6) {
                    Text("きのうの\(max(1, times.count))枚が、見られます。").font(LTFont.ui(18, weight: .heavy)).foregroundStyle(.white)
                    Text("今日を1枚撮るたびに、1枚ずつひらきます。").font(LTFont.ui(14)).foregroundStyle(LTColor.ink3)
                }.frame(maxWidth: .infinity).padding(.top, 24)
                VStack(spacing: 14) {
                    Button { onShoot() } label: { HashLensView(size: 84) }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("撮る")
                    Text("撮って、ひらく").font(LTFont.ui(16, weight: .heavy)).foregroundStyle(.white)
                    Button { LTHaptics.play(.tap); onLater() } label: {
                        Text("あとで").font(LTFont.ui(15, weight: .heavy)).foregroundStyle(LTColor.ink2).frame(width: 120, height: 44)
                    }.buttonStyle(.plain)
                }.frame(maxWidth: .infinity).padding(.top, 34).padding(.bottom, 24)
            }.padding(.horizontal, 22)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            LTHaptics.play(.lightsOn)
            if reduceMotion { lit = true; rise = [true, true, true]; return }
            withAnimation(.easeOut(duration: 1.6)) { lit = true }
            for i in 0..<3 { withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7).delay(0.5 + 0.18 * Double(i))) { rise[i] = true } }
        }
    }
}

/// 消灯中(0:00〜9:00):Home の 中身は 強く ぼかして 暗く(呼ぶ 側で)、まんなかに カウントダウン
struct LightsOutV134: View {
    var times: [Date]
    var target: Date
    var now: Date

    var body: some View {
        VStack(spacing: 0) {
            Text("いまは撮れません").font(LTFont.ui(14, weight: .heavy)).tracking(1).foregroundStyle(LTColor.ink3)
            Text(timerInterval: now...max(target, now.addingTimeInterval(1)), countsDown: true).font(LTFont.display(86)).monospacedDigit()
                .foregroundStyle(LinearGradient(colors: [.white, LTColor.tagGray], startPoint: .top, endPoint: .bottom)).lineLimit(1).minimumScaleFactor(0.6)
                .padding(.top, 6)
            Text("9:00にひらきます。\nきのうの3枚は、いま現像中。").font(LTFont.ui(16, weight: .heavy)).foregroundStyle(LTColor.ink2)
                .multilineTextAlignment(.center).lineSpacing(5).padding(.top, 14)
            HStack(spacing: 12) {
                ForEach(Array(times.prefix(3).enumerated()), id: \.offset) { _, t in MilkFilmV134(time: HomeV134Rules.clock(t), width: 62) }
            }.padding(.top, 34)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RadialGradient(colors: [Color(hex6: 0x2A2118).opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 260).allowsHitTesting(false))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("24:00から9:00までは撮れません。9:00にひらきます。")
    }
}
