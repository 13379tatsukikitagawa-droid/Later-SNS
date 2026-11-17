import SwiftUI

/// v54:モックの 画面は 390 × 844pt。`MEASURED_SPEC.md` の x・y・w・h は そのまま pt として 使い、
/// 幅が 390 で ない 機種では `s = 画面幅 / 390`(0.96〜1.10 の 範囲に おさめる)を かけて 中央に そろえる。
/// `UIScreen.main.bounds` は 使わない。画面の 幅は `GeometryReader` で 1回だけ 取って 渡す。
enum Metrics {
    /// モックの 基準幅
    static let baseWidth: CGFloat = 390

    /// 画面幅に対する 倍率(0.96〜1.10)
    static func scale(for width: CGFloat) -> CGFloat {
        min(1.10, max(0.96, width / baseWidth))
    }
}

extension View {
    /// 390pt 基準で 組んだ 画面を、実機の 幅に合わせて 一括で 拡大縮小する(中央ぞろえ)。
    /// 呼び出し側は GeometryReader で 取った `width` を そのまま 渡すだけでよい。
    func scaledToDeviceWidth(_ width: CGFloat, anchor: UnitPoint = .top) -> some View {
        let s = Metrics.scale(for: width)
        return self
            .frame(width: Metrics.baseWidth)
            .scaleEffect(s, anchor: anchor)
            .frame(width: width, alignment: anchor == .top ? .top : .center)
    }
}
