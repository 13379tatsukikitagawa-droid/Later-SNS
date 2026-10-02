import SwiftUI

/// Home画面(没入型v2・初回起動時)の背景に敷く、「現像中の写真」の壁。
///
/// 写真そのものの画像データは一切使わない(解禁前の写真は本人以外に見せない、という
/// 既存方針を破らないため)。固定パレットのぼかしたグラデーションで
/// 「何かが写っている気配」だけを表現する装飾。
///
/// 一度取得したタイルは@Stateにそのまま保持し、以後は再取得・再生成しない
/// (親のカウントダウン側が毎秒更新されても、このView自体はその状態を観測していない
/// ため再描画されない)。
struct HomeDevelopingWallView: View {
    private static let columns = 4
    private static let rows = 4
    private static let tileSize = CGSize(width: 118, height: 150)
    private static let tileSpacing: CGFloat = 8
    private static let rotationDegrees: Double = -8
    /// 実データが無い/少ない場合に敷き詰めるダミータイルの固定パレット。実在しない投稿の
    /// 地域・時刻を出さないよう、ダミーには一切テキストを付けない。各タイルは暗い下地
    /// (#1E1020系)の上にアクセントカラー1色を円形グラデーションで乗せ、「何かが写っている
    /// 気配」を淡く見せる(仕様書で指定された7色を使用)。
    private static let fallbackPalette: [[Color]] = [
        [Color(hex: "FF9E5E"), Color(hex: "1E1020")],
        [Color(hex: "3FA8FF"), Color(hex: "1E1020")],
        [Color(hex: "4ADE6C"), Color(hex: "1E1020")],
        [Color(hex: "FF7AA8"), Color(hex: "1E1020")],
        [Color(hex: "FFCF5E"), Color(hex: "1E1020")],
        [Color(hex: "7FD4FF"), Color(hex: "1E1020")],
        [Color(hex: "C9A0FF"), Color(hex: "1E1020")]
    ]

    private struct DisplayTile: Identifiable {
        let id: String
        let colors: [Color]
        /// nilならダミータイル(地域・時刻のラベルを一切表示しない)。
        let regionTimeLabel: String?
    }

    @State private var displayTiles: [DisplayTile] = []

    var body: some View {
        wallGrid
            .frame(height: 500)
            .clipped()
            .overlay(fadeOverlay)
            .overlay(centerVignette)
            .overlay(grainOverlay)
            .allowsHitTesting(false)
            .task {
                guard displayTiles.isEmpty else { return }
                await loadTiles()
            }
    }

    private var wallGrid: some View {
        VStack(spacing: Self.tileSpacing) {
            ForEach(0..<Self.rows, id: \.self) { row in
                HStack(spacing: Self.tileSpacing) {
                    ForEach(0..<Self.columns, id: \.self) { col in
                        let index = row * Self.columns + col
                        if index < displayTiles.count {
                            tileView(displayTiles[index])
                        } else {
                            Color.clear.frame(width: Self.tileSize.width, height: Self.tileSize.height)
                        }
                    }
                }
            }
        }
        .frame(width: CGFloat(Self.columns) * (Self.tileSize.width + Self.tileSpacing),
               height: CGFloat(Self.rows) * (Self.tileSize.height + Self.tileSpacing))
        .rotationEffect(.degrees(Self.rotationDegrees))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0d0f0c"))
    }

    private func tileView(_ tile: DisplayTile) -> some View {
        // タイルごとに光源の位置を変え、同じ壁の中でも単調に見えないようにする。
        let center: UnitPoint = abs(tile.id.hashValue) % 2 == 0 ? .topLeading : .bottomTrailing
        return ZStack(alignment: .bottomLeading) {
            RadialGradient(colors: tile.colors, center: center, startRadius: 4, endRadius: 140)

            if let label = tile.regionTimeLabel {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .semibold))
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(6)
            }
        }
        .frame(width: Self.tileSize.width, height: Self.tileSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 奥行き演出(壁のフェード・中央の暗転・粒子)

    private var fadeOverlay: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: "0d0f0c"), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 90)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, Color(hex: "0d0f0c")], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
        }
    }

    private var centerVignette: some View {
        RadialGradient(
            colors: [Color(hex: "0d0f0c").opacity(0.5), .clear],
            center: .center,
            startRadius: 10,
            endRadius: 220
        )
    }

    /// フィルムグレインの粒子オーバーレイ。Camera/Views/CameraCaptureView.swiftの
    /// filmGrainOverlayと同じ、乱数種のCanvas描画パターンをこの画面向けに踏襲している
    /// (プロジェクト内に共有コンポーネント化された粒子Viewが無いため、同じ実装方針を
    /// そのまま使う)。
    private var grainOverlay: some View {
        Canvas { context, size in
            for _ in 0..<300 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.02...0.06)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .opacity(0.4)
    }

    // MARK: - タイル生成(一度だけ)

    /// World Later(全体フィード)の廃止に伴い、実投稿の色タイルは取得しない。
    /// 装飾用の固定パレットだけで壁を埋める。
    private func loadTiles() async {
        let desiredCount = Self.columns * Self.rows
        var tiles: [DisplayTile] = []

        var fallbackIndex = 0
        while tiles.count < desiredCount {
            let palette = Self.fallbackPalette[fallbackIndex % Self.fallbackPalette.count]
            tiles.append(DisplayTile(id: "fallback-\(fallbackIndex)", colors: palette, regionTimeLabel: nil))
            fallbackIndex += 1
        }

        displayTiles = tiles
    }
}
