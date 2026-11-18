import SwiftUI

// P22-C(v78)+ P23-C(v79)+ P24-C(v80)+ v82:Mondo タブ。見本:Y03 Y05 Y08〜Y12 Y16 Y17。
// 3つの 場面:投稿が ない 日(No Mondo today.)/ 地球の 画面(字なし ・ 写真の ピン ・ 弧 ・ 丸い ボタン)/ ひらいた 後(地球 ・ 数字 ・ ランキング ・ Mondo って? ・ TODAY'S ONE ・ 世界の きのう)。
// 地球は Canvas(線だけ ・ ぼかし なし)。見えない とき ・ Reduce Motion では 止める。

struct YesterdayMondoInput {
    struct Tag: Identifiable { let id: String; var name: String; var count: Int; var cities: Int; var photos: [UIImage?]; var delta: Int? }
    struct City: Identifiable { let id: String; var name: String; var lat: Double; var lon: Double; var photo: UIImage? }
    struct Shot: Identifiable { let id: String; var photo: UIImage?; var city: String; var time: String; var tag: String? }
    var hasPosts = false
    var startOpened = false
    var dayLabel = "11/16"
    var shots = 2431
    var citiesCount = 128
    var tags: [Tag] = []
    var cities: [City] = []
    var todaysOne: Shot?
    var world: [Shot] = []
    var filterTag: String?
    var nextOpenSeconds = 70485
}

struct YesterdayMondoView: View {
    var input: YesterdayV64Input
    var actions: YesterdayV64Actions
    var active: Bool
    var locked: Bool
    var onScroll: (CGFloat) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var opened = false
    @State private var seeded = false
    @State private var spin: Double = 0
    @State private var speed: Double = 10
    @State private var dragSpin: Double = 0
    @State private var lastTickAngle: Double = 0
    @State private var rising = false
    @State private var filter: String?
    @State private var notify = false
    @State private var count = 0.0
    @State private var pos = ScrollPosition()

    private var m: YesterdayMondoInput { input.mondo }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if !m.hasPosts { MondoWaitV95View(input: input, actions: actions) }
                    else if !opened { stage }
                    else { openedBody(proxy: proxy) }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollPosition($pos)
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in onScroll(v) }
        }
        .background(Color.black)
        .onAppear {
            if !seeded { seeded = true; opened = m.startOpened; filter = m.filterTag
                if let y = input.debugScrollY, input.startTab == 1 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { pos.scrollTo(y: y) } } }
        }
    }

    // MARK: 投稿が ない 日(Y08 Y09)v87:ぜんぶ まんなか そろえ。字は へらす。大きい 部品は 並びの 中に 置かない

    private var empty: some View {
        let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MM/dd"; return f }()
        return VStack(spacing: 0) {
            Globe(spin: 0, tilt: 23, radius: 150, cities: [], lines: 0.14, rim: 0.2, glow: false)
                .frame(width: 300, height: 300).padding(.top, 130)
            Text(m.dayLabel.isEmpty ? df.string(from: input.now) : m.dayLabel).font(LF.mono(10.5)).tracking(2.3).foregroundStyle(.white.opacity(0.45)).padding(.top, 28)
            Text("No Mondo").font(LF.serif(46)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 6)
            countdown.padding(.top, 22)
            HStack(spacing: 10) {
                Button { Haptics.play(.click); actions.shoot() } label: {
                    HStack(spacing: 10) { Image(systemName: "camera").font(.system(size: 19, weight: .semibold)); Text("撮る").font(LF.inter(900, 17)) }.foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(HV.lime, in: Capsule())
                }.buttonStyle(HVPress(scale: 0.97))
                Button { Haptics.play(.success); notify.toggle() } label: {
                    Image(systemName: notify ? "bell.fill" : "bell").font(.system(size: 20, weight: .semibold)).foregroundStyle(notify ? HV.ink : .white).frame(width: 56, height: 56)
                        .background(notify ? HV.lime : Color.white.opacity(0.08), in: Circle()).overlay(Circle().strokeBorder(notify ? .clear : .white.opacity(0.2), lineWidth: 1))
                }.buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("9:00 に 知らせる")
            }.padding(.horizontal, 16).padding(.top, 26)
            Color.clear.frame(height: 160)
        }.frame(maxWidth: .infinity).clipped()
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let cal = Calendar.current
            let next = cal.nextDate(after: input.now, matching: DateComponents(hour: 9, minute: 0, second: 0), matchingPolicy: .nextTime) ?? input.now
            let el = Int(ctx.date.timeIntervalSince(startDate))
            let sec = max(0, UserDefaults.standard.bool(forKey: "debugMock") ? 4 * 3600 + 36 * 60 + 48 - el : Int(next.timeIntervalSince(input.now)) - el)
            VStack(spacing: 6) {
                Text("NEXT").font(LF.mono(10)).tracking(2).foregroundStyle(HV.lime)
                HStack(spacing: 0) {
                    Text("\(sec / 3600):\(String(format: "%02d", (sec % 3600) / 60))").foregroundStyle(.white)
                    Text(":\(String(format: "%02d", sec % 60))").foregroundStyle(.white.opacity(0.35))
                }.font(LF.inter(700, 44)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.1)); Capsule().fill(HV.lime).frame(width: 230 * CGFloat(1 - Double(sec) / 86400)) }.frame(width: 230, height: 4).padding(.top, 6)
            }
        }
    }
    @State private var startDate = Date()

    // MARK: 地球の 画面(Y10)。字は 使わない

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            Stars().frame(height: 844)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !active || scenePhase != .active)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let ang = reduceMotion ? 0 : spin + t.truncatingRemainder(dividingBy: 3600) * speed + dragSpin
                ZStack {
                    Globe(spin: ang, tilt: 23, radius: 178, cities: m.cities, lines: 0.26, rim: 0.45, glow: true, arcs: true, pinsOn: true, t: t).frame(width: 440, height: 440)
                    // 広がる 輪(押せる 合図)
                    ForEach(0..<2, id: \.self) { i in
                        let u = ((t + Double(i) * 1.1).truncatingRemainder(dividingBy: 2.2)) / 2.2
                        Circle().stroke(HV.lime.opacity(0.35 * (1 - u)), lineWidth: 1.5).frame(width: 356 + 70 * u, height: 356 + 70 * u)
                    }
                }.frame(width: 440, height: 440)
            }
            .offset(x: (UIScreen.main.bounds.width - 440) / 2, y: 162).opacity(rising ? 0 : 1).scaleEffect(rising ? 2.6 : 1).animation(.easeIn(duration: 0.6), value: rising)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                dragSpin = Double(v.translation.width) * 0.35
                if abs(dragSpin - lastTickAngle) > 18 { lastTickAngle = dragSpin; Haptics.play(.tick) }
            }.onEnded { v in
                if abs(v.translation.width) < 6 && abs(v.translation.height) < 6 { open() } else { spin += dragSpin; dragSpin = 0 }
            })
            .accessibilityLabel("Mondo を ひらく。指で 地球を まわせます").accessibilityAddTraits(.isButton)
            Button { open() } label: {
                ZStack {
                    Circle().fill(HV.lime.opacity(0.18)).frame(width: 80, height: 80)
                    Circle().fill(HV.lime).frame(width: 68, height: 68).shadow(color: HV.lime.opacity(0.5), radius: 16)
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 22, weight: .heavy)).foregroundStyle(HV.ink)
                }
            }.buttonStyle(HVPress(scale: 0.92)).offset(x: (UIScreen.main.bounds.width - 80) / 2, y: 642).accessibilityLabel("Mondo を ひらく")
        }.frame(height: 844, alignment: .topLeading)
    }

    private func open() {
        guard !rising else { return }
        Haptics.play(.rumble)
        withAnimation(.easeIn(duration: 0.9)) { speed = 120 }
        rising = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            Haptics.play(.success)
            speed = 10
            withAnimation(.easeOut(duration: 0.4)) { opened = true; rising = false }
        }
    }

    // MARK: ひらいた 後(Y03 Y05 Y12 Y16 Y17)

    @ViewBuilder private func openedBody(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !active || scenePhase != .active)) { ctx in
                    Globe(spin: reduceMotion ? 0 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) * 10, tilt: 23, radius: 160, cities: m.cities, lines: 0.24, rim: 0.45, glow: false, labels: true)
                        .frame(width: 340, height: 340)
                }
            }.frame(maxWidth: .infinity).padding(.top, 127)
            HStack(spacing: 28) {
                stat("2,431", "SHOTS", lime: true); stat("128", "CITIES", lime: false); stat("9:00", "OPENS", lime: false)
            }.frame(maxWidth: .infinity).padding(.top, 14)
            // ランキング
            HStack(alignment: .firstTextBaseline) {
                Text("きのうの タグ ランキング").font(LF.inter(800, 18)).foregroundStyle(.white)
                Spacer()
                Text("WORLD ・ TOP \(min(8, m.tags.count))").font(LF.mono(10.5)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
            }.padding(.horizontal, 16).padding(.top, 44)
            ranking.padding(.horizontal, 16).padding(.top, 12)
            // Mondo って?
            HStack { Text("Mondo って?").font(LF.inter(900, 18)).foregroundStyle(.white); Spacer(); Text("SWIPE →").font(LF.mono(10.5)).tracking(1.5).foregroundStyle(.white.opacity(0.4)) }.padding(.horizontal, 16).padding(.top, 44)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) { ForEach(0..<4, id: \.self) { i in explainer(i) } }.padding(.horizontal, 0)
            }.padding(.top, 12)
            // TODAY'S ONE
            if let one = m.todaysOne { todaysOne(one).padding(.horizontal, 16).padding(.top, 36) }
            // 世界の きのう
            HStack { Text(filter.map { "#\($0)" } ?? "世界の きのう").font(LF.inter(800, 18)).foregroundStyle(filter == nil ? .white : HV.lime).id("world")
                if filter != nil { Button { Haptics.play(.tick); withAnimation { filter = nil } } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .black)).foregroundStyle(HV.ink).frame(width: 22, height: 22).background(HV.lime, in: Circle()) }.buttonStyle(.plain) }
                Spacer() }.padding(.horizontal, 16).padding(.top, 30)
            world.padding(.horizontal, 16).padding(.top, 12)
            Color.clear.frame(height: 150)
        }
    }

    private func stat(_ n: String, _ l: String, lime: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(n).font(LF.inter(900, 26)).foregroundStyle(lime ? HV.lime : .white)
            Text(l).font(LF.mono(10.5)).tracking(1.6).foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: ランキング(1位 ・ 2〜3位 ・ 4〜8位)

    private var ranking: some View {
        VStack(spacing: 10) {
            if let t = m.tags.first { rankFirst(t) }
            if m.tags.count > 2 {
                HStack(spacing: 10) { rankSmall(m.tags[1], "02"); rankSmall(m.tags[2], "03") }
            }
            if m.tags.count > 3 {
                VStack(spacing: 0) {
                    ForEach(Array(m.tags.enumerated()).filter { $0.offset >= 3 && $0.offset < 8 }, id: \.element.id) { i, t in
                        rankRow(t, i, maxCount: Double(m.tags[0].count))
                        if i < min(7, m.tags.count - 1) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1).padding(.leading, 14) }
                    }
                }.background(Color(hex: "0E0F10"), in: RoundedRectangle(cornerRadius: 22, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
            }
        }
    }

    private func delta(_ d: Int?, big: Bool = false) -> some View {
        Group {
            if let d, d > 0 { Text("▲\(d)").foregroundStyle(HV.lime) } else if let d, d < 0 { Text("▼\(-d)").foregroundStyle(.white.opacity(0.45)) } else { Text("—").foregroundStyle(.white.opacity(0.45)) }
        }.font(LF.mono(big ? 12 : 11)).fontWeight(.bold)
    }

    private func rankFirst(_ t: YesterdayMondoInput.Tag) -> some View {
        Button { Haptics.play(.pop); pick(t.name) } label: {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(0..<2, id: \.self) { i in
                        Color.clear.overlay { if t.photos.indices.contains(i), let im = t.photos[i] { Image(uiImage: im).resizable().scaledToFill() } else { Color(hex: "2A2326") } }.clipped()
                    }
                }
                LinearGradient(stops: [.init(color: .black.opacity(0.1), location: 0), .init(color: Color(hex: "0B2A13").opacity(0.55), location: 0.55), .init(color: Color(hex: "0B1E10").opacity(0.96), location: 1)], startPoint: .top, endPoint: .bottom)
                Text("01").font(LF.inter(900, 22)).foregroundStyle(HV.ink).frame(width: 44, height: 44).background(HV.lime, in: Circle()).padding(14)
                delta(t.delta, big: true).padding(.horizontal, 10).frame(height: 30).background(.black.opacity(0.45), in: Capsule()).frame(maxWidth: .infinity, alignment: .trailing).padding(14)
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    (Text("#").foregroundColor(HV.lime) + Text(t.name).foregroundColor(.white)).font(LF.inter(900, 46)).minimumScaleFactor(0.6).lineLimit(1)
                    Text("\(t.count.formatted()) 枚 ・ \(t.cities) 都市 ・ いちばん 撮られた タグ").font(LF.mono(11)).foregroundStyle(.white.opacity(0.75))
                }.padding(16)
            }.frame(height: 236).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.98))
    }

    private func rankSmall(_ t: YesterdayMondoInput.Tag, _ rank: String) -> some View {
        Button { Haptics.play(.pop); pick(t.name) } label: {
            ZStack(alignment: .topLeading) {
                Color.clear.overlay { if let im = t.photos.first, let im { Image(uiImage: im).resizable().scaledToFill() } else { Color(hex: "2A2326") } }.clipped()
                LinearGradient(colors: [.black.opacity(0.1), Color(hex: "0B1E10").opacity(0.92)], startPoint: .top, endPoint: .bottom)
                Text(rank).font(LF.inter(900, 20)).foregroundStyle(.white).padding(14)
                delta(t.delta).frame(maxWidth: .infinity, alignment: .trailing).padding(14)
                VStack(alignment: .leading, spacing: 4) { Spacer(); (Text("#").foregroundColor(HV.lime) + Text(t.name).foregroundColor(.white)).font(LF.inter(900, 24)).lineLimit(1).minimumScaleFactor(0.6); Text("\(t.count.formatted()) 枚").font(LF.mono(11)).foregroundStyle(.white.opacity(0.7)) }.padding(14)
            }.frame(height: 168).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.98))
    }

    private func rankRow(_ t: YesterdayMondoInput.Tag, _ idx: Int, maxCount: Double) -> some View {
        Button { Haptics.play(.pop); pick(t.name) } label: {
            HStack(spacing: 10) {
                Text(String(format: "%02d", idx + 1)).font(LF.inter(900, 15)).foregroundStyle(.white.opacity(0.45)).frame(width: 28, alignment: .leading)
                ZStack(alignment: .leading) {
                    ForEach(Array(t.photos.prefix(2).enumerated()), id: \.offset) { i, im in
                        Color.clear.overlay { if let im { Image(uiImage: im).resizable().scaledToFill() } else { Color(hex: "2A2326") } }.frame(width: 26, height: 34).clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.black, lineWidth: 1.5)).offset(x: CGFloat(i) * 16)
                    }
                }.frame(width: 44, height: 34, alignment: .leading)
                (Text("#").foregroundColor(HV.lime) + Text(t.name).foregroundColor(.white)).font(LF.inter(800, 15.5)).lineLimit(1).frame(width: 88, alignment: .leading)
                ZStack(alignment: .leading) { Capsule().fill(.white.opacity(0.1)); GeometryReader { g in Capsule().fill(Color(hex: "3BD35A")).frame(width: max(8, g.size.width * CGFloat(Double(t.count) / maxCount))) } }.frame(height: 6)
                Text("\(t.count)").font(LF.mono(11)).foregroundStyle(.white.opacity(0.5)).frame(width: 34, alignment: .trailing)
                delta(t.delta).frame(width: 28, alignment: .trailing)
            }.padding(.horizontal, 14).frame(height: 54)
        }.buttonStyle(.plain)
    }

    private func pick(_ name: String) {
        withAnimation(.easeOut(duration: 0.3)) { filter = name }
    }

    // MARK: Mondo って?(図の カード)

    private func explainer(_ i: Int) -> some View {
        let items: [(String, String)] = [("撮った 1枚が 世界へ", "公開を えらんだ 写真だけ"), ("次の 朝 9:00 に ひらく", "どの 国も 同じ 9:00"), ("TODAY'S ONE", "いちばん 見られた 1枚が 表紙に"), ("# で 世界の 気分が わかる", "きのう 多かった タグの ランキング")]
        return VStack(alignment: .leading, spacing: 0) {
            ExplainerFigure(index: i).frame(height: 100)
            Text(items[i].0).font(LF.inter(900, 15)).foregroundStyle(.white).padding(.top, 14)
            Text(items[i].1).font(LF.inter(500, 12.5)).foregroundStyle(.white.opacity(0.5)).padding(.top, 4)
        }.padding(14).frame(width: 236, alignment: .leading).background(Color(hex: "0E0F10"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1)).padding(.leading, i == 0 ? 0 : 0)
    }

    private func todaysOne(_ s: YesterdayMondoInput.Shot) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.overlay { if let im = s.photo { Image(uiImage: locked ? V64Images.blurred(key: "mondoone", source: im, maxPixel: 48, radius: 14, saturation: 1, brightness: 0.6) : im).resizable().scaledToFill() } else { Color(hex: "2A2326") } }.clipped()
            LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
            Text("TODAY'S ONE ・ 9:00").font(LF.mono(11)).tracking(2).foregroundStyle(HV.lime).padding(16)
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text(s.city).font(LF.inter(900, 30)).foregroundStyle(.white)
                Text("JAPAN ・ \(s.time)" + (s.tag.map { " ・ #\($0)" } ?? "")).font(LF.mono(11)).foregroundStyle(.white.opacity(0.75))
                if locked { Text("今日 1枚 撮ると ひらく").font(LF.inter(600, 12.5)).foregroundStyle(.white.opacity(0.6)) }
            }.padding(18)
        }.frame(height: 448).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var world: some View {
        let list = filter == nil ? m.world : m.world.filter { $0.tag == filter }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
            ForEach(list) { s in
                ZStack(alignment: .bottomLeading) {
                    Color.clear.aspectRatio(3 / 4, contentMode: .fit).overlay { if let im = s.photo { Image(uiImage: locked ? V64Images.blurred(key: "mw\(s.id)", source: im, maxPixel: 48, radius: 10, saturation: 1, brightness: 0.6) : im).resizable().scaledToFill() } else { Color(hex: "2A2326") } }.clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 2) { Text(s.city).font(LF.inter(800, 13)).foregroundStyle(.white); Text(s.time).font(LF.mono(10)).foregroundStyle(.white.opacity(0.7)) }.padding(10)
                    if let tag = s.tag { Text("#\(tag)").font(LF.inter(800, 10.5)).foregroundStyle(HV.ink).padding(.horizontal, 8).frame(height: 20).background(HV.lime, in: Capsule()).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8) }
                }.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

// MARK: - 部品

/// 星(うすく またたく)
private struct Stars: View {
    var body: some View {
        Canvas { ctx, size in
            for (x, y, a, r) in [(0.20, 0.16, 0.5, 1.0), (0.52, 0.21, 0.35, 1.2), (0.78, 0.17, 0.5, 1.0), (0.89, 0.62, 0.45, 1.2), (0.06, 0.74, 0.4, 1.0), (0.64, 0.12, 0.65, 1.2), (0.31, 0.5, 0.35, 1.0), (0.84, 0.36, 0.5, 1.0)] {
                ctx.fill(Path(ellipseIn: CGRect(x: x * size.width, y: y * size.height, width: r * 1.5, height: r * 1.5)), with: .color(.white.opacity(a)))
            }
        }.allowsHitTesting(false)
    }
}

/// 地球(正射図 + 傾き)。線 = 緑 ・ ふち = 黄緑。`pinsOn` = 写真の ピン ・ `arcs` = 都市を むすぶ 点線の 弧
struct Globe: View {
    var spin: Double
    var tilt: Double
    var radius: CGFloat
    var cities: [YesterdayMondoInput.City]
    var lines: Double
    var rim: Double
    var glow: Bool
    var arcs = false
    var pinsOn = false
    var t: Double = 0
    var labels = false

    private func project(_ lat: Double, _ lon: Double) -> (x: Double, y: Double, z: Double) {
        let la = lat * .pi / 180, lo = (lon + spin) * .pi / 180, ti = tilt * .pi / 180
        let x = cos(la) * sin(lo), y0 = sin(la), z0 = cos(la) * cos(lo)
        let y = y0 * cos(ti) - z0 * sin(ti), z = y0 * sin(ti) + z0 * cos(ti)
        return (x, y, z)
    }

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2), r = Double(radius)
                if glow {
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - r - 20, y: c.y - r - 20, width: 2 * r + 40, height: 2 * r + 40)), with: .radialGradient(Gradient(stops: [.init(color: .clear, location: 0.82), .init(color: Color(hex: "C8F25A").opacity(0.22), location: 0.9), .init(color: Color(hex: "3BD35A").opacity(0.08), location: 0.96), .init(color: .clear, location: 1)]), center: c, startRadius: 0, endRadius: r + 20))
                }
                let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(disc, with: .radialGradient(Gradient(colors: [Color(hex: "173320"), Color(hex: "07130B"), Color(hex: "020403")]), center: CGPoint(x: c.x - r * 0.25, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.3))
                let green = Color(hex: "3BD35A").opacity(lines)
                func line(_ pts: [(Double, Double)], _ col: Color) {
                    var p = Path(); var pen = false
                    for (lat, lon) in pts {
                        let q = project(lat, lon)
                        if q.z > 0 { let pt = CGPoint(x: c.x + q.x * r, y: c.y - q.y * r); if pen { p.addLine(to: pt) } else { p.move(to: pt); pen = true } } else { pen = false }
                    }
                    ctx.stroke(p, with: .color(col), lineWidth: 0.9)
                }
                for lat in stride(from: -60.0, through: 60.0, by: 30.0) { line(stride(from: -180.0, through: 180.0, by: 4.0).map { (lat, $0) }, green) }
                for lon in stride(from: -180.0, to: 180.0, by: 20.0) { line(stride(from: -90.0, through: 90.0, by: 4.0).map { ($0, lon) }, green) }
                ctx.stroke(disc, with: .color(Color(hex: "C8F25A").opacity(rim)), lineWidth: 1.3)
                // 都市の 点
                for city in cities {
                    let q = project(city.lat, city.lon)
                    guard q.z > 0.05 else { continue }
                    let p = CGPoint(x: c.x + q.x * r, y: c.y - q.y * r)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(Color(hex: "C8F25A").opacity(0.18 * q.z)))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.4, y: p.y - 3.4, width: 6.8, height: 6.8)), with: .color(Color(hex: "C8F25A").opacity(0.4 + 0.6 * q.z)))
                    if labels && q.z > 0.55 { ctx.draw(Text(city.name).font(LF.mono(9)).foregroundColor(.white.opacity(0.8)), at: CGPoint(x: p.x + 8, y: p.y), anchor: .leading) }
                }
                if arcs {
                    let vis = cities.filter { project($0.lat, $0.lon).z > 0.1 }
                    for i in 0..<max(0, vis.count - 1) {
                        let a = project(vis[i].lat, vis[i].lon), b = project(vis[i + 1].lat, vis[i + 1].lon)
                        let pa = CGPoint(x: c.x + a.x * r, y: c.y - a.y * r), pb = CGPoint(x: c.x + b.x * r, y: c.y - b.y * r)
                        let mid = CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
                        let d = hypot(pb.x - pa.x, pb.y - pa.y), nx = (mid.x - c.x), ny = (mid.y - c.y), nl = max(1, hypot(nx, ny))
                        let ctl = CGPoint(x: mid.x + nx / nl * d * 0.35, y: mid.y + ny / nl * d * 0.35)
                        var p = Path(); p.move(to: pa); p.addQuadCurve(to: pb, control: ctl)
                        ctx.stroke(p, with: .color(Color(hex: "C8F25A").opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, dash: [3, 5], dashPhase: -t * 14))
                    }
                }
            }
            if pinsOn {
                GeometryReader { g in
                    ForEach(cities.filter { $0.photo != nil }) { city in
                        let q = project(city.lat, city.lon)
                        if q.z > 0.1 {
                            let k = 0.55 + 0.45 * q.z
                            VStack(spacing: 0) {
                                Image(uiImage: city.photo!).resizable().scaledToFill().frame(width: 36, height: 46).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color(hex: "C8F25A"), lineWidth: 1.5)).padding(2).background(Color.black, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                Rectangle().fill(Color(hex: "C8F25A")).frame(width: 2, height: 8)
                            }
                            .scaleEffect(k).opacity(min(1, (q.z - 0.1) * 4))
                            .position(x: g.size.width / 2 + CGFloat(q.x) * (radius + 14), y: g.size.height / 2 - CGFloat(q.y) * (radius + 14) - 28 * k)
                        }
                    }
                }
            }
        }
    }
}

/// 「Mondo って?」の 図(線 ・ 図形 だけ)
private struct ExplainerFigure: View {
    let index: Int
    var body: some View {
        Canvas { ctx, size in
            let lime = Color(hex: "C8F25A"), green = Color(hex: "3BD35A")
            switch index {
            case 0:
                ctx.stroke(Path(roundedRect: CGRect(x: 8, y: 6, width: 44, height: 78), cornerRadius: 9), with: .color(.white), lineWidth: 2)
                ctx.fill(Path(roundedRect: CGRect(x: 15, y: 13, width: 30, height: 48), cornerRadius: 5), with: .color(green))
                var arc = Path(); arc.move(to: CGPoint(x: 70, y: 40)); arc.addQuadCurve(to: CGPoint(x: 142, y: 26), control: CGPoint(x: 105, y: -2))
                ctx.stroke(arc, with: .color(lime), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                ctx.stroke(Path(ellipseIn: CGRect(x: 150, y: 14, width: 56, height: 56)), with: .color(lime), lineWidth: 2)
                ctx.stroke(Path(ellipseIn: CGRect(x: 164, y: 14, width: 28, height: 56)), with: .color(green), lineWidth: 1.5)
            case 1:
                ctx.fill(Path(ellipseIn: CGRect(x: 30, y: 22, width: 20, height: 20)), with: .color(lime))
                ctx.stroke(Path(ellipseIn: CGRect(x: 120, y: 10, width: 70, height: 70)), with: .color(.white), lineWidth: 2)
                var h = Path(); h.move(to: CGPoint(x: 155, y: 45)); h.addLine(to: CGPoint(x: 155, y: 20)); ctx.stroke(h, with: .color(lime), lineWidth: 2.5)
                var m = Path(); m.move(to: CGPoint(x: 155, y: 45)); m.addLine(to: CGPoint(x: 135, y: 45)); ctx.stroke(m, with: .color(.white), lineWidth: 2.5)
            case 2:
                for (i, x) in [20.0, 78.0, 136.0].enumerated() {
                    ctx.fill(Path(roundedRect: CGRect(x: x, y: i == 1 ? 8 : 26, width: 52, height: 66), cornerRadius: 8), with: .color(i == 1 ? lime.opacity(0.9) : .white.opacity(0.14)))
                }
            default:
                for (i, w) in [120.0, 84.0, 52.0].enumerated() {
                    ctx.fill(Path(roundedRect: CGRect(x: 10, y: 8 + Double(i) * 30, width: 38, height: 20), cornerRadius: 10), with: .color(i == 0 ? lime : .white.opacity(0.14)))
                    ctx.fill(Path(roundedRect: CGRect(x: 58, y: 14 + Double(i) * 30, width: w, height: 8), cornerRadius: 4), with: .color(green))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
