import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - ライブアクティビティ(撮った直後に始め、最大8時間。終わったあとはウィジェットが引きつぐ)

struct LaterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LaterActivityAttributes.self) { context in
            LaterActivityBanner(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(LaterWidgetShared.deepLink(context.state.isReady ? .R : .D))
        } dynamicIsland: { context in
            let ready = context.state.isReady
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LaterActivityDisc(ready: ready, size: 34)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.attributes.developAt, countsDown: true, showsHours: true)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(ready ? "昨日が、ひらけます" : "現像中")
                        .font(.system(size: 15, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(timerInterval: context.attributes.shotAt...context.attributes.developAt, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(LaterWidgetPalette.orange)
                        if ready { LaterOpenYesterdayLink() }
                    }
                }
            } compactLeading: {
                LaterActivityDisc(ready: ready, size: 16)
            } compactTrailing: {
                Text(timerInterval: Date()...context.attributes.developAt, countsDown: true, showsHours: true)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 50)
            } minimal: {
                LaterActivityDisc(ready: ready, size: 16)
            }
            .widgetURL(LaterWidgetShared.deepLink(ready ? .R : .D))
            .keylineTint(LaterWidgetPalette.orange)
        }
    }
}

extension LaterActivityAttributes.ContentState {
    var isReady: Bool { hasYesterday && !openedYesterday }
}

/// ロック画面バナー:写真は出さない。時刻と現像の進みだけ
struct LaterActivityBanner: View {
    let attributes: LaterActivityAttributes
    let state: LaterActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            LaterActivityDisc(ready: state.isReady, size: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(state.isReady ? "昨日が、ひらけます" : "現像中")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                // 大きな数字:あしたの 9:00 までの残り(自動更新)。semibold・丸ゴシック 34pt
                Text(timerInterval: Date()...attributes.developAt, countsDown: true, showsHours: true)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-0.03 * 34)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ProgressView(timerInterval: attributes.shotAt...attributes.developAt, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(LaterWidgetPalette.orange)
                Text("あしたの朝 9:00")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
            }
            if state.isReady {
                LaterOpenYesterdayLink()
            }
        }
        .padding(16)
    }
}

/// 「昨日をひらく」:タップでアプリへ(later://widget/R)
struct LaterOpenYesterdayLink: View {
    var body: some View {
        Link(destination: LaterWidgetShared.deepLink(.R)) {
            Text("昨日をひらく")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(LaterWidgetPalette.orange))
        }
    }
}

/// 円盤のしるし(R はオレンジの実線の封、D はうすい輪)
struct LaterActivityDisc: View {
    let ready: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [LaterWidgetPalette.orange, Color(red: 0.45, green: 0.3, blue: 0.7), .black],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
                .frame(width: size * 0.8, height: size * 0.8)
            Circle()
                .strokeBorder(ready ? LaterWidgetPalette.orange : .white.opacity(0.4),
                              style: StrokeStyle(lineWidth: ready ? 1.5 : 1, dash: ready ? [] : [2, 2]))
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - コントロール(iOS 18):左「今日を撮る」/ 右「昨日をひらく」

struct LaterShootControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LaterShootControl") {
            ControlWidgetButton(action: OpenURLIntent(LaterWidgetShared.deepLink(.U))) {
                Label("今日を撮る", systemImage: "circle.circle")
            }
        }
        .displayName("今日を撮る")
    }
}

struct LaterOpenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LaterOpenControl") {
            ControlWidgetButton(action: OpenURLIntent(LaterWidgetShared.deepLink(.R))) {
                Label("昨日をひらく", systemImage: "circle.dashed")
            }
        }
        .displayName("昨日をひらく")
    }
}
