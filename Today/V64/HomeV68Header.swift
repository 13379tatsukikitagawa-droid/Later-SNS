import SwiftUI

// P13(v69):ヘッダー = カメラの 上の 表示(HUD)。白い 字・ ガラス。下へ 60pt スクロールで 1つの 小さな ガラスに まとまる。
// 表示する 数字は 本物の 意味が ある ものだけ(のこり 時間 ・ のこり こま)。ISO や f値 などの にせの 数字は 出さない。

struct HV68Header: View {
    let input: HomeV64Input
    let f: HV.Frame
    let compact: Bool
    let scrollY: CGFloat
    let entered: Bool
    var onYesterday: () -> Void
    var onProfile: () -> Void
    var onLive: () -> Void

    private static let spring = Animation.timingCurve(0.3, 1.15, 0.4, 1, duration: 0.55)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // うしろの ぼかしの 帯(24pt より 下へ スクロールしたら)
            Rectangle().fill(.ultraThinMaterial)
                .overlay(Color(red: 10 / 255, green: 10 / 255, blue: 11 / 255).opacity(0.5))
                .frame(width: f.w, height: compact ? 108 : 178)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .opacity(scrollY > 24 ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: scrollY > 24)
                .allowsHitTesting(false)
            LinearGradient(colors: [.black.opacity(0.34), .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: f.w, height: 170).opacity(scrollY > 24 ? 0 : 1).allowsHitTesting(false)

            // ロゴ ・ モード(まとまる とき 上へ 10pt + 0.86倍 + 消える)
            Group {
                Text(Brand.name).font(LF.inter(900, 30)).tracking(-1.95).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 7, y: 1)
                    .frame(height: 40, alignment: .leading).fixedSize().offset(x: 22, y: 56)
                modeSwitch.offset(x: f.xr(156), y: 61)
            }
            .scaleEffect(compact ? 0.86 : 1, anchor: .topLeading)
            .offset(y: compact ? -10 : 0)
            .opacity(compact ? 0 : 1)
            .allowsHitTesting(!compact)

            hud
            avatar
        }
        .frame(width: f.w, height: f.h, alignment: .topLeading)
        .animation(Self.spring, value: compact)
    }

    // MARK: TODAY ・ YESTERDAY(カメラの PHOTO / VIDEO の 切りかえ)

    private var modeSwitch: some View {
        HStack(spacing: 3) {
            Text("TODAY").font(LF.mono(10.5)).tracking(1.68).foregroundStyle(HV.lime)
                .frame(width: 58, height: 30)
                .overlay(alignment: .bottom) { Circle().fill(HV.lime).frame(width: 4, height: 4).shadow(color: HV.lime, radius: 4).offset(y: -2) }
            Button { Haptics.play(.sel); onYesterday() } label: {
                Text("YESTERDAY").font(LF.mono(10.5)).tracking(1.68).foregroundStyle(.white.opacity(0.5)).frame(width: 91, height: 30)
                    .contentShape(Rectangle().inset(by: -7))
            }.buttonStyle(.plain)
        }
        .frame(width: 160, height: 30, alignment: .leading)
    }

    // MARK: アバター + 今日の 撮影の 進みの 輪

    private var avatar: some View {
        let ratio = input.limit == 0 ? 0 : Double(min(input.shotsUsed, input.limit)) / Double(input.limit)
        return Button { Haptics.play(.sel); onProfile() } label: {
            ZStack {
                Circle().stroke(.white.opacity(0.22), lineWidth: 1.6).frame(width: 52, height: 52)
                Circle().trim(from: 0, to: ratio).stroke(HV.lime, style: StrokeStyle(lineWidth: 1.6, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 52, height: 52)
                Group {
                    if let a = input.avatar { Image(uiImage: a).resizable().scaledToFill() }
                    else { Circle().fill(Self.color(input.avatarName)).overlay(Text(String(input.avatarName.prefix(1))).font(LF.inter(800, 18)).foregroundStyle(HV.ink)) }
                }
                .frame(width: 44, height: 44).clipShape(Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(HVPress(scale: 0.92))
        .scaleEffect(compact ? 0.73 : 1)
        .offset(x: f.w - 68, y: compact ? 50 : 50)
        .accessibilityLabel("プロフィール")
    }

    private static func color(_ name: String) -> Color {
        let palette = ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"]
        let n = name.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0xFFFF }
        return Color(hex: palette[n % palette.count])
    }

    // MARK: HUD(輪 ・ ラベル ・ 秒まで 進む 時計 ・ のこり こま ・ 矢印)

    private var hud: some View {
        let w: CGFloat = compact ? 196 : 358, h: CGFloat = compact ? 38 : 46
        return TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = input.debugClock ?? ctx.date
            let t = HV68Clock(now: now)
            ZStack(alignment: .topLeading) {
                // 輪(今日の 進み)+ まんなかの 録画の ような 点
                ZStack {
                    Circle().stroke(.white.opacity(0.18), lineWidth: 2.4)
                    Circle().trim(from: 0, to: t.progress).stroke(HV.lime, style: StrokeStyle(lineWidth: 2.4, lineCap: .round)).rotationEffect(.degrees(-90))
                    Circle().fill(HV.lime).frame(width: 7, height: 7)
                }
                .frame(width: 26, height: 26).scaleEffect(compact ? 0.9 : 1.22).offset(x: compact ? 8 : 8, y: compact ? 6 : 7)

                Text(t.label).font(LF.inter(700, 11.5)).foregroundStyle(.white.opacity(0.72)).fixedSize()
                    .offset(x: 49, y: 15).opacity(compact ? 0 : 1)

                HStack(spacing: 0) {
                    Text(t.hms.0).foregroundStyle(.white)
                    Text(t.hms.1).foregroundStyle(.white.opacity(0.55))
                }
                .font(LF.mono(compact ? 15 : 18)).monospacedDigit().fixedSize()
                .contentTransition(.numericText(countsDown: true))
                .offset(x: compact ? 42 : 114, y: compact ? 9 : 10)

                Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: compact ? 16 : 20).offset(x: compact ? 118 : 201, y: compact ? 11 : 13)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        let has = i < input.remaining
                        RoundedRectangle(cornerRadius: 2).fill(has ? HV.lime : .clear)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(has ? 0 : 0.45), lineWidth: 1))
                            .shadow(color: has ? HV.lime.opacity(0.5) : .clear, radius: 3)
                            .frame(width: 8, height: 12)
                    }
                }
                .offset(x: compact ? 128 : 214, y: compact ? 13 : 17)
                Text("\(input.remaining)").font(LF.inter(800, 16)).foregroundStyle(.white).fixedSize().offset(x: compact ? 162 : 251, y: compact ? 9 : 13)
                Text("EXP").font(LF.mono(9)).foregroundStyle(.white.opacity(0.6)).fixedSize().offset(x: 269, y: 16).opacity(compact ? 0 : 1)
                Circle().fill(.white.opacity(0.16)).frame(width: 34, height: 34)
                    .overlay(Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                    .offset(x: 318, y: 6).opacity(compact ? 0 : 1)
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .hvGlass(radius: h / 2, tint: 0.16)
            .mask(alignment: .leading) { Rectangle().frame(width: entered ? w + 40 : 0) }
            .animation(.timingCurve(0.3, 1, 0.4, 1, duration: 0.7).delay(entered ? 0.26 : 0), value: entered)
            .contentShape(Rectangle())
            .onTapGesture { Haptics.play(.click); onLive() }
        }
        .offset(x: compact ? f.cx - 98 : 16, y: compact ? 54 : 108)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("のこり時間と のこり こま")
        .accessibilityAddTraits(.isButton)
    }
}

/// 今日の 進み(9:00 → 24:00。夜 0:00〜9:00 は 24:00 → 9:00)と のこり 時間
struct HV68Clock {
    let label: String
    let hms: (String, String)
    let progress: Double

    init(now: Date) {
        let cal = Calendar.current
        let sec = cal.component(.hour, from: now) * 3600 + cal.component(.minute, from: now) * 60 + cal.component(.second, from: now)
        let night = sec < 9 * 3600
        let remain = night ? 9 * 3600 - sec : 86400 - sec
        label = night ? "ひらくまで" : "消灯まで"
        progress = night ? Double(sec) / Double(9 * 3600) : Double(sec - 9 * 3600) / Double(15 * 3600)
        hms = ("\(remain / 3600):\(String(format: "%02d", (remain % 3600) / 60))", ":\(String(format: "%02d", remain % 60))")
    }
}
