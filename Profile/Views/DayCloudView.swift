import SwiftUI
import UIKit

/// 「預けた日々」の1点(1日1枚)。
struct DayPoint: Identifiable, Equatable {
    let id: String          // ExposureDay.dayKey(安定した識別子)
    let date: Date
    /// その日の1枚がひらいているか(その日より後に撮っていれば、ひらいている)
    let opened: Bool
    /// 写真の中心の色(ひらいている日だけ。ひらいていない日は白)
    let color: Color?
    /// 市区町村まで
    let locationName: String?
    /// カードに写真を出してよいか(ひらいていて、写真を見られる期間内)
    let showsPhoto: Bool
}

/// 写真を見られる期間(日)。それより前の日は、点と色だけ残す。
enum DayCloudRules {
    static let photoVisibleDays = 7
    /// 描く日数の上限(それより古い日は描かない。日数の表示は総数)
    static let maxVisibleDays = 365
}

/// 点の群れ(ひまわりの種のような渦)。新しい日が中心、古い日が外側。Canvas 1枚で描く。
/// 押している間は回転を止め、指に最も近い点(30pt以内)を選んでカードを浮かべる。
struct DayCloudView: View {
    let points: [DayPoint]
    /// 画面が見えている間だけ回転・呼吸を動かす
    let isAnimating: Bool
    /// 登場演出(中心から外へ渦を巻いて現れる)の開始時刻。nilなら演出なし。
    let entranceStart: Date?
    let thumbnailFor: (DayPoint) -> UIImage?
    let onSelectionChange: (DayPoint?) -> Void
    /// なぞらずに短く押して離した(その日の詳細を開く入口。今は呼び出し口だけ)
    let onTapDay: (DayPoint) -> Void

    static let height: CGFloat = 236
    private static let rotationPeriod: Double = 240
    private static let hitRadius: CGFloat = 30
    private static let goldenAngle = 2.39996

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 回転の基準(なぞった後は、止めた角度から続ける)
    @State private var thetaBase: Double = 0
    @State private var thetaStart = Date()
    @State private var frozenTheta: Double?
    @State private var selectedIndex: Int?
    @State private var pressStart: Date?
    @State private var voiceOverIndex = 0

    var body: some View {
        GeometryReader { proxy in
            let layout = CloudLayout(points: points, width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(paused: !isAnimating || (reduceMotion && entranceStart == nil))) { context in
                    let theta = frozenTheta ?? currentTheta(at: context.date)
                    Canvas { graphics, _ in
                        draw(layout: layout, theta: theta, time: context.date, in: &graphics)
                    }
                }

                if let selectedIndex, let theta = frozenTheta, selectedIndex < layout.count {
                    let position = layout.position(of: selectedIndex, theta: theta)
                    DayCard(point: points[selectedIndex], thumbnail: thumbnailFor(points[selectedIndex]))
                        .position(cardPosition(for: position, in: proxy))
                        .transition(.opacity.combined(with: .offset(y: 8)).combined(with: .scale(scale: 0.96)))
                        .allowsHitTesting(false)
                        .id(points[selectedIndex].id)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in track(value.location, layout: layout) }
                    .onEnded { value in release(translation: value.translation) }
            )
            .accessibilityElement()
            .accessibilityLabel("預けた日々、\(points.count)日")
            .accessibilityValue(points.indices.contains(voiceOverIndex) ? Self.spokenDescription(points[voiceOverIndex]) : "")
            .accessibilityAdjustableAction { direction in
                guard !points.isEmpty else { return }
                switch direction {
                case .increment: voiceOverIndex = min(points.count - 1, voiceOverIndex + 1)
                case .decrement: voiceOverIndex = max(0, voiceOverIndex - 1)
                @unknown default: break
                }
            }
        }
        .frame(height: Self.height)
    }

    // MARK: 回転

    private func currentTheta(at date: Date) -> Double {
        guard !reduceMotion else { return thetaBase }
        return thetaBase + date.timeIntervalSince(thetaStart) / Self.rotationPeriod * 2 * .pi
    }

    // MARK: なぞる

    private func track(_ location: CGPoint, layout: CloudLayout) {
        if frozenTheta == nil {
            // 押した瞬間の角度で固定し、当たり判定もその座標で行う。
            frozenTheta = currentTheta(at: Date())
            pressStart = Date()
        }
        guard let theta = frozenTheta else { return }
        var nearest: (index: Int, distance: CGFloat)?
        for index in 0..<layout.count {
            let point = layout.position(of: index, theta: theta)
            let distance = hypot(point.x - location.x, point.y - location.y)
            if distance <= Self.hitRadius, distance < (nearest?.distance ?? .infinity) {
                nearest = (index, distance)
            }
        }
        let newIndex = nearest?.index
        guard newIndex != selectedIndex else { return }
        withAnimation(.easeOut(duration: 0.18)) { selectedIndex = newIndex }
        onSelectionChange(newIndex.map { points[$0] })
    }

    private func release(translation: CGSize) {
        let wasTap = hypot(translation.width, translation.height) < 6
            && (pressStart.map { Date().timeIntervalSince($0) < 0.35 } ?? false)
        if wasTap, let selectedIndex, points[selectedIndex].opened {
            onTapDay(points[selectedIndex])
        }
        if let frozenTheta {
            thetaBase = frozenTheta
            thetaStart = Date()
        }
        frozenTheta = nil
        pressStart = nil
        withAnimation(.easeOut(duration: 0.18)) { selectedIndex = nil }
        onSelectionChange(nil)
    }

    /// カードの上端を点の212pt上に置く。画面の上端から290ptより上にはみ出す時は、点の34pt下に出す。
    /// 画面の左右14ptの余白を守る。
    private func cardPosition(for point: CGPoint, in proxy: GeometryProxy) -> CGPoint {
        let frame = proxy.frame(in: .global)
        let cardTopAbove = point.y - 212
        let top = frame.minY + cardTopAbove >= 290 ? cardTopAbove : point.y + 34
        let halfWidth = DayCard.width / 2
        let minX = 14 + halfWidth - frame.minX
        let maxX = frame.width - 14 - halfWidth
        return CGPoint(x: min(max(point.x, minX), maxX), y: top + DayCard.approximateHeight / 2)
    }

    // MARK: 描画

    private func draw(layout: CloudLayout, theta: Double, time: Date, in graphics: inout GraphicsContext) {
        guard layout.count > 0 else { return }
        let t = time.timeIntervalSinceReferenceDate
        let isSelecting = selectedIndex != nil

        var dots: [(rect: CGRect, glow: CGRect, color: Color, opacity: Double, glowOpacity: Double, selected: Bool)] = []
        dots.reserveCapacity(layout.count)
        for index in 0..<layout.count {
            let point = points[index]
            let position = layout.position(of: index, theta: theta)
            var size = layout.size(of: index)
            var opacity = layout.opacity(of: index)
            let color = point.opened ? (point.color ?? .white) : .white

            // 中心の最新の点がひらいていない(今日の1枚)時は、白く大きく呼吸する。
            if index == 0 && !point.opened {
                size = 7.5 * (reduceMotion ? 1 : 1 + 0.18 * sin(t / 0.48))
                opacity = 1
            }

            let appear = entranceProgress(index: index, time: time)
            size *= appear
            opacity *= appear

            let selected = selectedIndex == index
            var glowOpacity = 0.35 * opacity
            if isSelecting {
                if selected {
                    size *= 2.3
                    glowOpacity = min(1, glowOpacity * 1.6)
                } else {
                    opacity *= 0.28
                    glowOpacity = 0.08 * opacity
                }
            }
            guard size > 0.05 else { continue }
            let rect = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)
            let glowRadius = size * 1.8
            let glow = CGRect(x: position.x - glowRadius, y: position.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            dots.append((rect, glow, color, opacity, glowOpacity, selected))
        }

        // やわらかい光は、全部の点を1つのレイヤーに描いてから1回だけぼかす(点ごとにぼかさない)。
        graphics.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            for dot in dots {
                layer.fill(Path(ellipseIn: dot.glow), with: .color(dot.color.opacity(dot.glowOpacity)))
            }
        }
        for dot in dots {
            graphics.fill(Path(ellipseIn: dot.rect), with: .color(dot.color.opacity(dot.opacity)))
            if dot.selected {
                graphics.stroke(Path(ellipseIn: dot.rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(.white), lineWidth: 1.6)
            }
        }
    }

    /// 中心に近い点から順に20msずつずらし、スケール・不透明度0→1(各0.4秒)。
    private func entranceProgress(index: Int, time: Date) -> Double {
        guard let entranceStart, !reduceMotion else { return 1 }
        let delay = min(Double(index) * 0.02, 0.8)
        let progress = (time.timeIntervalSince(entranceStart) - delay) / 0.4
        let clamped = min(1, max(0, progress))
        return 1 - pow(1 - clamped, 3)
    }

    // MARK: 読み上げ

    static func spokenDescription(_ point: DayPoint) -> String {
        if !point.opened {
            return Calendar.current.isDateInToday(point.date) ? "今日の1枚、まだひらいていません" : "\(DayCard.dateLabel(point.date))、まだひらいていません"
        }
        var parts = [DayCard.dateLabel(point.date), DayCard.weekdayLabel(point.date)]
        if let location = point.locationName { parts.append(location) }
        return parts.joined(separator: "、")
    }
}

// MARK: - 配置

/// i番目(0が最も新しい日)の点を、角度 i×2.39996+θ、半径 k×√(i+0.5) に置き、x方向は1.5倍(楕円)。
/// kは日数が増えても画面の幅に収まるよう min(16, 106/√(n+0.5))。
private struct CloudLayout {
    let count: Int
    let k: Double
    let center: CGPoint
    let xScale: Double

    init(points: [DayPoint], width: CGFloat) {
        count = min(points.count, DayCloudRules.maxVisibleDays)
        k = min(16, 106 / sqrt(Double(count) + 0.5))
        center = CGPoint(x: width / 2, y: 118)
        xScale = 1.5 * Double(width / 390)
    }

    func position(of index: Int, theta: Double) -> CGPoint {
        let angle = Double(index) * 2.39996 + theta
        let radius = k * sqrt(Double(index) + 0.5)
        return CGPoint(x: center.x + CGFloat(cos(angle) * radius * xScale), y: center.y + CGFloat(sin(angle) * radius))
    }

    /// 新しいほど大きく(最大6.2pt → 古いほど約2.6pt)。日数が多い時はさらに小さく。
    func size(of index: Int) -> CGFloat {
        let fraction = count > 1 ? Double(index) / Double(count - 1) : 0
        let crowding = count > 120 ? 0.8 : 1
        return CGFloat((6.2 - 3.6 * fraction) * crowding)
    }

    /// 古い点は少し暗く(1.0 → 0.5)
    func opacity(of index: Int) -> Double {
        let fraction = count > 1 ? Double(index) / Double(count - 1) : 0
        return 1 - 0.5 * fraction
    }
}

// MARK: - カード

/// なぞった時に、選んだ点のそばに浮かぶガラスのカード。ひらいていない日の写真は絶対に出さない。
struct DayCard: View {
    let point: DayPoint
    let thumbnail: UIImage?

    static let width: CGFloat = 156
    static let approximateHeight: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailArea
                .frame(width: Self.width - 14, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .tracking(-0.03 * 16)
                .foregroundStyle(.white)
                .padding(.top, 9)
                .padding(.horizontal, 3)

            Text(subtitle)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Color(hex: "8E8E93"))
                .lineLimit(1)
                .padding(.top, 3)
                .padding(.horizontal, 3)
                .padding(.bottom, 4)
        }
        .padding(7)
        .frame(width: Self.width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "1D1D20"), Color(hex: "121214")], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.14)).frame(height: 1).padding(.horizontal, 18)
        }
        .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var thumbnailArea: some View {
        if point.opened, point.showsPhoto, let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if point.opened {
            // 写真を見られる期間を過ぎた日は、その日の色だけを残す。
            (point.color ?? .white).opacity(0.55)
        } else {
            ZStack {
                Color.black
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: .white.opacity(0.8), radius: 5)
            }
        }
    }

    private var title: String {
        if !point.opened, Calendar.current.isDateInToday(point.date) { return "今日の1枚" }
        return Self.dateLabel(point.date)
    }

    private var subtitle: String {
        if !point.opened { return "まだ、ひらいていません" }
        var parts = [Self.weekdayLabel(point.date)]
        if let location = point.locationName { parts.append(location) }
        return parts.joined(separator: " ・ ")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static func dateLabel(_ date: Date) -> String { dateFormatter.string(from: date) }
    static func weekdayLabel(_ date: Date) -> String { weekdayFormatter.string(from: date) }
}
