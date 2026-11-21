import SwiftUI

/// v111 §7:参加の 演出「搭乗ゲート」(約 3.0 秒 ・ 右上に スキップ)。動きは offset ・ scale ・ rotation ・ opacity だけ(ぼかし なし)。
/// 参加の 処理が 終わって から 出す。終わったら `onDone`(その Trip の 画面へ)。
struct BoardingGateV111: View {
    var tripName: String
    var colorIndex: Int
    var date: Date = Date()
    var seatIndex: Int
    var memberLimit: Int
    var occupied: Int
    var myName: String
    var myAvatar: UIImage?
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var passIn = false
    @State private var torn = false
    @State private var passUp = false
    @State private var seatsIn = false
    @State private var flightStage = 0        // 0 まえ / 1 ちゅうかん / 2 席
    @State private var seated = false
    @State private var stamp = 0               // 0 まえ / 1 ドン(2.4) / 2 おちつく
    @State private var wipe = false
    @State private var shake: CGFloat = 0
    @State private var passSize: CGSize = .zero
    @State private var meLocal: CGPoint = .zero      // パスの 中の 自分の 丸の 中心(パスの 座標)
    @State private var seatLocal: CGPoint = .zero    // 席の 中心(席の 入れ物の 座標)
    @State private var seatScale: CGFloat = 1
    @State private var finished = false
    @State private var task: Task<Void, Never>?

    private var c: Color { PopColor.trip(colorIndex) }
    private var seatCount: Int { max(8, ((max(memberLimit, seatIndex + 1) + 3) / 4) * 4) }
    private var seatName: String { Self.label(seatIndex) }
    private var dateText: String { let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date) }

    static func label(_ i: Int) -> String { "\(Character(UnicodeScalar(65 + i / 4)!))\(i % 4 + 1)" }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                background
                pass.frame(width: g.size.width - 48).coordinateSpace(name: "pass")
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { passSize = $0 }
                    .offset(x: 0, y: 200)
                    .offset(y: passIn ? (passUp ? -150 : 0) : 420)
                    .rotationEffect(.degrees(passIn ? -3 : 8))
                    .scaleEffect(passUp ? 0.86 : 1)
                    .opacity(passIn ? 1 : 0)
                seats.frame(width: g.size.width - 48).coordinateSpace(name: "seats").offset(y: 400)
                    .opacity(seatsIn ? 1 : 0).offset(y: seatsIn ? 0 : 40).scaleEffect(seatsIn ? 1 : 0.96)
                if flightStage >= 1 && !seated {
                    avatar(44).scaleEffect(flightStage == 2 ? 1.35 : (flightStage == 3 ? 0.82 : 1)).rotationEffect(.degrees(flightStage == 2 ? -12 : 0))
                        .position(flierPoint(width: g.size.width)).allowsHitTesting(false).zIndex(5)
                }
                stampView.offset(y: 236)
                Circle().fill(PopColor.lime).frame(width: 40, height: 40)
                    .scaleEffect(wipe ? 46 : 0).offset(y: 300 - 20).allowsHitTesting(false)
                Button { skip() } label: {
                    Text("スキップ").font(.system(size: 12.5, weight: .bold)).foregroundStyle(Color(hex: "C9C9CF")).padding(.horizontal, 14).frame(height: 44)
                        .background(.white.opacity(0.1), in: Capsule())
                }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 16).padding(.top, g.safeAreaInsets.top + 6)
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .top)
            .coordinateSpace(name: "gate")
            .offset(x: shake)
            .ignoresSafeArea()
        }
        .onAppear { start() }
        .onDisappear { task?.cancel() }
    }

    private var background: some View {
        ZStack {
            Color(hex: "050506")
            RadialGradient(colors: [c.opacity(0.22), .clear], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }

    // MARK: パス

    private var pass: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TRIP PASS").font(LF.mono(10.5)).tracking(2.3).foregroundStyle(Color(hex: "7A776C"))
                Text(tripName).font(LGFont.mincho(32)).foregroundStyle(PopColor.ground).lineLimit(1).minimumScaleFactor(0.6)
                Text("\(dateText) ・ KEY").font(LF.mono(11.5)).foregroundStyle(Color(hex: "5A574E")).lineLimit(1)
                HStack(spacing: 14) {
                    avatar(44).opacity(flightStage == 0 ? 1 : 0)
                        .overlay { Circle().strokeBorder(c, lineWidth: 3).frame(width: 50, height: 50).opacity(flightStage == 0 ? 1 : 0) }
                        .onGeometryChange(for: CGPoint.self) { let f = $0.frame(in: .named("pass")); return CGPoint(x: f.midX, y: f.midY) } action: { meLocal = $0 }
                    VStack(alignment: .leading, spacing: 0) { Text("PASSENGER").font(LF.mono(9.5)).foregroundStyle(Color(hex: "8C8778")); Text(myName).font(.system(size: 17, weight: .black)).foregroundStyle(PopColor.ground).lineLimit(1) }
                    VStack(alignment: .leading, spacing: 0) { Text("SEAT").font(LF.mono(9.5)).foregroundStyle(Color(hex: "8C8778")); Text(seatName).font(.system(size: 17, weight: .black)).foregroundStyle(PopColor.ground) }
                }.padding(.top, 12).padding(.top, 0)
                    .overlay(alignment: .top) { Rectangle().stroke(Color(hex: "D8D4C8"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).frame(height: 1.5) }
            }
            .padding(.leading, 18).padding(.trailing, 14).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PopColor.paper, in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous))
            VStack(spacing: 4) {
                Text("GATE").font(LF.mono(9.5)).tracking(1.5)
                Text("9:00").font(.system(size: 22, weight: .black))
                HStack(spacing: 1.5) { ForEach(0..<9, id: \.self) { i in Rectangle().frame(width: i % 3 == 0 ? 2 : 1, height: 30) } }.padding(.top, 4)
            }
            .foregroundStyle(PopColor.ground)
            .frame(width: 86).frame(maxHeight: .infinity)
            .background(c, in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous))
            .overlay(alignment: .leading) { Rectangle().stroke(PopColor.ground.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [4, 3])).frame(width: 2) }
            .offset(x: torn ? 120 : 0, y: torn ? 560 : 0).rotationEffect(.degrees(torn ? 48 : 0), anchor: .topLeading).opacity(torn ? 0 : 1)
            .animation(.timingCurve(0.5, 0, 0.75, 0, duration: 0.9), value: torn)
        }
        .fixedSize(horizontal: false, vertical: true)
        .shadow(color: .black.opacity(0.55), radius: 18, y: 14)
    }

    private func avatar(_ s: CGFloat) -> some View {
        ZStack {
            if let a = myAvatar { Image(uiImage: a).resizable().scaledToFill() }
            else { LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "EE5E9C")], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Text(String(myName.prefix(1))).font(.system(size: s * 0.45, weight: .black)).foregroundStyle(.white.opacity(0.9))) }
        }.frame(width: s, height: s).clipShape(Circle())
    }

    // MARK: 席

    private var seats: some View {
        VStack(spacing: 10) {
            Text("FRONT").font(LF.mono(10)).tracking(3).foregroundStyle(.white.opacity(0.5))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<seatCount, id: \.self) { i in seat(i) }
            }
        }
        .padding(14)
        .background(PopColor.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func seat(_ i: Int) -> some View {
        let mine = i == seatIndex
        let taken = !mine && i < occupied
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "1B1B1E"))
            if mine && seated { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(c.opacity(0.22)) }
            if mine { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(c, lineWidth: 2) }
            VStack(spacing: 4) {
                if mine && seated {
                    avatar(34)
                    Text(myName).font(.system(size: 11, weight: .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                } else if taken {
                    Circle().fill(PopColor.tripCycle[i % 4]).frame(width: 34, height: 34)
                    Text(Self.label(i)).font(LF.mono(11)).foregroundStyle(Color(hex: "55555C"))
                } else {
                    Text(Self.label(i)).font(LF.mono(11)).foregroundStyle(Color(hex: "55555C"))
                }
            }.padding(.horizontal, 2)
        }
        .frame(height: 74)
        .padding(.leading, i % 4 == 2 ? 10 : 0).padding(.trailing, i % 4 == 1 ? 10 : 0)
        .onGeometryChange(for: CGPoint.self) { let f = $0.frame(in: .named("seats")); return CGPoint(x: f.midX, y: f.midY) } action: { if mine { seatLocal = $0 } }
        .scaleEffect(mine && seated ? seatScale : 1)
    }

    // MARK: スタンプ

    private var stampView: some View {
        VStack(spacing: 4) {
            Text("\(dateText) ・ \(seatName)").font(LF.mono(11)).tracking(2.2)
            Text("WELCOME\nABOARD").font(.system(size: 34, weight: .black)).tracking(1.4).multilineTextAlignment(.center).lineSpacing(0)
        }
        .foregroundStyle(PopColor.lime).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 12)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(PopColor.lime, lineWidth: 4))
        .background(Color(hex: "0A0A0B").opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .rotationEffect(.degrees(-9))
        .scaleEffect(stamp == 0 ? 2.4 : (stamp == 1 ? 0.92 : 1))
        .opacity(stamp == 0 ? 0 : 1)
    }

    // MARK: 飛ぶ アイコン

    /// ゲート全体の 座標での 位置。stage 1 = パスの 中 / 2 = 上へ(弧の いちばん 高い 所)/ 3 = 席
    private func flierPoint(width w: CGFloat) -> CGPoint {
        // パス:左 24 ・ 上 200 ・ 上へ -150 ・ 0.86 倍 ・ -3°(中心 まわり)
        let center = CGPoint(x: w / 2, y: 200 + passSize.height / 2 - 150)
        let lx = (meLocal.x - passSize.width / 2) * 0.86, ly = (meLocal.y - passSize.height / 2) * 0.86
        let th = -3.0 * .pi / 180
        let start = CGPoint(x: center.x + lx * cos(th) - ly * sin(th), y: center.y + lx * sin(th) + ly * cos(th))
        let seat = CGPoint(x: 24 + seatLocal.x, y: 400 + seatLocal.y)
        switch flightStage {
        case 1: return start
        case 2: return CGPoint(x: (start.x + seat.x) / 2, y: (start.y + seat.y) / 2 - 90)
        default: return seat
        }
    }

    // MARK: 進行

    private func start() {
        if reduceMotion {
            passIn = true; stamp = 2; seated = true; flightStage = 3; seatsIn = true
            Haptics.play(.success)
            task = Task { try? await Task.sleep(for: .milliseconds(900)); if !Task.isCancelled { finish() } }
            return
        }
        task = Task { @MainActor in
            func at(_ ms: Int, from: inout Int) async { try? await Task.sleep(for: .milliseconds(ms - from)); from = ms }
            var now = 0
            Haptics.play(.soft)
            withAnimation(.spring(response: 0.52, dampingFraction: 0.62)) { passIn = true }
            await at(620, from: &now); if Task.isCancelled { return }
            Haptics.play(.edge)
            torn = true
            withAnimation(.spring(response: 0.56, dampingFraction: 0.7).delay(0.12)) { passUp = true }
            await at(900, from: &now); if Task.isCancelled { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { seatsIn = true }
            await at(1180, from: &now); if Task.isCancelled { return }
            Haptics.play(.stretch)
            flightStage = 1
            try? await Task.sleep(for: .milliseconds(30)); now += 30
            withAnimation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.26)) { flightStage = 2 }
            await at(1470, from: &now); if Task.isCancelled { return }
            withAnimation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.26)) { flightStage = 3 }
            await at(1740, from: &now); if Task.isCancelled { return }
            seatScale = 0.8
            seated = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { seatScale = 1 }
            Haptics.play(.land)
            await at(1960, from: &now); if Task.isCancelled { return }
            Haptics.play(.thud)
            withAnimation(.timingCurve(0.2, 1.4, 0.4, 1, duration: 0.2)) { stamp = 1 }
            withAnimation(.timingCurve(0.2, 1.4, 0.4, 1, duration: 0.22).delay(0.2)) { stamp = 2 }
            for dx: CGFloat in [2, -2, 1, 0] { withAnimation(.linear(duration: 0.045)) { shake = dx }; try? await Task.sleep(for: .milliseconds(45)) }
            await at(2560, from: &now); if Task.isCancelled { return }
            Haptics.play(.success)
            withAnimation(.timingCurve(0.6, 0, 0.3, 1, duration: 0.5)) { wipe = true }
            await at(3050, from: &now); if Task.isCancelled { return }
            finish()
        }
    }

    private func skip() { task?.cancel(); finish() }
    private func finish() { guard !finished else { return }; finished = true; onDone() }
}

