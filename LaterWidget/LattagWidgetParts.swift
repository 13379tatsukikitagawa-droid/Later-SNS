import SwiftUI
import WidgetKit

// v96:ウィジェット 共通の 部品(アプリアイコン ・ こまの バー ・ レンズ ・ # の 帯 ・ 時間の 文字)

/// アプリアイコン(角丸 22.4% ・ ライムの 地 ・ 黒い # + レンズ)
struct WIcon: View {
    var size: CGFloat = 20
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.224, style: .continuous).fill(WColor.lime)
            Image(systemName: "number").font(.system(size: size * 0.58, weight: .black)).foregroundStyle(Color(hex6: 0x0B0B0C))
        }.frame(width: size, height: size)
    }
}

/// 3本の バー(のこりの こま = 明るい)
struct WBars: View {
    var remaining: Int
    var limit = 3
    var h: CGFloat = 12
    var w: CGFloat = 7
    var on: Color = WColor.lime
    var off: Color = .white.opacity(0.28)
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<limit, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2.5).fill(i < remaining ? on : off.opacity(0.0001)).frame(width: w, height: h)
                    .overlay(RoundedRectangle(cornerRadius: 2.5).strokeBorder(off, lineWidth: i < remaining ? 0 : 1.2))
            }
        }
    }
}

/// 時間の 文字(秒まで 自動で 動く)。`Text(timerInterval:)`
struct WTimer: View {
    let from: Date
    let to: Date
    var body: some View {
        Text(timerInterval: from...max(to, from.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: true)
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
    }
}

/// # の 帯(S1 の 地)。たて 2本 幅 30 ・ よこ 2本 高さ 28
struct WHashBand: View {
    var color: Color
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                ForEach([w * 0.30, w * 0.70], id: \.self) { x in Rectangle().fill(color).frame(width: 30, height: h).position(x: x, y: h / 2) }
                ForEach([h * 0.30, h * 0.70], id: \.self) { y in Rectangle().fill(color).frame(width: w, height: 28).position(x: w / 2, y: y) }
            }
        }
    }
}

/// レンズ(104)。外に 点線の 輪 + 字の 輪 + まんなかの # ボタン
struct WLens: View {
    var done: Bool
    var size: CGFloat = 104
    private let text = Array("LATTAG • 3 SHOTS A DAY • OPENS 9:00 • ")
    var body: some View {
        ZStack {
            Circle().fill(Color(hex6: 0x0B0B0C))
            Circle().strokeBorder(WColor.lime.opacity(done ? 0.25 : 0.9), style: StrokeStyle(lineWidth: 2, dash: [3, 4])).padding(2)
            ForEach(0..<text.count, id: \.self) { i in
                Text(String(text[i])).font(WFont.mono(7)).foregroundStyle(done ? .white.opacity(0.7) : .white)
                    .offset(y: -(size / 2 - 11))
                    .rotationEffect(.degrees(Double(i) / Double(text.count) * 360))
            }
            ZStack {
                Circle().fill(done ? Color(hex6: 0x16170F) : WColor.lime).frame(width: size * 0.38, height: size * 0.38)
                Circle().strokeBorder(done ? WColor.lime.opacity(0.4) : WColor.lime.opacity(0.0), lineWidth: 2).frame(width: size * 0.42, height: size * 0.42)
                Image(systemName: "number").font(.system(size: size * 0.2, weight: .black)).foregroundStyle(done ? WColor.lime : Color(hex6: 0x0B0B0C))
            }
        }
        .frame(width: size, height: size)
    }
}

/// 3つの こま(S2 ・ ミルク色の ぼかし / まだは 線)
struct WFrameRow: View {
    let model: WidgetModel
    var w: CGFloat = 38
    var h: CGFloat = 46
    var limeBase = true
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(0..<model.limit), id: \.self) { i in cell(i) }
        }
    }

    @ViewBuilder private func cell(_ i: Int) -> some View {
        let taken = i < model.shots
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack {
            if taken {
                shape.fill(WColor.paper.opacity(0.9))
                if let img = WImage.load(model.shotBlurs[safeW: i]) {
                    Image(uiImage: img).resizable().widgetAccentedRenderingMode(.desaturated).scaledToFill()
                        .frame(width: w, height: h).clipShape(shape).opacity(0.9)
                }
            } else {
                shape.fill(limeBase ? Color.black.opacity(0.08) : Color.white.opacity(0.06))
                shape.strokeBorder(limeBase ? Color.black.opacity(0.35) : Color.white.opacity(0.3), lineWidth: 1.2)
            }
        }.frame(width: w, height: h)
    }
}

extension Array {
    subscript(safeW i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// 時刻 → "9:20"(残り 時間)
enum WTimeText {
    static func hm(_ seconds: TimeInterval) -> String { let s = max(0, Int(seconds)); return "\(s / 3600):" + String(format: "%02d", (s % 3600) / 60) }
}
