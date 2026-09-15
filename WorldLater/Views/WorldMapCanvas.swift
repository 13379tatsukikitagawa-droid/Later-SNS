import SwiftUI

/// 地図上の1本のピン。位置(point)は0...1の相対座標(GeometryReaderで実サイズに変換する)。
/// 実際の撮影地点とは一切紐づかない、投稿IDから決定論的に算出した装飾的な座標
/// (DeterministicMapPosition参照。Laterの匿名性の設計方針に合わせた選択)。
struct WorldMapPin: Identifiable {
    let id: UUID
    let point: CGPoint
}

/// コルクボードに描かれた「世界地図」のスケッチ描画。経緯線を示唆する破線グリッド+
/// 大陸を示す抽象的な丸みのある塊で構成する、正確な地理データではない装飾的な地図。
/// 描画元(grid線・大陸の塊の座標)は全て静的な定数のため、再描画のたびに重い
/// 再計算は発生しない(Canvasのdraw closure自体もSwiftUIが必要な時にしか呼ばない)。
struct WorldMapCanvas: View {
    var pins: [WorldMapPin] = []
    var showsPlaceholderMarkers: Bool = false
    /// 状態B: ピンの1つに「糸で吊るされた写真」を添える(タップ動作は今回のスコープ外)。
    var featured: (photoID: UUID, imageData: Data, cacheKey: String)? = nil

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Canvas { context, canvasSize in
                    Self.drawGrid(context: context, size: canvasSize)
                    Self.drawContinents(context: context, size: canvasSize)
                    if showsPlaceholderMarkers {
                        Self.drawPlaceholderMarkers(context: context, size: canvasSize)
                    }
                }

                ForEach(pins) { pin in
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color.brandGreen.opacity(0.6), radius: 4)
                        .position(x: pin.point.x * size.width, y: pin.point.y * size.height)
                }

                if let featured, let pin = pins.first(where: { $0.id == featured.photoID }) {
                    featuredCard(imageData: featured.imageData, cacheKey: featured.cacheKey)
                        .position(x: pin.point.x * size.width, y: pin.point.y * size.height - 34)
                }
            }
        }
    }

    // MARK: - 糸で吊るされた写真カード

    private func featuredCard(imageData: Data, cacheKey: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.7))
                .frame(width: 1, height: 14)

            CachedPhotoImage(imageData: imageData, cacheKey: cacheKey) { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.corkboardPhotoArea
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(.white.opacity(0.85), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .rotationEffect(.degrees(-6))
        }
    }

    // MARK: - 経緯線を示唆する破線グリッド(装飾のみ)

    private static func drawGrid(context: GraphicsContext, size: CGSize) {
        var path = Path()
        let verticalLines = 4
        let horizontalLines = 3
        for i in 1...verticalLines {
            let x = size.width * CGFloat(i) / CGFloat(verticalLines + 1)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for i in 1...horizontalLines {
            let y = size.height * CGFloat(i) / CGFloat(horizontalLines + 1)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(Color.corkboardHeading.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
    }

    // MARK: - 大陸を示す、抽象化された丸みのある塊

    private struct ContinentBlob {
        /// 相対座標(0...1)の中心と大きさ。正確な地理データではなく、手描きの
        /// スケッチ地図を意識した目分量の配置。
        let center: CGPoint
        let size: CGSize
    }

    private static let continents: [ContinentBlob] = [
        ContinentBlob(center: CGPoint(x: 0.16, y: 0.30), size: CGSize(width: 0.16, height: 0.14)),
        ContinentBlob(center: CGPoint(x: 0.13, y: 0.44), size: CGSize(width: 0.10, height: 0.12)),
        ContinentBlob(center: CGPoint(x: 0.23, y: 0.64), size: CGSize(width: 0.09, height: 0.20)),
        ContinentBlob(center: CGPoint(x: 0.47, y: 0.26), size: CGSize(width: 0.08, height: 0.09)),
        ContinentBlob(center: CGPoint(x: 0.50, y: 0.52), size: CGSize(width: 0.14, height: 0.24)),
        ContinentBlob(center: CGPoint(x: 0.69, y: 0.28), size: CGSize(width: 0.22, height: 0.16)),
        ContinentBlob(center: CGPoint(x: 0.80, y: 0.42), size: CGSize(width: 0.10, height: 0.12)),
        ContinentBlob(center: CGPoint(x: 0.83, y: 0.68), size: CGSize(width: 0.10, height: 0.07))
    ]

    private static func drawContinents(context: GraphicsContext, size: CGSize) {
        for blob in continents {
            let rect = CGRect(
                x: (blob.center.x - blob.size.width / 2) * size.width,
                y: (blob.center.y - blob.size.height / 2) * size.height,
                width: blob.size.width * size.width,
                height: blob.size.height * size.height
            )
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(Color.corkboardHeading.opacity(0.16)))
            context.stroke(path, with: .color(Color.corkboardHeading.opacity(0.22)), lineWidth: 1)
        }
    }

    // MARK: - 状態A: 「ここにいずれピンが立つ」ことを示唆する破線マーカー

    private static let placeholderMarkerPoints: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.52),
        CGPoint(x: 0.70, y: 0.30)
    ]

    private static func drawPlaceholderMarkers(context: GraphicsContext, size: CGSize) {
        for point in placeholderMarkerPoints {
            let center = CGPoint(x: point.x * size.width, y: point.y * size.height)
            let rect = CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)
            let path = Path(ellipseIn: rect)
            context.stroke(path, with: .color(Color.corkboardHeading.opacity(0.3)), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
        }
    }
}
