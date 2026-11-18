import SwiftUI

// v95-10-2:Mondo(ない 日)= 「何も ない」ではなく、次の 9:00 を 待つ 画面(Y24 Y25)。
// 地球(120秒で 1回転)+ 朝の 線 + 脈 打つ 街 → No Mondo → NEXT MONDO → ベントー → 3つの 手順 → 撮って 参加。

struct MondoWaitV95View: View {
    var input: YesterdayV64Input
    var actions: YesterdayV64Actions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var notify = false
    @State private var startDate = Date()

    private var m: YesterdayMondoInput { input.mondo }
    private var dayText: String {
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        return (m.dayLabel.isEmpty ? f.string(from: input.now) : m.dayLabel) + " ・ きのう"
    }
    private let pulses: [(CGFloat, CGFloat)] = [(-44, -62), (52, -30), (-70, 18), (24, 58), (68, 44)]

    var body: some View {
        VStack(spacing: 0) {
            globe.padding(.top, 110)
            Text(dayText).font(LF.mono(10.5)).tracking(2.3).foregroundStyle(.white.opacity(0.45)).padding(.top, 20)
            Text("No Mondo").font(LF.serif(46)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 4)
            Text("きのうは お題が 出ませんでした").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.55)).padding(.top, 4)
            nextCard.padding(.horizontal, 16).padding(.top, 22)
            bento.padding(.horizontal, 16).padding(.top, 12)
            steps.padding(.horizontal, 16).padding(.top, 22)
            HStack(spacing: 10) {
                Button { Haptics.play(.click); actions.shoot() } label: {
                    HStack(spacing: 10) { Image(systemName: "camera").font(.system(size: 19, weight: .semibold)); Text("撮って 参加").font(LF.inter(900, 17)) }
                        .foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(HV.lime, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97))
                Button { Haptics.play(.success); notify.toggle() } label: {
                    Image(systemName: notify ? "bell.fill" : "bell").font(.system(size: 20, weight: .semibold)).foregroundStyle(notify ? HV.ink : .white).frame(width: 56, height: 56)
                        .background(notify ? HV.lime : Color.white.opacity(0.08), in: Circle()).overlay(Circle().strokeBorder(notify ? .clear : .white.opacity(0.2), lineWidth: 1))
                }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("9:00 に 知らせる")
            }.padding(.horizontal, 16).padding(.top, 22)
            Color.clear.frame(height: 160)
        }
        .frame(maxWidth: .infinity).clipped()
    }

    // MARK: 地球 + 朝の 線 + 脈 打つ 街

    private var globe: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || scenePhase != .active)) { ctx in
            let t = reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate
            let band = CGFloat(sin(t * 2 * .pi / 9)) * 46
            ZStack {
                Globe(spin: t * 3, tilt: 23, radius: 150, cities: [], lines: 0.16, rim: 0.22, glow: false)
                // 朝の 線(ライムの 光の 帯 ・ 9秒で 左右に ゆれる)
                LinearGradient(colors: [.clear, HV.lime.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 70, height: 300).rotationEffect(.degrees(14)).offset(x: band)
                    .mask(Circle().frame(width: 296, height: 296))
                ForEach(0..<pulses.count, id: \.self) { i in
                    let u = (t * 0.7 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
                    ZStack {
                        Circle().fill(HV.lime).frame(width: 4, height: 4)
                        Circle().stroke(HV.lime.opacity(0.6 * (1 - u)), lineWidth: 1.2).frame(width: 4 + 18 * u, height: 4 + 18 * u)
                    }.offset(x: pulses[i].0, y: pulses[i].1)
                }
            }
            .frame(width: 300, height: 300)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: NEXT MONDO

    private var nextCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let cal = Calendar.current
            let next = cal.nextDate(after: ctx.date, matching: DateComponents(hour: 9, minute: 0, second: 0), matchingPolicy: .nextTime) ?? ctx.date
            let sec = max(0, UserDefaults.standard.bool(forKey: "debugMock") ? 4 * 3600 + 36 * 60 + 48 - Int(ctx.date.timeIntervalSince(startDate)) : Int(next.timeIntervalSince(ctx.date)))
            VStack(spacing: 8) {
                Text("NEXT MONDO").font(LF.mono(10)).tracking(2.2).foregroundStyle(HV.lime)
                HStack(spacing: 0) {
                    Text("\(sec / 3600):\(String(format: "%02d", (sec % 3600) / 60))").foregroundStyle(.white)
                    Text(":\(String(format: "%02d", sec % 60))").foregroundStyle(.white.opacity(0.35))
                }.font(LF.inter(800, 52)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.1)); Capsule().fill(HV.lime).frame(width: 240 * CGFloat(1 - Double(sec) / 86400)) }.frame(width: 240, height: 4)
                Text("9:00 に 世界の きのうが ひらく").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.55)).padding(.top, 2)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 22)
            .background(Color(hex: "0C0D0E"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(HV.lime.opacity(0.18), lineWidth: 1))
        }
    }

    // MARK: ベントー

    private var bento: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("#").font(LF.serif(26, italic: true)).foregroundStyle(HV.lime)
                Text("おだい").font(LF.inter(900, 22)).foregroundStyle(.white).blur(radius: 6)
                Spacer()
                Label("9:00 に 発表", systemImage: "lock.fill").font(LF.inter(700, 12)).foregroundStyle(.white.opacity(0.6)).labelStyle(.titleAndIcon)
            }
            .padding(.horizontal, 16).frame(maxWidth: .infinity).frame(height: 64)
            .background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topLeading) { Text("今日の お題").font(LF.mono(8.5)).tracking(1.4).foregroundStyle(.white.opacity(0.4)).padding(.leading, 16).padding(.top, 8) }
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.num(m.shots)).font(LF.inter(900, 28)).foregroundStyle(HV.ink).lineLimit(1).minimumScaleFactor(0.6)
                    Text("きのうの 枚数").font(LF.inter(700, 11)).foregroundStyle(HV.ink.opacity(0.65))
                }.padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 78).background(HV.lime, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(m.citiesCount)").font(LF.inter(900, 28)).foregroundStyle(.white)
                    Text("都市").font(LF.inter(700, 11)).foregroundStyle(.white.opacity(0.55))
                }.padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading).frame(height: 78).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            relay
        }
    }

    private static func num(_ n: Int) -> String { let f = NumberFormatter(); f.numberStyle = .decimal; return f.string(from: NSNumber(value: n)) ?? "\(n)" }

    /// 9:00 リレー:次に 9:00 に なる 街が 左へ 流れる
    private var relay: some View {
        let cities: [(String, String)] = [("TOKYO", "Asia/Tokyo"), ("SEOUL", "Asia/Seoul"), ("SYDNEY", "Australia/Sydney"), ("BANGKOK", "Asia/Bangkok"), ("DELHI", "Asia/Kolkata"), ("DUBAI", "Asia/Dubai"),
                                           ("PARIS", "Europe/Paris"), ("LONDON", "Europe/London"), ("NEW YORK", "America/New_York"), ("LOS ANGELES", "America/Los_Angeles")]
        return TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || scenePhase != .active)) { ctx in
            let now = ctx.date
            let items: [(String, Int)] = cities.compactMap { name, id in
                guard let tz = TimeZone(identifier: id) else { return nil }
                var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
                guard let next = cal.nextDate(after: now, matching: DateComponents(hour: 9, minute: 0, second: 0), matchingPolicy: .nextTime) else { return nil }
                return (name, Int(next.timeIntervalSince(now)))
            }.sorted { $0.1 < $1.1 }
            let text = items.map { "● \($0.0) \($0.1 / 3600)h \(($0.1 % 3600) / 60)m" }.joined(separator: "      ")
            let t = reduceMotion ? 0 : now.timeIntervalSinceReferenceDate
            HStack(spacing: 0) {
                Text("9:00 リレー").font(LF.mono(9)).tracking(1.2).foregroundStyle(HV.lime).padding(.leading, 16).padding(.trailing, 12)
                GeometryReader { g in
                    let w = max(1, CGFloat(text.count) * 7.4)
                    let x = -CGFloat((t * 28).truncatingRemainder(dividingBy: Double(w + 40)))
                    HStack(spacing: 40) { Text(text).fixedSize(); Text(text).fixedSize() }
                        .font(LF.mono(11)).foregroundStyle(.white.opacity(0.75)).offset(x: x).frame(height: g.size.height)
                }.clipped()
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    // MARK: 3つの 手順

    private var steps: some View {
        HStack(spacing: 0) {
            step("1", "撮る"); line; step("2", "お題の タグを つける"); line; step("3", "世界と ならぶ")
        }
    }
    private var line: some View { Rectangle().fill(.white.opacity(0.15)).frame(height: 1).frame(maxWidth: 18).padding(.horizontal, 6) }
    private func step(_ n: String, _ t: String) -> some View {
        VStack(spacing: 6) {
            Text(n).font(LF.mono(11, bold: true)).foregroundStyle(HV.ink).frame(width: 24, height: 24).background(HV.lime, in: Circle())
            Text(t).font(LF.inter(700, 11)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
        }.frame(maxWidth: .infinity)
    }
}
