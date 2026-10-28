import SwiftUI
import WidgetKit

// ロック画面(accessory 系)の部品。アプリの「ウィジェットの置き方」でも、同じ部品を表示する

/// accessory 系は白だけ(vibrant)。色は使わず、不透明度の差(1.0 / 0.6 / 0.28)で表す
enum LaterAccessoryOpacity {
    static let full = 1.0
    static let mid = 0.6
    static let dim = 0.28
}

/// 丸(今日):点の輪(36個)+中央のしるし。U はのこり時間で点が減る / D・R は現像の進みで点が増える
struct LaterTodayCircle: View {
    let state: LaterWidgetState

    var body: some View {
        let lit: Int = {
            switch state.phase {
            case .U: return Int((36 * (1 - state.dayProgress)).rounded(.up))
            case .R, .D: return Int((36 * state.developProgress).rounded(.down))
            case .M: return 0
            }
        }()
        ZStack {
            LaterDotRing(count: 36, lit: lit, diameter: 54, dot: 2.6, litColor: .white, dimOpacity: LaterAccessoryOpacity.dim)
            LaterMark(phase: state.phase, size: 18)
        }
        .widgetAccentable()
        .accessibilityElement()
        .accessibilityLabel(LaterWidgetCopy.title(state.phase))
    }
}

/// 丸(昨日):封をされた円盤 → ひらけるとき光の筋
struct LaterYesterdayCircle: View {
    let state: LaterWidgetState

    var body: some View {
        let open = state.phase == .R
        ZStack {
            if open {
                // 光の筋
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(i % 2 == 0 ? LaterAccessoryOpacity.full : LaterAccessoryOpacity.mid))
                        .frame(width: 1.5, height: 6)
                        .offset(y: -24)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            Circle()
                .fill(.white.opacity(state.hasYesterday ? (open ? LaterAccessoryOpacity.full : LaterAccessoryOpacity.mid) : LaterAccessoryOpacity.dim))
                .frame(width: 26, height: 26)
            Circle()
                .strokeBorder(.white.opacity(open ? LaterAccessoryOpacity.full : LaterAccessoryOpacity.mid),
                              style: StrokeStyle(lineWidth: open ? 2 : 1.2, dash: open ? [] : [2.5, 2.5]))
                .frame(width: 36, height: 36)
        }
        .widgetAccentable()
        .accessibilityElement()
        .accessibilityLabel(open ? "昨日が、ひらけます" : (state.hasYesterday ? "昨日・封をされています" : "昨日はありません"))
    }
}

/// 丸(7日):7つの点の輪(撮った日だけ点が灯る)
struct LaterWeekCircle: View {
    let state: LaterWidgetState

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let shot = state.week.indices.contains(i) && state.week[i]
                Circle()
                    .fill(.white.opacity(shot ? LaterAccessoryOpacity.full : LaterAccessoryOpacity.dim))
                    .frame(width: i == 6 ? 7 : 5.5, height: i == 6 ? 7 : 5.5)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(i) * 360 / 7))
            }
            Text("7")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .opacity(0.9)
        }
        .widgetAccentable()
        .accessibilityElement()
        .accessibilityLabel("この7日で、\(state.week.filter { $0 }.count)日撮りました")
    }
}

/// 中央のしるし:U は月(円)、R・D は円盤(輪つき)、M は細い輪
struct LaterMark: View {
    let phase: LaterWidgetPhase
    let size: CGFloat

    var body: some View {
        switch phase {
        case .U:
            Circle().fill(.white).frame(width: size, height: size)
        case .R, .D:
            ZStack {
                Circle().fill(.white.opacity(LaterAccessoryOpacity.mid)).frame(width: size, height: size)
                Circle().strokeBorder(.white, lineWidth: 1.5).frame(width: size + 6, height: size + 6)
            }
        case .M:
            Circle().strokeBorder(.white.opacity(LaterAccessoryOpacity.mid), lineWidth: 1.2).frame(width: size, height: size)
        }
    }
}

/// 長方形:左にしるし、右に2行、下に細い時間のすじ(U は 9:00 → 24:00、D は 撮影 → 9:00)
struct LaterRectangularView: View {
    let state: LaterWidgetState

    var body: some View {
        let progress: Double = {
            switch state.phase {
            case .U: return state.dayProgress
            case .R, .D: return state.developProgress
            case .M: return 1
            }
        }()
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                LaterMark(phase: state.phase, size: 14)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(LaterWidgetCopy.title(state.phase, short: true))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Group {
                        if state.phase == .U {
                            Text("消灯まで \(Text(timerInterval: state.now...state.lightsOut, countsDown: true, showsHours: true))")
                        } else {
                            Text(LaterWidgetCopy.sub(state))
                        }
                    }
                    // 細い字は溶けやすい:semibold・不透明度 0.9
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .opacity(0.9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(LaterAccessoryOpacity.dim))
                    Capsule().fill(.white).frame(width: max(2, proxy.size.width * progress))
                }
            }
            .frame(height: 2)
        }
        .widgetAccentable()
    }
}

/// 1行:しるし + 文字
struct LaterInlineView: View {
    let state: LaterWidgetState

    var body: some View {
        content
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .monospacedDigit()
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .U:
            Label {
                Text("消灯まで \(Text(timerInterval: state.now...state.lightsOut, countsDown: true, showsHours: true))")
            } icon: {
                Image(systemName: "moon.fill")
            }
        case .R:
            Label("昨日が、ひらけます", systemImage: "circle.dashed")
        case .D:
            Label("現像中 \(state.developPercent)%", systemImage: "circle.circle")
        case .M:
            Label("消灯しました", systemImage: "moon.zzz")
        }
    }
}

