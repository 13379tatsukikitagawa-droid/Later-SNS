import SwiftUI

// P58 A(v133 3章):上の バーは 1つの 部品。Home ・ Friends ・ Trip で 同じ 位置 ・ 同じ 大きさ ・ 同じ 写真 ・ 同じ 通知の 数。
// 通知(左 52)・ 題(まんなか ・ SF Pro Black 30)・ 1行(Friends だけ)・ プロフィール(右 56)。移っても バーは 動かさない(中身 だけ かわる)。
// 背景の 帯(ぼかし ・ グラデ)は 画面ごとに 持つ(ここは 押せる 物と 題 だけ)。

enum TopBarMetrics {
    static let height: CGFloat = 120
    static let bell: CGFloat = 52
    static let bellX: CGFloat = 16
    static let bellY: CGFloat = 49
    static let avatar: CGFloat = 56
    static let avatarY: CGFloat = 47
    static let avatarRight: CGFloat = 16      // 右の はしから(390pt で x 318)
    static let titleY: CGFloat = 56           // 行 40 の 上 → 中心 y 76
    static let titleSize: CGFloat = 30
    static let subtitleY: CGFloat = 98
}

struct TopBar: View {
    var title: String
    var subtitle: String? = nil
    var width: CGFloat
    var inboxCount = 0
    var avatar: UIImage?
    var avatarName = ""
    /// Home だけ:今日の 撮影の 進みの 輪(0〜1)と 切りかえの 目じるし(⇄)
    var ring: Double? = nil
    var showsSwitchBadge = false
    /// まとまる 時(スクロール)
    var compact = false
    var hidesTitleWhenCompact = false
    var showsTip = false
    /// 2回 タップの 行き先の 名前(「きのうへ」/「今日へ」)
    var switchLabel = "きのうへ"
    var onBell: () -> Void = {}
    var onProfile: () -> Void = {}
    var onSwitch: () -> Void = {}
    var onTitleTap: (() -> Void)? = nil
    var titleScale: CGFloat = 1

    @State private var avatarPop = false
    @State private var tip = false
    @State private var singleTask: DispatchWorkItem?
    @AppStorage("home.switchTipSeen") private var tipSeen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let spring = Animation.timingCurve(0.3, 1.15, 0.4, 1, duration: 0.55)

    var body: some View {
        ZStack(alignment: .topLeading) {
            titleBlock
            bell
            avatarButton
        }
        .frame(width: width, height: TopBarMetrics.height, alignment: .topLeading)
        .animation(Self.spring, value: compact)
    }

    // MARK: 題

    private var titleBlock: some View {
        VStack(spacing: 2) {
            ZStack {
                Text(title).id(title).transition(.opacity)
            }
            .font(Typo.ui(900, TopBarMetrics.titleSize)).tracking(-1.95).foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 7, y: 1)
            .lineLimit(1).fixedSize()
            .scaleEffect(titleScale, anchor: .leading)
            .frame(height: 40)
            .contentShape(Rectangle())
            .onTapGesture { onTitleTap?() }
            .animation(.easeOut(duration: 0.2), value: title)
            if let subtitle, !compact {
                Text(subtitle).id(subtitle).transition(.opacity)
                    .font(Typo.ui(700, 11)).foregroundStyle(Color(hex: "8E8E95")).lineLimit(1)
                    .frame(height: 14)
                    .animation(.easeOut(duration: 0.2), value: subtitle)
            }
        }
        .frame(width: width)
        .scaleEffect(compact ? 0.86 : 1, anchor: .top)
        .offset(y: TopBarMetrics.titleY + (compact ? -10 : 0))
        .opacity(compact && hidesTitleWhenCompact ? 0 : 1)
        .allowsHitTesting(!(compact && hidesTitleWhenCompact) && onTitleTap != nil)
    }

    // MARK: 通知(左)

    private var bell: some View {
        let size = TopBarMetrics.bell
        return Button { Haptics.play(.tick); onBell() } label: {
            Image(systemName: "bell").font(.system(size: 23, weight: .semibold)).foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color(red: 28 / 255, green: 28 / 255, blue: 31 / 255).opacity(0.9), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                .overlay(alignment: .topLeading) {
                    if inboxCount > 0 {
                        Text(inboxCount > 9 ? "9+" : "\(inboxCount)").font(Typo.ui(800, 11)).foregroundStyle(HV.ink)
                            .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20).background(HV.lime, in: Capsule())
                            .overlay(Capsule().strokeBorder(.black, lineWidth: 2.5)).offset(x: 30, y: 2)
                    }
                }
                .frame(width: 56, height: 56)   // 押せる 所は 44 より 大きい
                .contentShape(Circle())
        }
        .buttonStyle(HVPress(scale: 0.92))
        .scaleEffect(compact ? 0.77 : 1, anchor: .leading)
        .offset(x: TopBarMetrics.bellX - 2, y: TopBarMetrics.bellY - 2)
        .accessibilityLabel(inboxCount > 0 ? "お知らせ \(inboxCount)件" : "お知らせ")
    }

    // MARK: プロフィール(右)

    private var avatarButton: some View {
        let size = TopBarMetrics.avatar
        return ZStack(alignment: .bottomLeading) {
            ZStack {
                if let ring {
                    Circle().stroke(.white.opacity(0.22), lineWidth: 1.6).frame(width: size, height: size)
                    Circle().trim(from: 0, to: ring).stroke(HV.lime, style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: size, height: size)
                }
                Group {
                    if let avatar { Image(uiImage: avatar).resizable().scaledToFill() }
                    else { Circle().fill(Self.color(avatarName)).overlay(Text(String(avatarName.prefix(1))).font(Typo.ui(800, 18)).foregroundStyle(HV.ink)) }
                }
                .frame(width: 48, height: 48).clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            }.frame(width: size, height: size)
            if showsSwitchBadge {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 9, weight: .black)).foregroundStyle(HV.lime)
                    .frame(width: 20, height: 20).background(Color(hex: "0B0C0D"), in: Circle()).overlay(Circle().strokeBorder(HV.lime, lineWidth: 1.5))
                    .rotationEffect(.degrees(avatarPop ? 180 : 0)).offset(x: -4, y: 4)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect((compact ? 0.77 : 1) * (avatarPop ? 1.14 : 1))
        .contentShape(Circle())
        .onTapGesture(count: 2) {
            singleTask?.cancel()
            Haptics.play(.sel)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { avatarPop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onSwitch(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { avatarPop = false } }
        }
        .onTapGesture {
            Haptics.play(.tick)
            singleTask?.cancel()
            let t = DispatchWorkItem { onProfile() }; singleTask = t
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: t)   // 2回 タップと 見わける
        }
        .overlay(alignment: .bottom) {
            if tip {
                Text("2回 タップで \(switchLabel)").font(Typo.ui(700, 12)).foregroundStyle(.white).fixedSize().padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.black.opacity(0.85), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.8))
                    .offset(y: 40).transition(.opacity).allowsHitTesting(false)
            }
        }
        .offset(x: width - TopBarMetrics.avatarRight - size, y: TopBarMetrics.avatarY)
        .onAppear {
            guard showsTip, !tipSeen else { return }
            tipSeen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.3)) { tip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { withAnimation(.easeOut(duration: 0.3)) { tip = false } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("プロフィール。2回 タップで \(switchLabel)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: switchLabel) { onSwitch() }
    }

    private static func color(_ name: String) -> Color {
        let palette = ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"]
        let n = name.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0xFFFF }
        return Color(hex: palette[n % palette.count])
    }
}
