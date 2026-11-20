import SwiftUI

/// v110 §5:Trip の 一覧(Home の Trip ページ ・ きのうの Trip タブの どちらも これ 1つ)。
/// 段階 A では 入れ物 + 今ある Trip の 一覧だけ(週の 帯 ・ いま / これから / おわった は 段階 D)。
struct TripHubItem: Identifiable {
    let id: UUID
    var name: String
    var members: Int
    var cover: UIImage?
}

struct TripHubView: View {
    var trips: [TripHubItem]
    var onOpen: (UUID) -> Void = { _ in }
    var onNew: () -> Void = {}
    var onJoinKey: () -> Void = {}
    @Binding var position: ScrollPosition
    var topInset: CGFloat = 120
    var onScroll: (CGFloat) -> Void = { _ in }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                Color.clear.frame(height: topInset)
                HStack(spacing: 10) {
                    Button { Haptics.play(.pop); onNew() } label: {
                        Text("+ 新しい Trip").font(LF.inter(800, 16)).foregroundStyle(HV.ink).frame(maxWidth: .infinity, minHeight: 50).background(HV.lime, in: Capsule())
                    }.buttonStyle(HVPress(scale: 0.93))
                    Button { Haptics.play(.pop); onJoinKey() } label: {
                        Text("KEY で 入る").font(LF.inter(800, 16)).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color(hex: "1D1D20"), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }.buttonStyle(HVPress(scale: 0.93))
                }.padding(.horizontal, 16)
                if trips.isEmpty {
                    VStack(spacing: 8) {
                        Text("まだ Trip が ありません").font(LF.inter(800, 18)).foregroundStyle(.white)
                        Text("旅の あいだ、みんなで 1日 23枚").font(LF.inter(500, 13)).foregroundStyle(HV.gray)
                    }.padding(.top, 60)
                } else {
                    ForEach(trips) { t in
                        Button { Haptics.play(.pop); onOpen(t.id) } label: {
                            HStack(spacing: 12) {
                                Group {
                                    if let c = t.cover { Image(uiImage: c).resizable().scaledToFill() } else { Color(hex: "2A2A2E") }
                                }.frame(width: 56, height: 70).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.name).font(LF.inter(800, 18)).foregroundStyle(.white).lineLimit(1)
                                    Text("\(t.members)人").font(LF.inter(600, 12)).foregroundStyle(HV.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(HV.gray)
                            }
                            .padding(12).background(Color(hex: "151517"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }.buttonStyle(HVPress(scale: 0.97)).padding(.horizontal, 16)
                    }
                }
                Color.clear.frame(height: 150)
            }
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in onScroll(v) }
    }
}
