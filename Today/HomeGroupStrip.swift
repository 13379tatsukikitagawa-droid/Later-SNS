import SwiftUI
import UIKit

/// Homeの「グループの段」。グループは、みんなの円の「小さな版」(点の輪)として見せる。
/// いいね・ランキング・連続記録は出さない。触覚なし。
struct HomeGroupStrip: View {
    /// MEを除いた、参加中のグループ
    let groups: [LaterGroup]
    /// 円をそのグループの点だけに絞っている時のグループ
    let selectedGroupID: UUID?
    var showsLabel = true
    let onSelect: (LaterGroup) -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsLabel {
                Text("グループ・\(groups.count) / \(GroupMembershipPolicy.maxGroupsPerUser)")
                    .font(.system(size: 9.5, design: .monospaced))
                    .tracking(0.14 * 9.5)
                    .foregroundStyle(Color(hex: "6B6B70"))
                    .padding(.horizontal, 28)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
            }
            if groups.isEmpty {
                createRow
                    .padding(.horizontal, 28)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(groups) { group in
                            Button { onSelect(group) } label: {
                                GroupRingTile(group: group, isSelected: group.id == selectedGroupID)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(group.name)、グループ、\(group.members.count)人")
                            .accessibilityAddTraits(group.id == selectedGroupID ? [.isButton, .isSelected] : .isButton)
                        }
                        if groups.count < GroupMembershipPolicy.maxGroupsPerUser {
                            Button(action: onCreate) {
                                VStack(spacing: 6) {
                                    dashedPlus(size: 52)
                                    Text("つくる")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(Color(hex: "8E8E93"))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("グループをつくる")
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private var createRow: some View {
        Button(action: onCreate) {
            HStack(spacing: 12) {
                dashedPlus(size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("グループをつくる")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("4〜8人で、同じ昨日をひらく。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(.horizontal, 12)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("グループをつくる")
    }

    private func dashedPlus(size: CGFloat) -> some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            Image(systemName: "plus")
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: size, height: size)
    }
}

/// グループの輪(52pt)。中にグループの写真(32pt、なければ名前の頭文字)、
/// まわりに8つの点(光っている点 = 参加ずみの人数、暗い点 = まだの枠)。
struct GroupRingTile: View {
    let group: LaterGroup
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            GroupDotRing(
                photo: group.iconImageData.flatMap(UIImage.init(data:)),
                initial: String(group.name.prefix(1)),
                memberCount: group.members.count,
                diameter: 52,
                photoDiameter: 32,
                dotSize: 3.5,
                litColor: nil
            )
            .overlay(Circle().strokeBorder(.white.opacity(isSelected ? 0.7 : 0), lineWidth: 1.2))
            Text(Self.shortName(group.name))
                .font(.system(size: 10.5))
                .foregroundStyle(Color(hex: "BCBBC0"))
                .lineLimit(1)
                .frame(width: 60)
        }
    }

    /// 5文字まで見せて省略
    static func shortName(_ name: String) -> String {
        name.count > 5 ? String(name.prefix(5)) + "…" : name
    }
}

/// グループの点の輪(Homeの段・作成フローで共有)。8つの点を、縁から内側に置く。
struct GroupDotRing: View {
    let photo: UIImage?
    let initial: String
    let memberCount: Int
    let diameter: CGFloat
    let photoDiameter: CGFloat
    var dotSize: CGFloat = 5
    /// 参加ずみの点の色(nilなら白)。作成フローの「できた」だけ、写真の色(オレンジ・青・黄)で光る。
    var litColor: ((Int) -> Color)?

    static let slotCount = GroupMembershipPolicy.maxMembersPerGroup

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.04))
            Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1)
            ForEach(0..<Self.slotCount, id: \.self) { index in
                let angle = -Double.pi / 2 + Double(index) / Double(Self.slotCount) * 2 * .pi
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
