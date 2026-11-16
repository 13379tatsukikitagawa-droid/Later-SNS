import SwiftUI

/// L11:今日の フィルム(現像中)を ひらく。ミルク色の 窓 + すすみ(%)+ 9:00 まで。
struct DevelopV64View: View {
    var count = 3
    var index = 0
    var times: [String] = []
    var now = Date()
    var photos: [UIImage?] = []
    var onClose: () -> Void = {}
    @State private var page = 0

    var body: some View {
        let cal = Calendar.current
        let open = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now) ?? now
        let remain = max(0, Int(open.timeIntervalSince(now)))
        let progress = min(1, max(0, 1 - Double(remain) / 86400))
        let pct = Int(progress * 100)
        VStack(spacing: 0) {
            ZStack {
                VStack(spacing: 2) {
                    Text("Developing").font(LF.serif(30)).foregroundStyle(.white)
                    Text("\(page + 1) / \(count)").font(LF.inter(500, 15)).foregroundStyle(Color(hex: "8E8E93"))
                }
                HStack { Button { Haptics.play(.tick); onClose() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 48, height: 48).background(Color(hex: "161618"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }.buttonStyle(.plain); Spacer() }.padding(.leading, 14)
            }.padding(.top, 54)
            TabView(selection: $page) {
                ForEach(0..<count, id: \.self) { i in
                    ZStack {
                        LinearGradient(colors: [Color(hex: "E6EDE8"), Color(hex: "D2DAD7")], startPoint: .top, endPoint: .bottom)
                        if let img = (photos[safe: i] ?? nil) { Image(uiImage: img).resizable().scaledToFill().blur(radius: 30 * (1 - progress)).opacity(progress) }
                        VStack { HStack { Spacer(); Text("\(pct)%").font(LF.serif(32, italic: true)).foregroundStyle(HV.ink.opacity(0.8)).padding(24) }; Spacer()
                            HStack { Text(times[safe: i] ?? "--:--").font(LF.mono(15)).foregroundStyle(Color(hex: "E0481A")); Spacer(); Text("PHOTO").font(LF.mono(13)).tracking(2.4).foregroundStyle(HV.gray) }.padding(24)
                        }
                    }
                    .frame(height: 452).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).padding(.horizontal, 14).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)).frame(height: 452).padding(.top, 20)
            HStack(spacing: 7) { ForEach(0..<count, id: \.self) { i in Capsule().fill(i == page ? .white : .white.opacity(0.25)).frame(width: i == page ? 22 : 6, height: 6) } }.padding(.top, 20)
            HStack(alignment: .lastTextBaseline) {
                (Text("\(pct)").font(LF.serif(56, italic: true)) + Text("%").font(LF.serif(28, italic: true)).foregroundColor(.white.opacity(0.6))).foregroundStyle(.white)
                Spacer()
                Text("DEVELOPING…").font(LF.mono(13)).tracking(3).foregroundStyle(Color(hex: "24A03C"))
            }.padding(.horizontal, 18).padding(.top, 14)
            ZStack(alignment: .leading) {
                GeometryReader { g in
                    Capsule().fill(Color.white.opacity(0.12)).frame(height: 3).offset(y: 6)
                    Capsule().fill(Color(hex: "24A03C")).frame(width: max(14, g.size.width * progress), height: 3).offset(y: 6)
                    Circle().fill(Color(hex: "24A03C")).frame(width: 24, height: 24).shadow(color: Color(hex: "24A03C").opacity(0.6), radius: 8).offset(x: max(0, g.size.width * progress - 12))
                }.frame(height: 24)
            }.padding(.horizontal, 18).padding(.top, 6)
            HStack { Text("\(times.first ?? "") SHOT").font(LF.mono(12)).tracking(1.5).foregroundStyle(Color(hex: "5A5A5F")); Spacer(); Text("9:00 OPENS").font(LF.mono(12)).tracking(1.5).foregroundStyle(Color(hex: "5A5A5F")) }.padding(.horizontal, 18).padding(.top, 10)
            HStack(spacing: 10) { Image(systemName: "play.fill").font(.system(size: 14)); Text("developing…").font(LF.inter(800, 20)) }
                .foregroundStyle(HV.ink).frame(maxWidth: .infinity).frame(height: 56).background(.white, in: Capsule()).padding(.horizontal, 18).padding(.top, 18)
            Text("OPENS IN \(remain / 3600)H \((remain % 3600) / 60)M").font(LF.mono(12)).tracking(3).foregroundStyle(Color(hex: "5A5A5F")).padding(.top, 12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: "0A0A0B").ignoresSafeArea()).ignoresSafeArea()
    }
}
