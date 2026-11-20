import SwiftData
import SwiftUI
import UIKit

// MARK: - グループの 部屋(v23)
//
// LINE の かわりでは なく「きのうの 写真の まわりで 話す 場所」。
// 上から:ヘッダー(もどる・名前 +「あと N人で そろう」・メニュー)→ メンバーの 列 + 今週の 点 → きのうの カード → メッセージ → 入力。
// いいね・既読・人数の 数字は 出さない。スタンプ = ハッシュタグ。メッセージは 7日で 消える。

// MARK: そろった(グループ全員が 今日 1枚)

enum GroupTogether {
    struct Member: Identifiable, Equatable {
        let id: String
        let name: String
        let seed: UUID
        let avatarData: Data?
        let isMe: Bool
        let shotToday: Bool
    }

    /// メンバー(同じ人は 1人)。今日 撮ったか は 共有ゾーンの 写真(撮った人・時刻は 投稿前でも 届く)で 見る
    static func members(of group: LaterGroup, me: String?, myShots: Int, now: Date, calendar: Calendar = .current) -> [Member] {
        let window = DailyWindow.latest(for: now, calendar: calendar)
        let shooters = Set(group.photos.filter { $0.captureDate >= window.open && $0.captureDate < window.close }.compactMap(\.authorCloudKitUserRecordName))
        var seen = Set<String>()
        var list: [Member] = []
        for profile in group.members {
            let key = profile.cloudKitUserRecordName ?? "local_\(profile.id.uuidString)"
            guard seen.insert(key).inserted else { continue }
            let isMe = key == me
            list.append(Member(id: key, name: profile.name, seed: profile.id, avatarData: profile.profileImageData,
                               isMe: isMe, shotToday: isMe ? (myShots > 0 || shooters.contains(key)) : shooters.contains(key)))
        }
        // 自分を 先に
        return list.sorted { $0.isMe && !$1.isMe }
    }

    /// まだ 撮っていない 人の 数
    static func remaining(_ members: [Member]) -> Int { members.filter { !$0.shotToday }.count }

    /// 「あと 2人で そろう」/「そろった」/ 1人の ときは なし
    static func status(_ members: [Member]) -> String? {
        guard members.count >= 2 else { return nil }
        let left = remaining(members)
        return left == 0 ? "そろった" : "あと \(left)人で そろう"
    }

    struct Dot: Identifiable, Equatable {
        let id: Int
        let together: Bool
        let isToday: Bool
        let isFuture: Bool
    }

    /// 今週(月〜日)の 7つ。そろった日だけ 塗る。途切れても 何も 失わない(数は 出さない)
    static func week(of group: LaterGroup, memberIDs: [String], now: Date, calendar base: Calendar = .current) -> [Dot] {
        var calendar = base
        calendar.firstWeekday = 2
        let todayKey = ExposureDayStore.dayKey(for: DailyWindow.latest(for: now, calendar: calendar).open, calendar: calendar)
        let start = calendar.dateInterval(of: .weekOfYear, for: DailyWindow.latest(for: now, calendar: calendar).open)?.start ?? now
        let byDay = Dictionary(grouping: group.photos) { ExposureDayStore.dayKey(for: $0.captureDate, calendar: calendar) }
        let need = Set(memberIDs)
        return (0..<7).map { i in
            let date = calendar.date(byAdding: .day, value: i, to: start) ?? start
            let key = ExposureDayStore.dayKey(for: date, calendar: calendar)
            let shooters = Set((byDay[key] ?? []).compactMap(\.authorCloudKitUserRecordName))
            let together = need.count >= 2 && need.isSubset(of: shooters)
            return Dot(id: i, together: together, isToday: key == todayKey, isFuture: key > todayKey)
        }
    }
}

// MARK: - 画面

struct PassBox: Identifiable { let id = UUID(); let data: TripPassData }

struct GroupChatRoomView: View {
    let group: LaterGroup
    /// ホームの ともだち(今は 使わない)
    var friends: [HomeFriend] = []
    let onClose: () -> Void
    /// メニュー:メンバー・ぬける など(今までの グループの 画面)
    let onOpenGroupSheet: () -> Void
    var onToast: (String) -> Void = { _ in }
    /// v28:はじめから この 写真への 返信に する
    var initialReply: LaterPhoto? = nil
    @State private var showsInviteFriends = false
    /// v98:Trip の KEY と パス(だれも いない 時の BOARDING)
    @State private var tripKey = ""
    @State private var tripPass: TripPassData?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var blockedUsers: [BlockedUser]
    @Query private var profiles: [UserProfile]

    @State private var store = GroupChatStore.shared
    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    @State private var showsStickers = false
    @State private var focus: ChatMessage?
    @State private var reporting: ChatMessage?
    @State private var blocking: ChatMessage?
    @State private var openPhoto: LaterPhoto?
    @State private var replyPhoto: LaterPhoto?
    @State private var toast: String?
    @State private var shareItems: [Any]?
    @State private var now = Date()

    private var me: String? { CloudKitManager.current?.currentUserRecordName }
    private var blocked: Set<String> { Set(blockedUsers.map(\.blockedCloudKitUserRecordName)) }
    /// v98:だれも いない 時は いつも 黒(`#0B0B0C`)
    private var night: Bool { palette.isNight || members.count <= 1 }
    private var bg: Color { night ? Color(hex: "0B0B0E") : Color(hex: "F7F5F1") }
    private var ink: Color { night ? Color(hex: "F5F5F7") : Color(hex: "111111") }
    private var sub: Color { night ? Color(hex: "A1A1A8") : Color(hex: "8E8E95") }
    private var card: Color { night ? Color.white.opacity(0.07) : .white }
    private var members: [GroupTogether.Member] {
        GroupTogether.members(of: group, me: me, myShots: FilmCounter.shared.used, now: now)
    }
    private var messages: [ChatMessage] { store.visible(group.id, blocked: blocked, now: now) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if members.count <= 1 {
                emptyRoom
            } else {
                ScrollViewReader { reader in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            membersRow.padding(.top, 6)
                            yesterdayCard.padding(.top, 14)
                            messageList.padding(.top, 18)
                            Color.clear.frame(height: 8).id("bottom")
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { DispatchQueue.main.async { reader.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: inputFocused) { _, focused in
                        if focused { withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("bottom", anchor: .bottom) } }
                    }
                    .onChange(of: messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("bottom", anchor: .bottom) }
                        store.markSeen(group.id)
                    }
                }
                inputBar
            }
        }
        .background(bg.ignoresSafeArea())
        .overlay { if let focus { focusOverlay(focus) } }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(night ? Color(hex: "111111") : .white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(night ? .white : Color(hex: "111111")))
                    .padding(.top, 70)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
        .preferredColorScheme(night ? .dark : .light)
        .onAppear {
            Haptics.play(.pop)
            store.openRoom = group.id
            store.markSeen(group.id)
            if let initialReply {
                replyPhoto = initialReply
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { inputFocused = true }
            }
        }
        .onDisappear {
            if store.openRoom == group.id { store.openRoom = nil }
            store.markSeen(group.id)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date()
            }
        }
        .sheet(item: $openPhoto) { photo in photoViewer(photo) }
        .sheet(isPresented: $showsStickers) { stickerBox.presentationDetents([.height(260)]) }
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
            ShareSheet(activityItems: shareItems ?? []) { _ in shareItems = nil }
        }
        .fullScreenCover(item: Binding(get: { tripPass.map { PassBox(data: $0) } }, set: { if $0 == nil { tripPass = nil } })) { box in
            TripPassView(data: box.data, newlyMade: false, onStart: { tripPass = nil }, onClose: { tripPass = nil })
        }
        .fullScreenCover(isPresented: $showsInviteFriends) {
            // v98:古い「ともだち ・ 呼ぶ」画面は 消した。どこから 来ても v94 の さがす 画面
            FriendsV68View(myName: UserProfile.current(from: profiles)?.name ?? "", friends: friends, groups: [group], onClose: { showsInviteFriends = false })
                .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NotificationCenter.default.post(name: .friendsSearchFocus, object: nil) } }
        }
        .confirmationDialog("通報する 理由", isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }), titleVisibility: .visible) {
            ForEach(ChatReport.Reason.allCases) { reason in
                Button(reason.rawValue) { if let message = reporting { report(message, reason: reason) } }
            }
            Button("やめる", role: .cancel) { reporting = nil }
        }
        .alert(blockTitle, isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })) {
            Button("ブロックする", role: .destructive) { if let message = blocking { block(message) } }
            Button("やめる", role: .cancel) { blocking = nil }
        } message: {
            Text("その人の メッセージと 写真が、あなたに 見えなく なります。相手には 知らせません。")
        }
    }

    private var blockTitle: String {
        guard let blocking else { return "" }
        return "\(name(of: blocking.senderId)) を ブロックする?"
    }

    // MARK: ヘッダー

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.play(.tick)
                onClose()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("もどる")
            VStack(alignment: .leading, spacing: 2) {
                // v28:見出しは セリフ体(日本語は 明朝)、下に 小さく オレンジ
                Text(group.name).font(Darkroom.title(group.name, size: 24)).foregroundStyle(ink).lineLimit(1)
                if let status = GroupTogether.status(members) {
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "FF6A1A"))
                        .contentTransition(.opacity)
                }
            }
            Spacer()
            Menu {
                Button("メンバー・グループの 画面", systemImage: "person.2") { onOpenGroupSheet() }
                Button(store.isMuted(group.id) ? "通知を オンにする" : "通知を オフにする", systemImage: store.isMuted(group.id) ? "bell" : "bell.slash") {
                    store.setMuted(group.id, !store.isMuted(group.id))
                    show(store.isMuted(group.id) ? "この 部屋の 通知を オフに しました" : "この 部屋の 通知を オンに しました")
                }
                Button("リンクで よぶ", systemImage: "link") { shareLink() }
                Button("友だちから 招待", systemImage: "person.badge.plus") { showsInviteFriends = true }
                Button("ぬける", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { onOpenGroupSheet() }
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 17, weight: .bold)).foregroundStyle(ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("メニュー")
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: メンバーの 列 + 今週の 点

    private var membersRow: some View {
        HStack(alignment: .center, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(members) { member in memberIcon(member) }
                }
                .padding(.vertical, 4)
            }
            weekDots
        }
    }

    private func memberIcon(_ member: GroupTogether.Member) -> some View {
        Button { tapMember(member) } label: {
            LayerAvatar(data: member.avatarData, seed: member.seed, name: member.name)
                .frame(width: 38, height: 38)
                .padding(3)
                .overlay(
                    Circle().strokeBorder(member.shotToday ? Color(hex: "FF6A1A") : sub.opacity(0.7),
                                          style: StrokeStyle(lineWidth: 2, dash: member.shotToday ? [] : [3, 3]))
                )
        }
        .buttonStyle(SquishButtonStyle())
        .accessibilityLabel("\(member.name)。\(member.shotToday ? "今日 撮った" : "まだ")")
        .accessibilityHint(member.isMe ? (member.shotToday ? "現像を見ます" : "撮影へ") : "")
    }

    /// v47:自分(撮った)→ 現像 / 自分(まだ)→ 撮影 / ほかの人(撮った)→ 知らせる / ほかの人(まだ)→ 何もしない
    private func tapMember(_ member: GroupTogether.Member) {
        if member.isMe {
            Haptics.play(.tick)
            if member.shotToday {
                DevelopRequestStore.shared.request()
            } else {
                CaptureRequestStore.shared.pendingRequestID = UUID()
            }
            return
        }
        if member.shotToday {
            Haptics.play(.tick)
            show("\(member.name)・今日 撮った・9:00に ひらく")
            return
        }
    }

    private var weekDots: some View {
        let dots = GroupTogether.week(of: group, memberIDs: members.map(\.id), now: now)
        return HStack(spacing: 5) {
            ForEach(dots) { dot in
                Circle()
                    .fill(dot.together ? Color(hex: "FF6A1A") : Color.clear)
                    .overlay(Circle().strokeBorder(dot.together ? Color.clear : sub.opacity(dot.isFuture ? 0.3 : 0.6), lineWidth: 1.2))
                    .frame(width: dot.isToday ? 11 : 7, height: dot.isToday ? 11 : 7)
                    .overlay { if dot.isToday { Circle().strokeBorder(ink, lineWidth: 1.5).frame(width: 15, height: 15) } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今週 そろった 日:\(dots.filter(\.together).count)日")
    }

    // MARK: きのうの カード

    private var yesterdayPhotos: [LaterPhoto] {
        let window = DailyWindow.yesterday(for: now)
        var seen = Set<String>()
        return group.photos
            .filter { $0.captureDate >= window.open && $0.captureDate < window.close }
            .filter { ($0.isPosted || $0.authorCloudKitUserRecordName == me) && !$0.imageData.isEmpty }
            .filter { !blocked.contains($0.authorCloudKitUserRecordName ?? "") }
            .sorted { $0.captureDate < $1.captureDate }
            .filter { seen.insert($0.dedupeKey).inserted }
    }

    private var yesterdayCard: some View {
        let photos = yesterdayPhotos
        let locked = FilmCounter.shared.used == 0
        return VStack(alignment: .leading, spacing: 10) {
            Text("きのうの みんな")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(sub)
            if photos.isEmpty {
                Text("きのうの 写真は ありません")
                    .font(.system(size: 13))
                    .foregroundStyle(sub)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                guard !locked else {
                                    LayerHaptics.softDouble()
                                    show("今日 1枚 撮ると、ひらきます")
                                    return
                                }
                                Haptics.play(.pop)
                                openPhoto = photo
                            } label: {
                                miniCheki(photo, rotation: index.isMultiple(of: 2) ? -3 : 3)
                            }
                            .buttonStyle(SquishButtonStyle())
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
                .blur(radius: locked ? 10 : 0)
                .overlay {
                    if locked {
                        Label("撮ると、ひらく", systemImage: "lock.fill")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 14).frame(height: 34)
                            .background(Capsule().fill(card))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(card))
    }

    private func miniCheki(_ photo: LaterPhoto, rotation: Double) -> some View {
        VStack(spacing: 0) {
            ChatPhotoThumb(photo: photo)
                .frame(width: 62, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            Color.clear.frame(height: 14)
        }
        .padding(.horizontal, 4).padding(.top, 4)
        .background(RoundedRectangle(cornerRadius: 3).fill(.white))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
        .rotationEffect(.degrees(rotation))
    }

    private func photoViewer(_ photo: LaterPhoto) -> some View {
        VStack(spacing: 18) {
            ChatPhotoThumb(photo: photo, maxPixel: 1200)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
            Text("\(name(of: photo.authorCloudKitUserRecordName ?? "")) ・ \(TodayFilmRules.timeText(photo.captureDate))")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
            Button {
                Haptics.play(.click)
                replyPhoto = photo
                openPhoto = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { inputFocused = true }
            } label: {
                Text("これに 返信").font(.system(size: 16, weight: .heavy)).foregroundStyle(Color(hex: "111111"))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(.white))
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0B0B0E").ignoresSafeArea())
        .presentationDetents([.large])
    }

    // MARK: メッセージ

    private var messageList: some View {
        let list = messages
        return VStack(spacing: 2) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, message in
                let previous = index > 0 ? list[index - 1] : nil
                if let divider = ChatDivider.text(between: previous, and: message) {
                    Text(divider)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(sub)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                }
                messageRow(message, showsHeader: previous?.senderId != message.senderId || ChatDivider.text(between: previous, and: message) != nil)
                    .id(message.id)
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage, showsHeader: Bool) -> some View {
        if message.kind == .system {
            Text(message.text)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(sub)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        } else {
            let mine = message.senderId == me
            HStack(alignment: .bottom, spacing: 8) {
                if mine { Spacer(minLength: 48) }
                if !mine {
                    if showsHeader {
                        avatar(for: message.senderId).frame(width: 30, height: 30)
                    } else {
                        Color.clear.frame(width: 30, height: 1)
                    }
                }
                VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                    if showsHeader && !mine {
                        Text(name(of: message.senderId)).font(.system(size: 11, weight: .bold)).foregroundStyle(sub)
                    }
                    bubble(message, mine: mine)
                        .onTapGesture(count: 2) { toggle(ChatRules.doubleTapSticker, on: message) }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            Haptics.play(.thud)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { focus = message }
                        }
                        .onTapGesture {
                            if mine, message.status == .failed {
                                Haptics.play(.click)
                                store.retry(message, group: group)
                            }
                        }
                    stickerChips(message)
                }
                if !mine { Spacer(minLength: 48) }
            }
            .padding(.top, showsHeader ? 10 : 2)
        }
    }

    private func bubble(_ message: ChatMessage, mine: Bool) -> some View {
        let tint = ChatColors.tint(seed: seed(of: message.senderId), night: night)
        return VStack(alignment: .leading, spacing: 6) {
            if message.kind == .photoReply, let photo = photo(named: message.photoRecordName) {
                ChatPhotoThumb(photo: photo)
                    .frame(width: 120, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if message.kind == .sticker, let sticker = message.stickerId {
                Text("#\(sticker)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color(hex: "FF6A1A"))
            } else if ChatRules.isEmojiOnly(message.text) {
                Text(message.text).font(.system(size: 44))
            } else if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(mine ? (night ? Color(hex: "111111") : .white) : ink)
            }
        }
        .padding(.horizontal, message.kind == .sticker || ChatRules.isEmojiOnly(message.text) ? 4 : 13)
        .padding(.vertical, message.kind == .sticker || ChatRules.isEmojiOnly(message.text) ? 2 : 9)
        .background {
            if message.kind != .sticker && !ChatRules.isEmojiOnly(message.text) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(mine ? (night ? Color.white : Color(hex: "111111")) : tint)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if mine, message.status == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(hex: "FF3B30"))
                    .background(Circle().fill(bg))
                    .offset(x: -24)
                    .accessibilityLabel("送れませんでした。タップで もういちど")
            }
        }
        .opacity(message.status == .sending ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mine ? "あなた" : name(of: message.senderId))。\(message.kind == .sticker ? "#" + (message.stickerId ?? "") : message.text)")
        .accessibilityAction(named: "#それな を はる") { toggle(ChatRules.doubleTapSticker, on: message) }
        .accessibilityAction(named: "メニュー") { focus = message }
    }

    /// はった スタンプ(数は 出さない。種類だけ)
    @ViewBuilder
    private func stickerChips(_ message: ChatMessage) -> some View {
        let kinds = Array(Set(store.stickers(on: message.id, groupID: group.id).filter { !blocked.contains($0.senderId) }.map(\.stickerId))).sorted()
        if !kinds.isEmpty {
            HStack(spacing: 4) {
                ForEach(kinds, id: \.self) { kind in
                    Text("#\(kind)")
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(Color(hex: "FF6A1A"))
                        .padding(.horizontal, 7).frame(height: 20)
                        .background(Capsule().fill(card))
                        .overlay(Capsule().strokeBorder(Color(hex: "FF6A1A").opacity(0.35), lineWidth: 1))
                }
            }
        }
    }

    // MARK: 長押し(浮く + 上に スタンプ 5つ + 下に メニュー)

    private func focusOverlay(_ message: ChatMessage) -> some View {
        let mine = message.senderId == me
        return ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { focus = nil } }
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(ChatRules.quickStickers, id: \.self) { kind in
                        Button {
                            toggle(kind, on: message)
                            withAnimation(.easeOut(duration: 0.2)) { focus = nil }
                        } label: {
                            Text("#\(kind)").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color(hex: "FF6A1A"))
                                .padding(.horizontal, 9).frame(height: 32)
                                .background(Capsule().fill(card))
                        }
                    }
                }
                bubble(message, mine: mine)
                    .scaleEffect(reduceMotion ? 1 : 1.04)
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 10)
                VStack(spacing: 0) {
                    menuRow("コピー", icon: "doc.on.doc") {
                        UIPasteboard.general.string = message.kind == .sticker ? "#" + (message.stickerId ?? "") : message.text
                        show("コピーしました")
                    }
                    if mine {
                        menuRow("とりけす", icon: "arrow.uturn.backward", destructive: true) {
                            Haptics.play(.soft)
                            store.unsend(message, group: group)
                        }
                    } else {
                        menuRow("通報する", icon: "exclamationmark.bubble", destructive: true) { reporting = message }
                        menuRow("ブロック", icon: "hand.raised", destructive: true) { blocking = message }
                    }
                }
                .frame(width: 220)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(card))
            }
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    private func menuRow(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { focus = nil }
            action()
        } label: {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: icon)
            }
            .foregroundStyle(destructive ? Color(hex: "FF3B30") : ink)
            .padding(.horizontal, 16).frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 入力

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let replyPhoto {
                HStack(spacing: 8) {
                    ChatPhotoThumb(photo: replyPhoto).frame(width: 30, height: 38).clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("この 写真に 返信").font(.system(size: 12, weight: .bold)).foregroundStyle(sub)
                    Spacer()
                    Button { self.replyPhoto = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(sub) }
                        .accessibilityLabel("返信を やめる")
                }
                .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    Haptics.play(.pop)
                    showsStickers = true
                } label: {
                    Text("#").font(.system(size: 20, weight: .black)).foregroundStyle(ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(card))
                }
                .accessibilityLabel("タグの スタンプ")
                TextField("メッセージ", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15))
                    .focused($inputFocused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(card))
                    .onChange(of: draft) { _, value in
                        if value.count > ChatRules.maxLength { draft = String(value.prefix(ChatRules.maxLength)) }
                    }
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || replyPhoto != nil {
                    Button(action: sendDraft) {
                        Image(systemName: "arrow.up").font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(night ? Color(hex: "111111") : .white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(hex: "FF6A1A")))
                    }
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("送る")
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(bg.opacity(0.96))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: draft.isEmpty)
    }

    private var stickerBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タグで ひとこと").font(.system(size: 13, weight: .heavy)).foregroundStyle(sub)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                ForEach(ChatRules.stickers, id: \.self) { kind in
                    Button {
                        Haptics.play(.pop)
                        showsStickers = false
                        store.send(kind: .sticker, stickerId: kind, group: group)
                    } label: {
                        Text("#\(kind)").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(hex: "FF6A1A"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(card))
                    }
                    .buttonStyle(SquishButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(bg)
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let refusal = ChatRules.check(text) {
            LayerHaptics.softDouble()
            show(refusal)
            return
        }
        Haptics.play(.click)
        if let replyPhoto {
            store.send(kind: .photoReply, text: text, photoRecordName: replyPhoto.ckRecordName, group: group)
        } else {
            store.send(kind: .text, text: text, group: group)
        }
        draft = ""
        replyPhoto = nil
    }

    private func toggle(_ sticker: String, on message: ChatMessage) {
        if store.toggleSticker(sticker, on: message, group: group) {
            Haptics.play(.pop)
        } else {
            Haptics.play(.tick)
        }
    }

    // MARK: 通報・ブロック

    private func report(_ message: ChatMessage, reason: ChatReport.Reason) {
        reporting = nil
        store.hide(message.id)
        show("通報しました。24時間以内に 確認します")
        let copy = message.kind == .sticker ? "#" + (message.stickerId ?? "") : message.text
        Task {
            try? await ChatReport.submit(messageID: message.id, senderId: message.senderId, groupName: group.name, reason: reason, textCopy: copy, reporter: me)
        }
    }

    private func block(_ message: ChatMessage) {
        blocking = nil
        Haptics.play(.thud)
        let target = message.senderId
        let displayName = name(of: target)
        Task {
            _ = try? await ModerationService.blockUser(cloudKitUserRecordName: target, displayName: displayName, modelContext: modelContext)
            show("\(displayName) を ブロックしました")
        }
    }

    // MARK: 1人の とき

    private var emptyRoom: some View {
        let df = DateFormatter(); df.dateFormat = "MM/dd"
        return TripBoardingView(
            name: group.name,
            date: df.string(from: group.creationDate),
            key: tripKey.isEmpty ? "meadow95" : tripKey,
            cover: V64Images.image(key: "tg\(group.id)", data: group.iconImageData, maxPixel: 360),
            me: UserProfile.current(from: profiles)?.name ?? "",
            people: group.members.map { TripSeatPerson(id: $0.id.uuidString, name: $0.name, image: V64Images.image(key: "tm\($0.id)", data: $0.profileImageData, maxPixel: 120)) },
            onSend: shareLink,
            onQR: openPass
        )
        .task(id: group.id) {
            if let k = try? await GroupInviteService.passphrase(for: group, context: modelContext) { tripKey = k }
        }
    }

    /// QR を 見せる:パス(→ T16)
    private func openPass() {
        Haptics.play(.click)
        Task {
            let link = (try? await GroupInviteService.link(for: group, context: modelContext)).flatMap { InviteConfig.shareURL(from: $0) ?? $0 }
            tripPass = TripPassData(group: group, key: tripKey, link: link?.absoluteString ?? "")
        }
    }

    /// 今までと 同じ 招待文で 共有シート
    private func shareLink() {
        Haptics.play(.click)
        Task {
            guard let link = await NewGroupFlowView.makeLink(for: group, context: modelContext) else {
                show("リンクを つくれませんでした")
                return
            }
            let shareURL = InviteConfig.shareURL(from: link) ?? link
            let join = GroupJoinLink.buildURL(shareURL: shareURL) ?? shareURL
            // v108 §5-2:LINE で 押せる https の 文(KEY)。KEY が とれない 時だけ 今までの 文
            if let key = try? await GroupInviteService.passphrase(for: group, context: modelContext) {
                shareItems = [ShareLinkItemSource(text: ShareTextV108.trip(host: ShareTextV108.me.name, name: group.name, dates: nil, members: nil, key: key), title: "「\(group.name)」に招待されました。")]
            } else {
                shareItems = [ShareLinkItemSource(text: InviteConfig.shareMessage(groupName: group.name, url: join), title: "「\(group.name)」に招待されました。")]
            }
        }
    }

    // MARK: 小さな 道具

    private func show(_ text: String) {
        toast = text
        onToast(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { if toast == text { toast = nil } }
    }

    private func profile(_ id: String) -> UserProfile? {
        group.members.first { $0.cloudKitUserRecordName == id }
    }

    private func name(of id: String) -> String {
        if id == me { return "あなた" }
        return profile(id)?.name ?? "なかま"
    }

    private func seed(of id: String) -> UUID { profile(id)?.id ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)) }

    private func avatar(for id: String) -> some View {
        let p = profile(id)
        return LayerAvatar(data: p?.profileImageData, seed: p?.id ?? seed(of: id), name: p?.name ?? "")
    }

    private func photo(named name: String?) -> LaterPhoto? {
        guard let name else { return nil }
        return group.photos.first { $0.ckRecordName == name }
    }
}

// MARK: - 部品

/// 相手の ふきだしの 色(その人の 色を うすく)
enum ChatColors {
    static func tint(seed: UUID, night: Bool) -> Color {
        let base = LayerAvatar.colors(seed).first ?? .gray
        return base.opacity(night ? 0.28 : 0.2)
    }
}

/// 区切り(「9:00 ・ きのうが ひらいた」・日付)
enum ChatDivider {
    static func text(between previous: ChatMessage?, and message: ChatMessage, calendar: Calendar = .current) -> String? {
        let window = DailyWindow.latest(for: message.sentAt, calendar: calendar)
        guard let previous else { return dayText(message.sentAt, calendar: calendar) }
        // 9:00 を またいだ
        if previous.sentAt < window.open && message.sentAt >= window.open {
            return "9:00 ・ きのうが ひらいた"
        }
        if !calendar.isDate(previous.sentAt, inSameDayAs: message.sentAt) { return dayText(message.sentAt, calendar: calendar) }
        return nil
    }

    private static func dayText(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return String(format: "%d.%02d", c.month ?? 1, c.day ?? 1)
    }
}

/// 写真の 小さな 画像
struct ChatPhotoThumb: View {
    let photo: LaterPhoto
    var maxPixel = 420

    @State private var image: UIImage?

    var body: some View {
        Color(hex: "26262B")
            .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } }
            .clipped()
            .task(id: photo.id) {
                let key = "chat-\(photo.id.uuidString)-\(maxPixel)"
                if let hit = MEImageLoader.cached(key) { image = hit; return }
                let data = photo.imageData
                image = await MEImageLoader.load(key: key, data: data)
            }
    }
}

// MARK: - 通報(公開 DB の Report。作成のみ・読み取り不可。本文の 写しも 保存)

enum ChatReport {
    enum Reason: String, CaseIterable, Identifiable {
        case harassment = "いやがらせ"
        case sexual = "性的な 内容"
        case personal = "個人情報"
        case other = "そのほか"
        var id: String { rawValue }
    }

    static func submit(messageID: String, senderId: String, groupName: String, reason: Reason, textCopy: String, reporter: String?) async throws {
        // メッセージは 7日で 消えるので、本文の 写しを detail に 入れる
        let detail = "送った人:\(senderId)\nグループ:\(groupName)\n本文:\(textCopy)"
        try await ModerationService.submitReport(targetType: .chatMessage, targetID: messageID, reasonText: reason.rawValue, detail: detail,
                                                 reporterCloudKitUserRecordName: reporter)
    }
}
