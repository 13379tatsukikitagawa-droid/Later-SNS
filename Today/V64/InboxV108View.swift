import SwiftUI

/// v109 §3-2:Trip の リンク(`/t/<トークン または KEY>`)を ひらいた 時の 受け渡し。ログイン前は おぼえて おく。
enum TripLinkInbox {
    static let key = "pendingTripLinkToken"
    static var pending: String? { let t = UserDefaults.standard.string(forKey: key) ?? ""; return t.isEmpty ? nil : t }
    static func set(_ token: String) { UserDefaults.standard.set(token, forKey: key) }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
extension Notification.Name { static let tripLinkOpened = Notification.Name("tripLinkOpened") }

/// v108 §3:お知らせ(友だち申請 + Trip の 招待)。Worker が できるまでは 今の CloudKit の 申請で 動かす(v108 つなぎ)。
struct InboxV108View: View {
    let myName: String
    var onChanged: () -> Void = {}
    var onShareLink: () -> Void = {}
    var onOpenChat: (_ friendID: String, _ name: String) -> Void = { _, _ in }
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable { case all = "すべて", friends = "友だち", trip = "Trip" }
    enum Kind { case friend, trip }
    struct Row: Identifiable, Equatable {
        let id: String
        let kind: Kind
        var title: String
        var sub: String
        var handle: String = ""
        var request: FriendRequests.Request?
        var card: FriendInviteCard?
        var linkURL: URL?
        var pinned = false
        var expired = false
        var state: State = .pending
        enum State { case pending, done, gone }
        static func == (a: Row, b: Row) -> Bool { a.id == b.id && a.state == b.state }
    }
    struct Past: Codable, Identifiable { var id = UUID().uuidString; var text: String; var kind: String; var otherID: String; var name: String; var date: Date }

    @State private var tab: Tab = TripLinkInbox.pending != nil ? .trip : .all
    @State private var rows: [Row] = []
    @State private var past: [Past] = Self.loadPast()
    @State private var loading = true
    @State private var burst: String?

    private static let pastKey = "inboxPastV108"
    private static func loadPast() -> [Past] {
        let all = (UserDefaults.standard.data(forKey: pastKey)).flatMap { try? JSONDecoder().decode([Past].self, from: $0) } ?? []
        return all.filter { Date().timeIntervalSince($0.date) < 30 * 86400 }
    }
    private func savePast() { UserDefaults.standard.set(try? JSONEncoder().encode(past), forKey: Self.pastKey) }

    private var shown: [Row] { rows.filter { $0.state != .gone && (tab == .all || (tab == .friends) == ($0.kind == .friend)) } }
    private func count(_ t: Tab) -> Int { rows.filter { $0.state == .pending && (t == .all || (t == .friends) == ($0.kind == .friend)) }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Text("とじる").font(Typo.ui(700, 15)).foregroundStyle(.white).frame(height: 44).padding(.horizontal, 4) }.buttonStyle(.plain)
                Spacer()
                Button { Haptics.play(.sel); onShareLink() } label: {
                    Image(systemName: "link").font(.system(size: 17, weight: .bold)).foregroundStyle(HV.lime).frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(HV.lime.opacity(0.5), lineWidth: 1.5).frame(width: 40, height: 40))
                }.buttonStyle(.plain).accessibilityLabel("リンクを 送る")
            }.padding(.horizontal, 16).overlay(Text("お知らせ").font(Typo.ui(900, 20)).foregroundStyle(.white))
            HStack(spacing: 8) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Button { Haptics.play(.tick); withAnimation(.easeOut(duration: 0.2)) { tab = t } } label: {
                        HStack(spacing: 6) {
                            Text(t.rawValue).font(Typo.ui(800, 13))
                            if count(t) > 0 { Text("\(count(t))").font(Typo.ui(800, 11)).foregroundStyle(HV.ink).padding(.horizontal, 6).frame(minWidth: 18, minHeight: 18).background(PopColor.pink, in: Capsule()) }
                        }
                        .foregroundStyle(tab == t ? HV.ink : .white).padding(.horizontal, 14).frame(height: 36)
                        .background(tab == t ? Color.white : Color.white.opacity(0.1), in: Capsule())
                    }.buttonStyle(.plain)
                }
                Spacer()
            }.padding(.horizontal, 16).padding(.top, 10)
            ScrollView {
                VStack(spacing: 10) {
                    if loading { ProgressView().tint(.white).padding(.top, 60) }
                    else if shown.isEmpty && pastShown.isEmpty { empty }
                    ForEach(shown) { r in row(r).transition(.opacity.combined(with: .offset(x: -40))) }
                    if !pastShown.isEmpty {
                        Text("これまで").font(Typo.ui(800, 12)).tracking(0.8).foregroundStyle(HV.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 14)
                        ForEach(pastShown) { p in pastRow(p) }
                    }
                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 40)
            }
        }
        .background(Color(hex: "0A0A0B").ignoresSafeArea()).preferredColorScheme(.dark)
        .task { await load() }
    }

    private var pastShown: [Past] { past.filter { tab == .all || (tab == .friends) == ($0.kind == "friend") } }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell").font(.system(size: 36, weight: .regular)).foregroundStyle(HV.gray)
            Text("お知らせは ありません").font(Typo.ui(800, 16)).foregroundStyle(.white)
            Text("友だち申請 と Trip の 招待が ここに 来ます").font(Typo.ui(500, 13)).foregroundStyle(HV.gray)
        }.padding(.top, 80)
    }

    private func row(_ r: Row) -> some View {
        let done = r.state == .done
        return HStack(spacing: 12) {
            if r.kind == .friend {
                Text(String(r.title.prefix(1))).font(Typo.ui(800, 18)).foregroundStyle(HV.ink).frame(width: 48, height: 48).background(Color(hex: "61DD7A"), in: Circle())
            } else {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: "2A2A2E")).frame(width: 48, height: 60)
                    .overlay(alignment: .bottomTrailing) { Image(systemName: "suitcase.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(HV.ink).frame(width: 20, height: 20).background(HV.lime, in: Circle()).offset(x: 5, y: 5) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.title).font(Typo.ui(800, 16)).foregroundStyle(.white).lineLimit(1)
                if done { Text(r.kind == .friend ? "友だちに なりました ・ あしたの 9:00 から 見せあえます" : "参加しました").font(Typo.ui(600, 12)).foregroundStyle(HV.lime).fixedSize(horizontal: false, vertical: true) }
                else {
                    if !r.handle.isEmpty { Text("@\(r.handle)").font(Typo.ui(600, 12)).foregroundStyle(HV.gray).lineLimit(1) }
                    Text(r.sub).font(Typo.ui(500, 12)).foregroundStyle(HV.gray).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if done {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .black)).foregroundStyle(HV.ink).frame(width: 40, height: 40).background(HV.lime, in: Circle())
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else {
                Button { dismissRow(r) } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(HV.gray).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("消す")
                if r.expired {
                    PopButton(title: "KEY で 入る", kind: .lime, small: true) { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.passphrase) } }
                } else {
                PopButton(title: r.kind == .friend ? "承認" : "参加", kind: .lime, small: true) { accept(r) }
                }
            }
        }
        .padding(12).background(Color(hex: "1C1C1F"), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(HV.lime, lineWidth: (done || r.pinned) ? 1.5 : 0))
        .overlay(alignment: .trailing) { if burst == r.id { Dots().offset(x: -30) } }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: done)
    }

    private func pastRow(_ p: Past) -> some View {
        HStack(spacing: 12) {
            Image(systemName: p.kind == "friend" ? "person.fill" : "suitcase.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(HV.gray).frame(width: 36, height: 36).background(Color.white.opacity(0.08), in: Circle())
            Text(p.text).font(Typo.ui(600, 14)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
            Spacer()
            if p.kind == "friend", !p.otherID.isEmpty {
                Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onOpenChat(p.otherID, p.name) } } label: { Image(systemName: "bubble.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(HV.lime).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("チャット")
            }
        }.padding(.horizontal, 12).padding(.vertical, 4)
    }

    // MARK: データ

    private func load() async {
        let reqs = await FriendRequests.incoming()
        let invites = await FriendCloud.inbox().filter { $0.status == .pending }
        var linkRow: Row?
        if let token = TripLinkInbox.pending {
            let w = await SocialClient.resolveTripLink(token: token)   // ランダムな トークン(Worker)。古い KEY 形式は nil → そのまま KEY で 探す
            if let url = try? await GroupInviteService.resolve(passphrase: w?.key ?? token, timeout: 10) {
                let name = (w?.groupName ?? "").isEmpty ? "Trip に 招待されました" : "『\(w!.groupName!)』に 招待"
                let from = (w?.fromName ?? "").isEmpty ? "" : "\(w!.fromName!) から ・ "
                linkRow = Row(id: "l-" + token, kind: .trip, title: name, sub: from + "参加の まえに たしかめて ください", linkURL: url, pinned: true)
            } else {
                linkRow = Row(id: "l-" + token, kind: .trip, title: "リンクの 期限が 切れました", sub: "もう一度 送って もらって ください", pinned: true, expired: true)
            }
            TripLinkInbox.clear()
        }
        var out: [Row] = reqs.map { r in
            Row(id: "f-" + r.id, kind: .friend, title: r.fromName.isEmpty ? "ともだち" : r.fromName, sub: "友だち申請 ・ " + Self.ago(r.createdAt), handle: r.fromUsername, request: r)
        }
        out += invites.map { c in Row(id: "t-" + c.id, kind: .trip, title: "『\(c.groupName)』に 招待", sub: "\(c.fromName) から ・ \(c.memberCount)人", card: c) }
        if let linkRow { out.insert(linkRow, at: 0) }
        rows = out; loading = false
    }

    private static func ago(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 3600 { return "\(max(1, s / 60))分" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)日"
    }

    private func accept(_ r: Row) {
        if r.kind == .friend, let req = r.request {
            Haptics.play(.success); mark(r, .done)
            Task { _ = await FriendRequests.respond(to: req, accept: true, myName: myName); onChanged() }
            finish(r, text: "\(r.title) と 友だちに なりました", kind: "friend", other: req.fromUserID)
        } else if let url = r.linkURL {
            Haptics.play(.success); mark(r, .done)
            finish(r, text: "Trip に 参加しました", kind: "trip", other: "")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                dismiss()
                NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.link(url))
            }
        } else if let card = r.card {
            guard let url = card.shareURL else { Haptics.play(.warn); return }
            InviteCardStore.set(.accepted, for: card.id)
            Haptics.play(.success); mark(r, .done)
            finish(r, text: "『\(card.groupName)』に 参加しました", kind: "trip", other: "")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                dismiss()
                NotificationCenter.default.post(name: .joinFlowRequested, object: JoinFlowStart.link(url))
            }
        }
    }

    private func dismissRow(_ r: Row) {
        Haptics.play(.tick)
        if let req = r.request { Task { _ = await FriendRequests.respond(to: req, accept: false, myName: myName); onChanged() } }
        if let card = r.card { InviteCardStore.set(.declined, for: card.id) }
        withAnimation(.easeIn(duration: 0.26)) { mark(r, .gone) }
    }

    private func mark(_ r: Row, _ s: Row.State) {
        if let i = rows.firstIndex(where: { $0.id == r.id }) { rows[i].state = s }
        if s == .done { burst = r.id; DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { burst = nil } }
    }

    private func finish(_ r: Row, text: String, kind: String, other: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                mark(r, .gone)
                past.insert(Past(text: text, kind: kind, otherID: other, name: r.title, date: Date()), at: 0)
                savePast()
            }
        }
    }

    /// ライムの 点が 7つ はじける
    private struct Dots: View {
        @State private var go = false
        var body: some View {
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    let a = Double(i) / 7 * 2 * .pi
                    Circle().fill(HV.lime).frame(width: 6, height: 6)
                        .offset(x: go ? cos(a) * 34 : 0, y: go ? sin(a) * 34 : 0).opacity(go ? 0 : 1)
                }
            }.onAppear { withAnimation(.easeOut(duration: 0.6)) { go = true } }.allowsHitTesting(false)
        }
    }
}
