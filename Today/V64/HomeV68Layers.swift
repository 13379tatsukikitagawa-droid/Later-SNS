import SwiftUI

// P12-A(v68):Home の うしろ = 全面の ぼかし写真(幅 390 × 高さ 1010)。
// 重さの 決まり(P11):ぼかし ・ 彩度 ・ 明るさは 小さな 画像に 1回だけ 焼きこんで、ひきのばす。毎フレーム 計算しない。

struct HV68Backdrop: View {
    let input: HomeV64Input
    /// いまの ページの 位置(0〜4。指に ついて 動く)
    let pos: Double
    let focus: Bool
    let entered: Bool
    let width: CGFloat
    static let height: CGFloat = 1010

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var idx = 0
    @State private var drift = false

    private func key(_ i: UIImage) -> String { "v68\(ObjectIdentifier(i).hashValue)" }
    private func baked(_ i: UIImage, r: CGFloat, sat: CGFloat, b: CGFloat) -> UIImage {
        V64Images.blurred(key: key(i), source: i, maxPixel: 96, radius: r, saturation: sat, brightness: b)
    }
    private func layerOpacity(_ i: Int) -> Double { max(0, 1 - abs(Double(i) - pos)) }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "0B0B0C")
            camera.opacity(layerOpacity(0))
            page(1, input.backdrop.first).opacity(layerOpacity(1))
            page(2, input.trip?.cover ?? input.tripSamples[safe: 1] ?? input.backdrop.first).opacity(layerOpacity(2))
            RadialGradient(stops: [.init(color: Color(hex: "0C1F13"), location: 0), .init(color: Color(hex: "070B09"), location: 0.46), .init(color: Color(hex: "050506"), location: 1)],
                           center: UnitPoint(x: 0.78, y: 0.32), startRadius: 0, endRadius: 620)
                .opacity(layerOpacity(3))
            page(4, input.yesterdayThumbs[safe: 1]?.image ?? input.yesterdayThumbs.first?.image ?? input.yesterdayPhoto).opacity(layerOpacity(4))
            // 光の もれ(オレンジ)
            RadialGradient(colors: [Color(hex: "FFB070").opacity(0.5), Color(hex: "FFB070").opacity(0)], center: .center, startRadius: 0, endRadius: 176)
                .frame(width: 351, height: 768).position(x: 313.5, y: 141).opacity(0.39).blendMode(.screen)
            // かげ:まわりは 黒 46% ・ たては 上 黒 → 透明 → 下は 深い 緑 → #0A0A0B
            RadialGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.34), .init(color: .black.opacity(0.46), location: 1)],
                           center: UnitPoint(x: 0.5, y: 0.44), startRadius: 0, endRadius: 640)
            LinearGradient(stops: [.init(color: .black.opacity(0.5), location: 0), .init(color: .clear, location: 0.20), .init(color: .clear, location: 0.56),
                                   .init(color: Color(red: 6 / 255, green: 20 / 255, blue: 10 / 255).opacity(0.72), location: 0.84), .init(color: Color(hex: "0A0A0B"), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            HVGrain().opacity(0.17).blendMode(.overlay)
        }
        .frame(width: width, height: Self.height)
        .clipped()
        .allowsHitTesting(false)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                if scenePhase == .active, !reduceMotion, input.backdrop.count > 1 { idx += 1 }
            }
        }
        .onAppear { startDrift() }
        .onChange(of: scenePhase) { _, p in if p == .active { startDrift() } else { stopDrift() } }
        .onDisappear { stopDrift() }
    }

    private func startDrift() { if !reduceMotion { drift = true } }
    private func stopDrift() { withTransaction(Transaction(animation: nil)) { drift = false } }

    // 0:カメラ(3枚を 7秒ごとに 1.8秒で クロスフェード・ゆっくり 動く)
    private var camera: some View {
        let imgs = Array(input.backdrop.prefix(3))
        let cur = imgs.isEmpty ? 0 : idx % imgs.count
        return ZStack {
            ForEach(imgs.indices, id: \.self) { i in
                let img = imgs[i]
                let strong = baked(img, r: 15, sat: 1.35, b: input.done ? 0.62 : 0.66)
                let weak = baked(img, r: 5, sat: 1.35, b: 0.76)
                let intro = baked(img, r: 31, sat: 1.35, b: 0.5)
                ZStack {
                    Image(uiImage: strong).resizable().scaledToFill()
                    Image(uiImage: weak).resizable().scaledToFill().opacity(focus ? 1 : 0)
                    Image(uiImage: intro).resizable().scaledToFill().opacity(entered ? 0 : 1)
                }
                .opacity(i == cur ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 1.8), value: idx)
        .animation(.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.55), value: focus)
        .frame(width: width + 110, height: 1296)
        .scaleEffect((entered ? 1 : 1.14) * (drift ? 1.12 : 1))
        .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 1.25), value: entered)
        .animation(drift ? .easeInOut(duration: 18).repeatForever(autoreverses: true) : nil, value: drift)
        .offset(y: 0)
        .frame(width: width, height: Self.height, alignment: .top)
        .clipped()
    }

    // 1・2・4:ページごとの 写真(ぼかし 18 ・ 彩度 1.3 ・ 明るさ 0.42)
    @ViewBuilder private func page(_ i: Int, _ photo: UIImage?) -> some View {
        if let photo {
            Image(uiImage: baked(photo, r: 18, sat: 1.3, b: 0.42)).resizable().scaledToFill()
                .frame(width: width, height: Self.height).clipped()
        } else {
            Color.clear
        }
    }
}

/// 下の つなぎ(`#dusk`):透明 → 深い 緑 → #0A0A0B。スクロールの 中身と いっしょに 動く(y = 692)
struct HV68Dusk: View {
    let width: CGFloat
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: Color(red: 11 / 255, green: 30 / 255, blue: 16 / 255).opacity(0.85), location: 0.34),
                               .init(color: Color(hex: "0B120D"), location: 0.62), .init(color: Color(hex: "0A0A0B"), location: 1)], startPoint: .top, endPoint: .bottom)
            .frame(width: width, height: 434).allowsHitTesting(false)
    }
}
