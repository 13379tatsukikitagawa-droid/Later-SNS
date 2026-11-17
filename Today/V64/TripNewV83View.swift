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

/// チケットの 見本(クリーム ・ 高さ 118)。入力する たびに その場で 変わる
struct TripTicket: View {
    var draft: TripDraft
    var cover: UIImage?
    var members: [(String, UIImage?)]
    private static let df: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MM/dd"; return f }()

    var body: some View {
        HStack(spacing: 0) {
            ZStack { Color(hex: "2A2326"); if let cover { Image(uiImage: cover).resizable().scaledToFill() } }.frame(width: 96, height: 118).clipped()
            VStack(alignment: .leading, spacing: 0) {
                Text("LATTAG ・ TRIP PASS").font(LF.mono(10.5)).tracking(1.5).foregroundStyle(Color(hex: "0B0C0D").opacity(0.5))
                Text(draft.name.isEmpty ? "どこへ?" : draft.name).font(LF.inter(900, 24)).foregroundStyle(Color(hex: "0B0C0D").opacity(draft.name.isEmpty ? 0.28 : 1)).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 3)
                Text("\(Self.df.string(from: draft.start)) → \(Self.df.string(from: draft.end)) ・ \(draft.days) DAYS").font(LF.mono(12.5)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.55)).padding(.top, 2)
                HStack(spacing: 8) {
                    HStack(spacing: -8) { ForEach(Array(members.prefix(3).enumerated()), id: \.offset) { _, m in memberDot(m.1, m.0, 26).overlay(Circle().strokeBorder(Color(hex: "F4EFE6"), lineWidth: 2)) } }
                    Text("\(members.count)人 ・ 1日 23枚").font(LF.mono(12)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.55))
                }.padding(.top, 8)
            }.padding(.leading, 14).frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 0) { ForEach(0..<12, id: \.self) { i in Rectangle().fill(i % 2 == 0 ? Color(hex: "C8F25A") : Color(hex: "24A03C")).frame(width: 8, height: 118.0 / 12) } }
        }
        .frame(height: 118).background(Color(hex: "F4EFE6")).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
    }

    func memberDot(_ img: UIImage?, _ name: String, _ size: CGFloat) -> some View {
        ZStack {
            if let img { Image(uiImage: img).resizable().scaledToFill() }
            else { Circle().fill(LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, size * 0.42)).foregroundStyle(.white)) }
        }.frame(width: size, height: size).clipShape(Circle())
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

    private let places = ["京都", "沖縄", "大阪", "北海道", "修学旅行", "卒業旅行", "合宿", "ライブ遠征", "部活の 遠征"]
    private var cover: UIImage? { photos.indices.contains(draft.coverIndex) ? photos[draft.coverIndex] : nil }
    private var members: [(String, UIImage?)] {
        [("あなた", myAvatar)] + friends.filter { draft.invited.contains($0.id) }.map { ($0.name, $0.avatarData.flatMap { UIImage(data: $0) }) }
    }
    private var canNext: Bool { step == 0 ? !draft.name.trimmingCharacters(in: .whitespaces).isEmpty : true }

    var body: some View {
        ZStack {
            Color(hex: "0A0A0B").ignoresSafeArea()
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

    private var wizard: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                topBar.padding(.top, 54)
                TripTicket(draft: draft, cover: cover, members: members).padding(.horizontal, 16).padding(.top, 14)
                ZStack {
                    Group {
                        switch step {
                        case 0: stepWhere
                        case 1: stepWhen
                        case 2: stepWho
                        default: stepCover
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: back ? .leading : .trailing).combined(with: .opacity), removal: .move(edge: back ? .trailing : .leading).combined(with: .opacity)))
                }
                .animation(reduceMotion ? nil : .timingCurve(0.3, 1, 0.4, 1, duration: 0.38), value: step)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                bottomButton.padding(.horizontal, 16).padding(.bottom, 34)
            }
            if let errorText { Text(errorText).font(LF.inter(700, 13)).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10).background(Color(hex: "FF3B30"), in: Capsule()).padding(.top, 120) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { Haptics.play(.sel); if step == 0 { onClose() } else { go(step - 1) } } label: {
                Image(systemName: step == 0 ? "xmark" : "chevron.left").font(.system(size: 17, weight: .black)).foregroundStyle(.white).frame(width: 44, height: 44).background(Color(hex: "1C1C1E"), in: Circle())
            }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel(step == 0 ? "とじる" : "もどる")
            HStack(spacing: 5) { ForEach(0..<4, id: \.self) { i in Capsule().fill(i <= step ? HV.lime : Color.white.opacity(0.14)).frame(height: 4) } }
            Text("\(step + 1) / 4").font(LF.mono(11)).fontWeight(.bold).foregroundStyle(.white.opacity(0.5)).frame(width: 40, alignment: .trailing)
        }.padding(.horizontal, 16)
    }

    private var bottomButton: some View {
        let last = step == 3
        return Button {
            if last { create() } else { Haptics.play(.click); go(step + 1) }
        } label: {
            Text(creating ? "つくっています…" : (last ? "Trip を つくる" : "つぎへ")).font(LF.inter(800, 17)).foregroundStyle(Color(hex: "0B0C0D")).frame(maxWidth: .infinity).frame(height: 56)
                .background(last ? HV.lime : Color.white, in: Capsule()).opacity(canNext ? 1 : 0.28)
        }.buttonStyle(HVPress(scale: 0.98)).disabled(!canNext || creating)
    }

    private func go(_ s: Int) {
        back = s < step
        focus = false
        withAnimation(.timingCurve(0.3, 1, 0.4, 1, duration: 0.38)) { step = s }
    }

    // 1 どこへ
    private var stepWhere: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("", text: $draft.name, prompt: Text("どこへ?").foregroundColor(.white.opacity(0.18))).font(LF.inter(800, 30)).foregroundStyle(.white).focused($focus)
                .frame(height: 64).submitLabel(.next).onSubmit { if canNext { go(1) } }
            Rectangle().fill(HV.lime).frame(height: 2)
            FlowChips(items: places, spacing: 8) { p in
                Button { Haptics.play(.sel); draft.name = ["京都", "沖縄", "大阪", "北海道"].contains(p) ? "\(p) 2泊3日" : p; setDays(3) } label: {
                    Text(p).font(LF.inter(800, 15)).foregroundStyle(.white).padding(.horizontal, 16).frame(height: 40).background(Color(hex: "1C1C1E"), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }.buttonStyle(HVPress(scale: 0.94))
            }.padding(.top, 16)
            Text("行き先 でも、イベント名 でも OK。あとで 変えられます。").font(LF.inter(600, 14)).foregroundStyle(.white.opacity(0.45)).padding(.top, 16)
        }.padding(.horizontal, 16).padding(.top, 10)
    }

    // 2 いつ
    private var stepWhen: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: todayOverride ?? Date())
        let lead = cal.component(.weekday, from: today) - 1
        let days = (0..<21).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
        let s = cal.startOfDay(for: draft.start), e = cal.startOfDay(for: draft.end)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach([("日帰り", 1), ("1泊2日", 2), ("2泊3日", 3), ("3泊4日", 4)], id: \.1) { t in
                    Button { Haptics.play(.sel); setDays(t.1) } label: {
                        Text(t.0).font(LF.inter(800, 15)).foregroundStyle(draft.days == t.1 ? Color(hex: "0B0C0D") : .white).padding(.horizontal, 14).frame(height: 40)
                            .background(draft.days == t.1 ? HV.lime : Color(hex: "1C1C1E"), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(draft.days == t.1 ? 0 : 0.1), lineWidth: 1))
                    }.buttonStyle(HVPress(scale: 0.94))
                }
            }
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
                                Text("\(cal.component(.day, from: d))").font(LF.inter(700, 18)).foregroundStyle(edge ? Color(hex: "0B0C0D") : .white)
                                if d == today || cal.component(.day, from: d) == 1 { Text("\(cal.component(.month, from: d))月").font(LF.inter(700, 9)).foregroundStyle(.white.opacity(0.45)).offset(y: -22) }
                            }.frame(height: 46)
                        }.buttonStyle(.plain)
                    }
                }.padding(.top, 6).padding(.bottom, 10)
            }.padding(.horizontal, 6).background(Color(hex: "141517"), in: RoundedRectangle(cornerRadius: 24, style: .continuous)).padding(.top, 14)
            (Text("はじまりの 日 → おわりの 日 の 順に タップ ・ ").foregroundColor(.white.opacity(0.45)) + Text("\(Self.md(draft.start))(\(Self.wd(draft.start)))→ \(Self.md(draft.end))(\(Self.wd(draft.end))) ・ \(draft.days)日").foregroundColor(.white).bold())
                .font(LF.inter(600, 14)).padding(.top, 16)
        }.padding(.horizontal, 16).padding(.top, 14)
    }

    // 3 だれと
    private var stepWho: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(friends) { f in
                        let on = draft.invited.contains(f.id)
                        Button { Haptics.play(.sel); if on { draft.invited.remove(f.id) } else { draft.invited.insert(f.id) } } label: {
                            HStack(spacing: 14) {
                                ZStack { if let d = f.avatarData, let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFill() } else { Circle().fill(LinearGradient(colors: f.colors.count > 1 ? f.colors : [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing)).overlay(Text(f.initial).font(LF.inter(900, 18)).foregroundStyle(.white)) } }.frame(width: 44, height: 44).clipShape(Circle())
                                Text(f.name).font(LF.inter(800, 20)).foregroundStyle(.white)
                                Spacer()
                                ZStack { if on { Circle().fill(HV.lime); Image(systemName: "checkmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color(hex: "0B0C0D")) } else { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 2) } }.frame(width: 36, height: 36)
                            }.padding(.horizontal, 12).frame(height: 62).background(on ? Color(hex: "141A12") : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxHeight: 280)
            HStack(spacing: 14) {
                Image(systemName: "arrow.up.right").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).frame(width: 40, height: 40).background(Color(hex: "1C1C1E"), in: Circle())
                VStack(alignment: .leading, spacing: 2) { Text("リンクで よぶ").font(LF.inter(800, 17)).foregroundStyle(.white); Text("あとから QR ・ KEY でも 入れます").font(LF.inter(600, 14)).foregroundStyle(.white.opacity(0.45)) }
                Spacer()
            }.padding(14).background(Color(hex: "141517"), in: RoundedRectangle(cornerRadius: 20, style: .continuous)).padding(.top, 14)
            (Text("\(members.count)人").foregroundColor(.white).bold() + Text(" ・ 1日 23枚を みんなで 撮る").foregroundColor(.white.opacity(0.45))).font(LF.inter(600, 15)).padding(.top, 20)
        }.padding(.horizontal, 16).padding(.top, 14)
    }

    // 4 表紙
    private var stepCover: some View {
        VStack(alignment: .leading, spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(photos.prefix(6).enumerated()), id: \.offset) { i, p in
                    Button { Haptics.play(.sel); draft.coverIndex = i } label: {
                        Color(hex: "2A2326").aspectRatio(3 / 4, contentMode: .fit).overlay { if let p { Image(uiImage: p).resizable().scaledToFill() } }.clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HV.lime, lineWidth: draft.coverIndex == i ? 3 : 0).padding(-1))
                    }.buttonStyle(HVPress(scale: 0.96))
                }
            }.padding(.top, 8)
            VStack(spacing: 0) {
                summaryRow("どこへ", draft.name, 0)
                Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                summaryRow("いつ", "\(Self.md(draft.start)) → \(Self.md(draft.end))", 1)
                Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                summaryRow("だれと", "\(members.count)人", 2)
            }.background(Color(hex: "141517"), in: RoundedRectangle(cornerRadius: 22, style: .continuous)).padding(.top, 14)
        }.padding(.horizontal, 16).padding(.top, 4)
    }

    private func summaryRow(_ k: String, _ v: String, _ to: Int) -> some View {
        HStack {
            Text(k).font(LF.inter(600, 14)).foregroundStyle(.white.opacity(0.45)).frame(width: 64, alignment: .leading)
            Text(v).font(LF.inter(800, 18)).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Button { Haptics.play(.sel); go(to) } label: { Text("変える").font(LF.inter(800, 15)).foregroundStyle(HV.lime) }.buttonStyle(.plain)
        }.padding(.horizontal, 16).frame(height: 54)
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
