import SwiftUI

// P12-C(v68):Shake モード(全画面・黒)。見本:K01〜K06・M15。
// この View は「いまの 状態」と「相手」を うけとって 描く だけ。ふった 判定 ・ 通信は `ShakeSession`(M5)。
// 状態:idle(ふる まえ)/ seek(さがす)/ found(見つけた)/ wait(まつ)/ done(つながった)/ none(見つからない)。

enum ShakeV68Phase: String, CaseIterable { case idle, seek, found, wait, done, none }

struct ShakeV68Peer: Equatable {
    var name: String
    var handle: String
    var photo: UIImage?
    var tags: [String] = []
    static func == (a: Self, b: Self) -> Bool { a.name == b.name && a.handle == b.handle }
}

struct ShakeV68View: View {
    var phase: ShakeV68Phase
    var me: UIImage?
    var myName = ""
    var peer: ShakeV68Peer?
    var onClose: () -> Void = {}
    var onConnect: () -> Void = {}
    var onNotThem: () -> Void = {}
    var onQR: () -> Void = {}
    var onID: () -> Void = {}
    /// ローカルネットワークを ことわられた とき「QR で つながる」を 目立たせる
    var emphasizeQR = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var drop = false          // 相手の 丸が 落ちて きた
    @State private var flash = false         // ぶつかった 白い 光
    @State private var ripple = false        // 白い 波紋
    @State private var bump = false          // 丸ぜんたいの 1 → 1.08 → 1
    @State private var around = false        // つながった:黄緑の 線
    @State private var hapticTask: Task<Void, Never>?

    private var animating: Bool { !reduceMotion && scenePhase == .active }
    private let tagColors = [Color(hex: "EE5E9C"), Color(hex: "FFD60A"), Color(hex: "9ED8FF")]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, mid = (g.size.height - 844) / 2
            ZStack {
                background(w: w, h: g.size.height)
                rings(w: w).position(x: w / 2, y: (phase == .found || phase == .wait ? 272 : (phase == .done ? 300 : 330)) + mid)
                content(w: w, mid: mid)
                header(w: w)
                if phase == .idle { bottom(w: w, h: g.size.height) }
                if flash { Color.white.opacity(0.22).ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
            }
            .frame(width: w, height: g.size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onChange(of: phase) { _, p in enter(p) }
        .onAppear { enter(phase, first: true) }
        .onDisappear { hapticTask?.cancel() }
    }

    // MARK: うしろ

    @ViewBuilder private func background(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color.black
            if (phase == .found || phase == .wait || phase == .done), let p = peer?.photo {
                Image(uiImage: V64Images.blurred(key: "sk\(ObjectIdentifier(p).hashValue)", source: p, maxPixel: 96, radius: 30, saturation: 1.2, brightness: 0.46))
                    .resizable().scaledToFill().frame(width: w, height: h).clipped().transition(.opacity)
            } else {
                RadialGradient(colors: [Color(red: 36 / 255, green: 160 / 255, blue: 60 / 255).opacity(0.42), .clear], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 360)
                RadialGradient(colors: [Color(hex: "C8F25A").opacity(0.14), .clear], center: UnitPoint(x: 0.0, y: 0.85), startRadius: 0, endRadius: 280)
            }
            HVGrain().opacity(0.12).blendMode(.overlay)
        }
        .animation(.easeInOut(duration: 0.5), value: phase == .found || phase == .wait || phase == .done)
        .ignoresSafeArea().allowsHitTesting(false)
    }

    // MARK: 輪(4本 + 黄緑の ひろがる 輪 + レーダー)

    private func rings(w: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating || !(phase == .idle || phase == .seek))) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let speed = phase == .seek ? 2.6 / 0.9 : 1.0
            ZStack {
                ForEach([190.0, 290, 390, 500], id: \.self) { d in
                    Circle().strokeBorder(.white.opacity(d < 300 ? 0.12 : 0.05), lineWidth: 1).frame(width: d, height: d)
                }
                if phase == .idle || phase == .seek {
                    ForEach(0..<3, id: \.self) { i in
                        let p = animating ? ((t * speed / 2.6) + Double(i) / 3).truncatingRemainder(dividingBy: 1) : Double(i) / 3
                        Circle().strokeBorder(Color(hex: "C8F25A").opacity(0.5 * (1 - p)), lineWidth: 2).frame(width: 116 * (1 + 3.2 * p), height: 116 * (1 + 3.2 * p))
                    }
                }
                if phase == .seek {
                    let a = animating ? (t / 1.1).truncatingRemainder(dividingBy: 1) * 360 : 0
                    Circle().fill(AngularGradient(stops: [.init(color: .clear, location: 0.0), .init(color: HV.lime.opacity(0.32), location: 0.25), .init(color: .clear, location: 0.26), .init(color: .clear, location: 1)], center: .center))
                        .frame(width: 290, height: 290).rotationEffect(.degrees(a))
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 中身

    @ViewBuilder private func content(w: CGFloat, mid: CGFloat) -> some View {
        switch phase {
        case .idle, .seek: idleBody(w: w, mid: mid)
        case .found, .wait: foundBody(w: w, mid: mid)
        case .done: doneBody(w: w, mid: mid)
        case .none: noneBody(w: w, mid: mid)
        }
    }

    private func photo(_ img: UIImage?, name: String, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: "3A3A3C"))
            if let img { Image(uiImage: img).resizable().scaledToFill() } else { Text(String(name.prefix(1))).font(LF.inter(800, size * 0.4)).foregroundStyle(.white) }
        }.frame(width: size, height: size).clipShape(Circle()).overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }

    private func idleBody(w: CGFloat, mid: CGFloat) -> some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animating)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let breath = animating ? 1 + 0.04 * (0.5 + 0.5 * sin(t * 2 * .pi / 2.6)) : 1
                let trem = phase == .seek && animating
                photo(me, name: myName, size: 116).scaleEffect(breath)
                    .offset(x: trem ? sin(t * 2 * .pi / 0.16) * 5 : 0, y: trem ? cos(t * 2 * .pi / 0.16) * 3 : 0)
                    .rotationEffect(.degrees(trem ? sin(t * 2 * .pi / 0.16) * 7 : 0))
            }.position(x: w / 2, y: 330 + mid)
            Circle().fill(HV.lime).frame(width: 6, height: 6).shadow(color: HV.lime, radius: 4).position(x: w / 2 - 36, y: 258 + mid)
            if phase == .idle { PhoneMark(shaking: animating).position(x: w / 2, y: 500 + mid) }
            Text(phase == .seek ? "さがして います…" : "スマホを ふって").font(LF.inter(900, 30)).foregroundStyle(.white).position(x: w / 2, y: 574 + mid)
            Text(phase == .seek ? "そのまま ちかくに" : "となりの 友だちも いっしょに").font(LF.inter(600, 15)).foregroundStyle(.white.opacity(0.72)).position(x: w / 2, y: 616 + mid)
        }
    }

    private func foundBody(w: CGFloat, mid: CGFloat) -> some View {
        let waiting = phase == .wait
        return ZStack {
            ZStack {
                photo(peer?.photo, name: peer?.name ?? "", size: 116).offset(x: -44, y: drop ? 0 : -470).scaleEffect(drop ? 1 : 0.7)
                photo(me, name: myName, size: 116).offset(x: 44)
                if ripple { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2).frame(width: 116, height: 116).scaleEffect(6).opacity(0).transition(.opacity) }
            }
            .scaleEffect(bump ? 1.08 : 1)
            .position(x: w / 2, y: 272 + mid)
            Text("見つけた").font(LF.inter(900, 34)).foregroundStyle(.white).position(x: w / 2, y: 405 + mid)
            Text("ちかくで いっしょに ふった 人").font(LF.inter(600, 15)).foregroundStyle(.white.opacity(0.72)).position(x: w / 2, y: 443 + mid)
            // 下から カード(ガラス ・ 角丸 38)
            VStack(spacing: 0) {
                Text(peer?.name ?? "").font(LGFont.mincho(40)).foregroundStyle(.white).lineLimit(1).padding(.top, 12)
                Text("@\(peer?.handle ?? "")").font(LF.mono(11)).foregroundStyle(.white.opacity(0.55)).padding(.top, 6)
                HStack(spacing: 10) {
                    ForEach(Array((peer?.tags ?? []).prefix(2).enumerated()), id: \.offset) { i, t in
                        Text(t.hasPrefix("#") ? t : "#\(t)").font(LF.inter(900, 14)).foregroundStyle(i == 1 ? HV.ink : .white)
                            .padding(.horizontal, 14).frame(height: 34).background(tagColors[i % 3], in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .rotationEffect(.degrees(i == 0 ? -4 : 3)).shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    }
                }.padding(.top, 18).frame(minHeight: 52)
                Button { onConnect() } label: {
                    HStack(spacing: 10) {
                        if waiting { ProgressView().tint(.white) }
                        Text(waiting ? "\(peer?.name ?? "") を まって います…" : "つながる").font(LF.inter(900, 20))
                    }
                    .foregroundStyle(waiting ? .white.opacity(0.7) : HV.ink).frame(maxWidth: .infinity).frame(height: 58)
                    .background(waiting ? AnyShapeStyle(Color.white.opacity(0.16)) : AnyShapeStyle(HV.lime), in: Capsule())
                    .shadow(color: waiting ? .clear : HV.lime.opacity(0.35), radius: 14, y: 8)
                }.buttonStyle(HVPress(scale: 0.97)).disabled(waiting).padding(.horizontal, 22).padding(.top, 18)
                Button { onNotThem() } label: { Text("ちがう人").font(LF.inter(700, 17)).foregroundStyle(.white.opacity(0.6)).frame(height: 44) }.buttonStyle(.plain).padding(.top, 10)
                Text("ふたりとも「つながる」を 押すと 友だちに なります").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.45)).padding(.top, 6)
                Spacer(minLength: 0)
            }
            .frame(width: w - 24, height: 320)
            .background(Color(red: 20 / 255, green: 16 / 255, blue: 18 / 255).opacity(0.72), in: RoundedRectangle(cornerRadius: 38, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 38, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .position(x: w / 2, y: 665 + mid)
            .offset(y: drop || reduceMotion ? 0 : 420)
        }
    }

    private func doneBody(w: CGFloat, mid: CGFloat) -> some View {
        ZStack {
            ZStack {
                photo(peer?.photo, name: peer?.name ?? "", size: 120).offset(x: -34)
                photo(me, name: myName, size: 120).offset(x: 34)
                RoundedRectangle(cornerRadius: 72, style: .continuous).trim(from: 0, to: around ? 1 : 0)
                    .stroke(LinearGradient(colors: [HV.lime, Color(hex: "3BD35A")], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 212, height: 144).shadow(color: HV.lime.opacity(0.5), radius: 10)
            }.position(x: w / 2, y: 300 + mid)
            Text("つながった").font(LF.inter(900, 38)).foregroundStyle(HV.lime).position(x: w / 2, y: 495 + mid)
            Text("あしたの 朝 9:00 から、きのうを 見せあえる").font(LF.inter(600, 15)).foregroundStyle(.white.opacity(0.72)).position(x: w / 2, y: 537 + mid)
        }
    }

    private func noneBody(w: CGFloat, mid: CGFloat) -> some View {
        ZStack {
            photo(me, name: myName, size: 116).opacity(0.7).position(x: w / 2, y: 330 + mid)
            Text("見つからなかった").font(LF.inter(900, 30)).foregroundStyle(.white).position(x: w / 2, y: 574 + mid)
            Text("もう いちど、いっしょに ふって みて").font(LF.inter(600, 15)).foregroundStyle(.white.opacity(0.72)).position(x: w / 2, y: 616 + mid)
        }
    }

    // MARK: 上(× と 題字)・ 下(QR / ID)

    private func header(w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Button { Haptics.play(.soft); onClose() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.92)).offset(x: 18, y: 58).accessibilityLabel("とじる")
            Text("Shake").font(LF.serif(24, italic: true)).foregroundStyle(.white).frame(width: w).offset(y: 60)
        }.frame(width: w, height: 120, alignment: .topLeading).frame(maxHeight: .infinity, alignment: .top)
    }

    private func bottom(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
            Text("ふった 人 どうし だけに 見えます").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.5)).padding(.bottom, 26)
            HStack(spacing: 8) {
                glassButton("qrcode", "QR で つながる", lime: emphasizeQR) { onQR() }
                glassButton("at", "ID で さがす") { onID() }
            }.padding(.horizontal, 24).padding(.bottom, 44)
        }.frame(width: w, height: h)
    }

    private func glassButton(_ icon: String, _ title: String, lime: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.click); action() } label: {
            HStack(spacing: 10) { Image(systemName: icon).font(.system(size: 17, weight: .semibold)); Text(title).font(LF.inter(700, 16)) }
                .foregroundStyle(lime ? HV.ink : .white).frame(maxWidth: .infinity).frame(height: 50)
                .background(lime ? AnyShapeStyle(HV.lime) : AnyShapeStyle(Color.white.opacity(0.12)), in: Capsule()).background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96))
    }

    // MARK: 状態が かわった とき(動き ・ バイブ。見本:M15)

    private func enter(_ p: ShakeV68Phase, first: Bool = false) {
        hapticTask?.cancel()
        if first && p == .idle { Haptics.play(.sel) }
        switch p {
        case .idle:
            reset()
        case .seek:
            reset()
            hapticTask = Task { @MainActor in
                Haptics.play(.buzz)
                var last = 0.0
                for ms in [140.0, 300, 440, 560, 660, 740] { try? await Task.sleep(nanoseconds: UInt64((ms - last) * 1_000_000)); last = ms; if Task.isCancelled { return }; Haptics.play(.tick) }
            }
        case .found:
            drop = false; flash = false; ripple = false; around = false
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.72)) { drop = true }
            hapticTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 430_000_000); if Task.isCancelled { return }
                Haptics.play(.success)
                withAnimation(.easeOut(duration: 0.1)) { flash = true }
                if !reduceMotion { withAnimation(.easeOut(duration: 0.9)) { ripple = true } }
                withAnimation(.timingCurve(0.3, 1.2, 0.4, 1, duration: 0.45)) { bump = true }
                try? await Task.sleep(nanoseconds: 420_000_000)
                withAnimation(.easeOut(duration: 0.3)) { flash = false; bump = false }
                try? await Task.sleep(nanoseconds: 500_000_000); ripple = false
            }
        case .wait:
            Haptics.play(.click)
        case .done:
            hapticTask = Task { @MainActor in
                Haptics.play(.success)
                withAnimation(.easeOut(duration: 0.8)) { around = true }
                try? await Task.sleep(nanoseconds: 380_000_000); if Task.isCancelled { return }
                Haptics.play(.heart)
            }
        case .none:
            Haptics.play(.warn)
        }
    }

    private func reset() { drop = false; flash = false; ripple = false; bump = false; around = false }
}

/// スマホの 印(ぶるっと ゆれる)
private struct PhoneMark: View {
    let shaking: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !shaking)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
            let wob = shaking && t < 0.2 ? sin(t / 0.2 * .pi * 6) * 10 * (1 - t / 0.2) : 0
            HStack(spacing: 6) {
                Capsule().fill(.white.opacity(0.85)).frame(width: 3, height: 16)
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 3).frame(width: 26, height: 44)
                Capsule().fill(.white.opacity(0.85)).frame(width: 3, height: 16)
            }.rotationEffect(.degrees(wob))
        }
    }
}


/// 本物の Shake:`ShakeSession`(センサー + 通信)と 画面を つなぐ。とじる / 消えた ときは 必ず `stop()`。
struct ShakeV68Host: View {
    let myName: String
    let myRecordName: String
    var myAvatarData: Data?
    let friendIDs: Set<String>
    let blockedIDs: Set<String>
    var onClose: () -> Void
    var onQR: () -> Void = {}
    var onID: () -> Void = {}
    var onToast: (String) -> Void = { _ in }
    var onConnected: () -> Void = {}
    @State private var session = ShakeSession()

    var body: some View {
        ShakeV68View(phase: session.phase,
                     me: myAvatarData.flatMap { V64Images.image(key: "shk-me", data: $0, maxPixel: 320) },
                     myName: myName, peer: session.peer,
                     onClose: { session.stop(); onClose() },
                     onConnect: { session.connect() }, onNotThem: { session.notThem() },
                     onQR: { session.stop(); onQR() }, onID: { session.stop(); onID() },
                     emphasizeQR: session.permissionProblem)
            .onAppear {
                session.onToast = onToast
                session.onConnected = onConnected
                session.start(myName: myName, myRecordName: myRecordName, myThumb: thumb(), friends: friendIDs, blocked: blockedIDs)
            }
            .onDisappear { session.stop() }
    }

    /// 相手に 送る 小さな 写真(96px ・ 数KB)。送るのは ふって 見つけた あとの 暗号化した 通信だけ
    private func thumb() -> Data? {
        guard let d = myAvatarData, let img = V64Images.image(key: "shk-th", data: d, maxPixel: 96) else { return nil }
        return img.jpegData(compressionQuality: 0.5)
    }
}
