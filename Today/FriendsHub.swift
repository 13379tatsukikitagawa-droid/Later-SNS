import CloudKit
import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI
import UIKit

// v14 ⑤ ともだち:プロフィールを見せるだけで つながる。
// 3つのサブタブ:呼ぶ(プロフィールカード・送る・コピー・QR)/ グループに えらぶ / とどいた。
//
// CloudKit(公開 DB。Development で作ってから Production に Deploy):
// - Friendship(fromUserId, toUserId, fromName, createdAt):片方が作ると「申請」、相手も作ると「成立」(相互)。
//   公開 DB は作った人しか書きかえられない(_creator)ので、承認は「相手が自分の Friendship を作る」で表す。
// - GroupInviteCard(fromUserId, fromName, toUserId, groupName, memberCount, shareURL, createdAt):招待カード。
//   本人が「入る」を押して、共有(CKShare)を受けいれるまで、グループには入らない。「あとで」は端末に pending のまま残す。

// MARK: - 決まり

extension FriendRules {
    /// 招待カードを送れる人数(グループの上限 8人 − 自分)
    static let maxInvitees = GroupMembershipPolicy.maxMembersPerGroup - 1

    /// 相互で成立しているか(自分 → 相手、相手 → 自分 の両方がある)
    static func isMutual(mine: Set<String>, theirs: Set<String>, other: String) -> Bool {
        mine.contains(other) && theirs.contains(other)
    }

    /// 友達のリンク(QR にも入れる)
    static func link(recordName: String) -> URL {
        var c = URLComponents()
        c.scheme = "later"
        c.host = "friend"
        c.queryItems = [URLQueryItem(name: "u", value: recordName)]
        return c.url ?? URL(string: "later://friend")!
    }

    static func recordName(from url: URL) -> String? {
        guard Brand.isOurScheme(url), url.host == "friend" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "u" }?.value
    }
}

enum InviteCardStatus: String, Codable, Sendable {
    case pending, accepted, declined
}

struct FriendInviteCard: Identifiable, Equatable {
    let id: String
    let fromName: String
    let groupName: String
    let memberCount: Int
    let shareURL: URL?
    var status: InviteCardStatus
}

// MARK: - CloudKit

@MainActor
enum FriendCloud {
    static let friendshipType = "Friendship"
    static let inviteType = "GroupInviteCard"

    private static var database: CKDatabase? { CloudKitManager.current?.container.publicCloudDatabase }

    /// つながる:自分 → 相手 の Friendship を作る(相手も作ると成立)。どちらかが 12人なら作らない
    static func connect(to other: String, myName: String, myCount: Int, theirCount: Int) async -> Result<Void, FriendError> {
        guard FriendRules.canConnect(myCount: myCount, theirCount: theirCount) else { return .failure(.full) }
        guard let database, let me = CloudKitManager.current?.currentUserRecordName, me != other else { return .failure(.notReady) }
        let record = CKRecord(recordType: friendshipType, recordID: CKRecord.ID(recordName: "friend_\(me)_\(other)"))
        record["fromUserId"] = me
        record["toUserId"] = other
        record["fromName"] = String(myName.prefix(24))
        record["createdAt"] = Date()
        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            return .success(())
        } catch {
            return .failure(.network)
        }
    }

    /// 自分が出した相手 / 自分あての相手(recordName の集合)
    static func friendIDs() async -> (mine: Set<String>, theirs: Set<String>) {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return ([], []) }
        async let out = ids(database, field: "fromUserId", equals: me, take: "toUserId")
        async let incoming = ids(database, field: "toUserId", equals: me, take: "fromUserId")
        return await (out, incoming)
    }

    /// v17:QR などで つながった人(自分が「つながる」を押した相手)。名前は、相手の Friendship の fromName か、つながったときの控え
    static func connections() async -> [BumpFriend] {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return BumpFriendStore.cached }
        async let out = records(database, field: "fromUserId", equals: me)
        async let incoming = records(database, field: "toUserId", equals: me)
        let (outs, ins) = await (out, incoming)
        guard let outs else { return BumpFriendStore.cached }
        var names: [String: String] = [:]
        for record in ins ?? [] {
            if let id = record["fromUserId"] as? String, let name = record["fromName"] as? String, !name.isEmpty { names[id] = name }
        }
        let sorted = outs.sorted { ($0["createdAt"] as? Date ?? .distantPast) < ($1["createdAt"] as? Date ?? .distantPast) }
        let friends: [BumpFriend] = sorted.compactMap { record in
            guard let id = record["toUserId"] as? String else { return nil }
            return BumpFriend(id: id, name: names[id] ?? BumpFriendStore.name(for: id) ?? "ともだち")
        }
        BumpFriendStore.cached = friends
        return friends
    }

    private static func records(_ database: CKDatabase, field: String, equals value: String) async -> [CKRecord]? {
        let query = CKQuery(recordType: friendshipType, predicate: NSPredicate(format: "%K == %@", field, value))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 50) else { return nil }
        return results.compactMap { try? $0.1.get() }
    }

    private static func ids(_ database: CKDatabase, field: String, equals value: String, take: String) async -> Set<String> {
        let query = CKQuery(recordType: friendshipType, predicate: NSPredicate(format: "%K == %@", field, value))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 50) else { return [] }
        return Set(results.compactMap { try? $0.1.get()[take] as? String })
    }

    /// 招待カードを送る(友達だけ。グループにはまだ入らない)
    static func sendInvites(to friends: [String], groupName: String, memberCount: Int, shareURL: URL?, myName: String) async -> Bool {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return false }
        let records = friends.map { other -> CKRecord in
            let record = CKRecord(recordType: inviteType, recordID: CKRecord.ID(recordName: "invite_\(me)_\(other)_\(UUID().uuidString.prefix(8))"))
            record["fromUserId"] = me
            record["fromName"] = String(myName.prefix(24))
            record["toUserId"] = other
            record["groupName"] = groupName
            record["memberCount"] = Int64(memberCount)
            record["shareURL"] = shareURL?.absoluteString
            record["createdAt"] = Date()
            return record
        }
        return (try? await database.modifyRecords(saving: records, deleting: [])) != nil
    }

    /// 自分あての招待カード(状態は端末に持つ:pending のものは「とどいた」に残る)
    static func inbox() async -> [FriendInviteCard] {
        guard let database, let me = CloudKitManager.current?.currentUserRecordName else { return [] }
        let query = CKQuery(recordType: inviteType, predicate: NSPredicate(format: "toUserId == %@", me))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 30) else { return [] }
        return results.compactMap { id, result in
            guard let record = try? result.get() else { return nil }
            return FriendInviteCard(
                id: id.recordName,
                fromName: record["fromName"] as? String ?? "",
                groupName: record["groupName"] as? String ?? "",
                memberCount: Int(record["memberCount"] as? Int64 ?? 0),
                shareURL: (record["shareURL"] as? String).flatMap(URL.init(string:)),
                status: InviteCardStore.status(id.recordName)
            )
        }
    }
}

enum FriendError: Error, Equatable {
    case full, notReady, network
    var message: String {
        switch self {
        case .full: return FriendRules.fullMessage
        case .notReady: return "iCloud に つながってから、もう一度"
        case .network: return "送れませんでした。つながってから、もう一度"
        }
    }
}

/// 招待カードの状態(端末に持つ。公開 DB のカードは送った人しか書きかえられないため)
enum InviteCardStore {
    private static let key = "inviteCard.status"

    static func status(_ id: String, defaults: UserDefaults = .standard) -> InviteCardStatus {
        let all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        return all[id].flatMap(InviteCardStatus.init(rawValue:)) ?? .pending
    }

    static func set(_ status: InviteCardStatus, for id: String, defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        all[id] = status.rawValue
        defaults.set(all, forKey: key)
    }
}

// MARK: - つながった人の控え

/// QR などで つながった人(公開 DB の Friendship から)
struct BumpFriend: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

/// QR などで つながった人の控え(端末の中だけ。通信できないときと、名前の控えに使う)
@MainActor
enum BumpFriendStore {
    private static let listKey = "bumpFriends.v1"
    private static let namesKey = "bumpFriendNames.v1"

    static var cached: [BumpFriend] {
        get { (UserDefaults.standard.data(forKey: listKey)).flatMap { try? JSONDecoder().decode([BumpFriend].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: listKey) }
    }

    static func name(for id: String) -> String? {
        (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String])?[id]
    }

    /// つながった瞬間:名前を控え、一覧にも足す(つぎの読み込みを待たずに、列に出す)
    static func remember(id: String, name: String) {
        var names = (UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String]) ?? [:]
        names[id] = name
        UserDefaults.standard.set(names, forKey: namesKey)
        var list = cached
        if !list.contains(where: { $0.id == id }) { list.append(BumpFriend(id: id, name: name)); cached = list }
        NotificationCenter.default.post(name: .bumpFriendsChanged, object: nil)
    }
}

extension Notification.Name {
    static let bumpFriendsChanged = Notification.Name("bumpFriendsChanged")
}

// MARK: - 画面

struct FriendsHubView: View {
    let myName: String
    let friends: [HomeFriend]
    let groups: [LaterGroup]
    var startTab = 0
    let onClose: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab = 0
    @State private var picked: Set<String> = []
    @State private var inbox: [FriendInviteCard] = []
    @State private var toast: String?
    /// v47:ともだちのQRをカメラで読む
    @State private var showsFriendScan = false
    @State private var shareItems: [Any]?
    @State private var targetGroup: UUID?

    private var myRecordName: String { CloudKitManager.current?.currentUserRecordName ?? "" }
    private var isFull: Bool { friends.count >= FriendRules.maxFriends }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("ともだち").font(.system(size: 20, weight: .heavy)).foregroundStyle(palette.ink)
                HStack {
                    Button {
                        Haptics.play(.soft)
                        onClose()
                    } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundStyle(palette.ink)
                            .frame(width: 44, height: 44).background(Circle().fill(palette.fill))
                    }
                    .buttonStyle(SquishButtonStyle(pressedScale: 0.88))
                    .accessibilityLabel("戻る")
                    Spacer()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            HStack(spacing: 6) {
                subTab("呼ぶ", 0)
                subTab("グループに えらぶ", 1)
                subTab(inbox.contains { $0.status == .pending } ? "とどいた \(inbox.filter { $0.status == .pending }.count)" : "とどいた", 2)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            ScrollView {
                Group {
                    switch tab {
                    case 0: callTab
                    case 1: pickTab
                    default: inboxTab
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .id(tab)
                .transition(.opacity.combined(with: .offset(y: 18)))
            }
            .scrollIndicators(.hidden)
        }
        .background(palette.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(.system(size: 13, weight: .bold)).foregroundStyle(palette.bg)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(palette.ink))
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: tab)
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
        .task { inbox = await FriendCloud.inbox() }
        .onAppear {
            tab = startTab
            targetGroup = groups.first?.id
        }
    }

    private func subTab(_ title: String, _ index: Int) -> some View {
        Button {
            guard tab != index else { return }
            Haptics.play(.tick)
            tab = index
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(tab == index ? palette.bg : palette.groupAdd.note)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Capsule().fill(tab == index ? palette.ink : palette.fill))
        }
        .buttonStyle(SquishButtonStyle())
    }

    // MARK: 呼ぶ

    private var callTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            profileCard
            HStack(spacing: 10) {
                bigButton("送る", primary: true) {
                    guard !isFull else { refuseFull(); return }
                    shareItems = ["\(myName) と Lattag で つながろう\n\(FriendRules.link(recordName: myRecordName).absoluteString)"]
                }
                bigButton("リンクを コピー", primary: false) {
                    guard !isFull else { refuseFull(); return }
                    UIPasteboard.general.string = FriendRules.link(recordName: myRecordName).absoluteString
                    Haptics.play(.pop)
                    show("リンクを コピーしたよ")
                }
            }
            rowButton(icon: "qrcode.viewfinder", title: "QRを よみとる", note: "ともだちの カードを カメラで") {
                guard !isFull else { refuseFull(); return }
                Haptics.play(.tick)
                showsFriendScan = true
            }
            Text("12人まで ・ 数は 出ません").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.ink.opacity(0.55)).frame(maxWidth: .infinity)
        }
    }

    private var profileCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(myName.isEmpty ? "わたし" : myName).font(.system(size: 34, weight: .heavy)).tracking(-0.06 * 34)
                Text("これを 見せるだけで\nつながれる。").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color(hex: "3A2A30"))
                Text("@\(String(myRecordName.suffix(8)).lowercased())")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.7)))
                    .padding(.top, 6)
                Text("ともだち \(friends.count) / \(FriendRules.maxFriends)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: "3A2A30"))
            }
            Spacer(minLength: 0)
            if let qr = QRImage.make(FriendRules.link(recordName: myRecordName).absoluteString) {
                Image(uiImage: qr).interpolation(.none).resizable().scaledToFit()
                    .padding(10).frame(width: 132, height: 132)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.white))
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 10)
                    .accessibilityLabel("つながるための QR")
            }
        }
        .foregroundStyle(Color(hex: "111114"))
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(LinearGradient(colors: [Color(hex: "FFE3D0"), Color(hex: "FFC9D8"), Color(hex: "CFC2FF")], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .shadow(color: Color(hex: "FF503C").opacity(0.3), radius: 25, y: 18)
    }

    // MARK: グループに えらぶ

    private var pickTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("だれを 呼ぶ?").font(.system(size: 22, weight: .heavy)).foregroundStyle(palette.ink)
                Spacer()
                Text("\(picked.count)人").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(palette.groupAdd.note)
            }
            if groups.count > 1 {
                Picker("グループ", selection: $targetGroup) {
                    ForEach(groups) { Text($0.name).tag(Optional($0.id)) }
                }
                .pickerStyle(.menu)
                .tint(palette.ink)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                ForEach(friends.filter { !$0.isMe }) { friend in
                    let on = picked.contains(friend.id)
                    Button {
                        if on {
                            picked.remove(friend.id)
                            Haptics.play(.soft)
                        } else if picked.count >= FriendRules.maxInvitees {
                            Haptics.play(.warn)
                            show("グループは \(GroupMembershipPolicy.maxMembersPerGroup)人まで")
                        } else {
                            picked.insert(friend.id)
                            Haptics.play(.pop)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            LayerAvatar(data: friend.avatarData, seed: friend.seed, name: friend.name)
                                .frame(width: 54, height: 54)
                                .padding(3)
                                .background(Circle().fill(on ? AnyShapeStyle(LinearGradient(colors: GroupAddColors.sunset, startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(palette.fill)))
                                .overlay(alignment: .bottomTrailing) {
                                    Text("✓").font(.system(size: 12, weight: .heavy)).foregroundStyle(palette.bg)
                                        .frame(width: 22, height: 22).background(Circle().fill(palette.ink))
                                        .scaleEffect(on ? 1 : 0.01)
                                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.5), value: on)
                                }
                            Text(friend.name).font(.system(size: 11.5, weight: .bold)).foregroundStyle(palette.ink).lineLimit(1)
                        }
                    }
                    .buttonStyle(SquishButtonStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            note("リンクは いらない。", "えらんだ人に「招待カード」が とどいて、OKすると 入るよ。かってには 入らないから あんしん。")
            bigButton(picked.isEmpty ? "えらんで 招待カードを おくる" : "\(picked.count)人に 招待カードを おくる", primary: true) {
                guard !picked.isEmpty else {
                    Haptics.play(.warn)
                    show("だれか えらんでね")
                    return
                }
                guard let group = groups.first(where: { $0.id == targetGroup }) ?? groups.first else {
                    Haptics.play(.warn)
                    show("さきに グループを つくってね")
                    return
                }
                guard let context = group.modelContext else { return }
                Task {
                    let link = try? await GroupInviteService.link(for: group, context: context)
                    let ok = await FriendCloud.sendInvites(to: Array(picked), groupName: group.name, memberCount: group.members.count, shareURL: link, myName: myName)
                    if ok {
                        Haptics.play(.success)
                        show("\(picked.count)人に 招待カードを おくったよ")
                        picked = []
                    } else {
                        Haptics.play(.warn)
                        show(FriendError.network.message)
                    }
                }
            }
        }
    }

    // MARK: とどいた

    private var inboxTab: some View {
        VStack(spacing: 14) {
            if inbox.filter({ $0.status != .declined || true }).isEmpty {
                note("まだ", "招待カードは とどいていないよ。")
            }
            ForEach(inbox) { card in
                VStack(alignment: .leading, spacing: 6) {
                    Text("INVITE").font(.system(size: 10.5, weight: .bold, design: .monospaced)).tracking(0.14 * 10.5).opacity(0.7)
                    Text("\(card.groupName) から\n招待が きたよ").font(.system(size: 28, weight: .heavy)).tracking(-0.05 * 28)
                    Text("\(card.fromName) が 呼んでるよ ・ \(card.memberCount)人").font(.system(size: 13)).opacity(0.8)
                    HStack(spacing: 10) {
                        Button {
                            Haptics.play(.soft)
                            show("あとで 見られるよ")
                        } label: {
                            Text("あとで").font(.system(size: 15, weight: .heavy)).frame(maxWidth: .infinity, minHeight: 50)
                                .background(Capsule().fill(palette.bg.opacity(0.14)))
                        }
                        .buttonStyle(SquishButtonStyle())
                        Button {
                            guard let url = card.shareURL else { show("この招待は、もう つかえないよ"); return }
                            Haptics.play(.success)
                            // 本人が「入る」を押したときだけ、共有を受けいれる(参加の流れへ)
                            InviteCardStore.set(.accepted, for: card.id)
                            if let i = inbox.firstIndex(where: { $0.id == card.id }) { inbox[i].status = .accepted }
                            NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.link(url))
                        } label: {
                            Text(card.status == .accepted ? "入った ✓" : "入る").font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Capsule().fill(LinearGradient(colors: GroupAddColors.sunset, startPoint: .leading, endPoint: .trailing)))
                        }
                        .buttonStyle(SquishButtonStyle())
                        .disabled(card.status == .accepted)
                    }
                    .padding(.top, 10)
                }
                .foregroundStyle(palette.bg)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(palette.ink))
            }
            note("入ると、", "グループの みんなの 投稿が 見えるよ。入るまでは、投稿も メンバーも 見えないよ。")
        }
    }

    // MARK: 部品

    private func bigButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 17, weight: .heavy))
                .foregroundStyle(primary ? palette.bg : palette.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(primary ? palette.ink : palette.bg))
                .overlay { if !primary { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.groupAdd.secondaryLine, lineWidth: 1.5) } }
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
    }

    private func rowButton(icon: String, title: String, note: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).frame(width: 48, height: 48).background(Circle().fill(palette.fill))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 18, weight: .heavy))
                    Text(note).font(.system(size: 12.5)).foregroundStyle(palette.groupAdd.note)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(palette.ink)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(palette.bg))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.groupAdd.secondaryLine, lineWidth: 1.5))
        }
        .buttonStyle(SquishButtonStyle(pressedScale: 0.97))
    }

    private func note(_ bold: String, _ text: String) -> some View {
        (Text(bold).bold().foregroundColor(palette.ink) + Text(" " + text))
            .font(.system(size: 12.5))
            .foregroundStyle(palette.groupAdd.note)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(palette.fill))
    }

    private func refuseFull() {
        Haptics.play(.warn)
        show(FriendRules.fullMessage)
    }

    private func show(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { if toast == message { toast = nil } }
    }
}

/// QR の画像(CoreImage)
enum QRImage {
    static func make(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
