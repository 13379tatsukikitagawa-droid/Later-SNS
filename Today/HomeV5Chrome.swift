import SwiftUI
import UIKit

// Home v5 の共通の部品:背景・ヘッダー・文字・ダブルタップ・波紋。

// MARK: - 色と文字

enum V5 {
    /// 暖かい黒
    static let bg = Color(hex: "0A0806")
    /// アクセントの琥珀
    static let amber = Color(hex: "FF9E5E")
    /// 強調の橙
    static let orange = Color(hex: "FF8A1F")
    /// 左右の余白(ピル・ランキングカード・見出しは、すべてこの1つにそろえる)
    static let edge: CGFloat = 20

    /// 手書き風(ハッシュタグなど、写真の上の文字)
    static func hand(_ size: CGFloat) -> Font {
        .custom("HiraMaruProN-W4", size: size)
    }

    /// 等幅(数字・日付)
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// 「10.25 14:15」
    static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM.dd HH:mm"
        return f.string(from: date)
    }

    /// 「10.25」(dayKey の yyyy-MM-dd から)
    static func monthDay(fromDayKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3 else { return key }
        return "\(parts[1]).\(parts[2])"
    }
}

// MARK: - 押せる場所は、ダブルタップの切りかえに使わない

/// ボタン・タイル・カード・ヘッダー・下の表示・地球の上で押された操作を覚えておく。
/// 画面のダブルタップは、この間に押された操作があれば、切りかえに使わない(それぞれの操作を優先する)。
@MainActor
enum TapConsumption {
    static var lastConsumedAt: Date = .distantPast

    static func mark() { lastConsumedAt = Date() }
}

extension View {
    /// ここで押された操作は、画面のダブルタップ(切りかえ)に使わない
    func consumesTap() -> some View {
        simultaneousGesture(TapGesture().onEnded { TapConsumption.mark() })
    }

    /// 押した場所(画面の座標)つきのタップ。押せる場所なので、ダブルタップの切りかえには使わない。
    func onSpatialTap(perform action: @escaping (CGPoint) -> Void) -> some View {
        contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(coordinateSpace: .global)
                    .onEnded { value in
                        TapConsumption.mark()
                        action(value.location)
                    }
            )
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - 画面のダブルタップ(UIKit)

/// 画面のダブルタップを拾う。ScrollView の子と競合しないよう、ウインドウに UITapGestureRecognizer を
/// 付ける(cancelsTouchesInView = false)。0.33秒以内・34pt以内の2回(DoubleTapSwitchRule)を、
/// 1回のダブルタップとみなす。押せる場所で押された場合(TapConsumption)は呼ばない。
struct DoubleTapSurface: UIViewRepresentable {
    var isEnabled: Bool
    var onDoubleTap: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onDoubleTap = onDoubleTap
    }

    static func dismantleUIView(_ view: AnchorView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class AnchorView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { coordinator?.attach(to: window) } else { coordinator?.detach() }
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = true
        var onDoubleTap: (CGPoint) -> Void = { _ in }
        private var recognizer: UITapGestureRecognizer?
        private weak var window: UIWindow?
        private var last: (at: Date, point: CGPoint)?

        func attach(to window: UIWindow) {
            guard self.window !== window else { return }
            detach()
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.numberOfTapsRequired = 1
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
            self.window = window
        }

        func detach() {
            if let recognizer { window?.removeGestureRecognizer(recognizer) }
            recognizer = nil
            window = nil
            last = nil
        }

        @objc private func tapped(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, isEnabled else { last = nil; return }
            let point = gesture.location(in: window)
            let now = Date()
            guard let first = last,
                  DoubleTapSwitchRule.isDoubleTap(firstAt: first.at, firstPoint: first.point, secondAt: now, secondPoint: point) else {
                last = (now, point)
                return
            }
            last = nil
            // 押せる場所の操作(SwiftUI 側)が同じ瞬間に届くので、少し待ってから判定する
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                guard let self, self.isEnabled else { return }
                guard TapConsumption.lastConsumedAt < first.at.addingTimeInterval(-0.05) else { return }
                self.onDoubleTap(point)
            }
        }

        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

// MARK: - 二重の波紋

struct RippleMark: Identifiable, Equatable {
    let id = UUID()
    let point: CGPoint
}

/// 触れた場所に出る、白橙の輪(0.7秒、2つ目は0.12秒おくれ)
struct DoubleRipple: View {
    let point: CGPoint
    @State private var go = false

    var body: some View {
        ZStack {
            ring(delay: 0)
            ring(delay: 0.12)
        }
        .position(point)
        .allowsHitTesting(false)
        .onAppear { go = true }
    }

    private func ring(delay: Double) -> some View {
        Circle()
            .strokeBorder(Color(hex: "FFD9B8"), lineWidth: 1.5)
            .frame(width: 120, height: 120)
            .scaleEffect(go ? 1 : 0.1)
            .opacity(go ? 0 : 0.85)
            .animation(.easeOut(duration: 0.7).delay(delay), value: go)
    }
}

// MARK: - 背景

/// 暖かい黒。下から橙の光だまり、左上に光のもれ、ごく弱い粒子(ほこり)。
struct V5Backdrop: View {
    var isAnimating = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Dust {
        let x: Double
        let y: Double
        let r: Double
        let speed: Double
        let phase: Double
    }

    private static let dust: [Dust] = {
        var g = SeededGenerator(seed: "v5-dust")
        var result: [Dust] = []
        for _ in 0..<26 {
            let x = Double(g.next() % 1000) / 1000
            let y = Double(g.next() % 1000) / 1000
            let r = 0.6 + Double(g.next() % 12) / 10
            let speed = 0.4 + Double(g.next() % 10) / 10
            let phase = Double(g.next() % 628) / 100
            result.append(Dust(x: x, y: y, r: r, speed: speed, phase: phase))
        }
        return result
    }()

    var body: some View {
        let animate = isAnimating && HomeMotion.ambientAllowed(reduceMotion: reduceMotion)
        ZStack {
            V5.bg
            RadialGradient(colors: [V5.orange.opacity(0.34), V5.orange.opacity(0.08), .clear], center: .bottom, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [V5.amber.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 280)
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animate)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    for p in Self.dust {
                        let drift = animate ? sin(t * 0.15 * p.speed + p.phase) * 10 : 0
                        let rise = animate ? (t * 3 * p.speed).truncatingRemainder(dividingBy: size.height) : 0
                        let y = (p.y * size.height - rise).truncatingRemainder(dividingBy: size.height)
                        let point = CGPoint(x: p.x * size.width + drift, y: y < 0 ? y + size.height : y)
                        let twinkle = animate ? 0.5 + 0.5 * sin(t * 0.6 * p.speed + p.phase) : 0.6
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: point.x, y: point.y, width: p.r, height: p.r)),
                            with: .color(Color(hex: "FFE2C2").opacity(0.18 * twinkle))
                        )
                    }
                }
            }
            FilmGrainOverlay(opacity: 0.07, blendMode: .overlay)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - ヘッダーの下の幕(ヘッダー本体は LaterHeader.swift)

/// ヘッダーの下の白い幕(上128pt。スクロールしても文字が読める)
struct V5HeaderScrim: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [ChicColor.paper.opacity(0.94), ChicColor.paper.opacity(0.6), ChicColor.paper.opacity(0)], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 128)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - ガラス

extension View {
    /// 暗いガラスの面(角丸つき)
    func v5Glass(cornerRadius: CGFloat, tint: Color? = nil, border: Double = 0.1) -> some View {
        background(
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(.ultraThinMaterial.opacity(0.55))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.white.opacity(0.04))
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(RadialGradient(colors: [tint.opacity(0.28), .clear], center: .topLeading, startRadius: 0, endRadius: 220))
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(border), lineWidth: 1))
    }
}


// MARK: - ホームの切りかえ(今日 / 昨日)

/// いま見せているホーム。左のドット = 今日、右のドット = 昨日。
enum HomeKind: String, Equatable {
    case today
    case yesterday

    var other: HomeKind { self == .today ? .yesterday : .today }
    var title: String { self == .today ? "今日" : "昨日" }
}

/// アバターからの切りかえの入口(TodayView が作って、2つのホームのヘッダーへ渡す)。
struct AvatarSwitch {
    var current: HomeKind = .today
    /// 増えるたびに、アバターが Y 軸で 90° → 0° に一回転する
    var flipToken = 0
    var onSwitch: () -> Void = {}
    var onMenu: () -> Void = {}
    /// アバターの中心(画面全体の座標)。円のアニメーション・メニュー・チップの位置に使う
    var onCenter: (CGPoint) -> Void = { _ in }
}

/// 右上のアバター(直径36pt、タップ領域は44pt)。1回タップ = プロフィール(0.3秒、2回目がなければ)・2回タップ = 今日/昨日の切りかえ・
/// 長押し(0.45秒) = ホームを選ぶメニュー。さわると 0.9 に縮み、離すともどる。
/// 縁は白2pt + 黒1.5pt の二重(夜は黒2pt + 白1.5pt)。写真がないときは、やわらかいグラデーションに名前の最初の1文字。
struct HomeAvatarControl: View {
    @Environment(\.palette) private var palette
    let avatarImage: UIImage?
    var name = ""
    let showsBadge: Bool
    let onProfile: () -> Void
    var control = AvatarSwitch()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var flip: Double = 0
    @State private var longPressedAt = Date.distantPast

    var body: some View {
        face
            .background {
                Color.clear.onGeometryChange(for: CGPoint.self) {
                    let frame = $0.frame(in: .global)
                    return CGPoint(x: frame.midX, y: frame.midY)
                } action: { control.onCenter($0) }
            }
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
            .rotation3DEffect(.degrees(flip), axis: (x: 0, y: 1, z: 0))
            .contentShape(Circle())
            // 2回タップを先に宣言する(1回タップは、2回目が来ないと確かめてから動く)
            .onTapGesture(count: 2) {
                TapConsumption.mark()
                control.onSwitch()
            }
            .onTapGesture {
                TapConsumption.mark()
                // 長押しの指を離したときは、プロフィールをひらかない
                guard Date().timeIntervalSince(longPressedAt) > 1 else { return }
                onProfile()
            }
            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 14, perform: {
                TapConsumption.mark()
                longPressedAt = Date()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                control.onMenu()
            }, onPressingChanged: { pressed = $0 })
            .onChange(of: control.flipToken) { _, _ in
                guard !reduceMotion else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { flip = 90 }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.5)) { flip = 0 }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(showsBadge ? "あなたのページ、新しい変化があります" : "プロフィール")
            .accessibilityValue(control.current.title + "のホーム")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onProfile() }
            .accessibilityAction(named: "ホームを切りかえ") { control.onSwitch() }
    }

    private var photo: some View {
        Group {
            if let avatarImage {
                Image(uiImage: avatarImage).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "FFD9B8"), Color(hex: "F4A38A"), Color(hex: "B88AC4")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)))
                        .font(UIFont(name: "Inter-Black", size: 15) != nil ? .custom("Inter-Black", fixedSize: 15) : .system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var face: some View {
        // 縁は写真の外がわに描く(白2pt + 黒1.5pt。夜は入れかわる)
        let outer: Color = palette.isNight ? .black : .white
        let inner: Color = palette.isNight ? .white : .black
        return ZStack(alignment: .topTrailing) {
            photo
                .padding(1.5)
                .background(Circle().fill(inner))
                .padding(2)
                .background(Circle().fill(outer))
                .frame(width: 44, height: 44)

            if showsBadge {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(palette.bg, lineWidth: 2))
                    .offset(x: -2, y: 2)
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: 円(カメラの絞り)で切りかえる

/// 昨日のホームを、アバターの中心から広がる円で見せる。active でないときは、画面より大きい四角(切り抜かない)。
struct IrisClip: Shape {
    var active: Bool
    var center: CGPoint
    var radius: CGFloat

    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard active else {
            return Path(CGRect(x: rect.minX - 3000, y: rect.minY - 3000, width: rect.width + 6000, height: rect.height + 6000))
        }
        let r = max(0.01, radius)
        return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }
}

/// 円のふちを追う細い琥珀のリング(2pt、#FF9E5E)
struct IrisRing: View {
    let center: CGPoint
    var radius: CGFloat

    var body: some View {
        let r = max(0.01, radius)
        Circle()
            .strokeBorder(Color(hex: "FF9E5E"), lineWidth: 2)
            .frame(width: r * 2, height: r * 2)
            .position(center)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: 切りかえたあとのチップ

/// 切りかえたあと、アバターの下に1.1秒だけ出す小さなガラス(アバター + 「今日」「昨日」 + ドット)
struct HomeSwitchChip: View {
    let avatarImage: UIImage?
    let avatarSeed: UUID?
    let kind: HomeKind

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let avatarImage {
                    Image(uiImage: avatarImage).resizable().aspectRatio(contentMode: .fill)
                } else if let avatarSeed {
                    PersonaIcon(seed: avatarSeed)
                } else {
                    Circle().fill(HomePalette.surface)
                }
            }
            .frame(width: 22, height: 22)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
            Text(kind.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .dynamicTypeSize(.large)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .v5Glass(cornerRadius: 17, border: 0.16)
        .background(Capsule().fill(.black.opacity(0.35)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title)のホーム")
    }
}

// MARK: 長押しのメニュー

/// 左半分の円(今日の「月」の小さな印)
struct HalfMoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = 48
        for i in 0...steps {
            let angle = (90 + 180 * Double(i) / Double(steps)) * .pi / 180
            let point = CGPoint(x: c.x + r * CGFloat(cos(angle)), y: c.y + r * CGFloat(sin(angle)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// アバターの下、右そろえのガラスのメニュー(幅 min(236, 画面 - 40))。背後は黒38%。
struct HomeSwitchMenu: View {
    let current: HomeKind
    /// アバターの中心(画面全体の座標)
    let avatarCenter: CGPoint
    let onPick: (HomeKind) -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let cx = avatarCenter.x - origin.x
            let cy = avatarCenter.y - origin.y
            let width = min(236, geo.size.width - 40)
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.38)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)
                panel
                    .frame(width: width)
                    .padding(.top, cy + 22 + 20)
                    .padding(.trailing, max(12, geo.size.width - (cx + 22)))
                    .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topTrailing)
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            row(.today, detail: "撮る") {
                HalfMoonShape().fill(Color(hex: "FFE2C2")).frame(width: 14, height: 14)
            }
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.horizontal, 14)
            row(.yesterday, detail: "見る") {
                VStack(spacing: 2) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "FFE2C2"))
                    Capsule().fill(Color(hex: "FFE2C2").opacity(0.7)).frame(width: 12, height: 2)
                }
            }
            Text("2回タップでも、切りかえ")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.black.opacity(0.4)))
        .v5Glass(cornerRadius: 24, border: 0.14)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
    }

    private func row<Icon: View>(_ kind: HomeKind, detail: String, @ViewBuilder icon: () -> Icon) -> some View {
        Button { onPick(kind) } label: {
            HStack(spacing: 12) {
                icon()
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white.opacity(0.09)))
                Text("\(kind.title) \(Text("— \(detail)").foregroundStyle(Color(hex: "BCBBC0")))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if kind == current {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "FFB277"))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title)、\(detail)")
        .accessibilityAddTraits(kind == current ? .isSelected : [])
    }
}

// MARK: 「今日を撮ると、ひらく」(昨日のホームを、撮る前にひらいたとき)

extension View {
    /// 昨日のものをぼかして(半径16)白い幕(60%)をかけ、さわれなくする。外れるときは 1.4 秒かけて晴れる。
    func v5Locked(_ locked: Bool) -> some View {
        blur(radius: locked ? 16 : 0)
            .overlay { ChicColor.paper.opacity(locked ? 0.6 : 0).allowsHitTesting(false) }
            .allowsHitTesting(!locked)
            .accessibilityHidden(locked)
            .animation(.easeInOut(duration: 1.4), value: locked)
    }
}

/// ロックの印と、言葉(Mondo のタブ)。白いカードに、細い線。
struct V5LockedNotice: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ChicColor.ink)
            Text("今日を撮ると、ひらく")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ChicColor.ink)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ChicColor.paper)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(ChicColor.line, lineWidth: 1))
        )
        .padding(.horizontal, V5.edge)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日を撮ると、ひらく")
    }
}

/// 同じ言葉の、小さな白いピル(グループのタブ。タブバーの上)
struct V5LockedPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold))
            Text("今日を撮ると、ひらく")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(ChicColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Capsule().fill(ChicColor.paper))
        .overlay(Capsule().strokeBorder(ChicColor.line, lineWidth: 1))
        .padding(.horizontal, V5.edge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日を撮ると、ひらく")
    }
}
