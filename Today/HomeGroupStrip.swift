import SwiftUI
import UIKit

/// Homeの「グループ」の列(v4)。どのグループに、昨日の光が何個あるかを、ひと目で。
/// 顔・リング(点 = メンバー、光る点 = 昨日投稿した人数)・名前・「3 / 8」。
/// だれが投稿したかは出さない。順位に見えないよう、投稿数では並べない。触覚なし。
struct HomeGroupStrip: View {
    let summaries: [GroupSummary]
    let canCreate: Bool
    /// Homeが前面にあるか(常に動くもの・投稿の演出は、前面のときだけ)
    let isFrontmost: Bool
    /// 入場の開始時刻(状態が切りかわったときだけ。nilなら入場しない)
    let entranceStart: Date?
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void
    /// 参加する(QR・合言葉・リンク)
    var onJoin: () -> Void = {}
    /// 「追加」タイル(列の先頭)を押した → 追加シート(参加する / つくる)
    var onAdd: () -> Void = {}
    /// いま入ったグループ(先頭に「ぽんと入る」)
    var arrivingID: UUID?
    /// 今日撮った枚数(見出しの「今日 N」。0のときは出さない)
    var shotsToday: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambientStart = Date()

    private var ambient: Bool { isFrontmost && HomeMotion.ambientAllowed(reduceMotion: reduceMotion) }

    var body: some View {
        TimelineView(.animation(paused: !ambient && entranceStart == nil)) { context in
            let now = context.date
            ZStack(alignment: .topLeading) {
                if summaries.isEmpty {
                    // 0個:見出しと列のかわりに、大きな2つのカード
                    emptyCards
                        .padding(.horizontal, 22)
                        .padding(.top, 44)
                        .entrance(
                            HomeMotion.entrance(start: entranceStart, now: now, delay: 0.55, duration: 0.8, reduceMotion: reduceMotion),
                            blur: reduceMotion ? 0 : 12, dy: reduceMotion ? 0 : 12
                        )
                        .transition(.opacity)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        headerRow
                            .padding(.horizontal, 22)
                            .entrance(
                                HomeMotion.entrance(start: entranceStart, now: now, delay: 0.55, duration: 0.8, reduceMotion: reduceMotion),
                                blur: reduceMotion ? 0 : 12, dy: reduceMotion ? 0 : 12
                            )
                        groupRow(now: now)
                    }
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: summaries.isEmpty)
        }
    }

    /// グループの区画(数による形)。1個=横のタイル、2〜3個=等しい幅のたて並び、4個以上=3つ+「ほか」。
    /// 横スクロールはやめて、常に画面の幅におさめる(区画の高さは数によってほぼ変わらない)。
    private func groupRow(now: Date) -> some View {
        let shown = summaries.count >= 4 ? Array(summaries.prefix(3)) : summaries
        let overflow = summaries.count - shown.count
        let isRow = summaries.count == 1
        return HStack(alignment: .top, spacing: 12) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, summary in
                GroupTile(
                    summary: summary,
                    index: index + 1,
                    now: now,
                    ambientStart: ambientStart,
                    ambient: ambient,
                    isFrontmost: isFrontmost,
                    entranceStart: entranceStart,
                    isArriving: summary.id == arrivingID,
                    style: isRow ? .row : .column,
                    onTap: { onSelect(summary.id) }
                )
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
            if overflow > 0 {
                OverflowGroupTile(count: overflow)
            }
            // 追加:4個以上では出さない(追加は大きな画面で)
            if summaries.count < 4 {
                AddGroupTile(isFull: isFull, onTap: onAdd)
                    .entrance(
                        HomeMotion.entrance(start: entranceStart, now: now, delay: 0.65, duration: 0.8, reduceMotion: reduceMotion),
                        dy: reduceMotion ? 0 : 18, scaleFrom: reduceMotion ? 1 : 0.88
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8), value: summaries.map(\.id))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("グループ、\(summaries.count)個")
        // 区画の中で始めた横の動きは、Profileを開かないための領域として残す
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HomeNoSwipeRegionKey.self, value: [proxy.frame(in: .global)])
        })
    }

    /// 10個のとき:追加タイルを薄くする(押すと、シートで理由が読める)
    private var isFull: Bool { !canCreate }

    /// 左に「グループ」+「4 / 10」だけ(右には何も置かない)
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("グループ")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color(hex: "D1D1D6"))
            Text("\(summaries.count) / \(GroupMembershipPolicy.maxGroupsPerUser)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(hex: "6B6B70"))
                .accessibilityLabel("\(summaries.count)個、最大\(GroupMembershipPolicy.maxGroupsPerUser)個")
            Spacer(minLength: 0)
            if shotsToday > 0 {
                // 今日の撮った枚数(事実だけ。競わせない)
                Text("今日 \(shotsToday)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "1A0F08"))
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(Capsule().fill(Color(hex: "FF9E5E")))
                    .accessibilityLabel("今日、\(shotsToday)こま撮りました")
            }
        }
        .accessibilityElement(children: .combine)
        .frame(height: 30)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// グループが0個のとき:左「参加する」/ 右「つくる」(シートを通さず、最初の一歩を1タップ短く)
    private var emptyCards: some View {
        HStack(spacing: 10) {
            Button(action: onJoin) {
                card(icon: "qrcode", title: "参加する", note: "合言葉・QR・リンク", primary: false)
            }
            .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
            .accessibilityLabel("グループに参加する。合言葉・QR・リンク")
            Button(action: onCreate) {
                card(icon: "plus", title: "つくる", note: "4〜8人のグループ", primary: true)
            }
            .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
            .accessibilityLabel("グループをつくる。4〜8人のグループ")
        }
    }

    private func card(icon: String, title: String, note: String, primary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 22, weight: .medium))
            Spacer(minLength: 0)
            Text(title).font(.system(size: 16, weight: .bold))
            Text(note).font(.system(size: 11)).opacity(0.6)
        }
        .foregroundStyle(primary ? Color.black : Color.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 84)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(primary
                      ? AnyShapeStyle(Color.white)
                      : AnyShapeStyle(LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)))
        }
        .overlay {
            if !primary {
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
        }
    }
}

// MARK: - 追加タイル(列の先頭)

/// 細い点線の円 +「＋」(塗りなし)。下に「追加」。人数の行は高さをそろえるため透明で置く。
/// 10個のときは薄く(0.45)するが、押せる(シートで理由を見せる)。触覚なし。
private struct AddGroupTile: View {
    let isFull: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 62, height: 62)

                VStack(spacing: 2) {
                    Text("追加")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                    Text("0 / 0")
                        .font(.system(size: 9.5, design: .monospaced))
                        .hidden()
                }
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            .frame(width: 66)
            .contentShape(Rectangle())
            .opacity(isFull ? 0.45 : 1)
        }
        .buttonStyle(PressScaleStyle(scale: 0.93, duration: 0.25))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("グループを追加")
        .accessibilityValue(isFull ? "10個まで入っています" : "")
        .accessibilityAddTraits(.isButton)
    }
}

/// 4個以上のとき、残りのグループの数(「ほか」)。大きな画面を開く入口は、その画面と一緒に作る(いまは押せない)。
private struct OverflowGroupTile: View {
    let count: Int

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                Text("+\(count)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 62, height: 62)
            Text("ほか")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ほか\(count)個のグループ")
    }
}

// MARK: - 1つのグループ

private struct GroupTile: View {
    let summary: GroupSummary
    let index: Int
    let now: Date
    let ambientStart: Date
    let ambient: Bool
    let isFrontmost: Bool
    let entranceStart: Date?
    var isArriving = false
    var style: Style = .column
    let onTap: () -> Void

    enum Style {
        /// 縦(顔の下に名前)。2〜3個のとき。幅は同じ幅に広がる
        case column
        /// 横(顔の右に名前と人数)。1個のとき
        case row
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 「誰かが投稿した」演出の開始時刻と、ふえた点の番号
    @State private var popStart: Date?
    @State private var popIndex = 0
    /// 入ったグループが「ぽんと入る」:0.5倍・上から30pt → 1.14倍 → 1倍(1秒)
    @State private var arriveScale: CGFloat = 1
    @State private var arriveOffset: CGFloat = 0

    var body: some View {
        let enter = HomeMotion.entrance(start: entranceStart, now: now, delay: 0.65 + Double(index) * 0.085, duration: 0.8, reduceMotion: reduceMotion)
        Button(action: onTap) {
            tileLabel
        }
        .buttonStyle(PressScaleStyle(scale: 0.93, duration: 0.25))
        .entrance(enter, dy: reduceMotion ? 0 : 18, scaleFrom: reduceMotion ? 1 : 0.88)
        .scaleEffect(arriveScale)
        .offset(y: arriveOffset)
        .onAppear { if isArriving { arrive() } }
        .onChange(of: isArriving) { _, arriving in if arriving { arrive() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.spokenSummary)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("グループをひらきます")
        .onChange(of: summary.postedYesterday) { old, new in
            // Homeが前面のときだけ、光がふえる演出(触覚なし)。背面では数だけ最新になる
            guard new > old, isFrontmost, !reduceMotion else { return }
            popIndex = GroupRingMath.dots(memberCount: summary.memberCount, posted: new).lit - 1
            popStart = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { popStart = nil }
        }
    }

    /// 顔とリング、名前と人数。行(1個)は横、列(2個以上)は縦。列は等しい幅に広がる
    @ViewBuilder
    private var tileLabel: some View {
        let isRow = style == .row
        let ring: CGFloat = isRow ? 54 : 62
        let face: CGFloat = isRow ? 40 : 46
        let ringView = ZStack {
            GroupFace(iconData: summary.iconData, initial: summary.initial, auraIndex: summary.auraIndex, diameter: face)
            GroupLightRing(
                memberCount: summary.memberCount,
                posted: summary.postedYesterday,
                diameter: ring,
                rotation: rotation,
                now: now,
                twinkle: ambient,
                entranceStart: reduceMotion ? nil : entranceStart,
                popStart: popStart,
                popIndex: popIndex
            )
        }
        .frame(width: 62, height: 62)
        let names = VStack(alignment: isRow ? .leading : .center, spacing: 2) {
            Text(summary.name)
                .font(.system(size: isRow ? 15 : 11.5, weight: isRow ? .bold : .medium))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: isRow ? nil : .infinity)
            Text(summary.countText)
                .font(.system(size: isRow ? 10 : 9.5, design: .monospaced))
                .tracking(0.08 * 9.5)
                .monospacedDigit()
                .foregroundStyle(summary.allPosted ? Color(hex: "FFB26E") : Color(hex: "8E8E93"))
                .contentTransition(.numericText(countsDown: false))
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5), value: summary.postedYesterday)
        }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        if isRow {
            HStack(spacing: 14) {
                ringView
                names
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        } else {
            VStack(spacing: 7) {
                ringView
                names
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }

    private func arrive() {
        guard !reduceMotion else { return }
        arriveScale = 0.5
        arriveOffset = -30
        withAnimation(.easeOut(duration: 0.55)) {
            arriveScale = 1.14
            arriveOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeInOut(duration: 0.45)) { arriveScale = 1 }
        }
    }

    /// ゆっくり回る(1周 90 + 番号×23 秒。偶数/奇数で向きを逆に)
    private var rotation: Double {
        guard ambient else { return 0 }
        let period = 90 + Double(index) * 23
        let direction: Double = index.isMultiple(of: 2) ? 1 : -1
        return direction * now.timeIntervalSince(ambientStart) / period * 2 * .pi
    }
}

// MARK: - 部品(Homeの列とグループのシートで共有)

/// グループの顔。写真があれば写真、なければ3色のオーラ+頭文字。上に光沢。
struct GroupFace: View {
    let iconData: Data?
    let initial: String
    let auraIndex: Int
    let diameter: CGFloat

    var body: some View {
        ZStack {
            if let iconData, let image = UIImage(data: iconData) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                aura
                Text(initial)
                    .font(.system(size: diameter * 19 / 46, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            // 光沢(左上から白の放射状)
            RadialGradient(colors: [.white.opacity(0.45), .clear], center: UnitPoint(x: 0.28, y: 0.2), startRadius: 0, endRadius: diameter * 0.55)
                .blendMode(.screen)
                .opacity(0.6)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var aura: some View {
        let colors = GroupRingMath.auraPalettes[auraIndex % GroupRingMath.auraPalettes.count]
        return ZStack {
            colors[2]
            Circle().fill(colors[0]).frame(width: diameter * 0.8).offset(x: -diameter * 0.18, y: -diameter * 0.16).blur(radius: diameter * 0.18)
            Circle().fill(colors[1]).frame(width: diameter * 0.7).offset(x: diameter * 0.22, y: diameter * 0.18).blur(radius: diameter * 0.18)
        }
    }
}

/// リング:うすい下地の線の上に、メンバー数ぶんの点(最大12)。光る点 = 昨日投稿した人数。
/// 点は12時の位置から時計まわりに、光っているものから先にならぶ。
struct GroupLightRing: View {
    let memberCount: Int
    let posted: Int
    let diameter: CGFloat
    var rotation: Double = 0
    var now = Date()
    /// またたき(不透明度 0.7 ↔ 1、3.4秒、点ごとに 0.37秒ずつずらす)
    var twinkle = false
    /// 入場:光っている点が、ぽっと現れる(1.1秒 + 点の番号×50ms、0.5秒)
    var entranceStart: Date?
    /// 投稿の演出:新しい点がオレンジで現れ(0.2 → 2.7 → 1倍、0.9秒で白へ)、輪が広がる(1 → 6倍、1.2秒)
    var popStart: Date?
    var popIndex = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = diameter / 2 * (28.8 / 31)
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(0.08)), lineWidth: 1
            )
            let (total, lit) = GroupRingMath.dots(memberCount: memberCount, posted: posted)
            for i in 0..<total {
                let angle = GroupRingMath.angle(index: i, total: total) + rotation
                let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if i < lit {
                    var r: CGFloat = 2.6
                    var opacity = 0.95
                    var color = Color.white
                    if twinkle {
                        let phase = now.timeIntervalSinceReferenceDate / 3.4 * 2 * .pi + Double(i) * 0.37 / 3.4 * 2 * .pi
                        opacity *= 0.85 + 0.15 * sin(phase)
                    }
                    if let entranceStart {
                        let u = min(1, max(0, (now.timeIntervalSince(entranceStart) - 1.1 - Double(i) * 0.05) / 0.5))
                        r *= CGFloat(Self.popScale(u))
                        opacity *= min(1, u * 2)
                    }
                    if let popStart, i == popIndex {
                        let t = now.timeIntervalSince(popStart)
                        let grow = min(1, max(0, t / 0.9))
                        r *= CGFloat(Self.burstScale(grow))
                        color = Self.mix(Color(hex: "FFB26E"), .white, grow)
                        let ringU = min(1, max(0, t / 1.2))
                        if ringU < 1 {
                            let rr = 2.6 * (1 + 5 * ringU)
                            context.stroke(
                                Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                                with: .color(Color(hex: "FFB26E").opacity(0.8 * (1 - ringU))), lineWidth: 1.2
                            )
                        }
                    }
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(opacity)))
                } else {
                    let r: CGFloat = 1.6
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.24)))
                }
            }
        }
        .frame(width: diameter + 24, height: diameter + 24)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0 → 少しこえて → 1(ぽっと)
    private static func popScale(_ u: Double) -> Double {
        guard u > 0 else { return 0 }
        return u < 0.6 ? 1.25 * (u / 0.6) : 1.25 - 0.25 * ((u - 0.6) / 0.4)
    }

    /// 0.2倍 → 2.7倍 → 1倍
    private static func burstScale(_ u: Double) -> Double {
        u < 0.35 ? 0.2 + 2.5 * (u / 0.35) : 2.7 - 1.7 * HomeMotion.ease((u - 0.35) / 0.65)
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(t)
        return Color(red: r1 + (r2 - r1) * k, green: g1 + (g2 - g1) * k, blue: b1 + (b2 - b1) * k)
    }
}

/// 押している間、縮む
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var duration: Double = 0.15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: duration), value: configuration.isPressed)
    }
}

/// グループの点の輪(作成フローで使う)。8つの点を、縁から内側に置く。
struct GroupDotRing: View {
    let photo: UIImage?
    let initial: String
    let memberCount: Int
    let diameter: CGFloat
    let photoDiameter: CGFloat
    var dotSize: CGFloat = 5
    /// 参加ずみの点の色(nilなら白)。作成フローの「できた」だけ、写真の色(オレンジ・青・黄)で光る。
    var litColor: ((Int) -> Color)?
    var slotCount = GroupMembershipPolicy.maxMembersPerGroup

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.04))
            Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1)
            ForEach(0..<slotCount, id: \.self) { index in
                let angle = -Double.pi / 2 + Double(index) / Double(slotCount) * 2 * .pi
                let radius = diameter / 2 - max(6, diameter * 0.1)
                let isLit = index < memberCount
                let color = isLit ? (litColor?(index) ?? .white) : .white.opacity(0.16)
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: isLit ? color.opacity(0.8) : .clear, radius: dotSize)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                    .animation(.easeInOut(duration: 0.5), value: memberCount)
            }
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: photoDiameter, height: photoDiameter)
                    .clipShape(Circle())
            } else {
                Text(initial)
                    .font(.system(size: photoDiameter * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

// MARK: - 追加シート(参加する / つくる)

/// 「追加」タイルから下に出るシート。見出し + 2行 + 注意書き1行だけ。
/// 10個のときは2行とも薄く(0.4)して押せない。選んだときだけ、ごく軽く1回(えらぶ)。
struct GroupAddSheet: View {
    let groupCount: Int
    let onJoin: () -> Void
    let onCreate: () -> Void

    private var isFull: Bool { groupCount >= GroupMembershipPolicy.maxGroupsPerUser }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("グループを追加")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 14)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 4) {
                row(icon: "qrcode", title: "参加する", note: "合言葉・QR・リンクで入る", action: onJoin)
                row(icon: "plus", title: "つくる", note: "4〜8人のグループ", action: onCreate)
            }
            .padding(.horizontal, 12)

            Text(isFull
                 ? "\(GroupMembershipPolicy.maxGroupsPerUser)個まで入れます。どれかを退出すると、追加できます。"
                 : "あと\(GroupMembershipPolicy.maxGroupsPerUser - groupCount)個、入れます")
                .font(.system(size: 12.5))
                .foregroundStyle(Color(hex: "8E8E93"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func row(icon: String, title: String, note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(note)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color(hex: "BCBBC0"))
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(SheetRowStyle())
        .disabled(isFull)
        .opacity(isFull ? 0.4 : 1)
        .accessibilityHint(note)
    }
}

/// 押している間だけ、行の背景を薄く光らせる
private struct SheetRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
