import SwiftUI
import UIKit

/// Homeの「グループ」(v13 ⑤)。見出し(左「グループ 4 / 10」・右「+ 追加」)+ 横にならぶカード。
/// カード:幅 148・角丸 28・中の左右 12。顔 68 のまわりに、人数ぶんの点の輪(昨日投稿した人数ぶんが色つきで光る)。
/// 最後に点線の「+ 追加」カード。0個のときは「つくる」「参加する」の2つのボタン(追加シートと同じ色分け)。
/// 色は Palette だけ(白地・黒地のどちらにも、帯や四角をしかずに、そのままのせる)。順位に見えないよう、投稿数では並べない。
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
    /// 「+ 追加」→ 追加シート(つくる / 参加する)
    var onAdd: () -> Void = {}
    /// いま入った・つくったグループ(いちばん左に「ぽんと生まれる」)
    var arrivingID: UUID?
    /// 今日撮った枚数(見出しの「今日 N」。0のときは出さない)
    var shotsToday: Int = 0

    static let cardWidth: CGFloat = 148
    static let cardRadius: CGFloat = 28
    static let cardSpacing: CGFloat = 12
    static let side: CGFloat = 22
    /// 影が切れないよう、横の列の上下にとる余白(レイアウトには入れない)
    static let shadowRoom: CGFloat = 18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    @State private var ambientStart = Date()
    @State private var focusedID: String?
    @State private var tick = ScrollTickHaptics()

    private var ambient: Bool { isFrontmost && HomeMotion.ambientAllowed(reduceMotion: reduceMotion) }
    /// 10個のとき:「+ 追加」は出さない
    private var isFull: Bool { !canCreate }

    var body: some View {
        TimelineView(.animation(paused: !ambient && entranceStart == nil)) { context in
            let now = context.date
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                    .padding(.horizontal, Self.side)
                    .entrance(
                        HomeMotion.entrance(start: entranceStart, now: now, delay: 0.55, duration: 0.8, reduceMotion: reduceMotion),
                        blur: reduceMotion ? 0 : 12, dy: reduceMotion ? 0 : 12
                    )
                if summaries.isEmpty {
                    emptyButtons
                        .padding(.horizontal, Self.side)
                        .entrance(
                            HomeMotion.entrance(start: entranceStart, now: now, delay: 0.6, duration: 0.8, reduceMotion: reduceMotion),
                            blur: reduceMotion ? 0 : 12, dy: reduceMotion ? 0 : 12
                        )
                        .transition(.opacity)
                } else {
                    cardsRow(now: now)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: summaries.isEmpty)
        }
    }

    /// 左に「グループ」+「4 / 10」、右に「+ 追加」(10個のときは出さない)
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("グループ")
                .font(.system(size: 22, weight: .heavy))
                .tracking(-0.03 * 22)
                .foregroundStyle(palette.ink)
                .accessibilityAddTraits(.isHeader)
            if !summaries.isEmpty {
                Text("\(summaries.count) / \(GroupMembershipPolicy.maxGroupsPerUser)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.groupAdd.note)
                    .accessibilityLabel("\(summaries.count)個、最大\(GroupMembershipPolicy.maxGroupsPerUser)個")
            }
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
            Spacer(minLength: 0)
            if !summaries.isEmpty && !isFull {
                Button {
                    LayerHaptics.light()
                    onAdd()
                } label: {
                    Text("+ 追加")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.94))
                .padding(.trailing, -12)
                .accessibilityLabel("グループを追加")
            }
        }
        .frame(minHeight: 30)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    /// 横にならぶカード。影が切れないよう .scrollClipDisabled() と、上下の余白をたっぷり
    private func cardsRow(now: Date) -> some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                        card(summary, index: index, now: now)
                    }
                    if !isFull {
                        addCard(now: now)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, Self.side)
                .padding(.vertical, Self.shadowRoom)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedID, anchor: .leading)
            .padding(.vertical, -Self.shadowRoom)
            .onChange(of: focusedID) { _, id in tick.step(id) }
            .onChange(of: arrivingID) { _, id in
                // 新しいグループは、いちばん左に生まれる。列が右へ進んでいたら、左へもどす
                guard let id else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { reader.scrollTo(id.uuidString, anchor: .leading) }
            }
        }
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8), value: summaries.map(\.id))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("グループ、\(summaries.count)個")
        // 列の中で始めた横の動きは、Profileを開かないための領域として残す
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HomeNoSwipeRegionKey.self, value: [proxy.frame(in: .global)])
        })
    }

    private func card(_ summary: GroupSummary, index: Int, now: Date) -> some View {
        HomeGroupCard(
            summary: summary,
            index: index + 1,
            now: now,
            ambientStart: ambientStart,
            ambient: ambient,
            isFrontmost: isFrontmost,
            entranceStart: entranceStart,
            isArriving: summary.id == arrivingID,
            onTap: {
                LayerHaptics.light()
                onSelect(summary.id)
            }
        )
        .id(summary.id.uuidString)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    private func addCard(now: Date) -> some View {
        let enter = HomeMotion.entrance(start: entranceStart, now: now, delay: 0.65 + Double(summaries.count) * 0.085, duration: 0.8, reduceMotion: reduceMotion)
        return AddGroupCard(onTap: {
            LayerHaptics.light()
            onAdd()
        })
        .id("add")
        .entrance(enter, dy: reduceMotion ? 0 : 18, scaleFrom: reduceMotion ? 1 : 0.88)
    }

    /// グループが0個のとき:「つくる」(主役)・「参加する」(脇役)。追加シートと同じ色分け
    private var emptyButtons: some View {
        let colors = palette.groupAdd
        return HStack(spacing: 10) {
            Button {
                LayerHaptics.light()
                onCreate()
            } label: {
                emptyCard(title: "つくる", note: "4〜8人のグループ", titleColor: colors.primaryText, noteColor: colors.primaryNote) {
                    Circle()
                        .fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(colors.plus))
                }
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(colors.primaryBg))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
            .accessibilityLabel("グループをつくる。4〜8人のグループ")
            Button {
                LayerHaptics.light()
                onJoin()
            } label: {
                emptyCard(title: "参加する", note: "合言葉・QR・リンク", titleColor: colors.secondaryText, noteColor: colors.note) {
                    Circle()
                        .fill(colors.secondaryIconBg)
                        .overlay(Image(systemName: "qrcode").font(.system(size: 16, weight: .medium)).foregroundStyle(colors.secondaryIcon))
                }
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(colors.secondaryBg))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(colors.secondaryLine, lineWidth: 1.5))
            }
            .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.15))
            .accessibilityLabel("グループに参加する。合言葉・QR・リンク")
        }
    }

    private func emptyCard<Icon: View>(title: String, note: String, titleColor: Color, noteColor: Color, @ViewBuilder icon: () -> Icon) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            icon().frame(width: 38, height: 38)
            Spacer(minLength: 0)
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(titleColor)
            Text(note).font(.system(size: 11.5)).foregroundStyle(noteColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - 点線の「+ 追加」カード(列の最後)

/// 点線のふち + 夕やけの丸に白い「+」+「追加」。押すと追加シート。
private struct AddGroupCard: View {
    let onTap: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "plus").font(.system(size: 24, weight: .bold)).foregroundStyle(palette.groupAdd.plus))
                    .frame(width: 68, height: 68)
                    .frame(width: HomeGroupCard.ringBox, height: HomeGroupCard.ringBox)
                Text("追加")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                Text(" ")
                    .font(.system(size: 10.5, design: .monospaced))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(width: HomeGroupStrip.cardWidth)
            .overlay(
                RoundedRectangle(cornerRadius: HomeGroupStrip.cardRadius, style: .continuous)
                    .strokeBorder(palette.groupAdd.secondaryLine, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            )
            .contentShape(RoundedRectangle(cornerRadius: HomeGroupStrip.cardRadius, style: .continuous))
        }
        .buttonStyle(PressScaleStyle(scale: 0.95, duration: 0.2))
        .accessibilityLabel("グループを追加")
    }
}

// MARK: - 1つのグループ(カード)

private struct HomeGroupCard: View {
    let summary: GroupSummary
    let index: Int
    let now: Date
    let ambientStart: Date
    let ambient: Bool
    let isFrontmost: Bool
    let entranceStart: Date?
    var isArriving = false
    let onTap: () -> Void

    /// 顔(68)と点の輪が入る箱
    static let ringBox: CGFloat = 84

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.palette) private var palette
    /// 「誰かが投稿した」演出の開始時刻と、ふえた点の番号
    @State private var popStart: Date?
    @State private var popIndex = 0
    /// 生まれたグループが「ぽんと入る」:0.5倍 → 1.14倍 → 1倍(1秒)
    @State private var arriveScale: CGFloat = 1
    @State private var arriveOffset: CGFloat = 0

    private var auraColors: [Color] { GroupRingMath.auraPalettes[summary.auraIndex % GroupRingMath.auraPalettes.count] }

    /// 面:グループの色(2番目)を 22% だけまぜた、うすい面
    private var face: Color { GroupCardColors.surface(base: palette.bg, tint: auraColors[1]) }

    var body: some View {
        let enter = HomeMotion.entrance(start: entranceStart, now: now, delay: 0.65 + Double(index) * 0.085, duration: 0.8, reduceMotion: reduceMotion)
        Button(action: onTap) { label }
            .buttonStyle(PressScaleStyle(scale: 0.95, duration: 0.2))
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
                // Homeが前面のときだけ、光がふえる演出。背面では数だけ最新になる
                guard new > old, isFrontmost, !reduceMotion else { return }
                popIndex = GroupRingMath.dots(memberCount: summary.memberCount, posted: new).lit - 1
                popStart = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { popStart = nil }
            }
    }

    private var label: some View {
        VStack(spacing: 10) {
            ZStack {
                GroupFace(iconData: summary.iconData, initial: summary.initial, auraIndex: summary.auraIndex, diameter: 68, mosaic: summary.faceMosaic, mosaicKey: summary.faceMosaicKey)
                GroupLightRing(
                    memberCount: summary.memberCount,
                    posted: summary.postedYesterday,
                    diameter: 80,
                    rotation: rotation,
                    now: now,
                    twinkle: ambient,
                    entranceStart: reduceMotion ? nil : entranceStart,
                    popStart: popStart,
                    popIndex: popIndex,
                    litColor: auraColors[0],
                    restColor: palette.ink.opacity(palette.isNight ? 0.28 : 0.22),
                    trackColor: palette.ink.opacity(0.08)
                )
            }
            .frame(width: Self.ringBox, height: Self.ringBox)
            VStack(spacing: 3) {
                Text(summary.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let preview = summary.chatPreview, summary.inviting == nil {
                    // v23:最後の メッセージ
                    Text(preview)
                        .font(.system(size: 10.5, weight: summary.chatUnread ? .bold : .regular))
                        .foregroundStyle(summary.chatUnread ? palette.ink : GroupCardColors.count(night: palette.isNight))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else if let inviting = summary.invitingText {
                    // v22:つくった ばかり・承認まち(「招待中」の ピル)
                    Text(inviting)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(auraColors[1].opacity(palette.isNight ? 0.4 : 0.3)))
                } else {
                Text("\(summary.postedYesterday) / \(summary.memberCount)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(GroupCardColors.count(night: palette.isNight))
                    .contentTransition(.numericText(countsDown: false))
                    .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.5), value: summary.postedYesterday)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: HomeGroupStrip.cardWidth)
        .background(
            RoundedRectangle(cornerRadius: HomeGroupStrip.cardRadius, style: .continuous)
                .fill(face)
                .shadow(color: auraColors[1].opacity(palette.isNight ? 0.28 : 0.22), radius: 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HomeGroupStrip.cardRadius, style: .continuous)
                .strokeBorder(auraColors[1].opacity(palette.isNight ? 0.45 : 0.35), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: HomeGroupStrip.cardRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            // v23:新しい メッセージ(数字は 出さない)
            if summary.chatUnread {
                Circle().fill(Color(hex: "FF6A1A")).frame(width: 9, height: 9).padding(12)
                    .accessibilityLabel("新しい メッセージ")
            }
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

/// カードの色(テストでコントラストを確かめる)
enum GroupCardColors {
    /// 面:base にグループの色を 22% まぜる
    static func surface(base: Color, tint: Color, amount: Double = 0.22) -> Color {
        let ua = UIColor(base), ub = UIColor(tint)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(amount)
        return Color(.sRGB, red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k), blue: Double(b1 + (b2 - b1) * k))
    }

    /// 「3 / 8」の色(昼 #5F5F66 / 夜 #B4B4BC)
    static func count(night: Bool) -> Color { GroupAddColors(isNight: night).note }
}

// MARK: - 部品(Homeの列とグループのシートで共有)

/// グループの顔。写真があれば写真、なければ3色のオーラ+頭文字。上に光沢。
struct GroupFace: View {
    let iconData: Data?
    let initial: String
    let auraIndex: Int
    let diameter: CGFloat
    /// 顔が「みんなの写真」:今日の1枚のモザイク(なければ色)
    var mosaic: Data? = nil
    var mosaicKey = ""

    var body: some View {
        ZStack {
            if let iconData, let image = UIImage(data: iconData) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else if let mosaic {
                MosaicView(tiny: mosaic, key: mosaicKey)
                Text(initial)
                    .font(.system(size: diameter * 19 / 46, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
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
    /// 光る点の色(Home のカードはグループの色。nil なら白)
    var litColor: Color = .white
    /// 光っていない点・下地の線の色(白地のときは濃い色にする)
    var restColor: Color = .white.opacity(0.24)
    var trackColor: Color = .white.opacity(0.08)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = diameter / 2 * (28.8 / 31)
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(trackColor), lineWidth: 1
            )
            let (total, lit) = GroupRingMath.dots(memberCount: memberCount, posted: posted)
            for i in 0..<total {
                let angle = GroupRingMath.angle(index: i, total: total) + rotation
                let p = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                if i < lit {
                    var r: CGFloat = 2.6
                    var opacity = 0.95
                    var color = litColor
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
                        color = Self.mix(Color(hex: "FFB26E"), litColor, grow)
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
                    context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(restColor))
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

/// 押している間、縮む。離すとバネでもどる(v14:spring 0.35 / 0.6)
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var duration: Double = 0.15

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(configuration.isPressed ? .easeOut(duration: duration) : .spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// ぷにっと押す(v14 2-B ①・Bump 風):押すと縮んで soft。離した瞬間、横 1.07 / 縦 0.9 → 逆 → 元(0.55秒のバネ)。
/// 視差を減らすときは、弾まない(縮むだけ)。
struct SquishButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        SquishBody(configuration: configuration, pressedScale: pressedScale)
    }
}

/// ぷにっとの形(テストで確かめる):離してからの時刻 t(秒)→ 横・縦の倍率
enum SquishCurve {
    static let duration: Double = 0.55
    static let keys: [(t: Double, x: CGFloat, y: CGFloat)] = [(0, 1, 1), (0.16, 1.07, 0.9), (0.34, 0.97, 1.05), (0.55, 1, 1)]
}

private struct SquishBody: View {
    let configuration: ButtonStyleConfiguration
    let pressedScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = 0

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(configuration.isPressed ? .easeOut(duration: 0.12) : .spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
            .keyframeAnimator(initialValue: CGSize(width: 1, height: 1), trigger: bounce) { content, value in
                content.scaleEffect(x: value.width, y: value.height)
            } keyframes: { _ in
                KeyframeTrack(\.width) {
                    SpringKeyframe(SquishCurve.keys[1].x, duration: 0.16)
                    SpringKeyframe(SquishCurve.keys[2].x, duration: 0.18)
                    SpringKeyframe(1, duration: 0.21)
                }
                KeyframeTrack(\.height) {
                    SpringKeyframe(SquishCurve.keys[1].y, duration: 0.16)
                    SpringKeyframe(SquishCurve.keys[2].y, duration: 0.18)
                    SpringKeyframe(1, duration: 0.21)
                }
            }
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    Haptics.play(.soft)
                } else if !reduceMotion {
                    bounce += 1
                }
            }
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

// MARK: - 追加シート(つくる / 参加する)

/// 「追加」から下に出るシート(v13 ①)。見出し + 2つのボタン + 注意書き1行。
/// 主役は「つくる」(黒い面、夜は白い面)、脇役は「参加する」(白い面 + ふち)。色は Palette.groupAdd だけを使う。
/// 10個のときは2つとも薄く(0.4)して押せない。
struct GroupAddSheet: View {
    let groupCount: Int
    let onJoin: () -> Void
    let onCreate: () -> Void

    @Environment(\.palette) private var palette

    private var colors: GroupAddColors { palette.groupAdd }
    private var isFull: Bool { groupCount >= GroupMembershipPolicy.maxGroupsPerUser }

    /// 「あと◯個、入れます」(10 − いまの数)
    static func remainingText(groupCount: Int) -> String {
        let max = GroupMembershipPolicy.maxGroupsPerUser
        return groupCount >= max
            ? "\(max)個まで入れます。どれかを退出すると、追加できます。"
            : "あと\(max - groupCount)個、入れます"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("グループを追加")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(colors.title)
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 16)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 10) {
                createButton
                joinButton
            }
            .padding(.horizontal, 16)

            Text(Self.remainingText(groupCount: groupCount))
                .font(.system(size: 12.5))
                .foregroundStyle(colors.note)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.sheet)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// つくる(主役・1番目):左に夕やけの丸と白い「+」
    private var createButton: some View {
        Button(action: onCreate) {
            row(title: "つくる", note: "4〜8人のグループ", titleColor: colors.primaryText, noteColor: colors.primaryNote, chevron: colors.primaryText) {
                Circle()
                    .fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "plus").font(.system(size: 19, weight: .bold)).foregroundStyle(colors.plus))
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(colors.primaryBg))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.12))
        .disabled(isFull)
        .opacity(isFull ? 0.4 : 1)
        .accessibilityHint("4〜8人のグループを、つくります")
    }

    /// 参加する(脇役・2番目):白い面に 1.5pt のふち。左の丸は うすい灰色に QR
    private var joinButton: some View {
        Button(action: onJoin) {
            row(title: "参加する", note: "合言葉・QR・リンクで入る", titleColor: colors.secondaryText, noteColor: colors.note, chevron: colors.note) {
                Circle()
                    .fill(colors.secondaryIconBg)
                    .overlay(Image(systemName: "qrcode").font(.system(size: 18, weight: .medium)).foregroundStyle(colors.secondaryIcon))
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(colors.secondaryBg))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(colors.secondaryLine, lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle(scale: 0.97, duration: 0.12))
        .disabled(isFull)
        .opacity(isFull ? 0.4 : 1)
        .accessibilityHint("合言葉・QR・リンクで入ります")
    }

    private func row<Icon: View>(title: String, note: String, titleColor: Color, noteColor: Color, chevron: Color, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 14) {
            icon().frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(titleColor)
                Text(note)
                    .font(.system(size: 12.5))
                    .foregroundStyle(noteColor)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(chevron)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

