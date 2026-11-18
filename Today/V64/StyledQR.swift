import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// v92:Lattag らしい QR。点(丸)+ # の 形の 緑 + 3つの 目 = レンズ + まんなかに アイコン。誤り訂正 H。
// 中身は 普通の QR と 同じ(Vision で 読めることを テストで 確かめる)。

enum QRMatrix {
    /// 1マス = 1要素。まわりの 白い ふちは 取りのぞく
    static func make(_ text: String) -> [[Bool]]? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "H"
        guard let out = f.outputImage else { return nil }
        let w = Int(out.extent.width), h = Int(out.extent.height)
        guard w > 0, h > 0 else { return nil }
        var px = [UInt8](repeating: 255, count: w * h)
        CIContext(options: [.useSoftwareRenderer: true]).render(out, toBitmap: &px, rowBytes: w, bounds: out.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h { for x in 0..<w where px[y * w + x] < 128 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) } }
        guard maxX > minX, maxY > minY else { return nil }
        let n = max(maxX - minX, maxY - minY) + 1
        return (0..<n).map { r in (0..<n).map { c in
            let x = minX + c, y = minY + r
            return x < w && y < h && px[y * w + x] < 128
        } }
    }
}

struct StyledQRView: View, Animatable {
    let matrix: [[Bool]]
    /// 0 → 1:点が まんなか から 外へ 出る
    var progress: Double = 1
    var side: CGFloat = 232
    var paper = Color(hex: "FBFAF6")

    var animatableData: Double { get { progress } set { progress = newValue } }

    static let ink = Color(hex: "0B0C0D"), green = Color(hex: "1F8F37")

    var body: some View {
        let n = matrix.count
        ZStack {
            Canvas { ctx, size in
                guard n > 0 else { return }
                let cell = size.width / CGFloat(n)
                let mid = Double(n) / 2
                let iconHalf = 7.6 / 2 + 0.4
                func finder(_ cx: Int, _ cy: Int) -> Bool { (cx < 7 || cx >= n - 7) && (cy < 7 || cy >= n - 7) && !(cx >= n - 7 && cy >= n - 7) }
                func hash(_ fx: Double, _ fy: Double) -> Bool {
                    let v = ((0.27...0.40).contains(fx) || (0.60...0.73).contains(fx)) && (0.08...0.92).contains(fy)
                    let h = ((0.27...0.40).contains(fy) || (0.60...0.73).contains(fy)) && (0.08...0.92).contains(fx)
                    return v || h
                }
                for r in 0..<n { for c in 0..<n where matrix[r][c] {
                    if finder(c, r) { continue }
                    if abs(Double(c) + 0.5 - mid) < iconHalf && abs(Double(r) + 0.5 - mid) < iconHalf { continue }
                    let d = hypot(Double(c) + 0.5 - mid, Double(r) + 0.5 - mid) / (mid * 1.42)
                    let local = max(0, min(1, (progress - d * 0.55) / 0.45))
                    guard local > 0 else { continue }
                    let rad = 0.43 * Double(cell) * (1 - pow(1 - local, 3))
                    let x = (Double(c) + 0.5) * Double(cell), y = (Double(r) + 0.5) * Double(cell)
                    let g = hash((Double(c) + 0.5) / Double(n), (Double(r) + 0.5) / Double(n))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)), with: .color(g ? Self.green : Self.ink))
                } }
                // 3つの 目 = レンズ(外 7 × 7 ・ 角丸 1マス ・ 白 5 × 5 ・ まんなかに 丸い レンズ)
                let ek = 0.6 + 0.4 * min(1, progress * 5)
                for (ox, oy) in [(0, 0), (n - 7, 0), (0, n - 7)] {
                    let cx = (Double(ox) + 3.5) * Double(cell), cy = (Double(oy) + 3.5) * Double(cell)
                    var e = ctx
                    e.translateBy(x: cx, y: cy); e.scaleBy(x: ek, y: ek); e.translateBy(x: -cx, y: -cy)
                    let o = CGRect(x: Double(ox) * Double(cell), y: Double(oy) * Double(cell), width: 7 * Double(cell), height: 7 * Double(cell))
                    e.fill(Path(roundedRect: o, cornerRadius: Double(cell)), with: .color(Self.ink))
                    e.fill(Path(roundedRect: o.insetBy(dx: Double(cell), dy: Double(cell)), cornerRadius: 0.5 * Double(cell)), with: .color(paper))
                    let lr = 1.62 * Double(cell)
                    e.fill(Path(ellipseIn: CGRect(x: cx - lr, y: cy - lr, width: lr * 2, height: lr * 2)),
                           with: .radialGradient(Gradient(stops: [.init(color: Color(hex: "2A3A5A"), location: 0), .init(color: Color(hex: "05070A"), location: 0.6), .init(color: Self.ink, location: 1)]),
                                                 center: CGPoint(x: cx + lr * 0.2, y: cy + lr * 0.2), startRadius: 0, endRadius: lr * 1.1))
                    let dr = 0.38 * Double(cell)
                    e.fill(Path(ellipseIn: CGRect(x: cx - lr * 0.35 - dr, y: cy - lr * 0.35 - dr, width: dr * 2, height: dr * 2)), with: .color(Color(hex: "C8F25A")))
                }
            }
            if n > 0 {
                OPIcon(size: side / CGFloat(n) * 7.6, lensScale: 1).scaleEffect(min(1, max(0, (progress - 0.05) * 6)))
            }
        }.frame(width: side, height: side)
    }
}
