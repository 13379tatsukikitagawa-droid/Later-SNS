import SwiftUI

/// v104:シートの 高さ = 中身の 高さ。`Spacer()` で のばさない。
/// 中身(`Spacer` なしの VStack)の 高さを `onGeometryChange` で はかり、`.presentationDetents([.height(h), .large])` に する。
/// 中身が かわる(行を ひらく など)たびに はかりなおし、`.smooth` で のびる。キーボードで シートが 上がるのは システムに まかせる。
struct SheetFitsContent: ViewModifier {
    /// 中身の 下に 足す 高さ(ホームバーの ぶん)
    var extra: CGFloat = SheetFitsContent.bottomInset
    @State private var h: CGFloat = 0

    static var bottomInset: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow?.safeAreaInsets.bottom ?? 34
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
                guard new > 0 else { return }
                if h == 0 { h = new } else { withAnimation(.smooth) { h = new } }
            }
            .presentationDetents(h > 0 ? [.height(h + extra), .large] : [.medium, .large])
    }
}

extension View {
    func sheetFitsContent(extra: CGFloat = SheetFitsContent.bottomInset) -> some View {
        modifier(SheetFitsContent(extra: extra))
    }
}
