import SwiftUI

// P13(v69):ヘッダー = カメラの 上の 表示(HUD)。白い 字・ ガラス。下へ 60pt スクロールで 1つの 小さな ガラスに まとまる。
// 表示する 数字は 本物の 意味が ある ものだけ(のこり 時間 ・ のこり こま)。ISO や f値 などの にせの 数字は 出さない。

struct HV68Header: View {
    @State private var logoScale: CGFloat = 1
    @State private var holding = false
    @State private var holdPulse = false
    @State private var holdTask: Task<Void, Never>?
    @State private var suppressTapUntil = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotionH
    let input: HomeV64Input
    let f: HV.Frame
    let compact: Bool
    let scrollY: CGFloat
    let entered: Bool
    var onYesterday: () -> Void
    var onProfile: () -> Void
    var onInbox: () -> Void = {}
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

            hud
            TopBar(title: Brand.name, width: f.w, inboxCount: input.inboxCount, avatar: input.avatar, avatarName: input.avatarName,
                   ring: input.limit == 0 ? 0 : Double(min(input.shotsUsed, input.limit)) / Double(input.limit), showsSwitchBadge: true,
                   compact: compact, hidesTitleWhenCompact: true, showsTip: true, switchLabel: "きのうへ",
                   onBell: onInbox, onProfile: onProfile, onSwitch: onYesterday, onTitleTap: { signTap() }, titleScale: logoScale)
        }
        .frame(width: f.w, height: f.h, alignment: .topLeading)
        .animation(Self.spring, value: compact)
    }

    // MARK: v100 サイン ・ 長押し

    private func signTap() {
        Haptics.play(.sig)
        guard !reduceMotionH else { return }
        Task { @MainActor in
            for (v, d) in [(1.06, 0.1), (0.98, 0.1), (1.03, 0.1), (1.0, 0.12)] {
                withAnimation(.easeInOut(duration: d)) { logoScale = v }
                try? await Task.sleep(for: .milliseconds(Int(d * 1000)))
            }
        }
    }

    private func startHold() {
        holding = true
        Haptics.play(.pop)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            var lastMinute: Int? = nil
            while !Task.isCancelled {
                let now = input.debugClock ?? Date()
                let frac = now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
                try? await Task.sleep(for: .milliseconds(Int((1 - frac) * 1000)))   // 秒の ちょうどに あわせる
                guard !Task.isCancelled else { return }
                let t = input.debugClock ?? Date()
                let cal = Calendar.current
                let sec = cal.component(.hour, from: t) * 3600 + cal.component(.minute, from: t) * 60 + cal.component(.second, from: t)
                let remain = sec < 9 * 3600 ? 9 * 3600 - sec : 86400 - sec
                let minute = remain / 60
                Haptics.play(lastMinute != nil && minute != lastMinute ? .click : .tick)
                lastMinute = minute
                if !reduceMotionH {
                    withAnimation(.easeOut(duration: 0.08)) { holdPulse = true }
                    try? await Task.sleep(for: .milliseconds(90))
                    withAnimation(.easeIn(duration: 0.12)) { holdPulse = false }
                }
            }
        }
    }

    private func endHold() {
        guard holding else { return }
        holdTask?.cancel(); holdTask = nil
        holding = false; holdPulse = false
        Haptics.play(.soft)
        suppressTapUntil = Date().addingTimeInterval(0.4)   // この 長押しの あと ライブ パネルは ひらかない
    }

    // MARK: 時間の カプセル(輪 ・ 消灯まで ・ 秒まで 進む 時計 ・ のこり こま)。まとまる と 中央の 小さな ピル

    private var hud: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = input.debugClock ?? ctx.date
            let t = HV68Clock(now: now)
            Group {
                if compact { compactRow(t) }
                else {
                    // はみ出さない:ラベルを 先に 消す。決めうちの 幅 ・ offset は 使わない
                    ViewThatFits(in: .horizontal) { fullRow(t, label: true); fullRow(t, label: false) }
                }
            }
            .frame(width: compact ? 176 : f.w - 32, height: compact ? 38 : 50)
            .background {
                if compact { Capsule().fill(.ultraThinMaterial).overlay(Capsule().fill(Color.black.opacity(0.82))) }
                else { Capsule().fill(.white.opacity(0.08)) }
            }
            .overlay(Capsule().strokeBorder(.white.opacity(compact ? 0.14 : 0.16), lineWidth: 0.8))
            .mask(alignment: .leading) { Rectangle().frame(width: entered ? f.w + 40 : 0) }
            .animation(.timingCurve(0.3, 1, 0.4, 1, duration: 0.7).delay(entered ? 0.26 : 0), value: entered)
            .contentShape(Rectangle())
            .overlay(Capsule().strokeBorder(LattagPalette.lime, lineWidth: 2).opacity(holding ? 1 : 0))
            .scaleEffect(holdPulse ? 1.035 : 1)
            .onTapGesture { guard Date() > suppressTapUntil else { return }; Haptics.play(.click); onLive() }
            // v100 §5:長押し = 時間を さわる(0.45秒で pop → はなす まで 1秒ごとに tick ・ 分が かわる 時は click)
            .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 40, perform: { startHold() }, onPressingChanged: { p in if !p { endHold() } })
        }
        .offset(x: compact ? f.cx - 88 : 16, y: compact ? 52 : 108)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("のこり時間と のこり こま")
        .accessibilityAddTraits(.isButton)
    }

    private func ring(_ t: HV68Clock, scale: CGFloat) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: 3).frame(width: 26, height: 26)
            Circle().trim(from: 0, to: t.progress).stroke(HV.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 26, height: 26)
            Circle().fill(HV.lime).frame(width: 7, height: 7)
        }.frame(width: 32, height: 32).scaleEffect(scale)
    }

    private var frames: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                let has = i < input.remaining
                RoundedRectangle(cornerRadius: 2).fill(has ? HV.lime : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(.white.opacity(has ? 0 : 0.45), lineWidth: 1))
                    .shadow(color: has ? HV.lime.opacity(0.5) : .clear, radius: 3)
                    .frame(width: 8, height: 12)
            }
        }
    }

    private func fullRow(_ t: HV68Clock, label: Bool) -> some View {
        HStack(spacing: 0) {
            ring(t, scale: 1)
            if label { Text(t.label).font(Typo.ui(700, 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1).fixedSize().padding(.leading, 10) }
            HStack(spacing: 0) {
                Text(t.hms.0).foregroundStyle(.white)
                Text(t.hms.1).foregroundStyle(.white.opacity(0.35))
            }
            .font(Typo.ui(700, 21)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            .contentTransition(.numericText(countsDown: true)).padding(.leading, 8)
            Spacer(minLength: 8)
            Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 22).padding(.trailing, 10)
            frames.fixedSize()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(input.remaining)").font(Typo.ui(800, 17)).foregroundStyle(.white)
                Text("枚").font(Typo.ui(700, 14)).foregroundStyle(.white.opacity(0.8))
            }.fixedSize().padding(.leading, 8)
        }.padding(.leading, 9).padding(.trailing, 16)
    }

    private func compactRow(_ t: HV68Clock) -> some View {
        HStack(spacing: 0) {
            ring(t, scale: 0.8).padding(.leading, 3)
            HStack(spacing: 0) { Text(t.hms.0).foregroundStyle(.white); Text(t.hms.1).foregroundStyle(.white.opacity(0.35)) }
                .font(Typo.ui(700, 16)).monospacedDigit().lineLimit(1).padding(.leading, 6)
            Spacer(minLength: 4)
            Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 16).padding(.trailing, 8)
            Text("\(input.remaining)").font(Typo.ui(800, 15)).foregroundStyle(HV.lime).padding(.trailing, 12)
        }
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
        label = night ? "ひらくまで" : "24:00まで"
        progress = night ? Double(sec) / Double(9 * 3600) : Double(sec - 9 * 3600) / Double(15 * 3600)
        hms = ("\(remain / 3600):\(String(format: "%02d", (remain % 3600) / 60))", ":\(String(format: "%02d", remain % 60))")
    }
}
