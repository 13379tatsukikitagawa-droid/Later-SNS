import SwiftUI

// v99 の 12場面。ぜんぶ「時間 t(場面の はじめ から の 秒)の 関数」。動きは offset / scaleEffect / opacity / rotationEffect だけ。
// 写真は 説明用の 色の 絵(いつも 同じ ・ 本番の 友だち写真は 使わない)。人は 名前の 1文字 + 色の 丸。

private let lime = Color(hex: "C8F25A")
private typealias M = IntroMath

/// 説明用の 写真(色の 絵 6枚)
private enum IntroPhoto {
    static let pairs: [(String, String)] = [("F2A65A", "7A3E5A"), ("8FB8D8", "2A3A5A"), ("E8C39A", "5A3A2A"), ("B7D9A0", "2A4A3A"), ("D98A9A", "3A2A4A"), ("F0D87A", "6A4A2A")]
    static func fill(_ i: Int) -> LinearGradient {
        let p = pairs[((i % 6) + 6) % 6]
        return LinearGradient(colors: [Color(hex: p.0), Color(hex: p.1)], startPoint: .top, endPoint: .bottom)
    }
}

private struct IAvatar: View {
    let name: String
    let i: Int
    var d: CGFloat = 58
    var ring = false
    var body: some View {
        ZStack {
            Circle().fill(IntroPhoto.fill(i + 2))
            Text(String(name.prefix(1))).font(LF.inter(800, d * 0.38)).foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: d, height: d)
        .overlay(Circle().strokeBorder(ring ? lime : .clear, lineWidth: 3))
    }
}

private struct ICheki: View {
    var i = 0
    var w: CGFloat = 44
    var body: some View {
        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "F4F1EA"))
            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(IntroPhoto.fill(i)).padding(.horizontal, w * 0.07).padding(.top, w * 0.07).frame(height: w * 0.9) }
            .frame(width: w, height: w * 1.22)
            .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
    }
}

/// 裏(`#161618` + ライムの #)
private struct IChekiBack: View {
    var w: CGFloat = 60
    var body: some View {
        RoundedRectangle(cornerRadius: 4).fill(Color(hex: "161618"))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.08)))
            .overlay(HV72HashShape().fill(lime).frame(width: w * 0.42, height: w * 0.42))
            .frame(width: w, height: w * 1.22)
    }
}

/// 表 / 裏の 入れかえは 不透明度で(横に つぶれて 戻る)
private struct IFlip<F: View, B: View>: View {
    let p: Double   // 0 → 1
    let front: F
    let back: B
    var body: some View {
        let x = abs(cos(p * .pi))   // 1 → 0 → 1
        ZStack {
            back.opacity(p < 0.5 ? 1 : 0)
            front.opacity(p < 0.5 ? 0 : 1)
        }.scaleEffect(x: max(0.001, x), y: 1)
    }
}

struct IntroSceneView: View {
    let kind: IntroKind
    let index: Int
    let t: Double
    let reduce: Bool

    var body: some View {
        ZStack {
            switch (kind, index) {
            case (.friends, 0): FShoot(t: t)
            case (.friends, 1): FSleep(t: t)
            case (.friends, 2): FOpen(t: t)
            case (.friends, 3): FConnect(t: t)
            case (.trip, 0): TPrint(t: t)
            case (.trip, 1): TBoard(t: t)
            case (.trip, 2): TShare(t: t)
            case (.trip, _): TDevelop(t: t)
            case (.mondo, 0): MLook(t: t)
            case (.mondo, 1): MMatch(t: t)
            case (.mondo, 2): MRank(t: t)
            default: MUnlock(t: t)
            }
        }
        .frame(width: 390, height: 440)
    }
}

// MARK: - Friends

private struct FShoot: View {
    let t: Double
    private let spots: [(CGFloat, CGFloat, String)] = [(-99, -99, "れな"), (99, -99, "そら"), (-99, 99, "みお"), (99, 99, "ここ")]
    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { n in
                Circle().strokeBorder(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
                    .frame(width: n == 0 ? 180 : 280, height: n == 0 ? 180 : 280)
                    .rotationEffect(.degrees(t * (n == 0 ? 360.0 / 18 : -360.0 / 30)))
            }
            ForEach(0..<4, id: \.self) { i in
                let s = spots[i]
                let a = 0.55 + 0.5 * Double(i)
                IAvatar(name: s.2, i: i, d: 58).scaleEffect(M.pop(t, 0.15 + 0.08 * Double(i))).offset(x: s.0, y: s.1)
                shot(a, i, x: s.0, y: s.1, r: 29, up: s.1 > 0 ? -1 : -1)
            }
            IAvatar(name: "ゆ", i: 0, d: 88, ring: true).scaleEffect(M.pop(t, 0.05))
            shot(2.3, 4, x: 0, y: 0, r: 44, up: -1)
        }
        .position(x: 195, y: 220)
    }

    private func shot(_ a: Double, _ i: Int, x: CGFloat, y: CGFloat, r: CGFloat, up: CGFloat) -> some View {
        let u = M.clamp((t - a) / 0.5)
        let life = M.clamp((t - a) / 0.9)
        return ZStack {
            Circle().stroke(.white.opacity(0.9 * (1 - u)), lineWidth: 3).frame(width: r * 2, height: r * 2).scaleEffect(1 + 0.9 * u).opacity(t >= a && u < 1 ? 1 : 0)
            ICheki(i: i, w: 44).rotationEffect(.degrees(i % 2 == 0 ? -8 : 8))
                .offset(y: -r - 10 - 44 * M.ease(t, a, 0.5)).opacity(t >= a ? (1 - life * life) : 0)
        }.offset(x: x, y: y)
    }
}

private struct FSleep: View {
    let t: Double
    var body: some View {
        ZStack {
            // 上から 暗く
            LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom).frame(height: 300).frame(maxHeight: .infinity, alignment: .top)
                .opacity(M.ease(t, 0.2, 0.7))
            Moon().fill(lime).frame(width: 46, height: 46).position(x: 330, y: 50).opacity(M.ease(t, 0.3, 0.5)).scaleEffect(0.6 + 0.4 * M.ease(t, 0.3, 0.5))
            // 時計 23:59 → 0:00
            let p = M.ease(t, 0.8, 0.4)
            ZStack {
                Text("23:59").offset(y: -CGFloat(p) * 34).opacity(1 - p)
                Text("0:00").offset(y: CGFloat(1 - p) * 34).opacity(p)
            }
            .font(LF.mono(34)).foregroundStyle(lime).frame(height: 44).clipped().position(x: 195, y: 70)
            // 3枚の チェキが 集まり、1枚ずつ 裏がえる
            ForEach(0..<3, id: \.self) { i in
                let g = M.ease(t, 0.3, 0.9)
                let sx = CGFloat([-130, 0, 130][i]), sy: CGFloat = [90, 150, 90][i]
                let f = M.clamp((t - (1.35 + 0.15 * Double(i))) / 0.3)
                IFlip(p: f, front: ICheki(i: i, w: 60), back: IChekiBack(w: 60))
                    .rotationEffect(.degrees(Double([-9, 4, 8][i]) * (1 - g * 0.4)))
                    .offset(x: sx * CGFloat(1 - g) + CGFloat([-10, 0, 10][i]) * CGFloat(g), y: 40 + (sy - 40) * CGFloat(1 - g))
                    .opacity(M.ease(t, 0.1 + 0.1 * Double(i), 0.3))
            }
        }
    }
}

private struct Moon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(ellipseIn: r)
        p = p.subtracting(Path(ellipseIn: r.offsetBy(dx: r.width * 0.3, dy: -r.height * 0.1)))
        return p
    }
}

private struct FOpen: View {
    let t: Double
    var body: some View {
        ZStack {
            Text("9:00").font(LF.mono(34)).foregroundStyle(lime).position(x: 195, y: 44).opacity(M.ease(t, 0, 0.4))
            // 地平線から ライムの 朝日
            ZStack {
                Circle().fill(RadialGradient(colors: [lime, lime.opacity(0.0)], center: .center, startRadius: 20, endRadius: 150)).frame(width: 300, height: 300).opacity(0.7)
                Circle().fill(lime).frame(width: 110, height: 110)
            }
            .offset(y: CGFloat(1 - M.ease(t, 0.2, 0.9)) * 150).position(x: 195, y: 250)
            .mask(Rectangle().frame(width: 390, height: 270).position(x: 195, y: 135).offset(y: 40))
            Rectangle().fill(.white.opacity(0.16)).frame(width: 390, height: 1.5).position(x: 195, y: 306)
            // 扇に ひらく 3枚 → めくれて 表 → 現像
            ForEach(0..<3, id: \.self) { i in
                let open = M.ease(t, 0.7, 0.6)
                let f = M.clamp((t - (1.2 + 0.2 * Double(i))) / 0.35)
                let dev = M.ease(t, 1.5 + 0.2 * Double(i), 0.6)
                IFlip(p: f, front: ZStack {
                    ICheki(i: i, w: 78).blur(radius: 6).saturation(0).opacity(1 - dev)
                    ICheki(i: i, w: 78).opacity(dev)
                }, back: IChekiBack(w: 78))
                .rotationEffect(.degrees(Double([-14, 0, 14][i]) * open), anchor: .bottom)
                .offset(x: CGFloat([-80, 0, 80][i]) * CGFloat(open), y: 20 + CGFloat(1 - open) * 20)
                .opacity(M.ease(t, 0.6, 0.3))
            }
            ForEach(0..<3, id: \.self) { i in
                let a = 2.4 + 0.12 * Double(i)
                Image(systemName: "heart.fill").font(.system(size: 22)).foregroundStyle(lime)
                    .offset(x: CGFloat([-70, 0, 70][i]), y: 130 - 120 * CGFloat(M.ease(t, a, 1.0)))
                    .opacity(t >= a ? 1 - M.clamp((t - a) / 1.0) * 0.6 : 0)
            }
        }
    }
}

private struct FConnect: View {
    let t: Double
    private let text = Array("@yui_k")
    var body: some View {
        let n = min(text.count, max(0, Int((t - 0.1) / 0.15)))
        ZStack {
            // さがす 欄
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                Text(String(text.prefix(n))).font(LF.mono(17)).foregroundStyle(.white)
                Rectangle().fill(lime).frame(width: 2, height: 20).opacity(Int(t * 2.4) % 2 == 0 && t < 1.1 ? 1 : 0)
                Spacer()
            }
            .padding(.horizontal, 16).frame(width: 310, height: 50)
            .background(RoundedRectangle(cornerRadius: 25).fill(Color(hex: "1C1C1F")))
            .position(x: 195, y: 50)
            // 結果の カード
            let c = M.pop(t, 1.05, 0.4)
            HStack(spacing: 12) {
                IAvatar(name: "ゆ", i: 1, d: 46)
                VStack(alignment: .leading, spacing: 2) { Text("ゆい").font(LF.inter(800, 16)).foregroundStyle(.white); Text("@yui_k").font(LF.mono(12)).foregroundStyle(.white.opacity(0.55)) }
                Spacer()
                let ok = t >= 2.0
                ZStack { Circle().fill(lime); Image(systemName: ok ? "checkmark" : "plus").font(.system(size: 15, weight: .heavy)).foregroundStyle(.black) }
                    .frame(width: 36, height: 36).scaleEffect(t > 1.95 && t < 2.15 ? 0.85 : 1)
            }
            .padding(.horizontal, 14).frame(width: 310, height: 72)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: "1C1C1F")))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.08)))
            .scaleEffect(c).opacity(M.clamp(c * 3)).position(x: 195, y: 140)
            // ライムの 点線が カードから 下の 自分へ
            Path { p in p.move(to: CGPoint(x: 195, y: 178)); p.addLine(to: CGPoint(x: 195, y: 330)) }
                .trim(from: 0, to: M.ease(t, 2.0, 0.6))
                .stroke(lime, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 9], dashPhase: -t * 30))
            // 自分
            ZStack {
                ForEach(0..<2, id: \.self) { n in
                    let u = M.clamp((t - 2.7 - 0.25 * Double(n)) / 0.7)
                    Circle().stroke(lime.opacity(t >= 2.7 + 0.25 * Double(n) ? 0.8 * (1 - u) : 0), lineWidth: 3).frame(width: 88, height: 88).scaleEffect(1 + 0.9 * u)
                }
                IAvatar(name: "ゆ", i: 0, d: 88, ring: true)
            }.position(x: 195, y: 372)
        }
    }
}

// MARK: - Trip

/// 小さい パス(幅 266)。プリンターの 口から 6段で 出る
private struct MiniPass: View {
    let t: Double
    private let link = "https://lattag.app/t/meadow95"
    var body: some View {
        let step = min(6, Int(t / (1.3 / 6)))
        let passH: CGFloat = 270
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(t >= 2.5 ? lime : Color(hex: "FF7A2F")).frame(width: 6, height: 6)
                Text(t >= 2.5 ? "LATTAG" : "PRINTING").font(LF.mono(8)).tracking(2).foregroundStyle(Color(hex: "6E6E75"))
            }.frame(width: 284, height: 22).background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: "1A1A1D"))).zIndex(2)
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        IntroPhoto.fill(0)
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("京都 2泊3日").font(LF.inter(900, 22)).foregroundStyle(.white)
                            Text("NOV 18 → NOV 20").font(LF.mono(9)).foregroundStyle(.white.opacity(0.8))
                        }.padding(12)
                    }.frame(height: 150)
                    HStack(spacing: 10) {
                        Group { if let m = QRMatrix.make(link) { StyledQRView(matrix: m, progress: M.clamp((t - 1.3) / 0.8), side: 78) } else { Color.clear } }
                            .frame(width: 78, height: 78).padding(4).background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "FBFAF6")))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KEY").font(LF.mono(7)).tracking(1.5).foregroundStyle(Color(hex: "8A857B"))
                            (Text("#meadow").foregroundColor(Color(hex: "0B0C0D")) + Text("95").foregroundColor(Color(hex: "5E8A12"))).font(LF.inter(900, 17))
                        }
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 12).frame(height: 100).background(Color(hex: "F4F1EA"))
                }
                .frame(width: 266, height: 250).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .offset(y: -passH * CGFloat(1 - Double(step) / 6) )
            }
            .frame(width: 266, height: 270, alignment: .top).clipped()
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 0) { Text("ISSUED").font(LF.mono(7)).tracking(1.4); Text("NOV 19").font(LF.inter(900, 11)) }
                    .foregroundStyle(lime).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(lime, lineWidth: 2))
                    .rotationEffect(.degrees(-14)).scaleEffect(t >= 2.1 ? 1 + 1.2 * (1 - M.pop(t, 2.1, 0.3)) : 1).opacity(t >= 2.1 ? 1 : 0).padding(.top, 70).padding(.trailing, 6)
            }
        }
    }
}

private struct TPrint: View {
    let t: Double
    var body: some View { MiniPass(t: t).position(x: 195, y: 160) }
}

private struct TBoard: View {
    let t: Double
    private let names = ["ゆい", "れな", "そら", "みお", "ここ", "りく"]
    // 座席の 中心(4列 × 2段 ・ 通路)
    private func seat(_ i: Int) -> CGPoint {
        let col = i % 4, row = i / 4
        let xs: [CGFloat] = [-114, -38, 38, 114]
        return CGPoint(x: 195 + xs[col] + (col < 2 ? -6 : 6), y: 270 + CGFloat(row) * 80)
    }
    var body: some View {
        let landed = (0..<6).filter { i in i == 0 || t >= 0.9 + 0.34 * Double(i) + 0.34 }.count
        ZStack {
            // メッセージの 吹き出し(左上)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5).fill(IntroPhoto.fill(0)).frame(width: 34, height: 40)
                VStack(alignment: .leading, spacing: 1) { Text("Trip の 招待").font(LF.inter(800, 12)).foregroundStyle(.white); Text("lattag.app/t/meadow95").font(LF.inter(600, 10)).foregroundStyle(.white.opacity(0.6)) }
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "2A2A2E")))
            .position(x: 140, y: 60).offset(x: CGFloat(1 - M.ease(t, 0, 0.45)) * -40).opacity(M.ease(t, 0, 0.3)).scaleEffect(0.9 + 0.1 * M.pop(t, 0.1))
            // 座席表
            Text("FRONT").font(LF.mono(8)).tracking(2.4).foregroundStyle(Color(hex: "4A4A50")).position(x: 195, y: 218)
            ForEach(0..<8, id: \.self) { i in
                let on = i == 0 || t >= 0.9 + 0.34 * Double(i) + 0.34
                let p = seat(i)
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? lime.opacity(0.1) : Color(hex: "19191C"))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? lime.opacity(0.5) : .white.opacity(0.06), lineWidth: 1.5))
                    .frame(width: 64, height: 66).position(p)
                if i < 6 && on { IAvatar(name: names[i], i: i, d: 36).position(p).scaleEffect(i == 0 ? 1 : 1).transition(.identity) }
                else if !on { Circle().strokeBorder(lime.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 36, height: 36).position(p) }
            }
            // 吹き出しから 飛ぶ 人(弧)
            ForEach(1..<6, id: \.self) { i in
                let a = 0.9 + 0.34 * Double(i), p = M.clamp((t - a) / 0.34)
                let to = seat(i), from = CGPoint(x: 140, y: 60)
                let x = from.x + (to.x - from.x) * p, y = from.y + (to.y - from.y) * p - sin(p * .pi) * 60
                IAvatar(name: names[i], i: i, d: 36).position(x: x, y: y).opacity(p > 0 && p < 1 ? 1 : 0)
            }
            Text("\(landed + (landed > 0 ? 0 : 1)) / 8").font(LF.mono(12)).foregroundStyle(lime).tracking(1.5).position(x: 195, y: 392)
                .contentTransition(.numericText())
        }
    }
}

private struct TShare: View {
    let t: Double
    var body: some View {
        let drops = (0..<6).filter { t >= 0.5 + 0.4 * Double($0) + 0.4 }.count
        ZStack {
            HStack(spacing: 10) { ForEach(0..<5, id: \.self) { i in IAvatar(name: ["ゆ", "れ", "そ", "み", "こ"][i], i: i, d: 44).scaleEffect(M.pop(t, 0.05 * Double(i))) } }.position(x: 195, y: 36)
            VStack(spacing: 0) {
                Text("\(23 - drops)").font(LF.serif(128, italic: true)).foregroundStyle(lime).contentTransition(.numericText(countsDown: true)).frame(height: 130)
                Text("LEFT TODAY").font(LF.mono(10)).tracking(3).foregroundStyle(.white.opacity(0.6))
            }.position(x: 195, y: 190)
            // フィルムの 帯
            ZStack {
                Rectangle().fill(Color(hex: "1A1A1D"))
                HStack(spacing: 14) { ForEach(0..<18, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(Color(hex: "0B0B0C")).frame(width: 8, height: 6) } }.offset(y: -30)
                HStack(spacing: 14) { ForEach(0..<18, id: \.self) { _ in RoundedRectangle(cornerRadius: 2).fill(Color(hex: "0B0B0C")).frame(width: 8, height: 6) } }.offset(y: 30)
                HStack(spacing: 6) { ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4).fill(IntroPhoto.fill(i)).frame(width: 48, height: 40).opacity(i < drops ? 1 : 0.0)
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.12)))
                } }
            }.frame(width: 390, height: 76).position(x: 195, y: 360)
            // 落ちる チェキ
            ForEach(0..<6, id: \.self) { i in
                let a = 0.5 + 0.4 * Double(i), p = M.clamp((t - a) / 0.4)
                ICheki(i: i, w: 34).offset(x: CGFloat(i - 3) * 14 + 7, y: 0).position(x: 195 + CGFloat(i - 3) * 40 + 20, y: 36 + 320 * CGFloat(p * p)).opacity(p > 0 && p < 1 ? 1 : 0)
            }
        }
    }
}

private struct TDevelop: View {
    let t: Double
    var body: some View {
        ZStack {
            Text("AM 9:00").font(LF.mono(20)).tracking(2).foregroundStyle(lime).position(x: 195, y: 36).opacity(M.ease(t, 0, 0.4))
            // 朝日
            Circle().fill(RadialGradient(colors: [lime.opacity(0.9), lime.opacity(0)], center: .center, startRadius: 6, endRadius: 120)).frame(width: 240, height: 240)
                .position(x: 195, y: 330 - 90 * CGFloat(M.ease(t, 0.3, 1.0))).opacity(0.7)
                .mask(Rectangle().frame(width: 390, height: 300).position(x: 195, y: 150).offset(y: 120))
            // 3 × 3 の こま
            ForEach(0..<9, id: \.self) { i in
                let r = i / 3, c = i % 3
                let d = hypot(Double(r - 1), Double(c - 1))
                let dev = M.ease(t, 1.0 + 0.18 * d, 0.5)
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: "161618"))
                    HV72HashShape().fill(lime.opacity(0.5)).frame(width: 22, height: 22).opacity(1 - dev)
                    RoundedRectangle(cornerRadius: 8).fill(IntroPhoto.fill(i)).opacity(dev)
                }
                .frame(width: 84, height: 84).scaleEffect(0.96 + 0.04 * dev)
                .position(x: 195 + CGFloat(c - 1) * 92, y: 200 + CGFloat(r - 1) * 92)
                .opacity(M.ease(t, 0.1 + 0.03 * Double(i), 0.3))
            }
            Text("DAY 1").font(LF.mono(13)).tracking(2).foregroundStyle(lime).padding(.horizontal, 12).padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(lime, lineWidth: 2.5))
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.6)))
                .rotationEffect(.degrees(-12)).scaleEffect(t >= 2.45 ? 1 + 1.2 * (1 - M.pop(t, 2.45, 0.3)) : 1).opacity(t >= 2.45 ? 1 : 0).position(x: 290, y: 330)
        }
    }
}

// MARK: - Mondo

private struct DotGlobeTexture: View {
    var body: some View {
        Canvas { c, s in
            let cols = 52, rows = 26
            for r in 0..<rows { for q in 0..<cols {
                // 陸っぽい 偏り(説明用・ざっくり)
                let h = sin(Double(q) * 0.7) * cos(Double(r) * 0.9) + sin(Double(q + r) * 0.31)
                guard h > -0.15 else { continue }
                let x = (Double(q) + 0.5) * s.width / Double(cols), y = (Double(r) + 0.5) * s.height / Double(rows)
                c.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(lime.opacity(0.75)))
            } }
        }.frame(width: 520, height: 260).drawingGroup()
    }
}

private struct MLook: View {
    let t: Double
    private let pins: [(CGFloat, CGFloat, String, Double)] = [(-70, -50, "TOKYO", 0.5), (40, -70, "PARIS", 0.9), (80, 10, "SEOUL", 1.3), (-30, 50, "LIMA", 1.7), (10, -10, "NYC", 2.1)]
    var body: some View {
        ZStack {
            ZStack {
                let off = CGFloat((t / 9).truncatingRemainder(dividingBy: 1)) * 520
                HStack(spacing: 0) { DotGlobeTexture(); DotGlobeTexture() }.frame(width: 1040).offset(x: -off - 260 + 260)
                    .frame(width: 260, height: 260, alignment: .leading)
                Circle().fill(RadialGradient(colors: [.clear, .black.opacity(0.85)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 60, endRadius: 190))
            }
            .frame(width: 260, height: 260).clipShape(Circle()).overlay(Circle().strokeBorder(lime.opacity(0.25)))
            Ellipse().strokeBorder(.white.opacity(0.18), lineWidth: 1).frame(width: 340, height: 90).rotationEffect(.degrees(-20))
            ForEach(0..<5, id: \.self) { i in
                let p = pins[i], a = p.3
                ZStack {
                    Circle().stroke(lime, lineWidth: 2).frame(width: 14, height: 14).scaleEffect(1 + (t - a).truncatingRemainder(dividingBy: 1.2) * 0.8).opacity(t >= a ? max(0, 1 - (t - a).truncatingRemainder(dividingBy: 1.2)) : 0)
                    Circle().fill(lime).frame(width: 9, height: 9).scaleEffect(M.pop(t, a, 0.3))
                    VStack(spacing: 2) {
                        ICheki(i: i, w: 34)
                        Text(p.2).font(LF.mono(8.5)).foregroundStyle(.white.opacity(0.8))
                    }.offset(y: -42).scaleEffect(M.pop(t, a + 0.1, 0.4)).opacity(t >= a + 0.1 ? 1 : 0)
                }.offset(x: p.0, y: p.1)
            }
        }.position(x: 195, y: 230)
    }
}

private struct MMatch: View {
    let t: Double
    private let towns = ["TOKYO", "PARIS", "SEOUL", "LIMA", "OSLO", "CAIRO"]
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let a = 0.45 + 0.25 * Double(i)
                let ang = Double(i) / 6 * 2 * .pi - .pi / 2
                let rx = 125 * cos(ang), ry = 125 * sin(ang)
                let p = M.ease(t, a, 0.6)
                Path { q in q.move(to: CGPoint(x: 195, y: 220)); q.addLine(to: CGPoint(x: 195 + rx, y: 220 + ry)) }
                    .trim(from: 0, to: M.ease(t, a + 0.1, 0.5)).stroke(lime.opacity(0.5), lineWidth: 1.5)
                VStack(spacing: 2) { ICheki(i: i, w: 46); Text(towns[i]).font(LF.mono(8)).foregroundStyle(.white.opacity(0.7)) }
                    .rotationEffect(.degrees((1 - p) * 220))
                    .position(x: 195 + rx * p + (1 - p) * (rx > 0 ? 220 : -220), y: 220 + ry * p + (1 - p) * (ry > 0 ? 150 : -150))
                    .opacity(M.clamp(p * 3))
            }
            let pulse = t > 2.1 ? 1 + 0.06 * sin((t - 2.1) * 6) : 1.0
            Text("#夕焼け").font(LF.inter(900, 22)).foregroundStyle(lime).shadow(color: lime.opacity(0.8), radius: 10)
                .scaleEffect(M.pop(t, 0.15) * pulse).position(x: 195, y: 220)
        }
    }
}

private struct MRank: View {
    let t: Double
    private let tags = ["#夕焼け", "#帰り道", "#雨の日", "#部活", "#いい匂い"]
    private let finals: [Double] = [480, 470, 352, 301, 244]
    var body: some View {
        let swap = M.ease(t, 1.9, 0.4)
        let count = M.ease(t, 0.2, 1.6)
        ZStack(alignment: .topLeading) {
            ForEach(0..<5, id: \.self) { i in
                // 2位(i=1)が 1位(i=0)を 追いこす
                let v: Double = i == 1 ? finals[1] * count + 26 * swap : finals[i] * count
                let rank: Double = i == 0 ? swap : (i == 1 ? 1 - swap : Double(i))
                let top = (i == 1 && swap > 0.5) || (i == 0 && swap <= 0.5)
                HStack(spacing: 10) {
                    Text("\(Int(rank.rounded()) + 1)").font(LF.inter(900, 20)).foregroundStyle(top ? lime : .white.opacity(0.5)).frame(width: 24)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(tags[i]).font(LF.inter(800, 15)).foregroundStyle(.white)
                        GeometryReader { g in Capsule().fill(.white.opacity(0.1)).overlay(alignment: .leading) { Capsule().fill(lime).frame(width: g.size.width * v / 520) } }.frame(height: 5)
                    }
                    Text("\(Int(v))").font(LF.mono(13)).foregroundStyle(.white.opacity(0.7)).frame(width: 44, alignment: .trailing).contentTransition(.numericText())
                }
                .padding(.horizontal, 14).frame(width: 340, height: 62)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: "161618")))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(top ? lime : .white.opacity(0.06), lineWidth: top ? 2 : 1))
                .offset(x: 25, y: 10 + CGFloat(rank) * 70)
                .opacity(M.ease(t, 0.05 * Double(i), 0.3))
            }
        }
        .frame(width: 390, height: 440, alignment: .topLeading)
    }
}

private struct MUnlock: View {
    let t: Double
    var body: some View {
        let open = M.ease(t, 1.75, 0.4)
        ZStack {
            // 2 × 2 の ぼけた 写真 → くっきり
            ForEach(0..<4, id: \.self) { i in
                ZStack {
                    IntroPhoto.fill(i).blur(radius: 14).opacity(1 - open)
                    IntroPhoto.fill(i).opacity(open)
                }
                .frame(width: 140, height: 120).clipShape(RoundedRectangle(cornerRadius: 14))
                .position(x: 195 + CGFloat(i % 2 == 0 ? -75 : 75), y: 100 + CGFloat(i / 2) * 130)
            }
            // かぎ
            Image(systemName: open > 0.6 ? "lock.open.fill" : "lock.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 6).scaleEffect(1 + 0.3 * open).opacity(1 - open).position(x: 195, y: 165)
            // Lattag の アイコン(撮影ボタン)に ライムが 下から たまる
            ShutterIconV94(progress: M.clamp((t - 0.4) / 1.2), holding: t > 0.4 && t < 1.7, video: false, recording: false, dead: false, late: false, snapToken: 0)
                .frame(width: 84, height: 84).position(x: 195, y: 360)
            Color.white.opacity(t >= 1.7 ? max(0, 0.85 * (1 - (t - 1.7) / 0.35)) : 0).frame(width: 390, height: 440).allowsHitTesting(false)
        }
    }
}
