import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
import AppIntents

// P40 A:ロック画面の 3つの 形(フィルム / ラストコール / 朝の 部)+ Dynamic Island。見本 widgets/live/A_film D_lastcall E_opening。

typealias LiveState = LattagLiveAttributes.ContentState

private let wStamp = Color(hex6: 0xFF7A2F)

struct LiveBadge: View {
    var text: String
    var dark = true
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(dark ? WColor.lime : WColor.lime).frame(width: 6, height: 6)
            Text(text).font(WFont.mono(8.5)).tracking(1.5).foregroundStyle(WColor.lime)
        }.padding(.horizontal, 9).frame(height: 20).background(dark ? WColor.lime.opacity(0.14) : Color.black, in: Capsule())
    }
}

// MARK: A フィルム

struct LiveFilmView: View {
    let s: LiveState
    var now: Date = Date()
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                WIcon(size: 22)
                Text("Lattag").font(WFont.inter(800, 12)).foregroundStyle(.white)
                LiveBadge(text: "LIVE")
                Spacer()
                Text("LIGHTS OUT 24:00").font(WFont.mono(9)).foregroundStyle(Color(hex6: 0x5D5D63))
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("のこり ").foregroundColor(.white) + Text("\(max(0, 3 - s.shotsTaken))こま").foregroundColor(WColor.lime)).font(WFont.inter(800, 15))
                    Text("今日の フィルム").font(WFont.inter(700, 12)).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("消灯まで").font(WFont.mono(9)).tracking(1.4).foregroundStyle(.white.opacity(0.55))
                    Text(timerInterval: now...max(s.endsAt, now.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: true)
                        .font(WFont.mono(34)).foregroundStyle(wStamp).shadow(color: wStamp.opacity(0.5), radius: 6).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                }
            }.padding(.top, 8)
            film.padding(.top, 8)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var film: some View {
        VStack(spacing: 3) {
            perforations
            HStack(spacing: 8) {
                ForEach(Array(0..<3), id: \.self) { i in frame(i) }
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 2) { ForEach(Array(0..<14), id: \.self) { _ in Rectangle().fill(.white.opacity(0.12)).frame(width: 2, height: 22) } }
                    Text("ISO 400 ・ 3 EXP").font(WFont.mono(7.5)).foregroundStyle(.white.opacity(0.4))
                }.frame(maxWidth: .infinity, alignment: .trailing)
            }
            perforations
        }
        .padding(.vertical, 3).padding(.horizontal, 6).background(Color(hex6: 0x16130F), in: RoundedRectangle(cornerRadius: 8))
    }

    private var perforations: some View {
        HStack(spacing: 6) { ForEach(Array(0..<26), id: \.self) { _ in RoundedRectangle(cornerRadius: 1).fill(Color.black).frame(width: 7, height: 4) } }.frame(maxWidth: .infinity, alignment: .leading).clipped()
    }

    @ViewBuilder private func frame(_ i: Int) -> some View {
        let taken = i < s.shotsTaken
        ZStack(alignment: .topTrailing) {
            if taken {
                RoundedRectangle(cornerRadius: 5).fill(WColor.paper.opacity(0.85))
                if let img = WImage.load(s.frameThumbs[safeW: i]) { Image(uiImage: img).resizable().scaledToFill().frame(width: 52, height: 40).clipped().opacity(0.9) }
                Color.white.opacity(0.35)
                Text("DEV").font(WFont.mono(6.5)).foregroundStyle(.black.opacity(0.6)).padding(3)
            } else {
                RoundedRectangle(cornerRadius: 5).strokeBorder(WColor.lime.opacity(0.85), lineWidth: 1.2)
                VStack(spacing: 0) { Text("+").font(WFont.inter(800, 14)); Text("撮る").font(WFont.inter(800, 9)) }.foregroundStyle(WColor.lime).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 52, height: 40).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: D ラストコール

struct LiveLastCallView: View {
    let s: LiveState
    var now: Date = Date()
    var body: some View {
        ZStack {
            WColor.lime
            WHashBand(color: .black.opacity(0.07))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ZStack { RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.black); Image(systemName: "number").font(.system(size: 12, weight: .black)).foregroundStyle(WColor.lime) }.frame(width: 22, height: 22)
                    Text("Lattag").font(WFont.inter(800, 12)).foregroundStyle(.black)
                    HStack(spacing: 5) { Circle().fill(WColor.lime).frame(width: 6, height: 6); Text("LAST CALL").font(WFont.mono(8.5)).tracking(1.5).foregroundStyle(WColor.lime) }.padding(.horizontal, 9).frame(height: 20).background(Color.black, in: Capsule())
                    Spacer()
                    Text("23:51").font(WFont.mono(9)).foregroundStyle(.black.opacity(0.55))
                }
                Text(timerInterval: now...max(s.endsAt, now.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: false)
                    .font(WFont.inter(900, 64)).foregroundStyle(.black).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5).padding(.top, 6)
                Spacer(minLength: 0)
                Text("消灯まで あと \(max(1, Int(s.endsAt.timeIntervalSince(now) / 60)))分 ・ のこり \(max(0, 3 - s.shotsTaken))こま").font(WFont.inter(900, 13)).foregroundStyle(.black)
            }.padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Button(intent: OpenCameraIntent()) {
                VStack(spacing: 2) {
                    WIcon(size: 46)
                    Text("撮る").font(WFont.inter(900, 10)).foregroundStyle(WColor.lime)
                }.frame(width: 74, height: 74).background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(14)
        }
    }
}

// MARK: E 朝の 部

struct LiveOpeningView: View {
    let s: LiveState
    var now: Date = Date()
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex6: 0x0B0B0C), Color(hex6: 0x14180A)], startPoint: .top, endPoint: .bottom)
            Ellipse().fill(RadialGradient(colors: [WColor.lime.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 120)).frame(width: 260, height: 120).blur(radius: 14).offset(y: 70)
            Rectangle().fill(LinearGradient(colors: [.clear, WColor.lime.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1).offset(y: 22)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    WIcon(size: 22)
                    Text("Lattag").font(WFont.inter(800, 12)).foregroundStyle(.white)
                    LiveBadge(text: s.phase == .opened ? "OPEN" : "OPENING")
                    Spacer()
                    Text("あした の 朝").font(WFont.inter(700, 10)).foregroundStyle(.white.opacity(0.4))
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        if s.phase == .opened {
                            Text("ひらいた ・ 見る").font(WFont.inter(900, 26)).foregroundStyle(WColor.lime).padding(.top, 14)
                        } else {
                            Text("9:00 まで").font(WFont.mono(10)).foregroundStyle(WColor.lime).padding(.top, 6)
                            Text(timerInterval: now...max(s.endsAt, now.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: true)
                                .font(WFont.inter(900, 42)).foregroundStyle(.white).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                        }
                    }
                    Spacer()
                    HStack(spacing: -10) {
                        ForEach(Array(0..<min(5, max(1, s.friendCount))), id: \.self) { i in
                            Circle().fill([WColor.lime, WColor.sky, WColor.pink, Color(hex6: 0xF4B942), WColor.paper][i % 5].opacity(0.85)).frame(width: 32, height: 32).blur(radius: 5).overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1.5))
                        }
                    }.padding(.top, 14)
                }
                Spacer(minLength: 0)
                HStack {
                    Text("\(s.friendCount)人の きのう が ひらく").font(WFont.inter(900, 13)).foregroundStyle(.white)
                    Spacer()
                    Text("\(s.shotsTaken) EXP  現像 \(s.devPercent)%").font(WFont.mono(9)).foregroundStyle(.white.opacity(0.5))
                }
            }.padding(14)
        }
    }
}

// MARK: v134 あかりが つくまで(1枚目を 撮った 瞬間 → あした 9:00)

/// #レンズ(小)。ライムの 玉に # と 小さな レンズ
struct WLiveLens: View {
    var size: CGFloat = 46
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex6: 0xF6FFD2), Color(hex6: 0xDDFB7D), WColor.lime, Color(hex6: 0x8DB928)], center: UnitPoint(x: 0.3, y: 0.18), startRadius: 0, endRadius: size * 0.8))
            Image(systemName: "number").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(Color(hex6: 0x0B0D06))
        }
        .frame(width: size, height: size)
        .shadow(color: WColor.lime.opacity(0.5), radius: size * 0.16, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

struct LiveWaitingView: View {
    let s: LiveState
    var stale = false
    var now: Date = Date()
    private var range: ClosedRange<Date> { now...max(s.endsAt, now.addingTimeInterval(1)) }
    private var clock: DateFormatter { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"; return f }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                WLiveLens(size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stale ? "あかりがつきました" : "あかりがつくまで").font(.system(size: 17, weight: .heavy)).foregroundStyle(.white)
                    if stale {
                        Text("今日の1枚を撮ると、きのうがひらく").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex6: 0xA3A3AB))
                    } else {
                        (Text("あと ") + Text(timerInterval: range, pauseTime: nil, countsDown: true, showsHours: true)).monospacedDigit()
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex6: 0xA3A3AB))
                    }
                }
                Spacer(minLength: 6)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(i < s.shotsTaken ? AnyShapeStyle(LinearGradient(colors: [Color(hex6: 0xECEAE3), Color(hex6: 0xD2CEC3)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(.white.opacity(i < s.shotsTaken ? 0 : 0.3), lineWidth: 1))
                            .frame(width: 20, height: 28)
                    }
                }
            }
            if let shotAt = s.shotAt, !stale {
                ProgressView(timerInterval: shotAt...max(s.endsAt, shotAt.addingTimeInterval(1)), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(WColor.lime)
                HStack {
                    Text("撮った \(clock.string(from: shotAt))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex6: 0x66666E))
                    Spacer()
                    Text("9:00 ひらく").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex6: 0x66666E))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: ロック画面 + Dynamic Island

struct LattagLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LattagLiveAttributes.self) { ctx in
            Group {
                switch ctx.state.phase {
                case .lastCall: LiveLastCallView(s: ctx.state)
                case .opening, .opened: LiveOpeningView(s: ctx.state)
                case .waiting: LiveWaitingView(s: ctx.state, stale: ctx.isStale)
                default: LiveFilmView(s: ctx.state)
                }
            }
            .activityBackgroundTint(ctx.state.phase == .lastCall ? WColor.lime : Color.black.opacity(0.9))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(ctx.state.phase == .opened || ctx.state.phase == .waiting ? LattagShared.Link.yesterday() : LattagShared.Link.shoot)
        } dynamicIsland: { ctx in
            let s = ctx.state
            let lime = s.phase == .lastCall
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { if s.phase == .waiting { WLiveLens(size: 30) } else { WIcon(size: 26) } }
                DynamicIslandExpandedRegion(.trailing) { if s.phase == .waiting { Text("9:00 ひらく").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(hex6: 0xA3A3AB)) } else { Text("● LIVE").font(WFont.mono(10)).foregroundStyle(WColor.lime) } }
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: Date.now...max(s.endsAt, Date.now.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: s.phase != .lastCall)
                        .font(WFont.inter(900, 40)).monospacedDigit().foregroundStyle(lime ? WColor.lime : .white).lineLimit(1).minimumScaleFactor(0.5)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(s.phase == .waiting ? "あかりがつくまで" : (s.phase == .opening || s.phase == .opened ? "9:00 に ひらく" : "のこり \(max(0, 3 - s.shotsTaken))こま")).font(WFont.inter(800, 13)).foregroundStyle(.white)
                        Spacer()
                        if s.phase != .opening && s.phase != .opened && s.phase != .waiting {
                            Button(intent: OpenCameraIntent()) { Text("撮る").font(WFont.inter(900, 14)).foregroundStyle(Color(hex6: 0x0B0B0C)).padding(.horizontal, 18).frame(height: 32).background(WColor.lime, in: Capsule()) }.buttonStyle(.plain)
                        }
                    }
                }
            } compactLeading: {
                if s.phase == .waiting { WLiveLens(size: 22) } else { WIcon(size: 22) }
            } compactTrailing: {
                Text(timerInterval: Date.now...max(s.endsAt, Date.now.addingTimeInterval(1)), pauseTime: nil, countsDown: true, showsHours: s.phase != .lastCall)
                    .font(s.phase == .film ? WFont.mono(14) : WFont.inter(900, 14)).monospacedDigit()
                    .foregroundStyle(s.phase == .waiting ? WColor.lime : (s.phase == .film ? wStamp : (lime ? .black : WColor.lime))).frame(maxWidth: 62)
            } minimal: {
                if s.phase == .waiting { WLiveLens(size: 18) }
                else if s.phase == .opening || s.phase == .opened { Text("9:00").font(WFont.inter(900, 11)).foregroundStyle(WColor.lime) }
                else { Text("\(max(0, 3 - s.shotsTaken))").font(WFont.inter(900, 14)).foregroundStyle(WColor.lime) }
            }
            .keylineTint(WColor.lime)
        }
    }
}
#endif
