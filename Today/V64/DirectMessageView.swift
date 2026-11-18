import SwiftUI

/// 友だちとの 1対1 チャット(F07)。明るい ベージュの 地 + 吹き出し + 下の 入力。5秒ごとに 読みなおす。
/// 上:名前 + `ふたり ・ 7日で きえる` ・ 2人の 丸 + 7日の 点。7日で きえる メッセージの きまりは そのまま。
struct DirectMessageView: View {
    let friendID: String
    let friendName: String
    var friendAvatar: UIImage? = nil
    /// 相手の きのうの こま数(0 なら カードを 出さない)
    var yesterdayCount = 0
    /// DEBUG:見本の メッセージ(本番は nil ・ CloudKit から)
    var injected: [DirectMessages.Message]? = nil

    @State private var messages: [DirectMessages.Message] = []
    @State private var draft = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private let ink = Color(hex: "0B0C0D"), green = Color(hex: "24A03C"), cream = Color(hex: "F5F4F0")

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        Text(Self.day(messages.first?.createdAt ?? Date())).font(LF.mono(12)).tracking(1.5).foregroundStyle(ink.opacity(0.45)).padding(.top, 14)
                        if yesterdayCount > 0 { yesterdayCard }
                        Text("友だちに なりました ・ メッセージは 7日で きえます").font(LF.inter(700, 13)).foregroundStyle(ink.opacity(0.45)).padding(.horizontal, 28).frame(height: 30).background(ink.opacity(0.07), in: Capsule()).padding(.top, 14)
                        ForEach(Array(messages.enumerated()), id: \.element.id) { i, m in bubble(m, first: i == 0 || messages[i - 1].senderID != m.senderID).id(m.id) }
                    }.padding(.horizontal, 16).padding(.bottom, 20)
                }
                .onChange(of: messages.count) { _, _ in if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            HStack(spacing: 10) {
                Text("#").font(LF.inter(900, 26)).foregroundStyle(green).frame(width: 52, height: 52).background(.white, in: Circle()).shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                HStack {
                    TextField("", text: $draft, prompt: Text("メッセージ").foregroundColor(ink.opacity(0.35))).font(LF.inter(500, 18)).foregroundStyle(ink).focused($focused).submitLabel(.send).onSubmit(send)
                    if DirectMessages.clean(draft) != nil { Button(action: send) { Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(.white).frame(width: 36, height: 36).background(green, in: Circle()) }.buttonStyle(.plain) }
                }.padding(.horizontal, 20).frame(height: 52).background(.white, in: Capsule()).shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }.padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(cream.ignoresSafeArea()).environment(\.colorScheme, .light)
        .task {
            if let injected { messages = injected; return }
            while !Task.isCancelled { messages = await DirectMessages.fetch(with: friendID); try? await Task.sleep(for: .seconds(5)) }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                VStack(spacing: 2) {
                    Text(friendName).font(LGFont.mincho(30)).foregroundStyle(ink)
                    Text("ふたり ・ 7日で きえる").font(LF.inter(700, 14)).foregroundStyle(green)
                }
                HStack {
                    circleButton("chevron.left") { dismiss() }
                    Spacer()
                    circleButton("ellipsis") { Haptics.play(.tick) }
                }
            }.padding(.horizontal, 14).padding(.top, 50)
            HStack {
                ZStack { Circle().strokeBorder(ink.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(width: 46, height: 46); Circle().fill(LinearGradient(colors: [Color(hex: "61D278"), Color(hex: "B9A8A0")], startPoint: .top, endPoint: .bottom)).frame(width: 38, height: 38) }
                avatar(friendAvatar, friendName, 46).overlay(Circle().strokeBorder(green, lineWidth: 3).padding(-3))
                Spacer()
                HStack(spacing: 6) { ForEach(0..<7, id: \.self) { i in Circle().fill(i == 0 ? green : .clear).overlay(Circle().strokeBorder(i <= 1 ? green : ink.opacity(0.25), lineWidth: 1.5)).frame(width: i == 1 ? 14 : 8, height: i == 1 ? 14 : 8) } }
            }.padding(.horizontal, 22)
        }.padding(.bottom, 12)
    }

    private func circleButton(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.play(.tick); a() } label: { Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(ink).frame(width: 44, height: 44).background(ink.opacity(0.07), in: Circle()) }.buttonStyle(.plain)
    }

    private func avatar(_ img: UIImage?, _ name: String, _ s: CGFloat) -> some View {
        ZStack { if let img { Image(uiImage: img).resizable().scaledToFill() } else { Circle().fill(LinearGradient(colors: [Color(hex: "7FB0FF"), Color(hex: "B28CFF")], startPoint: .top, endPoint: .bottom)).overlay(Text(String(name.prefix(1))).font(LF.inter(900, s * 0.4)).foregroundStyle(.white)) } }.frame(width: s, height: s).clipShape(Circle())
    }

    private var yesterdayCard: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [ink.opacity(0.5), ink.opacity(0.2), ink.opacity(0.5)], startPoint: .leading, endPoint: .trailing)).blur(radius: 6).frame(width: 200, height: 52)
                HStack(spacing: 6) { Image(systemName: "lock").font(.system(size: 13, weight: .bold)); Text("撮ると、ひらく").font(LF.inter(800, 17)) }.foregroundStyle(.white).padding(.horizontal, 20).frame(height: 38).background(ink, in: Capsule())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) { Text("yesterday").font(LF.serif(32, italic: true)).foregroundStyle(ink); Text("\(yesterdayCount) こま").font(LF.mono(12)).foregroundStyle(ink.opacity(0.45)) }
        }.padding(.horizontal, 18).frame(height: 110).background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous)).shadow(color: .black.opacity(0.08), radius: 12, y: 6).padding(.top, 18)
    }

    private func bubble(_ m: DirectMessages.Message, first: Bool) -> some View {
        let mine = m.senderID == DirectMessages.me
        return HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 60) } else { if first { avatar(friendAvatar, friendName, 30) } else { Color.clear.frame(width: 30, height: 1) } }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if first && !mine { Text(friendName).font(LF.inter(700, 12)).foregroundStyle(ink.opacity(0.45)).padding(.leading, 6) }
                Text(m.text).font(LF.inter(500, 18)).foregroundStyle(ink).padding(.horizontal, 18).padding(.vertical, 12).background(mine ? Color(hex: "D9F5C9") : Color(hex: "E8EEFF"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            if !mine { Spacer(minLength: 60) }
        }
    }

    private static func day(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MM.dd"; return f.string(from: d) }

    private func send() {
        guard let text = DirectMessages.clean(draft) else { return }
        draft = ""
        Haptics.play(.pop)
        Task { if let m = await DirectMessages.send(text, to: friendID) { messages.append(m) } }
    }
}
