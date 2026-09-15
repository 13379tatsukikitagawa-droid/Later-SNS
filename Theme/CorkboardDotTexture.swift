import SwiftUI

/// コルクボードの粒状感を表す、低透明度のドット模様。Canvasで一度だけ描画する
/// 静的な背景装飾(毎フレーム再計算しない。SwiftUIはCanvasの中身が変わらない限り
/// 再描画を省略できるため、スクロール中のフレームレートに影響しない)。
struct CorkboardDotTexture: View {
    private static let spacing: CGFloat = 20
    private static let dotRadius: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let columns = Int(size.width / Self.spacing) + 2
            let rows = Int(size.height / Self.spacing) + 2
            for row in 0..<rows {
                for col in 0..<columns {
                    let x = CGFloat(col) * Self.spacing
                    let y = CGFloat(row) * Self.spacing
                    let rect = CGRect(
                        x: x - Self.dotRadius,
                        y: y - Self.dotRadius,
                        width: Self.dotRadius * 2,
                        height: Self.dotRadius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.035)))
                }
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

/// Home画面(コルクボード面)の背景一式: ベースカラー+ドット模様+上部のごく薄い
/// 黒グラデーション(奥行き演出)。
struct CorkboardBackground: View {
    var body: some View {
        ZStack {
            Color.corkboardBackground
            CorkboardDotTexture()
            LinearGradient(
                colors: [.black.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.25)
            )
        }
        .ignoresSafeArea()
    }
}
