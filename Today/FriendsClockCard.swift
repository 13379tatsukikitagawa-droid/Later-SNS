import SwiftData
import SwiftUI

/// v47:FRIENDS = 12の 席(時計の 文字盤)。v49:カードの 中に 大きく「Friend」+ 数。
/// まんなかは なかまの イラスト。タップは すべて Friend 画面へ(そこで shake・席の えらぶ・poke が できる)。
struct FriendsClockCard: View {
    /// 自分を 除いた ともだち(友だちになった順)
    let friends: [HomeFriend]
    /// 見出し・まんなか・席・Add・Open のどれを 押しても Friend 画面
    let onOpenFriend: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [UserProfile]

    private static let seatCount = 12
    private static let radius: CGFloat = 112
    private static let cardHeight: CGFloat = 480

    private var me: UserProfile? { UserProfile.current(from: profiles) }
    private var shotCount: Int { friends.filter(\.hasShot).count }

    var body: some View {
        Button(action: onOpenFriend) {
            VStack(spacing: 0) {
                header
                ZStack {
                    radar
                    // 目盛りは 60本(5本ごとに 太い)。席は 12。
                    ForEach(0..<60, id: \.self) { tick(for: $0) }
                    ForEach(Array(friends.prefix(Self.seatCount).enumerated()), id: \.element.id) { index, friend in
                        seat(friend: friend, index: index)
                    }
                    if friends.count < Self.seatCount {
                        nextSeat(index: friends.count)
                    }
                    ForEach((friends.count + 1)..<Self.seatCount, id: \.self) { index in
                        emptySeat(index: index)
                    }
                    FriendGatheringGroup(colors: mascotColors, seatSize: 30)
                }
                .frame(maxHeight: .infinity)
                footerButtons
            }
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
        .frame(height: Self.cardHeight)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Darkroom.card))
        .accessibilityLabel("Friend。\(friends.count)/\(Self.seatCount)人")
    }

    private var mascotColors: [Color] {
        let colors = friends.prefix(4).map { LayerAvatar.colors($0.seed).first ?? .white }
        return colors.isEmpty ? [LayerAvatar.colors(me?.id ?? UUID(), override: me?.avatarColorIndex).first ?? Darkroom.orange] : Array(colors)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Friend").font(.custom("InstrumentSerif-Regular", size: 38)).foregroundStyle(.white)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: "\(friends.count)").font(.custom("InstrumentSerif-Regular", size: 22)).foregroundStyle(.white)
                Text(verbatim: "/\(Self.seatCount)").font(.custom("InstrumentSerif-Italic", size: 15)).foregroundStyle(.white)
            }
            if shotCount > 0 {
                HStack(spacing: 4) {
                    Circle().fill(Darkroom.orange).frame(width: 5, height: 5)
                    Text(verbatim: "\(shotCount)").font(Darkroom.mono(11))
                }
                .foregroundStyle(Darkroom.orange)
                .padding(.horizontal, 8).frame(height: 20)
                .background(Capsule().fill(Darkroom.orange.opacity(0.14)))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private var footerButtons: some View {
        HStack(spacing: 10) {
            Text("+ Add").font(.system(size: 15, weight: .heavy)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 50).background(Capsule().fill(.white))
            Text("Open ›").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50).background(Capsule().fill(.white.opacity(0.12)))
        }
        .padding(.horizontal, 18)
        .allowsHitTesting(false)
    }

    // MARK: 背景:ゆっくり回るレーダーの光(7秒で1周)

    private var radar: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let angle = Angle(degrees: (t.truncatingRemainder(dividingBy: 7) / 7) * 360)
            Circle()
                .fill(AngularGradient(colors: [.clear, Darkroom.orange.opacity(0.22), .clear], center: .center, angle: angle))
                .frame(width: Self.radius * 2.1, height: Self.radius * 2.1)
                .allowsHitTesting(false)
        }
    }

    // MARK: 目盛り(60本・5本ごとに太い)

    private func tick(for index: Int) -> some View {
        let thick = index % 5 == 0
        let angle = Double(index) / 60 * 2 * .pi - .pi / 2
        let outer = Self.radius + 14
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(.white.opacity(thick ? 0.3 : 0.12))
            .frame(width: thick ? 2.4 : 1.4, height: thick ? 9 : 5)
            .rotationEffect(.degrees(Double(index) / 60 * 360))
            .offset(x: cos(angle) * outer, y: sin(angle) * outer)
    }

    private func position(for index: Int) -> CGPoint {
        let angle = Double(index) / Double(Self.seatCount) * 2 * .pi - .pi / 2
        return CGPoint(x: cos(angle) * Self.radius, y: sin(angle) * Self.radius)
    }

    private func seat(friend: HomeFriend, index: Int) -> some View {
        let point = position(for: index)
        return ZStack(alignment: .topTrailing) {
            LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                .frame(width: 42, height: 42)
                .saturation(friend.hasShot ? 1 : 0.35)
                .opacity(friend.hasShot ? 1 : 0.6)
                .overlay(Circle().strokeBorder(friend.hasShot ? Darkroom.orange : .white.opacity(0.18), lineWidth: friend.hasShot ? 2.4 : 1.4))
                .shadow(color: friend.hasShot ? Darkroom.orange.opacity(0.7) : .clear, radius: 7)
            if friend.hasShot {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(Darkroom.orange))
                    .offset(x: 3, y: -3)
            }
        }
        .overlay(alignment: .topLeading) {
        }
        .offset(x: point.x, y: point.y)
        .accessibilityHidden(true)
    }

    private func nextSeat(index: Int) -> some View {
        let point = position(for: index)
        return PulsingDashedSeat(reduceMotion: reduceMotion, size: 42)
            .offset(x: point.x, y: point.y)
    }

    private func emptySeat(index: Int) -> some View {
        let point = position(for: index)
        return Circle()
            .strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.4, dash: [3, 4]))
            .frame(width: 42, height: 42)
            .offset(x: point.x, y: point.y)
    }
}

/// 次にすわる席:緑の点線が脈打つ + 「+」
struct PulsingDashedSeat: View {
    let reduceMotion: Bool
    var size: CGFloat = 46
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Darkroom.orange.opacity(pulse ? 0.9 : 0.4), style: StrokeStyle(lineWidth: 1.8, dash: [4, 4]))
                .scaleEffect(pulse ? 1.08 : 1)
            Text(verbatim: "+").font(.system(size: size * 0.4, weight: .light)).foregroundStyle(Darkroom.orange)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
