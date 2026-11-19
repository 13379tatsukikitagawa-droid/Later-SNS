import SwiftUI

// v104 §6-4:ウィジェットを ホームで 置く 案内。アプリの 中の 絵(ホーム画面に にせた 黒い 画面)。5場面を 自動で 流す(約 11秒 ・ 最後で 止まる)。
// 動きは 時間の 関数(`TimelineView`)。バイブは 別の Task で 時刻どおりに 鳴らす。Reduce Motion:自動で 流さず、場面ごとに 止まった 絵 +「つぎへ」。

enum WidgetHowTo {
    static let sceneLen = 2.2
    static let scenes: [(String, String)] = [
        ("下から 上へ スワイプ", "ホーム画面に もどります"),
        ("空いている 所を 長押し", "アイコンが ゆれたら できている"),
        ("左上の「+」を 押す", "iOS 18 では「編集」→「ウィジェットを 追加」"),
        ("「Lattag」を さがす", "検索欄に Lattag。えらんだ ウィジェットが 出ます"),
        ("「ウィジェットを 追加」", "ホームの 左上に のります"),
    ]
    static func scene(at t: Double) -> Int { min(scenes.count - 1, max(0, Int(t / sceneLen))) }
    static func progress(at t: Double) -> Double { scene(at: t) == scenes.count - 1 ? min(1, (t - Double(scenes.count - 1) * sceneLen) / sceneLen) : (t / sceneLen).truncatingRemainder(dividingBy: 1) }
    /// ゆれ(長押しの 1秒 あと〜)
    static func jiggling(at t: Double) -> Bool { t >= sceneLen + 1.0 && t < sceneLen * 4 + sceneLen * 0.75 }
    static func typedChars(at t: Double) -> Int {
        let s = t - sceneLen * 3
        guard s > sceneLen * 0.25 else { return 0 }
        return min(6, Int((s - sceneLen * 0.25) / 0.18) + 1)
    }
    /// バイブの 時刻
    static var hapticSchedule: [(Double, Haptics.Kind)] {
        var out: [(Double, Haptics.Kind)] = [(sceneLen + 1.0, .thud)]
        for i in 0..<6 { out.append((sceneLen * 3 + sceneLen * 0.25 + Double(i) * 0.18, .tick)) }
        out.append((sceneLen * 4 + sceneLen * 0.75, .success))
        return out
    }
}

struct WidgetHowToV104: View {
    let choice: WidgetChoice
    let sample: WidgetModel
    var onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var start = Date()
    @State private var manual = 0
    @State private var task: Task<Void, Never>?

    private let lime = HV.lime

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduce)) { ctx in
            let t = reduce ? (Double(manual) + 1) * WidgetHowTo.sceneLen - 0.0001 : ctx.date.timeIntervalSince(start)
            let sc = WidgetHowTo.scene(at: t)
            VStack(spacing: 0) {
                header(sc)
                phone(t: t).padding(.top, 14).padding(.horizontal, 36)
                Spacer(minLength: 8)
                footer(sc)
            }
        }
        .background(Color(hex: "0B0C0D").ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onAppear { if !reduce { run() } }
        .onDisappear { task?.cancel() }
    }

    private func header(_ sc: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(sc + 1) / \(WidgetHowTo.scenes.count)").font(LF.mono(12, bold: true)).tracking(1.5).foregroundStyle(lime).padding(.top, 16)
            Text(WidgetHowTo.scenes[sc].0).font(LF.inter(800, 21)).foregroundStyle(.white).padding(.top, 6).lineLimit(1).minimumScaleFactor(0.8)
            Text(WidgetHowTo.scenes[sc].1).font(LF.inter(500, 13)).foregroundStyle(.white.opacity(0.6)).padding(.top, 4).lineLimit(2)
            HStack(spacing: 5) { ForEach(0..<5, id: \.self) { i in Capsule().fill(i <= sc ? lime : Color.white.opacity(0.18)).frame(height: 3) } }.padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sc + 1) / 5。\(WidgetHowTo.scenes[sc].0)。\(WidgetHowTo.scenes[sc].1)")
    }

    private func footer(_ sc: Int) -> some View {
        VStack(spacing: 4) {
            if reduce && sc < WidgetHowTo.scenes.count - 1 {
                Button { Haptics.play(.tick); manual += 1 } label: { Text("つぎへ").font(LF.inter(800, 17)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.97))
            } else {
                Button { Haptics.play(.click); onBack() } label: { Text("Lattag に もどる").font(LF.inter(800, 17)).foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(lime, in: Capsule()) }.buttonStyle(HVPress(scale: 0.97))
            }
            Button { Haptics.play(.tick); restart() } label: { Text("もういちど").font(LF.inter(600, 14)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 24).padding(.bottom, 10)
    }

    private func restart() { start = Date(); manual = 0; if !reduce { run() } }

    private func run() {
        task?.cancel()
        let t0 = start
        task = Task { @MainActor in
            for (at, kind) in WidgetHowTo.hapticSchedule {
                let wait = at - Date().timeIntervalSince(t0)
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                guard !Task.isCancelled else { return }
                Haptics.play(kind, gap: 0)
            }
        }
    }

    // MARK: にせの ホーム画面

    private func phone(t: Double) -> some View {
        let sc = WidgetHowTo.scene(at: t), p = WidgetHowTo.progress(at: t)
        let jig = !reduce && WidgetHowTo.jiggling(at: t)
        let shownJig = reduce ? (sc == 1 || sc == 2 || sc == 3) : jig
        return GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let cols = 4, rows = 5
            let cell = w / CGFloat(cols)
            let icon = cell * 0.7
            let top = h * 0.12
            let landed = sc == 4 && p > 0.7
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 34, style: .continuous).fill(LinearGradient(colors: [Color(hex: "1B1D1F"), Color(hex: "0E0F10")], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1.5)
                // アイコン
                ForEach(0..<(cols * rows), id: \.self) { i in
                    let r = i / cols, c = i % cols
                    let isLattag = r == 4 && c == 1
                    let hidden = landed && r < 2 && c < 2
                    ZStack {
                        RoundedRectangle(cornerRadius: icon * 0.23, style: .continuous).fill(isLattag ? lime : Color.white.opacity(0.14))
                        if isLattag { Text("#").font(LF.inter(900, icon * 0.55)).foregroundStyle(HV.ink) }
                    }
                    .frame(width: icon, height: icon)
                    .rotationEffect(.degrees(shownJig ? sin(t * 28 + Double(i)) * 2.2 : 0))
                    .opacity(hidden ? 0 : 1)
                    .position(x: cell * (CGFloat(c) + 0.5), y: top + cell * 1.05 * CGFloat(r) + icon / 2)
                }
                // 置いた ウィジェット(左上 2×2)
                let side = cell * 2 - (cell - icon)
                choice.widget(sample).frame(width: 158, height: 158).scaleEffect(side / 158).frame(width: side, height: side).background(choice.bg)
                    .clipShape(RoundedRectangle(cornerRadius: side * 0.16, style: .continuous))
                    .scaleEffect(landed ? 1 : 1.25).opacity(landed ? 1 : 0)
                    .position(x: cell * 1.0, y: top + side / 2)
                    .animation(reduce ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: landed)
                // 1: スワイプ
                if sc == 0 {
                    let q = ease(p)
                    VStack(spacing: 8) {
                        Image(systemName: "chevron.up").font(.system(size: 22, weight: .black)).foregroundStyle(lime)
                        Capsule().fill(.white).frame(width: w * 0.32, height: 5)
                    }.position(x: w / 2, y: h * (0.95 - 0.35 * q)).opacity(1 - max(0, p - 0.8) * 5)
                }
                // 2: 長押し
                if sc == 1 && p * WidgetHowTo.sceneLen < 1.2 {
                    let s = min(1, p * WidgetHowTo.sceneLen / 1.0)
                    Circle().fill(lime.opacity(0.55)).frame(width: 64, height: 64).scaleEffect(1.5 - 0.8 * s).opacity(0.9 - 0.2 * s)
                        .position(x: cell * 3.5, y: h * 0.8)
                }
                // + ボタン
                if sc >= 1 && shownJig || sc == 2 {
                    ZStack {
                        if sc == 2 && !reduce { ForEach(0..<2, id: \.self) { k in let q = (t * 1.1 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1); Circle().strokeBorder(lime.opacity(0.7 * (1 - q)), lineWidth: 2).scaleEffect(1 + 1.6 * q) } }
                        Circle().fill(.white.opacity(sc == 2 ? 0.28 : 0.16))
                        Image(systemName: "plus").font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                    }.frame(width: 28, height: 28).position(x: 26, y: 26)
                }
                // 4・5: ギャラリー
                if sc >= 3 {
                    let rise = sc == 3 ? ease(min(1, p * 3)) : (p < 0.5 ? 1 : 1 - ease(min(1, (p - 0.5) / 0.25)))
                    let panelH = h * 0.66
                    gallery(w: w, h: panelH, t: t, sc: sc, p: p)
                        .frame(width: w, height: panelH)
                        .offset(y: h - panelH * rise)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .aspectRatio(0.56, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func gallery(w: CGFloat, h: CGFloat, t: Double, sc: Int, p: Double) -> some View {
        let n = reduce ? 6 : WidgetHowTo.typedChars(at: t)
        let typed = String("Lattag".prefix(sc == 4 ? 6 : n))
        let side = w * 0.42
        let pressing = sc == 4 && p > 0.28 && p < 0.42
        return VStack(spacing: 0) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 36, height: 4).padding(.top, 8)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                Text(typed.isEmpty ? "ウィジェットを 検索" : typed).font(LF.inter(600, 13)).foregroundStyle(typed.isEmpty ? .white.opacity(0.4) : .white)
                Spacer()
            }.padding(.horizontal, 10).frame(height: 32).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous)).padding(.horizontal, 14).padding(.top, 12)
            if typed.count >= 6 || sc == 4 {
                choice.widget(sample).frame(width: 158, height: 158).scaleEffect(side / 158).frame(width: side, height: side).background(choice.bg)
                    .clipShape(RoundedRectangle(cornerRadius: side * 0.16, style: .continuous)).padding(.top, 14)
                Text("Lattag ・ \(choice.title)").font(LF.inter(700, 11)).foregroundStyle(.white.opacity(0.7)).padding(.top, 6)
                Text("ウィジェットを 追加").font(LF.inter(800, 13)).foregroundStyle(HV.ink).padding(.horizontal, 18).frame(height: 36).background(lime, in: Capsule())
                    .scaleEffect(pressing ? 0.92 : 1).padding(.top, 10)
            } else { Spacer() }
            Spacer(minLength: 0)
        }
        .background(Color(hex: "2A2B2D"), in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
    }

    private func ease(_ x: Double) -> Double { 1 - pow(1 - min(1, max(0, x)), 3) }
}
