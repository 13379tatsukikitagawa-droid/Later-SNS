import SwiftUI
import UIKit

// 最初の1枚の光(撮った瞬間)と、0 グループのときの GROUP 画面(若い人向けの空の画面)。

// MARK: - 最初の1枚の光

/// 月の中心から画面いっぱいに広がる光(白 → ピンク)。progress 0〜1。
/// 円のふちは、最後の色を .clear にして、四角いふちが出ないようにしている。
struct FirstShotLight: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let reach = hypot(proxy.size.width, proxy.size.height) * 2.4
            let centerY = proxy.size.height - MoonLayout.visibleHeight / 2
            let pink = Color(hex: "FF5FA2")
            ZStack {
                Circle().fill(RadialGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.72),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    center: .center, startRadius: 0, endRadius: 50
                ))
                Circle().fill(RadialGradient(
                    stops: [
                        .init(color: pink, location: 0),
                        .init(color: pink, location: 0.72),
                        .init(color: pink.opacity(0), location: 1),
                    ],
                    center: .center, startRadius: 0, endRadius: 50
                ))
                .opacity(Double(progress))
            }
            .frame(width: 100, height: 100)
            .scaleEffect(max(0.001, progress) * reach / 100)
            .position(x: proxy.size.width / 2, y: centerY)
        }
    }
}

// MARK: - 0 グループの GROUP 画面

enum GroupEmptyYouth {
    static let seatColors = ["FF5FA2", "55D6FF", "C8FF5A", "9B7BFF", "FFB277", "FF7A59", "5FF0C8"]
    static let rainbow = ["FF5FA2", "FFB277", "C8FF5A", "55D6FF", "9B7BFF"]
    static let pink = Color(hex: "FF5FA2")
    static let ink = Color(hex: "2A1A12")

    /// 楕円の横の半径(画面が狭いときは縮める。SE の 375pt でも収まる)
    static func horizontalRadius(screenWidth: CGFloat) -> CGFloat {
        max(60, min(128, (screenWidth - 28) / 2 - 30))
    }

    /// 7つの席の位置(中心からのずれ)。真上から時計まわりに 360/7 度ずつ
    static func seatOffset(index: Int, rx: CGFloat) -> CGPoint {
        let ry = rx * 86 / 128
        let angle = (-90 + Double(index) * 360 / 7) * .pi / 180
        return CGPoint(x: rx * CGFloat(cos(angle)), y: ry * CGFloat(sin(angle)))
    }

    struct Sticker: Identifiable {
        let id: String
        let word: String
        let color: String
        let degrees: Double
        let alignment: Alignment
    }

    static let stickers: [Sticker] = [
        Sticker(id: "after", word: "放課後", color: "FF5FA2", degrees: -8, alignment: .topLeading),
        Sticker(id: "friends", word: "いつメン", color: "C8FF5A", degrees: 7, alignment: .topTrailing),
        Sticker(id: "club", word: "部活", color: "8FDBFF", degrees: 6, alignment: .bottomLeading),
        Sticker(id: "way", word: "帰り道", color: "FFB277", degrees: -6, alignment: .bottomTrailing),
    ]
}

struct GroupEmptyYouthView: View {
    let userName: String
    let isActive: Bool
    /// つくる(ステッカーなら、その言葉を名前に入れて)
    let onCreate: (String?) -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            GroupEmptyHero(userName: userName, isActive: isActive, onCreate: onCreate)
            headline
            Text("4〜8人のグループ。1枚撮ると、みんなの写真が届きます。")
                .font(.system(size: 12.5))
                .foregroundStyle(ChicColor.sub)
                .multilineTextAlignment(.center)
            buttons
            GroupSampleCard()
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var headline: some View {
        VStack(spacing: 7) {
            Text("なかまと、")
            HStack(spacing: 0) {
                Text("昨日")
                    .background(alignment: .bottom) {
                        GroupEmptyYouth.pink.opacity(0.7)
                            .frame(height: 29 * 1.25 * 0.34)
                    }
                Text("を見せあおう。")
            }
        }
        .font(.system(size: 29, weight: .heavy))
        .foregroundStyle(ChicColor.ink)
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("なかまと、昨日を見せあおう。")
        .accessibilityAddTraits(.isHeader)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                TapConsumption.mark()
                onCreate(nil)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                    Text("つくる").font(.system(size: 16, weight: .heavy))
                }
            }
            .buttonStyle(CreatePillStyle())
            .accessibilityLabel("グループをつくる")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                TapConsumption.mark()
                onJoin()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode").font(.system(size: 16, weight: .semibold))
                    Text("参加する").font(.system(size: 16, weight: .bold))
                }
            }
            .buttonStyle(JoinPillStyle())
            .accessibilityLabel("グループに参加する")
        }
        .padding(.trailing, 4)
    }
}

// MARK: ボタンの形

private struct CreatePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 27, style: .continuous).fill(ChicColor.ink))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct JoinPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ChicColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 27, style: .continuous).fill(ChicColor.fill))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: ヒーロー(あなた+7つの空席+ステッカー)

private struct GroupEmptyHero: View {
    let userName: String
    let isActive: Bool
    let onCreate: (String?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let height: CGFloat = 250

    private var initial: String {
        let first = userName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)
        return first.isEmpty ? "あ" : String(first)
    }

    var body: some View {
        GeometryReader { proxy in
            // 画面の幅(この画面は左右に V5.edge の余白がある)
            let screenWidth = proxy.size.width + V5.edge * 2
            let rx = GroupEmptyYouth.horizontalRadius(screenWidth: screenWidth)
            let center = CGPoint(x: proxy.size.width / 2, y: height / 2)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive || reduceMotion)) { context in
                let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<7, id: \.self) { index in
                        let offset = GroupEmptyYouth.seatOffset(index: index, rx: rx)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
                        }
                        .stroke(ChicColor.ink.opacity(0.13), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 5]))
                    }
                    ForEach(0..<7, id: \.self) { index in
                        let offset = GroupEmptyYouth.seatOffset(index: index, rx: rx)
                        let float: CGFloat = reduceMotion ? 0 : CGFloat(-6 * (0.5 + 0.5 * sin((t / 3.4 + Double(index) / 7) * 2 * .pi)))
                        SeatButton(color: Color(hex: GroupEmptyYouth.seatColors[index]), onTap: { onCreate(nil) })
                            .position(x: center.x + offset.x, y: center.y + offset.y + float)
                    }
                    centerBadge(t: t)
                        .position(x: center.x, y: center.y)
                    ForEach(GroupEmptyYouth.stickers) { sticker in
                        StickerButton(sticker: sticker, onTap: { onCreate(sticker.word) })
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: sticker.alignment)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                    }
                }
                .frame(width: proxy.size.width, height: height)
            }
        }
        .frame(height: height)
    }

    private func centerBadge(t: Double) -> some View {
        let degrees = reduceMotion ? 0 : (t.truncatingRemainder(dividingBy: 6) / 6) * 360
        let ringColors = (GroupEmptyYouth.rainbow + [GroupEmptyYouth.rainbow[0]]).map { Color(hex: $0) }
        return ZStack {
            Circle()
                .strokeBorder(AngularGradient(colors: ringColors, center: .center), lineWidth: 6)
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(degrees))
            Circle()
                .fill(LinearGradient(
                    colors: ["FFE2C8", "FF9A6A", "D8577E", "7A2C5A"].map { Color(hex: $0) },
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 88, height: 88)
            Text(initial)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("あなた")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(GroupEmptyYouth.pink))
                .background(Capsule().fill(Color(hex: "2A1A12")).offset(x: 2, y: 2))
                .offset(y: 62)
        }
        .frame(width: 100, height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("あなた")
    }
}

private struct SeatButton: View {
    let color: Color
    let onTap: () -> Void

    @State private var popped = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            TapConsumption.mark()
            popped = true
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { popped = false }
        } label: {
            ZStack {
                Circle().fill(RadialGradient(
                    colors: [color.opacity(0.22), color.opacity(0.06), .clear],
                    center: .center, startRadius: 0, endRadius: 23
                ))
                Circle().strokeBorder(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [2.5, 3.5]))
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.7), radius: 6)
            }
            .frame(width: 46, height: 46)
            .contentShape(Circle())
            .scaleEffect(popped ? 1.25 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: popped)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("グループをつくる")
    }
}

private struct StickerButton: View {
    let sticker: GroupEmptyYouth.Sticker
    let onTap: () -> Void

    @State private var popped = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            TapConsumption.mark()
            popped = true
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { popped = false }
        } label: {
            Text("#\(sticker.word)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(GroupEmptyYouth.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(GroupEmptyYouth.ink)
                            .offset(x: 3, y: 3)
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(hex: sticker.color))
                    }
                )
                .rotationEffect(.degrees(sticker.degrees))
                .padding(4)
                .contentShape(Rectangle())
                .scaleEffect(popped ? 1.18 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: popped)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sticker.word) という名前でグループをつくる")
    }
}

// MARK: サンプルのカード(押せない・下へ消える)

private struct GroupSampleCard: View {
    private static let section: GroupSectionModel = {
        let now = Date()
        let tiles = (0..<3).map { index in
            V5GroupTile(
                id: "sample-\(index)",
                authorSeed: UUID(),
                authorImage: nil,
                tags: index == 0 ? ["放課後"] : ["いつメン"],
                tiny: nil,
                imageData: nil,
                capturedAt: now,
                isMine: false
            )
        }
        return GroupSectionModel(
            id: UUID(),
            name: "いつメン",
            iconData: nil,
            auraIndex: 0,
            memberCount: 5,
            shotToday: 3,
            tiles: tiles,
            unlockedIDs: ["sample-0"],
            locationMode: .off
        )
    }()

    var body: some View {
        GroupSectionView(
            section: Self.section,
            levels: ["sample-0": .l3],
            scales: [:],
            bursts: [:],
            shakes: [:],
            glow: nil,
            pop: nil,
            isActive: false,
            announced: nil,
            litTileIDs: [],
            onOpenAnnounced: { _ in },
            onOpenRoom: {},
            onOpenTile: { _, _ in },
            onCycleLocation: {}
        )
        .mask(
            LinearGradient(stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.35),
                .init(color: .black.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
        .opacity(0.5)
        .scaleEffect(0.97)
        .overlay(alignment: .topLeading) {
            Text("SAMPLE")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(GroupEmptyYouth.pink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(GroupEmptyYouth.pink, lineWidth: 1.5))
                .rotationEffect(.degrees(-7))
                .padding(.leading, 10)
                .padding(.top, 4)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
