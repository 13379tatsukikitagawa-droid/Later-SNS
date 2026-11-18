import SwiftUI
import SwiftData

// P08 + P27(v83):Trip を つくる = 1問ずつ(どこへ → いつ → だれと → 表紙)+ チケットの 見本 + パス。見本:T01 T02 T10 T11 T03。
// 保存は 今までの しくみ(`LaterGroup` + `GroupSharingService.createGroup` + `GroupInviteService`)。キャラクターは 使わない。

struct TripDraft: Equatable {
    var name = ""
    var start = Date()
    var end = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    var invited: Set<String> = []
    var coverIndex = 0
    var days: Int { max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0) + 1) }
}

/// パス(搭乗券 ・ 高さ 148 ・ 角丸 22 ・ 地 #F4EFE6)。答える たびに 中身が その場で 書きかわる(v90)
struct TripTicket: View {
    var draft: TripDraft
    var cover: UIImage?
    var members: [(String, UIImage?)]
    /// 名前の 位置(チップが とんで くる 先)を 外へ 知らせる
    var onNameFrame: (CGRect) -> Void = { _ in }
    var coverKey = 0
    private static let df: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MM/dd EEE"; return f }()
    private let ink = Color(hex: "0B0C0D")

    private var number: String {
        let n = draft.name.unicodeScalars.reduce(1074) { ($0 &* 31 &+ Int($1.value)) % 10000 }
        return String(format: "%04d", draft.name.isEmpty ? 1074 : n)
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Color(hex: "2A2326")
                if let cover { Image(uiImage: cover).resizable().scaledToFill().id(coverKey).transition(.scale(scale: 1.15).combined(with: .opacity)) }
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                Text("LATTAG").font(LF.inter(900, 11)).foregroundStyle(.white).padding(.leading, 12).padding(.bottom, 10)
            }.frame(width: 98).clipped().animation(.easeOut(duration: 0.3), value: coverKey)
            // 切りとり線
            Rectangle().fill(.clear).frame(width: 2).overlay { GeometryReader { g in Path { p in p.move(to: CGPoint(x: 1, y: 0)); p.addLine(to: CGPoint(x: 1, y: g.size.height)) }.stroke(ink.opacity(0.22), style: StrokeStyle(lineWidth: 2, dash: [4, 4])) } }
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text("TRIP PASS").font(LF.mono(8.5)).tracking(1.5); Spacer(); Text("No.\(number)").font(LF.mono(8.5)).tracking(1) }.foregroundStyle(ink.opacity(0.5))
                FlipName(text: draft.name.isEmpty ? "どこへ?" : draft.name, dim: draft.name.isEmpty)
                    .padding(.top, 5)
                    .background(GeometryReader { g in Color.clear.onAppear { onNameFrame(g.frame(in: .global)) }.onChange(of: g.frame(in: .global)) { _, f in onNameFrame(f) } })
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("FROM").font(LF.mono(7.5)).foregroundStyle(ink.opacity(0.45)); Text(Self.df.string(from: draft.start).uppercased()).font(LF.mono(10.5)).fontWeight(.bold)
                    Text("TO").font(LF.mono(7.5)).foregroundStyle(ink.opacity(0.45)); Text(Self.df.string(from: draft.end).uppercased()).font(LF.mono(10.5)).fontWeight(.bold)
                    Spacer(minLength: 4)
                    Text("DAYS").font(LF.mono(7.5)).foregroundStyle(ink.opacity(0.45)); Text("\(draft.days)").font(LF.inter(900, 22)).contentTransition(.numericText())
                }.foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 6)
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    HStack(spacing: -7) {
                        ForEach(Array(members.prefix(4).enumerated()), id: \.offset) { _, m in memberDot(m.1, m.0, 22).overlay(Circle().strokeBorder(Color(hex: "F4EFE6"), lineWidth: 2)).transition(.scale(scale: 0).combined(with: .opacity)) }
                    }
                    Text("\(members.count)人 ・ 1日 23枚").font(LF.mono(9.5)).foregroundStyle(ink.opacity(0.55)).lineLimit(1)
                }
            }.padding(.leading, 14).padding(.trailing, 10).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 0) { ForEach(0..<14, id: \.self) { i in Rectangle().fill(i % 2 == 0 ? Color(hex: "C8F25A") : Color(hex: "24A03C")).frame(width: 8, height: 148.0 / 14) } }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: members.count)
        .frame(height: 148).background(Color(hex: "F4EFE6"))
        .overlay(alignment: .topLeading) { notch.padding(.leading, 98 + 1 - 9).padding(.top, -9) }
        .overlay(alignment: .bottomLeading) { notch.padding(.leading, 98 + 1 - 9).padding(.bottom, -9) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
    }

    private var notch: some View { Circle().fill(Color(hex: "0B0C0D")).frame(width: 18, height: 18) }

    func memberDot(_ img: UIImage?, _ name: String, _ size: CGFloat) -> some View {
        ZStack {
            if let img { Image(uiImage: img).resizable().scaledToFill() }
            else { Circle().fill(LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, size * 0.42)).foregroundStyle(.white)) }
        }.frame(width: size, height: size).clipShape(Circle())
    }
}

/// 名前:変わった 字だけ 1字ずつ めくれる(上へ 92° たおれた 所から 起きる ・ 0.3秒 ・ 32ms ずらし)
struct FlipName: View {
    let text: String
    var dim = false
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                FlipChar(ch: ch, delay: Double(i) * 0.032).id("\(i)-\(ch)")
            }
        }.font(.system(size: 27, weight: .black)).foregroundStyle(Color(hex: "0B0C0D").opacity(dim ? 0.24 : 1)).lineLimit(1).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading).clipped()
    }
}
private struct FlipChar: View {
    let ch: Character; let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var up = false
    var body: some View {
        Text(String(ch)).rotation3DEffect(.degrees(up || reduce ? 0 : -92), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.6)
            .opacity(up || reduce ? 1 : 0)
            .onAppear { withAnimation(.easeOut(duration: 0.3).delay(delay)) { up = true } }
    }
}

struct TripNewV83View: View {
    var friends: [GroupCreateFriend]
    /// 表紙の 候補(自分の 最近の 写真)
    var photos: [UIImage?]
    var myAvatar: UIImage?
    var startStep = 0
    var startDraft: TripDraft? = nil
    var onCreated: (String) -> Void = { _ in }
    var onClose: () -> Void
    /// DEBUG:作らず に パスを 見せる
    var previewPass = false
    /// DEBUG:今日の 日付を 固定(見本どり)
    var todayOverride: Date? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var back = false
    @State private var draft = TripDraft()
    @State private var pickingStart = true
    @State private var creating = false
    @State private var pass: TripPassData?
    @State private var errorText: String?
    @FocusState private var focus: Bool
    @State private var seeded = false

    private var cover: UIImage? { photos.indices.contains(draft.coverIndex) ? photos[draft.coverIndex] : nil }
    private var members: [(String, UIImage?)] {
        [("あなた", myAvatar)] + friends.filter { draft.invited.contains($0.id) }.map { ($0.name, $0.avatarData.flatMap { UIImage(data: $0) }) }
    }
    private var canNext: Bool { step == 0 ? !draft.name.trimmingCharacters(in: .whitespaces).isEmpty : true }

    var body: some View {
        ZStack {
            Color(hex: "0B0C0D").ignoresSafeArea()
            if let pass { TripPassView(data: pass, newlyMade: true, onStart: { onCreated(pass.name); onClose() }, onClose: onClose).transition(.opacity) }
            else { wizard.transition(.opacity) }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .onAppear {
            guard !seeded else { return }
            seeded = true; step = startStep; if let d = startDraft { draft = d }
            if previewPass { pass = TripPassData(name: draft.name.isEmpty ? "Kyoto" : "Kyoto", sub: draft.name, from: "NOV 17", to: "NOV 19", days: 3, key: "mango515", link: "lattag://join?x=sample", cover: cover, members: members.map { $0.1 }, names: members.map { $0.0 }) }
        }
    }

    // MARK: ウィザード

    @State private var nameFrame: CGRect = .zero
    @State private var fly: (text: String, from: CGRect, kind: Int, id: UUID)?
    @State private var flyGo = false
    @State private var sink = false
    @State private var coverKey = 0
    private let titles = ["どこへ 行く?", "いつ 行く?", "だれと 行く?", "表紙を えらぶ"]

    private var wizard: some View {
        ZStack(alignment: .top) {
            background
            VStack(spacing: 0) {
                topBar.padding(.top, 52)
                TripTicket(draft: draft, cover: cover, members: members, onNameFrame: { nameFrame = $0 }, coverKey: draft.coverIndex)
                    .padding(.horizontal, 16).padding(.top, 14)
                    .scaleEffect(sink ? 0.95 : 1).offset(y: sink ? 6 : 0)
                Text(titles[step]).font(.system(size: 30, weight: .black)).tracking(-1.2).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 18).id("t\(step)")
                ZStack {
                    Group {
                        switch step {
                        case 0: stepWhere
                        case 1: ScrollView(showsIndicators: false) { stepWhen }
                        case 2: ScrollView(showsIndicators: false) { stepWho }
                        default: ScrollView(showsIndicators: false) { stepCover }
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(insertion: .offset(x: back ? -32 : 32).combined(with: .opacity), removal: .opacity))
                }
                .animation(reduceMotion ? nil : .timingCurve(0.3, 1.1, 0.4, 1, duration: 0.42), value: step)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                bottomButton.padding(.horizontal, 16).padding(.bottom, 34)
                    .background(LinearGradient(colors: [Color(hex: "0B0C0D").opacity(0), Color(hex: "0B0C0D")], startPoint: .top, endPoint: .center).padding(.top, -40))
            }
            // チップの 写し(パスの 名前へ とぶ)
            if let fly {
                Text(fly.text).font(LF.inter(800, 15)).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 44).background(Color(hex: "17181B"), in: Capsule())
                    .overlay(Capsule().strokeBorder(HV.lime, lineWidth: 1.5))
                    .scaleEffect(flyGo ? 0.3 : 1).rotationEffect(.degrees(flyGo ? -12 : 0)).opacity(flyGo ? 0 : 1)
                    .position(x: flyGo ? nameFrame.minX + 40 : fly.from.midX, y: flyGo ? nameFrame.midY : fly.from.midY)
                    .allowsHitTesting(false).id(fly.id)
            }
            if let errorText { Text(errorText).font(LF.inter(700, 13)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10).background(Color(hex: "FF3B30"), in: Capsule()).padding(.top, 120) }
        }
        .coordinateSpace(name: "tripSpace")
    }

    private var background: some View {
        GeometryReader { g in
            ZStack {
                Color(hex: "0B0C0D")
                Circle().fill(RadialGradient(colors: [HV.lime.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.4)).frame(width: g.size.width * 0.8, height: g.size.width * 0.8).scaleEffect(x: 1, y: 0.62).position(x: g.size.width / 2, y: g.size.height * 0.18)
                Circle().fill(RadialGradient(colors: [Color(hex: "24A03C").opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: g.size.width * 0.6)).frame(width: g.size.width * 1.2, height: g.size.width * 1.2).scaleEffect(x: 1, y: 0.5).position(x: g.size.width / 2, y: g.size.height)
            }.frame(width: g.size.width, height: g.size.height).clipped()
        }.ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { Haptics.play(.sel); if step == 0 { onClose() } else { go(step - 1) } } label: {
                Image(systemName: step == 0 ? "xmark" : "chevron.left").font(.system(size: 17, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.1), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel(step == 0 ? "とじる" : "もどる")
            HStack(spacing: 5) { ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i < step ? HV.lime.opacity(0.5) : (i == step ? HV.lime : Color.white.opacity(0.12))).frame(height: 4).shadow(color: i == step ? HV.lime.opacity(0.7) : .clear, radius: 4)
            } }.animation(.easeOut(duration: 0.3), value: step)
            (Text("\(step + 1) ").font(LF.inter(900, 15)) + Text("/ 4").font(LF.mono(10))).foregroundStyle(.white.opacity(0.7)).frame(width: 44, alignment: .trailing)
        }.padding(.horizontal, 16)
    }

    private var bottomButton: some View {
        let last = step == 3
        return Button {
            if last { create() } else { Haptics.play(.click); go(step + 1) }
        } label: {
            Text(creating ? "つくっています…" : (last ? "Trip を つくる" : "つぎへ")).font(LF.inter(800, 17)).foregroundStyle(canNext ? Color(hex: "0B0C0D") : .white.opacity(0.3)).frame(maxWidth: .infinity).frame(height: 58)
                .background(canNext ? (last ? HV.lime : Color.white) : Color.white.opacity(0.08), in: Capsule()).shadow(color: last && canNext ? HV.lime.opacity(0.45) : .clear, radius: 14)
        }.buttonStyle(HVPress(scale: 0.98)).disabled(!canNext || creating)
    }

    private func go(_ s: Int) {
        back = s < step
        focus = false
        withAnimation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.42)) { step = s }
    }

    // 1 どこへ
    @State private var pausedRow = [false, false]
    @State private var pickedChip: String?
    private func suggest(_ text: String, from: CGRect, kind: Int) {
        if draft.name == text || pickedChip == text { Haptics.play(.warn); return }
        Haptics.play(.sel)
        pickedChip = text
        if reduceMotion { draft.name = text; Haptics.play(.pop); return }
        fly = (text, from, kind, UUID()); flyGo = false
        withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.52)) { flyGo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            draft.name = text; Haptics.play(.pop)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { sink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { sink = false } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { fly = nil }
    }

    private var stepWhere: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 18, weight: .bold)).foregroundStyle(HV.lime)
                TextField("", text: $draft.name, prompt: Text("行き先 ・ イベント").foregroundColor(.white.opacity(0.25))).font(LF.inter(900, 20)).foregroundStyle(.white).focused($focus)
                    .submitLabel(.next).onSubmit { if canNext { go(1) } }
                if !draft.name.isEmpty { Button { Haptics.play(.tick); draft.name = ""; pickedChip = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4)).frame(width: 44, height: 44) }.buttonStyle(.plain) }
            }.padding(.leading, 16).frame(height: 60).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(draft.name.isEmpty ? .clear : HV.lime, lineWidth: 1.5))
                .padding(.horizontal, 16).padding(.top, 14)
            Text("行き先 でも、イベント名 でも OK。あとで 変えられます。").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.45)).padding(.horizontal, 20).padding(.top, 12)
            FlowingChips(items: TripSuggestions.places, icon: "mappin", tint: HV.lime, period: 46, leftward: true, reduce: reduceMotion, selected: draft.name, paused: $pausedRow[0]) { t, f in suggest(t, from: f, kind: 0) }.padding(.top, 22)
            FlowingChips(items: TripSuggestions.events, icon: "star.fill", tint: Color(hex: "EE5E9C"), period: 54, leftward: false, reduce: reduceMotion, selected: draft.name, paused: $pausedRow[1]) { t, f in suggest(t, from: f, kind: 1) }.padding(.top, 10)
        }.padding(.top, 4)
    }

    // 2 いつ
    @Namespace private var segNS
    private var stepWhen: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: todayOverride ?? Date())
        let lead = cal.component(.weekday, from: today) - 1
        let days = (0..<28).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        let s = cal.startOfDay(for: draft.start), e = cal.startOfDay(for: draft.end)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach([("日帰り", 1), ("1泊2日", 2), ("2泊3日", 3), ("3泊4日", 4)], id: \.1) { t in
                    Button { Haptics.play(.sel); setDays(t.1) } label: {
                        Text(t.0).font(LF.inter(800, 14)).foregroundStyle(draft.days == t.1 ? Color(hex: "0B0C0D") : .white.opacity(0.8)).frame(maxWidth: .infinity).frame(height: 44)
                            .background { if draft.days == t.1 { Capsule().fill(HV.lime).matchedGeometryEffect(id: "seg", in: segNS) } }
                    }.buttonStyle(.plain)
                }
            }.padding(3).background(Color(hex: "121315"), in: Capsule()).animation(.timingCurve(0.3, 1.1, 0.4, 1, duration: 0.34), value: draft.days)
            VStack(spacing: 0) {
                HStack(spacing: 0) { ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { Text($0).font(LF.inter(700, 13)).foregroundStyle(.white.opacity(0.45)).frame(maxWidth: .infinity) } }.frame(height: 22).padding(.top, 14)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 46) }
                    ForEach(days, id: \.self) { d in
                        let inR = d >= s && d <= e, edge = d == s || d == e
                        Button { Haptics.play(.tick); tapDay(d) } label: {
                            ZStack {
                                if inR { Rectangle().fill(HV.lime.opacity(0.16)).frame(height: 40).padding(.leading, d == s ? 20 : 0).padding(.trailing, d == e ? 20 : 0) }
                                if edge { Circle().fill(HV.lime).frame(width: 40, height: 40) }
                                VStack(spacing: 1) {
                                    if cal.component(.day, from: d) == 1 { Text("\(cal.component(.month, from: d))月").font(LF.mono(8)).foregroundStyle(edge ? Color(hex: "0B0C0D") : HV.lime) }
                                    Text("\(cal.component(.day, from: d))").font(LF.inter(700, 18)).foregroundStyle(edge ? Color(hex: "0B0C0D") : .white)
                                    if d == today { Circle().fill(edge ? Color(hex: "0B0C0D") : HV.lime).frame(width: 4, height: 4) }
                                }
                            }.frame(height: 46)
                        }.buttonStyle(.plain)
                    }
                }.padding(.top, 6).padding(.bottom, 10)
            }.padding(.horizontal, 6).background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous)).padding(.top, 14)
            Text(pickingStart ? "はじまり → おわり の 順に タップ" : "おわりの 日を タップ").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.45)).padding(.top, 12).padding(.bottom, 20)
        }.padding(.horizontal, 16).padding(.top, 14)
    }

    // 3 だれと(4列の 丸)
    private var stepWho: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 16) {
                ForEach(friends) { f in
                    let on = draft.invited.contains(f.id)
                    Button { Haptics.play(on ? .soft : .pop); withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { if on { draft.invited.remove(f.id) } else { draft.invited.insert(f.id) } } } label: {
                        VStack(spacing: 8) {
                            ZStack(alignment: .bottomTrailing) {
                                ZStack { if let d = f.avatarData, let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFill() } else { Circle().fill(LinearGradient(colors: f.colors.count > 1 ? f.colors : [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(f.initial).font(LF.inter(900, 24)).foregroundStyle(.white)) } }
                                    .frame(width: 60, height: 60).clipShape(Circle()).overlay(Circle().strokeBorder(HV.lime, lineWidth: on ? 3 : 0).padding(-3))
                                if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "0B0C0D")).frame(width: 22, height: 22).background(HV.lime, in: Circle()).transition(.scale(scale: 0)).offset(x: 4, y: 4) }
                            }.frame(width: 66, height: 66)
                            Text(f.name).font(LF.inter(800, 12.5)).foregroundStyle(.white).lineLimit(1)
                        }.frame(maxWidth: .infinity)
                    }.buttonStyle(.plain)
                }
                VStack(spacing: 8) {
                    Image(systemName: "link").font(.system(size: 20, weight: .bold)).foregroundStyle(HV.lime).frame(width: 60, height: 60)
                        .overlay(Circle().strokeBorder(HV.lime.opacity(0.7), style: StrokeStyle(lineWidth: 1.6, dash: [4, 4]))).frame(width: 66, height: 66)
                    Text("リンク").font(LF.inter(800, 12.5)).foregroundStyle(.white)
                }.frame(maxWidth: .infinity)
            }
            (Text("\(members.count)人").foregroundColor(.white).bold() + Text(" ・ 1日 23枚を みんなで 撮る").foregroundColor(.white.opacity(0.45))).font(LF.inter(600, 15)).padding(.top, 24).padding(.bottom, 20)
        }.padding(.horizontal, 16).padding(.top, 18)
    }

    // 4 表紙(横に スナップ)
    private var stepCover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(photos.prefix(8).enumerated()), id: \.offset) { i, p in
                        let on = draft.coverIndex == i
                        Button { Haptics.play(.sel); draft.coverIndex = i } label: {
                            Color(hex: "2A2326").overlay { if let p { Image(uiImage: p).resizable().scaledToFill() } }.frame(width: 118, height: 157).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(HV.lime, lineWidth: on ? 3 : 0))
                                .overlay(alignment: .topTrailing) { if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(Color(hex: "0B0C0D")).frame(width: 22, height: 22).background(HV.lime, in: Circle()).padding(8) } }
                        }.buttonStyle(.plain).offset(y: on ? -4 : 0).animation(.spring(response: 0.3, dampingFraction: 0.7), value: on).scrollTransition(axis: .horizontal) { c, _ in c }
                    }
                }.scrollTargetLayout().padding(.horizontal, 16).padding(.vertical, 8)
            }.scrollTargetBehavior(.viewAligned)
            VStack(spacing: 0) {
                summaryRow("mappin", draft.name, 0)
                Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                summaryRow("calendar", "\(Self.md(draft.start)) → \(Self.md(draft.end)) ・ \(draft.days)日", 1)
                Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                summaryRow("star.fill", "\(members.count)人", 2)
            }.background(Color(hex: "121315"), in: RoundedRectangle(cornerRadius: 22, style: .continuous)).padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 20)
        }.padding(.top, 4)
    }

    private func summaryRow(_ icon: String, _ v: String, _ to: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(HV.lime).frame(width: 24)
            Text(v).font(LF.inter(800, 17)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Button { Haptics.play(.sel); go(to) } label: { Text("変える").font(LF.inter(800, 15)).foregroundStyle(HV.lime).frame(minWidth: 44, minHeight: 44) }.buttonStyle(.plain)
        }.padding(.horizontal, 16).frame(minHeight: 54)
    }

    // MARK: 日 ・ カレンダー

    private func setDays(_ n: Int) {
        draft.end = Calendar.current.date(byAdding: .day, value: n - 1, to: draft.start) ?? draft.start
    }
    private func tapDay(_ d: Date) {
        if pickingStart { draft.start = d; draft.end = d; pickingStart = false }
        else if d >= draft.start { draft.end = d; pickingStart = true }
        else { draft.start = d; draft.end = d }
    }
    private static func md(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MM/dd"; return f.string(from: d) }
    private static func wd(_ d: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "E"; return f.string(from: d) }

    // MARK: つくる(今までの しくみ)

    private func create() {
        guard !creating else { return }
        creating = true
        Haptics.play(.projector)
        Task { @MainActor in
            let result = await TripCreator.create(draft: draft, cover: cover, friends: friends, context: modelContext, user: UserProfile.current(from: profiles))
            creating = false
            switch result {
            case .success(let made):
                Haptics.play(.success)
                pass = TripPassData(name: made.name, sub: draft.name, from: Self.upper(draft.start), to: Self.upper(draft.end), days: draft.days, key: made.key, link: made.link, cover: cover, members: members.map { $0.1 }, names: members.map { $0.0 })
            case .failure(let message):
                Haptics.play(.warn); errorText = message
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { errorText = nil }
            }
        }
    }
    private static func upper(_ d: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = "MMM dd"; return f.string(from: d).uppercased() }
}

/// 折り返して ならべる チップ
struct FlowChips<Item: Hashable, V: View>: View {
    let items: [Item]
    var spacing: CGFloat = 8
    @ViewBuilder var content: (Item) -> V
    var body: some View {
        _FlowLayout(spacing: spacing) { ForEach(items, id: \.self) { content($0) } }
    }
}
private struct _FlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 358
        var x: CGFloat = 0, y: CGFloat = 0, h: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > w { x = 0; y += h + spacing; h = 0 }; x += sz.width + spacing; h = max(h, sz.height) }
        return CGSize(width: w, height: y + h)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, h: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > b.maxX { x = b.minX; y += h + spacing; h = 0 }; s.place(at: CGPoint(x: x, y: y), proposal: .unspecified); x += sz.width + spacing; h = max(h, sz.height) }
    }
}

// MARK: - 作る(LaterGroup + 共有)

enum TripCreator {
    struct Made { let name: String; let key: String; let link: String }
    enum Result { case success(Made), failure(String) }

    @MainActor static func create(draft: TripDraft, cover: UIImage?, friends: [GroupCreateFriend], context: ModelContext, user: UserProfile?) async -> Result {
        guard let user else { return .failure("自分の プロフィールが まだ 読めていません") }
        guard let cloud = CloudKitManager.current else { return .failure("iCloud に まだ つながっていません") }
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let group = LaterGroup(name: name, host: user, autoGenerateMission: false, isPrivate: true)
        group.memberLimit = GroupMembershipPolicy.maxMembersPerGroup
        group.colorIndex = GroupPalette.index(forName: name)
        group.faceStyle = GroupFaceStyle.aura
        group.showsInitial = true
        if let data = cover?.jpegData(compressionQuality: 0.8) { group.iconImageData = data }
        group.joinedAt = Date()
        _ = group.addMember(user)
        context.insert(group)
        let service = GroupSharingService(container: cloud.container, modelContext: context, cloudKitManager: cloud)
        do { try await service.createGroup(group, hostProfile: user) }
        catch GroupSharingError.quotaExceeded(groupCreatedWithoutImages: true) { }
        catch {
            context.delete(group); try? context.save()
            return .failure(GroupCreateFailureText.reason(for: error))
        }
        var link = await NewGroupFlowView.makeLink(for: group, context: context)
        if link == nil { try? await Task.sleep(for: .seconds(1)); link = await NewGroupFlowView.makeLink(for: group, context: context) }
        guard let link else { return .failure(NewGroupFlowView.lastLinkFailureReason ?? "リンクを つくれませんでした") }
        let share = InviteConfig.shareURL(from: link) ?? link
        let key = (try? await GroupInviteService.passphrase(for: group, context: context)) ?? ""
        if !draft.invited.isEmpty {
            let ok = await FriendCloud.sendInvites(to: Array(draft.invited), groupName: group.name, memberCount: group.members.count, shareURL: link, myName: user.name)
            if ok { GroupInviteSentStore.add(Array(draft.invited), to: group.id) }
        }
        return .success(Made(name: name, key: key, link: share.absoluteString))
    }
}

// MARK: - パス(T03 T05)

struct TripPassData {
    var name: String
    var sub: String
    var from: String
    var to: String
    var days: Int
    var key: String
    var link: String
    var cover: UIImage?
    var members: [UIImage?]
    var names: [String]
}

struct TripPassView: View {
    var data: TripPassData
    var newlyMade = false
    var onStart: () -> Void = {}
    var onClose: () -> Void = {}
    @State private var shareItems: [Any]?
    @State private var copied = false

    private var keyParts: (String, String) {
        let k = data.key.hasPrefix("#") ? String(data.key.dropFirst()) : data.key
        let digits = String(k.reversed().prefix(while: \.isNumber).reversed())
        return ("#" + String(k.dropLast(digits.count)), digits)
    }

    var body: some View {
        ZStack {
            Color(hex: "0A0A0B").ignoresSafeArea()
            RadialGradient(colors: [Color(hex: "24A03C").opacity(0.22), .clear], center: UnitPoint(x: 0.1, y: 0.4), startRadius: 0, endRadius: 260).ignoresSafeArea()
            VStack(spacing: 0) {
                Text(newlyMade ? "YOUR TRIP IS READY" : "TRIP PASS").font(LF.mono(11)).tracking(3.3).foregroundStyle(Color(hex: "61DD7A")).padding(.top, 110)
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        ZStack { Color(hex: "2A2326"); if let c = data.cover { Image(uiImage: c).resizable().scaledToFill() } }
                        LinearGradient(colors: [.black.opacity(0.3), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack { Text("LATTAG").font(LF.mono(10.5)).tracking(2); Spacer(); Text("TRIP PASS").font(LF.mono(10.5)).tracking(2) }.foregroundStyle(.white.opacity(0.65))
                            Text(data.name).font(LF.serif(42)).foregroundStyle(.white).padding(.top, 14)
                            Text(data.sub).font(LF.inter(700, 12)).foregroundStyle(.white.opacity(0.75)).padding(.top, 0)
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) { Text("FROM").font(LF.mono(8)).tracking(1.5).foregroundStyle(.white.opacity(0.6)); Text(data.from).font(LF.mono(15)).fontWeight(.bold).foregroundStyle(.white) }
                                Image(systemName: "arrow.right").font(.system(size: 18, weight: .light)).foregroundStyle(.white.opacity(0.7)).padding(.top, 18).padding(.horizontal, 12)
                                VStack(alignment: .leading, spacing: 2) { Text("TO").font(LF.mono(8)).tracking(1.5).foregroundStyle(.white.opacity(0.6)); Text(data.to).font(LF.mono(15)).fontWeight(.bold).foregroundStyle(.white) }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) { Text("DAYS").font(LF.mono(8)).tracking(1.5).foregroundStyle(.white.opacity(0.6)); Text("\(data.days)").font(LF.mono(15)).fontWeight(.bold).foregroundStyle(.white) }
                            }.padding(.top, 22)
                            HStack(spacing: 10) {
                                HStack(spacing: -8) { ForEach(Array(data.members.prefix(3).enumerated()), id: \.offset) { i, m in TripTicket(draft: TripDraft(), cover: nil, members: []).memberDot(m, data.names[safe: i] ?? "", 26).overlay(Circle().strokeBorder(.white, lineWidth: 2)) } }
                                Text("\(data.members.count) aboard ・ 23 / day").font(LF.mono(9.5)).fontWeight(.bold).foregroundStyle(.white.opacity(0.85))
                            }.padding(.top, 16)
                        }.padding(18)
                    }.frame(height: 215).clipped()
                    VStack(spacing: 0) {
                        if let qr = QRImage.make(data.link) { Image(uiImage: qr).interpolation(.none).resizable().frame(width: 110, height: 110).padding(.top, 26) }
                        Text("KEY").font(LF.mono(8.5)).tracking(2).foregroundStyle(Color(hex: "0B0C0D").opacity(0.5)).padding(.top, 20)
                        (Text(keyParts.0).foregroundColor(Color(hex: "0B0C0D")) + Text(keyParts.1).foregroundColor(Color(hex: "24A03C"))).font(LF.inter(900, 34)).tracking(-1.2).minimumScaleFactor(0.6).lineLimit(1).padding(.top, 4)
                        Text("SCAN TO JOIN ・ あした 9:00 に 現像").font(LF.mono(8.5)).tracking(1).foregroundStyle(Color(hex: "0B0C0D").opacity(0.5)).padding(.top, 6).padding(.bottom, 22)
                    }.frame(maxWidth: .infinity).background(Color(hex: "F3F0EA"))
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)).frame(width: 300).padding(.top, 14)
                HStack(spacing: 8) {
                    passButton("square.and.arrow.up", "Share") { shareItems = ["\(data.name) に きて ね\n\(data.link)"] }
                    passButton("arrow.down.to.line", "Save") { Haptics.play(.tick) }
                    passButton("doc.on.doc", copied ? "Copied" : "Copy key") { UIPasteboard.general.string = data.key; copied = true; Haptics.play(.success) }
                }.frame(width: 300).padding(.top, 12)
                Button { Haptics.play(.click); onStart() } label: { Text("Start the trip").font(LF.inter(800, 17)).foregroundStyle(Color(hex: "0B0C0D")).frame(maxWidth: .infinity).frame(height: 52).background(Color(hex: "F4F1EA"), in: Capsule()) }
                    .buttonStyle(HVPress(scale: 0.98)).frame(width: 300).padding(.top, 12)
                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }.presentationDetents([.medium, .large]) }
    }

    private func passButton(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 17, weight: .semibold)); Text(title).font(LF.inter(700, 12.5)) }.foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 60).background(Color(hex: "1C1C1E"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.95))
    }
}


// MARK: - 候補(あとで サーバーから 季節で 変えられる ように ここに まとめる)

enum TripSuggestions {
    static let places = ["京都", "沖縄", "大阪", "北海道", "福岡", "金沢", "箱根", "鎌倉", "名古屋", "広島", "横浜", "長野", "ディズニー", "USJ", "ソウル", "台湾", "ハワイ"]
    static let events = ["修学旅行", "卒業旅行", "合宿", "ライブ遠征", "部活の 遠征", "文化祭", "体育祭", "夏祭り", "花火大会", "誕生日", "クリスマス", "卒業式", "テスト明け", "いつメン旅"]
}

/// 横に 流れる 候補の 列(長押しで 止まる ・ タップで パスへ とぶ ・ 左右の はしは とける)
struct FlowingChips: View {
    let items: [String]
    let icon: String
    let tint: Color
    let period: Double
    let leftward: Bool
    let reduce: Bool
    let selected: String
    @Binding var paused: Bool
    var onPick: (String, CGRect) -> Void

    private final class Clock { var last: Date?; var acc = 0.0 }
    @State private var clock = Clock()
    @State private var width: CGFloat = 1

    private func chips(_ copy: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { t in
                GeometryReader { g in
                    chip(t).contentShape(Capsule()).onTapGesture { onPick(t, g.frame(in: .global)) }
                }.frame(width: Self.estimate(t), height: 44)
            }
        }.padding(.trailing, 8)
    }

    private static func estimate(_ t: String) -> CGFloat { CGFloat(t.count) * 15.5 + 16 + 14 + 32 }

    private func chip(_ t: String) -> some View {
        let on = selected == t
        return HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(on ? Color(hex: "0B0C0D") : tint)
            Text(t).font(LF.inter(800, 15)).foregroundStyle(on ? Color(hex: "0B0C0D") : .white).lineLimit(1).fixedSize()
        }.padding(.horizontal, 16).frame(height: 44).background(on ? HV.lime : Color(hex: "17181B"), in: Capsule())
    }

    var body: some View {
        let w = items.reduce(CGFloat(0)) { $0 + Self.estimate($1) + 8 } + 8
        Group {
            if reduce {
                ScrollView(.horizontal, showsIndicators: false) { chips(0).padding(.horizontal, 16) }
            } else {
                TimelineView(.animation(paused: false)) { ctx in
                    let _ = tick(ctx.date)
                    let u = (clock.acc.truncatingRemainder(dividingBy: period)) / period
                    let x = (leftward ? -u : u - 1) * w
                    Color.clear.frame(maxWidth: .infinity).frame(height: 44)
                        .overlay(alignment: .leading) { HStack(spacing: 0) { chips(0); chips(1) }.fixedSize().offset(x: x) }
                }
                .frame(height: 44).clipped()
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.09), .init(color: .black, location: 0.91), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
                .onLongPressGesture(minimumDuration: 0.15, maximumDistance: 12, perform: {}, onPressingChanged: { p in if p != paused { paused = p; if p { Haptics.play(.tick) } } })
            }
        }.frame(height: 44)
    }

    private func tick(_ now: Date) -> Bool {
        if let l = clock.last, !paused { clock.acc += min(0.1, now.timeIntervalSince(l)) }
        clock.last = now
        return true
    }
}
