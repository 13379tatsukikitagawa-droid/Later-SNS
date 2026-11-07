import CoreMotion
import SwiftUI
import UIKit

// 昨日 → グループ タブの ヒーロー(グループが 0件のときだけ)。見本:later_v22.html の「昨日 → グループ」。
// 幅 350 × 高さ 300(中央よせ・せまい画面では 左右 16pt あけて ちぢめる)。
// まんなかに 自分(頭文字・虹色のリング・「あなた」)、まわりに 点線の席が 7つ、ハッシュタグの シールが 4枚。

enum YesterdayHeroLayout {
    static let size = CGSize(width: 350, height: 300)

    struct Seat { let x: CGFloat; let y: CGFloat; let color: Color }
    struct Sticker { let text: String; let x: CGFloat; let y: CGFloat; let angle: Double; let bg: Color; let fg: Color }

    /// 席(中央からの位置)。色は ピンク / ミント / オレンジ / 水色 / ライム / 紫 / 黄
    static let seats: [Seat] = [
        Seat(x: 0, y: -82, color: Color(hex: "EE6F9C")),
        Seat(x: -95, y: -52, color: Color(hex: "6EE0C0")),
        Seat(x: 96, y: -50, color: Color(hex: "F5A965")),
        Seat(x: -118, y: 14, color: Color(hex: "66C4F5")),
        Seat(x: 119, y: 18, color: Color(hex: "B5E85A")),
        Seat(x: -54, y: 70, color: Color(hex: "9A82F2")),
        Seat(x: 54, y: 72, color: Color(hex: "F5D84A")),
    ]

    static let stickers: [Sticker] = [
        Sticker(text: "#放課後", x: -112, y: -104, angle: -8, bg: Color(hex: "EE5E9C"), fg: .white),
        Sticker(text: "#いつメン", x: 104, y: -98, angle: 8, bg: Color(hex: "C8F25A"), fg: Color(hex: "111111")),
        Sticker(text: "#部活", x: -118, y: 102, angle: 7, bg: Color(hex: "9ED8FF"), fg: Color(hex: "111111")),
        Sticker(text: "#帰り道", x: 112, y: 106, angle: -6, bg: Color(hex: "F2A65A"), fg: Color(hex: "111111")),
    ]

    static let ringColors: [Color] = ["F5E26A", "8FE6A8", "6ECBF5", "9A82F2", "F27AB0", "F5A965", "F5E26A"].map { Color(hex: $0) }

    /// 画面の幅に入る 倍率(左右 16pt あける)。350 より せまいときだけ ちぢめる
    static func scale(forWidth width: CGFloat) -> CGFloat {
        min(1, max(0.7, (width - 32) / size.width))
    }
}

/// 出現(約1.6秒)の 時間割(秒)。開いた 時刻からの 経過だけで 決める(開きなおしても 重ならない)
enum YesterdayHeroTiming {
    static let coreDuration = 0.5
    static let seatStart = 0.35, seatStep = 0.07, seatDuration = 0.45
    static let stickerStart = 0.8, stickerStep = 0.09, stickerDuration = 0.56
    /// 見出し → サブ → ボタン → ME(ヒーローが あるとき)
    static let riseStart = 1.0, riseStep = 0.07
    static var lastStickerLanded: Double { stickerStart + stickerStep * 3 + stickerDuration }

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }
    /// 0 → over → 1(はねる)
    static func overshoot(_ p: Double, from: Double, over: Double, peakAt: Double = 0.6) -> Double {
        let p = clamp(p)
        if p < peakAt { return from + (over - from) * easeOut(p / peakAt) }
        return over + (1 - over) * easeOut((p - peakAt) / (1 - peakAt))
    }
}

/// 端末の かたむき(-1〜1)。開いたときの 向きを 0 にする
@MainActor @Observable
final class YesterdayHeroTilt {
    private let manager = CMMotionManager()
    private var reference: CMAttitude?
    var x: Double = 0
    var y: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        reference = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let attitude = motion.attitude
            if self.reference == nil { self.reference = attitude.copy() as? CMAttitude }
            if let reference = self.reference { attitude.multiply(byInverseOf: reference) }
            let tx = max(-1, min(1, attitude.roll / 0.35)), ty = max(-1, min(1, attitude.pitch / 0.35))
            self.x += (tx - self.x) * 0.2
            self.y += (ty - self.y) * 0.2
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        x = 0
        y = 0
    }
}

/// バイブ(表どおり)。設定で 切っていれば 鳴らさない
enum YesterdayHeroHaptics {
    static func light() { guard Haptics.isEnabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func rigid() { guard Haptics.isEnabled else { return }; UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func selection() { guard Haptics.isEnabled else { return }; UISelectionFeedbackGenerator().selectionChanged() }
    /// ドクン:medium → 0.12秒後に light
    static func heartbeat() {
        guard Haptics.isEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { light() }
    }
}

struct YesterdayGroupHero: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let userName: String
    /// 出現の はじまり(nil = もう出ている)
    var introStart: Date?
    /// 前面に あるか(ふわふわ・回転・かたむきは 前面のときだけ)
    var isActive = true
    /// 席(+)を押した → つくる
    let onSeat: () -> Void

    @State private var tilt = YesterdayHeroTilt()
    @State private var coreBump = 0
    @State private var seatBumps = [Int](repeating: 0, count: 7)
    @State private var stickerWobbles = [Int](repeating: 0, count: 4)
    @State private var fade = 1.0

    private var initial: String { userName.first.map(String.init) ?? "あ" }
    private var moving: Bool { isActive && !reduceMotion }

    var body: some View {
        let night = palette.isNight
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !moving)) { context in
            let now = context.date
            let t = reduceMotion ? 10 : introStart.map { now.timeIntervalSince($0) } ?? 10
            let clock = moving ? now.timeIntervalSinceReferenceDate : 0
            let px = reduceMotion ? 0 : tilt.x * 10, py = reduceMotion ? 0 : tilt.y * 10
            let center = CGPoint(x: YesterdayHeroLayout.size.width / 2, y: YesterdayHeroLayout.size.height / 2)
            ZStack {
                // 各席から まんなかへ、うすい灰の 点線(席と いっしょに のびる)
                ForEach(Array(YesterdayHeroLayout.seats.enumerated()), id: \.offset) { i, seat in
                    let p = seatProgress(i, t)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(x: center.x + seat.x + px * 0.3, y: center.y + seat.y + bob(i, clock) + py * 0.3))
                    }
                    .trim(from: 0, to: YesterdayHeroTiming.easeOut(p))
                    .stroke(night ? Color(hex: "3A3A40") : Color(hex: "D9D8DE"), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 5]))
                }

                ForEach(Array(YesterdayHeroLayout.seats.enumerated()), id: \.offset) { i, seat in
                    let p = seatProgress(i, t)
                    let out = YesterdayHeroTiming.easeOut(p)
                    Button {
                        YesterdayHeroHaptics.rigid()
                        seatBumps[i] += 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { onSeat() }
                    } label: {
                        seatView(seat, night: night)
                    }
                    .buttonStyle(.plain)
                    .keyframeAnimator(initialValue: 1.0, trigger: seatBumps[i]) { content, s in content.scaleEffect(s) } keyframes: { _ in
                        KeyframeTrack { CubicKeyframe(0.82, duration: 0.14); CubicKeyframe(1.18, duration: 0.17); SpringKeyframe(1, duration: 0.2) }
                    }
                    .scaleEffect(YesterdayHeroTiming.overshoot(p, from: 0, over: 1.15, peakAt: 0.65))
                    .opacity(min(1, p * 2.5))
                    .offset(x: seat.x * out + px, y: seat.y * out + bob(i, clock) + py)
                    .accessibilityLabel("席。押すと グループを つくる")
                }

                ForEach(Array(YesterdayHeroLayout.stickers.enumerated()), id: \.offset) { j, sticker in
                    let p = YesterdayHeroTiming.clamp((t - YesterdayHeroTiming.stickerStart - Double(j) * YesterdayHeroTiming.stickerStep) / YesterdayHeroTiming.stickerDuration)
                    let drop = p < 0.7 ? -30 + 34 * YesterdayHeroTiming.easeOut(p / 0.7) : 4 - 4 * YesterdayHeroTiming.easeOut((p - 0.7) / 0.3)
                    Button {
                        YesterdayHeroHaptics.selection()
                        stickerWobbles[j] += 1
                    } label: {
                        stickerView(sticker, night: night)
                    }
                    .buttonStyle(.plain)
                    .keyframeAnimator(initialValue: 0.0, trigger: stickerWobbles[j]) { content, a in content.rotationEffect(.degrees(sticker.angle + a)) } keyframes: { _ in
                        KeyframeTrack { CubicKeyframe(14, duration: 0.15); CubicKeyframe(-10, duration: 0.16); SpringKeyframe(0, duration: 0.2) }
                    }
                    .scaleEffect(YesterdayHeroTiming.overshoot(p, from: 0.3, over: 1.1, peakAt: 0.7))
                    .opacity(min(1, p * 2.5))
                    .offset(x: sticker.x + px, y: sticker.y + drop + py)
                    .accessibilityLabel(sticker.text)
                }

                let coreP = YesterdayHeroTiming.clamp(t / YesterdayHeroTiming.coreDuration)
                Button {
                    YesterdayHeroHaptics.heartbeat()
                    coreBump += 1
                } label: {
                    core(night: night, ringTrim: coreP, ringAngle: moving ? (clock.truncatingRemainder(dividingBy: 12) / 12) * 360 : 0)
                }
                .buttonStyle(.plain)
                .keyframeAnimator(initialValue: 1.0, trigger: coreBump) { content, s in content.scaleEffect(s) } keyframes: { _ in
                    KeyframeTrack { CubicKeyframe(0.9, duration: 0.11); CubicKeyframe(1.1, duration: 0.17); SpringKeyframe(1, duration: 0.28) }
                }
                .scaleEffect(YesterdayHeroTiming.overshoot(coreP, from: 0.3, over: 1.1))
                .opacity(min(1, coreP * 3))
                .offset(x: -px * 0.4, y: -py * 0.4)
            }
            .frame(width: YesterdayHeroLayout.size.width, height: YesterdayHeroLayout.size.height)
        }
        .opacity(fade)
        .onAppear { updateTilt() }
        .onChange(of: isActive) { _, _ in updateTilt() }
        .onChange(of: introStart) { _, _ in
            // 「視差を減らす」:出現は フェードだけ
            guard reduceMotion else { return }
            fade = 0
            withAnimation(.easeOut(duration: 0.3)) { fade = 1 }
        }
        .onDisappear { tilt.stop() }
    }

    private func updateTilt() {
        if moving { tilt.start() } else { tilt.stop() }
    }

    private func seatProgress(_ i: Int, _ t: Double) -> Double {
        YesterdayHeroTiming.clamp((t - YesterdayHeroTiming.seatStart - Double(i) * YesterdayHeroTiming.seatStep) / YesterdayHeroTiming.seatDuration)
    }

    /// 席の ふわふわ(±3pt・周期 3〜5秒・それぞれ ちがう)
    private func bob(_ i: Int, _ clock: Double) -> CGFloat {
        guard moving else { return 0 }
        let periods = [3.2, 4.1, 3.6, 4.8, 3.9, 4.4, 3.4]
        return CGFloat(3 * sin(2 * .pi * clock / periods[i] + Double(i) * 1.3))
    }

    private func seatView(_ seat: YesterdayHeroLayout.Seat, night: Bool) -> some View {
        Circle()
            .fill(seat.color.opacity(0.1))
            .overlay(Circle().strokeBorder(seat.color, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
            .overlay(Text("+").font(.system(size: 30, weight: .light)).foregroundStyle(seat.color).offset(y: -1))
            .frame(width: 52, height: 52)
            .shadow(color: seat.color.opacity(night ? 0.5 : 0.28), radius: 11)
            .contentShape(Circle())
    }

    func stickerView(_ sticker: YesterdayHeroLayout.Sticker, night: Bool) -> some View {
        Text(sticker.text)
            .font(.system(size: 15, weight: .black))
            .tracking(-0.02 * 15)
            .foregroundStyle(sticker.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(sticker.bg))
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(night ? Color.white.opacity(0.18) : Color(hex: "2A1D1D"))
                .offset(x: 3, y: 4))
            .fixedSize()
    }

    private func core(night: Bool, ringTrim: Double, ringAngle: Double) -> some View {
        ZStack {
            // 虹色のリング(出現で 時計まわりに 描かれる・ふだんは 12秒で 色が ひとまわり)
            Circle()
                .trim(from: 0, to: ringTrim)
                .stroke(AngularGradient(colors: YesterdayHeroLayout.ringColors, center: .center, angle: .degrees(ringAngle)), lineWidth: 6)
                .rotationEffect(.degrees(-90))
                .padding(3)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "F8B880"), Color(hex: "E2677F"), Color(hex: "9A4A7A")], center: UnitPoint(x: 0.35, y: 0.28), startRadius: 0, endRadius: 60))
                .padding(6)
            Text(initial).font(.system(size: 44, weight: .black)).foregroundStyle(.white)
        }
        .frame(width: 104, height: 104)
        .overlay(alignment: .bottom) {
            Text("あなた")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: "EE5E9C")))
                .background(Capsule().fill(night ? Color.white.opacity(0.18) : Color(hex: "2A1D1D")).offset(x: 2, y: 3))
                .fixedSize()
                .offset(y: 14)
        }
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("あなた")
    }
}

/// 見出し「なかまと、/ 昨日を見せあおう。」(「昨日」の下に 太い ピンクの マーカー。左から右へ 0.5秒で 引かれる)
struct YesterdayGroupHeadline: View {
    @Environment(\.palette) private var palette
    /// マーカーの 引かれ具合 0〜1
    var marker: Double = 1

    var body: some View {
        VStack(spacing: 0) {
            Text("なかまと、")
            HStack(spacing: 0) {
                Text("昨日")
                    .background(alignment: .bottomLeading) {
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "F28CB8"))
                                .frame(width: proxy.size.width * marker, height: 34 * 0.34)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 4)
                        }
                    }
                Text("を見せあおう。")
            }
        }
        .font(.system(size: 34, weight: .black))
        .tracking(-0.04 * 34)
        .lineSpacing(6)
        .foregroundStyle(palette.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("なかまと、昨日を見せあおう。")
        .accessibilityAddTraits(.isHeader)
    }
}

/// サブ「4〜8人のグループ。/ 1枚撮ると、みんなの写真が届きます。」
struct YesterdayGroupSub: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Text("4〜8人のグループ。\n1枚撮ると、みんなの写真が届きます。")
            .font(.system(size: 12.5, weight: .medium))
            .lineSpacing(4)
            .multilineTextAlignment(.center)
            .foregroundStyle(palette.sub)
            .frame(maxWidth: .infinity)
    }
}

/// 下から 26pt 浮いて 出る(バイブなし)。token が かわるたびに もう一度。「視差を減らす」は フェードだけ
struct YesterdayRise: ViewModifier {
    let delay: Double
    let token: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = true

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 26)
            .onChange(of: token) { _, _ in
                var hide = Transaction()
                hide.disablesAnimations = true
                withTransaction(hide) { shown = false }
                let animation: Animation = reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.55, dampingFraction: 0.72).delay(delay)
                // 消すのと 出すのを 同じ更新に まとめない(まとめると 動かない)
                DispatchQueue.main.async { withAnimation(animation) { shown = true } }
            }
    }
}

extension View {
    func yesterdayRise(_ delay: Double, token: Int) -> some View { modifier(YesterdayRise(delay: delay, token: token)) }
}

// MARK: - つくる / 参加する(横に2つ・高さ 62・まるい)

/// 押している間 0.95 に ちぢみ、はなすと はずんで もどる。アイコンが うごき、白い光の筋が 横切る(0.55秒)
struct YesterdayPillButtonStyle: ButtonStyle {
    enum Icon { case plus, qr }
    let icon: Icon
    let title: String
    let primary: Bool
    let night: Bool

    func makeBody(configuration: Configuration) -> some View {
        YesterdayPill(icon: icon, title: title, primary: primary, night: night, pressed: configuration.isPressed)
    }
}

private struct YesterdayPill: View {
    let icon: YesterdayPillButtonStyle.Icon
    let title: String
    let primary: Bool
    let night: Bool
    let pressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: CGFloat = -0.6

    /// 昼:つくる = 黒地・白字 / 参加する = うすい灰・黒字。夜:つくる = 白地・黒字 / 参加する = 濃い灰・白字
    private var background: Color {
        primary ? (night ? .white : Color(hex: "111111")) : (night ? Color(hex: "1E1E21") : Color(hex: "F1F0F4"))
    }
    private var foreground: Color {
        primary ? (night ? Color(hex: "111111") : .white) : (night ? .white : Color(hex: "111111"))
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(icon == .plus && pressed ? 90 : 0))
                .scaleEffect(pressed ? 1.15 : 1)
            Text(title).font(.system(size: 18, weight: .black)).tracking(-0.01 * 18)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(Capsule().fill(background))
        .overlay {
            GeometryReader { proxy in
                LinearGradient(colors: [.clear, .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 0.46, height: proxy.size.height * 1.4)
                    .rotationEffect(.degrees(14))
                    .offset(x: proxy.size.width * sweep, y: -proxy.size.height * 0.2)
            }
            .clipShape(Capsule())
            .allowsHitTesting(false)
        }
        .shadow(color: primary ? (night ? Color.white.opacity(0.18) : .black.opacity(0.6)) : .clear, radius: 13, y: 14)
        .scaleEffect(pressed ? 0.95 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.5), value: pressed)
        .onChange(of: pressed) { _, now in
            guard now, !reduceMotion else { return }
            sweep = -0.6
            withAnimation(.timingCurve(0.3, 0.6, 0.3, 1, duration: 0.55)) { sweep = 1.2 }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .plus:
            Image(systemName: "plus").font(.system(size: 20, weight: .bold))
        case .qr:
            Image(systemName: "qrcode").font(.system(size: 20, weight: .semibold))
        }
    }
}
