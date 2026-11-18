// 参考(形の 見本)・ そのまま コピー しない。PROMPT_v97.md が 正解。
import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

struct LattagLiveAttributes: ActivityAttributes {
    enum Phase: String, Codable, Hashable { case film, lastCall, done, opening, opened }
    struct ContentState: Codable, Hashable {
        var phase: Phase
        var shotsTaken: Int          // 0...3
        var endsAt: Date             // 24:00 か 9:00
        var frameThumbs: [String]    // App Group の ぼかし 画像の ファイル名(本物は 入れない)
        var friendCount: Int
        var devPercent: Int
    }
    var dayKey: String
}

struct OpenCameraIntent: AppIntent {           // ボタン「撮る」
    static var title: LocalizedStringResource = "撮る"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult { /* lattag://shoot へ */ return .result() }
}

extension Color { static let lime = Color(red: 200/255, green: 242/255, blue: 90/255); static let stamp = Color(red: 1, green: 122/255, blue: 47/255) }

struct LattagLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LattagLiveAttributes.self) { ctx in
            switch ctx.state.phase {
            case .lastCall: LastCallView(s: ctx.state)                 // D:ライム 全面
            case .opening, .opened: OpeningView(s: ctx.state)           // E:朝の 部
            default: FilmView(s: ctx.state)                             // A:フィルム
            }
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { AppIconMark(size: 26) }
                DynamicIslandExpandedRegion(.trailing) { Text("● LIVE").font(.custom("SpaceMono-Bold", size: 10)).foregroundStyle(Color.lime) }
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: Date.now...ctx.state.endsAt, countsDown: true)
                        .font(.system(size: 44, weight: .heavy)).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack { /* あとで(終わらせる) */ Button(intent: OpenCameraIntent()) { Text("撮る").bold() }.tint(.lime) }
                }
            } compactLeading: {
                AppIconMark(size: 22)
            } compactTrailing: {
                Text(timerInterval: Date.now...ctx.state.endsAt, countsDown: true)
                    .font(ctx.state.phase == .film ? .custom("SpaceMono-Bold", size: 14) : .system(size: 14, weight: .heavy))
                    .foregroundStyle(ctx.state.phase == .film ? Color.stamp : (ctx.state.phase == .lastCall ? .black : .lime))
                    .frame(maxWidth: 64).monospacedDigit()
            } minimal: {
                ProgressView(timerInterval: Date.now...ctx.state.endsAt, countsDown: true) { EmptyView() } currentValueLabel: { Text("\(3 - ctx.state.shotsTaken)") }
                    .progressViewStyle(.circular).tint(.lime)
            }
            .keylineTint(.lime)
        }
    }
}

struct AppIconMark: View { var size: CGFloat
    var body: some View { RoundedRectangle(cornerRadius: size * 0.224, style: .continuous).fill(Color.lime).frame(width: size, height: size)
        .overlay(Image("HashMark").resizable().scaledToFit().padding(size * 0.18)) }   // # + レンズ の 絵(Asset)
}
struct FilmView: View { let s: LattagLiveAttributes.ContentState
    var body: some View { /* 上の 行 ・ のこり 1こま ・ オレンジの Text(timerInterval:) ・ フィルムの 帯(穴の 列 + 3こま)— PROMPT_v97 2章 */ Color.clear } }
struct LastCallView: View { let s: LattagLiveAttributes.ContentState
    var body: some View { /* ライム 全面 + # の 帯 + 64 の 黒い 数字 + Button(intent: OpenCameraIntent()) — 3章 */ Color.lime } }
struct OpeningView: View { let s: LattagLiveAttributes.ContentState
    var body: some View { /* 地平線 + 朝日 + 9:00 まで + ぼかした 友だち — 4章 */ Color.black } }
