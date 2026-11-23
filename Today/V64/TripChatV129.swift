import SwiftUI
import SwiftData
import UIKit

// P57 B(v129 2章):Trip の チャット(本当に 送れる)。見本:screens/v129_trip_chat.png
// 字 ・ よく使う ことば ・ ステッカー(8つ)・ ひらいた 写真 だけ。時間 と 既読。
// データは 今ある GroupChatStore / GroupChatMessage(Trip の 共有ゾーン)。

struct TripChatV129View: View {
    let group: LaterGroup
    let onClose: () -> Void
    /// はじめから この 写真への 返信に する
    var initialReply: LaterPhoto? = nil
    /// 既読 N(自分の メッセージ より 後に 読んだ 人の 数)。C で `TripReadStore` に つなぐ
    var readCount: (ChatMessage) -> Int = { TripReadStore.shared.readCount(of: $0) }
    /// DEBUG:見本の メッセージを 出す
    var debugMessages: [ChatMessage]? = nil
    var debugMe: String? = nil
    var debugTray: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var blockedUsers: [BlockedUser]

    @State private var store = GroupChatStore.shared
    @State private var draft = ""
    @FocusState private var focused: Bool
    @State private var tray: Tray?
    @State private var replyPhoto: LaterPhoto?
    @State private var reporting: ChatMessage?
    @State private var blocking: ChatMessage?
    @State private var toast: String?
    @State private var now = Date()

    private enum Tray { case photos, stickers }

    private var me: String? { debugMe ?? CloudKitManager.current?.currentUserRecordName }
    private var blocked: Set<String> { Set(blockedUsers.map(\.blockedCloudKitUserRecordName)) }
    private var tint: Color { PopColor.trip(group.tripColor >= 0 ? group.tripColor : 1) }
    private var messages: [ChatMessage] { debugMessages ?? store.visible(group.id, blocked: blocked, now: now) }
    private var items: [TripChatRules.Item] { TripChatRules.items(messages, me: me, tripStart: group.tripStart ?? group.creationDate) }

    private let bg = Color(hex: "0A0A0B")
    private let other = Color(hex: "1F1F23")

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.06))
            list
        }
        .background(bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { inputArea }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast).font(Typo.ui(800, 13)).foregroundStyle(Color(hex: "111113"))
                    .padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(.white))
                    .padding(.top, 70).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toast)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onAppear {
            if let debugTray { tray = debugTray == "stickers" ? .stickers : .photos }
            if debugMessages != nil { return }
            store.openRoom = group.id
            store.markSeen(group.id)
            readNow()
            if let initialReply { replyPhoto = initialReply; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true } }
        }
        .onDisappear {
            if store.openRoom == group.id { store.openRoom = nil }
            store.markSeen(group.id)
            if debugMessages == nil { TripReadStore.shared.markRead(group: group, flush: true) }
        }
        .task { while !Task.isCancelled { try? await Task.sleep(for: .seconds(30)); now = Date() } }
        .confirmationDialog("通報する 理由", isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }), titleVisibility: .visible) {
            ForEach(ChatReport.Reason.allCases) { reason in Button(reason.rawValue) { if let m = reporting { report(m, reason: reason) } } }
            Button("やめる", role: .cancel) { reporting = nil }
        }
        .alert(blocking.map { "\(name(of: $0.senderId)) を ブロックする?" } ?? "", isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } })) {
            Button("ブロックする", role: .destructive) { if let m = blocking { block(m) } }
            Button("やめる", role: .cancel) { blocking = nil }
        } message: { Text("その人の メッセージと 写真が、あなたに 見えなく なります。相手には 知らせません。") }
    }

    // MARK: 上(もどる ・ Trip の 名前 ・ メンバー)

    private var dayText: String {
        let cal = Calendar.current
        let start = cal.startOfDay(for: group.tripStart ?? group.creationDate)
        let n = max(1, (cal.dateComponents([.day], from: start, to: cal.startOfDay(for: now)).day ?? 0) + 1)
        let total = group.tripEnd.map { max(n, (cal.dateComponents([.day], from: start, to: cal.startOfDay(for: $0)).day ?? 0) + 1) }
        return total.map { "DAY \(n) / \($0)" } ?? "DAY \(n)"
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { Haptics.play(.tick); focused = false; onClose() } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(HVPress(scale: 0.92)).accessibilityLabel("もどる")
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name).font(Typo.title(22)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 5) {
                    Circle().fill(HV.lime).frame(width: 6, height: 6)
                    Text("\(group.members.count)人 ・ \(dayText)").font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: -9) {
                ForEach(Array(group.members.prefix(4).enumerated()), id: \.offset) { _, m in
                    face(name: m.name, data: m.profileImageData, 28).overlay(Circle().strokeBorder(bg, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: 一覧

    private var list: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in row(item).transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity)) }
                    Color.clear.frame(height: 10).id("bottom")
                }
                .padding(.horizontal, 12).padding(.top, 10)
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72), value: items.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: items.count) { _, _ in withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("bottom", anchor: .bottom) }; store.markSeen(group.id); readNow() }
            .onChange(of: focused) { _, f in if f { withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("bottom", anchor: .bottom) } } }
            .onChange(of: tray) { _, _ in DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("bottom", anchor: .bottom) } } }
        }
    }

    @ViewBuilder private func row(_ item: TripChatRules.Item) -> some View {
        switch item {
        case .day(_, let label):
            Text(label).font(Typo.ui(800, 11)).foregroundStyle(.white.opacity(0.55)).padding(.horizontal, 12).padding(.vertical, 5)
                .background(.white.opacity(0.08), in: Capsule()).padding(.vertical, 14)
        case .system(let m):
            HStack(spacing: 6) {
                Image(systemName: m.text.contains("撮") ? "camera" : "paperplane").font(.system(size: 11, weight: .bold)).foregroundStyle(tint)
                Text(m.text).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12).padding(.vertical, 5).background(.white.opacity(0.07), in: Capsule()).padding(.vertical, 8)
        case .bubble(let m, let first, let last, let mine):
            bubbleRow(m, first: first, last: last, mine: mine).padding(.top, first ? 10 : 2)
        }
    }

    private func bubbleRow(_ m: ChatMessage, first: Bool, last: Bool, mine: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 6) {
            if mine { Spacer(minLength: 56) }
            else {
                // 丸い 写真は かたまりの 最後 だけ
                if last { face(name: name(of: m.senderId), data: person(m.senderId)?.profileImageData, 28) } else { Color.clear.frame(width: 28, height: 28) }
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if first, !mine { Text(name(of: m.senderId)).font(Typo.ui(700, 11)).foregroundStyle(.white.opacity(0.5)).padding(.leading, 4) }
                HStack(alignment: .bottom, spacing: 6) {
                    if mine { meta(m, last: last, mine: true) }
                    content(m, mine: mine, first: first, last: last)
                        .contextMenu {
                            if !mine, m.status != .failed {
                                Button("通報する", systemImage: "exclamationmark.bubble", role: .destructive) { reporting = m }
                                Button("ブロック", systemImage: "hand.raised", role: .destructive) { blocking = m }
                            }
                        }
                        .onTapGesture { if mine, m.status == .failed, let g = Optional(group) { store.retry(m, group: g) } }
                    if !mine { meta(m, last: last, mine: false) }
                }
            }
            if !mine { Spacer(minLength: 56) }
        }
    }

    /// 時間は かたまりの 最後の 横に(10pt)。自分の 物には 既読 N
    @ViewBuilder private func meta(_ m: ChatMessage, last: Bool, mine: Bool) -> some View {
        if last {
            VStack(alignment: mine ? .trailing : .leading, spacing: 0) {
                if mine, m.status == .sending { Text("送信中").font(Typo.ui(700, 10)).foregroundStyle(.white.opacity(0.4)) }
                else if mine, m.status == .failed { Text("送れなかった ・ タップで 再送").font(Typo.ui(700, 10)).foregroundStyle(HVCardTint.badge) }
                else {
                    if mine, readCount(m) > 0 { Text("既読 \(readCount(m))").font(Typo.ui(800, 10)).foregroundStyle(.white.opacity(0.55)) }
                    Text(Self.time(m.sentAt)).font(Typo.ui(700, 10)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .fixedSize()
        }
    }

    private static func time(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "H:mm"; return f.string(from: d) }

    @ViewBuilder private func content(_ m: ChatMessage, mine: Bool, first: Bool, last: Bool) -> some View {
        switch m.kind {
        case .sticker:
            if let art = TripChatRules.art(m.stickerId) {
                PopSticker(shape: art.shape, color: art.color, size: 76, tilt: art.tilt)
            } else {
                Text("#\(m.stickerId ?? "")").font(.system(size: 22, weight: .black)).foregroundStyle(Color(hex: "FF6A1A"))   // 古い ハッシュタグ型
            }
        case .photo:
            if let p = photo(named: m.photoRecordName) {
                ChekiFrame(caption: p.tags.first.map { "#\($0)" } ?? Self.time(p.captureDate), captionSize: 15, tilt: Double(abs(m.id.hashValue % 5)) - 2) {
                    ChatPhotoThumb(photo: p, maxPixel: 420)
                }
                .frame(width: 170)
            } else {
                text("写真", mine: mine, first: first, last: last)
            }
        case .photoReply:
            VStack(alignment: .leading, spacing: 6) {
                if let p = photo(named: m.photoRecordName) { ChatPhotoThumb(photo: p).frame(width: 120, height: 150).clipShape(RoundedRectangle(cornerRadius: 10)) }
                if !m.text.isEmpty { Text(m.text).font(Typo.ui(700, 15)).foregroundStyle(mine ? Color(hex: "111113") : .white) }
            }
            .padding(.horizontal, 13).padding(.vertical, 9).background(mine ? HV.lime : other, in: bubbleShape(mine: mine, first: first, last: last))
        default:
            if ChatRules.isEmojiOnly(m.text) { Text(m.text).font(.system(size: 44)) }
            else { text(m.text, mine: mine, first: first, last: last) }
        }
    }

    private func text(_ s: String, mine: Bool, first: Bool, last: Bool) -> some View {
        Text(s).font(Typo.ui(700, 15)).foregroundStyle(mine ? Color(hex: "111113") : .white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(mine ? HV.lime : other, in: bubbleShape(mine: mine, first: first, last: last))
    }

    /// 続けて 送った 物は つなぐ 側の 角を 小さく(自分 = 右 ・ 相手 = 左)
    private func bubbleShape(mine: Bool, first: Bool, last: Bool) -> UnevenRoundedRectangle {
        let big: CGFloat = 18, small: CGFloat = 5
        let top = first ? big : small, bottom = last ? big : small
        return mine ? UnevenRoundedRectangle(topLeadingRadius: big, bottomLeadingRadius: big, bottomTrailingRadius: bottom, topTrailingRadius: top, style: .continuous)
                    : UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: big, topTrailingRadius: big, style: .continuous)
    }

    // MARK: 下(よく使う ことば ・ トレイ ・ 入力)

    private var inputArea: some View {
        VStack(spacing: 8) {
            if let replyPhoto {
                HStack(spacing: 10) {
                    ChatPhotoThumb(photo: replyPhoto, maxPixel: 120).frame(width: 36, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("この 写真に 返信").font(Typo.ui(700, 13)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button { self.replyPhoto = nil } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7)).frame(width: 44, height: 44) }
                }
                .padding(.horizontal, 14)
            }
            if draft.isEmpty && tray != .stickers { quickRow.transition(.opacity) }
            switch tray {
            case .photos: photoTray.transition(.move(edge: .bottom).combined(with: .opacity))
            case .stickers: stickerTray.transition(.move(edge: .bottom).combined(with: .opacity))
            case nil: EmptyView()
            }
            HStack(spacing: 8) {
                trayButton("photo", on: tray == .photos, label: "写真") { toggleTray(.photos) }
                trayButton("face.smiling", on: tray == .stickers, label: "ステッカー") { toggleTray(.stickers) }
                TextField("", text: $draft, prompt: Text("メッセージ").foregroundColor(.white.opacity(0.35)), axis: .horizontal)
                    .font(Typo.ui(700, 15)).foregroundStyle(.white).tint(HV.lime)
                    .focused($focused).submitLabel(.send).onSubmit { sendDraft() }
                    .padding(.horizontal, 16).frame(height: 44).background(.white.opacity(0.08), in: Capsule())
                    .onChange(of: draft) { _, v in if v.count > ChatRules.maxLength { draft = String(v.prefix(ChatRules.maxLength)) } }
                Button { sendDraft() } label: {
                    let ok = TripChatRules.canSendText(draft)
                    Image(systemName: "arrow.up").font(.system(size: 16, weight: .black)).foregroundStyle(Color(hex: "111113"))
                        .frame(width: 44, height: 44).background(HV.lime.opacity(ok ? 1 : 0.3), in: Circle())
                }
                .buttonStyle(HVPress(scale: 0.92)).disabled(!TripChatRules.canSendText(draft)).accessibilityLabel("送る")
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8).padding(.bottom, 8)
        .background(bg.opacity(0.97).ignoresSafeArea(edges: .bottom))
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: tray)
        .animation(.easeOut(duration: 0.15), value: draft.isEmpty)
    }

    private func trayButton(_ icon: String, on: Bool, label: String, _ action: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); action() } label: {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(on ? Color(hex: "111113") : .white.opacity(0.85))
                .frame(width: 44, height: 44).background(on ? tint : Color.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(HVPress(scale: 0.92)).accessibilityLabel(label)
    }

    private func toggleTray(_ t: Tray) { focused = false; tray = (tray == t) ? nil : t }

    private var quickRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TripChatRules.quickPhrases, id: \.self) { p in
                    Button { send(.text, text: p) } label: {
                        Text(p).font(Typo.ui(800, 13)).foregroundStyle(.white).padding(.horizontal, 14).frame(height: 36)
                            .background(.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(HVPress(scale: 0.94)).frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var stickerTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TripChatRules.stickers) { art in
                    Button { send(.sticker, stickerId: art.id) } label: { PopSticker(shape: art.shape, color: art.color, size: 52, tilt: art.tilt).frame(width: 66, height: 66) }
                        .buttonStyle(HVPress(scale: 0.9)).accessibilityLabel("ステッカー")
                }
            }
            .padding(.horizontal, 12)
        }
    }

    /// ひらいた 写真 だけ(きょうの 分は あした 9:00 から)
    private var photoTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TripChatRules.photoNote).font(Typo.ui(700, 11.5)).foregroundStyle(.white.opacity(0.55)).padding(.horizontal, 14)
            let photos = TripChatRules.sendable(group.photos.filter { $0.ckRecordName != nil }, takenAt: \.captureDate, now: now)
            if photos.isEmpty {
                Text("まだ ひらいた 写真は ありません").font(Typo.ui(700, 13)).foregroundStyle(.white.opacity(0.4)).frame(maxWidth: .infinity, minHeight: 70)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(photos.prefix(40), id: \.id) { p in
                            Button { send(.photo, photo: p) } label: {
                                ChekiFrame(caption: "", captionSize: 10, tilt: 0) { ChatPhotoThumb(photo: p, maxPixel: 200) }
                                    .frame(width: 82).environment(\.dynamicTypeSize, .medium)
                            }
                            .buttonStyle(HVPress(scale: 0.94)).accessibilityLabel("ひらいた 写真を 送る")
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 118)
            }
        }
    }

    // MARK: 送る

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TripChatRules.canSendText(text) else { return }
        if let refusal = ChatRules.check(text) { LayerHaptics.softDouble(); show(refusal); return }
        if let replyPhoto {
            Haptics.play(.pop)
            store.send(kind: .photoReply, text: text, photoRecordName: replyPhoto.ckRecordName, group: group)
            self.replyPhoto = nil
        } else {
            send(.text, text: text)
        }
        draft = ""
    }

    private func send(_ kind: ChatMessage.Kind, text: String = "", stickerId: String? = nil, photo: LaterPhoto? = nil) {
        if kind == .text, let refusal = ChatRules.check(text) { LayerHaptics.softDouble(); show(refusal); return }
        if kind == .photo {
            // きょうの 写真は 送れない(一覧に 出さない + ここでも 止める)
            guard let photo, TripChatRules.canSendPhoto(takenAt: photo.captureDate, now: Date()), photo.ckRecordName != nil else { show("きょうの 写真は あした 9:00 から 送れます"); return }
            tray = nil
        }
        if kind == .sticker { tray = nil }
        Haptics.play(kind == .sticker ? .heart : .pop)
        store.send(kind: kind, text: text, stickerId: stickerId, photoRecordName: photo?.ckRecordName, group: group)
    }

    /// ひらいて いる 間 は 「ここまで 読んだ」を 進める(1秒に 1回 まで)
    private func readNow() {
        guard debugMessages == nil else { return }
        TripReadStore.shared.markRead(group: group, at: max(Date(), messages.last?.sentAt ?? .distantPast))
    }

    // MARK: 人

    private func person(_ senderId: String) -> UserProfile? {
        group.members.first { ($0.cloudKitUserRecordName ?? "local_\($0.id.uuidString)") == senderId }
    }
    private func name(of senderId: String) -> String { senderId == me ? "あなた" : (person(senderId)?.name ?? "だれか") }
    private func photo(named name: String?) -> LaterPhoto? { name.flatMap { n in group.photos.first { $0.ckRecordName == n } } }

    private func face(name: String, data: Data?, _ s: CGFloat) -> some View {
        ZStack {
            if let img = V64Images.image(key: "tcf\(name)\(data?.count ?? 0)", data: data, maxPixel: 96) { Image(uiImage: img).resizable().scaledToFill() }
            else {
                Circle().fill(LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "61DD7A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Text(String(name.prefix(1))).font(Typo.ui(900, s * 0.42)).foregroundStyle(.white))
            }
        }
        .frame(width: s, height: s).clipShape(Circle())
    }

    // MARK: 通報 ・ ブロック

    private func show(_ s: String) {
        toast = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { if toast == s { toast = nil } }
    }

    private func report(_ m: ChatMessage, reason: ChatReport.Reason) {
        reporting = nil
        store.hide(m.id)
        show("通報しました。24時間以内に 確認します")
        let copy = m.kind == .sticker ? "#" + (m.stickerId ?? "") : (m.kind == .photo ? "(写真)" : m.text)
        Task { try? await ChatReport.submit(messageID: m.id, senderId: m.senderId, groupName: group.name, reason: reason, textCopy: copy, reporter: me) }
    }

    private func block(_ m: ChatMessage) {
        blocking = nil
        Haptics.play(.thud)
        let target = m.senderId, displayName = name(of: target)
        Task {
            _ = try? await ModerationService.blockUser(cloudKitUserRecordName: target, displayName: displayName, modelContext: modelContext)
            show("\(displayName) を ブロックしました")
        }
    }
}
