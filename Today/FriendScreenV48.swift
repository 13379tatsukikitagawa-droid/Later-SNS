import SwiftData
import SwiftUI

/// v48/v48b/v48c:ともだち画面を ぜんぶ 作りなおし。黒い 背景・大きな 12の 席・
/// 自分の チェキ・なかまの イラスト(「BUMP」の文字は 出さない)。
/// 友達追加・ブロック・通報は 今ある 処理を 呼ぶだけ。
struct FriendScreenV48: View {
    let myName: String
    var myColorIndex: Int?
    var myAvatarData: Data?
    let friends: [HomeFriend]
    let groups: [LaterGroup]
    let onClose: () -> Void
    /// v48:「とどいた」(ともだち申請の受信)は 今の FriendsHubView の タブへ
    var onOpenInbox: () -> Void = {}
    var onOpenInviteToGroup: () -> Void = {}
    var onEditProfile: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @State private var pendingInboxCount = 0
    @State private var selected: HomeFriend?
    @State private var showsFriendScan = false
    @State private var shareItems: [Any]?
    @State private var toast: String?
    @State private var holding = false
    @State private var ring: CGFloat = 0
    @State private var holdTask: Task<Void, Never>?
    @State private var cardFlipped = false
    @State private var actionFriend: HomeFriend?
    @State private var confirmingBlock: HomeFriend?
    @State private var reportingFriend: HomeFriend?

    /// v54:チェキの 日付スタンプ(見本:'26 11 13)
    private static func stampDate(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %02d %02d", (c.year ?? 2026) % 100, c.month ?? 1, c.day ?? 1)
    }

    private static let seatCount = 12
    private static let radius: CGFloat = 130
    private static let seatSize: CGFloat = 52

    private var myRecordName: String { CloudKitManager.current?.currentUserRecordName ?? "" }
    private var isFull: Bool { friends.count >= FriendRules.maxFriends }
    private var list: [HomeFriend] { friends.filter { !$0.isMe } }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 18) {
                        ring12
                        selfCheki
                        if !list.isEmpty {
                            todayList
                        }
                        connectTiles
                        Text("12人まで ・ 数は 出ません")
                            .font(Darkroom.mono(10.5))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 10)
                }
                .scrollIndicators(.hidden)
                .lgScrollEdgeSoft()
            }
        }
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(.white))
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toast)
        .fullScreenCover(isPresented: $showsFriendScan) {
            FriendQRScanView(myName: myName, friendCount: friends.count) { message in show(message) }
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { done in
                shareItems = nil
                if done { Haptics.play(.success) }
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("", isPresented: Binding(get: { actionFriend != nil }, set: { if !$0 { actionFriend = nil } }), titleVisibility: .hidden) {
            if let friend = actionFriend {
                Button("ふたりの グループを つくる") { makePair(friend) }
                Button("席で 見る") { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = friend } }
                Button("ブロックする", role: .destructive) { confirmingBlock = friend }
                Button("通報する", role: .destructive) { reportingFriend = friend }
                Button("やめる", role: .cancel) {}
            }
        }
        .confirmationDialog("\(confirmingBlock?.name ?? "") を ブロックしますか?", isPresented: Binding(get: { confirmingBlock != nil }, set: { if !$0 { confirmingBlock = nil } }), titleVisibility: .visible) {
            Button("ブロックする", role: .destructive) { if let f = confirmingBlock { block(f) } }
            Button("やめる", role: .cancel) {}
        }
        .sheet(item: $reportingFriend) { friend in
            ReportSheet(targetType: .user, targetID: friend.id)
        }
        .task { pendingInboxCount = await FriendCloud.inbox().filter { $0.status == .pending }.count }
    }

    // MARK: 背景:ぼけた 写真 + ぼけた チェキ + ビネット

    private var background: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Color.black
                if let data = myAvatarData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .blur(radius: 40).brightness(-0.4).saturation(0.8)
                        .opacity(0.6)
                }
                ForEach(0..<5, id: \.self) { i in
                    let phase = t / 9 + Double(i) * 1.3
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LayerAvatar.colors(UUID(), override: i % LayerAvatar.palettes.count).first ?? .white)
                        .frame(width: 90, height: 112)
                        .blur(radius: 6)
                        .opacity(0.14)
                        .rotationEffect(.degrees(Double(i) * 11 - 22))
                        .offset(x: CGFloat(i - 2) * 80, y: reduceMotion ? 0 : CGFloat(sin(phase)) * 14 - 60 + CGFloat(i) * 90)
                }
                RadialGradient(colors: [.clear, .black.opacity(0.75)], center: .center, startRadius: 160, endRadius: 420)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: 見出し

    /// v54:見本 C01 の .ftl em:Instrument Serif(立体)44px、字間 -0.44px
    private var friendTitle: some View {
        Text(verbatim: "Friend")
            .font(LF.serif(44))
            .tracking(-0.44)
            .foregroundStyle(.white)
    }

    private var header: some View {
        // mock .fhd:back・大きな 左づめの タイトル・右に Add。下ぞろえ。
        HStack(alignment: .bottom, spacing: 12) {
            Button {
                Haptics.play(.soft)
                onClose()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42).background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("戻る")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                friendTitle
                Text(verbatim: "\(list.count) / \(Self.seatCount)")
                    .font(LF.mono(11, bold: true)).tracking(1.54)
                    .foregroundStyle(LaterColor.filmLight)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.play(.tick)
                showsFriendScan = true
            } label: {
                Text("Add").font(LF.inter(800, 14)).foregroundStyle(.black)
                    .padding(.horizontal, 18).frame(height: 38).background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .overlay(alignment: .topTrailing) {
            if pendingInboxCount > 0 {
                Button {
                    Haptics.play(.tick)
                    onOpenInbox()
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .overlay(alignment: .topTrailing) {
                            Circle().fill(Darkroom.orange).frame(width: 9, height: 9).offset(x: 2, y: -2)
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 46)
                .padding(.trailing, 18)
                .accessibilityLabel("とどいた ともだち申請、\(pendingInboxCount)件")
            }
        }
    }

    // MARK: 12の 席

    private var ring12: some View {
        ZStack {
            // mock .tk:60こまの 分 目もり(5つめ ごとに 太く・長く)。席は 12。
            ForEach(0..<60, id: \.self) { tick(for: $0) }
            ForEach(Array(list.prefix(Self.seatCount).enumerated()), id: \.element.id) { index, friend in
                seat(friend: friend, index: index)
            }
            if list.count < Self.seatCount {
                nextSeat(index: list.count)
            }
            ForEach((list.count + 1)..<Self.seatCount, id: \.self) { index in
                emptySeat(index: index)
            }
            center
        }
        .frame(width: (Self.radius + 40) * 2, height: (Self.radius + 40) * 2)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture { if selected != nil { Haptics.play(.soft); selected = nil } }
    }

    private func tick(for index: Int) -> some View {
        let thick = index % 5 == 0
        let angle = Double(index) / 60 * 2 * .pi - .pi / 2
        let outer = Self.radius + 16
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(.white.opacity(thick ? 0.32 : 0.14))
            .frame(width: thick ? 2.6 : 1.6, height: thick ? 10 : 6)
            .rotationEffect(.degrees(Double(index) / 60 * 360))
            .offset(x: cos(angle) * outer, y: sin(angle) * outer)
    }

    private func position(for index: Int) -> CGPoint {
        let angle = Double(index) / Double(Self.seatCount) * 2 * .pi - .pi / 2
        return CGPoint(x: cos(angle) * Self.radius, y: sin(angle) * Self.radius)
    }

    private func seat(friend: HomeFriend, index: Int) -> some View {
        let point = position(for: index)
        return Button {
            Haptics.play(.detent)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = friend }
        } label: {
            ZStack(alignment: .topTrailing) {
                LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                    .frame(width: Self.seatSize, height: Self.seatSize)
                    .saturation(friend.hasShot ? 1 : 0.3)
                    .opacity(friend.hasShot ? 1 : 0.55)
                    .overlay(Circle().strokeBorder(friend.hasShot ? Darkroom.orange : .white.opacity(0.16), lineWidth: friend.hasShot ? 2.6 : 1.4))
                    .shadow(color: friend.hasShot ? Darkroom.orange.opacity(0.7) : .clear, radius: 8)
                if friend.hasShot {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .black)).foregroundStyle(.black)
                        .frame(width: 18, height: 18).background(Circle().fill(Darkroom.orange)).offset(x: 4, y: -4)
                }
            }
            .overlay(alignment: .topLeading) {
            }
        }
        .buttonStyle(.plain)
        .offset(x: point.x, y: point.y)
        .accessibilityLabel("\(friend.name)。\(friend.hasShot ? "今日 撮った" : "まだ")")
    }

    private func nextSeat(index: Int) -> some View {
        let point = position(for: index)
        return Button {
            Haptics.play(.pop)
            showsFriendScan = true
        } label: {
            PulsingDashedSeatBig()
        }
        .buttonStyle(.plain)
        .offset(x: point.x, y: point.y)
        .accessibilityLabel("ともだちを呼ぶ")
    }

    private func emptySeat(index: Int) -> some View {
        let point = position(for: index)
        return Button {
            Haptics.play(.pop)
            showsFriendScan = true
        } label: {
            Circle().strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.6, dash: [3, 5]))
                .frame(width: Self.seatSize, height: Self.seatSize)
        }
        .buttonStyle(.plain)
        .offset(x: point.x, y: point.y)
        .accessibilityHidden(true)
    }

    // MARK: まんなか:QR で つながる(長押し)

    @ViewBuilder
    private var center: some View {
        if let selected {
            selectedCenter(selected)
        } else {
            holdCenter
        }
    }

    private var holdCenter: some View {
        let colors = list.prefix(4).map { LayerAvatar.colors($0.seed).first ?? .white }
        let mascotColors = colors.isEmpty ? [LayerAvatar.colors(UUID(), override: myColorIndex).first ?? Darkroom.orange] : Array(colors)
        return ZStack {
            Circle().fill(Color(hex: "16161A"))
            Circle().trim(from: 0, to: max(0.0, ring))
                .stroke(Darkroom.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            FriendGatheringGroup(colors: mascotColors, shaking: holding, seatSize: 34)
                .offset(y: 10)
        }
        .frame(width: 176, height: 176)
        .scaleEffect(holding ? 0.97 : 1)
        .animation(.easeOut(duration: 0.15), value: holding)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 1.5, maximumDistance: 30) {
            completeHold()
        } onPressingChanged: { pressing in
            holdTask?.cancel()
            if pressing {
                guard !isFull else { Haptics.play(.warn); show("12の 席が、うまりました"); return }
                holding = true
                ring = 0
                Haptics.play(.rumble)
                withAnimation(.linear(duration: 1.5)) { ring = 1 }
            } else {
                if holding, ring < 0.98 { show("もうすこし") }
                holding = false
                withAnimation(.easeOut(duration: 0.3)) { ring = 0 }
            }
        }
        .accessibilityLabel("ながおしで、QR を よみとる")
        .accessibilityAddTraits(.isButton)
    }

    private func completeHold() {
        holding = false
        ring = 0
        guard !isFull else { Haptics.play(.warn); show("12の 席が、うまりました"); return }
        Haptics.play(.success)
        showsFriendScan = true
    }

    private func selectedCenter(_ friend: HomeFriend) -> some View {
        VStack(spacing: 8) {
            LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                .frame(width: 62, height: 62)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))
            Text(friend.name).font(Darkroom.title(friend.name, size: 26)).foregroundStyle(.white).lineLimit(1)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(friend.hasShot ? Darkroom.orange : .white.opacity(0.18))
                        .frame(width: 7, height: 10)
                }
            }
        }
        .frame(width: 176, height: 176)
        .transition(.opacity)
    }

    // MARK: 自分の チェキ

    private var selfCheki: some View {
        let myInitial = String(myName.prefix(1))
        return Button {
            Haptics.play(.tick)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { cardFlipped.toggle() }
        } label: {
            ZStack {
                if cardFlipped {
                    qrBack.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    chekiFront(myInitial)
                }
            }
            .frame(width: 236, height: 300)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .rotationEffect(.degrees(-2))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            .rotation3DEffect(.degrees(cardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("自分の カード。タップで QR")
    }

    /// v54:見本 C01 の #fmc(ゆい の チェキ)ふう:上に テープ・写真の 上に ハッシュタグ3つ・
    /// 日付スタンプ・下の 白い 帯に 手書きの 名前 + @ハンドル
    private func chekiFront(_ initial: String) -> some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .bottomTrailing) {
                if let data = myAvatarData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: LayerAvatar.colors(UUID(), override: myColorIndex), startPoint: .top, endPoint: .bottom)
                    Text(initial).font(.system(size: 64, weight: .heavy)).foregroundStyle(.white.opacity(0.9))
                }
                Text(verbatim: Self.stampDate(Date()))
                    .font(LF.mono(11, bold: true)).tracking(0.66)
                    .foregroundStyle(LaterColor.stamp)
                    .padding(8)
            }
            .frame(height: 227)
            .clipped()
            VStack(spacing: 2) {
                Text(myName).font(LF.hand(34)).foregroundStyle(Color(hex: "1A1A1D"))
                Text(verbatim: "@\(String(myRecordName.suffix(8)).lowercased())").font(LF.mono(9, bold: true)).tracking(0.95).foregroundStyle(.black.opacity(0.5))
            }
            .padding(.top, 227 + 12)
            .frame(maxWidth: .infinity)
            HStack(spacing: 6) {
                hashtag("夜型", bg: Color(hex: "9ED8FF"), ink: .black)
                hashtag("カフェ", bg: LaterColor.lime, ink: .black)
                hashtag("音楽", bg: Color(hex: "EE5E9C"), ink: .white)
            }
            .padding(.leading, 10)
            .padding(.top, 150)
            Rectangle().fill(LaterColor.lime.opacity(0.75))
                .frame(width: 86, height: 24)
                .rotationEffect(.degrees(-4))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 2)
                .offset(y: -10)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func hashtag(_ text: String, bg: Color, ink: Color) -> some View {
        Text(verbatim: "#\(text)")
            .font(LF.inter(900, 13))
            .tracking(-0.3)
            .foregroundStyle(ink)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg))
            .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 3)
    }

    private var qrBack: some View {
        VStack(spacing: 10) {
            if let qr = QRImage.make(FriendRules.link(recordName: myRecordName).absoluteString) {
                Image(uiImage: qr).resizable().frame(width: 140, height: 140)
            }
            Text("SCAN TO ADD").font(Darkroom.mono(10)).foregroundStyle(.black.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
    }

    // MARK: TODAY 一覧

    private var todayList: some View {
        VStack(spacing: 10) {
            HStack {
                Text("TODAY ・ \(Darkroom.dayLabel(Date()))").font(Darkroom.mono(10.5)).foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            ForEach(list) { friend in
                todayRow(friend)
            }
        }
        .padding(.horizontal, 18)
    }

    private func todayRow(_ friend: HomeFriend) -> some View {
        Button {
            Haptics.play(.tick)
            actionFriend = friend
        } label: {
            HStack(spacing: 12) {
                LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if friend.hasShot { Circle().fill(Darkroom.orange).frame(width: 10, height: 10).overlay(Circle().strokeBorder(Darkroom.card, lineWidth: 2)) }
                    }
                Text(friend.name).font(Darkroom.title(friend.name, size: 17)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(friend.hasShot ? Darkroom.orange : .white.opacity(0.14))
                            .frame(width: 6, height: 9)
                    }
                }
                if friend.hasShot {
                    Text("9:00").font(Darkroom.mono(11)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 70)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.06)).background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 22, style: .continuous)))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.98))
    }

    // MARK: CONNECT

    private var connectTiles: some View {
        HStack(spacing: 8) {
            connectTile(icon: "qrcode", title: "QR", primary: true) {
                guard !isFull else { refuseFull(); return }
                Haptics.play(.tick)
                showsFriendScan = true
            }
            connectTile(icon: "link", title: "Link", primary: false) {
                guard !isFull else { refuseFull(); return }
                shareItems = ["\(myName) と Lattag で つながろう\n\(FriendRules.link(recordName: myRecordName).absoluteString)"]
            }
        }
        .padding(.horizontal, 14)
        .overlay(alignment: .topTrailing) {
            Text("\(FriendRules.maxFriends - list.count) LEFT")
                .font(Darkroom.mono(9.5))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.trailing, 14)
                .offset(y: -14)
        }
    }

    /// mock .fwy button:96pt 高さ・22pt 角丸・アイコン24pt + Instrument Serif(--ttl)20pt の文字
    private func connectTile(icon: String, title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 24, weight: .regular))
                Text(title).font(.custom("InstrumentSerif-Regular", size: 20))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(primary ? Darkroom.orange : .white.opacity(0.08)))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.96))
    }

    // MARK: 処理(いまの ものを 呼ぶだけ)

    private func makePair(_ friend: HomeFriend) {
        // v48:「ふたりのグループをつくる」は 今の グループ作成の 入口を そのまま 呼ぶ(友だちの えらぶ状態だけ 渡す)
        onOpenInviteToGroup()
    }

    private func block(_ friend: HomeFriend) {
        Task {
            do {
                _ = try await ModerationService.blockUser(cloudKitUserRecordName: friend.id, displayName: friend.name, modelContext: modelContext)
                Haptics.play(.warn)
                show("\(friend.name) を ブロックしました")
            } catch {
                show("ブロックできませんでした")
            }
        }
    }

    private func refuseFull() {
        Haptics.play(.warn)
        show("12人まで です")
    }

    private func show(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { if toast == text { toast = nil } }
    }
}

/// 次に すわる 席(大きい版・緑の 点線が 脈打つ)
private struct PulsingDashedSeatBig: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().strokeBorder(Darkroom.orange.opacity(pulse ? 0.9 : 0.4), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .scaleEffect(pulse ? 1.07 : 1)
            Text("+").font(.system(size: 20, weight: .light)).foregroundStyle(Darkroom.orange)
        }
        .frame(width: 56, height: 56)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
