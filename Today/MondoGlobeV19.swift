import SwiftUI
import UIKit

// v19 Mondo の地球儀(見本:Docs/Mocks/later_me_mondo_v19.html の Mondo 部分)。
// 本物の陸の点 + 海のうすい点 + 経線・緯線(30°)+ きのう撮られた場所の光。
// 点は1つの Canvas で描く(点の数だけ View を作らない)。動きは GlobeController の 60fps のループ。

enum GlobeRules {
    /// 指 1pt あたりの回転(半径 150pt のとき 0.36°)
    static let degreesPerPoint = 0.36
    static let referenceRadius = 150.0
    /// 惰性:毎フレーム 0.95 倍
    static let friction = 0.95
    /// まわした角度 12° ごとに tick
    static let tickDegrees = 12.0
    /// 光がまん中(この角度以内 ÷ 拡大)に来たら click
    static let centerDegrees = 4.5
    /// 光をおせる距離(pt × √拡大)
    static let hitRadius = 22.0
    /// 跳んだ先の拡大
    static let jumpZoom = 2.6
    /// 跳ぶ時間:距離に合わせて 0.7〜1.5秒
    static func jumpDuration(distance: Double) -> Double { min(1.5, max(0.7, (500 + distance * 4.5) / 1000)) }
    /// ズームがもどる時間
    static let closeDuration = 0.52
    /// 何もしない時の自転(はなして 2.5秒後から)
    static let idleDelay = 2.5
    static let idleSpeed = 0.05

    static func easeInOutCubic(_ k: Double) -> Double {
        k < 0.5 ? 4 * k * k * k : 1 - pow(-2 * k + 2, 3) / 2
    }

    /// 跳ぶ途中の拡大:前半はいったん少し引き、後半で ぐっと寄る
    static func jumpZoomAt(_ k: Double, from z0: Double) -> Double {
        let hop = sin(.pi * min(1, max(0, k * 1.1)))
        if k < 0.5 { return z0 + (1 - z0) * easeInOutCubic(k * 2) - 0.08 * hop }
        return 1 + (jumpZoom - 1) * easeInOutCubic((k - 0.5) * 2)
    }
}

@MainActor @Observable
final class GlobeController {
    var view = GlobeView2D()
    var lights: [MondoLight] = []
    /// 跳んで着いた光(カードを出す)
    private(set) var selected: MondoLight?
    /// まん中にある光(照準の下に名前)
    private(set) var near: MondoLight?
    private(set) var isZoomed = false
    private(set) var isLocked = false
    private(set) var isBusy = false
    private(set) var dragging = false
    var cardOpen = false
    /// 脈打つための時刻
    private(set) var clock: Double = 0

    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var onArrive: (MondoLight) -> Void = { _ in }
    @ObservationIgnored private var velocity = (lon: 0.0, lat: 0.0)
    @ObservationIgnored private var accumulated = 0.0
    @ObservationIgnored private var idleSince = Date()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var jump: (light: MondoLight, start: Date, duration: Double, from: GlobeView2D, dLon: Double, toLat: Double)?
    @ObservationIgnored private var closing: (start: Date, from: Double)?
    @ObservationIgnored private var ramp = HapticRamp()
    @ObservationIgnored private var lastFrame = Date()

    nonisolated init() {}

    // MARK: ループ

    func start() {
        guard loop == nil else { return }
        lastFrame = Date()
        loop = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.frame()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        ramp.stop()
    }

    private func frame() {
        let now = Date()
        lastFrame = now
        clock = now.timeIntervalSinceReferenceDate
        if let jump { stepJump(jump, now: now); return }
        if let closing {
            let k = min(1, now.timeIntervalSince(closing.start) / GlobeRules.closeDuration)
            view.zoom = closing.from + (1 - closing.from) * GlobeRules.easeInOutCubic(k)
            if k >= 1 {
                self.closing = nil
                view.zoom = 1
                isZoomed = false
                isBusy = false
                selected = nil
            }
            return
        }
        guard !dragging else { return }
        if hypot(velocity.lon, velocity.lat) > 0.02 {
            // 惰性で回っている間は、カリカリを鳴らす
            turn(dLon: velocity.lon, dLat: velocity.lat, haptics: true)
            velocity = (velocity.lon * GlobeRules.friction, velocity.lat * GlobeRules.friction)
        } else if !cardOpen, !isZoomed, !reduceMotion, now.timeIntervalSince(idleSince) > GlobeRules.idleDelay {
            // 自転(バイブなし)
            view.turn(dLon: GlobeRules.idleSpeed, dLat: 0)
        }
    }

    // MARK: 回す

    private func turn(dLon: Double, dLat: Double, haptics: Bool) {
        view.turn(dLon: dLon, dLat: dLat)
        guard haptics else { return }
        accumulated += abs(dLon) * cos(view.lat * .pi / 180) + abs(dLat)
        if accumulated >= GlobeRules.tickDegrees {
            accumulated = 0
            Haptics.play(.tick, gap: 0.022)
        }
        let hit = lights.first { MondoGeo.angularDistance(view.center, $0.point) < GlobeRules.centerDegrees / view.zoom }
        if hit?.id != near?.id {
            near = hit
            if hit != nil { Haptics.play(.click, gap: 0.06) }
        }
    }

    private var dragLast: CGPoint?
    private var dragLastTime = Date()
    private var dragMoved = false

    func dragChanged(_ value: DragGesture.Value, radius: Double) {
        guard !isBusy || cardOpen else { return }
        if dragLast == nil {
            dragLast = value.startLocation
            dragLastTime = Date()
            dragMoved = false
            velocity = (0, 0)
            idleSince = Date()
        }
        guard let last = dragLast else { return }
        let dx = value.location.x - last.x, dy = value.location.y - last.y
        if !dragMoved, hypot(value.translation.width, value.translation.height) > 5 {
            dragMoved = true
            dragging = true
            if cardOpen { close(quick: true) }
        }
        guard dragMoved, !isBusy || cardOpen else { return }
        let k = GlobeRules.degreesPerPoint * (GlobeRules.referenceRadius / max(1, radius)) / view.zoom
        let now = Date()
        let dt = max(0.008, now.timeIntervalSince(dragLastTime))
        turn(dLon: -dx * k, dLat: dy * k, haptics: true)
        velocity = (velocity.lon * 0.4 + (-dx * k / dt * 0.016) * 0.6, velocity.lat * 0.4 + (dy * k / dt * 0.016) * 0.6)
        dragLast = value.location
        dragLastTime = now
    }

    /// はなした。動いていなければタップ(光をおす / とじる)
    func dragEnded(_ value: DragGesture.Value, center: CGPoint, radius: Double) {
        let moved = dragMoved
        dragLast = nil
        dragMoved = false
        dragging = false
        idleSince = Date()
        guard !moved else { return }
        velocity = (0, 0)
        let tap = value.location
        let r = radius * view.zoom
        let hit = lights.compactMap { light -> (MondoLight, Double)? in
            let p = view.project(light.point, radius: r)
            guard p.v > 0.05 else { return nil }
            return (light, hypot(center.x + p.x - tap.x, center.y + p.y - tap.y))
        }.min { $0.1 < $1.1 }
        if let hit, hit.1 < GlobeRules.hitRadius * view.zoom.squareRoot() {
            jump(to: hit.0)
        } else if cardOpen {
            close(quick: false)
        } else if hypot(tap.x - center.x, tap.y - center.y) < r {
            Haptics.play(.soft)
        }
    }

    // MARK: 跳ぶ

    func jump(to light: MondoLight) {
        guard jump == nil else { return }
        Haptics.play(.pop)
        velocity = (0, 0)
        closing = nil
        cardOpen = false
        isBusy = true
        isZoomed = true
        isLocked = false
        selected = light
        let dLon = ((light.point.lon - view.lon + 540).truncatingRemainder(dividingBy: 360)) - 180
        let toLat = min(64, max(-55, light.point.lat))
        let distance = hypot(dLon * cos(toLat * .pi / 180), toLat - view.lat)
        let duration = reduceMotion ? 0.35 : GlobeRules.jumpDuration(distance: distance)
        jump = (light, Date(), duration, view, dLon, toLat)
        if !reduceMotion { ramp.start() }
    }

    private func stepJump(_ j: (light: MondoLight, start: Date, duration: Double, from: GlobeView2D, dLon: Double, toLat: Double), now: Date) {
        let k = min(1, now.timeIntervalSince(j.start) / j.duration)
        let e = GlobeRules.easeInOutCubic(k)
        let lon = j.from.lon + j.dLon * e
        let lat = j.from.lat + (j.toLat - j.from.lat) * e
        let previous = view
        view.lon = ((lon + 540).truncatingRemainder(dividingBy: 360)) - 180
        view.lat = lat
        // 視差効果を減らす:ズームなしの短い回転
        view.zoom = reduceMotion ? 1 : GlobeRules.jumpZoomAt(k, from: j.from.zoom)
        // 12°ごとの tick(途中)
        var dl = view.lon - previous.lon
        if dl > 180 { dl -= 360 } else if dl < -180 { dl += 360 }
        accumulated += abs(dl) * cos(lat * .pi / 180) + abs(lat - previous.lat)
        if accumulated >= GlobeRules.tickDegrees { accumulated = 0; Haptics.play(.tick, gap: 0.022) }
        // ひゅーっ(まん中で一番強い)
        ramp.update(0.75 * sin(.pi * k))
        guard k >= 1 else { return }
        ramp.stop()
        jump = nil
        view.lon = ((j.from.lon + j.dLon + 540).truncatingRemainder(dividingBy: 360)) - 180
        view.lat = j.toLat
        view.zoom = reduceMotion ? 1 : GlobeRules.jumpZoom
        near = j.light
        isLocked = true
        Haptics.play(.thud)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { Haptics.play(.click) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, self.selected?.id == j.light.id else { return }
            self.cardOpen = true
            self.isBusy = false
            Haptics.play(.pop)
            self.onArrive(j.light)
        }
    }

    /// カードの × / 地球のほかの所 / ドラッグ:カードをとじ、0.52秒でズームがもどる
    func close(quick: Bool) {
        guard cardOpen || isZoomed else { return }
        cardOpen = false
        isLocked = false
        if !quick { Haptics.play(.soft) }
        isBusy = true
        closing = (Date(), view.zoom)
    }

    /// となりへ(経度で東の光へ、続けて跳ぶ)
    func jumpNext() {
        guard let selected, let next = MondoGeo.next(after: selected, in: lights) else { return }
        Haptics.play(.click)
        cardOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.jump(to: next) }
    }

    func random() {
        let others = lights.filter { $0.id != selected?.id }
        guard let pick = others.randomElement() ?? lights.first else { return }
        Haptics.play(.click)
        jump(to: pick)
    }
}

// MARK: - 描く

struct GlobeCanvasV19: View {
    let controller: GlobeController
    /// 拡大していない時の半径
    let radius: Double

    var body: some View {
        let view = controller.view
        let lights = controller.lights
        let selectedID = controller.selected?.id
        let t = controller.clock
        Canvas(rendersAsynchronously: false) { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let z = view.zoom
            let r = radius * z
            let rs = z.squareRoot()
            // まわりのにじみ
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.5, y: c.y - r * 1.5, width: r * 3, height: r * 3)),
                     with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.59, blue: 0.35).opacity(0.10), .clear]), center: c, startRadius: r * 0.8, endRadius: r * 1.5))
            let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.fill(disc, with: .radialGradient(Gradient(stops: [
                .init(color: Color(hex: "24242B"), location: 0), .init(color: Color(hex: "111115"), location: 0.6), .init(color: Color(hex: "08080A"), location: 1),
            ]), center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: r * 0.1, endRadius: r))
            var inner = ctx
            inner.clip(to: disc)
            // 経線・緯線(30°ごと)
            var grid = Path()
            for m in stride(from: -180.0, to: 180, by: 30) {
                var started = false
                for la in stride(from: -90.0, through: 90, by: 6) {
                    let p = view.project(GeoPoint(lat: la, lon: m), radius: r)
                    if p.v > 0 {
                        let pt = CGPoint(x: c.x + p.x, y: c.y + p.y)
                        if started { grid.addLine(to: pt) } else { grid.move(to: pt) }
                        started = true
                    } else { started = false }
                }
            }
            for la in stride(from: -60.0, through: 60, by: 30) {
                var started = false
                for lo in stride(from: -180.0, through: 180, by: 6) {
                    let p = view.project(GeoPoint(lat: la, lon: lo), radius: r)
                    if p.v > 0 {
                        let pt = CGPoint(x: c.x + p.x, y: c.y + p.y)
                        if started { grid.addLine(to: pt) } else { grid.move(to: pt) }
                        started = true
                    } else { started = false }
                }
            }
            inner.stroke(grid, with: .color(.white.opacity(0.07)), lineWidth: 1)
            // 海(うすい点・9%)
            let visible = CGRect(origin: .zero, size: size).insetBy(dx: -4, dy: -4)
            for q in MondoGeo.ocean {
                let p = view.project(q, radius: r)
                guard p.v > 0 else { continue }
                let x = c.x + p.x, y = c.y + p.y
                guard visible.contains(CGPoint(x: x, y: y)) else { continue }
                let s = 0.6 * rs
                inner.opacity = 0.09 * p.v
                inner.fill(Path(CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(.white))
            }
            // 陸(手前ほど明るく、ふちほど小さく暗く)。明るさを5段にまとめて、まとめて塗る
            var bands = [Path](repeating: Path(), count: 5)
            for q in MondoGeo.land {
                let p = view.project(q, radius: r)
                guard p.v > 0 else { continue }
                let x = c.x + p.x, y = c.y + p.y
                guard visible.contains(CGPoint(x: x, y: y)) else { continue }
                let s = 1.25 * rs * (0.6 + 0.4 * p.v)
                let band = min(4, Int(p.v * 5))
                bands[band].addEllipse(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2))
            }
            for (i, path) in bands.enumerated() {
                inner.opacity = 0.25 + 0.7 * (Double(i) + 0.5) / 5
                inner.fill(path, with: .color(.white))
            }
            inner.opacity = 1
            // 光(きのう撮られた場所)。大きさは枚数、ゆっくり脈打つ
            for light in lights {
                let p = view.project(light.point, radius: r)
                guard p.v > 0.02 else { continue }
                let pt = CGPoint(x: c.x + p.x, y: c.y + p.y)
                let pulse = 1 + 0.18 * sin(t * 3 + light.point.lon)
                let rr = (7 + min(Double(light.count), 40) * 0.45) * rs * pulse
                inner.fill(Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)),
                           with: .radialGradient(Gradient(stops: [
                               .init(color: Color(red: 1, green: 0.67, blue: 0.39).opacity(0.9 * p.v), location: 0),
                               .init(color: Color(red: 1, green: 0.47, blue: 0.24).opacity(0.35 * p.v), location: 0.4),
                               .init(color: .clear, location: 1),
                           ]), center: pt, startRadius: 0, endRadius: rr))
                let isSelected = light.id == selectedID
                let dot = (isSelected ? 3.6 : 2.4) * rs
                inner.fill(Path(ellipseIn: CGRect(x: pt.x - dot, y: pt.y - dot, width: dot * 2, height: dot * 2)), with: .color(isSelected ? .white : Color(hex: "FFC08A")))
            }
            // 左上の光の反射
            let glint = CGPoint(x: c.x - r * 0.4, y: c.y - r * 0.55)
            inner.fill(Path(CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .radialGradient(Gradient(colors: [.white.opacity(0.10), .clear]), center: glint, startRadius: 0, endRadius: r * 0.8))
            // ふちは点線
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r - 0.5, y: c.y - r - 0.5, width: r * 2 + 1, height: r * 2 + 1)),
                       with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 1, dash: [1.5, 4]))
        }
    }
}

/// 照準の丸と、英字の地名
struct GlobeCrosshair: View {
    let controller: GlobeController

    var body: some View {
        let locked = controller.isLocked
        let on = controller.dragging || controller.near != nil || controller.isZoomed
        VStack(spacing: 10) {
            Circle()
                .strokeBorder(locked ? Color(hex: "FFB27A") : Color(red: 1, green: 0.78, blue: 0.59).opacity(on ? 0.55 : 0), lineWidth: 1.5)
                .frame(width: locked ? 22 : 44, height: locked ? 22 : 44)
                .shadow(color: Color(red: 1, green: 0.54, blue: 0.16).opacity(locked ? 0.6 : 0), radius: 9)
                .frame(width: 44, height: 44)
            Text(controller.near?.latinName ?? " ")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.24 * 10)
                .foregroundStyle(Color(hex: "FFC8A0"))
                .opacity(controller.near == nil ? 0 : 1)
                .lineLimit(1)
                .fixedSize()
        }
        .animation(.easeOut(duration: 0.3), value: locked)
        .animation(.easeOut(duration: 0.25), value: controller.near?.id)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 場所チップ

struct MondoPlaceChips: View {
    let controller: GlobeController

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button { controller.random() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "dice").font(.system(size: 14, weight: .semibold))
                        Text("どこかへ").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "111111"))
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Capsule().fill(Color(hex: "F4F4F6")))
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
                .disabled(controller.lights.isEmpty)
                ForEach(controller.lights) { light in
                    Button { controller.jump(to: light) } label: {
                        HStack(spacing: 7) {
                            Circle().fill(Color(hex: "FF8A2A")).frame(width: 7, height: 7).shadow(color: Color(hex: "FF8A2A"), radius: 4)
                            Text(light.name).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Text("\(light.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color(hex: "8E8E95"))
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 14)
                        .frame(height: 38)
                        .background(GlassCapsule())
                    }
                    .buttonStyle(SquishButtonStyle(pressedScale: 0.94))
                    .accessibilityLabel("\(light.name)、\(light.count)まい")
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

/// 黒いガラス(白 8.5% → 3.5%・ふち 白12%・上のふちに細い光)
struct GlassCapsule: View {
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0.085), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
            .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

struct GlassRect: View {
    var radius: CGFloat
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(LinearGradient(colors: [.white.opacity(0.085), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
            .background(.ultraThinMaterial.opacity(0.6), in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .overlay(alignment: .top) {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
    }
}

// MARK: - 場所のカード

struct MondoPlaceCard: View {
    let light: MondoLight
    let entries: [MondoEntry]
    let locked: Bool
    let onClose: () -> Void
    let onNext: () -> Void
    let onOpenPhoto: (_ entry: MondoEntry, _ point: CGPoint) -> Void
    let onToast: (String) -> Void

    @State private var shown = false
    @State private var thumbs: [String: UIImage] = [:]

    private var shownEntries: [MondoEntry] { Array(entries.prefix(6)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(.white.opacity(0.22)).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, -6).padding(.bottom, 12)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(light.name)
                        .font(.system(size: 32, weight: .black))
                        .tracking(-0.04 * 32)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(light.coordinateText)
                        .font(.system(size: 9.5, design: .monospaced))
                        .tracking(0.18 * 9.5)
                        .foregroundStyle(Color(hex: "8E8E95"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(GlassCapsule())
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
                .accessibilityLabel("とじる")
            }
            HStack(spacing: 16) {
                (Text("\(light.count)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "FFB070")) + Text(" まい"))
                Text(light.tags.map { "#\($0)" }.joined(separator: " ")).lineLimit(1)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(hex: "D9D9DE"))
            .padding(.top, 14)
            .padding(.bottom, 12)
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(shownEntries.enumerated()), id: \.element.id) { index, entry in
                        photo(entry, index: index)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
            HStack {
                Text(locked ? "撮ると ひらく ・ 名前は 出ない" : "市区町村まで ・ 名前は 出ない")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.14 * 9.5)
                    .foregroundStyle(Color(hex: "5E5E66"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 10)
                Button(action: onNext) {
                    Text("となりへ ›").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "111111"))
                        .padding(.horizontal, 14).frame(height: 34).background(Capsule().fill(Color(hex: "F4F4F6")))
                }
                .buttonStyle(SquishButtonStyle(pressedScale: 0.92))
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background {
            let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
            shape.fill(LinearGradient(colors: [Color(red: 0.12, green: 0.11, blue: 0.125).opacity(0.86), Color(red: 0.063, green: 0.059, blue: 0.07).opacity(0.94)], startPoint: .top, endPoint: .bottom))
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            shown = true
            // 写真は1枚ずつ、少し遅れて浮かぶ(1枚ごとに tick)
            for i in 0..<shownEntries.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12 + Double(i) * 0.06) { Haptics.play(.tick, gap: 0) }
            }
        }
        .task(id: light.id) {
            guard !locked else { return }
            for entry in shownEntries {
                if let image = await MondoService.shared.thumbnail(for: entry) { thumbs[entry.id] = image }
            }
        }
    }

    private func photo(_ entry: MondoEntry, index: Int) -> some View {
        let rotation = [-3.0, 2, -1.5, 3, -2, 1][index % 6]
        return GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Color(hex: "F7F4EE")
                VStack {
                    ZStack {
                        if locked {
                            MondoMosaic(seed: entry.id, tone: entry.toneHex)
                            Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 18, height: 18).background(Circle().fill(.black.opacity(0.45)))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
                        } else if let image = thumbs[entry.id] {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Color(hex: entry.toneHex ?? "3A3A40")
                        }
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    Spacer(minLength: 0)
                }
                .padding(6)
                if let tag = entry.tags.first {
                    Text("#\(tag)").font(.system(size: 10, weight: .heavy)).foregroundStyle(Color(hex: "3A3A3C")).padding(.leading, 7).padding(.bottom, 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.45), radius: 12, y: 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if locked {
                    Haptics.play(.warn)
                    onToast("今日を撮ると、ひらきます")
                } else {
                    Haptics.play(.pop)
                    let frame = proxy.frame(in: .global)
                    onOpenPhoto(entry, CGPoint(x: frame.midX, y: frame.midY))
                }
            }
        }
        .frame(width: 104, height: 150)
        .rotationEffect(.degrees(rotation))
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 24)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.08 + Double(index) * 0.06), value: shown)
        .accessibilityLabel(locked ? "まだ ひらかない写真" : "写真 \(entry.tags.first.map { "#\($0)" } ?? "")")
    }
}

/// 撮る前のモザイク(写真の色から作る。写真そのものは読まない)
struct MondoMosaic: View {
    let seed: String
    let tone: String?

    var body: some View {
        Canvas { ctx, size in
            var hash: UInt64 = 1469598103934665603
            for b in seed.utf8 { hash = (hash ^ UInt64(b)) &* 1099511628211 }
            let palettes: [[String]] = [["F7B38A", "F28A9A", "9C86C9", "6C5BA8"], ["E9C99A", "F29A6B", "C2476B", "7A2E4A"], ["C9E1D2", "9FC2B0", "E8D9A8", "6E9AA8"], ["2C3E6B", "4C6F9C", "E6709A", "FFC27A"]]
            var colors = palettes[Int(hash % 4)]
            if let tone { colors[0] = tone }
            let cols = 6, rows = 7
            let w = size.width / CGFloat(cols), h = size.height / CGFloat(rows)
            for r in 0..<rows {
                for c in 0..<cols {
                    hash = hash &* 6364136223846793005 &+ 1442695040888963407
                    ctx.fill(Path(CGRect(x: CGFloat(c) * w, y: CGFloat(r) * h, width: w + 0.5, height: h + 0.5)), with: .color(Color(hex: colors[Int((hash >> 33) % 4)])))
                }
            }
        }
    }
}
