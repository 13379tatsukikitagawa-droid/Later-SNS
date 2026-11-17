import SwiftUI
import SwiftData

// P12-B(v68):Friends 画面(BeReal 型の 黒い 一覧)。見本:F01〜F04。
// データ ・ 申請 ・ つつく ・ チャット ・ ブロック ・ 通報の しくみは 今までの まま(`FriendRequests` `KnockStore` `DirectMessageView` `ModerationService`)。
// 友だちの 数は どこにも 出さない。キャラクターは 使わない。

struct FriendsV68View: View {
    let myName: String
    var myAvatarData: Data?
    let friends: [HomeFriend]
    let groups: [LaterGroup]
    let onClose: () -> Void
    var onOpenInviteToGroup: () -> Void = {}
    /// DEBUG の 見本どり 用(本番は nil ・ CloudKit から とる)
    var injectedRequests: [FriendRequests.Request]? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @State private var appeared = false
    @State private var query = ""
    @FocusState private var searching: Bool
    @State private var incoming: [FriendRequests.Request] = []
    @State private var hidden: Set<String> = []
    @State private var blockedIDs: Set<String> = []
    @State private var showsScan = false
    @State private var showsMyQR = false
    @State private var showsID = false
    @State private var idSeed = ""
    @State private var shareItems: [Any]?
    @State private var chat: HomeFriend?
    @State private var actionFriend: HomeFriend?
    @State private var confirmingBlock: HomeFriend?
    @State private var reportingFriend: HomeFriend?
    @State private var toast: String?
    @State private var scrollY: CGFloat = 0

    private var myRecordName: String { CloudKitManager.current?.currentUserRecordName ?? "" }
    private var list: [HomeFriend] { friends.filter { !$0.isMe } }
    private var shown: [HomeFriend] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty ? list : list.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.id.localizedCaseInsensitiveContains(q) }
        return base.sorted { ($0.hasShot ? 0 : 1) < ($1.hasShot ? 0 : 1) }
    }
    private var requests: [FriendRequests.Request] { incoming.filter { !hidden.contains($0.id) } }
    private var tookCount: Int { list.filter(\.hasShot).count }
    private var empty: Bool { list.isEmpty }
    private var on: Bool { appeared || reduceMotion }

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 62 + 44 + 12)
                    if !empty { todayLine.rise(on, 0); search.rise(on, 1) }
                    qrCards.rise(on, empty ? 0 : 2)
                    connectRow.rise(on, empty ? 1 : 3)
                    if !requests.isEmpty { requestsBlock.rise(on, empty ? 2 : 4) }
                    if !empty { friendsBlock.rise(on, 5) }
                    footer
                    Color.clear.frame(height: 60)
                }
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { max(0, $0.contentOffset.y + $0.contentInsets.top) } action: { _, v in scrollY = v }
            header
        }
        .background(Color(hex: "0A0A0B"))
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(LF.inter(700, 13)).foregroundStyle(HV.ink).padding(.horizontal, 18).padding(.vertical, 11).background(.white, in: Capsule()).padding(.bottom, 40)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: toast)
        .task { blockedIDs = Set(((try? modelContext.fetch(FetchDescriptor<BlockedUser>())) ?? []).map(\.blockedCloudKitUserRecordName)) }
        .task { if let inj = injectedRequests { incoming = inj } else { incoming = await FriendRequests.incoming() } }
        .onAppear {
            guard !appeared else { return }
            Haptics.play(.sel)
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Haptics.play(.tick) }
        }
        .sheet(isPresented: $showsMyQR) { MyQRSheet(name: myName, link: FriendRules.link(recordName: myRecordName).absoluteString) }
        .fullScreenCover(isPresented: $showsScan) { FriendQRScanView(myName: myName, friendCount: list.count) { show($0) } }
        .sheet(isPresented: $showsID) {
            FriendIDSearchSheet(myName: myName, seed: idSeed, onQR: { showsMyQR = true }, onLink: { shareItems = ["\(myName) と Lattag で つながろう\n\(FriendRules.link(recordName: myRecordName).absoluteString)"] }, onScan: { showsScan = true }) { show($0) }
        }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { done in shareItems = nil; if done { Haptics.play(.success) } }.presentationDetents([.medium, .large])
        }
        .sheet(item: $chat) { f in DirectMessageView(friendID: f.id, friendName: f.name) }
        .confirmationDialog("", isPresented: Binding(get: { actionFriend != nil }, set: { if !$0 { actionFriend = nil } }), titleVisibility: .hidden) {
            if let f = actionFriend {
                if !f.hasShot { Button("つつく") { poke(f) } }
                Button("ふたりの グループを つくる") { onOpenInviteToGroup() }
                Button("ブロックする", role: .destructive) { confirmingBlock = f }
                Button("通報する", role: .destructive) { reportingFriend = f }
                Button("やめる", role: .cancel) {}
            }
        }
        .confirmationDialog("\(confirmingBlock?.name ?? "") を ブロックしますか?", isPresented: Binding(get: { confirmingBlock != nil }, set: { if !$0 { confirmingBlock = nil } }), titleVisibility: .visible) {
            Button("ブロックする", role: .destructive) { if let f = confirmingBlock { block(f) } }
            Button("やめる", role: .cancel) {}
        }
        .sheet(item: $reportingFriend) { f in ReportSheet(targetType: .user, targetID: f.id) }
    }

    // MARK: うしろ(友だちの 写真を ぼかして 上 400pt に)

    private var backdrop: some View {
        let imgs = list.filter(\.hasShot).compactMap { f -> UIImage? in V64Images.image(key: "fb\(f.id)", data: f.mosaicTiny ?? f.avatarData, maxPixel: 160) }.prefix(3)
        return ZStack(alignment: .top) {
            Color(hex: "0A0A0B")
            if let img = imgs.first {
                Color.clear.frame(maxWidth: .infinity).frame(height: 640)
                    .overlay { Image(uiImage: V64Images.blurred(key: "fk\(ObjectIdentifier(img).hashValue)", source: img, maxPixel: 96, radius: 26, saturation: 1.4, brightness: 0.5)).resizable().scaledToFill() }
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.7), location: 0.45), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            } else {
                RadialGradient(colors: [Color(red: 36 / 255, green: 160 / 255, blue: 60 / 255).opacity(0.38), .clear], center: UnitPoint(x: 0.85, y: 0.05), startRadius: 0, endRadius: 320)
                RadialGradient(colors: [Color(hex: "C8F25A").opacity(0.12), .clear], center: UnitPoint(x: 0.05, y: 0.18), startRadius: 0, endRadius: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).ignoresSafeArea().allowsHitTesting(false)
        .offset(y: -scrollY * 0.5)
    }

    // MARK: ヘッダー

    private var header: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.5)).frame(height: 150)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.7), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .opacity(scrollY > 16 ? 1 : 0).animation(.easeOut(duration: 0.3), value: scrollY > 16)
            Button { Haptics.play(.tick); onClose() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.92)).offset(x: 18, y: 62).accessibilityLabel("もどる")
            Text("Friends").font(LF.serif(40)).foregroundStyle(.white).frame(height: 40, alignment: .leading).fixedSize().offset(x: 74, y: 66)
            Button { Haptics.play(.sel); showsScan = true } label: {
                Image(systemName: "qrcode").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle()).overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            }.buttonStyle(HVPress(scale: 0.92)).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 18).offset(y: 62).accessibilityLabel("QR")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: 今日の 一行

    private var todayLine: some View {
        HStack(spacing: 0) {
            let took = list.filter(\.hasShot).prefix(3)
            HStack(spacing: -8) {
                ForEach(Array(took), id: \.id) { f in avatar(f, 26).overlay(Circle().strokeBorder(Color(hex: "0A0A0B"), lineWidth: 2)) }
            }
            .padding(.leading, 20).padding(.trailing, took.isEmpty ? 0 : 10)
            if tookCount > 0 {
                (Text("きょう ") + Text("\(tookCount)人").foregroundColor(HV.lime).fontWeight(.heavy) + Text("が 撮った")).font(LF.inter(600, 13.5)).foregroundStyle(.white)
            } else {
                Text("きょうは まだ だれも 撮って いない").font(LF.inter(600, 13.5)).foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 8)
            Text("9:00 OPEN").font(LF.mono(9.5)).tracking(1.1).foregroundStyle(.white.opacity(0.55)).padding(.trailing, 20)
        }.frame(height: 26)
    }

    // MARK: さがす

    private var search: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            TextField("", text: $query, prompt: Text("名前 か ID で さがす").foregroundColor(.white.opacity(0.55)))
                .font(LF.inter(600, 16)).foregroundStyle(.white).focused($searching).submitLabel(.search)
                .onSubmit { if shown.isEmpty && !query.isEmpty { idSeed = query; showsID = true } }
        }
        .padding(.horizontal, 18).frame(height: 48)
        .background(.white.opacity(0.12), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 20)
    }

    // MARK: QR を 見せる / QR を 読む(v85。Shake は なくした)

    @ViewBuilder private var qrCards: some View {
        if empty {
            VStack(spacing: 8) {
                showCard(compact: false)
                readCard(compact: false)
            }
            .padding(.horizontal, 32).padding(.top, 14)
        } else {
            HStack(spacing: 8) {
                showCard(compact: true)
                readCard(compact: true)
            }
            .padding(.horizontal, 32).padding(.top, 12)
        }
    }

    private func showCard(compact: Bool) -> some View {
        Button { Haptics.play(.click); showsMyQR = true } label: {
            ZStack(alignment: compact ? .bottomTrailing : .trailing) {
                RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous).fill(HV.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text("QR を 見せる").font(LF.inter(900, compact ? 17 : 22)).foregroundStyle(HV.ink)
                    Text("会った 友だちに").font(LF.inter(600, 11.5)).foregroundStyle(HV.ink.opacity(0.78))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(.leading, 14)
                MiniQR(text: FriendRules.link(recordName: myRecordName).absoluteString, box: compact ? 56 : 96)
                    .padding(compact ? 12 : 18)
            }
            .frame(maxWidth: .infinity).frame(height: compact ? 142 : 150)
        }
        .buttonStyle(HVPress(scale: 0.98))
        .accessibilityLabel("QR を 見せる")
    }

    private func readCard(compact: Bool) -> some View {
        Button { Haptics.play(.click); showsScan = true } label: {
            ZStack(alignment: compact ? .bottomTrailing : .trailing) {
                RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous).fill(.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text("QR を 読む").font(LF.inter(900, compact ? 17 : 22)).foregroundStyle(.white)
                    Text("カメラで 読む").font(LF.inter(600, 11.5)).foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(.leading, 14)
                ScanFrame(size: compact ? 44 : 80).padding(compact ? 12 : 18)
            }
            .frame(maxWidth: .infinity).frame(height: compact ? 142 : 150)
        }
        .buttonStyle(HVPress(scale: 0.98))
        .accessibilityLabel("QR を 読む")
    }

    // MARK: QR / Link / ID

    private var connectRow: some View {
        HStack(spacing: 8) {
            tile("link", "Link") { Haptics.play(.tick); shareItems = ["\(myName) と Lattag で つながろう\n\(FriendRules.link(recordName: myRecordName).absoluteString)"] }
            tile("at", "ID") { Haptics.play(.tick); idSeed = ""; showsID = true }
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private func tile(_ icon: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) { Image(systemName: icon).font(.system(size: 16, weight: .semibold)); Text(title).font(LF.inter(700, 14)) }
                .foregroundStyle(.white).frame(width: 114, height: 48)
                .background(.white.opacity(0.10), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }.buttonStyle(HVPress(scale: 0.96))
    }

    // MARK: Requests

    private var requestsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Requests").font(LF.serif(28)).foregroundStyle(.white)
                Circle().fill(Color(hex: "FF3B30")).frame(width: 9, height: 9).offset(y: 3)
            }.frame(height: 28).padding(.leading, 20).padding(.top, 30)
            VStack(spacing: 0) {
                ForEach(Array(requests.enumerated()), id: \.element.id) { i, r in
                    requestRow(r)
                    if i < requests.count - 1 { Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 74) }
                }
            }.padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func requestRow(_ r: FriendRequests.Request) -> some View {
        let name = r.fromName.isEmpty ? "ともだち" : r.fromName
        let secs = max(0, Int(Date().timeIntervalSince(r.createdAt)))
        let ago = secs >= 86400 ? "\(secs / 86400)d" : (secs >= 3600 ? "\(secs / 3600)h" : "\(max(1, secs / 60))m")
        return HStack(spacing: 14) {
            initialCircle(name, 52, seed: r.fromUserID)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(LF.inter(700, 17)).foregroundStyle(.white).lineLimit(1)
                Text(r.fromUsername.isEmpty ? ago : "@\(r.fromUsername) ・ \(ago)").font(LF.inter(600, 12.5)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
            }
            Spacer(minLength: 6)
            Button { Haptics.play(.click); withAnimation(.easeOut(duration: 0.3)) { hidden.insert(r.id) }
                Task { _ = await FriendRequests.respond(to: r, accept: true, myName: myName); Haptics.play(.success); incoming = await FriendRequests.incoming() } } label: {
                Text("承認").font(LF.inter(800, 14)).foregroundStyle(HV.ink).frame(width: 64, height: 40).background(HV.lime, in: Capsule())
            }.buttonStyle(HVPress(scale: 0.95))
            Button { Haptics.play(.soft); withAnimation(.easeOut(duration: 0.24)) { hidden.insert(r.id) } } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.85)).frame(width: 40, height: 40).background(.white.opacity(0.10), in: Circle())
            }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("あとで")
        }
        .padding(.horizontal, 7).frame(height: 76)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    // MARK: Friends 一覧(撮った 人が 上)

    private var friendsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Friends").font(LF.serif(28)).foregroundStyle(.white)
                Spacer()
                if tookCount > 0 {
                    HStack(spacing: 5) { Circle().fill(Color(hex: "3BD35A")).frame(width: 5, height: 5); Text("\(tookCount) SHOT TODAY").font(LF.mono(9.5)).tracking(1.1).foregroundStyle(Color(hex: "7EE08F")) }
                }
            }.frame(height: 28).padding(.horizontal, 20).padding(.top, requests.isEmpty ? 30 : 27)
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, f in
                    friendRow(f)
                    if i < shown.count - 1 { Rectangle().fill(.white.opacity(0.08)).frame(height: 1).padding(.leading, 74) }
                }
            }.padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func friendRow(_ f: HomeFriend) -> some View {
        HStack(spacing: 0) {
            Button { Haptics.play(.sel); actionFriend = f } label: {
                HStack(spacing: 18) {
                    ZStack {
                        if f.hasShot {
                            ForEach(0..<3, id: \.self) { i in
                                Circle().trim(from: 0.02, to: 0.30).stroke(HV.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(Double(i) * 120 - 90)).frame(width: 56, height: 56)
                            }
                        }
                        avatar(f, 46)
                    }.frame(width: 56, height: 56).padding(.leading, 5)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.name).font(LF.inter(700, 17)).foregroundStyle(.white).lineLimit(1)
                        Text(f.hasShot ? "今日 撮った" : "まだ 撮って いない").font(LF.inter(600, 12.5)).foregroundStyle(f.hasShot ? HV.lime : .white.opacity(0.55))
                    }
                    Spacer(minLength: 4)
                }
            }.buttonStyle(.plain)
            if f.hasShot { lockedWindows(f) }
            else {
                Button { Haptics.play(.heart); poke(f) } label: {
                    Image(systemName: "hand.point.up.left.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(HV.lime)
                        .frame(width: 44, height: 44).background(HV.lime.opacity(0.16), in: Circle())
                }.buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("つつく")
            }
            Button { Haptics.play(.sel); chat = f } label: {
                Image(systemName: "bubble.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(width: 44, height: 44).background(.white.opacity(0.10), in: Circle())
            }.buttonStyle(HVPress(scale: 0.92)).padding(.leading, 8).accessibilityLabel("チャット")
        }
        .padding(.trailing, 6).frame(height: 76)
    }

    /// 今日の 写真の ぼかした 小窓(30×40)。いちばん 上に 鍵。48px の ロック用 だけ 使う
    private func lockedWindows(_ f: HomeFriend) -> some View {
        let img = V64Images.image(key: "lw\(f.id)", data: f.mosaicTiny, maxPixel: 48)
        return ZStack(alignment: .leading) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(hex: "222222"))
                    .overlay { if let img { Image(uiImage: img).resizable().scaledToFill().saturation(0.7) } }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .frame(width: 30, height: 40).offset(x: CGFloat(i) * 18)
                    .overlay { if i == 2 { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white).offset(x: 36) } }
            }
        }.frame(width: 66, height: 40, alignment: .leading)
    }

    private var footer: some View {
        Group {
            if empty {
                Text("さいしょの 友だちを よぼう。\nつながると、あしたの 朝 9:00 に きのうを 見せあえます。").font(LF.inter(600, 13.5)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 30)
            }
            Text("知らない人には 見つかりません ・ 友だちの 数は どこにも 出ません").font(LF.inter(600, 12)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 28)
        }
    }

    // MARK: 部品

    private func avatar(_ f: HomeFriend, _ size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(hex: ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"][abs(f.seed.hashValue) % 7]))
            if let img = V64Images.image(key: "fa\(f.id)", data: f.avatarData ?? f.mosaicTiny, maxPixel: 160) { Image(uiImage: img).resizable().scaledToFill() }
            else { Text(String(f.name.prefix(1))).font(LF.inter(800, size * 0.4)).foregroundStyle(HV.ink) }
        }.frame(width: size, height: size).clipShape(Circle())
    }

    private func initialCircle(_ name: String, _ size: CGFloat, seed: String) -> some View {
        ZStack {
            Circle().fill(Color(hex: ["61DD7A", "7FB0FF", "EE5E9C", "C8F25A", "B28CFF", "5AC8FF", "FFD25A"][abs(seed.hashValue) % 7]))
            Text(String(name.prefix(1))).font(LF.inter(800, size * 0.4)).foregroundStyle(HV.ink)
        }.frame(width: size, height: size)
    }

    // MARK: 処理(今ある ものを 呼ぶだけ)

    private func poke(_ friend: HomeFriend) {
        let window = DailyWindow.key(for: Date())
        if KnockStore.shared.hasKnocked(friend.id, window: window) { Haptics.play(.warn); show("つつくのは 1日 1回"); return }
        Haptics.play(.heart)
        Task {
            switch await KnockStore.shared.knock(friend, window: window, groups: groups, myName: myName) {
            case .sent: show("\(friend.name) を つつきました")
            case .already: Haptics.play(.warn); show("つつくのは 1日 1回")
            case .failed: show("送れませんでした。つながってから、もう一度")
            }
        }
    }

    private func block(_ friend: HomeFriend) {
        Task {
            do { _ = try await ModerationService.blockUser(cloudKitUserRecordName: friend.id, displayName: friend.name, modelContext: modelContext); Haptics.play(.warn); show("\(friend.name) を ブロックしました") }
            catch { show("ブロックできませんでした") }
        }
    }

    private func show(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { if toast == text { toast = nil } }
    }
}

// MARK: - 自分の QR(大)。プロフィールの チェキを 裏返す 画面が できる まで、これで 見せる

private struct MyQRSheet: View {
    let name: String
    let link: String
    var body: some View {
        VStack(spacing: 18) {
            Text(name).font(LF.inter(900, 22)).foregroundStyle(.white)
            MiniQR(text: link, box: 260)
            Text("会った 友だちに 読んで もらう").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0A0A0B"))
        .presentationDetents([.medium])
    }
}

// MARK: - 自分の QR(小)と 読み取りの 枠

private struct MiniQR: View {
    let text: String
    let box: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: box > 60 ? 18 : 12, style: .continuous).fill(Color(hex: "F4F1EA"))
            if let ui = QRImage.make(text) {
                Image(uiImage: ui).interpolation(.none).resizable().frame(width: box - (box > 60 ? 10 : 8), height: box - (box > 60 ? 10 : 8))
            }
        }
        .frame(width: box, height: box)
    }
}

/// 読み取りの 枠(4すみの かぎ + 上下に 動く 線 ・ 1.8秒)。見えない / Reduce Motion では 止める
private struct ScanFrame: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
            let k = reduceMotion ? 0.5 : (t < 0.5 ? t * 2 : (1 - t) * 2)
            ZStack {
                Corners().stroke(HV.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)).frame(width: size * 0.75, height: size * 0.75)
                Capsule().fill(HV.lime).frame(width: size * 0.8, height: 2)
                    .offset(y: (k - 0.5) * size * 0.7)
            }
            .frame(width: size, height: size)
        }
    }
    private struct Corners: Shape {
        func path(in r: CGRect) -> Path {
            let l = r.width * 0.28, c = r.width * 0.09
            var p = Path()
            for (sx, sy) in [(CGFloat(0), CGFloat(0)), (1, 0), (0, 1), (1, 1)] {
                let x = r.minX + sx * r.width, y = r.minY + sy * r.height
                let dx: CGFloat = sx == 0 ? 1 : -1, dy: CGFloat = sy == 0 ? 1 : -1
                p.move(to: CGPoint(x: x + dx * l, y: y))
                p.addLine(to: CGPoint(x: x + dx * c, y: y))
                p.addQuadCurve(to: CGPoint(x: x, y: y + dy * c), control: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x, y: y + dy * l))
            }
            return p
        }
    }
}

// MARK: - ID で さがす(今ある `UserDirectoryService` + `FriendRequests.send`)

struct FriendIDSearchSheet: View {
    let myName: String
    var seed: String
    var username: String = ""
    var onQR: () -> Void = {}
    var onLink: () -> Void = {}
    var onScan: () -> Void = {}
    var onToast: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var results: [UserDirectoryService.DirectoryProfile] = []
    @State private var searching = false
    @State private var sent: Set<UUID> = []
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Add friends").font(LF.inter(900, 28)).tracking(-1).foregroundStyle(Color(hex: "0B0C0D"))
                Spacer()
                if !username.isEmpty { Text("@\(username)").font(LF.mono(12)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.5)) }
            }.padding(.top, 26)
            HStack(spacing: 8) {
                Text("@").font(LF.inter(900, 17)).foregroundStyle(Color(hex: "24A03C"))
                TextField("", text: $text, prompt: Text("ID を そのまま 入力").foregroundColor(Color(hex: "0B0C0D").opacity(0.4))).font(LF.mono(16)).foregroundStyle(Color(hex: "0B0C0D"))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused).submitLabel(.search).onSubmit { run() }
                Button { run() } label: { Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .bold)).foregroundStyle(.white).frame(width: 42, height: 42).background(Color(hex: "0B0C0D"), in: Circle()) }.buttonStyle(.plain)
            }.padding(.leading, 16).padding(.trailing, 5).frame(height: 52).background(Color(hex: "F0EEE8"), in: Capsule()).overlay(Capsule().strokeBorder(Color(hex: "0B0C0D"), lineWidth: 2))
            Text("知らない人には 見つからない ように、ID が ぴったり 合った ときだけ 出ます").font(LF.inter(500, 13)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.45)).lineSpacing(3)
            HStack(spacing: 8) {
                addTile("qrcode", "QR", green: true) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onQR() } }
                addTile("link", "Link", green: false) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onLink() } }
                addTile("viewfinder", "Scan", green: false) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onScan() } }
            }
            if searching { ProgressView().tint(.white).frame(maxWidth: .infinity) }
            ForEach(results) { p in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: "7FB0FF"))
                        if let d = p.avatarData, let i = UIImage(data: d) { Image(uiImage: i).resizable().scaledToFill() } else { Text(String(p.name.prefix(1))).font(LF.inter(800, 18)).foregroundStyle(HV.ink) }
                    }.frame(width: 46, height: 46).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) { Text(p.name).font(LF.inter(700, 16)).foregroundStyle(.white); Text("@\(p.username)").font(LF.inter(600, 12.5)).foregroundStyle(.white.opacity(0.55)) }
                    Spacer()
                    Button { send(p) } label: {
                        Text(sent.contains(p.id) ? "送った" : "申請").font(LF.inter(800, 14)).foregroundStyle(HV.ink).frame(width: 64, height: 38).background(sent.contains(p.id) ? Color.white.opacity(0.4) : HV.lime, in: Capsule())
                    }.disabled(sent.contains(p.id) || p.cloudKitUserRecordName == nil)
                }
            }
            if !searching && results.isEmpty && !text.isEmpty { Text("見つかりませんでした。ID を たしかめて ください。").font(LF.inter(600, 13)).foregroundStyle(.white.opacity(0.6)) }
            Spacer()
            Text("申請して、承認されたら つながる ・ 数は 出ません").font(LF.inter(500, 13)).foregroundStyle(Color(hex: "0B0C0D").opacity(0.45)).frame(maxWidth: .infinity).padding(.bottom, 14)
        }
        .padding(.horizontal, 22).background(Color.white.ignoresSafeArea()).environment(\.colorScheme, .light)
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .onAppear { text = seed.hasPrefix("@") ? String(seed.dropFirst()) : seed; focused = true; if !text.isEmpty { run() } }
    }

    private func addTile(_ icon: String, _ title: String, green: Bool, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 22, weight: .semibold)); Text(title).font(LF.serif(20)) }
                .foregroundStyle(green ? .white : Color(hex: "0B0C0D")).frame(maxWidth: .infinity).frame(height: 74)
                .background(green ? Color(hex: "24A03C") : Color(hex: "F0EEE8"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }.buttonStyle(HVPress(scale: 0.96))
    }

    private func run() {
        let q = text.trimmingCharacters(in: .whitespaces); guard !q.isEmpty else { return }
        searching = true
        Task { results = await UserDirectoryService.search(usernamePrefix: q); searching = false }
    }

    private func send(_ p: UserDirectoryService.DirectoryProfile) {
        guard let rn = p.cloudKitUserRecordName else { return }
        Haptics.play(.click)
        Task {
            let ok = await FriendRequests.send(to: rn, toName: p.name, myName: myName)
            if ok { sent.insert(p.id); Haptics.play(.success); onToast("\(p.name) に 申請を 送りました") } else { Haptics.play(.warn); onToast("送れませんでした") }
        }
    }
}

extension View {
    /// 開く とき 下から 16pt(0.46秒 ・ 45ms ずつ)
    func rise(_ on: Bool, _ i: Int) -> some View {
        offset(y: on ? 0 : 16).opacity(on ? 1 : 0).animation(.timingCurve(0.2, 0.8, 0.3, 1, duration: 0.46).delay(0.045 * Double(i)), value: on)
    }
}
