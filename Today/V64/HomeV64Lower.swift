import SwiftUI
import SwiftData
import CoreMotion

// P04:Home の 下(スクロール した 所)。上から Today(今日の フィルム)→ Active → Yesterday → Albums → On this day → Friends。
// 見本:L01〜L11(mock/src/app.js の arcToday / arcActive / arcYesterday / arcMondo / arcAlbums / arcFriends)。背景は #0A0A0B。

struct HomeV64LowerData {
    struct Today { var thumbs: [UIImage?] = []; var times: [String] = []; var dates: [Date] = [] }
    struct Hero { var photo: UIImage?; var tag: String = "#朝"; var tagColor: Color = Color(hex: "9ED8FF"); var dateLabel = "NOV 15"; var moments = 0; var people = 0; var daysLeft = 6 }
    struct Tile: Identifiable { let id = UUID(); var photo: UIImage?; var name: String; var time: String?; var own = false; var kept = false }
    struct Album: Identifiable { let id = UUID(); var label: String; var left: String; var tiles: [UIImage?]; var more: Int; var hot = false }
    var today = Today()
    var hero: Hero?
    var tiles: [Tile] = []
    var albums: [Album] = []
    var onThisDay: (photo: UIImage?, daysLeft: Int, date: String)?
    var trips: [(id: UUID?, name: String, sub: String, cover: UIImage?, day: String, unread: Int)] = []
}

enum HVL {
    static let bg = Color(hex: "0A0A0B")
    static let line = Color.white.opacity(0.08)
    static let label = Color(hex: "8E8E93")
    static let card = Color(hex: "121214")

    /// v119 5章:アルバムの のこり(「あと 6日 ・ 金」/「あした 消える」)。2日 以下は ライム
    static func albumLeft(daysLeft: Int, date: Date) -> (text: String, hot: Bool) {
        if daysLeft <= 1 { return ("あした 消える", true) }
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "E"
        return ("あと \(daysLeft)日 ・ \(f.string(from: date))", daysLeft <= 2)
    }

    /// きのうの 曜日(「土曜日」)
    static func weekdayJA(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}

struct HVLabel: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        // v119 5章:日本語 ・ 12.5pt 太字 ・ 灰色(等幅 ・ 広い 字間は やめる)
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(Typo.ui(800, 12.5)).foregroundStyle(Color(hex: "8C8C93"))
            Spacer()
            if let trailing { Text(trailing).font(Typo.ui(700, 11.5)).foregroundStyle(Color(hex: "6E6E75")).lineLimit(1) }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - v132 3章:Today の カード = 暗室の ひも(モック `.x9t.c` ・ v117_today.*)

/// ひもの 形(モック X9S:幅 330 ・ 高さ 64 の 2次ベジェ。左の 釘 → 右上)。x は カードの 幅に あわせて のばす
enum HVTodayString {
    static let baseW: CGFloat = 330
    static let p0 = CGPoint(x: 6, y: 30), p1 = CGPoint(x: 150, y: 58), p2 = CGPoint(x: 300, y: 8)
    /// 3つの 枠の まんなか(幅 330 の とき)
    static let slotX: [CGFloat] = [58, 165, 272]
    /// 枠の 傾き(モック X9RZ)
    static let tilt: [Double] = [-2.4, 1.8, -1.3]

    static func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x, y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y)
    }
    static func y(atX x: CGFloat) -> CGFloat {
        var lo: CGFloat = 0, hi: CGFloat = 1
        for _ in 0..<24 { let m = (lo + hi) / 2; if point(m).x < x { lo = m } else { hi = m } }
        return point((lo + hi) / 2).y
    }
    static func path(width w: CGFloat) -> Path {
        let k = w / baseW
        var p = Path()
        p.move(to: CGPoint(x: p0.x * k, y: p0.y))
        p.addQuadCurve(to: CGPoint(x: p2.x * k, y: p2.y), control: CGPoint(x: p1.x * k, y: p1.y))
        return p
    }
    /// Lattag の 1日(9:00 → あした 9:00 の 24時間)の うち いま の 位置(0〜1)。24:00 の 消灯 = 0.625
    static func dayPosition(_ now: Date, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.hour, .minute], from: now)
        var x = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 - 9
        if x < 0 { x += 24 }
        return min(1, max(0, x / 24))
    }
    /// いま の あとの いちばん 近い 9:00
    static func nextNine(after now: Date, calendar: Calendar = .current) -> Date {
        let nine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        return nine > now ? nine : (calendar.date(byAdding: .day, value: 1, to: nine) ?? nine)
    }
    /// 「21:20」(9:00 まで ・ 時:分)
    static func untilNine(_ now: Date) -> String {
        let s = max(0, Int(nextNine(after: now).timeIntervalSince(now)))
        return "\(s / 3600):" + String(format: "%02d", (s % 3600) / 60)
    }
    /// 撮って から 次の 9:00 までの うち、すすんだ わりあい(0〜1)。9:00 で はっきり
    static func develop(takenAt t: Date, now: Date) -> Double {
        let total = nextNine(after: t).timeIntervalSince(t)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(t) / total))
    }
}

/// ジャイロの 傾き と スクロールの ゆれ(チェキ だけが 読む。カード 全体を 毎コマ 描きなおさない)
@Observable final class HVTodayFeel {
    /// (x軸, y軸)の 傾き(度)
    var gyro: CGSize = .zero
    var sway: Double = 0
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var ref: (Double, Double)?
    @ObservationIgnored var lastY: CGFloat?
    @ObservationIgnored private var kicking = false

    /// 見えて いる 間 だけ 動かす(30Hz)。止めて 持った ままの 傾きは ゆっくり 0 に もどる
    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1 / 30
        ref = nil
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let a = m?.attitude else { return }
            var r = self.ref ?? (a.pitch, a.roll)
            r.0 += (a.pitch - r.0) * 0.03; r.1 += (a.roll - r.1) * 0.03
            self.ref = r
            let k = 180 / Double.pi * 0.5
            let rx = max(-6, min(6, -(a.pitch - r.0) * k)), ry = max(-6, min(6, (a.roll - r.1) * k))
            if abs(rx - self.gyro.width) > 0.15 || abs(ry - self.gyro.height) > 0.15 { self.gyro = CGSize(width: rx, height: ry) }
        }
    }
    func stop() {
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        if gyro != .zero { gyro = .zero }
    }
    /// スクロールの 速さで 少し ゆれて、ばねで 止まる(最大 ±2.2°)
    func kick(_ dy: CGFloat) {
        let k = max(-2.2, min(2.2, Double(dy) * 0.05))
        guard abs(k) > 0.25, !kicking else { return }
        kicking = true
        withAnimation(.easeOut(duration: 0.12)) { sway = k } completion: {
            self.kicking = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.32)) { self.sway = 0 }
        }
    }
}

nonisolated private struct HVTodayGeo: Equatable, Sendable { var visible: CGFloat; var y: CGFloat }

/// 着地の 動き(1回 だけ)
struct HVEnterFrame { var rot: Double = 0; var y: CGFloat = 0; var rx: Double = 0; var o: Double = 1 }

struct HVTodayPanel: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let onShoot: () -> Void
    let onDevelop: () -> Void

    static let ground = Color(hex: "121014")
    static let paper = Color(hex: "F4F1EA")
    static let grey = Color(hex: "8C8C93")
    static let ink = Color(hex: "111113")

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feel = HVTodayFeel()
    @State private var photos: [UIImage?] = []
    /// 画面に 入った 回数(着地の きっかけ)
    @State private var enter = 0
    @State private var seen = false

    private var n: Int { min(input.shotsUsed, 3) }
    /// 撮れる 時間(今の アプリの きまり:9:00〜24:00)
    private var canShoot: Bool { !DailyWindow.isNight(input.now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            hang.padding(.top, -6).padding(.horizontal, -4)
        }
        .padding(20)
        .background(Self.ground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 14)
        .onGeometryChange(for: HVTodayGeo.self) { p in
            let r = p.frame(in: .local)
            let v = p.bounds(of: .scrollView).map { $0.intersection(r).height / max(1, r.height) } ?? 1
            return HVTodayGeo(visible: (max(0, v) * 100).rounded() / 100, y: p.frame(in: .global).minY)
        } action: { g in
            if g.visible >= 0.35, !seen {
                seen = true
                enter += 1
                if !reduceMotion, n > 0 { feel.start() }
            } else if g.visible <= 0, seen {
                seen = false
                feel.stop()
            }
            if let last = feel.lastY, seen, !reduceMotion, n > 0 { feel.kick(g.y - last) }
            feel.lastY = g.y
        }
        .onChange(of: n) { _, v in if v > 0, seen, !reduceMotion { feel.start() } }
        .onDisappear { feel.stop(); seen = false }
        .task(id: n) { await loadPhotos() }
    }

    // MARK: 上(Today + 1行 ・ 9:00 の 札)

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Today").font(Typo.title(38)).tracking(Typo.titleTracking(38)).foregroundStyle(HVCardTint.milk)
                stateLine.font(Typo.ui(700, 13)).foregroundStyle(Self.grey).lineLimit(1).minimumScaleFactor(0.8).padding(.top, 8)
            }
            Spacer(minLength: 0)
            HVNineTag(done: n >= 3, left: HVTodayString.untilNine(input.now), enter: enter, reduce: reduceMotion)
        }
        .frame(minHeight: 64, alignment: .top)
    }

    private var stateLine: Text {
        let b = { (s: String) in Text(verbatim: s).fontWeight(.heavy).foregroundColor(HVCardTint.milk) }
        if n >= 3 { return Text("3枚 そろった ・ ") + b("9:00") + Text(" に ひらく") }
        if n > 0 { return Text("現像中 ・ のこり ") + b("\(3 - n)枚") }
        if !canShoot { return Text("まだ 0枚 ・ ") + b("9:00") + Text(" から 撮れる") }
        return Text("まだ 0枚 ・ ") + b("24:00") + Text(" まで 撮れる")
    }

    // MARK: ひも と 3つの 枠

    private var hang: some View {
        GeometryReader { g in
            let w = g.size.width, k = w / HVTodayString.baseW
            ZStack(alignment: .topLeading) {
                HVTodayStringView(width: w, progress: HVTodayString.dayPosition(input.now), enter: enter, reduce: reduceMotion)
                ForEach(0..<3, id: \.self) { i in
                    let y = HVTodayString.y(atX: HVTodayString.slotX[i]) + 4
                    slot(i)
                        .frame(width: 96, height: 132)
                        .overlay(alignment: .top) { HVTodayClip().offset(y: -9) }
                        .position(x: HVTodayString.slotX[i] * k, y: y + 66)
                }
            }
        }
        .frame(height: 196)
    }

    @ViewBuilder private func slot(_ i: Int) -> some View {
        if i < n {
            HVHangCheki(index: i, photo: photos[safe: i] ?? nil, time: data.today.times[safe: i] ?? "",
                        p: data.today.dates[safe: i].map { HVTodayString.develop(takenAt: $0, now: input.now) } ?? 0,
                        rz: HVTodayString.tilt[i], feel: feel, enter: enter, reduce: reduceMotion, onTap: onDevelop)
        } else if i == n, canShoot {
            Button { Haptics.play(.pop); onShoot() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 24, weight: .bold))
                    Text("撮る").font(Typo.ui(800, 16))
                    Text("のこり \(3 - n)").font(Typo.ui(800, 11)).opacity(0.62)
                }
                .foregroundStyle(Self.ink)
                .frame(width: 96, height: 122)
            }
            .buttonStyle(HVLedgePress(face: HV.lime, ledge: Color(hex: "97C235"), radius: 18, depth: 6))
            .accessibilityLabel("撮る ・ のこり \(3 - n)枚")
            .modifier(HVDropIn(index: i, enter: enter, reduce: reduceMotion))
            .padding(.top, 4)
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                Text(verbatim: "\(i + 1)").font(Typo.title(30)).foregroundStyle(.white.opacity(0.22))
            }
            .frame(width: 96, height: 128)
            .modifier(HVDropIn(index: i, enter: enter, reduce: reduceMotion))
            .padding(.top, 4)
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityHidden(true)
        }
    }

    // MARK: 自分の きょうの 写真(64px で 1回 だけ ぼかして 置く ・ 表示は 不透明度 だけ)

    private func loadPhotos() async {
        guard n > 0 else { photos = []; return }
        // DEBUG の 状態メニューは 見本の 写真を 渡す
        if !data.today.thumbs.isEmpty {
            photos = data.today.thumbs.prefix(n).enumerated().map { i, img in img.map { V64Images.blurred(key: "tdx\(i)", source: $0, maxPixel: 64, radius: 10, saturation: 0.6) } }
            return
        }
        let start = DailyWindow.latest(for: input.now).open
        var fd = FetchDescriptor<LaterPhoto>(predicate: #Predicate { $0.captureDate >= start }, sortBy: [SortDescriptor(\.captureDate)])
        fd.fetchLimit = 30
        let items = (try? context.fetch(fd)) ?? []
        // 1回の 撮影は グループ ごとに 1つ ずつ 入るので、撮った 時刻(秒)で まとめる
        var seenAt = Set<Int>(), datas: [(Int, Data)] = []
        for p in items { let s = Int(p.captureDate.timeIntervalSinceReferenceDate); if seenAt.insert(s).inserted { datas.append((s, p.imageData)) } }
        let count = n
        photos = await Task.detached(priority: .utility) {
            datas.prefix(count).map { s, data -> UIImage? in
                guard let small = V64Images.image(key: "dvsrc\(s)", data: data, maxPixel: 96) else { return nil }
                return V64Images.blurred(key: "td\(s)", source: small, maxPixel: 64, radius: 10, saturation: 0.6)
            }
        }.value
    }
}

/// 右上の 9:00 の 札(紙 ・ -4° ・ 穴。3枚 そろったら ライム)
struct HVNineTag: View {
    let done: Bool
    let left: String
    let enter: Int
    let reduce: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: "9:00").font(Typo.title(30)).foregroundStyle(HVTodayPanel.ink).padding(.top, 6)
            Text(done ? "あと \(left) で ひらく" : "ひらく ・ あと \(left)")
                .font(Typo.ui(800, 10.5)).foregroundStyle(done ? Color(hex: "2F3A12") : Color(hex: "55555C"))
                .lineLimit(1).fixedSize()
                .padding(.top, 3)
        }
        .padding(.top, 8).padding(.horizontal, 12).padding(.bottom, 9)
        .background(done ? HV.lime : HVTodayPanel.paper, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(alignment: .top) {
            Circle().fill(HVTodayPanel.ground).frame(width: 7, height: 7)
                .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1.5)).padding(.top, 6)
        }
        .shadow(color: .black.opacity(0.55), radius: 9, y: 10)
        .keyframeAnimator(initialValue: HVEnterFrame(), trigger: enter) { c, f in
            c.rotationEffect(.degrees(-4 + f.rot)).offset(y: f.y).opacity(f.o)
        } keyframes: { _ in
            KeyframeTrack(\.rot) {
                MoveKeyframe(reduce ? 0 : 6); LinearKeyframe(reduce ? 0 : 6, duration: 0.04)
                LinearKeyframe(0, duration: 0.56, timingCurve: .bezier(startControlPoint: UnitPoint(x: 0.3, y: 1.4), endControlPoint: UnitPoint(x: 0.5, y: 1)))
            }
            KeyframeTrack(\.y) {
                MoveKeyframe(reduce ? 0 : -10); LinearKeyframe(reduce ? 0 : -10, duration: 0.04)
                LinearKeyframe(0, duration: 0.56, timingCurve: .bezier(startControlPoint: UnitPoint(x: 0.3, y: 1.4), endControlPoint: UnitPoint(x: 0.5, y: 1)))
            }
            KeyframeTrack(\.o) { MoveKeyframe(0); LinearKeyframe(0, duration: 0.04); LinearKeyframe(1, duration: reduce ? 0.26 : 0.56) }
        }
        .padding(.top, -2).padding(.trailing, -2)
        .accessibilityElement(children: .combine)
    }
}

/// ひも(うすい 線 + 9:00 から いま までの 白い 線 + 左の 釘)
struct HVTodayStringView: View {
    let width: CGFloat
    let progress: Double
    let enter: Int
    let reduce: Bool

    var body: some View {
        let path = HVTodayString.path(width: width)
        let k = width / HVTodayString.baseW
        ZStack(alignment: .topLeading) {
            path.stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            Color.clear.keyframeAnimator(initialValue: 1.0, trigger: enter) { c, f in
                c.overlay(path.trim(from: 0, to: progress * f).stroke(HVCardTint.milk, style: StrokeStyle(lineWidth: 2.6, lineCap: .round)))
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(reduce ? 1.0 : 0.0); LinearKeyframe(reduce ? 1.0 : 0.0, duration: 0.2)
                    LinearKeyframe(1.0, duration: 0.9, timingCurve: .bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8), endControlPoint: UnitPoint(x: 0.2, y: 1)))
                }
            }
            Circle().fill(Color(hex: "2A2A2E")).overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .frame(width: 8, height: 8)
                .position(x: HVTodayString.p0.x * k, y: HVTodayString.p0.y)
        }
        .frame(width: width, height: 64)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 枠を つるす クリップ(12×18 ・ 黒)
struct HVTodayClip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: "2A2A2E"))
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.25)).frame(height: 1.5).padding(.horizontal, 3).padding(.top, 7) }
            .frame(width: 12, height: 18)
            .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 撮る ・ 点線の 枠:上から 落ちる(-18pt ・ rotateX 28° → 0 ・ 0.62秒)
struct HVDropIn: ViewModifier {
    let index: Int
    let enter: Int
    let reduce: Bool
    func body(content: Content) -> some View {
        let d = 0.06 + Double(index) * 0.08
        let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.3, y: 1.25), endControlPoint: UnitPoint(x: 0.5, y: 1))
        content.keyframeAnimator(initialValue: HVEnterFrame(), trigger: enter) { c, f in
            c.rotation3DEffect(.degrees(f.rx), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5).offset(y: f.y).opacity(f.o)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                MoveKeyframe(reduce ? 0 : -18); LinearKeyframe(reduce ? 0 : -18, duration: d)
                LinearKeyframe(reduce ? 0 : 2, duration: 0.434, timingCurve: curve); LinearKeyframe(0, duration: 0.186, timingCurve: .easeOut)
            }
            KeyframeTrack(\.rx) {
                MoveKeyframe(reduce ? 0 : 28); LinearKeyframe(reduce ? 0 : 28, duration: d)
                LinearKeyframe(reduce ? 0 : -4, duration: 0.434, timingCurve: curve); LinearKeyframe(0, duration: 0.186, timingCurve: .easeOut)
            }
            KeyframeTrack(\.o) { MoveKeyframe(0); LinearKeyframe(0, duration: reduce ? 0 : d); LinearKeyframe(1, duration: reduce ? 0.26 : 0.434) }
        }
    }
}

/// つるした チェキ(紙 6 / 6 / 26 ・ 左下に 時刻 ・ 写真は 9:00 に むけて 浮きでる)。指 / ジャイロで 3D に 傾く
struct HVHangCheki: View {
    let index: Int
    let photo: UIImage?
    let time: String
    let p: Double
    let rz: Double
    let feel: HVTodayFeel
    let enter: Int
    let reduce: Bool
    let onTap: () -> Void

    @State private var touch: CGSize = .zero
    @State private var live = false
    @State private var lastTick = Date.distantPast

    var body: some View {
        let t = live ? touch : (reduce ? .zero : feel.gyro)
        let glow = min(1, (abs(t.width) + abs(t.height)) / 14)
        Button { Haptics.play(.pop); onTap() } label: {
            card(gx: 0.5 - t.height * 0.04, glow: glow)
                .rotationEffect(.degrees(rz + (reduce ? 0 : feel.sway)), anchor: .top)
                .rotation3DEffect(.degrees(t.height), axis: (x: 0, y: 1, z: 0), anchor: .top, perspective: 0.5)
                .rotation3DEffect(.degrees(t.width), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
        }
        .buttonStyle(HVPress(scale: 0.97))
        .gesture(HVTouchTracker { pt in
            guard !reduce else { return }
            if let pt {
                let nx = pt.x / 96 * 2 - 1, ny = pt.y / 132 * 2 - 1
                if !live { live = true }
                withAnimation(.linear(duration: 0.08)) { touch = CGSize(width: max(-12, min(12, -ny * 12)), height: max(-12, min(12, nx * 12))) }
                if Date().timeIntervalSince(lastTick) >= 0.2 { lastTick = Date(); Haptics.play(.tick) }
            } else if live {
                withAnimation(.timingCurve(0.3, 1.5, 0.45, 1, duration: 0.6)) { touch = .zero }
                live = false
            }
        })
        .keyframeAnimator(initialValue: HVEnterFrame(), trigger: enter) { c, f in
            c.rotationEffect(.degrees(f.rot), anchor: .top).opacity(f.o)
        } keyframes: { _ in
            let d = 0.06 + Double(index) * 0.09
            KeyframeTrack(\.rot) {
                MoveKeyframe(reduce ? 0 : 9); LinearKeyframe(reduce ? 0 : 9, duration: d)
                LinearKeyframe(reduce ? 0 : -6, duration: 0.352, timingCurve: .easeOut)
                LinearKeyframe(reduce ? 0 : 3, duration: 0.33, timingCurve: .easeInOut)
                LinearKeyframe(reduce ? 0 : -1, duration: 0.242, timingCurve: .easeInOut)
                LinearKeyframe(0, duration: 0.176, timingCurve: .easeOut)
            }
            KeyframeTrack(\.o) { MoveKeyframe(0); LinearKeyframe(0, duration: reduce ? 0 : d); LinearKeyframe(1, duration: reduce ? 0.26 : 0.352) }
        }
        .accessibilityLabel("\(time) に 撮った ・ 現像中")
        .accessibilityHint("現像を のぞく")
    }

    private func card(gx: Double, glow: Double) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(hex: "D9DDD8")
                if let photo { Image(uiImage: photo).resizable().scaledToFill().scaleEffect(1.15).opacity(0.25 + 0.75 * p) }
                LinearGradient(colors: [Color(hex: "F1F2EC"), Color(hex: "DCE3E0")], startPoint: UnitPoint(x: 0.37, y: 0), endPoint: UnitPoint(x: 0.63, y: 1))
                    .opacity(0.92 - 0.62 * p)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .padding([.top, .horizontal], 6)
            Color.clear.frame(height: 26)
        }
        .frame(width: 96, height: 132)
        .overlay(alignment: .bottomLeading) {
            Text(verbatim: time).font(Typo.ui(800, 11)).foregroundStyle(HVTodayPanel.ink).padding(.leading, 8).padding(.bottom, 6)
        }
        .overlay {
            // 光の すじ(さわった 時 だけ ・ くり返さない)
            GeometryReader { g in
                LinearGradient(stops: [.init(color: .white.opacity(0), location: 0.38), .init(color: .white.opacity(0.62), location: 0.5), .init(color: .white.opacity(0), location: 0.62)],
                               startPoint: UnitPoint(x: 0, y: 0.3), endPoint: UnitPoint(x: 1, y: 0.7))
                    .frame(width: g.size.width * 2.6)
                    .offset(x: -1.6 * g.size.width * gx)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .opacity(glow)
            .allowsHitTesting(false)
        }
        .background(HVCardTint.milk, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: 12, y: 14)
        .contentShape(Rectangle())
    }
}

/// v119 4章 + v121 4章:Trip の かたまり(Friends と 同じ 形の カード)。0件 = New trip の 行(高さ 150)/ ある 時 = カードの 中で 横スクロール
struct HVActiveRow: View {
    var body: some View { VStack(spacing: 0) { HVAnchor(id: "sec-active"); content } }
    let data: HomeV64LowerData
    let input: HomeV64Input
    let actions: HomeV64Actions

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HVBlockHeader(title: "Trip", action: actions.openTrip) { HVBlockLine(text: "旅行 ・ 合宿 ・ イベントを みんなで") }
                .padding(.horizontal, 20)
            if data.trips.isEmpty {
                newTripRow.padding(.horizontal, 16).padding(.top, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(data.trips.enumerated()), id: \.offset) { _, t in tripCard(t) }
                        newTripTile
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 14)
            }
        }
        .padding(.top, 20).padding(.bottom, 14)
        .background(Color(hex: "111113"), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    /// 0件:New trip の 行(高さ 150 ・ 角丸 26 ・ 空色の うすい 光 ・ チェキ 3枚 0.9倍 ・ 右に 空色の + の 丸 52 ・ 段 5pt)
    private var newTripRow: some View {
        Button { Haptics.play(.pop); actions.openTrip() } label: {
            HStack(spacing: 0) {
                chekiFan.scaleEffect(0.9).frame(width: 112, height: 150)
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "New trip").font(Typo.title(33)).tracking(Typo.titleTracking(33)).foregroundStyle(.white).lineLimit(1)
                    Text("2〜7日の アルバム").font(Typo.ui(700, 13)).foregroundStyle(Color(hex: "8C8C93")).lineLimit(1)
                }
                .padding(.leading, 16)
                Spacer(minLength: 6)
                ZStack {
                    Circle().fill(Color(hex: "4E9CD1")).offset(y: 5)
                    Circle().fill(HVCardTint.trip)
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                }
                .frame(width: 52, height: 52).padding(.trailing, 18)
            }
            .frame(height: 150)
            .background(Color(hex: "1A1A1D"), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .background(LinearGradient(colors: [HVCardTint.trip.opacity(0.16), HVCardTint.trip.opacity(0)], startPoint: .topLeading, endPoint: .center), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(LinearGradient(colors: [HVCardTint.trip.opacity(0.16), HVCardTint.trip.opacity(0)], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)).allowsHitTesting(false))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
        .accessibilityLabel("New trip")
    }

    /// チェキ 3枚の 扇
    private var chekiFan: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                VStack(spacing: 0) {
                    Group { if let img = input.tripSamples[safe: i] { Image(uiImage: img).resizable().scaledToFill() } else { Color(hex: "3A3A3C") } }
                        .frame(width: 56, height: 58).clipped().padding([.top, .horizontal], 4)
                    Spacer(minLength: 0)
                }
                .frame(width: 64, height: 78)
                .background(Color(hex: "F4F1EA"), in: RoundedRectangle(cornerRadius: 3))
                .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
                .rotationEffect(.degrees([-8.0, 6.0, -1.0][i]))
                .offset(x: [-14.0, 14.0, 0][i], y: [2.0, 2.0, -2.0][i])
            }
        }
        .offset(x: 8)
    }

    private func tripCard(_ t: (id: UUID?, name: String, sub: String, cover: UIImage?, day: String, unread: Int)) -> some View {
        Button { Haptics.play(.pop); if let id = t.id { actions.openTripHome(id) } else { actions.openTrip() } } label: {
            ZStack(alignment: .topLeading) {
                Color(hex: "1A1A1D")
                if let c = t.cover { Image(uiImage: c).resizable().scaledToFill().frame(width: 180, height: 220).clipped() }
                LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                Text(t.day).font(Typo.ui(800, 11)).foregroundStyle(HVCardTint.trip).padding(.horizontal, 8).frame(height: 22).background(Color(hex: "111113").opacity(0.72), in: Capsule()).padding(14)
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text(t.name).font(Typo.mincho(26)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    Text(t.sub).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                }.padding(14)
                if t.unread > 0 { Text("\(t.unread)").font(Typo.ui(800, 12)).foregroundStyle(.white).frame(width: 24, height: 24).background(HVCardTint.badge, in: Circle()).frame(maxWidth: .infinity, alignment: .trailing).padding(14) }
            }
            .frame(width: 180, height: 220).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
    }

    private var newTripTile: some View {
        Button { Haptics.play(.tick); actions.openTrip() } label: {
            VStack(spacing: 10) {
                chekiFan.scaleEffect(0.8).frame(height: 96)
                Text(verbatim: "New trip").font(Typo.title(26)).foregroundStyle(.white).lineLimit(1)
                ZStack {
                    Circle().fill(Color(hex: "4E9CD1")).offset(y: 4)
                    Circle().fill(HVCardTint.trip)
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: "111113"))
                }.frame(width: 40, height: 40)
            }
            .frame(width: 150, height: 220)
            .background(Color(hex: "1A1A1D"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(HVPress(scale: 0.97))
        .accessibilityLabel("New trip")
    }
}

/// Yesterday:大きな カード + ともだち / じぶんの 写真の 並び
struct HVYesterdayBlock: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let actions: HomeV64Actions

    var body: some View {
        let locked = input.locked
        VStack(alignment: .leading, spacing: 8) {
            HVAnchor(id: "sec-yesterday", locked: input.locked)
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "きのう", trailing: HVL.weekdayJA(Calendar.current.date(byAdding: .day, value: -1, to: input.now) ?? input.now)).padding(.top, 8).padding(.bottom, 6)
            if input.isFirstDay { firstDay } else { hero(locked: locked) }
            if !input.isFirstDay {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(data.tiles) { t in tile(t, locked: locked) }
                }.padding(.horizontal, 14)
            }
        }
    }

    private func hero(locked: Bool) -> some View {
        // モック `.ayh`:ロック中も 開いて いる ときも 同じ 並び(幅 362 × 高さ 452)。ロック中は ぼかした 空 + 白い「shoot today to open」
        ZStack(alignment: .topLeading) {
            if locked {
                LinearGradient(stops: [.init(color: Color(hex: "BDB8C4"), location: 0), .init(color: Color(hex: "E9DDE2"), location: 0.34), .init(color: Color(hex: "7A6A70"), location: 0.56), .init(color: Color(hex: "1E1A1C"), location: 0.8)], startPoint: .top, endPoint: .bottom)
            } else {
                Color(hex: "1A1618")
                if let img = data.hero?.photo { Image(uiImage: img).resizable().scaledToFill().frame(width: 362, height: 452).clipped() }
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.28), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            }
            if locked {
                HStack(spacing: 8) { Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)); Text("shoot today to open").font(Typo.ui(800, 13)) }
                    .foregroundStyle(HV.ink).frame(width: 177, height: 38).background(.white, in: Capsule()).offset(x: 92, y: 150)
            }
            let h = data.hero
            Text("Yesterday").font(Typo.title(54)).foregroundStyle(.white).frame(width: 362, height: 78).offset(y: 206)
            Text(h?.dateLabel ?? "").font(Typo.ui(700, 10.5)).foregroundStyle(.white.opacity(0.7)).frame(width: 362).offset(y: 268)
            stat("\(h?.moments ?? 0)", "枚").frame(width: 100).offset(x: 31, y: 296)
            ZStack { Ellipse().stroke(HV.lime, lineWidth: 2.5).frame(width: 68, height: 46).rotationEffect(.degrees(-4)); stat("\(h?.daysLeft ?? 6)日", "のこり") }.frame(width: 100).offset(x: 131, y: 296)
            stat("\(h?.people ?? 0)", "人 ›").frame(width: 100).offset(x: 231, y: 296)
            // v119:Mondo の ボタン → 「きのうを ひらく」(きのうの 画面へ)
            Button { Haptics.play(.pop); actions.openYesterday() } label: {
                Text("きのうを ひらく").font(Typo.ui(800, 14.5)).foregroundStyle(Color(hex: "111111"))
                    .frame(width: 268, height: 54).background(.white, in: Capsule())
            }
            .buttonStyle(HVPress(scale: 0.97))
            .offset(x: 16, y: 382)
            Image(systemName: "bubble.left").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 54, height: 54).background(Color.white.opacity(0.12), in: Circle()).offset(x: 292, y: 382)
            if !locked, let h { Text(h.tag).font(Typo.ui(900, 14)).foregroundStyle(HV.ink).padding(.horizontal, 12).padding(.vertical, 8).background(h.tagColor, in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(8)).offset(x: 293, y: 18) }
        }
        .frame(width: 362, height: 452).clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    /// はじめての 日:空っぽの カード(点線の チェキ 3つ + 「TODAY'S 1ST」+ カウントダウン)
    private var firstDay: some View {
        let cal = Calendar.current
        let open = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: input.now)) ?? input.now) ?? input.now
        let sec = max(0, Int(open.timeIntervalSince(input.now)))
        return VStack(spacing: 0) {
            ZStack {
                ForEach([-1, 1], id: \.self) { sgn in
                    RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(width: 96, height: 118)
                        .rotationEffect(.degrees(Double(sgn) * 10)).offset(x: CGFloat(sgn) * 70, y: 12)
                }
                RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.5), lineWidth: 1).background(RadialGradient(colors: [HV.lime.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: 60), in: RoundedRectangle(cornerRadius: 6)).frame(width: 96, height: 118)
                    .overlay(Text("TODAY'S 1ST").font(Typo.label(9)).tracking(1.6).foregroundStyle(HV.lime).padding(.bottom, 12), alignment: .bottom)
            }.frame(height: 150).padding(.top, 26)
            Text("Yesterday").font(Typo.title(52)).tracking(-1).foregroundStyle(.white).padding(.top, 40)
            Text("今日 撮った 1枚が、あしたの 朝 9:00 に\nここで ひらきます。").font(Typo.ui(500, 13)).foregroundStyle(.white.opacity(0.66)).multilineTextAlignment(.center).lineSpacing(4).padding(.top, 30)
            HStack(spacing: 10) {
                HVLiveDot()
                Text("9:00 まで \(sec / 3600)h \(String(format: "%02d", (sec % 3600) / 60))m").font(Typo.label(11, bold: true).italic()).tracking(1.4).foregroundStyle(.white.opacity(0.85))
            }.padding(.horizontal, 18).frame(height: 34).background(Color.white.opacity(0.06), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1)).padding(.vertical, 20)
        }
        .frame(width: 362).background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.08), lineWidth: 1)).padding(.horizontal, 14)
    }

    private func stat(_ n: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(n).font(Typo.title(31)).foregroundStyle(.white); Text(l).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.62)) }
    }

    private func tile(_ t: HomeV64LowerData.Tile, locked: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "161618"))
            if let img = t.photo { Image(uiImage: img).resizable().scaledToFill().blur(radius: locked ? 14 : 0).saturation(locked ? 0.4 : 1) }
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)
            HStack {
                if !locked { Text(t.own ? "わたし." : "\(t.name).").font(Typo.title(21)).foregroundStyle(.white).lineLimit(1) }
                Spacer()
                if locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                else if let tm = t.time { Text(tm).font(Typo.label(9.5)).foregroundStyle(Color(hex: "FF9A3C")) }
            }.padding(14)
        }
        .frame(height: 212).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .topTrailing) { if t.own { Image(systemName: "star").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).padding(12) } }
    }
}

/// セクションの 頭に 置く 目印(DEBUG の 位置あわせ ・ 目次から の スクロール 用)
struct HVAnchor: View {
    let id: String
    /// かぎ付き(撮る まえの Yesterday ・ Mondo)= knock
    var locked = false
    var body: some View { Color.clear.frame(height: 0).id(id).hapticSection(id, locked: locked) }
}

/// Albums(7日):日ごとに 3枚 + 「+N」(4列)
struct HVAlbums: View {
    let data: HomeV64LowerData
    let actions: HomeV64Actions
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HVAnchor(id: "sec-albums")
            Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
            HVLabel(text: "アルバム", trailing: "7日で 消える ・ まとめ ›").padding(.top, 14)
            ForEach(Array(data.albums.enumerated()), id: \.element.id) { k, a in
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.label).font(Typo.title(25)).tracking(Typo.titleTracking(25)).foregroundStyle(.white).frame(height: 25)
                        Spacer()
                        Text(a.left).font(Typo.ui(700, 11)).foregroundStyle(a.hot ? HV.lime : Color(hex: "55555B")).lineLimit(1)
                    }.padding(.horizontal, 18)
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { j in
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.02))
                                if let img = a.tiles[safe: j] ?? nil { Image(uiImage: img).resizable().scaledToFill() }
                            }.frame(maxWidth: .infinity).frame(height: 112).clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.10), lineWidth: 1))
                        }
                        ZStack {
                            if let img = a.tiles.first ?? nil { Image(uiImage: img).resizable().scaledToFill().blur(radius: 10).brightness(-0.1) }
                            Text("+\(a.more)").font(Typo.ui(600, 15)).foregroundStyle(.white)
                        }.frame(maxWidth: .infinity).frame(height: 112).background(HVL.card).clipShape(RoundedRectangle(cornerRadius: 18))
                    }.padding(.horizontal, 14)
                }
                .padding(.top, k == 0 ? 14 : 22)
                .opacity(1 - Double(k) * 0.07)
            }
        }
    }
}

/// On this day:1年 のこした 1枚(ポラロイド + 日付 + のこり)
struct HVOnThisDay: View {
    let data: HomeV64LowerData
    var body: some View {
        if let o = data.onThisDay {
            VStack(alignment: .leading, spacing: 0) {
                HVAnchor(id: "sec-onthisday")
                Rectangle().fill(HVL.line).frame(height: 1).padding(.horizontal, 18)
                HVLabel(text: "この日", trailing: "1か月 前").padding(.top, 20)
                HStack(alignment: .top, spacing: 18) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F4F1EA"))
                        ZStack { Rectangle().fill(Color(hex: "3A3A3C")); if let img = o.photo { Image(uiImage: img).resizable().scaledToFill() } }
                            .frame(width: 136, height: 146).clipped().offset(x: 9, y: 9)
                        Text(o.date).font(Typo.label(9)).foregroundStyle(Color(hex: "FF9A3C")).offset(x: 86, y: 134)
                        Image(systemName: "sparkle").font(.system(size: 18, weight: .bold)).foregroundStyle(Color(hex: "FFD60A")).offset(x: 10, y: 160)
                    }.frame(width: 154, height: 186).rotationEffect(.degrees(-4)).shadow(color: .black.opacity(0.6), radius: 14, y: 10)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Oct 17").font(Typo.title(44)).tracking(-0.9).foregroundStyle(.white).padding(.top, 14)
                        Text("1か月 前").font(Typo.ui(700, 14)).foregroundStyle(HVL.label)
                        ZStack(alignment: .leading) { Capsule().fill(Color.white.opacity(0.08)).frame(height: 3); Capsule().fill(HV.lime).frame(width: 150, height: 3) }.padding(.top, 14)
                        Text("あと \(o.daysLeft)日").font(Typo.ui(700, 12)).foregroundStyle(HVL.label)
                        HStack(spacing: 5) { Capsule().fill(.white).frame(width: 14, height: 5); Circle().fill(.white.opacity(0.3)).frame(width: 5, height: 5); Circle().fill(.white.opacity(0.3)).frame(width: 5, height: 5) }
                    }
                    Spacer(minLength: 0)
                }.padding(.horizontal, 16).padding(.top, 24)
            }
        }
    }
}

/// 下の ぜんぶを たばねる
struct HVLowerSections: View {
    let input: HomeV64Input
    let data: HomeV64LowerData
    let actions: HomeV64Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HVTodayPanel(input: input, data: data, onShoot: actions.shoot, onDevelop: actions.openDevelop).id("today")
            HVFriendsCard(input: input, actions: actions)   // v95-9:今日の フィルムの すぐ 下
            HVActiveRow(data: data, input: input, actions: actions)
            HVYesterdayBlock(input: input, data: data, actions: actions)
            if !input.isFirstDay {
                HVAlbums(data: data, actions: actions)
                HVOnThisDay(data: data)
            }
            Spacer().frame(height: 404)
        }
        .background(alignment: .top) { VStack(spacing: 0) { Color.clear.frame(height: 90); HVL.bg } }
    }
}

/// 指の 位置を 追う(スクロール ・ ボタンの じゃまを しない UIKit の 認識器 ・ 同時に 動く)
struct HVTouchTracker: UIGestureRecognizerRepresentable {
    let onChange: (CGPoint?) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let g = UILongPressGestureRecognizer()
        g.minimumPressDuration = 0
        g.allowableMovement = .greatestFiniteMagnitude
        g.cancelsTouchesInView = false
        g.delaysTouchesBegan = false
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ r: UILongPressGestureRecognizer, context: Context) {
        switch r.state {
        case .began, .changed: onChange(context.converter.localLocation)
        default: onChange(nil)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
