import SwiftUI
import UIKit

/// 画面のダブルタップ(MONDO ⇄ GROUP の切りかえ)の判定。
/// 0.33秒以内・34pt以内の2回のタップを、1回のダブルタップとみなす。
enum DoubleTapSwitchRule {
    static let maxInterval: TimeInterval = 0.33
    static let maxDistance: CGFloat = 34

    static func isDoubleTap(
        firstAt: Date,
        firstPoint: CGPoint,
        secondAt: Date,
        secondPoint: CGPoint
    ) -> Bool {
        guard secondAt.timeIntervalSince(firstAt) <= maxInterval else { return false }
        let dx = secondPoint.x - firstPoint.x
        let dy = secondPoint.y - firstPoint.y
        return (dx * dx + dy * dy).squareRoot() <= maxDistance
    }
}

/// 2つのページを、横にスライドして切りかえる。下に小さな切りかえ表示を出す。
/// どちらのページを見せるかは外が決める(showsSecond)。画面のダブルタップは、外の DoubleTapSurface が拾う。
/// 押せる場所(ボタン・タイル・カード)の上では、切りかえを使わない(子のタップを優先する)。
struct TwoPageSwitcher<First: View, Second: View>: View {
    let firstTitle: String
    let secondTitle: String
    let showsSecond: Bool
    /// 2つめのタイトルの右上に出す、橙の小さな点(新しい動きがあるとき)
    var secondBadge = false
    /// 下の表示をタップした(true なら2つめ)
    let onSelect: (Bool) -> Void
    @ViewBuilder let first: () -> First
    @ViewBuilder let second: () -> Second

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0.7秒、cubic-bezier(.2,.85,.2,1)
    static var slideAnimation: Animation { .timingCurve(0.2, 0.85, 0.2, 1, duration: 0.7) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                // 今の画面は -70pt・ぼかし10・透明へ、新しい画面は +70pt から戻る。「視差効果を減らす」はクロスフェード
                first()
                    .opacity(showsSecond ? 0 : 1)
                    .offset(x: reduceMotion ? 0 : (showsSecond ? -70 : 0))
                    .blur(radius: reduceMotion ? 0 : (showsSecond ? 10 : 0))
                    .allowsHitTesting(!showsSecond)
                    .accessibilityHidden(showsSecond)
                second()
                    .opacity(showsSecond ? 1 : 0)
                    .offset(x: reduceMotion ? 0 : (showsSecond ? 0 : 70))
                    .blur(radius: reduceMotion ? 0 : (showsSecond ? 0 : 10))
                    .allowsHitTesting(showsSecond)
                    .accessibilityHidden(!showsSecond)
            }

            switcherCapsule
                .frame(maxWidth: .infinity)
                .padding(.bottom, 26)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.3) : Self.slideAnimation, value: showsSecond)
    }

    private var switcherCapsule: some View {
        ZStack(alignment: .leading) {
            // 選ばれた側に、橙のにじむ「液体のハイライト」が横にすべる(0.65秒・少しゴムのように伸びる)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: "FFB27F"), Color(hex: "FF9E5E")], startPoint: .top, endPoint: .bottom))
                .shadow(color: V5.amber.opacity(0.55), radius: 10)
                .frame(width: 96, height: 38)
                .offset(x: showsSecond ? 98 : 3)
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.65, bounce: 0.32), value: showsSecond)
            HStack(spacing: 0) {
                capsuleLabel(firstTitle, selected: !showsSecond, target: false, badge: false)
                capsuleLabel(secondTitle, selected: showsSecond, target: true, badge: secondBadge && !showsSecond)
            }
        }
        .frame(width: 200, height: 46)
        .background(Capsule().fill(.ultraThinMaterial))
        .background(Capsule().fill(.black.opacity(0.4)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .consumesTap()
    }

    private func capsuleLabel(_ title: String, selected: Bool, target: Bool, badge: Bool) -> some View {
        Button {
            guard showsSecond != target else { return }
            onSelect(target)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle()
                            .fill(V5.orange)
                            .frame(width: 8, height: 8)
                            .shadow(color: V5.orange.opacity(0.9), radius: 4)
                            .padding(.top, 9)
                            .padding(.trailing, 14)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge ? "\(title)、新しい動きがあります" : title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
