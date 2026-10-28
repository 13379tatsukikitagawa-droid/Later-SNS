import SwiftUI

/// ビューアで、見ている範囲に写真が1枚もなかったときの画面。光が0の日 = 月が黒い(新月)。
/// 文言は事実だけ(ほめない・なぐさめない・責めない)。開くときの触覚は鳴らさない。
struct EmptyYesterdayView: View {
    enum Kind: Equatable {
        case everyone
        case mine
        case mondo
    }

    let kind: Kind
    /// 「自分」のとき、みんなに1枚以上あるか(「みんなの昨日を見る ›」を出す)
    let everyoneHasPhotos: Bool
    let isReloading: Bool
    /// 今日の1枚を撮ったか(今日のカードを出す)
    let showsTodayCard: Bool
    let haptics: ExposureHaptics
    let onSeeEveryone: () -> Void
    let onReload: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var flashStart: Date?

    struct Copy: Equatable {
        let kicker: String
        let title: String
        let body: String
    }

    static func copy(_ kind: Kind) -> Copy {
        switch kind {
        case .everyone:
            return Copy(kicker: "YESTERDAY ・ 0 LIGHTS", title: "昨日の写真は\nありません。", body: "グループの誰も、撮っていない日でした。")
        case .mine:
            return Copy(kicker: "YOU ・ 0 LIGHTS", title: "昨日は\n撮っていません。", body: "自分の写真は、ありませんでした。")
        case .mondo:
            return Copy(kicker: "MONDO", title: "まだ写真が\n届いていません。", body: "時間をおいて、もう一度ひらいてください。")
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            // 390×844 を基準に。小さい機種・大きい文字では、月のかたまりを 0.85 倍まで縮める
            let ky = h / 844
            let moonScale = max(0.85, min(1, ky)) * (dynamicTypeSize.isAccessibilitySize ? 0.85 : 1)
            ZStack(alignment: .top) {
                Color.black

                EmptyStarfield(isAnimating: !reduceMotion, avoid: CGRect(x: (w - 256) / 2, y: 200 * ky, width: 256, height: 256))

                NewMoon(isAnimating: !reduceMotion, flashStart: flashStart)
                    .frame(width: 256, height: 256)
                    .scaleEffect(moonScale)
                    .frame(width: 256 * moonScale, height: 256 * moonScale)
                    .offset(y: 200 * ky)
                    .contentShape(Circle())
                    .onTapGesture {
                        haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                        flashStart = Date()
                    }
                    .accessibilityElement()
                    .accessibilityLabel("光のない昨日")
                    .accessibilityAddTraits(.isImage)

                texts
                    .frame(width: w)
                    .offset(y: 500 * ky)

                destinationButton
                    .frame(width: w)
                    .offset(y: 682 * ky)

                if showsTodayCard {
                    todayCard
                        .padding(.horizontal, 22)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, max(34, proxy.safeAreaInsets.bottom + 4))
                }
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: - 文言(範囲をかえると 0.26秒で入れかわる。月はそのまま)

    private var texts: some View {
        let c = Self.copy(kind)
        return VStack(spacing: 14) {
            Text(c.kicker)
                .font(.system(size: 10.5, design: .monospaced))
                .tracking(0.24 * 10.5)
                .foregroundStyle(HomePalette.orange)
            Text(c.title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.05 * 30)
                .lineSpacing(30 * 0.3 - 6)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.white)
            Text(c.body)
                .font(.system(size: 14))
                .lineSpacing(14 * 0.85 - 4)
                .multilineTextAlignment(.center)
                .foregroundStyle(HomePalette.subText)
        }
        .padding(.horizontal, 24)
        .id(kind)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.26), value: kind)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var destinationButton: some View {
        switch kind {
        case .mine where everyoneHasPhotos:
            pillButton("みんなの昨日を見る ›", enabled: true) {
                haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                onSeeEveryone()
            }
        case .mondo:
            pillButton(isReloading ? "読みこみ中…" : "もう一度読みこむ", enabled: !isReloading) {
                haptics.playTransient(intensity: 0.3, sharpness: 0.4)
                onReload()
            }
        default:
            Color.clear.frame(height: 44)
        }
    }

    private func pillButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.5))
                .padding(.horizontal, 22)
                .frame(height: 44)
                .background(Capsule().fill(.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .transition(.opacity)
    }

    // MARK: - 今日のカード

    private var todayCard: some View {
        HStack(spacing: 14) {
            CrescentIcon().frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY ・ 9:00")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.2 * 9.5)
                    .foregroundStyle(Color(hex: "8E8E93"))
                Text("今日の1枚は、あしたの朝にひらきます")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(Capsule().fill(.white.opacity(0.055)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の1枚は、あしたの朝にひらきます")
    }
}

// MARK: - 黒い月(新月)

/// 目盛りの輪(120秒で1周)+ 上の白い点(6秒周期で明滅)+ ほぼ黒いディスク(左下に地球照)
/// + ふちの光(48秒で1周)+ まわりの光。タップでふちの光が1.2秒だけ明るくなる。
struct NewMoon: View {
    let isAnimating: Bool
    /// タップした時刻(ふちの光の、一瞬の明るさ)
    let flashStart: Date?

    var body: some View {
        TimelineView(.animation(paused: !isAnimating && !isFlashing(Date()))) { context in
            let t = isAnimating ? context.date.timeIntervalSinceReferenceDate : 0
            let flash = flashAmount(context.date)
            ZStack {
                // まわりの光(ハロ)
                Circle()
                    .fill(RadialGradient(colors: [HomePalette.orange.opacity(0.11), .clear], center: .center, startRadius: 0, endRadius: 160))
                    .frame(width: 320, height: 320)
                    .blur(radius: 10)

                // 目盛りの輪
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = size.width / 2 - 1
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.07)), lineWidth: 1)
                    let rotation = t * 2 * .pi / 120
                    for i in 0..<60 {
                        let major = i % 5 == 0
                        let a = Double(i) / 60 * 2 * .pi + rotation
                        let len: CGFloat = major ? 9 : 5
                        var p = Path()
                        p.move(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                        p.addLine(to: CGPoint(x: c.x + cos(a) * (r - len), y: c.y + sin(a) * (r - len)))
                        ctx.stroke(p, with: .color(.white.opacity(major ? 0.22 : 0.09)), lineWidth: 1)
                    }
                }
                .frame(width: 256, height: 256)

                // 上の白い点(輪の真上に固定。6秒周期で 1 → .25 → 1)
                Circle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .opacity(isAnimating ? 0.625 + 0.375 * cos(2 * .pi * t / 6) : 1)
                    .offset(y: -128)

                disc
                rim(t: t, flash: flash)
            }
            .frame(width: 256, height: 256)
        }
    }

    private func isFlashing(_ now: Date) -> Bool {
        guard let flashStart else { return false }
        return now.timeIntervalSince(flashStart) < 1.25
    }

    /// 0 → 1 → 0(1.2秒)
    private func flashAmount(_ now: Date) -> Double {
        guard let flashStart else { return 0 }
        let u = now.timeIntervalSince(flashStart) / 1.2
        guard u >= 0, u < 1 else { return 0 }
        return sin(.pi * u)
    }

    /// ディスク(168pt):中心 #14161c → #07070a → #030304、ふちに白7%の線、下に影、左下に地球照
    private var disc: some View {
        ZStack {
            Circle().fill(RadialGradient(stops: [
                .init(color: Color(hex: "14161C"), location: 0),
                .init(color: Color(hex: "07070A"), location: 0.6),
                .init(color: Color(hex: "030304"), location: 1),
            ], center: UnitPoint(x: 0.45, y: 0.4), startRadius: 0, endRadius: 90))
            Circle().fill(RadialGradient(colors: [Color(red: 110 / 255, green: 140 / 255, blue: 1).opacity(0.2), .clear],
                                         center: UnitPoint(x: 0.12, y: 0.9), startRadius: 0, endRadius: 120))
            Circle().strokeBorder(.white.opacity(0.07), lineWidth: 1)
        }
        .frame(width: 168, height: 168)
        .shadow(color: .black.opacity(0.8), radius: 18, y: 10)
    }

    /// ふちの光(太さ1.5pt・約1/3周)。あたたかい白の先端から、うすく伸びる。48秒で1周。
    private func rim(t: Double, flash: Double) -> some View {
        let angle = Angle.radians(t * 2 * .pi / 48)
        let gradient = AngularGradient(stops: [
            .init(color: Color(red: 1, green: 230 / 255, blue: 200 / 255).opacity(0), location: 0),
            .init(color: Color(red: 1, green: 230 / 255, blue: 200 / 255).opacity(0.85), location: 0.333),
            .init(color: .clear, location: 0.334),
            .init(color: .clear, location: 1),
        ], center: .center)
        return ZStack {
            Circle()
                .trim(from: 0, to: 0.334)
                .stroke(HomePalette.orange.opacity(0.55), lineWidth: 6)
                .blur(radius: 8)
            Circle()
                .stroke(gradient, lineWidth: 1.5)
        }
        .frame(width: 168, height: 168)
        .rotationEffect(angle - .degrees(120))
        .brightness(0.35 * flash)
        .shadow(color: HomePalette.orange.opacity(0.8 * flash), radius: 14 * flash)
        .scaleEffect(1 + 0.004 * flash)
        .opacity(min(1, 0.85 + 1.4 * flash))
    }
}

/// 画面全体の星(約26個・固定の乱数)。月のかたまりの上には置かない。6秒周期で、うすくちかちか。
struct EmptyStarfield: View {
    let isAnimating: Bool
    let avoid: CGRect

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isAnimating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                var g = SeededGenerator(seed: "empty-yesterday-stars")
                var placed = 0, tries = 0
                while placed < 26 && tries < 200 {
                    tries += 1
                    let x = CGFloat(Double(g.next() % 10_000) / 10_000) * size.width
                    let y = CGFloat(Double(g.next() % 10_000) / 10_000) * size.height
                    let r = 1 + CGFloat(g.next() % 100) / 200
                    let phase = Double(g.next() % 1000) / 1000 * 2 * .pi
                    if avoid.insetBy(dx: -16, dy: -16).contains(CGPoint(x: x, y: y)) { continue }
                    placed += 1
                    let o = isAnimating ? 0.275 + 0.225 * sin(2 * .pi * t / 6 + phase) : 0.3
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(o)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 三日月のアイコン(クリーム色の円を、黒い円で 9pt ずらして欠けさせる。やわらかい光)
struct CrescentIcon: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "FFF1DC"))
            Circle().fill(.black).offset(x: 9, y: -3).blendMode(.destinationOut)
        }
        .compositingGroup()
        .shadow(color: Color(hex: "FFE2C2").opacity(0.6), radius: 6)
        .accessibilityHidden(true)
    }
}
