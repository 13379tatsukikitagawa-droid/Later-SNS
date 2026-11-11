import SwiftUI
import UIKit

// MARK: - はじめての 合図(説明画面の かわりに、その場で ひとことだけ)
//
// - 画面に 出るのは 1回に 1つだけ(HintCenter が 表の 順に 1つ えらぶ)
// - 文は 1行。ボタンなし。その部品に さわったら すぐ 消える。画面を 移っても 消える
// - 1つの 合図は 一生に 1回だけ(出した 瞬間に UserDefaults に 保存。端末ごと)
// - 画面に 入って 0.8秒(撮影画面は 1.3秒)落ち着いてから 出す
// - シート・グループ作成・現像画面・トーストが 出ている間は 出さない。部品が 画面に 見えていないときも 出さない
// - 合図は 見た目だけ。ヒット判定を 持たない(部品の タップは そのまま 通る)

enum FirstHintKey: String, CaseIterable, Sendable {
    case first, unlock, tag, shoot, orb, grp

    var text: String {
        switch self {
        case .first: "ここから、1枚目"
        case .unlock: "撮ると、きのうが 1枚 ひらく"
        case .tag: "ひとこと タグ。なくても OK"
        case .shoot: "ながおしで 撮る"
        case .orb: "タップで、みんなの 今日"
        case .grp: "ともだちと、見せあう"
        }
    }

    /// 画面に 入ってから 出すまでの 待ち
    var dwell: Double { self == .shoot ? 1.3 : 0.8 }

    /// ほかを うすく ぼかす(スポットライト)
    var spotlight: Bool { self == .first || self == .unlock }
}

/// 見た 合図(UserDefaults の Set<String>)
enum FirstHintStore {
    static let key = "firstHint.seen.v1"

    static func seen(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func isSeen(_ hint: FirstHintKey, defaults: UserDefaults = .standard) -> Bool {
        seen(defaults: defaults).contains(hint.rawValue)
    }

    static func markSeen(_ hint: FirstHintKey, defaults: UserDefaults = .standard) {
        var all = seen(defaults: defaults)
        all.insert(hint.rawValue)
        defaults.set(Array(all).sorted(), forKey: key)
    }

    /// 設定の「はじめての 合図を もう一度」
    static func resetAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// 表示を 1つだけ 管理する
@MainActor @Observable
final class HintCenter {
    static let shared = HintCenter()

    /// いま 出している 合図
    private(set) var active: FirstHintKey?
    /// 出している 合図が、まわりを ぼかすか
    var spotlightOn: Bool { active?.spotlight == true }

    /// 条件が 合って 見えている 部品(いつから)
    @ObservationIgnored private var ready: [FirstHintKey: Date] = [:]
    /// 出さない 理由(シート・グループ作成・現像・トーストなど)
    @ObservationIgnored private var blockers: Set<String> = []
    @ObservationIgnored private var defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isBlocked: Bool { !blockers.isEmpty }

    /// 部品から:条件が 合っていて 画面に 見えているか
    func update(_ key: FirstHintKey, ready isReady: Bool, now: Date = Date()) {
        if isReady {
            guard ready[key] == nil else { return }
            guard !FirstHintStore.isSeen(key, defaults: defaults) || active == key else { return }
            ready[key] = now
            DispatchQueue.main.asyncAfter(deadline: .now() + key.dwell + 0.02) { [weak self] in self?.evaluate() }
        } else {
            ready[key] = nil
            // 画面を 移った・見えなくなった:すぐ 消える
            if active == key { hide() }
        }
    }

    /// 部品に さわった:すぐ 消える
    func touched(_ key: FirstHintKey) {
        ready[key] = nil
        if active == key { hide() }
    }

    /// シートなどが 開いている 間は 出さない(出ていたら 消す)
    func setBlocked(_ reason: String, _ on: Bool) {
        if on {
            guard !blockers.contains(reason) else { return }
            blockers.insert(reason)
            if active != nil { hide() }
        } else {
            guard blockers.contains(reason) else { return }
            blockers.remove(reason)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.82) { [weak self] in self?.evaluate() }
        }
    }

    /// 表の 順に 見て、落ち着いて(dwell)条件が 合った 最初の 1つを 出す
    func evaluate(now: Date = Date()) {
        guard active == nil, blockers.isEmpty else { return }
        for key in FirstHintKey.allCases {
            guard let since = ready[key], !FirstHintStore.isSeen(key, defaults: defaults) else { continue }
            guard now.timeIntervalSince(since) >= key.dwell else { continue }
            // 一生に 1回:出した 瞬間に 保存
            FirstHintStore.markSeen(key, defaults: defaults)
            Haptics.play(.soft)
            withAnimation(.easeOut(duration: 0.5)) { active = key }
            return
        }
    }

    private func hide() {
        withAnimation(.easeOut(duration: 0.5)) { active = nil }
        // 次の 合図(条件が 合っていれば)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.evaluate() }
    }

    /// テスト用
    func resetForTesting() {
        active = nil
        ready = [:]
        blockers = []
    }
}

// MARK: - 部品に つける

enum FirstHintShape {
    case circle
    case rounded(CGFloat)
    case capsule
}

extension View {
    /// はじめての 合図。eligible は「出る 条件」(画面・枚数など)。見えているかは ここで 見る
    /// - edge: ふきだしを 出す 側(.top = 部品の 上)
    /// - onDark: 暗い 画面(ふきだしは 白地に 黒文字)
    func firstHint(_ key: FirstHintKey, eligible: Bool, edge: VerticalEdge = .top, shape: FirstHintShape = .rounded(22), onDark: Bool = false, gap: CGFloat = 12) -> some View {
        modifier(FirstHintModifier(key: key, eligible: eligible, edge: edge, shape: shape, onDark: onDark, gap: gap))
    }
}

private struct FirstHintModifier: ViewModifier {
    let key: FirstHintKey
    let eligible: Bool
    let edge: VerticalEdge
    let shape: FirstHintShape
    let onDark: Bool
    let gap: CGFloat

    @State private var frame: CGRect = .zero
    @State private var onScreen = false
    private var center: HintCenter { HintCenter.shared }

    private var isActive: Bool { center.active == key }

    /// 部品が 画面の 中に まるごと 見えている
    private static func visible(_ rect: CGRect) -> Bool {
        guard rect.width > 1, rect.height > 1 else { return false }
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
        return screen.insetBy(dx: -1, dy: -1).contains(rect)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    HintRing(shape: shape)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: edge == .top ? .top : .bottom) {
                if isActive {
                    HintBubble(text: key.text, onDark: onDark, pointsDown: edge == .top)
                        .fixedSize()
                        // 部品の 外へ(ふきだし 38 + しっぽ 7 + すきま)
                        .offset(y: edge == .top ? -(HintBubble.height + gap) : HintBubble.height + gap)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rect in
                frame = rect
                onScreen = Self.visible(rect)
                report()
            }
            .onChange(of: eligible) { _, _ in report() }
            .onAppear { report() }
            .onDisappear { center.update(key, ready: false) }
            .simultaneousGesture(TapGesture().onEnded { center.touched(key) })
    }

    private func report() {
        center.update(key, ready: eligible && onScreen)
    }
}

// MARK: - 見た目

/// ふきだし:高さ 38・角丸 いっぱい。左に 小さな オレンジの点(ぽわっと 広がる)。しっぽは 部品の 中心を さす
struct HintBubble: View {
    let text: String
    let onDark: Bool
    /// しっぽが 下向き(ふきだしが 部品の 上)
    let pointsDown: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var bob = false
    @State private var pulse = false

    /// ふきだしと しっぽの 高さ
    static let height: CGFloat = 45

    private var bg: Color { onDark ? .white : Color(hex: "111114") }
    private var fg: Color { onDark ? Color(hex: "111114") : .white }

    var body: some View {
        VStack(spacing: 0) {
            if !pointsDown { tail.rotationEffect(.degrees(180)) }
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color(hex: "FF6A1A")).frame(width: 7, height: 7)
                    Circle().fill(Color(hex: "FF6A1A").opacity(0.45)).frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 2.6 : 1)
                        .opacity(pulse ? 0 : 1)
                }
                Text(text)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(fg)
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .frame(height: 38)
            .background(Capsule().fill(bg))
            .shadow(color: .black.opacity(onDark ? 0.25 : 0.18), radius: 12, y: 6)
            if pointsDown { tail }
        }
        .offset(y: reduceMotion ? 0 : (shown ? (bob ? -4 : 0) : 10))
        .scaleEffect(shown || reduceMotion ? 1 : 0.86, anchor: pointsDown ? .bottom : .top)
        .opacity(shown || reduceMotion ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .onAppear {
            guard !reduceMotion else { shown = true; return }
            // 下から ぽよんと(バネ)→ ゆっくり 上下に 4px ゆれる
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) { shown = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(0.5)) { bob = true }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private var tail: some View {
        HintTail()
            .fill(bg)
            .frame(width: 14, height: 7)
    }
}

private struct HintTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// 部品の まわりに オレンジの ふち(2.5px)+ 外へ 広がる 波(1.8秒ループ)
private struct HintRing: View {
    let shape: FirstHintShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wave = false

    var body: some View {
        ZStack {
            outline(lineWidth: 2.5)
            if !reduceMotion {
                outline(lineWidth: 2)
                    .scaleEffect(wave ? 1.22 : 1)
                    .opacity(wave ? 0 : 0.7)
            }
        }
        .padding(-4)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { wave = true }
        }
    }

    @ViewBuilder
    private func outline(lineWidth: CGFloat) -> some View {
        let color = Color(hex: "FF6A1A")
        switch shape {
        case .circle: Circle().strokeBorder(color, lineWidth: lineWidth)
        case .capsule: Capsule().strokeBorder(color, lineWidth: lineWidth)
        case .rounded(let r): RoundedRectangle(cornerRadius: r + 4, style: .continuous).strokeBorder(color, lineWidth: lineWidth)
        }
    }
}

/// 撮影の 見本:シャッターの まわりの リングが 2.2秒かけて オレンジで 1周 たまる + 中央に 指の 丸が 押しこまれる → ループ
struct ShutterHintDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let cycle = 2.8
            let t = reduceMotion ? 1.6 : context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: cycle)
            let fill = min(1, t / 2.2)
            let press = t < 0.25 ? t / 0.25 : (t < 2.2 ? 1 : max(0, 1 - (t - 2.2) / 0.3))
            ZStack {
                Circle().trim(from: 0, to: fill)
                    .stroke(Color(hex: "FF6A1A"), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 98, height: 98)
                    .opacity(t > 2.4 ? max(0, 1 - (t - 2.4) / 0.4) : 1)
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .overlay(Circle().strokeBorder(Color(hex: "FF6A1A").opacity(0.9), lineWidth: 2))
                    .frame(width: 34, height: 34)
                    .scaleEffect(1.25 - 0.3 * press)
                    .opacity(0.35 + 0.6 * press)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
